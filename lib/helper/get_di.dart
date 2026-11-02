import 'package:fitness_zone_2/data/Repos/auth_repo/auth_repo.dart';
import 'package:fitness_zone_2/data/Repos/home_repo/home_repo.dart';
import 'package:fitness_zone_2/data/Repos/cycle_repo/cycle_data_repository.dart';
import 'package:fitness_zone_2/data/Repos/checkin_repo/checkin_repository.dart';
import 'package:fitness_zone_2/data/Repos/plan_freeze_repo/plan_freeze_repository.dart';
import 'package:fitness_zone_2/data/Repos/user_plan_repo/user_plan_repository.dart';
import 'package:fitness_zone_2/data/Repos/diet_plan_v2/diet_plan_admin_repository.dart';
import 'package:fitness_zone_2/data/Repos/diet_plan_v2/diet_plan_user_repository.dart';
import 'package:fitness_zone_2/data/controllers/diet_plan_admin_controller/diet_plan_admin_controller.dart';
import 'package:fitness_zone_2/data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import 'package:fitness_zone_2/data/controllers/day7_review_controller/day7_review_controller.dart';
import 'package:fitness_zone_2/data/api_provider/chat_api_provider.dart';
import 'package:fitness_zone_2/data/controllers/consultation_controller/consultation_controller.dart';
import 'package:fitness_zone_2/data/controllers/dietitian_dashboard_controller/dietitian_dashboard_controller.dart';
import 'package:fitness_zone_2/data/controllers/meal_log_controller/meal_log_controller.dart';
import 'package:fitness_zone_2/data/controllers/diet_contoller/diet_controller.dart';
import 'package:fitness_zone_2/data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import 'package:fitness_zone_2/data/controllers/paid_home_controller/paid_home_controller.dart';
import 'package:fitness_zone_2/data/controllers/plan_controller/plan_controller.dart';
import 'package:fitness_zone_2/data/controllers/post_controller.dart';
import 'package:fitness_zone_2/data/controllers/progress_controller/progress_controller.dart';
import 'package:fitness_zone_2/data/controllers/rating_controller/rating_controller.dart';
import 'package:fitness_zone_2/data/controllers/workout_controller/work_out_controller.dart';
import 'package:fitness_zone_2/data/controllers/motivation_controller/motivation_controller.dart';
import 'package:fitness_zone_2/data/controllers/zoom_controller.dart';
import 'package:fitness_zone_2/data/services/youtube_tutorial_service.dart';
import 'package:fitness_zone_2/data/services/analytics_service.dart';
import 'package:fitness_zone_2/data/services/offline_sync_queue.dart';
import 'package:fitness_zone_2/data/services/timezone_sync_service.dart';
import 'package:fitness_zone_2/data/repos/daily_log_repo/daily_log_repository.dart';
import 'package:fitness_zone_2/data/controllers/daily_log_controller/daily_log_controller.dart';
import 'package:fitness_zone_2/data/services/tier_access_service.dart';
import 'package:fitness_zone_2/data/services/food_db_service.dart';
import 'package:fitness_zone_2/data/services/food_diary_service.dart';
import 'package:fitness_zone_2/data/services/luna_insight_service.dart';
import 'package:fitness_zone_2/data/services/behavior_signal_service.dart';
import 'package:fitness_zone_2/data/services/community_moderation_service.dart';
import 'package:fitness_zone_2/data/services/smart_reminder_service.dart';
import 'package:fitness_zone_2/guided_workout/guided_workout_controller.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_provider/api_provider.dart';
import '../data/controllers/auth_controller/auth_controller.dart';
import '../data/controllers/home_controller/home_controller.dart';
import 'notification_services.dart';

