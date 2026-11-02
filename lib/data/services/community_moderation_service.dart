import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helper/analytics_helper.dart';
import '../analytics/analytics_events.dart';

/// 1P1 client first-pass + 1P4 report/block/anonymous local store.
class CommunityModerationService extends GetxService {
  static const blockedKey = 'd1_blocked_users_v1';
  static const reportsKey = 'd1_post_reports_v1';
  static const flaggedKey = 'd1_flagged_posts_v1';

  static const _blockedWords = [
    'kill yourself',
    'suicide',
    'hate you',
    'stupid bitch',
    'slut',
  ];

  final SharedPreferences prefs;

  CommunityModerationService({required this.prefs});

  final RxSet<String> blockedUserIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    blockedUserIds.addAll(prefs.getStringList(blockedKey) ?? []);
  }

  /// Returns true if content should go to admin review queue.
  bool scanPost(String text) {
    final lower = text.toLowerCase();
    final flagged = _blockedWords.any(lower.contains);
    if (flagged) {
      AnalyticsHelper.track(AnalyticsEvents.postFlagged);
    }
    return flagged;
  }

  Future<void> markFlaggedLocally(String postId) async {
    final list = prefs.getStringList(flaggedKey) ?? [];
    if (!list.contains(postId)) {
      list.add(postId);
      await prefs.setStringList(flaggedKey, list);
    }
  }

  bool isFlagged(String postId) =>
      (prefs.getStringList(flaggedKey) ?? []).contains(postId);

  Future<void> reportPost({
    required String postId,
    required String reason,
  }) async {
    final raw = prefs.getString(reportsKey);
    final list = <Map<String, dynamic>>[];
    if (raw != null) {
      try {
        list.addAll((jsonDecode(raw) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
    list.add({
      'postId': postId,
      'reason': reason,
      'at': DateTime.now().toIso8601String(),
    });
    await prefs.setString(reportsKey, jsonEncode(list));
    await AnalyticsHelper.track(AnalyticsEvents.postReported, props: {
      'reason': reason,
    });
  }

  Future<void> blockUser(String userId) async {
    blockedUserIds.add(userId);
    await prefs.setStringList(blockedKey, blockedUserIds.toList());
    await AnalyticsHelper.track(AnalyticsEvents.userBlocked);
  }

  bool isBlocked(String userId) => blockedUserIds.contains(userId);
}
