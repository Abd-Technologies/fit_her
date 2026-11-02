import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/daily_log_controller/daily_log_controller.dart';
import '../../data/models/daily_log/skin_hair_log.dart';
import '../../data/services/extended_log_service.dart';
import '../../helper/analytics_helper.dart';
import '../../data/analytics/analytics_events.dart';
import '../../theme/app_colors.dart';

/// 2NH9 — skin and hair logging.
class SkinHairScreen extends StatefulWidget {
  const SkinHairScreen({super.key});

  @override
  State<SkinHairScreen> createState() => _SkinHairScreenState();
}

class _SkinHairScreenState extends State<SkinHairScreen> {
  final Map<String, int> severities = {};

  String get _today => Get.isRegistered<DailyLogController>()
      ? Get.find<DailyLogController>().todayDate
      : DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    final existing = Get.find<ExtendedLogService>().skinForDate(_today);
    if (existing != null) severities.addAll(existing.severities);
  }

  Future<void> _save() async {
    await Get.find<ExtendedLogService>().upsertSkinHair(SkinHairLog(
      id: '',
      date: _today,
      severities: Map<String, int>.from(severities),
      updatedAt: DateTime.now(),
    ));
    await AnalyticsHelper.track(AnalyticsEvents.skinHairLogged);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skin & hair saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Skin & hair'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ...SkinHairLog.chips.map((chip) {
            final level = severities[chip] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chip.replaceAll('_', ' '),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final n in [0, 1, 2, 3])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: level == n
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : null,
                              ),
                              onPressed: () => setState(() {
                                if (n == 0) {
                                  severities.remove(chip);
                                } else {
                                  severities[chip] = n;
                                }
                              }),
                              child: Text(n == 0 ? '—' : '$n'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
