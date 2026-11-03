import 'dart:convert';
import 'dart:ui';
import 'package:fitness_zone_2/UI/dashboard_module/bottom_bar_screen/diet_plans_of_user.dart';
import 'package:fitness_zone_2/UI/dashboard_module/bottom_bar_screen/progress_screen_v2.dart';
import 'package:fitness_zone_2/screens/unpaid_progress_screen.dart';
import 'package:fitness_zone_2/UI/dashboard_module/bottom_bar_screen/workout_plans_of_user.dart';
import 'package:fitness_zone_2/UI/dashboard_module/posts_module/feed_screen.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import '../../../data/controllers/home_controller/home_controller.dart';
import '../../../data/controllers/workout_controller/work_out_controller.dart';
import '../../../values/constants.dart';
import '../../../values/my_colors.dart';
import '../../../values/my_imgs.dart';
import 'package:fitness_zone_2/data/Repos/checkin_repo/checkin_repository.dart';
import 'package:fitness_zone_2/data/Repos/cycle_repo/cycle_data_repository.dart';
import 'package:fitness_zone_2/data/api_provider/api_provider.dart';
import 'package:fitness_zone_2/data/services/notification_scheduler.dart';
import '../../chat/chat_home_screen.dart';
import '../home_screen/home_screen.dart';
import '../profile_screen/profile_screen.dart';
import '../../../data/controllers/socket_controller.dart';
import '../../../widgets/notification_permission_sheet.dart';
import '../../../helper/popup_manager.dart';
import '../../../helper/app_update_checker.dart';
import '../../../widgets/announcement_popup.dart';

class BottomBarScreen extends StatefulWidget {
  int? index;
  BottomBarScreen({Key? key, this.index = 0, this.roomId, this.userMap})
      : super(key: key);
  String? roomId;
  Map<String, dynamic>? userMap;

  @override
  State<BottomBarScreen> createState() => _BottomBarScreenState();
}

