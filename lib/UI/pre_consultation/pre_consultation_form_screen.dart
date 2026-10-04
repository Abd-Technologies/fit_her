import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/Repos/cycle_repo/cycle_data_repository.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../values/constants.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/toasts.dart';
import '../auth_module/sign_up_screen/life_stage_screen.dart'
    show kLifeStageOptions, lifeStageHasPeriods;

/// The pre-consultation form. One form, one source of truth
/// (PreConsultationProfile + her signup answers on the User row).
///
/// It only asks what we don't know yet. The server decides which steps
/// are missing for her plan (GET /users/pre-consultation/requirements).
/// Everything she already answered shows on the review screen, with Edit,
/// right before she sends it with the health consent tick.
///
/// [canLater]: she may tap "Later" (the first 2 times). After that the
/// form is required and can't be closed until it's sent.
class PreConsultationFormScreen extends StatefulWidget {
  final String planType; // diet | workout | combined
  final bool canLater;
  final String popupVariable;

  const PreConsultationFormScreen({
    super.key,
    this.planType = 'diet',
    this.canLater = true,
    this.popupVariable = 'POPUP_PRE_CONSULTATION_FORM',
  });

  static Future<void> open({required String planType, required bool canLater}) async {
    await Get.to<void>(
      () => PreConsultationFormScreen(planType: planType, canLater: canLater),
      fullscreenDialog: true,
    );
  }

  @override
  State<PreConsultationFormScreen> createState() =>
      _PreConsultationFormScreenState();
}

class _Opt {
  final String value;
  final String emoji;
  final String title;
  final String? sub;
  const _Opt(this.value, this.emoji, this.title, [this.sub]);
}

// Same option values as signup and the free trial.
const _signupGoals = [
  _Opt('Lose weight', '⚖️', 'Lose weight', 'Calorie tracking, fat burn classes'),
  _Opt('Gain weight', '🥑', 'Gain weight', 'Healthy calorie surplus'),
  _Opt('Build strength & tone', '💪', 'Build strength & tone', 'Resistance training'),
  _Opt('Improve fitness', '🏃', 'Improve fitness', 'Cardio, stamina, daily energy'),
  _Opt('Reduce stress', '🧘', 'Reduce stress', 'Yoga, mindfulness, wellness'),
];
const _conditions = [
  _Opt('PCOS', '🔬', 'PCOS'),
  _Opt('Thyroid', '🦋', 'Thyroid'),
  _Opt('Diabetes', '💉', 'Diabetes'),
  _Opt('Endometriosis', '🩸', 'Endometriosis'),
  _Opt('Arthritis', '🦴', 'Arthritis'),
];
const _diet = [
  _Opt('no_restrictions', '🍽️', 'Eat everything'),
  _Opt('vegetarian', '🥦', 'Vegetarian'),
  _Opt('halal', '🍗', 'Halal'),
  _Opt('eggs_ok', '🥚', 'Eggs OK'),
  _Opt('seafood_ok', '🐟', 'Seafood OK'),
  _Opt('lactose_free', '🥛', 'Lactose free'),
  _Opt('gluten_free', '🌾', 'Gluten free'),
];
const _fitness = [
  _Opt('beginner', '🌱', 'Just starting', 'Little or no exercise'),
  _Opt('intermediate', '🚶‍♀️', 'Sometimes active', '1 to 3 times a week'),
  _Opt('advanced', '💪', 'Regularly active', '4 or more times a week'),
];

class _PreConsultationFormScreenState extends State<PreConsultationFormScreen> {
  final ConsultationController _ctrl = Get.find<ConsultationController>();
  final AuthController _auth = Get.find<AuthController>();

  bool _loading = true;
  bool _busy = false;
  List<String> _steps = const ['review'];
  int _index = 0;
  bool _backToReview = false;

