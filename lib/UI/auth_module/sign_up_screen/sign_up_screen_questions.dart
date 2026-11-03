import '../../../helper/analytics_helper.dart';
import '../../../helper/signup_progress.dart';
import 'package:fitness_zone_2/data/api_provider/api_provider.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/controllers/consultation_controller/consultation_controller.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/controllers/paid_home_controller/paid_home_controller.dart';
import 'package:fitness_zone_2/data/Repos/cycle_repo/cycle_data_repository.dart';
import 'package:fitness_zone_2/values/constants.dart';
import 'package:fitness_zone_2/widgets/onboarding_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'life_stage_gate.dart';
import '../pcos/generic_screening_intro.dart';
import '../../../widgets/trial_welcome/trial_welcome_sheet.dart';
import '../pcos/screening_data.dart';
import '../pcos/pcos_config.dart';
import '../pcos/thyroid_config.dart';
import '../pcos/menopause_config.dart';
import '../pcos/postpartum_config.dart';
import '../pcos/endometriosis_config.dart';
import 'life_stage_screen.dart';
import '../../../widgets/toasts.dart';

class _GoalOption {
  final String emoji;
  final String title;
  final String subtitle;

  const _GoalOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

class _Condition {
  final String emoji;
  final String label;

  const _Condition(this.emoji, this.label);
}

class _TimeBlock {
  final String emoji;
  final String label;
  final String subtitle;
  final String value;

  const _TimeBlock({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.value,
  });
}

/// Unified 5-Step Onboarding Questionnaire using a single PageView:
/// 1 / 5: Goal selection
/// 2 / 5: Body Metrics (Age, Weight, Height + Live BMI)
/// 3 / 5: Menstrual Cycle tracking
/// 4 / 5: Health Conditions
/// 5 / 5: Workout Time Preference
class SignUpScreenQuestions extends StatefulWidget {
  final String? selectedGoal;
  final int? initialPage;

  /// "About you" on the profile card (Oct 2026): only these sign-up pages
  /// (0 goal, 1 body, 2 life stage, 3 cycle), saved answers filled in.
  /// Finishing saves and goes back with true.
  final List<int>? gapPages;

  /// Gaps mode: her target weight is still empty (from the server).
  final bool askTarget;

  /// Gaps mode: false when the health form is compulsory (after 3
  /// "Not now"s), so the first page has no way out.
  final bool canLeave;

  /// Gaps mode: "Part 1 of 2 · About you" under the step bars.
  final String? partLabel;

  const SignUpScreenQuestions({
    Key? key,
    this.selectedGoal,
    this.initialPage,
    this.gapPages,
    this.askTarget = false,
    this.canLeave = true,
    this.partLabel,
  }) : super(key: key);

  @override
  State<SignUpScreenQuestions> createState() => _SignUpScreenQuestionsState();
}

class _SignUpScreenQuestionsState extends State<SignUpScreenQuestions> {
  static const int _totalSteps = 6;

  int _currentPage = 0;
  bool _isSubmitting = false;
  bool _isGoingForward = true;
  bool _pageVisible = true; // controls two-phase fade: out → swap → in
  late final ScrollController _cycleScrollController;

  void _scrollCycleToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cycleScrollController.hasClients) {
        _cycleScrollController.animateTo(
          _cycleScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  // ── Step 1: Goal State ──
  int _selectedGoalIndex = 0;
  static const List<_GoalOption> _goals = [
    _GoalOption(
      emoji: '⚖️',
      title: 'Lose weight',
      subtitle: 'Calorie tracking, fat burn classes',
    ),
    _GoalOption(
      emoji: '🥑',
      title: 'Gain weight',
      subtitle: 'Healthy calorie surplus, nutrition guidance',
    ),
    _GoalOption(
      emoji: '💪',
      title: 'Build strength & tone',
      subtitle: 'Resistance training, body recomposition',
    ),
    _GoalOption(
      emoji: '🏃',
      title: 'Improve fitness',
      subtitle: 'Cardio, stamina, daily energy',
    ),
    _GoalOption(
      emoji: '🧘',
      title: 'Reduce stress',
      subtitle: 'Yoga, mindfulness, wellness',
    ),
  ];

  // ── Step 2: Body Metrics State ──
  late double _age;
  late double _weight;
  // Target weight (Oct 2026): asked only for "Lose weight" / "Gain
  // weight". Null = not chosen yet; _targetSkipped = "I'm not sure yet".
  double? _target;
  bool _targetSkipped = false;
  // Body step (Oct 2026): each card stays empty ("—") until she sets it,
  // so we never save a default as her real number.
  bool _ageSet = false;
  bool _weightSet = false;
  bool _heightSet = false;
  final Map<String, GlobalKey> _bodyKeys = {
    for (final k in ['age', 'weight', 'height', 'target']) k: GlobalKey(),
  };
  String? _shakeKey;
  int _shakeTick = 0;
  late double _height;

  // ── Step 3: Cycle Data State ──
  DateTime _selectedPeriodDate = DateTime.now();
  double _cycleLength = 28;
  // Cycle step (Oct 2026): nothing pre-chosen; each answer stays empty
  // until she picks it, like the body step.
  String? _periodDuration;
  String? _flowType;
  String? _isRegular;
  bool _periodDateSet = false;
  bool _cycleLengthSet = false;
  final Map<String, GlobalKey> _cycleKeys = {
    for (final k in ['date', 'length', 'days', 'flow', 'regular']) k: GlobalKey(),
  };
  bool _cycleSkipped = false;

  // ── Life stage page state ──
  String? _lifeStage;

  // ── Step 4: Health Conditions State ──
  static const List<_Condition> _conditions = [
    _Condition('🔬', 'PCOS'),
    _Condition('🦋', 'Thyroid'),
    _Condition('🦴', 'Arthritis'),
    _Condition('🩸', 'Endometriosis'),
    _Condition('💉', 'Diabetes'),
  ];
  final Set<String> _selectedConditions = {};
  bool _noneConditions = false;

  // ── Step 5: Time Preference State ──
  int _selectedTimeIndex = 0;
  static const List<_TimeBlock> _timeBlocks = [
    _TimeBlock(
      emoji: '🌅',
      label: 'Morning',
      subtitle: '6 AM – 11 AM, start the day strong',
      value: 'morning',
    ),
    _TimeBlock(
      emoji: '☀️',
      label: 'Afternoon',
      subtitle: '11 AM – 4 PM, midday energy boost',
      value: 'afternoon',
    ),
    _TimeBlock(
      emoji: '🌇',
      label: 'Evening',
      subtitle: '4 PM – 8 PM, unwind after work',
      value: 'evening',
    ),
    _TimeBlock(
      emoji: '🌙',
      label: 'Night',
      subtitle: '8 PM – 11 PM, late session crew',
      value: 'night',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cycleScrollController = ScrollController();
    final auth = Get.find<AuthController>();

    // Initial page
    _currentPage = widget.initialPage ?? (widget.selectedGoal != null ? 1 : 0);
    if (_gaps) {
      _gapList = [...widget.gapPages!]..sort();
      _currentPage = _gapList.first;
      // Target already saved: don't ask it again here.
      _targetKnown = !widget.askTarget && !_gapList.contains(0);
    }

    // Goal
    final goalToMatch = widget.selectedGoal ?? auth.mainGoal.value;
    if (goalToMatch.isNotEmpty) {
      final idx = _goals.indexWhere(
        (g) => g.title.toLowerCase() == goalToMatch.toLowerCase(),
      );
      if (idx != -1) _selectedGoalIndex = idx;
    }

    // Life stage: show what she picked last time (coming back to signup).
    Get.find<ConsultationController>().getLifeStage().then((ls) {
      final st = ls?['status'];
      if (!mounted || _lifeStage != null || st is! String) return;
      // Past her due date: don't preselect "I'm pregnant" again.
      if (ls?['access'] == 'baby_check') return;
      if (kLifeStageOptions.any((o) => o.value == st)) {
        setState(() => _lifeStage = st);
      }
    });

    // Metrics (gaps mode: her saved profile if the fields are empty)
    String pickT(String a, String? b) =>
        a.trim().isNotEmpty ? a : (_gaps ? (b ?? '') : '');
    final ageT = pickT(auth.editAge.text, auth.logInUser?.age);
    final weightT = pickT(auth.editWeight.text, auth.logInUser?.weight);
    final heightT = pickT(auth.editHeight.text, auth.logInUser?.height);
    _age = (double.tryParse(ageT) ?? 25.0).clamp(18.0, 70.0);
    _weight = (double.tryParse(weightT) ?? 55.0).clamp(30.0, 150.0);
    _height = (double.tryParse(heightT) ?? 5.4).clamp(3.0, 7.0);
    // Coming back (profile edit / app restart): her saved numbers count.
    // Only a real saved value counts as "set" (a 0 / blank / out-of-range
    // value used to show 3'0" with a tick).
    bool inRange(String t, double lo, double hi) {
      final v = double.tryParse(t.trim());
      return v != null && v >= lo && v <= hi;
    }
    _ageSet = inRange(ageT, 18, 70);
    _weightSet = inRange(weightT, 30, 150);
    _heightSet = inRange(heightT, 3, 7);

    // Conditions
    final cond = auth.healthConditions.value;
    if (cond.isNotEmpty) {
      if (cond == 'none') {
        _noneConditions = true;
      } else {
        // Postpartum and menopause now come from the life stage
        // question, so drop them if an older signup saved them here.
        _selectedConditions.addAll(cond
            .split(',')
            .where((c) => c.isNotEmpty && c != 'Postpartum' && c != 'Menopause'));
      }
    }

    // Came back after closing the app / losing internet: her answers
    // from this phone, and the page where she stopped.
    if (!_gaps && widget.initialPage == null && widget.selectedGoal == null) {
      _restoreDraft();
    }
    _trackStep(_currentPage);
  }

  String get _userId =>
      Get.find<AuthController>().sharedPreferences.getString(Constants.userId) ?? '';

  Map<String, dynamic> _draftMap() => {
        'page': _currentPage,
        'goal': _selectedGoalTitle,
        'age': _age,
        'weight': _weight,
        'target': _target,
        'targetSkipped': _targetSkipped,
        'periodDateSet': _periodDateSet,
        'cycleLengthSet': _cycleLengthSet,
        'ageSet': _ageSet,
        'weightSet': _weightSet,
        'heightSet': _heightSet,
        'height': _height,
        'periodDate': _selectedPeriodDate.toIso8601String(),
        'cycleLength': _cycleLength,
        'periodDuration': _periodDuration,
        'flowType': _flowType,
        'isRegular': _isRegular,
        'cycleSkipped': _cycleSkipped,
        'cycleSkippedByLifeStage': _cycleSkippedByLifeStage,
        'conditions': _selectedConditions.toList(),
        'none': _noneConditions,
        'timeIndex': _selectedTimeIndex,
      };

  void _restoreDraft() {
    final prefs = Get.find<AuthController>().sharedPreferences;
    final d = SignupProgress.loadDraft(prefs, _userId);
    if (d == null) return;
    double? numOf(String k) => d[k] is num ? (d[k] as num).toDouble() : null;
    final goal = d['goal'];
    if (goal is String) {
      final idx = _goals.indexWhere((g) => g.title == goal);
      if (idx != -1) _selectedGoalIndex = idx;
    }
    _age = (numOf('age') ?? _age).clamp(18.0, 70.0);
    _weight = (numOf('weight') ?? _weight).clamp(30.0, 150.0);
    _height = (numOf('height') ?? _height).clamp(3.0, 7.0);
    _target = numOf('target');
    _targetSkipped = d['targetSkipped'] == true;
    if (d['ageSet'] == true) _ageSet = true;
    if (d['cycleLengthSet'] == true) _cycleLengthSet = true;
    if (d['weightSet'] == true) _weightSet = true;
    if (d['heightSet'] == true) _heightSet = true;
    final pd = DateTime.tryParse('${d['periodDate'] ?? ''}');
    if (pd != null && DateTime.now().difference(pd).inDays <= 60) _selectedPeriodDate = pd;
    if (d['periodDateSet'] == true && pd != null && DateTime.now().difference(pd).inDays <= 60) {
      _periodDateSet = true;
    }
    _cycleLength = numOf('cycleLength') ?? _cycleLength;
    if (d['periodDuration'] is String) _periodDuration = d['periodDuration'];
    if (d['flowType'] is String) _flowType = d['flowType'];
    if (d['isRegular'] is String) _isRegular = d['isRegular'];
    _cycleSkipped = d['cycleSkipped'] == true;
    _cycleSkippedByLifeStage = d['cycleSkippedByLifeStage'] == true;
    if (d['conditions'] is List) {
      _selectedConditions
        ..clear()
        ..addAll((d['conditions'] as List).whereType<String>());
    }
    _noneConditions = d['none'] == true;
    final ti = d['timeIndex'];
    if (ti is int && ti >= 0 && ti < _timeBlocks.length) _selectedTimeIndex = ti;
    final page = d['page'];
    if (page is int && page > 0 && page < _totalSteps) {
      _currentPage = page;
      AnalyticsHelper.track('signup_resumed', {'step': _stepNames[page]});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          CustomToast.infoToast('Welcome back 💚', sub: "Let's finish where you left off");
        }
      });
    }
  }

