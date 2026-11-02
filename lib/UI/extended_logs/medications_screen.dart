import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/daily_log_controller/daily_log_controller.dart';
import '../../data/models/daily_log/medication_log.dart';
import '../../data/services/extended_log_service.dart';
import '../../helper/analytics_helper.dart';
import '../../data/analytics/analytics_events.dart';
import '../../theme/app_colors.dart';

/// 2NH7 — medications and supplements (no dose advice).
class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<ExtendedLogService>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Medications & supplements'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAdd(context, svc),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Obx(() {
        if (svc.medications.isEmpty) {
          return const Center(
            child: Text(
              'Add medicines or supplements.\nThe app never advises on dose.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF6F8B7A)),
            ),
          );
        }
        final today = Get.isRegistered<DailyLogController>()
            ? Get.find<DailyLogController>().todayDate
            : DateTime.now().toIso8601String().substring(0, 10);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: svc.medications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final m = svc.medications[i];
            final taken = m.takenByDate[today] == true;
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFD8EDD4)),
              ),
              title: Text(
                m.name,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                [
                  if (m.doseText != null && m.doseText!.isNotEmpty) m.doseText!,
                  if (m.times.isNotEmpty) m.times.join(', '),
                  if (m.remind) 'Reminders on',
                ].join(' · '),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
              ),
              trailing: Checkbox(
                value: taken,
                activeColor: AppColors.primary,
                onChanged: (v) => svc.markTaken(m.id, today, v == true),
              ),
              onLongPress: () => svc.deleteMedication(m.id),
            );
          },
        );
      }),
    );
  }

  Future<void> _showAdd(BuildContext context, ExtendedLogService svc) async {
    final name = TextEditingController();
    final dose = TextEditingController();
    var remind = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add medication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: dose,
                decoration: const InputDecoration(
                  labelText: 'Dose (your note only)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remind me'),
                value: remind,
                onChanged: (v) => setLocal(() => remind = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await svc.upsertMedication(MedicationEntry(
        id: '',
        name: name.text.trim(),
        doseText: dose.text.trim().isEmpty ? null : dose.text.trim(),
        remind: remind,
        times: remind ? const ['09:00'] : const [],
        updatedAt: DateTime.now(),
      ));
      await AnalyticsHelper.track(AnalyticsEvents.medicationLogged);
    }
  }
}
