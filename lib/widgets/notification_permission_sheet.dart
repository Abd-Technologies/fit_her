import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helper/notification_services.dart';
import '../helper/popup_manager.dart';
import 'v2/v2_bottom_sheet.dart';
import 'v2/v2_buttons.dart';

/// "Turn on notifications" (Oct 2026). Our own sheet first, then the
/// phone's permission box only if she taps "Turn on".
///
/// Rules:
///  - Shown on the main tabs, only while notifications are off
///    (not asked yet, or turned off).
///  - "Not now" → ask again after 1 day.
///  - "Turn on" → the phone's box if it was never asked; if she turned
///    them off before, the app's settings page (the phone won't show
///    the box again).
///  - Once allowed, never shown again.
class NotificationPermissionSheet extends StatelessWidget {
  const NotificationPermissionSheet({super.key});

  static const String _nextKey = 'notif_ask_next_at';
  static const Duration _gap = Duration(days: 1);
  static bool _openThisRun = false;

  static bool _allowed(AuthorizationStatus s) =>
      s == AuthorizationStatus.authorized ||
      s == AuthorizationStatus.provisional;

  /// Call once the main tabs are on screen.
  static Future<void> maybeAsk() async {
    if (_openThisRun) return;
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (_allowed(settings.authorizationStatus)) return;
      final prefs = await SharedPreferences.getInstance();
      // Just signed up: her welcome sheet goes first; this asks on the
      // next app open instead of right after it.
      if ((prefs.getString('trial_welcome_pending') ?? '').isNotEmpty) return;
      final nextRaw = prefs.getInt(_nextKey);
      final next = nextRaw ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < next) return;
      Future<void> show() async {
        _openThisRun = true;
        await V2BottomSheet.show(
          title: 'Turn on notifications',
          child: const NotificationPermissionSheet(),
        );
      }
      // Oct 2026: first open on this phone (new install / first login) and
      // never asked: a setup step, asked right away, and it doesn't take
      // the turn from this open's planned pop-up. After a "Not now" it's
      // back to the normal order below.
      if (nextRaw == null &&
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        await PopupManager.runSetup('notifications_setup', show);
        return;
      }
      // Pop-up manager: first in the planned order, still one at a time.
      await PopupManager.run(
        'notifications',
        rank: PopupRank.notifications,
        show: () async {
          _openThisRun = true;
          await V2BottomSheet.show(
            title: 'Turn on notifications',
            child: const NotificationPermissionSheet(),
          );
        },
      );
    } catch (_) {}
  }

  static Future<void> _later() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _nextKey, DateTime.now().add(_gap).millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _turnOn() async {
    Get.back<dynamic>();
    final before =
        (await FirebaseMessaging.instance.getNotificationSettings())
            .authorizationStatus;
    if (before == AuthorizationStatus.notDetermined) {
      // The phone's own box; also saves her device token when allowed.
      NotificationServices().requestNotificationPermission();
    } else {
      await openAppSettings();
    }
    // If she still says no, come back after the same 1-day gap.
    await _later();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Get your class reminders, plan updates and messages from your dietitian and trainer.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Color(0xFF7A8C78),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        V2PrimaryButton(label: 'Turn on', onPressed: _turnOn),
        const SizedBox(height: 8),
        V2GhostButton(
          label: 'Not now',
          onPressed: () {
            _later();
            Get.back<dynamic>();
          },
        ),
      ],
    );
  }
}
