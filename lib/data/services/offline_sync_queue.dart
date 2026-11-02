import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local write-ahead queue for daily log payloads when offline.
/// Persists to SharedPreferences; [flush] replays FIFO when online.
class OfflineSyncQueue extends GetxService {
  static const _prefsKey = 'd1_offline_sync_queue_v1';

  final SharedPreferences prefs;

  OfflineSyncQueue({required this.prefs});

  List<Map<String, dynamic>> _items = [];

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _items = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _items = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[OfflineSyncQueue] load failed: $e');
      _items = [];
    }
  }

  Future<void> _persist() async {
    await prefs.setString(_prefsKey, jsonEncode(_items));
  }

  Future<void> enqueue({
    required String type,
    required Map<String, dynamic> body,
  }) async {
    _items.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'body': body,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _persist();
  }

  List<Map<String, dynamic>> peekAll() => List.unmodifiable(_items);

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    await _persist();
  }

  Future<void> clear() async {
    _items = [];
    await _persist();
  }

  /// [handler] returns true when the item synced successfully.
  Future<int> flush(
    Future<bool> Function(String type, Map<String, dynamic> body) handler,
  ) async {
    var synced = 0;
    var i = 0;
    while (i < _items.length) {
      final item = _items[i];
      final type = item['type'] as String? ?? '';
      final body = Map<String, dynamic>.from(item['body'] as Map? ?? {});
      try {
        final ok = await handler(type, body);
        if (ok) {
          _items.removeAt(i);
          synced++;
          await _persist();
          continue;
        }
      } catch (e) {
        debugPrint('[OfflineSyncQueue] flush item failed: $e');
      }
      i++;
    }
    return synced;
  }
}
