import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../../data/Repos/cycle_repo/cycle_data_repository.dart';
import '../../values/constants.dart';
import '../../widgets/toasts.dart';
import '../dashboard_module/bottom_bar_screen/bottom_bar_screen.dart';
import 'trial_meal_plan_screen.dart';

// ── Resume where she left off (Oct 2026) ────────────────────────────────
String _stepKey() {
  try {
    return 'trial_onb_step_${Get.find<AuthController>().logInUser?.id ?? ''}';
  } catch (_) {
    return 'trial_onb_step_';
  }
}

void saveTrialOnboardingStep(int step) {
  try {
    Get.find<AuthController>().sharedPreferences.setInt(_stepKey(), step);
  } catch (_) {}
}

/// The trial form screen she was on when she left (0 = not started).
int savedTrialOnboardingStep() {
  try {
    return Get.find<AuthController>().sharedPreferences.getInt(_stepKey()) ?? 0;
  } catch (_) {
    return 0;
  }
}

void clearTrialOnboardingStep() {
  try {
    Get.find<AuthController>().sharedPreferences.remove(_stepKey());
  } catch (_) {}
}

/// Free trial onboarding. The trial only starts once this is finished
/// and the answers are confirmed:
///
///   0. Welcome     what the trial gives her (AI meal plan + live classes)
///   1. Goal
///   2. Body & cycle
///   3. Food        (diet preferences, meals per day, fasting)
///   4. Movement    (fitness level, equipment, injuries) for the classes
///   5. Workouts    what she loves to do (high intensity, strength,
///                  zumba, yoga, low intensity, mix). Starred picks suit
///                  her goal and health. Feeds class recommendations.
///   6. Class times real classes from the backend, in her time zone. She
///                  picks at least one; picks only drive reminders (no
///                  booking, she can join any class)
///   7. Review      she ticks "these answers are correct"
///
/// Every step saves to the SAME pre-consultation profile paid clients
/// use, so if she buys a package later she only confirms it once.
/// On finish: start trial (idempotent) -> generate + activate the AI
/// starter plan -> mark trial active on the device -> meal plan screen.
class TrialOnboardingScreen extends StatefulWidget {
  const TrialOnboardingScreen({
    super.key,
    this.setupMode = false,
    this.includeClasses = true,
    this.timesOnly = false,
    this.canSkip = false,
    this.partLabel,
  });

  /// Health-form journey: "Part 2 of 2 · Your health" above the steps.
  final String? partLabel;

  /// Profile setup for existing clients (not a trial): same screens, but
  /// finishing just saves and closes (no trial start, no AI plan).
  /// Opened by ProfileSetupGate. Returns `true` when she completed it.
  final bool setupMode;

  /// Show the class-times step (workout/combined clients). Diet-only
  /// clients skip it.
  final bool includeClasses;

  /// She already filled the form; only ask for her class times.
  final bool timesOnly;

  /// Show a "Later" button (she has skips left).
  final bool canSkip;

  @override
  State<TrialOnboardingScreen> createState() => _TrialOnboardingScreenState();
}

// ── Design tokens (V2 trial flow) ─────────────────────────────────────
const _kBg = Color(0xFFE8F4E0);
const _kInk = Color(0xFF163220);
const _kInkSoft = Color(0xFF6F8B7A);
const _kAccent = Color(0xFF6DC55A);
const _kAccentBg = Color(0xFFEAF7E4);
const _kBorder = Color(0xFFD8EDD4);
const _kHero2 = Color(0xFF24502F);

/// Quick picks for the health step (shared with the paid form).
const kAllergyOptions = <String>[
  'Peanuts', 'Tree nuts', 'Dairy / lactose', 'Gluten / wheat',
  'Eggs', 'Fish', 'Shellfish', 'Soy',
];
const kConditionOptions = <String>[
  'PCOS', 'Thyroid', 'Diabetes', 'Insulin resistance', 'High BP',
  'High cholesterol', 'Anemia', 'Endometriosis',
];

class _Opt {
  final String value;
  final String emoji;
  final String label;
  final String? sub;
  const _Opt(this.value, this.emoji, this.label, [this.sub]);
}

// Same value strings the paid pre-consultation form and the AI prompt use.
const _goals = <_Opt>[
  _Opt('weight_loss', '🔥', 'Lose weight', 'Burn fat, feel lighter'),
  _Opt('weight_gain', '💪', 'Gain weight', 'Healthy, steady gain'),
  _Opt('maintain', '⚖️', 'Maintain', 'Stay where you feel good'),
  _Opt('pcos_management', '🌸', 'Manage PCOS', 'Balance hormones with food'),
  _Opt('postpartum', '🤱', 'Postpartum', 'Gentle rebuild after baby'),
  _Opt('pregnancy_prep', '🌱', 'Pregnancy prep', 'Nourish before you conceive'),
  _Opt('general_wellness', '✨', 'Feel better', 'More energy, better habits'),
];

const _cycle = <_Opt>[
  _Opt('regular_cycle', '🗓️', 'Regular cycle'),
  _Opt('irregular_cycle', '🔄', 'Irregular cycle'),
  _Opt('trying_to_conceive', '🌱', 'Trying for a baby'),
  _Opt('pcos', '🌸', 'PCOS'),
  _Opt('pregnant', '🤰', 'Pregnant'),
  _Opt('postpartum', '🤱', 'Postpartum'),
  _Opt('menopause', '🍂', 'Menopause'),
  _Opt('prefer_not_to_say', '🤍', 'Prefer not to say'),
];

const _diet = <_Opt>[
  _Opt('vegetarian', '🥦', 'Vegetarian'),
  _Opt('halal', '🍗', 'Halal'),
  _Opt('lactose_free', '🥛', 'Lactose-free'),
  _Opt('gluten_free', '🌾', 'Gluten-free'),
  _Opt('eggs_ok', '🥚', 'Eggs OK'),
  _Opt('seafood_ok', '🐟', 'Seafood OK'),
  _Opt('no_restrictions', '🍽️', 'Eat everything'),
];

const _meals = <_Opt>[
  _Opt('3', '3', '3 meals', 'Breakfast, lunch, dinner'),
  _Opt('4', '4', '4 meals', 'Plus an afternoon snack'),
  _Opt('5', '5', '5 meals', 'Plus a mid-morning snack'),
  _Opt('6', '6', '6 meals', 'Plus an evening snack'),
];

const _fitness = <_Opt>[
  _Opt('beginner', '🌱', 'Beginner', 'New to workouts, or getting back into it'),
  _Opt('intermediate', '🏃‍♀️', 'Intermediate', 'I work out a few times a week'),
  _Opt('advanced', '🔥', 'Advanced', 'I train regularly and want a challenge'),
];

const _equipment = <_Opt>[
  _Opt('none', '🙌', 'Just me'),
  _Opt('mat', '🧘‍♀️', 'Yoga mat'),
  _Opt('dumbbells', '🏋️‍♀️', 'Dumbbells'),
  _Opt('resistance_bands', '🎗️', 'Bands'),
  _Opt('treadmill', '🏃‍♀️', 'Treadmill'),
  _Opt('full_gym', '🏟️', 'Full gym'),
];

class _TrialOnboardingScreenState extends State<TrialOnboardingScreen> {
  static const int _lastStep = 7;

  late final ConsultationController _consult;
  late final HomeController _home;

  bool _loading = true;
  bool _saving = false;
  bool _generating = false;
  // Current screen. Saved on the phone on every change (Oct 2026), so if
  // she closes the app halfway she comes back to the SAME screen. Her
  // answers themselves are saved on the server after every step.
  int _stepValue = 0;
  int get _step => _stepValue;
  set _step(int v) {
    _stepValue = v;
    if (!widget.setupMode) saveTrialOnboardingStep(v);
  }

  String? _goal;
  // True when her goal already came from signup, so the "What brings you
  // here?" step is skipped (she can still change it from the review step).
  bool _skipGoal = false;
  String? _cycleStatus;
  final Set<String> _prefs = {};
  int _mealsPerDay = 4;
  // Body step: one key per question so Next can scroll to the one she missed.
  final _bodyQKeys = List.generate(3, (_) => GlobalKey());
  String? _fitnessLevel;
  final Set<String> _equip = {};
  // Step 5: workout styles she loves (workoutSection.favoriteWorkouts).
  final Set<String> _loves = {};
  bool _confirmed = false;
  // Health data consent (review screen). Saved with time + version.
  bool _consented = false;
  static const String _kConsentVersion = 'v1';

  // Class picker (step 5). Loaded from GET /trial/classes.
  final Set<int> _pickedSlots = {};
  Map<String, dynamic>? _classData;
  bool _classesLoading = false;
  final List<String> _pickedTimes = [];
  // Step 6 has two screens: pick times, then see the week.
  bool _weekView = false;

  // Life stage already answered at signup: show it as a summary line
  // instead of asking again (tap "Change" to edit).
  bool _cycleKnown = false;
  bool _editCycle = false;
  // Health conditions she ticked at signup (User.healthConditions).
  String _signupConditions = '';
  // Times saved last time ("8:00 PM"), used if slot ids changed.
  final List<String> _savedTimes = [];

  // Welcome preview: her current cycle phase (null if she has no cycle data).
  String? _phase;

  final _allergies = TextEditingController();
  final _medical = TextEditingController();
  final _fasting = TextEditingController();
  final _injuries = TextEditingController();

  static const _busyMessages = [
    'Reading your answers…',
    'Matching meals to your goal…',
    'Checking allergies and health notes…',
    'Balancing calories for your body…',
    'Almost ready…',
  ];
  int _busyIdx = 0;
  Timer? _busyTimer;

  @override
  void initState() {
    super.initState();
    _consult = Get.find<ConsultationController>();
    _home = Get.find<HomeController>();
    _prefill();
  }

  @override
  void dispose() {
    _busyTimer?.cancel();
    for (final c in [_allergies, _medical, _fasting, _injuries]) {
      c.dispose();
    }
    super.dispose();
  }

