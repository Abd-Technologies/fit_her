// To parse this JSON data, do
//
//     final getUserWorkoutPlanDetails = getUserWorkoutPlanDetailsFromJson(jsonString);

import 'dart:convert';

import 'package:fitness_zone_2/data/models/api_response/api_response_model.dart';
import 'package:fitness_zone_2/data/models/get_clients_diet.dart';
import 'package:intl/intl.dart';

GetUserWorkoutPlanDetails getUserWorkoutPlanDetailsFromJson(String str) =>
    GetUserWorkoutPlanDetails.fromJson(json.decode(str));

String getUserWorkoutPlanDetailsToJson(GetUserWorkoutPlanDetails data) =>
    json.encode(data.toJson());

class GetUserWorkoutPlanDetails extends Serializable {
  List<TrainerSlot> trainerSlots;
  Plan? plan;

  GetUserWorkoutPlanDetails({
    required this.trainerSlots,
    required this.plan,
  });

  factory GetUserWorkoutPlanDetails.fromJson(Map<String, dynamic> json) =>
      GetUserWorkoutPlanDetails(
        trainerSlots: List<TrainerSlot>.from(
            json["trainerSlots"].map((x) => TrainerSlot.fromJson(x))),
        plan: json["plan"] == null ? null : Plan.fromJson(json["plan"]),
      );

  Map<String, dynamic> toJson() => {
        "trainerSlots": List<dynamic>.from(trainerSlots.map((x) => x.toJson())),
        "plan": plan?.toJson(),
      };
}

class Plan {
  int id;
  String title;
  String shortDescription;
  String longDescription;

  Plan({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.longDescription,
  });

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: json["id"],
        title: json["title"],
        shortDescription: json["shortDescription"],
        longDescription: json["longDescription"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "shortDescription": shortDescription,
        "longDescription": longDescription,
      };
}

class TrainerSlot {
  int id;
  String day;
  List<Slot> slots;

  TrainerSlot({
    required this.id,
    required this.day,
    required this.slots,
  });

  factory TrainerSlot.fromJson(Map<String, dynamic> json) => TrainerSlot(
        id: json["id"],
        day: json["day"],
        slots: List<Slot>.from(json["slots"].map((x) => Slot.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "day": day,
        "slots": List<dynamic>.from(slots.map((x) => x.toJson())),
      };
}

class Slot {
  int id;
  String start;
  String end;
  String? trainerLink;
  ClientUser? trainer;
  /// Trainer's full name (analytics / presence logging). Null if unknown.
  String? get trainerName {
    final t = trainer;
    if (t == null) return null;
    final n = '${t.firstName} ${t.lastName}'.trim();
    return n.isEmpty ? null : n;
  }
  String? type;
  String? level;
  String? description;
  int? joinedUserUID;
  String? token;
  String? status;
  bool? isTrainerJoined;

  Slot(
      {required this.id,
      required this.start,
      required this.end,
      required this.trainerLink,
      required this.trainer,
      this.type,
      this.joinedUserUID,
      this.token,
      this.status,
      this.isTrainerJoined,
      this.level,
      this.description});

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
        id: json["id"],
        start: json["start"] == "Start Time"
            ? "Start Time"
            : (json["start"].toString().contains("AM") ||
                    json["start"].toString().contains("PM"))
                ? json["start"]
                : DateFormat('hh:mm a').format(
                    DateTime.fromMillisecondsSinceEpoch(
                        int.parse(json["start"]))),
        end: json["end"] == "End Time"
            ? "End Time"
            : (json["end"].toString().contains("AM") ||
                    json["end"].toString().contains("PM"))
                ? json["end"]
                : DateFormat('hh:mm a').format(
                    DateTime.fromMillisecondsSinceEpoch(
                        int.parse(json["end"]))),
        trainerLink: json["trainerLink"],
        joinedUserUID: json["joinedUserUID"],
        isTrainerJoined: json["isTrainerJoined"],
        type: json["type"],
        level: json["level"],
        status: json["status"],
        token: json["token"],
        description: json["description"],
        trainer: json["trainer"] == null
            ? null
            : ClientUser.fromJson(json["trainer"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "start": start,
        "end": end,
        "status": status,
        "trainerLink": trainerLink,
        "description": description,
        "type": type,
        "level": level,
        "token": token,
        "joinedUserUID": joinedUserUID,
        "isTrainerJoined": isTrainerJoined,
        "trainer": trainer?.toJson(),
      };
}
