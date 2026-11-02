
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 3NH2 — Ramadan mode (local rules).
class RamadanModeService extends GetxService {
  static const _key = 'd23_ramadan_v1';

  final SharedPreferences prefs;

  RamadanModeService({required this.prefs});

  final RxBool enabled = false.obs;
  final RxnString startDate = RxnString();
  final RxnString endDate = RxnString();
  final RxMap<String, String> fastMarks = <String, String>{}.obs; // date -> fasted|missed

  @override
  void onInit() {
    super.onInit();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        enabled.value = m['enabled'] == true;
        startDate.value = m['start']?.toString();
        endDate.value = m['end']?.toString();
        final marks = m['marks'];
        if (marks is Map) {
          fastMarks.assignAll(
            marks.map((k, v) => MapEntry(k.toString(), v.toString())),
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    await prefs.setString(
      _key,
      jsonEncode({
        'enabled': enabled.value,
        'start': startDate.value,
        'end': endDate.value,
        'marks': fastMarks,
      }),
    );
  }

  Future<void> setEnabled(bool v, {String? start, String? end}) async {
    enabled.value = v;
    if (start != null) startDate.value = start;
    if (end != null) endDate.value = end;
    await _persist();
  }

  Future<void> markDay(String date, String status) async {
    fastMarks[date] = status;
    await _persist();
  }

  bool get preferGentleWorkouts => enabled.value;
}
