import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/controllers/workout_controller/work_out_controller.dart';
import 'package:fitness_zone_2/data/models/get_all_users/get_all_users_based_on_type.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:fitness_zone_2/widgets/circular_progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/models/add_package/add_package_model.dart';
import '../../data/api_provider/api_provider.dart';
import '../../values/constants.dart';
import '../../values/my_colors.dart';
import '../../widgets/toasts.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/class_option_picker.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class AddTrainerSlots extends StatelessWidget {
  AddTrainerSlots({super.key});
  WorkOutController workOutController = Get.find();
  HomeController home = Get.find();

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: HelpingWidgets().appBarWidget(() {
        Get.back();
      }, text: "Add Trainer Slots"),
      body: ListView(
        children: [
          GetBuilder<WorkOutController>(builder: (homeController) {
            // NOTE: previously this (and the per-day slot list below) were
            // built with ListView.separated(shrinkWrap: true, physics:
            // NeverScrollableScrollPhysics()) nested inside an outer
            // ListView, and the slot-level one nested inside an
            // ExpansionTile's animated children list on top of that. That's
            // a sliver (RenderSliverList) nested inside another sliver's
            // shrink-wrapped viewport, nested inside ExpansionTile's
            // AnimatedSize/ClipRect transition -- fragile even with fixed
            // row heights, and it started crashing (RenderBox was not laid
            // out / 'child.hasSize' assertions cascading through
            // RenderSliverMultiBoxAdaptor, RenderShrinkWrappingViewport,
            // RenderOffstage, etc.) once the per-slot rows became
            // variable-height after adding the workout-detail fields below.
            // Rebuilt with plain Column + Builder so there are no nested
            // slivers at all -- just a regular box-layout tree, which
            // ExpansionTile's animation and GetBuilder's rebuilds can
            // resize safely.
            if (!homeController.getAllTimesSlotsLoad.value) {
              return CircularProgress();
            }
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int index = 0;
                      index < homeController.addPackageTimeTable.length;
                      index++) ...[
                    if (index > 0) SizedBox(height: 10.h),
                    Builder(builder: (context) {
                      var dayTime = homeController.addPackageTimeTable[index];
                      return ExpansionTile(
                        onExpansionChanged: (bool value) {
                          if (value) {}
                        },
                        trailing:
                            const Icon(Icons.keyboard_arrow_down_rounded),
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          dayTime.day,
                          style: textTheme.bodyLarge,
                        ),
                        children: [
                          for (int timeIndex = 0;
                              timeIndex < dayTime.slots.length;
                              timeIndex++) ...[
                            if (timeIndex > 0) SizedBox(height: 10.h),
                            Builder(builder: (context) {
                              var slot = dayTime.slots[timeIndex];
                              print("${slot.toJson()}");

                              // Collapsed-by-default summary so a day with
                              // several slots doesn't dump every slot's full
                              // edit form (time pickers, trainer dropdown,
                              // workout-detail fields) on screen at once --
                              // tap a slot to open just that one.
                              String trainerLabel = 'No trainer selected';
                              if (slot.trainerId != null) {
                                final matches = home
                                        .getUsersBasedOnUserTypeModel?.users
                                        .where(
                                            (u) => u.id == slot.trainerId)
                                        .toList() ??
                                    [];
                                if (matches.isNotEmpty) {
                                  trainerLabel =
                                      '${matches.first.firstName} ${matches.first.lastName}';
                                }
                              }

                              return Container(
                                // `slotKey` lives on the Slot object itself
                                // (not tied to its index), so it stays
                                // attached to this exact slot across
                                // add/remove and rebuilds, letting us scroll
                                // straight to it once it's expanded.
                                key: slot.slotKey,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.black26),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: ExpansionTile(
                                          tilePadding: EdgeInsets.symmetric(
                                              horizontal: 10.w),
                                          childrenPadding:
                                              EdgeInsets.fromLTRB(
                                                  10.w, 0, 10.w, 10.h),
                                          onExpansionChanged: (expanded) {
                                            if (!expanded) return;
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                              final slotContext =
                                                  slot.slotKey.currentContext;
                                              if (slotContext != null) {
                                                Scrollable.ensureVisible(
                                                  slotContext,
                                                  duration: const Duration(
                                                      milliseconds: 300),
                                                  curve: Curves.easeInOut,
                                                  alignment: 0.05,
                                                );
                                              }
                                            });
                                          },
                                          title: Text(
                                            '${slot.start} - ${slot.end}',
                                            style: textTheme.bodyMedium,
                                          ),
                                          subtitle: Text(
                                            trainerLabel,
                                            style: TextStyle(
                                                color: MyColors.hintText,
                                                fontSize: 13.sp),
                                          ),
                                          children: [
                                            Column(
                                              children: [
                                                Row(children: [
                                                  Expanded(
                                                    child: GestureDetector(
                                                        onTap: () async {
                                                          TimeOfDay? time =
                                                              await showTimePicker(
                                                            context: context,
                                                            initialTime:
                                                                TimeOfDay
                                                                    .now(),
                                                            builder:
                                                                (BuildContext
                                                                        context,
                                                                    Widget?
                                                                        child) {
                                                              return Theme(
                                                                data: ThemeData
                                                                        .light()
                                                                    .copyWith(
                                                                  primaryColor:
                                                                      Colors
                                                                          .blue,
                                                                  dialogBackgroundColor:
                                                                      Colors
                                                                          .white,
                                                                  textTheme:
                                                                      const TextTheme(
                                                                    bodyLarge:
                                                                        TextStyle(
                                                                            color:
                                                                                Colors.black),
                                                                  ),
                                                                ),
                                                                child: child!,
                                                              );
                                                            },
                                                          );
                                                          if (time != null) {
                                                            final now =
                                                                DateTime.now();
                                                            final formatted =
                                                                DateFormat.jm()
                                                                    .format(
                                                              DateTime(
                                                                  now.year,
                                                                  now.month,
                                                                  now.day,
                                                                  time.hour,
                                                                  time
                                                                      .minute),
                                                            );
                                                            slot.start = time
                                                                .format(
                                                                    context);
                                                            homeController
                                                                .update();
                                                          }
                                                        },
                                                        child: Container(
                                                          height: 56.h,
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      5.w),
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          decoration: BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .black)),
                                                          child: Text(
                                                            slot.start,
                                                            style: slot.start ==
                                                                    "Start Time"
                                                                ? TextStyle(
                                                                    color: MyColors
                                                                        .hintText,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .normal,
                                                                    fontSize:
                                                                        14.sp)
                                                                : TextStyle(
                                                                    color: MyColors
                                                                        .textColor,
                                                                    fontSize:
                                                                        16.sp,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w400),
                                                          ),
                                                        )),
                                                  ),
                                                  SizedBox(
                                                    width: 10.w,
                                                  ),
                                                  Expanded(
                                                    child: GestureDetector(
                                                        onTap: () async {
                                                          TimeOfDay? time =
                                                              await showTimePicker(
                                                            context: context,
                                                            initialTime:
                                                                TimeOfDay
                                                                    .now(),
                                                            builder:
                                                                (BuildContext
                                                                        context,
                                                                    Widget?
                                                                        child) {
                                                              return Theme(
                                                                data: ThemeData
                                                                        .light()
                                                                    .copyWith(
                                                                  primaryColor:
                                                                      Colors
                                                                          .blue,
                                                                  dialogBackgroundColor:
                                                                      Colors
                                                                          .white,
                                                                  textTheme:
                                                                      const TextTheme(
                                                                    bodyLarge:
                                                                        TextStyle(
                                                                            color:
                                                                                Colors.black),
                                                                  ),
                                                                ),
                                                                child: child!,
                                                              );
                                                            },
                                                          );
                                                          if (time != null) {
                                                            final now =
                                                                DateTime.now();
                                                            final formatted =
                                                                DateFormat.jm()
                                                                    .format(
                                                              DateTime(
                                                                  now.year,
                                                                  now.month,
                                                                  now.day,
                                                                  time.hour,
                                                                  time
                                                                      .minute),
                                                            );

                                                            print(
                                                                'AddTrainerSlots.build  ${time}');
                                                            slot.end = time
                                                                .format(
                                                                    context);
                                                            print(
                                                                'AddTrainerSlots.build  ${time.format(context)}');
                                                            homeController
                                                                .update();
                                                          }
                                                        },
                                                        child: Container(
                                                          height: 56.h,
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      5.w),
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          decoration: BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .black)),
                                                          child: Text(
                                                            slot.end,
                                                            style: slot.end ==
                                                                    "End Time"
                                                                ? TextStyle(
                                                                    color: MyColors
                                                                        .hintText,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .normal,
                                                                    fontSize:
                                                                        14.sp)
                                                                : TextStyle(
                                                                    color: MyColors
                                                                        .textColor,
                                                                    fontSize:
                                                                        16.sp,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w400),
                                                          ),
                                                        )),
                                                  ),
                                                ]),
                                                const SizedBox(
                                                  height: 10,
                                                ),
                                                Obx(() => home
                                                        .getUsersBasedOnUserTypeLoad
                                                        .value
                                                    ? Container(
                                                        // width: 80,
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                              color: Colors
                                                                  .black),
                                                          color: MyColors
                                                              .textFieldColor,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8),
                                                        ),
                                                        child:
                                                            DropdownButtonFormField<
                                                                UserTypeData>(
                                                          style: TextStyle(
                                                              color: MyColors
                                                                  .textColor,
                                                              fontSize: 16.sp,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            16.w,
                                                                        vertical:
                                                                            12.h),
                                                            border: InputBorder
                                                                .none,
                                                          ),

                                                          //padding: EdgeInsets.symmetric(horizontal: 10.w),
                                                          value: slot
                                                                      .trainerId ==
                                                                  null
                                                              ? home
                                                                  .getUsersBasedOnUserTypeModel
                                                                  ?.users[0]
                                                              : home
                                                                  .getUsersBasedOnUserTypeModel
                                                                  ?.users
                                                                  .firstWhere((value) =>
                                                                      value.id ==
                                                                      (slot
                                                                          .trainerId)),
                                                          onChanged:
                                                              (UserTypeData?
                                                                  newValue) {
                                                            if (newValue !=
                                                                null) {
                                                              slot.trainerId = newValue
                                                                          .id ==
                                                                      0
                                                                  ? null
                                                                  : newValue
                                                                      .id;
                                                              homeController
                                                                  .update();
                                                            }
                                                          },
                                                          items: home
                                                              .getUsersBasedOnUserTypeModel!
                                                              .users
                                                              .map(
                                                                  (UserTypeData
                                                                      cat) {
                                                            return DropdownMenuItem<
                                                                UserTypeData>(
                                                              value: cat,
                                                              child: SizedBox(
                                                                //  width: 60.w,
                                                                child: Text(
                                                                  ("${cat.firstName} ${cat.lastName}")
                                                                      .toString(),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: textTheme
                                                                      .bodySmall!
                                                                      .copyWith(
                                                                          color:
                                                                              Colors.black,
                                                                          overflow:
                                                                              TextOverflow.ellipsis),
                                                                ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                      )
                                                    : CircularProgress()),
                                                // Workout details -- admin can
                                                // now fill these in right
                                                // here instead of a trainer
                                                // having to add them
                                                // separately afterward via
                                                // the Class Details screen.
                                                // Optional: left blank,
                                                // nothing changes -- so these
                                                // don't use the mandatory
                                                // "Please enter some text"
                                                // validator CustomTextField
                                                // shows by default (that
                                                // validator error state also
                                                // changes the field's
                                                // rendered height, which is
                                                // exactly the kind of
                                                // mid-animation resize that
                                                // broke layout before).
                                                const SizedBox(height: 10),
                                                // Picked from fixed options
                                                // (same list as the trainer's
                                                // Class Details screen) so the
                                                // spelling always matches the
                                                // client screens' colours.
                                                ClassOptionPicker(
                                                  key: ObjectKey(
                                                      slot.typeController),
                                                  label: "Class type",
                                                  options: kClassTypeOptions,
                                                  controller:
                                                      slot.typeController,
                                                  allowOther: true,
                                                ),
                                                const SizedBox(height: 14),
                                                ClassOptionPicker(
                                                  key: ObjectKey(
                                                      slot.levelController),
                                                  label: "Intensity",
                                                  options:
                                                      kClassIntensityOptions,
                                                  controller:
                                                      slot.levelController,
                                                ),
                                                const SizedBox(height: 10),
                                                CustomTextField(
                                                  height: 80,
                                                  moreThanOneLine: true,
                                                  keyboardType:
                                                      TextInputType.text,
                                                  text: "Description".tr,
                                                  length: 300,
                                                  controller: slot
                                                      .descriptionController,
                                                  inputFormatters:
                                                      FilteringTextInputFormatter
                                                          .singleLineFormatter,
                                                  validator: (value) => null,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    timeIndex == dayTime.slots.length - 1
                                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                                          if (slot.id != null) ...[
                                            _deleteButton(context, dayTime, slot),
                                            const SizedBox(height: 8),
                                          ],
                                          GestureDetector(
                                            onTap: () {
                                              dayTime.slots.add(Slot(
                                                  trainerId: null,
                                                  id: null,
                                                  dayId: dayTime.id,
                                                  start: "Start Time",
                                                  end: "End Time"));
                                              homeController.update();
                                            },
                                            child: Container(
                                              height: 40.h,
                                              width: 40.h,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: MyColors
                                                          .buttonColor,
                                                      width: 2)),
                                              child: const Icon(
                                                Icons.add,
                                                color: MyColors.buttonColor,
                                              ),
                                            ),
                                          )])
                                        : slot.id != null
                                            ? _deleteButton(context, dayTime, slot)
                                            : GestureDetector(
                                            onTap: () {
                                              dayTime.slots
                                                  .removeAt(timeIndex);
                                              homeController.update();
                                            },
                                            child: Container(
                                              height: 40.h,
                                              width: 40.h,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: MyColors
                                                          .buttonColor,
                                                      width: 2)),
                                              child: const Icon(
                                                Icons.remove,
                                                color: MyColors.buttonColor,
                                              ),
                                            ),
                                          )
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      );
                    }),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: HelpingWidgets().bottomBarButtonWidget(onTap: () {
        workOutController.addTrainerSlots();
      }),
    );
  }

  /// Red bin for a saved slot: deletes it on the server (it leaves the
  /// timetable for everyone; past attendance and ratings stay).
  Widget _deleteButton(BuildContext context, Time dayTime, Slot slot) => GestureDetector(
        onTap: () => _deleteSavedSlot(context, dayTime, slot),
        child: Container(
          height: 40.h,
          width: 40.h,
          decoration: BoxDecoration(
              shape: BoxShape.circle, border: Border.all(color: const Color(0xFFC24A4A), width: 2)),
          child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFC24A4A), size: 20),
        ),
      );

  Future<void> _deleteSavedSlot(BuildContext context, Time dayTime, Slot slot) async {
    final sure = await Get.dialog<bool>(AlertDialog(
      title: const Text('Delete this class slot?'),
      content: Text('${dayTime.day} ${slot.start} - ${slot.end} will be removed from the timetable for everyone. '
          'Women booked into it will no longer see it. Past attendance and ratings are kept.'),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: const Text('Delete slot', style: TextStyle(color: Color(0xFFC24A4A), fontWeight: FontWeight.w700)),
        ),
      ],
    ));
    if (sure != true) return;
    Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
    final r = await Get.find<ApiProvider>().postData('/admin/slots/${slot.id}/delete',
        body: {}, headers: {'accessToken': home.sharedPreferences.getString(Constants.accessToken) ?? ''});
    Get.back();
    final b = r.body;
    if (b is Map && '${b['status']}' == '1') {
      dayTime.slots.remove(slot);
      if (dayTime.slots.isEmpty) {
        dayTime.slots.add(Slot(trainerId: null, id: null, dayId: dayTime.id, start: "Start Time", end: "End Time"));
      }
      workOutController.update();
      CustomToast.successToast(msg: 'Slot deleted');
    } else {
      CustomToast.failToast(msg: b is Map ? b['message'] : "Couldn't delete. Please try again.");
    }
  }
}
