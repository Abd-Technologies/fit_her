import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../UI/dashboard_module/profile_screen/profile_screen_user.dart';
import '../../data/Repos/plan_freeze_repo/plan_freeze_repository.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../values/constants.dart';
import 'pill_button.dart';
import 'unfreeze_confirm_dialog.dart';

const Color _kAccent = Color(0xFF6DC55A);
const Color _kFrozenBlue = Color(0xFF4A8FB8);
const Color _kCardBorder = Color(0xFFD8EDD4);
const Color _kHeroDark = Color(0xFF163220);

/// Self-hiding heads-up on the paid home screen for a plan that's
/// currently frozen/paused. Sibling of PlanExpiryBanner (renewal) and
/// V2Day7TriggerBanner (day-7 check-in) in paid_home_screen_v2.dart --
/// same self-hide-when-not-applicable pattern, own GET on mount.
///
/// Item #1 of the "what else needs to know about a frozen plan"
/// architecture pass: before this, freezing a plan only ever showed up
/// on the Profile screen -- the home screen (what a user actually opens
/// first after launching the app) had no idea the plan was paused at
/// all, so a frozen user landed on a home screen that looked exactly
/// like an active one.
///
/// This is the ONLY "your plan is paused" messaging on the home screen
/// (an earlier pass also had the hero repeat the message with its own
/// Unfreeze link -- reverted as redundant, see paid_hero_coming_up.dart).
///
/// Visual language matches `new screens/Profile_Final_3Screens.html`'s
/// actual subscription card (and its production Dart twin,
/// _subscriptionSecondaryButton/_subscriptionPrimaryButton in
/// profile_screen_user.dart) -- solid pill buttons side by side, Poppins,
/// #6DC55A primary green -- not the drop-shadow-card-with-colored-strip
/// look this file used before, which was never actually checked against
/// the real design reference (Shaista flagged this).
class PlanFrozenBanner extends StatefulWidget {
  // Fires after a successful unfreeze triggered right here (the banner's
  // own "Unfreeze" button), separately from _load()'s own refetch and
  // the dashboard refresh below. Neither of those tells PaidHero (a
  // sibling widget, up in paid_home_screen_v2.dart's Column) that ITS
  // own independently-fetched frozen status is now stale -- so without
  // this callback, unfreezing from here would refresh the class *data*
  // but PaidHero would keep hiding the class tiles / keep "Join"
  // disabled, because it never re-checked whether it's still frozen.
  // paid_home_screen_v2.dart wires this to the same _refreshGen bump
  // that RouteAware's didPopNext() uses, forcing PaidHero to remount and
  // re-fetch -- same fix, second trigger.
  final VoidCallback? onUnfrozen;

  const PlanFrozenBanner({super.key, this.onUnfrozen});

  @override
  State<PlanFrozenBanner> createState() => _PlanFrozenBannerState();
}

class _PlanFrozenBannerState extends State<PlanFrozenBanner> {
  Map<String, dynamic>? _status;
  bool _loaded = false;
  bool _unfreezing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = Get.find<AuthController>();
      final token =
          auth.sharedPreferences.getString(Constants.accessToken) ?? '';
      final repo = Get.find<PlanFreezeRepository>();
      final res = await repo.getStatus(accessToken: token);

      Map<String, dynamic>? status;
      if (res.body != null &&
          res.body['status'] == '1' &&
          res.body['data'] is Map) {
        status = Map<String, dynamic>.from(res.body['data']);
      }
      if (status != null && Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().planFrozen.value = status['isFrozen'] == true;
      }
      if (mounted) {
        setState(() {
          _status = status;
          _loaded = true;
        });
      }
    } catch (_) {
      // Best-effort and silent, same as PlanExpiryBanner -- a status
      // hiccup here shouldn't block the rest of the home screen from
      // rendering.
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _formatShortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _handleUnfreezeTap() async {
    if (_unfreezing) return;
    final resumeOn = _status?['willResumeOn'];
    final resumeDate =
        resumeOn != null ? DateTime.tryParse(resumeOn.toString()) : null;
    final confirmed =
        await Get.dialog<bool>(UnfreezeConfirmDialog(resumeOn: resumeDate));
    if (confirmed != true) return;

    setState(() => _unfreezing = true);
    try {
      final auth = Get.find<AuthController>();
      final token =
          auth.sharedPreferences.getString(Constants.accessToken) ?? '';
      final repo = Get.find<PlanFreezeRepository>();
      final res = await repo.unfreeze(accessToken: token);
      final ok = res.body != null && res.body['status'] == '1';
      Get.snackbar(
        ok ? 'Plan resumed' : 'Could not unfreeze',
        res.body?['message']?.toString() ?? '',
        snackPosition: SnackPosition.BOTTOM,
      );
      if (ok) {
        await _load();
        if (Get.isRegistered<PaidHomeController>()) {
          Get.find<PaidHomeController>().refreshDashboard();
        }
        widget.onUnfrozen?.call();
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _unfreezing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _status == null) return const SizedBox.shrink();
    if (_status?['isFrozen'] != true) return const SizedBox.shrink();

    final resumeOn = _status?['willResumeOn'];
    final resumeDate =
        resumeOn != null ? DateTime.tryParse(resumeOn.toString()) : null;
    final message = resumeDate != null
        ? 'Your plan is paused -- resumes ${_formatShortDate(resumeDate)}'
        : 'Your plan is currently paused';

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
                Text('\u2744', style: TextStyle(fontSize: 14.sp, color: _kFrozenBlue)),
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
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: SecondaryPillButton(
                    label: 'Unfreeze',
                    icon: '\u25b6',
                    color: _kFrozenBlue,
                    loading: _unfreezing,
                    onTap: _handleUnfreezeTap,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: PrimaryPillButton(
                    label: 'Manage',
                    color: _kAccent,
                    onTap: () => Get.to(() => const ProfileScreenUser()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
