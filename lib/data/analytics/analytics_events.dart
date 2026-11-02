/// Final Plan 1A1 — single event catalog for Delivery 1 funnel tracking.
/// Wire call sites through [AnalyticsHelper.track] / [AnalyticsService.track].
class AnalyticsEvents {
  AnalyticsEvents._();

  // Lifecycle
  static const install = 'install';
  static const appOpen = 'app_open';
  static const sessionStart = 'session_start';
  static const sessionEnd = 'session_end';
  static const crash = 'crash';

  // Auth / onboarding
  static const signup = 'signup';
  static const login = 'login';
  static const onboardingStep = 'onboarding_step';
  static const onboardingComplete = 'onboarding_complete';

  // Firsts
  static const firstLog = 'first_log';
  static const firstWorkout = 'first_workout';

  // Daily log
  static const dailyCheckinSaved = 'daily_checkin_saved';
  static const symptomLogged = 'symptom_logged';
  static const waterLogged = 'water_logged';
  static const mealLogged = 'meal_logged';
  static const mealPhotoLogged = 'meal_photo_logged';
  static const mealEdited = 'meal_edited';

  // Luna / insights
  static const lunaCardViewed = 'luna_card_viewed';
  static const phaseMessageViewed = 'phase_message_viewed';
  static const suggestionTapped = 'suggestion_tapped';
  static const featureOpened = 'feature_opened';
  static const logSkipped = 'log_skipped';

  // Workouts
  static const guidedWorkoutStarted = 'guided_workout_started';
  static const guidedWorkoutCompleted = 'guided_workout_completed';
  static const guidedMoveMarkedDone = 'guided_move_marked_done';
  static const guidedFeedback = 'guided_feedback';
  static const badgeUnlocked = 'badge_unlocked';

  // Paywall / money
  static const paywallView = 'paywall_view';
  static const upgradeTap = 'upgrade_tap';
  static const paymentSuccess = 'payment_success';
  static const paymentFailure = 'payment_failure';
  static const cancel = 'cancel';
  static const freeze = 'freeze';
  static const unfreeze = 'unfreeze';
  static const refund = 'refund';
  static const trialStart = 'trial_start';

  // Push
  static const pushReceived = 'push_received';
  static const pushOpened = 'push_opened';

  // Community
  static const postCreated = 'post_created';
  static const postFlagged = 'post_flagged';
  static const postReported = 'post_reported';
  static const userBlocked = 'user_blocked';

  // Delivery 2–3
  static const foodPrefsSaved = 'food_prefs_saved';
  static const mealPhaseScored = 'meal_phase_scored';
  static const weeklyPlanAdjusted = 'weekly_plan_adjusted';
  static const groceryListBuilt = 'grocery_list_built';
  static const periodFlowLogged = 'period_flow_logged';
  static const medicationLogged = 'medication_logged';
  static const skinHairLogged = 'skin_hair_logged';
  static const weeklyReportViewed = 'weekly_report_viewed';
  static const monthlyReportViewed = 'monthly_report_viewed';
  static const doctorPdfGenerated = 'doctor_pdf_generated';
  static const periodPredictorViewed = 'period_predictor_viewed';
  static const guidedPickerUsed = 'guided_picker_used';
  static const guidedSwapUsed = 'guided_swap_used';
  static const restDaySuggested = 'rest_day_suggested';
  static const todayPlanCardTapped = 'today_plan_card_tapped';
  static const progressPhotoAdded = 'progress_photo_added';
  static const badgeShared = 'badge_shared';
  static const libraryClassStarted = 'library_class_started';
  static const libraryClassCompleted = 'library_class_completed';
  static const unlimitedGateHit = 'unlimited_gate_hit';
  static const nutritionistMessage = 'nutritionist_message';
  static const conditionActivated = 'condition_activated';
  static const referralShared = 'referral_shared';
  static const privacyLockEnabled = 'privacy_lock_enabled';
  static const remoteConfigOverride = 'remote_config_override';
}
