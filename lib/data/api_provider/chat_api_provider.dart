import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../values/constants.dart';

/// Chat push notifications. The server sends them now
/// (POST /users/chat/notify); the app no longer holds any Google key.
class ChatApiProvider extends GetConnect implements GetxService {
  SharedPreferences sharedPreferences;

  ChatApiProvider(this.sharedPreferences);

  /// body: {toUserId, body}. Never throws.
  Future<http.Response?> postData({
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final toUserId = '${body['toUserId'] ?? ''}'.trim();
    final text = '${body['body'] ?? ''}'.trim();
    if (toUserId.isEmpty || text.isEmpty) return null;
    try {
      return await http
          .post(
            Uri.parse('${Constants.baseUrl}/users/chat/notify'),
            headers: {
              'Content-Type': 'application/json',
              'accessToken': sharedPreferences.getString(Constants.accessToken) ?? '',
            },
            body: jsonEncode({'toUserId': toUserId, 'text': text}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    }
  }
}
