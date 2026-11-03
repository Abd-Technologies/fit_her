import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../../widgets/v2/v2_bottom_sheet.dart';
import '../../../widgets/v2/v2_buttons.dart';

/// `POPUP_RENEW_PLAN` — Day 30 + progress submitted. Per Decision 9 this
/// is CTA-only; no embedded price. Tapping "View renewal plans" hands off
/// to the existing plan-purchase flow.
class RenewPlanSheet extends StatelessWidget {
  static const String variable = 'POPUP_RENEW_PLAN';

  /// Caller hooks the navigation to the existing plans-purchase screen.
  final VoidCallback onViewPlans;

  /// Her plan has already ended (not just ending soon).
  final bool ended;

  const RenewPlanSheet({Key? key, required this.onViewPlans, this.ended = false}) : super(key: key);

  static Future<void> show({required VoidCallback onViewPlans, bool ended = false}) {
    return V2BottomSheet.show(
      title: ended ? "Your plan has ended" : "Ready for next month?",
      child: RenewPlanSheet(onViewPlans: onViewPlans, ended: ended),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ConsultationController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ended
              ? "Renew to keep your dietitian, live classes and your routine. Your meal plan stays here for you to look back on."
              : "You finished your 30-day cycle. Renew now to keep your dietitian, your progress, and your routine.",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Color(0xFF7A8C78),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        V2PrimaryButton(
          label: 'View renewal plans',
          onPressed: () {
            ctrl.completePopup(variable);
            Get.back<dynamic>();
            onViewPlans();
          },
        ),
        const SizedBox(height: 8),
        V2GhostButton(
          label: 'Maybe later',
          onPressed: () {
            ctrl.dismissPopup(variable);
            Get.back<dynamic>();
          },
        ),
      ],
    );
  }
}
