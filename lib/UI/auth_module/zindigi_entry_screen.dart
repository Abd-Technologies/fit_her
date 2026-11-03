// MOCK — Zindigi mini-app entry point.
//
// This is what a user lands on when they tap "FitHer" inside the
// Zindigi app: Zindigi opens this screen (as a web build) with an
// encrypted payload attached to the URL containing whatever identity
// fields Zindigi already has on file — per their doc, that's just
// cnic + email + name + mobile. FitHer's own signup needs a lot more
// (age, weight, height, goal, health conditions, cycle info, time
// preference) before someone can really use the app — this screen's
// whole job is to bridge that gap:
//
//   1. Decrypt what Zindigi gave us.
//   2. Ask FitHer's backend: does an account already exist for this
//      person?
//        - Yes -> log them straight in, skip everything else.
//        - No  -> create a bare-minimum account, then send them
//                 through FitHer's EXISTING onboarding wizard
//                 (GoalScreen -> SignUpScreenQuestions) to collect
//                 the rest. Nothing new to build for that part — it
//                 already exists and already knows how to finish a
//                 partial signup.
//
// What's mocked vs. real:
//   - The AES decrypt (ZindigiCrypto) is REAL, spec-correct logic —
//     only the shared secret is a placeholder until Zindigi provides
//     the real one.
//   - The backend call to `/auth/zindigi-entry` is real *if* that
//     endpoint exists; if it 404s/fails (because it doesn't exist
//     yet), this screen falls back to an in-memory mock response so
//     the rest of the flow is still demoable end-to-end right now.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/models/login_response_model/login_response_model.dart';
import '../../utils/zindigi_crypto.dart';
import '../../values/constants.dart';
import '../dashboard_module/bottom_bar_screen/bottom_bar_screen.dart';
import 'login/login.dart';
import 'sign_up_screen/goal_screen.dart';
import 'sign_up_screen/sign_up_screen_questions.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class ZindigiEntryScreen extends StatefulWidget {
  const ZindigiEntryScreen({super.key});

  @override
  State<ZindigiEntryScreen> createState() => _ZindigiEntryScreenState();
}

