import 'package:get/get.dart';
import '../data/services/analytics_service.dart';

class AnalyticsHelper {
  static final AnalyticsService _analyticsService =
      Get.find<AnalyticsService>();

  // Track app open
  static Future<void> trackAppOpen() async {
    print('AnalyticsHelper: Tracking app open');
    await _analyticsService.logAppOpen();
    print('AnalyticsHelper: App open tracked');
  }

  // Track screen views
  static Future<void> trackScreenView(String screenName) async {
    print('AnalyticsHelper: Tracking screen view: $screenName');
    await _analyticsService.logScreenView(screenName: screenName);
    print('AnalyticsHelper: Screen view tracked: $screenName');
  }

  // Track login events
  static Future<void> trackLogin(String method) async {
    await _analyticsService.logLogin(method: method);
  }

  // Track sign up events
  static Future<void> trackSignUp(String method) async {
    await _analyticsService.logSignUp(method: method);
  }

  // Track tutorial completion
  static Future<void> trackTutorialComplete({String? tutorialName}) async {
    await _analyticsService.logTutorialComplete(tutorialName: tutorialName);
  }

  // Track button clicks
  static Future<void> trackButtonClick(String buttonName,
      {String? screenName}) async {
    await _analyticsService.logButtonClick(
      buttonName: buttonName,
      screenName: screenName,
    );
  }

  // Track scroll activity
  static Future<void> trackScrollActivity(String screenName,
      {String? contentType, int? scrollDepth}) async {
    await _analyticsService.logScrollActivity(
      screenName: screenName,
      contentType: contentType,
      scrollDepth: scrollDepth,
    );
  }

  // Track search activity
  static Future<void> trackSearch(String searchTerm,
      {String? searchCategory, int? resultsCount}) async {
    await _analyticsService.logSearch(
      searchTerm: searchTerm,
      searchCategory: searchCategory,
      resultsCount: resultsCount,
    );
  }

  // Track class view
  static Future<void> trackClassView(String className,
      {String? classType, String? instructorName}) async {
    await _analyticsService.logClassView(
      className: className,
      classType: classType,
      instructorName: instructorName,
    );
  }

  // Track tutorial events
  static Future<void> trackTutorialEvent(
      String tutorialName, String action) async {
    await _analyticsService.logTutorialEvent(
      tutorialName: tutorialName,
      action: action,
    );
  }

  // Track subscribe click
  static Future<void> trackSubscribeClick({String? screenName}) async {
    await _analyticsService.logSubscribeClick(screenName: screenName);
  }

  // Track plan selection
  static Future<void> trackPlanSelected(String planName,
      {String? planPrice, String? planDuration}) async {
    await _analyticsService.logPlanSelected(
      planName: planName,
      planPrice: planPrice,
      planDuration: planDuration,
    );
  }

  // Track checkout begin
  static Future<void> trackBeginCheckout(String planName,
      {String? planPrice, String? currency}) async {
    await _analyticsService.logBeginCheckout(
      planName: planName,
      planPrice: planPrice,
      currency: currency,
    );
  }

  // Track payment info added
  static Future<void> trackAddPaymentInfo(String paymentType,
      {String? planName}) async {
    await _analyticsService.logAddPaymentInfo(
      paymentType: paymentType,
      planName: planName,
    );
  }

  // Track successful purchase
  static Future<void> trackPurchase(String planName, String planPrice,
      {String? currency, String? transactionId}) async {
    await _analyticsService.logPurchase(
      planName: planName,
      planPrice: planPrice,
      currency: currency,
      transactionId: transactionId,
    );
  }

  // Track failed purchase
  static Future<void> trackPurchaseFailed(String planName,
      {String? planPrice, String? errorReason, String? paymentType}) async {
    await _analyticsService.logPurchaseFailed(
      planName: planName,
      planPrice: planPrice,
      errorReason: errorReason,
      paymentType: paymentType,
    );
  }

  // Track subscription events (legacy)
  static Future<void> trackSubscriptionEvent(String action,
      {String? planName, String? planPrice}) async {
    await _analyticsService.logSubscriptionEvent(
      action: action,
      planName: planName,
      planPrice: planPrice,
    );
  }

  // Track class booking
  static Future<void> trackClassBooked(String className,
      {String? classType,
      String? instructorName,
      String? classTime,
      String? classDate}) async {
    await _analyticsService.logClassBooked(
      className: className,
      classType: classType,
      instructorName: instructorName,
      classTime: classTime,
      classDate: classDate,
    );
  }

  // Track class attendance
  static Future<void> trackClassAttended(String className,
      {String? classType, String? instructorName, int? duration}) async {
    await _analyticsService.logClassAttended(
      className: className,
      classType: classType,
      instructorName: instructorName,
      duration: duration,
    );
  }

