import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/Repos/progress_v2/progress_repository.dart';
import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../values/constants.dart';

/// Phase E2 — beta opt-in toggle for the new Progress hub.
///
/// Self-contained:
///   • Reads current state from `authController.logInUser.useNewProgressHub`
///   • Calls `ProgressRepository.setFeatureFlag` on toggle
///   • On success: updates the in-memory LoginModel + SharedPreferences so
///     the bottom-nav router re-routes on the next tab switch without
///     waiting for a re-login.
///   • On failure: reverts the optimistic UI flip + shows a snackbar.
///
/// Visual style mirrors the Notifications tile in profile_screen_user.dart
/// so the addition reads as part of the existing settings list.
class ProgressBetaToggle extends StatefulWidget {
  const ProgressBetaToggle({Key? key}) : super(key: key);

  @override
  State<ProgressBetaToggle> createState() => _ProgressBetaToggleState();
}

class _ProgressBetaToggleState extends State<ProgressBetaToggle> {
  /// True while a setFeatureFlag round-trip is in flight. Disables the
  /// switch so a user can't double-tap and race against themselves.
  bool _saving = false;

  bool _currentValue() {
    try {
      final auth = Get.find<AuthController>();
      return auth.logInUser?.useNewProgressHub ?? false;
    } catch (_) {
      // AuthController not registered (test harness etc.)
      return false;
    }
  }

  Future<void> _onChanged(bool next) async {
    if (_saving) return;
    setState(() => _saving = true);

    // Optimistic: flip the in-memory model now so the UI feels snappy. We
    // revert below if the network call fails.
    final auth = Get.find<AuthController>();
    final previous = auth.logInUser?.useNewProgressHub ?? false;
    if (auth.logInUser != null) {
      auth.logInUser!.useNewProgressHub = next;
    }

    final repo = _ensureRepo();
    final ok = await repo.setFeatureFlag(
      flag: 'useNewProgressHub',
      value: next,
    );

    if (!mounted) return;

    if (ok) {
      // Persist to SharedPreferences so cold-start picks up the new value.
      try {
        final prefs = Get.find<SharedPreferences>();
        await prefs.setBool(Constants.useNewProgressHubKey, next);
      } catch (_) {
        // SharedPreferences is always registered in production; treating
        // a missing instance as a no-op is fine for tests.
      }
      _showSnack(
        next ? 'You\'re on the new Progress hub. Tap the Progress tab to see it.' : 'Reverted to the classic Progress screen.',
      );
    } else {
      // Revert the optimistic flip.
      if (auth.logInUser != null) {
        auth.logInUser!.useNewProgressHub = previous;
      }
      _showSnack('Could not save your preference. Try again.');
    }

    setState(() => _saving = false);
  }

  ProgressRepository _ensureRepo() {
    if (!Get.isRegistered<ApiProvider>()) {
      Get.put(ApiProvider(), permanent: true);
    }
    if (!Get.isRegistered<ProgressRepository>()) {
      Get.put(
        ProgressRepository(apiProvider: Get.find<ApiProvider>()),
        permanent: true,
      );
    }
    return Get.find<ProgressRepository>();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF163220),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = _currentValue();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: Color(0xFF6DC55A), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progress hub (reports live)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
                ),
                const SizedBox(height: 2),
                Text(
                  value ? 'You\'re on the new hub. Toggle off to revert.' : 'Single-scroll dashboard with rings, charts, and AI tips.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF969696), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            // activeThumbColor replaces the soft-deprecated activeColor
            // post-Flutter 3.31. Same green either way.
            activeTrackColor: const Color(0xFF6DC55A),
            onChanged: _saving ? null : _onChanged,
          ),
        ],
      ),
    );
  }
}