class _ZindigiEntryScreenState extends State<ZindigiEntryScreen> {
  String _status = 'Verifying your Zindigi account…';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processEntry());
  }

  Future<void> _processEntry() async {
    try {
      final encryptedPayload = _readPayloadFromUrl();

      final decrypted = ZindigiCrypto.decrypt(
        encryptedPayload,
        ZindigiCrypto.mockSharedSecret, // TODO: swap for the real shared secret from Zindigi
      );
      final fields = ZindigiCrypto.parseFieldPayload(decrypted);

      final cnic = fields['cnic'] ?? '';
      final email = fields['email'] ?? '';
      final name = fields['name'] ?? '';
      final mobile = fields['mobile'] ?? '';

      if (email.isEmpty && mobile.isEmpty) {
        throw Exception('Payload missing both email and mobile — cannot identify user.');
      }

      setState(() => _status = 'Setting up your FitHer account…');

      final entryResult = await _callZindigiEntryEndpoint(
        cnic: cnic,
        email: email,
        name: name,
        mobile: mobile,
      );

      _finishLogin(entryResult);
    } catch (e) {
      debugPrint('ZindigiEntryScreen error: $e');
      setState(() {
        _failed = true;
        _status = "Couldn't verify your Zindigi session.";
      });
    }
  }

  /// Reads `?payload=...` from the browser URL (this screen only makes
  /// sense as a web build). Falls back to a locally-encrypted sample
  /// payload so the screen is runnable/demoable outside a real Zindigi
  /// launch (e.g. testing with `flutter run -d chrome` directly).
  String _readPayloadFromUrl() {
    if (kIsWeb) {
      final payload = Uri.base.queryParameters['payload'];
      if (payload != null && payload.isNotEmpty) return payload;
    }
    return _mockEncryptedPayloadForDemo();
  }

  /// Builds a fake "Zindigi already encrypted this for us" payload
  /// locally, using the same doc-sample field shape, purely so this
  /// screen has something to decrypt when there's no real launch URL
  /// yet (dev/demo only — delete once real testing with Zindigi
  /// starts).
  String _mockEncryptedPayloadForDemo() {
    const sampleFields =
        'cnic=3720012765434&email=demo.user@example.com&name=Demo User&mobile=03001234567';
    return ZindigiCrypto.encryptText(sampleFields, ZindigiCrypto.mockSharedSecret);
  }

  /// Calls FitHer's own backend to find-or-create the account for this
  /// identity. This endpoint doesn't exist yet — when the real one
  /// (`/auth/zindigi-entry`) is added, this is the only place that
  /// needs to change. Until then, any failure falls back to a mock
  /// "new user" response so the onboarding hand-off below is still
  /// fully testable.
  Future<_ZindigiEntryResult> _callZindigiEntryEndpoint({
    required String cnic,
    required String email,
    required String name,
    required String mobile,
  }) async {
    try {
      final api = Get.find<ApiProvider>();
      final response = await api.postData(
        '/auth/zindigi-entry',
        body: {
          'cnic': cnic,
          'email': email,
          'name': name,
          'mobile': mobile,
        },
      );

      final body = response.body;
      if (body is Map && body['status'] == '1' && body['data'] != null) {
        final data = Map<String, dynamic>.from(body['data']);
        return _ZindigiEntryResult(
          model: LoginModel.fromJson(data),
          isNewUser: data['isNewUser'] == true,
        );
      }
      throw Exception('Unexpected response shape from /auth/zindigi-entry');
    } catch (e) {
      debugPrint('/auth/zindigi-entry not available yet, using mock response: $e');
      return _mockNewUserResult(cnic: cnic, email: email, name: name, mobile: mobile);
    }
  }

  /// Stand-in for "backend said this is a brand-new user" — splits
  /// `name` into first/last the same naive way a real endpoint would,
  /// and marks the account as needing the rest of onboarding.
  _ZindigiEntryResult _mockNewUserResult({
    required String cnic,
    required String email,
    required String name,
    required String mobile,
  }) {
    final parts = name.trim().split(' ');
    final firstName = parts.isNotEmpty ? parts.first : 'Zindigi';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : 'User';

    return _ZindigiEntryResult(
      isNewUser: true,
      model: LoginModel(
        id: DateTime.now().millisecondsSinceEpoch, // mock only — real id comes from backend
        firstName: firstName,
        lastName: lastName,
        phone: mobile,
        email: email,
        accessToken: 'MOCK_ACCESS_TOKEN', // TODO: real token comes from /auth/zindigi-entry
        userType: Constants.user,
        adminId: 0,
        status: false, // no active plan yet — matches a brand-new account
      ),
    );
  }

  void _finishLogin(_ZindigiEntryResult result) {
    final auth = Get.find<AuthController>();
    auth.loginAsA.value = Constants.user;
    auth.logInUser = result.model;
    auth.addLocalStorage(result.model, '');

    if (!result.isNewUser) {
      // Existing FitHer account — nothing more needed from this
      // person, go straight in.
      Get.offAll(() => BottomBarScreen());
      return;
    }

    // Brand-new account — Zindigi only gave us cnic/email/name/mobile.
    // Everything else FitHer needs (goal, age, weight, height, cycle
    // info, health conditions, notification time preference) is
    // collected by the SAME onboarding wizard normal signups already
    // go through. No new screens needed for that part — just enter
    // the existing chain at its normal starting point.
    Get.offAll(() => const SignUpScreenQuestions());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_failed) const FhLoader(),
              const SizedBox(height: 20),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              if (_failed) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Get.offAll(() => Login()),
                  child: const Text('Continue in FitHer app'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ZindigiEntryResult {
  final LoginModel model;
  final bool isNewUser;
  const _ZindigiEntryResult({required this.model, required this.isNewUser});
}
