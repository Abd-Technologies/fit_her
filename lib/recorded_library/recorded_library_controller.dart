
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/services/tier_access_service.dart';
import '../helper/analytics_helper.dart';
import '../data/analytics/analytics_events.dart';
import 'models/recorded_class.dart';

/// 3M1–3M8 recorded library (local catalog + progress).
class RecordedLibraryController extends GetxController {
  static const catalogAsset = 'assets/recorded_library/catalog_v1.json';
  static const _progressKey = 'd23_library_progress_v1';
  static const _favKey = 'd23_library_favs_v1';
  static const _downloadsKey = 'd23_library_downloads_v1';
  static const _qualityKey = 'd23_library_quality_v1';
  static const _programKey = 'd23_library_program_progress_v1';

  final SharedPreferences prefs;

  RecordedLibraryController({required this.prefs});

  final RxList<RecordedClass> catalog = <RecordedClass>[].obs;
  final RxList<LibraryProgram> programs = <LibraryProgram>[].obs;
  final RxString styleFilter = ''.obs;
  final RxString levelFilter = ''.obs;
  final RxBool microOnly = false.obs;
  final RxBool lowData = false.obs;
  final RxSet<String> favourites = <String>{}.obs;
  final RxMap<String, double> progress = <String, double>{}.obs;
  final RxSet<String> downloaded = <String>{}.obs;
  final RxnString activeProgramId = RxnString();
  final RxInt programWeek = 0.obs;

  @override
  void onInit() {
    super.onInit();
    lowData.value = prefs.getBool(_qualityKey) ?? false;
    favourites.addAll(prefs.getStringList(_favKey) ?? []);
    downloaded.addAll(prefs.getStringList(_downloadsKey) ?? []);
    final progRaw = prefs.getString(_progressKey);
    if (progRaw != null) {
      try {
        final map = jsonDecode(progRaw) as Map<String, dynamic>;
        progress.assignAll(
          map.map((k, v) => MapEntry(k, (v as num).toDouble())),
        );
      } catch (_) {}
    }
    final pRaw = prefs.getString(_programKey);
    if (pRaw != null) {
      try {
        final m = jsonDecode(pRaw) as Map<String, dynamic>;
        activeProgramId.value = m['id']?.toString();
        programWeek.value = (m['week'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }
    loadCatalog();
  }

  Future<void> loadCatalog() async {
    try {
      final raw = await rootBundle.loadString(catalogAsset);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      catalog.assignAll(
        ((decoded['classes'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => RecordedClass.fromJson(Map<String, dynamic>.from(e))),
      );
      programs.assignAll(
        ((decoded['programs'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => LibraryProgram.fromJson(Map<String, dynamic>.from(e))),
      );
    } catch (_) {
      catalog.clear();
    }
  }

  List<RecordedClass> get visible {
    var list = catalog.toList();
    if (styleFilter.value.isNotEmpty) {
      list = list
          .where((c) => c.trainerStyle == styleFilter.value)
          .toList();
    }
    if (levelFilter.value.isNotEmpty) {
      list = list.where((c) => c.level == levelFilter.value).toList();
    }
    if (microOnly.value) {
      list = list.where((c) => c.micro).toList();
    }
    return list;
  }

  bool canPlay(RecordedClass c) {
    if (!Get.isRegistered<TierAccessService>()) return true;
    final tier = Get.find<TierAccessService>();
    if (tier.libraryAccess == 'none') return false;
    if (c.unlimitedOnly && !tier.isUnlimited) return false;
    return tier.canOpenLibraryClass(c.id) ||
        tier.libraryAccess == 'full' ||
        !c.unlimitedOnly;
  }

  Future<void> toggleFavourite(String id) async {
    if (favourites.contains(id)) {
      favourites.remove(id);
    } else {
      favourites.add(id);
    }
    await prefs.setStringList(_favKey, favourites.toList());
  }

  Future<void> saveProgress(String id, double position) async {
    progress[id] = position;
    await prefs.setString(_progressKey, jsonEncode(progress));
  }

  Future<void> markComplete(String id) async {
    progress[id] = 1.0;
    await prefs.setString(_progressKey, jsonEncode(progress));
    await AnalyticsHelper.track(AnalyticsEvents.libraryClassCompleted,
        props: {'id': id});
  }

  Future<void> toggleDownload(String id) async {
    if (downloaded.contains(id)) {
      downloaded.remove(id);
    } else {
      downloaded.add(id);
    }
    await prefs.setStringList(_downloadsKey, downloaded.toList());
  }

  Future<void> setLowData(bool v) async {
    lowData.value = v;
    await prefs.setBool(_qualityKey, v);
  }

  Future<void> startProgram(String id) async {
    activeProgramId.value = id;
    programWeek.value = 1;
    await prefs.setString(
      _programKey,
      jsonEncode({'id': id, 'week': 1}),
    );
  }

  Future<void> advanceProgramWeek() async {
    if (activeProgramId.value == null) return;
    programWeek.value = (programWeek.value + 1).clamp(1, 4);
    await prefs.setString(
      _programKey,
      jsonEncode({'id': activeProgramId.value, 'week': programWeek.value}),
    );
  }

  /// 3M5 stub — staff imports a replay id into local catalog memory.
  Future<void> importReplayStub({
    required String title,
    required String trainerStyle,
  }) async {
    catalog.add(RecordedClass(
      id: 'replay_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      trainer: 'Replay',
      trainerStyle: trainerStyle,
      durationMin: 30,
      level: 'intermediate',
      focus: 'replay',
      phase: 'any',
      equipment: const ['none'],
      streamUrl: 'https://example.com/vod/replay_stub.mp4',
      tags: const ['replay'],
    ));
  }
}
