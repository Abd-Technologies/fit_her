import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../UI/plans_module/all_plans.dart';
import '../data/controllers/consultation_controller/consultation_controller.dart';
import '../data/controllers/home_controller/home_controller.dart';
import '../data/models/get_user_plan/get_workout_user_plan_details.dart';
import '../utils/app_clock.dart';
import '../utils/slot_ui_state.dart';
import 'app_bar_widget.dart';
import 'class_reminder/class_reminder_flow.dart';

/// Class details sheet (Oct 2026 redesign). Opens for any class tap.
///
/// Real facts only: length from the class's own start/end (the old sheet
/// showed a fixed "50 Min" and "254 Calories" for every class). One action
/// area that always says the next thing she can do: remind, wait, join,
/// or nothing (cancelled / ended). The Join rules still come from
/// [presentationForState] and [HelpingWidgets.dispatchSlotAction].
class ClassDetailsSheet extends StatefulWidget {
  final Slot slot;
  final SlotUIState state;
  final SlotPresentation presentation;
  final DateTime anchor;
  final HomeController homeController;

  const ClassDetailsSheet({
    super.key,
    required this.slot,
    required this.state,
    required this.presentation,
    required this.anchor,
    required this.homeController,
  });

  @override
  State<ClassDetailsSheet> createState() => _ClassDetailsSheetState();
}

const _ink = Color(0xFF163220);
const _sub = Color(0xFF5F7A5D);
const _muted = Color(0xFF8A9A88);
const _green = Color(0xFF6DC55A);
const _deep = Color(0xFF3E8E36);
const _wash = Color(0xFFEAF6E4);
const _line = Color(0xFFDCE8D6);
const _amber = Color(0xFFB7791F);
const _red = Color(0xFFC24A4A);

TextStyle _t(double s, {FontWeight w = FontWeight.w400, Color c = _ink, double? h}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: s, fontWeight: w, color: c, height: h);

class _ClassDetailsSheetState extends State<ClassDetailsSheet> {
  Map<String, dynamic>? _ws; // her workoutSection (reminder picks)
  bool _wsLoaded = false;
  bool _justAdded = false;

  Slot get s => widget.slot;

