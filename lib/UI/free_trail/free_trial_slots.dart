import 'package:fitness_zone_2/widgets/new_home/trial_cta_card.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/controllers/workout_controller/work_out_controller.dart';
import 'package:fitness_zone_2/helper/analytics_helper.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:fitness_zone_2/widgets/circular_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../values/my_imgs.dart';
import '../../data/models/get_user_plan/get_workout_user_plan_details.dart';
import '../../values/constants.dart';
import '../../widgets/custom_button.dart';

class FreeTrialSlots extends StatefulWidget {
  FreeTrialSlots({super.key});

  @override
  State<FreeTrialSlots> createState() => _FreeTrialSlotsState();
}

class _FreeTrialSlotsState extends State<FreeTrialSlots> {
  WorkOutController workOutController = Get.find();
  HomeController homeController = Get.find();

  @override
  void initState() {
    super.initState();
    AnalyticsHelper.trackScreenView('free_trial_slots_screen');
    AnalyticsHelper.trackFreeTrialEvent('slots_viewed', step: 'slots');
    AnalyticsHelper.trackFreeTrial('started', step: 'slots');
  }

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: HelpingWidgets().appBarWidget(() {
        Get.back();
      }, text: "Workout Slots"),
      body: Obx(
        () => !workOutController.workOutPlanDetailsLoad.value
            ? const CircularProgress()
            : Column(
                children: [
                  Center(
                    child: Text(
                      "Browse the available class times for your ${homeController.trialDays.value}-day trial.\nYou will book one class at a time as you progress.",
                      style:
                          textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w400),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    height: 20.h,
                  ),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      itemBuilder: (BuildContext context, int timeIndex) {
                        var time = workOutController
                            .getUserWorkoutPlanDetailsPlan!.trainerSlots[timeIndex];
                        return ExpansionTile(
                          key: ValueKey(time.id),
                          iconColor: Colors.black,
                          initiallyExpanded: expandTile(time).value,
                          collapsedIconColor: Colors.black,
                          title: Text(
                            time.day,
                            style: textTheme.headlineSmall,
                          ),
                          children: [
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                  vertical: 10.h, horizontal: 10),
                              itemCount: time.slots.length,
                              itemBuilder: (context, index) {
                                var slot = time.slots[index];
                                return Container(
                                  height: 90,
                                  width: double.maxFinite,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 13, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.black),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            slot.type ?? "N/A",
                                            style: textTheme.bodySmall!
                                                .copyWith(
                                                    fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(
                                            height: 3,
                                          ),
                                          Text(
                                            "${slot.start} - ${slot.end}",
                                            style: textTheme.bodySmall!
                                                .copyWith(
                                                    fontWeight: FontWeight.w500),
                                          ),
                                          const Spacer(),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              const CircleAvatar(
                                                radius: 12,
                                                backgroundImage:
                                                    AssetImage(MyImgs.logo),
                                              ),
                                              SizedBox(
                                                width: 10.w,
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "${slot.trainer?.firstName} ${slot.trainer?.lastName}",
                                                    style: textTheme.bodySmall!
                                                        .copyWith(
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            color: const Color(
                                                                0xff7F7F7F)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      SvgPicture.asset(MyImgs.progressbar)
                                    ],
                                  ),
                                );
                              },
                              separatorBuilder:
                                  (BuildContext context, int index) {
                                return SizedBox(
                                  height: 15.h,
                                );
                              },
                            ),
                          ],
                        );
                      },
                      separatorBuilder: (BuildContext context, int index) {
                        return SizedBox(
                          height: 10.h,
                        );
                      },
                      itemCount: workOutController
                          .getUserWorkoutPlanDetailsPlan!.trainerSlots.length,
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  CustomButton(
                    text: "Continue to 3-Day Trial",
                    onPressed: () {
                      // Consolidated: same confirm-and-start dialog as
                      // every other entry point (showTrialStartDialog),
                      // which routes on into the diet quick-intake + AI
                      // plan step before workout onboarding, instead of
                      // TrialJourneyScreen's own separate confirm dialog
                      // that skipped straight past both of those.
                      showTrialStartDialog();
                    },
                  ),
                  SizedBox(
                    height: 20,
                  ),
                ],
              ),
      ),
    );
  }

  RxBool expandTile(TrainerSlot time) {
    return RxBool(time.day == today || time.day == tomorrow);
  }
}
