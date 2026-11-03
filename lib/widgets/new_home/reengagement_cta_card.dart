import '../../helper/analytics_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../UI/plans_module/all_plans.dart';
import '../../data/Repos/user_plan_repo/user_plan_repository.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/models/user_plan/user_plan_item.dart';
import '../../values/constants.dart';
import 'trial_cta_card.dart';

/// Decides what re-engagement pitch belongs at the bottom of the unpaid
/// home screen.
///
/// Before this widget, every unpaid user — brand new, mid-trial,
/// trial-ended, AND a lapsed paying customer who cancelled or let their
/// plan run out — saw exactly one thing here: [TrialCtaCard]. For a real
/// former subscriber that's a bad experience twice over: it offers a
/// "3-day free trial" to someone who already paid real money, and it
/// never acknowledges they were a customer at all. That's the dead end
/// Shaista flagged.
///
/// Priority:
///   1. Ever started a trial (`AuthController.trialActivated`, true for
///      the lifetime of the account once a trial starts — see
///      HomeController.getMyTrialJourney) → always [TrialCtaCard]. It
///      already has full idle / active / "Trial ended · choose a plan"
///      coverage for that user; trial history takes priority over plan
///      history so we don't show two competing CTAs.
///   2. Never trialed, but GET /users/get_user_plans returns a real
///      (non-"Free Trial") plan → a lapsed paying customer. Show
///      [_LapsedPlanCard], which names their plan and says plainly
///      whether they cancelled it or it ran out.
///   3. Neither → genuinely new visitor → [TrialCtaCard]'s idle state,
///      same as before this widget existed.
class ReengagementCtaCard extends StatefulWidget {
  const ReengagementCtaCard({super.key});

  @override
  State<ReengagementCtaCard> createState() => _ReengagementCtaCardState();
}

class _ReengagementCtaCardState extends State<ReengagementCtaCard> {
  UserPlanItem? _lapsedPlan;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    if (!Get.find<AuthController>().trialActivated.value) {
      _checkLapsedPlan();
    }
  }

  Future<void> _checkLapsedPlan() async {
    try {
      final auth = Get.find<AuthController>();
      final token =
          auth.sharedPreferences.getString(Constants.accessToken) ?? '';
      final repo = Get.find<UserPlanRepository>();
      final res = await repo.getMyPlans(accessToken: token);

      if (res.body != null && res.body['status'] == '1' && res.body['data'] is List) {
        final rows = (res.body['data'] as List)
            .whereType<Map>()
            .map((m) => UserPlanItem.fromJson(Map<String, dynamic>.from(m)))
            // Free Trial rows are destroyed on trial expiry anyway (see
            // freeTrialExpiry.js), but filter defensively — this card is
            // only for real, paid plan history.
            .where((p) => p.plan?.title != 'Free Trial')
            .toList();
        rows.sort((a, b) => b.id.compareTo(a.id));
        if (rows.isNotEmpty && mounted) {
          setState(() => _lapsedPlan = rows.first);
        }
      }
    } catch (_) {
      // Best-effort — falls back to TrialCtaCard's idle state below,
      // never blocks the rest of the home screen from rendering.
    } finally {
      if (mounted) setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final trialActivated = Get.find<AuthController>().trialActivated.value;
      if (trialActivated) return const TrialCtaCard();
      // While the lookup is in flight, default to the idle trial CTA
      // rather than an empty gap — for the common case (new visitor)
      // that's also the correct final answer, so there's no flash for
      // most people.
      if (!_checked || _lapsedPlan == null) return const TrialCtaCard();
      return _LapsedPlanCard(plan: _lapsedPlan!);
    });
  }
}

// ─── Lapsed paying customer — names the plan, says what happened. ──────
class _LapsedPlanCard extends StatelessWidget {
  final UserPlanItem plan;
  const _LapsedPlanCard({required this.plan});

  static const _accent = Color(0xFF6DC55A);

  String _formatDate(DateTime d) => DateFormat('MMM d').format(d.toLocal());

  @override
  Widget build(BuildContext context) {
    final title = plan.plan?.title ?? 'plan';
    final cancelled = plan.planStatus == 'cancelled';
    final endDate = cancelled ? plan.cancelledAt : plan.expireDate;

    final String headline = cancelled
        ? 'You cancelled your $title plan'
        : 'Your $title plan ended';
    final String detail = endDate != null
        ? (cancelled
            ? 'Cancelled ${_formatDate(endDate)}. Your classes, dashboard, and diet plan are paused — pick up right where you left off.'
            : 'Ended ${_formatDate(endDate)}. Renew to get back to your classes and dashboard.')
        : (cancelled
            ? 'Your classes, dashboard, and diet plan are paused — pick up right where you left off.'
            : 'Renew to get back to your classes and dashboard.');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF163220), Color(0xFF1A3A28)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withOpacity(0.32), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF163220).withOpacity(0.18),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.22),
                  border: Border.all(color: _accent.withOpacity(0.4), width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('👋', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              AnalyticsHelper.offerTapped('reactivate_card');
              Get.to<dynamic>(() => OurPlansScreen());
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Reactivate my plan →',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Your progress and history are saved',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.white.withOpacity(0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
