import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../UI/consultation_module/booking/book_consultation_sheet.dart';
import '../../UI/consultation_module/popups/photo_privacy_notice_sheet.dart';
import '../../UI/plans_module/all_plans.dart';
import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../paid_home_v2/set_target_weight_modal.dart';
import '../../data/models/progress_v2/measurement_entry.dart';
import '../../helper/device_only_photo_picker.dart';
import '../../values/constants.dart';
import '../toasts.dart';
import '../v2/rating_star_row.dart';
import '../v2/v2_bottom_sheet.dart';
import '../v2/v2_buttons.dart';
import '../v2/v2_slider_input.dart';

/// One weekly check-in (Oct 2026). Replaces the Day 7 review, Day 15
/// progress and Day 30 progress pop-ups.
///
/// The server decides everything about the week
/// (GET /users/weekly-checkin/state, helper/weeklyCheckin.js):
///   label     week1 | weekly | halfway | end
///   sections  diet / workout plan questions (week 1 + milestone weeks),
///             milestone "halfway" or "end"
///   last      the values from last time (or her start from sign-up)
///
/// Every week: weight (required) + measurements (optional), shown as two
/// rows: last time on top (read-only), this week below (starts as a copy;
/// she changes what moved), then one tap for "How was your week?".
/// Halfway: saves, then "Pick a time" opens "Book a follow-up".
/// End of package: "See renewal plans".
class WeeklyCheckinSheet extends StatefulWidget {
  const WeeklyCheckinSheet({super.key, required this.state, required this.result, this.logOnly = false});

  final WeeklyCheckinState state;
  final WeeklyCheckinResult result;

  /// "Log measurements" any time: weight + measurements only, no
  /// questions (POST /users/weekly-checkin/measurements).
  final bool logOnly;

  /// Loads her check-in state. Null when it can't be loaded.
  static Future<WeeklyCheckinState?> loadState() async {
    try {
      final token = Get.find<AuthController>()
              .sharedPreferences
              .getString(Constants.accessToken) ??
          '';
      if (token.isEmpty) return null;
      final r = await Get.find<ApiProvider>().getData(
        Constants.weeklyCheckinState,
        headers: {'accessToken': token},
      );
      final body = r.body;
      if (body is! Map || '${body['status']}' != '1' || body['data'] is! Map) {
        return null;
      }
      return WeeklyCheckinState.fromJson(Map<String, dynamic>.from(body['data']));
    } catch (e) {
      debugPrint('[weekly_checkin] state: $e');
      return null;
    }
  }

