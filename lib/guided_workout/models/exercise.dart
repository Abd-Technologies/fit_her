class Exercise {
  final String id;
  final String name;
  final String bodyArea;
  final String impact;
  final String equipment;
  final List<String> injuryConflicts;
  final String? easierId;
  final String? harderId;
  final String cueText;
  final String voiceAssetKey;
  final String clipUrl;
  final int durationSec;

  const Exercise({
    required this.id,
    required this.name,
    required this.bodyArea,
    required this.impact,
    required this.equipment,
    required this.injuryConflicts,
    this.easierId,
    this.harderId,
    required this.cueText,
    required this.voiceAssetKey,
    required this.clipUrl,
    required this.durationSec,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      bodyArea: json['bodyArea']?.toString() ?? '',
      impact: json['impact']?.toString() ?? 'low',
      equipment: json['equipment']?.toString() ?? 'none',
      injuryConflicts: (json['injuryConflicts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      easierId: json['easierId'] as String?,
      harderId: json['harderId'] as String?,
      cueText: json['cueText']?.toString() ?? '',
      voiceAssetKey: json['voiceAssetKey']?.toString() ?? '',
      clipUrl: json['clipUrl']?.toString() ?? '',
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 30,
    );
  }
}

enum WorkoutIntensity { easy, normal, hard }

class GuidedRoutine {
  final String id;
  final String title;
  final WorkoutIntensity intensity;
  final List<Exercise> moves;

  const GuidedRoutine({
    required this.id,
    required this.title,
    required this.intensity,
    required this.moves,
  });

  int get totalSeconds =>
      moves.fold(0, (sum, m) => sum + m.durationSec);
}
