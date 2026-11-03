import '../../../helper/pk_time.dart';

/// Returned by GET /users/dietitian-availability. Each AvailabilitySlot
/// is a (template × date) pair already filtered against existing booked
/// Appointments — `available` tells the UI whether to render the slot
/// as bookable.
class DietitianAvailabilitySlot {
  final int? slotDietId;

  /// Nov 2026: [date], [start] and [end] are in HER phone's time (what
  /// the screens show). [pkDate] is the server's Pakistan date: always
  /// send that one back when booking.
  final String date; // YYYY-MM-DD, her time
  final String? start; // "h:mm AM", her time
  final String? end;
  final String pkDate; // YYYY-MM-DD, Pakistan (server)
  final bool available;

  const DietitianAvailabilitySlot({
    this.slotDietId,
    required this.date,
    this.start,
    this.end,
    String? pkDate,
    this.available = false,
  }) : pkDate = pkDate ?? date;

  factory DietitianAvailabilitySlot.fromJson(Map<String, dynamic> json) {
    final pkDate = (json['date'] as String?) ?? '';
    final pkStart = json['start'] as String?;
    final pkEnd = json['end'] as String?;
    final s = PkTime.toLocal(pkDate, pkStart);
    final e = PkTime.toLocal(pkDate, pkEnd);
    return DietitianAvailabilitySlot(
      slotDietId: json['slotDietId'] as int?,
      date: s != null ? PkTime.ymd(s) : pkDate,
      start: s != null ? PkTime.clock(s) : pkStart,
      end: e != null ? PkTime.clock(e) : pkEnd,
      pkDate: pkDate,
      available: (json['available'] as bool?) ?? false,
    );
  }
}

class DietitianAvailability {
  final int? dietitianId;
  final String? dietitianName;
  final String? from;
  final String? to;
  final List<DietitianAvailabilitySlot> slots;

  const DietitianAvailability({
    this.dietitianId,
    this.dietitianName,
    this.from,
    this.to,
    this.slots = const [],
  });

  factory DietitianAvailability.fromJson(Map<String, dynamic> json) {
    final raw = json['slots'];
    final slots = raw is List
        ? raw
            .whereType<Map>()
            .map((m) => DietitianAvailabilitySlot.fromJson(
                Map<String, dynamic>.from(m)))
            .toList()
        : <DietitianAvailabilitySlot>[];
    return DietitianAvailability(
      dietitianId: json['dietitianId'] as int?,
      dietitianName: json['dietitianName']?.toString(),
      from: json['from'] as String?,
      to: json['to'] as String?,
      slots: slots,
    );
  }
}
