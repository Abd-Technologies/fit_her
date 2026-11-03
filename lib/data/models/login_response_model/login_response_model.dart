// To parse this JSON data, do
//
//     final loginModel = loginModelFromJson(jsonString);

import 'dart:convert';

import 'package:fitness_zone_2/data/models/api_response/api_response_model.dart';

LoginModel loginModelFromJson(String str) => LoginModel.fromJson(json.decode(str));

String loginModelToJson(LoginModel data) => json.encode(data.toJson());

class LoginModel extends Serializable {
  int id;
  String firstName;
  String lastName;
  String phone;
  String email;
  int adminId;
  bool status;
  String accessToken;
  String userType;
  String? age;
  String? height;
  String? weight;
  String? bmiResult;
  String? mainGoal;
  String? healthConditions;
  // Finished the sign-up questions. Null = older server (see SignupProgress).
  bool? onboardingDone;
  // Option-C feature flags. Backend always returns these; fromJson defaults
  // to false when missing (older clients / offline JSON caches).
  bool useNewPaidHome;
  bool useNewUnpaidHome;
  // Phase A — Progress Screen rebuild. Defaults false; backend flips this
  // per-user to opt into the new hub. See bottom_bar_screen.dart for the
  // routing decision.
  bool useNewProgressHub;
  // Phase F.3 — IANA zone the dietitian set on the User row server-side
  // (camelCase column `User.timeZone`). Used by DietPlanUserController
  // for "today's meals" math and by TimezoneSyncService to detect
  // device drift. Defaults to Asia/Karachi for older login responses
  // that didn't include the field.
  String timeZone;

  LoginModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.accessToken,
    required this.userType,
    required this.adminId,
    required this.status,
    this.height,
    this.age,
    this.weight,
    this.bmiResult,
    this.mainGoal,
    this.healthConditions,
    this.onboardingDone,
    this.useNewPaidHome = false,
    this.useNewUnpaidHome = false,
    this.useNewProgressHub = false,
    this.timeZone = 'Asia/Karachi',
  });

  factory LoginModel.fromJson(Map<String, dynamic> json) => LoginModel(
        id: json["id"],
        firstName: json["firstName"],
        lastName: json["lastName"],
        phone: json["phone"] ?? "",
        email: json["email"],
        accessToken: json["accessToken"],
        status: json["status"],
        userType: json["userType"],
        adminId: json["adminId"],
        age: json["age"],
        weight: json["weight"],
        height: json["height"],
        bmiResult: json["bmiResult"],
        mainGoal: json["mainGoal"],
        healthConditions: json["healthConditions"],
        onboardingDone: json["onboardingDone"] is bool ? json["onboardingDone"] as bool : null,
        useNewPaidHome: json["useNewPaidHome"] ?? false,
        useNewUnpaidHome: json["useNewUnpaidHome"] ?? false,
        useNewProgressHub: json["useNewProgressHub"] ?? false,
        timeZone: (json["timeZone"] ?? 'Asia/Karachi').toString(),
      );

  @override
  Map<String, dynamic> toJson() => {
        "id": id,
        "firstName": firstName,
        "lastName": lastName,
        "phone": phone,
        "status": status,
        "email": email,
        "userType": userType,
        "adminId": adminId,
        "accessToken": accessToken,
        "mainGoal": mainGoal,
        "healthConditions": healthConditions,
        if (onboardingDone != null) "onboardingDone": onboardingDone,
        "useNewPaidHome": useNewPaidHome,
        "useNewUnpaidHome": useNewUnpaidHome,
        "useNewProgressHub": useNewProgressHub,
        "timeZone": timeZone,
      };

  String get fullName => "${firstName} ${lastName}";
}
