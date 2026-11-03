import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../data/Repos/user_plan_repo/user_plan_repository.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../../data/models/user_plan/user_plan_item.dart';
import '../../helper/popup_manager.dart';
import '../../values/constants.dart';
import '../anim/check_draw.dart';
import '../anim/confetti.dart';
import '../anim/motion.dart';
import '../../UI/profile_setup/plan_personal_screens.dart';

/// One-time "Welcome to Fit Her" moment, shown on the paid home the first
/// time she opens it after a PAID plan was activated (slip approved /
/// plan started).
///
/// Rule: logged-in paid user, not on the free trial; her newest active
/// plan (from GET get_user_plans) is not a trial/system plan, not
/// cancelled, frozen or expired, and started (buyingDate) within the last
/// 3 days; and SharedPreferences has no `welcome_plan_<userPlanId>` yet.
/// The marker is written before showing, so it appears once per plan.
/// Any missing data or error -> nothing is shown.
class PlanWelcomeMoment {
  PlanWelcomeMoment._();

  static const String _kPrefix = 'welcome_plan_';
  static const Duration _kFreshFor = Duration(days: 3);

  static bool _checkedThisSession = false;
  static bool _open = false;

  static Future<void> maybeShow() async {
    if (_checkedThisSession || _open) return;
    _checkedThisSession = true;
    try {
      if (!Get.isRegistered<AuthController>()) return;
      final auth = Get.find<AuthController>();
      final user = auth.logInUser;
      if (user == null || user.status != true) return;
      if (Get.isRegistered<HomeController>() &&
          Get.find<HomeController>().isFreeTrialUser.value) {
        return;
      }
      final prefs = auth.sharedPreferences;
      final token = prefs.getString(Constants.accessToken) ?? '';
      if (token.isEmpty || !Get.isRegistered<UserPlanRepository>()) return;

      final res =
          await Get.find<UserPlanRepository>().getMyPlans(accessToken: token);
      final body = res.body;
      if (body is! Map || '${body['status']}' != '1') return;
      final raw = body['data'];
      if (raw is! List) return;

      final now = DateTime.now();
      UserPlanItem? fresh;
      Map? freshRow;
      for (final row in raw) {
        if (row is! Map) continue;
        final p = UserPlanItem.fromJson(Map<String, dynamic>.from(row));
        final title = (p.plan?.title ?? '').trim().toLowerCase();
        if (p.id == 0 || title.isEmpty) continue;
        if (title.contains('trial') || title.startsWith('system')) continue;
        if (p.cancelledAt != null || p.frozenAt != null) continue;
        if ((p.planStatus ?? '').toLowerCase() == 'expired') continue;
        final start = p.buyingDate;
        final end = p.expireDate;
        if (start == null || end == null || !end.isAfter(now)) continue;
        final age = now.difference(start.toLocal());
        if (age > _kFreshFor || age < const Duration(days: -1)) continue;
        if (fresh == null || start.isAfter(fresh.buyingDate!)) {
          fresh = p;
          freshRow = row;
        }
      }
      if (fresh == null) return;

      final key = '$_kPrefix${fresh.id}';
      if (prefs.getBool(key) == true) return;

      // Don't stack on top of another dialog/sheet (e.g. the "Successfully
      // Uploaded!" box when the slip was auto-approved): wait up to a
      // minute for it to close, else leave it for the next launch.
      bool busy() =>
          (Get.isDialogOpen ?? false) || (Get.isBottomSheetOpen ?? false);
      for (var i = 0; i < 30 && busy(); i++) {
        await Future.delayed(const Duration(seconds: 2));
      }
      if (busy()) {
        _checkedThisSession = false;
        return;
      }
      await Future.delayed(const Duration(milliseconds: 400));
      if (busy()) {
        _checkedThisSession = false;
        return;
      }

      final firstName = user.firstName.trim().split(RegExp(r'\s+')).first;
      final planTitle = (fresh.plan?.title ?? '').trim();
      final int? origDays = fresh.originalDurationDays;
      final int days = (origDays != null && origDays > 0)
          ? origDays
          : fresh.expireDate!.difference(fresh.buyingDate!).inDays;
      final line = _planLine(planTitle, days);
      final planType = _planTypeOf(freshRow, planTitle);

      // Pop-up manager, ESSENTIAL (Oct 2026): it's the moment she paid for
      // and only lasts 3 days, so it never waits for a turn, the 30-min
      // gap or the daily limit. It only waits for Home to be free, then
      // uses up this open's turn (nothing planned opens right after it).
      final shown = await PopupManager.runFirstLanding(
        'welcome',
        () async {
          await prefs.setBool(key, true);
          _open = true;
          await Get.dialog(
            _PlanWelcomeDialog(firstName: firstName, planLine: line, planType: planType),
            barrierDismissible: true,
            barrierColor: Colors.black.withValues(alpha: 0.45),
          );
        },
      );
      // Lost its turn: ask again on the next app open.
      if (!shown) _checkedThisSession = false;
    } catch (e) {
      debugPrint('[plan_welcome] skipped: $e');
    } finally {
      _open = false;
    }
  }

