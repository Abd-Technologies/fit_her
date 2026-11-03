import 'package:get/get.dart';

import '../../../values/constants.dart';
import '../../api_provider/api_provider.dart';
import '../../models/diet_plan_v2/day7_review_model.dart';
import '../../models/diet_plan_v2/diet_plan_v2_models.dart';
import '../../models/diet_plan_v2/meal_log_v2.dart';
import 'diet_plan_admin_repository.dart' show DietPlanApiException;

/// User-side diet-plan endpoints. Phase F (consumer-facing surfaces)
/// will consume these; created here so the data layer is finished in
/// one shot rather than dripping into Phase F.
///
/// Mirrors `partner_backend/routes/FrontSite/dietPlan.js`:
///   GET    /users/diet-plan/me/active
///   PATCH  /users/diet-plan/me/timezone
class DietPlanUserRepository extends GetxService {
  final ApiProvider apiProvider;
  DietPlanUserRepository({required this.apiProvider});

  Map<String, String> _headers(String accessToken) => {
        'accessToken': accessToken,
      };

  /// Returns the user's active diet plan, or `null` when she has none.
  /// The backend distinguishes "no active plan" (status: "1", data:
  /// { dietPlan: null }) from a real failure — callers should NOT
  /// treat null as an error.
  Future<DietPlanV2?> getMyActivePlan({required String accessToken}) async {
    final res = await _safe(() => apiProvider.getData(
          Constants.dietPlanUserActive,
          headers: _headers(accessToken),
        ));
    final data = _expectOk(res);
    final raw = data['dietPlan'];
    if (raw == null) return null;
    if (raw is! Map) {
      throw DietPlanApiException('Server response missing dietPlan');
    }
    return DietPlanV2.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Phase F.2 — fetch every MealLog row for the given local date so
  /// the meal cards can render their per-meal status indicators on
  /// first paint. Backend route: GET /users/meal-logs?from=&to=
  /// (existing endpoint; ENUM was extended in migration 20260508120000).
  Future<List<MealLogV2>> getMealLogsForDate({
    required String accessToken,
    required String dateYYYYMMDD,
  }) async {
    final res = await _safe(() => apiProvider.getData(
          Constants.mealLogs,
          query: {'from': dateYYYYMMDD, 'to': dateYYYYMMDD},
          headers: _headers(accessToken),
        ));
    final data = _expectOk(res);
    final raw = data['mealLogs'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => MealLogV2.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Phase F.2 — upsert today's log for one meal slot. Mirrors the
  /// existing `MealLogController.upsertToday` shape but uses string
  /// `mealType` (the V2 wire format covers all 6 ENUM values whereas
  /// the legacy MealLogController is locked to 3). Backend hostname
  /// matches POST /users/meal-logs.
  Future<MealLogV2> upsertMealLog({
    required String accessToken,
    required String dateYYYYMMDD,
    required String mealTypeWire,
    required MealLogStatusV2 status,
    String? alternativeText,
    String? reasonCode,
    int? dietPlanMealId,
  }) async {
    final body = <String, dynamic>{
      'date': dateYYYYMMDD,
      'mealType': mealTypeWire,
      'status': mealLogStatusV2ToString(status),
    };
    if (alternativeText != null && alternativeText.isNotEmpty) {
      body['alternativeText'] = alternativeText;
    }
    if (reasonCode != null && reasonCode.isNotEmpty) {
      body['reasonCode'] = reasonCode;
    }
    if (dietPlanMealId != null) {
      body['dietPlanMealId'] = dietPlanMealId;
    }
    final res = await _safe(() => apiProvider.postData(
          Constants.mealLogs,
          body: body,
          headers: _headers(accessToken),
        ));
    final data = _expectOk(res);
    final raw = data['mealLog'];
    if (raw is! Map) {
      throw DietPlanApiException('Server response missing mealLog');
    }
    return MealLogV2.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Phase G.3 — submit a Day 7 check-in. Backend hooks compute
  /// `flagged` + `flagReasons` from the row contents (severe side
  /// effects, low adherence, etc.) and may open an EscalationTicket.
  /// Server-side popup state for `POPUP_DAY7_REVIEW` is also stamped
  /// `completedAt` so the same cycle can't be submitted twice.
  Future<Day7Review> submitDay7Review({
    required String accessToken,
    required Day7ReviewSubmission submission,
  }) async {
    final res = await _safe(() => apiProvider.postData(
          Constants.day7Review,
          body: submission.toJson(),
          headers: _headers(accessToken),
        ));
    final data = _expectOk(res);
    final raw = data['review'];
    if (raw is! Map) {
      throw DietPlanApiException('Server response missing review');
    }
    return Day7Review.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Phase G.3 — record a popup dismissal. Increments dismissCount on
  /// the server side without retiring the popup; the eligibility helper
  /// decides when too many dismissals = "stop nagging this cycle".
  /// Uses the existing `popupAck` base path documented in
  /// values/constants.dart (`/users/popup` + `/{variable}/dismiss`).
  Future<void> dismissPopup({
    required String accessToken,
    required String popupVariable,
  }) async {
    final path = '${Constants.popupAck}/$popupVariable/dismiss';
    final res = await _safe(() => apiProvider.postData(
          path,
          body: const <String, dynamic>{},
          headers: _headers(accessToken),
        ));
    _expectOk(res);
  }

  /// IANA name like "Asia/Karachi". Backend writes to `User.timeZone`
  /// (camelCase column) — see Phase B notes. Use [Intl] / system tz as
  /// the source.
  Future<void> updateMyTimezone({
    required String accessToken,
    required String timezone,
  }) async {
    final res = await _safe(() => apiProvider.patchData(
          Constants.dietPlanUserTimezone,
          body: {'timezone': timezone},
          headers: _headers(accessToken),
        ));
    _expectOk(res);
  }

  /// Phase F.3 — fetch the IDs the empty-state CTA needs to open
  /// `BookConsultationSheet.show(...)`. Returns a struct with nullable
  /// IDs — caller falls back to OurPlansScreen when userPlanId/
  /// dietitianId is null.
  Future<BookingContextV2> getBookingContext(
      {required String accessToken}) async {
    final res = await _safe(() => apiProvider.getData(
          Constants.dietPlanUserBookingContext,
          headers: _headers(accessToken),
        ));
    final data = _expectOk(res);
    return BookingContextV2(
      userId: _toInt(data['userId']),
      userPlanId: _toInt(data['userPlanId']),
      dietitianId: _toInt(data['dietitianId']),
      hasActivePlan: data['hasActivePlan'] == true,
      bookingLocked: data['bookingLocked'] == true,
      lateChangeAvailable: data['lateChangeAvailable'] != false,
      packageEndsOn: DateTime.tryParse('${data['packageEndsOn'] ?? ''}')?.toLocal(),
      halfwayOpensOn: DateTime.tryParse('${data['halfwayOpensOn'] ?? ''}')?.toLocal(),
      nextStep: data['nextStep']?.toString(),
      planEnded: data['planEnded'] == true,
      planEndedOn: DateTime.tryParse('${data['planEndedOn'] ?? ''}')?.toLocal(),
      planPreparing: data['planPreparing'] is Map
          ? PlanPreparingV2.fromJson(
              Map<String, dynamic>.from(data['planPreparing'] as Map))
          : null,
    );
  }

  // ─── Internals (mirrors admin repo to keep error shape identical) ──────

  Future<Response> _safe(Future<Response> Function() fn) async {
    try {
      return await fn();
    } on DietPlanApiException {
      rethrow;
    } catch (_) {
      throw DietPlanApiException(
        'Network error — check your connection and try again',
      );
    }
  }

  Map<String, dynamic> _expectOk(Response res) {
    final body = res.body;
    if (body is! Map) {
      throw DietPlanApiException(
        'Unexpected server response',
        statusCode: res.statusCode,
      );
    }
    if (body['status']?.toString() != '1') {
      throw DietPlanApiException(
        body['message']?.toString() ?? 'Request failed',
        statusCode: res.statusCode,
      );
    }
    final data = body['data'];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }
}

/// Phase F.3 — booking-context payload from
/// `GET /users/diet-plan/me/booking-context`. Every field is nullable
/// because a brand-new user may have neither a UserPlan nor an
/// Appointment yet — the caller checks `canBook` to decide whether to
/// open the booking sheet or fall back to the paywall.
class BookingContextV2 {
  final int? userId;
  final int? userPlanId;
  final int? dietitianId;
  final bool hasActivePlan;

  /// Set only between "consultation completed" and "plan delivered".
  /// Drives the "your plan is being prepared" card.
  final PlanPreparingV2? planPreparing;

  const BookingContextV2({
    this.userId,
    this.userPlanId,
    this.dietitianId,
    this.hasActivePlan = false,
    this.bookingLocked = false,
    this.lateChangeAvailable = true,
    this.packageEndsOn,
    this.halfwayOpensOn,
    this.nextStep,
    this.planEnded = false,
    this.planEndedOn,
    this.planPreparing,
  });

  /// Her paid plan has ended (no live plan). She still sees her meal
  /// plan (read-only); booking and classes need a renewal.
  final bool planEnded;
  final DateTime? planEndedOn;

  /// What she should do next when a plan ends (server decides, so the
  /// app never offers a button the server would refuse): explore_plans,
  /// renew, locked, book_initial, day15_checkin, book_followup,
  /// followup_booked. Null on older backends.
  final String? nextStep;

  /// Self-booking is locked for this package (second missed session).
  /// Booking entry points show BookingLockedSheet instead.
  final bool bookingLocked;

  /// Her one free late change (cancel or miss inside 24 h) on this
  /// package is still unused. Once used, a session inside 24 h can't be
  /// cancelled. Oct 2026. True on older backends.
  final bool lateChangeAvailable;

  /// When her package (UserPlan) ends. Oct 2026.
  final DateTime? packageEndsOn;

  /// When the halfway check-in that unlocks the follow-up opens (only
  /// while nextStep == day15_checkin). Oct 2026.
  final DateTime? halfwayOpensOn;

  /// True when we have everything `BookConsultationSheet.show(...)`
  /// requires. False → caller routes to OurPlansScreen instead.
  bool get canBook =>
      userId != null &&
      userPlanId != null &&
      dietitianId != null &&
      !planEnded &&
      nextStep != 'renew';
}

/// The client has had her consultation and her plan is being built.
/// The plan is due 48 hours after the consultation ends; `delayed`
/// flips true once that has passed without delivery.
class PlanPreparingV2 {
  final DateTime? consultationDoneAt;
  final DateTime? dueAt;
  final bool delayed;
  final int? dietitianId;
  final String? dietitianName;

  const PlanPreparingV2({
    this.consultationDoneAt,
    this.dueAt,
    this.delayed = false,
    this.dietitianId,
    this.dietitianName,
  });

  factory PlanPreparingV2.fromJson(Map<String, dynamic> j) => PlanPreparingV2(
        consultationDoneAt: j['consultationDoneAt'] == null
            ? null
            : DateTime.tryParse(j['consultationDoneAt'].toString())?.toLocal(),
        dueAt: j['dueAt'] == null
            ? null
            : DateTime.tryParse(j['dueAt'].toString())?.toLocal(),
        delayed: j['delayed'] == true,
        dietitianId: _toInt(j['dietitianId']),
        dietitianName: j['dietitianName']?.toString(),
      );
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
