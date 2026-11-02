
class RecordedClass {
  final String id;
  final String title;
  final String trainer;
  final String trainerStyle;
  final int durationMin;
  final String level;
  final String focus;
  final String phase;
  final List<String> equipment;
  final String streamUrl;
  final List<String> tags;
  final bool micro;
  final bool unlimitedOnly;

  const RecordedClass({
    required this.id,
    required this.title,
    required this.trainer,
    required this.trainerStyle,
    required this.durationMin,
    required this.level,
    required this.focus,
    required this.phase,
    required this.equipment,
    required this.streamUrl,
    this.tags = const [],
    this.micro = false,
    this.unlimitedOnly = false,
  });

  factory RecordedClass.fromJson(Map<String, dynamic> json) => RecordedClass(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        trainer: json['trainer']?.toString() ?? '',
        trainerStyle: json['trainerStyle']?.toString() ?? 'calm',
        durationMin: (json['durationMin'] as num?)?.toInt() ?? 0,
        level: json['level']?.toString() ?? 'beginner',
        focus: json['focus']?.toString() ?? '',
        phase: json['phase']?.toString() ?? 'any',
        equipment: (json['equipment'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        streamUrl: json['streamUrl']?.toString() ?? '',
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        micro: json['micro'] == true,
        unlimitedOnly: json['unlimitedOnly'] == true,
      );
}

class LibraryProgram {
  final String id;
  final String title;
  final int weeks;
  final List<String> classIds;

  const LibraryProgram({
    required this.id,
    required this.title,
    required this.weeks,
    required this.classIds,
  });

  factory LibraryProgram.fromJson(Map<String, dynamic> json) => LibraryProgram(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        weeks: (json['weeks'] as num?)?.toInt() ?? 4,
        classIds: (json['classIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}