  // Resume where she left off if she started before.
  Future<void> _prefill() async {
    final p = await _consult.loadProfile();
    if (!mounted) return;
    if (p != null) {
      _goal = p.goals;
      _cycleStatus = p.pregnancyMenstrualStatus;
      _allergies.text = p.allergies ?? '';
      _medical.text = p.medicalConditions ?? '';
      _fasting.text = p.fastingHabits ?? '';
      if (p.dietaryPreferences != null) {
        _prefs.addAll(p.dietaryPreferences!.map((e) => e.toString()));
      }
      final m = p.mealsPerDay;
      if (m != null && m >= 3 && m <= 6) _mealsPerDay = m;
      final ws = p.workoutSection;
      if (ws != null) {
        _fitnessLevel = ws['fitnessLevel'] as String?;
        if (ws['injuries'] is String) _injuries.text = ws['injuries'] as String;
        if (ws['favoriteWorkouts'] is List) {
          _loves.addAll((ws['favoriteWorkouts'] as List).map((e) => e.toString()));
        }
        if (ws['equipment'] is List) {
          _equip.addAll((ws['equipment'] as List).map((e) => e.toString()));
        }
        if (ws['preferredSlotIds'] is List) {
          for (final e in ws['preferredSlotIds'] as List) {
            final id = int.tryParse('$e');
            if (id != null) _pickedSlots.add(id);
          }
        }
        if (ws['preferredTimes'] is List) {
          _savedTimes.addAll(
              (ws['preferredTimes'] as List).map((e) => '$e').where((e) => e.isNotEmpty));
        }
      }
    }
    // Goal was already chosen at signup: carry it over and skip the step.
    final fromSignup = _goalFromSignup();
    if (_goal == null && fromSignup != null) _goal = fromSignup;
    _skipGoal = fromSignup != null && _goal != null;
    // Life stage comes from signup (same field), so don't ask it again.
    _cycleKnown = _cycleStatus != null;
    // One health-conditions answer: start from what she ticked at signup.
    try {
      final auth = Get.find<AuthController>();
      _signupConditions = (auth.logInUser?.healthConditions ?? '').trim();
      if (_signupConditions.isEmpty) {
        _signupConditions = auth.healthConditions.value.trim();
      }
    } catch (_) {}
    if (_medical.text.trim().isEmpty && _signupConditions.isNotEmpty) {
      _medical.text = _signupConditions;
    }
    if (widget.setupMode) {
      // No trial welcome page: straight to the form, or to class times.
      _step = widget.timesOnly ? 6 : (_skipGoal ? 2 : 1);
    } else {
      // Closed the app halfway last time: open the screen she was on.
      final saved = savedTrialOnboardingStep();
      if (saved > 0 && saved <= _lastStep) _stepValue = saved;
    }
    setState(() => _loading = false);
    _loadClasses();
    _loadPhase();
  }

  // Works out today's phase from her saved cycle (same formula as the
  // backend), so the preview isn't stuck on the phase from signup day.
  Future<void> _loadPhase() async {
    try {
      final token =
          Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
      final r = await Get.find<CycleDataRepository>().getCycleData(accessToken: token);
      final body = r.body;
      if (body is! Map || body['data'] == null) return;
      var d = body['data'];
      if (d is Map && d['cycleData'] is Map) d = d['cycleData'];
      if (d is! Map) return;
      final provided = d['dataProvided'];
      if (provided == 0 || provided == false || d['lastPeriodDate'] == null) return;
      final last = DateTime.tryParse('${d['lastPeriodDate']}');
      if (last == null) return;
      final len = int.tryParse('${d['averageCycleLength'] ?? 28}') ?? 28;
      final now = DateTime.now();
      final days = DateTime(now.year, now.month, now.day)
          .difference(DateTime(last.year, last.month, last.day))
          .inDays;
      if (days < 0 || len <= 0) return;
      final day = (days % len) + 1;
      String phase;
      if (day <= (len * 0.18).round()) {
        phase = 'menstrual';
      } else if (day <= (len * 0.46).round()) {
        phase = 'follicular';
      } else if (day <= (len * 0.57).round()) {
        phase = 'ovulatory';
      } else {
        phase = 'luteal';
      }
      if (mounted) setState(() => _phase = phase);
    } catch (_) {
      // No cycle data: the phase tag and tip simply don't show.
    }
  }

  /// Signup goal (+ PCOS / new mother) mapped onto the trial goal list.
  /// Null when signup didn't record a goal (older accounts).
  String? _goalFromSignup() {
    final auth = Get.find<AuthController>();
    // Memory first, then the saved login user as a fallback.
    String pick(String a, String? b) => a.trim().isNotEmpty ? a : (b ?? '');
    final main = pick(auth.mainGoal.value, auth.logInUser?.mainGoal)
        .trim()
        .toLowerCase();
    final cond = pick(auth.healthConditions.value, auth.logInUser?.healthConditions)
        .toLowerCase();
    if (main.isEmpty) return null;
    if (_cycleStatus == 'postpartum') return 'postpartum';
    if (cond.contains('pcos')) return 'pcos_management';
    if (main.contains('lose')) return 'weight_loss';
    if (main.contains('gain')) return 'weight_gain';
    if (main.contains('strength') || main.contains('tone')) return 'maintain';
    return 'general_wellness'; // Improve fitness, Reduce stress, anything else
  }

  Future<void> _loadClasses() async {
    if (_classesLoading) return;
    setState(() => _classesLoading = true);
    final data = await _home.loadTrialClasses();
    if (!mounted) return;
    setState(() {
      _classData = data;
      _classesLoading = false;
      // Drop picks for classes that no longer exist.
      final ids = _classes.map((c) => c['slotId'] as int).toSet();
      _pickedSlots.removeWhere((id) => !ids.contains(id));
      _timesFromSlots();
      _restoreOrSuggestTimes();
    });
  }

  /// No picks found by id: use the times she saved last time; if none,
  /// pre-select up to 2 classes in the time of day she chose at signup
  /// (morning / afternoon / evening / night). She can change them.
  /// Time of day she chose at signup (morning / afternoon / evening /
  /// night), or '' if none / "all".
  String get _signupTimeBlock {
    try {
      final b = Get.find<AuthController>()
              .sharedPreferences
              .getString(Constants.timeBlock) ??
          '';
      return b == 'all' ? '' : b;
    } catch (_) {
      return '';
    }
  }

  void _restoreOrSuggestTimes() {
    if (_pickedTimes.isNotEmpty) return;
    final options = _timeOptions;
    String n(String t) => t.trim().toUpperCase().replaceFirst(RegExp(r'^0'), '');
    for (final saved in _savedTimes) {
      for (final o in options) {
        final t = '${o['time']}';
        if (n(t) == n(saved) && !_pickedTimes.contains(t) && _pickedTimes.length < 2) {
          _pickedTimes.add(t);
        }
      }
    }
    // Her signup "time of day" is NOT pre-selected: she picks her own free
    // times. It only adds a "Suggested for you" tag on that part of the day.
    if (_pickedTimes.isNotEmpty) _syncSlotsFromTimes();
  }