class _BottomBarScreenState extends State<BottomBarScreen> {
  late List<Widget> _widgetOption = [];
  final Set<int> _activatedTabs = {};
  AuthController authController = Get.find();
  Worker? _opensWorker;
  ModalRoute<dynamic>? _myRoute;
  @override
  void initState() {
    super.initState();
    _activatedTabs.add(widget.index ?? 0);
    // Pop-up manager: knows when Home is the open tab, and asks again on
    // every new app open for pop-ups that lost their turn.
    PopupManager.init();
    PopupManager.onHomeTab = (widget.index ?? 0) == 0;
    _opensWorker = ever(PopupManager.opens, (_) {
      if (!mounted) return;
      // Required update is checked again on every app open, not only at
      // the start (once-a-day rule for the optional one still applies).
      AppUpdateChecker.check();
      NotificationPermissionSheet.maybeAsk();
      _maybeShowAnnouncement();
    });
    // Register SocketController here so any tab (especially FeedScreen) can
    // safely call Get.find<SocketController>() regardless of visit order.
    // Admin has no FeedScreen tab, but registering early is harmless.
    if (!Get.isRegistered<SocketController>()) {
      Get.put(SocketController(), permanent: true);
    }
    // "Turn on notifications" while they're off; "Not now" = 1 day.
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) NotificationPermissionSheet.maybeAsk();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authController.loginAsA.value == Constants.user) {
        final homeController = Get.find<HomeController>();
        // Paused plan? (no classes / consultations while paused)
        homeController.refreshPlanFrozen();
        homeController.getPlansUser();
        homeController.getMyTrialJourney();
        if (Get.isRegistered<WorkOutController>()) {
          Get.find<WorkOutController>().getWorkoutAllPlansFunc(silent: true);
        }
      }
      authController.showDot.value =
          authController.sharedPreferences.getBool("showDot") ?? false;
    });
    // Trainers and dietitians get a 4th "Community" tab between Chat and
    // Profile. Same FeedScreen the women users see — single shared feed,
    // no separate version. Paywall bypass for these roles is handled
    // inside FeedScreen / CreatePostScreen via `userType` checks.
    final isPro = authController.loginAsA.value == Constants.trainer ||
        authController.loginAsA.value == Constants.dietitian;
    _widgetOption = authController.loginAsA.value == Constants.admin
        ? [
            HomeScreen(),
            ChatHomeScreen(),
            ProfileScreen(),
          ]
        : authController.loginAsA.value == Constants.user
            ? [
                HomeScreen(),
                WorkPlansOfUser(
                  showBackButton: false,
                ),
                DietPlansOfUser(
                  showBackButton: false,
                ),
                // Progress tab — paid users (status=true) see the new V2
                // hub; unpaid users see a preview of the Day-14 report
                // (UnpaidProgressScreen) instead of the legacy V1.
                // Mirrors the home_screen.dart paid-vs-free pattern. The
                // useNewProgressHub flag is retained in the DB/model for
                // backward compat but no longer drives routing.
                ((authController.logInUser?.status ?? false)
                    ? const ProgressScreenV2()
                    : const UnpaidProgressScreen()),
                FeedScreen()
                // ChatRoom(
                //     chatRoomId: widget.roomId ?? "",
                //     userMap: widget.userMap ?? {}),
              ]
            : isPro
                ? [
                    HomeScreen(),
                    ChatHomeScreen(),
                    FeedScreen(),
                    ProfileScreen(),
                  ]
                : [
                    HomeScreen(),
                    ChatHomeScreen(),
                    ProfileScreen(),
                  ];

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowAnnouncement());
    // Old "rate your class" popup on every app open after a class is
    // gone: class feedback is now one card on home after the class ends
    // (widgets/class_feedback). Clear the leftover flag from old builds.
    authController.sharedPreferences.remove(Constants.giveReview);

    // Cycle data migration check — only for regular users
    if (authController.loginAsA.value == Constants.user) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkCycleMigration();
        _rescheduleNotifications();
      });
    }
  }

  // Pop-up manager: this route on top = nothing else open over Home
  // (works for paid and trial/free Home alike).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _myRoute = ModalRoute.of(context);
    PopupManager.homeRoute = _myRoute;
  }

  @override
  void dispose() {
    if (PopupManager.homeRoute == _myRoute) {
      PopupManager.homeRoute = null;
    }
    _opensWorker?.dispose();
    super.dispose();
  }

  /// Announcement saved from a push (widgets/announcement_popup.dart).
  void _maybeShowAnnouncement() => AnnouncementPopup.maybeShow();

  void _checkCycleMigration() async {
    final repo = Get.find<CycleDataRepository>();
    final token =
        authController.sharedPreferences.getString(Constants.accessToken) ?? '';
    final response = await repo.getCycleData(accessToken: token);
    if (response.body != null && response.body['status'] == '1') {
      // No cycle data: the full-screen "What's new" page used to open
      // here. Removed (Oct 2026); her period date comes from the health
      // form and the "Add your period date" card on Home.
      if (response.body['data'] != null) {
        authController.sharedPreferences.setInt(
          'cycle_data_provided',
          response.body['data']['dataProvided'] ?? 0,
        );
      }
    }
  }

  void _rescheduleNotifications() async {
    debugPrint('🔔 _rescheduleNotifications called');
    final token =
        authController.sharedPreferences.getString(Constants.accessToken) ?? '';
    final apiProvider = Get.find<ApiProvider>();

    // 1. Fetch notification preferences
    final prefsResponse = await apiProvider.getData(
      '/users/notification_preferences',
      headers: {'accessToken': token},
    );

    Map<String, dynamic> prefs = {
      'morningNudge': 1,
      'weeklyCheckin': 1,
    };
    if (prefsResponse.body != null &&
        prefsResponse.body['status'] == '1' &&
        prefsResponse.body['data'] != null) {
      prefs = Map<String, dynamic>.from(prefsResponse.body['data']);
    }

    // 2. Check if weekly check-in already done this week
    bool weeklyDone = false;
    final checkinRepo = Get.find<CheckinRepository>();
    final weeklyResponse =
        await checkinRepo.getWeeklyCheckinsRecent(accessToken: token);
    if (weeklyResponse.body != null &&
        weeklyResponse.body['status'] == '1' &&
        weeklyResponse.body['data'] is List) {
      final checkins = weeklyResponse.body['data'] as List;
      if (checkins.isNotEmpty) {
        final latest = checkins.first;
        final weekDate = latest['weekDate'] as String?;
        if (weekDate != null) {
          final now = DateTime.now();
          final monday = now.subtract(Duration(days: now.weekday - 1));
          final mondayStr =
              '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
          weeklyDone = weekDate == mondayStr;
        }
      }
    }

    // 3. Reschedule. The weekly check-in is for paid plans only: no
    // reminder once her plan has ended.
    // Oct 2026: the phone's own Sunday reminder is off for everyone. The
    // server sends the Sunday 7 pm push only when her check-in is due
    // (helper/notifications/weeklyCheckin.js); both together sent it twice.
    prefs = {...prefs, 'weeklyCheckin': 0};
    await NotificationScheduler.rescheduleAll(
      prefs: prefs,
      weeklyCheckinDone: weeklyDone,
    );
    debugPrint('🔔 rescheduleAll completed');
  }

  // int _currentIndex = wi;

  var scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // drawer: MyDrawer(),
      backgroundColor: MyColors.primaryColor,
      key: scaffoldKey,
      resizeToAvoidBottomInset: true,
      body: IndexedStack(
        index: widget.index!,
        children: List.generate(_widgetOption.length, (i) {
          if (_activatedTabs.contains(i)) {
            return _widgetOption[i];
          }
          return const SizedBox.shrink();
        }),
      ),
      // WhatsApp floating button removed (kept clean home).
      bottomNavigationBar: Get.find<AuthController>().loginAsA.value ==
              Constants.user
          ? _buildUserOrProNav(textTheme: textTheme, forPro: false)
          : (Get.find<AuthController>().loginAsA.value == Constants.trainer ||
                  Get.find<AuthController>().loginAsA.value ==
                      Constants.dietitian)
              ? _buildUserOrProNav(textTheme: textTheme, forPro: true)
              : _legacyAdminNav(textTheme: textTheme),
    );
  }

  /// User-side and trainer/dietitian both use the standard
  /// `BottomNavigationBar` chrome (white bg, accent-circle on active,
  /// icon-on-top + label-below). User-side has 5 tabs, pros have 4
  /// (Home / Chat / Community / Profile). Falls back to this chrome
  /// instead of the legacy rounded green pill so "Community" never gets
  /// clipped at narrow widths.
  Widget _buildUserOrProNav({
    required TextTheme textTheme,
    required bool forPro,
  }) {
    return PreferredSize(
      preferredSize: Size.fromHeight(70.h),
      child: BottomNavigationBar(
        elevation: 0,
        backgroundColor: Colors.white,
        currentIndex: widget.index!,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: MyColors.primaryGradient1,
        unselectedIconTheme:
            const IconThemeData(color: MyColors.primaryGradient1),
        unselectedLabelStyle: TextStyle(
            color: MyColors.primaryGradient1,
            fontWeight: FontWeight.w500,
            fontSize: 10.sp),
        selectedIconTheme: const IconThemeData(color: MyColors.primaryColor),
        selectedFontSize: 10.sp,
        items: forPro ? _proItems() : _userItems(),
        onTap: (value) async {
          // Pre-existing showDot-clear behaviour for women users — fires
          // when value == 3 (was the Progress tab in older layouts; kept
          // verbatim to avoid behaviour drift). Pros don't carry showDot.
          if (!forPro && value == 3) {
            authController.sharedPreferences.setBool("showDot", false);
            authController.showDot.value = false;
          }
          PopupManager.onHomeTab = value == 0;
          setState(() {
            widget.index = value;
            _activatedTabs.add(value);
          });
        },
      ),
    );
  }

  Color get _phaseAccent {
    try {
      return Get.find<CycleThemeController>().theme.value.accent;
    } catch (_) {
      return MyColors.buttonColor;
    }
  }

  /// Active-state circle behind the icon — phase-accent coloured, white icon.
  Widget _activeIconCircle(String svgAsset) => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: _phaseAccent),
        child: SvgPicture.asset(
          svgAsset,
          height: 30,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      );

  /// Pro variant of the active-icon circle for tabs that use Material
  /// icons instead of SVG (Chat, Profile — no SVG asset exists).
  Widget _activeMaterialIconCircle(IconData icon) => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: _phaseAccent),
        child: Icon(icon, color: Colors.white, size: 24),
      );

  /// Trainer / dietitian — 4 tabs: Home / Chat / Community / Profile.
  /// Home + Community use the same SVG assets as the user-side nav so
  /// shared tabs feel identical. Chat + Profile fall back to Material
  /// icons because no SVG counterpart exists in `MyImgs`.
  List<BottomNavigationBarItem> _proItems() {
    return [
      BottomNavigationBarItem(
        icon: SvgPicture.asset(MyImgs.homeSVG, height: 30),
        activeIcon: _activeIconCircle(MyImgs.homeSVG),
        label: "Home",
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 28),
        activeIcon: _activeMaterialIconCircle(Icons.chat_bubble_rounded),
        label: "Chat",
      ),
      BottomNavigationBarItem(
        icon: SvgPicture.asset(MyImgs.helpSVG, height: 30),
        activeIcon: _activeIconCircle(MyImgs.helpSVG),
        label: "Community",
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline_rounded, size: 28),
        activeIcon: _activeMaterialIconCircle(Icons.person_rounded),
        label: "Profile",
      ),
    ];
  }

  /// Regular women user — 5 tabs: Home / Workout / Diet / Progress / Community.
  /// Verbatim from the previous version of this file.
  List<BottomNavigationBarItem> _userItems() {
    return [
      BottomNavigationBarItem(
        icon: SvgPicture.asset(MyImgs.homeSVG, height: 30),
        activeIcon: _activeIconCircle(MyImgs.homeSVG),
        label: "Home",
      ),
      BottomNavigationBarItem(
        icon: SvgPicture.asset(MyImgs.workout, height: 30),
        activeIcon: _activeIconCircle(MyImgs.workout),
        label: "Workout",
      ),
      BottomNavigationBarItem(
        icon: SvgPicture.asset(MyImgs.diet, height: 30),
        activeIcon: _activeIconCircle(MyImgs.diet),
        label: "Diet",
      ),
      BottomNavigationBarItem(
        icon: SvgPicture.asset(MyImgs.progress, height: 30),
        activeIcon: _activeIconCircle(MyImgs.progress),
        label: "Progress",
      ),
      BottomNavigationBarItem(
        icon: Stack(
          alignment: Alignment.topRight,
          children: [
            SvgPicture.asset(MyImgs.helpSVG, height: 30),
            dotWidget(),
          ],
        ),
        activeIcon: Stack(
          alignment: Alignment.topRight,
          children: [
            _activeIconCircle(MyImgs.helpSVG),
            dotWidget(),
          ],
        ),
        label: "Community",
      ),
    ];
  }

  /// Admin / specialists / customer support — legacy rounded green pill,
  /// 3 tabs: Home / Chat / Profile. Verbatim from the previous version.
  Widget _legacyAdminNav({required TextTheme textTheme}) {
    return Container(
      padding: EdgeInsets.only(bottom: 20.h, left: 20, right: 20.w),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: PreferredSize(
          preferredSize: Size.fromHeight(56.h),
          child: BottomNavigationBar(
            elevation: 0,
            backgroundColor: MyColors.buttonColor,
            currentIndex: widget.index!,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.white,
            unselectedItemColor: MyColors.black,
            selectedFontSize: 0,
            unselectedFontSize: 0,
            selectedIconTheme:
                const IconThemeData(color: MyColors.primaryColor),
            items: [
              BottomNavigationBarItem(
                icon: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.home),
                    SizedBox(width: 5.w),
                    Text(
                      "Home",
                      style: textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                          color:
                              widget.index == 0 ? Colors.white : Colors.black),
                    ),
                  ],
                ),
                label: "",
              ),
              BottomNavigationBarItem(
                icon: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.message),
                    SizedBox(width: 5.w),
                    Text(
                      "Chat",
                      style: textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                          color:
                              widget.index == 1 ? Colors.white : Colors.black),
                    ),
                  ],
                ),
                label: "",
              ),
              BottomNavigationBarItem(
                icon: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person),
                    SizedBox(width: 5.w),
                    Text(
                      "Profile",
                      style: textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                          color:
                              widget.index == 2 ? Colors.white : Colors.black),
                    ),
                  ],
                ),
                label: "",
              ),
            ],
            onTap: (value) async {
              PopupManager.onHomeTab = value == 0;
              setState(() {
                widget.index = value;
                _activatedTabs.add(value);
              });
            },
          ),
        ),
      ),
    );
  }

  dotWidget() {
    return Obx(() => authController.showDot.value
        ? Container(
            height: 5,
            width: 5,
            decoration:
                BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          )
        : SizedBox.shrink());
  }
}