  /// Her weigh-ins and measurements, oldest first (Progress tab, PDF).
  /// Empty when it can't be loaded.
  static Future<List<MeasurementEntry>> loadHistory() async {
    try {
      final token = Get.find<AuthController>()
              .sharedPreferences
              .getString(Constants.accessToken) ??
          '';
      if (token.isEmpty) return const [];
      final r = await Get.find<ApiProvider>()
          .getData(Constants.weeklyCheckinHistory, headers: {'accessToken': token});
      final body = r.body;
      final rows = (body is Map && '${body['status']}' == '1' && body['data'] is Map)
          ? body['data']['rows']
          : null;
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((e) => MeasurementEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('[weekly_checkin] history: $e');
      return const [];
    }
  }

  /// Opens this week's check-in (Home card, push, "Do my check-in").
  /// Returns true when she saved it.
  static Future<bool> open() async {
    final state = await loadState();
    if (state == null) {
      CustomToast.failToast(msg: "Couldn't load your check-in. Please try again.");
      return false;
    }
    if (!state.due) {
      if (state.reason == 'too_early' && state.nextOn != null) {
        CustomToast.successToast(
            msg: 'Your first check-in opens on ${DateFormat('d MMM').format(state.nextOn!.toLocal())}');
      } else if (state.checkinDay != null) {
        CustomToast.successToast(msg: 'Your check-in is done for this week 💚');
      }
      return false;
    }
    final result = WeeklyCheckinResult();
    await V2BottomSheet.show<void>(
      title: state.title,
      child: WeeklyCheckinSheet(state: state, result: result),
    );
    if (result.wantsTarget) await _openTarget();
    return result.saved;
  }

  /// After a weigh-in, ONCE: a Lose / Gain weight woman with no target
  /// weight is asked if she wants to set one (Oct 2026). Oct 2026 v2: asked
  /// as a small card on the "Saved" screen, not a second sheet.
  static Future<bool> targetAskDue() async {
    try {
      if (!Get.isRegistered<PaidHomeController>()) return false;
      final prefs = Get.find<AuthController>().sharedPreferences;
      final uid = prefs.getString(Constants.userId) ?? '';
      if (prefs.getBool('target_ask_after_weighin_$uid') == true) return false;
      final paid = Get.find<PaidHomeController>();
      await paid.loadDashboard();
      final d = paid.dashboard.value;
      final g = d?.user?.mainGoal;
      if (d == null || (g != 'Lose weight' && g != 'Gain weight')) return false;
      return d.goal?.targetWeightKg == null;
    } catch (_) {
      return false;
    }
  }

  /// Marks the question as asked (shown once per user).
  static Future<void> markTargetAsked() async {
    try {
      final prefs = Get.find<AuthController>().sharedPreferences;
      final uid = prefs.getString(Constants.userId) ?? '';
      await prefs.setBool('target_ask_after_weighin_$uid', true);
    } catch (_) {}
  }

  static Future<void> _openTarget() async {
    try {
      if (!Get.isRegistered<PaidHomeController>()) return;
      final d = Get.find<PaidHomeController>().dashboard.value;
      final c = Get.context;
      if (d != null && c != null) await SetTargetWeightModal.show(context: c, dashboard: d);
    } catch (e) {
      debugPrint('[weekly_checkin] target: $e');
    }
  }

  /// "Log measurements" (My reports, Home weight card). If this week's
  /// check-in is due she gets the check-in itself (it has the same
  /// measurements); otherwise just weight + measurements.
  /// Returns true when she saved.
  static Future<bool> logMeasurements() async {
    final state = await loadState();
    if (state == null) {
      CustomToast.failToast(msg: "Couldn't load your measurements. Please try again.");
      return false;
    }
    if (state.due) return open();
    final result = WeeklyCheckinResult();
    await V2BottomSheet.show<void>(
      title: 'Log measurements',
      child: WeeklyCheckinSheet(state: state, result: result, logOnly: true),
    );
    if (result.wantsTarget) await _openTarget();
    return result.saved;
  }

  @override
  State<WeeklyCheckinSheet> createState() => _WeeklyCheckinSheetState();
}

class WeeklyCheckinResult {
  bool saved = false;
  // "Set target" tapped on the Saved screen: open the target sheet once
  // the check-in sheet has closed (no stacking).
  bool wantsTarget = false;
}

/// Server state for the check-in (see helper/weeklyCheckin.js).
class WeeklyCheckinState {
  WeeklyCheckinState({
    required this.due,
    this.reason,
    this.label,
    this.checkinDay,
    this.planType,
    this.diet = false,
    this.workout = false,
    this.milestone,
    this.endOfPackage = false,
    this.start,
    this.last,
    this.checkinsDone = 0,
    this.nextOn,
  });

  final bool due;
  final String? reason;
  final String? label; // week1 | weekly | halfway | end
  final int? checkinDay;
  final String? planType;
  final bool diet;
  final bool workout;
  final String? milestone; // halfway | end
  final bool endOfPackage;
  final Measurements? start;
  final Measurements? last;
  final int checkinsDone;
  final DateTime? nextOn;

  factory WeeklyCheckinState.fromJson(Map<String, dynamic> j) {
    final s = j['sections'] is Map ? Map<String, dynamic>.from(j['sections']) : const {};
    return WeeklyCheckinState(
      due: j['due'] == true,
      reason: j['reason']?.toString(),
      label: j['label']?.toString(),
      checkinDay: (j['checkinDay'] as num?)?.toInt(),
      planType: j['planType']?.toString(),
      diet: s['diet'] == true,
      workout: s['workout'] == true,
      milestone: s['milestone']?.toString(),
      endOfPackage: j['endOfPackage'] == true,
      start: Measurements.fromJson(j['start']),
      last: Measurements.fromJson(j['last']),
      checkinsDone: (j['checkinsDone'] as num?)?.toInt() ?? 0,
      nextOn: DateTime.tryParse('${j['nextOn'] ?? ''}'),
    );
  }

  bool get hasPlanQuestions => diet || workout;

  /// Small label above the title.
  String get eyebrow {
    switch (label) {
      case 'week1':
        return 'Week 1 check-in · 3 min';
      case 'halfway':
        return 'Day $checkinDay · halfway check-in';
      case 'end':
        return endOfPackage ? 'End-of-plan check-in' : 'Day $checkinDay check-in';
      default:
        return 'Weekly check-in · day $checkinDay';
    }
  }

