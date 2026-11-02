import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../values/constants.dart';
import '../../models/daily_log/quick_checkin.dart';
import '../../models/daily_log/symptom_log.dart';
import '../../services/offline_sync_queue.dart';
import '../checkin_repo/checkin_repository.dart';

/// Local-first daily log store (symptoms + quick check-in) with API sync.
class DailyLogRepository extends GetxService {
  static const _symptomsKey = 'd1_symptom_logs_v1';
  static const _checkinsKey = 'd1_quick_checkins_v1';
  static const _waterGoalKey = 'd1_water_goal_ml';

  final SharedPreferences prefs;
  final CheckinRepository checkinRepo;
  final OfflineSyncQueue syncQueue;

  DailyLogRepository({
    required this.prefs,
    required this.checkinRepo,
    required this.syncQueue,
  });

  final _uuid = const Uuid();

  // ── Symptoms ──────────────────────────────────────────────────────────

  List<SymptomLog> loadSymptoms() {
    final raw = prefs.getString(_symptomsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => SymptomLog.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveSymptoms(List<SymptomLog> items) async {
    await prefs.setString(
      _symptomsKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  SymptomLog? symptomForDate(String date) {
    try {
      return loadSymptoms().firstWhere((e) => e.date == date);
    } catch (_) {
      return null;
    }
  }

  Future<SymptomLog> upsertSymptom(SymptomLog entry) async {
    final items = loadSymptoms();
    final idx = items.indexWhere((e) => e.date == entry.date);
    final next = entry.copyWith(updatedAt: DateTime.now(), synced: false);
    if (idx >= 0) {
      if (!items[idx].isEditable && items[idx].id != entry.id) {
        throw StateError('Symptom entry older than 48h cannot be edited');
      }
      items[idx] = next.copyWith();
      // preserve id
      items[idx] = SymptomLog(
        id: items[idx].id.isEmpty ? entry.id : items[idx].id,
        date: next.date,
        cyclePhase: next.cyclePhase,
        severities: next.severities,
        painBodyArea: next.painBodyArea,
        updatedAt: next.updatedAt,
        synced: false,
      );
    } else {
      items.add(SymptomLog(
        id: entry.id.isEmpty ? _uuid.v4() : entry.id,
        date: next.date,
        cyclePhase: next.cyclePhase,
        severities: next.severities,
        painBodyArea: next.painBodyArea,
        updatedAt: next.updatedAt,
        synced: false,
      ));
    }
    await _saveSymptoms(items);
    final saved = symptomForDate(entry.date)!;
    await _trySyncSymptom(saved);
    return symptomForDate(entry.date)!;
  }

  Future<void> _trySyncSymptom(SymptomLog log) async {
    final online = await _isOnline();
    final body = log.toJson()..remove('synced');
    if (!online) {
      await syncQueue.enqueue(type: 'symptom', body: body);
      return;
    }
    // Backend contract deferred — mark local synced after queue enqueue to API stub.
    await syncQueue.enqueue(type: 'symptom', body: body);
    final items = loadSymptoms();
    final i = items.indexWhere((e) => e.id == log.id);
    if (i >= 0) {
      items[i] = items[i].copyWith(synced: true);
      await _saveSymptoms(items);
    }
  }

  /// Average severity per symptom key over [days] for Progress UI.
  Map<String, double> symptomAverages({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffStr =
        '${cutoff.year.toString().padLeft(4, '0')}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
    final counts = <String, int>{};
    final sums = <String, int>{};
    for (final log in loadSymptoms()) {
      if (log.date.compareTo(cutoffStr) < 0) continue;
      log.severities.forEach((k, v) {
        sums[k] = (sums[k] ?? 0) + v;
        counts[k] = (counts[k] ?? 0) + 1;
      });
    }
    final out = <String, double>{};
    for (final k in SymptomLog.symptomKeys) {
      final c = counts[k] ?? 0;
      if (c == 0) continue;
      out[k] = (sums[k]! / c) / 3.0; // normalize 0–1
    }
    return out;
  }

  // ── Quick check-in ────────────────────────────────────────────────────

  List<QuickCheckin> loadCheckins() {
    final raw = prefs.getString(_checkinsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => QuickCheckin.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCheckins(List<QuickCheckin> items) async {
    await prefs.setString(
      _checkinsKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  QuickCheckin? checkinForDate(String date) {
    try {
      return loadCheckins().firstWhere((e) => e.date == date);
    } catch (_) {
      return null;
    }
  }

  Future<QuickCheckin> saveQuickCheckin(QuickCheckin checkin) async {
    final items = loadCheckins();
    final idx = items.indexWhere((e) => e.date == checkin.date);
    final next = QuickCheckin(
      date: checkin.date,
      mood: checkin.mood,
      energy: checkin.energy,
      stress: checkin.stress,
      stressCause: checkin.stressCause,
      sleepHours: checkin.sleepHours,
      sleepRested: checkin.sleepRested,
      cyclePhase: checkin.cyclePhase,
      updatedAt: DateTime.now(),
      synced: false,
    );
    if (idx >= 0) {
      items[idx] = next;
    } else {
      items.add(next);
    }
    await _saveCheckins(items);

    final online = await _isOnline();
    final token = prefs.getString(Constants.accessToken) ?? '';
    if (online && token.isNotEmpty) {
      try {
        final response = await checkinRepo.saveDailyCheckin(
          accessToken: token,
          body: next.toApiBody(),
        );
        final body = response.body;
        final ok = body is Map && body['status'] == '1';
        if (ok) {
          final updated = loadCheckins();
          final i = updated.indexWhere((e) => e.date == next.date);
          if (i >= 0) {
            updated[i] = QuickCheckin(
              date: next.date,
              mood: next.mood,
              energy: next.energy,
              stress: next.stress,
              stressCause: next.stressCause,
              sleepHours: next.sleepHours,
              sleepRested: next.sleepRested,
              cyclePhase: next.cyclePhase,
              updatedAt: next.updatedAt,
              synced: true,
            );
            await _saveCheckins(updated);
          }
          return checkinForDate(next.date)!;
        }
      } catch (e) {
        debugPrint('[DailyLogRepository] checkin API failed: $e');
      }
    }
    await syncQueue.enqueue(type: 'quick_checkin', body: next.toApiBody());
    return checkinForDate(next.date)!;
  }

  // ── Water goal ────────────────────────────────────────────────────────

  int get waterGoalMl => prefs.getInt(_waterGoalKey) ?? 2000;

  Future<void> setWaterGoalMl(int ml) async {
    await prefs.setInt(_waterGoalKey, ml.clamp(500, 6000));
  }

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((e) => e != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  Future<int> flushQueue() async {
    final token = prefs.getString(Constants.accessToken) ?? '';
    return syncQueue.flush((type, body) async {
      if (type == 'quick_checkin' && token.isNotEmpty) {
        final response = await checkinRepo.saveDailyCheckin(
          accessToken: token,
          body: body,
        );
        final resBody = response.body;
        return resBody is Map && resBody['status'] == '1';
      }
      // symptom / meal stubs succeed locally until backend exists
      return true;
    });
  }
}