  /// diet | workout | combined, from the plan row (planType, then
  /// CategoryId 1/2/3), then the profile card, then the title.
  static String _planTypeOf(Map? row, String title) {
    final plan = row?['Plan'] ?? row?['plan'];
    if (plan is Map) {
      final pt = '${plan['planType'] ?? ''}'.toLowerCase();
      if (pt == 'diet' || pt == 'workout' || pt == 'combined') return pt;
      final cat = int.tryParse('${plan['CategoryId'] ?? plan['categoryId'] ?? ''}');
      if (cat == 1) return 'diet';
      if (cat == 2) return 'workout';
      if (cat == 3) return 'combined';
    }
    final t = title.toLowerCase();
    final d = t.contains('diet') || t.contains('nutrition');
    final w = t.contains('workout') || t.contains('fitness') || t.contains('class');
    if (d && w) return 'combined';
    if (w) return 'workout';
    if (d) return 'diet';
    return 'combined';
  }

  static String _planLine(String title, int days) {
    final hasPlanWord = title.toLowerCase().contains('plan');
    final name = title.isEmpty
        ? 'Your plan'
        : 'Your $title${hasPlanWord ? '' : ' plan'}';
    final span = days > 0 ? ' for $days days' : '';
    return '$name is active$span. Everything is unlocked for you.';
  }
}

class _PlanWelcomeDialog extends StatefulWidget {
  const _PlanWelcomeDialog({required this.firstName, required this.planLine, required this.planType});

  final String firstName;
  final String planLine;
  final String planType;

  @override
  State<_PlanWelcomeDialog> createState() => _PlanWelcomeDialogState();
}

class _PlanWelcomeDialogState extends State<_PlanWelcomeDialog> {
  static const Color _green = Color(0xFF6DC55A);
  static const Color _greenText = Color(0xFF3F9B35);
  static const Color _ink = Color(0xFF163220);
  static const Color _sage = Color(0xFF6F8B7A);

  bool _confetti = false;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    if (Motion.calm(context)) return;
    // Tick starts at 200 ms; confetti once it has drawn.
    Future.delayed(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => _confetti = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final calm = Motion.calm(context);
    final title = widget.firstName.isEmpty
        ? 'Welcome to Fit Her!'
        : 'Welcome to Fit Her, ${widget.firstName}!';

    Widget card = Container(
      width: 304,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FhCheckDraw(76, _green, delay: Duration(milliseconds: 200)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'PLAN ACTIVE',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: _greenText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.planLine,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              height: 1.5,
              color: _sage,
            ),
          ),
          const SizedBox(height: 16),
          // Same "Every day in Fit Her" list as the profile done screen.
          EverydayInFitHer(planType: widget.planType),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                "Let's start",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!calm) {
      card = card
          .animate()
          .fadeIn(duration: Motion.fast, curve: Motion.ease)
          .scale(
            begin: const Offset(0.94, 0.94),
            end: const Offset(1, 1),
            duration: Motion.normal,
            curve: Motion.ease,
          );
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            if (_confetti)
              const Positioned(
                top: 64,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FhConfettiBurst(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
