
import 'package:get/get.dart';

import '../../helper/analytics_helper.dart';
import '../analytics/analytics_events.dart';
import 'ai_cost_monitor_service.dart';
import 'food_preferences_service.dart';
import 'tier_access_service.dart';

class ChatMessage {
  final bool fromUser;
  final String text;
  final DateTime at;

  ChatMessage({required this.fromUser, required this.text, DateTime? at})
      : at = at ?? DateTime.now();
}

/// 3NH1 — AI nutritionist shell (rules/FAQ; medical safe reply).
class NutritionistChatService extends GetxService {
  static const medicalSafeReply =
      'I can help with food and your plan, but medical questions need a qualified professional. Please speak with your doctor.';

  final RxList<ChatMessage> messages = <ChatMessage>[].obs;

  Future<String> ask(String question) async {
    final tier = Get.find<TierAccessService>();
    if (!tier.canAccessNutritionist) {
      return 'AI Nutritionist is an Unlimited feature.';
    }
    if (!tier.canSendNutritionistMessage) {
      return 'You\'ve reached today\'s message cap. Try again tomorrow.';
    }
    messages.add(ChatMessage(fromUser: true, text: question));
    await tier.recordNutritionistMessage();
    if (Get.isRegistered<AiCostMonitorService>()) {
      await Get.find<AiCostMonitorService>().record('nutritionist');
    }
    await AnalyticsHelper.track(AnalyticsEvents.nutritionistMessage);

    final q = question.toLowerCase();
    String reply;
    if (_looksMedical(q)) {
      reply = medicalSafeReply;
    } else if (q.contains('protein') || q.contains('hungry')) {
      reply =
          'From your recent logs, aim for a protein-rich meal at lunch — dal, eggs, or chicken fit most plans.';
    } else if (q.contains('swap') || q.contains('allergic')) {
      final prefs = Get.isRegistered<FoodPreferencesService>()
          ? Get.find<FoodPreferencesService>().current.value
          : null;
      reply = prefs == null || prefs.allergies.isEmpty
          ? 'Tell me an allergy in Food preferences and I\'ll keep those foods out.'
          : 'I\'ll keep ${prefs.allergies.join(", ")} out of suggestions.';
    } else {
      reply =
          'Based on your plan and last logs: keep portions steady, hydrate, and match carbs to your training day. (Rules reply — live LLM later.)';
    }
    messages.add(ChatMessage(fromUser: false, text: reply));
    return reply;
  }

  bool _looksMedical(String q) {
    const keys = [
      'diagnos',
      'disease',
      'cancer',
      'pregnant',
      'miscarriage',
      'dose',
      'medicine',
      'prescription',
      'blood test',
      'thyroid medication',
    ];
    return keys.any(q.contains);
  }
}
