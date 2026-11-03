// To parse this JSON data, do
//
//     final getAllPlansImages = getAllPlansImagesFromJson(jsonString);

import 'dart:convert';

import 'package:fitness_zone_2/data/models/api_response/api_response_model.dart';
import 'package:fitness_zone_2/data/models/get_clients_diet.dart';

import '../duration_model.dart';
import '../get_user_plan/get_user_plan.dart';

GetAllPlansImages getAllPlansImagesFromJson(String str) => GetAllPlansImages.fromJson(json.decode(str));

String getAllPlansImagesToJson(GetAllPlansImages data) => json.encode(data.toJson());

class GetAllPlansImages extends Serializable {
  List<Datum> data;

  GetAllPlansImages({
    required this.data,
  });

  factory GetAllPlansImages.fromJson(Map<String, dynamic> json) => GetAllPlansImages(
    data: List<Datum>.from(json["data"].map((x) => Datum.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

class Datum {
  int id;
  String? image;
  ClientUser? user;
  Plan? plan;
  // Backend has been observed sending records with `PriceDuration: null`
  // (e.g. when a plan's price tier was deleted but the image record
  // remained). Treat as nullable instead of crashing the whole list parse.
  DurationModel? priceDuration;

  // Slip check (server: helper/slipRules.js).
  String? price;
  num? ocrAmount;
  String? ocrDate;
  String? ocrTransactionId;
  Map<String, dynamic>? ocrData;

  String? get slipReason => ocrData?['approvalReason']?.toString();
  Map<String, dynamic>? get slipAccount =>
      ocrData?['account'] is Map ? Map<String, dynamic>.from(ocrData!['account']) : null;

  Datum({
    required this.id,
    required this.image,
    required this.user,
    required this.plan,
    required this.priceDuration,
    this.price,
    this.ocrAmount,
    this.ocrDate,
    this.ocrTransactionId,
    this.ocrData,
  });

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
    id: json["id"],
    image: json["image"],
    user: json["User"] == null ? null : ClientUser.fromJson(json["User"]),
    plan: json["Plan"] == null ? null : Plan.fromJson(json["Plan"]),
    priceDuration: json["PriceDuration"] == null
        ? null
        : DurationModel.fromJson(json["PriceDuration"]),
    price: json["price"]?.toString(),
    ocrAmount: json["ocrAmount"] is num ? json["ocrAmount"] : num.tryParse('${json["ocrAmount"] ?? ''}'),
    ocrDate: json["ocrDate"]?.toString(),
    ocrTransactionId: json["ocrTransactionId"]?.toString(),
    ocrData: _ocrMap(json["ocrData"]),
  );

  static Map<String, dynamic>? _ocrMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String && v.isNotEmpty) {
      try {
        final d = json.decode(v);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "image": image,
    "User": user?.toJson(),
    "Plan": plan?.toJson(),
    "PriceDuration": priceDuration?.toJson(),
  };
}



