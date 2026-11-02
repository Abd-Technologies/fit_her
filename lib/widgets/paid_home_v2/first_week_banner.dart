import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/luna_insight_service.dart';
import '../../values/constants.dart';

/// 1P12 — personal first-week message pack (days 1–7).
class FirstWeekBanner extends StatelessWidget {
  const FirstWeekBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<LunaInsightService>()) {
      return const SizedBox.shrink();
    }
    final prefs = Get.find<SharedPreferences>();
    final startMs = prefs.getInt('d1_first_open_ms');
    final now = DateTime.now().millisecondsSinceEpoch;
    if (startMs == null) {
      prefs.setInt('d1_first_open_ms', now);
    }
    final start = DateTime.fromMillisecondsSinceEpoch(
      prefs.getInt('d1_first_open_ms') ?? now,
    );
    final dayIndex = DateTime.now().difference(start).inDays;
    if (dayIndex > 6) return const SizedBox.shrink();

    // Only show for unpaid / early users; paid users still see day 1–3 tips.
    final paid = prefs.getString(Constants.packageState) == 'true';
    if (paid && dayIndex > 2) return const SizedBox.shrink();

    final msg = Get.find<LunaInsightService>().firstWeekMessage(dayIndex);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7E4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8EDD4)),
      ),
      child: Text(
        'Day ${dayIndex + 1} · $msg',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          color: Color(0xFF163220),
          height: 1.4,
        ),
      ),
    );
  }
}
