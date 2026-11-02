/// 2NH9 — skin and hair logging (no photos in this item).
class SkinHairLog {
  final String id;
  final String date;
  final Map<String, int> severities; // chip -> 1–3
  final String? cyclePhase;
  final DateTime updatedAt;

  const SkinHairLog({
    required this.id,
    required this.date,
    this.severities = const {},
    this.cyclePhase,
    required this.updatedAt,
  });

  static const chips = [
    'acne',
    'oily_skin',
    'dry_skin',
    'hair_fall',
    'unwanted_hair',
  ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'severities': severities,
        'cyclePhase': cyclePhase,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SkinHairLog.fromJson(Map<String, dynamic> json) {
    final sev = <String, int>{};
    final raw = json['severities'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num) sev[k.toString()] = v.toInt();
      });
    }
    return SkinHairLog(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      severities: sev,
      cyclePhase: json['cyclePhase']?.toString(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
