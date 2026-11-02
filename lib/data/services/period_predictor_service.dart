import 'package:get/get.dart';

import 'extended_log_service.dart';

/// 2NH14 — next period as a range + what to expect (rules/stats, no AI).
class PeriodPrediction {
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final int expectedLengthDays;
  final String expectedHeaviness;
  final List<String> usualSymptoms;
  final bool irregular;
  final bool sharpChangePrompt;
  final String summary;

  const PeriodPrediction({
    required this.rangeStart,
    required this.rangeEnd,
    required this.expectedLengthDays,
    required this.expectedHeaviness,
    required this.usualSymptoms,
    required this.irregular,
    required this.sharpChangePrompt,
    required this.summary,
  });
}

class PeriodPredictorService extends GetxService {
  PeriodPrediction? predict() {
    if (!Get.isRegistered<ExtendedLogService>()) return null;
    final records = Get.find<ExtendedLogService>().buildPeriodRecords();
    if (records.isEmpty) return null;

    final recent = records.take(3).toList();
    final lengths = recent.map((r) => r.lengthDays).toList();
    final avgLen =
        (lengths.reduce((a, b) => a + b) / lengths.length).round().clamp(3, 8);

    final gaps = <int>[];
    for (var i = 0; i < recent.length - 1; i++) {
      final a = DateTime.tryParse(recent[i].startDate);
      final b = DateTime.tryParse(recent[i + 1].startDate);
      if (a != null && b != null) {
        gaps.add(a.difference(b).inDays.abs());
      }
    }
    final cycle = gaps.isEmpty
        ? 28
        : (gaps.reduce((a, b) => a + b) / gaps.length).round();
    final irregular = gaps.any((g) => (g - cycle).abs() >= 7) || cycle < 21 || cycle > 35;

    final lastStart = DateTime.tryParse(recent.first.startDate) ?? DateTime.now();
    final nextCenter = lastStart.add(Duration(days: cycle));
    final pad = irregular ? 4 : 2;
    final heaviness = recent.first.heaviness;

    var sharp = false;
    if (recent.length >= 2) {
      final prevH = recent[1].heaviness;
      if (heaviness == 'heavy' && prevH != 'heavy') sharp = true;
      if (gaps.isNotEmpty && gaps.first > cycle + 10) sharp = true;
    }

    final symptoms = <String>[];
    for (final d in recent.first.days) {
      if ((d.pain ?? 0) >= 5) symptoms.add('cramps');
    }
    if (heaviness == 'heavy') symptoms.add('heavier flow');

    return PeriodPrediction(
      rangeStart: nextCenter.subtract(Duration(days: pad)),
      rangeEnd: nextCenter.add(Duration(days: pad)),
      expectedLengthDays: avgLen,
      expectedHeaviness: heaviness,
      usualSymptoms: symptoms.toSet().toList(),
      irregular: irregular,
      sharpChangePrompt: sharp,
      summary: irregular
          ? 'Your cycles vary — expect a wider window, not an exact day.'
          : 'Based on your last ${recent.length} cycle(s).',
    );
  }
}