  List<Map<String, dynamic>> get _classes {
    final raw = _classData?['classes'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((c) => c['slotId'] is int)
        .toList();
  }

  Map<String, dynamic> get _workoutBody => {
        'fitnessLevel': _fitnessLevel,
        'injuries':
            _injuries.text.trim().isEmpty ? null : _injuries.text.trim(),
        'equipment': _equip.toList(),
        'favoriteWorkouts': _loves.toList(),
        'preferredSlotIds': _pickedSlots.toList(),
        'preferredTimes': _pickedTimes.toList(),
        // Picking times = leaving "All classes" (if she had chosen it).
        if (_pickedTimes.isNotEmpty) 'reminderMode': 'picked',
      };

  /// Body step questions still unanswered (0 cycle, 1 allergies, 2 health).
  List<int> get _bodyMissing => [
        if (_cycleStatus == null) 0,
        if (_allergies.text.trim().isEmpty) 1,
        if (_medical.text.trim().isEmpty) 2,
      ];

  /// The cycle question is only asked when we don't know it yet.
  bool get _cycleQuestionShown => !_cycleKnown || _editCycle || _cycleStatus == null;
  int get _bodyTotal => _cycleQuestionShown ? 3 : 2;

  /// Next tapped with answers missing: scroll to the first one.
  void _nudgeBody() {
    final ctx = _bodyQKeys[_bodyMissing.first].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300), alignment: 0.2);
    }
  }

  bool get _stepValid {
    switch (_step) {
      case 1:
        return _goal != null;
      case 2:
        return _cycleStatus != null &&
            _allergies.text.trim().isNotEmpty &&
            _medical.text.trim().isNotEmpty;
      case 3:
        return _prefs.isNotEmpty;
      case 4:
        return _fitnessLevel != null;
      case 5:
        return _loves.isNotEmpty;
      case 6:
        return _pickedTimes.isNotEmpty;
      case 7:
        return _confirmed && _consented;
      default:
        return true;
    }
  }

  Map<String, dynamic>? _bodyForStep(int step) {
    switch (step) {
      case 1:
        return {'goals': _goal, 'step': 'goals'};
      case 2:
        return {
          'pregnancyMenstrualStatus': _cycleStatus,
          'allergies': _allergies.text.trim(),
          'medicalConditions': _medical.text.trim(),
          'step': 'health',
        };
      case 3:
        return {
          'dietaryPreferences': _prefs.toList(),
          'mealsPerDay': _mealsPerDay,
          'fastingHabits':
              _fasting.text.trim().isEmpty ? null : _fasting.text.trim(),
          'step': 'diet_lifestyle',
        };
      case 4:
        return {'workoutSection': _workoutBody, 'step': 'workout'};
      case 5:
        return {'workoutSection': _workoutBody, 'step': 'workout_likes'};
      case 6:
        return {'workoutSection': _workoutBody, 'step': 'classes'};
      default:
        return null;
    }
  }

  /// Review step button: start straight away when both boxes are ticked,
  /// otherwise "One last step" (promises + Agree & start).
  Future<void> _onReviewButton() async {
    if (_confirmed && _consented) return _next();
    final agreed = await showAgreeAndStartSheet(setupMode: widget.setupMode);
    if (!mounted || !agreed) return;
    setState(() {
      _confirmed = true;
      _consented = true;
    });
    await _next();
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step == _lastStep) return _finish();
    if (_step == 6 && !_weekView) {
      setState(() => _weekView = true);
      return;
    }
    // Setup mode, diet-only client: no class times, go from step 5 to review.
    if (widget.setupMode && !widget.includeClasses && _step == 5) {
      final body = _bodyForStep(5);
      setState(() => _saving = true);
      final ok = body == null || await _consult.patchProfile(body);
      if (!mounted) return;
      setState(() => _saving = false);
      if (!ok) {
        CustomToast.failToast(msg: 'Could not save. Please try again.');
        return;
      }
      setState(() => _step = _lastStep);
      return;
    }
    // Setup mode, times only: save the picks and close.
    if (widget.setupMode && widget.timesOnly && _step == 6) {
      setState(() => _saving = true);
      final ok = await _consult.patchProfile(_bodyForStep(6)!);
      if (!mounted) return;
      setState(() => _saving = false);
      if (!ok) {
        CustomToast.failToast(msg: 'Could not save. Please try again.');
        return;
      }
      CustomToast.successToast(msg: 'Saved! We\'ll remind you before your classes.');
      Get.back<bool>(result: true);
      return;
    }
    if (_step == 0 && _skipGoal) {
      setState(() => _saving = true);
      final ok = await _consult.patchProfile(_bodyForStep(1)!);
      if (!mounted) return;
      setState(() => _saving = false);
      if (!ok) {
        CustomToast.failToast(msg: 'Could not save. Please try again.');
        return;
      }
      setState(() => _step = 2);
      return;
    }
    final body = _bodyForStep(_step);
    if (body != null) {
      setState(() => _saving = true);
      final ok = await _consult.patchProfile(body);
      if (!mounted) return;
      setState(() => _saving = false);
      if (!ok) {
        CustomToast.failToast(msg: 'Could not save. Please try again.');
        return;
      }
    }
    setState(() => _step++);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    final firstSetupStep =
        widget.timesOnly ? 6 : (_skipGoal ? 2 : 1);
    if (_step == 6 && _weekView) {
      setState(() => _weekView = false);
    } else if (widget.setupMode && _step <= firstSetupStep) {
      // First page of setup: back = "Later" if allowed, else stay.
      if (widget.canSkip) Get.back<bool>(result: false);
    } else if (widget.setupMode && !widget.includeClasses && _step == _lastStep) {
      setState(() => _step = 5);
    } else if (_step > 0) {
      setState(() => _step = (_step == 2 && _skipGoal) ? 0 : _step - 1);
    } else {
      _leave();
    }
  }

  void _leave() {
    if (Navigator.of(context).canPop()) {
      Get.back<void>();
    } else {
      Get.offAll<void>(() => BottomBarScreen(index: 0));
    }
  }

  Future<void> _finish() async {
    if (widget.setupMode) {
      setState(() => _saving = true);
      final ok = await _consult.patchProfile({
        'isComplete': true,
        'healthConsent': true,
        'consentVersion': _kConsentVersion,
        // She reviewed and confirmed: counts as her real health form
        // (also for answers carried over from her free trial).
        'confirmed': true,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      if (!ok) {
        CustomToast.failToast(msg: 'Could not save. Please try again.');
        return;
      }
      CustomToast.successToast(msg: 'All set, thank you!');
      Get.back<bool>(result: true);
      return;
    }
    setState(() => _generating = true);
    _busyIdx = 0;
    _busyTimer?.cancel();
    _busyTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() => _busyIdx = (_busyIdx + 1) % _busyMessages.length);
      }
    });

    final saved = await _consult.patchProfile({
      'isComplete': true,
      'healthConsent': true,
      'consentVersion': _kConsentVersion,
    });
    // Starting is idempotent: returns her existing journey if she already
    // has one. The 3-day clock only starts here, after the form.
    final started = saved && await _home.startTrial();
    // The server waits at most 6 s for the AI plan (the "making your
    // plan" screen stays up meanwhile), then lets her move on.
    final planned = started && await _home.submitTrialQuickIntake();

    _busyTimer?.cancel();
    if (!mounted) return;
    if (!planned) {
      setState(() => _generating = false);
      if (!saved) CustomToast.failToast(msg: 'Could not save. Please try again.');
      return;
    }
    // Form done: nothing to resume any more.
    clearTrialOnboardingStep();
    // Only now is the trial switched on for this device.
    Get.find<AuthController>().activateTrial();
    if (_home.trialPlanPending.value) {
      // Plan still being made: she uses the app meanwhile; one push
      // ("Your starter plan is ready 🌱") when it's done.
      Get.offAll<void>(() => BottomBarScreen(index: 0));
      CustomToast.successToast(
        msg: "Your plan will be shared soon. We'll send you a notification when it's ready.",
      );
      return;
    }
    Get.offAll<void>(() => const TrialMealPlanScreen());
  }

  String _labelOf(List<_Opt> opts, String? v) {
    for (final o in opts) {
      if (o.value == v) return '${o.emoji}  ${o.label}';
    }
    return v ?? '';
  }

  // ── Layout ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_generating) return false;
        if (widget.setupMode) {
          _back();
          return false;
        }
        if (_step > 0) {
          _back();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Same soft circles as the signup screens (OnboardingScaffold).
            Positioned(
              top: -80,
              right: -70,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kAccentBg.withOpacity(0.5),
                ),
              ),
            ),
            Positioned(
              bottom: 140,
              left: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kAccentBg.withOpacity(0.3),
                ),
              ),
            ),
            SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
                  ),
                )
              : Stack(
                  children: [
                    Column(
                      children: [
                        if (_step > 0) _topBar(),
                        if (_step > 0 && widget.partLabel != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(62, 4, 20, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                              widget.partLabel!,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kAccent,
                              ),
                            ),
                            ),
                          ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.06, 0),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            ),
                            child: SingleChildScrollView(
                              key: ValueKey('$_step${_step == 6 && _weekView ? 'w' : ''}'),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              child: _stepContent(),
                            ),
                          ),
                        ),
                        _bottomBar(),
                      ],
                    ),
                    if (_generating) _generatingOverlay(),
                  ],
                ),
            ),
          ],
        ),
      ),
    );
  }

  // Step numbers shown to her (goal step hidden when it came from signup).
  int get _shownTotal => _skipGoal ? _lastStep - 1 : _lastStep;
  int get _shownStep => (_skipGoal && _step > 1) ? _step - 1 : _step;

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 4),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _back,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder, width: 1.5),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _kInk, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: (widget.setupMode && widget.timesOnly)
                ? const SizedBox.shrink()
                : Row(
              children: List.generate(_shownTotal, (i) {
                final on = i < _shownStep;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: EdgeInsets.only(right: i == _shownTotal - 1 ? 0 : 5),
                    height: 6,
                    decoration: BoxDecoration(
                      color: on ? _kAccent : _kBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          if (!(widget.setupMode && widget.timesOnly))
            Text(
              '$_shownStep of $_shownTotal',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kInkSoft,
              ),
            ),
          if (widget.setupMode && widget.canSkip) ...[
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Get.back<bool>(result: false),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  'Later',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kInkSoft,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final label = _step == 0
        ? 'Build my plan  →'
        : _step == _lastStep
            ? (widget.setupMode ? 'Save my answers' : 'Start my free trial')
            : (_step == 5 && _loves.isEmpty)
                ? 'Pick at least one  →'
                : _step == 6
                    ? (_pickedTimes.isEmpty
                        ? 'Pick a time  →'
                        : !_weekView
                            ? 'See my week  →'
                            : (widget.setupMode && widget.timesOnly)
                                ? 'Save · remind me at ${_pickedTimes.join(' & ')}'
                                : 'Remind me at ${_pickedTimes.join(' & ')}  →')
                    : (_step == 2 && _bodyMissing.isNotEmpty)
                        ? '${_bodyTotal - _bodyMissing.length} of $_bodyTotal answered · Next →'
                        : 'Continue';
    // Review step: always green (Oct 2026). Without both ticks a tap opens
    // "One last step" with the promises and "Agree & start".
    final reviewStep = _step == _lastStep;
    final bodyNudge = _step == 2 && _bodyMissing.isNotEmpty;
    final enabled =
        (reviewStep || bodyNudge || _stepValid) && !_saving && !_generating;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: _kInk.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_step == 0) _WelcomeTrustLine(days: _home.trialDays.value),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: enabled
                  ? (reviewStep
                      ? _onReviewButton
                      : bodyNudge
                          ? _nudgeBody
                          : _next)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                disabledBackgroundColor: _kAccent.withOpacity(0.35),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          if (_step == 6 && _pickedTimes.isNotEmpty && _classes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _weekView
                    ? "We'll remind you 15 min before and when class goes live"
                    : 'Tap a picked time to change it',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  color: _kInkSoft,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepContent() {
    switch (_step) {
      case 0:
        return _welcome();
      case 1:
        return _goalStep();
      case 2:
        return _bodyStep();
      case 3:
        return _foodStep();
      case 4:
        return _moveStep();
      case 5:
        return _lovesStep();
      case 6:
        return _classStep();
      default:
        return _reviewStep();
    }
  }

  // ── Step 0: Welcome ────────────────────────────────────────────────
  // First screen: a preview of her first trial day, built from her
  // signup answers (goal, PCOS), her cycle phase and the real class
  // schedule. Shows instead of telling. The questions start on "Build
  // my plan".
  Widget _welcome() {
    final auth = Get.find<AuthController>();
    final name = (auth.logInUser?.firstName ?? '').trim();
    final days = _home.trialDays.value;
    final meals = _WelcomeMeals.forUser(
      trialGoal: _goal,
      signupGoal: auth.mainGoal.value,
      conditions: auth.healthConditions.value,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _leave,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBorder, width: 1.5),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: _kInk, size: 20),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kAccentBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircleAvatar(radius: 3, backgroundColor: _kAccent),
                  SizedBox(width: 6),
                  Text('Your plan preview',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kInk,
                      )),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          name.isEmpty ? 'Hi,' : 'Hi $name,',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: _kInkSoft,
          ),
        ),
        const SizedBox(height: 2),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 23,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: _kInk,
              letterSpacing: -0.3,
            ),
            children: [
              TextSpan(text: "Here's what your "),
              TextSpan(text: 'first', style: TextStyle(color: Color(0xFF3F9B35))),
              TextSpan(text: ' day could look like'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _WelcomeDayCard(days: days, phase: _phase),
        const SizedBox(height: 12),
        _WelcomeClassCard(
          cls: _welcomeClass(),
          loading: _classesLoading && _classData == null,
          phase: _phase,
          womenLastWeek: ((_classData?['womenLastWeek'] ?? 0) as num).toInt(),
          onTap: _classes.isEmpty ? null : _showTimetable,
        ),
        const SizedBox(height: 18),
        _WelcomeSection(title: 'Your meals tomorrow', trailing: '${meals.length} meals'),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < meals.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _WelcomeMealCard(meal: meals[i])),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _WelcomeSection(
          title: 'Coming up',
          trailing: days > 1 ? '${days - 1} more ${days - 1 == 1 ? 'day' : 'days'}' : '',
        ),
        const SizedBox(height: 10),
        _WelcomeComingUp(days: days),
      ],
    );
  }

  /// The class to feature, all from the real schedule: her picked one,
  /// else a recommended one at a sensible hour, else the most popular
  /// daytime class. Night classes (11 PM to 6 AM her time) are only used
  /// if nothing else exists.
  Map<String, dynamic>? _welcomeClass() {
    final list = _dayClasses;
    if (list.isEmpty) return null;
    bool daytime(Map<String, dynamic> c) {
      final k = c['sortKey'];
      if (k is! num) return true;
      return k >= 360 && k < 1380;
    }
    int pop(Map<String, dynamic> c) => ((c['joinedLastWeek'] ?? 0) as num).toInt();

    // Match the class to her cycle phase so the card never says "go
    // gentle" next to a High Intensity class.
    bool gentle(Map<String, dynamic> c) => RegExp(
            r'yoga|stretch|pilates|low|beginner|mobility|breath|gentle',
            caseSensitive: false)
        .hasMatch('${c['type'] ?? ''} ${c['level'] ?? ''}');
    bool intense(Map<String, dynamic> c) => RegExp(
            r'high|hiit|intens|strength|cardio|advanced|tone',
            caseSensitive: false)
        .hasMatch('${c['type'] ?? ''} ${c['level'] ?? ''}');
    final wantGentle = _phase == 'menstrual' || _phase == 'luteal';
    final wantStrong = _phase == 'ovulatory' || _phase == 'follicular';

    final picked = list
        .where((c) => _pickedTimes.contains('${c['startLocal']}'))
        .toList();
    if (picked.isNotEmpty) return picked.first;
    final day = list.where(daytime).toList();
    var pool = day.isNotEmpty ? day : list;
    if (wantGentle) {
      final g = pool.where(gentle).toList();
      final notHard = pool.where((c) => !intense(c)).toList();
      pool = g.isNotEmpty ? g : (notHard.isNotEmpty ? notHard : pool);
    } else if (wantStrong) {
      final st = pool.where(intense).toList();
      if (st.isNotEmpty) pool = st;
    }
    final rec = pool.where((c) => c['recommended'] == true).toList();
    if (rec.isNotEmpty) return rec.first;
    final sorted = [...pool]..sort((a, b) => pop(b).compareTo(pop(a)));
    return sorted.first;
  }

  /// Full daily class timetable (real schedule, her time zone). She can
  /// tap classes to pick them here; the picks carry over to the class
  /// step and the preview card updates.
  Future<void> _showTimetable() async {
    final showPk = _classData?['showsPakistanTime'] == true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final groups = <Widget>[];
          for (final entry in _parts.entries) {
            final inPart =
                _dayClasses.where((c) => c['part'] == entry.key).toList();
            if (inPart.isEmpty) continue;
            final meta = entry.value;
            groups.add(Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              decoration: BoxDecoration(
                color: meta[2] as Color,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      '${meta[0]}  ${meta[1]}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                  ),
                  ...inPart.map((c) {
                    final t = '${c['startLocal']}';
                    return TrialClassCard(
                      data: c,
                      selected: _pickedTimes.contains(t),
                      showPakistanTime: showPk,
                      onTap: () {
                        setSheet(() => _toggleTime(t));
                        if (mounted) setState(() {});
                      },
                    );
                  }),
                ],
              ),
            ));
          }
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scroll) => Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Class timetable',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _kInk,
                                )),
                            SizedBox(height: 2),
                            Text('Live every day · times in your time zone',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: _kInkSoft,
                                )),
                          ],
                        ),
                      ),
                      if (_pickedTimes.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kAccentBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_pickedTimes.length} picked',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _kDeep,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'Tap a class to pick it for your reminders. You can join any class during your trial.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      height: 1.4,
                      color: _kInkSoft,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: groups,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Done',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  // ── Step 1: Goal ───────────────────────────────────────────────────
  Widget _goalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          title: 'What brings you here?',
          sub: 'Pick your main goal. Your meals and workouts are built around it.',
        ),
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _goals
                .map((g) => SizedBox(
                      width: w,
                      child: _BigCard(
                        opt: g,
                        selected: _goal == g.value,
                        onTap: () => setState(() => _goal = g.value),
                      ),
                    ))
                .toList(),
          );
        }),
      ],
    );
  }

  // ── Step 2: Body & cycle ───────────────────────────────────────────
  Widget _bodyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          title: _cycleQuestionShown ? 'Your body & cycle' : 'Your health',
          sub: 'Keeps your plan safe.',
        ),
        // Oct 2026 (shorter page): one privacy line instead of the card.
        Transform.translate(
          offset: const Offset(0, -12),
          child: const Text(
            '🔒 Private to you and your Fit Her team',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: _kInkSoft),
          ),
        ),
        const SizedBox(height: 6),
        // Cycle: hidden when she already told us (sign-up life stage);
        // she can still change it on the review step.
        if (_cycleQuestionShown) ...[
          _Label('Where are you in your cycle?', key: _bodyQKeys[0]),
          const _Hint('So your meals match your cycle phase.'),
          _ChipGrid(
            opts: _cycle,
            isOn: (v) => _cycleStatus == v,
            onTap: (v) => setState(() => _cycleStatus = v),
          ),
          const SizedBox(height: 22),
        ],
        _Label('Any food allergies?', key: _bodyQKeys[1]),
        const _Hint("So we never add something you can't eat."),
        _InputWithNone(
          controller: _allergies,
          hint: 'Something else? Type it here',
          noneLabel: 'No allergies',
          options: kAllergyOptions,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 22),
        _Label('Any health conditions?', key: _bodyQKeys[2]),
        _Hint(_signupConditions.isNotEmpty
            ? 'From your signup. Add anything else, or edit.'
            : "So we never suggest something that isn't right for you."),
        _InputWithNone(
          controller: _medical,
          hint: 'Something else? Type it here',
          noneLabel: 'None',
          options: kConditionOptions,
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }

  /// An answer she already gave at signup, with a small "Change" link.
  Widget _knownAnswer(String text, VoidCallback onChange) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kAccentBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kInk,
              ),
            ),
          ),
          GestureDetector(
            onTap: onChange,
            child: const Text(
              'Change',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Food ───────────────────────────────────────────────────
  Widget _foodStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          title: 'How you like to eat',
          sub: "We'll only suggest food that fits your life.",
        ),
        const _Label('Food preferences (pick all that apply)'),
        _ChipGrid(
          opts: _diet,
          isOn: (v) => _prefs.contains(v),
          onTap: (v) => setState(() {
            if (!_prefs.remove(v)) _prefs.add(v);
          }),
        ),
        const SizedBox(height: 22),
        const _Label('How many meals a day suit you?'),
        ..._meals.map((m) {
          final on = '$_mealsPerDay' == m.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SelectRow(
              selected: on,
              onTap: () => setState(() => _mealsPerDay = int.parse(m.value)),
              leading: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? _kAccent : _kAccentBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  m.emoji,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: on ? Colors.white : _kInk,
                  ),
                ),
              ),
              title: m.label,
              sub: m.sub!,
            ),
          );
        }),
        const SizedBox(height: 14),
        const _Label('Do you fast? (optional)'),
        _Input(controller: _fasting, hint: 'e.g. Mondays and Thursdays, Ramadan'),
      ],
    );
  }

  // ── Step 4: Movement ───────────────────────────────────────────────
  Widget _moveStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          title: 'How you like to move',
          sub: 'So your live classes match your level.',
        ),
        const _Label('Your fitness level'),
        ..._fitness.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SelectRow(
                selected: _fitnessLevel == f.value,
                onTap: () => setState(() => _fitnessLevel = f.value),
                leading: Text(f.emoji, style: const TextStyle(fontSize: 26)),
                title: f.label,
                sub: f.sub!,
              ),
            )),
        const SizedBox(height: 14),
        const _Label('What do you have at home?'),
        _ChipGrid(
          opts: _equipment,
          isOn: (v) => _equip.contains(v),
          onTap: (v) => setState(() {
            if (!_equip.remove(v)) _equip.add(v);
          }),
        ),
        const SizedBox(height: 22),
        const _Label('Any injuries or pain to avoid? (optional)'),
        _Input(controller: _injuries, hint: 'e.g. knee pain, lower back'),
      ],
    );
  }

  // ── Step 5: Workouts she loves ─────────────────────────────────────
  Widget _lovesStep() {
    final starred = _WorkoutLove.recommendedFor(
      goal: _goal,
      cycleStatus: _cycleStatus,
      fitnessLevel: _fitnessLevel,
      conditions: '${Get.find<AuthController>().healthConditions.value} ${_medical.text}',
    );
    final tiles = _WorkoutLove.all.map((o) {
      final on = _loves.contains(o.value);
      return _WorkoutLoveTile(
        option: o,
        selected: on,
        starred: starred.contains(o.value),
        onTap: () => setState(() {
          if (o.value == 'mix') {
            // "A bit of everything" stands alone.
            if (on) {
              _loves.remove('mix');
            } else {
              _loves
                ..clear()
                ..add('mix');
            }
          } else {
            _loves.remove('mix');
            if (!_loves.remove(o.value)) _loves.add(o.value);
          }
        }),
      );
    }).toList();
    final rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 10),
              Expanded(
                  child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
            ],
          ),
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
            children: [
              TextSpan(text: 'What do you '),
              TextSpan(text: 'love to do?', style: TextStyle(color: _kDeep)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pick everything you enjoy.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _kInkSoft),
        ),
        const SizedBox(height: 12),
        if (starred.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFDEFF3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 18, color: Color(0xFFE0A21B)),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 11.5, color: _kInkSoft, height: 1.4),
                      children: [
                        TextSpan(
                            text: 'Picked for you',
                            style: TextStyle(fontWeight: FontWeight.w700, color: _kInk)),
                        TextSpan(text: ' · starred to suit your goal and health profile'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ...rows,
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'You can change this anytime',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: _kInkSoft),
          ),
        ),
      ],
    );
  }

  // ── Step 7: Review & confirm ───────────────────────────────────────
  Widget _reviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          title: "Here's your plan recipe",
          sub: 'Check everything is right. We build your meal plan and match your classes from this.',
        ),
        _ReviewCard(
          title: 'Goal',
          onEdit: () => setState(() => _step = 1),
          lines: [_labelOf(_goals, _goal)],
        ),
        _ReviewCard(
          title: 'Body & cycle',
          onEdit: () => setState(() => _step = 2),
          lines: [
            _labelOf(_cycle, _cycleStatus),
            'Allergies: ${_allergies.text.trim()}',
            'Health: ${_medical.text.trim()}',
          ],
        ),
        _ReviewCard(
          title: 'Food',
          onEdit: () => setState(() => _step = 3),
          lines: [
            _prefs.map((p) => _labelOf(_diet, p)).join('   '),
            '$_mealsPerDay meals a day',
            if (_fasting.text.trim().isNotEmpty) 'Fasting: ${_fasting.text.trim()}',
          ],
        ),
        _ReviewCard(
          title: 'Movement',
          onEdit: () => setState(() => _step = 4),
          lines: [
            _labelOf(_fitness, _fitnessLevel),
            if (_equip.isNotEmpty)
              _equip.map((e) => _labelOf(_equipment, e)).join('   '),
            if (_injuries.text.trim().isNotEmpty) 'Avoid: ${_injuries.text.trim()}',
          ],
        ),
        _ReviewCard(
          title: 'Workouts you love',
          onEdit: () => setState(() => _step = 5),
          lines: [
            _loves.map((v) => _WorkoutLove.labelOf(v)).join('   '),
          ],
        ),
        _ReviewCard(
          title: 'Class reminders',
          onEdit: () => setState(() {
            _step = 6;
            _weekView = false;
          }),
          lines: _pickedSummary(),
        ),
        const SizedBox(height: 6),
        _ConsentTick(
          checked: _confirmed,
          onTap: () => setState(() => _confirmed = !_confirmed),
          child: const Text(
            'Yes, these answers are correct',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: _kInk,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ConsentTick(
          checked: _consented,
          onTap: () => setState(() => _consented = !_consented),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: "I'm happy for Fit Her to use my health info "),
                const TextSpan(
                  text: 'only to create my plan and keep my classes safe.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () => showSafeSpaceSheet(),
                    child: const Text(
                      'Read more',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kAccent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              height: 1.45,
              color: _kInk,
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 5: Class times ────────────────────────────────────────────
  static const _parts = <String, List<Object>>{
    // part: [emoji, label, card tint]
    'morning': ['🌅', 'Morning', Color(0xFFFFF1DE)],
    'afternoon': ['☀️', 'Afternoon', Color(0xFFFFF8E1)],
    'evening': ['🌇', 'Evening', Color(0xFFF6ECFA)],
    'night': ['🌙', 'Night', Color(0xFFE9ECF8)],
  };

  // Her class times ("h:mm A", her time zone) live in _pickedTimes, in
  // pick order (1st, 2nd). _pickedSlots holds every class at those times
  // on every day, so the server reminds her whichever day it is.
  static const _weekOrder = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  String? _dayOf(Map<String, dynamic> c) {
    final d = c['dayLocal'] ?? c['day'];
    return d is String && d.isNotEmpty ? d : null;
  }

  String get _tomorrowName =>
      _weekOrder[DateTime.now().add(const Duration(days: 1)).weekday - 1];

  /// Tomorrow's classes if the schedule has days, else all classes.
  List<Map<String, dynamic>> get _dayClasses {
    final all = _classes;
    final tm = all.where((c) => _dayOf(c) == _tomorrowName).toList();
    return tm.isNotEmpty ? tm : all;
  }

  List<String> get _weekDays {
    final set = _classes.map(_dayOf).whereType<String>().toSet();
    return _weekOrder.where(set.contains).toList();
  }

  List<Map<String, dynamic>> _classesOn(String? day) =>
      _classes.where((c) => _dayOf(c) == null || _dayOf(c) == day).toList();

  /// Distinct class start times, earliest first.
  List<Map<String, dynamic>> get _timeOptions {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    final sorted = [..._classes]..sort((a, b) =>
        ((a['sortKey'] ?? 0) as num).compareTo((b['sortKey'] ?? 0) as num));
    for (final c in sorted) {
      final t = '${c['startLocal'] ?? ''}';
      if (t.isEmpty || !seen.add(t)) continue;
      out.add({'time': t, 'part': c['part'], 'sortKey': c['sortKey']});
    }
    return out;
  }

  void _syncSlotsFromTimes() {
    _pickedSlots
      ..clear()
      ..addAll(_classes
          .where((c) => _pickedTimes.contains('${c['startLocal']}'))
          .map((c) => c['slotId'] as int));
  }

  /// Rebuilds her picked times from saved slot ids (first load).
  void _timesFromSlots() {
    if (_pickedTimes.isNotEmpty || _pickedSlots.isEmpty) return;
    for (final o in _timeOptions) {
      final t = o['time'] as String;
      if (_classes.any((c) =>
          '${c['startLocal']}' == t && _pickedSlots.contains(c['slotId']))) {
        _pickedTimes.add(t);
        if (_pickedTimes.length == 2) break;
      }
    }
    _syncSlotsFromTimes();
  }

  /// Tap a time: picks it, or removes it if already picked. A third pick
  /// replaces the 2nd.
  void _toggleTime(String t) {
    if (!_pickedTimes.remove(t)) {
      if (_pickedTimes.length >= 2) _pickedTimes.removeLast();
      _pickedTimes.add(t);
    }
    _syncSlotsFromTimes();
  }

  static List<Object> _typeStyle(String type) {
    final t = type.toLowerCase();
    if (RegExp(r'zumba|danc').hasMatch(t)) {
      return ['Zumba', const Color(0xFFFCE1EC), const Color(0xFFC2185B)];
    }
    if (RegExp(r'yoga|stretch|pilates|mobility|breath').hasMatch(t)) {
      return ['Yoga', const Color(0xFFECE6FA), const Color(0xFF6A4FB3)];
    }
    if (RegExp(r'\blow\b|gentle|walk|beginner').hasMatch(t)) {
      return ['Low', const Color(0xFFE1F0FA), const Color(0xFF2E7DAF)];
    }
    if (RegExp(r'hiit|high|cardio|burn').hasMatch(t)) {
      return ['HIIT', const Color(0xFFFFE3D3), const Color(0xFFC4551F)];
    }
    if (RegExp(r'strength|tone|weight|sculpt').hasMatch(t)) {
      return ['Strength', const Color(0xFFFFF3CC), const Color(0xFF9A6F00)];
    }
    final w = type.trim().split(RegExp(r'\s+')).first;
    return [
      w.isEmpty ? 'Class' : (w.length > 8 ? w.substring(0, 8) : w),
      _kAccentBg,
      _kInk,
    ];
  }

  /// True when the class matches a workout she said she loves.
  bool _isFavourite(Map<String, dynamic> c) {
    if (_loves.isEmpty || _loves.contains('mix')) return false;
    final t = '${c['type'] ?? ''} ${c['level'] ?? ''}'.toLowerCase();
    const pats = {
      'high_intensity': r'hiit|high|cardio|burn',
      'strength': r'strength|tone|weight|sculpt',
      'zumba': r'zumba|danc',
      'yoga': r'yoga|stretch|pilates|mobility',
      'low_intensity': r'\blow\b|gentle|walk|beginner',
    };
    return _loves.any((l) => pats[l] != null && RegExp(pats[l]!).hasMatch(t));
  }

  String _short(String day) => day.length > 3 ? day.substring(0, 3) : day;

  /// Days that have a class at one of her times.
  List<String?> get _workoutDays {
    final days = _weekDays;
    final list = days.isEmpty ? <String?>[null] : days.cast<String?>();
    return list
        .where((d) => _classesOn(d)
            .any((c) => _pickedTimes.contains('${c['startLocal']}')))
        .toList();
  }

  String _rangeLabel(List<String?> days) {
    if (days.isEmpty || days.first == null || days.length == 7) return 'Every day';
    if (days.length == 1) return days.first!;
    return '${_short(days.first!)} to ${_short(days.last!)}';
  }

  /// Her next class at one of her times: {'when': 'tomorrow', 'c': class}.
  Map<String, dynamic>? _firstClass() {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    for (int i = 0; i < 7; i++) {
      final name = _weekOrder[now.add(Duration(days: i)).weekday - 1];
      final list = _classesOn(name)
          .where((c) => _pickedTimes.contains('${c['startLocal']}'))
          .where((c) => i > 0 || ((c['sortKey'] ?? 0) as num) > nowMin + 10)
          .toList()
        ..sort((a, b) =>
            ((a['sortKey'] ?? 0) as num).compareTo((b['sortKey'] ?? 0) as num));
      if (list.isNotEmpty) {
        return {
          'when': i == 0 ? 'today' : (i == 1 ? 'tomorrow' : name),
          'c': list.first,
        };
      }
    }
    return null;
  }

  List<String> _pickedSummary() {
    if (_pickedTimes.isEmpty) return const [];
    final days = _workoutDays;
    return [
      '🔔  ${_pickedTimes.join(' and ')}',
      '${days.length == 1 && days.first == null ? 'Every day' : '${days.length} workout days'}, ${_rangeLabel(days)}',
    ];
  }

  Widget _stepBadge(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccentBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: _kAccent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5A7A56),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _twoToneTitle(String a, String b) => RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: _kInk,
          ),
          children: [
            TextSpan(text: a),
            TextSpan(text: b, style: const TextStyle(color: _kDeep)),
          ],
        ),
      );

  Widget _subLine(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 13, height: 1.45, color: _kInkSoft),
        ),
      );

  Widget _classStep() {
    final classes = _classes;
    if (_classesLoading && classes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
          ),
        ),
      );
    }
    if (classes.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 60),
          const Text(
            "We couldn't load the class times.",
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: _kInkSoft),
          ),
          TextButton(
            onPressed: _loadClasses,
            child: const Text(
              'Try again',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: _kAccent,
              ),
            ),
          ),
        ],
      );
    }
    _timesFromSlots();
    return _weekView && _pickedTimes.isNotEmpty ? _weekScreen() : _timeScreen();
  }

  // ── Step 6a: Tell us when you're free ─────────────────────────────
  Widget _timeScreen() {
    final options = _timeOptions;

    Widget slot(String tag, String? time, {String empty = 'Pick'}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: time == null ? const Color(0xFFF6F8F5) : _kAccentBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '$tag  ',
                style: const TextStyle(fontSize: 10.5, color: _kInkSoft),
              ),
              TextSpan(
                text: time ?? empty,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: time == null ? _kInkSoft : _kInk,
                ),
              ),
            ]),
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
        );

    final groups = <Widget>[];
    for (final entry in _parts.entries) {
      final inPart = options.where((o) => o['part'] == entry.key).toList();
      if (inPart.isEmpty) continue;
      final meta = entry.value;
      final range = inPart.length == 1
          ? '${inPart.first['time']}'
          : '${inPart.first['time']} to ${inPart.last['time']}';
      groups.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${meta[0]}  ${meta[1]}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: _kInk),
                ),
                TextSpan(
                  text: '   $range',
                  style: const TextStyle(fontSize: 11.5, color: _kInkSoft),
                ),
                if (entry.key == _signupTimeBlock)
                  const TextSpan(
                    text: '   ·  Suggested for you',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _kAccent),
                  ),
              ]),
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, box) {
              final w = (box.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 12,
                children: inPart.map((o) {
                  final t = o['time'] as String;
                  final idx = _pickedTimes.indexOf(t);
                  final on = idx >= 0;
                  return GestureDetector(
                    onTap: () => setState(() => _toggleTime(t)),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: w,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: on ? _kDeep : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: on ? _kDeep : _kBorder, width: 1.5),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: on ? Colors.white : _kInk,
                            ),
                          ),
                        ),
                        if (on)
                          Positioned(
                            top: -8,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _kDeep),
                              ),
                              child: Text(
                                idx == 0 ? '1st' : '2nd',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: _kDeep,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ));
    }

    final days = _workoutDays;
    Widget getRow(IconData icon, String bold, String rest) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: _kDeep),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: bold,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: rest, style: const TextStyle(color: _kInkSoft)),
                  ]),
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 12.5, color: _kInk),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        _stepBadge('Your time'),
        const SizedBox(height: 12),
        _twoToneTitle('Tell us when ', "you're free"),
        _subLine("Pick 1 or 2 times and we'll remind you before class."),
        if (widget.setupMode) ...[
          const SizedBox(height: 6),
          const Text(
            'Fewer, calmer notifications. Prefer a reminder for every class? '
            'Switch to "All classes" anytime in Settings › Notifications.',
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 11.5, height: 1.4, color: _kInkSoft),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Icon(
                _pickedTimes.isEmpty
                    ? Icons.radio_button_unchecked_rounded
                    : Icons.check_circle_rounded,
                size: 18,
                color: _pickedTimes.isEmpty ? _kBorder : _kAccent,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Your times',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ),
              slot('1st', _pickedTimes.isNotEmpty ? _pickedTimes[0] : null),
              const SizedBox(width: 6),
              slot('2nd', _pickedTimes.length > 1 ? _pickedTimes[1] : null, empty: 'optional'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...groups,
        if (_pickedTimes.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: _kAccentBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Here's what you'll get",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
                getRow(
                  Icons.calendar_month_rounded,
                  days.length == 1 && days.first == null
                      ? 'A class every day'
                      : '${days.length} workout days',
                  days.length == 1 && days.first == null
                      ? ''
                      : '  ${_rangeLabel(days)}',
                ),
                getRow(
                  Icons.schedule_rounded,
                  _pickedTimes.length == 2 ? '2 times' : '1 time',
                  ' to choose from each day',
                ),
                getRow(
                  Icons.notifications_active_outlined,
                  'A reminder',
                  ' before class and when it goes live',
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Step 6b: Your week is ready ───────────────────────────────────
  Widget _weekScreen() {
    final window = _classData?['joinWindowMinutes'] ?? _home.joinWindowMinutes.value;
    final win = window is int ? window : 10;
    final days = _workoutDays;
    final everyDay = days.length == 1 && days.first == null;
    final times = _pickedTimes.join(' or ');
    final favDays = days
        .where((d) => _classesOn(d).any((c) =>
            _pickedTimes.contains('${c['startLocal']}') && _isFavourite(c)))
        .length;
    final first = _firstClass();
    final tz = _classData?['showsPakistanTime'] == true
        ? 'your time zone'
        : 'Pakistan time';

    Widget pill(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        );

    Widget rule(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFFB7791F)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  ),
                ),
              ),
            ],
          ),
        );

    // Timetable grid: columns are days, rows are class times.
    final gridDays = _weekDays.isEmpty ? <String?>[null] : _weekDays.cast<String?>();
    final tmName = _tomorrowName;
    const timeCol = 58.0;
    final header = Row(
      children: [
        const SizedBox(width: timeCol),
        ...gridDays.map((d) {
          final tm = d == tmName;
          return Expanded(
            child: Text(
              d == null ? 'Daily' : (tm ? 'Tmrw' : _short(d)),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                fontWeight: tm ? FontWeight.w800 : FontWeight.w600,
                color: tm ? _kDeep : _kInkSoft,
              ),
            ),
          );
        }),
      ],
    );
    bool anyFav = false;
    final rows = _timeOptions.map((o) {
      final t = o['time'] as String;
      final mine = _pickedTimes.contains(t);
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: mine ? _kAccentBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: mine ? _kAccent : Colors.transparent),
        ),
        child: Row(
          children: [
            SizedBox(
              width: timeCol,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  t,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: mine ? FontWeight.w800 : FontWeight.w500,
                    color: mine ? _kDeep : _kInkSoft,
                  ),
                ),
              ),
            ),
            ...gridDays.map((d) {
              final here = _classesOn(d)
                  .where((c) => '${c['startLocal']}' == t)
                  .toList();
              if (here.isEmpty) {
                return const Expanded(
                  child: SizedBox(
                    height: 26,
                    child: Center(
                      child: Text('·',
                          style: TextStyle(color: _kBorder, fontSize: 16)),
                    ),
                  ),
                );
              }
              final c = here.first;
              final st = _typeStyle('${c['type'] ?? ''}');
              final fav = _isFavourite(c);
              if (fav) anyFav = true;
              return Expanded(
                child: Container(
                  height: 26,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: st[1] as Color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      fav ? '${st[0]} ★' : '${st[0]}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: st[2] as Color,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        _stepBadge('Your week'),
        const SizedBox(height: 12),
        _twoToneTitle('Your week ', 'is ready'),
        _subLine("Your times on the trainers' timetable."),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kClassA, _kClassB],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR PLAN · ${_rangeLabel(days).toUpperCase()}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFFA8F0C0),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                everyDay
                    ? 'A class every day at $times'
                    : '${days.length} workout days at $times',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (favDays > 0)
                    pill(everyDay
                        ? '★ A workout you love'
                        : '★ $favDays of ${days.length} days have a favourite'),
                  if (first != null)
                    pill('First: ${first['when']}, '
                        '${(first['c'] as Map)['startLocal']} · '
                        '${_typeStyle('${(first['c'] as Map)['type'] ?? ''}')[0]}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFBE3B5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BEFORE YOUR FIRST CLASS',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Color(0xFFB7791F),
                ),
              ),
              rule(Icons.timer_outlined, 'Join in the first $win minutes'),
              rule(Icons.female_rounded, 'Women only'),
              rule(Icons.videocam_off_outlined, 'Live only, no recordings'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 12),
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(
                      text: "Trainers' weekly timetable\n",
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _kInk),
                    ),
                    TextSpan(
                      text: 'Live · $tz',
                      style: const TextStyle(fontSize: 11, color: _kInkSoft),
                    ),
                  ]),
                  style: const TextStyle(fontFamily: 'Poppins', height: 1.4),
                ),
              ),
              header,
              ...rows,
              if (anyFav)
                const Padding(
                  padding: EdgeInsets.only(top: 10, left: 6),
                  child: Text(
                    '★ a workout you love',
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 11, color: _kInkSoft),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Generating overlay ─────────────────────────────────────────────
  Widget _generatingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.97),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _kAccent.withOpacity(0.35), blurRadius: 30),
                ],
              ),
              child: const Text('🥗', style: TextStyle(fontSize: 44)),
            ),
            const SizedBox(height: 26),
            const Text(
              'Building your plan',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _busyMessages[_busyIdx],
                key: ValueKey(_busyIdx),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  color: _kInkSoft,
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                minHeight: 5,
                backgroundColor: _kBorder,
                valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Building blocks ──────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final String title;
  final String sub;
  const _StepHeader({required this.title, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: _kInk,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              height: 1.5,
              color: _kInkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kInk,
          ),
        ),
      );
}

