import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/Repos/cycle_repo/cycle_data_repository.dart';
import 'package:fitness_zone_2/data/Repos/home_repo/home_repo.dart';
import 'package:fitness_zone_2/data/models/get_user_plan/get_workout_user_plan_details.dart';
import 'package:fitness_zone_2/data/services/cycle_engine.dart';
import 'package:fitness_zone_2/data/services/recommendation_service.dart';
import 'package:fitness_zone_2/theme/app_colors.dart';
import 'package:fitness_zone_2/UI/plans_module/all_plans.dart';
import 'package:fitness_zone_2/values/constants.dart';
import 'package:fitness_zone_2/values/my_imgs.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:fitness_zone_2/widgets/recommended_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class RecommendedSlotsScreen extends StatefulWidget {
  const RecommendedSlotsScreen({super.key});

  @override
  State<RecommendedSlotsScreen> createState() => _RecommendedSlotsScreenState();
}

class _RecommendedSlotsScreenState extends State<RecommendedSlotsScreen> {
  String? _currentPhase;
  List<Slot> _slots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authController = Get.find<AuthController>();
    final token = authController.sharedPreferences.getString(Constants.accessToken) ?? '';
    final userId = authController.sharedPreferences.getString(Constants.userId) ?? '';

    String? phase;
    List<Slot> filtered = [];

    // The network calls below can no longer hang or throw on a bad
    // connection (api_provider.dart now times out and returns a Response
    // either way) — but parsing the responses (DateTime.parse, model
    // mapping) still can. Wrapping the whole thing means any failure here
    // degrades to an empty list instead of leaving the spinner stuck with
    // no feedback; the `finally` always turns it off.
    try {
      // 1. Load cycle phase
      final cycleRepo = Get.find<CycleDataRepository>();
      final cycleResponse = await cycleRepo.getCycleData(accessToken: token);

      if (cycleResponse.body != null &&
          cycleResponse.body['status'] == '1' &&
          cycleResponse.body['data'] != null &&
          cycleResponse.body['data']['dataProvided'] == 1 &&
          cycleResponse.body['data']['lastPeriodDate'] != null) {
        final data = cycleResponse.body['data'];
        final cycleInfo = CycleEngine.calculate(
          lastPeriodDate: DateTime.parse(data['lastPeriodDate']),
          cycleLength: data['averageCycleLength'] ?? 28,
        );
        if (cycleInfo != null) {
          phase = cycleInfo.phase;
        }
      }

      // 2. Load all slots
      final homeRepo = Get.find<HomeRepo>();
      final slotsResponse = await homeRepo.getUserPlanDetailsWorkout(
        accessToken: token,
        planId: '0',
        userId: userId,
        showSlots: true,
      );

      List<Slot> allSlots = [];
      if (slotsResponse.body != null && slotsResponse.body['status'] == '1' && slotsResponse.body['data'] != null) {
        final data = slotsResponse.body['data'];
        if (data['trainerSlots'] is List) {
          final trainerSlots = (data['trainerSlots'] as List).whereType<Map<String, dynamic>>().map((ts) => TrainerSlot.fromJson(ts)).toList();
          for (final ts in trainerSlots) {
            allSlots.addAll(ts.slots);
          }
        }
      }

      // 3. Filter recommended or take first 5
      if (phase != null) {
        filtered = RecommendationService.filterRecommended<Slot>(
          allSlots,
          (slot) => slot.type,
          phase,
        );
      } else {
        filtered = allSlots.take(5).toList();
      }
    } catch (e) {
      debugPrint('RecommendedSlotsScreen · _loadData failed: $e');
      filtered = [];
    } finally {
      if (mounted) {
        setState(() {
          _currentPhase = phase;
          _slots = filtered;
          _isLoading = false;
        });
      }
    }
  }

  void _showSubscribeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Subscribe to Join',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Get unlimited access to all live classes with expert trainers.',
          style: TextStyle(
            fontSize: 13.sp,
            color: AppColors.textTertiary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Maybe Later',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textHint,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Get.to(() => OurPlansScreen());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            ),
            child: Text(
              'View Plans',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: HelpingWidgets().appBarWidget(() {
        Get.back();
      }, text: "Recommended for You"),
      body: _isLoading
          ? const Center(child: FhLoader())
          : _slots.isEmpty
              ? _buildEmptyState(textTheme)
              : ListView(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  children: [
                    SizedBox(height: 8.h),
                    Text(
                      _currentPhase != null
                          ? 'Based on your ${_currentPhase![0].toUpperCase()}${_currentPhase!.substring(1)} phase today'
                          : 'Top classes for you today',
                      style: textTheme.bodySmall!.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ...List.generate(_slots.length, (index) {
                      final slot = _slots[index];
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: _buildSlotCard(slot, textTheme),
                      );
                    }),
                  ],
                ),
    );
  }

  Widget _buildSlotCard(Slot slot, TextTheme textTheme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 8,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RecommendedBadge(),
                SizedBox(height: 6.h),
                Text(
                  slot.type ?? 'N/A',
                  style: textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${slot.start} - ${slot.end}',
                  style: textTheme.bodySmall!.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary,
                      backgroundImage: AssetImage(MyImgs.logo),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${slot.trainer?.firstName ?? ''} ${slot.trainer?.lastName ?? ''}'.trim(),
                      style: textTheme.bodySmall!.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          SizedBox(
            height: 40.h,
            child: ElevatedButton(
              onPressed: _showSubscribeDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
              ),
              child: Text(
                'Join Now',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: const BoxDecoration(
                color: AppColors.cardGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center_outlined,
                size: 36.sp,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'No classes available right now',
              style: textTheme.titleSmall!.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              'Check back later for new sessions',
              style: textTheme.bodySmall!.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
