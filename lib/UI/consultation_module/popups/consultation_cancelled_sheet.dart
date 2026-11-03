import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../../widgets/v2/v2_bottom_sheet.dart';
import '../../../widgets/v2/v2_buttons.dart';

/// `POPUP_CONSULTATION_CANCELLED` (Oct 2026): her consultation was
/// cancelled by the dietitian or by the system (never when she cancelled
/// it herself). Urgent in the pop-up manager. Same look as the "class
/// cancelled" sheet. The server sends `reason`, `kind`, `bonusDays`,
/// `locked` (helper/consultationCancelledPopup.js).
class ConsultationCancelledSheet extends StatelessWidget {
  static const String variable = 'POPUP_CONSULTATION_CANCELLED';

  static const Color _textMuted = Color(0xFF7A8C78);
  static const Color _noteBg = Color(0xFFEAF7E4);
  static const Color _noteBorder = Color(0xFFD8EDD4);
  static const Color _textDark = Color(0xFF1A3A22);

  final String reason;
  final int bonusDays;
  final bool locked;
  final VoidCallback onPickNewTime;

  const ConsultationCancelledSheet({
    Key? key,
    required this.reason,
    required this.bonusDays,
    required this.locked,
    required this.onPickNewTime,
  }) : super(key: key);

  static Future<void> show({
    required String reason,
    int bonusDays = 0,
    bool locked = false,
    required VoidCallback onPickNewTime,
  }) {
    final missedByHer = reason == 'client_no_show';
    return V2BottomSheet.show(
      title: missedByHer ? 'We missed you today 💚' : "We're sorry 🙏",
      child: ConsultationCancelledSheet(
        reason: reason,
        bonusDays: bonusDays,
        locked: locked,
        onPickNewTime: onPickNewTime,
      ),
    );
  }

  String get _message {
    switch (reason) {
      case 'dietitian_no_show':
        return "Your dietitian couldn't join your session, so we cancelled it. "
            'Pick a new time, it\'s free.';
      case 'client_no_show':
        return locked
            ? 'You missed your session again, so our team will reach out to '
                'help you book a new time.'
            : "No problem, this one's on us. Book a new time and we'll build "
                'your plan right after.';
      case 'dietitian_emergency':
        return 'Your dietitian had an emergency and couldn\'t take your '
            'session. Pick a new time, it\'s free.';
      case 'dietitian_cancelled':
      default:
        return 'Your dietitian had to cancel your session. '
            'Pick a new time, it\'s free.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ConsultationController>();
    final canRebook = !(reason == 'client_no_show' && locked);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: _textMuted,
            height: 1.5,
          ),
        ),
        if (bonusDays > 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _noteBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _noteBorder),
            ),
            child: Text(
              "We've added $bonusDays free day${bonusDays == 1 ? '' : 's'} to your package",
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (canRebook) ...[
          V2PrimaryButton(
            label: 'Pick a new time',
            onPressed: () {
              ctrl.completePopup(variable);
              Get.back<dynamic>();
              onPickNewTime();
            },
          ),
          const SizedBox(height: 8),
        ],
        V2GhostButton(
          label: 'OK',
          onPressed: () {
            ctrl.completePopup(variable);
            Get.back<dynamic>();
          },
        ),
      ],
    );
  }
}
