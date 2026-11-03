import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/controllers/diet_plan_admin_controller/diet_plan_admin_controller.dart';
import '../../../data/controllers/dietitian_dashboard_controller/dietitian_dashboard_controller.dart';
import '../../../data/models/diet_plan_v2/meal_templates.dart';
import '../../../widgets/v2/v2_buttons.dart';
import 'plan_review_edit_screen.dart';

const Color _kCream = Color(0xFFEAF7E4);
const Color _kHeroDark = Color(0xFF163220);
const Color _kSage = Color(0xFF9AB09A);
const Color _kBodyMuted = Color(0xFF6F8B7A);
const Color _kAccent = Color(0xFF6DC55A);
const Color _kCardBorder = Color(0xFFD8EDD4);
const Color _kDanger = Color(0xFFE07B7B);

/// Phase E.3 — pre-selected client; configure planDays / mealsPerDay
/// and trigger AI generation. The screen is opened from a client-detail
/// surface, so [userId] / [userPlanId] / [userDisplayName] are required
/// constructor args (no in-screen user picker).
class GeneratePlanScreen extends StatefulWidget {
  final int userId;
  final int userPlanId;
  final String userDisplayName;
  final String? userProfileImage;

  const GeneratePlanScreen({
    super.key,
    required this.userId,
    required this.userPlanId,
    required this.userDisplayName,
    this.userProfileImage,
  });

  @override
  State<GeneratePlanScreen> createState() => _GeneratePlanScreenState();
}

class _GeneratePlanScreenState extends State<GeneratePlanScreen> {
  static const int _kMinDays = 3;
  static const int _kMaxDays = 14;
  // 14 days = the plan lasts until her Day-15 check-in / follow-up.
  static const int _kDefaultDays = 14;
  static const int _kDefaultMeals = 5;

  // Rotating progress messages while the AI call is in flight. Vertex/
  // Gemini generation for a full multi-day, multi-meal plan can
  // genuinely take up to ~2 minutes (see the 120s timeout on
  // DietPlanAdminRepository.generatePlan), so this ticks slowly enough
  // to still be moving near the end instead of sitting on "Almost
  // there…" for the better part of a minute looking frozen.
  static const List<String> _kProgressMessages = [
    'Asking Gemini for the best meals…',
    'Balancing calories and nutrition…',
    'Adding cycle-phase awareness…',
    'Double-checking allergies and preferences…',
    'Putting the days together…',
    'Almost there…',
  ];

  late final DietPlanAdminController _ctrl;
  int _planDays = _kDefaultDays;
  int _mealsPerDay = _kDefaultMeals;

