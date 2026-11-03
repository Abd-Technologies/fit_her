import 'package:url_launcher/url_launcher.dart';

/// Opens a Google Meet (or any meeting) link reliably.
///
/// Links are typed by staff, so they often come without "https://"
/// ("meet.google.com/abc-defg-hij"), with spaces, or with a trailing dot.
/// A link without a scheme can't be launched and the tap silently did
/// nothing. This cleans the link, tries the Meet app / browser first and
/// falls back to the platform default. Returns false if nothing opened.
Future<bool> openMeetingLink(String? raw) async {
  var link = (raw ?? '').trim();
  if (link.isEmpty) return false;
  link = link.replaceAll(RegExp(r'\s+'), '');
  link = link.replaceAll(RegExp(r'[.,;]+$'), '');
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(link)) {
    link = 'https://$link';
  }
  final uri = Uri.tryParse(link);
  if (uri == null || uri.host.isEmpty) return false;
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return true;
    }
  } catch (_) {}
  try {
    return await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}
