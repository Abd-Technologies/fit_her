import '../../helper/analytics_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../../UI/free_trail/trial_onboarding_screen.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_clock.dart';

/// "Remind me" for one class — one rule everywhere:
///
///  • never picked (default = every class) → opens "pick 2 times"
///    (fewer notifications) — we nudge her from default to picked;
///  • chose "All classes" herself in Settings → nothing to do;
///  • 0–1 picked times → this class's time becomes a pick (max 2);
///  • 2 picked times → small sheet: swap one of them, or
///    "Just remind me this once" (today's / tomorrow's class only).
///
/// Saved in PreConsultationProfile.workoutSection:
///   preferredTimes   — her 2 times ("08:00 PM", her time zone)
///   preferredSlotIds — class ids at those times (kept in sync)
///   oneTimeReminders — [{slotId, date: "YYYY-MM-DD" (PKT)}], any number a
///                      day; only that day's date counts (resets next day)
class ClassReminderFlow {
  ClassReminderFlow._();

  static const int maxTimes = 2;

  static String norm(String t) =>
      t.trim().toUpperCase().replaceFirst(RegExp(r'^0'), '');

  /// PKT calendar date of the class (classes run on PKT days).
  static String pktDate(int dayOffset) {
    final pkt = AppClock.now().toUtc().add(const Duration(hours: 5));
    return DateFormat('yyyy-MM-dd')
        .format(DateTime(pkt.year, pkt.month, pkt.day + dayOffset));
  }

  /// Never picked times AND never chose "All classes" herself: she's on
  /// the default (every class). Home shows "Pick 2 times" for her.
  static bool isDefaultAll(Map<String, dynamic> ws) =>
      _ids(ws).isEmpty && _times(ws).isEmpty && ws['reminderMode'] != 'all';

  /// The same "Tell us when you're free" picker used in setup.
  /// Returns true when she saved her times.
  static Future<bool> openTimePicker() async {
    final done = await Get.to<bool>(
      () => const TrialOnboardingScreen(
        setupMode: true,
        includeClasses: true,
        timesOnly: true,
        canSkip: true,
      ),
      fullscreenDialog: true,
    );
    if (done == true && Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().loadTrialClasses();
    }
    return done == true;
  }

  /// True when this class already reminds her (pick or one-time).
  static bool isReminded({
    required Map<String, dynamic> ws,
    required int? slotId,
    required String? start,
    int dayOffset = 0,
  }) {
    final ids = _ids(ws);
    final times = _times(ws);
    if (ids.isEmpty && times.isEmpty) return true; // all classes
    if (slotId != null && ids.contains(slotId)) return true;
    if (start != null && times.map(norm).contains(norm(start))) return true;
    final date = pktDate(dayOffset);
    return _once(ws).any((r) => r['slotId'] == slotId && r['date'] == date);
  }

  /// Runs the flow. Returns true when this class now has a reminder.
  static Future<bool> request({
    required int slotId,
    required String start,
    int dayOffset = 0,
  }) async {
    final consult = Get.find<ConsultationController>();
    final profile = await consult.loadProfile();
    if (profile == null) {
      _failToast();
      return false;
    }
    final ws = Map<String, dynamic>.from(profile.workoutSection ?? const {});
    if (isDefaultAll(ws)) return openTimePicker();
    if (isReminded(ws: ws, slotId: slotId, start: start, dayOffset: dayOffset)) {
      showReminderToast('Reminder on', 'You already get a reminder for this class.');
      return true;
    }

    final classes = await _classes();
    var times = _times(ws);
    // Old picks saved only as ids: turn them into times first.
    if (times.isEmpty && _ids(ws).isNotEmpty) {
      final ids = _ids(ws);
      times = classes
          .where((c) => ids.contains(c['slotId']))
          .map((c) => '${c['startLocal']}')
          .fold<List<String>>([], (l, t) {
        if (!l.map(norm).contains(norm(t))) l.add(t);
        return l;
      });
    }

    if (times.length < maxTimes) {
      final ok = await _save(consult, ws, classes, [...times, start], slotId);
      if (ok) {
        AnalyticsHelper.classReminderSet('always');
        showReminderToast('Added to your reminders',
            "We'll remind you 15 min before the ${norm(start)} class.");
      } else {
        _failToast();
      }
      return ok;
    }

    // Sheet stays open (with a spinner on her choice) until the server
    // answers; it closes only after it's saved, then the toast shows.
    final choice = await Get.bottomSheet<_Choice>(
      _SwapSheet(
        times: times,
        newTime: start,
        onPick: (c) async {
          if (c.once) {
            // Nov 2026: several "just this once" classes a day are fine.
            // Keep today's and tomorrow's (drop past days: they reset the
            // next day), skip a duplicate of this same class + day.
            final date = pktDate(dayOffset);
            final list = _once(ws)
                .where((r) => '${r['date']}'.compareTo(pktDate(0)) >= 0)
                .where((r) => !(r['slotId'] == slotId && r['date'] == date))
                .toList()
              ..add({'slotId': slotId, 'date': date});
            ws['oneTimeReminders'] = list;
            return consult.patchProfile({'workoutSection': ws});
          }
          final kept = [...times]..removeAt(c.replaceIndex!);
          return _save(consult, ws, classes, [...kept, start], slotId);
        },
      ),
      isScrollControlled: true,
    );
    if (choice == null) return false;
    AnalyticsHelper.classReminderSet(choice.once ? 'once' : 'swap');
    if (choice.once) {
      showReminderToast('Reminder set',
          "We'll remind you once, 15 min before the ${norm(start)} class.");
    } else {
      showReminderToast('Reminder times updated',
          'Every day: ${norm(times[choice.replaceIndex!])} → ${norm(start)}');
    }
    return true;
  }

