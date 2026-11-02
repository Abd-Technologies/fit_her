import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/services/tier_access_service.dart';
import '../../guided_workout/ui/adaptive_workout_sheet.dart';
import '../../guided_workout/ui/badge_share_sheet.dart';
import '../../recorded_library/ui/recorded_library_screen.dart';
import '../../theme/app_colors.dart';
import '../conditions/condition_modules_screen.dart';
import '../extended_logs/medications_screen.dart';
import '../extended_logs/period_flow_screen.dart';
import '../extended_logs/skin_hair_screen.dart';
import '../food_prefs/food_preferences_screen.dart';
import '../guidance_d23/guidance_hub_screen.dart';
import '../nutrition_d23/grocery_list_screen.dart';
import '../nutrition_d23/period_predictor_screen.dart';
import '../nutrition_d23/weekly_adjust_screen.dart';
import '../platform_d23/platform_hub_screen.dart';
import '../reports_d23/reports_hub_screen.dart';

/// Central entry for Delivery 2–3 Flutter surfaces (QA + profile link).
class Delivery23HubScreen extends StatelessWidget {
  const Delivery23HubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tier = Get.find<TierAccessService>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Personalization & more'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Obx(() => Text(
                'Tier: ${tier.tier.value.name} · library: ${tier.libraryAccess}',
                style: const TextStyle(color: Color(0xFF6F8B7A), fontSize: 12),
              )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AppTier.values
                .map(
                  (t) => ActionChip(
                    label: Text(t.name),
                    onPressed: () => tier.setTierOverride(t),
                  ),
                )
                .toList(),
          ),
          TextButton(
            onPressed: () => tier.setTierOverride(null),
            child: const Text('Clear tier override'),
          ),
          const Divider(),
          _section('Nutrition & hormones'),
          _tile('Food preferences', () => Get.to(() => const FoodPreferencesScreen())),
          _tile('Weekly plan adjust', () => Get.to(() => const WeeklyAdjustScreen())),
          _tile('Grocery list', () => Get.to(() => const GroceryListScreen())),
          _tile('Medications', () => Get.to(() => const MedicationsScreen())),
          _tile('Period flow', () => Get.to(() => const PeriodFlowScreen())),
          _tile('Skin & hair', () => Get.to(() => const SkinHairScreen())),
          _tile('Period predictor', () => Get.to(() => const PeriodPredictorScreen())),
          _tile('Reports', () => Get.to(() => const ReportsHubScreen())),
          _tile('Guidance (Luna tone, Ramadan, labs…)',
              () => Get.to(() => const GuidanceHubScreen())),
          _section('Movement'),
          _tile('Adaptive guided (picker / rest / fuel)', () {
            showAdaptiveWorkoutSheet(context);
          }),
          _tile('Share milestone badge', () => showBadgeShareSheet(context)),
          _tile('Recorded library', () => Get.to(() => const RecordedLibraryScreen())),
          _section('Conditions'),
          _tile('Condition modules',
              () => Get.to(() => const ConditionModulesScreen())),
          _section('Platform'),
          _tile('Growth & privacy',
              () => Get.to(() => const PlatformHubScreen())),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.primary,
          ),
        ),
      );

  Widget _tile(String title, VoidCallback onTap) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontFamily: 'Poppins')),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