class _FeatureTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  const _FeatureTile({required this.emoji, required this.title, required this.body});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kAccentBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    height: 1.45,
                    color: _kInkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final _Opt opt;
  final bool selected;
  final VoidCallback onTap;
  const _BigCard({required this.opt, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: BoxDecoration(
          color: selected ? _kAccentBg : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? _kAccent : _kBorder, width: selected ? 2 : 1),
          boxShadow: selected
              ? [BoxShadow(color: _kAccent.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 6))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(opt.emoji, style: const TextStyle(fontSize: 30)),
                const Spacer(),
                if (selected)
                  const CircleAvatar(
                    radius: 10,
                    backgroundColor: _kAccent,
                    child: Icon(Icons.check_rounded, size: 13, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              opt.label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
            if (opt.sub != null) ...[
              const SizedBox(height: 2),
              Text(
                opt.sub!,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  height: 1.35,
                  color: _kInkSoft,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChipGrid extends StatelessWidget {
  final List<_Opt> opts;
  final bool Function(String) isOn;
  final void Function(String) onTap;
  const _ChipGrid({required this.opts, required this.isOn, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opts.map((o) {
        final on = isOn(o.value);
        return GestureDetector(
          onTap: () => onTap(o.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: on ? _kInk : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: on ? _kInk : _kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(o.emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(
                  o.label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: on ? Colors.white : _kInk,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SelectRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String sub;
  const _SelectRow({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.sub,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? _kAccentBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _kAccent : _kBorder, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            SizedBox(width: 40, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: _kInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? _kAccent : _kBorder,
            ),
          ],
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onChanged;
  const _Input({required this.controller, required this.hint, this.onChanged});
  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _kBorder),
    );
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: 3,
      onChanged: (_) => onChanged?.call(),
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: _kInk),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF9AB09A)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: _kAccent, width: 1.5),
        ),
      ),
    );
  }
}

/// Text field plus a one-tap "None" chip, so she never has to type
/// "none" herself on a required question.
class _InputWithNone extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String noneLabel;
  final VoidCallback onChanged;
  /// Quick picks (e.g. "Peanuts"). Tapping adds/removes it in the text
  /// box as a comma list; she can still type anything else.
  final List<String> options;
  const _InputWithNone({
    required this.controller,
    required this.hint,
    required this.noneLabel,
    required this.onChanged,
    this.options = const [],
  });

  @override
  State<_InputWithNone> createState() => _InputWithNoneState();
}

/// Oct 2026 (shorter page): chips, "None" and "+ Other" in one wrap; the
/// text box only opens from "+ Other" (or when she already typed her own).
class _InputWithNoneState extends State<_InputWithNone> {
  bool _other = false;

  TextEditingController get controller => widget.controller;

  List<String> get _items => controller.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && e.toLowerCase() != 'none')
      .toList();

  bool _has(String o) => _items.any((e) => e.toLowerCase() == o.toLowerCase());

  bool get _hasCustom => _items.any(
      (e) => !widget.options.any((o) => o.toLowerCase() == e.toLowerCase()));

  void _toggle(String o) {
    final items = _items;
    final i = items.indexWhere((e) => e.toLowerCase() == o.toLowerCase());
    if (i >= 0) {
      items.removeAt(i);
    } else {
      items.add(o);
    }
    controller.text = items.join(', ');
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    widget.onChanged();
  }

  Widget _chip(String text, {required bool on, required VoidCallback onTap, bool dark = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: on ? (dark ? _kInk : _kAccentBg) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: on ? (dark ? _kInk : _kAccent) : _kBorder,
            width: on && !dark ? 1.5 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: on && dark ? Colors.white : _kInk,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNone = controller.text.trim().toLowerCase() == 'none';
    final showBox = !isNone && (_other || _hasCustom || widget.options.isEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!isNone)
              for (final o in widget.options)
                _chip(_has(o) ? '✓  $o' : o, on: _has(o), onTap: () => _toggle(o)),
            _chip(
              '✓  ${widget.noneLabel}',
              on: isNone,
              dark: true,
              onTap: () {
                controller.text = isNone ? '' : 'None';
                setState(() => _other = false);
                widget.onChanged();
              },
            ),
            if (!isNone && widget.options.isNotEmpty && !showBox)
              _chip('+ Other', on: false, onTap: () => setState(() => _other = true)),
          ],
        ),
        if (showBox) ...[
          const SizedBox(height: 8),
          _Input(controller: controller, hint: widget.hint, onChanged: widget.onChanged),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final List<String> lines;
  final VoidCallback onEdit;
  const _ReviewCard({required this.title, required this.lines, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kInkSoft,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                ...lines.where((l) => l.trim().isNotEmpty).map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        l,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _kInk,
                        ),
                      ),
                    )),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: const Text(
              'Edit',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _kAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Class picker widgets ─────────────────────────────────────────────

(String, Color) _classStyle(String type) {
  final t = type.toLowerCase();
  if (t.contains('yoga') || t.contains('stretch')) return ('🧘‍♀️', const Color(0xFF9B7FD1));
  if (t.contains('zumba') || t.contains('dance')) return ('💃', const Color(0xFFE36FA8));
  if (t.contains('high') || t.contains('hiit') || t.contains('cardio')) {
    return ('🔥', const Color(0xFFF08A3C));
  }
  if (t.contains('low') || t.contains('pcos') || t.contains('gentle')) {
    return ('🌸', const Color(0xFF4FAE84));
  }
  if (t.contains('strength') || t.contains('weight')) return ('💪', const Color(0xFFE8735A));
  return ('🏋️‍♀️', _kAccent);
}

String _imageUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  if (raw.startsWith('http')) return raw;
  return '${Constants.baseUrl}/${raw.replaceFirst(RegExp(r'^/'), '')}';
}

class TrialClassCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool selected;
  final bool showPakistanTime;
  final VoidCallback onTap;
  const TrialClassCard({
    required this.data,
    required this.selected,
    required this.showPakistanTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = '${data['type'] ?? 'Live class'}';
    final (emoji, color) = _classStyle(type);
    final trainer = data['trainer'] is Map ? data['trainer'] as Map : const {};
    final trainerName = '${trainer['name'] ?? ''}'.trim();
    final img = _imageUrl(trainer['image']?.toString());
    final joined = data['joinedLastWeek'] is int ? data['joinedLastWeek'] as int : 0;
    final recommended = data['recommended'] == true;
    final shift = data['dayShift'] is int ? data['dayShift'] as int : 0;
    final time = '${data['startLocal'] ?? ''}';
    final parts = time.split(' ');

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? _kAccent : _kBorder, width: selected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: selected ? _kAccent.withOpacity(0.28) : _kInk.withOpacity(0.06),
                blurRadius: selected ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recommended)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: const BoxDecoration(
                    color: _kInk,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '⭐  Recommended for you',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Big time
                    SizedBox(
                      width: 74,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parts.isNotEmpty ? parts.first : time,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _kInk,
                              height: 1.0,
                            ),
                          ),
                          if (parts.length > 1)
                            Text(
                              parts[1],
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kInkSoft,
                              ),
                            ),
                          if (shift != 0)
                            Text(
                              shift < 0 ? 'day before' : 'next day',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: _kInkSoft,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Class + trainer
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$emoji  $type',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ClipOval(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: img.isEmpty
                                      ? _initial(trainerName)
                                      : Image.network(
                                          img,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _initial(trainerName),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  trainerName.isEmpty ? 'Fit Her trainer' : 'with $trainerName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _kInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (joined > 0 || showPakistanTime) ...[
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (joined > 0) '👭 $joined women joined last week',
                                if (showPakistanTime) '${data['startPkt']} Pakistan',
                              ].join('  ·  '),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: _kInkSoft,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: selected ? _kAccent : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? _kAccent : _kBorder, width: 2),
                      ),
                      child: Icon(
                        selected ? Icons.notifications_active_rounded : Icons.add_rounded,
                        size: 17,
                        color: selected ? Colors.white : _kInkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _initial(String name) => Container(
        color: _kAccentBg,
        alignment: Alignment.center,
        child: Text(
          name.isEmpty ? '💚' : name[0].toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _kInk,
          ),
        ),
      );
}

/// "How your trial classes work": the class rules, said positively.
class TrialClassRulesCard extends StatelessWidget {
  final int joinWindowMinutes;
  const TrialClassRulesCard({required this.joinWindowMinutes});

  @override
  Widget build(BuildContext context) {
    Widget row(String emoji, String bold, String rest) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: bold, style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: rest),
                  ]),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    height: 1.45,
                    color: _kInk,
                  ),
                ),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💚  How your trial classes work',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 12),
          row('⏰', 'Join in the first $joinWindowMinutes minutes. ',
              'Classes start with a warm-up, so joining on time keeps you safe and gets you the full workout.'),
          row('📷', 'Camera is your choice. ',
              "Turn it on if you'd like your trainer to check your form, or keep it off and just follow along."),
          row('👩', 'Women trainers, women-only classes.', ''),
          row('📵', 'Classes are never recorded.', ''),
          row('✨', 'Join any class you like. ', 'Your picks just decide your reminders.'),
        ],
      ),
    );
  }
}

