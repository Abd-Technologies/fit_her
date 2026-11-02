import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/analytics/analytics_events.dart';
import '../../data/models/home_dashboard/home_dashboard_model.dart';
import '../../data/services/behavior_signal_service.dart';
import '../../data/services/luna_insight_service.dart';
import '../../helper/analytics_helper.dart';

/// Plus Luna card with five sections (1NH12). Prefer server insight text.
class LunaFivePartCard extends StatefulWidget {
  final HomeDashboardModel dashboard;

  const LunaFivePartCard({super.key, required this.dashboard});

  @override
  State<LunaFivePartCard> createState() => _LunaFivePartCardState();
}

class _LunaFivePartCardState extends State<LunaFivePartCard> {
  static const _ink = Color(0xFF163220);
  static const _deep = Color(0xFF3F9B35);

  @override
  void initState() {
    super.initState();
    final text = widget.dashboard.insight?.text;
    Get.find<LunaInsightService>().refreshCard(serverInsightText: text);
    AnalyticsHelper.track(AnalyticsEvents.lunaCardViewed);
    if (Get.isRegistered<BehaviorSignalService>()) {
      Get.find<BehaviorSignalService>().recordInsightType('luna');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final card = Get.find<LunaInsightService>().todayCard.value;
      if (card == null) return const SizedBox.shrink();

      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD8EDD4)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: 'Luna',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _deep,
                        ),
                      ),
                      TextSpan(
                        text: ' by FitHer',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9AB09A),
                        ),
                      ),
                    ]),
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                  ),
                  Spacer(),
                  Text(
                    'Today',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      color: Color(0xFF9AB09A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _part('Phase', card.phase),
              _part('How you may feel', card.feel),
              _part('Food', card.foodTip),
              _part('Movement', card.movementTip),
              _part('Sleep & rest', card.sleepNote),
            ],
          ),
        ),
      );
    });
  }

  Widget _part(String label, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF9AB09A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              height: 1.4,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}