  // Track missed class
  static Future<void> trackClassMissed(String className,
      {String? classType, String? instructorName, String? reason}) async {
    await _analyticsService.logClassMissed(
      className: className,
      classType: classType,
      instructorName: instructorName,
      reason: reason,
    );
  }

  // Track session feedback
  static Future<void> trackSessionFeedback(String className, int rating,
      {String? feedback, String? instructorName}) async {
    await _analyticsService.logSessionFeedback(
      className: className,
      rating: rating,
      feedback: feedback,
      instructorName: instructorName,
    );
  }

  // Track workout events
  static Future<void> trackWorkoutEvent(String action,
      {String? workoutType, int? duration}) async {
    await _analyticsService.logWorkoutEvent(
      action: action,
      workoutType: workoutType,
      duration: duration,
    );
  }

  // Track diet events
  static Future<void> trackDietEvent(String action,
      {String? mealType, String? foodItem}) async {
    await _analyticsService.logDietEvent(
      action: action,
      mealType: mealType,
      foodItem: foodItem,
    );
  }

  // Track freeze events
  static Future<void> trackFreezeEvent(String action) async {
    await _analyticsService.logFreezeEvent(action: action);
  }

  // Track daily active user
  static Future<void> trackDailyActiveUser() async {
    await _analyticsService.logDailyActiveUser();
  }

  // Track weekly active user
  static Future<void> trackWeeklyActiveUser() async {
    await _analyticsService.logWeeklyActiveUser();
  }

  // Track churn event
  static Future<void> trackChurnEvent(int daysInactive,
      {String? lastActivity}) async {
    await _analyticsService.logChurnEvent(
      daysInactive: daysInactive,
      lastActivity: lastActivity,
    );
  }

  // Track errors
  static Future<void> trackError(String errorType,
      {String? errorMessage, String? screenName}) async {
    await _analyticsService.logError(
      errorType: errorType,
      errorMessage: errorMessage,
      screenName: screenName,
    );
  }

  // Set user ID
  static Future<void> setUserId(String userId) async {
    print('AnalyticsHelper: Setting user ID: $userId');
    await _analyticsService.setUserId(userId);
    print('AnalyticsHelper: User ID set: $userId');
  }

  // Track free trial events
  static Future<void> trackFreeTrialEvent(String action,
      {String? step, Map<String, Object>? additionalParams}) async {
    await _analyticsService.logFreeTrialEvent(
      action: action,
      step: step,
      additionalParams: additionalParams,
    );
  }

  // Track questionnaire events
  static Future<void> trackQuestionnaireEvent(String action,
      {String? questionnaireType,
      String? questionNumber,
      String? answer,
      Map<String, Object>? additionalParams}) async {
    await _analyticsService.logQuestionnaireEvent(
      action: action,
      questionnaireType: questionnaireType,
      questionNumber: questionNumber,
      answer: answer,
      additionalParams: additionalParams,
    );
  }

  // Set user properties
  static Future<void> setUserProperty(String name, String value) async {
    await _analyticsService.setUserProperty(name: name, value: value);
  }

  // ========== Key Business Events ==========

  /// Track weekly attendance (motivation)
  static Future<void> trackWeeklyAttendance({String? slotId}) async {
    await _analyticsService.logWeeklyAttendance(slotId: slotId);
  }

  /// Track free trial key event
  static Future<void> trackFreeTrial(String action,
      {String? step, Map<String, Object>? additionalParams}) async {
    await _analyticsService.logFreeTrial(
      action: action,
      step: step,
      additionalParams: additionalParams,
    );
  }

  /// Track review submitted
  static Future<void> trackReview(String planId, double rating,
      String trainerOrDiet, {String? classReview, bool hasComment = false}) async {
    await _analyticsService.logReview(
      planId: planId,
      rating: rating,
      trainerOrDiet: trainerOrDiet,
      classReview: classReview,
      hasComment: hasComment,
    );
  }

  /// Track consultation booked
  static Future<void> trackConsultationBooked(
      int planId, int dietitianId, String date,
      {int? timeSlotId}) async {
    await _analyticsService.logConsultationBooked(
      planId: planId,
      dietitianId: dietitianId,
      date: date,
      timeSlotId: timeSlotId,
    );
  }

  /// Track consultation done/completed
  static Future<void> trackConsultationDone(int appointmentId,
      {String? status}) async {
    await _analyticsService.logConsultationDone(
      appointmentId: appointmentId,
      status: status,
    );
  }

  /// Track diet plan delivered (period: day, week, month)
  static Future<void> trackDietPlanDelivered(String period,
      {int? userPlanId, int? dietitianId, String? date}) async {
    await _analyticsService.logDietPlanDelivered(
      period: period,
      userPlanId: userPlanId,
      dietitianId: dietitianId,
      date: date,
    );
  }

  /// Track weekly progress report viewed
  static Future<void> trackWeeklyProgressReport() async {
    await _analyticsService.logWeeklyProgressReport();
  }