// ── Trust & privacy ──────────────────────────────────────────────────
// Final copy agreed for the trial (see docs/FitHer_Free_Trial_Flow_Final.md
// section 6). Every promise here must stay exactly true.

/// The four safe-space promises (same words everywhere they show).
List<Widget> safeSpacePromises() => [
      _safePromise('👩', 'Women only. ',
          'All trainers are women, and every class is women-only.'),
      _safePromise('🔒', 'Your health info stays private. ',
          "We use it only to build your plan and keep you safe. It's never shared, sold, or used for anything else."),
      _safePromise('📵', 'Classes are never recorded. ',
          'What happens in class stays in class.'),
      _safePromise('📷', 'Your camera, your choice. ',
          'Turn it on for form tips, or keep it off and follow along.'),
    ];

Widget _safePromise(String emoji, String bold, String rest) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kAccentBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: bold, style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: rest),
              ]),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                height: 1.45,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );

/// "One last step" (Oct 2026): opens when she taps "Start my free trial"
/// without both ticks. Shows the safe-space promises in full (she reads
/// what we promise) and ONE clear choice: "Agree & start". Never closes
/// by itself. Returns true when she agreed.
Future<bool> showAgreeAndStartSheet({bool setupMode = false}) async {
  final agreed = await Get.bottomSheet<bool>(
    Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDADFD5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Text(
                'One last step 💚',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'This is your safe space. Here is what we promise you:',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _kInkSoft, height: 1.4),
              ),
              const SizedBox(height: 14),
              ...safeSpacePromises(),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kAccent.withOpacity(0.35)),
                ),
                child: const Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'By tapping below you confirm '),
                    TextSpan(text: 'your answers are correct', style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ' and you agree that Fit Her uses your health info '),
                    TextSpan(
                      text: 'only to create your plan and keep your classes safe.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ]),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, height: 1.45, color: _kInk),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Get.back<bool>(result: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    setupMode ? 'Agree & save my answers' : 'Agree & start my free trial',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Get.back<bool>(result: false),
                child: const Text(
                  'Go back and check my answers',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _kInkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    isScrollControlled: true,
  );
  return agreed == true;
}

