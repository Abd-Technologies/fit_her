import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../guided_workout/guided_workout_controller.dart';
import '../../../helper/analytics_helper.dart';
import '../../../utils/app_clock.dart';
import '../../analytics/analytics_events.dart';
import '../../models/daily_log/quick_checkin.dart';
import '../../models/daily_log/symptom_log.dart';
import '../../repos/daily_log_repo/daily_log_repository.dart';
import '../cycle_theme_controller/cycle_theme_controller.dart';

class DailyLogController extends GetxController {
  final DailyLogRepository repo;
  final SharedPreferences prefs;

  DailyLogController({required this.repo, required this.prefs});

  final Rxn<QuickCheckin> todayCheckin = Rxn<QuickCheckin>();
  final Rxn<SymptomLog> todaySymptoms = Rxn<SymptomLog>();
  final RxInt waterGoalMl = 2000.obs;
  final RxBool isSaving = false.obs;

  String get todayDate {
    final n = AppClock.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  String? get _phase {
    try {
      return Get.find<CycleThemeController>().phase.value.name;
    } catch (_) {
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    refreshToday();
    repo.flushQueue();
  }

  void refreshToday() {
    todayCheckin.value = repo.checkinForDate(todayDate);
    todaySymptoms.value = repo.symptomForDate(todayDate);
    waterGoalMl.value = repo.waterGoalMl;
  }

  Future<bool> saveQuickCheckin({
    required int mood,
    required int energy,
    required int stress,
    String? stressCause,
    required double sleepHours,
    required int sleepRested,
    int? hunger,
    List<String> cravings = const [],
    String? digestion,
    String? digestionNote,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      final hadAny = repo.loadCheckins().isNotEmpty ||
          repo.loadSymptoms().isNotEmpty;
      final saved = await repo.saveQuickCheckin(QuickCheckin(
        date: todayDate,
        mood: mood,
        energy: energy,
        stress: stress,
        stressCause: stressCause,
        sleepHours: sleepHours,
        sleepRested: sleepRested,
        hunger: hunger,
        cravings: cravings,
        digestion: digestion,
        digestionNote: digestionNote,
        cyclePhase: _phase,
        updatedAt: DateTime.now(),
      ));
      todayCheckin.value = saved;
      await AnalyticsHelper.track(
        AnalyticsEvents.dailyCheckinSaved,
        props: {'phase': _phase, 'complete': saved.isComplete},
      );
      if (!hadAny) {
        await AnalyticsHelper.track(AnalyticsEvents.firstLog);
        try {
          if (Get.isRegistered<GuidedWorkoutController>()) {
            await Get.find<GuidedWorkoutController>().markFirstLogBadge();
          }
        } catch (_) {}
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> saveSymptoms({
    required Map<String, int> severities,
    String? painBodyArea,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      final existing = repo.symptomForDate(todayDate);
      final saved = await repo.upsertSymptom(SymptomLog(
        id: existing?.id ?? const Uuid().v4(),
        date: todayDate,
        cyclePhase: _phase,
        severities: severities,
        painBodyArea: painBodyArea,
        updatedAt: DateTime.now(),
      ));
      todaySymptoms.value = saved;
      await AnalyticsHelper.track(
        AnalyticsEvents.symptomLogged,
        props: {'count': severities.length, 'phase': _phase},
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> setWaterGoal(int ml) async {
    await repo.setWaterGoalMl(ml);
    waterGoalMl.value = repo.waterGoalMl;
  }

  Map<String, double> symptomAverages({int days = 30}) =>
      repo.symptomAverages(days: days);
}
