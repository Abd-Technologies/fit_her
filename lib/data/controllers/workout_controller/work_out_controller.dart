import 'package:fitness_zone_2/UI/dashboard_module/bottom_bar_screen/bottom_bar_screen.dart';
import 'package:fitness_zone_2/widgets/new_home/trial_cta_card.dart';
import 'package:fitness_zone_2/data/models/get_user_plan/get_workout_user_plan_details.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../helper/permissions.dart';
import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';
import '../../GetServices/CheckConnectionService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:fitness_zone_2/data/models/add_package/add_package_model.dart'
    as addPackage;

import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitness_zone_2/utils/app_clock.dart';
import '../../Repos/home_repo/home_repo.dart';
import '../../models/api_response/api_response_model.dart';
import '../../models/free_trial_user_details.dart';
import '../../models/get_user_plan/get_user_plan.dart';
import '../auth_controller/auth_controller.dart';
import '../../../helper/analytics_helper.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class WorkOutController extends GetxController implements GetxService {
  SharedPreferences sharedPreferences;
  HomeRepo homeRepo;
  AuthController authController = Get.find();

  WorkOutController({required this.sharedPreferences, required this.homeRepo});

  CheckConnectionService connectionService = CheckConnectionService();

  ///Rx Variables
  var workOutOfUserLoad = false.obs;
  var workOutPlanDetailsLoad = false.obs;
  var getAllTimesSlotsLoad = false.obs;
  var getFreeTrialUserDetailsLoad = false.obs;
  var trainerHomeLoad = false.obs;

  var freeTrialSlots = [].obs;
  var freeTrailSlotIndex = 0;

  List<FreeTrialUser> freeTrialUser = [];
  List<addPackage.Time> addPackageTimeTable = [];

  ///models
  AllPlanModel? workoutPlans;
  GetUserWorkoutPlanDetails? getUserWorkoutPlanDetailsPlan;
  GetUserWorkoutPlanDetails? getTrainerHome;

  DateTime? _lastWorkoutAllPlansFetched;
  DateTime? _lastDietPlanDetailsFetched;
  String? _lastDietPlanDetailsId;
  static const Duration _workoutPlansTtl = Duration(minutes: 5);
  static const Duration _planDetailsTtl = Duration(minutes: 3);

  getWorkoutAllPlansFunc({bool isFree = false, bool silent = false, bool forceRefresh = false}) {
    final now = DateTime.now();
    final isFresh = _lastWorkoutAllPlansFetched != null &&
        now.difference(_lastWorkoutAllPlansFetched!) < _workoutPlansTtl;

    if (!forceRefresh && workoutPlans != null && isFresh) {
      workOutOfUserLoad.value = true;
      return;
    }

    if (workoutPlans == null && !silent) {
      workOutOfUserLoad.value = false;
    }
    connectionService.checkConnection().then((value) async {
      if (!value) {
        if (!silent) CustomToast.noInternetToast();
      } else {
        homeRepo
            .getUserPlansWorkout(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userId: sharedPreferences.getString(Constants.userId) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<AllPlanModel> model =
                ApiResponse.fromJson(response.body, AllPlanModel.fromJson);
            if (model.status == "1") {
              workoutPlans = model.data;
              _lastWorkoutAllPlansFetched = DateTime.now();
              workOutOfUserLoad.value = true;
              print(
                  'WorkOutController.getWorkoutAllPlansFunc ${(workoutPlans?.plans.isNotEmpty)}');
              if (isFree && !(workoutPlans?.plans.isNotEmpty ?? true)) {
                // Consolidated: route through the same confirm-and-start
                // dialog every other entry point uses, instead of jumping
                // straight to TrialJourneyScreen's own (redundant, and
                // quick-intake-skipping) confirm dialog.
                showTrialStartDialog();
              }
            }
          }
        });
      }
    });
  }

  // [silent] true = heartbeat refresh from the schedule's polling timer.
  // Skips the load-flag toggle so the screen doesn't flash a spinner,
  // and skips toast errors so transient network blips don't spam the
  // user. Returns true on a status="1" payload — the schedule uses
  // that to drive the connection banner.
  Future<bool> getDietPlanDetailsFunc(
    String id, {
    bool showSlots = false,
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final isFresh = _lastDietPlanDetailsFetched != null &&
        _lastDietPlanDetailsId == id &&
        now.difference(_lastDietPlanDetailsFetched!) < _planDetailsTtl;

    if (!forceRefresh && !silent && getUserWorkoutPlanDetailsPlan != null && isFresh) {
      workOutPlanDetailsLoad.value = true;
      return true;
    }

    print(
        'WorkOutController.getDietPlanDetailsFunc${silent ? ' (silent)' : ''}');
    if (!silent) workOutPlanDetailsLoad.value = false;
    final hasInternet = await connectionService.checkConnection();
    if (!hasInternet) {
      if (!silent) CustomToast.noInternetToast();
      return false;
    }
    try {
      final response = await homeRepo.getUserPlanDetailsWorkout(
        accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        planId: id,
        userId: sharedPreferences.getString(Constants.userId) ?? "",
        showSlots: showSlots,
      );
      if (response.body["status"] == "0") {
        if (!silent) CustomToast.failToast(msg: response.body["message"]);
        return false;
      }
      final model = ApiResponse<GetUserWorkoutPlanDetails>.fromJson(
        response.body,
        GetUserWorkoutPlanDetails.fromJson,
      );
      if (model.status != "1") return false;
      getUserWorkoutPlanDetailsPlan = model.data;
      _lastDietPlanDetailsFetched = DateTime.now();
      _lastDietPlanDetailsId = id;
      if (showSlots) {
        final nowAtServer = AppClock.now();
        final today = DateFormat('EEEE').format(nowAtServer);
        final tomorrow =
            DateFormat('EEEE').format(nowAtServer.add(const Duration(days: 1)));
        final filter = getUserWorkoutPlanDetailsPlan?.trainerSlots
                .where((t) => t.day == today || t.day == tomorrow)
                .toList() ??
            [];
        getUserWorkoutPlanDetailsPlan?.trainerSlots = filter;
      }
      workOutPlanDetailsLoad.value = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  // Lightweight per-slot refresh. Patches the in-memory slot at [slotId]
  // with fresh status / trainerLink / isTrainerJoined / joinedUserUID and
  // forces a rebuild via update(). Used by the popup-open trigger and any
  // future per-slot smart triggers. Returns the updated fields, or null
  // on any failure (silent — caller decides what to do).
  Future<Map<String, dynamic>?> refreshSlotStatus(int slotId) async {
    try {
      final token = sharedPreferences.getString(Constants.accessToken) ?? '';
      final response = await homeRepo.getSlotStatus(
        accessToken: token,
        slotId: slotId,
      );
      final body = response.body;
      if (body is! Map || body['status'] != '1') return null;
      final patch = body['data']?['slot'];
      if (patch is! Map) return null;
      // Walk the cached trainerSlots tree and patch in place.
      final plan = getUserWorkoutPlanDetailsPlan;
      if (plan == null) return Map<String, dynamic>.from(patch);
      for (final daySlot in plan.trainerSlots) {
        for (final slot in daySlot.slots) {
          if (slot.id == slotId) {
            if (patch.containsKey('status'))
              slot.status = patch['status'] as String?;
            if (patch.containsKey('trainerLink'))
              slot.trainerLink = patch['trainerLink'] as String?;
            if (patch.containsKey('isTrainerJoined')) {
              slot.isTrainerJoined = patch['isTrainerJoined'] as bool?;
            }
            if (patch.containsKey('joinedUserUID')) {
              slot.joinedUserUID = patch['joinedUserUID'] as int?;
            }
            update();
            return Map<String, dynamic>.from(patch);
          }
        }
      }
      return Map<String, dynamic>.from(patch);
    } catch (_) {
      return null;
    }
  }

  /// Trainer home (her week of classes). [silent]: pull-to-refresh keeps
  /// the list on screen while it reloads instead of showing a spinner.
  Future<void> getTrainerHomeFunc({bool silent = false}) async {
    if (!silent || getTrainerHome == null) trainerHomeLoad.value = false;
    final online = await connectionService.checkConnection();
    if (!online) {
      CustomToast.noInternetToast();
      return;
    }
    try {
      final response = await homeRepo.getTrainerHome(
        accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        userId: sharedPreferences.getString(Constants.userId) ?? "",
      );
      if (response.body["status"] == "0") {
        CustomToast.failToast(msg: response.body["message"]);
      } else if (response.body["status"] != "0") {
        ApiResponse<GetUserWorkoutPlanDetails> model = ApiResponse.fromJson(
            response.body, GetUserWorkoutPlanDetails.fromJson);
        if (model.status == "1") {
          getTrainerHome = model.data!;
          trainerHomeLoad.value = true;
          update();
        }
      }
    } catch (_) {
      CustomToast.failToast(msg: "Couldn't refresh. Please try again.");
    }
    // Keep the old list visible if the refresh failed.
    if (getTrainerHome != null) trainerHomeLoad.value = true;
  }

  addTrainerSlots() {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()),
            barrierDismissible: false);

        addPackageTimeTable.removeWhere((time) {
          // Remove invalid slots
          time.slots.removeWhere((slot) =>
              slot.start == "Start Time" ||
              slot.end == "End Time" ||
              slot.trainerId == null);

          // Optionally remove the entire time object if slots list is empty
          return time.slots.isEmpty;
        });
        for (var time in addPackageTimeTable) {
          for (var slot in time.slots) {
            //  if(slot.start.contains("AM")||slot.start.contains("PM")){
            slot.start = covertToTimeStamp(slot.start).toString();
            slot.end = covertToTimeStamp(slot.end).toString();
            //   }
          }
        }
        await homeRepo.addTrainerSlots(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {"times": addPackageTimeTable},
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: model.message);
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  checkTiming(String start, String end) {
    // Server-anchored — drifted device clocks would otherwise lock
    // the trainer out of joining or open the door too early.
    Timestamp timestamp = Timestamp.fromDate(AppClock.now());
    int startTime = covertToTimeStamp(start);
    int endTime = covertToTimeStamp(end);

    if (timestamp.millisecondsSinceEpoch > startTime &&
        timestamp.millisecondsSinceEpoch < endTime) {
      return true;
    }
    return false;
  }

  getAllTimesSlotsTrainerFunc() {
    getAllTimesSlotsLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        return;
      }
      homeRepo
          .getAllTimesWithSlotsTrainer(
        accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      )
          .then((response) async {
        // Get.back();
        if (response.body["status"] == "0") {
          CustomToast.failToast(msg: response.body["message"]);
        } else if (response.body["status"] != "0") {
          // ApiResponse model = ApiResponse.fromJson(
          //     response.body,(p0){});

          if (response.body["status"] == "1") {
            addPackageTimeTable = List<addPackage.Time>.from(response
                .body["data"]["times"]
                .map((x) => addPackage.Time.fromJson(x)));
            for (var time in addPackageTimeTable) {
              if (time.slots.isEmpty) {
                time.slots.add(addPackage.Slot(
                    start: 'Start Time',
                    end: 'End Time',
                    id: null,
                    dayId: time.id,
                    trainerId: null));
              }
            }
            // for (var time in addPackageTimeTable) {
            //   time.slots.forEach((slot) {
            //     print("slot ${slot.toJson()}");
            //   });
            // }

            getAllTimesSlotsLoad.value = true;
            update();
          }
        }
      }).catchError((error, stackTrace) {
        // Surfacing async failures (network, parse, etc) instead of dying
        // silently inside the .then chain — which previously left the
        // screen on a perpetual spinner.
        print('getAllTimesSlotsTrainerFunc failed: $error\n$stackTrace');
        CustomToast.failToast(msg: "Couldn't load slots. Please try again.");
        update();
      });
    }).catchError((error, stackTrace) {
      print('getAllTimesSlotsTrainerFunc connection check failed: $error');
      CustomToast.failToast(msg: "Couldn't load slots. Please try again.");
      update();
    });
  }

  getFreeTrialUserDetails(String slotId) {
    getFreeTrialUserDetailsLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getAllFreeTrialUsers(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          id: sharedPreferences.getString(Constants.userId) ?? "",
          slotId: slotId,
        )
            .then((response) async {
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetFreeTrialUserDetails> model = ApiResponse.fromJson(
                response.body, GetFreeTrialUserDetails.fromJson);

            if (response.body["status"] == "1") {
              print(
                  'WorkOutController.getFreeTrialUserDetails ${model.data?.user}');
              freeTrialUser = model.data?.user ?? [];

              getFreeTrialUserDetailsLoad.value = true;
            }
          }
        });
      }
    });
  }

  updateClassDetails(int id, TextEditingController type,
      TextEditingController level, TextEditingController description) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()),
            barrierDismissible: false);

        await homeRepo.addClassDetails(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {
            "type": type.text,
            "level": level.text,
            "description": description.text,
            "slotId": id
          },
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: model.message);
                type.clear();
                level.clear();
                description.clear();
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  // Returns a Future so callers can await completion and prevent double-submits.
  Future<void> updateFreeTrialData(List<Map<String, dynamic>> answers) async {
    final connected = await connectionService.checkConnection();
    if (!connected) {
      CustomToast.noInternetToast();
      return;
    }

    Get.dialog(const Center(child: FhLoader()),
        barrierDismissible: false);

    final response = await homeRepo.addFreeTrialUserData(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      map: {
        "mainGoal": answers[0]["other"]
            ? answers[0]["otherText"]
            : answers[0]["answersList"].join(","),
        "specificIssues": answers[1]["other"]
            ? answers[1]["otherText"]
            : answers[1]["answersList"].join(","),
        "prefrences": answers[2]["other"]
            ? answers[2]["otherText"]
            : answers[2]["answersList"].join(","),
        "freeTrialUser": sharedPreferences.getString(Constants.userId) ?? "",
        "slots": freeTrialSlots
      },
    );

    Get.back(); // close loading dialog

    if (response.statusCode == 200) {
      if (response.body["status"] == "0") {
        CustomToast.failToast(msg: response.body["message"]);
      } else if (response.body["status"] == "1") {
        final model = ApiResponse.fromJson(response.body, (p0) {});
        if (model.status == "1") {
          AnalyticsHelper.trackFreeTrialEvent('completed', step: 'slots');
          CustomToast.successToast(msg: model.message);
          Get.offAll(() => BottomBarScreen());
        }
      }
    } else {
      CustomToast.failToast(msg: response.body["message"]);
    }
  }
}
