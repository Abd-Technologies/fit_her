import '../../helper/class_join_memory.dart';
import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../../data/controllers/motivation_controller/motivation_controller.dart';
import '../../data/models/home_dashboard/home_dashboard_model.dart';
import '../../helper/analytics_helper.dart';
import '../../utils/app_clock.dart';
import '../../utils/slot_input_builder.dart'
    show parseSlotWallClock, minutesUntilStart;
import '../../utils/slot_ui_state.dart';
import '../app_bar_widget.dart';
import '../toasts.dart';
import '../class_reminder/class_reminder_flow.dart';
import '../new_home/phase_theme.dart';
import '../anim/live_dot.dart';
import '../anim/motion.dart';

/// H-01 LIVE section.
///
/// Ported from the Workout Schedule screen's "STARTING SOON → LIVE" card
/// (see work_out_bottom_screen.dart's _buildLiveCard + lib/utils/slot_ui_state.dart)
/// so the home screen no longer needs a trainer to manually flip a slot to
/// "In Progress" before showing anything.
///
/// This widget still calls the shared [resolveSlotUIState] resolver for the
/// things it's authoritative on -- cancelled, the actual joinable/blocked
/// gate, and "the class is over" -- so Home can never disagree with the
/// Workout Schedule screen about whether a class is cancelled or genuinely
/// joinable. But the *pre-join* lifecycle Shaista asked for here (a
/// "Confirmed" status well before class, then a "Get ready" step once the
/// trainer's added the link and we're close to start, and finally "Live"
/// only once she taps "In Progress" from her panel) is specific to this
/// card's design and isn't something the schedule screen has adopted, so
/// it's computed locally in this file rather than added to the shared
/// resolver. That keeps this redesign from silently changing the Workout
/// Schedule screen's look too -- if that's wanted later, say so and this
/// logic can move into slot_ui_state.dart for both screens to share.
///
/// Phases, matching `Home_All43_Variants.html` CAT 2 where a mockup state
/// exists, plus three new pre-join states the mockup never designed for:
///   - cancelled       -- trainer cancelled the slot. No mockup state; own
///                        neutral "Cancelled" look, no button.
///   - confirmed        -- more than [_kGetReadyLeadMinutes] before start.
///                        No mockup state; own "Confirmed" look, no button
///                        (the class is scheduled and on -- nothing to do
///                        yet).
///   - waitingForLink   -- within [_kGetReadyLeadMinutes] of start (or
///                        already inside the class window) but the trainer
///                        hasn't added the Zoom link yet. Old grey-button
///                        "Trainer is setting up" look.
///   - getReady (H-06)  -- within [_kGetReadyLeadMinutes] of start (or
///                        inside the window) AND the trainer's link is up,
///                        but she hasn't tapped "In Progress" yet. Green
///                        ghost "Get ready" button.
///   - live, H-05        -- she tapped "In Progress": actually joinable,
///                        more than [_kNearEndMinutes] left.
///   - live, H-09        -- joinable, [_kNearEndMinutes] or less left
///                        ("Rejoin" + green "IN SESSION" pill).
///   - liveBlocked        -- joinable per the trainer, but this user is
///                        frozen/expired. Old grey-button look with the
///                        specific block-reason toast.
///
/// Title splits on the FIRST space: first word in bold #fff, rest muted.
/// A single-word title (e.g., "Yoga") renders all-bold with no muted suffix.
/// (H-09 is the one exception -- the mockup renders its title as a single
/// solid-bold string with no split, so that phase skips the split.)
class PaidHeroLiveSection extends StatefulWidget {
  final LiveClass? live;
  final PhaseTheme theme;
  // Frozen-plan awareness (architecture item #2): the backend already
  // refuses to let a frozen user join a live class (findFrozenActivePlan
  // gate in AdminController's join endpoint) -- this just makes the
  // button stop lying about it before the tap, instead of showing a live
  // "Join" CTA that only fails after the user taps it. Defaults to false
  // so nothing changes for any existing caller that doesn't pass it.
  final bool isFrozen;

  /// Preview (not started the free trial yet): every action button on
  /// the card becomes this one, e.g. "Try free →" that starts the trial.
  final String? previewCtaLabel;
  final VoidCallback? onPreviewCta;

  const PaidHeroLiveSection({
    Key? key,
    required this.live,
    required this.theme,
    this.isFrozen = false,
    this.previewCtaLabel,
    this.onPreviewCta,
  }) : super(key: key);

