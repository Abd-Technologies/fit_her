import 'package:flutter/material.dart';

import '../../../helper/analytics_helper.dart';
import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';
import '../../GetServices/CheckConnectionService.dart';
import '../../Repos/home_repo/home_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

import '../../models/api_response/api_response_model.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class RatingController extends GetxController implements GetxService {
  SharedPreferences sharedPreferences;
  HomeRepo homeRepo;

  RatingController({required this.sharedPreferences, required this.homeRepo});

  CheckConnectionService connectionService = CheckConnectionService();
  var classReview='Fun & Engaging'.obs;


  addClassReview(String planId, String comment, double value,String trainerOrDiet) {
    final rating = value;
    connectionService.checkConnection().then((hasConnection) async {
      if (!hasConnection) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()),
            barrierDismissible: false);

        await homeRepo.addReview(
            accessToken:
                sharedPreferences.getString(Constants.accessToken) ?? "",
            map: {
              "comment": comment,
              "value": rating,
              "classReview": classReview.value,
              "trainerOrDiet": trainerOrDiet,
              "PlanId": planId,
              "userId": sharedPreferences.getString(Constants.userId) ?? ""
            }).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
            if (model.status == "0") {
              CustomToast.failToast(msg: model.message);
            }
            if (model.status == "1") {
              CustomToast.successToast(msg: model.message);
              sharedPreferences.setString(Constants.reviewDate, DateTime.now().toString());
              // Track review in Mixpanel
              AnalyticsHelper.trackReview(planId, rating, trainerOrDiet,
                  classReview: classReview.value,
                  hasComment: comment.trim().isNotEmpty);
              Get.back();
            }
          } else {
            CustomToast.failToast(msg: "Something wrong happened");
          }
        });
      }
    });
  }
}
