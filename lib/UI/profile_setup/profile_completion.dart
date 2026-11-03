import 'package:get/get.dart';

import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../data/models/consultation/pre_consultation_profile.dart';
import '../free_trail/trial_onboarding_screen.dart';
import '../auth_module/log_period_screen.dart';
import '../auth_module/sign_up_screen/sign_up_screen_questions.dart';
import 'plan_personal_screens.dart';
import '../pre_consultation/pre_consultation_form_screen.dart';

/// Sign-up pages she still has gaps in (0 goal, 1 body, 2 life stage,
/// 3 period), from the server's requirements. Used by "About you" and by
/// the health form, so both start with the screens she knows from sign-up.
List<int> signupGapPages(Map<String, dynamic>? req) {
  final required = ((req?['required'] as List?) ?? const []).map((e) => '$e').toSet();
  List<String> about;
  final am = req?['aboutMissing'];
  if (am is List) {
    about = am.map((e) => '$e').toList();
  } else {
    // Older server: work it out from her saved profile on this phone.
    final auth = Get.find<AuthController>();
    bool okNum(String? t, double lo, double hi) {
      final v = double.tryParse((t ?? '').trim());
      return v != null && v >= lo && v <= hi;
    }
    final u = auth.logInUser;
    final goal = (u?.mainGoal ?? '').trim().isNotEmpty ? u!.mainGoal! : auth.mainGoal.value;
    about = [
      if (goal.trim().isEmpty) 'goal',
      if (!okNum(u?.age ?? auth.editAge.text, 18, 70)) 'age',
      if (!okNum(u?.weight ?? auth.editWeight.text, 30, 150)) 'weight',
      if (!okNum(u?.height ?? auth.editHeight.text, 3, 7)) 'height',
    ];
  }
  return [
    if (required.contains('goal') || about.contains('goal')) 0,
    if (about.any((k) => k != 'goal') || req?['targetMissing'] == true) 1,
    if (required.contains('lifeStage')) 2,
    if (required.contains('cycle')) 3,
  ];
}

/// What an old paid client has not filled yet, and what is locked
/// because of it (Oct 2026, "old client" handling).
///
/// One truth: the server's GET /users/pre-consultation/requirements
/// (helper/preConsultRequirements.js) decides which answers are missing.
/// This class only turns that into simple yes/no flags for the screens:
///   - periodLocked: cycle card + Luna tip wait for her period date
///   - dietLocked:   Diet tab + Meals tile wait for health + food answers
///   - showCard:     the "Finish your profile" checklist on home
///   - showAllClassesNote: she never picked her 2 class times, so she
///     is reminded of all classes (server rule, helper/classAudience.js)
///
/// Nothing is ever blocked: classes always work. Only paid clients
/// (not free trial) are affected. On any error nothing is locked.
class ProfileCompletion extends GetxController {
  static ProfileCompletion get to => Get.isRegistered<ProfileCompletion>()
      ? Get.find<ProfileCompletion>()
      : Get.put(ProfileCompletion(), permanent: true);

  static const _hasPeriods = ['regular_cycle', 'irregular_cycle', 'trying_to_conceive'];

  final RxBool loaded = false.obs;
  final RxBool eligible = false.obs; // paid client with a live plan
  final RxString planType = 'diet'.obs; // diet | workout | combined
  final RxList<String> missing = <String>[].obs;
  final RxBool needsConsent = false.obs;
  final RxBool needsConfirm = false.obs;
  final RxBool picksDone = false.obs; // picked class times / chose "all"
  final RxBool pickedOwnTimes = false.obs;
  final RxnString lifeStage = RxnString();
  final RxBool cardHidden = false.obs; // "Not now" on the card, for 1 day
  // "Profile complete 🎉": once, the first time everything is done after
  // she has seen the checklist.
  final RxBool showComplete = false.obs;
  // "About you": sign-up answers still empty (goal, age, weight, height)
  // and whether her target weight is missing (Lose / Gain weight only).
  final RxList<String> aboutMissing = <String>[].obs;
  final RxBool targetMissing = false.obs;

  DateTime? _lastLoad;
  bool _loading = false;

