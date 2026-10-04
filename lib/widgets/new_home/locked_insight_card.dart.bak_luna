import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/auth_controller/auth_controller.dart';
import 'trial_cta_card.dart' show showLockedFeatureDialog;

/// FitHer AI insight teaser on the unpaid home.
/// • Pre-activation: padlocked label, blurred preview, "Unlock insight →".
/// • Post-activation: clean label, full-opacity insight, no CTA tail.
///   Copy is the same sample phrasing so users feel they got the real
///   thing they were teased.
class LockedInsightCard extends StatelessWidget {
  const LockedInsightCard({Key? key}) : super(key: key);

  static const _kBody =
      'Recovery is 40% faster in your follicular phase — push today, '
      'rest smart this weekend for…';

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activated =
          Get.find<AuthController>().trialActivated.value;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Only the locked (pre-activation) state pops the trial teaser --
        // once unlocked this is just a normal insight card, no popup.
        onTap: activated
            ? null
            : () => showLockedFeatureDialog('FitHer AI Insight'),
        child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD8EDD4), width: 1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activated
                  ? "FITHER AI · TODAY'S INSIGHT"
                  : "🔒 FITHER AI · TODAY'S INSIGHT",
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9AB09A),
                letterSpacing: 0.63,
              ),
            ),
            const SizedBox(height: 6),
            Opacity(
              opacity: activated ? 1.0 : 0.55,
              child: const Text(
                _kBody,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Color(0xFF4A6B4A),
                  height: 1.5,
                ),
              ),
            ),
            // The "Unlock insight →" tail only makes sense pre-activation —
            // once the trial is active, there's nothing left to unlock here.
            if (!activated) ...const [
              SizedBox(height: 8),
              Text(
                'Unlock insight →',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6DC55A),
                ),
              ),
            ],
          ],
        ),
        ),
      );
    });
  }
}
