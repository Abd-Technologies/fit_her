
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helper/analytics_helper.dart';
import '../analytics/analytics_events.dart';

/// 3P1 — privacy lock + discreet notifications (local PIN).
class PrivacyLockService extends GetxService {
  static const _pinKey = 'd23_privacy_pin_v1';
  static const _enabledKey = 'd23_privacy_enabled_v1';
  static const _discreetKey = 'd23_discreet_notifs_v1';
  static const _unlockedKey = 'd23_privacy_unlocked_session';

  final SharedPreferences prefs;

  PrivacyLockService({required this.prefs});

  final RxBool enabled = false.obs;
  final RxBool discreetNotifications = false.obs;
  final RxBool unlockedThisSession = false.obs;

  @override
  void onInit() {
    super.onInit();
    enabled.value = prefs.getBool(_enabledKey) ?? false;
    discreetNotifications.value = prefs.getBool(_discreetKey) ?? false;
    unlockedThisSession.value = prefs.getBool(_unlockedKey) ?? false;
  }

  Future<void> setEnabled(bool v, {String? pin}) async {
    enabled.value = v;
    await prefs.setBool(_enabledKey, v);
    if (pin != null && pin.isNotEmpty) {
      await prefs.setString(_pinKey, pin);
    }
    if (v) {
      unlockedThisSession.value = false;
      await prefs.setBool(_unlockedKey, false);
      await AnalyticsHelper.track(AnalyticsEvents.privacyLockEnabled);
    }
  }

  Future<void> setDiscreet(bool v) async {
    discreetNotifications.value = v;
    await prefs.setBool(_discreetKey, v);
  }

  bool unlock(String pin) {
    final stored = prefs.getString(_pinKey) ?? '';
    final ok = stored.isNotEmpty && stored == pin;
    if (ok) {
      unlockedThisSession.value = true;
      prefs.setBool(_unlockedKey, true);
    }
    return ok;
  }

  String notificationTitle(String realTitle) {
    if (!discreetNotifications.value) return realTitle;
    return 'Fit Her';
  }

  String notificationBody(String realBody) {
    if (!discreetNotifications.value) return realBody;
    return 'You have an update';
  }
}
