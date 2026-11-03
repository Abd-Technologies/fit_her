import '../utils/trial_join_window.dart';
import '../zoom_meeting.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'new_home/trial_cta_card.dart' show showTrialStartDialog;
import '../UI/free_trail/trial_summary_screen.dart';
import 'class_reminder/class_reminder_flow.dart';
import 'class_details_sheet.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/controllers/motivation_controller/motivation_controller.dart';
import 'package:fitness_zone_2/data/controllers/workout_controller/work_out_controller.dart';
import 'package:fitness_zone_2/data/controllers/zoom_controller.dart';
import 'package:fitness_zone_2/data/services/youtube_tutorial_service.dart';
import 'package:fitness_zone_2/utils/app_clock.dart';
import 'package:fitness_zone_2/utils/slot_input_builder.dart';
import 'package:fitness_zone_2/utils/slot_ui_state.dart';
import 'package:fitness_zone_2/widgets/toasts.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../UI/plans_module/all_plans.dart';
import '../data/models/get_all_users/get_all_users_based_on_type.dart';
import '../data/models/get_user_plan/get_workout_user_plan_details.dart';
import '../values/constants.dart';
import '../values/my_colors.dart';
import '../values/my_imgs.dart';
import '../helper/analytics_helper.dart';
import 'custom_button.dart';
import 'anim/brand_loader.dart';
import 'class_joining_screen.dart';
import 'package:intl/intl.dart';

enum StatusType {
  pending,
  delayed,
  completed,
  canceled,
  confirmed,
  canceledByUser
}

