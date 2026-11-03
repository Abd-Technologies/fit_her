import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/models/country_model.dart';
import 'package:fitness_zone_2/data/models/duration_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';
import '../../GetServices/CheckConnectionService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

import '../../Repos/home_repo/home_repo.dart';
import '../../models/add_package/add_package_model.dart';
import '../../models/api_response/api_response_model.dart';
import '../../models/get_all_cat_plan/get_all_categories.dart';
import '../../models/get_all_cat_plan/get_all_sub_cat.dart';
import '../../models/get_user_plan/get_user_plan.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class PlanController extends GetxController implements GetxService {
  SharedPreferences sharedPreferences;
  HomeRepo homeRepo;

  PlanController({required this.sharedPreferences, required this.homeRepo});
  CheckConnectionService connectionService = CheckConnectionService();

  ///Variables
  var selectedCountry = "Country".obs;
  var selectedCountryCode = "Country".obs;
  var getAllCountriesLoad = false.obs;
  var getAllDurationLoad = false.obs;
  var getCatLoaded = false.obs;
  var getSubCatLoaded = false.obs;

  ///Selection Variable
  var selectedId = 0.obs;
  var selectedSubCatId = 0.obs;
  List<AddCountriesListToPackage> addCountriesList = [
    AddCountriesListToPackage(id: 0, durationList: [DurationPackageSent(id: 0)])
  ];

  ///Model
  CountryList? countryList;
  DurationList? durationList;
  AllCategoriesOfPlan? allCategoriesOfPlan;
  GetSubCategories? allSubCategories;

  ///for adding Package

  TextEditingController packageName = TextEditingController();
  TextEditingController shortDis = TextEditingController();
  TextEditingController longDis = TextEditingController();
  TextEditingController price = TextEditingController();

  ///
  TextEditingController packageDuration = TextEditingController();

  addCountryFunc() {
    if (selectedCountry.value == "Country") {
      CustomToast.failToast(msg: "Please select country");
      return;
    }

    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()),
            barrierDismissible: false);
        await homeRepo.addCountry(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {
            "code": selectedCountryCode.value,
            "name": selectedCountry.value
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
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  addTimeDuration() {
    if (packageDuration.text.isEmpty) {
      CustomToast.failToast(msg: "Please select duration");
      return;
    }

    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()),
            barrierDismissible: false);
        await homeRepo.addTimeDuration(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: {"duration": packageDuration.text, "countryId": null},
        ).then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                packageDuration.clear();
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

  getAllCountriesFunc({bool isFromUpdate = false, Plan? plan}) {
    getAllCountriesLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getCountries(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<CountryList> model =
                ApiResponse.fromJson(response.body, CountryList.fromJson);

            if (model.status == "1") {
              countryList = model.data;
              if (countryList!.countries.isNotEmpty) {
                addCountriesList = [];

                if (isFromUpdate && plan?.countries != null) {
                  for (int i = 0; i < plan!.countries!.length; i++) {
                    addCountriesList.add(AddCountriesListToPackage(
                        id: plan.countries![i].id ?? 0, durationList: []));
                    addCountriesList[i].name = plan.countries![i].name!;
                    if (plan.countries![i].duration != null) {
                      for (int j = 0;
                          j < plan.countries![i].duration!.length;
                          j++) {
                        var ddd = plan.countries![i].duration![j];

                        addCountriesList[i]
                            .durationList
                            .add(DurationPackageSent(id: ddd.id ?? 0));
                        addCountriesList[i].durationList[j].amount =
                            TextEditingController(text: ddd.priceAmount ?? "0");
                      }
                    }
                  }
                } else {
                  addCountriesList.add(AddCountriesListToPackage(
                      id: countryList!.countries.first.id, durationList: []));
                  addCountriesList[0].name = countryList!.countries[0].name;
                }
              }
              getAllDurationFunc();
              getAllCountriesLoad.value = true;
            }
          }
        });
      }
    });
  }

  getAllDurationFunc({bool isFromUpdate=false}) {
    getAllDurationLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getTmeDurations(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<DurationList> model =
                ApiResponse.fromJson(response.body, DurationList.fromJson);

            if (model.status == "1") {
              durationList = model.data;
              if (durationList!.durations.isNotEmpty) {
                if(!isFromUpdate){
                  if(addCountriesList.first.durationList.isEmpty){
                    addCountriesList.first.durationList.add(DurationPackageSent(id: durationList!.durations.first.id));
                  }
                  addCountriesList[0].durationList[0].duration =
                      durationList!.durations[0].duration;
                }

              }
              getAllDurationLoad.value = true;
            }
          }
        });
      }
    });
  }

  getCategories({int? catId, int? subCatId}) {
    getCatLoaded.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        // Get.dialog(const Center(child: CircularProgressIndicator()),
        //     barrierDismissible: false);

        homeRepo
            .getAllCategories(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<AllCategoriesOfPlan> model = ApiResponse.fromJson(
                response.body, AllCategoriesOfPlan.fromJson);
            if (model.status == "1") {
              allCategoriesOfPlan = model.data!;
              if (allCategoriesOfPlan!.categories.isNotEmpty) {
                if (catId != null) {
                  selectedId.value = catId;
                } else {
                  selectedId.value = allCategoriesOfPlan!.categories[0].id;
                }
                getSubCategories(selectedId.value.toString(), subId: subCatId);
              }

              getCatLoaded.value = true;
            }
          }
        });
      }
    });
  }

  getSubCategories(String catId, {int? subId}) {
    getSubCatLoaded.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        homeRepo
            .getSubCategories(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          catId: catId,
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetSubCategories> model =
                ApiResponse.fromJson(response.body, GetSubCategories.fromJson);
            if (model.status == "1") {
              allSubCategories = model.data!;
              if (allSubCategories!.data.isNotEmpty) {
                if (subId != null) {
                  selectedSubCatId.value = subId;
                } else {
                  selectedSubCatId.value = allSubCategories!.data[0].id;
                }
              }

              getSubCatLoaded.value = true;
            }
          }
        });
      }
    });
  }

  addPlan({String? dietitianId}) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()),
            barrierDismissible: false);
        await homeRepo
            .addPlanRepo(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: AddPackageModel(
                  title: packageName.text,
                  shortDescription: shortDis.text,
                  longDescription: longDis.text,
                  categoryId: selectedId.toString(),
                  countriesList: addCountriesList,
                  subCategoryId: selectedSubCatId.value.toString(),
                  dietitianId: dietitianId)
              .toJson(),
        )
            .then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.failToast(msg: response.body["message"]);
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  updatePlan(String id) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()),
            barrierDismissible: false);
        await homeRepo
            .updatePlanRepo(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: AddPackageModel(
                  id: id,
                  title: packageName.text,
                  shortDescription: shortDis.text,
                  longDescription: longDis.text,
                  categoryId: selectedId.toString(),
                  countriesList: addCountriesList,
                  subCategoryId: selectedSubCatId.value.toString())
              .toJson(),
        )
            .then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: response.body["message"]);
                Get.find<HomeController>().getPlans();
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  addDietitionPlan() {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()),
            barrierDismissible: false);
        await homeRepo
            .addDietitionPlan(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          map: AddPackageModel(
                  title: packageName.text,
                  shortDescription: shortDis.text,
                  longDescription: longDis.text,
                  categoryId: selectedId.toString(),
                  countriesList: addCountriesList,
                  subCategoryId: selectedSubCatId.value.toString())
              .toJson(),
        )
            .then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
              if (model.status == "1") {
                CustomToast.successToast(msg: model.message);
                Get.back();
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  Country? findCountryWhichIsNotAdded() {
    Country? country;
    if (countryList != null &&
        countryList!.countries.isNotEmpty &&
        durationList != null &&
        durationList!.durations.isNotEmpty) {
      for (var add in addCountriesList) {
        countryList?.countries.forEach((ccc) {
          if (ccc.id != add.id) {
            country = ccc;
          }
        });
      }
    }
    return country;
  }

  void addCountry(Country country) {
    if (countryList != null &&
        countryList!.countries.isNotEmpty &&
        durationList != null &&
        durationList!.durations.isNotEmpty) {
      // Check if the country is already in addCountriesList
      // bool isCountryNotAdded =
      //     !addCountriesList.any((existing) => existing.id == country.id);

      // if (isCountryNotAdded) {
      addCountriesList.add(AddCountriesListToPackage(
        id: country.id,
        durationList: [
          DurationPackageSent(id: durationList!.durations.first.id)
        ],
      ));
      // }
      // else{
      //   print("valueee99999");
      // }
    } else {
      print("no duration");
    }
    update();
  }
}
