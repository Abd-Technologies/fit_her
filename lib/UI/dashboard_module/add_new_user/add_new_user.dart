import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../data/models/get_all_cat_plan/get_all_sub_cat.dart';
import '../../../data/models/get_all_users/get_all_users_based_on_type.dart';
import '../../../data/models/get_user_plan/get_user_plan.dart';
import '../../../values/dimens.dart';
import '../../../values/my_colors.dart';
import '../../../values/my_imgs.dart';
import '../../../widgets/app_bar_widget.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../widgets/circular_progress.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_textfield.dart';
import '../../../widgets/toasts.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class AddNewUser extends StatelessWidget {
  AddNewUser({Key? key, this.isMember = false}) : super(key: key);
  final bool isMember;
  final AuthController authController = Get.find();
  final HomeController homeController = Get.find();

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: HelpingWidgets().appBarWidget(() {
        Get.back();
      }, text: isMember ? "Add Member" : "Add User"),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Dimens.size20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: Dimens.size32.h,
              ),
              CustomTextField(
                keyboardType: TextInputType.text,
                text: "First Name".tr,
                length: 30,
                controller: homeController.firstNameController,
                inputFormatters:
                    FilteringTextInputFormatter.singleLineFormatter,
              ),
              SizedBox(
                height: 20.h,
              ),
              CustomTextField(
                keyboardType: TextInputType.text,
                text: "Last Name".tr,
                length: 30,
                controller: homeController.lastNameController,
                inputFormatters:
                    FilteringTextInputFormatter.singleLineFormatter,
              ),
              SizedBox(
                height: 20.h,
              ),
              CustomTextField(
                keyboardType: TextInputType.text,
                text: "Email".tr,
                length: 30,
                controller: homeController.emailController,
                inputFormatters:
                    FilteringTextInputFormatter.singleLineFormatter,
              ),
              SizedBox(
                height: 20.h,
              ),
              CustomTextField(
                keyboardType: TextInputType.text,
                text: "Phone no".tr,
                length: 30,
                controller: homeController.phoneController,
                inputFormatters:
                    FilteringTextInputFormatter.singleLineFormatter,
              ),
              SizedBox(
                height: 20.h,
              ),
              CustomTextField(
                keyboardType: TextInputType.text,
                text: "Password".tr,
                length: 30,
                controller: homeController.passwordController,
                inputFormatters:
                    FilteringTextInputFormatter.singleLineFormatter,
              ),
              SizedBox(
                height: 20.h,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isMember
                      ? Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black),
                                color: MyColors.textFieldColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonFormField<String>(
                                style: TextStyle(
                                    color: MyColors.textColor,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16.w, vertical: 12.h),
                                  border: InputBorder.none,
                                ),

                                //padding: EdgeInsets.symmetric(horizontal: 10.w),
                                value: homeController.addTeamMember[0],
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    homeController.addedTeamMember.value =
                                        newValue;
                                    if (!homeController
                                        .isCustomerSupport.value) {
                                      homeController
                                          .getSubCatBasedOnUserType(newValue);
                                    }
                                  }
                                },
                                items: homeController.addTeamMember
                                    .map((String cat) {
                                  return DropdownMenuItem<String>(
                                    value: cat,
                                    child: Text(
                                      cat,
                                      style: textTheme.bodySmall!
                                          .copyWith(color: Colors.black),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            SizedBox(
                              height: 16.h,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 20.h,
                            ),
                            Text(
                              "Please select customer support representative",
                              style: textTheme.headlineSmall!.copyWith(
                                  fontSize: 15.sp,
                                  color: MyColors.textColor3,
                                  fontWeight: FontWeight.w600),
                            ),
                            SizedBox(
                              height: 10.h,
                            ),
                            Obx(() => homeController
                                    .getUsersBasedOnUserTypeLoad.value
                                ? homeController.getUsersBasedOnUserTypeModel!
                                        .users.isNotEmpty
                                    ? Container(
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.black),
                                          color: MyColors.textFieldColor,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: DropdownButtonFormField<
                                            UserTypeData>(
                                          style: TextStyle(
                                              color: MyColors.textColor,
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w600),
                                          decoration: InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 16.w,
                                                    vertical: 12.h),
                                            border: InputBorder.none,
                                          ),

                                          //padding: EdgeInsets.symmetric(horizontal: 10.w),
                                          value: homeController
                                              .getUsersBasedOnUserTypeModel!
                                              .users
                                              .firstWhere((element) =>
                                                  element.id ==
                                                  homeController
                                                      .selectCustomerSupport
                                                      .value),
                                          onChanged: (UserTypeData? newValue) {
                                            if (newValue != null) {
                                              homeController
                                                  .selectCustomerSupport
                                                  .value = newValue.id;
                                            }
                                          },
                                          items: homeController
                                              .getUsersBasedOnUserTypeModel!
                                              .users
                                              .map((UserTypeData cat) {
                                            return DropdownMenuItem<
                                                UserTypeData>(
                                              value: cat,
                                              child: SizedBox(
                                                width: 200.w,
                                                child: Text(
                                                  "${cat.id}: ${cat.firstName} ${cat.lastName}",
                                                  maxLines: 2,
                                                  style: textTheme.bodySmall!
                                                      .copyWith(
                                                          color: Colors.black,
                                                          overflow: TextOverflow
                                                              .ellipsis),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      )
                                    : SizedBox.shrink()
                                : const Center(
                                    child: FhLoader())),
                          ],
                        ),
                  isMember
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 20.h),
                            Text(
                              "Select Plan",
                              style: textTheme.headlineMedium!
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(
                              height: 10.h,
                            ),
                            // isMember
                            //     ?
                            Obx(() => homeController.getPlanLoaded.value
                                ? SizedBox(
                                    height: 180.h,
                                    child: ListView.separated(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 20.h),
                                      itemCount: homeController
                                          .allPlanModel!.plans.length,
                                      scrollDirection: Axis.horizontal,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        var plan = homeController
                                            .allPlanModel!.plans[index];

                                        return GestureDetector(
                                          onTap: () {
                                            homeController.selectedPlanIndex
                                                .value = index;
                                          },
                                          child: Obx(
                                            () => Container(
                                              width: 300.w,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                      color: homeController
                                                                  .selectedPlanIndex
                                                                  .value ==
                                                              index
                                                          ? MyColors.buttonColor
                                                          : Colors.white),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        offset: Offset(0, 2),
                                                        blurRadius: 4,
                                                        color: Colors.black
                                                            .withOpacity(0.1))
                                                  ]),
                                              child: Column(
                                                children: [
                                                  Expanded(
                                                    child: Row(children: [
                                                      SizedBox(
                                                        width: 70.w,
                                                        child: Image.asset(
                                                            MyImgs.logo),
                                                      ),
                                                      SizedBox(
                                                        width: 10.w,
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              plan.title,
                                                              style: textTheme
                                                                  .bodyLarge!
                                                                  .copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            Text(
                                                              plan.shortDescription,
                                                              style: textTheme
                                                                  .bodySmall!
                                                                  .copyWith(),
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),

                                                            // Text(
                                                            //   "Duration: ${plan.countries![0].duration![0].days}",
                                                            //   style: textTheme
                                                            //       .titleLarge!
                                                            //       .copyWith(),
                                                            //   maxLines: 2,
                                                            //   overflow: TextOverflow
                                                            //       .ellipsis,
                                                            // ),
                                                            // Text(
                                                            //   "PKR ${plan.countries![0].duration![0].priceAmount}",
                                                            //   style: textTheme
                                                            //       .titleLarge!
                                                            //       .copyWith(
                                                            //     fontWeight:
                                                            //         FontWeight.w500,
                                                            //   ),
                                                            // ),
                                                          ],
                                                        ),
                                                      )
                                                    ]),
                                                  ),
                                                  Container(
                                                    height: 30,
                                                    alignment: Alignment.center,
                                                    decoration: const BoxDecoration(
                                                        // border: Border.all(
                                                        //     color: Colors.black),
                                                        // color: MyColors
                                                        //     .textFieldColor,
                                                        // borderRadius:
                                                        //     BorderRadius.circular(
                                                        //         8),
                                                        ),
                                                    child:
                                                        DropdownButtonFormField<
                                                            DurationPlan>(
                                                      style: TextStyle(
                                                          color: MyColors
                                                              .textColor,
                                                          fontSize: 16.sp,
                                                          fontWeight:
                                                              FontWeight.w600),

                                                      decoration:
                                                          InputDecoration(
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                          horizontal: 5.w,
                                                        ),
                                                        border:
                                                            InputBorder.none,
                                                      ),

                                                      //padding: EdgeInsets.symmetric(horizontal: 10.w),
                                                      value: plan.selectedDurationId
                                                                  .value ==
                                                              0
                                                          ? plan.countries![0]
                                                              .duration![0]
                                                          : plan.countries![0]
                                                              .duration!
                                                              .firstWhere((value) =>
                                                                  value.id ==
                                                                  plan.selectedDurationId
                                                                      .value),
                                                      onChanged: (DurationPlan?
                                                          newValue) {
                                                        if (newValue != null) {
                                                          plan.selectedDurationId
                                                                  .value =
                                                              newValue.id!;
                                                        }
                                                      },
                                                      items: plan.countries![0]
                                                          .duration!
                                                          .map((DurationPlan
                                                              cat) {
                                                        return DropdownMenuItem<
                                                            DurationPlan>(
                                                          value: cat,
                                                          child: SizedBox(
                                                            // width: 100.w,
                                                            child: Text(
                                                              "${cat.id}: ${cat.days} ${cat.priceAmount}",
                                                              maxLines: 2,
                                                              style: textTheme
                                                                  .bodySmall!
                                                                  .copyWith(
                                                                      color: Colors
                                                                          .black,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis),
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    height: 5,
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      separatorBuilder:
                                          (BuildContext context, int index) {
                                        return SizedBox(
                                          width: 10.w,
                                        );
                                      },
                                    ))
                                : const Center(
                                    child: CircularProgress(),
                                  )),
                            SizedBox(
                              height: 20.h,
                            ),
                          ],
                        ),
                ],
              )
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomButton(
                text: "Add",
                onPressed: () async {
                  if (isMember) {
                    if (homeController.firstNameController.text.isEmpty ||
                        homeController.lastNameController.text.isEmpty ||
                        homeController.emailController.text.isEmpty ||
                        homeController.phoneController.text.isEmpty) {
                      CustomToast.failToast(
                          msg: "Please provide all information");
                    } else if (!homeController.emailController.text.isEmail) {
                      CustomToast.failToast(msg: "Please provide valid email");
                    } else {
                      int id = homeController.addedTeamMember.value == "Trainer"
                          ? homeController.selectedTrainerIdForMember.value
                          : homeController.selectedDietIdForMember.value;
                      if (homeController.isCustomerSupport.value) {
                        homeController.addTeamMemberFunc(null);
                      } else {
                        homeController.addTeamMemberFunc(null);
                      }
                    }
                  } else {
                    if (homeController.firstNameController.text.isEmpty ||
                        homeController.lastNameController.text.isEmpty ||
                        homeController.emailController.text.isEmpty ||
                        homeController.phoneController.text.isEmpty) {
                      CustomToast.failToast(
                          msg: "Please provide all information");
                    } else if (!homeController.emailController.text.isEmail) {
                      CustomToast.failToast(msg: "Please provide valid email");
                    } else {
                      var plan = homeController.allPlanModel!
                          .plans[homeController.selectedPlanIndex.value];
                      var price = plan.countries![0].duration
                              ?.firstWhere(
                                  (v) => v.id == plan.selectedDurationId.value)
                              .priceAmount ??
                          "N/A";
                      Get.find<HomeController>().addUser(
                          status: false,
                          firstName: homeController.firstNameController.text,
                          lastName: homeController.lastNameController.text,
                          email: homeController.emailController.text,
                          phone: homeController.phoneController.text,
                          password: homeController.passwordController.text, customerSupportId: homeController.selectCustomerSupport.value);
                    }
                  }
                }),
          ],
        ),
      ),
    ),
  );
}
}
