
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/controllers/daily_log_controller/daily_log_controller.dart';
import '../helper/analytics_helper.dart';
import '../data/analytics/analytics_events.dart';
import 'guided_workout_controller.dart';
import 'models/exercise.dart';

/// 2M1–2M9 adaptive guided helpers (picker, swap, progression, rest, fuel).
class AdaptiveWorkoutService extends GetxService {
  static const _swapMemoryKey = 'd23_swap_memory_v1';
  static const _progressionKey = 'd23_progression_week_v1';

  final SharedPreferences prefs;

  AdaptiveWorkoutService({required this.prefs});

  final RxInt preferredMinutes = 20.obs; // 10|20|30
  final RxString energyPick = 'normal'.obs; // easier|normal|harder
  final RxnString restSuggestion = RxnString();
  final RxnString fuelBefore = RxnString();
  final RxnString fuelAfter = RxnString();
  final RxnString streakExplain = RxnString();

  Map<String, String> get swapMemory {
    final raw = prefs.getString(_swapMemoryKey);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> rememberSwap(String fromId, String toId) async {
    final map = swapMemory..[fromId] = toId;
    await prefs.setString(_swapMemoryKey, jsonEncode(map));
  }

  Future<void> applyPicker({
    required int minutes,
    required String energy,
  }) async {
    preferredMinutes.value = minutes;
    energyPick.value = energy;
    if (Get.isRegistered<GuidedWorkoutController>()) {
      final g = Get.find<GuidedWorkoutController>();
      g.intensityOverride.value = energy == 'easier'
          ? 'easy'
          : energy == 'harder'
              ? 'hard'
              : 'normal';
      g.buildRoutine(targetMinutes: minutes);
    }
    await AnalyticsHelper.track(AnalyticsEvents.guidedPickerUsed, props: {
      'minutes': minutes,
      'energy': energy,
    });
  }

  Exercise? swapExercise(Exercise current, String reason) {
    if (!Get.isRegistered<GuidedWorkoutController>()) return null;
    final g = Get.find<GuidedWorkoutController>();
    final pool = g.filteredCatalog()
        .where((e) => e.id != current.id && e.bodyArea == current.bodyArea)
        .toList();
    if (pool.isEmpty) return null;
    final next = pool.first;
    rememberSwap(current.id, next.id);
    if (reason == 'hurts') {
      final injuries = [...g.userInjuries, current.bodyArea];
      g.setInjuries(injuries.toSet().toList());
    }
    AnalyticsHelper.track(AnalyticsEvents.guidedSwapUsed, props: {
      'reason': reason,
      'from': current.id,
      'to': next.id,
    });
    return next;
  }

  int progressionMultiplierPercent() {
    final week = prefs.getInt(_progressionKey) ?? 0;
    return (100 + (week * 5)).clamp(100, 130);
  }

  Future<void> bumpProgressionWeek() async {
    final week = (prefs.getInt(_progressionKey) ?? 0) + 1;
    await prefs.setInt(_progressionKey, week);
  }

  void evaluateRestDay() {
    if (!Get.isRegistered<DailyLogController>()) {
      restSuggestion.value = null;
      return;
    }
    final c = Get.find<DailyLogController>().todayCheckin.value;
    final s = Get.find<DailyLogController>().todaySymptoms.value;
    final tired = (c?.energy ?? 3) <= 2 ||
        (c?.stress ?? 0) >= 4 ||
        (c?.sleepHours ?? 8) < 5 ||
        (c?.mood ?? 3) <= 2;
    final cramps = (s?.severities['cramps'] ?? 0) >= 2;
    if (tired || cramps) {
      restSuggestion.value = cramps
          ? 'Cramps look high — rest or a gentle stretch set today keeps your streak.'
          : 'Logs suggest a rest or gentle day. Rest still counts for your streak.';
      AnalyticsHelper.track(AnalyticsEvents.restDaySuggested);
    } else {
      restSuggestion.value = null;
    }
  }

  void refreshFuelTips({String? phase}) {
    final p = (phase ?? 'follicular').toLowerCase();
    if (p.contains('menstrual')) {
      fuelBefore.value = 'Light snack + water an hour before if you train.';
      fuelAfter.value = 'Iron-friendly meal after — dates or lentils help.';
    } else if (p.contains('luteal')) {
      fuelBefore.value = 'Steady carb snack ~60 min before.';
      fuelAfter.value = 'Protein + carbs after to settle cravings.';
    } else {
      fuelBefore.value = 'Hydrate; optional yogurt or fruit before.';
      fuelAfter.value = 'Protein within an hour after your session.';
    }
  }

  void explainStreakFromFeedback(String feedback) {
    if (feedback.contains('easy')) {
      streakExplain.value = 'Because that felt easy, tomorrow leans a bit stronger.';
    } else if (feedback.contains('hard')) {
      streakExplain.value = 'Because that felt hard, tomorrow stays gentler.';
    } else {
      streakExplain.value = 'Nice — we\'ll keep a similar mix tomorrow.';
    }
  }

  List<Exercise> womenBasicSet(String kind) {
    if (!Get.isRegistered<GuidedWorkoutController>()) return const [];
    final all = Get.find<GuidedWorkoutController>().filteredCatalog();
    bool match(Exercise e) {
      final tags = [
        e.bodyArea.toLowerCase(),
        e.name.toLowerCase(),
        e.equipment.toLowerCase(),
      ].join(' ');
      switch (kind) {
        case 'pelvic':
          return tags.contains('pelvic') || tags.contains('floor');
        case 'posture':
          return tags.contains('posture') ||
              tags.contains('back') ||
              tags.contains('shoulder');
        default:
          return tags.contains('core') || tags.contains('abs');
      }
    }
    return all.where(match).take(6).toList();
  }
}
