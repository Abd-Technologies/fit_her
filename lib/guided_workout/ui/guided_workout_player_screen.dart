import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/analytics/analytics_events.dart';
import '../../data/services/tier_access_service.dart';
import '../../helper/analytics_helper.dart';
import '../../theme/app_colors.dart';
import '../adaptive_workout_service.dart';
import '../guided_workout_controller.dart';
import '../models/exercise.dart';

class GuidedWorkoutPlayerScreen extends StatefulWidget {
  const GuidedWorkoutPlayerScreen({super.key});

  @override
  State<GuidedWorkoutPlayerScreen> createState() =>
      _GuidedWorkoutPlayerScreenState();
}

class _GuidedWorkoutPlayerScreenState extends State<GuidedWorkoutPlayerScreen> {
  late final GuidedWorkoutController c;
  Timer? _timer;
  int _secondsLeft = 0;
  bool _finished = false;
  bool _blocked = false;

  @override
  void initState() {
    super.initState();
    c = Get.find<GuidedWorkoutController>();
    if (Get.isRegistered<TierAccessService>() &&
        !Get.find<TierAccessService>().canAccessGuidedWorkouts) {
      _blocked = true;
      AnalyticsHelper.track(AnalyticsEvents.upgradeTap, props: {
        'reason': 'guided_workout',
      });
      return;
    }
    c.buildRoutine();
    AnalyticsHelper.track(AnalyticsEvents.guidedWorkoutStarted);
    _startMoveTimer();
  }

  void _startMoveTimer() {
    _timer?.cancel();
    final move = c.currentMove;
    _secondsLeft = move?.durationSec ?? 30;
    setState(() {});
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _onMoveComplete();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _onMoveComplete() async {
    _timer?.cancel();
    final r = c.activeRoutine.value;
    if (r == null) return;
    if (c.currentMoveIndex.value >= r.moves.length - 1) {
      setState(() => _finished = true);
      return;
    }
    await c.markMoveDone();
    _startMoveTimer();
  }

  Future<void> _submitFeedback(String value) async {
    await c.completeWorkout(feedback: value);
    if (Get.isRegistered<AdaptiveWorkoutService>()) {
      Get.find<AdaptiveWorkoutService>().explainStreakFromFeedback(value);
      await Get.find<AdaptiveWorkoutService>().bumpProgressionWeek();
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7E4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Obx(() => Text(
              c.activeRoutine.value?.title ?? 'Guided workout',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF163220),
              ),
            )),
        actions: [
          Obx(() => IconButton(
                tooltip: 'Toggle cues',
                onPressed: () => c.setCuesEnabled(!c.cuesEnabled.value),
                icon: Icon(
                  c.cuesEnabled.value
                      ? Icons.record_voice_over
                      : Icons.voice_over_off,
                  color: AppColors.primaryDeep,
                ),
              )),
        ],
      ),
      body: _blocked
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Guided workouts are included with Plus. Upgrade to follow animated sessions at home.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                ),
              ),
            )
          : _finished
              ? _feedback()
              : _player(),
    );
  }

  Widget _player() {
    return Obx(() {
      final move = c.currentMove;
      final r = c.activeRoutine.value;
      if (move == null || r == null) {
        return const Center(child: Text('No exercises loaded'));
      }
      final step = c.currentMoveIndex.value + 1;
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Move $step of ${r.moves.length}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFF6F8B7A),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD8EDD4)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.accessibility_new,
                        size: 96, color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text(
                      move.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF163220),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_secondsLeft s',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                    if (c.cuesEnabled.value) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          move.cueText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Color(0xFF4F6B5A),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (Get.isRegistered<AdaptiveWorkoutService>())
              Wrap(
                spacing: 8,
                children: [
                  for (final reason in const ['too_hard', 'hurts', 'dislike'])
                    OutlinedButton(
                      onPressed: () {
                        final swapped = Get.find<AdaptiveWorkoutService>()
                            .swapExercise(move, reason);
                        if (swapped != null && c.activeRoutine.value != null) {
                          final r = c.activeRoutine.value!;
                          final moves = [...r.moves];
                          moves[c.currentMoveIndex.value] = swapped;
                          c.activeRoutine.value = GuidedRoutine(
                            id: r.id,
                            title: r.title,
                            intensity: r.intensity,
                            moves: moves,
                          );
                          _startMoveTimer();
                        }
                      },
                      child: Text(
                        reason.replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _onMoveComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Mark done',
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
      );
    });
  }

  Widget _feedback() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'How was that?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF163220),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Two taps — this shapes your next session.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Color(0xFF6F8B7A),
            ),
          ),
          const SizedBox(height: 24),
          for (final e in const [
            ('too_easy', 'Too easy'),
            ('right', 'Just right'),
            ('too_hard', 'Too hard'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton(
                onPressed: () => _submitFeedback(e.$1),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: Color(0xFFD8EDD4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  e.$2,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF163220),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
