
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 3P3 — Health Connect / HealthKit stub (mock pull).
class HealthSyncStubService extends GetxService {
  static const _key = 'd23_health_sync_v1';

  final SharedPreferences prefs;

  HealthSyncStubService({required this.prefs});

  final RxBool permissionGranted = false.obs;
  final RxInt steps = 0.obs;
  final RxDouble sleepHours = 0.0.obs;
  final RxInt heartRate = 0.obs;

  @override
  void onInit() {
    super.onInit();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        permissionGranted.value = m['perm'] == true;
        steps.value = (m['steps'] as num?)?.toInt() ?? 0;
        sleepHours.value = (m['sleep'] as num?)?.toDouble() ?? 0;
        heartRate.value = (m['hr'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }
  }

  Future<void> requestPermission() async {
    permissionGranted.value = true;
    await _persist();
  }

  Future<void> mockPull() async {
    if (!permissionGranted.value) return;
    steps.value = 6420;
    sleepHours.value = 7.2;
    heartRate.value = 72;
    await _persist();
  }

  Future<void> _persist() async {
    await prefs.setString(
      _key,
      jsonEncode({
        'perm': permissionGranted.value,
        'steps': steps.value,
        'sleep': sleepHours.value,
        'hr': heartRate.value,
      }),
    );
  }
}
