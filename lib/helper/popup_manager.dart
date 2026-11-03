import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pop-up manager (Oct 2026): the one place that decides which pop-up
/// may open by itself, so she never gets several in a row.
///
/// Rules:
///  1. One pop-up at a time, never on top of another dialog or sheet.
///  2. Only on the Home tab, with no other screen on top, and only after
///     the app has been open for [_settle] (so home shows first).
///  3. One planned pop-up per app open. If several want to open, the one
///     with the smallest rank wins (see [PopupRank]); the others wait for
///     a later app open.
///  4. The next planned pop-up only when the app is opened again, and at
///     least [_gap] after the last one closed.
///  5. At most [_maxPerDay] planned pop-ups a day.
///  6. Urgent ones (required update, class cancelled) skip rules 2 to 5:
///     they only wait for the pop-up on screen to close, and they don't
///     use up the turn.
///
/// Things she opens herself (tapping a push, a Home card, a button) do
/// not come here, so they always open.
class PopupManager {
  PopupManager._();

  static const Duration _settle = Duration(seconds: 3);
  static const Duration _gap = Duration(minutes: 30);
  static const int _maxPerDay = 2;
  // Waits this long for Home to be free (e.g. she is in a chat), then
  // gives up until the next app open.
  static const Duration _maxWait = Duration(minutes: 10);
  static const Duration _poll = Duration(seconds: 1);

  static const String _kLastClosed = 'pm_last_closed_at';
  static const String _kDay = 'pm_day';
  static const String _kDayCount = 'pm_day_count';

  /// Goes up by one every time the app is opened again from the
  /// background. Screens listen to it to ask again for a pop-up that
  /// lost its turn.
  static final RxInt opens = 0.obs;

  /// Set by the bottom bar: Home tab selected, and the bottom bar's own
  /// route (to know when another screen is on top, for paid AND
  /// trial/free users).
  static bool onHomeTab = true;
  static ModalRoute<dynamic>? homeRoute;
  // Extra flag, used by tests.
  static bool homeCovered = false;

  static DateTime _openedAt = DateTime.now();
  static bool _usedThisOpen = false;
  static bool _busy = false;
  static bool _deciding = false;
  static bool _started = false;
  static final List<_Ask> _waiting = [];

  /// Call once the main tabs are on screen. Safe to call again.
  static void init() {
    if (_started) return;
    _started = true;
    _openedAt = DateTime.now();
    WidgetsBinding.instance.addObserver(_Lifecycle());
  }

  static void _onResumed() {
    _openedAt = DateTime.now();
    _usedThisOpen = false;
    opens.value++;
  }

  static bool get _screenBusy =>
      _busy || (Get.isDialogOpen ?? false) || (Get.isBottomSheetOpen ?? false);

  static bool get _homeFree =>
      onHomeTab &&
      !homeCovered &&
      (homeRoute?.isCurrent ?? true) &&
      !_screenBusy;

  /// Asks to show a pop-up. [show] opens it and must finish when it is
  /// closed. Returns true if it was shown, false if it has to wait for a
  /// later app open (then nothing was shown and nothing should be marked).
  static Future<bool> run(
    String id, {
    required int rank,
    required Future<void> Function() show,
    bool urgent = false,
  }) async {
    if (urgent) return _runUrgent(id, show);
    if (_waiting.any((a) => a.id == id)) return false;
    final ask = _Ask(id, rank, show);
    _waiting.add(ask);
    if (!_deciding) unawaited(_decide());
    return ask.done.future;
  }

  /// She tapped something (a push) that opens a pop-up: show it now, only
  /// waiting for the open pop-up to close. Uses up this open's turn, so
  /// no planned pop-up opens right after it. Not counted in the daily 2.
  static Future<void> runNow(String id, Future<void> Function() show) async {
    _usedThisOpen = true;
    await _runUrgent(id, show);
    await _setLastClosed();
  }

  /// Her first landing on home right after sign-up (welcome sheet).
  /// It is part of the sign-up flow, so it does not wait for a turn, the
  /// 30-minute gap or the daily limit (all left over from an earlier
  /// account on the same phone). It only waits until Home is on screen
  /// with nothing on top (max 2 min), then uses up this open's turn so no
  /// other planned pop-up opens right after it. Returns false if Home
  /// never became free (asked again on the next open).
  static Future<bool> runFirstLanding(
      String id, Future<void> Function() show,
      {Duration wait = const Duration(milliseconds: 1500)}) async {
    await Future.delayed(wait);
    for (var i = 0; i < 120 && !_homeFree; i++) {
      await Future.delayed(_poll);
    }
    if (!_homeFree) return false;
    _usedThisOpen = true;
    _busy = true;
    try {
      await show();
    } catch (e) {
      debugPrint('[popup_manager] $id: $e');
    } finally {
      _busy = false;
      await _setLastClosed();
    }
    return true;
  }

