import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../../widgets/v2/v2_bottom_sheet.dart';
import '../../../widgets/v2/v2_buttons.dart';

/// `POPUP_CLASS_CANCELLED` — the server auto-cancels a workout class the
/// trainer hasn't started 10 minutes after its time (Pakistan time).
/// Apologises and points her to the next class today.
class ClassCancelledSheet extends StatelessWidget {
  static const String variable = 'POPUP_CLASS_CANCELLED';

  final String? classTime;
  final String? classType;
  final String? nextClass;
  final VoidCallback onViewClasses;

  const ClassCancelledSheet({
    Key? key,
    this.classTime,
    this.classType,
    this.nextClass,
    required this.onViewClasses,
  }) : super(key: key);

  static Future<void> show({
    String? classTime,
    String? classType,
    String? nextClass,
    required VoidCallback onViewClasses,
  }) {
    return V2BottomSheet.show(
      title: "We're sorry 🙏",
      child: ClassCancelledSheet(
        classTime: classTime,
        classType: classType,
        nextClass: nextClass,
        onViewClasses: onViewClasses,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ConsultationController>();
    final what = [
      if ((classTime ?? '').isNotEmpty) classTime,
      if ((classType ?? '').isNotEmpty) classType,
    ].join(' ');
    final classText = what.isEmpty ? 'Your class' : 'Your $what class';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "$classText couldn't start on time, so we cancelled it. "
          'Your time is important to us, and we apologise for the wait.',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Color(0xFF7A8C78),
            height: 1.5,
          ),
        ),
        if ((nextClass ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7E4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD8EDD4)),
            ),
            child: Text(
              'Next class today · $nextClass',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A3A22),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        V2PrimaryButton(
          label: "See today's classes",
          onPressed: () {
            ctrl.completePopup(variable);
            Get.back<dynamic>();
            onViewClasses();
          },
        ),
        const SizedBox(height: 8),
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
