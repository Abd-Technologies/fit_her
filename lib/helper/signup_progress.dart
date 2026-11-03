import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../UI/auth_module/login/login.dart';
import '../data/controllers/auth_controller/auth_controller.dart';
import '../data/models/login_response_model/login_response_model.dart';
import '../widgets/onboarding_scaffold.dart';

/// Sign-up questions (goal, body, life stage, cycle, health, class time):
/// saved after every page so closing the app or losing internet never
/// loses her answers, and reopened where she stopped until she finishes.
class SignupProgress {
  SignupProgress._();

  static String _draftKey(String userId) => 'signup_draft_$userId';
  static String _doneKey(String userId) => 'signup_done_$userId';

  /// True when she has finished the questions.
  ///  1. this phone saw the server confirm it, or
  ///  2. the server says so (login answer `onboardingDone`), or
  ///  3. an older server without that field: goal and age are saved.
  static bool isDone(LoginModel? user, SharedPreferences prefs) {
    if (user == null) return true;
    if (prefs.getString(_doneKey(user.id.toString())) == 'true') return true;
    if (user.onboardingDone != null) return user.onboardingDone!;
    return (user.mainGoal ?? '').isNotEmpty && (user.age ?? '').isNotEmpty;
  }

  /// Server confirmed the last page: never ask again on this phone.
  static void markDone(SharedPreferences prefs, String userId) {
    prefs.setString(_doneKey(userId), 'true');
    prefs.remove(_draftKey(userId));
    try {
      Get.find<AuthController>().logInUser?.onboardingDone = true;
    } catch (_) {}
  }

  static void saveDraft(SharedPreferences prefs, String userId, Map<String, dynamic> draft) {
    if (userId.isEmpty) return;
    try {
      prefs.setString(_draftKey(userId), jsonEncode(draft));
    } catch (_) {}
  }

  static Map<String, dynamic>? loadDraft(SharedPreferences prefs, String userId) {
    if (userId.isEmpty) return null;
    final raw = prefs.getString(_draftKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      return m is Map<String, dynamic> ? m : null;
    } catch (_) {
      return null;
    }
  }
}

/// Sign-up said "Email already exists": usually her account was made but
/// the answer never reached the phone (internet dropped). Offer log in.
void showAccountExistsDialog(String email) {
  if (Get.isDialogOpen ?? false) return;
  Get.dialog(
    AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'You already have an account',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: OnboardingScaffold.textDark),
      ),
      content: Text(
        email.isEmpty
            ? 'This email is already signed up. Log in to continue where you left off.'
            : '$email is already signed up. Log in to continue where you left off.',
        style: const TextStyle(fontSize: 14, height: 1.4, color: OnboardingScaffold.textSub),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Use another email', style: TextStyle(color: OnboardingScaffold.textSub)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: OnboardingScaffold.green,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Get.back();
            try {
              final auth = Get.find<AuthController>();
              auth.loginUserPhone.text = email;
              auth.loginUserPassword.clear();
            } catch (_) {}
            Get.offAll(() => Login());
          },
          child: const Text('Log in'),
        ),
      ],
    ),
  );
}
