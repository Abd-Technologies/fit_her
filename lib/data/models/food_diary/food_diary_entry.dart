import 'dart:convert';

import '../../services/food_db_service.dart';

/// Free-form / photo meal diary entry (1NH8–1NH10, 1NH9).
class FoodDiaryEntry {
  final String id;
  final String date;
  final String foodId;
  final String name;
  final String serving;
  final double portion; // 1.0 = default serving
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? photoPath;
  final bool fromPhoto;
  final String? phaseScoreTag; // green|amber|neutral (2NH2)
  final String? phaseScoreReason;
  final DateTime updatedAt;

  const FoodDiaryEntry({
    required this.id,
    required this.date,
    required this.foodId,
    required this.name,
    required this.serving,
    this.portion = 1.0,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.photoPath,
    this.fromPhoto = false,
    this.phaseScoreTag,
    this.phaseScoreReason,
    required this.updatedAt,
  });

  int get totalCalories => (calories * portion).round();

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'foodId': foodId,
        'name': name,
        'serving': serving,
        'portion': portion,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'photoPath': photoPath,
        'fromPhoto': fromPhoto,
        'phaseScoreTag': phaseScoreTag,
        'phaseScoreReason': phaseScoreReason,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FoodDiaryEntry.fromJson(Map<String, dynamic> json) {
    return FoodDiaryEntry(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      foodId: json['foodId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      serving: json['serving']?.toString() ?? '',
      portion: (json['portion'] as num?)?.toDouble() ?? 1.0,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      photoPath: json['photoPath'] as String?,
      fromPhoto: json['fromPhoto'] == true,
      phaseScoreTag: json['phaseScoreTag'] as String?,
      phaseScoreReason: json['phaseScoreReason'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  factory FoodDiaryEntry.fromFood({
    required String id,
    required String date,
    required FoodItem food,
    double portion = 1.0,
    String? photoPath,
    bool fromPhoto = false,
    String? phaseScoreTag,
    String? phaseScoreReason,
  }) {
    return FoodDiaryEntry(
      id: id,
      date: date,
      foodId: food.id,
      name: food.nameEn,
      serving: food.serving,
      portion: portion,
      calories: food.calories,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      photoPath: photoPath,
      fromPhoto: fromPhoto,
      phaseScoreTag: phaseScoreTag,
      phaseScoreReason: phaseScoreReason,
      updatedAt: DateTime.now(),
    );
  }

  FoodDiaryEntry copyWith({
    String? foodId,
    String? name,
    String? serving,
    double? portion,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? phaseScoreTag,
    String? phaseScoreReason,
  }) {
    return FoodDiaryEntry(
      id: id,
      date: date,
      foodId: foodId ?? this.foodId,
      name: name ?? this.name,
      serving: serving ?? this.serving,
      portion: portion ?? this.portion,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      photoPath: photoPath,
      fromPhoto: fromPhoto,
      phaseScoreTag: phaseScoreTag ?? this.phaseScoreTag,
      phaseScoreReason: phaseScoreReason ?? this.phaseScoreReason,
      updatedAt: DateTime.now(),
    );
  }

  static List<FoodDiaryEntry> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => FoodDiaryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
