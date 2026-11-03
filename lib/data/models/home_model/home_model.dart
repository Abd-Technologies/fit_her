// To parse this JSON data, do
//
//     final userHomeData = userHomeDataFromJson(jsonString);

import 'dart:convert';

import 'package:fitness_zone_2/data/models/api_response/api_response_model.dart';
import 'package:get/get.dart';

import '../get_clients_diet.dart';

UserHomeData userHomeDataFromJson(String str) =>
    UserHomeData.fromJson(json.decode(str));

String userHomeDataToJson(UserHomeData data) => json.encode(data.toJson());

class UserHomeData extends Serializable {
  UserData userData;
  RxInt freeze;
  List<UserAllPlan> userAllPlans;
  ClientUser? customSupporter;

  UserHomeData({
    required this.userData,
    required this.freeze,
    required this.userAllPlans,
    required this.customSupporter,
  });

  factory UserHomeData.fromJson(Map<String, dynamic> json) => UserHomeData(
        userData: UserData.fromJson(json["userData"]),
        customSupporter: _safeSupporter(json["customSupporterData"]),
        freeze: RxInt(json["freeze"] ?? 0),
        userAllPlans: json["plans"] == null || json["plans"] == [null]
            ? []
            : List<UserAllPlan>.from((json["plans"] as List)
                .where((x) => x is Map)
                .map((x) => UserAllPlan.fromJson(Map<String, dynamic>.from(x)))),
      );

  static ClientUser? _safeSupporter(dynamic v) {
    if (v is! Map) return null;
    try {
      return ClientUser.fromJson(Map<String, dynamic>.from(v));
    } catch (_) {
      return null; // a half-filled supporter must not hide her plan
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        "userData": userData.toJson(),
        "customSupporterData": customSupporter?.toJson(),
        "freeze": freeze,
        "UserAllPlans": List<dynamic>.from(userAllPlans.map((x) => x.toJson())),
      };
}

class UserAllPlan {
  int planId;
  int spendDays;
  int remainingDays;
  String title;
  String shortDescription;
  String longDescription;
  int categoryId;
  String price;
  String currency;
  DateTime? buyingDate;
  DateTime? expireDate;
  PriceData? priceData;

  UserAllPlan({
    required this.spendDays,
    required this.planId,
    required this.remainingDays,
    required this.title,
    required this.shortDescription,
    required this.longDescription,
    required this.categoryId,
    required this.buyingDate,
    required this.expireDate,
    required this.price,
    required this.currency,
    this.priceData,
  });

  // Every field is null-safe: one empty field on one plan (e.g. a plan
  // with no short description) used to break the whole home response,
  // so the app thought she had no plan at all.
  factory UserAllPlan.fromJson(Map<String, dynamic> json) => UserAllPlan(
        spendDays: _toInt(json["spendDays"]),
        price: (json["price"] ?? "").toString(),
        currency: (json["currency"] ?? "").toString(),
        planId: _toInt(json["planId"]),
        remainingDays: _toInt(json["remainingDays"]),
        title: (json["title"] ?? "").toString(),
        shortDescription: (json["shortDescription"] ?? "").toString(),
        longDescription: (json["longDescription"] ?? "").toString(),
        categoryId: _toInt(json["CategoryId"]),
        buyingDate: DateTime.tryParse((json["buyingDate"] ?? "").toString()),
        expireDate: DateTime.tryParse((json["expireDate"] ?? "").toString()),
        priceData: json["priceData"] is Map
            ? PriceData.fromJson(Map<String, dynamic>.from(json["priceData"]))
            : PriceData(id: 0, priceAmount: "N/A"),
      );

  static int _toInt(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse("${v ?? ''}") ?? 0);

  Map<String, dynamic> toJson() => {
        "spendDays": spendDays,
        "planId": planId,
        "remainingDays": remainingDays,
        "title": title,
        "shortDescription": shortDescription,
        "longDescription": longDescription,
        "CategoryId": categoryId,
        "buyingDate": buyingDate?.toIso8601String(),
        "expireDate": expireDate?.toIso8601String(),
        "priceData": priceData?.toJson(),
      };
}

class PriceData {
  int? id;
  String? priceAmount;

  PriceData({
    this.id,
    this.priceAmount,
  });

  factory PriceData.fromJson(Map<String, dynamic> json) => PriceData(
        id: json["id"],
        priceAmount: json["priceAmount"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "priceAmount": priceAmount,
      };
}

class UserData {
  int id;
  RxBool freeze;
  RxBool usedFreezeOption;

  UserData({
    required this.id,
    required this.freeze,
    required this.usedFreezeOption,
  });

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
        id: json["id"] is int ? json["id"] : int.tryParse("${json["id"]}") ?? 0,
        freeze: RxBool(json["freeze"] == true || json["freeze"] == 1),
        usedFreezeOption: RxBool(
            json["usedFreezeOption"] == true || json["usedFreezeOption"] == 1),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "freeze": freeze,
        "usedFreezeOption": usedFreezeOption,
      };
}
