import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helper/analytics_helper.dart';
import '../analytics/analytics_events.dart';
import '../models/food_prefs/food_preferences.dart';

/// 2NH1 — persist and filter food suggestions by prefs/allergies.
class FoodPreferencesService extends GetxService {
  static const _key = 'd23_food_prefs_v1';

  final SharedPreferences prefs;

  FoodPreferencesService({required this.prefs});

  final Rx<FoodPreferences> current = const FoodPreferences().obs;

  @override
  void onInit() {
    super.onInit();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        current.value =
            FoodPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> save(FoodPreferences next) async {
    current.value = next;
    await prefs.setString(_key, jsonEncode(next.toJson()));
    await AnalyticsHelper.track(
      AnalyticsEvents.foodPrefsSaved,
      props: {
        'dietType': next.dietType,
        'allergies': next.allergies.length,
        'dislikes': next.dislikes.length,
      },
    );
  }

  List<T> filterSafe<T>(
    List<T> items,
    String Function(T) textOf, {
    bool dropDislikes = false,
  }) {
    return items.where((item) {
      final text = textOf(item);
      if (current.value.isAllergyBlocked(text)) return false;
      if (dropDislikes && current.value.isDisliked(text)) return false;
      return true;
    }).toList();
  }
}
