import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../UI/chat/widgets/chat_room.dart';
import '../../data/Repos/diet_plan_v2/diet_plan_user_repository.dart';
import '../../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../../widgets/toasts.dart';
import 'pill_button.dart';
import 'v2_buttons.dart';

const Color _kHeroDark = Color(0xFF163220);
const Color _kSage = Color(0xFF9AB09A);
const Color _kBodyMuted = Color(0xFF6F8B7A);
const Color _kAccent = Color(0xFF6DC55A);
const Color _kAmber = Color(0xFFC98A2C);
const Color _kCardBorder = Color(0xFFD8EDD4);

/// Shown between "consultation completed" and "plan delivered", so the
/// client always knows her plan is coming and when. Two looks:
///
///  * full    (Diet tab): replaces the "no plan yet, book a
///             consultation" empty state, which was wrongly telling a
///             client who had JUST finished her consultation to book one.
///  * compact (paid home): small self-hiding banner, same pattern and
///             visual language as PlanExpiryBanner.
///
/// Once the 48 hour window passes without a plan, the copy switches to a
/// warm apology with a way to reach her dietitian, so she never feels
/// forgotten.
class V2PlanPreparingCard extends StatelessWidget {
  final PlanPreparingV2 info;
  final bool compact;

  const V2PlanPreparingCard({
    super.key,
    required this.info,
    this.compact = false,
  });

  String get _who {
    final n = info.dietitianName?.trim() ?? '';
    return n.isEmpty ? 'Your dietitian' : n;
  }

  String get _dueText {
    final d = info.dueAt;
    if (d == null) return 'within 2 working days';
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day;
    final time = DateFormat('h:mm a').format(d);
    if (isToday) return 'today by $time';
    if (isTomorrow) return 'tomorrow by $time';
    return '${DateFormat('EEEE').format(d)} by $time';
  }

  Future<void> _messageDietitian() async {
    final id = info.dietitianId;
    if (id == null) {
      CustomToast.failToast(msg: 'Could not open chat right now');
      return;
    }
    try {
      final home = Get.find<HomeController>();
      final userMap = await home.getspecificUserFromFireStore(id.toString());
      final roomId = await home.makeRoomId(id.toString());
      Get.to(() => ChatRoom(
            chatRoomId: roomId,
            userMap: Map<String, dynamic>.from(userMap as Map),
            showBack: true,
          ));
    } catch (_) {
      CustomToast.failToast(msg: 'Could not open chat right now');
    }
  }

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompact() : _buildFull();
  }

  // ── Diet tab ─────────────────────────────────────────────────────────
  Widget _buildFull() {
    final isLate = info.delayed;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(isLate ? '💛' : '👩‍🍳',
                  style: TextStyle(fontSize: 48.sp)),
            ),
            SizedBox(height: 14.h),
            Center(
              child: Text(
                isLate ? 'TAKING A LITTLE LONGER' : 'PLAN BEING PREPARED',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: isLate ? _kAmber : _kSage,
                  letterSpacing: 0.84,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              isLate
                  ? "Sorry, your plan is running late"
                  : 'Your plan is on its way',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: _kHeroDark,
                letterSpacing: -0.2,
                height: 1.3,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              isLate
                  ? "We know you're waiting, and we're on it. $_who has been "
                      'reminded and our team is following up. The days you '
                      'waited will be added back to your plan, free.'
                  : '$_who is building your personalized meal plan from '
                      'your consultation. Expected $_dueText.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                color: _kBodyMuted,
                height: 1.5,
              ),
            ),
            SizedBox(height: 18.h),
            if (isLate)
              V2PrimaryButton(
                label: 'Message my dietitian',
                leadingIcon: Icons.chat_bubble_outline_rounded,
                onPressed: _messageDietitian,
              )
            else
              Center(
                child: V2GhostButton(
                  label: 'Message my dietitian',
                  onPressed: _messageDietitian,
                  fullWidth: false,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Paid home banner ────────────────────────────────────────────────
  Widget _buildCompact() {
    final isLate = info.delayed;
    final message = isLate
        ? "Your plan is running a little late. We're on it, and the days you waited will be added back to your plan."
        : 'Your plan is being prepared. Expected $_dueText.';
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kCardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(isLate ? '💛' : '🥗', style: TextStyle(fontSize: 14.sp)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: _kHeroDark,
                    ),
                  ),
                ),
              ],
            ),
            if (isLate) ...[
              SizedBox(height: 12.h),
              PrimaryPillButton(
                label: 'Message my dietitian',
                color: _kAmber,
                onTap: _messageDietitian,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Paid home slot: loads the booking context itself and hides unless
/// the client is waiting on a plan. Same self-hiding sibling pattern as
/// PlanExpiryBanner / PlanFrozenBanner.
class V2PlanPreparingBanner extends StatefulWidget {
  const V2PlanPreparingBanner({super.key});

  @override
  State<V2PlanPreparingBanner> createState() => _V2PlanPreparingBannerState();
}

class _V2PlanPreparingBannerState extends State<V2PlanPreparingBanner> {
  late final DietPlanUserController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<DietPlanUserController>();
    // Always refresh here: home is where she lands, so the countdown and
    // delayed state must be current.
    _ctrl.loadBookingContext(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final info = _ctrl.bookingContext.value?.planPreparing;
      if (info == null) return const SizedBox.shrink();
      return V2PlanPreparingCard(info: info, compact: true);
    });
  }
}
