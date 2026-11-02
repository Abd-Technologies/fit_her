
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helper/analytics_helper.dart';
import '../analytics/analytics_events.dart';

/// 2M10 — private progress photo timeline.
class ProgressPhotoService extends GetxService {
  static const _key = 'd23_progress_photos_v1';

  final SharedPreferences prefs;

  ProgressPhotoService({required this.prefs});

  final RxList<Map<String, String>> photos = <Map<String, String>>[].obs;

  @override
  void onInit() {
    super.onInit();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        photos.assignAll(
          (jsonDecode(raw) as List)
              .whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v.toString()))),
        );
      } catch (_) {}
    }
  }

  Future<void> add({required String path, required String label}) async {
    photos.insert(0, {
      'path': path,
      'label': label,
      'at': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_key, jsonEncode(photos));
    await AnalyticsHelper.track(AnalyticsEvents.progressPhotoAdded);
  }
}
