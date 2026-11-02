import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../helper/analytics_helper.dart';
import '../../utils/app_clock.dart';
import '../analytics/analytics_events.dart';
import '../controllers/cycle_theme_controller/cycle_theme_controller.dart';
import '../models/food_diary/food_diary_entry.dart';
import 'food_db_service.dart';
import 'food_preferences_service.dart';
import 'phase_food_scoring_service.dart';
import 'tier_access_service.dart';

class FoodDiaryService extends GetxService {
  static const _prefsKey = 'd1_food_diary_v1';
  static const _correctionsKey = 'd1_food_corrections_v1';

  final SharedPreferences prefs;
  final FoodDbService foodDb;
  final TierAccessService tier;

  FoodDiaryService({
    required this.prefs,
    required this.foodDb,
    required this.tier,
  });

  final RxList<FoodDiaryEntry> entries = <FoodDiaryEntry>[].obs;

  @override
  void onInit() {
    super.onInit();
    entries.assignAll(FoodDiaryEntry.decodeList(prefs.getString(_prefsKey)));
  }

  Future<void> _persist() async {
    await prefs.setString(
      _prefsKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  String get _today {
    final n = AppClock.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  List<FoodDiaryEntry> forDate(String date) =>
      entries.where((e) => e.date == date).toList();

  /// Returns null if Free cap reached.
  Future<FoodDiaryEntry?> addFromPhotoHint({
    required String hint,
    String? photoPath,
    double portion = 1.0,
  }) async {
    if (!tier.canLogMealPhoto) {
      await AnalyticsHelper.track(AnalyticsEvents.upgradeTap, props: {
        'reason': 'meal_photo_cap',
      });
      return null;
    }
    final food = foodDb.matchFromHint(hint) ?? foodDb.foods.first;
    final scored = _score(food.nameEn);
    final entry = FoodDiaryEntry.fromFood(
      id: const Uuid().v4(),
      date: _today,
      food: food,
      portion: portion,
      photoPath: photoPath,
      fromPhoto: true,
      phaseScoreTag: scored.tag,
      phaseScoreReason: scored.reason,
    );
    entries.insert(0, entry);
    await tier.recordMealPhoto();
    await _persist();
    await AnalyticsHelper.track(AnalyticsEvents.mealPhotoLogged, props: {
      'foodId': food.id,
      'remaining': tier.photosRemaining,
    });
    await AnalyticsHelper.track(AnalyticsEvents.mealPhaseScored, props: {
      'tag': scored.tag,
    });
    return entry;
  }

  Future<FoodDiaryEntry> addFromSearch({
    required FoodItem food,
    double portion = 1.0,
  }) async {
    final scored = _score(food.nameEn);
    final entry = FoodDiaryEntry.fromFood(
      id: const Uuid().v4(),
      date: _today,
      food: food,
      portion: portion,
      phaseScoreTag: scored.tag,
      phaseScoreReason: scored.reason,
    );
    entries.insert(0, entry);
    await _persist();
    await AnalyticsHelper.track(AnalyticsEvents.mealLogged, props: {
      'foodId': food.id,
    });
    await AnalyticsHelper.track(AnalyticsEvents.mealPhaseScored, props: {
      'tag': scored.tag,
    });
    return entry;
  }

  PhaseFoodScore _score(String name) {
    String? phase;
    try {
      phase = Get.find<CycleThemeController>().phase.value.name;
    } catch (_) {}
    final prefs = Get.isRegistered<FoodPreferencesService>()
        ? Get.find<FoodPreferencesService>().current.value
        : null;
    return PhaseFoodScoringService().score(
      foodName: name,
      phase: phase,
      prefs: prefs,
    );
  }

  Future<FoodDiaryEntry?> editEntry({
    required String id,
    required FoodItem food,
    double portion = 1.0,
  }) async {
    final idx = entries.indexWhere((e) => e.id == id);
    if (idx < 0) return null;
    final old = entries[idx];
    final next = old.copyWith(
      foodId: food.id,
      name: food.nameEn,
      serving: food.serving,
      portion: portion,
      calories: food.calories,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
    );
    entries[idx] = next;
    await _persist();
    await _storeCorrection(oldFoodId: old.foodId, newFoodId: food.id);
    await AnalyticsHelper.track(AnalyticsEvents.mealEdited, props: {
      'from': old.foodId,
      'to': food.id,
    });
    return next;
  }

  Future<void> _storeCorrection({
    required String oldFoodId,
    required String newFoodId,
  }) async {
    final raw = prefs.getString(_correctionsKey);
    final list = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        list.addAll((jsonDecode(raw) as List).whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
            ));
      } catch (_) {}
    }
    list.add({
      'from': oldFoodId,
      'to': newFoodId,
      'at': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_correctionsKey, jsonEncode(list));
  }
}
