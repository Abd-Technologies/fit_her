import 'package:fitness_zone_2/data/models/api_response/api_response_model.dart';

class DailyCheckin extends Serializable {
  final int? id;
  final int? userId;
  final String? date;
  final int? energyLevel;
  final int? moodLevel;
  final double? sleepHours;
  final String? cravingType;
  final String? note;
  final int? cycleDay;
  final String? cyclePhase;
  final int? predictedEnergy;
  final int? predictedMood;
  final String? createdAt;
  /// Delivery 1 — stress + rested fields (1NH4 / 1NH5).
  final int? stressLevel;
  final String? stressCause;
  final int? sleepRested;

  DailyCheckin({
    this.id,
    this.userId,
    this.date,
    this.energyLevel,
    this.moodLevel,
    this.sleepHours,
    this.cravingType,
    this.note,
    this.cycleDay,
    this.cyclePhase,
    this.predictedEnergy,
    this.predictedMood,
    this.createdAt,
    this.stressLevel,
    this.stressCause,
    this.sleepRested,
  });

  factory DailyCheckin.fromJson(Map<String, dynamic> json) {
    return DailyCheckin(
      id: json['id'] as int?,
      userId: json['userId'] as int?,
      date: json['date'] as String?,
      energyLevel: json['energyLevel'] as int?,
      moodLevel: json['moodLevel'] as int?,
      sleepHours: (json['sleepHours'] as num?)?.toDouble(),
      cravingType: json['cravingType'] as String?,
      note: json['note'] as String?,
      cycleDay: json['cycleDay'] as int?,
      cyclePhase: json['cyclePhase'] as String?,
      predictedEnergy: json['predictedEnergy'] as int?,
      predictedMood: json['predictedMood'] as int?,
      createdAt: json['createdAt'] as String?,
      stressLevel: json['stressLevel'] as int?,
      stressCause: json['stressCause'] as String?,
      sleepRested: json['sleepRested'] as int?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date,
      'energyLevel': energyLevel,
      'moodLevel': moodLevel,
      'sleepHours': sleepHours,
      'cravingType': cravingType,
      'note': note,
      'cycleDay': cycleDay,
      'cyclePhase': cyclePhase,
      'predictedEnergy': predictedEnergy,
      'predictedMood': predictedMood,
      'createdAt': createdAt,
      'stressLevel': stressLevel,
      'stressCause': stressCause,
      'sleepRested': sleepRested,
    };
  }

  DailyCheckin copyWith({
    int? id,
    int? userId,
    String? date,
    int? energyLevel,
    int? moodLevel,
    double? sleepHours,
    String? cravingType,
    String? note,
    int? cycleDay,
    String? cyclePhase,
    int? predictedEnergy,
    int? predictedMood,
    String? createdAt,
    int? stressLevel,
    String? stressCause,
    int? sleepRested,
  }) {
    return DailyCheckin(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      energyLevel: energyLevel ?? this.energyLevel,
      moodLevel: moodLevel ?? this.moodLevel,
      sleepHours: sleepHours ?? this.sleepHours,
      cravingType: cravingType ?? this.cravingType,
      note: note ?? this.note,
      cycleDay: cycleDay ?? this.cycleDay,
      cyclePhase: cyclePhase ?? this.cyclePhase,
      predictedEnergy: predictedEnergy ?? this.predictedEnergy,
      predictedMood: predictedMood ?? this.predictedMood,
      createdAt: createdAt ?? this.createdAt,
      stressLevel: stressLevel ?? this.stressLevel,
      stressCause: stressCause ?? this.stressCause,
      sleepRested: sleepRested ?? this.sleepRested,
    );
  }
}