  @override
  State<PaidHeroLiveSection> createState() => _PaidHeroLiveSectionState();
}

enum _Phase { cancelled, confirmed, waitingForLink, getReady, live, blocked }

class _PaidHeroLiveSectionState extends State<PaidHeroLiveSection> {
  // Local clock tick so a state that flips purely because of elapsed time
  // (e.g. "Confirmed" -> "Get ready", "LIVE" -> "IN SESSION") repaints
  // without waiting on the next network refresh. Same 30s cadence
  // PaidHeroComingUp already uses for its own countdown pills.
  Timer? _ticker;

  // Once a live class has this many minutes or fewer left, the card
  // switches from H-05's "Live now" look to H-09's "In progress" look
  // (green "IN SESSION" pill, "{M} min remaining", "Rejoin" button).
  static const int _kNearEndMinutes = 10;

  /// Mixpanel: Join now / Rejoin first appeared (once per class per day).
  static final Set<String> _seenJoin = {};
  void _trackJoinSeen(LiveClass l, bool rejoin) {
    final d = DateTime.now();
    final key = '${l.slotId}-${d.year}${d.month}${d.day}-$rejoin';
    if (!_seenJoin.add(key)) return;
    final trial = Get.isRegistered<HomeController>() && Get.find<HomeController>().isFreeTrialUser.value;
    AnalyticsHelper.classJoinButtonSeen(where: 'home', tier: trial ? 'free_trial' : 'paid', rejoin: rejoin);
  }
  /// Last 20 min: a woman who never joined sees "Join now · 8 min left".
  static const int _kLastCallMinutes = 20;

  bool get _isTrialUser =>
      Get.isRegistered<HomeController>() && Get.find<HomeController>().isFreeTrialUser.value;

  /// Free trial only: minutes left to join (join window after the class
  /// start), 0 when it's gone, null for paid women.
  int? _trialJoinMinutesLeft(dynamic l, DateTime anchor, DateTime now) {
    if (!_isTrialUser) return null;
    final start = parseSlotWallClock(l.start, anchor);
    if (start == null) return null;
    final window = Get.find<HomeController>().joinWindowMinutes.value;
    final closes = start.add(Duration(minutes: window));
    final left = closes.difference(now).inSeconds;
    return left <= 0 ? 0 : (left / 60).ceil();
  }

  // Countdown + Get ready start this many minutes before class; earlier
  // than that the card shows the calm "UP NEXT" state.
  static const int _kUpNextLeadMinutes = 15; // matches the 15-min reminder push

  // Her reminder picks (null = not loaded yet). Empty = she gets
  // reminders for every class, so no "Remind me" link is needed.
  Set<int>? _pickedIds;
  Map<String, dynamic> _ws = const {};
  bool _reminderAdded = false;

  // Last picks we loaded, kept while the app runs. Home rebuilds this card
  // when she comes back from another screen (Profile…); starting from the
  // last known picks stops the button flashing "Reminder on" → "Remind me"
  // while they reload (Oct 2026).
  static Set<int>? _lastIds;
  static Map<String, dynamic> _lastWs = const {};

  Future<void> _loadPicks() async {
    try {
      final p = await Get.find<ConsultationController>().loadProfile();
      final ws = p?.workoutSection ?? const {};
      final ids = ((ws['preferredSlotIds'] as List?) ?? const [])
          .map((e) => int.tryParse('$e'))
          .whereType<int>()
          .toSet();
      if (mounted) {
        _lastIds = ids;
        _lastWs = Map<String, dynamic>.from(ws);
        setState(() {
          _pickedIds = ids;
          _ws = Map<String, dynamic>.from(ws);
          _reminderAdded = false; // fresh truth from the server
        });
      }
    } catch (_) {}
  }

  bool _isReminded(LiveClass l) {
    if (_pickedIds == null) return true; // unknown yet: don't offer the link
    if (_reminderAdded) return true;
    return ClassReminderFlow.isReminded(
      ws: _ws,
      slotId: l.slotId,
      start: l.start,
      dayOffset: l.dayOffset,
    );
  }

