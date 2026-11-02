import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2P5 — remote controls (bundled JSON + local override, no app release).
class RemoteConfigService extends GetxService {
  static const assetPath = 'assets/remote/remote_controls_v1.json';
  static const _overrideKey = 'd23_remote_controls_override_v1';

  final SharedPreferences prefs;

  RemoteConfigService({required this.prefs});

  final RxMap<String, dynamic> config = <String, dynamic>{}.obs;
  final RxBool loaded = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final base = jsonDecode(raw) as Map<String, dynamic>;
      final overrideRaw = prefs.getString(_overrideKey);
      if (overrideRaw != null && overrideRaw.isNotEmpty) {
        final override = jsonDecode(overrideRaw) as Map<String, dynamic>;
        config.assignAll(_deepMerge(base, override));
      } else {
        config.assignAll(base);
      }
    } catch (_) {
      config.assignAll(_fallback);
    }
    loaded.value = true;
  }

  /// Apply a partial override (QA / founder tools) without a release.
  Future<void> applyOverride(Map<String, dynamic> partial) async {
    final merged = _deepMerge(Map<String, dynamic>.from(config), partial);
    config.assignAll(merged);
    await prefs.setString(_overrideKey, jsonEncode(partial));
  }

  Future<void> clearOverride() async {
    await prefs.remove(_overrideKey);
    await load();
  }

  bool flag(String key, {bool fallback = false}) {
    final flags = config['featureFlags'];
    if (flags is Map && flags[key] is bool) return flags[key] as bool;
    return fallback;
  }

  int get mealPhotoCapFree =>
      (config['mealPhotoCapFree'] as num?)?.toInt() ?? 30;

  int get nutritionistDailyCap =>
      (config['nutritionistDailyCap'] as num?)?.toInt() ?? 10;

  int get nutritionistMonthlyCap =>
      (config['nutritionistMonthlyCap'] as num?)?.toInt() ?? 100;

  String get pdfGate => config['pdfGate']?.toString() ?? 'plus';

  String get monthlyReportGate =>
      config['monthlyReportGate']?.toString() ?? 'plus';

  String get doctorPdfGate => config['doctorPdfGate']?.toString() ?? 'plus';

  int get aiCostAlertThreshold =>
      (config['aiCostAlertThreshold'] as num?)?.toInt() ?? 50;

  Map<String, dynamic> entitlementsFor(String tier) {
    final table = config['tierEntitlements'];
    if (table is Map && table[tier] is Map) {
      return Map<String, dynamic>.from(table[tier] as Map);
    }
    return const {};
  }

  List<String> get libraryActiveClassIds {
    final list = config['libraryActiveClassIds'];
    if (list is List) {
      return list.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static Map<String, dynamic> _deepMerge(
    Map<String, dynamic> base,
    Map<String, dynamic> overlay,
  ) {
    final out = Map<String, dynamic>.from(base);
    overlay.forEach((key, value) {
      if (value is Map && out[key] is Map) {
        out[key] = _deepMerge(
          Map<String, dynamic>.from(out[key] as Map),
          Map<String, dynamic>.from(value),
        );
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  static const _fallback = <String, dynamic>{
    'version': 0,
    'featureFlags': <String, dynamic>{},
    'mealPhotoCapFree': 30,
    'nutritionistDailyCap': 10,
    'nutritionistMonthlyCap': 100,
    'pdfGate': 'plus',
    'monthlyReportGate': 'plus',
    'doctorPdfGate': 'plus',
    'aiCostAlertThreshold': 50,
    'tierEntitlements': <String, dynamic>{},
    'libraryActiveClassIds': <String>[],
  };
}
