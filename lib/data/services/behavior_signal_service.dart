import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helper/analytics_helper.dart';
import '../analytics/analytics_events.dart';

/// 1NH11 — behavior signal capture (no user-facing screen).
class BehaviorSignalService extends GetxService {
  static const _prefsKey = 'd1_behavior_signals_v1';

  final SharedPreferences prefs;

  BehaviorSignalService({required this.prefs});

  final Map<String, int> _featureOpens = {};
  final Map<String, int> _insightTypeOpens = {};
  final List<int> _logHours = [];

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final fo = map['featureOpens'];
      if (fo is Map) {
        fo.forEach((k, v) {
          if (v is num) _featureOpens[k.toString()] = v.toInt();
        });
      }
      final io = map['insightTypeOpens'];
      if (io is Map) {
        io.forEach((k, v) {
          if (v is num) _insightTypeOpens[k.toString()] = v.toInt();
        });
      }
      final hours = map['logHours'];
      if (hours is List) {
        _logHours.addAll(hours.whereType<num>().map((e) => e.toInt()));
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'featureOpens': _featureOpens,
        'insightTypeOpens': _insightTypeOpens,
        'logHours': _logHours.take(200).toList(),
      }),
    );
  }

  Future<void> recordFeatureOpen(String feature) async {
    _featureOpens[feature] = (_featureOpens[feature] ?? 0) + 1;
    await AnalyticsHelper.track(
      AnalyticsEvents.featureOpened,
      props: {'feature': feature},
    );
    await _persist();
  }

  Future<void> recordInsightType(String type) async {
    _insightTypeOpens[type] = (_insightTypeOpens[type] ?? 0) + 1;
    await _persist();
  }

  Future<void> recordLogMoment() async {
    _logHours.add(DateTime.now().hour);
    await _persist();
  }

  Future<void> recordSkip(String what) async {
    await AnalyticsHelper.track(
      AnalyticsEvents.logSkipped,
      props: {'what': what},
    );
  }

  Future<void> recordSuggestionTap(String id) async {
    await AnalyticsHelper.track(
      AnalyticsEvents.suggestionTapped,
      props: {'id': id},
    );
  }

  /// Named consumer 1: insight type she opens most.
  String? preferredInsightType() {
    if (_insightTypeOpens.isEmpty) return null;
    final sorted = _insightTypeOpens.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  /// Named consumer 2: best hour for a push (mode of log hours).
  int? preferredReminderHour() {
    if (_logHours.isEmpty) return null;
    final counts = <int, int>{};
    for (final h in _logHours) {
      counts[h] = (counts[h] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
}
