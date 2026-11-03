// Fit Her staff portal (web). Admin, Trainer, Dietitian only.
// Run (live server, default):
//   flutter run -d chrome -t lib/portal/main_portal.dart
// Build for hosting:
//   flutter build web -t lib/portal/main_portal.dart --dart-define=BASE_URL=https://api.thefither.com
// Run against a backend on this laptop instead:
//   flutter run -d chrome -t lib/portal/main_portal.dart --dart-define=BASE_URL=http://localhost:9000
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_provider/api_provider.dart';
import '../firebase_options.dart';
import 'pages/login_page.dart';
import 'portal_session.dart';
import 'portal_theme.dart';
import 'shell/portal_shell.dart';

const _baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'https://api.thefither.com');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Chat uses Firestore (public web config, no secrets).
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  } catch (_) {} // Chat page shows a not-connected message if this fails
  // The app's .env holds server secrets; the portal never loads it, only
  // the server address (Constants.baseUrl reads BASE_URL from dotenv).
  dotenv.testLoad(fileInput: 'BASE_URL=$_baseUrl');
  final prefs = await SharedPreferences.getInstance();
  Get.put(ApiProvider(), permanent: true);
  final session = Get.put(PortalSession(prefs), permanent: true);
  session.restore();
  // Login token renewal + "your login ended" (Oct 2026, helper/authToken.js).
  ApiProvider.onNewToken = session.updateToken;
  ApiProvider.onAuthInvalid = () {
    if (!session.loggedIn) return; // already handled (several calls fail at once)
    session.logout();
    Get.offAll(() => const PortalLoginPage(), transition: Transition.fadeIn);
    Future.delayed(const Duration(milliseconds: 300), () => portalToast('Please log in again', error: true));
  };
  runApp(const PortalApp());
}

class PortalApp extends StatelessWidget {
  const PortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<PortalSession>();
    return GetMaterialApp(
      title: 'Fit Her Team Portal',
      debugShowCheckedModeBanner: false,
      navigatorKey: portalNavKey,
      theme: PT.theme(),
      home: session.loggedIn ? const PortalShell() : const PortalLoginPage(),
    );
  }
}
