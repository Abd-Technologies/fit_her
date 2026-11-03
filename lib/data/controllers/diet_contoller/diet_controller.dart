import 'dart:convert';
import '../../../UI/pre_consultation/pre_consultation_form_screen.dart';
import '../consultation_controller/consultation_controller.dart';
import 'dart:io';
import 'package:fitness_zone_2/data/models/nutrition_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:fitness_zone_2/data/models/diet_appointments.dart';
import 'package:fitness_zone_2/data/models/dietitian_times.dart';
import 'package:fitness_zone_2/data/models/get_all_dietitian_trainers/get_all_diet_plans_of_user.dart';
import 'package:fitness_zone_2/data/models/food_suggestion_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../UI/diet_screen/calerie_info.dart';
import '../../../helper/analytics_helper.dart';
import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';
import '../../api_provider/api_provider.dart';
import '../../GetServices/CheckConnectionService.dart';
import '../../Repos/home_repo/home_repo.dart';
import '../../models/api_response/api_response_model.dart';
import '../../models/day_slots_of_diet.dart';
import '../../models/diet_schedule_status.dart';
import '../../models/get_all_dietitian_trainers/get_diet_plan_details.dart';
import '../../models/get_clients_diet.dart';
import 'package:fitness_zone_2/helper/meeting_link.dart';
import '../auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class DietController extends GetxController implements GetxService {
  SharedPreferences sharedPreferences;
  HomeRepo homeRepo;
  AuthController authController = Get.find();

  DietController({required this.sharedPreferences, required this.homeRepo});

  CheckConnectionService connectionService = CheckConnectionService();

  ///Rx Variables
  var dietOfUserLoad = false.obs;
  var clientDataLoad = false.obs;
  var appointmentLoad = false.obs;
  var dietPlanStatusLoad = false.obs;
  var consultationStatusLoad = false.obs;
  var timesLoad = false.obs;
  var slotsLoad = false.obs;
  var dietPlanDetailsLoad = false.obs;
  var bookAppointmentSlotId = 0.obs;
  var foodSuggestionLoad = false.obs;

  ///Calori xFile
  XFile? calorieFile;

  ///File Variable
  File? addDietPdfFil;
  List<Appointment> rescheduleAppointments = [];
  List<Appointment> consultationStatus = [];
  List<PdfDiet> pdfDietStatus = [];

  ///models
  GetDietAllPlans? getDietAllPlans;
  GetDietPlanDetails? getDietPlanDetails;
  DietClients? getDietClientsModel;
  DietAppointments? dietAppointmentsModel;
  DietitianTiming? dietitianTimingModel;
  DaySlotsOfDiet? daySlotsOfDietModel;
  FoodSuggestionResponse? foodSuggestionResponse;

  getDietAllPlansFunc() {
    dietOfUserLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getUserPlansDiet(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userId: sharedPreferences.getString(Constants.userId) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetDietAllPlans> model = ApiResponse.fromJson(response.body, GetDietAllPlans.fromJson);
            if (model.status == "1") {
              getDietAllPlans = model.data;

              dietOfUserLoad.value = true;
            }
          }
        });
      }
    });
  }

  /// Set when the clients list couldn't load, so screens can show the
  /// reason and a Retry button instead of spinning forever.
  final RxnString clientDataError = RxnString();

  clientsOfDietFunc() {
    clientDataLoad.value = false;
    clientDataError.value = null;
    // Every failure path ends the loading state.
    void fail(String msg) {
      clientDataError.value = msg;
      clientDataLoad.value = true;
    }

    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        fail('No internet connection.');
        return;
      }
      try {
        final response = await homeRepo.getClients(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userId: sharedPreferences.getString(Constants.userId) ?? "",
        );
        final body = response.body;
        if (body is! Map) {
          fail('Could not load your clients. Please try again.');
          return;
        }
        if (body["status"]?.toString() != "1") {
          fail(body["message"]?.toString() ??
              'Could not load your clients. Please try again.');
          return;
        }
        ApiResponse<DietClients> model = ApiResponse.fromJson(
            Map<String, dynamic>.from(body), DietClients.fromJson);
        getDietClientsModel = model.data;
        clientDataLoad.value = true;
      } catch (_) {
        fail('Could not load your clients. Please try again.');
      }
    });
  }

  /// Set when the consultations list couldn't load, so the screen can
  /// show the reason and a Retry button instead of spinning forever.
  final RxnString appointmentError = RxnString();

  /// Nov 2026: finished calls of the last 2 days (times + "Did she join?").
  List<Appointment> recentFinished = [];

  /// Nov 2026: "Yes, she joined" with about how long (minutes).
  Future<bool> confirmClientJoined(int id, int minutes) async {
    try {
      final r = await Get.find<ApiProvider>().postData(
        '/appointment/$id/client-joined',
        body: {'minutes': minutes},
        headers: {'accessToken': sharedPreferences.getString(Constants.accessToken) ?? ''},
      );
      final b = r.body;
      final ok = b is Map && '${b['status']}' == '1';
      if (ok) {
        final a = recentFinished.firstWhereOrNull((x) => x.id == id);
        a?.attendanceFlag = 'dietitian_confirmed';
        CustomToast.successToast(msg: 'Thanks, noted');
        appointmentLoad.value = false;
        appointmentLoad.value = true;
      } else {
        CustomToast.failToast(msg: (b is Map ? b['message']?.toString() : null) ?? 'Could not update');
      }
      return ok;
    } catch (_) {
      CustomToast.failToast(msg: 'Could not update. Please try again.');
      return false;
    }
  }

  getAppointmentsOfDiets() {
    appointmentLoad.value = false;
    appointmentError.value = null;
    // Every failure path ends the loading state; before, a failed or
    // unexpected response left the spinner running for good.
    void fail(String msg) {
      appointmentError.value = msg;
      appointmentLoad.value = true;
    }

    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        fail('No internet connection.');
        return;
      }
      try {
        final response = await homeRepo.getAppointments(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userId: sharedPreferences.getString(Constants.userId) ?? "",
          recentDays: 2,
        );
        final body = response.body;
        if (body is! Map) {
          fail('Could not load consultations. Please try again.');
          return;
        }
        if (body["status"]?.toString() != "1") {
          fail(body["message"]?.toString() ??
              'Could not load consultations. Please try again.');
          return;
        }
        ApiResponse<DietAppointments> model =
            ApiResponse.fromJson(
                Map<String, dynamic>.from(body), DietAppointments.fromJson);
        // Nov 2026: the list now also has the last 2 days' finished calls.
        // Keep `appointments` as before (still-active ones only, which the
        // home screen and sessions list use) and the finished ones apart.
        final all = model.data?.appointments ?? <Appointment>[];
        const active = {'pending', 'confirmed', 'In Progress'};
        recentFinished = all.where((a) => a.status == 'completed').toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        model.data?.appointments = all.where((a) => active.contains(a.status)).toList();
        dietAppointmentsModel = model.data;
        appointmentLoad.value = true;
      } catch (_) {
        fail('Could not load consultations. Please try again.');
      }
    });
  }

  // Flips a confirmed consultation to "In Progress" so the client's
  // Join Meeting button turns green. Mirrors updateAppointmentStatus's
  // shape (optimistic local update on the cached model + a toast) but
  // hits the dedicated /start endpoint rather than the generic
  // status-patch one, since /start also enforces "must be confirmed
  // first" and sends the client a push notification server-side.
  Future<void> startAppointmentSession(int id) async {
    final connected = await connectionService.checkConnection();
    if (!connected) {
      CustomToast.noInternetToast();
      return;
    }
    Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
    try {
      final response = await homeRepo.startAppointmentSession(
        accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        id: id.toString(),
      );
      Get.back();
      final body = response.body;
      final ok = body is Map && body['status'] == '1';
      if (ok) {
        CustomToast.successToast(msg: body['message']?.toString() ?? 'Session started');
        final appt = dietAppointmentsModel?.appointments.firstWhereOrNull((v) => v.id == id);
        if (appt != null) {
          appt.status = 'In Progress';
          update();
          // The consultations list is an Obx on appointmentLoad, so
          // flip it to redraw the card as "Live now" immediately.
          appointmentLoad.value = false;
          appointmentLoad.value = true;
          final link = appt.resolvedMeetLink;
          if (link == null || link.isEmpty) {
            CustomToast.failToast(
                msg: "Session started, but this slot has no Meet link. "
                    "Add one in your availability so the client can join.");
          } else {
            await _openMeetLink(link);
          }
        }
      } else {
        CustomToast.failToast(
            msg: (body is Map ? body['message']?.toString() : null) ?? 'Could not start the session');
      }
    } catch (_) {
      Get.back();
      CustomToast.failToast(msg: 'Could not start the session. Please try again.');
    }
  }

  // Dietitian: "Client didn't join". Server cancels the booking without
  // using up her consultation and pushes her a "book a new time" note.
  Future<void> reportClientNoShow(int id) async {
    final connected = await connectionService.checkConnection();
    if (!connected) {
      CustomToast.noInternetToast();
      return;
    }
    Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
    try {
      final response = await homeRepo.reportClientNoShow(
        accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        id: id.toString(),
      );
      Get.back();
      final body = response.body;
      final ok = body is Map && body['status'] == '1';
      final msg = body is Map ? body['message']?.toString() : null;
      if (ok) {
        CustomToast.successToast(msg: msg ?? "Marked as missed. She's been asked to rebook.");
        final appt = dietAppointmentsModel?.appointments.firstWhereOrNull((v) => v.id == id);
        if (appt != null) {
          appt.status = 'canceled';
          update();
        }
      } else {
        CustomToast.failToast(msg: msg ?? 'Could not update. Please try again.');
      }
    } catch (_) {
      Get.back();
      CustomToast.failToast(msg: 'Could not update. Please try again.');
    }
  }

  // Opens the Google Meet link right after a session goes live, so
  // starting the session and joining it is one tap instead of two —
  // she used to have to start it here, then separately hunt down the
  // link she pasted into the weekly slot. Silent no-op if no link has
  // ever been set for this slot: the session still starts (the client
  // side already tells her to add one), it just can't auto-open yet.
  Future<void> _openMeetLink(String? link) async {
    if (link == null || link.trim().isEmpty) return;
    if (!await openMeetingLink(link)) {
      CustomToast.failToast(
          msg: "Couldn't open the meeting link. Check the Meet link saved on this slot.");
    }
  }

  // Public wrapper so screens can offer a standalone "Join call" action
  // (re-opening a link for a session already under way) without going
  // through startAppointmentSession, which also flips the status.
  Future<void> openMeetLink(String? link) async {
    if (link == null || link.isEmpty) {
      CustomToast.failToast(msg: "No meeting link has been set for this slot yet.");
      return;
    }
    await _openMeetLink(link);
  }

  // Inline status change from TodaySessionsScreen's consultation list —
  // Completed / Cancel next to a booking, mirroring the same three
  // actions (Join call / Completed / Cancel) ClientDetailsScreen has
  // always had, so she doesn't have to leave the list and open a
  // client's profile just to close out or cancel a session. Deliberately
  // does NOT reuse updateAppointmentStatus(isFromAppointment: true) —
  // that method calls Get.back() on success (it was written for the
  // profile screen, where popping after the action makes sense); here
  // we want to stay on the list and just see the row update in place.
  Future<bool> setAppointmentStatusInline(int id, String status) async {
    final connected = await connectionService.checkConnection();
    if (!connected) {
      CustomToast.noInternetToast();
      return false;
    }
    Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
    try {
      final response = await homeRepo.updateAppointment(
        accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        map: {"status": status},
        id: id.toString(),
      );
      Get.back();
      final body = response.body;
      final ok = body is Map && body['status'] == '1';
      if (ok) {
        CustomToast.successToast(
            msg: body['message']?.toString() ??
                (status == 'completed' ? 'Marked as completed' : 'Consultation canceled'));
        if (status.toLowerCase() == 'completed') {
          AnalyticsHelper.trackConsultationDone(id, status: status);
        }
        final appt = dietAppointmentsModel?.appointments.firstWhereOrNull((v) => v.id == id);
        if (appt != null) {
          appt.status = status;
          // dietAppointmentsModel itself isn't Rx — mutating a field on
          // one of its items doesn't notify Obx on its own. Toggling
          // appointmentLoad false→true is the same trick
          // updateAppointmentStatus already relies on elsewhere to force
          // the list to redraw with the new status.
          appointmentLoad.value = false;
          appointmentLoad.value = true;
        }
        return true;
      } else {
        CustomToast.failToast(
            msg: (body is Map ? body['message']?.toString() : null) ?? 'Could not update the consultation');
      }
    } catch (_) {
      Get.back();
      CustomToast.failToast(msg: 'Could not update the consultation. Please try again.');
    }
    return false;
  }

  getRescheduleAppointments({bool reschedule = false}) {
    appointmentLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getRescheduleAppointments(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          reschedule: reschedule,
          dietitianId: sharedPreferences.getString(Constants.userId) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<DietAppointments> model = ApiResponse.fromJson(response.body, DietAppointments.fromJson);
            if (model.status == "1") {
              rescheduleAppointments = model.data?.appointments ?? [];

              appointmentLoad.value = true;
            }
          }
        });
      }
    });
  }

  getConsultationStatus() {
    consultationStatusLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getConsultationStatus(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<DietAppointments> model = ApiResponse.fromJson(response.body, DietAppointments.fromJson);
            if (model.status == "1") {
              consultationStatus = model.data?.appointments ?? [];

              consultationStatusLoad.value = true;
            }
          }
        });
      }
    });
  }

  getDietPlanScheduleStatus() {
    dietPlanStatusLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getReschedulePdfStatus(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<DietPlanScheduleStatus> model = ApiResponse.fromJson(response.body, DietPlanScheduleStatus.fromJson);
            if (model.status == "1") {
              pdfDietStatus = model.data?.pdfDiets ?? [];
              dietPlanStatusLoad.value = true;
            }
          }
        });
      }
    });
  }

  getDietTimes() {
    timesLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getTimesOfDiet(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userId: sharedPreferences.getString(Constants.userId) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<DietitianTiming> model = ApiResponse.fromJson(response.body, DietitianTiming.fromJson);
            if (model.status == "1") {
              dietitianTimingModel = model.data;

              timesLoad.value = true;
            }
          }
        });
      }
    });
  }

  getSlotsOfDay(int dayId) {
    slotsLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo.getDaySlots(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userId: sharedPreferences.getString(Constants.userId) ?? "",
          map: {"dietitionId": sharedPreferences.getString(Constants.userId) ?? "", "dayId": dayId},
        ).then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<DaySlotsOfDiet> model = ApiResponse.fromJson(response.body, DaySlotsOfDiet.fromJson);
            if (model.status == "1") {
              daySlotsOfDietModel = model.data;

              slotsLoad.value = true;
            }
          }
        });
      }
    });
  }

  getDietPlanDetailsFunc(String id) {
    dietPlanDetailsLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getUserPlanDetailsDiet(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          planId: id,
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetDietPlanDetails> model = ApiResponse.fromJson(response.body, GetDietPlanDetails.fromJson);
            if (model.status == "1") {
              getDietPlanDetails = model.data;
              // await getUserPdfFile(id.toString()); // legacy PDF diet plan — disabled (backend route removed)
              //
              dietPlanDetailsLoad.value = true;
            }
          }
        });
      }
    });
  }

  getUserPdfFile(String id) {
    // dietPlanDetailsLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getDietPdfRepo(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          planId: id,
          userId: sharedPreferences.getString(Constants.userId) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
            if (model.status == "1") {
              getDietPlanDetails!.pdfFile.value = "${Constants.baseUrl}/${response.body["data"]["details"]["pdfFile"] ?? ""}";

              dietPlanDetailsLoad.value = true;
            }
          }
        });
      }
    });
  }

  addDietPdFFile(String planId, String userId) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        await homeRepo.addPdfFileRepo(accessToken: sharedPreferences.getString(Constants.accessToken) ?? "", map: {
          "image": addDietPdfFil!.path,
          "userId": userId,
          "userPlanId": planId,
        }).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            ApiResponse model = ApiResponse.fromJson(jsonDecode(response.bodyString!), (p0) {});
            if (model.status == "0") {
              CustomToast.failToast(msg: model.message);
            }
            if (model.status == "1") {
              CustomToast.successToast(msg: model.message);
              addDietPdfFil = null;
              Get.back();
            }
          } else {
            CustomToast.failToast(msg: "Something wrong happened");
          }
        });
      }
    });
  }

  bookAppointment(int planId, int dietId, DateTime date) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        await homeRepo.bookAppointment(accessToken: sharedPreferences.getString(Constants.accessToken) ?? "", map: {
          "date": date.toIso8601String(),
          "userId": sharedPreferences.getString(Constants.userId) ?? "",
          "dietitionId": dietId,
          "timeSlotId": bookAppointmentSlotId.value,
          "userPlanId": planId
        }).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
            // Health form first (server FORM_REQUIRED): open the form, and
            // book right after she finishes it.
            final bodyMap = response.body is Map ? response.body as Map : const {};
            final dataMap = bodyMap['data'] is Map ? bodyMap['data'] as Map : const {};
            final code = dataMap['code'];
            if (model.status == "0" && code == 'FORM_REQUIRED') {
              await PreConsultationFormScreen.open(
                  planType: '${dataMap['planType'] ?? 'diet'}', canLater: true);
              final req = Get.isRegistered<ConsultationController>()
                  ? await Get.find<ConsultationController>().getPreConsultRequirements('diet')
                  : null;
              if (req != null && req['shouldShow'] != true) {
                bookAppointment(planId, dietId, date);
              } else {
                CustomToast.failToast(msg: model.message);
              }
              return;
            }
            if (model.status == "0") {
              CustomToast.failToast(msg: model.message);
            }
            if (model.status == "1") {
              CustomToast.successToast(msg: model.message);
              getDietPlanDetails?.isBooked = true;
              getDietPlanDetails?.status = response.body["data"]["appointment"]['status'] ?? "pending";
              getDietPlanDetails?.id = response.body["data"]["appointment"]["id"] ?? 0;
              // Track consultation booked in Mixpanel
              AnalyticsHelper.trackConsultationBooked(
                planId,
                dietId,
                date.toIso8601String(),
                timeSlotId: bookAppointmentSlotId.value,
              );
              getDietPlanDetailsFunc(planId.toString());
              //  Get.back();
            }
          } else {
            CustomToast.failToast(msg: "Something wrong happened");
          }
        });
      }
    });
  }

  addCaloriesImage(String foodName) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);

        await homeRepo
            .addCalorieImage(
                accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
                map: {
                  "foodName": foodName,
                },
                id: sharedPreferences.getString(Constants.userId) ?? "")
            .then((response) async {
          Get.back();
          if (response.statusCode == 200) {
            ApiResponse<NutritionModel> model = ApiResponse.fromJson(response.body, NutritionModel.fromJson);
            if (model.status == "0") {
              CustomToast.failToast(msg: model.message);
            }
            if (model.status == "1") {
              CustomToast.successToast(msg: model.message);
              Get.to(() => NutritionScreen(
                    nutritionModel: model.data!,
                  ));
            }
          } else {
            CustomToast.failToast(msg: "Something wrong happened");
          }
        });
      }
    });
  }

  removeImage() {
    calorieFile = null;
    update(["colorieUpdate"]);
  }

  getFoodSuggestions(String query) {
    foodSuggestionLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        try {
          final response = await http.get(
            Uri.parse(
              'https://api.spoonacular.com/food/ingredients/autocomplete?query=${Uri.encodeComponent(query)}&number=10&apiKey=a2291fd5db7543429f91495c0654f28f',
            ),
            headers: {
              'Content-Type': 'application/json',
            },
          );
          print('DietController.getFoodSuggestions ${response.body}');

          if (response.statusCode == 200) {
            final jsonData = jsonDecode(response.body);

            // jsonData will be a List, so you may need a new model
            // Example format: [{ "name": "apple", "id": 9003, "image": "apple.png" }, ...]

            foodSuggestionResponse = FoodSuggestionResponse.fromJson(jsonData);

            foodSuggestionLoad.value = true;
          } else {
            CustomToast.failToast(msg: "Failed to get food suggestions");
            foodSuggestionLoad.value = false;
          }
        } catch (e) {
          CustomToast.failToast(msg: "Error getting food suggestions");
          foodSuggestionLoad.value = false;
        }
      }
    });
  }

  updateAppointmentStatus(int id, String status,
      {bool isFromAppointment = false, bool reschedule = false, bool isFromDietDetails = false, String? planId}) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        print('DietController.updateAppointmentStatus ${status}');
        await homeRepo
            .updateAppointment(accessToken: sharedPreferences.getString(Constants.accessToken) ?? "", map: {"status": status}, id: id.toString())
            .then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
            if (model.status == "0") {
              CustomToast.failToast(msg: model.message);
            }
            if (model.status == "1") {
              CustomToast.successToast(msg: model.message);
              // Track consultation done in Mixpanel when status is completed/done
              if (status.toLowerCase() == 'completed' || status.toLowerCase() == 'done') {
                AnalyticsHelper.trackConsultationDone(id, status: status);
              }
              if (isFromAppointment) {
                appointmentLoad.value = false;
                var value = dietAppointmentsModel!.appointments.firstWhereOrNull((v) => v.id == id);
                if (value != null) {
                  value.status = status;
                  Get.back();
                }
              }
              if (isFromDietDetails) {
                getDietPlanDetailsFunc(planId.toString());
              }
              appointmentLoad.value = true;
            }
          } else {
            CustomToast.failToast(msg: "Something wrong happened");
          }
        });
      }
    });
  }

  deletedAppointment(int id, int planId) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        await homeRepo
            .deleteAppointment(accessToken: sharedPreferences.getString(Constants.accessToken) ?? "", id: id.toString())
            .then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
            if (model.status == "0") {
              CustomToast.failToast(msg: model.message);
            }
            if (model.status == "1") {
              CustomToast.successToast(msg: model.message);
              getDietPlanDetailsFunc(planId.toString());
            }
          } else {
            CustomToast.failToast(msg: "Something wrong happened");
          }
        });
      }
    });
  }

  updateReschedule() {
    getDietPlanDetails?.isBooked = false;
    update(["dietBottomScreen"]);
  }

  addDaySlots(String dayId) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        var list = [];
        if (daySlotsOfDietModel != null) {
          // Send the "h:mm AM/PM" text as-is — do NOT run it through
          // covertToTimeStamp. That helper builds a Firestore epoch-ms
          // timestamp, which is not what this endpoint wants: the
          // backend's addOrUpdateDaySlot validates start/end against
          // `^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$` (e.g. "9:00 AM") and
          // rejects anything else with "Slot[i] has invalid time
          // format". Converting to an epoch-ms string always failed
          // that check — this previously slipped through unnoticed
          // because the same conversion was ALSO being written back
          // onto the shared Slot objects (now fixed separately), which
          // masked the mismatch behind a client-side crash instead of
          // surfacing the backend's rejection.
          for (var value in daySlotsOfDietModel!.slots) {
            list.add({
              "start": value.start,
              "end": value.end,
              "id": value.id,
              // Included so the "Join Meeting" flow on the client side
              // has something to show once she fills this in on the
              // Slots screen — see day_slots_screen.dart.
              "dietitionLink": value.dietitionLink,
            });
          }
        } else {
          return;
        }

        await homeRepo.addDaySlots(
            accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
            map: {"dietitionId": sharedPreferences.getString(Constants.userId) ?? "", "dayId": dayId, "slotsList": list}).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
            if (model.status == "0") {
              CustomToast.failToast(msg: model.message);
            }
            if (model.status == "1") {
              CustomToast.successToast(msg: model.message);
              Get.back();
            }
          } else {
            CustomToast.failToast(msg: "Something wrong happened");
          }
        });
      }
    });
  }

  Future<String> downloadFile(var filePath, var documentUrl) async {
    try {
      final filename = filePath;
      var downloadDir = (Platform.isIOS) ? (await getApplicationDocumentsDirectory()).path : (await getApplicationSupportDirectory()).path;

      String dir = downloadDir;

      // Construct the full file path
      File file = File('$dir/$filename');
      print('Downloading file to: $dir/$filename');

      // Create the directory if it doesn't exist
      if (!await Directory(dir).exists()) {
        await Directory(dir).create(recursive: true);
        print('Created directory: $dir');
      }

      // Make the HTTP request
      String url = documentUrl;
      print('Fetching from URL: $url');
      var request = await HttpClient().getUrl(Uri.parse(url));
      var response = await request.close();

      // Check if the response is successful
      if (response.statusCode != 200) {
        print('Failed to download file. Status code: ${response.statusCode}');
        return "Error: Failed to download file";
      }

      // Write the file
      var bytes = await consolidateHttpClientResponseBytes(response);
      await file.writeAsBytes(bytes);
      print('File downloaded successfully: ${file.path}');
      return file.path;
    } catch (err) {
      print('Error during file download: $err');
      return "Error: $err";
    }
  }

  @override
  void onInit() {
    //  getDietAllPlansFunc();
    if (authController.loginAsA.value == Constants.dietitian) {
      getAppointmentsOfDiets();
    }
    super.onInit();
  }
}