  /// Green "Try free →" button for preview users (same look as Join).
  Widget _previewCta() {
    final accent = widget.theme.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onPreviewCta,
      // Never wider than 160 so it can't push the time box off screen
      // (small phones); a longer label shrinks to fit on one line.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: _pulse(Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: accent.withOpacity(0.28), blurRadius: 12)],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.previewCtaLabel ?? 'Try free →',
              maxLines: 1,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        )),
      ),
    );
  }

  /// Gentle "breathing" on the Try free button (1.0 ↔ 1.03, ~1.8 s).
  /// Off when the phone asks for less motion.
  Widget _pulse(Widget child) {
    if (Motion.calm(context)) return child;
    return child
        .animate(onPlay: (c) => c.repeat(reverse: true), delay: const Duration(milliseconds: 900))
        .scaleXY(begin: 1.0, end: 1.03, duration: const Duration(milliseconds: 900), curve: Curves.easeInOutSine);
  }

  Future<void> _remindMe(LiveClass l) async {
    final id = l.slotId;
    final start = l.start;
    if (id == null || start == null) return;
    // 0–1 picks: adds it. 2 picks: swap sheet or "just this once".
    final ok = await ClassReminderFlow.request(
      slotId: id,
      start: start,
      dayOffset: l.dayOffset,
    );
    if (!mounted) return;
    if (ok) setState(() => _reminderAdded = true);
    _loadPicks();
  }

  /// Calm "UP NEXT" card: class, when, trainer · duration · intensity, and
  /// a small "Remind me" link. No countdown or button yet.
  Widget _upNextCard(LiveClass l, DateTime start) {
    final now = AppClock.now();
    final isToday = start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    final title = ((l.classType ?? '').trim().isEmpty ? 'Live class' : l.classType!.trim());
    final sub = <String>[];
    final trainer = (l.trainerName ?? '').trim();
    if (trainer.isNotEmpty) sub.add(trainer);
    final end = parseSlotWallClock(l.end, start);
    final dur = l.durationMinutes ?? (end == null ? 0 : end.difference(start).inMinutes);
    if (dur > 0) sub.add('$dur min');
    if ((l.level ?? '').trim().isNotEmpty) sub.add('${l.level!.trim()} intensity');
    final reminded = _isReminded(l);
    // Default "every class" (she never picked): nudge to pick 2 times.
    final pickTimes = _pickedIds != null && !_reminderAdded &&
        ClassReminderFlow.isDefaultAll(_ws);

    // Title split like the countdown card: first word bold, rest muted.
    final sp = title.indexOf(' ');
    final first = sp > 0 ? title.substring(0, sp) : title;
    final rest = sp > 0 ? title.substring(sp + 1) : '';

    // "in 2h 15m" / "in 45 min"
    final diff = start.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final inText = h > 0 ? 'in ${h}h${m > 0 ? ' ${m}m' : ''}' : 'in ${diff.inMinutes} min';

    // Compact (Oct 2026): 3 short left-aligned rows, reminder chip on the
    // right, centred on them.
    //   ● UP NEXT · IN 5H 9M
    //   Yoga  8:00 AM                         [🔔 Remind me]
    //   Hira Trainer · 50 min · Beginner
    final level = (l.level ?? '').trim();
    final shortSub = <String>[
      if (trainer.isNotEmpty) trainer,
      if (dur > 0) '$dur min',
      if (level.isNotEmpty) level,
    ];
    final timeText = isToday
        ? DateFormat('h:mm a').format(start)
        : 'Tomorrow ${DateFormat('h:mm a').format(start)}';

    // Round bell: outline = tap to get a reminder; filled = reminder on;
    // sliders = pick your 2 class times.
    final Widget bell = widget.onPreviewCta != null
        ? _previewCta()
        : _pickedIds == null
            // Very first load: don't guess (it used to show "Reminder on").
            ? const SizedBox(width: 1)
            : Tooltip(
            message: pickTimes
                ? 'Pick 2 class times'
                : reminded
                    ? 'Reminder on'
                    : 'Remind me',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: pickTimes
                  ? () async {
                      await ClassReminderFlow.openTimePicker();
                      _loadPicks();
                    }
                  : reminded
                      ? null
                      : () => _remindMe(l),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: reminded && !pickTimes
                      ? widget.theme.accent.withOpacity(0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.theme.accent
                        .withOpacity(reminded && !pickTimes ? 0.0 : 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pickTimes
                          ? Icons.tune_rounded
                          : reminded
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                      size: 13,
                      color: widget.theme.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pickTimes
                          ? 'Pick 2 times'
                          : reminded
                              ? 'Reminder on'
                              : 'Remind me',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.theme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Pill: same shape as "STARTING IN 8 MIN", calm colours.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.theme.accent.withOpacity(0.16),
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 5,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.theme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'UP NEXT · ${inText.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: widget.theme.accent,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: first,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: Colors.white),
              ),
              if (rest.isNotEmpty)
                TextSpan(
                  text: ' $rest',
                  style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.55)),
                ),
              TextSpan(
                text: '   $timeText',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, letterSpacing: -0.2, height: 1.2),
          ),
          if (shortSub.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              shortSub.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
          ],
        ],
            ),
          ),
          const SizedBox(width: 12),
          bell,
        ],
      ),
    );
  }


  // How close to start (or already inside the window) before the card
  // moves on from "Confirmed" to "Get ready"/"trainer is setting up".
  static const int _kGetReadyLeadMinutes = 15;

  static const Color _readyGreen = Color(0xFF6DC55A);
  static const Color _liveRed = Color(0xFFE24B4A);
  static const Color _amber = Color(0xFFFAC775);

  @override
  void initState() {
    super.initState();
    // 1s so the "Starts in mm:ss" countdown ticks live.
    _pickedIds = _lastIds;
    _ws = _lastWs;
    _loadPicks();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cross-fade when the card moves between states (up next -> get
    // ready -> LIVE -> in session ...). Each state's card carries its own
    // key; within one state the card just updates in place (countdown,
    // elapsed minutes), so nothing replays. Reduce-motion: instant swap.
    final calm = Motion.calm(context);
    final duration = calm ? Duration.zero : const Duration(milliseconds: 300);
    return AnimatedSize(
      duration: duration,
      curve: Motion.ease,
      alignment: Alignment.topCenter,
      // No clipping: the Join button's glow paints past the card's edge.
      clipBehavior: Clip.none,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          clipBehavior: Clip.none,
          children: [...previous, if (current != null) current],
        ),
        child: _buildCard(context),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final l = widget.live;
    if (l == null) return const SizedBox.shrink(key: ValueKey('live_none'));

    // Anchor the slot's wall-clock start/end strings to today -- live
    // classes are always today's occurrence. If either fails to parse
    // (unexpected format from the backend), fall back to the old, simpler
    // "only show when explicitly In Progress" behavior rather than
    // crashing or guessing.
    final today = AppClock.now();
    final anchor = DateTime(today.year, today.month, today.day)
        .add(Duration(days: l.dayOffset));
    final start = parseSlotWallClock(l.start, anchor);
    final end = parseSlotWallClock(l.end, anchor);
    if (start == null || end == null) {
      if (l.status != 'In Progress') {
        return const SizedBox.shrink(key: ValueKey('live_none'));
      }
      return KeyedSubtree(key: const ValueKey('live_legacy'), child: _legacyCard(l));
    }

    final now = AppClock.now();
    // More than 15 min away (or tomorrow): calm "UP NEXT", no countdown.
    if (l.status != SlotStatus.cancelled &&
        l.status != SlotStatus.inProgress &&
        start.difference(now).inMinutes > _kUpNextLeadMinutes) {
      return KeyedSubtree(
        key: const ValueKey('live_upnext'),
        child: _upNextCard(l, start),
      );
    }
    final state = resolveSlotUIState(
      slot: SlotInput(
        status: l.status,
        start: start,
        end: end,
        trainerLink: l.trainerLink,
      ),
      now: now,
      user: UserAccessInput(
        isFrozen: widget.isFrozen,
        // Home doesn't currently thread plan-remaining-days into this
        // widget (only the freeze flag) -- treat as not-expired so
        // behavior matches the pre-port version, which never gated on
        // expiry here either. Freezing is still fully honored below.
        remainingDays: widget.isFrozen ? 0 : 999,
      ),
    );

    // Hide only once the class has genuinely concluded. The backend only
    // ever sends a slot as `live` while today's occurrence is still
    // upcoming or inside its window, so these three should be rare in
    // practice -- kept as a defensive fallback, not the normal path.
    if (state == SlotUIState.past ||
        state == SlotUIState.endedNotAttended ||
        state == SlotUIState.endedEarly) {
      return const SizedBox.shrink(key: ValueKey('live_none'));
    }

    final bool isCancelled = state == SlotUIState.cancelled;
    final bool isTrulyLive = state == SlotUIState.liveReady;
    final bool isBlocked = state == SlotUIState.liveBlocked;
    // True from `_kGetReadyLeadMinutes` before start all the way through
    // the rest of the class window -- once reached, it stays true, so
    // "Get ready" / "trainer is setting up" persists through any gap
    // between class time arriving and the trainer actually tapping
    // "In Progress", instead of the card going blank or reverting.
    final bool closeEnough =
        !now.isBefore(start.subtract(const Duration(minutes: _kGetReadyLeadMinutes)));

    final _Phase phase;
    if (isCancelled) {
      phase = _Phase.cancelled;
    } else if (isTrulyLive) {
      phase = _Phase.live;
    } else if (isBlocked) {
      phase = _Phase.blocked;
    } else if (!closeEnough) {
      phase = _Phase.confirmed;
    } else {
      // The join link now only arrives once the trainer taps Start (the
      // server hides it before), so "Get ready" no longer waits for it.
      phase = _Phase.getReady;
    }

    // Free trial: join window over and she never joined → don't keep
    // showing this class (the server moves her to the next one).
    if (phase == _Phase.live &&
        _trialJoinMinutesLeft(l, anchor, now) == 0 &&
        !(l.joinedToday || ClassJoinMemory.joinedToday(l.slotId))) {
      return const SizedBox.shrink(key: ValueKey('live_none'));
    }

    final presentation = presentationForState(
      state,
      minutesUntilStart: null,
      blockReason:
          widget.isFrozen ? SlotBlockReason.frozen : SlotBlockReason.expired,
    );

    // Real time math off the already-parsed start/end, not a backend
    // field -- always in sync with the 30s ticker above rather than
    // whatever the last dashboard fetch happened to compute.
    final int elapsedMinutes = max(0, now.difference(start).inMinutes);
    final int remainingMinutes = max(0, end.difference(now).inMinutes);
    final bool hasStarted = !now.isBefore(start);

    // Trainer ran past the scheduled end: not "near the end" (no
    // "0 min remaining" / Rejoin look), just a normal live class.
    final bool overrun = !end.isAfter(now);
    // Free trial, not joined yet: all timing on the card is about the
    // join window (first N min), not the class length.
    final int? trialJoinLeft = phase == _Phase.live &&
            !(l.joinedToday || ClassJoinMemory.joinedToday(l.slotId))
        ? _trialJoinMinutesLeft(l, anchor, now)
        : null;
    final isNearEnd = phase == _Phase.live &&
        trialJoinLeft == null &&
        !overrun &&
        remainingMinutes <= _kNearEndMinutes;


    // ── pill ─────────────────────────────────────────────────────────
    late final Color pillColor;
    late final String pillLabel;
    late final Color pillTextColor;
    late final bool showPillDot;
    switch (phase) {
      case _Phase.cancelled:
        pillColor = Colors.white24;
        pillLabel = 'CANCELLED';
        pillTextColor = Colors.white;
        showPillDot = false;
        break;
      case _Phase.confirmed:
        pillColor = _amber.withOpacity(0.18);
        pillLabel = 'STARTING IN ${minutesUntilStart(start, now) ?? 0} MIN';
        pillTextColor = _amber;
        showPillDot = true;
        break;
      case _Phase.live:
        if (isNearEnd) {
          pillColor = _readyGreen.withOpacity(0.2);
          pillLabel = 'IN SESSION';
          pillTextColor = _readyGreen;
        } else {
          pillColor = _liveRed;
          pillLabel = 'LIVE';
          pillTextColor = Colors.white;
        }
        showPillDot = true;
        break;
      case _Phase.blocked:
        pillColor = _liveRed;
        pillLabel = 'LIVE';
        pillTextColor = Colors.white;
        showPillDot = false;
        break;
      case _Phase.getReady:
      case _Phase.waitingForLink:
        if (hasStarted) {
          // Scheduled start time has technically arrived, but the
          // resolver says `state` is still liveNotReady -- the trainer
          // hasn't flipped the class to "In Progress" yet (or hasn't
          // posted the link). This used to show a red "LIVE" pill here,
          // which was wrong: LIVE is reserved for _Phase.live, i.e. the
          // real backend status, not wall-clock time. Reuse the same
          // amber "not live yet" treatment as the pre-start countdown,
          // just with copy that matches where we actually are (waiting
          // on the trainer, not waiting on the clock).
          pillColor = _amber.withOpacity(0.18);
          pillLabel = 'GETTING READY';
          pillTextColor = _amber;
        } else {
          final mins = minutesUntilStart(start, now) ?? 0;
          pillColor = _amber.withOpacity(0.18);
          pillLabel = 'STARTING IN $mins MIN';
          pillTextColor = _amber;
        }
        showPillDot = true;
        break;
    }

    // ── status text next to the pill ────────────────────────────────
    String statusText;
    switch (phase) {
      case _Phase.cancelled:
        statusText = '';
        break;
      case _Phase.confirmed:
        statusText = ''; // start time is in the box below
        break;
      case _Phase.live:
        if (trialJoinLeft != null) {
          final w = Get.find<HomeController>().joinWindowMinutes.value;
          statusText = 'Trial: join within $w min of start · ${max(1, trialJoinLeft)} min left';
        } else if (isNearEnd) {
          statusText = '$elapsedMinutes min elapsed';
        } else {
          final parts = <String>[];
          if (l.participantCount != null) {
            parts.add('${l.participantCount} women');
          }
          parts.add('$elapsedMinutes min elapsed');
          statusText = parts.join(' · ');
        }
        break;
      case _Phase.blocked:
        // The button's toast already names the real reason (frozen /
        // expired) on tap -- no need to editorialize here too.
        statusText = '';
        break;
      case _Phase.waitingForLink:
        statusText = hasStarted ? 'Trainer is setting up' : '';
        break;
      case _Phase.getReady:
        // Same "meaningful, not misleading" treatment as the pill above:
        // once class time has passed but the trainer hasn't started it,
        // say so instead of staying blank.
        statusText = hasStarted ? 'Trainer is setting up' : '';
        break;
    }

    // ── title ────────────────────────────────────────────────────────
    final title = (l.classType ?? '').trim().isEmpty ? 'Live class' : l.classType!.trim();
    final spaceIdx = title.indexOf(' ');
    final hasSuffix = spaceIdx > 0 && spaceIdx < title.length - 1;
    final firstWord = hasSuffix ? title.substring(0, spaceIdx) : title;
    final restWords = hasSuffix ? title.substring(spaceIdx + 1) : '';
    // H-09 renders the whole title as one solid-bold string, no split.
    final splitTitle = !isNearEnd;

    // ── subtitle ─────────────────────────────────────────────────────
    final subParts = <String>[];
    final trainer = (l.trainerName ?? '').trim();
    String? subtitleOverride;
    if (phase == _Phase.cancelled) {
      subtitleOverride = 'This class has been cancelled';
    } else if (phase == _Phase.live && isNearEnd) {
      subParts.add('$remainingMinutes min remaining');
      if (trainer.isNotEmpty) subParts.add(trainer);
    } else {
      if (trainer.isNotEmpty) subParts.add(trainer);
      final dur = l.durationMinutes ?? end.difference(start).inMinutes;
      if (dur > 0) subParts.add('$dur min');
      if ((l.level ?? '').trim().isNotEmpty) subParts.add('${l.level!.trim()} intensity');
    }
    final subtitle = subtitleOverride ?? subParts.join(' · ');

    // ── button (none for cancelled / confirmed -- nothing to do yet) ──
    // Every pre-start phase shows "Get ready"; it turns into "Join now"
    // once the trainer starts the class.
    final bool showButton = phase != _Phase.cancelled;
    final bool isPreview = widget.onPreviewCta != null;
    // Countdown info row (H-06's "Starts at {time}" box) -- only while
    // there's still real time left to count down, i.e. pre-start
    // get-ready/waiting states. Once class time itself has arrived this
    // would just be stale, so it's dropped.
    final bool showInfoRow = (phase == _Phase.confirmed ||
            phase == _Phase.getReady ||
            phase == _Phase.waitingForLink) &&
        !hasStarted;
    final Duration toStart = start.difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    final String countdown = toStart.inHours > 0
        ? '${toStart.inHours}:${two(toStart.inMinutes % 60)}:${two(toStart.inSeconds % 60)}'
        : '${two(toStart.inMinutes)}:${two(toStart.inSeconds % 60)}';

    return Padding(
      key: ValueKey('live_${phase.name}_$isNearEnd'),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showPillDot) ...[
                      // Red LIVE pill: the dot gently breathes.
                      if (phase == _Phase.live && !isNearEnd)
                        FhLiveDot(size: 5, color: pillTextColor)
                      else
                        SizedBox(
                          width: 5,
                          height: 5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: pillTextColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      pillLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: pillTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (statusText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(
                          (phase == _Phase.live) ? 0.22 : 0.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    splitTitle
                        ? Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: hasSuffix ? '$firstWord ' : firstWord,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                    height: 1.0,
                                  ),
                                ),
                                if (hasSuffix)
                                  TextSpan(
                                    text: restWords,
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white.withOpacity(0.5),
                                      letterSpacing: -0.3,
                                      height: 1.0,
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                              height: 1.0,
                            ),
                          ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Was 26% white: trainer / duration / intensity
                        // were nearly invisible on the dark card.
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showButton) ...[
                const SizedBox(width: 14),
                isPreview
                    ? _previewCta()
                    : _buildButton(presentation, l, phase, isNearEnd),
              ],
            ],
          ),
          if (showInfoRow) ...[
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(
                    'Starts at',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('h:mm a').format(start),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFAC775),
                    ),
                  ),
                  const Spacer(),
                  // Live timer where the mockup has "34 booked".
                  // Pre-start only (see showInfoRow), so it's always a
                  // countdown: label it "in mm:ss".
                  Text(
                    'in $countdown',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.45),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Button rendered off the phase computed in [build] plus the shared
  /// resolver's [SlotPresentation] for the two phases (live, blocked)
  /// where that presentation is accurate. "Get ready" / "waiting for
  /// link" aren't resolver-native states, so their label/toast/action are
  /// set directly here instead of pretending they came from
  /// [presentationForState].
  Widget _buildButton(
    SlotPresentation presentation,
    LiveClass l,
    _Phase phase,
    bool isNearEnd,
  ) {
    String label;
    Color? bg;
    Color textColor = Colors.white;
    Border? border;
    List<BoxShadow> shadow = const [];
    bool enabled = false;
    SlotButtonAction action = SlotButtonAction.none;
    String? toastMessage;

    // For the live button label.
    final now = AppClock.now();
    final anchor = DateTime(now.year, now.month, now.day).add(Duration(days: l.dayOffset));
    final end = parseSlotWallClock(l.end, anchor);
    final bool overrun = end == null || !end.isAfter(now);
    final int remainingMinutes = end == null ? 0 : max(0, end.difference(now).inMinutes);
    // "Rejoin" only when SHE already joined this class today (server flag,
    // or this phone remembers it). Never just because the class is ending.
    final bool joinedBefore = l.joinedToday || ClassJoinMemory.joinedToday(l.slotId);

    switch (phase) {
      case _Phase.confirmed:
      case _Phase.waitingForLink:
      case _Phase.getReady:
        // H-06 "Get ready": green ghost/outline button. Not tappable into
        // the class yet -- joining is still gated on the trainer's manual
        // "In Progress" flip -- so the tap just reassures the user.
        label = 'Get ready';
        bg = _readyGreen.withOpacity(0.15);
        textColor = _readyGreen;
        border = Border.all(color: _readyGreen.withOpacity(0.3));
        enabled = true;
        action = SlotButtonAction.showToast;
        toastMessage = 'Hang tight, the trainer is about to start. The button turns into Join now when the class begins.';
        break;
      case _Phase.blocked:
        // "Join" for copy parity with the live/getReady buttons --
        // presentation.buttonLabel is the resolver's generic "Join now".
        label = 'Join';
        bg = Colors.white24;
        action = presentation.action;
        toastMessage = presentation.toastMessage;
        break;
      case _Phase.live:
        _trackJoinSeen(l, joinedBefore);
        final trialLeft = _trialJoinMinutesLeft(l, anchor, now);
        if (joinedBefore) {
          label = 'Rejoin';
        } else if (trialLeft != null) {
          // Free trial: join only in the first N minutes after start —
          // show how long she has. (Paid women just see "Join now".)
          label = 'Join now · ${max(1, trialLeft)} min left';
        } else {
          label = 'Join now';
        }
        bg = widget.theme.accent;
        enabled = true;
        action = presentation.action;
        // Glow for "Join now"; "Rejoin" is calmer.
        if (!joinedBefore) {
          shadow = [
            BoxShadow(
                color: widget.theme.accent.withOpacity(0.33), blurRadius: 16),
          ];
        }
        break;
      case _Phase.cancelled:
        // Never reached -- build() skips rendering a button for this.
        label = '';
        break;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(action, toastMessage, l),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: BorderRadius.circular(16),
            boxShadow: shadow,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: isNearEnd ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    SlotButtonAction action,
    String? toastMessage,
    LiveClass l,
  ) async {
    switch (action) {
      case SlotButtonAction.joinClass:
        final link = l.trainerLink ?? '';
        final id = l.slotId;
        if (link.isEmpty || id == null) return;

        // Free-trial users: first 10 minutes only (app + server check),
        // same as the schedule screen. Used to be skipped on this card.
        if (Get.isRegistered<HomeController>() &&
            !await HelpingWidgets.trialJoinGate(
              homeController: Get.find<HomeController>(),
              slotId: id,
              start: l.start,
              className: l.type,
              trainerName: l.trainerName,
            )) {
          return;
        }

        await AnalyticsHelper.trackWorkoutJoinClicked(
          slotId: id.toString(),
          className: l.type,
          trainerName: l.trainerName,
          userTier: (Get.isRegistered<HomeController>() &&
                  Get.find<HomeController>().isFreeTrialUser.value)
              ? 'free_trial'
              : 'paid',
          linkType: link.contains('https') ? 'https_url' : 'zoom_native',
        );

        try {
          if (link.contains('https')) {
            if (Get.isRegistered<MotivationController>()) {
              await Get.find<MotivationController>().classPresenceJoin(
                slotId: id.toString(),
                className: l.type,
                trainerName: l.trainerName,
                scheduledStartTime: l.start,
              );
            }
            await launchUrl(Uri.parse(link));
          } else {
            await HelpingWidgets.startMeeting(
              link,
              id.toString(),
              className: l.type,
              trainerName: l.trainerName,
              scheduledStartTime: l.start,
            );
          }
        } catch (_) {
          HelpingWidgets.showError('Could not start the session. Please try again.');
        }
        break;
      case SlotButtonAction.showToast:
        if (toastMessage != null && toastMessage.isNotEmpty) {
          HelpingWidgets.showError(toastMessage);
        }
        break;
      case SlotButtonAction.none:
        break;
    }
  }

  /// Pre-port fallback: only used if the backend ever sends a live class
  /// whose start/end strings don't parse. Identical to the previous
  /// unconditional behavior (status must literally be "In Progress").
  Widget _legacyCard(LiveClass l) {
    final title = (l.classType ?? '').trim().isEmpty ? 'Live class' : l.classType!.trim();
    final spaceIdx = title.indexOf(' ');
    final hasSuffix = spaceIdx > 0 && spaceIdx < title.length - 1;
    final firstWord = hasSuffix ? title.substring(0, spaceIdx) : title;
    final restWords = hasSuffix ? title.substring(spaceIdx + 1) : '';
    final statusParts = <String>[];
    if (l.participantCount != null) statusParts.add('${l.participantCount} women');
    if (l.elapsedMinutes != null) statusParts.add('${l.elapsedMinutes} min elapsed');
    final statusText = statusParts.join(' · ');
    final subParts = <String>[];
    final trainer = (l.trainerName ?? '').trim();
    if (trainer.isNotEmpty) subParts.add(trainer);
    if (l.durationMinutes != null) subParts.add('${l.durationMinutes} min');
    if ((l.level ?? '').trim().isNotEmpty) subParts.add('${l.level!.trim()} intensity');
    final subtitle = subParts.join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: const BoxDecoration(
                  color: Color(0xFFE24B4A),
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    FhLiveDot(size: 5, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (statusText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.22)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: hasSuffix ? '$firstWord ' : firstWord,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                              height: 1.0,
                            ),
                          ),
                          if (hasSuffix)
                            TextSpan(
                              text: restWords,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w300,
                                color: Colors.white.withOpacity(0.5),
                                letterSpacing: -0.3,
                                height: 1.0,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.72)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.isFrozen
                    ? null
                    : () async {
                        final link = l.trainerLink;
                        final id = l.slotId;
                        if (link == null || link.isEmpty || id == null) return;
                        // Same gate as every Join (trial window / trial ended).
                        if (Get.isRegistered<HomeController>() &&
                            !await HelpingWidgets.trialJoinGate(
                              homeController: Get.find<HomeController>(),
                              slotId: id,
                              start: l.start,
                              className: l.type,
                              trainerName: l.trainerName,
                            )) {
                          return;
                        }
                        HelpingWidgets.startMeeting(link, id.toString());
                      },
                child: Opacity(
                  opacity: widget.isFrozen ? 0.45 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: widget.theme.accent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: widget.isFrozen
                          ? const []
                          : [
                              BoxShadow(
                                color: widget.theme.accent.withOpacity(0.33),
                                blurRadius: 16,
                              ),
                            ],
                    ),
                    child: Text(
                      widget.isFrozen ? 'Paused' : 'Join',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
