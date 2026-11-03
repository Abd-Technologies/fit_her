import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../../widgets/toasts.dart';
import '../../../widgets/v2/v2_bottom_sheet.dart';

/// `POPUP_EARLY_CHECKIN` — fires on day 4 (open until day 6) after EVERY
/// diet plan the dietitian shares with her. First plan and later plans
/// get slightly different titles.
/// One question, three one-tap answers. A tap saves the answer and
/// closes the sheet; no follow-up questions (Oct 2026, kept simple).
class EarlyCheckinSheet extends StatelessWidget {
  static const String variable = 'POPUP_EARLY_CHECKIN';

  /// Kept for the orchestrator's existing call; not used any more.
  final VoidCallback onOpenChat;
  final VoidCallback onOpenFaq;

  const EarlyCheckinSheet({
    Key? key,
    required this.onOpenChat,
    required this.onOpenFaq,
  }) : super(key: key);

  static Future<void> show({
    required VoidCallback onOpenChat,
    required VoidCallback onOpenFaq,
    bool firstPlan = true,
  }) {
    return V2BottomSheet.show(
      title: firstPlan
          ? "How's your diet plan going?"
          : "How's your new diet plan going?",
      child: EarlyCheckinSheet(onOpenChat: onOpenChat, onOpenFaq: onOpenFaq),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ConsultationController>();

    void answer(String response) {
      ctrl.completePopup(variable, metadata: {'response': response});
      Get.back<dynamic>();
      CustomToast.successToast(msg: 'Thanks for telling us');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tell us in one tap.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Color(0xFF7A8C78),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _CheckinOption(
          emoji: '😊',
          label: 'Good',
          color: const Color(0xFF6DC55A),
          onTap: () => answer('good'),
        ),
        const SizedBox(height: 10),
        _CheckinOption(
          emoji: '😐',
          label: 'Some issues',
          color: const Color(0xFFFAC775),
          onTap: () => answer('some_issues'),
        ),
        const SizedBox(height: 10),
        _CheckinOption(
          emoji: '😟',
          label: 'Need help',
          color: const Color(0xFFFF8A8A),
          onTap: () => answer('need_help'),
        ),
      ],
    );
  }
}

class _CheckinOption extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CheckinOption({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.32)),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A3A22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
