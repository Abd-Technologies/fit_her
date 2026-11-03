import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../data/api_provider/api_provider.dart';
import '../data/controllers/auth_controller/auth_controller.dart';
import '../values/constants.dart';

/// Consultation "she left the call" time (Nov 2026).
///
/// Without Google Meet we can't see the call, so: when she taps Join and
/// Meet opens, we remember it. When she comes back to Fit Her (the call is
/// over, or she closed Meet), the app tells the server that time:
/// POST /appointment/:id/app-return. The latest return counts (she may
/// drop out and rejoin). Saved on the phone, so it still works if the app
/// was closed and she reopens it later. Forgotten after 3 hours.
class ConsultPresence with WidgetsBindingObserver {
  ConsultPresence._();
  static final ConsultPresence instance = ConsultPresence._();

  static const _key = 'consultInCall'; // "<appointmentId>|<opened at, UTC ISO>"
  static const _forgetAfter = Duration(hours: 3);
  bool _started = false;

  /// Call once the user is known (idempotent). Also checks a call left
  /// open from before the app was closed.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _reportReturn();
  }

  /// She tapped Join and Meet is opening.
  void openedMeet(int appointmentId) {
    start();
    try {
      Get.find<AuthController>().sharedPreferences.setString(
          _key, '$appointmentId|${DateTime.now().toUtc().toIso8601String()}');
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reportReturn();
  }

  Future<void> _reportReturn() async {
    try {
      final auth = Get.find<AuthController>();
      final prefs = auth.sharedPreferences;
      final raw = prefs.getString(_key);
      if (raw == null || !raw.contains('|')) return;
      final parts = raw.split('|');
      final id = int.tryParse(parts[0]);
      final opened = DateTime.tryParse(parts[1]);
      final now = DateTime.now().toUtc();
      if (id == null || opened == null || now.difference(opened) > _forgetAfter) {
        await prefs.remove(_key);
        return;
      }
      // Back within a minute: Meet didn't really start, keep waiting.
      if (now.difference(opened) < const Duration(minutes: 1)) return;
      final token = prefs.getString(Constants.accessToken) ?? '';
      if (token.isEmpty) return;
      await Get.find<ApiProvider>().postData(
        '/appointment/$id/app-return',
        body: {'at': now.toIso8601String()},
        headers: {'accessToken': token},
      );
      // Kept (not removed): if she goes back into the call and returns
      // again, the later time is the real "left" time.
    } catch (_) {}
  }
}
