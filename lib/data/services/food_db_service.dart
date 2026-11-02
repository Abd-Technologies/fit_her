import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Bundled Pakistani / South Asian food database (1NH7).
class FoodItem {
  final String id;
  final String nameEn;
  final String nameRoman;
  final List<String> aliases;
  final String serving;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;

  const FoodItem({
    required this.id,
    required this.nameEn,
    required this.nameRoman,
    required this.aliases,
    required this.serving,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id']?.toString() ?? '',
      nameEn: json['nameEn']?.toString() ?? '',
      nameRoman: json['nameRoman']?.toString() ?? '',
      aliases: (json['aliases'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      serving: json['serving']?.toString() ?? '1 serving',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      fibre: (json['fibre'] as num?)?.toDouble() ?? 0,
    );
  }

  bool matches(String q) {
    final needle = q.trim().toLowerCase();
    if (needle.isEmpty) return true;
    if (nameEn.toLowerCase().contains(needle)) return true;
    if (nameRoman.toLowerCase().contains(needle)) return true;
    return aliases.any((a) => a.toLowerCase().contains(needle));
  }
}

class FoodDbService extends GetxService {
  static const assetPath = 'assets/food/pakistani_foods.json';
  static const version = 1;

  final RxList<FoodItem> foods = <FoodItem>[].obs;
  final RxBool loaded = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      final list = decoded is Map ? decoded['foods'] : decoded;
      if (list is List) {
        foods.assignAll(
          list
              .whereType<Map>()
              .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e))),
        );
      }
    } catch (e) {
      debugPrint('[FoodDbService] load failed, using fallback: $e');
      foods.assignAll(_fallback);
    } finally {
      loaded.value = true;
    }
  }

  List<FoodItem> search(String query, {int limit = 20}) {
    final q = query.trim();
    final hits = foods.where((f) => f.matches(q)).take(limit).toList();
    return hits;
  }

  FoodItem? byId(String id) {
    try {
      return foods.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Local "recognition" stub: pick best name match from filename/hint.
  FoodItem? matchFromHint(String hint) {
    final hits = search(hint, limit: 1);
    return hits.isEmpty ? null : hits.first;
  }

  static const _fallback = <FoodItem>[
    FoodItem(
      id: 'roti',
      nameEn: 'Roti',
      nameRoman: 'Roti',
      aliases: ['chapati', 'phulka'],
      serving: '1 roti',
      calories: 120,
      protein: 3,
      carbs: 20,
      fat: 3,
      fibre: 2,
    ),
    FoodItem(
      id: 'daal',
      nameEn: 'Daal',
      nameRoman: 'Daal',
      aliases: ['lentil', 'dal'],
      serving: '1 katori',
      calories: 180,
      protein: 12,
      carbs: 25,
      fat: 4,
      fibre: 8,
    ),
  ];
}
