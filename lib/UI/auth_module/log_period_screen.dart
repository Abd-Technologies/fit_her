import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/Repos/cycle_repo/cycle_data_repository.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../values/constants.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/toasts.dart';

/// "Log my period" (Oct 2026): the same cycle questions and look as the
/// sign-up cycle page, prefilled with what she saved before. Saving a new
/// start date also teaches the hormonal engine her real cycle length
/// (backend helper/cycleLearning.js). Returns true when saved.
class LogPeriodScreen extends StatefulWidget {
  const LogPeriodScreen({super.key});

  @override
  State<LogPeriodScreen> createState() => _LogPeriodScreenState();
}

class _LogPeriodScreenState extends State<LogPeriodScreen> {
  bool _loading = true;
  bool _saving = false;
  DateTime _periodDate = DateTime.now();
  double _cycleLength = 28;
  String? _periodDuration = '3–5 days';
  String? _flowType;
  String? _isRegular;
  // Flow and regular start empty on a first log; Save counts them.
  final _flowKey = GlobalKey();
  final _regularKey = GlobalKey();
  int get _missing => (_flowType == null ? 1 : 0) + (_isRegular == null ? 1 : 0);

  void _nudge() {
    final ctx = (_flowType == null ? _flowKey : _regularKey).currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.2);
    }
  }

  String get _token =>
      Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Get.find<CycleDataRepository>().getCycleData(accessToken: _token);
      final body = r.body;
      var d = body is Map ? body['data'] : null;
      if (d is Map && d['cycleData'] is Map) d = d['cycleData'];
      if (d is Map) {
        final last = DateTime.tryParse('${d['lastPeriodDate'] ?? ''}');
        // Her saved date is the default only if it can still be picked.
        if (last != null && DateTime.now().difference(last).inDays <= 60) _periodDate = last;
        final len = num.tryParse('${d['averageCycleLength'] ?? ''}');
        if (len != null) _cycleLength = len.toDouble().clamp(21, 45);
        if (d['periodDuration'] is String) _periodDuration = d['periodDuration'];
        if (d['flowType'] is String) _flowType = d['flowType'];
        final reg = '${d['isRegular'] ?? ''}';
        _isRegular = reg == 'yes'
            ? '✓ Yes'
            : reg == 'no'
                ? '✗ No'
                : reg == 'not sure'
                    ? '? Not sure'
                    : null;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodDate.isAfter(now) ? now : _periodDate,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: OnboardingScaffold.green,
            onPrimary: Colors.white,
            onSurface: OnboardingScaffold.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _periodDate = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    bool ok = false;
    try {
      final r = await Get.find<CycleDataRepository>().saveCycleData(
        accessToken: _token,
        body: {
          'lastPeriodDate': DateFormat('yyyy-MM-dd').format(_periodDate),
          'averageCycleLength': _cycleLength.round(),
          'isRegular': _isRegular == '✓ Yes'
              ? 'yes'
              : _isRegular == '✗ No'
                  ? 'no'
                  : 'not sure',
          'periodDuration': _periodDuration,
          'flowType': _flowType,
          'dataProvided': 1,
        },
      );
      final b = r.body;
      ok = b is Map && '${b['status']}' == '1';
    } catch (_) {}
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      CustomToast.failToast(msg: "Couldn't save. Please try again.");
      return;
    }
    CustomToast.successToast(msg: 'Saved. Your hormonal engine has learned from it 💚');
    Get.back<bool>(result: true);
  }

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
    return OnboardingScaffold(
      questionLine1: 'Log your',
      questionLine2: 'period',
      subtitle: 'Your hormonal engine learns from every period you log',
      showProgressBar: false,
      showStepCounter: false,
      showBackButton: true,
      onBack: () => Get.back<bool>(result: false),
      buttonText: _saving
          ? 'Saving…'
          : _missing > 0
              ? '${5 - _missing} of 5 answered · Next →'
              : 'Save',
      onNext: _missing > 0 ? _nudge : _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Start date ──
          OnboardingScaffold.buildLabel('When did your ', 'period', ' start?'),
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: _pickDate,
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
                        DateFormat('MMMM d, yyyy').format(_periodDate),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: OnboardingScaffold.textDark,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Tap to change',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.sp,
                          color: OnboardingScaffold.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Text('📅', style: TextStyle(fontSize: 20.sp)),
                ],
              ),
            ),
          ),
          SizedBox(height: 20.h),

          // ── Cycle length ──
          OnboardingScaffold.buildLabel('Average ', 'cycle length?'),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: OnboardingScaffold.optionBg,
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
                          '${_cycleLength.round()}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w700,
                            color: OnboardingScaffold.textDark,
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
                      _cycleLength < 25
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
                    activeTrackColor: OnboardingScaffold.green,
                    inactiveTrackColor: OnboardingScaffold.radioBorder,
                    thumbColor: OnboardingScaffold.green,
                    overlayColor: OnboardingScaffold.green.withValues(alpha: 0.15),
                    trackHeight: 5.h,
                  ),
                  child: Slider(
                    value: _cycleLength,
                    min: 21,
                    max: 45,
                    divisions: 24,
                    onChanged: (v) => setState(() => _cycleLength = v),
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
              ],
            ),
          ),
          SizedBox(height: 20.h),

          // ── Days of bleeding ──
          OnboardingScaffold.buildLabel('How many ', 'days', ' do you bleed?'),
          SizedBox(height: 10.h),
          OnboardingScaffold.buildPillRow(
            options: const ['1–2 days', '3–5 days', '6–7 days', '8+ days'],
            selected: _periodDuration,
            onSelect: (v) => setState(() => _periodDuration = v),
          ),
          SizedBox(height: 20.h),

          // ── Flow ──
          KeyedSubtree(key: _flowKey, child: OnboardingScaffold.buildLabel('How ', 'heavy', ' is your flow?')),
          SizedBox(height: 10.h),
          OnboardingScaffold.buildPillRow(
            options: const ['Light', 'Moderate', 'Heavy'],
            selected: _flowType,
            onSelect: (v) => setState(() => _flowType = v),
          ),
          SizedBox(height: 20.h),

          // ── Regular ──
          KeyedSubtree(key: _regularKey, child: OnboardingScaffold.buildLabel('Are your periods ', 'regular', '?')),
          SizedBox(height: 10.h),
          OnboardingScaffold.buildYesNoRow(
            options: const ['✓ Yes', '✗ No', '? Not sure'],
            selected: _isRegular,
            onSelect: (v) => setState(() => _isRegular = v),
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }
}
