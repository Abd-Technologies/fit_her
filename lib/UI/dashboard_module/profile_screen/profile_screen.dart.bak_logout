import 'package:fitness_zone_2/UI/auth_module/choose_any_one/choose_any_one.dart';
import 'package:fitness_zone_2/UI/auth_module/cycle_settings_screen.dart';
import 'package:fitness_zone_2/UI/dashboard_module/profile_screen/notification_settings_screen.dart';
import 'package:fitness_zone_2/UI/dashboard_module/profile_screen/add_plan_diet.dart';
import 'package:fitness_zone_2/UI/dashboard_module/profile_screen/update_profile.dart';
import 'package:fitness_zone_2/helper/get_di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../data/controllers/home_controller/home_controller.dart';
import '../../../values/constants.dart';
import '../../../values/my_colors.dart';
import '../../../values/my_imgs.dart';
import '../../../widgets/CustomText.dart';
import '../../auth_module/walt_through/walk_through_screenn.dart';
import '../add_package/add_package.dart';
import '../my_daily_meal/my_daily_meal.dart';
import 'Imporatant_Screen.dart';
import 'Success_Stories.dart';
import 'about_us_screen.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({Key? key, this.fromWelcomeScreen = false}) : super(key: key);
  final bool fromWelcomeScreen;
  final HomeController homeController = Get.find();

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: MyColors.primaryColor,
      body: Column(
        children: [
          Image.asset(
            'assets/icons/userScreen.png',
            fit: BoxFit.cover,
          ),
          // SizedBox(
          //   height: 43.h,
          // ),
          // Center(
          //     child: CustomText(
          //   Title: "Abdullah Akram",
          //   //Get.find<AuthController>().sharedPreferences.getBool(Constants.isGuest)!?"Guest":"${Get.find<AuthController>().logInUser!.firstName} ${Get.find<AuthController>().logInUser!.firstName}",
          //   TitleFontSize: 20,
          // )),
          SizedBox(
            height: 40.h,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
              children: [
                rowWidget(MyImgs.aboutUs, "About Us", () {
                  Get.to(() => AboutUsScreen());
                }),
                SizedBox(
                  height: 10.h,
                ),
                rowWidget(MyImgs.successStories, "Success Stories", () {
                  Get.to(() => Success_Stories());
                }),
                SizedBox(
                  height: 10.h,
                ),
                rowWidget(MyImgs.payment, "Important Tips", () {
                  Get.to(() => ImportantScreen());
                }),
                SizedBox(
                  height: 10.h,
                ),
                fromWelcomeScreen
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: () {
                          Get.to(() => const CycleSettingsScreen());
                        },
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.track_changes, color: MyColors.buttonColor, size: 20.sp),
                                SizedBox(width: 10.w),
                                Text(
                                  'Cycle Data',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: MyColors.textColor,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Divider(height: 1.h, color: Colors.black.withOpacity(0.2)),
                          ],
                        ),
                      ),
                SizedBox(
                  height: 10.h,
                ),
                fromWelcomeScreen
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: () {
                          Get.to(() => const NotificationSettingsScreen());
                        },
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.notifications_outlined, color: MyColors.buttonColor, size: 20.sp),
                                SizedBox(width: 10.w),
                                Text(
                                  'Notifications',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: MyColors.textColor,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Divider(height: 1.h, color: Colors.black.withOpacity(0.2)),
                          ],
                        ),
                      ),
                SizedBox(
                  height: 10.h,
                ),
                // fromWelcomeScreen
                //     ? const SizedBox.shrink()
                //     : rowWidget(MyImgs.package, "Add Plan", () {
                //         Get.to(() => AddPlanDiet());
                //         homeController.getSubCatBasedOnUserType(Get.find<AuthController>().loginAsA.value);
                //       }),

                fromWelcomeScreen
                    ? const SizedBox.shrink()
                    : rowWidget(MyImgs.package, "Update Profile", () {
                        Get.to(() => UpdateProfile());
                        homeController.getSubCatBasedOnUserType(
                            Get.find<AuthController>().loginAsA.value);
                        // homeController.getCategories();
                      }),
                // Get.find<AuthController>().sharedPreferences.getBool(Constants.isGuest)!?SizedBox():
                fromWelcomeScreen
                    ? const SizedBox.shrink()
                    : rowWidget(MyImgs.logOut, "Log Out", () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(
                                  "Log Out",
                                  style: textTheme.headlineSmall,
                                ),
                                content: Text(
                                  "Are you sure you want to logout?",
                                  style: textTheme.bodyMedium,
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () {
                                        Get.back();
                                      },
                                      child: Text(
                                        "Cancel",
                                        style: textTheme.bodyMedium,
                                      )),
                                  TextButton(
                                      onPressed: () async {
                                        Get.find<AuthController>().logout();


                                      },
                                      child: Text(
                                        "Logout",
                                        style: textTheme.bodyMedium,
                                      )),
                                ],
                              );
                            });
                      }),
                SizedBox(
                  height: 10.h,
                ),
                fromWelcomeScreen
                    ? const SizedBox.shrink()
                    : rowWidget(MyImgs.logOut, "Delete Account", () {
                        Get.defaultDialog(
                            title: "Alert",
                            content: const Text(
                                "Do you really want to delete your Account"),
                            onConfirm: () async {
                              Get.back();

                              Get.find<AuthController>().deleteUser();
                            },
                            onCancel: () async {});
                      }),
              ],
            ),
          ),
        ),

          // InkWell(
          //   onTap: () {
          //     Get.to(() => ImportantScreen()); //link AboutUs Screen here!
          //   },
          //   child: Row(
          //     children: [
          //       Image.asset('assets/icons/Layer 2.png'),
          //       CustomText(
          //         Title: "  About Us",
          //         TitleFontSize: 16,
          //       )
          //     ],
          //   ),
          // ),
          // InkWell(
          //   onTap: () {
          //     Get.to(Success_Stories());
          //   },
          //   child: Row(
          //     children: [
          //       Image.asset('assets/icons/ic.png'),
          //       CustomText(
          //         Title: "  Success Stories",
          //         TitleFontSize: 16,
          //       )
          //     ],
          //   ),
          // ),
          // InkWell(
          //   onTap: () {
          //     Get.to(Payment());
          //   },
          //   child: Row(
          //     children: [
          //       Image.asset('assets/icons/phone.png'),
          //       CustomText(
          //         Title: "  Payment Details",
          //         TitleFontSize: 16,
          //       )
          //     ],
          //   ),
          // ),
          // InkWell(
          //   onTap: () {
          //     Get.to(WorkOuts()); //link LogOut Screen here
          //   },
          //   child: Row(
          //     children: [
          //       Image.asset('assets/icons/Logout.png'),
          //       CustomText(
          //         Title: "Log Out",
          //         TitleFontSize: 16,
          //       )
          //     ],
          //   ),
          // )
        ],
      ),
    );
  }

  rowWidget(String image, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                image,
                scale: 3,
              ),
              SizedBox(
                width: 10.w,
              ),
              Text(
                text,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: MyColors.textColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(
            height: 10.h,
          ),
          Divider(
            height: 1.h,
            color: Colors.black.withOpacity(0.2),
          )
        ],
      ),
    );
  }
}
