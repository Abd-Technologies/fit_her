import 'package:fitness_zone_2/data/models/country_model.dart';
import 'package:fitness_zone_2/data/models/duration_model.dart';
import 'package:fitness_zone_2/data/models/get_all_cat_plan/get_all_sub_cat.dart';
import 'package:fitness_zone_2/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/controllers/diet_contoller/diet_controller.dart';
import '../../../data/controllers/home_controller/home_controller.dart';
import '../../../data/controllers/plan_controller/plan_controller.dart';
import '../../../data/models/add_package/add_package_model.dart';
import '../../../data/models/get_all_cat_plan/get_all_categories.dart';
import '../../../helper/validators.dart';
import '../../../values/my_colors.dart';
import '../../../values/my_imgs.dart';
import '../../../widgets/app_bar_widget.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../widgets/circular_progress.dart';
import '../../../widgets/custom_textfield.dart';
import '../../../widgets/toasts.dart';
import '../../diet_screen/doctor_details.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class AddPackage extends StatelessWidget {
  AddPackage({super.key, this.isFromUpdate = false, this.id});
  final bool isFromUpdate;
  final String? id;
  final PlanController planController = Get.find();
  final HomeController homeController = Get.find();

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: HelpingWidgets().appBarWidget(() {
        Get.back();
      }, text: isFromUpdate ? "Update Package" : "Add Package"),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20.h,
              ),
              CustomTextField(
                text: "Package name",
                length: 500,
                controller: planController.packageName,
                validator: (value) =>
                    Validators.firstNameValidation(value!.toString()),
                keyboardType: TextInputType.text,
                inputFormatters:
                    FilteringTextInputFormatter.singleLineFormatter,
              ),
              SizedBox(
                height: 16.h,
              ),
              CustomTextField(
                text: "Description",
                length: 500,
                controller: planController.shortDis,
                validator: (value) =>
                    Validators.firstNameValidation(value!.toString()),
                keyboardType: TextInputType.text,
                inputFormatters:
                    FilteringTextInputFormatter.singleLineFormatter,
              ),
              SizedBox(
                height: 16.h,
              ),
              CustomTextField(
                text: "Long Description",
                length: 500,
                controller: planController.longDis,
                validator: (value) =>
                    Validators.emailValidator(value!.toString()),
                keyboardType: TextInputType.text,
                inputFormatters:
                    FilteringTextInputFormatter.singleLineFormatter,
              ),
              SizedBox(
                height: 16.h,
              ),
              Obx(() => planController.getCatLoaded.value
                  ? Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        color: MyColors.textFieldColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonFormField<Category>(
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
                        value: planController.allCategoriesOfPlan!.categories
                            .firstWhere((element) =>
                                element.id == planController.selectedId.value),
                        onChanged: (Category? newValue) {
                          if (newValue != null) {
                            planController.selectedId.value = newValue.id;
                            planController
                                .getSubCategories(newValue.id.toString());
                            planController.update();
                          }
                        },
                        items: planController.allCategoriesOfPlan!.categories
                            .map((Category cat) {
                          return DropdownMenuItem<Category>(
                            value: cat,
                            child: Text(
                              cat.title,
                              style: textTheme.bodySmall!
                                  .copyWith(color: Colors.black),
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  : const Center(
                      child: FhLoader())),
              SizedBox(
                height: 16.h,
              ),
              Obx(() => planController.selectedSubCatId.value == 0
                  ? const SizedBox.shrink()
                  : planController.getSubCatLoaded.value
                      ? Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            color: MyColors.textFieldColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonFormField<SubCategory>(
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
                            value: planController.allSubCategories!.data
                                .firstWhere((element) =>
                                    element.id ==
                                    planController.selectedSubCatId.value),
                            onChanged: (SubCategory? newValue) {
                              if (newValue != null) {
                                planController.selectedSubCatId.value =
                                    newValue.id;
                              }
                            },
                            items: planController.allSubCategories!.data
                                .map((SubCategory cat) {
                              return DropdownMenuItem<SubCategory>(
                                value: cat,
                                child: SizedBox(
                                  width: 200.w,
                                  child: Text(
                                    cat.title,
                                    maxLines: 2,
                                    style: textTheme.bodySmall!.copyWith(
                                        color: Colors.black,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      : const Center(
                          child: FhLoader())),
              SizedBox(
                height: 20.h,
              ),
              GetBuilder<PlanController>(builder: (planCont) {
                return Column(
                  children: [
                    if (planCont.addCountriesList.isEmpty)
                      CustomButton(
                          text: "Add Country",
                          onPressed: () {
                            planCont.addCountry(
                                planCont.countryList!.countries.first);
                          }),
                    ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemBuilder: (context, int index) {
                          var country = planCont.addCountriesList[index];
                          return Row(
                            children: [
                              Expanded(
                                child: ExpansionTile(
                                  onExpansionChanged: (bool value) {
                                    if (value) {}
                                  },
                                  collapsedIconColor: Colors.black,
                                  iconColor: Colors.black,
                                  trailing: const Icon(
                                      Icons.keyboard_arrow_down_rounded),
                                  tilePadding: EdgeInsets.zero,
                                  title: Obx(() => planController
                                          .getAllCountriesLoad.value
                                      ? Container(
                                          // width: 80,
                                          decoration: BoxDecoration(
                                            // border: Border.all(color: Colors.black),
                                            // color: MyColors.textFieldColor,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child:
                                              DropdownButtonFormField<Country>(
                                            style: TextStyle(
                                                color: MyColors.textColor,
                                                fontSize: 20.sp,
                                                fontWeight: FontWeight.w700),
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 5.w,
                                                      vertical: 5.h),
                                              border: InputBorder.none,
                                            ),

                                            //padding: EdgeInsets.symmetric(horizontal: 10.w),
                                            value: country.id == 0
                                                ? planCont
                                                    .countryList?.countries[0]
                                                : planCont
                                                    .countryList?.countries
                                                    .firstWhere((value) =>
                                                        value.id == country.id),
                                            onChanged: (Country? newValue) {
                                              if (newValue != null) {
                                                country.id = newValue.id;
                                                planCont.update();
                                              }
                                            },
                                            items: planCont
                                                .countryList?.countries
                                                .map((Country cat) {
                                              return DropdownMenuItem<Country>(
                                                value: cat,
                                                child: SizedBox(
                                                  //  width: 60.w,
                                                  child: Text(
                                                    cat.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: textTheme.bodySmall!
                                                        .copyWith(
                                                            color: Colors.black,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        )
                                      : CircularProgress()),
                                  children: [
                                    ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemBuilder: (context, int timeIndex) {
                                          var duration =
                                              country.durationList[timeIndex];
                                          return Row(children: [
                                            Obx(() => planController
                                                    .getAllDurationLoad.value
                                                ? Container(
                                                    width: 110,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: Colors.black),
                                                      color: MyColors
                                                          .textFieldColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child:
                                                        DropdownButtonFormField<
                                                            DurationModel>(
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
                                                                    horizontal:
                                                                        7.w,
                                                                    vertical:
                                                                        12.h),
                                                        border:
                                                            InputBorder.none,
                                                      ),

                                                      //padding: EdgeInsets.symmetric(horizontal: 10.w),
                                                      value: duration.id == 0
                                                          ? planCont
                                                              .durationList
                                                              ?.durations[0]
                                                          : planCont
                                                              .durationList
                                                              ?.durations
                                                              .firstWhere(
                                                                  (value) =>
                                                                      value
                                                                          .id ==
                                                                      duration
                                                                          .id),
                                                      onChanged: (DurationModel?
                                                          newValue) {
                                                        if (newValue != null) {
                                                          duration.id =
                                                              newValue.id;
                                                          planCont.update();
                                                        }
                                                      },
                                                      items: planCont
                                                          .durationList
                                                          ?.durations
                                                          .map((DurationModel
                                                              cat) {
                                                        return DropdownMenuItem<
                                                            DurationModel>(
                                                          value: cat,
                                                          child: SizedBox(
                                                            //  width: 60.w,
                                                            child: Text(
                                                              cat.duration
                                                                  .toString(),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
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
                                                  )
                                                : CircularProgress()),
                                            SizedBox(
                                              width: 10.w,
                                            ),
                                            SizedBox(
                                              width: 100,
                                              child: CustomTextField(
                                                text: "Amount",
                                                length: 100,
                                                height: 50,
                                                keyboardType:
                                                    TextInputType.text,
                                                inputFormatters:
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                controller: duration.amount,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 10,
                                            ),
                                            timeIndex ==
                                                    country.durationList
                                                            .length -
                                                        1
                                                ? HelpingWidgets()
                                                    .iconPlusMinus(
                                                    onTap: () {
                                                      country.durationList.add(
                                                          DurationPackageSent(
                                                              id: 0));

                                                      planCont.update();
                                                    },
                                                  )
                                                : HelpingWidgets()
                                                    .iconPlusMinus(
                                                    onTap: () {
                                                      country.durationList
                                                          .removeAt(timeIndex);
                                                      planCont.update();
                                                    },
                                                    icon: Icons.remove,
                                                  )
                                          ]);
                                        },
                                        separatorBuilder: (context, int index) {
                                          return SizedBox(
                                            height: 10.h,
                                          );
                                        },
                                        itemCount: country.durationList.length)
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              index ==
                                      planController.addCountriesList.length - 1
                                  ? HelpingWidgets().iconPlusMinus(
                                      onTap: () {
                                        Country? con = planCont
                                            .findCountryWhichIsNotAdded();
                                        print("coming  alue  ${con}");
                                        if (con == null) {
                                          CustomToast.failToast(
                                              msg:
                                                  "No other Countries available");
                                          return;
                                        }
                                        planCont.addCountry(con);
                                      },
                                    )
                                  : HelpingWidgets().iconPlusMinus(
                                      onTap: () {
                                        planCont.addCountriesList
                                            .removeAt(index);
                                        planCont.update();
                                      },
                                      icon: Icons.remove,
                                    )
                            ],
                          );
                        },
                        separatorBuilder: (context, int index) {
                          return SizedBox(
                            height: 10.h,
                          );
                        },
                        itemCount: planController.addCountriesList.length),
                    SizedBox(
                      height: 20.h,
                    ),
                    if (planController.allCategoriesOfPlan?.categories
                            .firstWhere(
                              (category) =>
                                  category.id ==
                                  planController.selectedId.value,
                              orElse: () => Category(
                                  id: -1,
                                  title: ''), // default in case not found
                            )
                            .title !=
                        "Workout") ...{
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Associate Dietitian to Plan"),
                          SizedBox(
                            height: 110.h,
                            child: Obx(() {
                              // Check loading state to display list or progress indicator
                              return homeController
                                      .getUsersBasedOnUserTypeLoad.value
                                  ? HelpingWidgets().list(
                                      homeController
                                          .getUsersBasedOnUserTypeModel!.users,
                                      homeController.selectedDietIdForMember,
                                      textTheme,
                                    )
                                  : const CircularProgress();
                            }),
                          ),
                          const SizedBox(height: 10),
                        ],
                      )
                    } else ...{
                      SizedBox()
                    }
                  ],
                );
              }),
              CustomButton(
                  text: isFromUpdate ? "Update Package" : "Add Package",
                  onPressed: () {
                    if (planController.packageName.text.isEmpty ||
                        planController.shortDis.text.isEmpty ||
                        planController.longDis.text.isEmpty) {
                      CustomToast.failToast(
                          msg: "Please provide all information");
                    } else {
                      if (isFromUpdate) {
                        planController.updatePlan(id ?? "");
                      } else {
                        final selectedCategoryTitle =
                            planController.allCategoriesOfPlan?.categories
                                .firstWhere(
                                  (category) =>
                                      category.id ==
                                      planController.selectedId.value,
                                  orElse: () => Category(
                                      id: -1,
                                      title: ''), // default in case not found
                                )
                                .title;
                        if (selectedCategoryTitle == "Workout") {
                          planController.addPlan();
                        } else {
                          if (homeController.selectedDietIdForMember.value ==
                              0) {
                            CustomToast.failToast(
                                msg: "Please select dietitian first");
                          } else {
                            planController.addPlan(
                                dietitianId: homeController
                                    .selectedDietIdForMember.value
                                    .toString());
                          }
                        }
                      }
                    }
                  }),
              SizedBox(
                height: 20.h,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
