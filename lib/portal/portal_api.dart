import 'package:get/get.dart';

import '../data/api_provider/api_provider.dart';
import '../helper/private_file_url.dart';
import '../values/constants.dart';
import 'portal_session.dart';

/// Thin API helper for portal screens. Returns the response body as a map
/// ({status, message, data}). Never throws.
class PortalApi {
  PortalApi._();

  static Map<String, String> get _h {
    final s = Get.find<PortalSession>();
    s.touch();
    return s.headers;
  }

  static Map<String, dynamic> _body(dynamic b) =>
      b is Map ? Map<String, dynamic>.from(b) : {'status': '0', 'message': "Couldn't reach the server."};

  static Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async =>
      _body((await Get.find<ApiProvider>().getData(path, query: query, headers: _h)).body);

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async =>
      _body((await Get.find<ApiProvider>().postData(path, body: body, headers: _h)).body);

  static bool ok(Map<String, dynamic> b) => '${b['status']}' == '1';
  static String msg(Map<String, dynamic> b, [String fallback = 'Something went wrong.']) =>
      (b['message'] ?? fallback).toString();

  /// Full URL for a PUBLIC uploaded file (plan images, testimonials,
  /// community posts, profile photos).
  static String file(String path) =>
      path.startsWith('http') ? path : '${Constants.baseUrl}/${path.startsWith('/') ? path.substring(1) : path}';

  /// Full URL for a PRIVATE uploaded file (payment slips, progress photos,
  /// support screenshots) via the protected GET /files route, with the
  /// portal session token in ?t= (Image.network can't send headers on web).
  static String privateFile(String path) {
    String token = '';
    try {
      token = Get.find<PortalSession>().token;
    } catch (_) {}
    return privateFileUrl(path, token: token);
  }
}
