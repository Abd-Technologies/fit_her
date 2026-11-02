
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_config_service.dart';

/// 2P4 — local AI cost counters per feature.
class AiCostMonitorService extends GetxService {
  static const _key = 'd23_ai_cost_v1';

  final SharedPreferences prefs;

  AiCostMonitorService({required this.prefs});

  final RxMap<String, int> counts = <String, int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        counts.assignAll(map.map((k, v) => MapEntry(k, (v as num).toInt())));
      } catch (_) {}
    }
  }

  Future<void> record(String feature, {int units = 1}) async {
    counts[feature] = (counts[feature] ?? 0) + units;
    await prefs.setString(_key, jsonEncode(counts));
  }

  int get total => counts.values.fold(0, (a, b) => a + b);

  bool get overThreshold {
    final t = Get.isRegistered<RemoteConfigService>()
        ? Get.find<RemoteConfigService>().aiCostAlertThreshold
        : 50;
    return total >= t;
  }
}