/// "Your safe space": the four promises. Opened from the welcome trust
/// strip and the "Read more" link on the consent tick.
Future<void> showSafeSpaceSheet() {
  Widget promise(String emoji, String bold, String rest) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kAccentBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 19)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: bold, style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: rest),
                ]),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  height: 1.5,
                  color: _kInk,
                ),
              ),
            ),
          ],
        ),
      );
  return Get.bottomSheet<void>(
    Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your safe space 💚',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 16),
            promise('👩', 'Women only. ',
                'All trainers are women, and every class is women-only.'),
            promise('🔒', 'Your health info stays private. ',
                "We use it only to build your plan and keep you safe. It's never shared, sold, or used for anything else."),
            promise('📵', 'Classes are never recorded. ',
                'What happens in class stays in class.'),
            promise('📷', 'Your camera, your choice. ',
                'Turn it on for form tips, or keep it off and follow along.'),
            TextButton(
              onPressed: () => Get.back(),
              child: const Text(
                'Got it',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

/// Welcome screen: 👩 Women only · 🔒 Private & safe · 📵 Never recorded
class _TrustStrip extends StatelessWidget {
  final VoidCallback onTap;
  const _TrustStrip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget chip(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kBorder),
          ),
          child: Text(
            t,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _kInk,
            ),
          ),
        );
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              chip('👩 Women only'),
              chip('🔒 Private & safe'),
              chip('📵 Never recorded'),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap to see how we keep you safe',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: _kInkSoft,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Body & cycle step: reassurance BEFORE the health questions.
class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kAccentBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAccent.withOpacity(0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔒', style: TextStyle(fontSize: 18)),
          SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: 'Your health info stays between you and Fit Her\n',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: "We use it only to build your plan and keep you safe. It's never shared, sold, or used for anything else.",
                ),
              ]),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                height: 1.5,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "why we ask" line under a sensitive question.