  // Answers
  String? _goal; // signup title, e.g. "Lose weight"
  String? _lifeStage;
  DateTime? _lastPeriod;
  int _cycleLength = 28;
  bool _cycleNotSure = false;
  final Set<String> _conds = {};
  bool _noConds = false;
  final _allergies = TextEditingController();
  final Set<String> _prefs = {};
  int _meals = 4;
  final _fasting = TextEditingController();
  final _meds = TextEditingController();
  final _family = TextEditingController();
  final _surgeries = TextEditingController();
  String? _fitnessLevel;
  final _injuries = TextEditingController();
  Map<String, dynamic> _wsKeep = {};
  bool _consent = false;

  bool get _hasDiet => widget.planType == 'diet' || widget.planType == 'combined';
  bool get _hasWorkout =>
      widget.planType == 'workout' || widget.planType == 'combined';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_allergies, _fasting, _meds, _family, _surgeries, _injuries]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final req = await _ctrl.getPreConsultRequirements(widget.planType);
    final p = await _ctrl.loadProfile();
    if (!mounted) return;

    // Prefill everything we know, so the review shows it.
    final u = _auth.logInUser;
    final goal = _auth.mainGoal.value.trim().isNotEmpty
        ? _auth.mainGoal.value
        : (u?.mainGoal ?? '');
    if (goal.trim().isNotEmpty) _goal = goal.trim();
    final cond = _auth.healthConditions.value.trim().isNotEmpty
        ? _auth.healthConditions.value
        : (u?.healthConditions ?? '');
    if (cond.trim() == 'none') {
      _noConds = true;
    } else if (cond.trim().isNotEmpty) {
      _conds.addAll(
          cond.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }
    if (p != null) {
      _lifeStage = p.pregnancyMenstrualStatus;
      _allergies.text = p.allergies ?? '';
      final dp = p.dietaryPreferences;
      if (dp != null) _prefs.addAll(dp.map((e) => e.toString()));
      final m = p.mealsPerDay;
      if (m != null && m >= 3 && m <= 6) _meals = m;
      _fasting.text = p.fastingHabits ?? '';
      _meds.text = p.currentMedications ?? '';
      _family.text = p.familyHistory ?? '';
      _surgeries.text = p.surgeries ?? '';
      final ws = p.workoutSection;
      if (ws != null) {
        _wsKeep = Map<String, dynamic>.from(ws);
        _fitnessLevel = ws['fitnessLevel'] as String?;
        if (ws['injuries'] is String) _injuries.text = ws['injuries'] as String;
      }
    }

    final steps = (req?['steps'] as List?)?.map((e) => e.toString()).toList();
    setState(() {
      _steps = (steps == null || steps.isEmpty) ? ['review'] : steps;
      _loading = false;
    });
  }

  // ── navigation ────────────────────────────────────────────────────
  String get _step => _steps[_index];

  void _goNext() {
    if (_backToReview) {
      _backToReview = false;
      setState(() => _index = _steps.indexOf('review'));
      return;
    }
    if (_index < _steps.length - 1) setState(() => _index++);
  }

  void _goBack() {
    if (_index > 0) {
      setState(() => _index--);
    } else if (widget.canLater) {
      _later();
    }
  }

  Future<void> _later() async {
    await _ctrl.dismissPopup(widget.popupVariable);
    if (mounted) Get.back<void>();
  }

  /// Edit from the review: open that step even if it was skipped.
  void _edit(String step) {
    final list = List<String>.from(_steps);
    if (!list.contains(step)) list.insert(list.indexOf('review'), step);
    setState(() {
      _steps = list;
      _index = list.indexOf(step);
      _backToReview = true;
    });
  }

  // ── saving ────────────────────────────────────────────────────────
  static String _goalValue(String title, Set<String> conds, String? lifeStage) {
    final t = title.toLowerCase();
    if (lifeStage == 'postpartum') return 'postpartum';
    if (conds.contains('PCOS')) return 'pcos_management';
    if (t.contains('lose')) return 'weight_loss';
    if (t.contains('gain')) return 'weight_gain';
    if (t.contains('strength') || t.contains('tone')) return 'maintain';
    return 'general_wellness';
  }

  Future<bool> _patch(Map<String, dynamic> body) async {
    setState(() => _busy = true);
    final ok = await _ctrl.patchProfile(body);
    if (mounted) setState(() => _busy = false);
    if (!ok) CustomToast.failToast(msg: 'Could not save. Please try again.');
    return ok;
  }

  Future<void> _saveCycle() async {
    final token = _auth.sharedPreferences.getString(Constants.accessToken) ?? '';
    final Map<String, dynamic> body = _cycleNotSure || _lastPeriod == null
        ? {'dataProvided': 0}
        : {
            'lastPeriodDate': DateFormat('yyyy-MM-dd').format(_lastPeriod!),
            'averageCycleLength': _cycleLength,
            'isRegular': _lifeStage == 'irregular_cycle' ? 'no' : 'yes',
            'dataProvided': 1,
          };
    try {
      await Get.find<CycleDataRepository>()
          .saveCycleData(accessToken: token, body: body);
    } catch (_) {}
  }

  Future<void> _onNext() async {
    if (_busy) return;
    if (!_valid(_step)) {
      CustomToast.failToast(
          msg: _step == 'review'
              ? 'Please tick the box to send your answers'
              : 'Please pick an answer');
      return;
    }
    bool ok = true;
    switch (_step) {
      case 'goal':
        ok = await _patch({
          'userMainGoal': _goal,
          'goals': _goalValue(_goal!, _conds, _lifeStage),
          'step': 'goals',
        });
        if (ok) _auth.mainGoal.value = _goal!;
        break;
      case 'lifeStage':
        ok = await _patch(
            {'pregnancyMenstrualStatus': _lifeStage, 'step': 'lifeStage'});
        // Cycle questions only make sense if she has periods.
        if (ok && lifeStageHasPeriods(_lifeStage) && !_steps.contains('cycle')) {
          setState(() => _steps = List<String>.from(_steps)..insert(_index + 1, 'cycle'));
        } else if (ok && !lifeStageHasPeriods(_lifeStage) && _steps.contains('cycle')) {
          setState(() => _steps = List<String>.from(_steps)..remove('cycle'));
        }
        break;
      case 'cycle':
        setState(() => _busy = true);
        await _saveCycle();
        if (mounted) setState(() => _busy = false);
        break;
      case 'conditions':
        final v = _noConds ? 'none' : _conds.join(',');
        ok = await _patch({'userHealthConditions': v, 'step': 'conditions'});
        if (ok) _auth.healthConditions.value = v;
        break;
      case 'health':
        ok = await _patch({
          'allergies':
              _allergies.text.trim().isEmpty ? 'None' : _allergies.text.trim(),
          'step': 'health',
        });
        break;
      case 'food':
        ok = await _patch({
          'dietaryPreferences': _prefs.toList(),
          'mealsPerDay': _meals,
          'fastingHabits':
              _fasting.text.trim().isEmpty ? null : _fasting.text.trim(),
          'step': 'diet_lifestyle',
        });
        break;
      case 'dietitian':
        ok = await _patch({
          'currentMedications': _meds.text.trim(),
          'familyHistory': _family.text.trim(),
          'surgeries': _surgeries.text.trim(),
          'step': 'history',
        });
        break;
      case 'workout':
        ok = await _patch({
          'workoutSection': {
            ..._wsKeep,
            'fitnessLevel': _fitnessLevel,
            'injuries': _injuries.text.trim(),
          },
          'step': 'workout',
        });
        break;
      case 'review':
        await _submit();
        return;
    }
    if (ok && mounted) _goNext();
  }

  Future<void> _submit() async {
    final ok = await _patch({
      'isComplete': true,
      'confirmed': true,
      'healthConsent': true,
      'consentVersion': 'v1',
      'step': 'review',
    });
    if (!ok || !mounted) return;
    await _ctrl.completePopup(widget.popupVariable);
    Get.back<void>();
    CustomToast.successToast(
        msg: 'Thank you! Your answers are with your team now.');
  }

  bool _valid(String step) {
    switch (step) {
      case 'goal':
        return _goal != null;
      case 'lifeStage':
        return _lifeStage != null;
      case 'cycle':
        return _cycleNotSure || _lastPeriod != null;
      case 'conditions':
        return _noConds || _conds.isNotEmpty;
      case 'food':
        return _prefs.isNotEmpty;
      case 'workout':
        return _fitnessLevel != null;
      case 'review':
        return _consent;
      default:
        return true;
    }
  }

  // ── UI ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(OnboardingScaffold.green),
          ),
        ),
      );
    }
    final step = _step;
    final c = _copy(step);
    final optionalStep = step == 'dietitian';
    final showLater = widget.canLater && step != 'review' && !optionalStep;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: OnboardingScaffold(
        currentStep: _index + 1,
        totalSteps: _steps.length,
        badgeText: c[0],
        questionLine1: c[1],
        questionLine2: c[2],
        subtitle: c[3],
        showBackButton: _index > 0 || widget.canLater,
        onBack: _goBack,
        buttonText: _busy
            ? 'Saving…'
            : step == 'review'
                ? 'Send to my team'
                : 'Next →',
        onNext: _onNext,
        onSkip: optionalStep
            ? () async {
                final ok = await _patch({'step': 'history'});
                if (ok) _goNext();
              }
            : (showLater ? _later : null),
        skipText: optionalStep ? 'Skip for now' : (showLater ? 'Later' : null),
        body: _body(step),
      ),
    );
  }

  List<String> _copy(String step) {
    switch (step) {
      case 'goal':
        return ['Your goal', "What's your", 'main goal?', "We'll shape your plan around it."];
      case 'lifeStage':
        return ['Your body', 'Which of these', 'fits you right now?', 'This helps us keep your meals and workouts safe.'];
      case 'cycle':
        return ['Your cycle', 'When did your', 'last period start?', 'So your plan follows your cycle.'];
      case 'conditions':
        return ['Your health', 'Are you managing', 'any conditions?', 'Pick all that apply.'];
      case 'health':
        return ['Your health', 'Any food', 'allergies?', 'Your dietitian will keep these out of your meals.'];
      case 'food':
        return ['Your food', 'How do you', 'like to eat?', 'Pick everything that fits.'];
      case 'dietitian':
        return ['For your dietitian', 'Anything else she', 'should know?', "Skip anything you're not sure about. You can tell her on the call."];
      case 'workout':
        return ['Your movement', 'How active are', 'you right now?', 'So your trainer starts at the right level.'];
      default:
        return ['Almost done', 'Check your', 'answers', 'Tap Edit to change anything.'];
    }
  }

  Widget _body(String step) {
    switch (step) {
      case 'goal':
        return _options(_signupGoals, _goal, (v) => setState(() => _goal = v));
      case 'lifeStage':
        return Column(
          children: [
            for (final o in kLifeStageOptions)
              _OptionCard(
                emoji: o.emoji,
                title: o.title,
                sub: o.subtitle,
                selected: _lifeStage == o.value,
                onTap: () => setState(() => _lifeStage = o.value),
              ),
          ],
        );
      case 'cycle':
        return _cycleBody();
      case 'conditions':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                for (final o in _conditions)
                  _Chip(
                    label: '${o.emoji} ${o.title}',
                    selected: _conds.contains(o.value),
                    onTap: () => setState(() {
                      _noConds = false;
                      if (!_conds.remove(o.value)) _conds.add(o.value);
                    }),
                  ),
              ],
            ),
            SizedBox(height: 14.h),
            _Chip(
              label: "I don't have any",
              selected: _noConds,
              onTap: () => setState(() {
                _noConds = !_noConds;
                if (_noConds) _conds.clear();
              }),
            ),
          ],
        );
      case 'health':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Field(controller: _allergies, hint: 'For example peanuts, lactose'),
            SizedBox(height: 10.h),
            _Chip(
              label: 'No allergies',
              selected: _allergies.text.trim().toLowerCase() == 'none',
              onTap: () => setState(() => _allergies.text = 'None'),
            ),
          ],
        );
      case 'food':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                for (final o in _diet)
                  _Chip(
                    label: '${o.emoji} ${o.title}',
                    selected: _prefs.contains(o.value),
                    onTap: () => setState(() {
                      if (!_prefs.remove(o.value)) _prefs.add(o.value);
                    }),
                  ),
              ],
            ),
            const _Label('Meals a day'),
            Row(
              children: [
                for (final n in [3, 4, 5, 6]) ...[
                  Expanded(
                    child: _Chip(
                      label: '$n',
                      selected: _meals == n,
                      center: true,
                      onTap: () => setState(() => _meals = n),
                    ),
                  ),
                  if (n != 6) SizedBox(width: 8.w),
                ],
              ],
            ),
            const _Label('Do you fast? (optional)'),
            _Field(
                controller: _fasting,
                hint: 'For example Ramadan, Monday and Thursday'),
          ],
        );
      case 'dietitian':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Medicines you take', top: 0),
            _Field(controller: _meds, hint: 'For example Metformin, thyroid tablets'),
            const _Label('Family history'),
            _Field(controller: _family, hint: 'For example diabetes, heart problems'),
            const _Label('Past surgeries'),
            _Field(controller: _surgeries, hint: 'For example C section in 2022'),
          ],
        );
      case 'workout':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _options(_fitness, _fitnessLevel,
                (v) => setState(() => _fitnessLevel = v)),
            const _Label('Any pain or injury? (optional)'),
            _Field(controller: _injuries, hint: 'For example knee pain'),
          ],
        );
      default:
        return _review();
    }
  }

  Widget _options(
      List<_Opt> opts, String? selected, ValueChanged<String> onPick) {
    return Column(
      children: [
        for (final o in opts)
          _OptionCard(
            emoji: o.emoji,
            title: o.title,
            sub: o.sub,
            selected: selected == o.value,
            onTap: () => onPick(o.value),
          ),
      ],
    );
  }

  Widget _cycleBody() {
    final label = _lastPeriod == null
        ? 'Pick a date'
        : DateFormat('d MMM yyyy').format(_lastPeriod!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Chip(
          label: '📅  $label',
          selected: _lastPeriod != null && !_cycleNotSure,
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _lastPeriod ?? now,
              firstDate: now.subtract(const Duration(days: 90)),
              lastDate: now,
            );
            if (picked != null) {
              setState(() {
                _lastPeriod = picked;
                _cycleNotSure = false;
              });
            }
          },
        ),
        const _Label('Cycle length'),
        Row(
          children: [
            _Round(
                icon: Icons.remove_rounded,
                onTap: () => setState(
                    () => _cycleLength = (_cycleLength - 1).clamp(21, 45))),
            SizedBox(
              width: 110.w,
              child: Text(
                '$_cycleLength days',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: OnboardingScaffold.textDark),
              ),
            ),
            _Round(
                icon: Icons.add_rounded,
                onTap: () => setState(
                    () => _cycleLength = (_cycleLength + 1).clamp(21, 45))),
          ],
        ),
        SizedBox(height: 14.h),
        _Chip(
          label: "I don't remember",
          selected: _cycleNotSure,
          onTap: () => setState(() => _cycleNotSure = !_cycleNotSure),
        ),
      ],
    );
  }

  String _labelFor(List<_Opt> opts, String? v) {
    for (final o in opts) {
      if (o.value == v) return '${o.emoji} ${o.title}';
    }
    return v ?? '';
  }

  String _orText(String s, String fallback) => s.trim().isEmpty ? fallback : s;

  Widget _review() {
    String lifeLabel = _lifeStage ?? '';
    for (final o in kLifeStageOptions) {
      if (o.value == _lifeStage) lifeLabel = '${o.emoji} ${o.title}';
    }
    final cards = <Widget>[
      _ReviewCard(title: 'Goal', text: _goal ?? 'Not set', onEdit: () => _edit('goal')),
      _ReviewCard(
          title: 'Right now',
          text: _orText(lifeLabel, 'Not set'),
          onEdit: () => _edit('lifeStage')),
      _ReviewCard(
        title: 'Health conditions',
        text: _noConds ? 'None' : (_conds.isEmpty ? 'Not set' : _conds.join(' · ')),
        onEdit: () => _edit('conditions'),
      ),
      if (_hasDiet) ...[
        _ReviewCard(
          title: 'Allergies',
          text: _orText(_allergies.text, 'None'),
          onEdit: () => _edit('health'),
        ),
        _ReviewCard(
          title: 'Food',
          text: [
            _prefs.map((p) => _labelFor(_diet, p)).join(' · '),
            '$_meals meals a day',
            if (_fasting.text.trim().isNotEmpty) 'Fasting: ${_fasting.text.trim()}',
          ].where((e) => e.isNotEmpty).join('\n'),
          onEdit: () => _edit('food'),
        ),
        _ReviewCard(
          title: 'For your dietitian',
          text: _orText(
              [
                if (_meds.text.trim().isNotEmpty) 'Medicines: ${_meds.text.trim()}',
                if (_family.text.trim().isNotEmpty) 'Family: ${_family.text.trim()}',
                if (_surgeries.text.trim().isNotEmpty) 'Surgeries: ${_surgeries.text.trim()}',
              ].join('\n'),
              'Nothing added'),
          onEdit: () => _edit('dietitian'),
        ),
      ],
      if (_hasWorkout)
        _ReviewCard(
          title: 'Workout',
          text: [
            _orText(_labelFor(_fitness, _fitnessLevel), 'Not set'),
            if (_injuries.text.trim().isNotEmpty) 'Avoid: ${_injuries.text.trim()}',
          ].join('\n'),
          onEdit: () => _edit('workout'),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...cards,
        SizedBox(height: 6.h),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _consent = !_consent),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  color: _consent ? OnboardingScaffold.green : Colors.white,
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: _consent
                        ? OnboardingScaffold.green
                        : OnboardingScaffold.radioBorder,
                    width: 2,
                  ),
                ),
                child: _consent
                    ? Icon(Icons.check_rounded, size: 15.sp, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'I agree FitHer uses my health information only to make my plan and keep my classes safe.',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      height: 1.45,
                      color: OnboardingScaffold.textSub),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── small widgets (same look as the signup screens) ─────────────────

