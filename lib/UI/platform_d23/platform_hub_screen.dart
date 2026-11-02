import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/ai_cost_monitor_service.dart';
import '../../data/services/community_streak_service.dart';
import '../../data/services/content_poster_service.dart';
import '../../data/services/gift_group_plans_service.dart';
import '../../data/services/health_sync_stub_service.dart';
import '../../data/services/locale_pref_service.dart';
import '../../data/services/points_service.dart';
import '../../data/services/privacy_lock_service.dart';
import '../../data/services/referral_service.dart';
import '../../data/services/remote_config_service.dart';
import '../../guided_workout/ui/cast_workout_screen.dart';
import '../../theme/app_colors.dart';
import '../progress_photos/progress_photo_timeline_screen.dart';

/// 2P1/2/4/6/7 + 3P1–7 platform hub.
class PlatformHubScreen extends StatelessWidget {
  const PlatformHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final privacy = Get.find<PrivacyLockService>();
    final locale = Get.find<LocalePrefService>();
    final health = Get.find<HealthSyncStubService>();
    final points = Get.find<PointsService>();
    final referral = Get.find<ReferralService>();
    final community = Get.find<CommunityStreakService>()..refreshDemo();
    final cost = Get.find<AiCostMonitorService>();
    final poster = Get.find<ContentPosterService>();
    final gifts = Get.find<GiftGroupPlansService>();
    final remote = Get.find<RemoteConfigService>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Growth & privacy'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Obx(() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Privacy lock'),
                subtitle: const Text('PIN gate for health screens'),
                value: privacy.enabled.value,
                activeColor: AppColors.primary,
                onChanged: (v) async {
                  if (v) {
                    await privacy.setEnabled(true, pin: '1234');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN set to 1234 (demo)')),
                      );
                    }
                  } else {
                    await privacy.setEnabled(false);
                  }
                },
              )),
          Obx(() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Discreet notifications'),
                value: privacy.discreetNotifications.value,
                onChanged: privacy.setDiscreet,
              )),
          const Divider(),
          Text(locale.t('Language', ur: 'زبان', romanUr: 'Zaban')),
          Obx(() => Wrap(
                spacing: 8,
                children: [
                  ('en', 'English'),
                  ('ur', 'Urdu'),
                  ('ur_Latn', 'Roman Urdu'),
                ]
                    .map(
                      (e) => ChoiceChip(
                        label: Text(e.$2),
                        selected: locale.localeCode.value == e.$1,
                        onSelected: (_) => locale.setLocale(e.$1),
                      ),
                    )
                    .toList(),
              )),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Health sync (stub)'),
            subtitle: Obx(() => Text(
                  health.permissionGranted.value
                      ? 'Steps ${health.steps.value} · Sleep ${health.sleepHours.value}h · HR ${health.heartRate.value}'
                      : 'Not connected',
                )),
            trailing: TextButton(
              onPressed: () async {
                await health.requestPermission();
                await health.mockPull();
              },
              child: const Text('Pull'),
            ),
          ),
          const Divider(),
          Obx(() => Text(
                'Points: ${points.balance.value}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              )),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('+10 streak'),
                onPressed: () => points.award('streak', 10),
              ),
              ...PointsService.redeemCatalog.map(
                (e) => ActionChip(
                  label: Text('${e.$1} (${e.$2})'),
                  onPressed: () => points.redeem(e.$1, e.$2),
                ),
              ),
            ],
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Referral ${referral.code.value}'),
            subtitle: Obx(() => Text(
                  'Pending rewards: ${referral.pendingRewards.value} · Friends: ${referral.friendsJoined.value}',
                )),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: referral.inviteLink),
                );
                await referral.markShared();
              },
            ),
          ),
          TextButton(
            onPressed: referral.simulateFriendJoined,
            child: const Text('Simulate friend joined'),
          ),
          Obx(() => Text(
                'Community today: ${community.membersLoggedToday.value} logged · ${community.membersTrainedToday.value} trained',
              )),
          const Divider(),
          Obx(() => Text(
                'AI cost units: ${cost.total}${cost.overThreshold ? " · ALERT" : ""}',
              )),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Draft education post'),
                onPressed: () => poster.draftEducationalPost('hormones'),
              ),
              ActionChip(
                label: const Text('Weekly community prompt'),
                onPressed: poster.draftWeeklyPrompt,
              ),
            ],
          ),
          Obx(() => Column(
                children: poster.drafts
                    .take(3)
                    .map((d) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(d['body']?.toString() ?? ''),
                          subtitle: Text(d['status']?.toString() ?? ''),
                        ))
                    .toList(),
              )),
          const Divider(),
          const Text('Gift & group', style: TextStyle(fontWeight: FontWeight.w700)),
          TextButton(
            onPressed: () => gifts.giftPlan(
              recipientPhone: '+920000000000',
              plan: 'mother_daughter',
            ),
            child: const Text('Gift mother & daughter plan (stub)'),
          ),
          ...gifts.groupPlans.map(
            (g) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(g['name'] ?? ''),
              subtitle: Text('${g['seats']} seats'),
              trailing: TextButton(
                onPressed: () => gifts.joinGroupStub(g['id'] ?? ''),
                child: const Text('Join'),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Progress photos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Get.to(() => const ProgressPhotoTimelineScreen()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cast workout (large layout)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Get.to(() => const CastWorkoutScreen()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Free website tools'),
            onTap: () => launchUrl(
              Uri.parse('https://fither.app/tools'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const Divider(),
          const Text('Remote controls (2P5)',
              style: TextStyle(fontWeight: FontWeight.w700)),
          Obx(() => Text('Flags: ${remote.config['featureFlags']}')),
          TextButton(
            onPressed: () => remote.applyOverride({
              'mealPhotoCapFree': 15,
            }),
            child: const Text('Override free photo cap → 15'),
          ),
          TextButton(
            onPressed: remote.clearOverride,
            child: const Text('Clear remote override'),
          ),
        ],
      ),
    );
  }
}