  Timer? _progressTimer;
  int _progressIdx = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<DietPlanAdminController>();
    // Reset any stale state from a previous attempt — otherwise an old
    // error or success would render before we even fire.
    _ctrl.clearGenerationError();
    _ctrl.lastGeneratedPlan.value = null;
    _prefillMealsFromForm();
  }

  // Start from the meals-per-day the dietitian set on the client's form
  // during the consultation, instead of always defaulting to 5.
  Future<void> _prefillMealsFromForm() async {
    try {
      final raw = await Get.find<DietitianDashboardController>()
          .loadClientProfileRaw(widget.userId);
      final n = int.tryParse('${raw?['mealsPerDay'] ?? ''}');
      if (!mounted || n == null || n < 3 || n > 6) return;
      setState(() => _mealsPerDay = n);
    } catch (_) {
      // Keep the default. Generation still works without the form.
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startProgressTicker() {
    _progressIdx = 0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() {
        // Hold on the last message rather than looping — looping reads
        // as "stuck", a sticky last message reads as "almost done".
        if (_progressIdx < _kProgressMessages.length - 1) _progressIdx++;
      });
    });
  }

  void _stopProgressTicker() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> _onGenerate() async {
    _startProgressTicker();
    final plan = await _ctrl.generatePlan(
      userId: widget.userId,
      userPlanId: widget.userPlanId,
      planDays: _planDays,
      mealsPerDay: _mealsPerDay,
    );
    _stopProgressTicker();

    if (!mounted) return;
    if (plan != null) {
      // Replace (not stack) so Back from the review screen returns to
      // the originating client-detail surface, not the generate form.
      Get.off<dynamic>(() => PlanReviewEditScreen(dietPlanId: plan.id));
    }
    // Errors are rendered inline via Obx — nothing to do here.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCream,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _clientCard(),
                    SizedBox(height: 18.h),
                    _planDurationSection(),
                    SizedBox(height: 18.h),
                    _mealsPerDaySection(),
                    SizedBox(height: 22.h),
                    _generateBlock(),
                    SizedBox(height: 6.h),
                    Center(
                      child: V2GhostButton(
                        label: 'Cancel',
                        onPressed: () => Get.back<dynamic>(),
                        fullWidth: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top bar ────────────────────────────────────────────────────────────

  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 4.h, 16.w, 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back<dynamic>(),
            icon: const Icon(Icons.arrow_back, color: _kHeroDark, size: 22),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GENERATE',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: _kSage,
                    letterSpacing: 0.7,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'New Diet Plan',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: _kHeroDark,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section 1 — client card ────────────────────────────────────────────

  Widget _clientCard() {
    return _Card(
      child: Row(
        children: [
          _ClientAvatar(
            name: widget.userDisplayName,
            imageUrl: widget.userProfileImage,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CLIENT',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: _kSage,
                    letterSpacing: 0.7,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  widget.userDisplayName.isEmpty
                      ? 'User #${widget.userId}'
                      : widget.userDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: _kHeroDark,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section 2 — plan duration ──────────────────────────────────────────

  Widget _planDurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('PLAN DURATION'),
        SizedBox(height: 8.h),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$_planDays',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 32.sp,
                          fontWeight: FontWeight.w800,
                          color: _kHeroDark,
                          height: 1.0,
                        ),
                      ),
                      TextSpan(
                        text: _planDays == 1 ? ' day' : ' days',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: _kBodyMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _kAccent,
                  inactiveTrackColor: _kCardBorder,
                  thumbColor: _kAccent,
                  overlayColor: _kAccent.withOpacity(0.12),
                  trackHeight: 4,
                ),
                child: Slider(
                  min: _kMinDays.toDouble(),
                  max: _kMaxDays.toDouble(),
                  divisions: _kMaxDays - _kMinDays,
                  value: _planDays.toDouble(),
                  onChanged: _ctrl.isGenerating.value
                      ? null
                      : (v) => setState(() => _planDays = v.round()),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '14 days lasts until her Day-15 check-in',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  color: _kSage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Section 3 — meals per day ──────────────────────────────────────────

  Widget _mealsPerDaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('MEALS PER DAY'),
        SizedBox(height: 8.h),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: validMealsPerDay
                    .map(
                      (n) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: _MealsChip(
                            label: '$n',
                            selected: _mealsPerDay == n,
                            onTap: _ctrl.isGenerating.value
                                ? null
                                : () => setState(() => _mealsPerDay = n),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: 12.h),
              Text(
                mealTemplateHint(_mealsPerDay),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  color: _kBodyMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Section 4 — generate / busy / error ────────────────────────────────

  Widget _generateBlock() {
    return Obx(() {
      final busy = _ctrl.isGenerating.value;
      final err = _ctrl.generationError.value;

      if (busy) {
        return _busyState();
      }
      if (err != null) {
        return _errorState(err);
      }
      return V2PrimaryButton(
        label: 'Generate with AI',
        leadingIcon: Icons.auto_awesome,
        onPressed: _onGenerate,
      );
    });
  }

  Widget _busyState() {
    return _Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          children: [
            SizedBox(
              width: 32.w,
              height: 32.w,
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Generating your plan…',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: _kHeroDark,
              ),
            ),
            SizedBox(height: 6.h),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _kProgressMessages[_progressIdx],
                key: ValueKey(_progressIdx),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  color: _kBodyMuted,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: _kDanger, size: 18.w),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _kDanger,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        V2SecondaryButton(
          label: 'Try again',
          onPressed: () {
            _ctrl.clearGenerationError();
            _onGenerate();
          },
        ),
      ],
    );
  }
}

// ─── Local widgets ────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kHeroDark.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          color: _kSage,
          letterSpacing: 0.84,
        ),
      ),
    );
  }
}

class _MealsChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _MealsChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(vertical: 12.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _kAccent : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kAccent : _kCardBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : _kHeroDark,
          ),
        ),
      ),
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  const _ClientAvatar({required this.name, this.imageUrl});

  String get _initial {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = 52.w;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kCream,
        shape: BoxShape.circle,
        border: Border.all(color: _kAccent.withOpacity(0.32), width: 1.5),
      ),
      child: Text(
        _initial,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20.sp,
          fontWeight: FontWeight.w800,
          color: _kHeroDark,
        ),
      ),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}