class _OptionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;
  const _OptionCard({
    required this.emoji,
    required this.title,
    this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: selected
                ? OnboardingScaffold.optionSelectedBg
                : OnboardingScaffold.optionBg,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
                color: selected ? OnboardingScaffold.green : Colors.transparent,
                width: 2),
          ),
          child: Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: 24.sp)),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: OnboardingScaffold.textDark)),
                    if (sub != null)
                      Text(sub!,
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w300,
                              color: OnboardingScaffold.textMuted)),
                  ],
                ),
              ),
              Container(
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? OnboardingScaffold.green : Colors.transparent,
                  border: Border.all(
                      color: selected
                          ? OnboardingScaffold.green
                          : OnboardingScaffold.radioBorder,
                      width: 2),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 14.sp, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool center;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: center ? Alignment.center : null,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: selected
              ? OnboardingScaffold.optionSelectedBg
              : OnboardingScaffold.optionBg,
          borderRadius: BorderRadius.circular(40.r),
          border: Border.all(
              color: selected ? OnboardingScaffold.green : Colors.transparent,
              width: 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.5.sp,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: OnboardingScaffold.textDark,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _Field({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13.5.sp,
          color: OnboardingScaffold.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.sp,
            color: OnboardingScaffold.textMuted),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(
              color: OnboardingScaffold.dividerLine, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide:
              const BorderSide(color: OnboardingScaffold.green, width: 1.5),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final double top;
  const _Label(this.text, {this.top = 16});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top.h, bottom: 8.h),
      child: Text(text,
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: OnboardingScaffold.textDark)),
    );
  }
}

class _Round extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Round({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38.w,
        height: 38.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: OnboardingScaffold.dividerLine, width: 1.5),
        ),
        child: Icon(icon, size: 18.sp, color: OnboardingScaffold.textDark),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final String text;
  final VoidCallback onEdit;
  const _ReviewCard({required this.title, required this.text, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 10.w, 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: OnboardingScaffold.dividerLine, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: OnboardingScaffold.textDark)),
                SizedBox(height: 2.h),
                Text(text,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.sp,
                        height: 1.45,
                        color: OnboardingScaffold.textSub)),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onEdit,
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Text('Edit',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: OnboardingScaffold.green)),
            ),
          ),
        ],
      ),
    );
  }
}
