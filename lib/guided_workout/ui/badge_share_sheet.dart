import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/analytics/analytics_events.dart';
import '../../helper/analytics_helper.dart';
import '../../theme/app_colors.dart';
import '../guided_workout_controller.dart';

/// 2M11 — share a badge card with no health data.
Future<void> showBadgeShareSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _BadgeShareSheet(),
  );
}

class _BadgeShareSheet extends StatelessWidget {
  const _BadgeShareSheet();

  @override
  Widget build(BuildContext context) {
    final badges = Get.isRegistered<GuidedWorkoutController>()
        ? Get.find<GuidedWorkoutController>().unlockedBadges.toList()
        : <String>[];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Share a milestone',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Only the badge name is shared — no health data.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6F8B7A)),
          ),
          const SizedBox(height: 12),
          if (badges.isEmpty)
            const Text('Earn a badge first.')
          else
            ...badges.map(
              (b) => ListTile(
                title: Text(b.replaceAll('_', ' ')),
                trailing: const Icon(Icons.ios_share),
                onTap: () async {
                  await Share.share(
                    'I unlocked the ${b.replaceAll('_', ' ')} badge on Fit Her!',
                  );
                  await AnalyticsHelper.track(AnalyticsEvents.badgeShared,
                      props: {'badge': b});
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
