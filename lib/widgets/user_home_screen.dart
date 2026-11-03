import 'package:fitness_zone_2/UI/dashboard_module/bottom_bar_screen/Help_Screen.dart';
import 'package:fitness_zone_2/UI/dashboard_module/home_screen/notification_screen.dart';
import 'package:fitness_zone_2/UI/dashboard_module/profile_screen/profile_screen_user.dart';
import 'package:fitness_zone_2/UI/diet_screen/diet_module.dart';
import 'package:fitness_zone_2/UI/freee_test_module/my_journey_screen.dart';
import 'package:fitness_zone_2/UI/plans_module/all_plans.dart';
import 'package:fitness_zone_2/UI/plans_module/invoice_screen.dart';
import 'package:fitness_zone_2/UI/plans_module/view_details.dart';
import 'package:fitness_zone_2/data/controllers/socket_controller.dart';
import 'package:fitness_zone_2/data/models/upcoming_class_slot.dart';
import 'package:fitness_zone_2/values/values.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:fitness_zone_2/widgets/circular_progress.dart';
import 'package:fitness_zone_2/widgets/custom_button.dart';
import 'package:fitness_zone_2/widgets/gradient_border_container.dart';
import 'package:fitness_zone_2/widgets/plan_widget.dart';
import 'package:fitness_zone_2/widgets/toasts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../UI/dashboard_module/bottom_bar_screen/workout_plans_of_user.dart';
import '../UI/in_app_webview.dart';
import '../data/controllers/auth_controller/auth_controller.dart';
import '../data/controllers/home_controller/home_controller.dart';
import '../data/controllers/zoom_controller.dart';
import '../data/models/get_user_plan/get_workout_user_plan_details.dart';
import '../data/services/youtube_tutorial_service.dart';

import '../helper/analytics_helper.dart';
import 'package:get/get.dart';
import 'package:fitness_zone_2/widgets/migration_banner.dart';
import 'package:fitness_zone_2/widgets/insight_card.dart';
import 'package:fitness_zone_2/widgets/checkin_prompt.dart';
import 'package:fitness_zone_2/widgets/weekly_report_progress.dart';
import 'package:fitness_zone_2/UI/auth_module/daily_checkin_screen.dart';
import 'package:fitness_zone_2/UI/auth_module/log_period_screen.dart';
import 'package:fitness_zone_2/UI/dashboard_module/recommended_slots_screen.dart';
import 'package:fitness_zone_2/data/Repos/cycle_repo/cycle_data_repository.dart';
import 'package:fitness_zone_2/data/Repos/checkin_repo/checkin_repository.dart';
import 'package:fitness_zone_2/data/services/cycle_engine.dart';
import 'package:fitness_zone_2/data/services/insight_service.dart';
import 'package:fitness_zone_2/data/services/accuracy_service.dart';
import 'package:fitness_zone_2/values/constants.dart';
import 'border_titlle_widget.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'custom_textfield.dart';

class UserHomeScreen extends StatefulWidget {
  UserHomeScreen({Key? key}) : super(key: key);

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final AuthController authController = Get.find();
  final HomeController homeController = Get.find();
  final SocketController socketController = Get.find<SocketController>();
  final ScrollController userHomeScreenScrollController = ScrollController();
  ZoomMeetingGetxController controller = Get.find();

  // Constants for better maintainability
  static const double _kDefaultPadding = 20.0;
  static const double _kDefaultRadius = 25.0;
  static const double _kSmallRadius = 15.0;
  static const double _kAvatarSize = 60.0;
  static const double _kIconSize = 30.0;
  static const double _kSmallIconSize = 12.0;
  static const double _kProgressRadius = 120.0;
  static const double _kProgressLineWidth = 30.0;

  final List<Color> colors = [Colors.grey, Colors.blueGrey, Colors.teal, Colors.cyanAccent];
  final List<String> images = [
    MyImgs.yoga,
    MyImgs.zumba,
    MyImgs.cardio,
    MyImgs.mediation,
  ];