  // ─── Phase E3 — Progress Hub V2 events ──────────────────────────────────

  /// E3 — Hub screen view (fires from ProgressScreenV2.initState).
  static Future<void> trackProgressV2HubView() async {
    await _analyticsService.logProgressV2HubView();
  }

  /// E3 — Period chip selector changed.
  static Future<void> trackProgressV2PeriodChanged({
    required String to,
    String? from,
  }) async {
    await _analyticsService.logProgressV2PeriodChanged(to: to, from: from);
  }

  /// E3 — PDF generated successfully (before share sheet opens).
  static Future<void> trackProgressV2PdfDownloaded({
    int? bytes,
    int? pageCount,
    String? period,
  }) async {
    await _analyticsService.logProgressV2PdfDownloaded(
      bytes: bytes,
      pageCount: pageCount,
      period: period,
    );
  }

  /// E3 — Share-sheet outcome.
  static Future<void> trackProgressV2PdfShareCompleted({
    required String status,
    String? period,
  }) async {
    await _analyticsService.logProgressV2PdfShareCompleted(
      status: status,
      period: period,
    );
  }

  /// E3 — Locked Doctor Share button tapped (signals demand).
  static Future<void> trackProgressV2DoctorShareClicked() async {
    await _analyticsService.logProgressV2DoctorShareClicked();
  }
// ─── Subscription lifecycle events ──────────────────────────────────

  /// Repeat purchase from an already-active user (renewal), not a
  /// first-time signup. Caller must already know the user was paid
  /// before this purchase went through.
  static Future<void> trackSubscriptionRenewed(String planId,
      {String? planName, String? planPrice}) async {
    await _analyticsService.logSubscriptionRenewed(
      planId: planId,
      planName: planName,
      planPrice: planPrice,
    );
  }

  /// Fire once per plan id when its expiry date has passed — caller is
  /// responsible for de-duplicating so this doesn't refire on every
  /// render of the plan card.
  static Future<void> trackSubscriptionExpired(String planId,
      {String? planName, int? daysOverdue, String source = 'client_inferred'}) async {
    await _analyticsService.logSubscriptionExpired(
      planId: planId,
      planName: planName,
      daysOverdue: daysOverdue,
      source: source,
    );
  }

  /// Admin/dietitian-initiated plan cancellation — there is no client
  /// self-serve cancellation flow today.
  static Future<void> trackSubscriptionCancelled(String planId,
      {String? reason}) async {
    await _analyticsService.logSubscriptionCancelled(
      planId: planId,
      reason: reason,
    );
  }

  // ─── Workout Class & Attendance Analytics ──────────────────────────

  /// User joined a live workout class
  static Future<void> trackWorkoutClassJoined({
    required String slotId,
    String? className,
    String? trainerName,
    required String userTier,
    String? scheduledStartTime,
    int? delayFromScheduleMinutes,
    String? source,
  }) async {
    await _analyticsService.logWorkoutClassJoined(
      slotId: slotId,
      className: className,
      trainerName: trainerName,
      userTier: userTier,
      scheduledStartTime: scheduledStartTime,
      delayFromScheduleMinutes: delayFromScheduleMinutes,
      source: source,
    );
  }

  /// User left a live workout class
  static Future<void> trackWorkoutClassLeft({
    required String slotId,
    String? className,
    String? trainerName,
    required String userTier,
    int? durationMinutes,
    int? durationSeconds,
    String? exitReason,
  }) async {
    await _analyticsService.logWorkoutClassLeft(
      slotId: slotId,
      className: className,
      trainerName: trainerName,
      userTier: userTier,
      durationMinutes: durationMinutes,
      durationSeconds: durationSeconds,
      exitReason: exitReason,
    );
  }

  /// User viewed workout schedule timeline
  static Future<void> trackWorkoutScheduleViewed({
    String? planId,
    required String userTier,
    String? dayOfWeek,
  }) async {
    await _analyticsService.logWorkoutScheduleViewed(
      planId: planId,
      userTier: userTier,
      dayOfWeek: dayOfWeek,
    );
  }

  /// User tapped a day in workout schedule day strip
  static Future<void> trackWorkoutDaySelected({
    required String selectedDate,
    required String dayName,
    required bool isToday,
  }) async {
    await _analyticsService.logWorkoutDaySelected(
      selectedDate: selectedDate,
      dayName: dayName,
      isToday: isToday,
    );
  }

  /// User tapped Join button on workout schedule
  static Future<void> trackWorkoutJoinClicked({
    required String slotId,
    String? className,
    String? trainerName,
    required String userTier,
    String? linkType,
  }) async {
    await _analyticsService.logWorkoutJoinClicked(
      slotId: slotId,
      className: className,
      trainerName: trainerName,
      userTier: userTier,
      linkType: linkType,
    );
  }
}