  /// Sheet title.
  String get title {
    switch (label) {
      case 'week1':
        return 'How was your first week?';
      case 'halfway':
        return 'Halfway there!';
      case 'end':
        return endOfPackage ? 'End-of-plan check-in' : 'How did this month go?';
      default:
        return 'How did this week go?';
    }
  }

  /// Home card: title + subtitle.
  String get cardTitle {
    switch (label) {
      case 'week1':
        return 'How was your first week?';
      case 'halfway':
        return 'Halfway there!';
      case 'end':
        return endOfPackage ? 'See how far you\'ve come' : 'Your day $checkinDay check-in';
      default:
        return "Log this week's weight";
    }
  }

  String get cardSubtitle {
    switch (label) {
      case 'week1':
        return 'Your dietitian uses this to tune your plan.';
      case 'halfway':
        return 'Share your progress to unlock your follow-up call.';
      case 'end':
        return "Share your progress and plan what's next.";
      default:
        final w = last?.weightKg;
        return w == null
            ? 'Weight and measurements, about 1 minute.'
            : 'Last time ${_fmt(w)} kg · ${DateFormat('d MMM').format(last!.date!.toLocal())}';
    }
  }

  String get cardEyebrow {
    switch (label) {
      case 'week1':
        return 'Week 1 check-in · 3 min';
      case 'halfway':
        return 'Halfway check-in · 3 min';
      case 'end':
        return endOfPackage ? 'End-of-plan check-in · 3 min' : 'Check-in · 3 min';
      default:
        return 'Weekly check-in · 1 min';
    }
  }
}

class Measurements {
  Measurements({this.date, this.weightKg, this.waistCm, this.hipsCm, this.chestCm, this.armsCm, this.thighsCm});

  final DateTime? date;
  final double? weightKg;
  final double? waistCm;
  final double? hipsCm;
  final double? chestCm;
  final double? armsCm;
  final double? thighsCm;

  static double? _d(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static Measurements? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return Measurements(
      date: DateTime.tryParse('${raw['date'] ?? ''}'),
      weightKg: _d(raw['weightKg']),
      waistCm: _d(raw['waistCm']),
      hipsCm: _d(raw['hipsCm']),
      chestCm: _d(raw['chestCm']),
      armsCm: _d(raw['armsCm']),
      thighsCm: _d(raw['thighsCm']),
    );
  }
}

String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class _Opt {
  const _Opt(this.value, this.label);
  final String value;
  final String label;
}

class _WeeklyCheckinSheetState extends State<WeeklyCheckinSheet> {
  // V2 palette (same as the Day 7 review / progress sheets).
  static const Color _ink = Color(0xFF1A3A22);
  static const Color _hero = Color(0xFF163220);
  static const Color _heroFg = Color(0xFFF2FAEE);
  static const Color _lime = Color(0xFF8FE07C);
  static const Color _sage = Color(0xFF5A7A56);
  static const Color _muted = Color(0xFF7A8C78);
  static const Color _accent = Color(0xFF6DC55A);
  static const Color _accentInk = Color(0xFF2F7A25);
  static const Color _wash = Color(0xFFF5FDF2);
  static const Color _line = Color(0xFFD8EDD4);
  static const Color _field = Color(0xFFC8DEC4);
  static const Color _hint = Color(0xFF9AB09A);
  static const Color _up = Color(0xFFB7791F);
  static const Color _warn = Color(0xFFE24B4A);
  static const Color _infoBg = Color(0xFFEAF7E4);

  static const String _photoBucket = 'progress';
  static const String _photoNoticeKey = 'photoPrivacyNoticeShown';

  WeeklyCheckinState get s => widget.state;

  // This week (starts as a copy of last time).
  late final Map<String, TextEditingController> _m = {
    'weightKg': TextEditingController(text: _start(s.last?.weightKg)),
    'waistCm': TextEditingController(text: _start(s.last?.waistCm)),
    'hipsCm': TextEditingController(text: _start(s.last?.hipsCm)),
    'chestCm': TextEditingController(text: _start(s.last?.chestCm)),
    'armsCm': TextEditingController(text: _start(s.last?.armsCm)),
    'thighsCm': TextEditingController(text: _start(s.last?.thighsCm)),
  };

  static String _start(double? v) => v == null ? '' : _fmt(v);

