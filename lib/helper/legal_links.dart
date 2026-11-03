import 'package:url_launcher/url_launcher.dart';

import '../widgets/toasts.dart';

/// Fit Her Terms and Privacy pages (thefither.com). Opened in an in-app
/// browser so she stays in the app.
class LegalLinks {
  LegalLinks._();

  static const String terms = 'https://thefither.com/terms-conditions.html';
  static const String privacy = 'https://thefither.com/privacy-policy.html';

  static Future<void> openTerms() => _open(terms);
  static Future<void> openPrivacy() => _open(privacy);

  static Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return;
    } catch (_) {}
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    CustomToast.failToast(msg: "Couldn't open the page. Please try again.");
  }
}
