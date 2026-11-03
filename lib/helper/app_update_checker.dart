import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/api_provider/api_provider.dart';
import '../data/controllers/auth_controller/auth_controller.dart';
import '../values/constants.dart';
import 'popup_manager.dart';

/// App update popup — full flow in "fitHer Flows" › App update.
///
/// On every cold start the app asks the server (GET /users/app-version)
/// for this platform's rule and compares it with its own version:
///
///   • older than **minimum** → MUST update, no "Later".
///       Android: Google Play's in-app "Immediate" update (full-screen,
///                downloads inside the app, restarts on the new version).
///       iPhone / not from Play: blocking screen → App Store / Play page.
///   • older than **latest** → soft popup with "Later", at most once a day.
///       She can tap Later 2 times (each Later = not asked again for a
///       day). The 3rd time there is no Later: it becomes a must-update.
///       Counted per latest version, so a new release starts again at 2.
///       Android: Google Play's in-app "Flexible" update (downloads in the
///                background, "Restart" bar when ready); "No thanks" there
///                counts as a Later.
///       iPhone / not from Play: "Update / Later" popup → store page.
///   • otherwise nothing.
///
/// Any failure (no internet, server down, Play unavailable) = do nothing
/// unless the version is below minimum, so the app is never blocked by
/// a broken check.
class AppUpdateChecker {
  AppUpdateChecker._();

  static bool _running = false;
  static const _softKey = 'app_update_soft_shown_day';
  static const maxLater = 2;
  static String _laterKey(String latest) => 'app_update_later_count_$latest';

  /// [fromPush]: she tapped the "update" notification — show the popup
  /// even if it was already shown today (the Later count still applies).
  static Future<void> check({bool fromPush = false}) async {
    if (_running) return;
    _running = true;
    try {
      // Tell the server which version she's on (for the "please update"
      // push). Fire-and-forget; works for every role.
      _reportVersion();
      // Never block the admin's own phone: she must always be able to
      // reach Admin › App Version to change or undo the rule.
      if (Get.isRegistered<AuthController>() &&
          Get.find<AuthController>().loginAsA.value == Constants.admin) {
        return;
      }
      final info = await PackageInfo.fromPlatform();
      final current = info.version; // "13.0.0"
      final rule = await _fetchRule();
      if (rule == null) return;
      final minimum = rule['minimumVersion'] as String?;
      final latest = rule['latestVersion'] as String?;
      final storeUrl = rule['storeUrl'] as String?;
      final message = rule['message'] as String?;

      if (minimum != null && compare(current, minimum) < 0) {
        final target = latest ?? minimum;
        // Required update: urgent, never waits for a turn.
        await PopupManager.run('update_required',
            rank: 0,
            urgent: true,
            show: () => _forceUpdate(storeUrl, message, current, target));
      } else if (latest != null && compare(current, latest) < 0) {
        await _softUpdate(storeUrl, message, latest, current, ignoreToday: fromPush);
      }
    } catch (e) {
      debugPrint('[AppUpdateChecker] $e');
    } finally {
      _running = false;
    }
  }

