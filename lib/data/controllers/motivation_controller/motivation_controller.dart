import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helper/analytics_helper.dart';
import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';
import '../../Repos/home_repo/home_repo.dart';
import '../../GetServices/CheckConnectionService.dart';
import '../../models/api_response/api_response_model.dart';
import '../../models/motivation_stats/motivation_stats_model.dart';
import '../home_controller/home_controller.dart';

class MotivationController extends GetxController implements GetxService {
  final SharedPreferences sharedPreferences;
  final HomeRepo homeRepo;

  MotivationController(
      {required this.sharedPreferences, required this.homeRepo});

  final CheckConnectionService connectionService = CheckConnectionService();

  /// Loading states
  final isLoadingStats = false.obs;
  final isMarkingAttendance = false.obs;

  /// Data
  final motivationStats = Rxn<MotivationStatsData>();

  Future<void> fetchMotivationStats() async {
    isLoadingStats.value = true;
    final hasInternet = await connectionService.checkConnection();
    if (!hasInternet) {
      CustomToast.noInternetToast();
      isLoadingStats.value = false;
      return;
    }

    try {
      final String accessToken =
          sharedPreferences.getString(Constants.accessToken) ?? "";
      final String userId = sharedPreferences.getString(Constants.userId) ?? "";

      final response = await homeRepo.getMotivationStats(
          accessToken: accessToken, userId: userId);

      if (response.body["status"] == "0") {
        CustomToast.failToast(
            msg: response.body["message"] ?? "Failed to fetch stats");
      } else {
        // Parse the response using the model
        final ApiResponse<MotivationStatsData> model =
            ApiResponse.fromJson(response.body, MotivationStatsData.fromJson);

        if (model.status == "1") {
          motivationStats.value = model.data;
        }
      }
    } catch (e) {
      CustomToast.failToast(msg: e.toString());
    } finally {
      isLoadingStats.value = false;
    }
  }

  Future<void> markAttendance({String? slotId}) async {
    isMarkingAttendance.value = true;
    final hasInternet = await connectionService.checkConnection();
    if (!hasInternet) {
      CustomToast.noInternetToast();
      isMarkingAttendance.value = false;
      return;
    }

    try {
      final String accessToken =
          sharedPreferences.getString(Constants.accessToken) ?? "";
      final String userId = sharedPreferences.getString(Constants.userId) ?? "";
      final Map<String, dynamic> body = {
        if (slotId != null) "slotId": slotId,
      };

      final response = await homeRepo.markMotivationAttendance(
          accessToken: accessToken, userId: userId, map: body);

      if (response.body["status"] == "0") {
        CustomToast.failToast(
            msg: response.body["message"] ?? "Attendance not marked");
      } else {
        CustomToast.successToast(msg: "Attendance marked");
        // Track weekly attendance in Mixpanel
        await AnalyticsHelper.trackWeeklyAttendance(slotId: slotId);
        // Refresh stats after marking attendance
        //  await fetchMotivationStats();
      }
    } catch (e) {
      CustomToast.failToast(msg: e.toString());
    } finally {
      isMarkingAttendance.value = false;
    }
  }

  DateTime? _classJoinedAt;

  Future<void> classPresenceJoin({
    required String slotId,
    String? meetingNumber,
    String? className,
    String? trainerName,
    String? scheduledStartTime,
  }) async {
    _classJoinedAt = DateTime.now();

    final homeController =
        Get.isRegistered<HomeController>() ? Get.find<HomeController>() : null;
    final isTrial = homeController?.isFreeTrialUser.value ?? false;
    final userTier = isTrial ? 'free_trial' : 'paid';

    int? delayMinutes;
    if (scheduledStartTime != null && scheduledStartTime.isNotEmpty) {
      try {
        final now = DateTime.now();
        final parsed = DateFormat('h:mm a').parse(scheduledStartTime.trim());
        final scheduledToday =
            DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
        delayMinutes = now.difference(scheduledToday).inMinutes;
      } catch (_) {}
    }

    // Fire Mixpanel event for class join
    await AnalyticsHelper.trackWorkoutClassJoined(
      slotId: slotId,
      className: className,
      trainerName: trainerName,
      userTier: userTier,
      scheduledStartTime: scheduledStartTime,
      delayFromScheduleMinutes: delayMinutes,
      source: meetingNumber != null ? 'zoom_native' : 'https_url',
    );

    final accessToken =
        sharedPreferences.getString(Constants.accessToken) ?? "";
    if (accessToken.isEmpty) return;

    try {
      await homeRepo.classPresenceJoin(
        accessToken: accessToken,
        map: {
          "slotId": slotId,
          if (meetingNumber != null && meetingNumber.isNotEmpty)
            "meetingNumber": meetingNumber,
          "source": "zoom_native",
        },
      );
    } catch (_) {
      // Presence reporting is best-effort and should never block class entry.
    }
  }

  Future<void> classPresenceLeave({
    required String slotId,
    String? meetingNumber,
    String? className,
    String? trainerName,
    String? exitReason,
  }) async {
    final now = DateTime.now();
    int? durationMinutes;
    int? durationSeconds;

    if (_classJoinedAt != null) {
      durationSeconds = now.difference(_classJoinedAt!).inSeconds;
      durationMinutes = (durationSeconds / 60).round();
      _classJoinedAt = null;
    }

    final homeController =
        Get.isRegistered<HomeController>() ? Get.find<HomeController>() : null;
    final isTrial = homeController?.isFreeTrialUser.value ?? false;
    final userTier = isTrial ? 'free_trial' : 'paid';

    // Fire Mixpanel event for class leave with duration
    await AnalyticsHelper.trackWorkoutClassLeft(
      slotId: slotId,
      className: className,
      trainerName: trainerName,
      userTier: userTier,
      durationMinutes: durationMinutes,
      durationSeconds: durationSeconds,
      exitReason: exitReason ?? 'completed',
    );

    final accessToken =
        sharedPreferences.getString(Constants.accessToken) ?? "";
    if (accessToken.isEmpty) return;

    try {
      final response = await homeRepo.classPresenceLeave(
        accessToken: accessToken,
        map: {
          "slotId": slotId,
          if (meetingNumber != null && meetingNumber.isNotEmpty)
            "meetingNumber": meetingNumber,
          "source": "zoom_native",
        },
      );
      final body = response.body;
      final data = body is Map ? body["data"] : null;
      final trialAttendance = data is Map ? data["trialAttendance"] : null;
      final marked =
          trialAttendance is Map && trialAttendance["marked"] == true;
      if (marked && Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().getMyTrialJourney();
      }
    } catch (_) {
      // Presence reporting is best-effort and should stay silent on failure.
    }
  }

  // Getters for easy access to stats data
  int get streak => motivationStats.value?.streak ?? 0;
  int get daysAttendedLast7 => motivationStats.value?.daysAttendedLast7 ?? 0;
  int get daysAttendedLast30 => motivationStats.value?.daysAttendedLast30 ?? 0;
  int get regularityPercentage =>
      motivationStats.value?.regularityPercentage ?? 0;
  List<AttendanceHistoryItem> get attendanceHistory =>
      motivationStats.value?.attendanceHistory ?? [];
}