  bool get hasDiet => planType.value == 'diet' || planType.value == 'combined';
  bool get hasWorkout => planType.value == 'workout' || planType.value == 'combined';

  bool get goalNeeded => missing.contains('goal');
  bool get periodNeeded => missing.contains('lifeStage') || missing.contains('cycle');
  bool get healthNeeded =>
      missing.contains('conditions') ||
      missing.contains('workout') ||
      needsConsent.value ||
      needsConfirm.value;
  bool get foodNeeded => hasDiet && (missing.contains('health') || missing.contains('food'));

  bool get periodLocked => eligible.value && periodNeeded;
  bool get dietLocked => eligible.value && hasDiet && (healthNeeded || foodNeeded);
  /// "About you" row: every sign-up answer (goal, body, life stage, period).
  bool get aboutNeeded => goalNeeded || periodNeeded || aboutMissing.isNotEmpty;
  bool get anythingMissing => eligible.value && (aboutNeeded || healthNeeded || foodNeeded);
  // Oct 2026: no "Not now" any more, so the card always shows while
  // something is missing (an old "hide for today" no longer applies).
  bool get showCard => anythingMissing;
  bool get showAllClassesNote => eligible.value && hasWorkout && !picksDone.value;

  /// Her period item belongs on the checklist only when she has periods
  /// (or we don't know her life stage yet).
  bool get periodItemApplies =>
      periodNeeded || _hasPeriods.contains(lifeStage.value ?? '');

  String get _uid => (Get.find<AuthController>().logInUser?.id ?? '').toString();
  String get _hideKey => 'profile_card_hidden_until_$_uid';
  String get _seenKey => 'profile_card_seen_$_uid';
  String get _completeKey => 'profile_complete_shown_$_uid';

  /// Re-reads her answers. Cheap to call often: skips if it ran in the
  /// last 30 seconds unless [force].
  Future<void> reload({bool force = false}) async {
    if (_loading) return;
    if (!force && _lastLoad != null &&
        DateTime.now().difference(_lastLoad!) < const Duration(seconds: 30)) {
      return;
    }
    _loading = true;
    try {
      final auth = Get.find<AuthController>();
      final user = auth.logInUser;
      if (!Get.isRegistered<HomeController>()) return;
      final home = Get.find<HomeController>();
      if (user == null || user.status != true || home.isFreeTrialUser.value) {
        eligible.value = false;
        loaded.value = true;
        return;
      }
      final plans = home.userHomeData?.userAllPlans;
      if (plans == null) return; // not loaded yet, try again later
      final real = plans.where((p) {
        final t = p.title.trim().toLowerCase();
        return t != 'free trial' && !t.startsWith('system') && p.remainingDays > 0;
      }).toList();
      if (real.isEmpty) {
        eligible.value = false;
        loaded.value = true;
        return;
      }
      // CategoryId: 1 diet, 2 workout, 3 combined.
      final d = real.any((p) => p.categoryId == 1 || p.categoryId == 3);
      final w = real.any((p) => p.categoryId == 2 || p.categoryId == 3);
      var pt = d && w ? 'combined' : (w ? 'workout' : 'diet');

      final c = Get.find<ConsultationController>();
      final res = await Future.wait<dynamic>([
        c.getPreConsultRequirements(pt),
        c.loadProfile(),
      ]);
      final req = res[0] as Map<String, dynamic>?;
      final PreConsultationProfile? p = res[1] as PreConsultationProfile?;
      if (req == null) return; // offline: keep what we had, lock nothing new

      final serverPt = req['planType'];
      if (serverPt is String && ['diet', 'workout', 'combined'].contains(serverPt)) {
        pt = serverPt;
      }
      planType.value = pt;
      missing.assignAll(((req['required'] as List?) ?? const [])
          .map((e) => e.toString()));
      needsConsent.value = req['needsConsent'] == true;
      final am = req['aboutMissing'];
      if (am is List) {
        aboutMissing.assignAll(am.map((e) => e.toString()));
      } else {
        // Older server: work it out from her saved profile on this phone.
        bool okNum(String? t, double lo, double hi) {
          final v = double.tryParse((t ?? '').trim());
          return v != null && v >= lo && v <= hi;
        }
        final u = auth.logInUser;
        final goal = (u?.mainGoal ?? '').trim().isNotEmpty ? u!.mainGoal! : auth.mainGoal.value;
        aboutMissing.assignAll([
          if (goal.trim().isEmpty) 'goal',
          if (!okNum(u?.age ?? auth.editAge.text, 18, 70)) 'age',
          if (!okNum(u?.weight ?? auth.editWeight.text, 30, 150)) 'weight',
          if (!okNum(u?.height ?? auth.editHeight.text, 3, 7)) 'height',
        ]);
      }
      targetMissing.value = req['targetMissing'] == true;
      needsConfirm.value = req['needsConfirm'] == true;
      lifeStage.value = p?.pregnancyMenstrualStatus;

      final ws = p?.workoutSection;
      bool nonEmpty(Object? v) => v is List && v.isNotEmpty;
      pickedOwnTimes.value =
          nonEmpty(ws?['preferredSlotIds']) || nonEmpty(ws?['preferredTimes']);
      picksDone.value = pickedOwnTimes.value || ws?['reminderMode'] == 'all';

      final until = auth.sharedPreferences.getInt(_hideKey) ?? 0;
      cardHidden.value = DateTime.now().millisecondsSinceEpoch < until;

      eligible.value = true;
      final prefs = auth.sharedPreferences;
      if (anythingMissing) {
        await prefs.setBool(_seenKey, true);
      } else if ((prefs.getBool(_seenKey) ?? false) &&
          !(prefs.getBool(_completeKey) ?? false)) {
        await prefs.setBool(_completeKey, true);
        showComplete.value = true;
      }
      loaded.value = true;
      _lastLoad = DateTime.now();
    } catch (_) {
      // Best effort: never lock anything because of an error.
    } finally {
      _loading = false;
    }
  }