class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 0, bottom: 10),
        child: Text(
          '💡 $text',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _kInkSoft),
        ),
      );
}

/// Tick row used for the two review confirmations.
class _ConsentTick extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  final Widget child;
  const _ConsentTick({required this.checked, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: checked ? _kAccentBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: checked ? _kAccent : _kBorder, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: checked ? _kAccent : Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: checked ? _kAccent : _kBorder, width: 2),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Welcome preview ("Here's what your first day could look like")
// ══════════════════════════════════════════════════════════════════════

const _kDeep = Color(0xFF3F9B35);
const _kClassA = Color(0xFF1F5A2E);
const _kClassB = Color(0xFF2E6B38);

/// Phase copy for the tag and the tip inside the class card.
class _PhaseCopy {
  final String tag;
  final String tipTitle;
  final String tipBody;
  const _PhaseCopy(this.tag, this.tipTitle, this.tipBody);

  static _PhaseCopy of(String? phase) {
    switch (phase) {
      case 'menstrual':
        return const _PhaseCopy('Period week', 'Go gentle this week',
            'Light movement helps with cramps. Go at your own pace.');
      case 'follicular':
        return const _PhaseCopy('Follicular week', 'Your energy is rising',
            'A great week to try something new.');
      case 'ovulatory':
        return const _PhaseCopy('Ovulation week', 'Your energy peaks this week',
            'A great time for your first strong class.');
      case 'luteal':
        return const _PhaseCopy('Luteal week', 'Steady does it this week',
            'A medium class suits your body right now.');
      default:
        return const _PhaseCopy('', 'Start at your own pace',
            'Camera optional, no pressure. Just show up.');
    }
  }
}

class _WelcomeDayCard extends StatelessWidget {
  final int days;
  final String? phase;
  const _WelcomeDayCard({required this.days, required this.phase});

  @override
  Widget build(BuildContext context) {
    final tag = _PhaseCopy.of(phase).tag;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 46,
            decoration: BoxDecoration(
              color: _kAccentBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('DAY',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: _kInkSoft,
                        letterSpacing: 0.5)),
                Text('1',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: _kDeep)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tomorrow · Day 1 of $days',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(days.clamp(1, 14), (i) {
                    return Container(
                      width: days > 5 ? 12 : 22,
                      height: 4,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i == 0 ? _kDeep : _kBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          if (tag.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE4EC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFC2185B),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomeClassCard extends StatelessWidget {
  final Map<String, dynamic>? cls;
  final bool loading;
  final String? phase;
  final VoidCallback? onTap;
  final int womenLastWeek;
  const _WelcomeClassCard(
      {required this.cls,
      required this.loading,
      required this.phase,
      this.womenLastWeek = 0,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = cls;
    // If she picked a hard class herself during her period / luteal week,
    // soften the tip instead of contradicting her choice.
    final hard = c != null &&
        RegExp(r'high|hiit|intens|strength|cardio|advanced|tone',
                caseSensitive: false)
            .hasMatch('${c['type'] ?? ''} ${c['level'] ?? ''}');
    final tip = hard && (phase == 'menstrual' || phase == 'luteal')
        ? const _PhaseCopy('', 'Listen to your body',
            'Go at your own pace and take breaks whenever you need.')
        : _PhaseCopy.of(phase);
    final title = c == null
        ? 'Live classes every day'
        : ((c['type'] as String?)?.trim().isNotEmpty ?? false)
            ? c['type'] as String
            : 'Live class';
    // First name only ("Hira"), the last name field is often a
    // placeholder like "Trainer".
    final fullName = c == null
        ? null
        : ((c['trainer'] is Map) ? (c['trainer']['name'] as String?) : null);
    final trainer = (fullName ?? '').trim().split(RegExp(r'\s+')).first;
    final minutes = c == null
        ? null
        : _minutesBetween(c['startLocal'] as String?, c['endLocal'] as String?);
    final realInitials = c == null || c['recentInitials'] is! List
        ? const <String>[]
        : (c['recentInitials'] as List).map((e) => '$e').toList();
    // Avatar row always shows. Real initials when we have them, otherwise
    // decorative letters.
    final initials = realInitials.isNotEmpty ? realInitials : const ['S', 'M', 'H'];
    // Real numbers first: this class, then all classes, then a plain line
    // with no number (never a made up count).
    final joined = c == null ? 0 : ((c['joinedLastWeek'] ?? 0) as num).toInt();
    final String socialLine = joined > 0
        ? '$joined ${joined == 1 ? 'woman' : 'women'} joined last week'
        : womenLastWeek > 0
            ? '$womenLastWeek women trained with us last week'
            : 'Women only · join from home';
    final time = c == null ? null : c['startLocal'] as String?;
    final sub = [
      if (trainer.isNotEmpty) 'With Coach $trainer',
      if (minutes != null) '$minutes min',
      'camera optional',
    ].join(' · ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kClassA, _kClassB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _kInk.withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                          radius: 3.5, backgroundColor: Color(0xFFE53935)),
                      const SizedBox(width: 6),
                      Text(
                        time == null
                            ? 'LIVE · EVERY DAY'
                            : 'LIVE · TOMORROW $time',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC62828),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  loading ? 'Finding your class…' : title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 21,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c == null ? 'Real trainers, from home · camera optional' : sub,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                if (!loading) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (int a = 0; a < 3; a++)
                        Align(
                          widthFactor: 0.72,
                          child: Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const [
                                Color(0xFFF3D9C9),
                                Color(0xFFCFE6C6),
                                Color(0xFFF6D3DC),
                              ][a],
                              shape: BoxShape.circle,
                              border: Border.all(color: _kClassA, width: 2),
                            ),
                            child: Text(
                              a < initials.length ? initials[a] : '',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: _kInk,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      Text(
                        socialLine,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded,
                          size: 18, color: Color(0xFFFAC775)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tip.tipTitle,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                            Text(tip.tipBody,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.8),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

/// "07:00 PM" / "07:45 PM" -> 45. Null if either is missing or odd.
int? _minutesBetween(String? a, String? b) {
  int? parse(String? t) {
    if (t == null) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$').firstMatch(t.trim());
    if (m == null) return null;
    var h = int.parse(m.group(1)!) % 12;
    if (m.group(3)!.toUpperCase() == 'PM') h += 12;
    return h * 60 + int.parse(m.group(2)!);
  }
  final s = parse(a), e = parse(b);
  if (s == null || e == null) return null;
  var d = e - s;
  if (d <= 0) d += 24 * 60;
  return d > 0 && d <= 240 ? d : null;
}

class _WelcomeSection extends StatelessWidget {
  final String title;
  final String trailing;
  const _WelcomeSection({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: _kInk,
              )),
        ),
        Text(trailing,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              color: _kInkSoft,
            )),
      ],
    );
  }
}

class _WelcomeMeal {
  final IconData icon;
  final String time;
  final String name;
  final String why;
  final String tag;
  const _WelcomeMeal(this.icon, this.time, this.name, this.why, this.tag);
}

/// Sample meals for the preview, picked from her signup answers. No AI
/// call here: the real plan is generated after the questions.
class _WelcomeMeals {
  static List<_WelcomeMeal> forUser({
    String? trialGoal,
    String? signupGoal,
    String? conditions,
  }) {
    final g = '${trialGoal ?? ''} ${signupGoal ?? ''}'.toLowerCase();
    final pcos = (conditions ?? '').toLowerCase().contains('pcos') ||
        g.contains('pcos');
    const bf = Icons.free_breakfast_outlined;
    const ln = Icons.ramen_dining_outlined;
    if (pcos) {
      return const [
        _WelcomeMeal(bf, '8:00 AM', 'Egg bhurji & 1 roti',
            'Protein and slow carbs, kind to your hormones.', '320 kcal'),
        _WelcomeMeal(ln, '1:30 PM', 'Daal chawal with salad',
            'Low GI lunch, kind to PCOS.', 'Low GI'),
      ];
    }
    if (g.contains('gain')) {
      return const [
        _WelcomeMeal(bf, '8:00 AM', 'Anda paratha & lassi',
            'Healthy calories to help you gain steadily.', '520 kcal'),
        _WelcomeMeal(ln, '1:30 PM', 'Chicken pulao & raita',
            'Protein to build strength.', 'High protein'),
      ];
    }
    if (g.contains('lose') || g.contains('weight_loss')) {
      return const [
        _WelcomeMeal(bf, '8:00 AM', 'Besan chilla & chai',
            'Protein to start your day, fits your weight loss goal.', '300 kcal'),
        _WelcomeMeal(ln, '1:30 PM', 'Daal chawal with salad',
            'Filling and light, keeps you full till evening.', 'Low GI'),
      ];
    }
    if (g.contains('strength') || g.contains('fitness')) {
      return const [
        _WelcomeMeal(bf, '8:00 AM', 'Anda paratha & chai',
            'Protein to fuel your workouts.', '380 kcal'),
        _WelcomeMeal(ln, '1:30 PM', 'Chicken salan & 2 roti',
            'Protein for strong muscles.', 'High protein'),
      ];
    }
    return const [
      _WelcomeMeal(bf, '8:00 AM', 'Oats with banana & dates',
          'Slow energy to keep you calm and steady.', '330 kcal'),
      _WelcomeMeal(ln, '1:30 PM', 'Daal chawal with salad',
          'Light and comforting.', 'Low GI'),
    ];
  }
}

class _WelcomeMealCard extends StatelessWidget {
  final _WelcomeMeal meal;
  const _WelcomeMealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kAccentBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meal.icon, size: 17, color: _kDeep),
              ),
              const Spacer(),
              Text(meal.time,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Text(meal.name,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: _kInk,
              )),
          const SizedBox(height: 4),
          Text(meal.why,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                height: 1.4,
                color: _kInkSoft,
              )),
          const Spacer(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(meal.tag,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _kInk,
                )),
          ),
        ],
      ),
    );
  }
}

