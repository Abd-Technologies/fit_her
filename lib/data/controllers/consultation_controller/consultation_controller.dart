import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';
import '../../Repos/home_repo/home_repo.dart';
import '../../models/consultation/dietitian_availability.dart';
import '../../models/consultation/pre_consultation_profile.dart';
import '../../models/consultation/upcoming_appointment.dart';

/// Result of [ConsultationController.bookConsultation]. See that method's
/// doc comment for what `appointmentId` means for reschedule callers.
class BookConsultationOutcome {
  final bool ok;
  final int? appointmentId;
  const BookConsultationOutcome({required this.ok, this.appointmentId});
}

/// Glue between the consultation-flow pop-ups (Phase 2C) and the new
/// Phase 1B endpoints. Kept thin: each method is one network call +
/// envelope-aware result. Heavier UX state (in-flight submission flags,
/// optimistic state) lives inside the sheets that own it.
class ConsultationController extends GetxController {
  final HomeRepo homeRepo;
  final SharedPreferences sharedPreferences;

  ConsultationController({
    required this.homeRepo,
    required this.sharedPreferences,
  });

  String get _token =>
      sharedPreferences.getString(Constants.accessToken) ?? '';

  // ── Pre-consultation profile ─────────────────────────────────────────

  /// Loads the user's pre-consultation profile (creates an empty draft
  /// row server-side on first call). Returns null on any failure — the
  /// form sheets fall back to a fresh blank state in that case.
  Future<PreConsultationProfile?> loadProfile() async {
    try {
      final response = await homeRepo.getPreConsultationProfile(
        accessToken: _token,
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

  /// Per-step PATCH (Decision 5). Returns true on `status:"1"`. The
  /// caller passes the partial body — controller doesn't second-guess
  /// what fields belong to the current step.
  // ── Life stage (signup step 5) ───────────────────────────────────────
  // Returns the backend's { status, access, availableFrom, babyBirthDate,
  // deliveryType, waitDays } or null on failure. access is one of:
  // full | pregnant | needs_details | waiting | needs_clearance.

  /// Steps of the pre-consultation form she still has to answer
  /// (server decides, see helper/preConsultRequirements.js).
  Future<Map<String, dynamic>?> getPreConsultRequirements(String planType) async {
    try {
      final r = await homeRepo.getPreConsultRequirements(
          accessToken: _token, planType: planType);
      final parsed = r.body is String ? jsonDecode(r.body) : r.body;
      if (parsed is Map && parsed['status'] == '1' && parsed['data'] is Map) {
        return Map<String, dynamic>.from(parsed['data']);
      }
    } catch (e) {
      debugPrint('[preConsult] requirements: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getLifeStage() async {
    try {
      final r = await homeRepo.getLifeStage(accessToken: _token);
      final parsed = r.body is String ? jsonDecode(r.body) : r.body;
      if (parsed is Map && parsed['status'] == '1' && parsed['data'] is Map) {
        return Map<String, dynamic>.from(parsed['data']);
      }
    } catch (e) {
      debugPrint('[lifeStage] get: $e');
    }
    return null;
  }

  /// Saves and returns the new state. On failure shows the server's
  /// message and returns null.
  Future<Map<String, dynamic>?> saveLifeStage(Map<String, dynamic> body) async {
    try {
      final r = await homeRepo.saveLifeStage(accessToken: _token, body: body);
      final parsed = r.body is String ? jsonDecode(r.body) : r.body;
      if (parsed is Map && parsed['status'] == '1' && parsed['data'] is Map) {
        return Map<String, dynamic>.from(parsed['data']);
      }
      CustomToast.failToast(
          msg: (parsed is Map ? parsed['message'] : null)?.toString() ??
              'Could not save. Please try again.');
    } catch (e) {
      debugPrint('[lifeStage] save: $e');
      CustomToast.failToast(msg: 'Could not save. Please try again.');
    }
    return null;
  }

  Future<bool> patchProfile(Map<String, dynamic> body) async {
    try {
      final response = await homeRepo.patchPreConsultationProfile(
        accessToken: _token,
        body: body,
      );
      final json = response.body;
      // apiProvider.putData returns the http.Response; body may already
      // be Map (we set application/json) or raw String — accept both.
      final parsed = json is String ? jsonDecode(json) : json;
      return parsed is Map && parsed['status'] == '1';
    } catch (_) {
      return false;
    }
  }

  // ── Popup state acks ─────────────────────────────────────────────────

  Future<void> dismissPopup(
    String variable, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await homeRepo.dismissPopup(
        accessToken: _token,
        variable: variable,
        metadata: metadata,
      );
    } catch (_) {
      // Server-side state is the source of truth for re-eligibility.
      // A failed dismiss just means the popup may show again next
      // dashboard fetch — acceptable.
    }
  }

  Future<void> completePopup(
    String variable, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await homeRepo.completePopup(
        accessToken: _token,
        variable: variable,
        metadata: metadata,
      );
    } catch (_) {
      // Completion is idempotent — controllers that perform a domain
      // action (submit review, submit progress) ALSO retire the popup
      // server-side. This call is a belt-and-braces backup.
    }
  }

  /// "Remind me tomorrow" — distinct from dismiss: doesn't touch
  /// dismissCount, just pushes eligibility forward server-side so the
  /// popup stays away for `days` instead of resurfacing on the very
  /// next dashboard reload.
  Future<void> snoozePopup(String variable, {int days = 1}) async {
    try {
      await homeRepo.snoozePopup(
        accessToken: _token,
        variable: variable,
        days: days,
      );
    } catch (_) {
      // Best-effort, same as dismiss/complete — a failed snooze just
      // means it may resurface sooner than intended, not a hard error.
    }
  }

  // ── Booking calendar ─────────────────────────────────────────────────

  /// Loads dietitian availability for the next 14 days (server-side
  /// default) or a custom range. Returns null on failure — sheet shows
  /// an inline error state instead of a stale list.
  ///
  /// `.timeout(...)` matters here specifically: this call had no bound
  /// at all before, so a stalled connection (dropped wifi mid-request,
  /// a backend restart that never sends a response, etc.) left the
  /// booking sheet's `_loading` flag stuck true forever — the ONLY
  /// widget it renders in that state is a bare spinner with no retry
  /// affordance. Bounding it means the sheet can always fall through to
  /// its "Couldn't load availability. Tap retry." state instead.
  Future<DietitianAvailability?> loadAvailability({
    required int dietitianId,
    String? from,
    String? to,
  }) async {
    debugPrint('[ConsultationController] loadAvailability start dietitianId=$dietitianId');
    try {
      final response = await homeRepo
          .getDietitianAvailability(
            accessToken: _token,
            dietitianId: dietitianId,
            from: from,
            to: to,
          )
          .timeout(const Duration(seconds: 15));
      final body = response.body;
      debugPrint('[ConsultationController] loadAvailability response status=${body is Map ? body['status'] : body.runtimeType}');
      if (body is! Map ||
          body['status'] != '1' ||
          body['data'] is! Map) {
        return null;
      }
      return DietitianAvailability.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    } catch (e) {
      debugPrint('[ConsultationController] loadAvailability failed: $e');
      return null;
    }
  }

  /// Books a consultation. `appointmentId` on success is the row that
  /// ended up holding the booking: the SAME id as `rescheduleAppointmentId`
  /// when the backend updated an existing active booking in place instead
  /// of creating a new row (see the dedup comment on the backend's
  /// createAppointment — this is what stops the dietitian's queue from
  /// accumulating duplicate "requests" for one relationship), or a fresh
  /// id on a genuinely new booking. Callers doing a reschedule compare
  /// this id against the old one to know whether there's still an old
  /// row left to clean up.
  Future<BookConsultationOutcome> bookConsultation({
    required String date,        // YYYY-MM-DD
    required int userId,
    required int dietitianId,
    required int timeSlotId,     // SlotDiet.id
    required int userPlanId,
    required String kind,        // "initial" | "followup"
    String? note,                // optional note for the dietitian
  }) async {
    try {
      final response = await homeRepo.bookConsultation(
        accessToken: _token,
        body: {
          'date': date,
          'userId': userId,
          // Backend column has the historical typo `dietitionId` (kept
          // per CLAUDE.md instruction). Don't "fix" it here.
          'dietitionId': dietitianId,
          'timeSlotId': timeSlotId,
          'userPlanId': userPlanId,
          'kind': kind,
          if (note != null && note.trim().isNotEmpty) 'message': note.trim(),
        },
      );
      final body = response.body;
      final ok = body is Map && body['status'] == '1';
      if (!ok) {
        if (body is Map) {
          CustomToast.failToast(
              msg: body['message']?.toString() ?? 'Could not book');
        }
        return const BookConsultationOutcome(ok: false);
      }
      final data = body['data'];
      final apptJson = data is Map ? data['appointment'] : null;
      final id = apptJson is Map ? (apptJson['id'] as num?)?.toInt() : null;
      return BookConsultationOutcome(ok: true, appointmentId: id);
    } catch (_) {
      CustomToast.failToast(msg: 'Could not book. Please try again.');
      return const BookConsultationOutcome(ok: false);
    }
  }

  // ── Progress submission (Day 15 / Day 30) ───────────────────────────

  /// Body must match ProgressSubmission.toJson(). Server is idempotent
  /// on (userPlanId, cycle) — re-opening the sheet overwrites the prior
  /// submission. Photos are NEVER part of this body (Section 10).
  Future<bool> submitProgress(Map<String, dynamic> body) async {
    try {
      final response = await homeRepo.submitProgress(
        accessToken: _token,
        body: body,
      );
      final responseBody = response.body;
      final ok = responseBody is Map && responseBody['status'] == '1';
      if (!ok && responseBody is Map) {
        CustomToast.failToast(
            msg: responseBody['message']?.toString() ??
                'Could not submit progress');
      }
      return ok;
    } catch (_) {
      CustomToast.failToast(msg: 'Could not submit progress.');
      return false;
    }
  }

  /// Section 9 "previous values pre-filled for comparison". Returns null
  /// on cycle 15 (no earlier checkpoint — expected) or on any failure;
  /// the sheet just shows blank fields with no "Last: ..." text in that
  /// case, same as today.
  Future<Map<String, dynamic>?> loadPreviousProgress({
    required int userPlanId,
    required int cycle,
  }) async {
    try {
      final response = await homeRepo.getPreviousProgress(
        accessToken: _token,
        userPlanId: userPlanId,
        cycle: cycle,
      );
      final body = response.body;
      if (body is! Map || body['status'] != '1') return null;
      final previous = body['data']?['previous'];
      return previous is Map ? Map<String, dynamic>.from(previous) : null;
    } catch (_) {
      return null;
    }
  }

  // ── Day 7 review ─────────────────────────────────────────────────────

  /// Submits a Day 7 review. Body must match Day7Review.toJson(). The
  /// server hook computes flagged + flagReasons (Decision 6 thresholds:
  /// adherence < 40, pain reported, severe side effects, satisfaction
  /// < 2). Client never overrides the flag. Returns true on success.
  Future<bool> submitDay7Review(Map<String, dynamic> body) async {
    try {
      final response = await homeRepo.submitDay7Review(
        accessToken: _token,
        body: body,
      );
      final responseBody = response.body;
      final ok = responseBody is Map && responseBody['status'] == '1';
      if (!ok && responseBody is Map) {
        CustomToast.failToast(
            msg: responseBody['message']?.toString() ??
                'Could not submit review');
      }
      return ok;
    } catch (_) {
      CustomToast.failToast(msg: 'Could not submit review.');
      return false;
    }
  }

  // ── Upcoming booking ("your booked consultation" card) ───────────────

  /// Cached read for `UpcomingConsultationCard`. Always refetched on
  /// `loadUpcomingAppointment()` (unlike `bookingContext`, which is
  /// cached) — status can change server-side (dietitian confirms/
  /// cancels) between visits, so a stale cache would show the wrong
  /// state.
  final Rxn<UpcomingAppointment> upcomingAppointment =
      Rxn<UpcomingAppointment>();
  final RxBool isUpcomingAppointmentLoading = false.obs;

  Future<void> loadUpcomingAppointment() async {
    isUpcomingAppointmentLoading.value = true;
    try {
      final response = await homeRepo.getMyCurrentAppointment(
        accessToken: _token,
      );
      final body = response.body;
      if (body is Map && body['status'] == '1') {
        final data = body['data'];
        final apptJson = data is Map ? data['appointment'] : null;
        upcomingAppointment.value = apptJson is Map
            ? UpcomingAppointment.fromJson(
                Map<String, dynamic>.from(apptJson))
            : null;
      }
    } catch (_) {
      // Leave whatever was cached — a transient failure here shouldn't
      // wipe a card the user was already looking at.
    } finally {
      isUpcomingAppointmentLoading.value = false;
    }
  }

  /// Cancels the user's own booking. Returns true on success and clears
  /// the cached card immediately so the UI doesn't have to wait on a
  /// refetch to reflect it.
  Future<bool> cancelAppointment(int appointmentId) async {
    try {
      final response = await homeRepo.cancelMyAppointment(
        accessToken: _token,
        appointmentId: appointmentId,
      );
      final body = response.body;
      final ok = body is Map && body['status'] == '1';
      if (ok) {
        upcomingAppointment.value = null;
      } else if (body is Map) {
        CustomToast.failToast(
            msg: body['message']?.toString() ?? 'Could not cancel');
      }
      return ok;
    } catch (_) {
      CustomToast.failToast(msg: 'Could not cancel. Please try again.');
      return false;
    }
  }

  // ── Escalations ──────────────────────────────────────────────────────

  /// User self-reports a medical concern (FAB / popup CTA). Opens a
  /// MEDICAL escalation server-side which fans out to admin + dietitian.
  Future<bool> openMedicalConcern({
    String? description,
    int? severity,
  }) async {
    try {
      final response = await homeRepo.openEscalation(
        accessToken: _token,
        trigger: 'MEDICAL',
        severity: severity != null && severity >= 4 ? 'high' : 'medium',
        payload: {
          if (description != null) 'description': description,
          if (severity != null) 'severity': severity,
        },
      );
      final body = response.body;
      final ok = body is Map && body['status'] == '1';
      if (!ok) {
        CustomToast.failToast(msg: 'Could not send. Please try again.');
      }
      return ok;
    } catch (_) {
      CustomToast.failToast(msg: 'Could not send. Please try again.');
      return false;
    }
  }

  /// User self-reports their plan is delayed past Day 3. Opens a
  /// PLAN_DELAYED escalation; backend already auto-creates one when the
  /// SLA breach is detected, so this is the user-driven path.
  Future<bool> reportPlanDelayed({String? reason}) async {
    try {
      final response = await homeRepo.openEscalation(
        accessToken: _token,
        trigger: 'PLAN_DELAYED',
        severity: 'medium',
        payload: {
          if (reason != null) 'reason': reason,
        },
      );
      return response.body is Map && response.body['status'] == '1';
    } catch (_) {
      return false;
    }
  }

  /// Reports the dietitian didn't show up at the consultation slot.
  Future<bool> reportConsultantNoShow({
    required int appointmentId,
    String? reason,
  }) async {
    try {
      final response = await homeRepo.reportConsultationNoShow(
        accessToken: _token,
        appointmentId: appointmentId,
        reason: reason,
      );
      return response.body is Map && response.body['status'] == '1';
    } catch (_) {
      return false;
    }
  }
}
