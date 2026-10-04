import 'package:get/get.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

class AnalyticsService extends GetxService {
  static Mixpanel? _mixpanel;

  // Initialize analytics
  Future<void> init() async {
    try {
      _mixpanel = await Mixpanel.init('14d69695d1cf63e1705033ca2e307088',
          trackAutomaticEvents: true);
      print('Mixpanel initialized successfully');
    } catch (e) {
      print('Failed to initialize Mixpanel: $e');
    }
  }

  // Track screen views
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    print('Tracking Screen View: $screenName');
    await _mixpanel?.track('Screen View', properties: {
      'screen_name': screenName,
      if (screenClass != null) 'screen_class': screenClass,
    });
    print('Screen View tracked: $screenName');
  }

  // Track scroll activity
  Future<void> logScrollActivity({
    required String screenName,
    String? contentType, // 'classes', 'diet_plans', 'workouts'
    int? scrollDepth,
  }) async {
    print('Tracking Scroll Activity: $screenName');
    await _mixpanel?.track('Scroll Activity', properties: {
      'screen_name': screenName,
      if (contentType != null) 'content_type': contentType,
      if (scrollDepth != null) 'scroll_depth': scrollDepth,
    });
    print('Scroll Activity tracked: $screenName');
  }

  // Track search activity
  Future<void> logSearch({
    required String searchTerm,
    String? searchCategory, // 'workouts', 'diet_plans', 'classes'
    int? resultsCount,
  }) async {
    print('Tracking Search: $searchTerm');
    await _mixpanel?.track('Search', properties: {
      'search_term': searchTerm,
      if (searchCategory != null) 'search_category': searchCategory,
      if (resultsCount != null) 'results_count': resultsCount,
    });
    print('Search tracked: $searchTerm');
  }

  // Track class view
  Future<void> logClassView({
    required String className,
    String? classType, // 'live', 'recorded'
    String? instructorName,
  }) async {
    await _mixpanel?.track('Class View', properties: {
      'class_name': className,
      if (classType != null) 'class_type': classType,
      if (instructorName != null) 'instructor_name': instructorName,
    });
  }

  // Track app open
  Future<void> logAppOpen() async {
    print('Attempting to track App Open event');
    await _mixpanel?.track('App Open');
    print('App Open event tracked');
  }

  // Track user login
  Future<void> logLogin({required String method}) async {
    await _mixpanel?.track('Login', properties: {
      'method': method,
    });
  }

  // Track user sign up
  Future<void> logSignUp({required String method}) async {
    await _mixpanel?.track('Sign Up', properties: {
      'method': method,
    });
  }

  // Track tutorial completion
  Future<void> logTutorialComplete({String? tutorialName}) async {
    await _mixpanel?.track('Tutorial Complete', properties: {
      if (tutorialName != null) 'tutorial_name': tutorialName,
    });
  }

  // Track custom events
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _mixpanel?.track(name, properties: parameters);
  }

  // Track button clicks
  Future<void> logButtonClick({
    required String buttonName,
    String? screenName,
    Map<String, Object>? additionalParams,
  }) async {
    final Map<String, dynamic> params = {
      'button_name': buttonName,
      if (screenName != null) 'screen_name': screenName,
    };
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    await _mixpanel?.track('Button Click', properties: params);
  }

  // Track feature usage
  Future<void> logFeatureUsage({
    required String featureName,
    String? screenName,
    Map<String, Object>? additionalParams,
  }) async {
    final Map<String, dynamic> params = {
      'feature_name': featureName,
      if (screenName != null) 'screen_name': screenName,
    };
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    await _mixpanel?.track('Feature Usage', properties: params);
  }

  // Track tutorial events
  Future<void> logTutorialEvent({
    required String tutorialName,
    required String action, // 'started', 'completed', 'skipped'
    Map<String, Object>? additionalParams,
  }) async {
    final Map<String, dynamic> params = {
      'tutorial_name': tutorialName,
      'action': action,
    };
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    await _mixpanel?.track('Tutorial Event', properties: params);
  }

  // Track subscription click
  Future<void> logSubscribeClick({String? screenName}) async {
    await _mixpanel?.track('Subscribe Click', properties: {
      if (screenName != null) 'screen_name': screenName,
    });
  }

  // Track plan selection
  Future<void> logPlanSelected({
    required String planName, // 'Basic', 'Premium', 'Consultation'
    String? planPrice,
    String? planDuration, // 'monthly', 'yearly'
  }) async {
    await _mixpanel?.track('Plan Selected', properties: {
      'plan_name': planName,
      if (planPrice != null) 'plan_price': planPrice,
      if (planDuration != null) 'plan_duration': planDuration,
    });
  }

  // Track checkout begin
  Future<void> logBeginCheckout({
    required String planName,
    String? planPrice,
    String? currency,
  }) async {
    await _mixpanel?.track('Begin Checkout', properties: {
      'plan_name': planName,
      if (planPrice != null) 'plan_price': planPrice,
      if (currency != null) 'currency': currency,
    });
  }

  // Track payment info added
  Future<void> logAddPaymentInfo({
    required String paymentType, // 'card', 'paypal', 'apple_pay'
    String? planName,
  }) async {
    await _mixpanel?.track('Add Payment Info', properties: {
      'payment_type': paymentType,
      if (planName != null) 'plan_name': planName,
    });
  }

  // Track successful purchase
  Future<void> logPurchase({
    required String planName,
    required String planPrice,
    String? currency,
    String? transactionId,
  }) async {
    await _mixpanel?.track('Purchase', properties: {
      'plan_name': planName,
      'plan_price': planPrice,
      if (currency != null) 'currency': currency,
      if (transactionId != null) 'transaction_id': transactionId,
    });
  }

  // Track failed purchase
  Future<void> logPurchaseFailed({
    required String planName,
    String? planPrice,
    String? errorReason,
    String? paymentType,
  }) async {
    await _mixpanel?.track('Purchase Failed', properties: {
      'plan_name': planName,
      if (planPrice != null) 'plan_price': planPrice,
      if (errorReason != null) 'error_reason': errorReason,
      if (paymentType != null) 'payment_type': paymentType,
    });
  }

  // Track subscription events (legacy method)
  Future<void> logSubscriptionEvent({
    required String action, // 'viewed', 'started', 'completed', 'cancelled'
    String? planName,
    String? planPrice,
    Map<String, Object>? additionalParams,
  }) async {
    final Map<String, dynamic> params = {
      'action': action,
      if (planName != null) 'plan_name': planName,
      if (planPrice != null) 'plan_price': planPrice,
    };
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    await _mixpanel?.track('Subscription Event', properties: params);
  }

  // Track class booking
  Future<void> logClassBooked({
    required String className,
    String? classType, // 'live', 'recorded'
    String? instructorName,
    String? classTime,
    String? classDate,
  }) async {
    await _mixpanel?.track('Class Booked', properties: {
      'class_name': className,
      if (classType != null) 'class_type': classType,
      if (instructorName != null) 'instructor_name': instructorName,
      if (classTime != null) 'class_time': classTime,
      if (classDate != null) 'class_date': classDate,
    });
  }

  // Track class attendance
  Future<void> logClassAttended({
    required String className,
    String? classType,
    String? instructorName,
    int? duration, // minutes attended
  }) async {
    await _mixpanel?.track('Class Attended', properties: {
      'class_name': className,
      if (classType != null) 'class_type': classType,
      if (instructorName != null) 'instructor_name': instructorName,
      if (duration != null) 'duration_minutes': duration,
    });
  }

  // Track missed class
  Future<void> logClassMissed({
    required String className,
    String? classType,
    String? instructorName,
    String? reason, // 'forgot', 'sick', 'busy', 'technical_issue'
  }) async {
    await _mixpanel?.track('Class Missed', properties: {
      'class_name': className,
      if (classType != null) 'class_type': classType,
      if (instructorName != null) 'instructor_name': instructorName,
      if (reason != null) 'reason': reason,
    });
  }

  // Track session feedback
  Future<void> logSessionFeedback({
    required String className,
    required int rating, // 1-5 stars
    String? feedback,
    String? instructorName,
  }) async {
    await _mixpanel?.track('Session Feedback', properties: {
      'class_name': className,
      'rating': rating,
      if (feedback != null) 'feedback': feedback,
      if (instructorName != null) 'instructor_name': instructorName,
    });
  }

  // Track workout events
  Future<void> logWorkoutEvent({
    required String action, // 'started', 'completed', 'paused', 'resumed'
    String? workoutType,
    int? duration,
    Map<String, Object>? additionalParams,
  }) async {
    final Map<String, dynamic> params = {
      'action': action,
      if (workoutType != null) 'workout_type': workoutType,
      if (duration != null) 'duration_seconds': duration,
    };
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    await _mixpanel?.track('Workout Event', properties: params);
  }

  // Track diet events
  Future<void> logDietEvent({
    required String
        action, // 'meal_logged', 'consultation_booked', 'plan_viewed'
    String? mealType,
    String? foodItem,
    Map<String, Object>? additionalParams,
  }) async {
    final Map<String, dynamic> params = {
      'action': action,
      if (mealType != null) 'meal_type': mealType,
      if (foodItem != null) 'food_item': foodItem,
    };
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    await _mixpanel?.track('Diet Event', properties: params);
  }

  // Track freeze/unfreeze events
  Future<void> logFreezeEvent({
    required String
        action, // 'freeze_requested', 'unfreeze_requested', 'freeze_completed'
    Map<String, Object>? additionalParams,
  }) async {
    final Map<String, dynamic> params = {
      'action': action,
    };
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    await _mixpanel?.track('Freeze Event', properties: params);
  }

  // Track daily active user
  Future<void> logDailyActiveUser() async {
    await _mixpanel?.track('Daily Active User');
  }

  // Track weekly active user
  Future<void> logWeeklyActiveUser() async {
    await _mixpanel?.track('Weekly Active User');
  }

  // Track churn event
  Future<void> logChurnEvent({
    required int daysInactive,
    String? lastActivity,
  }) async {
    await _mixpanel?.track('Churn Event', properties: {
      'days_inactive': daysInactive,
      if (lastActivity != null) 'last_activity': lastActivity,
    });
  }

  // Track error events
  Future<void> logError({
    required String errorType,
    String? errorMessage,
    String? screenName,
    Map<String, Object>? additionalParams,
  }) async {
    final Map<String, dynamic> params = {
      'error_type': errorType,
      if (errorMessage != null) 'error_message': errorMessage,
      if (screenName != null) 'screen_name': screenName,
    };
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    await _mixpanel?.track('App Error', properties: params);
  }

  // Set user ID for tracking
  Future<void> setUserId(String userId) async {
    print('Setting user ID: $userId');
    await _mixpanel?.identify(userId);
    print('User ID set: $userId');
  }

  // Track free trial events
  Future<void> logFreeTrialEvent({
    required String
        action, // 'started', 'questionnaire_completed', 'slots_selected', 'completed', 'already_used'
    String? step, // 'personalization', 'slots', 'questionnaire'
    Map<String, Object>? additionalParams,
  }) async {
    final Map<String, dynamic> params = {
      'action': action,
      if (step != null) 'step': step,
    };
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    await _mixpanel?.track('Free Trial Event', properties: params);
  }

  // Track questionnaire events
  Future<void> logQuestionnaireEvent({
    required String action, // 'started', 'completed', 'question_answered'
    String? questionnaireType, // 'hormone_test', 'personalization'
    String? questionNumber,
    String? answer,
    Map<String, Object>? additionalParams,
  }) async {
    final Map<String, dynamic> params = {
      'action': action,
      if (questionnaireType != null) 'questionnaire_type': questionnaireType,
      if (questionNumber != null) 'question_number': questionNumber,
      if (answer != null) 'answer': answer,
    };
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    await _mixpanel?.track('Questionnaire Event', properties: params);
  }

  // Set user properties
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    print('Setting user property: $name = $value');
    _mixpanel?.getPeople().set(name, value);
    print('User property set: $name = $value');
  }

  // ========== Key Business Events ==========

  // Track weekly attendance (motivation)
  Future<void> logWeeklyAttendance({
    String? slotId,
  }) async {
    await _mixpanel?.track('Weekly Attendance', properties: {
      if (slotId != null) 'slot_id': slotId,
    });
  }

  // Sign Up - already exists as logSignUp above

  // Track free trial (dedicated key event)
  Future<void> logFreeTrial({
    required String action, // 'started', 'completed', 'slots_selected'
    String? step,
    Map<String, Object>? additionalParams,
  }) async {
    final Map<String, dynamic> params = {
      'action': action,
      if (step != null) 'step': step,
    };
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }
    await _mixpanel?.track('Free Trial', properties: params);
  }

  // Track review submitted
  Future<void> logReview({
    required String planId,
    required double rating,
    required String trainerOrDiet,
    String? classReview,
    bool hasComment = false,
  }) async {
    await _mixpanel?.track('Review', properties: {
      'plan_id': planId,
      'rating': rating,
      'trainer_or_diet': trainerOrDiet,
      if (classReview != null) 'class_review': classReview,
      'has_comment': hasComment,
    });
  }

  // Track consultation booked
  Future<void> logConsultationBooked({
    required int planId,
    required int dietitianId,
    required String date,
    int? timeSlotId,
  }) async {
    await _mixpanel?.track('Consultation Booked', properties: {
      'plan_id': planId,
      'dietitian_id': dietitianId,
      'date': date,
      if (timeSlotId != null) 'time_slot_id': timeSlotId,
    });
  }

  // Track consultation done/completed
  Future<void> logConsultationDone({
    required int appointmentId,
    String? status,
  }) async {
    await _mixpanel?.track('Consultation Done', properties: {
      'appointment_id': appointmentId,
      if (status != null) 'status': status,
    });
  }

  // Track diet plan delivered (period: day, week, month)
  Future<void> logDietPlanDelivered({
    required String period, // 'day', 'week', 'month'
    int? userPlanId,
    int? dietitianId,
    String? date,
  }) async {
    await _mixpanel?.track('Diet Plan Delivered', properties: {
      'period': period,
      if (userPlanId != null) 'user_plan_id': userPlanId,
      if (dietitianId != null) 'dietitian_id': dietitianId,
      if (date != null) 'date': date,
    });
  }

  // Track weekly progress report viewed
  Future<void> logWeeklyProgressReport() async {
    await _mixpanel?.track('Weekly Progress Report');
  }

  // ─── Phase E3 — Progress Hub V2 events ──────────────────────────────────
  // 5 explicit events per the rollout brief. Event names use the
  // `progress_v2_*` prefix so they're easy to filter in Mixpanel and
  // distinguish from any future v3 work.

  /// E3 — Hub screen view. Fired when ProgressScreenV2 mounts.
  Future<void> logProgressV2HubView() async {
    await _mixpanel?.track('progress_v2_hub_view');
  }

  /// E3 — User changed the period chip selector. `from` may be null on
  /// the first auto-fire from controller.onInit so the funnel can tell
  /// active toggles from the initial state.
  Future<void> logProgressV2PeriodChanged({
    required String to,
    String? from,
  }) async {
    await _mixpanel?.track('progress_v2_period_changed', properties: {
      'period_to': to,
      if (from != null) 'period_from': from,
    });
  }

  /// E3 — PDF generation succeeded. Captured before the share sheet opens
  /// so we can measure how often users abandon at the share step.
  Future<void> logProgressV2PdfDownloaded({
    int? bytes,
    int? pageCount,
    String? period,
  }) async {
    await _mixpanel?.track('progress_v2_pdf_downloaded', properties: {
      if (bytes != null) 'bytes': bytes,
      if (pageCount != null) 'page_count': pageCount,
      if (period != null) 'period': period,
    });
  }

  /// E3 — Share sheet completed (user picked a destination, or dismissed).
  /// `status` is the share_plus result: 'success' | 'dismissed' | 'unavailable'
  /// | 'unknown'.
  Future<void> logProgressV2PdfShareCompleted({
    required String status,
    String? period,
  }) async {
    await _mixpanel?.track('progress_v2_pdf_share_completed', properties: {
      'status': status,
      if (period != null) 'period': period,
    });
  }

  /// E3 — Locked Doctor Share button tapped. Logged even though no action
  /// fires — the click count signals demand for the unlocked feature.
  Future<void> logProgressV2DoctorShareClicked() async {
    await _mixpanel?.track('progress_v2_doctor_share_clicked');
  }

  // ─── Subscription lifecycle events ──────────────────────────────────
  // Added alongside the retention-funnel work: identify (setUserId) +
  // session-joined tracking are the other two legs of that funnel.
  // These three complete the "who renews / who lapses / who gets
  // cancelled" side of it.

  /// Fired when a user whose plan was ALREADY active (status == true
  /// before this purchase) completes a new plan purchase — i.e. a repeat
  /// purchase rather than a first-time signup. The app has no separate
  /// backend concept of "renewal" vs "new purchase", so the caller must
  /// pass in whether the user was already paid before calling this.
  Future<void> logSubscriptionRenewed({
    required String planId,
    String? planName,
    String? planPrice,
  }) async {
    await _mixpanel?.track('Subscription Renewed', properties: {
      'plan_id': planId,
      if (planName != null) 'plan_name': planName,
      if (planPrice != null) 'plan_price': planPrice,
    });
  }

  /// Fired the first time the app detects a client's assigned plan has
  /// passed its expiry date. Expiry is a client-side date comparison
  /// (there is no backend "expired" status), so the caller is
  /// responsible for de-duplicating per plan id — this should fire once
  /// per plan lapsing, not on every screen render.
  Future<void> logSubscriptionExpired({
    required String planId,
    String? planName,
    int? daysOverdue,
    // 'backend' when the app read planStatus == 'expired' (the hourly
    // autoExpireUserPlans cron already flagged it — authoritative).
    // 'client_inferred' when the app only had the date to go on (the
    // cron hasn't swept this row yet, e.g. within the last hour).
    String source = 'client_inferred',
  }) async {
    await _mixpanel?.track('Subscription Expired', properties: {
      'plan_id': planId,
      if (planName != null) 'plan_name': planName,
      if (daysOverdue != null) 'days_overdue': daysOverdue,
      'source': source,
    });
  }

  /// Fired when a plan is cancelled. Today this only ever happens from
  /// the admin/dietitian side (diet_plan_admin_controller.cancelCurrentPlan)
  /// — there is no client self-serve cancellation flow in the app.
  Future<void> logSubscriptionCancelled({
    required String planId,
    String? reason,
  }) async {
    await _mixpanel?.track('Subscription Cancelled', properties: {
      'plan_id': planId,
      if (reason != null) 'reason': reason,
    });
  }

  // ─── Workout Class & Attendance Analytics ──────────────────────────

  /// Fired when a user enters a live class session.
  Future<void> logWorkoutClassJoined({
    required String slotId,
    String? className,
    String? trainerName,
    required String userTier, // 'free_trial' | 'paid' | 'none'
    String? scheduledStartTime,
    int? delayFromScheduleMinutes,
    String? source,
  }) async {
    await _mixpanel?.track('workout_class_joined', properties: {
      'slot_id': slotId,
      if (className != null) 'class_name': className,
      if (trainerName != null) 'trainer_name': trainerName,
      'user_tier': userTier,
      if (scheduledStartTime != null) 'scheduled_start_time': scheduledStartTime,
      if (delayFromScheduleMinutes != null)
        'delay_from_schedule_minutes': delayFromScheduleMinutes,
      'source': source ?? 'zoom_native',
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  /// Fired when a user leaves or finishes a live class session.
  Future<void> logWorkoutClassLeft({
    required String slotId,
    String? className,
    String? trainerName,
    required String userTier,
    int? durationMinutes,
    int? durationSeconds,
    String? exitReason, // 'completed' | 'dropped_early' | 'meeting_ended' | 'failed'
  }) async {
    await _mixpanel?.track('workout_class_left', properties: {
      'slot_id': slotId,
      if (className != null) 'class_name': className,
      if (trainerName != null) 'trainer_name': trainerName,
      'user_tier': userTier,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (exitReason != null) 'exit_reason': exitReason,
      'left_at': DateTime.now().toIso8601String(),
    });
  }

  /// Fired when viewing the workout timeline / schedule screen.
  Future<void> logWorkoutScheduleViewed({
    String? planId,
    required String userTier,
    String? dayOfWeek,
  }) async {
    await _mixpanel?.track('workout_schedule_viewed', properties: {
      if (planId != null) 'plan_id': planId,
      'user_tier': userTier,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
    });
  }

  /// Fired when selecting a day from the workout day strip.
  Future<void> logWorkoutDaySelected({
    required String selectedDate,
    required String dayName,
    required bool isToday,
  }) async {
    await _mixpanel?.track('workout_day_selected', properties: {
      'selected_date': selectedDate,
      'day_name': dayName,
      'is_today': isToday,
    });
  }

  /// Fired when tapping Join / Join Now on a workout slot.
  Future<void> logWorkoutJoinClicked({
    required String slotId,
    String? className,
    String? trainerName,
    required String userTier,
    String? linkType, // 'zoom_native' | 'https_url'
  }) async {
    await _mixpanel?.track('workout_join_clicked', properties: {
      'slot_id': slotId,
      if (className != null) 'class_name': className,
      if (trainerName != null) 'trainer_name': trainerName,
      'user_tier': userTier,
      if (linkType != null) 'link_type': linkType,
    });
  }
}
