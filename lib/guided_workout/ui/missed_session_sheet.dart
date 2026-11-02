import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import 'guided_workout_player_screen.dart';

/// X7 — missed session sheet with correct slot data + action.
Future<void> showMissedSessionSheet(
  BuildContext context, {
  required String className,
  required String scheduledAt,
  String? trainerName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
              'You missed a session',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF163220),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              className,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF163220),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (trainerName != null && trainerName.isNotEmpty) trainerName,
                scheduledAt,
              ].join(' · '),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFF6F8B7A),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  // 2M5 — short recovery workout matching the missed class.
                  Navigator.pop(ctx);
                  Get.to(() => const GuidedWorkoutPlayerScreen());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Do a short guided workout',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF6F8B7A),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