  int get _dayOffset {
    final now = AppClock.now();
    final a = DateTime(widget.anchor.year, widget.anchor.month, widget.anchor.day);
    return a.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  bool get _remindable =>
      widget.state == SlotUIState.upcomingFar || widget.state == SlotUIState.upcomingSoon;

  @override
  void initState() {
    super.initState();
    if (_remindable) _loadPicks();
  }

  Future<void> _loadPicks() async {
    try {
      final p = await Get.find<ConsultationController>().loadProfile();
      _ws = Map<String, dynamic>.from(p?.workoutSection ?? const {});
    } catch (_) {}
    if (mounted) setState(() => _wsLoaded = true);
  }

  // ── facts ──
  static String _clean(String t) => t.trim().replaceFirst(RegExp(r'^0'), '');

  static int? _minutes(String t) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])?$').firstMatch(t.trim());
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ap = m.group(3)?.toUpperCase();
    if (ap == 'PM' && h != 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
    return h * 60 + min;
  }

  int? get _length {
    final a = _minutes(s.start), b = _minutes(s.end);
    if (a == null || b == null) return null;
    final d = b >= a ? b - a : b + 24 * 60 - a;
    return d > 0 ? d : null;
  }

  String get _dayWord {
    switch (_dayOffset) {
      case 0:
        return 'Today';
      case 1:
        return 'Tomorrow';
      default:
        const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        return days[widget.anchor.weekday - 1];
    }
  }

  String get _title {
    final t = (s.type ?? '').trim();
    if (t.isEmpty) return 'Live class';
    return t[0].toUpperCase() + t.substring(1);
  }

  (String, Color) get _eyebrow {
    switch (widget.state) {
      case SlotUIState.cancelled:
        return ('CANCELLED', _red);
      // Oct 2026: no "you missed it" on past classes, it reads like blame.
      case SlotUIState.past:
      case SlotUIState.endedEarly:
      case SlotUIState.endedNotAttended:
        return ('ENDED', _muted);
      case SlotUIState.liveReady:
      case SlotUIState.liveNotReady:
      case SlotUIState.liveBlocked:
        return ('● LIVE NOW', _deep);
      case SlotUIState.upcomingSoon:
        return ('● ${(widget.presentation.buttonLabel ?? 'Starts soon').toUpperCase()}', _amber);
      case SlotUIState.upcomingFar:
        return (_dayOffset == 0 ? 'LATER TODAY' : _dayWord.toUpperCase(), _deep);
    }
  }

  // ── action area ──
  Widget _button(String label,
      {VoidCallback? onTap, bool filled = true, IconData? icon, Color color = _green}) {
    final on = onTap != null;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
              label: Text(label, style: _t(15, w: FontWeight.w600, c: on ? Colors.white : _muted)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                disabledBackgroundColor: const Color(0xFFEEF2EC),
                foregroundColor: Colors.white,
                disabledForegroundColor: _muted,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20, color: _deep),
              label: Text(label, style: _t(15, w: FontWeight.w600, c: _deep)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _green, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, textAlign: TextAlign.center, style: _t(11.5, c: _muted, h: 1.4)),
      );

  Future<void> _join() async {
    await HelpingWidgets.dispatchSlotAction(
      context: context,
      homeController: widget.homeController,
      presentation: widget.presentation,
      slot: s,
      anchorDate: widget.anchor,
    );
  }

  Widget _reminderArea({required bool soon}) {
    if (!_wsLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _green)),
        ),
      );
    }
    final ws = _ws ?? const <String, dynamic>{};
    final all = ClassReminderFlow.isDefaultAll(ws);
    final on = _justAdded ||
        ClassReminderFlow.isReminded(ws: ws, slotId: s.id, start: s.start, dayOffset: _dayOffset);

    if (soon) {
      // Starting within 20 min: the wait button, and her reminder status.
      return Column(children: [
        _button(widget.presentation.buttonLabel ?? 'Starts soon', onTap: null, icon: Icons.schedule_rounded),
        _hint(on ? '✓ Reminder on · Join opens when your trainer starts' : 'Join opens when your trainer starts'),
      ]);
    }
    if (on) {
      return Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: _wash, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.notifications_active_rounded, color: _deep, size: 20),
            const SizedBox(width: 8),
            Text('Reminder on', style: _t(15, w: FontWeight.w600, c: _deep)),
          ]),
        ),
        _hint(all && !_justAdded
            ? "You're reminded of every class, 15 min before"
            : "We'll remind you 15 min before"),
        TextButton(
          onPressed: () async {
            await ClassReminderFlow.openTimePicker();
            _loadPicks();
          },
          child: Text('Change my class times', style: _t(12.5, w: FontWeight.w600, c: _deep)),
        ),
      ]);
    }
    return Column(children: [
      _button('Remind me', filled: false, icon: Icons.notifications_none_rounded, onTap: () async {
        final ok = await ClassReminderFlow.request(slotId: s.id, start: s.start, dayOffset: _dayOffset);
        if (!mounted) return;
        if (ok) setState(() => _justAdded = true);
        _loadPicks();
      }),
      _hint("We'll send a push 15 min before it starts"),
    ]);
  }

  Widget _actionArea() {
    final p = widget.presentation;
    switch (widget.state) {
      case SlotUIState.liveReady:
        return Column(children: [
          _button('Join now', onTap: _join, icon: Icons.videocam_rounded),
          _hint('Opens the class'),
        ]);
      case SlotUIState.liveNotReady:
        return Column(children: [
          _button('Join opens in a moment', onTap: null, icon: Icons.hourglass_top_rounded),
          _hint('Your trainer is getting ready…'),
        ]);
      case SlotUIState.liveBlocked:
        final msg = p.toastMessage ?? '';
        final renew = msg.toLowerCase().contains('renew');
        return Column(children: [
          if (renew)
            _button('Renew my plan', onTap: () {
              Get.back<void>();
              Get.to<void>(() => OurPlansScreen());
            }, icon: Icons.refresh_rounded)
          else
            _button('Join now', onTap: null, icon: Icons.videocam_rounded),
          _hint(renew
              ? 'Your plan has ended. Renew to join live classes.'
              : 'Your plan is paused. Unfreeze it from Home to join.'),
        ]);
      case SlotUIState.upcomingSoon:
        return _reminderArea(soon: true);
      case SlotUIState.upcomingFar:
        return _reminderArea(soon: false);
      case SlotUIState.cancelled:
        return _note('This class was cancelled', 'Pick another class from the schedule.');
      case SlotUIState.endedNotAttended:
      case SlotUIState.past:
      case SlotUIState.endedEarly:
        return _note('This class has ended', 'Pick your next class from the schedule.');
    }
  }

  Widget _note(String title, String sub) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(color: const Color(0xFFF6F8F5), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(title, textAlign: TextAlign.center, style: _t(14, w: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub, textAlign: TextAlign.center, style: _t(11.5, c: _muted)),
        ]),
      );

  Widget _chip(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F9F4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          child: Column(children: [
            // Shrinks long values ("Moderate-high") instead of cutting them.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, maxLines: 1, style: _t(14, w: FontWeight.w700)),
            ),
            Text(label, style: _t(10.5, c: _muted)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final (eyebrow, eyebrowColor) = _eyebrow;
    final len = _length;
    final trainer = (s.trainerName ?? '').trim();
    final about = (s.description ?? '').trim();
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFD5DED1), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            Text(eyebrow, style: _t(10.5, w: FontWeight.w700, c: eyebrowColor).copyWith(letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(_title, style: _t(21, w: FontWeight.w800, h: 1.2)),
            const SizedBox(height: 2),
            Text('$_dayWord · ${_clean(s.start)} – ${_clean(s.end)}', style: _t(12.5, c: _sub)),
            const SizedBox(height: 14),
            Row(children: [
              _chip(len != null ? '$len min' : '—', 'Length'),
              const SizedBox(width: 8),
              _chip((s.level ?? '').trim().isNotEmpty ? s.level!.trim() : '—', 'Intensity'),
              const SizedBox(width: 8),
              _chip('Live', 'Women only'),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: _wash, shape: BoxShape.circle),
                  child: Text(trainer.isEmpty ? '💪' : trainer[0].toUpperCase(),
                      style: _t(14, w: FontWeight.w700, c: _deep)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(trainer.isEmpty ? 'Fit Her trainer' : trainer, style: _t(13, w: FontWeight.w600)),
                    Text('Your trainer', style: _t(11, c: _muted)),
                  ]),
                ),
              ]),
            ),
            if (about.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('About this class', style: _t(12.5, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(about, maxLines: 5, overflow: TextOverflow.ellipsis, style: _t(12, c: _sub, h: 1.5)),
            ],
            const SizedBox(height: 18),
            _actionArea(),
          ],
        ),
      ),
    );
  }
}
