import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import '../guided_workout_controller.dart';
import '../models/exercise.dart';

/// 2M12 — large-layout cast / mirroring stopgap UI.
class CastWorkoutScreen extends StatelessWidget {
  const CastWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    GuidedRoutine? routine;
    try {
      routine = Get.find<GuidedWorkoutController>().activeRoutine.value;
    } catch (_) {}
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Cast / TV layout'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Use phone screen mirroring (AirPlay / Cast) as stopgap.\nChromecast/AirPlay SDK wiring is contract-ready.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Text(
              routine?.title ?? 'No active guided workout',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              routine == null
                  ? 'Start a guided session, then open cast.'
                  : '${routine.moves.length} moves · larger timer & cues',
              style: const TextStyle(color: AppColors.primary, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
