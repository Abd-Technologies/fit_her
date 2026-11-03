import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../data/models/diet_plan_v2/diet_plan_v2_models.dart';
import 'v2_buttons.dart';

const Color _kHeroDark = Color(0xFF163220);
const Color _kSage = Color(0xFF9AB09A);
const Color _kBodyMuted = Color(0xFF6F8B7A);
const Color _kAccent = Color(0xFF6DC55A);
const Color _kAccentDark = Color(0xFF4FA642);
const Color _kCardBorder = Color(0xFFD8EDD4);
const Color _kLuteal = Color(0xFFFAC775);

/// Phase G.2 — small banner at the top of the Diet tab (above the day
/// strip) that tells the user where she is in her plan and surfaces a
/// follow-up consultation CTA in the last 2 days.
///
/// Two visual states:
///   • Normal — sage label, accent-green progress bar, text-only "Ends
///     {weekday, date}". No CTA — plenty of time before the plan rolls
///     over.
///   • Ending-soon (last 2 days) — luteal label + ⏳, luteal-tinted
///     progress bar, "Plan ends today / tomorrow" subtitle, and a
///     full-width V2DarkCtaButton "Book Follow-up Consultation".
///
/// Plan-ended is the existing F.1 "Plan Completed" empty state; this
/// widget returns SizedBox.shrink() in that case so the parent doesn't
/// have to special-case it.
class V2PlanTimelineBanner extends StatelessWidget {
  final DietPlanV2 plan;

  /// Today's day number relative to plan.activatedAt — 1-indexed. Pass
  /// null when the plan hasn't started yet (banner hides itself).
  final int? todaysDayNumber;

  /// Days remaining including today. Day 1 of 7 → 6. Day 7 of 7 → 0.
  final int daysRemaining;

  /// 0..1 progress through the plan. Day 1 → 0; Day N → (N-1)/N.
  final double progressPercent;

  /// True for the last two days (Day N or Day N-1).
  final bool endingSoon;

  /// Tapped from the "Book Follow-up Consultation" CTA. Only invoked
  /// in the ending-soon state. Caller threads the booking-context
  /// fallback (BookConsultationSheet vs OurPlansScreen).
  final VoidCallback? onBookFollowUp;

  /// Button label for her next step ("Book follow-up", "Do my check-in",
  /// "Renew my plan"...). Short so it fits small phones.
  final String ctaLabel;

  const V2PlanTimelineBanner({
    super.key,
    required this.plan,
    required this.todaysDayNumber,
    required this.daysRemaining,
    required this.progressPercent,
    required this.endingSoon,
    this.onBookFollowUp,
    this.ctaLabel = 'Book follow-up',
  });

  @override
  Widget build(BuildContext context) {
    if (todaysDayNumber == null) {
      // No plan day to anchor against — let the empty state handle it.
      return const SizedBox.shrink();
    }
    final headerColor = endingSoon ? _kLuteal : _kSage;
    final headerLabel = endingSoon ? '⏳ PLAN ENDING SOON' : 'YOUR PLAN';
    final fillColors = endingSoon
        ? const [_kLuteal, Color(0xFFE9B056)]
        : const [_kAccent, _kAccentDark];

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headerLabel,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: headerColor,
                letterSpacing: 0.84,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Day $todaysDayNumber of ${plan.planDays}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: _kHeroDark,
                letterSpacing: -0.2,
                height: 1.2,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              _subtitle(),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.sp,
                fontWeight:
                    endingSoon ? FontWeight.w600 : FontWeight.w500,
                color: endingSoon ? _kLuteal : _kBodyMuted,
                height: 1.4,
              ),
            ),
            SizedBox(height: 10.h),
            _ProgressBar(
              percent: progressPercent,
              fillColors: fillColors,
            ),
            if (endingSoon && onBookFollowUp != null) ...[
              SizedBox(height: 14.h),
              V2DarkCtaButton(
                label: ctaLabel,
                onPressed: onBookFollowUp,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "Ends Wed, May 14" / "Plan ends today" / "Plan ends tomorrow".
  /// Falls back to the date form if `daysRemaining > 1` (normal state).
  String _subtitle() {
    if (daysRemaining == 0) return 'Plan ends today';
    if (daysRemaining == 1) return 'Plan ends tomorrow';
    final activatedAt = plan.activatedAt;
    if (activatedAt == null) return 'Plan in progress';
    // End date in device-local; the controller does the user-tz
    // resolution upstream when computing daysRemaining, so we just
    // need the calendar string here. Day N is the last day, so
    // activatedAt + (planDays - 1) days = end date.
    final end = activatedAt
        .toLocal()
        .add(Duration(days: plan.planDays - 1));
    return 'Ends ${DateFormat('EEE, MMM d').format(end)}';
  }
}

class _ProgressBar extends StatelessWidget {
  final double percent;
  final List<Color> fillColors;

  const _ProgressBar({
    required this.percent,
    required this.fillColors,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6.h,
        color: _kCardBorder.withOpacity(0.5),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: percent.clamp(0.0, 1.0),
            heightFactor: 1.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: fillColors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
