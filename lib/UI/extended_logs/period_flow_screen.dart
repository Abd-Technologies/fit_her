import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/daily_log_controller/daily_log_controller.dart';
import '../../data/models/daily_log/period_flow_log.dart';
import '../../data/services/extended_log_service.dart';
import '../../helper/analytics_helper.dart';
import '../../data/analytics/analytics_events.dart';
import '../../theme/app_colors.dart';

/// 2NH8 — period flow and spotting logging.
class PeriodFlowScreen extends StatefulWidget {
  const PeriodFlowScreen({super.key});

  @override
  State<PeriodFlowScreen> createState() => _PeriodFlowScreenState();
}

class _PeriodFlowScreenState extends State<PeriodFlowScreen> {
  String flow = 'light';
  bool clots = false;
  int pain = 3;

  String get _today => Get.isRegistered<DailyLogController>()
      ? Get.find<DailyLogController>().todayDate
      : DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    final existing = Get.find<ExtendedLogService>().flowForDate(_today);
    if (existing != null) {
      flow = existing.flow;
      clots = existing.clots;
      pain = existing.pain ?? 3;
    }
  }

  Future<void> _save() async {
    await Get.find<ExtendedLogService>().upsertFlow(PeriodFlowLog(
      id: '',
      date: _today,
      flow: flow,
      clots: clots,
      pain: pain,
      updatedAt: DateTime.now(),
    ));
    await AnalyticsHelper.track(AnalyticsEvents.periodFlowLogged);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flow logged for today')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<ExtendedLogService>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Period flow'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Today\'s flow',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: PeriodFlowLog.flowOptions.map((f) {
              return ChoiceChip(
                label: Text(f),
                selected: flow == f,
                onSelected: (_) => setState(() => flow = f),
                selectedColor: AppColors.primary.withValues(alpha: 0.25),
              );
            }).toList(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Clots'),
            value: clots,
            onChanged: (v) => setState(() => clots = v),
          ),
          Text(
            'Pain · $pain',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
          Slider(
            value: pain.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => pain = v.round()),
          ),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Save today',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Period records',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            // touch list so Obx rebuilds
            final _ = svc.flowLogs.length;
            final records = svc.buildPeriodRecords();
            if (records.isEmpty) {
              return const Text(
                'No periods grouped yet.',
                style: TextStyle(color: Color(0xFF6F8B7A)),
              );
            }
            return Column(
              children: records
                  .take(6)
                  .map(
                    (r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${r.startDate} → ${r.endDate}'),
                      subtitle: Text(
                        '${r.lengthDays} days · ${r.heaviness}',
                      ),
                    ),
                  )
                  .toList(),
            );
          }),
        ],
      ),
    );
  }
}
