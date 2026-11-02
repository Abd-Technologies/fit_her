
import 'package:get/get.dart';

import 'extended_log_service.dart';

class RedFlagAlert {
  final String id;
  final String message;
  final String reviewTag;

  const RedFlagAlert({
    required this.id,
    required this.message,
    this.reviewTag = 'pending_doctor_review',
  });
}

/// 3NH6 — gentle red flag guidance (rules; wording pending doctor review).
class RedFlagService extends GetxService {
  List<RedFlagAlert> evaluate() {
    final alerts = <RedFlagAlert>[];
    if (!Get.isRegistered<ExtendedLogService>()) return alerts;
    final flow = Get.find<ExtendedLogService>().flowLogs.take(7).toList();
    final heavyDays =
        flow.where((f) => f.flow == 'heavy').length;
    if (heavyDays >= 4) {
      alerts.add(const RedFlagAlert(
        id: 'heavy_bleeding',
        message:
            'pending_doctor_review: Several heavy bleeding days can be worth mentioning to a doctor. This is not a diagnosis.',
      ));
    }
    final highPain = flow.where((f) => (f.pain ?? 0) >= 8).length;
    if (highPain >= 2) {
      alerts.add(const RedFlagAlert(
        id: 'high_pain',
        message:
            'pending_doctor_review: High pain across days may deserve clinical advice. Please seek care if worried.',
      ));
    }
    return alerts;
  }
}
