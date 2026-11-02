/// Quick daily check-in payload (1NH2–1NH5 + 2NH5/2NH6). Skipped day stays null.
class QuickCheckin {
  final String date; // yyyy-MM-dd
  final int? mood; // 1–5
  final int? energy; // 1–5
  final int? stress; // 1–5
  final String? stressCause; // work|family|health|money|other
  final double? sleepHours;
  final int? sleepRested; // 1–3
  final int? hunger; // 1–5 (2NH5)
  final List<String> cravings; // sweet|salty|carbs|none (2NH5)
  final String? digestion; // normal|bloated|constipated|loose (2NH6)
  final String? digestionNote;
  final String? cyclePhase;
  final DateTime updatedAt;
  final bool synced;

  const QuickCheckin({
    required this.date,
    this.mood,
    this.energy,
    this.stress,
    this.stressCause,
    this.sleepHours,
    this.sleepRested,
    this.hunger,
    this.cravings = const [],
    this.digestion,
    this.digestionNote,
    this.cyclePhase,
    required this.updatedAt,
    this.synced = false,
  });

  static const stressCauses = ['work', 'family', 'health', 'money', 'other'];
  static const cravingOptions = ['sweet', 'salty', 'carbs', 'none'];
  static const digestionOptions = [
    'normal',
    'bloated',
    'constipated',
    'loose',
  ];

  bool get isComplete =>
      mood != null &&
      energy != null &&
      stress != null &&
      sleepHours != null &&
      sleepRested != null;

  Map<String, dynamic> toApiBody() => {
        'date': date,
        if (mood != null) 'moodLevel': mood,
        if (energy != null) 'energyLevel': energy,
        if (stress != null) 'stressLevel': stress,
        if (stressCause != null) 'stressCause': stressCause,
        if (sleepHours != null) 'sleepHours': sleepHours,
        if (sleepRested != null) 'sleepRested': sleepRested,
        if (hunger != null) 'hunger': hunger,
        if (cravings.isNotEmpty) 'cravings': cravings,
        if (digestion != null) 'digestion': digestion,
        if (digestionNote != null) 'digestionNote': digestionNote,
        if (cyclePhase != null) 'cyclePhase': cyclePhase,
      };

  Map<String, dynamic> toJson() => {
        ...toApiBody(),
        'updatedAt': updatedAt.toIso8601String(),
        'synced': synced,
      };

  factory QuickCheckin.fromJson(Map<String, dynamic> json) {
    return QuickCheckin(
      date: json['date']?.toString() ?? '',
      mood: (json['moodLevel'] ?? json['mood']) as int?,
      energy: (json['energyLevel'] ?? json['energy']) as int?,
      stress: (json['stressLevel'] ?? json['stress']) as int?,
      stressCause: json['stressCause'] as String?,
      sleepHours: (json['sleepHours'] as num?)?.toDouble(),
      sleepRested: json['sleepRested'] as int?,
      hunger: json['hunger'] as int?,
      cravings: (json['cravings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      digestion: json['digestion'] as String?,
      digestionNote: json['digestionNote'] as String?,
      cyclePhase: json['cyclePhase'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      synced: json['synced'] == true,
    );
  }
}