  static Future<bool> _save(
    ConsultationController consult,
    Map<String, dynamic> ws,
    List<Map<String, dynamic>> classes,
    List<String> times,
    int slotId,
  ) async {
    final want = times.map(norm).toSet();
    final ids = <int>{
      if (classes.isEmpty) ..._ids(ws), // no class list: keep old ids
      ...classes
          .where((c) => want.contains(norm('${c['startLocal']}')))
          .map((c) => c['slotId'])
          .whereType<int>(),
      slotId,
    };
    ws['preferredTimes'] = times;
    ws['preferredSlotIds'] = ids.toList();
    final ok = await consult.patchProfile({'workoutSection': ws});
    if (ok && Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().loadTrialClasses();
    }
    return ok;
  }

  static void _failToast() => showReminderToast(
      "Couldn't set the reminder", 'Please check your internet and try again.',
      error: true);

  /// Reminder confirmation (Oct 2026 design): white card, green check,
  /// bold title + one line, slides up from the bottom for 3 s.
  static void showReminderToast(String title, String sub,
      {bool error = false, IconData icon = Icons.notifications_active_rounded}) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    final accent = error ? const Color(0xFFC2412D) : const Color(0xFF4C6A4B);
    final tint = error ? const Color(0xFFFCEBE7) : const Color(0xFFEEF7E6);
    Get.showSnackbar(GetSnackBar(
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 280),
      messageText: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(error ? Icons.error_outline_rounded : icon,
                color: accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2A1E))),
              const SizedBox(height: 2),
              Text(sub,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, height: 1.35, color: Color(0xFF66705F))),
            ]),
          ),
          if (!error) Icon(Icons.check_circle_rounded, color: accent, size: 20),
        ]),
      ),
    ));
  }

  static Future<List<Map<String, dynamic>>> _classes() async {
    if (!Get.isRegistered<HomeController>()) return const [];
    final home = Get.find<HomeController>();
    if (home.trialClassData.value == null) await home.loadTrialClasses();
    return home.trialClasses.where((c) => c['slotId'] is int).toList();
  }

  static Set<int> _ids(Map<String, dynamic> ws) =>
      ((ws['preferredSlotIds'] as List?) ?? const [])
          .map((e) => int.tryParse('$e'))
          .whereType<int>()
          .toSet();

  static List<String> _times(Map<String, dynamic> ws) =>
      ((ws['preferredTimes'] as List?) ?? const [])
          .map((e) => '$e')
          .where((e) => e.trim().isNotEmpty)
          .toList();

  static List<Map<String, dynamic>> _once(Map<String, dynamic> ws) =>
      ((ws['oneTimeReminders'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => <String, dynamic>{
                'slotId': int.tryParse('${e['slotId']}'),
                'date': '${e['date']}',
              })
          .toList();
}

class _Choice {
  final int? replaceIndex;
  final bool once;
  const _Choice.replace(int i) : replaceIndex = i, once = false;
  const _Choice.once() : replaceIndex = null, once = true;
}

class _SwapSheet extends StatefulWidget {
  final List<String> times;
  final String newTime;
  final Future<bool> Function(_Choice) onPick;
  const _SwapSheet({required this.times, required this.newTime, required this.onPick});

  @override
  State<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<_SwapSheet> {
  int? _busy; // index of the tapped option (times.length = "once")
  bool _failed = false;

  static String _pretty(String t) => ClassReminderFlow.norm(t);

  Future<void> _pick(int index, _Choice c) async {
    if (_busy != null) return;
    setState(() {
      _busy = index;
      _failed = false;
    });
    final ok = await widget.onPick(c);
    if (!mounted) return;
    if (ok) {
      Get.back(result: c); // close only once it's saved
    } else {
      setState(() {
        _busy = null;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = AppColors.primaryDeep;
    final times = widget.times;
    final newTime = widget.newTime;
    return PopScope(
      canPop: _busy == null,
      child: Container(
      padding: EdgeInsets.fromLTRB(
          22, 14, 22, 18 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'You already have 2 class reminders',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2A1E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Swap one for the ${_pretty(newTime)} class, or get a reminder just this once.',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF66705F),
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < times.length; i++) ...[
            _option(
              icon: Icons.swap_horiz_rounded,
              title: 'Replace ${_pretty(times[i])}',
              sub: 'Every day: ${_pretty(times[i])} → ${_pretty(newTime)}',
              onTap: () => _pick(i, _Choice.replace(i)),
              color: green,
              busy: _busy == i,
              dim: _busy != null && _busy != i,
            ),
            const SizedBox(height: 10),
          ],
          _option(
            icon: Icons.notifications_active_outlined,
            title: 'Just remind me this once',
            sub: 'Your 2 reminder times stay the same',
            onTap: () => _pick(times.length, const _Choice.once()),
            color: green,
            filled: true,
            busy: _busy == times.length,
            dim: _busy != null && _busy != times.length,
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            const Text(
              "Couldn't save. Please try again.",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Color(0xFFC2412D)),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy != null ? null : () => Get.back(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Color(0xFF66705F),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String sub,
    required VoidCallback onTap,
    required Color color,
    bool filled = false,
    bool busy = false,
    bool dim = false,
  }) {
    return Opacity(
      opacity: dim ? 0.45 : 1,
      child: Material(
      color: filled ? const Color(0xFFEAF6E2) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: (busy || dim) ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: filled ? Colors.transparent : const Color(0xFFE3E8DF)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2A1E),
                        )),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF66705F),
                        )),
                  ],
                ),
              ),
              busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
                    )
                  : const Icon(Icons.chevron_right_rounded, color: Color(0xFFB5BDB0)),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
