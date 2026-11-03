import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../UI/dashboard_module/bottom_bar_screen/bottom_bar_screen.dart';
import '../../UI/free_trail/trial_journey_screen.dart';
import '../../UI/free_trail/trial_summary_screen.dart';
import '../../UI/plans_module/all_plans.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import 'trial_recap_card.dart';

const Color _kHeroDark = Color(0xFF163220);
const Color _kHero2 = Color(0xFF24502F);
const Color _kAccent = Color(0xFF6DC55A);
const Color _kAmber = Color(0xFFF2B34B);

/// Top-of-home card for a free trial user on the paid home:
///   * "Day X of N · Free trial" + Upgrade, day segments
///   * class goal: "2 of 3 classes done"
///   * her next class, with a button to the live classes
/// Refreshes her trial progress whenever the app comes back to the
/// foreground (e.g. after a class), which is also what triggers the
/// "Class N of M done" celebration. Hides itself when no trial is running.
class V2TrialBanner extends StatefulWidget {
  const V2TrialBanner({super.key});

  @override
  State<V2TrialBanner> createState() => _V2TrialBannerState();
}

class _V2TrialBannerState extends State<V2TrialBanner> with WidgetsBindingObserver {
  final HomeController home = Get.find<HomeController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (home.trialLive.value && home.trialClassData.value == null) {
      home.loadTrialClasses();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && home.trialLive.value) {
      home.getMyTrialJourney();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final started = home.trialStartedAt.value;
      if (!home.trialLive.value || started == null) {
        return const SizedBox.shrink();
      }
      final total = home.trialDays.value;
      final endsAt = started.add(home.kTrialLength);
      final now = DateTime.now();
      // Calendar days, like her starter meal plan ("Day 3 of 3, Mon") and
      // the server's trial recap, so the day number never disagrees
      // between screens (Oct 2026).
      final startDay = DateTime(started.year, started.month, started.day);
      final today = DateTime(now.year, now.month, now.day);
      final day = (today.difference(startDay).inDays + 1).clamp(1, total);
      final lastDay = day >= total || endsAt.difference(now).inHours < 24;
      final endsToday = endsAt.year == now.year && endsAt.month == now.month && endsAt.day == now.day;
      final endTime = endsToday
          ? 'today at ${DateFormat('h:mm a').format(endsAt)}'
          : 'on ${DateFormat('EEE').format(endsAt)} at ${DateFormat('h:mm a').format(endsAt)}';
      final goal = home.classGoal.value;
      final attended = home.classesAttended.value;
      final goalDone = attended >= goal;
      home.trialClassData.value; // rebuild when classes load
      final next = home.nextTrialClass();

      final Widget banner = Padding(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
        child: GestureDetector(
          onTap: () => Get.to(() => const TrialJourneyScreen()),
          child: Container(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 14.w, 14.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kHeroDark, _kHero2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(lastDay ? '⏳' : '🎁', style: TextStyle(fontSize: 16.sp)),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Day $day of $total · Free trial',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      // Last day: her summary + offer. Before that: plans.
                      onTap: () => lastDay
                          ? Get.to(() => const TrialSummaryScreen())
                          : Get.to(() => OurPlansScreen()),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                        decoration: BoxDecoration(
                          color: lastDay ? _kAmber : _kAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Upgrade',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  children: List.generate(total, (i) {
                    final done = i < day;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i == total - 1 ? 0 : 5.w),
                        height: 5,
                        decoration: BoxDecoration(
                          color: done
                              ? (lastDay ? _kAmber : _kAccent)
                              : Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
                if (lastDay) ...[
                  SizedBox(height: 10.h),
                  Text(
                    'Your trial ends $endTime. Tap Upgrade to see your trial summary and your special offer.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      height: 1.45,
                      color: Colors.white.withOpacity(0.82),
                    ),
                  ),
                ],
                SizedBox(height: 12.h),
                // Class goal + next class
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(goalDone ? '🏆' : '💪', style: TextStyle(fontSize: 14.sp)),
                          SizedBox(width: 6.w),
                          Text(
                            goalDone
                                ? 'Class goal complete!'
                                : '$attended of $goal classes done',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          ...List.generate(goal, (i) => Container(
                                margin: EdgeInsets.only(left: 4.w),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: i < attended ? _kAccent : Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                              )),
                        ],
                      ),
                      if (next != null) ...[
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                next.label == 'Live now'
                                    ? 'Live now · ${next.data['type'] ?? 'Live class'}'
                                    : 'Next: ${next.label} · ${next.data['type'] ?? 'Live class'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12.sp,
                                  color: Colors.white.withOpacity(0.82),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Get.offAll(() => BottomBarScreen(index: 1)),
                              child: Text(
                                'See classes ›',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _kAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // Last trial day: what she did each day + Keep going (this banner
      // stays as the fallback if the recap can't load).
      return lastDay
          ? TrialRecapCard(key: ValueKey('recap_$day'), fallback: banner)
          : banner;
    });
  }
}