  int? _feel; // 1 Hard, 2 Okay, 3 Good, 4 Great
  bool _targetAsk = false; // "Set a target" card on the Saved screen

  // Required questions, so Save can say "2 of 4 answered" and scroll to
  // the first one she missed.
  final Map<String, GlobalKey> _qKeys = {
    for (final k in ['weight', 'hunger', 'difficulty', 'timing', 'pain', 'feel']) k: GlobalKey(),
  };

  /// Required questions in screen order, with whether each is answered.
  List<MapEntry<String, bool>> get _required {
    final w = _val('weightKg');
    return [
      MapEntry('weight', w != null && w >= 20 && w <= 500),
      if (s.diet) MapEntry('hunger', _hunger != null),
      if (s.workout) MapEntry('difficulty', _difficulty != null),
      if (s.workout) MapEntry('timing', _timingIssues != null),
      if (_pain) MapEntry('pain', _painWhere.text.trim().isNotEmpty),
      MapEntry('feel', _feel != null),
    ];
  }

  void _nudgeMissing() {
    final miss = _required.firstWhere((e) => !e.value, orElse: () => const MapEntry('', true));
    final ctx = _qKeys[miss.key]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.2);
    }
  }

  // Diet (Day 7 review questions).
  int _adherence = 70;
  final Set<String> _meals = {};
  String? _hunger;
  final Set<String> _sideEffects = {};
  // Workout.
  String? _difficulty;
  bool? _timingIssues;
  // Shared alerts.
  bool _pain = false;
  final TextEditingController _painWhere = TextEditingController();
  bool _severe = false;
  // Halfway / end.
  String? _clothes;
  int? _sleep;
  int? _satisfaction;
  List<String> _photos = const [];
  bool _addingPhoto = false;

  bool _busy = false;
  Map<String, dynamic>? _saved; // server reply once saved

  static const _mealOpts = [
    _Opt('breakfast', 'Breakfast'),
    _Opt('lunch', 'Lunch'),
    _Opt('dinner', 'Dinner'),
    _Opt('snacks', 'Snacks'),
    _Opt('none', 'None'),
  ];
  static const _hungerOpts = [
    _Opt('always_hungry', 'Always hungry'),
    _Opt('just_right', 'Just right'),
    _Opt('too_full', 'Too full'),
  ];
  static const _sideOpts = [
    _Opt('bloating', 'Bloating'),
    _Opt('headaches', 'Headaches'),
    _Opt('cravings', 'Cravings'),
    _Opt('other', 'Other'),
    _Opt('none', 'None'),
  ];
  static const _difficultyOpts = [
    _Opt('too_easy', 'Too easy'),
    _Opt('just_right', 'Just right'),
    _Opt('too_hard', 'Too hard'),
  ];
  static const _clothesOpts = [
    _Opt('looser', 'Looser'),
    _Opt('same', 'Same'),
    _Opt('tighter', 'Tighter'),
  ];
  static const _feelOpts = [
    _Opt('1', '😕 Hard'),
    _Opt('2', '😐 Okay'),
    _Opt('3', '🙂 Good'),
    _Opt('4', '😍 Great'),
  ];

  @override
  void initState() {
    super.initState();
    if (s.milestone != null) _loadPhotos();
  }

  @override
  void dispose() {
    for (final c in _m.values) {
      c.dispose();
    }
    _painWhere.dispose();
    super.dispose();
  }

  double? _val(String key) {
    final t = _m[key]!.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  bool get _canSave {
    final w = _val('weightKg');
    if (widget.logOnly) {
      // At least one value; a weight, if given, must make sense.
      if (w != null && (w < 20 || w > 500)) return false;
      return _m.keys.any((k) => _val(k) != null);
    }
    if (w == null || w < 20 || w > 500) return false;
    if (_feel == null) return false;
    if (s.diet && _hunger == null) return false;
    if (s.workout && (_difficulty == null || _timingIssues == null)) return false;
    if (_pain && _painWhere.text.trim().isEmpty) return false;
    return true;
  }

  Map<String, dynamic> _body() => {
        for (final e in _m.entries)
          if (_val(e.key) != null) e.key: _val(e.key),
        'weekFeel': _feel,
        if (s.hasPlanQuestions) ...{
          'painReported': _pain,
          if (_pain) 'painLocation': _painWhere.text.trim(),
          'severeSideEffectsReported': _severe,
        },
        if (s.diet) ...{
          'adherencePct': _adherence,
          'mealsStruggled': _meals.toList(),
          'hungerLevel': _hunger,
          'sideEffects': _sideEffects.toList(),
        },
        if (s.workout) ...{
          'difficultyLevel': _difficulty,
          'sessionTimingIssues': _timingIssues ?? false,
        },
        if (s.milestone != null) ...{
          if (_clothes != null) 'clothesFit': _clothes,
          if (_sleep != null) 'sleepQuality': _sleep,
          if (_satisfaction != null) 'satisfaction': _satisfaction,
        },
      };

  Future<void> _save() async {
    if (!_canSave || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final token = Get.find<AuthController>()
              .sharedPreferences
              .getString(Constants.accessToken) ??
          '';
      final r = await Get.find<ApiProvider>().postData(
        widget.logOnly ? Constants.weeklyCheckinMeasurements : Constants.weeklyCheckinSave,
        body: widget.logOnly
            ? {for (final e in _m.entries) if (_val(e.key) != null) e.key: _val(e.key)}
            : _body(),
        headers: {'accessToken': token},
      );
      final body = r.body;
      if (body is! Map || '${body['status']}' != '1') {
        CustomToast.failToast(
            msg: (body is Map ? body['message'] : null) ?? "Couldn't save. Please try again.");
        return;
      }
      widget.result.saved = true;
      if (!widget.logOnly) {
        // Same flag the old weekly sheet set (reminders).
        Get.find<AuthController>()
            .sharedPreferences
            .setInt('weekly_report_at', DateTime.now().millisecondsSinceEpoch);
      }
      if (!mounted) return;
      setState(() => _saved = body['data'] is Map ? Map<String, dynamic>.from(body['data']) : {});
      // Target question on this Saved screen (once per user).
      WeeklyCheckinSheet.targetAskDue().then((due) {
        if (!due || !mounted) return;
        WeeklyCheckinSheet.markTargetAsked();
        setState(() => _targetAsk = true);
      });
    } catch (e) {
      debugPrint('[weekly_checkin] save: $e');
      CustomToast.failToast(msg: "Couldn't save. Please try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Photos (stay on her phone, never uploaded) ──
  Future<void> _loadPhotos() async {
    final paths = await DeviceOnlyPhotoPicker.listBucket(_photoBucket);
    if (mounted) setState(() => _photos = paths);
  }

  Future<void> _addPhoto() async {
    setState(() => _addingPhoto = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_photoNoticeKey) ?? false)) {
        await PhotoPrivacyNoticeSheet.show();
        await prefs.setBool(_photoNoticeKey, true);
      }
      final source = await Get.bottomSheet<ImageSource>(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: _accent),
                title: const Text('Pick from gallery'),
                onTap: () => Get.back(result: ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: _accent),
                title: const Text('Take a new photo'),
                onTap: () => Get.back(result: ImageSource.camera),
              ),
            ]),
          ),
        ),
      );
      if (source == null) return;
      final path = await DeviceOnlyPhotoPicker.pickAndStore(bucket: _photoBucket, source: source);
      if (path != null) await _loadPhotos();
    } finally {
      if (mounted) setState(() => _addingPhoto = false);
    }
  }

  // ── After saving ──
  Future<void> _bookFollowUp() async {
    Get.back<dynamic>();
    final ctrl = Get.find<DietPlanUserController>();
    await ctrl.loadBookingContext(refresh: true);
    final ctx = ctrl.bookingContext.value;
    if (ctx != null && ctx.canBook) {
      await BookConsultationSheet.show(
        popupVariable: 'POPUP_BOOK_FOLLOWUP_CONSULTATION',
        dietitianId: ctx.dietitianId!,
        userId: ctx.userId!,
        userPlanId: ctx.userPlanId!,
        kind: 'followup',
      );
    } else {
      CustomToast.successToast(msg: 'Your follow-up is open. Book it from the Diet tab.');
    }
  }

  void _seePlans() {
    Get.back<dynamic>();
    Get.to<dynamic>(() => OurPlansScreen());
  }

  @override
  Widget build(BuildContext context) {
    if (_saved != null) return _done();
    if (widget.logOnly) return _logOnlyBody();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.eyebrow.toUpperCase(), style: _eyebrowStyle(_accent)),
        if (s.label == 'halfway' || s.label == 'week1') ...[
          const SizedBox(height: 4),
          Text(
            s.label == 'halfway'
                ? 'Your dietitian uses this to plan your next 15 days.'
                : 'Your dietitian uses this to tune your plan.',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: _muted, height: 1.45),
          ),
        ],
        const SizedBox(height: 12),
        if (_sinceStart() != null) ...[_sinceBand(), const SizedBox(height: 10)],
        _lastRow(),
        const SizedBox(height: 10),
        _thisWeek(),
        if (s.diet) ..._dietSection(),
        if (s.workout) ..._workoutSection(),
        if (s.hasPlanQuestions) ..._alertsSection(),
        if (s.milestone != null) ..._milestoneSection(),
        const SizedBox(height: 18),
        _label('How was your week?', key: _qKeys['feel']),
        const SizedBox(height: 8),
        _pills(_feelOpts, _feel == null ? const {} : {'$_feel'}, (v) => setState(() => _feel = int.parse(v))),
        const SizedBox(height: 22),
        V2PrimaryButton(
          label: _canSave
              ? (s.milestone == 'halfway'
                  ? 'Save & book my follow-up'
                  : (s.milestone == 'end' && s.endOfPackage ? 'Save & see renewal plans' : 'Save check-in'))
              : '${_required.where((e) => e.value).length} of ${_required.length} answered · Next →',
          busy: _busy,
          onPressed: _busy ? null : (_canSave ? _save : _nudgeMissing),
        ),
        const SizedBox(height: 8),
        V2GhostButton(label: 'Later', onPressed: _busy ? null : () => Get.back<dynamic>()),
      ],
    );
  }

  /// "Log measurements": the two rows only.
  Widget _logOnlyBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Update what changed. Your weekly check-in uses these too.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: _muted, height: 1.45),
        ),
        const SizedBox(height: 12),
        if (_sinceStart() != null) ...[_sinceBand(), const SizedBox(height: 10)],
        if (s.last != null || s.start != null) ...[_lastRow(), const SizedBox(height: 10)],
        _thisWeek(),
        const SizedBox(height: 22),
        V2PrimaryButton(
          label: 'Save measurements',
          busy: _busy,
          onPressed: _canSave ? _save : null,
        ),
        const SizedBox(height: 8),
        V2GhostButton(label: 'Later', onPressed: _busy ? null : () => Get.back<dynamic>()),
      ],
    );
  }

  // ── Rows ──
  double? _sinceStart() {
    final a = s.start?.weightKg;
    final b = s.last?.weightKg;
    if (a == null || b == null || s.checkinsDone == 0) return null;
    return b - a;
  }

  Widget _sinceBand() {
    final d = _sinceStart()!;
    final sign = d > 0 ? '+' : (d < 0 ? '−' : '');
    final date = s.start?.date;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: _hero, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const Expanded(
          child: Text('Since you started',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: _heroFg)),
        ),
        Text('$sign${_fmt(d.abs())} kg',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: _lime)),
        if (date != null) ...[
          const SizedBox(width: 10),
          Text('since ${DateFormat('d MMM').format(date.toLocal())}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: _heroFg)),
        ],
      ]),
    );
  }

  Widget _lastRow() {
    final fromStart = s.checkinsDone == 0 && !widget.logOnly;
    final v = fromStart ? (s.start ?? s.last) : s.last;
    String show(double? x, String unit) => x == null ? '—' : '${_fmt(x)} $unit';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _wash, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(fromStart ? 'START · FROM SIGN-UP' : 'LAST TIME', style: _eyebrowStyle(_sage))),
          if (v?.date != null)
            Text(DateFormat('d MMM').format(v!.date!.toLocal()), style: _eyebrowStyle(_sage)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 8, children: [
          _valueCell('Weight', show(v?.weightKg, 'kg')),
          _valueCell('Waist', show(v?.waistCm, 'cm')),
          _valueCell('Hips', show(v?.hipsCm, 'cm')),
          if (v?.chestCm != null) _valueCell('Chest', show(v?.chestCm, 'cm')),
          if (v?.armsCm != null) _valueCell('Arms', show(v?.armsCm, 'cm')),
          if (v?.thighsCm != null) _valueCell('Thighs', show(v?.thighsCm, 'cm')),
        ]),
      ]),
    );
  }

  Widget _valueCell(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _sage)),
        Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
      ]);

  Widget _thisWeek() {
    return Container(
      key: widget.logOnly ? null : _qKeys['weight'],
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _accent, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
                widget.logOnly
                    ? 'TODAY · CHANGE WHAT MOVED'
                    : (s.checkinsDone == 0 ? 'THIS WEEK' : 'THIS WEEK · CHANGE WHAT MOVED'),
                style: _eyebrowStyle(_accentInk)),
          ),
          Text(DateFormat('d MMM').format(DateTime.now()), style: _eyebrowStyle(_accentInk)),
        ]),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.25,
          children: [
            _input('weightKg', widget.logOnly ? 'Weight · kg' : 'Weight · kg *', s.last?.weightKg,
                required: !widget.logOnly),
            _input('waistCm', 'Waist · cm', s.last?.waistCm),
            _input('hipsCm', 'Hips · cm', s.last?.hipsCm),
            _input('chestCm', 'Chest · cm', s.last?.chestCm),
            _input('armsCm', 'Arms · cm', s.last?.armsCm),
            _input('thighsCm', 'Thighs · cm', s.last?.thighsCm),
          ],
        ),
      ]),
    );
  }

  Widget _input(String key, String label, double? last, {bool required = false}) {
    final now = _val(key);
    Widget? change;
    if (now != null && last != null && s.checkinsDone > 0) {
      final d = now - last;
      if (d.abs() < 0.05) {
        change = const Text('same', style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: _hint));
      } else {
        change = Text('${d > 0 ? '+' : '−'}${_fmt(d.abs())}',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: d < 0 ? _accentInk : _up));
      }
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: required ? _accent : _field),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: _sage), maxLines: 1),
        Expanded(
          child: TextField(
            controller: _m[key],
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: _ink),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'add',
              hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: _hint),
              contentPadding: EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ),
        if (change != null) change,
      ]),
    );
  }

  // ── Sections ──
  List<Widget> _dietSection() => [
        _section('🥗 Your diet plan'),
        _label('How much of the plan did you follow?'),
        const SizedBox(height: 8),
        V2SliderInput(value: _adherence, onChanged: (v) => setState(() => _adherence = v)),
        const SizedBox(height: 14),
        _label('Meals you struggled with'),
        const SizedBox(height: 8),
        _pills(_mealOpts, _meals, (v) => setState(() => _toggleMulti(_meals, v))),
        const SizedBox(height: 14),
        _label('Hunger', key: _qKeys['hunger']),
        const SizedBox(height: 8),
        _pills(_hungerOpts, _hunger == null ? const {} : {_hunger!}, (v) => setState(() => _hunger = v)),
        const SizedBox(height: 14),
        _label('Side effects'),
        const SizedBox(height: 8),
        _pills(_sideOpts, _sideEffects, (v) => setState(() => _toggleMulti(_sideEffects, v))),
      ];

  List<Widget> _workoutSection() => [
        _section('🏋️ Your workouts'),
        _label('Difficulty', key: _qKeys['difficulty']),
        const SizedBox(height: 8),
        _pills(_difficultyOpts, _difficulty == null ? const {} : {_difficulty!}, (v) => setState(() => _difficulty = v)),
        const SizedBox(height: 14),
        _label('Did class timings work?', key: _qKeys['timing']),
        const SizedBox(height: 8),
        _pills(
          const [_Opt('yes', 'Yes'), _Opt('no', 'No')],
          _timingIssues == null ? const {} : {_timingIssues! ? 'no' : 'yes'},
          (v) => setState(() => _timingIssues = v == 'no'),
        ),
      ];

  List<Widget> _alertsSection() => [
        const SizedBox(height: 14),
        _label('Any pain beyond normal?', key: _qKeys['pain']),
        const SizedBox(height: 8),
        _pills(const [_Opt('no', 'No'), _Opt('yes', 'Yes')], {_pain ? 'yes' : 'no'}, (v) {
          setState(() {
            _pain = v == 'yes';
            if (!_pain) _painWhere.clear();
          });
        }, warnValue: 'yes'),
        if (_pain) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _painWhere,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: _ink),
            decoration: InputDecoration(
              hintText: 'Where? (e.g. lower back, knee)',
              hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _hint),
              filled: true,
              fillColor: _wash,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _field)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _field)),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _label('Any severe reactions or side effects?'),
        const SizedBox(height: 8),
        _pills(const [_Opt('no', 'No'), _Opt('yes', 'Yes')], {_severe ? 'yes' : 'no'},
            (v) => setState(() => _severe = v == 'yes'),
            warnValue: 'yes'),
      ];

  List<Widget> _milestoneSection() => [
        _section(s.milestone == 'halfway' ? '⭐ Halfway check' : '⭐ End-of-plan check'),
        _label('Clothes are fitting'),
        const SizedBox(height: 8),
        _pills(_clothesOpts, _clothes == null ? const {} : {_clothes!}, (v) => setState(() => _clothes = v)),
        const SizedBox(height: 14),
        _label('Sleep'),
        const SizedBox(height: 6),
        RatingStarRow(value: _sleep, size: 30, onChanged: (v) => setState(() => _sleep = v)),
        const SizedBox(height: 12),
        _label('How happy are you with your progress?'),
        const SizedBox(height: 6),
        RatingStarRow(value: _satisfaction, size: 30, onChanged: (v) => setState(() => _satisfaction = v)),
        const SizedBox(height: 14),
        _label('Photos (optional) · stay on your phone'),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: _addingPhoto ? null : _addPhoto,
                child: Container(
                  width: 64,
                  decoration: BoxDecoration(
                    color: _wash,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _field),
                  ),
                  child: _addingPhoto
                      ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                      : const Icon(Icons.add_a_photo_outlined, color: _accent),
                ),
              ),
              for (final p in _photos.take(6)) ...[
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(p), width: 64, height: 64, fit: BoxFit.cover),
                ),
              ],
            ],
          ),
        ),
      ];

  void _toggleMulti(Set<String> set, String v) {
    // "None" can't be picked with anything else.
    if (v == 'none') {
      set
        ..clear()
        ..add('none');
      return;
    }
    set.remove('none');
    if (!set.remove(v)) set.add(v);
  }

  // ── Done ──
  Widget _done() {
    final d = _saved ?? const {};
    double? n(Object? v) => v is num ? v.toDouble() : null;
    String kg(double x) => '${x > 0 ? '+' : (x < 0 ? '−' : '')}${_fmt(x.abs())} kg';
    final week = n(d['changeThisWeek']);
    final total = n(d['changeSinceStart']);
    final line = [
      if (week != null && s.checkinsDone > 0) '${kg(week)} this week',
      if (total != null) '${kg(total)} since you started',
    ].join(' · ');
    final followup = d['followupOpen'] == true;
    final renew = d['milestone'] == 'end' && d['endOfPackage'] == true;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: _infoBg, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: _accent, size: 36),
        ),
      ),
      const SizedBox(height: 12),
      const Text('Saved, thank you',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
      if (line.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(line,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _muted)),
      ],
      if (followup) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: _infoBg, borderRadius: BorderRadius.circular(12)),
          child: const Text('Your follow-up call is now open',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: _accentInk)),
        ),
      ],
      if (_targetAsk) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          child: Row(children: [
            const Text('🎯', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Set a target to see your progress',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
            ),
            TextButton(
              onPressed: () {
                widget.result.wantsTarget = true;
                Get.back<dynamic>();
              },
              child: const Text('Set target',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: _accent)),
            ),
            IconButton(
              tooltip: 'Not now',
              onPressed: () => setState(() => _targetAsk = false),
              icon: const Icon(Icons.close_rounded, size: 18, color: _muted),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 20),
      if (followup)
        V2PrimaryButton(label: 'Pick a time', onPressed: _bookFollowUp)
      else if (renew)
        V2PrimaryButton(label: 'See renewal plans', onPressed: _seePlans)
      else
        V2PrimaryButton(label: 'Done', onPressed: () => Get.back<dynamic>()),
      if (followup || renew) ...[
        const SizedBox(height: 8),
        V2GhostButton(label: 'Later', onPressed: () => Get.back<dynamic>()),
      ],
    ]);
  }

  // ── Small pieces ──
  TextStyle _eyebrowStyle(Color c) =>
      TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c);

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))),
          child: Text(text,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w700, color: _hero)),
        ),
      );

  Widget _label(String text, {Key? key}) => Text(text,
      key: key,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: _ink));

  Widget _pills(List<_Opt> opts, Set<String> selected, ValueChanged<String> onTap, {String? warnValue}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in opts)
          GestureDetector(
            onTap: () => onTap(o.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: selected.contains(o.value) ? (o.value == warnValue ? _warn : _accent) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected.contains(o.value) ? (o.value == warnValue ? _warn : _accent) : _field),
              ),
              child: Text(o.label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected.contains(o.value) ? Colors.white : _ink,
                  )),
            ),
          ),
      ],
    );
  }
}
