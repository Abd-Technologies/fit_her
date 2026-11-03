import 'package:fitness_zone_2/helper/popup_manager.dart';
import 'package:fitness_zone_2/helper/class_join_memory.dart';
import 'package:fitness_zone_2/widgets/class_feedback/class_feedback_card.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:fitness_zone_2/data/controllers/workout_controller/work_out_controller.dart';
import 'package:fitness_zone_2/data/models/get_all_cat_plan/get_all_sub_cat.dart';
import 'package:fitness_zone_2/data/models/get_all_dietitian_trainers/add_diet_of_user.dart';
import 'package:fitness_zone_2/data/models/get_team_members/get_team_members.dart';
import 'package:fitness_zone_2/data/models/upcoming_class_slot.dart';
import 'package:fitness_zone_2/helper/permissions.dart';
import 'package:fitness_zone_2/values/my_imgs.dart';
import 'package:fitness_zone_2/UI/web_view.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fitness_zone_2/data/models/get_all_dietitian_trainers/get_all_dietitian_trainers.dart';
import 'package:fitness_zone_2/data/models/get_guest_user/get_guest_users.dart';
import 'package:fitness_zone_2/data/models/get_user_plan/get_user_plan.dart';
import 'package:fitness_zone_2/data/models/get_users_plan_images/get_user_plan_images.dart';
import 'package:fitness_zone_2/data/models/get_weekly_report/get_weekly_report.dart';
import 'package:fitness_zone_2/data/models/login_response_model/login_response_model.dart';
import 'package:fitness_zone_2/data/models/paymetn/direct_pay_url_response.dart';
import 'package:fitness_zone_2/data/models/paymetn/payment_link.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fitness_zone_2/UI/free_trail/trial_onboarding_screen.dart';
import 'package:fitness_zone_2/UI/free_trail/trial_class_celebration_screen.dart';
import 'package:fitness_zone_2/data/controllers/consultation_controller/consultation_controller.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:get/get_state_manager/src/rx_flutter/rx_disposable.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../UI/auth_module/sign_up_screen/goal_screen.dart';
import '../../../UI/auth_module/sign_up_screen/sign_up_screen_questions.dart';
import '../../../helper/analytics_helper.dart';
import '../../../helper/signup_progress.dart';
import '../../../values/constants.dart';
import '../../Repos/plan_freeze_repo/plan_freeze_repository.dart';
import '../../../widgets/toasts.dart';
import '../../GetServices/CheckConnectionService.dart';
import '../../Repos/home_repo/home_repo.dart';
import '../../models/api_response/api_response_model.dart';
import '../../models/get_all_cat_plan/get_all_categories.dart';
import '../../models/get_all_dietitian_users/get_all_dietitian_users.dart';
import '../../models/get_all_health_tips/get_health_tips.dart';
import '../../models/get_all_users/get_all_users.dart';
import '../../models/get_all_users/get_all_users_based_on_type.dart';
import '../../models/get_trainer_home/get_trainer_home.dart';
import '../../models/home_model/home_model.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class HomeController extends GetxController implements GetxService {
  SharedPreferences sharedPreferences;
  HomeRepo homeRepo;

  HomeController({required this.sharedPreferences, required this.homeRepo});

  CheckConnectionService connectionService = CheckConnectionService();

  @override
  void onInit() {
    initUpcomingSlot();
    _restoreTrialRx();
    trialPlanPending.value = sharedPreferences.getBool(kTrialPlanPendingKey) ?? false;
    dietOfUserByDiet = [
      getDietOfUser("Monday"),
      getDietOfUser("Tuesday"),
      getDietOfUser("Wednesday"),
      getDietOfUser("Thursday"),
      getDietOfUser("Friday"),
      getDietOfUser("Saturday"),
      getDietOfUser("Sunday"),
    ];
    if (sharedPreferences.getBool("showDotHome") == null) {
      showDotHome.value = false;
    } else if (sharedPreferences.getBool("showDotHome") == true) {
      // Was wrongly set to false here, silencing the unread dot for any
      // push that arrived while the app was closed. A stored `true` means
      // there's something unread waiting -> the dot should show.
      showDotHome.value = true;
    }

    super.onInit();
  }

  bool get isFrozen => (userHomeData?.freeze.value == 1);

  // Plan paused by her (freeze v2, UserPlan.frozenAt), from
  // GET plan-freeze status. One app-wide flag (Oct 2026): while paused
  // she only logs and sees insights; no classes, no consultations.
  // Set by PaidHero / PlanFrozenBanner when they load the status.
  final RxBool planFrozen = false.obs;

  Future<void> refreshPlanFrozen() async {
    try {
      final token = sharedPreferences.getString(Constants.accessToken) ?? '';
      if (token.isEmpty) return;
      final res = await Get.find<PlanFreezeRepository>().getStatus(accessToken: token);
      final b = res.body;
      if (b is Map && b['status'] == '1' && b['data'] is Map) {
        planFrozen.value = b['data']['isFrozen'] == true;
      }
    } catch (_) {}
  }

  /// True if user has at least one active plan (remaining days > 0). Used to restrict posts/messages.
  bool get hasActivePackage =>
      userHomeData != null && userHomeData!.userAllPlans.isNotEmpty && userHomeData!.userAllPlans.any((p) => p.remainingDays > 0);

  ///Notifcation listern

  ///adding team member
  List<String> addTeamMember = ["Dietition", "Trainer", "Gynecologist", "Psychiatrist", "Customer_Support_Representative"];
  var addedTeamMember = "Dietition".obs;

  RxBool get isCustomerSupport => RxBool(addTeamMember[4] == addedTeamMember.value);

  // String get customerSupporter =>
  //     "Customer Support Representative".replaceAll(" ", "_");

  ///Measurement controllers Weekly
  TextEditingController firstDay = TextEditingController();
  TextEditingController currentDate = TextEditingController();
  TextEditingController firstWeight = TextEditingController();
  TextEditingController currentWeight = TextEditingController();
  TextEditingController waist = TextEditingController();
  TextEditingController hips = TextEditingController();
  TextEditingController shoulder = TextEditingController();
  TextEditingController arms = TextEditingController();
  TextEditingController chest = TextEditingController();
  TextEditingController abdonmen = TextEditingController();
  TextEditingController thighs = TextEditingController();
  TextEditingController tellUsMore = TextEditingController();
  var selectedSatisfaction = 4.obs;
  final List<String> satisfactionEmojis = [
    '😡', // Very Unsatisfied
    '😕', // Unsatisfied
    '😐', // Neutral
    '😊', // Satisfied
    '😁', // Very Satisfied
  ];
  final List<String> labels = ["Very Unsatisfied", "Unsatisfied", "Neutral", "Satisfied", "Very Satisfied"];

  ValueNotifier<UpcomingClassSlot?> upComingClassNotifier = ValueNotifier<UpcomingClassSlot?>(null);

  checkTiming(String start, String end) {
    Timestamp timestamp = Timestamp.fromDate(DateTime.now());
    int startTime = covertToTimeStamp(start);
    int endTime = covertToTimeStamp(end);

    if (timestamp.millisecondsSinceEpoch > startTime && timestamp.millisecondsSinceEpoch < endTime) {
      return true;
    }
    return false;
  }

  initUpcomingSlot() {
    var list = sharedPreferences.getString(Constants.upcomingSlot);
    UpcomingClassSlot? notificationMessages;

    if (list != null) {
      notificationMessages = UpcomingClassSlot.fromJson(jsonDecode(list));
    }
    upComingClassNotifier.value = notificationMessages;
  }

  clearMeasurementController() {
    firstDay.clear();
    currentDate.clear();
    firstWeight.clear();
    currentWeight.clear();
    waist.clear();
    hips.clear();
    shoulder.clear();
    arms.clear();
    hips.clear();
    thighs.clear();
    abdonmen.clear();
    chest.clear();
    tellUsMore.clear();
  }

  ///Get Cat
  AllCategoriesOfPlan? allCategoriesOfPlan;
  GetSubCategories? allSubCategories;
  GetUsersBasedOnUserType? getUsersBasedOnUserTypeModel;
  AllPlanModel? allPlanModel;
  GetAllHealthTips? getAllHealthTips;
  GetAllDietitianAndTrainers? getAllDietitianAndTrainers;
  GetAllUsers? getAllUsers;
  GetGuestData? getGuestData;
  GetAllPlansImages? getAllPlansImages;
  GetTeamMembers? getTeamMembers;
  GetTrainerHome? getTrainerHome;
  GetDietitianUsers? getDietitianUsers;
  UserHomeData? userHomeData;
  DateTime? _lastUserHomeFetched;
  static const Duration _userHomeTtl = Duration(minutes: 3);
  GetWeeklyReportsModel? getWeeklyReportsModel;

  var team = [MyImgs.team1, MyImgs.team2, MyImgs.team3, MyImgs.team4];

  ///My Weekly Report Function

  var selectedPlanIndex = 0.obs;

  // List<addPackage.Time> addPackageTimeTable = [];
  List<DietOfUser> dietOfUserByDiet = [];

  ///get Cat
  var getCatLoaded = false.obs;
  var getSubCatLoaded = false.obs;
  var getUsersBasedOnUserTypeLoad = false.obs;
  var getPlanLoaded = false.obs;
  var getHealthTipsLoad = false.obs;
  var getDietitianLoad = false.obs;
  var getAllUsersLoad = false.obs;
  var trainerHomeLoad = false.obs;
  var weeklyReportLoad = false.obs;
  var dietHomeLoad = false.obs;
  var guestUserLoad = false.obs;
  var userHomeLoad = false.obs;
  var getPlanImagesLoad = false.obs;
  var getTeamMembersLoad = false.obs;
  var trialLoad = false.obs;
  /// Nov 2026: true once her trial status was checked this session. Until
  /// then Home doesn't decide "unpaid" for a woman whose trial may be
  /// running (after logout + login she briefly saw the plans home).
  final RxBool trialChecked = false.obs;
  var trialActionLoad = false.obs;
  Map<String, dynamic>? trialJourney;

  // ── Free trial "live" state ─────────────────────────────────────────
  // True while her 3-day trial is running (started, not expired, not
  // converted). Drives the home switch: a live trial user sees the paid
  // home with a trial banner instead of the unpaid home. Persisted so a
  // cold start doesn't flash the unpaid home before the journey loads.
  static const String _kTrialStartedAtKey = 'trialStartedAtIso';
  static const String _kTrialDaysKey = 'trialDays';
  /// Trial length in days, sent by the backend (TRIAL_DAYS in .env) in
  /// the journey payload. Defaults to 3 until the first load.
  final RxInt trialDays = 3.obs;
  Duration get kTrialLength => Duration(days: trialDays.value);

  /// Free-trial user right now: an unconverted 3-day trial that hasn't
  /// ended, or a "Free Trial" plan. Same rule as the class Join button
  /// (HelpingWidgets._isFreeTrialUser). Used by analytics.
  RxBool get isFreeTrialUser {
    final j = trialJourney;
    var activeTrial = false;
    if (j != null && j['convertedAt'] == null) {
      final started = DateTime.tryParse(j['startedAt']?.toString() ?? '');
      activeTrial =
          started != null && DateTime.now().isBefore(started.add(kTrialLength));
    }
    final freePlan = userHomeData?.userAllPlans.any(
          (p) => p.title.trim().toLowerCase() == 'free trial',
        ) ??
        false;
    return (activeTrial || freePlan).obs;
  }

  /// From the backend (TRIAL_JOIN_WINDOW_MINUTES / TRIAL_CLASS_GOAL).
  final RxInt joinWindowMinutes = 10.obs;
  // Placeholder until the server sends the real goal (half the trial days,
  // rounded up; 2 for a 3-day trial).
  final RxInt classGoal = 2.obs;
  final RxInt classesAttended = 0.obs;
  final RxInt attendanceMinutes = 10.obs;

  /// Last loaded class schedule (GET /trial/classes), shared by the home
  /// "next class" card, the trial screen and the late-join message.
  final Rxn<Map<String, dynamic>> trialClassData = Rxn<Map<String, dynamic>>();

  DateTime? _trialClassesLoadedAt;

  /// Home refresh (Nov 2026): reload the trial class list at most every
  /// 2 minutes while her trial runs, so the free-trial box sees a changed
  /// time, a cancelled class or a finished class (it used to load once).
  Future<void> refreshTrialClassesIfStale() async {
    if (!trialLive.value) return;
    final at = _trialClassesLoadedAt;
    if (at != null && DateTime.now().difference(at) < const Duration(minutes: 2)) return;
    _trialClassesLoadedAt = DateTime.now();
    await loadTrialClasses();
  }

  /// Live class schedule for the trial class picker. Null on failure.
  Future<Map<String, dynamic>?> loadTrialClasses() async {
    try {
      final res = await homeRepo.getTrialClasses(
        accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      );
      final body = res.body;
      if (body is Map && body['status'] == '1' && body['data'] is Map) {
        final data = Map<String, dynamic>.from(body['data'] as Map);
        trialClassData.value = data;
        return data;
      }
    } catch (_) {}
    return null;
  }

  /// "My trial" summary + offer (GET /trial/summary). Null on failure.
  /// [peek]: read only (home recap card); the offer countdown starts
  /// when she opens the summary itself.
  Future<Map<String, dynamic>?> loadTrialSummary({bool peek = false}) async {
    try {
      final country = await getCountryCode();
      final res = await homeRepo.getTrialSummary(
        accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        country: country,
        peek: peek,
      );
      final body = res.body;
      if (body is Map && body['status'] == '1' && body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
    } catch (_) {}
    return null;
  }

  List<Map<String, dynamic>> get trialClasses {
    final raw = trialClassData.value?['classes'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Her next class: first a picked class she can still join today, then
  /// any class today, then her first picked class tomorrow. Returns the
  /// class plus a label like "Today 7:30 PM" / "Tomorrow 8:00 AM".
  ({Map<String, dynamic> data, String label, bool today})? nextTrialClass({
    bool pickedOnly = false,
  }) {
    final all = trialClasses;
    if (all.isEmpty) return null;
    final picked = all.where((c) => c['picked'] == true).toList();
    final now = DateTime.now();
    final window = Duration(minutes: joinWindowMinutes.value);
    DateTime? at(Map<String, dynamic> c, DateTime day) {
      try {
        final t = DateFormat('hh:mm a').parse('${c['startLocal']}');
        return DateTime(day.year, day.month, day.day, t.hour, t.minute);
      } catch (_) {
        return null;
      }
    }

    // The list holds the whole week; each class runs on one weekday
    // ("dayLocal" in her time zone, else "day"). Only classes that run on
    // [day]'s weekday count (classes without a weekday are kept).
    bool runsOn(Map<String, dynamic> c, DateTime day) {
      final wd = '${c['dayLocal'] ?? c['day'] ?? ''}'.trim().toLowerCase();
      if (wd.isEmpty || wd == 'null') return true;
      return wd == DateFormat('EEEE').format(day).toLowerCase();
    }

    // Free trial (Nov 2026, same rule as the home class card and the
    // server): a class can be joined in its first [window] minutes. After
    // that, if she didn't join, show her next class. If she joined, keep
    // it until it ends (she can rejoin). Skip a class cancelled today, or
    // one that already finished.
    bool stillOnForHer(Map<String, dynamic> c, DateTime when, DateTime day) {
      final st = '${c['status'] ?? ''}'.trim().toLowerCase();
      if (st == 'cancelled') return false;
      if (st == 'completed' && !now.isBefore(when)) return false;
      if (now.isBefore(when.add(window))) return true;
      if (ClassJoinMemory.joinedToday(c['slotId'])) {
        try {
          final t = DateFormat('hh:mm a').parse('${c['endLocal']}');
          final end = DateTime(day.year, day.month, day.day, t.hour, t.minute);
          return now.isBefore(end);
        } catch (_) {
          return false;
        }
      }
      return false;
    }

    ({Map<String, dynamic> data, DateTime when})? firstFrom(
        List<Map<String, dynamic>> list, DateTime day, bool todayOnly) {
      final items = list
          .where((c) => runsOn(c, day))
          .map((c) => (data: c, when: at(c, day)))
          .where((x) => x.when != null)
          .map((x) => (data: x.data, when: x.when!))
          .where((x) => !todayOnly || stillOnForHer(x.data, x.when, day))
          .toList()
        ..sort((a, b) => a.when.compareTo(b.when));
      return items.isEmpty ? null : items.first;
    }

    final tomorrow = now.add(const Duration(days: 1));
    // Today: the soonest class she can still join (same one the home's
    // big class card shows). Picked-only screens use her picks.
    final hit = pickedOnly ? firstFrom(picked, now, true) : firstFrom(all, now, true);
    if (hit != null) {
      return (
        data: hit.data,
        // Already started (inside her join window, or she joined): "Live now".
        label: now.isBefore(hit.when)
            ? 'Today ${DateFormat('h:mm a').format(hit.when)}'
            : 'Live now',
        today: true,
      );
    }
    final next = firstFrom(picked.isNotEmpty ? picked : all, tomorrow, false);
    if (next == null) return null;
    return (
      data: next.data,
      label: 'Tomorrow ${DateFormat('h:mm a').format(next.when)}',
      today: false,
    );
  }

  /// Adds a class to her reminder picks (from the late-join "Remind me").
  Future<bool> addTrialReminderSlot(int slotId) =>
      updateTrialReminderSlots(add: {slotId});

  /// Replaces (replace != null) or extends (add) her reminder picks,
  /// keeping the rest of her workout answers untouched.
  Future<bool> updateTrialReminderSlots({Set<int>? replace, Set<int> add = const {}}) async {
    try {
      final consult = Get.find<ConsultationController>();
      final profile = await consult.loadProfile();
      final ws = Map<String, dynamic>.from(profile?.workoutSection ?? {});
      final ids = <int>{
        ...(replace ??
            ((ws['preferredSlotIds'] as List?) ?? const [])
                .map((e) => int.tryParse('$e'))
                .whereType<int>()),
        ...add,
      };
      ws['preferredSlotIds'] = ids.toList();
      final ok = await consult.patchProfile({'workoutSection': ws});
      if (ok) await loadTrialClasses();
      return ok;
    } catch (_) {
      return false;
    }
  }

  static const String _kCelebratedKey = 'trialCelebratedClasses';

  /// Show the "Class N of M done" celebration once for each new class.
  void _maybeCelebrate() {
    if (!trialLive.value) return;
    final done = classesAttended.value;
    final last = sharedPreferences.getInt(_kCelebratedKey) ?? 0;
    if (done <= last) return;
    sharedPreferences.setInt(_kCelebratedKey, done);
    // Through the pop-up manager (Oct 2026): waits for any open pop-up to
    // close, then shows, and uses up this open's turn so no planned
    // pop-up lands right after it. It used to open by itself, sometimes
    // on top of another pop-up.
    // Nov 2026: the after-class "well done" sheet (class_feedback_card.dart)
    // celebrates with her trial progress. Only when there's no sheet to
    // show for this class (rating paused, for example) the old full-screen
    // celebration still opens, so a counted class is always celebrated once.
    Future.delayed(const Duration(seconds: 5), () async {
      final fb = ClassFeedbackController.ensure();
      await fb.refreshPending(force: true);
      if (fb.pending.value != null) return;
      PopupManager.runNow('trial_class_celebration', () async {
        await Get.to(() => TrialClassCelebrationScreen(
              attended: done,
              goal: classGoal.value,
            ));
      });
    });
  }
  final Rxn<DateTime> trialStartedAt = Rxn<DateTime>();
  final RxBool trialLive = false.obs;
  Timer? _trialEndTimer;

  DateTime? get trialEndsAt => trialStartedAt.value?.add(kTrialLength);

  /// Her free trial is over and she hasn't bought a plan. Classes then lead
  /// to "Continue with a plan" instead of Join. Reactive (reads trialLive).
  bool get trialEndedUnpaid {
    final running = trialLive.value;
    final j = trialJourney;
    if (j == null || running || j['convertedAt'] != null) return false;
    // A real package wins. (user.status alone isn't enough: it can stay
    // true after a trial ends, which is why she kept the paid home.)
    return hasRealPlan == false; // unknown (not loaded) = don't block
  }

  /// Has a real package (not the free trial / system trial plan) with days
  /// left. null = plans not loaded yet. Same rule as Profile "Your plan".
  bool? get hasRealPlan {
    final plans = userHomeData?.userAllPlans;
    if (plans == null) return null;
    return plans.any((p) {
      final t = p.title.trim().toLowerCase();
      return t != 'free trial' && !t.startsWith('system') && p.remainingDays > 0;
    });
  }

  void _syncTrialRx() {
    final j = trialJourney;
    DateTime? started;
    var ended = true;
    if (j != null) {
      final w = int.tryParse('${j['joinWindowMinutes'] ?? ''}');
      if (w != null && w > 0) joinWindowMinutes.value = w;
      final g = int.tryParse('${j['classGoal'] ?? ''}');
      if (g != null && g > 0) classGoal.value = g;
      final a = int.tryParse('${j['classesAttended'] ?? ''}');
      if (a != null && a >= 0) classesAttended.value = a;
      final am = int.tryParse('${j['attendanceMinutes'] ?? ''}');
      if (am != null && am > 0) attendanceMinutes.value = am;
      final d = int.tryParse('${j['trialDays'] ?? ''}');
      if (d != null && d > 0) {
        trialDays.value = d;
        sharedPreferences.setInt(_kTrialDaysKey, d);
      }
      started = DateTime.tryParse('${j['startedAt'] ?? ''}')?.toLocal();
      ended = started == null ||
          j['convertedAt'] != null ||
          j['isExpired'] == true ||
          DateTime.now().isAfter(started.add(kTrialLength));
    }
    trialStartedAt.value = started;
    _applyTrialLive(started, ended);
    if (!ended && started != null) {
      sharedPreferences.setString(_kTrialStartedAtKey, started.toIso8601String());
    } else {
      sharedPreferences.remove(_kTrialStartedAtKey);
    }
    if (j != null && j['classesAttended'] != null) _maybeCelebrate();
  }

  void _applyTrialLive(DateTime? started, bool ended) {
    trialLive.value = !ended;
    _trialEndTimer?.cancel();
    if (!ended && started != null) {
      final left = started.add(kTrialLength).difference(DateTime.now());
      // Flip back to the unpaid home the moment the 3 days are up, even
      // if the app stays open.
      _trialEndTimer = Timer(left, () => trialLive.value = false);
    }
  }

  void _restoreTrialRx() {
    final savedDays = sharedPreferences.getInt(_kTrialDaysKey);
    if (savedDays != null && savedDays > 0) trialDays.value = savedDays;
    final saved = DateTime.tryParse(
        sharedPreferences.getString(_kTrialStartedAtKey) ?? '');
    if (saved == null) return;
    final ended = DateTime.now().isAfter(saved.add(kTrialLength));
    trialStartedAt.value = ended ? null : saved;
    _applyTrialLive(saved, ended);
  }

  // Trial-to-Plan funnel — quick-intake submit state.
  var trialQuickIntakeLoad = false.obs;
  // Oct 2026: the AI took longer than 6 s, so the server said "Your plan
  // will be shared soon" and is still making it. A push
  // ("trialPlanReady") arrives when it's ready. Saved on the phone so the
  // Diet tab still says "being prepared" after an app restart.
  final RxBool trialPlanPending = false.obs;
  static const String kTrialPlanPendingKey = 'trial_plan_pending';

  void setTrialPlanPending(bool v) {
    trialPlanPending.value = v;
    try {
      if (v) {
        sharedPreferences.setBool(kTrialPlanPendingKey, true);
      } else {
        sharedPreferences.remove(kTrialPlanPendingKey);
      }
    } catch (_) {}
  }

  ///testimonials pic
  XFile? testiPicture;
  XFile? dietPicture;
  XFile? profilePicture;
  XFile? planPicture;

  ///Add a new User
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController dateExtendController = TextEditingController();

  clearyControllers() {
    firstNameController.clear();
    lastNameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();
  }

  ///plans list
  var dietPlanList = <Plan>[].obs;
  var trainerPlanList = <Plan>[].obs;

  ///select cat id
  var selectedId = 0.obs;
  var selectedSubCatId = 0.obs;
  var selectCustomerSupport = 0.obs;
  var selectedPlanId = 0.obs;
  var selectedDurationId = 0.obs;
  var selectedDietId = 0.obs;
  var selectedDietIdForMember = 0.obs;
  var selectedTrainerId = 0.obs;
  var selectedTrainerIdForMember = 0.obs;
  var selectedTrainerIdForBoth = 0.obs;

  // getTimeModel(String day) {
  //   addPackage.Time timeModel = addPackage.Time(
  //       day: day,
  //       slots: [addPackage.Slot(start: "Start Time", end: "End Time")]);
  //   return timeModel;
  // }

  getDietOfUser(String day) {
    DietOfUser dietofDay = DietOfUser(day: day, meals: [MealOfUser(time: "Time", food: "N/A", calories: "N/A")]);
    return dietofDay;
  }

  getSubCatBasedOnUserType(String userType) {
    getSubCatLoaded.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getSubCategoriesBasedOnUserTypes(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userType: userType,
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetSubCategories> model = ApiResponse.fromJson(response.body, GetSubCategories.fromJson);
            if (model.status == "1") {
              allSubCategories = model.data!;
              if (allSubCategories!.data.isNotEmpty) {
                selectedSubCatId.value = allSubCategories!.data[0].id;
              }

              getSubCatLoaded.value = true;
            }
          }
        });
      }
    });
  }

  getUsersBasedOnUserType(String userType, {bool addNull = false}) {
    getUsersBasedOnUserTypeLoad.value = false;

    // Every failure path must release the loading flag, otherwise screens
    // that wait on it (e.g. the home "Diet"/"Psychiatrist" tiles ->
    // DietScreen) spin forever. Screens read the model with `!` once the
    // flag is true, so fall back to an empty list (they show their own
    // "nothing to show" state) rather than leaving it null.
    void releaseOnFailure() {
      getUsersBasedOnUserTypeModel ??= GetUsersBasedOnUserType(users: []);
      getUsersBasedOnUserTypeLoad.value = true;
    }

    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        releaseOnFailure();
      } else {
        homeRepo
            .getSubUserBasedOnUserTypes(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userType: userType,
        )
            .then((response) async {
          // Get.back();
          if (response.body is! Map) {
            CustomToast.failToast(msg: "Couldn't load. Please try again.");
            releaseOnFailure();
          } else if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
            releaseOnFailure();
          } else if (response.body["status"] != "0") {
            ApiResponse<GetUsersBasedOnUserType> model = ApiResponse.fromJson(response.body, GetUsersBasedOnUserType.fromJson);
            if (model.status == "1") {
              getUsersBasedOnUserTypeModel = model.data!;
              if (addNull) {
                getUsersBasedOnUserTypeModel?.users.insert(0, UserTypeData(id: 0, firstName: "Select", lastName: "..", email: "", phone: ""));
              } else {
                if (getUsersBasedOnUserTypeModel!.users.isNotEmpty) {
                  selectCustomerSupport.value = getUsersBasedOnUserTypeModel!.users.first.id;
                }
              }
              getUsersBasedOnUserTypeLoad.value = true;
            } else {
              releaseOnFailure();
            }
          }
        }).catchError((_) {
          CustomToast.failToast(msg: "Couldn't load. Please try again.");
          releaseOnFailure();
        });
      }
    });
  }

  getPlansBasedOnSubCat(String subCatId) {
    getPlanLoaded.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getPlansBasedOnSubCat(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          subCat: subCatId,
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<AllPlanModel> model = ApiResponse.fromJson(response.body, AllPlanModel.fromJson);
            if (model.status == "1") {
              allPlanModel = model.data!;

              getPlanLoaded.value = true;
            }
          }
        });
      }
    });
  }

  getWorkoutAndTrainerPlan() {
    getPlanLoaded.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getWorkoutAndTrainerPlan(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<AllPlanModel> model = ApiResponse.fromJson(response.body, AllPlanModel.fromJson);
            if (model.status == "1") {
              allPlanModel = model.data!;

              getPlanLoaded.value = true;
            }
          }
        });
      }
    });
  }

  Future<Map<String, dynamic>> getUserNameUsingId(int id) async {
    Map<String, dynamic> name = {"name": "unknown", "days": ""};

    // Use try-catch to handle errors
    try {
      var querySnapshot = await FirebaseFirestore.instance.collection("users").where("remoteId", isEqualTo: id).get();


      if (querySnapshot.docs.isNotEmpty) {
        var documentSnapshot = querySnapshot.docs.first;
        var data = documentSnapshot.data();
        name = {"name": data["name"], "days": data["days"]};
      }
    } catch (error) {
      // silently ignore — name stays null, caller handles missing value
    }

    return name;
  }

  getPlans() {
    getPlanLoaded.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        // Get.dialog(const Center(child: CircularProgressIndicator()),
        //     barrierDismissible: false);
        dietPlanList.value = [];
        trainerPlanList.value = [];

        homeRepo
            .getAllPlansAdmin(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<AllPlanModel> model = ApiResponse.fromJson(response.body, AllPlanModel.fromJson);
            if (model.status == "1") {
              allPlanModel = model.data!;
              if (allPlanModel!.plans.isNotEmpty) {
                selectedPlanId.value = allPlanModel!.plans[0].id ?? 0;
                selectedPlanIndex.value = 0;
                if (allPlanModel!.plans[0].countries!.isNotEmpty) {
                  allPlanModel!.plans[0].selectedDurationId.value = allPlanModel!.plans[0].countries![0].duration![0].id!;
                }
              }

              getPlanLoaded.value = true;
            }
          }
        });
      }
    });
  }

  getPlansUser() {
    getPlanLoaded.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        // Get.dialog(const Center(child: CircularProgressIndicator()),
        //     barrierDismissible: false);
        dietPlanList.value = [];
        trainerPlanList.value = [];
        String code = await getCountryCode();
        homeRepo
            .getAllPlans(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          code: code,
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<AllPlanModel> model = ApiResponse.fromJson(response.body, AllPlanModel.fromJson);
            if (model.status == "1") {
              allPlanModel = model.data!;
              if (allPlanModel!.plans.isNotEmpty) {
                selectedPlanId.value = allPlanModel!.plans[0].id ?? 0;
                selectedPlanIndex.value = 0;
                if (allPlanModel!.plans[0].countries!.isNotEmpty) {
                  allPlanModel!.plans[0].selectedDurationId.value = allPlanModel!.plans[0].countries![0].duration![0].id!;
                }
              }

              getPlanLoaded.value = true;
            }
          }
        });
      }
    });
  }

  Future<bool> addFreeTrial() async {
    bool already = false;
    await connectionService.checkConnection().then((value) async {
      if (!value) {
        already = false;
        CustomToast.noInternetToast();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        var c = await getCountryCode();
        await homeRepo.addFreeTrialUser(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {"userId": sharedPreferences.getString(Constants.userId) ?? "", "country": c},
        ).then((response) async {
          Get.back();
          if (response.body["status"] == "0") {
            // Check the machine-readable field first (added to assignFreePlan response).
            // Fall back to string match for backward compat with older server versions.
            final data = response.body["data"];
            final isAlreadyUsed = (data is Map && data["alreadyUsed"] == true) ||
                response.body["message"] == "You can't subscribe free trial at this movement";
            if (isAlreadyUsed) {
              already = true;
            } else {
              CustomToast.failToast(msg: response.body["message"]);
            }

            //  print('HomeController.addFreeTrial here');
          } else if (response.body["status"] != "0") {
            ApiResponse<AllPlanModel> model = ApiResponse.fromJson(response.body, (p0) {});
            if (model.status == "1") {
              CustomToast.successToast(msg: model.message);

              Get.find<WorkOutController>().getWorkoutAllPlansFunc(isFree: true);
              getUserHomeFunc(isFromFree: true);
              already = false;
            }
          }
        });
      }
    });
    return already;
  }

  double getPlanValue() {
    var value = userHomeData!.userAllPlans[0].spendDays / (userHomeData!.userAllPlans[0].remainingDays + userHomeData!.userAllPlans[0].spendDays);

    if (value >= 0 && value <= 1) {
      return value;
    }
    return 1;
  }

  getHealthTips() {
    getHealthTipsLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getHealthTips(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetAllHealthTips> model = ApiResponse.fromJson(response.body, GetAllHealthTips.fromJson);
            if (model.status == "1") {
              getAllHealthTips = model.data!;

              getHealthTipsLoad.value = true;
            }
          }
        });
      }
    });
  }

  getAllDietitian() {
    getDietitianLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        // Get.dialog(const Center(child: CircularProgressIndicator()),
        //     barrierDismissible: false);

        homeRepo
            .getDietAndTrain(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetAllDietitianAndTrainers> model = ApiResponse.fromJson(response.body, GetAllDietitianAndTrainers.fromJson);
            if (model.status == "1") {
              getAllDietitianAndTrainers = model.data!;
              selectedPlanIndex.value = 0;
              if (getAllDietitianAndTrainers!.dietitions.isNotEmpty) {
                selectedDietId.value = getAllDietitianAndTrainers!.dietitions[0].id;
              }
              if (getAllDietitianAndTrainers!.trainers.isNotEmpty) {
                selectedTrainerId.value = getAllDietitianAndTrainers!.trainers[0].id;
              }

              getDietitianLoad.value = true;
            }
          }
        });
      }
    });
  }

  getAllUsersFunc({bool isCustomerSupport = false}) {
    getAllUsersLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        // Get.dialog(const Center(child: CircularProgressIndicator()),
        //     barrierDismissible: false);

        homeRepo
            .getAllUsers(
          isCustomerSupport: isCustomerSupport,
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userId: sharedPreferences.getString(Constants.userId) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetAllUsers> model = ApiResponse.fromJson(response.body, GetAllUsers.fromJson);
            if (model.status == "1") {
              getAllUsers = model.data!;

              getAllUsersLoad.value = true;
            }
          }
        });
      }
    });
  }

  getWeeklyReportsFunc() {
    weeklyReportLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        // Get.dialog(const Center(child: CircularProgressIndicator()),
        //     barrierDismissible: false);

        homeRepo
            .getWeeklyReportsRepo(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetWeeklyReportsModel> model = ApiResponse.fromJson(response.body, GetWeeklyReportsModel.fromJson);
            if (model.status == "1") {
              getWeeklyReportsModel = model.data!;

              weeklyReportLoad.value = true;
              update();
            }
          }
        });
      }
    });
  }

  getDietHomeFunc() {
    dietHomeLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        // Get.dialog(const Center(child: CircularProgressIndicator()),
        //     barrierDismissible: false);

        homeRepo
            .getDietHome(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userId: sharedPreferences.getString(Constants.userId) ?? "0",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetDietitianUsers> model = ApiResponse.fromJson(response.body, GetDietitianUsers.fromJson);
            if (model.status == "1") {
              getDietitianUsers = model.data!;
              dietHomeLoad.value = true;
              update();
            }
          }
        });
      }
    });
  }

  Plan? trailPlan;
  var trialPlanLoad = false.obs;

  getTrialPlanDetails() {
    trialPlanLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        // Get.dialog(const Center(child: CircularProgressIndicator()),
        //     barrierDismissible: false);

        homeRepo
            .getFreePlan(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<Plan> model = ApiResponse.fromJson(response.body, Plan.fromJson);
            if (model.status == "1") {
              trailPlan = model.data!;
              trialPlanLoad.value = true;
              update();
            }
          }
        });
      }
    });
  }

  postTrialPlanDetails(String id, bool status) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        await homeRepo.changeFreeTrialStatus(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {"status": status, "id": id},
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: model.message);
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  getGuestUsers() {
    guestUserLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        // Get.dialog(const Center(child: CircularProgressIndicator()),
        //     barrierDismissible: false);

        homeRepo
            .getGuestUsers(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userId: sharedPreferences.getString(Constants.userId) ?? "0",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetGuestData> model = ApiResponse.fromJson(response.body, GetGuestData.fromJson);
            if (model.status == "1") {
              getGuestData = model.data!;

              guestUserLoad.value = true;
              update();
            }
          }
        });
      }
    });
  }

  getAllImagesPlan() {
    getPlanImagesLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        // Get.dialog(const Center(child: CircularProgressIndicator()),
        //     barrierDismissible: false);

        homeRepo
            .getPlanImages(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetAllPlansImages> model = ApiResponse.fromJson(response.body, GetAllPlansImages.fromJson);
            if (model.status == "1") {
              getAllPlansImages = model.data!;

              getPlanImagesLoad.value = true;
              update();
            }
          }
        });
      }
    });
  }

  getAllTeamMembers() {
    getTeamMembersLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        // Get.dialog(const Center(child: CircularProgressIndicator()),
        //     barrierDismissible: false);

        homeRepo
            .getTeamMembersRepo(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetTeamMembers> model = ApiResponse.fromJson(response.body, GetTeamMembers.fromJson);
            if (model.status == "1") {
              getTeamMembers = model.data!;

              getTeamMembersLoad.value = true;
              update();
            }
          }
        });
      }
    });
  }

  getUserHomeFunc({bool isFromFree = false, bool silent = false, bool forceRefresh = false}) {
    final now = DateTime.now();
    final isFresh = _lastUserHomeFetched != null &&
        now.difference(_lastUserHomeFetched!) < _userHomeTtl;

    if (!forceRefresh && !silent && userHomeData != null && isFresh) {
      userHomeLoad.value = true;
      return;
    }

    if (userHomeData == null && !silent) {
      userHomeLoad.value = false;
    }

    connectionService.checkConnection().then((value) async {
      if (!value) {
        if (!silent) CustomToast.noInternetToast();
      } else {
        // Get.dialog(const Center(child: CircularProgressIndicator()),
        //     barrierDismissible: false);
        String code = await getCountryCode();
        homeRepo
            .getUserHome(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userId: sharedPreferences.getString(Constants.userId) ?? "0",
          code: code,
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            if (!silent) CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<UserHomeData> model;
            try {
              model = ApiResponse.fromJson(response.body, UserHomeData.fromJson);
            } catch (e, st) {
              // Used to fail silently: she'd see an empty plan card
              // with no clue why. Print it so it shows in the run log.
              debugPrint('[userHome] could not read home data: $e\n$st');
              return;
            }
            if (model.status == "1") {
              userHomeData = model.data!;
              _lastUserHomeFetched = DateTime.now();
              userHomeLoad.value = true;
              // Was already true on a silent reload: still tell Home her plans
              // changed (e.g. just paid -> switch to the paid home now).
              userHomeLoad.refresh();
              // Mixpanel profile (no names): trial / paid / ended, so every
              // chart can be split by where she is in her journey.
              try {
                final real = hasRealPlan;
                AnalyticsHelper.setProfile({
                  'plan_state': real == true
                      ? 'paid'
                      : (trialEndedUnpaid
                          ? 'trial_ended'
                          : (isFreeTrialUser.value ? 'trial' : 'none')),
                  'active_plans': userHomeData!.userAllPlans
                      .where((p) => p.remainingDays > 0)
                      .map((p) => p.title)
                      .join(', '),
                });
              } catch (_) {}
              if (userHomeData!.userAllPlans.isEmpty) {
                upComingClassNotifier.value = null;
                await FirebaseMessaging.instance.unsubscribeFromTopic('userPlan');
              }
              if (userHomeData!.userAllPlans.isNotEmpty) {
                await FirebaseMessaging.instance.subscribeToTopic('userPlan');
                final hasPaidPlan = userHomeData!.userAllPlans
                    .any((p) => p.title != "Free Trial");
                if (hasPaidPlan && Get.isRegistered<AuthController>()) {
                  Get.find<AuthController>().markPaid();
                }
              }

              if (isFromFree) {
                Get.find<AuthController>().logInUser!.status = true;
              }
              update();
            }
          }
        });
      }
    });
  }

  addUser(
      {bool status = true,
      required String firstName,
      required String lastName,
      required String email,
      required String phone,
      required String password,
      required int customerSupportId,
      String? age,
      String? height,
      String? weight,
      String? price,
      String? bmiResult,
      String signupMethod = 'email'}) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        final String currentTimeZone = await FlutterTimezone.getLocalTimezone();

        await homeRepo.addUserRepo(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "password": password,
            "phone": phone.isEmpty ? Random.secure().nextInt(10000) : phone,
            "planId": status ? allPlanModel!.plans[selectedPlanIndex.value].id : null,
            "status": status,
            "deviceToken": sharedPreferences.getString(Constants.deviceToken) ?? "",
            "customSupporterId": customerSupportId,
            "durationId": status ? allPlanModel!.plans[selectedPlanIndex.value].selectedDurationId.value : null,
            "age": age,
            "weight": weight,
            "height": height,
            "bmiResult": bmiResult,
            "price": price,
            "timeZone": currentTimeZone,
            // Growth analytics: how and where she signed up.
            "signupMethod": signupMethod,
            "signupSource": sharedPreferences.getString('signup_source'),
            "signupCampaign": sharedPreferences.getString('signup_campaign'),
          },
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              if (!status) AnalyticsHelper.signupFailed(signupMethod, '${response.body["message"] ?? 'refused'}');
              final msg = '${response.body["message"] ?? ''}';
              if (!status && msg.toLowerCase().contains('email already')) {
                // Often her account was made but the answer was lost
                // (internet dropped): offer log in instead of a dead end.
                showAccountExistsDialog(email);
              } else {
                CustomToast.failToast(msg: response.body["message"]);
              }
            } else if (response.body["status"] != "0") {
              ApiResponse<LoginModel> model = ApiResponse.fromJson(response.body, LoginModel.fromJson);
              if (model.status == "1") {
                CustomToast.successToast(msg: response.body["message"]);

                if (!status) {
                  // Self sign-up (not admin adding a client).
                  AnalyticsHelper.setUserId(model.data!.id.toString());
                  AnalyticsHelper.signupCompleted(signupMethod);
                  AnalyticsHelper.setProfile({
                    'signup_method': signupMethod,
                    'signup_source': sharedPreferences.getString('signup_source') ?? 'organic',
                  });
                }
                if (status) {
                  getAllUsersFunc();
                } else {
                  Get.find<AuthController>().loginAsA.value = Constants.user;
                  sharedPreferences.setString(Constants.accessToken, model.data!.accessToken);
                  sharedPreferences.setString(Constants.userId, model.data!.id.toString());

                  sharedPreferences.setBool(Constants.isGuest, false);
                  Get.find<AuthController>().logInUser = model.data;
                  Get.find<AuthController>().addLocalStorage(model.data!, password);
                  // getPlans();
                  Get.offAll(() => const SignUpScreenQuestions());
                }
                clearyControllers();
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  /// Saves her profile answers. Returns true when the server saved them.
  /// [onboardingDone]: last sign-up page (server marks the questions done).
  /// [navigate]: false lets the caller decide what opens next.
  Future<bool> addUserDetails({bool status = true, String? age, String? height, String? weight, String? bmiResult, String? mainGoal, String? healthConditions, bool onboardingDone = false, bool navigate = true}) async {
    final online = await connectionService.checkConnection();
    if (!online) {
      if (navigate) CustomToast.noInternetToast();
      return false;
    }
    Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
    Response? response;
    try {
      response = await homeRepo.addUserDetails(
        accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        map: {
          "userId": sharedPreferences.getString(Constants.userId),
          "age": age,
          "weight": weight,
          "height": height,
          "bmiResult": bmiResult,
          if (mainGoal != null) "mainGoal": mainGoal,
          if (healthConditions != null) "healthConditions": healthConditions,
          if (onboardingDone) "onboardingDone": true,
        },
      ).timeout(const Duration(seconds: 25));
    } catch (_) {
      response = null;
    }
    if (Get.isDialogOpen ?? false) Get.back();

    final body = response?.body;
    if (response == null || response.statusCode != 200 || body is! Map) {
      if (navigate) CustomToast.failToast(msg: (body is Map ? body["message"] : null) ?? "Couldn't save. Please try again.");
      return false;
    }
    if (body["status"] == "0") {
      CustomToast.failToast(msg: body["message"]);
      return false;
    }
    ApiResponse<LoginModel> model = ApiResponse.fromJson(response.body, (p0) {});
    if (model.status != "1") return false;

    // Keep the signup answers in memory too, so screens that
    // read them right after signup (like the free trial,
    // which skips its goal question) see them without a
    // fresh login.
    final auth = Get.find<AuthController>();
    if (mainGoal != null) {
      auth.mainGoal.value = mainGoal;
      auth.logInUser?.mainGoal = mainGoal;
    }
    if (healthConditions != null) {
      auth.healthConditions.value = healthConditions;
      auth.logInUser?.healthConditions = healthConditions;
    }
    if (age != null) auth.logInUser?.age = age;
    if (onboardingDone) {
      SignupProgress.markDone(sharedPreferences, sharedPreferences.getString(Constants.userId) ?? '');
    }
    if (navigate) {
      CustomToast.successToast(msg: body["message"]);
      auth.updateUserDetails(updateFields: false);
    }
    return true;
  }

  /// Sign-up questions: silent save of what she has answered so far
  /// (no spinner, no toast). Offline: skipped, the phone keeps the draft.
  Future<void> saveSignupDraft(Map<String, dynamic> fields, int step) async {
    try {
      if (!await connectionService.checkConnection()) return;
      final userId = sharedPreferences.getString(Constants.userId);
      if (userId == null || userId.isEmpty) return;
      await homeRepo.addUserDetails(
        accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        map: {"userId": userId, ...fields, "onboardingStep": step},
      ).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  getPaymentLink(String amount, int id) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        await homeRepo.getPaymentLink(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {"amount": amount, "planId": id},
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse<PaymentLink> model = ApiResponse.fromJson(response.body, PaymentLink.fromJson);
              if (model.status == "1") {
                Get.to(() => WebViewScreen(url: model.data!.session.url));
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  /// Direct Pay (Payin PWA): JazzCash / EasyPaisa. Backend returns payment URL.
  /// [msisdn] if provided is used (e.g. from phone confirmation dialog); otherwise uses profile phone.
  void getDirectPayPaymentLink(String amount, String planId, {String? msisdn}) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        return;
      }
      final user = Get.find<AuthController>().logInUser;
      if (user == null) {
        CustomToast.failToast(msg: "Please log in to continue.");
        return;
      }
      final payerName = user.fullName.trim();
      final email = user.email.trim();
      if (payerName.isEmpty || email.isEmpty) {
        CustomToast.failToast(msg: "Please complete your profile (name and email) before paying.");
        return;
      }
      final phoneToUse = msisdn ?? normalizeMsisdn(user.phone);
      if (phoneToUse == null || phoneToUse.length != 11) {
        CustomToast.failToast(msg: "Please provide a valid Pakistan mobile number (03xxxxxxxxx).");
        return;
      }
      final successRedirectUrl = "fither://payment/success?planId=$planId";
      final failedRedirectUrl = "fither://payment/failed";
      Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
      await homeRepo.getDirectPayPaymentUrl(
        accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        map: {
          "planId": planId,
          "amount": amount,
          "payerName": payerName,
          "email": email,
          "userId": sharedPreferences.getString(Constants.userId),
          "msisdn": phoneToUse,
          "successRedirectUrl": successRedirectUrl,
          "failedRedirectUrl": failedRedirectUrl,
        },
      ).then((response) async {
        Get.back();
        if (response.statusCode == 200 && response.body["status"] != "0") {
          ApiResponse<DirectPayUrlResponse> model = ApiResponse.fromJson(response.body, DirectPayUrlResponse.fromJson);
          if (model.status == "1" && model.data != null && model.data!.url.isNotEmpty) {
            Get.to(() => WebViewScreen(
                  url: model.data!.url,
                  successPlanId: planId,
                ));
          } else {
            CustomToast.failToast(msg: model.message ?? response.body["message"] ?? "Could not create payment link.");
          }
        } else {
          CustomToast.failToast(msg: response.body["message"] ?? "Could not create payment link.");
        }
      });
    });
  }

  /// Normalize Pakistan mobile to 03xxxxxxxxx (11 digits) for Direct Pay. Public for prefilling UI.
  static String? normalizeMsisdn(String? phone) {
    if (phone == null || phone.isEmpty) return null;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && digits.startsWith('3')) return '0$digits';
    if (digits.length == 12 && digits.startsWith('92')) return '0${digits.substring(2)}';
    if (digits.length == 11 && digits.startsWith('03')) return digits;
    if (digits.length == 11 && digits.startsWith('0')) return digits;
    return null;
  }

  /// Validate Pakistan mobile for Direct Pay: 03 + 9 digits (11 total).
  static bool isValidMsisdn(String? value) {
    if (value == null || value.isEmpty) return false;
    final normalized = normalizeMsisdn(value);
    return normalized != null && normalized.length == 11 && RegExp(r'^03\d{9}$').hasMatch(normalized);
  }

  addWorkoutAndTrainerApp() {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        await homeRepo.assignWorkoutAndTrainer(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {"planId": allPlanModel!.plans[selectedPlanIndex.value].id, "dietitianId": selectedDietId.value, "trainerId": selectedTrainerId.value},
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: model.message);
                Get.back();
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  getspecificUserFromFireStore(String id) async {
    Map<String, dynamic>? userMap;
    await FirebaseFirestore.instance.collection("users").doc(id).get().then((value) {
      userMap = value.data();
    });
    userMap ??= {"id": id, "name": "", "deviceToken": ""};
    return userMap;
  }

  makeRoomId(String id) async {
    String roomId = (sharedPreferences.getString(Constants.userId).hashCode + id.hashCode).toString();
    return roomId;
  }

  addAnnouncement(TextEditingController title, TextEditingController body) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        await homeRepo.addAnnouncement(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {"title": title.text, "body": body.text},
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: response.body["message"]);
                title.clear();
                body.clear();
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  freezeMyAccount(bool freeze) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        await homeRepo.freezeMyAccount(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {
            "userId": sharedPreferences.getString(Constants.userId),
            "freeze": freeze,
            "freezingDays": !freeze ? null : Get.find<AuthController>().dateExtendController.text.split(" ").first
          },
        ).then((response) async {
          Get.back();
          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: response.body["message"]);
                // userHomeData?.userData.usedFreezeOption.value =
                //     freeze ? false : true;
                //   userHomeData!.userData.freeze.value = freeze;
                getUserHomeFunc();
                update(['freezeButton']);
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  synchronization() {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        await homeRepo
            .synchronizationRepo(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          Get.back();
          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: "Reminder Send Successfully");
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  /// Saves the weekly measurements. True when the server saved them.
  /// Her first-day date + weight are remembered so she types them once.
  Future<bool> updateMyWeeklyReport() async {
    if (!await connectionService.checkConnection()) {
      CustomToast.noInternetToast();
      return false;
    }
    Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
    Response? response;
    try {
      response = await homeRepo.updateWeeklyReportRepo(
        accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        map: {
          "weight": firstWeight.text,
          "currentWeight": currentWeight.text,
          "arms": arms.text,
          "chest": chest.text,
          "abdoman": abdonmen.text,
          "shoulder": shoulder.text,
          "thighs": thighs.text,
          "userId": sharedPreferences.getString(Constants.userId) ?? "",
          "hips": hips.text,
          "istDayDate": firstDay.text.replaceAll("/", "-"),
          "currentDate": currentDate.text.replaceAll("/", "-"),
          "weist": waist.text,
          "review": labels[selectedSatisfaction.value],
          "aboutService": tellUsMore.text
        },
      );
    } catch (_) {
      response = null;
    }
    if (Get.isDialogOpen ?? false) Get.back();
    final body = response?.body;
    if (response == null || response.statusCode != 200 || body is! Map) {
      CustomToast.failToast(msg: (body is Map ? body["message"] : null) ?? "Couldn't save. Please try again.");
      return false;
    }
    if (body["status"] != "1") {
      CustomToast.failToast(msg: body["message"]);
      return false;
    }
    CustomToast.successToast(msg: "Weekly check-in saved");
    sharedPreferences.setString('weekly_first_day', firstDay.text);
    sharedPreferences.setString('weekly_first_weight', firstWeight.text);
    sharedPreferences.setInt('weekly_report_at', DateTime.now().millisecondsSinceEpoch);
    clearMeasurementController();
    firstDay.text = sharedPreferences.getString('weekly_first_day') ?? '';
    firstWeight.text = sharedPreferences.getString('weekly_first_weight') ?? '';
    return true;
  }

  updateLinkFunc(TextEditingController textEditingController, int slotId, bool isDiet, int userId, String planId) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        await homeRepo
            .updateLinkRepo(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {
            isDiet ? "id" : "slotId": slotId,
            "link": textEditingController.text,
            "userId": userId,
            "planId": planId,
          },
          isDiet: isDiet,
        )
            .then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: response.body["message"]);
                Get.find<WorkOutController>().getTrainerHomeFunc();
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  updateSlotStatus(String slotId, String status) async {
    await connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        await homeRepo.updateSlotStatus(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {
            "slotId": slotId,
            "status": status,
          },
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: response.body["message"]);
                WorkOutController workOutController = Get.find();

                var trainerSlots = workOutController.getTrainerHome?.trainerSlots;
                if (trainerSlots != null && trainerSlots.isNotEmpty) {
                  for (var slot in trainerSlots) {
                    for (var s in slot.slots) {
                      if (s.id.toString() == slotId) {
                        s.status = status;
                      }
                    }
                  }
                }

                // Get.find<WorkOutController>().getTrainerHomeFunc();
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  updateTrainerJoin(int uid, int slotId, String channel, {bool isTrainerJoined = true}) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        await homeRepo.updateTrainerJoin(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {
            "slotId": slotId,
            "isTrainerJoined": isTrainerJoined,
            "joinedUserUID": uid,
          },
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: response.body["message"]);
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  addTeamMemberFunc(int? planId) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        // var plan = allPlanModel!.plans[selectedPlanIndex.value];
        // var expiryDate = DateTime.now()
        //     .add(Duration(days: int.parse(plan.duration.split(" ").first)));
        // var price = plan.price;

        await homeRepo.addTeamMemberRepo(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {
            "firstName": firstNameController.text,
            "lastName": lastNameController.text,
            "email": emailController.text,
            "password": passwordController.text,
            "phone": phoneController.text,
            "userType": addedTeamMember.value,
            "planId": null
          },
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: response.body["message"]);
                clearyControllers();
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  updateUser(int userId, bool freeze, String days, String planId) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        await homeRepo.updateUserRepo(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {
            "firstName": firstNameController.text,
            "lastName": lastNameController.text,
            "email": emailController.text,
            "password": passwordController.text,
            "phone": phoneController.text,
            "userId": userId,
            "freeze": freeze,
            "days": days,
            "UserPlanId": planId
          },
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: response.body["message"]);
                getAllUsersFunc();
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  updateUserPlanStatus(String planId) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        await homeRepo.updateUserPayment(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {"userId": sharedPreferences.getString(Constants.userId) ?? "", "planId": planId},
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: response.body["message"]);
                if (Get.isRegistered<AuthController>()) {
                  Get.find<AuthController>().markPaid();
                }
                getUserHomeFunc();
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  /// [reason]: why the slip was rejected (sent to her). Oct 2026.
  approveUser(String imageId, bool reject, {String? reason}) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        await homeRepo.approveUser(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {
            "planImageId": imageId,
            "rejected": reject,
            if (reject && reason != null) "reason": reason,
          },
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                getAllPlansImages?.data.removeWhere((image) => image.id.toString() == imageId);
                update(["newList"]);
                CustomToast.successToast(msg: response.body["message"]);
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  addTestimonials() {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        await homeRepo.addTestimonials(
            accessToken: sharedPreferences.getString(Constants.accessToken) ?? "", map: {"image": testiPicture!.path}).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            ApiResponse model = ApiResponse.fromJson(jsonDecode(response.bodyString!), (p0) {});
            if (model.status == "0") {
              CustomToast.failToast(msg: model.message);
            }
            if (model.status == "1") {
              CustomToast.successToast(msg: model.message);
              Get.back();
            }
          } else {
            CustomToast.failToast(msg: "Something wrong happened");
          }
        });
      }
    });
  }

  updateUserProfile(String speciality, String totalPatients, String experience, String description) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        await homeRepo.updateUserProfile(accessToken: sharedPreferences.getString(Constants.accessToken) ?? "", map: {
          "image": profilePicture!.path,
          "userId": sharedPreferences.getString(Constants.userId),
          "speciality": speciality,
          "totalPatients": totalPatients,
          "experience": experience,
          "description": description
        }).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            ApiResponse model = ApiResponse.fromJson(jsonDecode(response.bodyString!), (p0) {});
            if (model.status == "0") {
              CustomToast.failToast(msg: model.message);
            }
            if (model.status == "1") {
              CustomToast.successToast(msg: model.message);
              Get.back();
            }
          } else {
            CustomToast.failToast(msg: "Something wrong happened");
          }
        });
      }
    });
  }

  updateUserDietOfWeek(String userID, String userPlanId) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        await homeRepo
            .updateUserDietOfWeek(
                accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
                map: AddDietOfUser(userId: userID, userPlanId: userPlanId, dietOfUser: dietOfUserByDiet).toJson())
            .then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: response.body["message"]);
                Get.back();
              }
            }
          } else {
            CustomToast.failToast(msg: "Something wrong happened");
          }
        });
      }
    });
  }

  /// True when the last uploaded slip was approved by the AI and her plan
  /// is already on (upload screen then says so). Oct 2026.
  final RxBool lastSlipAutoApproved = false.obs;

  Future<bool> addPlanBuyImage(String planId, int durationId, String price) async {
    bool success = false;
    lastSlipAutoApproved.value = false;
    await connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        // Clear "please wait" while the slip uploads and is checked (it can
        // take a few seconds); back button blocked so she can't leave
        // half-way and upload twice.
        Get.dialog(
          PopScope(
            canPop: false,
            child: Center(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 26, vertical: 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FhLoader(),
                      SizedBox(height: 16),
                      Text(
                        'Uploading your payment slip…',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A3A22),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Please wait and don't close the app.",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF7A8C78),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          barrierDismissible: false,
        );

        Plan? plan = allPlanModel?.plans.firstWhereOrNull((p) => p.id == selectedPlanId.value);

        await homeRepo.addPlanImageRepo(accessToken: sharedPreferences.getString(Constants.accessToken) ?? "", map: {
          "image": planPicture!.path,
          "planId": planId,
          // "durationId": durationId.toString(),
          "price": price,
          "durationId": durationId.toString(),
          "userId": sharedPreferences.getString(Constants.userId),
        }).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            // Surface the backend's OCR + auto-approval payload in the
            // debug console so we can see at a glance whether Cloud Vision
            // ran on this upload, what it extracted, and whether the slip
            // got auto-approved or sent to the admin queue.
            // Shape: data.{ autoApproved, verificationStatus,
            //   userPlanActivated, planImageId,
            //   ocrSummary: { confidence, amount, bank, date, refNumber } | null }
            try {
              final decoded = jsonDecode(response.bodyString!);
              final data = decoded is Map ? decoded['data'] : null;
              if (data is Map) {
                final ocr = data['ocrSummary'];
                debugPrint('🧾 SLIP UPLOAD · verificationStatus='
                    '${data['verificationStatus']} · '
                    'autoApproved=${data['autoApproved']} · '
                    'userPlanActivated=${data['userPlanActivated']} · '
                    'planImageId=${data['planImageId']}');
                if (ocr == null) {
                  debugPrint('🧾 OCR · skipped (no Vision response — check '
                      'GOOGLE_VISION_API_KEY on backend or network)');
                } else if (ocr is Map) {
                  debugPrint('🧾 OCR · confidence=${ocr['confidence']} · '
                      'amount=${ocr['amount']} · bank=${ocr['bank']} · '
                      'receiver=${ocr['receiver']} (verified=${ocr['receiverVerified']}) · '
                      'date=${ocr['date']} · refNumber=${ocr['refNumber']}');
                }
              }
            } catch (e) {
              debugPrint('🧾 SLIP UPLOAD · failed to parse OCR summary: $e');
            }

            ApiResponse model = ApiResponse.fromJson(jsonDecode(response.bodyString!), (p0) {});
            if (model.status == "0") {
              CustomToast.failToast(msg: model.message);
            }
            if (model.status == "1") {
              // CustomToast.successToast(msg: model.message);
              planPicture = null;
              success = true;

              // Auto-promote the user to paid + V2 home if Cloud Vision /
              // admin queue auto-approved the slip and the backend already
              // activated the plan. `markPaid()` flips `logInUser.status`,
              // `useNewPaidHome`, and the reactive `isPaid` Rx → the home
              // Obx rebuilds straight into `PaidHomeScreenV2`.
              try {
                final decoded = jsonDecode(response.bodyString!);
                final data = decoded is Map ? decoded['data'] : null;
                if (data is Map &&
                    data['userPlanActivated'] == true &&
                    data['autoApproved'] == true) {
                  // Capture paid status BEFORE markPaid() flips it — that's
                  // what tells us this is a repeat purchase (renewal) and
                  // not the user's first-ever activation. There's no
                  // separate "renewal" concept on the backend, so this is
                  // the only place we can make that distinction.
                  final wasAlreadyPaid =
                      Get.find<AuthController>().logInUser?.status ?? false;
                  lastSlipAutoApproved.value = true;
                  Get.find<AuthController>().markPaid();
                  // Fresh home + trial state now (no logout / login needed).
                  getUserHomeFunc(isFromFree: true, silent: true, forceRefresh: true);
                  debugPrint('🧾 SLIP UPLOAD · auto-promoted to paid · '
                      'home will swap to PaidHomeScreenV2');
                  if (wasAlreadyPaid) {
                    AnalyticsHelper.trackSubscriptionRenewed(
                      planId,
                      planName: plan?.title,
                      planPrice: price,
                    );
                  }
                }
              } catch (e) {
                debugPrint('🧾 SLIP UPLOAD · auto-promote skipped: $e');
              }
            }
          } else {
            CustomToast.failToast(msg: "Something wrong happened");
          }
        });
      }
    });
    return success;
  }

  Future<bool> validateTrialToken(String token,
      {bool showToastOnSuccess = false, bool quiet = false}) async {
    bool isValid = false;
    trialActionLoad.value = true;

    await connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        await homeRepo.validateTrialToken(token: token).then((response) async {
          if (response.statusCode == 200 && response.body["status"] == "1") {
            sharedPreferences.setString(Constants.trialToken, token);
            trialJourney = response.body["data"]?["journey"];
            // Trial length from the server even before she starts one,
            // so "Start your N-day free trial" is right from day zero.
            final days = int.tryParse('${response.body["data"]?["trialDays"] ?? ''}');
            if (days != null && days > 0) {
              trialDays.value = days;
              sharedPreferences.setInt(_kTrialDaysKey, days);
            }
        _syncTrialRx();
            isValid = true;
            if (showToastOnSuccess) {
              CustomToast.successToast(msg: response.body["message"]);
            }
          } else {
            if (!quiet) {
              CustomToast.failToast(msg: response.body["message"] ?? "Invalid trial token");
            }
          }
        });
      }
    });

    trialActionLoad.value = false;
    update();
    return isValid;
  }

  /// True when she's logged in and has a saved invite token from a rep's
  /// link (tapped, or read from the install referrer). Callers use it to
  /// send her into trial onboarding.
  ///
  /// It no longer starts the trial here: the trial and its day clock
  /// start only when she finishes onboarding (startTrial() below, which
  /// uses and consumes this saved token). Name kept so existing callers
  /// in auth_controller / app_link_handler don't change.
  Future<bool> startTrialFromSavedToken() async {
    final accessToken = sharedPreferences.getString(Constants.accessToken) ?? "";
    final token = sharedPreferences.getString(Constants.trialToken) ?? "";
    return accessToken.isNotEmpty && token.isNotEmpty;
  }

  Future<bool> startTrial() async {
    bool started = false;
    trialActionLoad.value = true;
    final accessToken = sharedPreferences.getString(Constants.accessToken) ?? "";
    // If she came from a rep's invite, attach it now, at the moment the
    // trial actually starts (end of onboarding), so the rep gets credit.
    final inviteToken = sharedPreferences.getString(Constants.trialToken) ?? "";

    Future<Response> call(String? token) =>
        homeRepo.startTrial(accessToken: accessToken, token: token);

    var response = await call(inviteToken.isEmpty ? null : inviteToken);
    var ok = response.statusCode == 200 && response.body["status"] == "1";
    // The invite may have expired or been used since she tapped it. Don't
    // block her trial over that: start it without the invite instead.
    if (!ok && inviteToken.isNotEmpty) {
      sharedPreferences.remove(Constants.trialToken);
      response = await call(null);
      ok = response.statusCode == 200 && response.body["status"] == "1";
    }
    if (ok) {
      trialJourney = response.body["data"]?["journey"];
      _syncTrialRx();
      sharedPreferences.remove(Constants.trialToken);
      started = true;
    } else {
      CustomToast.failToast(msg: response.body["message"] ?? "Unable to start trial");
    }
    trialActionLoad.value = false;
    update();
    return started;
  }

  // Trial-to-Plan funnel Steps 3+4+5 in one call. Returns true once the
  // starter plan is generated AND auto-activated server-side — the
  // caller can go straight to the meal-log screen on true. On false,
  // this has already shown the user-facing error via CustomToast
  // (mirrors startTrial()'s pattern above) so the caller just stays put.
  Future<bool> submitTrialQuickIntake({
    String? goal,
    String? allergies,
    int? mealsPerDay,
  }) async {
    bool success = false;
    trialQuickIntakeLoad.value = true;
    await homeRepo
        .submitTrialQuickIntake(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      goal: goal,
      allergies: allergies,
      mealsPerDay: mealsPerDay,
    )
        .then((response) {
      if (response.statusCode == 200 && response.body["status"] == "1") {
        success = true;
        // Not ready within 6 s: made in the background, push when ready.
        final data = response.body["data"];
        setTrialPlanPending(data is Map && data["pending"] == true);
      } else if (response.statusCode == 200 &&
          (response.body["message"] ?? "")
              .toString()
              .toLowerCase()
              .contains("already got a plan")) {
        setTrialPlanPending(false);
        // Not a real failure -- the desired end state (a plan exists) is
        // already met, most often because a second trial-start trigger
        // fired after the first one already ran this. Let the caller
        // proceed to the meal plan instead of dead-ending on an error.
        success = true;
      } else {
        CustomToast.failToast(
          msg: response.body["message"] ??
              "Couldn't generate your plan yet — please try again",
        );
      }
    });
    trialQuickIntakeLoad.value = false;
    update();
    return success;
  }

  Future<void> getMyTrialJourney() async {
    trialLoad.value = false;
    // Never leave Home waiting if this call fails or hangs (Nov 2026).
    Future.delayed(const Duration(seconds: 8), () => trialChecked.value = true);

    await connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Unblock TrialJourneyScreen — without this, CircularProgress spins
        // forever because trialLoad is never set to true on the no-internet
        // path. trialJourney stays null; the screen's _loadJourney() will
        // attempt startTrial() which will also fail and show its own toast.
        trialLoad.value = true;
        trialChecked.value = true;
      } else {
        await homeRepo
            .getMyTrial(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          if (response.statusCode == 200 && response.body["status"] == "1") {
            trialJourney = response.body["data"]?["journey"];
            // Trial length from the server even before she starts one,
            // so "Start your N-day free trial" is right from day zero.
            final days = int.tryParse('${response.body["data"]?["trialDays"] ?? ''}');
            if (days != null && days > 0) {
              trialDays.value = days;
              sharedPreferences.setInt(_kTrialDaysKey, days);
            }
        _syncTrialRx();

            // Sync the local trialActivated flag with server truth so the
            // TrialCtaCard always shows the correct state:
            //   journey == null  → no trial exists  → show _IdleCard
            //                                         ("Start 3-day free trial")
            //   journey != null  → trial exists      → show _ActivatedCard
            //                                         (even if expired/completed)
            final auth = Get.find<AuthController>();
            if (trialJourney == null) {
              auth.trialActivated.value = false;
              auth.sharedPreferences.setBool(Constants.trialActivatedKey, false);
            } else if (!auth.trialActivated.value) {
              auth.trialActivated.value = true;
              auth.sharedPreferences.setBool(Constants.trialActivatedKey, true);
            }
          } else {
            CustomToast.failToast(msg: response.body["message"] ?? "Unable to load trial");
          }
          // Always unblock the screen regardless of success/failure so it
          // never hangs on a CircularProgress with no recovery path.
          trialLoad.value = true;
          trialChecked.value = true;
        });
      }
    });
    update();
  }

  Future<void> bookTrialDay({required int day, required int slotId}) async {
    trialActionLoad.value = true;
    await homeRepo
        .bookTrialDay(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      day: day,
      slotId: slotId,
    )
        .then((response) async {
      if (response.statusCode == 200 && response.body["status"] == "1") {
        trialJourney = response.body["data"]?["journey"];
        _syncTrialRx();
        CustomToast.successToast(msg: response.body["message"]);
      } else if (response.body["data"] is Map &&
          response.body["data"]["needsForm"] == true) {
        // Trial classes are locked until her trial form is done. Take her
        // straight to it instead of a dead-end error.
        CustomToast.failToast(msg: response.body["message"]);
        Get.to(() => const TrialOnboardingScreen());
      } else {
        CustomToast.failToast(msg: response.body["message"] ?? "Unable to book day");
      }
    });
    trialActionLoad.value = false;
    update();
  }

  Future<void> markTrialAttendance({required int day, int attendedMinutes = 30}) async {
    trialActionLoad.value = true;
    await homeRepo
        .markTrialAttendance(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      day: day,
      attendedMinutes: attendedMinutes,
    )
        .then((response) async {
      if (response.statusCode == 200 && response.body["status"] == "1") {
        trialJourney = response.body["data"]?["journey"];
        _syncTrialRx();
        CustomToast.successToast(msg: response.body["message"]);
      } else {
        CustomToast.failToast(msg: response.body["message"] ?? "Unable to mark attendance");
      }
    });
    trialActionLoad.value = false;
    update();
  }

  Future<bool> submitTrialFeedback({
    required double rating,
    required String comment,
    required String classReview,
  }) async {
    bool success = false;
    trialActionLoad.value = true;
    await homeRepo
        .addReview(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      map: {
        "comment": comment,
        "value": rating.toInt(),
        "classReview": classReview,
        // Trial feedback has no specific trainer — 0 avoids sending the
        // user's own ID as the reviewed entity, which was the previous bug.
        "trainerOrDiet": 0,
        "PlanId": 0,
        "userId": sharedPreferences.getString(Constants.userId) ?? "",
      },
    )
        .then((response) async {
      if (response.statusCode == 200 && response.body["status"] == "1") {
        success = true;
        CustomToast.successToast(msg: response.body["message"]);
      } else {
        CustomToast.failToast(msg: response.body["message"] ?? "Unable to submit feedback");
      }
    });
    trialActionLoad.value = false;
    update();
    return success;
  }

  Future<bool> markTrialConverted() async {
    bool converted = false;
    trialActionLoad.value = true;
    await homeRepo
        .markTrialConverted(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
    )
        .then((response) async {
      if (response.statusCode == 200 && response.body["status"] == "1") {
        trialJourney = response.body["data"]?["journey"];
        _syncTrialRx();
        converted = true;
        await AnalyticsHelper.trackFreeTrialEvent(
          'trial_converted_backend_confirmed',
          step: 'conversion',
          additionalParams: {
            'state': trialJourney?["state"]?.toString() ?? "",
          },
        );
      } else {
        CustomToast.failToast(msg: response.body["message"] ?? "Unable to complete conversion");
      }
    });
    trialActionLoad.value = false;
    update();
    return converted;
  }

  var showDotHome = false.obs;
}
