
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 3P6 — points for streaks (local ledger).
class PointsService extends GetxService {
  static const _key = 'd23_points_v1';

  final SharedPreferences prefs;

  PointsService({required this.prefs});

  final RxInt balance = 0.obs;
  final RxList<String> history = <String>[].obs;

  static const redeemCatalog = [
    ('Free class credit stub', 100),
    ('Profile badge', 50),
  ];

  @override
  void onInit() {
    super.onInit();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        balance.value = (m['balance'] as num?)?.toInt() ?? 0;
        history.assignAll(
          ((m['history'] as List?) ?? []).map((e) => e.toString()),
        );
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    await prefs.setString(
      _key,
      jsonEncode({'balance': balance.value, 'history': history}),
    );
  }

  Future<void> award(String reason, int points) async {
    balance.value += points;
    history.insert(0, '+$points · $reason');
    await _persist();
  }

  Future<bool> redeem(String item, int cost) async {
    if (balance.value < cost) return false;
    balance.value -= cost;
    history.insert(0, '-$cost · redeemed $item');
    await _persist();
    return true;
  }
}
