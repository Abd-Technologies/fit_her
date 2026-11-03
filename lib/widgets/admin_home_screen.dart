import '../UI/admin_module/payment_checks/payment_checks_screen.dart';
import '../UI/admin_module/payment_accounts/payment_accounts_screen.dart';
import 'package:fitness_zone_2/UI/dashboard_module/add_package/add_package.dart';
import 'package:fitness_zone_2/UI/dashboard_module/get_all_new_user_images/get_new_user_images.dart';
import 'package:fitness_zone_2/UI/admin_module/admin_v2/admin_escalations_screen.dart';
import 'package:fitness_zone_2/UI/admin_module/admin_v2/admin_metrics_screen.dart';
import 'package:fitness_zone_2/UI/dashboard_module/posts_module/admin_approve_posts.dart';
import 'package:fitness_zone_2/UI/dashboard_module/posts_module/feed_screen.dart';
// import 'package:fitness_zone_2/UI/diet_screen/dietry_module/dietaryCheckScreen.dart'; // legacy PDF diet plan — disabled
import 'package:fitness_zone_2/UI/plans_module/add_country.dart';
import 'package:fitness_zone_2/UI/plans_module/add_time_durations.dart';
import 'package:fitness_zone_2/UI/plans_module/add_trainer_slots.dart';
import 'package:fitness_zone_2/UI/trainer_class/trainer_rooms_screen.dart';
import 'package:fitness_zone_2/UI/admin_module/app_version/app_version_screen.dart';
import 'package:fitness_zone_2/UI/admin_module/trial_days/trial_days_screen.dart';
import 'admin_payment_alerts.dart';
import 'package:fitness_zone_2/UI/class_feedback/class_feedback_screens.dart';
import 'package:fitness_zone_2/UI/admin_module/growth/growth_dashboard_screen.dart';
import 'package:fitness_zone_2/UI/plans_module/assign_workout_diet_plan.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/controllers/plan_controller/plan_controller.dart';
import 'package:fitness_zone_2/data/controllers/workout_controller/work_out_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../UI/dashboard_module/add_new_user/add_new_user.dart';
import '../UI/dashboard_module/all_user_screens/all_users_screen.dart';
import '../UI/dashboard_module/all_weekly_reports/all_weekly_report.dart';
import '../UI/dashboard_module/get_guest_users/get_guest_users.dart';
import '../UI/dashboard_module/home_screen/home_screen.dart';
import '../UI/dashboard_module/my_daily_meal/my_daily_meal.dart';
import '../UI/dashboard_module/my_recordings/my_recordings_screen.dart';

import '../UI/dashboard_module/reminders_screen/reminders_screen.dart';
import '../data/controllers/post_controller.dart';
import '../values/constants.dart';
import '../values/my_colors.dart';
import '../values/my_imgs.dart';
import 'package:get/get.dart';

