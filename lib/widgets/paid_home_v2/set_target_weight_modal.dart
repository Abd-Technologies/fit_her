import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../data/models/home_dashboard/home_dashboard_model.dart';
import '../new_home/phase_theme.dart';

/// Slider-only bottom sheet for setting/editing the user's goal weight.
/// Range: 40.0..150.0 kg in 0.5 kg steps. Pattern mirrors LogWeightModal.
/// Seeds from current goal → current weight → 60 kg (last fallback).
class SetTargetWeightModal extends StatefulWidget {
  final HomeDashboardModel dashboard;

  const SetTargetWeightModal({Key? key, required this.dashboard})
      : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required HomeDashboardModel dashboard,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SetTargetWeightModal(dashboard: dashboard),
    );
  }

  @override
  State<SetTargetWeightModal> createState() => _SetTargetWeightModalState();
}

class _SetTargetWeightModalState extends State<SetTargetWeightModal> {
  static const double _minKg = 40.0;
  static const double _maxKg = 150.0;
  static const int _divisions = 220;
  static const double _defaultKg = 60.0;

  late double _selectedKg;

  // Whether we need to ask "lose or gain" at all. The signup mainGoal
  // already answers this when it's specifically 'Lose weight' — asking
  // again there would be redundant. For every other goal (Build
  // strength & tone / Improve fitness / Reduce stress / no goal set),
  // weight direction isn't implied by anything else the user has told
  // us, so we ask here, once, and remember the answer.
  late final bool _needsDirectionPicker;
  // 'lose' | 'gain' — always resolved to a concrete value before save,
  // even when the picker isn't shown, so the backend always receives a
  // definite direction rather than leaving it ambiguous.
  late String _direction;

  @override
  void initState() {
    super.initState();
    final goal = widget.dashboard.goal;
    // Seed priority: existing target → current weight → 60 kg fallback.
    final seed = goal?.targetWeightKg ?? goal?.currentWeightKg ?? _defaultKg;
    if (seed < _minKg || seed > _maxKg) {
      debugPrint('[SetTargetWeightModal] Clamping out-of-range seed: $seed');
    }
    _selectedKg = seed.clamp(_minKg, _maxKg);

    final mainGoal = widget.dashboard.user?.mainGoal;
    _needsDirectionPicker = mainGoal != 'Lose weight' && mainGoal != 'Gain weight';
    _direction = _needsDirectionPicker
        ? (goal?.weightGoalDirection ?? 'lose')
        : (mainGoal == 'Gain weight' ? 'gain' : 'lose');
  }

  Future<void> _onSave() async {
    // A target the wrong way for her goal is refused (server checks too).
    final now = widget.dashboard.goal?.currentWeightKg;
    if (now != null && now > 0) {
      String? msg;
      if (_direction == 'lose' && _selectedKg >= now) {
        msg = 'To lose weight, pick a target below your current weight (${now.toStringAsFixed(1)} kg).';
      } else if (_direction == 'gain' && _selectedKg <= now) {
        msg = 'To gain weight, pick a target above your current weight (${now.toStringAsFixed(1)} kg).';
      }
      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
        );
        return;
      }
    }
    final controller = Get.find<PaidHomeController>();
    final success = await controller.saveTargetWeight(
      _selectedKg,
      weightGoalDirection: _direction,
      includeDirection: true,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save. Try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = PhaseTheme.forPhaseString(widget.dashboard.cycle?.phase);
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final controller = Get.find<PaidHomeController>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomSafe + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFD8EDD4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            "What's your goal weight?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF163220),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'You can change this anytime',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9AB09A),
            ),
          ),
          if (_needsDirectionPicker) ...[
            const SizedBox(height: 20),
            _DirectionPicker(
              accent: theme.accent,
              direction: _direction,
              onChanged: (d) => setState(() => _direction = d),
            ),
          ],
          const SizedBox(height: 32),
          Center(
            child: Text(
              '${_selectedKg.toStringAsFixed(1)} kg',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: theme.accent,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.accent,
              inactiveTrackColor: const Color(0xFFD8EDD4),
              thumbColor: theme.accent,
              overlayColor: theme.accent.withOpacity(0.20),
              trackHeight: 4,
            ),
            child: Slider(
              value: _selectedKg,
              min: _minKg,
              max: _maxKg,
              divisions: _divisions,
              onChanged: (v) => setState(() => _selectedKg = v),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '40kg',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9AB09A),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '150kg',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9AB09A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _CancelButton(
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SaveButton(
                  accent: theme.accent,
                  onTap: _onSave,
                  isSaving: controller.isSavingTargetWeight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "I'm trying to: Lose weight / Gain weight" segmented toggle. Only
/// shown when the signup mainGoal doesn't already say which way — see
/// _SetTargetWeightModalState._needsDirectionPicker. Answer determines
/// whether a future week-over-week change reads as good news or a
/// heads-up on the home screen's Weight card.
class _DirectionPicker extends StatelessWidget {
  final Color accent;
  final String direction; // 'lose' | 'gain'
  final ValueChanged<String> onChanged;

  const _DirectionPicker({
    required this.accent,
    required this.direction,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "I'm trying to",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9AB09A),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DirectionPill(
                label: 'Lose weight',
                selected: direction == 'lose',
                accent: accent,
                onTap: () => onChanged('lose'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DirectionPill(
                label: 'Gain weight',
                selected: direction == 'gain',
                accent: accent,
                onTap: () => onChanged('gain'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DirectionPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _DirectionPill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : const Color(0xFFD8EDD4),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF163220),
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD8EDD4), width: 1),
        ),
        child: const Text(
          'Cancel',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9AB09A),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  final RxBool isSaving;

  const _SaveButton({
    required this.accent,
    required this.onTap,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final saving = isSaving.value;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: saving ? null : onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      );
    });
  }
}
