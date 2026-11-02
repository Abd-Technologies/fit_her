
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helper/analytics_helper.dart';
import '../data/analytics/analytics_events.dart';

class ConditionModuleConfig {
  final String id;
  final String title;
  final List<String> tracking;
  final List<String> nutritionRules;
  final List<String> workoutModifiers;
  final int notificationCapPerDay;
  final String doctorReportSection;
  final String safetyPrompt;
  final String communitySpace;
  final bool disableCyclePredictionUntilReturn;

  const ConditionModuleConfig({
    required this.id,
    required this.title,
    required this.tracking,
    required this.nutritionRules,
    required this.workoutModifiers,
    required this.notificationCapPerDay,
    required this.doctorReportSection,
    required this.safetyPrompt,
    required this.communitySpace,
    this.disableCyclePredictionUntilReturn = false,
  });

  factory ConditionModuleConfig.fromJson(Map<String, dynamic> json) {
    return ConditionModuleConfig(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      tracking: (json['tracking'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      nutritionRules:
          (json['nutritionRules'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      workoutModifiers: (json['workoutModifiers'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      notificationCapPerDay:
          (json['notificationCapPerDay'] as num?)?.toInt() ?? 2,
      doctorReportSection: json['doctorReportSection']?.toString() ?? '',
      safetyPrompt: json['safetyPrompt']?.toString() ?? '',
      communitySpace: json['communitySpace']?.toString() ?? '',
      disableCyclePredictionUntilReturn:
          json['disableCyclePredictionUntilReturn'] == true,
    );
  }
}

/// 3H1 — config-driven condition modules (cautious rule wins).
class ConditionModuleEngine extends GetxService {
  static const assetPath = 'assets/conditions/modules_v1.json';
  static const _activeKey = 'd23_active_conditions_v1';
  static const _painKey = 'd23_endo_pain_diary_v1';
  static const _ttcKey = 'd23_ttc_log_v1';
  static const _pmsKey = 'd23_pms_ratings_v1';
  static const _periKey = 'd23_peri_symptoms_v1';
  static const _postpartumKey = 'd23_postpartum_meta_v1';
  static const _thyroidKey = 'd23_thyroid_meta_v1';

  final SharedPreferences prefs;

  ConditionModuleEngine({required this.prefs});

  final RxList<ConditionModuleConfig> catalog = <ConditionModuleConfig>[].obs;
  final RxSet<String> activeIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    activeIds.addAll(prefs.getStringList(_activeKey) ?? []);
    load();
  }

  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      catalog.assignAll(
        ((decoded['modules'] as List?) ?? [])
            .whereType<Map>()
            .map((e) =>
                ConditionModuleConfig.fromJson(Map<String, dynamic>.from(e))),
      );
    } catch (_) {}
  }

  Future<void> setActive(String id, bool on) async {
    if (on) {
      activeIds.add(id);
    } else {
      activeIds.remove(id);
    }
    await prefs.setStringList(_activeKey, activeIds.toList());
    if (on) {
      await AnalyticsHelper.track(
        AnalyticsEvents.conditionActivated,
        props: {'id': id},
      );
    }
  }

  List<ConditionModuleConfig> get activeModules =>
      catalog.where((m) => activeIds.contains(m.id)).toList();

  /// Cautious rule: lowest notification cap among active modules wins.
  int get notificationCap {
    final caps = activeModules.map((m) => m.notificationCapPerDay);
    if (caps.isEmpty) return 3;
    return caps.reduce((a, b) => a < b ? a : b);
  }

  bool get cyclePredictionDisabled {
    return activeModules.any((m) => m.disableCyclePredictionUntilReturn);
  }

  List<String> get workoutModifiers {
    final out = <String>{};
    for (final m in activeModules) {
      out.addAll(m.workoutModifiers);
    }
    return out.toList();
  }

  List<String> get nutritionRules {
    final out = <String>{};
    for (final m in activeModules) {
      out.addAll(m.nutritionRules);
    }
    return out.toList();
  }

  String get combinedSafetyPrompt {
    return activeModules.map((m) => m.safetyPrompt).join('\n');
  }

  String get doctorReportSections {
    return activeModules.map((m) => m.doctorReportSection).join('\n');
  }

  // --- module-specific local stores ---

  Future<void> savePainDiary(Map<String, dynamic> entry) async {
    final list = _loadList(_painKey);
    list.add({...entry, 'at': DateTime.now().toIso8601String()});
    await prefs.setString(_painKey, jsonEncode(list));
  }

  List<Map<String, dynamic>> painDiary() => _loadList(_painKey);

  Future<void> saveTtcEntry(Map<String, dynamic> entry) async {
    final list = _loadList(_ttcKey);
    list.add({...entry, 'at': DateTime.now().toIso8601String()});
    await prefs.setString(_ttcKey, jsonEncode(list));
  }

  List<Map<String, dynamic>> ttcLog() => _loadList(_ttcKey);

  Future<void> savePmsRating(Map<String, dynamic> entry) async {
    final list = _loadList(_pmsKey);
    list.add({...entry, 'at': DateTime.now().toIso8601String()});
    await prefs.setString(_pmsKey, jsonEncode(list));
  }

  Future<void> savePeriSymptoms(Map<String, dynamic> entry) async {
    final list = _loadList(_periKey);
    list.add({...entry, 'at': DateTime.now().toIso8601String()});
    await prefs.setString(_periKey, jsonEncode(list));
  }

  Future<void> savePostpartumMeta(Map<String, dynamic> meta) async {
    await prefs.setString(_postpartumKey, jsonEncode(meta));
  }

  Map<String, dynamic>? postpartumMeta() {
    final raw = prefs.getString(_postpartumKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveThyroidMeta(Map<String, dynamic> meta) async {
    await prefs.setString(_thyroidKey, jsonEncode(meta));
  }

  Map<String, dynamic>? thyroidMeta() {
    final raw = prefs.getString(_thyroidKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _loadList(String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
