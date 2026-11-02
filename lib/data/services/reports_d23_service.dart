import 'package:get/get.dart';

import '../../helper/analytics_helper.dart';
import '../analytics/analytics_events.dart';
import '../models/daily_log/quick_checkin.dart';
import '../repos/daily_log_repo/daily_log_repository.dart';
import 'extended_log_service.dart';
import 'food_diary_service.dart';
import 'tier_access_service.dart';

/// 2NH10–2NH13 template reports (rules; Progress beta exit for weekly).
class WeeklyPatternReport {
  final List<String> patterns;
  final String recap;
  final bool enoughData;

  const WeeklyPatternReport({
    required this.patterns,
    required this.recap,
    required this.enoughData,
  });
}

class MonthlyBodyReport {
  final Map<String, num> nutritionAverages;
  final List<String> bodyTrends;
  final List<String> nextMonthTips;

  const MonthlyBodyReport({
    required this.nutritionAverages,
    required this.bodyTrends,
    required this.nextMonthTips,
  });
}

class ReportsD23Service extends GetxService {
  WeeklyPatternReport buildWeekly() {
    if (!Get.isRegistered<DailyLogRepository>()) {
      return const WeeklyPatternReport(
        patterns: [],
        recap: 'No logs yet.',
        enoughData: false,
      );
    }
    final repo = Get.find<DailyLogRepository>();
    final checkins = repo.loadCheckins().take(14).toList();
    if (checkins.length < 7) {
      return const WeeklyPatternReport(
        patterns: [],
        recap: 'Need at least 7 days of check-ins for a weekly pattern report.',
        enoughData: false,
      );
    }
    final week = checkins.take(7).toList();
    final prev = checkins.skip(7).take(7).toList();

    double avgMood(List<QuickCheckin> list) {
      final vals = list.map((c) => c.mood).whereType<int>().toList();
      if (vals.isEmpty) return 0;
      return vals.reduce((a, b) => a + b) / vals.length;
    }

    double avgEnergy(List<QuickCheckin> list) {
      final vals = list.map((c) => c.energy).whereType<int>().toList();
      if (vals.isEmpty) return 0;
      return vals.reduce((a, b) => a + b) / vals.length;
    }

    final mood = avgMood(week);
    final energy = avgEnergy(week);
    final sleepVals =
        week.map((c) => c.sleepHours).whereType<double>().toList();
    final sleep = sleepVals.isEmpty
        ? 0.0
        : sleepVals.reduce((a, b) => a + b) / sleepVals.length;

    final patterns = <String>[];
    if (energy < 2.5) {
      patterns.add(
          'Energy ran lower this week (avg ${energy.toStringAsFixed(1)}/5).');
    }
    if (mood >= 3.5) {
      patterns.add(
          'Mood held steady-to-good (avg ${mood.toStringAsFixed(1)}/5).');
    }
    final bloated = week.where((c) => c.digestion == 'bloated').length;
    if (bloated >= 2) {
      patterns.add(
          'Bloating showed up on $bloated days — check luteal timing in your cycle view.');
    }
    if (patterns.isEmpty) {
      patterns.add('No standout pattern — your week looks balanced.');
    }

    String delta(String label, double cur, double? old) {
      if (old == null || old == 0) return '$label ${cur.toStringAsFixed(1)}';
      final d = cur - old;
      final arrow = d >= 0 ? 'up' : 'down';
      return '$label ${cur.toStringAsFixed(1)} ($arrow ${d.abs().toStringAsFixed(1)} vs last week)';
    }

    final prevMood = prev.isEmpty ? null : avgMood(prev);
    final prevEnergy = prev.isEmpty ? null : avgEnergy(prev);
    final recap =
        'Days logged: ${week.length}. ${delta('Mood', mood, prevMood)}. ${delta('Energy', energy, prevEnergy)}. Sleep avg ${sleep.toStringAsFixed(1)}h.';

    AnalyticsHelper.track(AnalyticsEvents.weeklyReportViewed);
    return WeeklyPatternReport(
      patterns: patterns,
      recap: recap,
      enoughData: true,
    );
  }

  MonthlyBodyReport buildMonthly() {
    final nutrition = <String, num>{
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
    };
    if (Get.isRegistered<FoodDiaryService>()) {
      final meals = Get.find<FoodDiaryService>().entries.take(60).toList();
      if (meals.isNotEmpty) {
        nutrition['calories'] =
            meals.map((e) => e.totalCalories).reduce((a, b) => a + b) /
                meals.length;
        nutrition['protein'] =
            meals.map((e) => e.protein * e.portion).reduce((a, b) => a + b) /
                meals.length;
        nutrition['carbs'] =
            meals.map((e) => e.carbs * e.portion).reduce((a, b) => a + b) /
                meals.length;
        nutrition['fat'] =
            meals.map((e) => e.fat * e.portion).reduce((a, b) => a + b) /
                meals.length;
      }
    }
    final trends = <String>[];
    if (Get.isRegistered<DailyLogRepository>()) {
      final c = Get.find<DailyLogRepository>().loadCheckins().take(30).toList();
      if (c.isNotEmpty) {
        final energy =
            c.map((e) => e.energy ?? 3).reduce((a, b) => a + b) / c.length;
        trends.add(
            'Energy trend ~${energy.toStringAsFixed(1)}/5 over logged days.');
      }
    }
    if (Get.isRegistered<ExtendedLogService>()) {
      final skin = Get.find<ExtendedLogService>().skinHairLogs.length;
      if (skin > 0) trends.add('Skin/hair logged on $skin days.');
    }
    if (trends.isEmpty) {
      trends.add('Keep logging to unlock clearer monthly trends.');
    }

    AnalyticsHelper.track(AnalyticsEvents.monthlyReportViewed);
    return MonthlyBodyReport(
      nutritionAverages: nutrition,
      bodyTrends: trends,
      nextMonthTips: const [
        'Protect a consistent check-in time.',
        'Match protein to your training days.',
        'Note flow heaviness for better predictions.',
      ],
    );
  }

  bool get canViewWeekly =>
      !Get.isRegistered<TierAccessService>() ||
      Get.find<TierAccessService>().canAccessReports;

  bool get canViewMonthly =>
      !Get.isRegistered<TierAccessService>() ||
      Get.find<TierAccessService>().canViewMonthlyReport;
}
