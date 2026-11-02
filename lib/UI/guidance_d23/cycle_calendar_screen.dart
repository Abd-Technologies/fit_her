import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import '../../data/services/period_predictor_service.dart';
import '../../theme/app_colors.dart';

/// 3NH5 — cycle calendar with plan-ahead lines.
class CycleCalendarScreen extends StatelessWidget {
  const CycleCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String phase = 'follicular';
    try {
      phase = Get.find<CycleThemeController>().phase.value.name;
    } catch (_) {}
    final pred = Get.isRegistered<PeriodPredictorService>()
        ? Get.find<PeriodPredictorService>().predict()
        : null;

    final lines = {
      'menstrual': 'Food: iron-rich · Move: gentle only',
      'follicular': 'Food: protein focus · Move: build strength',
      'ovulatory': 'Food: fibre + hydrate · Move: higher intensity OK',
      'luteal': 'Food: steady carbs · Move: moderate, listen to energy',
    };

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cycle calendar'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Current phase: $phase',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...lines.entries.map(
            (e) => Card(
              elevation: 0,
              color: e.key == phase
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : const Color(0xFFF3F8F1),
              child: ListTile(
                title: Text(e.key),
                subtitle: Text(e.value),
              ),
            ),
          ),
          if (pred != null) ...[
            const SizedBox(height: 16),
            Text(
              'Predicted period window: '
              '${pred.rangeStart.toIso8601String().substring(0, 10)} – '
              '${pred.rangeEnd.toIso8601String().substring(0, 10)}',
            ),
          ],
        ],
      ),
    );
  }
}
