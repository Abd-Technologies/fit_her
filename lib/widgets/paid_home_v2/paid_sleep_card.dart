import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../data/models/home_dashboard/home_dashboard_model.dart';
import '../new_home/phase_theme.dart';
import 'dart:async';

import 'quick_amount_sheet.dart';

/// Sleep card: three quick-log presets (6h / 7h / 8h) + tap-card to open
/// the full slider modal for a custom value.
///
/// Mirrors PaidWaterCard's layout: header pinned top, action buttons pinned
/// bottom, Spacer in between — so both cards always match height inside an
/// IntrinsicHeight Row.
class PaidSleepCard extends StatefulWidget {
  final HomeDashboardModel dashboard;

  /// Inside the "Today's insights" box: lighter border, no shadow.
  final bool embedded;

  /// Opened from a tile in the box: keep the buttons open even after
  /// the goal is reached.
  final bool alwaysShowButtons;

  const PaidSleepCard({Key? key, required this.dashboard, this.embedded = false, this.alwaysShowButtons = false}) : super(key: key);

  @override
  State<PaidSleepCard> createState() => _PaidSleepCardState();
}

class _PaidSleepCardState extends State<PaidSleepCard> {
  final PaidHomeController _controller = Get.find<PaidHomeController>();

  /// After the goal the chips fold away; "Change ›" opens them again.
  bool _editing = false;
  Timer? _foldTimer;

  @override
  void dispose() {
    _foldTimer?.cancel();
    super.dispose();
  }

