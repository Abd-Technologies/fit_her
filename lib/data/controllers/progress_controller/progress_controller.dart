import 'dart:convert';

import 'package:fitness_zone_2/data/models/get_all_dietitian_trainers/get_all_diet_plans_of_user.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';
import '../../GetServices/CheckConnectionService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

import '../../Repos/home_repo/home_repo.dart';
import '../../models/api_response/api_response_model.dart';
import '../../models/get_all_dietitian_trainers/get_diet_plan_details.dart';
import '../../models/get_all_users/get_user_progress_model.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class ProgressController extends GetxController implements GetxService {
  SharedPreferences sharedPreferences;
  HomeRepo homeRepo;

  ProgressController({required this.sharedPreferences, required this.homeRepo});

  CheckConnectionService connectionService = CheckConnectionService();

  ///Rx Variables
  var imagesProgressOfUser = false.obs;
  var dietPlanDetailsLoad = false.obs;

  File? beforeImage;
  File? afterImage;

  List<dynamic> progressImagesList = [];

  ///models
  GetUserProgressImagesModel? getUserProgressImagesModel;
  GetDietPlanDetails? getDietPlanDetails;

  getUserProgressImages() {
    imagesProgressOfUser.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getUserImagesProgress(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userId: sharedPreferences.getString(Constants.userId) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetUserProgressImagesModel> model =
                ApiResponse.fromJson(
                    response.body, GetUserProgressImagesModel.fromJson);
            if (model.status == "1") {
              progressImagesList=[];
              getUserProgressImagesModel = model.data;

              getUserProgressImagesModel?.progress.forEach((item) {
                progressImagesList.add(item.before);
                progressImagesList.add(item.after);
              });

              progressImagesList.add(null);
              progressImagesList.add(null);
              imagesProgressOfUser.value = true;
              update();
            }
          }
        });
      }
    });
  }

  addProgressImages() {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()),
            barrierDismissible: false);

        await homeRepo.addProgressImages(
            accessToken:
                sharedPreferences.getString(Constants.accessToken) ?? "",
            map: {
              "before": progressImagesList[progressImagesList.length - 2].path,
              "after": progressImagesList[progressImagesList.length - 1].path,
              "userId": sharedPreferences.getString(Constants.userId),
            }).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            ApiResponse model =
                ApiResponse.fromJson(jsonDecode(response.bodyString!), (p0) {});
            if (model.status == "0") {
              CustomToast.failToast(msg: model.message);
            }
            if (model.status == "1") {
              CustomToast.successToast(msg: model.message);
              getUserProgressImages();
            }
          } else {
            CustomToast.failToast(msg: "Something wrong happened");
          }
        });
      }
    });
  }

  @override
  void onInit() {
    getUserProgressImages();

    super.onInit();
  }
}