Future init() async {
  Get.log("int di");
  final sharedPreferences = await SharedPreferences.getInstance();
  // permanent: true — SharedPreferences must survive route changes so
  // HomeRepo.getPaidHomeDashboard / logWater / logSleep can always find it
  // via Get.find<SharedPreferences>().
  Get.put<SharedPreferences>(sharedPreferences, permanent: true);
  NotificationServices notificationServices = NotificationServices();
  Get.lazyPut(() => ApiProvider());
  Get.lazyPut(() => ChatApiProvider(sharedPreferences));

  ///Repos
  Get.lazyPut(() => AuthRepo(apiProvider: Get.find()));
  Get.lazyPut(() => HomeRepo(apiProvider: Get.find()));
  Get.lazyPut(() => CycleDataRepository(apiProvider: Get.find()));
  Get.lazyPut(() => CheckinRepository(apiProvider: Get.find()));
  Get.lazyPut(() => PlanFreezeRepository(apiProvider: Get.find()));
  Get.lazyPut(() => UserPlanRepository(apiProvider: Get.find()));
  Get.lazyPut(() => DietPlanAdminRepository(apiProvider: Get.find()));
  Get.lazyPut(() => DietPlanUserRepository(apiProvider: Get.find()));

  ///Services
  Get.lazyPut(() => YouTubeTutorialService());
  Get.lazyPut(() => AnalyticsService());
  Get.lazyPut(() => OfflineSyncQueue(prefs: sharedPreferences));
  Get.lazyPut(() => FoodDbService());
  Get.lazyPut(() => TierAccessService(prefs: sharedPreferences));
  Get.lazyPut(() => BehaviorSignalService(prefs: sharedPreferences));
  Get.lazyPut(() => LunaInsightService(prefs: sharedPreferences));
  Get.lazyPut(
      () => CommunityModerationService(prefs: sharedPreferences));
  Get.lazyPut(
    () => FoodDiaryService(
      prefs: sharedPreferences,
      foodDb: Get.find(),
      tier: Get.find(),
    ),
  );
  Get.lazyPut(
    () => DailyLogRepository(
      prefs: sharedPreferences,
      checkinRepo: Get.find(),
      syncQueue: Get.find(),
    ),
  );
  Get.lazyPut(
    () => SmartReminderService(
      prefs: sharedPreferences,
      plugin: FlutterLocalNotificationsPlugin(),
    ),
  );

  // fenix: true on every controller below — survives any GetX scope
  // teardown (logout flow, hot-restart in dev, idle eviction on low-mem
  // devices). Without it, once the instance is removed, the next
  // `Get.find<XController>()` from a tab-content widget throws
  // "XController not found" and that tab crashes. Repos/services above
  // stay as bare lazyPut — they're stateless and don't ship symptoms.
  Get.lazyPut(
    () => AuthController(
        sharedPreferences: sharedPreferences,
        authRepo: Get.find(),
        notificationServices: notificationServices,
        chatApiProvider: Get.find()),
    fenix: true,
  );
  Get.lazyPut(
    () => HomeController(
        sharedPreferences: sharedPreferences, homeRepo: Get.find()),
    fenix: true,
  );
  Get.lazyPut(
    () => DietController(
        sharedPreferences: sharedPreferences, homeRepo: Get.find()),
    fenix: true,
  );
  Get.lazyPut(
    () => ProgressController(
        sharedPreferences: sharedPreferences, homeRepo: Get.find()),
    fenix: true,
  );
  Get.lazyPut(
    () => WorkOutController(
        sharedPreferences: sharedPreferences, homeRepo: Get.find()),
    fenix: true,
  );
  Get.lazyPut(
    () => MotivationController(
        sharedPreferences: sharedPreferences, homeRepo: Get.find()),
    fenix: true,
  );
  Get.lazyPut(
    () => PlanController(
        sharedPreferences: sharedPreferences, homeRepo: Get.find()),
    fenix: true,
  );
  Get.lazyPut(
    () => RatingController(
        sharedPreferences: sharedPreferences, homeRepo: Get.find()),
    fenix: true,
  );
  Get.lazyPut(
    () => PostController(
        sharedPreferences: sharedPreferences, homeRepo: Get.find()),
    fenix: true,
  );
  Get.lazyPut(
    () => CycleThemeController(prefs: sharedPreferences),
    fenix: true,
  );
  Get.lazyPut(
    () => PaidHomeController(
      homeRepo: Get.find(),
      checkinRepo: Get.find(),
      sharedPreferences: sharedPreferences,
    ),
    fenix: true,
  );
  Get.lazyPut(
    () => ConsultationController(
      homeRepo: Get.find(),
      sharedPreferences: sharedPreferences,
    ),
    fenix: true,
  );
  Get.lazyPut(
    () => MealLogController(
      homeRepo: Get.find(),
      sharedPreferences: sharedPreferences,
    ),
    fenix: true,
  );
  Get.lazyPut(
    () => DietitianDashboardController(
      homeRepo: Get.find(),
      sharedPreferences: sharedPreferences,
    ),
    fenix: true,
  );
  Get.lazyPut(
    () => DietPlanAdminController(
      repo: Get.find<DietPlanAdminRepository>(),
      auth: Get.find<AuthController>(),
    ),
    fenix: true,
  );
  Get.lazyPut(
    () => DietPlanUserController(
      repo: Get.find<DietPlanUserRepository>(),
      auth: Get.find<AuthController>(),
    ),
    fenix: true,
  );
  Get.lazyPut(
    () => Day7ReviewController(
      repo: Get.find<DietPlanUserRepository>(),
      auth: Get.find<AuthController>(),
    ),
    fenix: true,
  );
  Get.lazyPut(
    () => TimezoneSyncService(
      auth: Get.find<AuthController>(),
      repo: Get.find<DietPlanUserRepository>(),
    ),
    fenix: true,
  );
  Get.lazyPut(
    () => DailyLogController(
      repo: Get.find(),
      prefs: sharedPreferences,
    ),
    fenix: true,
  );
  Get.lazyPut(
    () => GuidedWorkoutController(prefs: sharedPreferences),
    fenix: true,
  );
  Get.lazyPut(() => ZoomMeetingGetxController(), fenix: true);
}
