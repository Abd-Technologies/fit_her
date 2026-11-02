import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../UI/daily_log/quick_daily_checkin_sheet.dart';
import '../../UI/daily_log/symptom_picker_sheet.dart';
import '../../data/controllers/daily_log_controller/daily_log_controller.dart';
import '../../data/analytics/analytics_events.dart';
import '../../guided_workout/adaptive_workout_service.dart';
import '../../guided_workout/ui/adaptive_workout_sheet.dart';
import '../../helper/analytics_helper.dart';
import '../../recorded_library/ui/recorded_library_screen.dart';
import '../../theme/app_colors.dart';

/// 1P10 + 2M6 — one primary daily focus CTA (check-in | symptoms | rest | guided | library).
class DailyFocusCard extends StatelessWidget {
  const DailyFocusCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<DailyLogController>()) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      final log = Get.find<DailyLogController>();
      final checkinDone = log.todayCheckin.value?.isComplete == true;
      final symptomsDone = log.todaySymptoms.value != null;

      String title;
      String subtitle;
      Future<void> Function() action;

      if (!checkinDone) {
        title = 'Today’s focus: quick check-in';
        subtitle = 'Mood, energy, stress and sleep — under 30 seconds.';
        action = () async {
          await showQuickDailyCheckinSheet(context);
        };
      } else if (!symptomsDone) {
        title = 'Today’s focus: log symptoms';
        subtitle = 'A quick tap helps Luna and your weekly patterns.';
        action = () async {
          await showSymptomPickerSheet(context);
        };
      } else {
        String? rest;
        if (Get.isRegistered<AdaptiveWorkoutService>()) {
          final a = Get.find<AdaptiveWorkoutService>();
          a.evaluateRestDay();
          rest = a.restSuggestion.value;
        }
        if (rest != null) {
          title = 'Today’s focus: rest or gentle';
          subtitle = rest;
          action = () async {
            await AnalyticsHelper.track(AnalyticsEvents.todayPlanCardTapped,
                props: {'choice': 'rest'});
            await showAdaptiveWorkoutSheet(context);
          };
        } else {
          title = 'Today’s focus: guided or library';
          subtitle = 'A short session matched to your phase — or open recorded classes.';
          action = () async {
            await AnalyticsHelper.track(AnalyticsEvents.todayPlanCardTapped,
                props: {'choice': 'guided'});
            await showAdaptiveWorkoutSheet(context);
          };
        }
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF163220),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: action,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF163220),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Start',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (checkinDone && symptomsDone) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () {
                        AnalyticsHelper.track(
                          AnalyticsEvents.todayPlanCardTapped,
                          props: {'choice': 'library'},
                        );
                        Get.to(() => const RecordedLibraryScreen());
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      child: const Text('Library'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    });
  }
}
