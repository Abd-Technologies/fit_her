import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/daily_log_controller/daily_log_controller.dart';
import '../../data/models/daily_log/quick_checkin.dart';
import '../../theme/app_colors.dart';

/// One-screen quick check-in: mood, energy, stress, sleep (<30s) — 1NH2–1NH5.
Future<bool?> showQuickDailyCheckinSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _QuickDailyCheckinSheet(),
  );
}

class _QuickDailyCheckinSheet extends StatefulWidget {
  const _QuickDailyCheckinSheet();

  @override
  State<_QuickDailyCheckinSheet> createState() =>
      _QuickDailyCheckinSheetState();
}

class _QuickDailyCheckinSheetState extends State<_QuickDailyCheckinSheet> {
  int? mood;
  int? energy;
  int? stress;
  String? stressCause;
  double sleepHours = 7.0;
  int? sleepRested;
  int? hunger;
  final Set<String> cravings = {};
  String? digestion;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<DailyLogController>()) {
      final existing = Get.find<DailyLogController>().todayCheckin.value;
      if (existing != null) {
        mood = existing.mood;
        energy = existing.energy;
        stress = existing.stress;
        stressCause = existing.stressCause;
        sleepHours = existing.sleepHours ?? 7.0;
        sleepRested = existing.sleepRested;
        hunger = existing.hunger;
        cravings.addAll(existing.cravings);
        digestion = existing.digestion;
      }
    }
  }

  bool get _ready =>
      mood != null &&
      energy != null &&
      stress != null &&
      sleepRested != null;

  Future<void> _save() async {
    if (!_ready || !Get.isRegistered<DailyLogController>()) return;
    final ok = await Get.find<DailyLogController>().saveQuickCheckin(
      mood: mood!,
      energy: energy!,
      stress: stress!,
      stressCause: stressCause,
      sleepHours: sleepHours,
      sleepRested: sleepRested!,
      hunger: hunger,
      cravings: cravings.toList(),
      digestion: digestion,
    );
    if (mounted) Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8EDD4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quick check-in',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF163220),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Four taps. Under 30 seconds.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFF6F8B7A),
              ),
            ),
            const SizedBox(height: 18),
            _ScaleRow(
              label: 'Mood',
              value: mood,
              onChanged: (v) => setState(() => mood = v),
            ),
            _ScaleRow(
              label: 'Energy',
              value: energy,
              onChanged: (v) => setState(() => energy = v),
            ),
            _ScaleRow(
              label: 'Stress',
              value: stress,
              onChanged: (v) => setState(() => stress = v),
            ),
            if (stress != null && stress! >= 3) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: QuickCheckin.stressCauses.map((c) {
                  final selected = stressCause == c;
                  return ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (_) => setState(() => stressCause = c),
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Sleep · ${sleepHours.toStringAsFixed(1)} h',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF163220),
              ),
            ),
            Slider(
              value: sleepHours,
              min: 3,
              max: 12,
              divisions: 18,
              label: sleepHours.toStringAsFixed(1),
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => sleepHours = v),
            ),
            const Text(
              'How rested?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF163220),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final e in const [
                  (1, 'Tired'),
                  (2, 'OK'),
                  (3, 'Rested'),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: sleepRested == e.$1
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : null,
                          side: BorderSide(
                            color: sleepRested == e.$1
                                ? AppColors.primary
                                : const Color(0xFFD8EDD4),
                          ),
                        ),
                        onPressed: () => setState(() => sleepRested = e.$1),
                        child: Text(
                          e.$2,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFF163220),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _ScaleRow(
              label: 'Hunger (optional)',
              value: hunger,
              onChanged: (v) => setState(() => hunger = v),
            ),
            const Text(
              'Cravings',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF163220),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: QuickCheckin.cravingOptions.map((c) {
                final selected = cravings.contains(c);
                return FilterChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (on) => setState(() {
                    if (on) {
                      if (c == 'none') {
                        cravings
                          ..clear()
                          ..add('none');
                      } else {
                        cravings.remove('none');
                        cravings.add(c);
                      }
                    } else {
                      cravings.remove(c);
                    }
                  }),
                  selectedColor: AppColors.primary.withValues(alpha: 0.25),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Digestion',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF163220),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: QuickCheckin.digestionOptions.map((d) {
                final selected = digestion == d;
                return ChoiceChip(
                  label: Text(d),
                  selected: selected,
                  onSelected: (_) => setState(() => digestion = d),
                  selectedColor: AppColors.primary.withValues(alpha: 0.25),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _ready ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: const Color(0xFFD8EDD4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save check-in',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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

class _ScaleRow extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int> onChanged;

  const _ScaleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF163220),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final level = i + 1;
              final selected = value == level;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(level),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFFF3F8F1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : const Color(0xFFD8EDD4),
                      ),
                    ),
                    child: Text(
                      '$level',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF4F6B5A),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
