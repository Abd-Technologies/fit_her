import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helper/analytics_helper.dart';
import '../analytics/analytics_events.dart';
import '../repos/daily_log_repo/daily_log_repository.dart';
import 'food_preferences_service.dart';

/// 2NH3 — local weekly diet plan adjustment (rules; sync hook later).
class WeeklyDietAdjustment {
  final String weekOf;
  final List<String> changes;
  final String note;
  final DateTime builtAt;

  const WeeklyDietAdjustment({
    required this.weekOf,
    required this.changes,
    required this.note,
    required this.builtAt,
  });

  Map<String, dynamic> toJson() => {
        'weekOf': weekOf,
        'changes': changes,
        'note': note,
        'builtAt': builtAt.toIso8601String(),
      };

  factory WeeklyDietAdjustment.fromJson(Map<String, dynamic> json) {
    return WeeklyDietAdjustment(
      weekOf: json['weekOf']?.toString() ?? '',
      changes: (json['changes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      note: json['note']?.toString() ?? '',
      builtAt: DateTime.tryParse(json['builtAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class WeeklyDietAdjustService extends GetxService {
  static const _key = 'd23_weekly_diet_adjust_v1';
  static const calorieFloor = 1400;

  final SharedPreferences prefs;

  WeeklyDietAdjustService({required this.prefs});

  final Rxn<WeeklyDietAdjustment> latest = Rxn<WeeklyDietAdjustment>();

  @override
  void onInit() {
    super.onInit();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        latest.value =
            WeeklyDietAdjustment.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<WeeklyDietAdjustment> runForCurrentWeek() async {
    final now = DateTime.now();
    final weekOf =
        '${now.year}-W${((now.difference(DateTime(now.year)).inDays) / 7).floor() + 1}';
    final changes = <String>[];
    final prefsSvc = Get.isRegistered<FoodPreferencesService>()
        ? Get.find<FoodPreferencesService>().current.value
        : null;

    if (Get.isRegistered<DailyLogRepository>()) {
      final repo = Get.find<DailyLogRepository>();
      final checkins = repo.loadCheckins().take(7).toList();
      final bloated = checkins.where((c) => c.digestion == 'bloated').length;
      final sweet = checkins
          .where((c) => c.cravings.contains('sweet'))
          .length;
      final lowEnergy =
          checkins.where((c) => (c.energy ?? 3) <= 2).length;

      if (bloated >= 2) {
        changes.add('Swap heavy fried sides for steamed vegetables this week.');
      }
      if (sweet >= 2) {
        changes.add('Add a fruit + protein snack after lunch for sweet cravings.');
      }
      if (lowEnergy >= 3) {
        changes.add('Slightly increase lunch carbs within the calorie floor.');
      }
    }

    if (prefsSvc != null && prefsSvc.allergies.isNotEmpty) {
      changes.add(
        'Kept ${prefsSvc.allergies.join(", ")} out of every suggestion.',
      );
    }
    if (changes.isEmpty) {
      changes.add('No major changes — your logs look steady. Keeping portions.');
    }

    final adj = WeeklyDietAdjustment(
      weekOf: weekOf,
      changes: changes,
      note:
          'Plan stayed at or above $calorieFloor kcal floor. Rules-only adjust; dietitian floor respected.',
      builtAt: DateTime.now(),
    );
    latest.value = adj;
    await prefs.setString(_key, jsonEncode(adj.toJson()));
    await AnalyticsHelper.track(
      AnalyticsEvents.weeklyPlanAdjusted,
      props: {'changes': changes.length},
    );
    return adj;
  }
}
