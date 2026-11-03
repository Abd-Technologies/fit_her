import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../data/api_provider/api_provider.dart';
import '../data/controllers/auth_controller/auth_controller.dart';
import '../values/constants.dart';

/// Can she download her progress PDF yet? Server rule: a starting entry
/// plus a weekly check-in 7+ days later (so the report shows real change).
class ProgressReportAccess {
  final bool canDownload;
  final String? reason;
  final DateTime? unlockOn;
  const ProgressReportAccess({required this.canDownload, this.reason, this.unlockOn});

  /// "Unlocks after your first weekly check-in (from 25 Oct)."
  String get lockedText {
    final base = reason ?? 'Your report unlocks after your first weekly check-in.';
    if (unlockOn == null) return base;
    return '$base Earliest: ${DateFormat('d MMM').format(unlockOn!)}.';
  }

  static Future<ProgressReportAccess> load() async {
    try {
      final token = Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
      final r = await Get.find<ApiProvider>()
          .getData('/users/progress-report/eligibility', headers: {'accessToken': token});
      final b = r.body;
      if (b is Map && b['status'] == '1' && b['data'] is Map) {
        final d = b['data'] as Map;
        return ProgressReportAccess(
          canDownload: d['canDownload'] == true,
          reason: d['reason']?.toString(),
          unlockOn: DateTime.tryParse('${d['unlockOn'] ?? ''}')?.toLocal(),
        );
      }
    } catch (_) {}
    // Unknown (offline / old server): don't block her.
    return const ProgressReportAccess(canDownload: true);
  }
}
