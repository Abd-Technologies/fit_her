import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helper/analytics_helper.dart';
import '../analytics/analytics_events.dart';
import 'food_preferences_service.dart';
import 'phase_food_scoring_service.dart';

class GroceryItem {
  final String id;
  final String name;
  final String category;
  final String? phaseSwap;
  final bool checked;

  const GroceryItem({
    required this.id,
    required this.name,
    required this.category,
    this.phaseSwap,
    this.checked = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'phaseSwap': phaseSwap,
        'checked': checked,
      };

  factory GroceryItem.fromJson(Map<String, dynamic> json) => GroceryItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Other',
        phaseSwap: json['phaseSwap']?.toString(),
        checked: json['checked'] == true,
      );

  GroceryItem copyWith({bool? checked}) => GroceryItem(
        id: id,
        name: name,
        category: category,
        phaseSwap: phaseSwap,
        checked: checked ?? this.checked,
      );
}

/// 2NH4 — grocery list from plan + phase-aware swaps.
class GroceryListService extends GetxService {
  static const _key = 'd23_grocery_list_v1';

  final SharedPreferences prefs;

  GroceryListService({required this.prefs});

  final RxList<GroceryItem> items = <GroceryItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        items.assignAll(
          list
              .whereType<Map>()
              .map((e) => GroceryItem.fromJson(Map<String, dynamic>.from(e))),
        );
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    await prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> rebuildFromSamplePlan({String? phase}) async {
    final prefsSvc = Get.isRegistered<FoodPreferencesService>()
        ? Get.find<FoodPreferencesService>().current.value
        : null;
    final scorer = PhaseFoodScoringService();
    final seed = <GroceryItem>[
      const GroceryItem(
        id: 'g1',
        name: 'Chicken breast 1kg',
        category: 'Meat',
        phaseSwap: 'Iron-rich lentils if menstrual',
      ),
      const GroceryItem(
        id: 'g2',
        name: 'Spinach bunch',
        category: 'Produce',
      ),
      const GroceryItem(
        id: 'g3',
        name: 'Basmati rice 2kg',
        category: 'Pantry',
        phaseSwap: 'Oats for luteal steady carbs',
      ),
      const GroceryItem(
        id: 'g4',
        name: 'Yogurt 1kg',
        category: 'Dairy',
      ),
      const GroceryItem(
        id: 'g5',
        name: 'Bananas',
        category: 'Produce',
      ),
      const GroceryItem(
        id: 'g6',
        name: 'Olive oil',
        category: 'Pantry',
      ),
    ];

    final filtered = seed.where((item) {
      if (prefsSvc == null) return true;
      return !prefsSvc.isAllergyBlocked(item.name);
    }).map((item) {
      final score = scorer.score(
        foodName: item.name,
        phase: phase,
        prefs: prefsSvc,
      );
      if (score.tag == 'green' && item.phaseSwap == null) {
        return GroceryItem(
          id: item.id,
          name: item.name,
          category: item.category,
          phaseSwap: score.reason,
          checked: item.checked,
        );
      }
      return item;
    }).toList();

    items.assignAll(filtered);
    await _persist();
    await AnalyticsHelper.track(
      AnalyticsEvents.groceryListBuilt,
      props: {'count': items.length},
    );
  }

  Future<void> toggle(String id) async {
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    items[idx] = items[idx].copyWith(checked: !items[idx].checked);
    await _persist();
  }
}
