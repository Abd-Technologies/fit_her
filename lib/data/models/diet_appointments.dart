// To parse this JSON data, do
//
//     final dietAppointments = dietAppointmentsFromJson(jsonString);

import 'dart:convert';

import 'package:fitness_zone_2/data/models/api_response/api_response_model.dart';

import 'get_clients_diet.dart';
import 'package:intl/intl.dart';

DietAppointments dietAppointmentsFromJson(String str) => DietAppointments.fromJson(json.decode(str));

String dietAppointmentsToJson(DietAppointments data) => json.encode(data.toJson());

class DietAppointments  extends Serializable{
  List<Appointment> appointments;

  DietAppointments({
    required this.appointments,
  });

  factory DietAppointments.fromJson(Map<String, dynamic> json) => DietAppointments(
    appointments: List<Appointment>.from(json["appointments"].map((x) => Appointment.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "appointments": List<dynamic>.from(appointments.map((x) => x.toJson())),
  };
}

class Appointment {
  int id;
  DateTime date;
  String status;
  int userId;
  int dietitionId;
  int timeSlotId;
  String message;
  ClientUser? clientUser;
  SlotDiet? slotDiet;
  // 'initial' | 'followup' | null (legacy rows predate this column —
  // treat null as 'initial', same convention the backend itself uses
  // wherever it queries by kind).
  String? kind;
  // Per-appointment snapshot of the meeting link, taken at confirm time
  // (see backend Appointments.js meetLink doc comment). Null for older
  // rows or ones confirmed before a link existed on the slot yet — in
  // that case fall back to slotDiet.dietitionLink, same rule the client
  // side already applies server-side. Use `resolvedMeetLink` below
  // rather than reading this directly.
  dynamic meetLink;
  // Which consultation this is for the client (1 = her first, 2 = her
  // second...). Sent by the dietitian's appointments endpoint; null on
  // older backends.
  int? consultNumber;
  // The client's package (UserPlan id) this booking belongs to. Lets the
  // dietitian generate the plan straight from the session's profile.
  int? planId;
  // Nov 2026: attendance from the app (helper/consultAttendance.js on the
  // server). `attendance` = {client: {joinedAt, leftAt, leftHow, minutes,
  // joins, minutesFrom}, dietitian: {startedAt, endedAt, endedHow}, source}.
  Map<String, dynamic>? attendance;
  String? clientJoinTapAt;
  String? clientNoShowAt;
  String? attendanceFlag;
  String? attendanceSource;

  Appointment({
    required this.id,
    required this.date,
    required this.status,
    required this.userId,
    required this.dietitionId,
    required this.timeSlotId,
    required this.clientUser,
    required this.message,
    required this.slotDiet,
    this.meetLink,
    this.kind,
    this.consultNumber,
    this.planId,
    this.attendance,
    this.clientJoinTapAt,
    this.clientNoShowAt,
    this.attendanceFlag,
    this.attendanceSource,
  });

  /// The link to actually open for this appointment: this appointment's
  /// own frozen snapshot if it has one, otherwise the weekly slot's
  /// current link. Null (or blank) means no link has been set yet.
  String? get resolvedMeetLink {
    final own = meetLink?.toString().trim();
    if (own != null && own.isNotEmpty) return own;
    final slotLink = slotDiet?.dietitionLink?.toString().trim();
    if (slotLink != null && slotLink.isNotEmpty) return slotLink;
    return null;
  }

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    // Same `?? 0` defensive pattern already used for userId below.
    // Backend has been observed returning null timeSlotId for some
    // appointment rows (e.g. unassigned slot deleted server-side);
    // without the guard, the int cast crashes the whole list parse
    // and no appointments render at all.
    id: json["id"] ?? 0,
    date: DateTime.parse(json["date"]),
    status: json["status"] ?? "",
    userId: json["userId"]??0,
    message: json["message"]??"N/A",
    dietitionId: json["dietitionId"] ?? 0,
    timeSlotId: json["timeSlotId"] ?? 0,
    clientUser:json["ClientUser"]==null?null: ClientUser.fromJson(json["ClientUser"]),
    slotDiet: json["SlotDiet"]==null?null:SlotDiet.fromJson(json["SlotDiet"]),
    meetLink: json["meetLink"],
    kind: json["kind"],
    consultNumber: json["consultNumber"] is num
        ? (json["consultNumber"] as num).toInt()
        : null,
    planId: json["planId"] is num ? (json["planId"] as num).toInt() : null,
    attendance: json["attendance"] is Map ? Map<String, dynamic>.from(json["attendance"]) : null,
    clientJoinTapAt: json["clientJoinTapAt"]?.toString(),
    clientNoShowAt: json["clientNoShowAt"]?.toString(),
    attendanceFlag: json["attendanceFlag"]?.toString(),
    attendanceSource: json["attendanceSource"]?.toString(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "date": date.toIso8601String(),
    "status": status,
    "message": message,
    "userId": userId,
    "dietitionId": dietitionId,
    "timeSlotId": timeSlotId,
    "ClientUser": clientUser?.toJson(),
    "SlotDiet": slotDiet?.toJson(),
    "meetLink": meetLink,
    "kind": kind,
    "consultNumber": consultNumber,
  };
}



class SlotDiet {
  int? id;
  String? start;
  String? end;
  dynamic dietitionLink;
  dynamic isAvailble;
  int? dietitionId;
  int? timeDietitionId;

  SlotDiet({
    required this.id,
    required this.start,
    required this.end,
    required this.dietitionLink,
    required this.isAvailble,
    required this.dietitionId,
    required this.timeDietitionId,
  });

  factory SlotDiet.fromJson(Map<String, dynamic> json) => SlotDiet(
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
    dietitionLink: json["dietitionLink"],
    isAvailble: json["isAvailble"],
    dietitionId: json["dietitionId"],
    timeDietitionId: json["TimeDietitionId"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "start": start,
    "end": end,
    "dietitionLink": dietitionLink,
    "isAvailble": isAvailble,
    "dietitionId": dietitionId,
    "TimeDietitionId": timeDietitionId,
  };
  get time => "${this.start} - ${this.end}";

}
