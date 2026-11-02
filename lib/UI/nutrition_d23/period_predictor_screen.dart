import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/services/period_predictor_service.dart';
import '../../helper/analytics_helper.dart';
import '../../data/analytics/analytics_events.dart';
import '../../theme/app_colors.dart';

/// 2NH14 — period predictor: range + what to expect.
class PeriodPredictorScreen extends StatefulWidget {
  const PeriodPredictorScreen({super.key});

  @override
  State<PeriodPredictorScreen> createState() => _PeriodPredictorScreenState();
}

class _PeriodPredictorScreenState extends State<PeriodPredictorScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsHelper.track(AnalyticsEvents.periodPredictorViewed);
  }

  @override
  Widget build(BuildContext context) {
    final pred = Get.find<PeriodPredictorService>().predict();
    final fmt = DateFormat('d MMM');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('What to expect'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: pred == null
            ? const Text(
                'Log flow for a few cycles to unlock a prediction range.',
                style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF6F8B7A)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F8F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Next period window',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${fmt.format(pred.rangeStart)} – ${fmt.format(pred.rangeEnd)}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF163220),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(pred.summary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Likely length: ~${pred.expectedLengthDays} days'),
                  Text('Likely flow: ${pred.expectedHeaviness}'),
                  if (pred.usualSymptoms.isNotEmpty)
                    Text('Often with: ${pred.usualSymptoms.join(", ")}'),
                  if (pred.irregular) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Your pattern is irregular — the window is wider on purpose.',
                      style: TextStyle(color: Color(0xFF6F8B7A)),
                    ),
                  ],
                  if (pred.sharpChangePrompt) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'pending_doctor_review: A sharp change in your pattern can be worth mentioning to a doctor. This is not a diagnosis.',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'Reminder: we\'ll nudge you a few days before the window.',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontFamily: 'Poppins',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