  /// After every page: keep her answers on this phone, and on the server
  /// when online (so home is personal even if she stops here).
  // ── Gaps mode ("About you") ──
  bool get _gaps => widget.gapPages != null && widget.gapPages!.isNotEmpty;
  List<int> _gapList = const [];
  bool _targetKnown = false;
  int get _barCount => _gaps ? _gapList.length : _totalSteps;
  int get _barIndex => _gaps ? _gapList.indexOf(_currentPage).clamp(0, 99) : _currentPage;

  /// Last page of "About you": the button says Save.
  bool get _lastGap =>
      _gaps &&
      _currentPage != _pLifeStage &&
      !_gapList.any((p) => p > _currentPage) &&
      !(_currentPage == 0 && _weightWay != null && !_targetKnown);

  Future<void> _nextGap() async {
    // Picked Lose / Gain weight: the body page follows for her target.
    if (_currentPage == 0 && _weightWay != null && !_gapList.contains(1)) {
      _gapList = [..._gapList, 1]..sort();
    }
    final next = _gapList.where((p) => p > _currentPage);
    if (next.isEmpty) return _finishGaps();
    await _animateTo(next.first);
  }

  /// "Later" in gaps mode: keep what she answered so far (only those
  /// fields), then close. Next time only what's still missing is asked.
  void _laterGaps() {
    final auth = Get.find<AuthController>();
    final goalDone = _gapList.contains(0) && _currentPage > 0;
    final hm = _height * 0.3048;
    final fields = <String, dynamic>{
      if (goalDone) 'mainGoal': _selectedGoalTitle,
      if (_ageSet) 'age': _age.round().toString(),
      if (_weightSet) 'weight': _weight.round().toString(),
      if (_heightSet) 'height': _height.toString(),
      if (_weightSet && _heightSet) 'bmiResult': (_weight / (hm * hm)).toStringAsFixed(2),
    };
    if (fields.isNotEmpty) {
      Get.find<HomeController>().saveSignupDraft(fields, 1);
      if (goalDone) {
        auth.mainGoal.value = _selectedGoalTitle;
        auth.logInUser?.mainGoal = _selectedGoalTitle;
      }
      if (_ageSet) auth.editAge.text = _age.round().toString();
      if (_weightSet) auth.editWeight.text = _weight.round().toString();
      if (_heightSet) auth.editHeight.text = _height.toString();
    }
    final way = _weightWay;
    if (way != null && !_targetKnown && !_targetSkipped && _target != null &&
        _targetRange.$2 > _targetRange.$1) {
      _saveTarget(way);
    }
    Get.back<bool>(result: false);
  }

  /// Saves her target weight, then refreshes Home so the Weight tile
  /// stops asking "Set your target" straight away.
  Future<void> _saveTarget(String way) async {
    try {
      await Get.find<HomeController>().homeRepo.saveTargetWeight(
        _targetValue,
        weightGoalDirection: way,
        includeDirection: true,
      );
      if (Get.isRegistered<PaidHomeController>()) {
        Get.find<PaidHomeController>().silentRefresh();
      }
    } catch (_) {}
  }

