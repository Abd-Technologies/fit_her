import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helper/popup_manager.dart';
import '../values/constants.dart';
import 'v2/v2_bottom_sheet.dart';
import 'v2/v2_buttons.dart';

/// Admin announcement pop-up (Oct 2026). One place for saving and showing
/// it, so the push handlers (open / background / closed app) and the
/// main tabs all behave the same.
///
/// Rules:
///  - Saved when the push arrives; shown if it's less than 1 day old.
///  - Goes through the pop-up manager, 2nd in line (right after the
///    urgent ones).
///  - Shown once: closing it any way (button, swipe, tap outside) counts
///    as seen.
///  - Needs no BuildContext, so it can't crash on a closed screen.
///  - Only the latest announcement is kept (a new one replaces the old).
class AnnouncementPopup extends StatelessWidget {
  const AnnouncementPopup({super.key, required this.body});

  final String body;

  static const Color _textMuted = Color(0xFF7A8C78);
  static const Duration _maxAge = Duration(days: 1);

  /// Save from any push handler (also works in the background isolate).
  static Future<void> save(String? title, String? body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      Constants.announcementNotification,
      jsonEncode({
        'title': title,
        'body': body,
        'date': DateTime.now().toString(),
      }),
    );
  }

  /// Show the saved announcement if it is still fresh.
  /// [fromTap]: she tapped the announcement push, so show it now (only
  /// waits for an open pop-up), not on a later app open.
  static Future<void> maybeShow({bool fromTap = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // A push that arrived while the app was in the background was saved
      // by another isolate: re-read from disk.
      await prefs.reload();
      final raw = prefs.getString(Constants.announcementNotification);
      if (raw == null) return;
      final a = jsonDecode(raw);
      if (a is! Map) return;
      final date = DateTime.tryParse('${a['date']}');
      if (date == null || DateTime.now().difference(date) > _maxAge) {
        await prefs.remove(Constants.announcementNotification);
        return;
      }
      final title = (a['title'] ?? '').toString().trim();
      final body = (a['body'] ?? '').toString().trim();
      if (title.isEmpty && body.isEmpty) return;

      Future<void> show() async {
        // Seen as soon as it opens: closing it never brings it back.
        await prefs.remove(Constants.announcementNotification);
        await V2BottomSheet.show(
          title: title.isEmpty ? 'News from Fit Her' : title,
          child: AnnouncementPopup(body: body),
        );
      }

      if (fromTap) {
        await PopupManager.runNow('announcement_tap', show);
      } else {
        await PopupManager.run('announcement', rank: PopupRank.announcement, show: show);
      }
    } catch (e) {
      debugPrint('[announcement] skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (body.isNotEmpty)
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: _textMuted,
              height: 1.5,
            ),
          ),
        const SizedBox(height: 20),
        V2PrimaryButton(
          label: 'Ok, Got It',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
