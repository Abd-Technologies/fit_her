import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/food_db_service.dart';
import '../../data/services/food_diary_service.dart';
import '../../data/services/tier_access_service.dart';
import '../../helper/analytics_helper.dart';
import '../../data/analytics/analytics_events.dart';
import '../../theme/app_colors.dart';
import 'food_search_sheet.dart';

/// 1NH8–1NH10 meal photo logging (local matcher until recognition API).
class MealPhotoLogScreen extends StatefulWidget {
  const MealPhotoLogScreen({super.key});

  @override
  State<MealPhotoLogScreen> createState() => _MealPhotoLogScreenState();
}

class _MealPhotoLogScreenState extends State<MealPhotoLogScreen> {
  String? _photoPath;
  String _hint = '';
  FoodItem? _proposed;
  bool _saving = false;

  Future<void> _pick(ImageSource source) async {
    final tier = Get.find<TierAccessService>();
    if (!tier.canLogMealPhoto) {
      if (tier.shouldShowUpgrade('meal_photo_cap')) {
        await AnalyticsHelper.track(AnalyticsEvents.upgradeTap, props: {
          'reason': 'meal_photo_cap',
        });
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Photo limit reached'),
            content: Text(
              'Free includes ${Get.find<TierAccessService>().freePhotoCap} meal photos per month. '
              'Upgrade to Plus for unlimited logging.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Plans screen route varies; caller can navigate.
                },
                child: const Text('See Plus'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (file == null) return;
    setState(() {
      _photoPath = file.path;
      _hint = file.name.replaceAll(RegExp(r'[_\-.]'), ' ');
      _proposed = Get.find<FoodDbService>().matchFromHint(_hint) ??
          Get.find<FoodDbService>().foods.firstOrNull;
    });
  }

  Future<void> _confirm() async {
    if (_proposed == null || _saving) return;
    setState(() => _saving = true);
    final diary = Get.find<FoodDiaryService>();
    final entry = await diary.addFromPhotoHint(
      hint: _proposed!.nameEn,
      photoPath: _photoPath,
    );
    setState(() => _saving = false);
    if (!mounted) return;
    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monthly photo cap reached')),
      );
      return;
    }
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final tier = Get.find<TierAccessService>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Log meal photo',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Color(0xFF163220),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF163220)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() {
              final left = tier.photosRemaining;
              return Text(
                tier.isPlus
                    ? 'Plus · unlimited photos'
                    : 'Free · $left photos left this month',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Color(0xFF6F8B7A),
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_proposed != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8F1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD8EDD4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _proposed!.nameEn,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF163220),
                      ),
                    ),
                    Text(
                      '${_proposed!.serving} · ${_proposed!.calories} kcal',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFF6F8B7A),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showFoodSearchSheet(context);
                        if (picked != null) {
                          setState(() => _proposed = picked);
                        }
                      },
                      child: const Text('Change dish'),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _saving ? 'Saving…' : 'Confirm meal',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'Take or pick a photo to estimate your meal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFF6F8B7A),
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

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