  /// A one-time SETUP step on this phone (Oct 2026: "Turn on
  /// notifications" right after install / first login). Waits until Home
  /// is on screen with nothing on top, shows, and does NOT use up the
  /// turn or start the 30-min gap, so the planned pop-up of this open can
  /// still follow after it. Returns false if Home never became free.
  static Future<bool> runSetup(String id, Future<void> Function() show) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    for (var i = 0; i < 120 && !_homeFree; i++) {
      await Future.delayed(_poll);
    }
    if (!_homeFree) return false;
    _busy = true;
    try {
      await show();
    } catch (e) {
      debugPrint('[popup_manager] $id: $e');
    } finally {
      _busy = false;
    }
    return true;
  }

  static Future<bool> _runUrgent(
      String id, Future<void> Function() show) async {
    // Wait for the pop-up on screen to close (max 2 min), then show.
    for (var i = 0; i < 120 && _screenBusy; i++) {
      await Future.delayed(_poll);
    }
    _busy = true;
    try {
      await show();
    } catch (e) {
      debugPrint('[popup_manager] $id: $e');
    } finally {
      _busy = false;
    }
    return true;
  }

  static Future<void> _decide() async {
    _deciding = true;
    try {
      final started = DateTime.now();
      // Wait for the settle time, then for Home to be free.
      while (true) {
        final settled = DateTime.now().difference(_openedAt) >= _settle;
        if (settled && _homeFree) break;
        if (DateTime.now().difference(started) > _maxWait) {
          _declineAll();
          return;
        }
        await Future.delayed(_poll);
      }
      if (_waiting.isEmpty) return;
      if (!await _allowedNow()) {
        _declineAll();
        return;
      }

      _waiting.sort((a, b) => a.rank.compareTo(b.rank));
      final winner = _waiting.removeAt(0);
      _declineAll();

      _usedThisOpen = true;
      _busy = true;
      await _countToday();
      var shown = true;
      try {
        await winner.show();
      } catch (e) {
        shown = false;
        debugPrint('[popup_manager] ${winner.id}: $e');
      } finally {
        _busy = false;
        await _setLastClosed();
      }
      winner.done.complete(shown);
    } finally {
      _deciding = false;
      // Someone asked while this one was open: decide for them too
      // (they will be told "wait", as the turn is used).
      if (_waiting.isNotEmpty) unawaited(_decide());
    }
  }

  static void _declineAll() {
    for (final a in _waiting) {
      if (!a.done.isCompleted) a.done.complete(false);
    }
    _waiting.clear();
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static Future<bool> _allowedNow() async {
    if (_usedThisOpen) return false;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastClosed) ?? 0;
    final sinceLast = DateTime.now().millisecondsSinceEpoch - last;
    if (sinceLast < _gap.inMilliseconds) return false;
    final count =
        prefs.getString(_kDay) == _today() ? (prefs.getInt(_kDayCount) ?? 0) : 0;
    return count < _maxPerDay;
  }

  static Future<void> _countToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final count =
        prefs.getString(_kDay) == today ? (prefs.getInt(_kDayCount) ?? 0) : 0;
    await prefs.setString(_kDay, today);
    await prefs.setInt(_kDayCount, count + 1);
  }

  static Future<void> _setLastClosed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastClosed, DateTime.now().millisecondsSinceEpoch);
  }
}

/// Planned order: smaller rank opens first.
class PopupRank {
  PopupRank._();
  // Announcement: 2nd in line, right after the urgent ones (Oct 2026).
  static const int announcement = 3;
  static const int lastDay = 5; // last day of a short window (diet check-in)
  // Free-trial moment of the day (Day 3 / Day 4 / last day / trial ended,
  // widgets/trial_moments): ahead of setup asks, so it isn't pushed back
  // by them during the busy first days (Nov 2026).
  static const int trialMoment = 6;
  // Welcome sheet right after sign-up: her first landing on home (Oct 2026).
  static const int trialWelcome = 8;
  static const int notifications = 10;
  static const int classRating = 20;
  // Paid-plan welcome goes before the notifications ask (Oct 2026): it
  // only lasts 3 days after she pays, the ask can wait one open.
  static const int welcome = 9;
  static const int healthForm = 40;
  static const int classTimes = 45;
  static const int bookSession = 50;
  static const int progress = 60; // Day 7 / 15 / 30
  static const int followUp = 70;
  static const int dietCheckin = 80;
  static const int renew = 90;
  static const int other = 95;
  static const int optionalUpdate = 110;
}

class _Ask {
  _Ask(this.id, this.rank, this.show);
  final String id;
  final int rank;
  final Future<void> Function() show;
  final Completer<bool> done = Completer<bool>();
}

class _Lifecycle extends WidgetsBindingObserver {
  AppLifecycleState? _last;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameBack = state == AppLifecycleState.resumed &&
        (_last == AppLifecycleState.paused ||
            _last == AppLifecycleState.hidden);
    if (state != AppLifecycleState.inactive) _last = state;
    if (cameBack) PopupManager._onResumed();
  }
}
