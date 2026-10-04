import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/app_clock.dart';
import '../../../values/constants.dart';
import '../../Repos/checkin_repo/checkin_repository.dart';
import '../../Repos/home_repo/home_repo.dart';
import '../../models/home_dashboard/home_dashboard_model.dart';
import '../cycle_theme_controller/cycle_theme_controller.dart';

/// Owns the reactive state for PaidHomeScreenV2. One call to loadDashboard()
/// populates `dashboard`. UI reads via Obx / GetBuilder / dashboard.value.
/// Errors are surfaced through `errorMessage` — never thrown to the UI.
class PaidHomeController extends GetxController {
  final HomeRepo homeRepo;
  final CheckinRepository checkinRepo;
  final SharedPreferences sharedPreferences;

  PaidHomeController({
    required this.homeRepo,
    required this.checkinRepo,
    required this.sharedPreferences,
  });

  final Rx<HomeDashboardModel?> dashboard = Rx<HomeDashboardModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isSavingMood = false.obs;
  final RxBool isLoggingWater = false.obs;
  final RxBool isSavingSleep = false.obs;
  final RxBool isSavingWeight = false.obs;
  final RxBool isSavingTargetWeight = false.obs;
  final RxBool isSavingMainGoal = false.obs;
  final RxString errorMessage = ''.obs;