  /// Saves only what these pages asked, then back to Home.
  Future<void> _finishGaps() async {
    if (_isSubmitting) return;
    _backToHere();
    setState(() => _isSubmitting = true);
    final auth = Get.find<AuthController>();
    final token = auth.sharedPreferences.getString(Constants.accessToken) ?? '';
    // Life stage saving in the background: let it land first, so the
    // health form that follows doesn't ask it again.
    try {
      await _lifeStageSave;
    } catch (_) {}

    if (_gapList.contains(0) || _gapList.contains(1)) {
      final hm = _height * 0.3048;
      final bmi = (_weight / (hm * hm)).toStringAsFixed(2);
      final ok = await Get.find<HomeController>().addUserDetails(
        status: false,
        age: _age.round().toString(),
        weight: _weight.round().toString(),
        height: _height.toString(),
        bmiResult: bmi,
        mainGoal: _selectedGoalTitle,
        navigate: false,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() => _isSubmitting = false);
        CustomToast.warnToast("Couldn't save", sub: 'Check your internet and try again.');
        return;
      }
      auth.editAge.text = _age.round().toString();
      auth.editWeight.text = _weight.round().toString();
      auth.editHeight.text = _height.toString();
      auth.editBmi.text = bmi;
      auth.logInUser?.weight = _weight.round().toString();
      auth.logInUser?.height = _height.toString();

      final way = _weightWay;
      if (way != null && !_targetKnown && !_targetSkipped && _target != null &&
          _targetRange.$2 > _targetRange.$1) {
        await _saveTarget(way);
      }
    }

    if (_gapList.contains(_pCycle)) {
      final cycleBody = _cycleSkipped
          ? {'dataProvided': 0}
          : {
              'lastPeriodDate': DateFormat('yyyy-MM-dd').format(_selectedPeriodDate),
              'averageCycleLength': _cycleLength.round(),
              'isRegular': _regularAnswer == '✓ Yes'
                  ? 'yes'
                  : _regularAnswer == '✗ No'
                      ? 'no'
                      : 'not sure',
              'periodDuration': _periodDuration,
              'flowType': _flowType,
              'dataProvided': 1,
            };
      try {
        await Get.find<CycleDataRepository>().saveCycleData(accessToken: token, body: cycleBody);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Get.back<bool>(result: true);
    CustomToast.successToast(msg: 'Saved 💚');
  }

  void _saveProgress({bool toServer = false}) {
    if (_gaps) return; // "About you" saves only on its last page
    final prefs = Get.find<AuthController>().sharedPreferences;
    SignupProgress.saveDraft(prefs, _userId, _draftMap());
    if (!toServer || _currentPage < 2) return;
    final heightInMeters = _height * 0.3048;
    final bmi = _weight / (heightInMeters * heightInMeters);
    Get.find<HomeController>().saveSignupDraft({
      'mainGoal': _selectedGoalTitle,
      'age': _age.round().toString(),
      'weight': _weight.round().toString(),
      'height': _height.toString(),
      'bmiResult': bmi.toStringAsFixed(2),
      if (_currentPage > _pHealth)
        'healthConditions': _noneConditions
            ? 'none'
            : _selectedConditions.join(','),
    }, _currentPage);
  }

  @override
  void dispose() {
    _cycleScrollController.dispose();
    super.dispose();
  }

  String get _displayHeight {
    final feet = _height.floor();
    final inches = ((_height - feet) * 12).round();
    return "$feet' $inches\"";
  }

  double get _bmi {
    final heightInMeters = _height * 0.3048;
    if (heightInMeters <= 0) return 0;
    return _weight / (heightInMeters * heightInMeters);
  }


  // ── Step 3: "Which of these fits you right now?" ──
  // A page in this flow, like the others. Saved on the backend
  // (pre-consultation profile) so the trial / paid forms never ask again.
  //   * pregnant            -> due date, then Coming soon, signup stops.
  //   * recently had a baby -> birth date + delivery type. Still inside the
  //                            waiting time: Coming soon with her date.
  //                            Past it: doctor tick, then health conditions.
  //   * periods on time / irregular / trying for a baby -> cycle page.
  //   * periods stopped / rather not say -> skip cycle, health conditions.
  static const int _pLifeStage = 2;

  /// Mixpanel: which questionnaire page she reached (drop-off per page).
  static const _stepNames = ['goal', 'body', 'life_stage', 'cycle', 'health', 'time'];
  void _trackStep(int page) {
    if (page >= 0 && page < _stepNames.length) {
      AnalyticsHelper.signupStepViewed(_stepNames[page]);
    }
  }
  static const int _pCycle = 3;
  static const int _pHealth = 4;

  Future<void> _submitLifeStage() async {
    final value = _lifeStage;
    if (value == null) {
      CustomToast.failToast(msg: 'Please pick the one that fits you');
      return;
    }
    if (_isSubmitting) return;

    // Periods / no periods: nothing to wait for, so move on at once and
    // save in the background (Oct 2026: the button used to spin for the
    // server round trip, which felt like a reload). Only pregnant and
    // postpartum need the server's answer for their next screen.
    if (value != 'pregnant' && value != 'postpartum') {
      _lifeStageSave = _saveLifeStageInBackground(value);
      _selfRoute ??= ModalRoute.of(context);
      if (lifeStageHasPeriods(value)) {
        _goToCycle(_age.round(), _weight, _height);
      } else {
        _saveCycleData({'dataProvided': 0});
        _goToHealthConditions(_age.round(), _weight, _height);
      }
      return;
    }

    setState(() => _isSubmitting = true);
    final ls = await Get.find<ConsultationController>()
        .saveLifeStage({'status': value});
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ls == null) return; // toast already shown, stay on this page

    final age = _age.round();
    _selfRoute ??= ModalRoute.of(context);
    if (value == 'pregnant') {
      Get.to(() => PregnancyDetailsScreen(
            currentStep: _pLifeStage + 1,
            totalSteps: _totalSteps,
            initial: ls,
            onSaved: (res) => _gaps
                ? _finishGaps()
                : Get.offAll(() => LifeStageComingSoonScreen(data: res)),
          ));
      return;
    }
    if (value == 'postpartum') {
      _goToPostpartum(ls, age, _weight, _height);
      return;
    }
    if (lifeStageHasPeriods(value)) {
      _goToCycle(age, _weight, _height);
    } else {
      _saveCycleData({'dataProvided': 0});
      _goToHealthConditions(age, _weight, _height);
    }
  }

  Future<void>? _lifeStageSave; // background save, awaited on finish