class _WelcomeComingUp extends StatelessWidget {
  final int days;
  const _WelcomeComingUp({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days <= 1) return const SizedBox.shrink();
    String label(int d) {
      if (d == days) return 'Your progress summary';
      if (d == 2) return '2nd class + new meals';
      return 'Classes + meals';
    }

    Widget tile(int d) => Container(
          width: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: d == days ? _kDeep : _kAccentBg,
                ),
                child: Text('$d',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: d == days ? Colors.white : _kInk,
                    )),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Day $d',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                        )),
                    Text(label(d),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          height: 1.3,
                          color: _kInkSoft,
                        )),
                  ],
                ),
              ),
            ],
          ),
        );

    final tiles = [for (int d = 2; d <= days; d++) tile(d)];
    if (days <= 3) {
      return Row(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: tiles[i]),
          ],
        ],
      );
    }
    // Longer trials scroll sideways. Tall enough for a 2-line label
    // (it overflowed by 7 px at 58).
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => tiles[i],
      ),
    );
  }
}

class _WelcomeTrustLine extends StatelessWidget {
  final int days;
  const _WelcomeTrustLine({required this.days});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined,
                  size: 14, color: _kDeep),
              const SizedBox(width: 6),
              Text(
                '$days days free · no card needed',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: _kInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => showSafeSpaceSheet(),
            child: const Text(
              'How we keep you safe',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kDeep,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════
// Step 5: "What do you love to do?"
// ══════════════════════════════════════════════════════════════════════

class _WorkoutLove {
  final String value;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String sub;
  final List<String> tags;
  final Color bg;
  final Color tagText;
  const _WorkoutLove(this.value, this.icon, this.iconColor, this.title,
      this.sub, this.tags, this.bg, this.tagText);

  // Values are saved in workoutSection.favoriteWorkouts and read by the
  // backend class recommender (helper/trialClasses.js).
  static const all = <_WorkoutLove>[
    _WorkoutLove('high_intensity', Icons.local_fire_department_outlined,
        Color(0xFFE0612B), 'High Intensity', 'Short, sweaty bursts that burn fat fast',
        ['Fat burn', 'High energy'], Color(0xFFFDEEE3), Color(0xFF9A4A1F)),
    _WorkoutLove('strength', Icons.fitness_center_rounded, Color(0xFFB8860B),
        'Strength', 'Build muscle and tone your body', ['Toning', 'Muscle'],
        Color(0xFFFBF3DF), Color(0xFF7A5B12)),
    _WorkoutLove('zumba', Icons.music_note_rounded, Color(0xFFC2185B), 'Zumba',
        'Dance cardio that feels like a party', ['Cardio', 'Fun'],
        Color(0xFFFCE8EE), Color(0xFF9C1C4B)),
    _WorkoutLove('yoga', Icons.spa_outlined, Color(0xFF6A4FB3), 'Yoga',
        'Flexibility, calm and stress relief', ['Flexibility', 'Calm'],
        Color(0xFFEFEAFB), Color(0xFF55409A)),
    _WorkoutLove('low_intensity', Icons.eco_outlined, Color(0xFF2E7DAF),
        'Low Intensity', 'Gentle moves, easy on your joints', ['Gentle', 'Joint friendly'],
        Color(0xFFE6F2FA), Color(0xFF235F86)),
    _WorkoutLove('mix', Icons.shuffle_rounded, _kDeep, 'A bit of everything',
        'Something new every day', ['Variety'], Color(0xFFF3FAF0), _kDeep),
  ];

  static String labelOf(String v) =>
      all.firstWhere((o) => o.value == v, orElse: () => all.last).title;

  /// Stars the styles that suit her goal, life stage and health.
  static Set<String> recommendedFor({
    String? goal,
    String? cycleStatus,
    String? fitnessLevel,
    String? conditions,
  }) {
    final g = (goal ?? '').toLowerCase();
    final c = (conditions ?? '').toLowerCase();
    final st = (cycleStatus ?? '').toLowerCase();
    if (st == 'pregnant' || st == 'postpartum' || g.contains('postpartum') ||
        g.contains('pregnancy')) {
      return {'low_intensity', 'yoga'};
    }
    if (g.contains('pcos') || c.contains('pcos') || st == 'pcos') {
      return {'strength', 'yoga'};
    }
    if (st == 'menopause' || c.contains('arthritis')) {
      return {'strength', 'low_intensity'};
    }
    if (g.contains('weight_loss')) {
      return fitnessLevel == 'beginner'
          ? {'zumba', 'low_intensity'}
          : {'high_intensity', 'strength'};
    }
    if (g.contains('weight_gain')) return {'strength'};
    if (g.contains('maintain')) return {'strength', 'zumba'};
    if (g.contains('general_wellness')) return {'yoga', 'zumba'};
    return const {};
  }
}

class _WorkoutLoveTile extends StatelessWidget {
  final _WorkoutLove option;
  final bool selected;
  final bool starred;
  final VoidCallback onTap;
  const _WorkoutLoveTile({
    required this.option,
    required this.selected,
    required this.starred,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final o = option;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: o.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? _kAccent
                : (o.value == 'mix' ? _kBorder : Colors.transparent),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(o.icon, size: 20, color: o.iconColor),
                ),
                const Spacer(),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? _kAccent : Colors.white,
                    border: Border.all(
                        color: selected ? _kAccent : _kBorder, width: 1.5),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(
                  child: Text(
                    o.title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                ),
                if (starred) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFE0A21B)),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              o.sub,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                height: 1.35,
                color: _kInkSoft,
              ),
            ),
            const SizedBox(height: 8),
            const Spacer(),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: o.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(t,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: o.tagText,
                            )),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
