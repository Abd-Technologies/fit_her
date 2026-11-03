import '../../../helper/analytics_helper.dart';
import 'package:fitness_zone_2/UI/dashboard_module/bottom_bar_screen/diet_bottom_bar.dart';
import '../../free_trail/trial_summary_screen.dart';
import '../../../widgets/new_home/trial_cta_card.dart' show showTrialStartDialog;
import '../../../data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/UI/dashboard_module/recommended_slots_screen.dart';
import 'package:fitness_zone_2/UI/dashboard_module/bottom_bar_screen/work_out_bottom_screen.dart';
import 'package:fitness_zone_2/data/controllers/diet_contoller/diet_controller.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/controllers/workout_controller/work_out_controller.dart';
import 'package:fitness_zone_2/main.dart';
import 'package:fitness_zone_2/utils/slot_input_builder.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../values/my_colors.dart';
import '../../../values/my_imgs.dart';
import '../../../widgets/app_bar_widget.dart';
import '../../../widgets/circular_progress.dart';

class WorkPlansOfUser extends StatefulWidget {
  WorkPlansOfUser({super.key, this.showBackButton = true});
  bool showBackButton;

  @override
  State<WorkPlansOfUser> createState() => _WorkPlansOfUserState();
}

class _WorkPlansOfUserState extends State<WorkPlansOfUser> {
  WorkOutController workOutController = Get.find();
  HomeController homeController = Get.find();
  String? _singlePlanId;
  bool _requestedSinglePlanDetails = false;
  // Guards the one-time getDietPlanDetailsFunc('0') call for trial users
  // so navigating away and back doesn't re-trigger a redundant fetch.
  bool _requestedTrialSlots = false;

  Widget _animatedBody(Widget child, {required String keyValue}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(keyValue),
        child: child,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Defer so Rx writes don't fire during the first build, which would
    // trigger Obx while the framework is still building widgets → assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        workOutController.getWorkoutAllPlansFunc(
          silent: workOutController.workoutPlans != null,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return Obx(() {
      final isLoaded = workOutController.workOutOfUserLoad.value;
      if (isLoaded && workOutController.workoutPlans != null) {
        final plans = workOutController.workoutPlans!.plans;
        if (plans.length == 1) {
          final singlePlanId = plans.first.id.toString();
          if (_singlePlanId != singlePlanId) {
            _singlePlanId = singlePlanId;
            _requestedSinglePlanDetails = false;
          }
          if (!_requestedSinglePlanDetails) {
            _requestedSinglePlanDetails = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _singlePlanId == null) return;
              selectedPlan = _singlePlanId!;
              workOutController.getDietPlanDetailsFunc(_singlePlanId!);
            });
          }
          return _animatedBody(
            WorkOutBottomScreen(
              planId: singlePlanId,
              showBackButton: widget.showBackButton,
            ),
            keyValue: 'workout-detail-$singlePlanId',
          );
        }

        // No package: always the paid schedule design (public slots,
        // planId '0'), never the old "Your Plans" page.
        //   trial running   → exactly like a paid user (trial join rules)
        //   trial not started → buttons "Try free →" (trial flow)
        //   trial ended     → buttons "Choose a plan →" (summary + offer)
        if (plans.isEmpty) {
          final running = hasActiveThreeDayTrial(homeController);
          final started = Get.find<AuthController>().trialActivated.value;
          final ended = !running && started && homeController.trialEndedUnpaid;
          homeController.trialLive.value; // rebuild when trial ends
          if (!_requestedTrialSlots) {
            _requestedTrialSlots = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              selectedPlan = '0';
              workOutController.getDietPlanDetailsFunc('0');
            });
          }
          return _animatedBody(
            WorkOutBottomScreen(
              planId: '0',
              showBackButton: widget.showBackButton,
              previewCtaLabel: running ? null : (ended ? 'Choose a plan →' : 'Try free →'),
              onPreviewCta: running
                  ? null
                  : (ended
                      ? () {
                          AnalyticsHelper.offerTapped('workout_preview', offer: 'plans');
                          Get.to<dynamic>(() => const TrialSummaryScreen());
                        }
                      : () {
                          AnalyticsHelper.offerTapped('workout_preview', offer: 'trial');
                          showTrialStartDialog();
                        }),
            ),
            keyValue: running ? 'workout-trial' : (ended ? 'workout-ended' : 'workout-preview'),
          );
        }

        // (old) Active 3-day trial with no paid plan → kept for reference.
        if (plans.isEmpty && hasActiveThreeDayTrial(homeController)) {
          if (!_requestedTrialSlots) {
            _requestedTrialSlots = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              selectedPlan = '0';
              workOutController.getDietPlanDetailsFunc('0');
            });
          }
          return _animatedBody(
            WorkOutBottomScreen(
              planId: '0',
              showBackButton: widget.showBackButton,
            ),
            keyValue: 'workout-trial',
          );
        }

        return Scaffold(
          appBar: HelpingWidgets().appBarWidget(
              widget.showBackButton
                  ? () {
                      Get.back();
                    }
                  : null,
              text: "Your Plans"),
          body: _animatedBody(
            plans.isEmpty
                ? Column(
                    children: [
                      Expanded(
                        child:
                            HelpingWidgets().getOurPlans(context, textTheme),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: TextButton(
                          onPressed: () {
                            Get.to(() => const RecommendedSlotsScreen());
                          },
                          child: Text(
                            'View recommended sessions →',
                            style: textTheme.bodyMedium!.copyWith(
                              color: MyColors.buttonColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.h, vertical: 20.h),
                    itemCount: plans.length,
                    itemBuilder: (BuildContext context, int index) {
                      var plan = plans[index];
                      return GestureDetector(
                        onTap: () {
                          Get.to(() => WorkOutBottomScreen(
                                planId: plan.id.toString(),
                              ));
                          selectedPlan = plan.id.toString();
                          workOutController
                              .getDietPlanDetailsFunc(plan.id.toString());
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.1))
                              ]),
                          child: Row(children: [
                            SizedBox(
                              width: 70.w,
                              child: Image.asset(MyImgs.logo),
                            ),
                            SizedBox(
                              width: 10.w,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.title,
                                    style: textTheme.bodyLarge!.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    plan.shortDescription,
                                    style: textTheme.bodySmall!.copyWith(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            )
                          ]),
                        ),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return SizedBox(
                        height: 20.w,
                      );
                    },
                  ),
            keyValue: plans.isEmpty ? 'workout-empty' : 'workout-list',
          ),
        );
      }

      // Initial loading state (plans not loaded yet):
      // Matches WorkOutBottomScreen's background color with centered progress indicator,
      // never flashing the legacy "Your Plans" AppBar.
      return Scaffold(
        backgroundColor: const Color(0xFFE8F4E0),
        body: SafeArea(
          child: Stack(
            children: [
              if (widget.showBackButton)
                Positioned(
                  top: 8.h,
                  left: 8.w,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Color(0xFF1A3A22)),
                    onPressed: () => Get.back(),
                  ),
                ),
              const Center(
                child: CircularProgress(),
              ),
            ],
          ),
        ),
      );
    });
  }
}
