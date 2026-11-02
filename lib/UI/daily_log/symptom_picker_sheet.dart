import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/daily_log_controller/daily_log_controller.dart';
import '../../data/models/daily_log/symptom_log.dart';
import '../../theme/app_colors.dart';

Future<bool?> showSymptomPickerSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SymptomPickerSheet(),
  );
}

class _SymptomPickerSheet extends StatefulWidget {
  const _SymptomPickerSheet();

  @override
  State<_SymptomPickerSheet> createState() => _SymptomPickerSheetState();
}

class _SymptomPickerSheetState extends State<_SymptomPickerSheet> {
  final Map<String, int> severities = {};
  String? painBodyArea;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<DailyLogController>()) {
      final existing = Get.find<DailyLogController>().todaySymptoms.value;
      if (existing != null) {
        severities.addAll(existing.severities);
        painBodyArea = existing.painBodyArea;
      }
    }
  }

  Future<void> _save() async {
    if (severities.isEmpty || !Get.isRegistered<DailyLogController>()) return;
    final ok = await Get.find<DailyLogController>().saveSymptoms(
      severities: Map<String, int>.from(severities),
      painBodyArea: painBodyArea,
    );
    if (mounted) Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8EDD4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How do you feel today?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF163220),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a symptom, then set severity 1–3.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFF6F8B7A),
              ),
            ),
            const SizedBox(height: 16),
            ...SymptomLog.symptomKeys.map((key) {
              final label = SymptomLog.labels[key] ?? key;
              final sev = severities[key];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF163220),
                        ),
                      ),
                    ),
                    for (var i = 1; i <= 3; i++)
                      GestureDetector(
                        onTap: () => setState(() {
                          if (sev == i) {
                            severities.remove(key);
                          } else {
                            severities[key] = i;
                          }
                        }),
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(left: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sev == i
                                ? AppColors.primary
                                : const Color(0xFFF3F8F1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$i',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: sev == i
                                  ? Colors.white
                                  : const Color(0xFF4F6B5A),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            if (severities.containsKey('cramps') ||
                severities.containsKey('back_pain')) ...[
              const SizedBox(height: 8),
              const Text(
                'Pain area',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF163220),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SymptomLog.painAreas.map((a) {
                  final selected = painBodyArea == a;
                  return ChoiceChip(
                    label: Text(a.replaceAll('_', ' ')),
                    selected: selected,
                    onSelected: (_) => setState(() => painBodyArea = a),
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: severities.isEmpty ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: const Color(0xFFD8EDD4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save symptoms',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
