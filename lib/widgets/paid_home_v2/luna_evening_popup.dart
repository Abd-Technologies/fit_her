import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../helper/popup_manager.dart';
import '../../screens/paid_home_screen_v2.dart';

/// Luna's evening pop-up (Nov 2026), the in-app side of the 8 PM push.
///
/// ESSENTIAL in the pop-up manager: it does not wait for a turn, the
/// 30 minute gap or the 2 a day limit. It only waits until Home is free
/// (nothing else on screen), then shows.
///   * Tap on the push: shows right away (runNow).
///   * Push arrives while the app is open, or she opens the app after
///     8 PM without tapping: shows once Home is free.
/// Once a day. "Log now" scrolls Home to the "Today's insights" box.
class LunaEveningPopup {
  LunaEveningPopup._();

  static const int fromHour = 20; // 8 PM her phone time
  static const String _kShownDay = 'luna_evening_shown_day';
  static bool _asking = false;

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  static Future<bool> _shownToday() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kShownDay) == _today();
  }

  static Future<void> _markShown() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kShownDay, _today());
  }

  /// How many of feeling / water / sleep are still to log today.
  static int _left() {
    try {
      final d = Get.find<PaidHomeController>().dashboard.value;
      if (d == null) return 3;
      var left = 0;
      if (d.todayCheckin?.moodLevel == null) left++;
      if ((d.hydration?.consumedMl ?? 0) <= 0) left++;
      if (d.sleep?.hoursToday == null) left++;
      return left;
    } catch (_) {
      return 3;
    }
  }

  /// From Home (app open / back from background) and from a push that
  /// arrived while the app is open. After 8 PM only, once a day.
  static Future<void> maybeShow({bool fromPush = false}) async {
    if (_asking) return;
    if (!fromPush && DateTime.now().hour < fromHour) return;
    if (await _shownToday()) return;
    _asking = true;
    try {
      await PopupManager.runEssential('luna_evening', _show);
    } finally {
      _asking = false;
    }
  }

  /// She tapped the push: show now.
  static Future<void> openFromPush() async {
    await PopupManager.runNow('luna_evening', _show);
  }

  static Future<void> _show() async {
    await _markShown();
    final left = _left();
    await Get.bottomSheet<void>(
      _LunaSheet(left: left),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _LunaSheet extends StatelessWidget {
  const _LunaSheet({required this.left});
  final int left;

  static const _ink = Color(0xFF163220);
  static const _soft = Color(0xFF6F8B7A);
  static const _deep = Color(0xFF3E8E4A);

  @override
  Widget build(BuildContext context) {
    final done = left == 0;
    final title = done ? 'Nice work today 🌙' : 'How was your day? 🌙';
    final body = done
        ? "You logged your feeling, water and sleep today. Come see today's tip."
        : left == 3
            ? 'Log your feeling, water and sleep. It takes 10 seconds and helps me learn your body.'
            : '$left of 3 left for today. Finish your check-in so my tips fit you better.';
    return Container(
      padding: EdgeInsets.fromLTRB(22, 10, 22, 18 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(color: const Color(0xFFDCE2D8), borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(height: 18),
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Color(0xFF7ACB63), _deep]),
          ),
          child: const Icon(Icons.nightlight_round, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 10),
        const Text('Luna',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: _soft)),
        const SizedBox(height: 4),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 8),
        Text(body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.5, color: _soft)),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _deep,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Get.back();
              PaidHomeScreenV2.requestInsights();
            },
            child: Text(done ? "See today's tip" : 'Log now',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Later', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _soft)),
        ),
      ]),
    );
  }
}