  final List<Map<String, String>> textList = [
    {"text": "Workouts", "image": MyImgs.workoutHome},
    {"text": "Diet Plans", "image": MyImgs.dietPlanHome},
    {"text": "Mental Help", "image": MyImgs.mentalHelpHome},
    {"text": "Gynae", "image": MyImgs.GynaeHome},
    {"text": "Free Test", "image": MyImgs.freeTestHome},
    {"text": "Health Tips", "image": MyImgs.healthTips},
    {"text": "Cooperates", "image": MyImgs.team},
    {"text": "Our Journey", "image": MyImgs.ourJourney},
  ];

  // Phase 2: Insight data state
  CycleInfo? _cycleInfo;
  Insight? _insight;
  double? _accuracyPercent;
  int _checkinsThisWeek = 0;
  bool _hasCheckinToday = false;
  bool _hasCycleData = false;
  bool _showCheckinPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInsightData();
    });
  }

  Future<void> _loadInsightData() async {
    final token = authController.sharedPreferences.getString(Constants.accessToken) ?? '';

    // a. Get cycle data
    final cycleRepo = Get.find<CycleDataRepository>();
    final cycleResponse = await cycleRepo.getCycleData(accessToken: token);

    CycleInfo? cycleInfo;
    bool hasCycleData = false;

    if (cycleResponse.body != null &&
        cycleResponse.body['status'] == '1' &&
        cycleResponse.body['data'] != null &&
        cycleResponse.body['data']['dataProvided'] == 1 &&
        cycleResponse.body['data']['lastPeriodDate'] != null) {
      final data = cycleResponse.body['data'];
      cycleInfo = CycleEngine.calculate(
        lastPeriodDate: DateTime.parse(data['lastPeriodDate']),
        cycleLength: data['averageCycleLength'] ?? 28,
      );
      hasCycleData = true;
    }

    // b. Get insight
    final insight = InsightService.getTodayInsight(cycleInfo);

    // c. Check today's checkin
    final checkinRepo = Get.find<CheckinRepository>();
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayResponse = await checkinRepo.getDailyCheckin(accessToken: token, date: todayStr);
    final hasCheckinToday = todayResponse.body != null &&
        todayResponse.body['status'] == '1' &&
        todayResponse.body['data'] != null;

    // d. Get week checkins count
    final weekResponse = await checkinRepo.getDailyCheckinsWeek(accessToken: token);
    int checkinsThisWeek = 0;
    if (weekResponse.body != null && weekResponse.body['status'] == '1' && weekResponse.body['data'] is List) {
      checkinsThisWeek = (weekResponse.body['data'] as List).length;
    }

    // e. Get accuracy from recent checkins
    double? accuracyPercent;
    final recentResponse = await checkinRepo.getDailyCheckinsRecent(accessToken: token, limit: 7);
    if (recentResponse.body != null && recentResponse.body['status'] == '1' && recentResponse.body['data'] is List) {
      final recentList = (recentResponse.body['data'] as List).whereType<Map<String, dynamic>>().toList();
      final accuracy = AccuracyService.getRolling7DayAccuracy(recentList);
      if (accuracy != null) {
        accuracyPercent = accuracy * 100;
      }
    }

    // f. Show checkin prompt: after 2PM + no checkin today
    final showPrompt = DateTime.now().hour >= 14 && !hasCheckinToday;

    if (mounted) {
      setState(() {
        _cycleInfo = cycleInfo;
        _insight = insight;
        _hasCycleData = hasCycleData;
        _hasCheckinToday = hasCheckinToday;
        _checkinsThisWeek = checkinsThisWeek;
        _accuracyPercent = accuracyPercent;
        _showCheckinPrompt = showPrompt;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 750;
    final isMediumScreen = size.height >= 750 && size.height < 900;
    final isLargeScreen = size.height >= 900;

    return GetBuilder<HomeController>(
      builder: (cont) {
        return RefreshIndicator(
          onRefresh: () async {
            homeController.getUserHomeFunc();
            Get.find<SocketController>().getSlot();
          },
          child: ListView(
            controller: userHomeScreenScrollController,
            children: [
              _buildMainContent(context, textTheme, size, isSmallScreen, isMediumScreen, isLargeScreen),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context, TextTheme textTheme, Size size, bool isSmallScreen, bool isMediumScreen, bool isLargeScreen) {
    return Stack(
      children: [
        Column(
          children: [
            _buildHeaderSection(context, textTheme, size, isSmallScreen, isMediumScreen, isLargeScreen),
            _buildSpacing(size, isSmallScreen, isMediumScreen, isLargeScreen),
            // Phase 2: Insight Card
            if (_insight != null)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: InsightCard(
                  cycleInfo: _cycleInfo,
                  insight: _insight!,
                  accuracyPercent: _accuracyPercent,
                  onViewSessions: () => Get.to(() => const RecommendedSlotsScreen()),
                  onAddCycleData: () => Get.to(() => const LogPeriodScreen()),
                ),
              ),
            // Phase 2: Check-in Prompt
            if (_showCheckinPrompt)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: CheckinPrompt(
                  onTap: () async {
                    setState(() => _showCheckinPrompt = false);
                    final token = authController.sharedPreferences.getString(Constants.accessToken) ?? '';
                    await Get.to(() => DailyCheckinScreen(
                      onSubmit: (data) async {
                        final now = DateTime.now();
                        final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                        data['date'] = dateStr;
                        if (_cycleInfo != null) {
                          data['cycleDay'] = _cycleInfo!.cycleDay;
                          data['cyclePhase'] = _cycleInfo!.phase;
                          data['predictedEnergy'] = _insight?.energy?.energy;
                          data['predictedMood'] = _insight?.mood?.mood;
                        }
                        final response = await Get.find<CheckinRepository>().saveDailyCheckin(accessToken: token, body: data);
                        if (response.body == null || response.body['status'] != '1') {
                          Get.snackbar(
                            'Error',
                            'Could not save check-in. Please try again.',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: MyColors.error,
                            colorText: Colors.white,
                          );
                        }
                      },
                      onDismiss: () => Get.back(),
                    ));
                    _loadInsightData();
                  },
                ),
              ),
            // Phase 2: Weekly Progress Bar
            if (_hasCycleData)
              Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: WeeklyReportProgress(
                  checkinsThisWeek: _checkinsThisWeek,
                ),
              ),
            if (_shouldShowMigrationBanner()) const MigrationBanner(),
            if (_shouldShowFreezeSection()) _buildFreezeSection(context, textTheme),
            _buildGridSection(context, textTheme, size, isSmallScreen, isMediumScreen, isLargeScreen),
            _buildTopSellersSection(context, textTheme, size),
            _buildTeamSection(context, textTheme, size),
            SizedBox(height: 20.h),
          ],
        ),
        if (_shouldShowProgressCard()) _buildProgressCard(context, textTheme, size, isSmallScreen, isMediumScreen, isLargeScreen),
      ],
    );
  }

  Widget _buildHeaderSection(BuildContext context, TextTheme textTheme, Size size, bool isSmallScreen, bool isMediumScreen, bool isLargeScreen) {
    final topPadding = isLargeScreen
        ? 40.h
        : isMediumScreen
            ? 35.h
            : 30.h;
    final bottomPadding = _calculateBottomPadding(isSmallScreen, isMediumScreen, isLargeScreen);

    return Container(
      padding: EdgeInsets.only(
        top: topPadding,
        left: _kDefaultPadding.w,
        right: _kDefaultPadding.w,
        bottom: bottomPadding,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: MyColors.mainGradient,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_kDefaultRadius),
          bottomRight: Radius.circular(_kDefaultRadius),
        ),
      ),
      child: Column(
        children: [
          _buildHeaderTopRow(context, textTheme),
          _buildUpcomingClassSection(context, textTheme),
        ],
      ),
    );
  }

  double _calculateBottomPadding(bool isSmallScreen, bool isMediumScreen, bool isLargeScreen) {
    if (!authController.logInUser!.status || homeController.isFrozen) {
      return 25.h;
    }

    if (homeController.upComingClassNotifier.value != null) {
      return isLargeScreen
          ? 150.h
          : isMediumScreen
              ? 145.h
              : 140.h;
    }

    return isLargeScreen
        ? 165.h
        : isMediumScreen
            ? 160.h
            : 155.h;
  }

  Widget _buildHeaderTopRow(BuildContext context, TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildUserInfoSection(context, textTheme),
        ),
        _buildActionButtonsSection(context, textTheme),
      ],
    );
  }

  Widget _buildUserInfoSection(BuildContext context, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildUserAvatar(context),
            SizedBox(width: 8.w),
            _buildUserNameSection(textTheme),
          ],
        ),
        SizedBox(height: 10.h),
        _buildUserPlanInfo(textTheme),
        _buildSubscriptionStatus(textTheme),
        _buildViewDetailsButton(context, textTheme),
        SizedBox(height: 10.h),
      ],
    );
  }

  Widget _buildUserAvatar(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => ProfileScreenUser()),
      child: Container(
        height: _kAvatarSize.h,
        width: _kAvatarSize.h,
        padding: EdgeInsets.all(5.h),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: MyColors.primaryGradient1,
          image: DecorationImage(image: AssetImage(MyImgs.avatarUser)),
        ),
      ),
    );
  }

  Widget _buildUserNameSection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hey!",
          style: textTheme.titleLarge!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          "${authController.logInUser!.firstName} ${authController.logInUser!.lastName}",
          style: textTheme.titleLarge!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildUserPlanInfo(TextTheme textTheme) {
    return GetBuilder<HomeController>(
      builder: (co) {
        final planTitle = homeController.userHomeData == null
            ? "No Plan"
            : homeController.userHomeData!.userAllPlans.isEmpty
                ? "No Plan"
                : homeController.userHomeData!.userAllPlans[0].title;

        return Text(
          planTitle,
          style: textTheme.titleLarge!.copyWith(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  Widget _buildSubscriptionStatus(TextTheme textTheme) {
    final statusText =
        (homeController.userHomeData?.freeze.value == 1 ?? false) ? "Frozen" : "${authController.logInUser!.status ? "" : "Not "}Subscribed";

    return Text(
      statusText,
      style: textTheme.headlineSmall!.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildViewDetailsButton(BuildContext context, TextTheme textTheme) {
    return GestureDetector(
      onTap: () => Get.to(() => ViewDetails()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "View Details   ",
            style: textTheme.titleLarge!.copyWith(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: Colors.white.withOpacity(0.8),
            size: 10.w,
          )
        ],
      ),
    );
  }

  Widget _buildActionButtonsSection(BuildContext context, TextTheme textTheme) {
    return Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_shouldShowInvoiceButton()) _buildInvoiceButton(),
              SizedBox(width: 10.w),
              _buildNotificationButton(context),
              SizedBox(width: 10.w),
              _buildHelpButton(context)
            ],
          ),
          SizedBox(height: 30.h),
          _buildOurPlansButton(context, textTheme),
        ],
      ),
    );
  }

  bool _shouldShowInvoiceButton() {
    return homeController.userHomeData != null &&
        authController.logInUser!.status &&
        homeController.userHomeData!.userAllPlans.isNotEmpty &&
        homeController.userHomeData?.userAllPlans.first.title != "Free Trial";
  }

  Widget _buildInvoiceButton() {
    return GestureDetector(
      onTap: () => Get.to(() => InvoiceScreen()),
      child: Icon(
        Icons.inventory_2_outlined,
        color: Colors.white,
        size: _kIconSize.w,
      ),
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        GestureDetector(
          onTap: () {
            homeController.showDotHome.value = false;
            Get.to(() => NotificationScreen());
          },
          child: Icon(
            Icons.notifications_none,
            color: Colors.white,
            size: _kIconSize.w,
          ),
        ),
        _buildNotificationDot(),
      ],
    );
  }

  Widget _buildHelpButton(BuildContext context) {
    return GestureDetector(
        onTap: () {
          homeController.showDotHome.value = false;
          Get.to(() => HelpScreen());
        },
        child: Icon(Icons.help_outline,size: 25,color: Colors.white,));
  }

  Widget _buildNotificationDot() {
    return Obx(() => homeController.showDotHome.value
        ? Container(
            height: 5.h,
            width: 5.w,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          )
        : const SizedBox.shrink());
  }

  Widget _buildOurPlansButton(BuildContext context, TextTheme textTheme) {
    return MaterialButton(
      color: MyColors.primaryGradient3,
      textColor: Colors.white,
      onPressed: () async {
        await AnalyticsHelper.trackSubscribeClick(screenName: 'user_home_screen');
        final tutorialService = Get.find<YouTubeTutorialService>();
        await tutorialService.showSubscribeTutorial(context);
        homeController.getPlansUser();
        Get.to(() => OurPlansScreen());
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kDefaultRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Our Plans",
            style: textTheme.titleLarge!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 5.w),
          Icon(
            Icons.arrow_downward,
            size: 15.w,
            weight: 20,
            grade: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingClassSection(BuildContext context, TextTheme textTheme) {
    return ValueListenableBuilder<UpcomingClassSlot?>(
      valueListenable: homeController.upComingClassNotifier,
      builder: (context, value, child) {
        if (value == null || (homeController.userHomeData?.userAllPlans[0].remainingDays ?? 0) <= 0) {
          return const SizedBox.shrink();
        }

        return _buildUpcomingClassCard(context, textTheme, value);
      },
    );
  }

  Widget _buildUpcomingClassCard(BuildContext context, TextTheme textTheme, UpcomingClassSlot value) {
    return GestureDetector(
      onTap: () => _handleUpcomingClassTap(context, value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kSmallRadius),
          border: Border.all(color: MyColors.green),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value.upcomingSlot?.type ?? "",
                  style: textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  value.upcomingSlot?.status ?? "",
                  style: textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: _getStatusColor(value.upcomingSlot?.status ?? ""),
                  ),
                ),
              ],
            ),
            Text(
              "with ${value.trainer?.firstName ?? ""} ${value.trainer?.lastName ?? ""}",
              style: textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 5.h),
            Row(
              children: [
                _buildTimeInfo(textTheme, value.upcomingSlot?.start ?? ""),
                SizedBox(width: 20.w),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _handleUpcomingClassTap(BuildContext context, UpcomingClassSlot value) {
    Slot? slot = value.upcomingSlot;
    slot?.trainer = value.trainer;

    if (slot != null) {
      if (slot.status != "Cancelled") {
        HelpingWidgets.showWorkoutBottomSheet(
          context: context,
          slot: slot,
          homeController: homeController,
        );
      }
    } else {
      CustomToast.failToast(msg: "Something went wrong. Please try again later");
    }
  }

  Widget _buildTimeInfo(TextTheme textTheme, String time) {
    return Row(
      children: [
        Icon(Icons.access_time_rounded, size: _kSmallIconSize.w),
        SizedBox(width: 6.w),
        Text(
          time,
          style: textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Confirmed":
        return MyColors.buttonColor;
      case "Cancelled":
        return MyColors.red1;
      default:
        return Colors.black;
    }
  }

  Widget _buildSpacing(Size size, bool isSmallScreen, bool isMediumScreen, bool isLargeScreen) {
    if (!authController.logInUser!.status || homeController.isFrozen) {
      return SizedBox(height: 10.h);
    }

    final spacingFactor = isLargeScreen
        ? 0.26
        : isMediumScreen
            ? 0.25
            : 0.24;
    return SizedBox(height: size.height * spacingFactor);
  }

  bool _shouldShowMigrationBanner() {
    final prefs = Get.find<AuthController>().sharedPreferences;
    final dataProvided = prefs.getInt('cycle_data_provided') ?? -1;
    final dismissed = prefs.getBool('cycle_banner_dismissed') ?? false;
    return dataProvided == 0 && !dismissed;
  }

  bool _shouldShowFreezeSection() {
    return authController.logInUser!.status &&
        (homeController.userHomeData?.userAllPlans.isNotEmpty ?? false) &&
        homeController.userHomeData?.userAllPlans.first.title != "Free Trial" &&
        homeController.userHomeData!.userAllPlans[0].remainingDays > 0;
  }

  Widget _buildFreezeSection(BuildContext context, TextTheme textTheme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _kDefaultPadding.w),
      child: Row(
        children: [
          Expanded(
            child: _buildFreezeTextField(context, textTheme),
          ),
          SizedBox(width: 10.w),
          _buildFreezeButton(context, textTheme),
        ],
      ),
    );
  }

  Widget _buildFreezeTextField(BuildContext context, TextTheme textTheme) {
    return CustomTextField(
      keyboardType: TextInputType.text,
      text: "Duration Freeze".tr,
      length: 30,
      controller: authController.dateExtendController,
      Readonly: true,
      bordercolor: MyColors.primaryGradient1,
      inputFormatters: FilteringTextInputFormatter.singleLineFormatter,
      suffixIcon: GestureDetector(
        onTap: () => _showFreezeDatePicker(context),
        child: Image.asset(
          MyImgs.calender2,
          scale: 3,
        ),
      ),
    );
  }

  Future<void> _showFreezeDatePicker(BuildContext context) async {
    bool isFreezing = !homeController.userHomeData!.userData.freeze.value;

    if (isFreezing) {
      final tutorialService = Get.find<YouTubeTutorialService>();
      await tutorialService.showFreezeTutorial(context);
    }

    if (homeController.userHomeData!.userData.usedFreezeOption.value) {
      CustomToast.failToast(msg: "You have already used this option");
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: MyColors.buttonColor,
            hintColor: MyColors.buttonColor,
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: homeController.userHomeData!.userAllPlans[0].remainingDays)),
    );

    if (picked != null) {
      authController.dateExtendController.text = "${picked.difference(DateTime.now()).inDays} days";
    }
  }

  Widget _buildFreezeButton(BuildContext context, TextTheme textTheme) {
    return Obx(
      () => homeController.userHomeLoad.value
          ? GestureDetector(
              onTap: () => _handleFreezeAction(),
              child: GetBuilder<HomeController>(
                id: 'freezeButton',
                builder: (cont) {
                  return Container(
                    alignment: Alignment.center,
                    width: 100.w,
                    height: 56.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: MyColors.buttonColor,
                    ),
                    child: Text(
                      cont.userHomeData!.userData.freeze.value ? "Unfreeze" : "Freeze",
                      style: textTheme.bodySmall,
                    ),
                  );
                },
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  void _handleFreezeAction() {
    if (homeController.userHomeData!.userData.usedFreezeOption.value) {
      CustomToast.failToast(msg: "You have already used this option");
      return;
    }

    if (homeController.userHomeData!.userData.freeze.value) {
      homeController.freezeMyAccount(false);
    } else {
      if (authController.dateExtendController.text.isEmpty) {
        CustomToast.failToast(msg: "Please enter freeze days");
      } else {
        homeController.freezeMyAccount(true);
      }
    }
  }

  Widget _buildGridSection(BuildContext context, TextTheme textTheme, Size size, bool isSmallScreen, bool isMediumScreen, bool isLargeScreen) {
    final gridHeight = isLargeScreen
        ? size.height * 0.28
        : isMediumScreen
            ? size.height * 0.26
            : size.height * 0.30;

    return SizedBox(
      height: gridHeight,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 15.h),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 20.w,
          mainAxisSpacing: 14.h,
          childAspectRatio: 0.90,
        ),
        itemCount: textList.length,
        itemBuilder: (context, index) => _buildGridItem(context, textTheme, index),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, TextTheme textTheme, int index) {
    return GestureDetector(
      onTap: () => _handleGridItemTap(context, index),
      child: Column(
        children: [
          Expanded(
            child: GradientBorderContainer(
              child: Center(child: SvgPicture.asset(textList[index]["image"]!)),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            textList[index]["text"]!,
            style: textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w500,
              color: MyColors.primaryGradient3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _handleGridItemTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Get.to(() => WorkPlansOfUser());
        break;
      case 1:
      case 2:
        Get.to(() => DietScreen());
        homeController.getUsersBasedOnUserType(index == 3
            ? Constants.GYNECOLOGIST
            : index == 2
                ? Constants.PSYCHIATRIST
                : Constants.dietitian);

      case 3:
        CustomToast.successToast(msg: "Coming soon! Stay tuned");
        break;
      case 4:
        Get.to(() => const AppWebView(
              url: "https://pcos.thefither.com/",
              appName: "PCOS Risk Assessment Test",
            ));
        break;
      case 5:
        CustomToast.successToast(msg: "Coming soon! Stay tuned");
        break;
      case 6:
        CustomToast.successToast(msg: "Coming soon! Stay tuned");
        break;
      case 7:
        Get.to(() => OurJourneyScreen());
        break;
    }
  }

  Widget _buildTopSellersSection(BuildContext context, TextTheme textTheme, Size size) {
    return Column(
      children: [
        SizedBox(height: 20.h),
        const BorderTitleWidget(text: "Top Sellers Plans"),
        SizedBox(height: 20.h),
        SizedBox(
          height: size.height * 0.39,
          child: Obx(() => homeController.getPlanLoaded.value ? _buildPlansCarousel(size) : const CircularProgress()),
        ),
      ],
    );
  }

  Widget _buildPlansCarousel(Size size) {
    return CarouselSlider(
      options: CarouselOptions(
        height: size.height * 0.37,
        autoPlay: true,
        viewportFraction: 0.7,
        enlargeFactor: 0.2,
        enlargeCenterPage: true,
        enlargeStrategy: CenterPageEnlargeStrategy.scale,
      ),
      items: homeController.allPlanModel!.plans.map((plan) {
        return Builder(
          builder: (BuildContext context) {
            if (plan.countries!.isNotEmpty && plan.countries!.first.duration!.isNotEmpty) {
              plan.selectedDurationId.value = plan.countries!.first.duration!.first.id!;
            }
            return PlanWidget(plan: plan);
          },
        );
      }).toList(),
    );
  }

  Widget _buildTeamSection(BuildContext context, TextTheme textTheme, Size size) {
    return Column(
      children: [
        SizedBox(height: 40.h),
        const BorderTitleWidget(text: "Our Team"),
        SizedBox(height: 20.h),
        CarouselSlider(
          options: CarouselOptions(
            height: 250.h,
            autoPlay: true,
            viewportFraction: 0.7,
            enlargeFactor: 0.3,
            enlargeCenterPage: true,
            enlargeStrategy: CenterPageEnlargeStrategy.scale,
          ),
          items: homeController.team
              .map((member) => Builder(
                    builder: (BuildContext context) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(member),
                      );
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  bool _shouldShowProgressCard() {
    return authController.logInUser!.status && !homeController.isFrozen;
  }

  Widget _buildProgressCard(BuildContext context, TextTheme textTheme, Size size, bool isSmallScreen, bool isMediumScreen, bool isLargeScreen) {
    return ValueListenableBuilder(
      valueListenable: homeController.upComingClassNotifier,
      builder: (context, value, _) {
        final topPosition = _calculateProgressCardTopPosition(value, size, isSmallScreen, isMediumScreen, isLargeScreen);

        return Positioned(
          top: topPosition,
          left: 19.w,
          right: 19.w,
          child: _buildProgressCardContent(context, textTheme, size),
        );
      },
    );
  }

  double _calculateProgressCardTopPosition(UpcomingClassSlot? value, Size size, bool isSmallScreen, bool isMediumScreen, bool isLargeScreen) {
    if (value != null && homeController.userHomeData!.userAllPlans[0].remainingDays > 0) {
      return isLargeScreen
          ? size.height * 0.29
          : isMediumScreen
              ? size.height * 0.28
              : size.height * 0.315;
    }
    return isLargeScreen
        ? size.height * 0.22
        : isMediumScreen
            ? size.height * 0.21
            : size.height * 0.22;
  }

  Widget _buildProgressCardContent(BuildContext context, TextTheme textTheme, Size size) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: MediaQuery.of(context).size.width - 38.w,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: MyColors.primaryGradient1),
            borderRadius: BorderRadius.circular(_kDefaultRadius),
          ),
          child: Obx(() => homeController.userHomeLoad.value ? _buildProgressCardBody(textTheme) : const Center(child: CircularProgress())),
        ),
        _buildProgressIndicator(textTheme),
        _buildProgressCardBottom(context, textTheme),
      ],
    );
  }

  Widget _buildProgressCardBody(TextTheme textTheme) {
    return Column(
      children: [
        SizedBox(height: 110.h),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Days Spent", style: textTheme.bodyMedium!),
            Text(
              homeController.userHomeData!.userAllPlans.isEmpty
                  ? "N/a"
                  : "${homeController.userHomeData!.userAllPlans[0].spendDays}/${homeController.userHomeData!.userAllPlans[0].remainingDays + homeController.userHomeData!.userAllPlans[0].spendDays}",
              style: textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        SizedBox(height: 150.h),
      ],
    );
  }

  Widget _buildProgressIndicator(TextTheme textTheme) {
    return Obx(() => homeController.userHomeLoad.value
        ? homeController.userHomeData!.userAllPlans.isNotEmpty
            ? Positioned(
                top: 20.h,
                child: CircularPercentIndicator(
                  radius: _kProgressRadius.w,
                  lineWidth: _kProgressLineWidth.w,
                  percent: homeController.getPlanValue(),
                  progressColor: homeController.userHomeData!.userAllPlans[0].remainingDays > 0 ? MyColors.primaryGradient1 : Colors.red,
                  arcBackgroundColor: MyColors.planColor,
                  circularStrokeCap: CircularStrokeCap.round,
                  startAngle: 180.0,
                  arcType: ArcType.HALF,
                ),
              )
            : const SizedBox.shrink()
        : const Center(child: CircularProgress()));
  }

  Widget _buildProgressCardBottom(BuildContext context, TextTheme textTheme) {
    return Obx(() => homeController.userHomeLoad.value
        ? homeController.userHomeData!.userAllPlans.isEmpty
            ? const SizedBox.shrink()
            : homeController.userHomeData!.userAllPlans[0].remainingDays > 0
                ? _buildDaysInfo(textTheme)
                : _buildRenewButton(context, textTheme)
        : const CircularProgress());
  }

  Widget _buildDaysInfo(TextTheme textTheme) {
    return Positioned(
      bottom: 20.h,
      child: Column(
        children: [
          SizedBox(height: 30.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDaySpentWidget(textTheme, "${homeController.userHomeData!.userAllPlans[0].spendDays}", "Done"),
              SizedBox(width: 15.w),
              _buildDaySpentWidget(textTheme, "${homeController.userHomeData!.userAllPlans[0].remainingDays}", "Remaining"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRenewButton(BuildContext context, TextTheme textTheme) {
    return Positioned(
      bottom: 20.h,
      left: 20.w,
      right: 20.w,
      child: CustomButton(
        text: "Renew Plan",
        onPressed: () async {
          await AnalyticsHelper.trackSubscribeClick(screenName: 'user_home_screen');
          final tutorialService = Get.find<YouTubeTutorialService>();
          await tutorialService.showSubscribeTutorial(context);
          _scrollToPosition(userHomeScreenScrollController.position.maxScrollExtent / 1.2);
        },
      ),
    );
  }

  Widget _buildDaySpentWidget(TextTheme textTheme, String text, String label) {
    return Container(
      height: 100.h,
      width: 120.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kSmallRadius),
        color: MyColors.planColor,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: textTheme.headlineLarge!.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 36.sp,
            ),
          ),
          Text(
            label,
            style: textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _scrollToPosition(double position) {
    userHomeScreenScrollController.animateTo(
      position,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }
}
