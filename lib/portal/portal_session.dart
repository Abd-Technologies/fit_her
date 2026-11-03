import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_provider/api_provider.dart';
import '../values/constants.dart';

enum PortalRole { admin, trainer, dietitian }

/// Who is logged in on the portal (kept in the browser).
class PortalSession extends GetxService {
  PortalSession(this.prefs);
  final SharedPreferences prefs;

  static const _kUser = 'portal_user';
  static const _kSeen = 'portal_last_seen';
  static const idleLimit = Duration(hours: 12);

  final user = Rxn<Map<String, dynamic>>();

  String get token => '${user.value?['accessToken'] ?? ''}';
  int? get userId => (user.value?['id'] as num?)?.toInt();
  String get name => '${user.value?['firstName'] ?? ''} ${user.value?['lastName'] ?? ''}'.trim();
  Map<String, String> get headers => {'accessToken': token};

  PortalRole? get role {
    final t = '${user.value?['userType'] ?? ''}'.trim().toLowerCase();
    if (t == 'admin') return PortalRole.admin;
    if (t == 'trainer') return PortalRole.trainer;
    if (t == 'dietition' || t == 'dietitian') return PortalRole.dietitian;
    return null;
  }

  String get roleLabel => switch (role) {
        PortalRole.admin => 'Admin',
        PortalRole.trainer => 'Trainer',
        PortalRole.dietitian => 'Dietitian',
        null => '',
      };

  bool get loggedIn => token.isNotEmpty && role != null;

  /// Restore from the browser; logged out after 12 h without use.
  void restore() {
    final raw = prefs.getString(_kUser);
    final seen = prefs.getInt(_kSeen) ?? 0;
    if (raw == null) return;
    if (DateTime.now().millisecondsSinceEpoch - seen > idleLimit.inMilliseconds) {
      logout();
      return;
    }
    try {
      user.value = Map<String, dynamic>.from(jsonDecode(raw));
      touch();
    } catch (_) {
      logout();
    }
  }

  void touch() => prefs.setInt(_kSeen, DateTime.now().millisecondsSinceEpoch);

  /// The server renewed the login token (`x-new-token`): keep using the new one.
  void updateToken(String newToken) {
    final u = user.value;
    if (u == null || newToken.isEmpty || token == newToken) return;
    final next = Map<String, dynamic>.from(u)..['accessToken'] = newToken;
    user.value = next;
    prefs.setString(_kUser, jsonEncode(next));
  }

  /// Staff login (server refuses clients). Returns an error message or null.
  Future<String?> login(String email, String password) async {
    try {
      final r = await Get.find<ApiProvider>().postData(
        Constants.loginPath,
        body: {'email': email.trim(), 'password': password, 'client': 'portal'},
      );
      final b = r.body;
      if (b is Map && b['status'] == '1' && b['data'] is Map) {
        final data = Map<String, dynamic>.from(b['data']);
        user.value = data;
        if (role == null) {
          user.value = null;
          return 'This portal is for the Fit Her team. Please use the Fit Her mobile app.';
        }
        prefs.setString(_kUser, jsonEncode(data));
        touch();
        return null;
      }
      return b is Map ? '${b['message'] ?? 'Login failed'}' : 'Login failed';
    } catch (_) {
      return "Can't reach the server. Is the backend running?";
    }
  }

  void logout() {
    user.value = null;
    prefs.remove(_kUser);
    prefs.remove(_kSeen);
  }
}
