import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/daily_log_controller/daily_log_controller.dart';
import '../../data/services/daily_note_service.dart';
import '../../data/services/lab_report_service.dart';
import '../../data/services/ramadan_mode_service.dart';
import '../../data/services/red_flag_service.dart';
import '../../data/services/tone_personalization_service.dart';
import '../../theme/app_colors.dart';
import 'cycle_calendar_screen.dart';
import 'nutritionist_chat_screen.dart';

/// 3NH1–3NH7 guidance hub.
class GuidanceHubScreen extends StatelessWidget {
  const GuidanceHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tone = Get.find<TonePersonalizationService>();
    final notes = Get.find<DailyNoteService>();
    final ramadan = Get.find<RamadanModeService>();
    final labs = Get.find<LabReportService>();
    final flags = Get.find<RedFlagService>().evaluate();
    final today = Get.isRegistered<DailyLogController>()
        ? Get.find<DailyLogController>().todayDate
        : DateTime.now().toIso8601String().substring(0, 10);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Guidance & safety'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Tone', style: TextStyle(fontWeight: FontWeight.w700)),
          Obx(() => Wrap(
                spacing: 8,
                children: ['calm', 'high_energy']
                    .map(
                      (t) => ChoiceChip(
                        label: Text(t.replaceAll('_', ' ')),
                        selected: tone.tone.value == t,
                        onSelected: (_) => tone.setTone(t),
                      ),
                    )
                    .toList(),
              )),
          const SizedBox(height: 8),
          Obx(() => Text(
                tone.rewrite(
                  'A calm note for your phase today.',
                  highEnergy: 'High-energy pep: own your phase today!',
                ),
              )),
          const Divider(height: 32),
          const Text('Daily note', style: TextStyle(fontWeight: FontWeight.w700)),
          TextFormField(
            initialValue: notes.forDate(today) ?? '',
            maxLength: 280,
            onChanged: (v) => notes.save(today, v),
            decoration: const InputDecoration(
              hintText: 'Private note for today',
              border: OutlineInputBorder(),
            ),
          ),
          const Divider(height: 32),
          Obx(() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ramadan mode'),
                value: ramadan.enabled.value,
                activeColor: AppColors.primary,
                onChanged: (v) => ramadan.setEnabled(
                  v,
                  start: DateTime.now().toIso8601String().substring(0, 10),
                  end: DateTime.now()
                      .add(const Duration(days: 30))
                      .toIso8601String()
                      .substring(0, 10),
                ),
              )),
          if (ramadan.enabled.value)
            Row(
              children: [
                TextButton(
                  onPressed: () => ramadan.markDay(today, 'fasted'),
                  child: const Text('Mark fasted'),
                ),
                TextButton(
                  onPressed: () => ramadan.markDay(today, 'missed'),
                  child: const Text('Mark missed'),
                ),
              ],
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('AI Nutritionist'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Get.to(() => const NutritionistChatScreen()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cycle calendar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Get.to(() => const CycleCalendarScreen()),
          ),
          const Divider(height: 32),
          const Text('Red flags', style: TextStyle(fontWeight: FontWeight.w700)),
          if (flags.isEmpty)
            const Text('No rule triggers right now.')
          else
            ...flags.map((f) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: Text(f.message, style: const TextStyle(fontSize: 13)),
                )),
          const Divider(height: 32),
          const Text('Lab upload (stub)',
              style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: LabReportService.markers
                .map(
                  (m) => ActionChip(
                    label: Text('Sample $m'),
                    onPressed: () async {
                      await labs.addSampleParse(
                        marker: m,
                        value: m == 'TSH' ? 2.1 : 30,
                        unit: m == 'TSH' ? 'mIU/L' : 'ng/mL',
                      );
                    },
                  ),
                )
                .toList(),
          ),
          Obx(() => Column(
                children: labs.values
                    .take(6)
                    .map((v) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${v.marker}: ${v.value} ${v.unit}'),
                          subtitle: Text(labs.explanation(v),
                              style: const TextStyle(fontSize: 11)),
                        ))
                    .toList(),
              )),
        ],
      ),
    );
  }
}
