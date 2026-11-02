import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/services/weekly_diet_adjust_service.dart';
import '../../theme/app_colors.dart';

/// 2NH3 — weekly diet plan adjustment note.
class WeeklyAdjustScreen extends StatelessWidget {
  const WeeklyAdjustScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<WeeklyDietAdjustService>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Weekly plan update'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Obx(() {
          final adj = svc.latest.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () => svc.runForCurrentWeek(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  'Run this week\'s adjust',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              if (adj == null)
                const Text(
                  'No adjustment yet. Run once you have a few days of logs.',
                  style: TextStyle(color: Color(0xFF6F8B7A)),
                )
              else ...[
                Text(
                  'Week ${adj.weekOf}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(adj.note),
                const SizedBox(height: 16),
                const Text(
                  'What changed',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                ...adj.changes.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline,
                        color: AppColors.primary),
                    title: Text(c),
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}
