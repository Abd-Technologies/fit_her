import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import '../../theme/app_colors.dart';
import '../adaptive_workout_service.dart';
import 'guided_workout_player_screen.dart';

Future<void> showAdaptiveWorkoutSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AdaptiveWorkoutSheet(),
  );
}

class _AdaptiveWorkoutSheet extends StatefulWidget {
  const _AdaptiveWorkoutSheet();

  @override
  State<_AdaptiveWorkoutSheet> createState() => _AdaptiveWorkoutSheetState();
}

class _AdaptiveWorkoutSheetState extends State<_AdaptiveWorkoutSheet> {
  int minutes = 20;
  String energy = 'normal';

  @override
  void initState() {
    super.initState();
    final a = Get.find<AdaptiveWorkoutService>();
    a.evaluateRestDay();
    String? phase;
    try {
      phase = Get.find<CycleThemeController>().phase.value.name;
    } catch (_) {}
    a.refreshFuelTips(phase: phase);
  }

  @override
  Widget build(BuildContext context) {
    final a = Get.find<AdaptiveWorkoutService>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s movement',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Obx(() {
              final rest = a.restSuggestion.value;
              if (rest == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(rest),
              );
            }),
            const SizedBox(height: 16),
            const Text('Time', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              children: [10, 20, 30]
                  .map(
                    (m) => ChoiceChip(
                      label: Text('$m min'),
                      selected: minutes == m,
                      onSelected: (_) => setState(() => minutes = m),
                      selectedColor: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            const Text('Energy', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              children: ['easier', 'normal', 'harder']
                  .map(
                    (e) => ChoiceChip(
                      label: Text(e),
                      selected: energy == e,
                      onSelected: (_) => setState(() => energy = e),
                      selectedColor: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Obx(() => Text('Before: ${a.fuelBefore.value ?? ''}')),
            Obx(() => Text('After: ${a.fuelAfter.value ?? ''}')),
            const SizedBox(height: 8),
            Text(
              'Progression: ${a.progressionMultiplierPercent()}% of baseline',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6F8B7A)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  await a.applyPicker(minutes: minutes, energy: energy);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  Get.to(() => const GuidedWorkoutPlayerScreen());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text(
                  'Start guided',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final set = a.womenBasicSet('core');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Women basic core set: ${set.length} moves ready',
                    ),
                  ),
                );
              },
              child: const Text('Preview women-specific core set'),
            ),
          ],
        ),
      ),
    );
  }
}