  /// Closes the "Profile complete" card.
  void dismissComplete() => showComplete.value = false;

  /// "Not now" on the home card: hide it for a day. Locks stay.
  Future<void> hideCardForToday() async {
    cardHidden.value = true;
    try {
      await Get.find<AuthController>().sharedPreferences.setInt(
            _hideKey,
            DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
          );
    } catch (_) {}
  }

  /// Opens the health form (only the missing questions), then refreshes
  /// home and diet so the locks open right away.
  Future<void> openForm() async {
    await PreConsultationFormScreen.open(planType: planType.value, canLater: true);
    await _afterChange();
  }

  /// Period date: the sign-up style "Log your period" page.
  Future<void> openPeriod() async {
    await Get.to<bool>(() => const LogPeriodScreen());
    await _afterChange();
  }

  /// "About you": the sign-up pages she still has gaps in, nothing else.
  Future<void> openAbout() async {
    final pages = <int>[
      if (goalNeeded || aboutMissing.contains('goal')) 0,
      if (aboutMissing.any((k) => k != 'goal') || targetMissing.value) 1,
      if (missing.contains('lifeStage')) 2,
      if (missing.contains('cycle')) 3,
    ];
    if (pages.isEmpty) pages.add(1); // all done: let her edit her numbers
    // First time: explain why, once per user.
    if (aboutNeeded && !PlanPersonalIntro.seen()) {
      final go = await PlanPersonalIntro.show(planType: planType.value, parts: 1);
      if (!go) return;
    }
    await Get.to<bool>(
      () => SignUpScreenQuestions(gapPages: pages, askTarget: targetMissing.value),
    );
    await _afterChange();
  }

  /// Card "Continue": the whole journey (About you, then health), only
  /// the parts still missing.
  Future<void> openNext() => openForm();

  /// Opens "Tell us when you're free" to pick her class reminder times.
  Future<void> openClassTimes() async {
    await Get.to<bool>(
      () => const TrialOnboardingScreen(
        setupMode: true,
        includeClasses: true,
        timesOnly: true,
        canSkip: true,
      ),
      fullscreenDialog: true,
    );
    await _afterChange();
  }

  Future<void> _afterChange() async {
    await reload(force: true);
    try {
      Get.find<PaidHomeController>().refreshDashboard();
    } catch (_) {}
    try {
      Get.find<DietPlanUserController>().loadActivePlan(refresh: true);
    } catch (_) {}
  }
}