  Future<void> loadDashboard() async {
    // Guard against re-entrant calls (e.g., rapid pull-to-refresh).
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final result = await homeRepo.getPaidHomeDashboard();
      if (result != null) {
        dashboard.value = result;
        // Push phase to the global theme controller so every screen updates.
        try {
          Get.find<CycleThemeController>().setPhase(result.cycle?.phase);
        } catch (_) {}
      } else {
        errorMessage.value = 'Could not load dashboard';
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
      debugPrint('[PaidHomeController] $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshDashboard() => loadDashboard();

  /// Heartbeat-friendly refresh. Skips the [isLoading] toggle so polling
  /// timers don't fight pull-to-refresh, and never overwrites the
  /// existing [dashboard] with `null` on transient failures. Returns
  /// true on a successful payload — UI uses that to drive the
  /// "Reconnecting…" banner.
  Future<bool> silentRefresh() async {
    try {
      final result = await homeRepo.getPaidHomeDashboard();
      if (result == null) return false;
      dashboard.value = result;
      return true;
    } catch (e) {
      debugPrint('[PaidHomeController.silentRefresh] $e');
      return false;
    }
  }

  /// Persists today's mood via the existing CheckinRepository (upsert on
  /// `(userId, today)` server-side). On success refetches the dashboard so
  /// `todayCheckin.moodLevel` reflects the new value. Returns true on
  /// success, false on any failure (widget reverts optimistic UI + shows
  /// a SnackBar).
  Future<bool> logMood(int moodLevel) async {
    // Simple in-flight guard — ignore rapid double taps.
    if (isSavingMood.value) return false;
    isSavingMood.value = true;
    try {
      final token =
          sharedPreferences.getString(Constants.accessToken) ?? '';
      if (token.isEmpty) {
        errorMessage.value = 'Not logged in';
        return false;
      }
      final response = await checkinRepo.saveDailyCheckin(
        accessToken: token,
        body: {
          'date': _todayLocalDateOnly(),
          'moodLevel': moodLevel,
        },
      );
      final body = response.body;
      if (body is Map && body['status'] == '1') {
        // Refetch so the single source of truth (`dashboard`) carries the
        // updated moodLevel — keeps future builds consistent without
        // duplicating model-construction logic.
        await loadDashboard();
        return true;
      }
      errorMessage.value = 'Could not save mood';
      return false;
    } catch (e) {
      errorMessage.value = 'Error: $e';
      debugPrint('[PaidHomeController.logMood] $e');
      return false;
    } finally {
      isSavingMood.value = false;
    }
  }

  String _todayLocalDateOnly() {
    // Server-anchored: a drifted device clock would otherwise persist
    // checkins under the wrong date and they'd vanish from the dashboard
    // once the device clock corrected itself.
    final now = AppClock.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Logs a water intake for today, then refetches the dashboard so
  /// `hydration.consumedMl` / `remainingMl` reflect the new total.
  /// Returns true on success, false on any failure.
  /// Undo her last water tap (home card "Undo").
  Future<bool> undoLastWater() async {
    if (isLoggingWater.value) return false;
    isLoggingWater.value = true;
    try {
      final ok = await homeRepo.undoLastWater();
      if (ok) await loadDashboard();
      return ok;
    } catch (e) {
      debugPrint('[PaidHomeController.undoLastWater] $e');
      return false;
    } finally {
      isLoggingWater.value = false;
    }
  }

  Future<bool> logWater(int amountMl) async {
    if (isLoggingWater.value) return false;
    isLoggingWater.value = true;
    try {
      final success = await homeRepo.logWater(amountMl);
      if (success) {
        await loadDashboard();
        return true;
      }
      errorMessage.value = 'Could not log water';
      return false;
    } catch (e) {
      errorMessage.value = 'Error: $e';
      debugPrint('[PaidHomeController.logWater] $e');
      return false;
    } finally {
      isLoggingWater.value = false;
    }
  }

  /// Upsert this week's weight. Refetches dashboard so `startingWeightKg`,
  /// `currentWeightKg`, `lostKg`, and `isWeighInDue` all reflect the new row.
  Future<bool> logWeight(double kg) async {
    if (isSavingWeight.value) return false;
    isSavingWeight.value = true;
    try {
      final success = await homeRepo.logWeight(kg);
      if (success) {
        await loadDashboard();
        return true;
      }
      errorMessage.value = 'Could not save weight';
      return false;
    } catch (e) {
      errorMessage.value = 'Error: $e';
      debugPrint('[PaidHomeController.logWeight] $e');
      return false;
    } finally {
      isSavingWeight.value = false;
    }
  }

  /// Set (or clear with null) the user's target weight. Refetches dashboard
  /// so the stats card can flip from "Set a goal →" to the progress state.
  Future<bool> saveTargetWeight(
    double? kg, {
    String? weightGoalDirection,
    bool includeDirection = false,
  }) async {
    if (isSavingTargetWeight.value) return false;
    isSavingTargetWeight.value = true;
    try {
      final success = await homeRepo.saveTargetWeight(
        kg,
        weightGoalDirection: weightGoalDirection,
        includeDirection: includeDirection,
      );
      if (success) {
        await loadDashboard();
        return true;
      }
      errorMessage.value = 'Could not save goal';
      return false;
    } catch (e) {
      errorMessage.value = 'Error: $e';
      debugPrint('[PaidHomeController.saveTargetWeight] $e');
      return false;
    } finally {
      isSavingTargetWeight.value = false;
    }
  }

  /// Set/update the signup goal category (Lose weight / Build strength &
  /// tone / etc.) via the PaidHero "Set goal →" chip. Refetches dashboard
  /// so the chip flips from "Set goal →" to the chosen goal's label.
  Future<bool> saveMainGoal(String goal) async {
    if (isSavingMainGoal.value) return false;
    isSavingMainGoal.value = true;
    try {
      final success = await homeRepo.saveMainGoal(goal);
      if (success) {
        await loadDashboard();
        return true;
      }
      errorMessage.value = 'Could not save goal';
      return false;
    } catch (e) {
      errorMessage.value = 'Error: $e';
      debugPrint('[PaidHomeController.saveMainGoal] $e');
      return false;
    } finally {
      isSavingMainGoal.value = false;
    }
  }

  /// Logs sleep hours for today via the same DailyCheckin upsert used by
  /// logMood — partial body `{date, sleepHours}` leaves moodLevel and
  /// every other field on the row untouched. Refetches the dashboard on
  /// success so the sleep card reflects the new value + (eventually) a
  /// recomputed week delta.
  Future<bool> logSleep(double hours) async {
    if (isSavingSleep.value) return false;
    isSavingSleep.value = true;
    try {
      final token =
          sharedPreferences.getString(Constants.accessToken) ?? '';
      if (token.isEmpty) {
        errorMessage.value = 'Not logged in';
        return false;
      }
      final response = await checkinRepo.saveDailyCheckin(
        accessToken: token,
        body: {
          'date': _todayLocalDateOnly(),
          'sleepHours': hours,
        },
      );
      final body = response.body;
      if (body is Map && body['status'] == '1') {
        await loadDashboard();
        return true;
      }
      errorMessage.value = 'Could not save sleep';
      return false;
    } catch (e) {
      errorMessage.value = 'Error: $e';
      debugPrint('[PaidHomeController.logSleep] $e');
      return false;
    } finally {
      isSavingSleep.value = false;
    }
  }
}
