/// Daily symptom entry (1NH1). One logical entry per day; editable 48h.
class SymptomLog {
  final String id;
  final String date; // yyyy-MM-dd
  final String? cyclePhase;
  final Map<String, int> severities; // symptom key -> 1..3
  final String? painBodyArea;
  final DateTime updatedAt;
  final bool synced;

  const SymptomLog({
    required this.id,
    required this.date,
    this.cyclePhase,
    required this.severities,
    this.painBodyArea,
    required this.updatedAt,
    this.synced = false,
  });

  static const symptomKeys = <String>[
    'cramps',
    'headache',
    'bloating',
    'fatigue',
    'nausea',
    'breast_tenderness',
    'back_pain',
    'acne',
  ];

  static const labels = <String, String>{
    'cramps': 'Cramps',
    'headache': 'Headache',
    'bloating': 'Bloating',
    'fatigue': 'Fatigue',
    'nausea': 'Nausea',
    'breast_tenderness': 'Breast tenderness',
    'back_pain': 'Back pain',
    'acne': 'Acne',
  };

  static const painAreas = <String>[
    'lower_abdomen',
    'lower_back',
    'pelvis',
    'thighs',
    'other',
  ];

  bool get isEditable {
    final age = DateTime.now().difference(updatedAt);
    return age.inHours < 48;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'cyclePhase': cyclePhase,
        'severities': severities,
        'painBodyArea': painBodyArea,
        'updatedAt': updatedAt.toIso8601String(),
        'synced': synced,
      };

  factory SymptomLog.fromJson(Map<String, dynamic> json) {
    final raw = json['severities'];
    final sev = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num) sev[k.toString()] = v.toInt().clamp(1, 3);
      });
    }
    return SymptomLog(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      cyclePhase: json['cyclePhase'] as String?,
      severities: sev,
      painBodyArea: json['painBodyArea'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      synced: json['synced'] == true,
    );
  }

  SymptomLog copyWith({
    Map<String, int>? severities,
    String? painBodyArea,
    String? cyclePhase,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return SymptomLog(
      id: id,
      date: date,
      cyclePhase: cyclePhase ?? this.cyclePhase,
      severities: severities ?? this.severities,
      painBodyArea: painBodyArea ?? this.painBodyArea,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }
}