  /// Saves her life stage without holding up the next page; tries twice.
  Future<void> _saveLifeStageInBackground(String value) async {
    final c = Get.find<ConsultationController>();
    for (var i = 0; i < 2; i++) {
      final ok = await c.saveLifeStage({'status': value}, quiet: i == 0);
      if (ok != null) return;
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void _goToPostpartum(
      Map<String, dynamic> ls, int age, double weight, double height) {
    Get.to(() => PostpartumDetailsScreen(
          currentStep: _pLifeStage + 1,
          totalSteps: _totalSteps,
          initial: ls,
          onSaved: (res) {
            switch (res['access']) {
              case 'waiting':
                if (_gaps) {
                  _finishGaps();
                } else {
                  Get.offAll(() => LifeStageComingSoonScreen(data: res));
                }
                break;
              case 'needs_clearance':
                Get.to(() => DoctorClearanceScreen(
                      currentStep: _pLifeStage + 1,
                      totalSteps: _totalSteps,
                      onCleared: () => _afterPostpartumCleared(age, weight, height),
                    ));
                break;
              default: // full: already cleared earlier
                _afterPostpartumCleared(age, weight, height);
            }
          },
        ));
  }

  // Periods may not be back yet after birth, so the cycle step is skipped.
  void _afterPostpartumCleared(int age, double weight, double height) {
    _saveCycleData({'dataProvided': 0});
    _goToHealthConditions(age, weight, height);
  }

  /// This screen's route, so the pushed follow-up screens (due date,
  /// birth details, doctor tick) can be closed back to it.
  ModalRoute<dynamic>? _selfRoute;

  /// True when the life stage answer skipped the cycle page, so Back
  /// from health conditions returns to the life stage page.
  bool _cycleSkippedByLifeStage = false;

  void _backToHere() {
    final me = _selfRoute;
    if (me != null && !me.isCurrent) {
      Navigator.of(context).popUntil((r) => r == me || r.isFirst);
    }
  }

  /// Periods on time, irregular or trying for a baby: the cycle page.
  void _goToCycle(int age, double weight, double height) {
    _cycleSkippedByLifeStage = false;
    _cycleSkipped = false;
    _backToHere();
    if (_gaps && !_gapList.contains(_pCycle)) _gapList = [..._gapList, _pCycle]..sort();
    _animateTo(_pCycle);
  }

  /// Saves cycle data now. {'dataProvided': 0} also marks the cycle as
  /// skipped so _finish() sends the same thing.
  void _saveCycleData(Map<String, dynamic> cycleData) {
    if (cycleData['dataProvided'] == 0) {
      _cycleSkipped = true;
      _cycleSkippedByLifeStage = true;
    }
    final token = Get.find<AuthController>()
            .sharedPreferences
            .getString(Constants.accessToken) ??
        '';
    try {
      Get.find<CycleDataRepository>()
          .saveCycleData(accessToken: token, body: cycleData);
    } catch (_) {}
  }

  /// No cycle page for her: straight to health conditions.
  void _goToHealthConditions(int age, double weight, double height) {
    _backToHere();
    if (_gaps) {
      _finishGaps();
      return;
    }
    _animateTo(_pHealth);
  }

  String get _bmiCategory {
    final b = _bmi;
    if (b < 18.5) return 'Underweight';
    if (b < 25.0) return 'Healthy weight';
    if (b < 30.0) return 'Overweight';
    return 'Obese';
  }

  String get _selectedGoalTitle => _goals[_selectedGoalIndex].title;

  /// 'lose' / 'gain' when her goal is about weight, else null.
  String? get _weightWay {
    final g = _selectedGoalTitle.toLowerCase();
    if (g == 'lose weight') return 'lose';
    if (g == 'gain weight') return 'gain';
    return null;
  }

  /// Slider range for the target: below her weight to lose, above to gain.
  (double, double) get _targetRange => _weightWay == 'gain'
      ? ((_weight + 1).clamp(31.0, 199.0).roundToDouble(), 200.0)
      : (_minHealthyKg, (_weight - 1).clamp(30.0, 149.0).roundToDouble());

  /// Lowest safe target: healthy BMI 18.5 for her height (never below 30).
  double get _minHealthyKg {
    final m = _height * 0.3048;
    return (18.5 * m * m).ceilToDouble().clamp(30.0, 149.0);
  }

  /// Fields still to set on the body step, in screen order.
  List<String> get _bodyMissing => [
        if (!_ageSet) 'age',
        if (!_weightSet) 'weight',
        if (!_heightSet) 'height',
        if (_weightWay != null &&
            !_targetKnown &&
            _targetRange.$2 > _targetRange.$1 &&
            !_targetSkipped &&
            _target == null)
          'target',
      ];

  int get _bodyTotal =>
      3 + ((_weightWay != null && !_targetKnown && _targetRange.$2 > _targetRange.$1 && !_targetSkipped) ? 1 : 0);

  /// Next tapped too early: scroll to the first empty card and shake it.
  void _nudgeBody() {
    final miss = _bodyMissing;
    if (miss.isEmpty) return;
    final k = miss.first;
    final ctx = _bodyKeys[k]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350), alignment: 0.3, curve: Curves.easeOutCubic);
    }
    HapticFeedback.lightImpact();
    setState(() {
      _shakeKey = k;
      _shakeTick++;
    });
  }

  /// Oct 2026: "My periods come on time / are irregular" on the life
  /// stage page already answers "Are your periods regular?", so that
  /// question is only asked when she picked something else.
  String? get _regularFromLifeStage => _lifeStage == 'regular_cycle'
      ? '✓ Yes'
      : _lifeStage == 'irregular_cycle'
          ? '✗ No'
          : null;

  /// The answer that is saved: from the life stage page, else her tap.
  String? get _regularAnswer => _regularFromLifeStage ?? _isRegular;

  int get _cycleTotal => _regularFromLifeStage != null ? 4 : 5;

  /// Cycle questions still to answer, in screen order.
  List<String> get _cycleMissing => [
        if (!_periodDateSet) 'date',
        if (!_cycleLengthSet) 'length',
        if (_periodDuration == null) 'days',
        if (_flowType == null) 'flow',
        if (_regularAnswer == null) 'regular',
      ];

  void _nudgeCycle() {
    final miss = _cycleMissing;
    if (miss.isEmpty) return;
    final k = miss.first;
    final ctx = _cycleKeys[k]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350), alignment: 0.3, curve: Curves.easeOutCubic);
    }
    HapticFeedback.lightImpact();
    setState(() {
      _shakeKey = 'c_$k';
      _shakeTick++;
    });
  }

  /// One cycle question: key (scroll target), shake, amber hint if empty.
  Widget _cycleQ(String k, Widget child) {
    final missing = _shakeKey == 'c_$k' && _cycleMissing.contains(k);
    return KeyedSubtree(
      key: _cycleKeys[k],
      child: _shaky('c_$k', Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: missing ? const Color(0xFFE9B872) : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: missing ? EdgeInsets.all(6.w) : EdgeInsets.zero,
        child: child,
      )),
    );
  }

  /// Tap the big number: type it exactly.
  Future<void> _typeValue(String field) async {
    final isHeight = field == 'height';
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    String title;
    if (isHeight) {
      title = 'Your height';
      if (_heightSet) {
        c1.text = '${_height.floor()}';
        c2.text = '${((_height - _height.floor()) * 12).round()}';
      }
    } else {
      title = field == 'age' ? 'Your age' : field == 'weight' ? 'Your weight (kg)' : 'Target weight (kg)';
      final v = field == 'age'
          ? (_ageSet ? _age : null)
          : field == 'weight'
              ? (_weightSet ? _weight : null)
              : _target;
      if (v != null) c1.text = '${v.round()}';
    }
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        );
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
        content: isHeight
            ? Row(children: [
                Expanded(child: TextField(controller: c1, autofocus: true, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: deco('ft'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: c2, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: deco('in'))),
              ])
            : TextField(controller: c1, autofocus: true, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: deco(field == 'age' ? 'years' : 'kg')),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final a = double.tryParse(c1.text.trim());
    if (a == null) return;
    String? err;
    setState(() {
      switch (field) {
        case 'age':
          if (a < 18 || a > 70) { err = 'Age must be 18–70.'; break; }
          _age = a; _ageSet = true;
          break;
        case 'weight':
          if (a < 30 || a > 150) { err = 'Weight must be 30–150 kg.'; break; }
          _weight = a; _weightSet = true;
          break;
        case 'height':
          {
            final inch = double.tryParse(c2.text.trim()) ?? 0;
            final h = a + (inch.clamp(0, 11) / 12);
            if (h < 3 || h > 7) { err = "Height must be 3'0\" to 7'0\"."; break; }
            _height = h; _heightSet = true;
          }
          break;
        case 'target':
          {
            final (lo, hi) = _targetRange;
            if (a < lo || a > hi) { err = 'Pick a target between ${lo.round()} and ${hi.round()} kg.'; break; }
            _target = a;
          }
          break;
      }
    });
    if (err != null) CustomToast.warnToast(err!);
  }

  /// "16 kg to lose · about 8 months at a healthy pace" (0.5 kg/week,
  /// 4–52 weeks, same rule as the server's goal sync).
  String? get _targetHint {
    if (_target == null || !_weightSet) return null;
    final diff = (_weight - _targetValue).abs().round();
    if (diff <= 0) return null;
    final weeks = (diff / 0.5).ceil().clamp(4, 52);
    final months = (weeks / 4.3).round();
    final when = months < 2 ? '$weeks weeks' : (weeks >= 52 ? 'about a year' : 'about $months months');
    return '$diff kg to ${_weightWay == 'gain' ? 'gain' : 'lose'} · $when at a healthy pace';
  }

  /// Her target kept inside the allowed range (default: 5 kg away).
  double get _targetValue {
    final (lo, hi) = _targetRange;
    final def = _weightWay == 'gain' ? _weight + 5 : _weight - 5;
    return (_target ?? def).clamp(lo, hi).roundToDouble();
  }

  /// Conditions page needs an answer: at least one condition, or
  /// "None of the above" (Oct 2026: it could be skipped with nothing).
  bool get _healthMissing =>
      _currentPage == _pHealth && _selectedConditions.isEmpty && !_noneConditions;

  Future<void> _nextPage() async {
    if (_healthMissing) {
      HapticFeedback.lightImpact();
      CustomToast.failToast(msg: 'Pick one, or "None of the above"');
      return;
    }
    if (_currentPage == _pCycle) _cycleSkipped = false;
    if (_currentPage == 1 && _bodyMissing.isNotEmpty) return _nudgeBody();
    if (_currentPage == _pCycle && _cycleMissing.isNotEmpty) return _nudgeCycle();
    if (_currentPage == _pLifeStage) return _submitLifeStage();
    if (_gaps) return _nextGap();
    if (_currentPage >= _totalSteps - 1) return;
    await _animateTo(_currentPage + 1);
  }

  Future<void> _prevPage() async {
    if (_gaps) {
      final prev = _gapList.where((p) => p < _currentPage);
      if (prev.isEmpty) {
        if (widget.canLeave) _laterGaps();
        return;
      }
      await _animateTo(prev.last);
      return;
    }
    if (_currentPage <= 0) return;
    await _animateTo(
      (_currentPage == _pHealth && _cycleSkippedByLifeStage)
          ? _pLifeStage
          : _currentPage - 1,
    );
  }

  /// Same fade and slide for every page change, forward or back.
  Future<void> _animateTo(int page) async {
    if (!mounted || page == _currentPage) return;
    final forward = page > _currentPage;

    // Phase 1: fade out current content
    setState(() {
      _pageVisible = false;
      _isGoingForward = forward;
    });
    await Future.delayed(const Duration(milliseconds: 180));

    // Phase 2: swap page (invisible), then fade in
    if (!mounted) return;
    setState(() {
      _currentPage = page;
    });
    _trackStep(page);
    _saveProgress(toServer: forward);
    await Future.delayed(const Duration(milliseconds: 20));
    if (!mounted) return;
    setState(() {
      _pageVisible = true;
    });
  }

  Future<void> _pickPeriodDate() async {
    final now = DateTime.now();
    final earliest = now.subtract(const Duration(days: 60));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedPeriodDate,
      firstDate: earliest,
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: OnboardingScaffold.green,
              onPrimary: Colors.white,
              onSurface: OnboardingScaffold.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriodDate = picked;
        _periodDateSet = true;
      });
    }
  }

  Future<void> _finish() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    _saveProgress();

    final auth = Get.find<AuthController>();
    final prefs = auth.sharedPreferences;
    final token = prefs.getString(Constants.accessToken) ?? '';

    // 1. BMI Calculation
    final heightInMeters = _height * 0.3048;
    final bmi = _weight / (heightInMeters * heightInMeters);
    final bmiStr = bmi.toStringAsFixed(2);
    final selectedTimeBlock = _timeBlocks[_selectedTimeIndex].value;
    final conditionsStr = _noneConditions
        ? 'none'
        : _selectedConditions.isEmpty
            ? ''
            : _selectedConditions.join(',');

    // 2. Profile first: this is what marks the questions done. If it
    //    fails (no internet), nothing is marked done and the button
    //    comes back, her answers kept on the phone.
    final ok = await Get.find<HomeController>().addUserDetails(
      status: false,
      age: _age.round().toString(),
      weight: _weight.round().toString(),
      height: _height.toString(),
      bmiResult: bmiStr,
      mainGoal: _selectedGoalTitle,
      healthConditions: conditionsStr,
      onboardingDone: true,
      navigate: false,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _isSubmitting = false);
      AnalyticsHelper.track('signup_finish_failed', {});
      CustomToast.warnToast("Couldn't finish",
          sub: 'Your answers are saved. Check your internet and tap Get Started again.');
      return;
    }

    // Welcome sheet on her first landing on home (shown once).
    TrialWelcomeSheet.markPending();

    // Target weight (Lose / Gain weight, unless "I'm not sure yet").
    final way = _weightWay;
    if (way != null && !_targetSkipped && _target != null && _targetRange.$2 > _targetRange.$1) {
      try {
        Get.find<HomeController>().homeRepo.saveTargetWeight(
          _targetValue,
          weightGoalDirection: way,
          includeDirection: true,
        );
      } catch (_) {}
    }

    // 3. Class time preference (only now marked done on this phone).
    prefs.setString(Constants.timeBlock, selectedTimeBlock);
    prefs.setString(Constants.timePreferenceDone, 'true');
    try {
      final api = Get.find<ApiProvider>();
      await api.postData(
        '/users/notification_preferences',
        body: {'timeBlock': selectedTimeBlock},
        headers: {'accessToken': token},
      );
    } catch (_) {}

    // 4. Cycle data
    final cycleBody = _cycleSkipped
        ? {'dataProvided': 0}
        : {
            'lastPeriodDate': DateFormat('yyyy-MM-dd').format(_selectedPeriodDate),
            'averageCycleLength': _cycleLength.round(),
            'isRegular': _regularAnswer == '✓ Yes'
                ? 'yes'
                : _regularAnswer == '✗ No'
                    ? 'no'
                    : 'not sure',
            'periodDuration': _periodDuration,
            'flowType': _flowType,
            'dataProvided': 1,
          };
    try {
      Get.find<CycleDataRepository>().saveCycleData(accessToken: token, body: cycleBody);
    } catch (_) {}

    // 5. Local profile for screens that open right away
    auth.editBmi.text = bmiStr;
    auth.editAge.text = _age.round().toString();
    auth.editWeight.text = _weight.round().toString();
    auth.editHeight.text = _height.toString();
    auth.mainGoal.value = _selectedGoalTitle;
    auth.healthConditions.value = conditionsStr;

    // 6. Home (or the trial / time screens updateUserDetails decides)
    auth.updateUserDetails(updateFields: false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentPage > 0 || _gaps) {
          _prevPage();
        }
      },
      child: Scaffold(
        backgroundColor: OnboardingScaffold.bg,
        body: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // ── Persistent Top-Right Bubble ──
              Positioned(
                top: 110.h,
                right: -70.w,
                child: Container(
                  width: 240.w,
                  height: 240.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: OnboardingScaffold.circleBg.withValues(alpha: 0.45),
                  ),
                ),
              ),

              // ── Persistent Bottom-Left Bubble ──
              Positioned(
                bottom: 140.h,
                left: -60.w,
                child: Container(
                  width: 180.w,
                  height: 180.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: OnboardingScaffold.circleBg.withValues(alpha: 0.3),
                  ),
                ),
              ),

              // ── Main Layout ──
              SafeArea(
                child: Column(
                  children: [
                    // ── Pinned Navigation Header ──
                    Padding(
                      padding: EdgeInsets.only(left: 28.w, right: 28.w, top: 14.h),
                      child: Row(
                        children: [
                          if (_gaps
                              ? (widget.canLeave || _barIndex > 0)
                              : (_currentPage > 0 || widget.selectedGoal != null))
                            GestureDetector(
                              onTap: _prevPage,
                              child: Container(
                                width: 40.w,
                                height: 40.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: OnboardingScaffold.dividerLine, width: 1.5),
                                ),
                                child: Center(
                                  child: Icon(Icons.arrow_back_ios_new, size: 16.sp, color: OnboardingScaffold.textDark),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              width: 40.w,
                              height: 40.w,
                            ),
                          SizedBox(width: 12.w),

                          // ── 6-Segment Pill Indicators ──
                          Expanded(
                            child: Row(
                              children: List.generate(_barCount, (i) {
                                final isActive = i == _barIndex;
                                final isDone = i < _barIndex;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 3.w),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 350),
                                      curve: Curves.easeInOutCubic,
                                      height: 4.h,
                                      decoration: BoxDecoration(
                                        color: (isActive || isDone)
                                            ? OnboardingScaffold.green
                                            : OnboardingScaffold.circleBg,
                                        borderRadius: BorderRadius.circular(2.r),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          // Step counter "2 / 6", same as the other forms.
                          SizedBox(width: 12.w),
                          if (_gaps && widget.canLeave) ...[
                            GestureDetector(
                              onTap: _isSubmitting ? null : _laterGaps,
                              child: Padding(
                                padding: EdgeInsets.only(right: 10.w),
                                child: Text(
                                  'Later',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: OnboardingScaffold.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          SizedBox(
                            width: 42.w,
                            child: Text(
                              '${_barIndex + 1} / $_barCount',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: OnboardingScaffold.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_gaps && widget.partLabel != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(80.w, 4.h, 28.w, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.partLabel!,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: OnboardingScaffold.green,
                            ),
                          ),
                        ),
                      ),
                    // ── Page Content: AnimatedOpacity (no overlap, pure sequential) ──
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: _pageVisible ? 1.0 : 0.0,
                        duration: Duration(
                          milliseconds: _pageVisible ? 260 : 160,
                        ),
                        curve: _pageVisible ? Curves.easeOut : Curves.easeIn,
                        child: AnimatedSlide(
                          offset: _pageVisible ? Offset.zero : Offset(0, _isGoingForward ? -0.03 : 0.03),
                          duration: Duration(
                            milliseconds: _pageVisible ? 300 : 160,
                          ),
                          curve: _pageVisible ? Curves.easeOutCubic : Curves.easeIn,
                          // A fresh scroll view per page, so every page starts
                          // at its question (it kept the last page's scroll).
                          child: KeyedSubtree(
                            key: ValueKey<int>(_currentPage),
                            child: _buildCurrentPage(),
                          ),
                        ),
                      ),
                    ),

                    // ── Pinned Bottom CTA (Always at the exact same vertical position) ──
                    Padding(
                      padding: EdgeInsets.fromLTRB(28.w, 8.h, 28.w, 20.h),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 54.h,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : (_currentPage == _totalSteps - 1 ? _finish : _nextPage),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _healthMissing
                                    ? OnboardingScaffold.green.withOpacity(0.45)
                                    : OnboardingScaffold.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: 22.w,
                                      height: 22.w,
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      _currentPage == _totalSteps - 1
                                          ? 'Get Started 🎉'
                                          : (_currentPage == 1 && _bodyMissing.isNotEmpty)
                                              ? '${_bodyTotal - _bodyMissing.length} of $_bodyTotal answered · Next →'
                                              : (_currentPage == _pCycle && _cycleMissing.isNotEmpty)
                                                  ? '${_cycleTotal - _cycleMissing.length} of $_cycleTotal answered · Next →'
                                                  : _lastGap
                                                      ? 'Save'
                                                      : 'Next →',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(
                            height: 38.h,
                            child: Center(
                              child: _buildBottomSubAction(),
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
      ),
    );
  }

  /// Consistent sub-action under the pinned primary CTA across all 6 steps
  Widget _buildBottomSubAction() {
    switch (_currentPage) {
      case 0:
        return Text(
          'You can always change this later',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.sp,
            color: OnboardingScaffold.textMuted,
          ),
        );
      case 1:
        return Text(
          'You can always update these anytime in your profile',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.sp,
            color: OnboardingScaffold.textMuted,
          ),
        );
      case 2:
        return Text(
          'You can always change this later',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.sp,
            color: OnboardingScaffold.textMuted,
          ),
        );
      case 3:
        return TextButton(
          onPressed: () {
            setState(() => _cycleSkipped = true);
            if (_gaps) {
              _finishGaps();
            } else {
              _animateTo(_pHealth);
            }
          },
          child: Text(
            'Skip, not tracking my cycle',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.sp,
              color: OnboardingScaffold.textMuted,
            ),
          ),
        );
      case 4:
        return const SizedBox.shrink();
      case 5:
        return Text(
          'You can change notification times anytime in Settings',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.sp,
            color: OnboardingScaffold.textMuted,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ════════════════════════════════════════════════════════
  // ── DISPATCHER: returns the current page widget
  // ════════════════════════════════════════════════════════
  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case 0:
        return _buildGoalPage();
      case 1:
        return _buildBodyMetricsPage();
      case 2:
        return _buildLifeStagePage();
      case 3:
        return _buildCyclePage();
      case 4:
        return _buildHealthConditionsPage();
      case 5:
        return _buildTimePreferencePage();
      default:
        return _buildGoalPage();
    }
  }

  // ════════════════════════════════════════════════════════
  // ── PAGE 1: GOAL SELECTION
  // ════════════════════════════════════════════════════════
  Widget _buildGoalPage() {
    return _buildPageLayout(
      questionLine1: "What's your",
      questionLine2: 'main goal?',
      subtitle: "We'll personalise your entire\nexperience around this",
      content: Column(
        children: List.generate(_goals.length, (i) {
          final opt = _goals[i];
          final isSelected = i == _selectedGoalIndex;
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: GestureDetector(
              onTap: () => setState(() => _selectedGoalIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
                decoration: BoxDecoration(
                  color: isSelected ? OnboardingScaffold.optionSelectedBg : OnboardingScaffold.optionBg,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: isSelected ? OnboardingScaffold.green : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Text(opt.emoji, style: TextStyle(fontSize: 26.sp)),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.title,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: OnboardingScaffold.textDark,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            opt.subtitle,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w300,
                              color: OnboardingScaffold.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 24.w,
                      height: 24.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? OnboardingScaffold.green : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? OnboardingScaffold.green : OnboardingScaffold.radioBorder,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: CustomPaint(
                                size: Size(12.w, 12.w),
                                painter: _CheckPainter(),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ── PAGE 2: BODY METRICS (AGE, WEIGHT, HEIGHT)
  // ════════════════════════════════════════════════════════
  Widget _buildBodyMetricsPage() {
    final hasTarget = _weightWay != null && !_targetKnown && _targetRange.$2 > _targetRange.$1;
    return _buildPageLayout(
      questionLine1: 'Tell us about',
      questionLine2: 'your body',
      subtitle: "We'll tailor your calorie targets and workout intensity using these metrics",
      content: Column(
        children: [
          // ── Age ──
          _shaky('age', _buildSliderMetricCard(
            key: _bodyKeys['age'],
            isSet: _ageSet,
            onTapValue: () => _typeValue('age'),
            emoji: '🎂',
            label: 'Age',
            valueText: '${_age.round()}',
            unitText: 'years old',
            sliderValue: _age,
            min: 18,
            max: 70,
            divisions: 52,
            minLabel: '18 yrs',
            maxLabel: '70 yrs',
            onChanged: (v) => setState(() { _age = v; _ageSet = true; }),
          )),
          SizedBox(height: 14.h),

          // ── Weight ──
          _shaky('weight', _buildSliderMetricCard(
            key: _bodyKeys['weight'],
            isSet: _weightSet,
            onTapValue: () => _typeValue('weight'),
            emoji: '⚖️',
            label: 'Weight',
            valueText: '${_weight.round()}',
            unitText: 'kg',
            sliderValue: _weight,
            min: 30,
            max: 150,
            divisions: 120,
            minLabel: '30 kg',
            maxLabel: '150 kg',
            onChanged: (v) => setState(() { _weight = v; _weightSet = true; }),
          )),
          SizedBox(height: 14.h),

          // ── Height ──
          _shaky('height', _buildSliderMetricCard(
            key: _bodyKeys['height'],
            isSet: _heightSet,
            onTapValue: () => _typeValue('height'),
            emoji: '📏',
            label: 'Height',
            valueText: _displayHeight,
            unitText: 'ft',
            sliderValue: _height,
            min: 3.0,
            max: 7.0,
            divisions: 48,
            minLabel: "3' 0\"",
            maxLabel: "7' 0\"",
            onChanged: (v) => setState(() { _height = v; _heightSet = true; }),
          )),
          SizedBox(height: 14.h),

          // ── Target weight (Lose / Gain weight only), after height so the
          //    healthy minimum uses her real height ──
          if (hasTarget) ...[
            if (_targetSkipped)
              _targetSkippedRow()
            else ...[
              _shaky('target', _buildSliderMetricCard(
                key: _bodyKeys['target'],
                isSet: _target != null,
                onTapValue: () => _typeValue('target'),
                emoji: '🎯',
                label: 'Target weight',
                valueText: '${_targetValue.round()}',
                unitText: 'kg',
                sliderValue: _targetValue,
                min: _targetRange.$1,
                max: _targetRange.$2,
                divisions: (_targetRange.$2 - _targetRange.$1).round().clamp(1, 200),
                minLabel: '${_targetRange.$1.round()} kg',
                maxLabel: '${_targetRange.$2.round()} kg',
                onChanged: (v) => setState(() => _target = v),
                footer: [
                  if (_targetHint != null) _targetHint!,
                  if (_weightWay == 'lose' && _heightSet)
                    'Lowest healthy target for your height: ${_minHealthyKg.round()} kg',
                ],
              )),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() { _targetSkipped = true; _target = null; }),
                  child: Text(
                    "I'm not sure yet",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      color: OnboardingScaffold.textSub,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: 8.h),
          ],

          // ── Live BMI Preview Card (once weight + height are set) ──
          if (_weightSet && _heightSet) Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: OnboardingScaffold.optionSelectedBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: OnboardingScaffold.green.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('📊', style: TextStyle(fontSize: 16.sp)),
                    SizedBox(width: 8.w),
                    Text(
                      'Est. BMI: ',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: OnboardingScaffold.textDark,
                      ),
                    ),
                    Text(
                      _bmi.toStringAsFixed(1),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: OnboardingScaffold.green,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: OnboardingScaffold.circleBg,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    _bmiCategory,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: OnboardingScaffold.textSub,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ── PAGE 3: LIFE STAGE ("Which of these fits you right now?")
  // ════════════════════════════════════════════════════════
  Widget _buildLifeStagePage() {
    return _buildPageLayout(
      questionLine1: 'Which of these',
      questionLine2: 'fits you right now?',
      subtitle: 'This helps us keep your meals\nand workouts safe for you',
      content: Column(
        children: kLifeStageOptions.map((opt) {
          final isSelected = _lifeStage == opt.value;
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: GestureDetector(
              onTap: () => setState(() => _lifeStage = opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
                decoration: BoxDecoration(
                  color: isSelected ? OnboardingScaffold.optionSelectedBg : OnboardingScaffold.optionBg,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: isSelected ? OnboardingScaffold.green : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Text(opt.emoji, style: TextStyle(fontSize: 26.sp)),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.title,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: OnboardingScaffold.textDark,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            opt.subtitle,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w300,
                              color: OnboardingScaffold.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 24.w,
                      height: 24.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? OnboardingScaffold.green : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? OnboardingScaffold.green : OnboardingScaffold.radioBorder,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: CustomPaint(
                                size: Size(12.w, 12.w),
                                painter: _CheckPainter(),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ── PAGE 4: CYCLE TRACKING
  // ════════════════════════════════════════════════════════
  Widget _buildCyclePage() {
    return _buildPageLayout(
      questionLine1: 'Tell us about',
      questionLine2: 'your cycle',
      subtitle: 'This powers your hormonal intelligence and phase tracking',
      scrollController: _cycleScrollController,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Q1: Last Period Date ──
          OnboardingScaffold.buildLabel('When did your ', 'last period', ' start?'),
          SizedBox(height: 10.h),
          _cycleQ('date', GestureDetector(
            onTap: _pickPeriodDate,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 15.h),
              decoration: BoxDecoration(
                color: OnboardingScaffold.optionBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: OnboardingScaffold.radioBorder, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _periodDateSet
                            ? DateFormat('MMMM d, yyyy').format(_selectedPeriodDate)
                            : 'Pick the date',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: _periodDateSet
                              ? OnboardingScaffold.textDark
                              : OnboardingScaffold.textMuted,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _periodDateSet ? 'Tap to change' : 'Tap to open the calendar',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.sp,
                          color: OnboardingScaffold.textMuted,
                        ),
                      ),
                    ],
                  ),
                  _periodDateSet
                      ? Icon(Icons.check_circle_rounded, color: OnboardingScaffold.green, size: 20.sp)
                      : Text('📅', style: TextStyle(fontSize: 20.sp)),
                ],
              ),
            ),
          )),
          SizedBox(height: 20.h),

          // ── Q2: Cycle Length Slider ──
          OnboardingScaffold.buildLabel('Average ', 'cycle length?'),
          SizedBox(height: 10.h),
          _cycleQ('length', Container(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: _cycleLengthSet ? OnboardingScaffold.optionBg : const Color(0xFFF1F3EF),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _cycleLengthSet ? '${_cycleLength.round()}' : '—',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w700,
                            color: _cycleLengthSet
                                ? OnboardingScaffold.textDark
                                : OnboardingScaffold.textMuted,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'days',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.sp,
                            color: OnboardingScaffold.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      !_cycleLengthSet
                          ? 'Slide to set'
                          : _cycleLength < 25
                          ? 'Shorter'
                          : _cycleLength > 35
                              ? 'Longer'
                              : 'Typical',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: OnboardingScaffold.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _cycleLengthSet ? OnboardingScaffold.green : OnboardingScaffold.radioBorder,
                    inactiveTrackColor: OnboardingScaffold.radioBorder,
                    thumbColor: _cycleLengthSet ? OnboardingScaffold.green : OnboardingScaffold.textMuted,
                    overlayColor: OnboardingScaffold.green.withValues(alpha: 0.15),
                    trackHeight: 5.h,
                    thumbShape: _OnboardingThumb(),
                  ),
                  child: Slider(
                    value: _cycleLength,
                    min: 21,
                    max: 45,
                    divisions: 24,
                    onChanged: (v) => setState(() {
                      _cycleLength = v;
                      _cycleLengthSet = true;
                    }),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('21 days', style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp, color: OnboardingScaffold.textMuted)),
                      Text('45 days', style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp, color: OnboardingScaffold.textMuted)),
                    ],
                  ),
                ),
                if (_cycleLengthSet)
                  Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      'Not sure? 28 is the most common. The app learns your real length as you log.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp, color: OnboardingScaffold.textMuted),
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _cycleLength = 28;
                        _cycleLengthSet = true;
                      }),
                      child: Text(
                        "Not sure? Use 28 days (most common)",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: OnboardingScaffold.green,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          )),
          SizedBox(height: 20.h),

          // ── Q3: Period Duration ──
          OnboardingScaffold.buildLabel('How many ', 'days', ' do you bleed?'),
          SizedBox(height: 10.h),
          _cycleQ('days', OnboardingScaffold.buildPillRow(
            options: const [
              '1–2 days',
              '3–5 days',
              '6–7 days',
              '8+ days',
            ],
            selected: _periodDuration,
            onSelect: (v) {
              setState(() => _periodDuration = v);
              _scrollCycleToBottom();
            },
          )),
          SizedBox(height: 20.h),

          // ── Q4: Flow Type ──
          OnboardingScaffold.buildLabel('How ', 'heavy', ' is your flow?'),
          SizedBox(height: 10.h),
          _cycleQ('flow', OnboardingScaffold.buildPillRow(
            options: const ['Light', 'Moderate', 'Heavy'],
            selected: _flowType,
            onSelect: (v) => setState(() => _flowType = v),
          )),
          SizedBox(height: 20.h),

          // ── Q5: Regularity (skipped when the life stage page answered it) ──
          if (_regularFromLifeStage == null) ...[
            OnboardingScaffold.buildLabel('Are your periods ', 'regular', '?'),
            SizedBox(height: 10.h),
            _cycleQ('regular', OnboardingScaffold.buildYesNoRow(
              options: const ['✓ Yes', '✗ No', '? Not sure'],
              selected: _isRegular,
              onSelect: (v) => setState(() => _isRegular = v),
            )),
          ],
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ── PAGE 5: HEALTH CONDITIONS
  // ════════════════════════════════════════════════════════
  Widget _buildHealthConditionsPage() {
    return _buildPageLayout(
      questionLine1: 'Are you managing',
      questionLine2: 'any conditions?',
      subtitle: "Select all that apply — we'll personalise your program, diet plan and symptom tracking around each one",
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: [
              ..._conditions.map((cond) {
                final isSel = _selectedConditions.contains(cond.label);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _noneConditions = false;
                      if (_selectedConditions.contains(cond.label)) {
                        _selectedConditions.remove(cond.label);
                      } else {
                        _selectedConditions.add(cond.label);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: isSel ? OnboardingScaffold.optionSelectedBg : OnboardingScaffold.optionBg,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isSel ? OnboardingScaffold.green : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cond.emoji, style: TextStyle(fontSize: 18.sp)),
                        SizedBox(width: 8.w),
                        Text(
                          cond.label,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.sp,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                            color: OnboardingScaffold.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // 'None of the above' chip
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedConditions.clear();
                    _noneConditions = !_noneConditions;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: _noneConditions ? OnboardingScaffold.optionSelectedBg : OnboardingScaffold.optionBg,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: _noneConditions ? OnboardingScaffold.green : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('✨', style: TextStyle(fontSize: 18.sp)),
                      SizedBox(width: 8.w),
                      Text(
                        'None of the above',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14.sp,
                          fontWeight: _noneConditions ? FontWeight.w600 : FontWeight.w500,
                          color: OnboardingScaffold.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _symptomCheckSection(),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  // ── "Not sure? Check my symptoms" (PCOS / thyroid / menopause /
  // postpartum / endometriosis screening). Opens the screening for the
  // first chosen condition that has one, PCOS by default. A moderate/high
  // result adds that condition to her chips when she comes back.
  static final Map<String, ScreeningConfig> _screeningConfigs = {
    'PCOS': pcosConfig,
    'Thyroid': thyroidConfig,
    'Menopause': menopauseConfig,
    'Postpartum': postpartumConfig,
    'Endometriosis': endometriosisConfig,
  };

  Future<void> _openSymptomCheck() async {
    ScreeningConfig config = pcosConfig;
    for (final label in _selectedConditions) {
      final c = _screeningConfigs[label];
      if (c != null) {
        config = c;
        break;
      }
    }
    AnalyticsHelper.track('symptom_check_opened', {'from': 'signup', 'screening': config.conditionType});
    await Get.to(() => GenericScreeningIntro(config: config));
    if (!mounted) return;
    // The screening adds a likely condition to auth.healthConditions.
    final saved = Get.find<AuthController>().healthConditions.value.toLowerCase();
    setState(() {
      for (final cond in _conditions) {
        if (saved.split(',').map((e) => e.trim()).contains(cond.label.toLowerCase())) {
          _selectedConditions.add(cond.label);
          _noneConditions = false;
        }
      }
    });
  }

  Widget _symptomCheckSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Container(height: 1, color: OnboardingScaffold.circleBg)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text(
                'not sure if you have a condition?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: OnboardingScaffold.textMuted,
                ),
              ),
            ),
            Expanded(child: Container(height: 1, color: OnboardingScaffold.circleBg)),
          ],
        ),
        SizedBox(height: 20.h),
        GestureDetector(
          onTap: _openSymptomCheck,
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: OnboardingScaffold.optionBg,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: OnboardingScaffold.green, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: OnboardingScaffold.green,
                        borderRadius: BorderRadius.circular(13.r),
                      ),
                      child: Center(child: Text('🔍', style: TextStyle(fontSize: 20.sp))),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Check my symptoms',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: OnboardingScaffold.textDark,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            "Answer 5 quick questions and we'll tell you if your symptoms suggest a hormonal condition",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w300,
                              color: OnboardingScaffold.textSub,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: ['Irregular periods', 'Fatigue', 'Weight gain', 'Hair growth', 'Acne']
                      .map((tag) => Container(
                            padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: OnboardingScaffold.textSub,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  // ── PAGE 6: TIME PREFERENCE & FINISH
  // ════════════════════════════════════════════════════════
  Widget _buildTimePreferencePage() {
    return _buildPageLayout(
      questionLine1: 'What time',
      questionLine2: 'suits you?',
      subtitle: "We'll schedule class recommendations and workout reminders around your preference",
      content: Column(
        children: List.generate(_timeBlocks.length, (i) {
          final block = _timeBlocks[i];
          final isSelected = i == _selectedTimeIndex;
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTimeIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
                decoration: BoxDecoration(
                  color: isSelected ? OnboardingScaffold.optionSelectedBg : OnboardingScaffold.optionBg,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: isSelected ? OnboardingScaffold.green : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Text(block.emoji, style: TextStyle(fontSize: 26.sp)),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            block.label,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: OnboardingScaffold.textDark,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            block.subtitle,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w300,
                              color: OnboardingScaffold.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 24.w,
                      height: 24.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? OnboardingScaffold.green : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? OnboardingScaffold.green : OnboardingScaffold.radioBorder,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: CustomPaint(
                                size: Size(12.w, 12.w),
                                painter: _CheckPainter(),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ── HELPER: COMMON PAGE LAYOUT WRAPPER
  // ════════════════════════════════════════════════════════
  Widget _buildPageLayout({
    required String questionLine1,
    required String questionLine2,
    required String subtitle,
    required Widget content,
    ScrollController? scrollController,
  }) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Heading
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: OnboardingScaffold.textDark,
                height: 1.3,
              ),
              children: [
                TextSpan(text: '$questionLine1\n'),
                TextSpan(
                  text: questionLine2,
                  style: const TextStyle(color: OnboardingScaffold.green),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),

          // Subtitle
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w300,
              color: OnboardingScaffold.textMuted,
              height: 1.6,
            ),
          ),
          SizedBox(height: 20.h),

          // Page Specific Content
          content,
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ── HELPER: SLIDER METRIC CARD (BODY METRICS)
  // ════════════════════════════════════════════════════════
  Widget _targetSkippedRow() {
    return GestureDetector(
      onTap: () => setState(() => _targetSkipped = false),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: OnboardingScaffold.optionBg,
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Row(
          children: [
            Text('🎯', style: TextStyle(fontSize: 16.sp)),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Target weight: set it later in Progress',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.sp,
                  color: OnboardingScaffold.textSub,
                ),
              ),
            ),
            Text(
              'Set now',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: OnboardingScaffold.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shakes the card she must still set (Next tapped too early).
  Widget _shaky(String k, Widget child) {
    if (_shakeKey != k) return child;
    return KeyedSubtree(
      key: ValueKey('shake_${k}_$_shakeTick'),
      child: child.animate().shake(hz: 5, offset: const Offset(6, 0), duration: 450.ms),
    );
  }

  Widget _buildSliderMetricCard({
    Key? key,
    bool isSet = true,
    VoidCallback? onTapValue,
    List<String> footer = const [],
    required String emoji,
    required String label,
    required String valueText,
    required String unitText,
    required double sliderValue,
    required double min,
    required double max,
    required int divisions,
    required String minLabel,
    required String maxLabel,
    required ValueChanged<double> onChanged,
  }) {
    final muted = OnboardingScaffold.textMuted;
    return Container(
      key: key,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: isSet ? OnboardingScaffold.optionBg : const Color(0xFFF1F3EF),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: (!isSet && _shakeKey != null && key == _bodyKeys[_shakeKey])
              ? const Color(0xFFE9B872)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(emoji, style: TextStyle(fontSize: 18.sp)),
                  SizedBox(width: 8.w),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: OnboardingScaffold.textDark,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapValue,
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (isSet && onTapValue != null) ...[
                    Icon(Icons.check_circle_rounded, size: 14.sp, color: OnboardingScaffold.green),
                    SizedBox(width: 5.w),
                  ],
                  Text(
                    isSet ? valueText : '—',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: isSet ? OnboardingScaffold.green : muted,
                      decoration: onTapValue != null ? TextDecoration.underline : null,
                      decorationStyle: TextDecorationStyle.dotted,
                      decorationColor: isSet ? OnboardingScaffold.green : muted,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  if (isSet) Text(
                    unitText,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: OnboardingScaffold.textMuted,
                    ),
                  ),
                ],
              ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: isSet ? OnboardingScaffold.green : OnboardingScaffold.radioBorder,
              inactiveTrackColor: OnboardingScaffold.radioBorder,
              thumbColor: isSet ? OnboardingScaffold.green : muted,
              overlayColor: OnboardingScaffold.green.withValues(alpha: 0.15),
              trackHeight: 5.h,
              thumbShape: _OnboardingThumb(),
            ),
            child: Slider(
              value: sliderValue,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  minLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.sp,
                    color: OnboardingScaffold.textMuted,
                  ),
                ),
                Text(
                  maxLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.sp,
                    color: OnboardingScaffold.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!isSet && onTapValue != null)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                'Tap or slide to set',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp, color: muted),
              ),
            ),
          for (final line in footer)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.sp,
                  fontWeight: line.contains('·') ? FontWeight.w600 : FontWeight.w400,
                  color: line.contains('·') ? OnboardingScaffold.green : muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kept for backward compatibility
class Question {
  final String text;
  final List<String>? options;

  Question({required this.text, this.options});
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final sx = size.width / 12;
    final sy = size.height / 12;

    final path = Path()
      ..moveTo(2 * sx, 6 * sy)
      ..lineTo(4.5 * sx, 9 * sy)
      ..lineTo(10 * sx, 3 * sy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingThumb extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(22, 22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center + const Offset(0, 2),
      11,
      Paint()
        ..color = OnboardingScaffold.green.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(center, 11, Paint()..color = Colors.white);
    canvas.drawCircle(center, 8, Paint()..color = OnboardingScaffold.green);
  }
}
