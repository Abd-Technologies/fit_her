import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';
import '../../Repos/home_repo/home_repo.dart';
import '../../models/consultation/day7_review.dart';
import '../../models/consultation/escalation_ticket.dart';
import '../../models/consultation/pre_consultation_profile.dart';
import '../../models/consultation/progress_submission.dart';

/// Drives the dietitian/admin-side surfaces (Phase 3-4). Admin auth on
/// the backend allows any non-User userType (Dietition, Admin,
/// Trainer, Gynecologist, Psychiatrist) — this controller doesn't try
/// to restrict further; callers compose their own role-aware UI.
class DietitianDashboardController extends GetxController {
  final HomeRepo homeRepo;
  final SharedPreferences sharedPreferences;

  DietitianDashboardController({
    required this.homeRepo,
    required this.sharedPreferences,
  });

  String get _token =>
      sharedPreferences.getString(Constants.accessToken) ?? '';

  // ── Pre-consultation profile (per-client) ──────────────────────────

  Future<PreConsultationProfile?> loadClientProfile(int userId) async {
    try {
      final response = await homeRepo.adminGetPreConsultationProfile(
        accessToken: _token,
        userId: userId,
      );
      final body = response.body;
      if (body is! Map ||
          body['status'] != '1' ||
          body['data']?['profile'] is! Map) {
        return null;
      }
      return PreConsultationProfile.fromJson(
        Map<String, dynamic>.from(body['data']['profile'] as Map),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns the raw profile JSON so the caller can pull the private
  /// `dietitianComments` array (which the user-side model strips).
  /// Last-7-days meal logging for one client: a list of
  /// {date, planned, followed, alternative, skipped, logged}, oldest
  /// first. Null on any failure (caller shows its own error state).
  Future<List<Map<String, dynamic>>?> loadClientMealActivity(int userId,
      {int days = 7}) async {
    try {
      final response = await homeRepo.adminGetClientMealActivity(
        accessToken: _token,
        userId: userId,
        days: days,
      );
      final body = response.body;
      if (body is! Map ||
          body['status'] != '1' ||
          body['data']?['days'] is! List) {
        return null;
      }
      return (body['data']['days'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> loadClientProfileRaw(int userId) async {
    try {
      final response = await homeRepo.adminGetPreConsultationProfile(
        accessToken: _token,
        userId: userId,
      );
      final body = response.body;
      if (body is! Map ||
          body['status'] != '1' ||
          body['data']?['profile'] is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(body['data']['profile'] as Map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> patchClientProfile({
    required int userId,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await homeRepo.adminPatchPreConsultationProfile(
        accessToken: _token,
        userId: userId,
        body: body,
      );
      final responseBody = response.body;
      final ok = responseBody is Map && responseBody['status'] == '1';
      if (!ok) {
        CustomToast.failToast(msg: 'Could not save changes');
      }
      return ok;
    } catch (_) {
      CustomToast.failToast(msg: 'Could not save changes');
      return false;
    }
  }

  Future<bool> addClientComment({
    required int userId,
    required String text,
  }) async {
    try {
      final response = await homeRepo.adminAddPreConsultationComment(
        accessToken: _token,
        userId: userId,
        text: text,
      );
      final responseBody = response.body;
      final ok = responseBody is Map && responseBody['status'] == '1';
      if (!ok) {
        CustomToast.failToast(msg: 'Could not add comment');
      }
      return ok;
    } catch (_) {
      CustomToast.failToast(msg: 'Could not add comment');
      return false;
    }
  }

  // ── Day 7 reviews ──────────────────────────────────────────────────

  /// `flagged=true` → admin flagged-queue. `userId` set → per-client
  /// review history. Both null → all reviews (admin firehose).
  Future<List<Day7Review>> loadReviews({
    bool? flagged,
    int? userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await homeRepo.adminListDay7Reviews(
        accessToken: _token,
        flagged: flagged,
        userId: userId,
        limit: limit,
        offset: offset,
      );
      final body = response.body;
      if (body is! Map ||
          body['status'] != '1' ||
          body['data']?['reviews'] is! List) {
        return const [];
      }
      return (body['data']['reviews'] as List)
          .whereType<Map>()
          .map((m) => Day7Review.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Progress submissions ───────────────────────────────────────────

  Future<List<ProgressSubmission>> loadClientProgress(int userId) async {
    try {
      final response = await homeRepo.adminGetUserProgress(
        accessToken: _token,
        userId: userId,
      );
      final body = response.body;
      if (body is! Map ||
          body['status'] != '1' ||
          body['data']?['progressSubmissions'] is! List) {
        return const [];
      }
      return (body['data']['progressSubmissions'] as List)
          .whereType<Map>()
          .map((m) =>
              ProgressSubmission.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Escalations queue (admin-side) ─────────────────────────────────

  Future<List<EscalationTicket>> loadEscalations({
    String? status,
    String? trigger,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await homeRepo.adminListEscalations(
        accessToken: _token,
        status: status,
        trigger: trigger,
        limit: limit,
        offset: offset,
      );
      final body = response.body;
      if (body is! Map ||
          body['status'] != '1' ||
          body['data']?['tickets'] is! List) {
        return const [];
      }
      return (body['data']['tickets'] as List)
          .whereType<Map>()
          .map((m) =>
              EscalationTicket.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> resolveEscalation({
    required int ticketId,
    String? resolutionNote,
  }) async {
    try {
      final response = await homeRepo.adminResolveEscalation(
        accessToken: _token,
        ticketId: ticketId,
        resolutionNote: resolutionNote,
      );
      final body = response.body;
      final ok = body is Map && body['status'] == '1';
      if (!ok) {
        CustomToast.failToast(msg: 'Could not resolve');
      }
      return ok;
    } catch (_) {
      CustomToast.failToast(msg: 'Could not resolve');
      return false;
    }
  }

  /// Unlocks self-booking for a client whose package was locked after a
  /// second missed session, and gives her late change back.
  Future<bool> resetBookingPass(int userPlanId) async {
    try {
      final response = await homeRepo.adminResetBookingPass(
        accessToken: _token,
        userPlanId: userPlanId,
      );
      final body = response.body;
      final ok = body is Map && body['status']?.toString() == '1';
      if (!ok) {
        CustomToast.failToast(
            msg: (body is Map ? body['message']?.toString() : null) ??
                'Could not unlock booking');
      }
      return ok;
    } catch (_) {
      CustomToast.failToast(msg: 'Could not unlock booking');
      return false;
    }
  }

  // ── Metrics overview (Section 15) ──────────────────────────────────

  /// Returns the raw `data` block from `/admin/metrics/overview` so the
  /// UI can pluck specific keys without us schema-locking too early.
  /// Each subobject is independently nullable server-side.
  Future<Map<String, dynamic>?> loadMetricsOverview() async {
    try {
      final response = await homeRepo.adminGetMetricsOverview(
        accessToken: _token,
      );
      final body = response.body;
      if (body is! Map ||
          body['status'] != '1' ||
          body['data'] is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(body['data'] as Map);
    } catch (_) {
      return null;
    }
  }
}
