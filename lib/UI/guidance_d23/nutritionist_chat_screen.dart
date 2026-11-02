import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/services/nutritionist_chat_service.dart';
import '../../data/services/tier_access_service.dart';
import '../../theme/app_colors.dart';

class NutritionistChatScreen extends StatefulWidget {
  const NutritionistChatScreen({super.key});

  @override
  State<NutritionistChatScreen> createState() => _NutritionistChatScreenState();
}

class _NutritionistChatScreenState extends State<NutritionistChatScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = Get.find<NutritionistChatService>();
    final tier = Get.find<TierAccessService>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI Nutritionist'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: Column(
        children: [
          if (!tier.canAccessNutritionist)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF4E5),
              padding: const EdgeInsets.all(12),
              child: const Text('Unlimited feature — upgrade to chat.'),
            ),
          Expanded(
            child: Obx(() => ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: chat.messages.length,
                  itemBuilder: (_, i) {
                    final m = chat.messages[i];
                    return Align(
                      alignment: m.fromUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: m.fromUser
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : const Color(0xFFF3F8F1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(m.text),
                      ),
                    );
                  },
                )),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Ask about food or your plan…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final q = _ctrl.text.trim();
                    if (q.isEmpty) return;
                    _ctrl.clear();
                    await chat.ask(q);
                  },
                  icon: const Icon(Icons.send, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
