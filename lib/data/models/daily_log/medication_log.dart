/// 2NH7 — medicines and supplements (never advise on dose).
class MedicationEntry {
  final String id;
  final String name;
  final String? doseText;
  final List<String> times; // HH:mm
  final bool remind;
  final Map<String, bool> takenByDate; // yyyy-MM-dd -> taken
  final DateTime updatedAt;

  const MedicationEntry({
    required this.id,
    required this.name,
    this.doseText,
    this.times = const [],
    this.remind = false,
    this.takenByDate = const {},
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'doseText': doseText,
        'times': times,
        'remind': remind,
        'takenByDate': takenByDate,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MedicationEntry.fromJson(Map<String, dynamic> json) {
    final takenRaw = json['takenByDate'];
    final taken = <String, bool>{};
    if (takenRaw is Map) {
      takenRaw.forEach((k, v) => taken[k.toString()] = v == true);
    }
    return MedicationEntry(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      doseText: json['doseText']?.toString(),
      times: (json['times'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      remind: json['remind'] == true,
      takenByDate: taken,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  MedicationEntry copyWith({
    String? name,
    String? doseText,
    List<String>? times,
    bool? remind,
    Map<String, bool>? takenByDate,
    DateTime? updatedAt,
  }) {
    return MedicationEntry(
      id: id,
      name: name ?? this.name,
      doseText: doseText ?? this.doseText,
      times: times ?? this.times,
      remind: remind ?? this.remind,
      takenByDate: takenByDate ?? this.takenByDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
