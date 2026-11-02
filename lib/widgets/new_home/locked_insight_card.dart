import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/analytics/analytics_events.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/services/luna_insight_service.dart';
import '../../helper/analytics_helper.dart';
import 'trial_cta_card.dart' show showLockedFeatureDialog;

/// Free home phase message (1NH14). Luna stays locked; rotating phase copy.
class LockedInsightCard extends StatelessWidget {
  const LockedInsightCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activated = Get.find<AuthController>().trialActivated.value;
      final luna = Get.isRegistered<LunaInsightService>()
          ? Get.find<LunaInsightService>()
          : null;
      final body = luna?.freePhaseMessage() ??
          'Your phase message unlocks a short daily tip. Plus adds Luna.';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        AnalyticsHelper.track(AnalyticsEvents.phaseMessageViewed);
      });

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: activated
            ? null
            : () => showLockedFeatureDialog('Luna insight'),
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
                    ? "TODAY'S PHASE MESSAGE"
                    : "🔒 LUNA BY FITHER · PHASE MESSAGE",
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
                opacity: activated ? 1.0 : 0.85,
                child: Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Color(0xFF4A6B4A),
                    height: 1.5,
                  ),
                ),
              ),
              if (!activated) ...const [
                SizedBox(height: 8),
                Text(
                  'See what Plus Luna adds →',
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
