/// Returned by GET /users/dietitian-availability. Each AvailabilitySlot
/// is a (template × date) pair already filtered against existing booked
/// Appointments — `available` tells the UI whether to render the slot
/// as bookable.
class DietitianAvailabilitySlot {
  final int? slotDietId;
  final String date; // YYYY-MM-DD
  final String? start;
  final String? end;
  final bool available;

  const DietitianAvailabilitySlot({
    this.slotDietId,
    required this.date,
    this.start,
    this.end,
    this.available = false,
  });

  factory DietitianAvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return DietitianAvailabilitySlot(
      slotDietId: json['slotDietId'] as int?,
      date: (json['date'] as String?) ?? '',
      start: json['start'] as String?,
      end: json['end'] as String?,
      available: (json['available'] as bool?) ?? false,
    );
  }
}

class DietitianAvailability {
  final int? dietitianId;
  final String? from;
  final String? to;
  final List<DietitianAvailabilitySlot> slots;

  const DietitianAvailability({
    this.dietitianId,
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
      from: json['from'] as String?,
      to: json['to'] as String?,
      slots: slots,
    );
  }
}
