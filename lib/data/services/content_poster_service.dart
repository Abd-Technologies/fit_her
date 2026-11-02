
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_cost_monitor_service.dart';

/// 2P1 / 2P2 — AI content poster + community manager shells.
class ContentPosterService extends GetxService {
  static const _draftsKey = 'd23_content_drafts_v1';

  final SharedPreferences prefs;

  ContentPosterService({required this.prefs});

  final RxList<Map<String, dynamic>> drafts = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    final raw = prefs.getString(_draftsKey);
    if (raw != null) {
      try {
        drafts.assignAll(
          (jsonDecode(raw) as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e)),
        );
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> draftEducationalPost(String topic) async {
    final draft = {
      'type': 'post',
      'topic': topic,
      'body':
          'Myth vs fact: $topic. (Draft from approved library templates — staff review before publish.)',
      'status': 'pending_review',
      'at': DateTime.now().toIso8601String(),
    };
    drafts.insert(0, draft);
    await prefs.setString(_draftsKey, jsonEncode(drafts));
    if (Get.isRegistered<AiCostMonitorService>()) {
      await Get.find<AiCostMonitorService>().record('content_poster');
    }
    return draft;
  }

  Future<Map<String, dynamic>> draftWeeklyPrompt() async {
    final draft = {
      'type': 'prompt',
      'body':
          'Weekly prompt: What helped your energy this week? (Community manager shell)',
      'status': 'pending_review',
      'at': DateTime.now().toIso8601String(),
    };
    drafts.insert(0, draft);
    await prefs.setString(_draftsKey, jsonEncode(drafts));
    if (Get.isRegistered<AiCostMonitorService>()) {
      await Get.find<AiCostMonitorService>().record('community_manager');
    }
    return draft;
  }
}
