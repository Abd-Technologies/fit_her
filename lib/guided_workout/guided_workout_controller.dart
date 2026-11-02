import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/controllers/daily_log_controller/daily_log_controller.dart';
import '../data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import '../helper/analytics_helper.dart';
import '../data/analytics/analytics_events.dart';
import 'models/exercise.dart';

/// Guided workouts foundation (X1/X3/X8 + 1M1–1M6). Separate from Zoom live classes.
class GuidedWorkoutController extends GetxController {
  static const exercisesAsset = 'assets/guided_workout/exercises.json';
  static const injuriesKey = 'd1_user_injuries_v1';
  static const badgesKey = 'd1_badges_v1';
  static const streakKey = 'd1_guided_streak_v1';
  static const lastActiveKey = 'd1_last_active_day';
  static const feedbackKey = 'd1_guided_feedback_v1';
  static const cuesEnabledKey = 'd1_cues_enabled';

  final SharedPreferences prefs;

  GuidedWorkoutController({required this.prefs});

  final RxList<Exercise> catalog = <Exercise>[].obs;
  final Rxn<GuidedRoutine> activeRoutine = Rxn<GuidedRoutine>();
  final RxInt currentMoveIndex = 0.obs;
  final RxBool cuesEnabled = true.obs;
  final RxSet<String> unlockedBadges = <String>{}.obs;
  final RxInt streakDays = 0.obs;
  final RxnString intensityOverride = RxnString(); // easy|normal|hard

  @override
  void onInit() {
    super.onInit();
    cuesEnabled.value = prefs.getBool(cuesEnabledKey) ?? true;
    streakDays.value = prefs.getInt(streakKey) ?? 0;
    final badges = prefs.getStringList(badgesKey) ?? [];
    unlockedBadges.addAll(badges);
    loadCatalog();
  }

  Future<void> loadCatalog() async {
    try {
      final raw = await rootBundle.loadString(exercisesAsset);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = decoded['exercises'] as List<dynamic>? ?? [];
      catalog.assignAll(
        list
            .whereType<Map>()
            .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e))),
      );
    } catch (_) {
      catalog.clear();
    }
  }

  List<String> get userInjuries =>
      prefs.getStringList(injuriesKey) ?? const [];

  Future<void> setInjuries(List<String> injuries) async {
    await prefs.setStringList(injuriesKey, injuries);
  }

  /// 1M1 — filter moves that conflict with injuries.
  List<Exercise> filteredCatalog() {
    final injuries = userInjuries.map((e) => e.toLowerCase()).toSet();
    return catalog.where((e) {
      return e.injuryConflicts
          .every((c) => !injuries.contains(c.toLowerCase()));
    }).toList();
  }

  /// 1M2 — phase + check-in adaptive intensity.
  WorkoutIntensity resolveIntensity() {
    final override = intensityOverride.value;
    if (override == 'easy') return WorkoutIntensity.easy;
    if (override == 'hard') return WorkoutIntensity.hard;
    if (override == 'normal') return WorkoutIntensity.normal;

    String phase = 'follicular';
    try {
      phase = Get.find<CycleThemeController>().phase.value.name;
    } catch (_) {}

    int energy = 3;
    int stress = 3;
    double sleep = 7;
    if (Get.isRegistered<DailyLogController>()) {
      final c = Get.find<DailyLogController>().todayCheckin.value;
      energy = c?.energy ?? 3;
      stress = c?.stress ?? 3;
      sleep = c?.sleepHours ?? 7;
    }

    if (phase == 'menstrual' || phase == 'luteal' || energy <= 2 || stress >= 4 || sleep < 5.5) {
      return WorkoutIntensity.easy;
    }
    if (phase == 'ovulation' && energy >= 4) {
      return WorkoutIntensity.hard;
    }
    return WorkoutIntensity.normal;
  }

  GuidedRoutine buildRoutine({int moveCount = 5, int? targetMinutes}) {
    final intensity = resolveIntensity();
    var moves = filteredCatalog();
    if (intensity == WorkoutIntensity.easy) {
      moves = moves.map((e) {
        if (e.easierId == null) return e;
        try {
          return catalog.firstWhere((x) => x.id == e.easierId);
        } catch (_) {
          return e;
        }
      }).toList();
    }
    if (targetMinutes != null) {
      // Roughly 1 move per ~2.5 minutes.
      moveCount = (targetMinutes / 2.5).round().clamp(3, 12);
    }
    moves = moves.take(moveCount).toList();
    if (moves.isEmpty) moves = catalog.take(moveCount).toList();

    final title = switch (intensity) {
      WorkoutIntensity.easy => 'Gentle guided session',
      WorkoutIntensity.hard => 'Strong guided session',
      WorkoutIntensity.normal => 'Guided session',
    };

    final routine = GuidedRoutine(
      id: const Uuid().v4(),
      title: title,
      intensity: intensity,
      moves: moves,
    );
    activeRoutine.value = routine;
    currentMoveIndex.value = 0;
    return routine;
  }

  Exercise? get currentMove {
    final r = activeRoutine.value;
    if (r == null || r.moves.isEmpty) return null;
    final i = currentMoveIndex.value.clamp(0, r.moves.length - 1);
    return r.moves[i];
  }

  Future<void> markMoveDone() async {
    final r = activeRoutine.value;
    if (r == null) return;
    await AnalyticsHelper.track(AnalyticsEvents.guidedMoveMarkedDone);
    if (currentMoveIndex.value < r.moves.length - 1) {
      currentMoveIndex.value++;
    }
  }

  Future<void> completeWorkout({required String feedback}) async {
    await AnalyticsHelper.track(
      AnalyticsEvents.guidedWorkoutCompleted,
      props: {'feedback': feedback},
    );
    final list = prefs.getStringList(feedbackKey) ?? [];
    list.add(jsonEncode({
      'at': DateTime.now().toIso8601String(),
      'feedback': feedback,
      'routineId': activeRoutine.value?.id,
    }));
    await prefs.setStringList(feedbackKey, list.take(50).toList());
    await _bumpStreakAndBadges();
  }

  Future<void> _bumpStreakAndBadges() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final last = prefs.getString(lastActiveKey);
    if (last != today) {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      if (last == yesterday) {
        streakDays.value = streakDays.value + 1;
      } else {
        streakDays.value = 1;
      }
      await prefs.setString(lastActiveKey, today);
      await prefs.setInt(streakKey, streakDays.value);
    }
    await _maybeUnlock('first_workout');
    if (streakDays.value >= 3) await _maybeUnlock('streak_3');
    if (streakDays.value >= 7) await _maybeUnlock('streak_7');
    if (streakDays.value >= 30) await _maybeUnlock('streak_30');
  }

  Future<void> markFirstLogBadge() async => _maybeUnlock('first_log');

  Future<void> _maybeUnlock(String id) async {
    if (unlockedBadges.contains(id)) return;
    unlockedBadges.add(id);
    await prefs.setStringList(badgesKey, unlockedBadges.toList());
    await AnalyticsHelper.track(
      AnalyticsEvents.badgeUnlocked,
      props: {'badge': id},
    );
  }

  Future<void> setCuesEnabled(bool enabled) async {
    cuesEnabled.value = enabled;
    await prefs.setBool(cuesEnabledKey, enabled);
  }

  /// Rest day keeps streak alive (1M6).
  Future<void> markRestDay() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final last = prefs.getString(lastActiveKey);
    if (last == today) return;
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    if (last == yesterday || last == null) {
      // do not increment, just preserve continuity
      await prefs.setString(lastActiveKey, today);
    }
  }
}
