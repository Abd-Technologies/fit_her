import 'package:fitness_zone_2/UI/free_trail/trial_onboarding_screen.dart';
import 'package:fitness_zone_2/UI/plans_module/refund_policy.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/widgets/circular_progress.dart';
import 'package:fitness_zone_2/widgets/meal_details.dart';
import 'package:fitness_zone_2/widgets/plans/instant_activation_banner.dart';
import 'package:fitness_zone_2/widgets/v2/v2_price_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/get_user_plan/get_user_plan.dart';
import '../../helper/analytics_helper.dart';

class OurPlansScreen extends StatelessWidget {
  OurPlansScreen({super.key});
  final HomeController homeController = Get.find();

  static const _kCream = Color(0xFFEAF7E4);
  static const _kHeroDark = Color(0xFF163220);
  static const _kSage = Color(0xFF9AB09A);
  static const _kTextMuted = Color(0xFF6F8B7A);

  @override
  Widget build(BuildContext context) {
    AnalyticsHelper.trackScreenView('OurPlans');
    return Scaffold(
      backgroundColor: _kCream,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: InstantActivationBanner(),
            ),
            Expanded(
              child: Obx(
                () => homeController.getPlanLoaded.value
                    ? _buildList()
                    : const Center(child: CircularProgress()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back, color: _kHeroDark, size: 22),
          ),
          const Spacer(),
          const Text(
            'OUR PLANS',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kSage,
              letterSpacing: 0.84,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildList() {
    final plans = homeController.allPlanModel?.plans ?? const <Plan>[];
    if (plans.isEmpty) {
      return const Center(
        child: Text(
          'No plans available',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Color(0xFF6F8B7A),
          ),
        ),
      );
    }

    // Recommend the middle / fuller plan when several exist; otherwise first.
    final recommendedIndex = plans.length >= 2 ? (plans.length > 2 ? 1 : 0) : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _trialClarityBanner(),
        const SizedBox(height: 10),
        ...List.generate(plans.length, (index) {
          final plan = plans[index];
          if (plan.countries != null &&
              plan.countries!.isNotEmpty &&
              plan.countries!.first.duration!.isNotEmpty) {
            if (plan.selectedDurationId.value == 0) {
              plan.selectedDurationId.value =
                  plan.countries!.first.duration!.first.id ?? 0;
            }
          }
          final features = featuresForPlan(plan);
          final isWorkoutOnly = features.every((f) => !f.toLowerCase().contains('diet'));
          return Padding(
            padding: EdgeInsets.only(bottom: index == plans.length - 1 ? 0 : 14),
            child: V2PriceCard(
              plan: plan,
              features: features,
              isRecommended: index == recommendedIndex,
              isLighter: isWorkoutOnly,
              onSubscribe: () => _onSubscribe(plan),
            ),
          );
        }),
        const SizedBox(height: 16),
        _refundLink(),
      ],
    );
  }

  /// Wave 0 trial clarity: surface the existing trial CTA when the user
  /// is unpaid and not already on a trial; otherwise a short note.
  Widget _trialClarityBanner() {
    final auth = Get.find<AuthController>();
    final onTrial = auth.trialActivated.value;
    if (auth.isPaid.value) return const SizedBox.shrink();

    if (onTrial) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD8EDD4)),
        ),
        child: const Text(
          'Your free trial is active. Subscribe below to keep access after it ends.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            height: 1.4,
            color: _kHeroDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Trial start already lives on unpaid home via TrialCtaCard — point
    // users there rather than inventing a second trial system in Wave 0.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8EDD4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New here? Start a free trial from Home before you subscribe.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              height: 1.4,
              color: _kHeroDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Get.to(() => const TrialOnboardingScreen()),
            child: const Text(
              'Start free trial',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6DC55A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _refundLink() {
    return Column(
      children: [
        const Text(
          'By subscribing you agree to our refund and cancellation terms.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11.5,
            height: 1.4,
            color: _kTextMuted,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Get.to(() => const RefundPolicyScreen()),
          child: const Text(
            'View refund & cancellation policy',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _kHeroDark,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  void _onSubscribe(Plan plan) {
    DurationPlan? durationPlan;
    if (plan.countries != null &&
        plan.countries!.isNotEmpty &&
        plan.countries!.first.duration!.isNotEmpty) {
      durationPlan = plan.countries!.first.duration!.firstWhere(
        (d) => d.id == plan.selectedDurationId.value,
        orElse: () => plan.countries!.first.duration!.first,
      );
    }

    Get.to(() => DietDetails(
          isPlan: true,
          title: plan.title,
          description: plan.shortDescription,
          longDescription: plan.longDescription,
          planId: plan.id.toString(),
          currency: plan.countries?.first.currency ?? 'Rs.',
          price: durationPlan?.priceAmount ?? '',
          duration: durationPlan?.days ?? '',
          durationId: plan.selectedDurationId.value,
        ));
  }
}
