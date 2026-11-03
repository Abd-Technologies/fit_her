import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/models/get_all_users/get_all_users.dart';
import 'package:fitness_zone_2/theme/app_colors.dart';
import 'package:flutter/material.dart';

import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../values/constants.dart';
import '../../../values/my_colors.dart';
import '../../../values/my_imgs.dart';
import '../../../widgets/app_bar_widget.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../widgets/circular_progress.dart';
import '../../../widgets/custom_button.dart';
import '../../auth_module/edit_user/edit_user.dart';
import '../../chat/widgets/chat_room.dart';
import '../add_new_user/add_new_user.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class AllUsersScreen extends StatelessWidget {
  AllUsersScreen({Key? key, this.isCustomerSupport = false}) : super(key: key);
  final bool isCustomerSupport;
  final HomeController homeController = Get.find();

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return WillPopScope(
      onWillPop: () {
        homeController.clearyControllers();
        return Future.value(true);
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: HelpingWidgets().appBarWidget(
            () {
              homeController.clearyControllers();
              Get.back();
            },
            text: "All Users",
            bottom: TabBar(
              padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 10.h),
              indicatorColor: MyColors.primaryGradient1,
              labelColor: MyColors.black,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(
                  text: "My Users",
                ),
                Tab(
                  text: "Free Trial Users",
                ),
              ],
            ),
          ),
          body: TabBarView(children: [
            Obx(() => homeController.getAllUsersLoad.value
                ? ListView.separated(
                    itemCount: homeController.getAllUsers!.otherPlanUsers.length,
                    padding: EdgeInsets.all(20.h),
                    itemBuilder: (BuildContext context, int index) {
                      var user = homeController.getAllUsers?.otherPlanUsers[index];
                      return containerWidget(isCustomerSupport, user, textTheme);
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return SizedBox(
                        height: 20.h,
                      );
                    },
                  )
                : const CircularProgress()),
            Obx(() => homeController.getAllUsersLoad.value
                ? ListView.separated(
                    itemCount: homeController.getAllUsers!.freeTrialUsers.length,
                    padding: EdgeInsets.all(20.h),
                    itemBuilder: (BuildContext context, int index) {
                      var user = homeController.getAllUsers!.freeTrialUsers[index];
                      return containerWidget(isCustomerSupport, user, textTheme);
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return SizedBox(
                        height: 20.h,
                      );
                    },
                  )
                : const CircularProgress())
          ]),
          bottomNavigationBar: isCustomerSupport
              ? null
              : SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomButton(
                            text: "Add User",
                            onPressed: () async {
                              Get.to(() => AddNewUser());
                              homeController.getUsersBasedOnUserType(homeController.addTeamMember[4].replaceAll(" ", "_"));
                              homeController.getPlans();
                              // Get.find<HomeController>().getAllDietitian();
                            }),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget containerWidget(bool isCustomerSupport, User? user, TextTheme textTheme) {
    return Row(children: [
      Container(
        height: 32.h,
        width: 32.h,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
        child: Image.asset(
          MyImgs.userIcon,
          scale: 4,
        ),
      ),
      SizedBox(
        width: 15.w,
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${user?.user.firstName} ${user?.user.lastName}",
              style: textTheme.bodyMedium!.copyWith(color: MyColors.textColor, fontWeight: FontWeight.w500),
            ),
            Text(
              isCustomerSupport ? user?.user.phone ?? "N/A" : user?.user.email ?? "N/A",
              style: textTheme.bodySmall!.copyWith(color: MyColors.textColor, fontWeight: FontWeight.w400),
            ),
            if (user != null)
              if (user.plans != null)
                Text(
                  "Plan: ${user.plans?.plan.title} (${DateTime.now().difference(user.plans!.buyingDate).inDays} days ago)",
                  style: textTheme.bodySmall!.copyWith(color: MyColors.textColor, fontWeight: FontWeight.w400),
                ),
            Text(
              "BMI Result: ${user?.user.bmiResult ?? "N/A"}",
              style: textTheme.bodySmall!.copyWith(color: MyColors.textColor, fontWeight: FontWeight.w400),
            )
          ],
        ),
      ),
      const Spacer(),
      !isCustomerSupport
          ? Row(
              children: [
                GestureDetector(
                  onTap: () {
                    homeController.firstNameController.text = user?.user.firstName ?? "";
                    homeController.lastNameController.text = user?.user.lastName ?? "";
                    homeController.emailController.text = user?.user.email ?? "";
                    homeController.phoneController.text = user?.user.phone ?? "";
                    homeController.passwordController.text = "";
                    if (user?.plans != null) {
                      homeController.dateExtendController.text = "${user?.plans!.expireDate.difference(DateTime.now()).inDays} days";
                    }
                    if (user != null) {
                      Get.to(() => EditUser(
                            user: user,
                          ));
                    }
                  },
                  child: Container(
                    height: 32.h,
                    width: 32.h,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xffEBEBEB)),
                    child: const Icon(Icons.edit),
                  ),
                ),
                SizedBox(
                  width: 12.w,
                ),
                GestureDetector(
                  onTap: () {
                    Get.defaultDialog(
                      title: "Delete User",
                      titleStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      content: Text(
                        "Are you sure you want to delete ${user?.user.firstName}?",
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      confirmTextColor: AppColors.textOnPrimary,
                      buttonColor: AppColors.error,
                      cancelTextColor: AppColors.textPrimary,
                      onConfirm: () async {
                        Get.back();
                        if (user?.user != null) {
                          Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
                          final authController = Get.find<AuthController>();
                          final response = await authController.authRepo.deleteUser(
                            id: user!.user.id.toString(),
                          );
                          Get.back();
                          if (response.statusCode == 200 && response.body["status"] == "1") {
                            homeController.getAllUsers?.otherPlanUsers.remove(user);
                            homeController.getAllUsers?.freeTrialUsers.remove(user);
                            homeController.getAllUsersLoad.refresh();
                            Get.snackbar(
                              'Success',
                              response.body["message"],
                              backgroundColor: AppColors.success,
                              colorText: AppColors.textOnPrimary,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          } else {
                            Get.snackbar(
                              'Error',
                              response.body["message"] ?? "Failed to delete user",
                              backgroundColor: AppColors.error,
                              colorText: AppColors.textOnPrimary,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                        }
                      },
                      onCancel: () {},
                    );
                  },
                  child: Container(
                    height: 32.h,
                    width: 32.h,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error),
                    child: const Icon(Icons.delete, color: AppColors.textOnPrimary, size: 16),
                  ),
                ),
              ],
            )
          : GestureDetector(
              onTap: () async {
                if(user !=null){
                  var userDetail = user.user.id.toString();

                  var userMap = await homeController.getspecificUserFromFireStore(userDetail);
                  var roomId = await homeController.makeRoomId(userDetail);

                  Get.to(() => ChatRoom(
                    chatRoomId: roomId,
                    userMap: userMap,
                  ));
                }

              },
              child: Container(
                height: 32.h,
                width: 32.h,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xffFFDAD3)),
                child: const Icon(
                  Icons.message,
                  size: 15,
                ),
              ),
            ),
    ]);
  }
}
