import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../values/constants.dart';

/// URL for a PRIVATE uploaded file (payment slips, progress photos, support
/// screenshots, meal photos). Goes through the backend's protected
/// `GET /files/<path>` route, with the access token in `?t=` because
/// Image.network / NetworkImage can't reliably send headers (Flutter web).
///
/// Accepts any stored form:
///   "public/images/x.jpg", "/public/images/x.jpg", "images/x.jpg",
///   "C:/srv/app/public/payment_slips/x.png" (magic-link slips),
///   "https://host/public/issueUploads/x.jpg" (support tickets).
/// Other http(s) URLs (not under /public/) are returned unchanged.
///
/// Public images (plans, testimonials, posts, profile photos) keep using
/// "${Constants.baseUrl}/<path>" — don't route them through here.
String privateFileUrl(String? path, {String? token}) {
  if (path == null) return '';
  var p = path.trim().replaceAll('\\', '/');
  if (p.isEmpty || p == 'null') return '';

  String base = Constants.baseUrl.replaceFirst(RegExp(r'/+$'), '');
  final isUrl = RegExp(r'^https?://', caseSensitive: false).hasMatch(p);
  if (isUrl && p.contains('/files/')) return p; // already protected
  final i = p.toLowerCase().lastIndexOf('/public/');
  if (isUrl) {
    if (i < 0) return p; // external URL — leave alone
    base = p.substring(0, i);
    p = p.substring(i + 8);
  } else if (i >= 0) {
    p = p.substring(i + 8);
  } else {
    p = p.replaceFirst(RegExp(r'^/+'), '');
    if (p.toLowerCase().startsWith('public/')) p = p.substring(7);
  }
  p = p.split('?').first;

  final t = token ?? _storedToken();
  final enc = p.split('/').map(Uri.encodeComponent).join('/');
  return t.isEmpty ? '$base/files/$enc' : '$base/files/$enc?t=${Uri.encodeQueryComponent(t)}';
}

String _storedToken() {
  try {
    return Get.find<SharedPreferences>().getString(Constants.accessToken) ?? '';
  } catch (_) {
    return '';
  }
}
