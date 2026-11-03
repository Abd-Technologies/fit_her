import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:fitness_zone_2/UI/auth_module/sign_up_screen/signup_screen_user.dart';
import 'package:fitness_zone_2/UI/free_trail/trial_journey_screen.dart';
import 'package:fitness_zone_2/widgets/new_home/trial_cta_card.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../UI/auth_module/walt_through/walk_through_screenn.dart';
import '../../UI/dashboard_module/bottom_bar_screen/bottom_bar_screen.dart';
import '../../values/constants.dart';

class AppLinkHandler {
  static final AppLinkHandler _instance = AppLinkHandler._internal();

  factory AppLinkHandler() => _instance;

  AppLinkHandler._internal();

  final AppLinks _appLinks = AppLinks();
  Uri? _initialLinkData;
  bool _initialized = false;

  void init(BuildContext context) async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    // First launch after installing from a rep's invite link: the Play
    // Store hands us the invite as the install referrer. Save it like a
    // tapped link, so signup continues straight into the trial.
    await _checkInstallReferrer();

    try {
      _initialLinkData = await _appLinks.getInitialLink();
      final uri = _initialLinkData;
      if (uri != null) {
        await _handleIncomingUri(context, uri);
      }
    } catch (e) {
      debugPrint('Error getting initial app link: $e');
    }

    // Handle app in background/foreground
    _appLinks.uriLinkStream.listen((Uri? uri) async {
      if (uri != null) {
        await _handleIncomingUri(context, uri);
      }
    }, onError: (err) {
      debugPrint('App link error: $err');
    });
  }

  static const String _kReferrerCheckedKey = 'installReferrerChecked';

  Future<void> _checkInstallReferrer() async {
    if (!Platform.isAndroid) return;
    try {
      final auth = Get.find<AuthController>();
      final prefs = auth.sharedPreferences;
      if (prefs.getBool(_kReferrerCheckedKey) == true) return;
      prefs.setBool(_kReferrerCheckedKey, true);

      final details = await PlayInstallReferrer.installReferrer;
      final raw = details.installReferrer ?? '';
      if (raw.isEmpty) return;
      // Growth analytics: where she came from (saved, sent at sign-up).
      try {
        final q = Uri.splitQueryString(raw);
        final src = q['utm_source'] ?? (q['trial_token'] != null ? 'rep_link' : null);
        if (src != null && src.isNotEmpty && src != 'google-play') {
          prefs.setString('signup_source', src);
        }
        if ((q['utm_campaign'] ?? '').isNotEmpty) prefs.setString('signup_campaign', q['utm_campaign']!);
      } catch (_) {}
      final token = Uri.splitQueryString(raw)['trial_token'] ?? '';
      if (token.isEmpty) return;
      if ((prefs.getString(Constants.trialToken) ?? '').isNotEmpty) return;

      // Saves the token on success. Stays quiet otherwise: a used or
      // expired invite just means she starts the trial from the app.
      await Get.find<HomeController>()
          .validateTrialToken(token, showToastOnSuccess: false, quiet: true);
    } catch (e) {
      debugPrint('Install referrer check skipped: $e');
    }
  }

  Future<void> _handleIncomingUri(BuildContext context, Uri uri) async {
    final token = uri.queryParameters["token"];
    if (uri.toString().contains("trial") && token != null && token.isNotEmpty) {
      // Growth analytics: she came from a sales rep's trial link.
      try {
        final p = Get.find<AuthController>().sharedPreferences;
        if ((p.getString('signup_source') ?? '').isEmpty) p.setString('signup_source', 'rep_link');
      } catch (_) {}
      final homeController = Get.find<HomeController>();
      final authController = Get.find<AuthController>();

      final isValid = await homeController.validateTrialToken(token, showToastOnSuccess: false);
      if (!isValid) {
        // Token invalid/expired/used — if logged in stay in app, otherwise go to walkthrough.
        final hasSession = (authController.sharedPreferences.getString(Constants.accessToken) ?? "").isNotEmpty;
        if (!hasSession) Get.offAll(() => const WalkThroughScreen());
        return;
      }

      final accessToken =
          authController.sharedPreferences.getString(Constants.accessToken) ?? "";

      if (accessToken.isNotEmpty) {
        // Already logged in. If her trial is already running, just go
        // home. Otherwise go to trial onboarding: the trial (and its
        // clock) only starts when she finishes it.
        if (homeController.trialLive.value) {
          Get.offAll(() => BottomBarScreen(index: 0));
          return;
        }
        final started = await homeController.startTrialFromSavedToken();
        if (started) {
          // Consolidated: freshly-started trial -> diet quick-intake ->
          // AI plan -> workout onboarding, same as every other entry
          // point. Clears the nav stack so the deep link doesn't leave a
          // dangling back-history.
          enterTrialOnboarding(TrialNav.replaceAll);
          return;
        }
        // startTrialFromSavedToken failed (e.g. user already has an active trial).
        // Do NOT send a logged-in user to WalkThroughScreen — go home instead.
        await homeController.getMyTrialJourney();
        Get.offAll(() => const TrialJourneyScreen());
        return;
      }

      // Not logged in — save token (already done inside validateTrialToken) and
      // send to onboarding so they can sign up / log in.
      Get.offAll(() => const WalkThroughScreen());
      return;
    }

    if (uri.toString().contains('customerSupport')) {
      Get.offAll(() => SignUpNewUser(
            supporterId: uri.toString().split("/").last,
          ));
    } else {
      Get.offAll(() => const WalkThroughScreen());
    }
  }
}