import 'all_plans_screen.dart';
import 'package:fitness_zone_2/widgets/anim/motion.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminHomeScreen extends StatelessWidget {
  AdminHomeScreen({Key? key}) : super(key: key);
  final HomeController homeController = Get.find();
  final PlanController planController = Get.find();
  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: _softIn(context, Column(
          children: [
            SizedBox(
              height: 50.h,
            ),
            // Oct 2026: "N payments to confirm" / "N slips to approve".
            const AdminPaymentAlerts(),
            Stack(
              alignment: Alignment.bottomLeft,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(top: 42.h, bottom: 42.h, right: 15.w, left: 130.w),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xffFAD8CD)),
                  child: Text(
                    "Make Your Body\nHealthy & Fit With Us",
                    style: textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Image.asset(
                  MyImgs.girl,
                  scale: 3,
                ),
              ],
            ),
            SizedBox(
              height: 40.h,
            ),
            GestureDetector(
              onTap: () {
                Get.to(() => AllUsersScreen());
                homeController.getAllUsersFunc();
              },
              child: containerWidget(const Color(0xffCCF2FE), "All Users", MyImgs.userIcon),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.to(() => AllGuestUsers());
                homeController.getGuestUsers();
              },
              child: containerWidget(const Color(0xffCCF2FE), "PCOS Assessment Users", MyImgs.userIcon),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.to(() => AllNewUserImages());
                homeController.getAllImagesPlan();
              },
              child: containerWidget(const Color(0xffCCF2FE), "New Users", MyImgs.userIcon),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.to(() => AllWeeklyReport());
                homeController.getWeeklyReportsFunc();
              },
              child: containerWidget(const Color(0xffFCE4D1), "All Weekly Reports", MyImgs.myWeeklyReport),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.to(() => AllPlansScreen(
                      isHaveAppBar: true,
                    ));
                homeController.getPlans();
              },
              child: containerWidget(const Color(0xffFdE4F1), "All Packages", MyImgs.package),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.to(() => AddPackage());
                planController.getCategories();
                planController.getAllCountriesFunc();

                homeController.selectedDietIdForMember.value = 0;
                homeController.getUsersBasedOnUserType(Constants.dietitian);
              },
              child: containerWidget(const Color(0xffFdE4F1), "Add Package", MyImgs.package),
            ),
            SizedBox(
              height: 16.h,
            ),
            // GestureDetector(
            //   onTap: () {
            //     Get.to(() => AssignWorkoutDietPlan());
            //     homeController.getAllDietitian();
            //     homeController.getWorkoutAndTrainerPlan();
            //   },
            //   child: containerWidget(const Color(0xffFdE4F1),
            //       "Assign Workout and Diet Plan", MyImgs.package),
            // ),
            // SizedBox(
            //   height: 16.h,
            // ),
            GestureDetector(
              onTap: () {
                Get.to(() => AddNewUser(
                      isMember: true,
                    ));
              },
              child: containerWidget(const Color(0xffE9ECEF), "Add Team Member", MyImgs.addMember),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.to(() => RemindersScreen(
                      isAnnouncement: true,
                    ));
              },
              child: containerWidget(const Color(0xffE6EEFF), "Announcements", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.to(() => RemindersScreen());
              },
              child: containerWidget(const Color(0xffE6EEFF), "Meal Plan Tracker", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.to(() => MyDailyMeal(
                      isTestimonials: true,
                    ));
              },
              child: containerWidget(const Color(0xffE6EEFF), "Add Testimonials", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.to(() => AddCountry());
              },
              child: containerWidget(const Color(0xffE6EEFF), "Add Country", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.find<WorkOutController>().getAllTimesSlotsTrainerFunc();
                homeController.getUsersBasedOnUserType(Constants.trainer, addNull: true);
                Get.to(() => AddTrainerSlots());
              },
              child: containerWidget(const Color(0xffE6EEFF), "Add Trainer Slots", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () => Get.to(() => const TrainerRoomsScreen()),
              child: containerWidget(const Color(0xffE6F6E0), "Class Zoom Room", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () => Get.to(() => const GrowthDashboardScreen()),
              child: containerWidget(const Color(0xffE6F6E0), "Growth", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () => Get.to(() => const PaymentChecksScreen()),
              child: containerWidget(const Color(0xffFDECEC), "Confirm payments", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () => Get.to(() => const PaymentAccountsScreen()),
              child: containerWidget(const Color(0xffE8F0F8), "Payment accounts", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () => Get.to(() => const AdminClassFeedbackScreen()),
              child: containerWidget(const Color(0xffFFF0E6), "Class Feedback", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () => Get.to(() => const AppVersionScreen()),
              child: containerWidget(const Color(0xffFFF4E0), "App Version", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () => Get.to(() => const TrialDaysScreen()),
              child: containerWidget(const Color(0xffEAF7E4), "Free Trial Length", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.find<PlanController>().getAllCountriesFunc();

                Get.to(() => AddTimeDurations());
              },
              child: containerWidget(const Color(0xffE6EEFF), "Add Time Duration", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),

            // Legacy PDF diet plan status list — disabled (backend route removed).
            // GestureDetector(
            //   onTap: () {
            //     Get.to(() => DietaryCheckScreen());
            //   },
            //   child: containerWidget(const Color(0xffE6EEFF), "Dietary Check", MyImgs.annoucements),
            // ),
            // SizedBox(
            //   height: 20.h,
            // ),

            GestureDetector(
              onTap: () {
                Get.find<PostController>().getAllPosts(approved: false);
                Get.to(() => AdminApprovePosts());
              },
              child: containerWidget(const Color(0xffE6EEFF), "Posts Check", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.to(() => const AdminMetricsScreen());
              },
              child: containerWidget(const Color(0xffE0F2D8), "Metrics Overview", MyImgs.annoucements),
            ),
            SizedBox(
              height: 20.h,
            ),
            GestureDetector(
              onTap: () {
                Get.to(() => const AdminEscalationsScreen());
              },
              child: containerWidget(const Color(0xffFFF1EE), "Escalations", MyImgs.annoucements),
            ),
            // Obx(
            //   () => homeController.trialPlanLoad.value
            //       ? containerWidget(const Color(0xffE6EEFF), "Start Free Trial",
            //           MyImgs.annoucements,
            //           isShowSwitch: true,
            //           switchValue: homeController.trailPlan?.status,
            //           id: homeController.trailPlan!.id.toString())
            //       : SizedBox(),
            // ),

            SizedBox(
              height: 20.h,
            ),
          ],
        )),
      ),
    );
  }

  /// One soft fade-in of the admin tiles (staff screen: small touch only).
  Widget _softIn(BuildContext context, Widget child) =>
      Motion.calm(context) ? child : child.animate().fadeIn(duration: Motion.normal, curve: Motion.ease);
}
