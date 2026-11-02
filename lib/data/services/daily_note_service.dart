
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 3NH3 — private daily notes.
class DailyNoteService extends GetxService {
  static const _key = 'd23_daily_notes_v1';

  final SharedPreferences prefs;

  DailyNoteService({required this.prefs});

  final RxMap<String, String> notes = <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        notes.assignAll(m.map((k, v) => MapEntry(k, v.toString())));
      } catch (_) {}
    }
  }

  Future<void> save(String date, String text) async {
    notes[date] = text;
    await prefs.setString(_key, jsonEncode(notes));
  }

  String? forDate(String date) => notes[date];
}
