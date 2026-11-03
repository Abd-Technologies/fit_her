import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class Constants {
  static const String robotoFamily = "Roboto";
  static const String RobotoFamily = "Roboto";
  static const String isGuest = "isGuest";
  static const String chatRoom = "chatRoom";
  static const String allMessages = "allMessages";
  static const String reviewDate = "reviewDate";
  static const String giveReview = "giveReview";

  static const String subscriptionDuration = "subscriptionDuration";
  static String countryCode = "92";
  static String countryName = "PK";
  static String screenShot = "screenShot";
  static String notificationList = "notificationList";
  static String upcomingSlot = "upcomingSlot";
  static const String timeBlock = "timeBlock"; // 'morning'|'afternoon'|'evening'|'night'|'all'
  /// Set to 'true' once the user completes OR skips the time-preference
  /// onboarding screen. Survives logout (preserved across clear()). Checked
  /// by updateUserDetails() so the screen never re-appears after first save.
  static const String timePreferenceDone = "timePreferenceDone";
  static String type = "type";
  static String recording = "recording";
  static String fullName = "fullName";
  static String packageState = "packageState";
  static String userId = "userId";
  static String trialToken = "trialToken";

  static String email = "email";
  static String password = "p";
  static String loginAsa = "loginAsa";
  static String userMobileNumber = "userMobileNumber";
  static String userUid = "userUid";
  static String userCountryCode = "userCountryCode";
  static String trainer = "Trainer";
  static String dietitian = "Dietition";
  static String customerSupport = "Customer_Support_Representative";
  static String admin = "Admin";
  static String GYNECOLOGIST = "Gynecologist";
  static String PSYCHIATRIST = "Psychiatrist";

  static String user = "User";
  static String accessToken = "accessToken";
  // Option-C feature flags persisted across sessions. Saved in addLocalStorage
  // so the cached values survive app restart before a fresh login response
  // refreshes them.
  static const String useNewPaidHomeKey = 'useNewPaidHome';
  static const String useNewUnpaidHomeKey = 'useNewUnpaidHome';
  // Phase A — Progress Screen rebuild. Routes between progress_screen_v1.dart
  // (legacy) and progress_screen_v2.dart (new hub). Default false; opt-in
  // per-user via the backend flag.
  static const String useNewProgressHubKey = 'useNewProgressHub';
  // Local-only "trial activated" flag. Flipped client-side when the user
  // taps Start 3-day free trial on the unpaid home; flips locked tiles +
  // insight, retitles CTAs, and persists across cold starts so the demo
  // state survives an app restart. No backend tie-in.
  static const String trialActivatedKey = 'trialActivated';
  // Global cycle phase cache — persisted so CycleThemeController can restore
  // the correct phase colors on cold start before any API response arrives.
  static const String lastKnownPhase = 'lastKnownPhase';
  // Phase F.3 — IANA timezone last seen for the logged-in user.
  // Populated on login from the server, kept in sync by
  // TimezoneSyncService when the device timezone drifts. Survives
  // cold-start so DietPlanUserController doesn't fall back to device-
  // local math while the user model rehydrates.
  static const String userTimeZoneKey = 'userTimeZone';
  // Progress hub endpoints (Phase B). All accept ?period and ?asOf.
  static const String progressSummary = '/users/progress/summary';
  static const String progressWeight = '/users/progress/weight';
  static const String progressGlance = '/users/progress/glance';
  static const String progressHydration = '/users/progress/hydration';
  static const String progressSymptoms = '/users/progress/symptoms';
  static const String progressInsightsHub = '/users/progress/insights/hub';
  // Phase E — minimal feature-flag toggle endpoint (POST). Only flags in
  // the backend allow-list can be flipped from the client.
  static const String setFeatureFlag = '/users/profile/feature_flag';

  // Plan freeze (user-button flow). See partner_backend
  // docs/Freeze_Logic_Audit.md for the contract.
  static const String planFreeze = '/users/plan/freeze';
  static const String planUnfreeze = '/users/plan/unfreeze';
  static const String planFreezeStatus = '/users/plan/freeze-status';
  static const String planCancel = '/users/plan/cancel';
  // PaidHomeScreenV2 data layer. Leading slash required — ApiProvider
  // concatenates `baseUrl + url` without adding separators.
  static const String paidHomeDashboard = "/users/home/dashboard";
  static const String waterLog = "/users/water_log";
  // PaidHomeScreenV2 — Phase B2.7. Weekly weight upsert + target weight set.
  static const String weightLog = "/users/weekly_checkin/weight";
  static const String targetWeight = "/users/profile/target_weight";
  static const String mainGoal = "/users/profile/main_goal";
  static String login = "login";
  static String weeklyReports = "weeklyReports";

  ///base url
  // static String baseUrl = "https://test.thefither.com";
  // static String baseUrl = "http://192.168.1.31:9005";
//   static String baseUrl = "https://backend.thefither.com";
  static String baseUrl = dotenv.env['BASE_URL'] ?? "http://192.168.100.20:3306";
  static String customerSupportLink =
      "https://backend.thefither.com/customerSupport/";
  static const chatBaseUrl =
      "https://fcm.googleapis.com/v1/projects/fither-e7a36/messages:send";

  /// Firebase collections and document collection
  static String customers = "customers";
  static String fcmToken = "fcmToken";
  static String members = "members";
  static String deviceToken = "deviceToken";
  static String announcementNotification = "announcementNotification";
  static String serverKey = dotenv.env['FCM_SERVER_KEY'] ?? '';

  /// Apis end points

  static String signupPath = "/users/registration";
  static String loginPath = "/admin/login";
  static String socialLogin = "/admin/socialLogin";
  static String guestLogin = "/admin/guestlogin";
  static String forgotPassword = "/users/forget_password";
  static String verifyOtp = "/users/verify_otp";
  static String resendOtp = "/users/resend_otp";
  static String resetPassword = "/users/change_password_after_otp";
  static String dietitianLogin = "/users/dietition_login";
  static String trainerLogin = "/users/trainer_login";

  // ── Phase E.1 — Structured AI diet-plan endpoints (Phase C/D backend) ──
  // Admin/dietitian surface:
  static const String dietPlanAdminGenerate = "/admin/diet-plan/generate";
  static const String dietPlanAdminDrafts = "/admin/diet-plan/drafts";
  // Path templates — repo expands `{id}` / `{userId}` / `{mealId}` at call time.
  static const String dietPlanAdminById = "/admin/diet-plan/{id}";
  static const String dietPlanAdminActivate = "/admin/diet-plan/{id}/activate";
  static const String dietPlanAdminCancel = "/admin/diet-plan/{id}/cancel";
  static const String dietPlanAdminUserList =
      "/admin/diet-plan/user/{userId}/list";
  static const String dietPlanAdminUpdateMeal =
      "/admin/diet-plan/meal/{mealId}";
  // User-facing surface (Phase F consumer):
  static const String dietPlanUserActive = "/users/diet-plan/me/active";
  static const String dietPlanUserTimezone = "/users/diet-plan/me/timezone";
  // Phase F.3 — booking context for the empty-state CTA (userId,
  // userPlanId, dietitianId, hasActivePlan).
  static const String dietPlanUserBookingContext =
      "/users/diet-plan/me/booking-context";
  // Phase G.3 — Day 7 check-in popup variable name. The endpoint paths
  // themselves are already declared further down (`day7Review` +
  // `popupAck`, lines ~207–212); this is just the variable string used
  // in the URL fragment + matches the backend whitelist in
  // controllers/FrontSite/popupStateController.js.
  static const String day7ReviewPopupVariable = "POPUP_DAY7_REVIEW";
  static String getAllCategories = "/admin/all_categories";
  static String getSubCat = "/admin/get_subcategories";
  static String getUserDietPlans = "/admin/userDietPlans";
  static String getClients = "/dietTimes/getClients";
  static String addCalorieImage = "/dietTimes/checkNutrition";
  static String getAppointments = "/appointment/dietAppointments";
  static String rescheduleAppointments =
      "/appointment/rescheduled/appointments";
  static String getConsultationStatus = "/appointment/status";
  static String getSchedulePdfStatus = "/admin/getDietPlanStatus";
  static String dietTimes = "/dietTimes";
  static String addReview = "/admin/addReview";
  static String getUserWorkoutPlans = "/admin/user_workout_plans";
  static String getUserImagesProgress = "/admin/getProgressImages";
  static String getUserDietPlanDetails = "/admin/dietPlanDetails";
  static String getDietPdf = "/admin/getDietPdf";
  static String getUserWorkoutPlanDetails = "/admin/workout_plan_details";
  static String getSubCatBasedOnUserType =
      "/admin/get_subcategories_based_on_user_types";
  static String getUsersOnUserType = "/admin/get_users_based_on_types";
  static String getPlansBasedOnSubCat =
      "/admin/get_plans_based_on_sub_categories";
  static String getWorkoutAndTrainersPlan = "/admin/workout_plans";
  static String getAllDietAndTrain = "/admin/getAllDeititions";
  static String getAllUsers = "/admin/get_all_users";
  static String getAllUserWithSpecificCustomer =
      "/admin/getAllCustomSupporters";
  static String getTrainerHome = "/admin/trainerHome";
  static String getReports = "/admin/userReports";
  static String getDietHome = "/admin/dietitionHome";
  static String getFreePlan = "/admin/getFreePlan";
  static String getGuestUsers = "/admin/getGuest";
  static String getAllUsersPlanImages = "/admin/getAllPlanImages";
  static String getTeamMembers = "/admin/getTeamMember";
  static String getUserHome = "/admin/userHome";
  static String getAllPlans = "/admin/get_plans";
  static String addFreeTrial = "/admin/assignFreePlan";
  static String getAllHealthTips = "/admin/getAllHealthTips";
  static String postAddPlan = "/admin/add_plan";
  static String postUpdatePlan = "/admin/update_plan";
  static String addNewUser = "/admin/addUser";
  static String addUserDetails = "/admin/addUserDetails";
  static String payment = "/admin/payment";
  static String getAllTimesWithSlots = "/admin/getAllTimesWithSlots";
  static String getAllFreeTrialUsers = "/admin/getFreeTrialUserById";
  static String changeFreeTrialStatus = "/admin/changeFreeTrialStatus";
  static String assignWorkoutAndTrainerPlan = "/admin/assign_workout_diet_plan";
  static String addDietionPlan = "/admin/dietition_add_plan";
  static String addAnnouncement = "/admin/addAnnouncement";
  static String freezeMyAccount = "/admin/freeze";
  static String synchronization = "/admin/syncrhonize";
  static String addReport = "/admin/addReport";
  static String updateLink = "/admin/updateLink";
  static String updateDietLink = "/admin/updateDietitionLink";
  static String updateTrainerJoin = "/admin/updateTrainerJoin";
  static String updateSlotStatus = "/admin/updateSlotStatus";
  // App update popup (Oct 2026)
  static String appVersion = "/users/app-version";
  static String adminAppVersion = "/admin/app-version";
  static String appVersionReport = "/users/app-version/report";
  static String adminAppVersionAudience = "/admin/app-version/audience";
  static String adminAppVersionNotify = "/admin/app-version/notify";
  // Class rooms (Oct 2026): trainer Zoom room set once by admin.
  static String trainerClass = "/admin/trainerClass";
  static String trainerClassBackupLink = "/admin/trainerClass/backupLink";
  static String trainerRooms = "/admin/trainerRooms";
  static String trainerRoom = "/admin/trainerRoom";
  static String mainClassRoom = "/admin/mainClassRoom";
  // Free trial length set by admin (GET + POST).
  static String adminTrialDays = "/admin/trialDays";
  static String addTeamMember = "/admin/addTeamMember";
  static String updateUser = "/admin/updateUser";
  static String paymentSuccess = "/admin/payment_success";
  static String approveUser = "/admin/approvedImage";
  static String addTestimonials = "/admin/add_testimonial";
  static String addPdfFile = "/admin/addDietPdf";
  static String updateUserProfile = "/admin/update_user";
  static String updateUserDietOfWeek = "/admin/addDiet";
  static String addPlanImage = "/admin/addImage";
  static String addProgressImages = "/admin/addProgressImages";
  static String resendOtpPath = "/users/resend_otp";
  static String home = "/users/home";

  // ── Consultation flow (Phase 1B endpoints) ─────────────────────────
  static const String preConsultationProfile = "/users/pre-consultation";
  static const String mealLogs = "/users/meal-logs";
  static const String day7Review = "/users/day7-review";
  static const String progressSubmission = "/users/progress";
  static const String dietitianAvailability = "/users/dietitian-availability";
  static const String userEscalations = "/users/escalations";
  // Append "/<variable>/dismiss" or "/<variable>/complete".
  static const String popupAck = "/users/popup";
  // Admin-side endpoints.
  static const String adminPreConsultationProfile = "/admin/pre-consultation";
  static const String adminDay7Reviews = "/admin/day7-reviews";
  static const String adminUserProgress =
      "/admin/users"; // append /:id/progress
  static const String adminEscalations = "/admin/escalations";
  static const String adminMetricsOverview = "/admin/metrics/overview";

  static String getDietitianUsers = "/users/dietition_get_all_users";
  static String getUserPlan = "/users/get_user_plans";

  /// Direct Pay (Payin PWA) - backend returns payment URL; client_secret stays on server
  static String directPayUrl = "/pay/directpay_payment";
  static String logout = "/users/logout";
  static String updateDeviceToken = "/users/device-token";
  static String notifications = "/users/notifications";
  static String markNotificationsRead = "/users/notifications/read";
  // Swiped away in the bell: hidden on the server too (Oct 2026).
  static String hideNotifications = "/users/notifications/hide";
  static String deleteUser = "/admin/delete_user";
  static String updateSlotTrainer = "/admin/update_slot_trainer";
  static String addFreeTrailUser = "/admin/createFreeTrialUser";

  /// 3-Day Trial MVP
  static String trialValidateToken = "/trial/validate-token";
  static String trialStart = "/trial/start";
  static String trialMe = "/trial/me";
  static String trialClasses = "/trial/classes";
  static String trialSummary = "/trial/summary";
  static String trialBookDay = "/trial/book-day";
  static String trialAttendance = "/trial/attendance";
  static String trialConvert = "/trial/convert";
  // Trial-to-Plan funnel — quick intake -> auto-generated + auto-activated
  // starter diet plan. See trialDietPlanController.js on the backend.
  static String trialQuickIntake = "/trial/quick-intake";

  /// Trial Token — sales rep deep-link system
  /// Deep-link format: https://backend.thefither.com/trial?token=<token>
  static String trialTokenCreate = "/admin/create-trial-token";
  static String trialTokenList   = "/admin/my-trial-tokens";
  static String trialTokenRevoke = "/admin/revoke-trial-token";

  /// Motivation module
  static String getMotivationStats = "/attendance/motivation";
  static String markMotivationAttendance = "/attendance/mark";
  static String classPresenceJoin = "/attendance/presence/join";
  static String classPresenceLeave = "/attendance/presence/leave";
  // Class feedback (fitHer Flows › Class feedback)
  static String classFeedbackPending = "/attendance/feedback/pending";
  // Free-trial moments (Nov 2026): GET today's moment, POST "seen".
  static String trialMoment = "/trial/moment";
  static String trialMomentSeen = "/trial/moment/seen";
  // One weekly check-in (Oct 2026): widgets/weekly_checkin/weekly_checkin_sheet.dart
  static String weeklyCheckinState = "/users/weekly-checkin/state";
  static String weeklyCheckinSave = "/users/weekly-checkin";
  static String weeklyCheckinMeasurements = "/users/weekly-checkin/measurements";
  static String weeklyCheckinHistory = "/users/weekly-checkin/history";
  static String classFeedback = "/attendance/feedback";
  static String classFeedbackSkip = "/attendance/feedback/skip";
  static String classFeedbackTrainer = "/attendance/feedback/trainer";
  static String adminClassFeedback = "/admin/classFeedback";

  ///  Country ///
  static String country = "/country";
  static String add_slots = "/admin/update_slots";

  ///Duration
  static String timeDuration = "/duration/create";

  /// CYCLE DATA
  static const String getCycleData = "/users/cycle_data";
  static const String saveCycleData = "/users/cycle_data";
  static const String savePcosScreening = "/users/pcos_screening";
  static const String saveHealthScreening = "/users/health_screening";
  static const String getHealthScreening = "/users/health_screening";

  /// CHECK-INS
  static const String saveDailyCheckin = "/users/daily_checkin";
  static const String getDailyCheckin = "/users/daily_checkin";
  static const String getDailyCheckinsWeek = "/users/daily_checkins/week";
  static const String getDailyCheckinsRecent = "/users/daily_checkins/recent";
  static const String saveWeeklyCheckin = "/users/weekly_checkin";
  static const String getWeeklyCheckinsRecent = "/users/weekly_checkins/recent";

  /// POSTS MODULE
  static const String getAllPosts = "/posts/";
  static const String createPost = "/posts";
  static const String deletePost = "/posts";
  static const String approvePost = "/posts/approve";
  static const String likePost = "/posts/like"; // new
  static const String sendReply = "/posts/reply"; // new
  static const String getReplies = "/posts/replies"; // new
  // POST approve/disapprove post
}

String get today => DateFormat('EEEE').format(DateTime.now());
String get tomorrow =>
    DateFormat('EEEE').format(DateTime.now().add(const Duration(days: 1)));
