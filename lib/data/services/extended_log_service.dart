import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/daily_log/medication_log.dart';
import '../models/daily_log/period_flow_log.dart';
import '../models/daily_log/skin_hair_log.dart';

/// 2NH7–2NH9 local stores (meds, period flow, skin/hair).
class ExtendedLogService extends GetxService {
  static const _medsKey = 'd23_medications_v1';
  static const _flowKey = 'd23_period_flow_v1';
  static const _skinKey = 'd23_skin_hair_v1';

  final SharedPreferences prefs;
  final _uuid = const Uuid();

  ExtendedLogService({required this.prefs});

  final RxList<MedicationEntry> medications = <MedicationEntry>[].obs;
  final RxList<PeriodFlowLog> flowLogs = <PeriodFlowLog>[].obs;
  final RxList<SkinHairLog> skinHairLogs = <SkinHairLog>[].obs;

  @override
  void onInit() {
    super.onInit();
    medications.assignAll(_loadList(_medsKey, MedicationEntry.fromJson));
    flowLogs.assignAll(_loadList(_flowKey, PeriodFlowLog.fromJson));
    skinHairLogs.assignAll(_loadList(_skinKey, SkinHairLog.fromJson));
  }

  List<T> _loadList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    await prefs.setString(
      key,
      jsonEncode(items.map(toJson).toList()),
    );
  }

  Future<MedicationEntry> upsertMedication(MedicationEntry entry) async {
    final next = entry.id.isEmpty
        ? MedicationEntry(
            id: _uuid.v4(),
            name: entry.name,
            doseText: entry.doseText,
            times: entry.times,
            remind: entry.remind,
            takenByDate: entry.takenByDate,
            updatedAt: DateTime.now(),
          )
        : entry.copyWith(updatedAt: DateTime.now());
    final idx = medications.indexWhere((e) => e.id == next.id);
    if (idx >= 0) {
      medications[idx] = next;
    } else {
      medications.add(next);
    }
    await _persist(_medsKey, medications, (e) => e.toJson());
    return next;
  }

  Future<void> deleteMedication(String id) async {
    medications.removeWhere((e) => e.id == id);
    await _persist(_medsKey, medications, (e) => e.toJson());
  }

  Future<void> markTaken(String id, String date, bool taken) async {
    final idx = medications.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final map = Map<String, bool>.from(medications[idx].takenByDate);
    map[date] = taken;
    medications[idx] = medications[idx].copyWith(
      takenByDate: map,
      updatedAt: DateTime.now(),
    );
    await _persist(_medsKey, medications, (e) => e.toJson());
  }

  Future<PeriodFlowLog> upsertFlow(PeriodFlowLog entry) async {
    final next = PeriodFlowLog(
      id: entry.id.isEmpty ? _uuid.v4() : entry.id,
      date: entry.date,
      flow: entry.flow,
      clots: entry.clots,
      pain: entry.pain,
      cyclePhase: entry.cyclePhase,
      updatedAt: DateTime.now(),
    );
    final idx = flowLogs.indexWhere((e) => e.date == next.date);
    if (idx >= 0) {
      flowLogs[idx] = next;
    } else {
      flowLogs.add(next);
    }
    flowLogs.sort((a, b) => b.date.compareTo(a.date));
    await _persist(_flowKey, flowLogs, (e) => e.toJson());
    return next;
  }

  List<PeriodRecord> buildPeriodRecords() {
    final sorted = [...flowLogs]..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.isEmpty) return [];
    final records = <PeriodRecord>[];
    var bucket = <PeriodFlowLog>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      final prev = DateTime.tryParse(sorted[i - 1].date);
      final cur = DateTime.tryParse(sorted[i].date);
      if (prev != null &&
          cur != null &&
          cur.difference(prev).inDays <= 1) {
        bucket.add(sorted[i]);
      } else {
        records.add(_toRecord(bucket));
        bucket = [sorted[i]];
      }
    }
    records.add(_toRecord(bucket));
    return records.reversed.toList();
  }

  PeriodRecord _toRecord(List<PeriodFlowLog> days) {
    final heavinessScore = days.map((d) {
      switch (d.flow) {
        case 'heavy':
          return 3;
        case 'medium':
          return 2;
        case 'light':
          return 1;
        default:
          return 0;
      }
    }).fold<int>(0, (a, b) => a > b ? a : b);
    final heaviness = heavinessScore >= 3
        ? 'heavy'
        : heavinessScore >= 2
            ? 'medium'
            : 'light';
    return PeriodRecord(
      startDate: days.first.date,
      endDate: days.last.date,
      lengthDays: days.length,
      heaviness: heaviness,
      days: days,
    );
  }

  Future<SkinHairLog> upsertSkinHair(SkinHairLog entry) async {
    final next = SkinHairLog(
      id: entry.id.isEmpty ? _uuid.v4() : entry.id,
      date: entry.date,
      severities: entry.severities,
      cyclePhase: entry.cyclePhase,
      updatedAt: DateTime.now(),
    );
    final idx = skinHairLogs.indexWhere((e) => e.date == next.date);
    if (idx >= 0) {
      skinHairLogs[idx] = next;
    } else {
      skinHairLogs.add(next);
    }
    await _persist(_skinKey, skinHairLogs, (e) => e.toJson());
    return next;
  }

  SkinHairLog? skinForDate(String date) {
    try {
      return skinHairLogs.firstWhere((e) => e.date == date);
    } catch (_) {
      return null;
    }
  }

  PeriodFlowLog? flowForDate(String date) {
    try {
      return flowLogs.firstWhere((e) => e.date == date);
    } catch (_) {
      return null;
    }
  }
}