class HelpingWidgets {
  PreferredSizeWidget appBarWidget(onTap,
      {String? text,
      TextAlign? textAlign,
      Color backGroundColor = Colors.white,
      Widget? actionWidget,
      PreferredSizeWidget? bottom}) {
    return AppBar(
      backgroundColor: backGroundColor,
      // leadingWidth: 70.w,
      elevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle(statusBarColor: backGroundColor),
      title: text != null
          ? Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 20.sp,
                color: Colors.black,
              ),
              textAlign: textAlign ?? TextAlign.start,
            )
          : null,
      centerTitle: true,
      leading: onTap == null
          ? null
          : GestureDetector(
              onTap: onTap,
              child: Icon(
                Icons.arrow_back,
                color: MyColors.iconColor2,
              ),
            ),
      actions: [actionWidget ?? const SizedBox()],
      bottom: bottom,
    );
  }

  static String formatDateWithMonthName(DateTime date) {
    final day = date.day.toString().padLeft(2, '0'); // 2-digit day
    final year =
        (date.year % 100).toString().padLeft(2, '0'); // last 2 digits of year
    final monthName =
        DateFormat('MMMM').format(date); // Full month name (e.g., July)

    return '$day $monthName $year';
  }

  static DateTime getNextWeekdayDate(String selectedDayName) {
    // Map weekday names to DateTime weekday numbers
    final Map<String, int> weekdayMap = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    int? selectedDay = weekdayMap[selectedDayName];
    if (selectedDay == null)
      throw Exception('Invalid weekday name: $selectedDayName');

    DateTime today = AppClock.now();
    int currentWeekday = today.weekday;

    // Calculate how many days to add to get to the next selected day
    int daysToAdd = (selectedDay - currentWeekday + 7) % 7;
    if (daysToAdd == 0)
      daysToAdd = 7; // if today is the selected day, pick next week's day

    return today.add(Duration(days: daysToAdd));
  }

  Widget appBarText(String text) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 24.sp,
          fontWeight: FontWeight.w500,
          //  fontStyle: FontStyle.normal,
          // Was "Roboto", which isn't in the app (iPhone showed another
          // font). Poppins is the app's font (Oct 2026).
          fontFamily: "Poppins"),
    );
  }

  Widget notSubscribed() {
    return const Center(
        child: Text("Please subscribe our plan to get started"));
  }

  Widget bottomBarButtonWidget({String text = "Submit", VoidCallback? onTap}) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: CustomButton(
          text: text,
          onPressed: onTap ?? () => Get.back(),
        ),
      ),
    );
  }

  Widget iconPlusMinus({IconData icon = Icons.add, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40.h,
        width: 40.h,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: MyColors.buttonColor, width: 2)),
        child: Icon(
          icon,
          color: MyColors.buttonColor,
        ),
      ),
    );
  }

  Widget getOurPlans(BuildContext context, TextTheme textTheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
              color: MyColors.planColor,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: MyColors.primaryGradient1)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(MyImgs.freeTrial),
                  const SizedBox(
                    width: 10,
                  ),
                  Text(
                    "Free Trial",
                    style: textTheme.bodyMedium!
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(
                height: 7,
              ),
              Text(
                "Get Fit, Feel Strong — Start Your FREE Fither Trial Today!",
                style: textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.3)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const Spacer(),
        CustomButton(
          text: "Start Free Trial",
          onPressed: () async {
            Get.find<WorkOutController>().getWorkoutAllPlansFunc(isFree: true);
          },
          color: Colors.white,
          textColor: MyColors.primaryGradient1,
        ),
        SizedBox(
          height: 18.h,
        ),
        CustomButton(
            text: "Subscribe Now",
            onPressed: () async {
              // Track subscribe click
              await AnalyticsHelper.trackSubscribeClick(
                  screenName: 'home_screen');

              // Show subscribe tutorial first and wait for user response
              final tutorialService = Get.find<YouTubeTutorialService>();
              await tutorialService.showSubscribeTutorial(context);

              // Then proceed with subscription
              Get.find<HomeController>().getPlansUser();
              Get.to(() => OurPlansScreen());
            }),
        SizedBox(
          height: 20.h,
        )
      ],
    );
  }

  Widget list(List<UserTypeData> list, RxInt variable, TextTheme textTheme) {
    return ListView.separated(
      // shrinkWrap: true,
      itemCount: list.length,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(vertical: 10),
      itemBuilder: (BuildContext context, int index) {
        var diet = list[index];

        return GestureDetector(
          onTap: () {
            variable.value = diet.id;
          },
          child: Obx(
            () => Container(
              width: 300.w,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: variable.value == diet.id
                          ? MyColors.buttonColor
                          : Colors.white),
                  boxShadow: [
                    BoxShadow(
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                        color: Colors.black.withOpacity(0.1))
                  ]),
              child: Row(children: [
                Container(
                  width: 70.w,
                  height: 80,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: MyColors.primaryGradient1,
                      image: const DecorationImage(
                          image: AssetImage(MyImgs.logo))),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${diet.firstName} ${diet.lastName}",
                          style: textTheme.bodyLarge!.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          diet.email,
                          style: textTheme.bodySmall!.copyWith(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                )
              ]),
            ),
          ),
        );
      },
      separatorBuilder: (BuildContext context, int index) {
        return SizedBox(
          width: 10.h,
        );
      },
    );
  }

  static showCustomDialog(
    BuildContext context,
    Function()? onTap,
    String firstText,
    String secondText,
    String? image, {
    String? buttonText,
    String? secondButtonText,
    Function()? secondButtonTap,
  }) {
    var textTheme = Theme.of(context).textTheme;
    // Returned so callers can wait for it to close (pop-up manager).
    return showDialog(
        context: context,
        builder: (context) => Dialog(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (image != null)
                      image.contains("svg")
                          ? SvgPicture.asset(image)
                          : Image.asset(image),
                    const SizedBox(
                      height: 14,
                    ),
                    Text(
                      firstText,
                      style: textTheme.bodyMedium!.copyWith(
                          color: MyColors.black, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      secondText,
                      style: textTheme.titleLarge!.copyWith(
                          fontSize: 13,
                          color: MyColors.black.withOpacity(0.5),
                          fontWeight: FontWeight.w400),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    Row(
                      children: [
                        if (secondButtonTap != null)
                          Expanded(
                            child: CustomButton(
                              text: secondButtonText ?? "Ok",
                              onPressed: secondButtonTap,
                              color: Colors.white,
                              textColor: MyColors.buttonColor,
                              height: 40,
                              fontSize: 14,
                              roundCorner: 25,
                            ),
                          ),
                        if (secondButtonTap != null)
                          SizedBox(
                            width: 14,
                          ),
                        if (onTap != null)
                          Expanded(
                            child: CustomButton(
                              text: buttonText ?? "Start",
                              onPressed: onTap,
                              height: 40,
                              fontSize: 14,
                              roundCorner: 25,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(
                      height: 10,
                    ),
                  ],
                ),
              ),
            ));
  }

  /// Bottom-sheet popup. Opens for ANY slot tap (per UX spec). The Join
  /// button inside is rendered straight from [presentationForState] —
  /// this widget makes no decisions of its own about color, label, or
  /// action. Add a state in the resolver, this surface follows.
  ///
  /// [anchorDate] is the calendar date the slot's wall-clock times
  /// belong to (today by default; the workout schedule passes its
  /// selected date). Without it, tomorrow's 8am would be misclassified
  /// as today's 8am.
  static showWorkoutBottomSheet({
    required BuildContext context,
    required Slot? slot,
    required HomeController homeController,
    DateTime? anchorDate,
  }) {
    final anchor = anchorDate ?? AppClock.now();
    final access = buildUserAccess(homeController);
    final input = slot != null ? buildSlotInput(slot, anchor) : null;
    final state = input != null
        ? resolveSlotUIState(
            slot: input,
            now: AppClock.now(),
            user: access,
          )
        : SlotUIState.upcomingFar;
    final mins = (state == SlotUIState.upcomingSoon && input != null)
        ? minutesUntilStart(input.start, AppClock.now())
        : null;
    final presentation = applyTrialJoinWindow(
      presentationForState(
        state,
        minutesUntilStart: mins,
        blockReason: blockReasonFor(access),
      ),
      state,
      start: input?.start,
      slotId: slot?.id,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      // Oct 2026 redesign: real length, class name, trainer, and one action
      // area (remind / wait / join / nothing). widgets/class_details_sheet.dart
      builder: (BuildContext sheetContext) => slot == null
          ? const SizedBox(height: 120)
          : ClassDetailsSheet(
              slot: slot,
              state: state,
              presentation: presentation,
              anchor: anchor,
              homeController: homeController,
            ),
    );
  }

  static Widget _buildPopupActionButton({
    required BuildContext context,
    required Slot? slot,
    required DateTime anchorDate,
    required SlotPresentation presentation,
    required HomeController homeController,
  }) {
    final bg = switch (presentation.buttonColor) {
      SlotButtonColor.accent => Colors.green,
      SlotButtonColor.grey => Colors.grey,
      SlotButtonColor.none => Colors.transparent,
    };
    return ElevatedButton.icon(
      onPressed: slot == null
          ? null
          : () => dispatchSlotAction(
                context: context,
                homeController: homeController,
                presentation: presentation,
                slot: slot,
                anchorDate: anchorDate,
              ),
      icon: const Icon(Icons.video_call),
      label: Text(presentation.buttonLabel ?? ''),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        backgroundColor: bg,
        disabledBackgroundColor: bg,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
    );
  }

  /// Single dispatch path used by the schedule live card and the popup
  /// button. Switches purely on [SlotPresentation.action] — no slot
  /// inspection, no status checks. Both surfaces share this so they
  /// can never disagree on what a tap means.
  static Future<void> dispatchSlotAction({
    required BuildContext context,
    required HomeController homeController,
    required SlotPresentation presentation,
    required Slot slot,
    DateTime? anchorDate,
  }) async {
    switch (presentation.action) {
      case SlotButtonAction.joinClass:
        // Trial join window: checked here AND by the server.
        if (!await trialJoinGate(
          homeController: homeController,
          slotId: slot.id,
          start: slot.start,
          className: slot.type,
          trainerName: slot.trainerName,
          anchorDate: anchorDate,
        )) {
          return;
        }
        // First trial class only: "Ready for your first class?".
        if (_isFreeTrialUser(homeController)) {
          final go = await _showFirstTrialClassSheet(homeController, slot);
          if (!go) return;
        }
        final link = slot.trainerLink ?? '';
        if (link.isEmpty) {
          AnalyticsHelper.workoutJoinFailed('no_link', slotId: '${slot.id}');
          return;
        }

        final isTrial = _isFreeTrialUser(homeController);
        final userTier = isTrial ? 'free_trial' : 'paid';

        // Fire workout_join_clicked analytics
        await AnalyticsHelper.trackWorkoutJoinClicked(
          slotId: slot.id.toString(),
          className: slot.type,
          trainerName: slot.trainerName,
          userTier: userTier,
          linkType: link.contains('https') ? 'https_url' : 'zoom_native',
        );

        try {
          if (link.contains('https')) {
            // For web links, record join presence right away since Zoom SDK won't fire callbacks
            if (Get.isRegistered<MotivationController>()) {
              await Get.find<MotivationController>().classPresenceJoin(
                slotId: slot.id.toString(),
                className: slot.type,
                trainerName: slot.trainerName,
                scheduledStartTime: slot.start,
              );
            }
            await launchUrl(Uri.parse(link));
          } else {
            await startMeeting(
              link,
              slot.id.toString(),
              className: slot.type,
              trainerName: slot.trainerName,
              scheduledStartTime: slot.start,
            );
          }
        } catch (_) {
          AnalyticsHelper.workoutJoinFailed('launch_error', slotId: '${slot.id}', tier: userTier);
          showError('Could not start the session. Please try again.');
        }
        break;
      case SlotButtonAction.showToast:
        final msg = presentation.toastMessage;
        if (msg != null && msg.isNotEmpty) showError(msg);
        break;
      case SlotButtonAction.none:
        break;
    }
  }

  /// Free-trial join window (first N minutes of a class). Used by every
  /// Join button (schedule, popup, home big card). Checks the app clock
  /// first, then asks the server (POST /presence/join refuses a late
  /// trial join with TRIAL_LATE). Shows the kind "next class" sheet and
  /// returns false when she's too late. Paid users always pass.
  static Future<bool> trialJoinGate({
    required HomeController homeController,
    required int? slotId,
    required String? start,
    String? className,
    String? trainerName,
    DateTime? anchorDate,
  }) async {
    // No package and never started a trial: start the trial instead.
    if (homeController.hasRealPlan == false &&
        Get.isRegistered<AuthController>() &&
        !Get.find<AuthController>().trialActivated.value &&
        !(homeController.userHomeData?.userAllPlans.any(
                (p) => p.title.trim().toLowerCase() == 'free trial' && p.remainingDays > 0) ??
            false)) {
      AnalyticsHelper.workoutJoinFailed('no_trial', slotId: '$slotId');
      showTrialStartDialog();
      return false;
    }
    // Trial over and no plan: no free joining — kind sheet + her offer.
    if (homeController.trialEndedUnpaid) {
      AnalyticsHelper.workoutJoinFailed('trial_ended', slotId: '$slotId', tier: 'trial_ended');
      AnalyticsHelper.offerSeen('trial_ended_join');
      await _showTrialEndedSheet(homeController);
      return false;
    }
    if (!_isFreeTrialUser(homeController)) return true;
    final anchor = anchorDate ?? AppClock.now();
    final startAt = parseSlotWallClock(start, anchor);
    final localLate = startAt == null ||
        AppClock.now().isAfter(startAt
            .add(Duration(minutes: homeController.joinWindowMinutes.value)));
    // Always ask the server: it allows an on-time join, and also a REJOIN
    // of a class she already joined on time (until the class ends). When
    // the app clock says she's late, only an explicit OK lets her in.
    var allowed = !localLate;
    if (slotId != null && Get.isRegistered<MotivationController>()) {
      allowed = await Get.find<MotivationController>().classPresenceJoin(
        slotId: slotId.toString(),
        className: className,
        trainerName: trainerName,
        scheduledStartTime: start,
        strict: localLate,
        // Only a check here; "joined" is tracked when Zoom really opens.
        track: false,
      );
    }
    if (!allowed) {
      AnalyticsHelper.workoutJoinFailed('trial_late', slotId: '$slotId', tier: 'free_trial');
      await _showTrialLateSheet(
        homeController: homeController,
        start: start,
        anchorDate: anchor,
      );
    }
    return allowed;
  }

  static const String _kFirstClassSheetKey = 'trialFirstClassSheetShown';

  /// One-time sheet before a trial user's first class. Returns true to
  /// continue joining.
  static Future<bool> _showFirstTrialClassSheet(
    HomeController homeController,
    Slot slot,
  ) async {
    final prefs = homeController.sharedPreferences;
    if (prefs.getBool(_kFirstClassSheetKey) == true) return true;
    prefs.setBool(_kFirstClassSheetKey, true);
    final trainer = (slot.trainer?.firstName ?? '').trim();
    final result = await Get.bottomSheet<bool>(
      _TrialSheet(
        emoji: '🎉',
        title: 'Ready for your first class?',
        lines: [
          "✅  You're joining on time, great!",
          '📷  Camera on or off, it\'s up to you',
          '👩  ${trainer.isEmpty ? 'Your trainer is a woman' : 'Your trainer is $trainer'}, women only',
          '📵  This class is not recorded',
        ],
        primaryLabel: 'Join class',
        onPrimary: () => Get.back(result: true),
      ),
      isScrollControlled: true,
    );
    return result == true;
  }

  /// Tapping Join after the free trial ended (no plan yet).
  static Future<void> _showTrialEndedSheet(HomeController homeController) async {
    final done = homeController.classesAttended.value;
    await Get.bottomSheet<void>(
      _TrialSheet(
        emoji: '💚',
        title: 'Your free trial has ended',
        lines: [
          done > 0
              ? 'You showed up for $done class${done == 1 ? '' : 'es'}, amazing. Continue your live classes with a plan.'
              : 'Continue your live classes with a plan.',
        ],
        primaryLabel: 'See plans & my offer',
        onPrimary: () {
          AnalyticsHelper.offerTapped('trial_ended_sheet');
          Get.back();
          Get.to<dynamic>(() => const TrialSummaryScreen());
        },
        secondaryLabel: 'Not now',
        onSecondary: () => Get.back(),
      ),
      isScrollControlled: true,
    );
  }

  /// Joining too late as a trial user: say why kindly and offer her next
  /// class (with a one-tap reminder) instead of an error.
  static Future<void> _showTrialLateSheet({
    required HomeController homeController,
    required String? start,
    required DateTime anchorDate,
  }) async {
    final startAt = parseSlotWallClock(start, anchorDate);
    final minsLate =
        startAt == null ? null : AppClock.now().difference(startAt).inMinutes;
    if (homeController.trialClassData.value == null) {
      await homeController.loadTrialClasses();
    }
    final next = homeController.nextTrialClass();
    final window = homeController.joinWindowMinutes.value;
    final nextId = next?.data['slotId'];
    final nextTrainer = next?.data['trainer'] is Map
        ? '${(next!.data['trainer'] as Map)['name'] ?? ''}'.trim()
        : '';
    await Get.bottomSheet<void>(
      _TrialSheet(
        emoji: '⏰',
        title: minsLate == null
            ? 'This class has already started'
            : 'This class started $minsLate minutes ago',
        lines: [
          'To keep you safe, trial classes are joined within the first $window minutes.',
          if (next != null)
            'Next class: ${next.label} · ${next.data['type'] ?? 'Live class'}'
                '${nextTrainer.isEmpty ? '' : ' with $nextTrainer'}',
        ],
        primaryLabel: next != null && next.data['picked'] != true ? 'Remind me' : 'See all classes',
        onPrimary: () async {
          if (next != null && next.data['picked'] != true && nextId is int) {
            Get.back();
            // Same rule as home: max 2 times, else swap / just this once.
            await ClassReminderFlow.request(
              slotId: nextId,
              start: '${next.data['startLocal'] ?? ''}',
              dayOffset: next.today ? 0 : 1,
            );
          } else {
            Get.back();
          }
        },
        secondaryLabel: next != null && next.data['picked'] != true ? 'See all classes' : null,
        onSecondary: () => Get.back(),
      ),
      isScrollControlled: true,
    );
  }

  static bool _canFreeTrialUserJoin({
    required HomeController homeController,
    required Slot slot,
    required DateTime anchorDate,
  }) {
    if (!_isFreeTrialUser(homeController)) return true;

    final start = parseSlotWallClock(slot.start, anchorDate);
    if (start == null) return false;

    final cutoff =
        start.add(Duration(minutes: homeController.joinWindowMinutes.value));
    return !AppClock.now().isAfter(cutoff);
  }

  static bool _isFreeTrialUser(HomeController homeController) {
    final planFreeTrial = homeController.userHomeData?.userAllPlans.any(
          (plan) => plan.title.trim().toLowerCase() == 'free trial',
        ) ??
        false;
    if (_hasActiveThreeDayTrial(homeController)) return true;
    return planFreeTrial;
  }

  static bool _hasActiveThreeDayTrial(HomeController homeController) {
    final journey = homeController.trialJourney;
    if (journey == null || journey["convertedAt"] != null) return false;

    final startedAt = DateTime.tryParse(journey["startedAt"]?.toString() ?? "");
    if (startedAt == null) return false;

    return AppClock.now().isBefore(startedAt.add(homeController.kTrialLength));
  }

  static startMeeting(
    String meetingNumber,
    String slotId, {
    String? className,
    String? trainerName,
    String? scheduledStartTime,
  }) async {
    final authController = Get.find<AuthController>();
    final homeController = Get.find<HomeController>();
    final displayName = _buildMeetingDisplayName(
      authController: authController,
      homeController: homeController,
    );

    // "Opening your class…" while Zoom signs in / we retry.
    _showJoiningDialog(className, trainerName);
    var success = false;
    // First tap after opening the app often fails because Zoom is still
    // signing in (Try again then works). So try up to 3 times, quietly,
    // before showing the "Couldn't open your class" sheet.
    for (var attempt = 0; attempt < 3 && !success; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(milliseconds: 1500));
      try {
        success = await Get.find<ZoomMeetingGetxController>().joinMeeting(
          meetingNumber,
          displayName,
          slotId: slotId,
          className: className,
          trainerName: trainerName,
          scheduledStartTime: scheduledStartTime,
        );
      } catch (_) {
        success = false;
      }
    }
    _closeJoiningDialog();
    if (!success) {
      AnalyticsHelper.workoutJoinFailed('zoom_error ${ZoomMeeting.lastError ?? ''}'.trim(), slotId: slotId);
      debugPrint('[zoom] join failed: ${ZoomMeeting.lastError}');
      // Backup: never leave her stuck. Try again, or open the SAME class
      // in the regular Zoom app.
      await _showZoomFallbackSheet(
        meetingNumber: meetingNumber,
        slotId: slotId,
        className: className,
        trainerName: trainerName,
        scheduledStartTime: scheduledStartTime,
      );
      return;
    }
    // (The "rate this class" sheet 5 min into class is gone: feedback is
    // asked once, after the class ends, on home — widgets/class_feedback.)
    Get.find<MotivationController>().markAttendance(slotId: slotId);
  }

  static bool _joiningOpen = false;

  static void _showJoiningDialog(String? className, [String? trainerName]) {
    if (_joiningOpen) return;
    _joiningOpen = true;
    // Oct 2026: full-screen "Joining live class" wait (was a small white
    // box) so the seconds Zoom needs to load feel short.
    Get.dialog(
      ClassJoiningScreen(
        className: className,
        trainerName: trainerName,
        onClose: _closeJoiningDialog,
      ),
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      useSafeArea: false,
    );
  }

  static void _closeJoiningDialog() {
    if (!_joiningOpen) return;
    _joiningOpen = false;
    if (Get.isDialogOpen ?? false) Get.back();
  }

  /// Shown when Zoom can't open inside the app.
  static Future<void> _showZoomFallbackSheet({
    required String meetingNumber,
    required String slotId,
    String? className,
    String? trainerName,
    String? scheduledStartTime,
  }) async {
    final digits = meetingNumber.replaceAll(RegExp(r'[^0-9]'), '');
    await Get.bottomSheet<void>(
      _TrialSheet(
        emoji: '📹',
        title: "Couldn't open your class",
        lines: const [
          'Your class is live. Tap Try again, or open it in the Zoom app.',
        ],
        primaryLabel: 'Open in Zoom app',
        onPrimary: () async {
          Get.back();
          // Join presence first: the Zoom app won't report back to us.
          if (Get.isRegistered<MotivationController>()) {
            await Get.find<MotivationController>().classPresenceJoin(
              slotId: slotId,
              className: className,
              trainerName: trainerName,
              scheduledStartTime: scheduledStartTime,
            );
          }
          final app = Uri.parse('zoomus://zoom.us/join?confno=$digits');
          final web = Uri.parse('https://zoom.us/j/$digits');
          try {
            if (!await launchUrl(app, mode: LaunchMode.externalApplication)) {
              await launchUrl(web, mode: LaunchMode.externalApplication);
            }
          } catch (_) {
            await launchUrl(web, mode: LaunchMode.externalApplication);
          }
        },
        secondaryLabel: 'Try again',
        onSecondary: () {
          Get.back();
          startMeeting(
            meetingNumber,
            slotId,
            className: className,
            trainerName: trainerName,
            scheduledStartTime: scheduledStartTime,
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  static String _buildMeetingDisplayName({
    required AuthController authController,
    required HomeController homeController,
  }) {
    final loginUser = authController.logInUser;
    final baseName = (loginUser?.fullName.trim().isNotEmpty ?? false)
        ? loginUser!.fullName.trim()
        : 'User';

    final isFree = _isFreeTrialUser(homeController);
    final tierTag = isFree ? 'Free' : 'Paid';

    final tags = <String>[tierTag];
    final goal = loginUser?.mainGoal?.trim();
    if (goal != null && goal.isNotEmpty) {
      tags.add(goal);
    }

    return '$baseName (${tags.join(', ')})';
  }

  static StatusType getStatusTypeFromString(String status) {
    switch (status) {
      case 'completed':
        return StatusType.completed;
      case 'canceled':
        return StatusType.canceled;
      case 'canceledByUser':
        return StatusType.canceledByUser;
      case 'pending':
        return StatusType.pending;
      case 'confirmed':
        return StatusType.confirmed;
      case 'delayed':
        return StatusType.delayed;
      default:
        return StatusType.pending; // fallback
    }
  }

  static getStatusColorAndIcon(String status) {
    StatusType statusType = getStatusTypeFromString(status ?? "");
    print('HelpingWidgets.getStatusColorAndIcon ${statusType}');
    print('HelpingWidgets.getStatusColorAndIcon ${status}');

    IconData icon;
    Color color;

    switch (statusType) {
      case StatusType.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case StatusType.canceled:
        icon = Icons.phone_missed;
        color = Colors.red;
        break;
      case StatusType.canceledByUser:
        icon = Icons.phone_missed;
        color = Colors.red;
        break;
      case StatusType.pending:
        icon = Icons.access_time;
        color = Colors.orange;
        break;
      case StatusType.confirmed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case StatusType.delayed:
        icon = Icons.timelapse;
        color = Colors.orange;
        break;
    }
    return [icon, color];
  }

  static getDateFromTimeStamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate(); // Convert to Dart DateTime

    String formatted = DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    return formatted;
  }

  static bool isSessionValid(Slot slot, HomeController homeController) {
    if (!homeController.checkTiming(slot.start, slot.end)) {
      //   showError("The class has not started yet or has already passed.");
      return false;
    }
    return true;
  }

  static showError(String message) {
    CustomToast.failToast(msg: message);
  }
}

/// Simple bottom sheet used for the trial first-class and late-join
/// messages. Same V2 look as the rest of the trial flow.
class _TrialSheet extends StatelessWidget {
  final String emoji;
  final String title;
  final List<String> lines;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _TrialSheet({
    required this.emoji,
    required this.title,
    required this.lines,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: const BoxDecoration(
        color: Color(0xFFE8F4E0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF163220),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD8EDD4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines
                    .map((l) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            l,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              height: 1.45,
                              color: Color(0xFF163220),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6DC55A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  primaryLabel,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (secondaryLabel != null && onSecondary != null)
              TextButton(
                onPressed: onSecondary,
                child: Text(
                  secondaryLabel!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6F8B7A),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