  /// -1 when a < b, 0 equal, 1 when a > b. "13.0" == "13.0.0".
  static int compare(String a, String b) {
    List<int> parts(String v) =>
        v.split('+').first.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final pa = parts(a), pb = parts(b);
    for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x < y ? -1 : 1;
    }
    return 0;
  }

  static Future<void> _reportVersion() async {
    try {
      final token = Get.find<AuthController>()
              .sharedPreferences
              .getString(Constants.accessToken) ??
          '';
      if (token.isEmpty) return;
      final info = await PackageInfo.fromPlatform();
      await Get.find<ApiProvider>().postData(
        Constants.appVersionReport,
        body: {'platform': Platform.isIOS ? 'ios' : 'android', 'version': info.version},
        headers: {'accessToken': token},
        timeout: const Duration(seconds: 8),
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> _fetchRule() async {
    try {
      final r = await Get.find<ApiProvider>()
          .getData(Constants.appVersion, timeout: const Duration(seconds: 8));
      if (r.body is! Map || r.body['status'] != '1') return null;
      final data = r.body['data'];
      final key = Platform.isIOS ? 'ios' : 'android';
      if (data is Map && data[key] is Map) return Map<String, dynamic>.from(data[key]);
    } catch (_) {}
    return null;
  }

  // ── Must update ─────────────────────────────────────────────────────
  static Future<void> _forceUpdate(
      String? storeUrl, String? message, String current, String target) async {
    if (Platform.isAndroid && await _playImmediate()) return;
    // iPhone, or Play's in-app update not possible: full "Time to update"
    // screen. No skip, back button does nothing.
    await Get.to<void>(
      () => _ForceUpdatePage(
        current: current,
        target: target,
        message: message,
        onUpdate: () => _openStore(storeUrl),
      ),
      fullscreenDialog: true,
      popGesture: false,
    );
  }

  /// Google Play "Immediate" update. True when Play handled it.
  static Future<bool> _playImmediate() async {
    try {
      final u = await InAppUpdate.checkForUpdate();
      if (u.updateAvailability == UpdateAvailability.updateAvailable && u.immediateUpdateAllowed) {
        final res = await InAppUpdate.performImmediateUpdate();
        return res == AppUpdateResult.success;
      }
    } catch (_) {
      // Not installed from Play (e.g. debug build) — fall back.
    }
    return false;
  }

  // ── Optional update: "Later" 2 times, then must update ──────────────
  static Future<void> _softUpdate(
      String? storeUrl, String? message, String latest, String current,
      {bool ignoreToday = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final laterUsed = prefs.getInt(_laterKey(latest)) ?? 0;

    // Used both Laters: no more Later.
    if (laterUsed >= maxLater) {
      await PopupManager.run('update_required',
          rank: 0,
          urgent: true,
          show: () => _forceUpdate(storeUrl, message, current, latest));
      return;
    }

    // Asked already today (or she tapped Later today): not again today.
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (!ignoreToday && prefs.getString(_softKey) == today) return;
    // Pop-up manager: opened by itself, so it waits for its turn
    // (lowest rank). Opened from the update push: show now.
    Future<void> show() async {
      await prefs.setString(_softKey, today);

      Future<void> tookLater() async =>
          prefs.setInt(_laterKey(latest), laterUsed + 1);

      if (Platform.isAndroid) {
        final r = await _playFlexible();
        if (r == _Flex.declined) await tookLater();
        if (r != _Flex.unavailable) return;
      }

      final lastSkip = maxLater - laterUsed <= 1;
      await Get.bottomSheet<void>(
        _UpdateSheet(
          version: latest,
          message: message,
          lastSkip: lastSkip,
          onUpdate: () {
            Get.back();
            _openStore(storeUrl);
          },
          onLater: () async {
            Get.back();
            await tookLater();
          },
        ),
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
      );
    }

    if (ignoreToday) {
      await show();
    } else {
      await PopupManager.run('update_optional',
          rank: PopupRank.optionalUpdate, show: show);
    }
  }

  /// Google Play "Flexible" update: downloads in the background, then a
  /// "Restart" bar finishes it.
  static Future<_Flex> _playFlexible() async {
    try {
      final u = await InAppUpdate.checkForUpdate();
      if (u.updateAvailability != UpdateAvailability.updateAvailable || !u.flexibleUpdateAllowed) {
        return _Flex.unavailable;
      }
      final res = await InAppUpdate.startFlexibleUpdate();
      if (res == AppUpdateResult.userDeniedUpdate) return _Flex.declined; // "No thanks" = Later
      if (res != AppUpdateResult.success) return _Flex.unavailable;
      Get.showSnackbar(GetSnackBar(
        message: 'Update downloaded. Restart Fit Her to finish.',
        duration: const Duration(seconds: 20),
        snackPosition: SnackPosition.BOTTOM,
        mainButton: TextButton(
          onPressed: () => InAppUpdate.completeFlexibleUpdate(),
          child: const Text('RESTART', style: TextStyle(color: Color(0xFF8AD167), fontWeight: FontWeight.w700)),
        ),
      ));
      return _Flex.started;
    } catch (_) {
      return _Flex.unavailable;
    }
  }

  static Future<void> _openStore(String? storeUrl) async {
    final url = storeUrl ??
        (Platform.isIOS
            ? 'https://apps.apple.com/search?term=Fit%20Her'
            : 'https://play.google.com/store/apps/details?id=com.abtechnologies.fitHer');
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

enum _Flex { started, declined, unavailable }

// ── Design (approved preview v4) ─────────────────────────────────────
// Fit Her wordmark, app button style (green #89CB68→#8AD167, white text,
// soft shadow), version tag in light green.
const _ink = Color(0xFF1E2A1F);
const _soft = Color(0xFF6B7468);
const _tint = Color(0xFFEFF6EA);
const _dark = Color(0xFF2D422F);
const _lineC = Color(0xFFE6EBE2);
const _btnGradient = [Color(0xFF89CB68), Color(0xFF8AD167)];

class _GreenButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _GreenButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(colors: _btnGradient),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Text(text,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _VersionTag extends StatelessWidget {
  final String text;
  final bool highlight;
  const _VersionTag(this.text, {this.highlight = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? _tint : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: highlight ? null : Border.all(color: _lineC),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (highlight) ...[
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF8EC867), shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Text(text,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: highlight ? _dark : _soft)),
      ]),
    );
  }
}

/// Optional update: bottom sheet.
class _UpdateSheet extends StatelessWidget {
  final String version;
  final String? message;
  final bool lastSkip;
  final VoidCallback onUpdate;
  final VoidCallback onLater;
  const _UpdateSheet({
    required this.version,
    required this.message,
    required this.lastSkip,
    required this.onUpdate,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(22, 10, 22, 16 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFDCE2D8), borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 20),
          Image.asset('assets/images/logo_wordmark.png', width: 104, fit: BoxFit.contain),
          const SizedBox(height: 16),
          const Text('Update available',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 8),
          _VersionTag('Version $version'),
          if (message != null && message!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, height: 1.45, color: _soft)),
          ],
          if (lastSkip) ...[
            const SizedBox(height: 12),
            const Text('You can skip this one more time.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _soft)),
          ],
          const SizedBox(height: 20),
          _GreenButton(text: 'Update now', onTap: onUpdate),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: TextButton(
              onPressed: onLater,
              child: const Text('Not now',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w500, color: _soft)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Required update: full screen, no skip, back does nothing.
class _ForceUpdatePage extends StatelessWidget {
  final String current;
  final String target;
  final String? message;
  final VoidCallback onUpdate;
  const _ForceUpdatePage({
    required this.current,
    required this.target,
    required this.message,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .55],
              colors: [_tint, Colors.white],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 28, 26, 20),
              child: Column(children: [
                Image.asset('assets/images/logo_wordmark.png', width: 128, fit: BoxFit.contain),
                const Spacer(flex: 2),
                Container(
                  width: 136,
                  height: 136,
                  decoration: BoxDecoration(color: const Color(0xFF8EC867).withOpacity(.14), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(color: const Color(0xFF8EC867).withOpacity(.24), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: _btnGradient),
                        boxShadow: [BoxShadow(color: const Color(0xFF8AD167).withOpacity(.45), blurRadius: 18, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(Icons.download_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text('Time to update',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 10),
                Text(
                  (message != null && message!.trim().isNotEmpty)
                      ? message!
                      : 'This version of Fit Her is no longer supported. Update to keep joining your classes.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, height: 1.55, color: _soft),
                ),
                const SizedBox(height: 18),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _VersionTag(current, highlight: false),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 16, color: _soft),
                  ),
                  _VersionTag(target),
                ]),
                const Spacer(flex: 3),
                _GreenButton(text: 'Update now', onTap: onUpdate),
                const SizedBox(height: 10),
                const Text('Takes less than a minute',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _soft)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
