
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/services/reports_d23_service.dart';
import '../../data/services/tier_access_service.dart';
import '../../theme/app_colors.dart';

/// 2NH10–13 hub — weekly pattern, weekly recap, monthly report (doctor PDF via Progress).
class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<ReportsD23Service>();
    final weekly = svc.buildWeekly();
    final monthly = svc.buildMonthly();
    final tier = Get.find<TierAccessService>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Your reports'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!svc.canViewWeekly)
            _gate(tier)
          else ...[
            const Text('Weekly patterns',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (!weekly.enoughData)
              Text(weekly.recap)
            else ...[
              ...weekly.patterns.map((p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insights, color: AppColors.primary),
                    title: Text(p),
                  )),
              const SizedBox(height: 8),
              const Text('Weekly recap',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text(weekly.recap),
            ],
            const Divider(height: 32),
            const Text('Monthly nutrition & body',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (!svc.canViewMonthly)
              _gate(tier)
            else ...[
              Text(
                'Avg kcal ${monthly.nutritionAverages['calories']?.toStringAsFixed(0) ?? '—'} · '
                'P ${monthly.nutritionAverages['protein']?.toStringAsFixed(0)}g · '
                'C ${monthly.nutritionAverages['carbs']?.toStringAsFixed(0)}g · '
                'F ${monthly.nutritionAverages['fat']?.toStringAsFixed(0)}g',
              ),
              ...monthly.bodyTrends.map((t) => Text('• $t')),
              const SizedBox(height: 8),
              const Text('Try next month',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              ...monthly.nextMonthTips.map((t) => Text('• $t')),
            ],
            const SizedBox(height: 24),
            const Text(
              'Doctor PDF: open Progress → Share Report (includes meds & cycle when logged).',
              style: TextStyle(color: Color(0xFF6F8B7A), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gate(TierAccessService tier) => Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Reports unlock on ${tier.tier.value.name.toUpperCase() == 'FREE' ? 'Plus' : 'your plan'}. Current tier: ${tier.tier.value.name}.',
        ),
      );
}