  void _openEdit() {
    _foldTimer?.cancel();
    setState(() => _editing = true);
    _foldTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _editing = false);
    });
  }

  Future<bool> _onQuickLog(double hours) async {
    if (_controller.isSavingSleep.value) return false;

    // Capture pre-log values to detect the goal-reached transition —
    // mirrors PaidWaterCard._onTap.
    final s = widget.dashboard.sleep;
    final prevHours = s?.hoursToday;
    final target = s?.targetHours;
    final wasUnderGoal =
        target != null && target > 0 && (prevHours == null || prevHours < target);

    final success = await _controller.logSleep(hours);
    if (!mounted) return success;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't save sleep"),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    if (_editing) {
      _foldTimer?.cancel();
      _foldTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _editing = false);
      });
    }

    if (wasUnderGoal) {
      final newHours = _controller.dashboard.value?.sleep?.hoursToday;
      if (newHours != null && newHours >= target) {
        showSleepGoalReachedDialog(context);
      }
    }
    return true;
  }

  /// The › (or a tap on the card): any time from 4h to 12h.
  void _openModal() {
    final theme = PhaseTheme.forPhaseString(widget.dashboard.cycle?.phase);
    QuickAmountSheet.show(
      context,
      QuickAmountSheet(
        title: 'How long did you sleep?',
        subtitle: 'Last night',
        presets: const [5, 6, 6.5, 7, 7.5, 8, 9],
        initial: widget.dashboard.sleep?.hoursToday ?? 7,
        min: 4,
        max: 12,
        step: 0.5,
        buttonLabel: 'Save',
        accent: theme.accent,
        format: (v) => '${_formatHours(v)}h',
        onSave: _onQuickLog,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = PhaseTheme.forPhaseString(widget.dashboard.cycle?.phase);
    final s = widget.dashboard.sleep;
    final hoursToday = s?.hoursToday;
    final targetHours = s?.targetHours;
    final hasTarget = targetHours != null && targetHours > 0;
    final hasHours = hoursToday != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Tap anywhere on the card (not on a button) opens the slider modal.
      onTap: _openModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.embedded ? const Color(0xFFE3EFE0) : const Color(0xFFD8EDD4), width: 1),
          boxShadow: widget.embedded ? null : [
            BoxShadow(
              color: const Color(0xFF163220).withOpacity(0.05),
              offset: const Offset(0, 2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: [
            // ── Header ──
            _buildHeaderRow(),
            const SizedBox(height: 8),
            // "7h last night" once logged, "Not logged yet" before.
            if (hasHours)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${_formatHours(hoursToday!)}h',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF163220),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'last night',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9AB09A),
                    ),
                  ),
                ],
              )
            else
              const Text(
                'Not logged yet',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF163220),
                ),
              ),
            if (hasTarget) ...[
              const SizedBox(height: 4),
              Text(
                'Goal ${targetHours}h',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 9.5,
                  color: Color(0xFF9AB09A),
                ),
              ),
            ],
            // One kind line once she has logged: green at or above her
            // goal, soft amber and matched to her cycle phase below it.
            if (hasHours && hasTarget) ...[
              const SizedBox(height: 5),
              _SleepNote(
                good: (hoursToday ?? 0) >= (targetHours ?? 0),
                text: (hoursToday ?? 0) >= (targetHours ?? 0)
                    ? 'Well rested 💚'
                    : _underGoalLine(widget.dashboard.cycle?.phase,
                        widget.dashboard.cycle?.cycleDay != null),
              ),
            ],
            const SizedBox(height: 8),
            // ── Spacer keeps buttons at the bottom ──
            const Spacer(),
            // ── Quick-log preset buttons, or once her goal is met one
            // small "✓ Logged · Change ›" line so the card gets shorter ──
            if (hasHours && hasTarget && hoursToday! >= targetHours! && !_editing && !widget.alwaysShowButtons)
              CardDoneLine(
                done: '✓ Logged',
                action: 'Change ›',
                color: theme.accent,
                onTap: _openEdit,
              )
            else
              _buildButtonRow(theme, hoursToday),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6D6DC5).withOpacity(0.14),
          ),
          child: const Text('🌙', style: TextStyle(fontSize: 10, height: 1.0)),
        ),
        const SizedBox(width: 5),
        const Text(
          'Sleep',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF163220),
          ),
        ),
        const Spacer(),
        // The whole card opens the slider modal for a custom value.
        Icon(Icons.chevron_right_rounded,
            size: 14, color: const Color(0xFF6D6DC5).withOpacity(0.55)),
      ],
    );
  }

  /// Short, kind line when she slept less than her goal.
  static String _underGoalLine(String? phase, bool hasCycle) {
    if (!hasCycle) return 'Try an early night 🌙';
    switch (parseCyclePhase(phase).name) {
      case 'menstrual':
        return 'Rest well tonight 🌙';
      case 'luteal':
        return 'Rest a little more 🌙';
      default:
        return 'Try an early night 🌙';
    }
  }

  static String _formatHours(double h) =>
      h == h.roundToDouble() ? h.toInt().toString() : h.toStringAsFixed(1);

  Widget _buildButtonRow(PhaseTheme theme, double? hoursToday) {
    return Obx(() {
      final saving = _controller.isSavingSleep.value;
      return Opacity(
        opacity: saving ? 0.6 : 1.0,
        child: IgnorePointer(
          ignoring: saving,
          child: Row(
            children: [
              Expanded(
                child: _SleepButton(
                  label: '6h',
                  accent: theme.accent,
                  selected: hoursToday == 6.0,
                  // GestureDetector absorbs tap so it doesn't bubble to the
                  // outer card GestureDetector (which opens the modal).
                  onTap: () => _onQuickLog(6.0),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _SleepButton(
                  label: '7h',
                  accent: theme.accent,
                  selected: hoursToday == 7.0,
                  onTap: () => _onQuickLog(7.0),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _SleepButton(
                  label: '8h',
                  accent: theme.accent,
                  selected: hoursToday == 8.0,
                  onTap: () => _onQuickLog(8.0),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

}

class _SleepNote extends StatelessWidget {
  final bool good;
  final String text;
  const _SleepNote({required this.good, required this.text});

  /// One line, same style as the water card's "Goal reached!" line.
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: good ? const Color(0xFF6DC55A) : const Color(0xFFC8893A),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick-log button — same visual spec as PaidWaterCard._ActionButton
// ─────────────────────────────────────────────────────────────────────────────

class _SleepButton extends StatelessWidget {
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _SleepButton({
    required this.label,
    required this.accent,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // absorb the tap so it doesn't open the modal.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // Matches the two line water buttons next to it.
        height: 34,
        alignment: Alignment.center,
        // A touch more fill than the old near-transparent outline (0.08)
        // so these read as tappable chips — mirrors PaidWaterCard's
        // _ActionButton treatment.
        // The logged preset fills in solid so she can see what she saved.
        decoration: BoxDecoration(
          color: selected ? accent : accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? accent : accent.withOpacity(0.45), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : accent,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Goal-reached celebration dialog — sleep counterpart to PaidWaterCard's
// _showGoalReachedDialog/_GoalReachedDialog. Public (not prefixed with _)
// so SleepLogModal can also trigger it when a save via the slider crosses
// the same under-goal -> goal-reached threshold.
// ─────────────────────────────────────────────────────────────────────────────

void showSleepGoalReachedDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 380),
    transitionBuilder: (_, anim, __, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (_, __, ___) => const _SleepGoalReachedDialog(),
  );
}

class _SleepGoalReachedDialog extends StatefulWidget {
  const _SleepGoalReachedDialog();

  @override
  State<_SleepGoalReachedDialog> createState() =>
      _SleepGoalReachedDialogState();
}

class _SleepGoalReachedDialogState extends State<_SleepGoalReachedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bounceAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );
    _bounceCtrl.forward();
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F2FB), Color(0xFFE0DAF5)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D6DC5).withOpacity(0.18),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _bounceAnim,
              child: const Text(
                '🌙',
                style: TextStyle(fontSize: 56, height: 1),
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✨', style: TextStyle(fontSize: 14)),
                SizedBox(width: 6),
                Text('✨', style: TextStyle(fontSize: 18)),
                SizedBox(width: 6),
                Text('✨', style: TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Sleep Goal\nReached!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF201A3A),
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Well rested! You've hit your sleep\ngoal for today. Your body thanks you! 💤",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF4A4A7A),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D6DC5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Sweet dreams! 🌿',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
