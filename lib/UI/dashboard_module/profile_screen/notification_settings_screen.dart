import '../../../helper/analytics_helper.dart';
import 'package:fitness_zone_2/data/api_provider/api_provider.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/Repos/checkin_repo/checkin_repository.dart';
import 'package:fitness_zone_2/data/services/notification_scheduler.dart';
import 'package:fitness_zone_2/theme/app_colors.dart';
import 'package:fitness_zone_2/values/constants.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:fitness_zone_2/widgets/toasts.dart';
import 'package:fitness_zone_2/data/controllers/consultation_controller/consultation_controller.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/UI/free_trail/trial_onboarding_screen.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

const List<Map<String, String>> _kTimeBlocks = [
  {'value': 'morning',   'label': 'Morning',    'sub': '6 AM – 11 AM',          'icon': '🌅'},
  {'value': 'afternoon', 'label': 'Afternoon',  'sub': '11 AM – 4 PM',          'icon': '☀️'},
  {'value': 'evening',   'label': 'Evening',    'sub': '4 PM – 8 PM',           'icon': '🌇'},
  {'value': 'night',     'label': 'Night',      'sub': '8 PM – 11 PM',          'icon': '🌙'},
  {'value': 'all',       'label': 'All Classes','sub': 'Notify for every class', 'icon': '🔔'},
];

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _isLoading = true;

  int _morningNudge = 1;
  int _classPrep = 1;
  int _classStart = 1;
  int _missedRecovery = 1;
  int _trainerCancelled = 1;
  int _weeklyCheckin = 1;
  int _dietUpdates = 1;
  String _quietStart = '23:30';
  String _quietEnd = '07:00';
  String _timeBlock = 'all';

  // ── Workout reminders ────────────────────────────────────────────────
  // Her picked class times ("8:00 AM"); empty = reminders for ALL classes.
  List<String> _pickedTimes = [];
  bool _allByChoice = false; // she chose "All classes" herself
  bool _pickedLoaded = false;
  bool _showWorkout = false; // workout / combined package, or a trial
  bool _isTrial = false;
  bool _savingMode = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadWorkoutReminders();
  }

  Future<void> _loadWorkoutReminders() async {
    try {
      if (Get.isRegistered<HomeController>()) {
        final home = Get.find<HomeController>();
        _isTrial = home.isFreeTrialUser.value;
        final plans = home.userHomeData?.userAllPlans ?? const [];
        final workout = plans.any((p) =>
            (p.categoryId == 2 || p.categoryId == 3) && p.remainingDays > 0);
        _showWorkout = workout || _isTrial;
      }
      final p = await Get.find<ConsultationController>().loadProfile();
      final ws = p?.workoutSection ?? const {};
      final times = ((ws['preferredTimes'] as List?) ?? const [])
          .map((e) => '$e')
          .where((e) => e.isNotEmpty)
          .toList();
      final ids = (ws['preferredSlotIds'] as List?) ?? const [];
      if (mounted) {
        setState(() {
          _allByChoice = ws['reminderMode'] == 'all';
          // Old picks saved only as ids still count as "my class times".
          _pickedTimes = times.isEmpty && ids.isNotEmpty ? ['Your picked classes'] : times;
          _pickedLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _pickedLoaded = true);
    }
  }

  /// Opens the same "Tell us when you're free" picker + week view.
  Future<void> _openTimePicker() async {
    await Get.to<bool>(
      () => const TrialOnboardingScreen(
        setupMode: true,
        timesOnly: true,
        canSkip: true,
      ),
      fullscreenDialog: true,
    );
    await _loadWorkoutReminders();
  }

  /// "All classes": asks first, then clears her picks so she's reminded
  /// before every class. Saved as her own choice (reminderMode 'all'), so
  /// we never nag her to pick times again.
  Future<void> _chooseAllClasses() async {
    if (_savingMode) return;
    if (_pickedTimes.isEmpty && _allByChoice) return; // already her choice
    // Only ask when there are times to remove.
    final yes = _pickedTimes.isEmpty ? true : await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remind you for every class?',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Your reminder times (${_pickedTimes.join(' · ')}) will be removed and '
          "you'll get a reminder before every class.\n\n"
          'You can pick your times again here anytime.',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Keep my times',
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Yes, all classes',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _savingMode = true);
    try {
      final consult = Get.find<ConsultationController>();
      final p = await consult.loadProfile();
      final ws = Map<String, dynamic>.from(p?.workoutSection ?? {});
      ws['preferredSlotIds'] = <int>[];
      ws['preferredTimes'] = <String>[];
      ws['oneTimeReminders'] = <Map<String, dynamic>>[];
      ws['reminderMode'] = 'all'; // her choice, not the default
      final ok = await consult.patchProfile({'workoutSection': ws});
      if (ok) AnalyticsHelper.classReminderSet('all_classes');
      if (ok && mounted) {
        setState(() {
          _pickedTimes = [];
          _allByChoice = true;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _savingMode = false);
  }

  Future<void> _loadPreferences() async {
    final authController = Get.find<AuthController>();
    final token =
        authController.sharedPreferences.getString(Constants.accessToken) ?? '';
    final apiProvider = Get.find<ApiProvider>();

    final response = await apiProvider.getData(
      '/users/notification_preferences',
      headers: {'accessToken': token},
    );

    if (response.body != null &&
        response.body['status'] == '1' &&
        response.body['data'] != null) {
      final data = response.body['data'];
      if (mounted) {
        setState(() {
          _morningNudge = data['morningNudge'] ?? 1;
          // Class reminders can't be turned off for now (always on).
          _classPrep = 1;
          // "Class is live" can't be turned off (always on).
          _classStart = 1;
          _missedRecovery = data['missedRecovery'] ?? 1;
          _trainerCancelled = data['trainerCancelled'] ?? 1;
          _weeklyCheckin = data['weeklyCheckin'] ?? 1;
          _dietUpdates = data['dietUpdates'] ??
              (authController.sharedPreferences.getBool('pref_dietUpdates') == false ? 0 : 1);
          _quietStart = data['quietStart'] ?? '23:30';
          _quietEnd = data['quietEnd'] ?? '07:00';
          _timeBlock = data['timeBlock'] ?? 'all';
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        final authController = Get.find<AuthController>();
        setState(() {
          _dietUpdates = authController.sharedPreferences.getBool('pref_dietUpdates') == false ? 0 : 1;
          _isLoading = false;
        });
      }
    }
  }

  /// Saves on the server and reschedules reminders. True when the server saved it.
  Future<bool> _savePreferences() async {
    final authController = Get.find<AuthController>();
    final token =
        authController.sharedPreferences.getString(Constants.accessToken) ?? '';
    final apiProvider = Get.find<ApiProvider>();

    final body = {
      'morningNudge': _morningNudge,
      'classPrep': 1, // always on for now
      'classStart': 1, // always on
      'missedRecovery': _missedRecovery,
      'trainerCancelled': _trainerCancelled,
      'weeklyCheckin': _weeklyCheckin,
      'dietUpdates': _dietUpdates,
      'quietStart': _quietStart,
      'quietEnd': _quietEnd,
      'timeBlock': _timeBlock,
    };

    // Persist timeBlock & diet preference locally
    authController.sharedPreferences.setString(Constants.timeBlock, _timeBlock);
    authController.sharedPreferences.setBool('pref_dietUpdates', _dietUpdates == 1);

    var saved = false;
    try {
      final r = await apiProvider.postData(
        '/users/notification_preferences',
        body: body,
        headers: {'accessToken': token},
      );
      saved = r.statusCode == 200 && !(r.body is Map && r.body['status'] == '0');
    } catch (_) {}

    // Check weekly check-in status for reschedule
    bool weeklyDone = false;
    final checkinRepo = Get.find<CheckinRepository>();
    dynamic weeklyResponse;
    try {
      weeklyResponse = await checkinRepo.getWeeklyCheckinsRecent(accessToken: token);
    } catch (_) {}
    if (weeklyResponse != null &&
        weeklyResponse.body != null &&
        weeklyResponse.body['status'] == '1' &&
        weeklyResponse.body['data'] is List) {
      final checkins = weeklyResponse.body['data'] as List;
      if (checkins.isNotEmpty) {
        final latest = checkins.first;
        final weekDate = latest['weekDate'] as String?;
        if (weekDate != null) {
          final now = DateTime.now();
          final monday = now.subtract(Duration(days: now.weekday - 1));
          final mondayStr =
              '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
          weeklyDone = weekDate == mondayStr;
        }
      }
    }

    await NotificationScheduler.rescheduleAll(
      prefs: body,
      weeklyCheckinDone: weeklyDone,
    );
    return saved;
  }

  void _onToggle(String key, bool value) {
    setState(() {
      switch (key) {
        case 'morningNudge':
          _morningNudge = value ? 1 : 0;
          break;
        case 'classPrep':
          _classPrep = value ? 1 : 0;
          break;
        case 'classStart':
          _classStart = value ? 1 : 0;
          break;
        case 'missedRecovery':
          _missedRecovery = value ? 1 : 0;
          break;
        case 'trainerCancelled':
          _trainerCancelled = value ? 1 : 0;
          break;
        case 'weeklyCheckin':
          _weeklyCheckin = value ? 1 : 0;
          break;
        case 'dietUpdates':
          _dietUpdates = value ? 1 : 0;
          break;
      }
    });
    _savePreferences();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final parts = (isStart ? _quietStart : _quietEnd).split(':');
    final initial =
        TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _quietStart = formatted;
        } else {
          _quietEnd = formatted;
        }
      });
      final saved = await _savePreferences();
      if (!mounted) return;
      final from = _formatTimeDisplay(_quietStart);
      final to = _formatTimeDisplay(_quietEnd);
      if (saved) {
        FhToast.show(FhToastKind.success, 'Quiet hours set',
            sub: 'No reminders from $from to $to');
      } else {
        CustomToast.warnToast("Couldn't save quiet hours",
            sub: 'Check your internet and try again');
      }
    }
  }

  String _formatTimeDisplay(String time24) {
    final parts = time24.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HelpingWidgets().appBarWidget(() {
        Get.back();
      }, text: "Notifications"),
      body: _isLoading
          ? const Center(
              child: FhLoader())
          : SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
                children: [
                  Text(
                    'Notification Types',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildToggleRow(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Daily Insights',
                    description: 'A daily nudge at 1 PM with your energy forecast',
                    value: _morningNudge == 1,
                    onChanged: (v) => _onToggle('morningNudge', v),
                  ),
                  _buildToggleRow(
                    icon: Icons.calendar_today_outlined,
                    title: 'Weekly Check-in',
                    description:
                        'Sunday reminder to update your weight and trends',
                    value: _weeklyCheckin == 1,
                    onChanged: (v) => _onToggle('weeklyCheckin', v),
                  ),
                  _buildToggleRow(
                    icon: Icons.restaurant_menu_outlined,
                    title: 'Diet Plan Updates',
                    description:
                        'Alerts when your nutritionist assigns or updates your meal plan',
                    value: _dietUpdates == 1,
                    onChanged: (v) => _onToggle('dietUpdates', v),
                  ),
                  SizedBox(height: 24.h),

                  // ── Workout Reminders ────────────────────────────────────
                  // (Replaces "Preferred Class Time": her time of day is
                  // still saved, but reminders follow her picked times.)
                  if (_showWorkout) ...[
                    Text(
                      'Workout Reminders',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Remind me 15 minutes before',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.sp,
                        color: AppColors.textHint,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    if (!_pickedLoaded)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2),
                        ),
                      )
                    else ...[
                      _modeCard(
                        selected: _pickedTimes.isNotEmpty,
                        title: 'My class times',
                        badge: 'Recommended',
                        description: _pickedTimes.isEmpty
                            ? 'Only the times you pick (up to 2)'
                            : _pickedTimes.join('  ·  '),
                        trailing: _pickedTimes.isEmpty ? 'Pick ›' : 'Change ›',
                        onTap: _openTimePicker,
                      ),
                      // Everyone (paid and trial) can choose every class.
                      _modeCard(
                        selected: _pickedTimes.isEmpty,
                        title: 'All classes',
                        description: 'A reminder before every class of the day',
                        onTap: _chooseAllClasses,
                      ),
                    ],
                    SizedBox(height: 8.h),
                    _buildToggleRow(
                      icon: Icons.cancel_outlined,
                      title: 'Class cancelled',
                      description:
                          'If your trainer cancels, or a class doesn\'t start on time',
                      value: _trainerCancelled == 1,
                      onChanged: (v) => _onToggle('trainerCancelled', v),
                    ),
                    _buildToggleRow(
                      icon: Icons.refresh_outlined,
                      title: 'Missed session',
                      description: 'An evening nudge if you skipped today',
                      value: _missedRecovery == 1,
                      onChanged: (v) => _onToggle('missedRecovery', v),
                    ),
                  ],

                  SizedBox(height: 24.h),
                  Text(
                    'Quiet Hours',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'No notifications at all during these hours',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      color: AppColors.textHint,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildTimeRow(
                    label: 'From',
                    value: _formatTimeDisplay(_quietStart),
                    onTap: () => _pickTime(isStart: true),
                  ),
                  SizedBox(height: 8.h),
                  _buildTimeRow(
                    label: 'To',
                    value: _formatTimeDisplay(_quietEnd),
                    onTap: () => _pickTime(isStart: false),
                  ),
                  SizedBox(height: 36.h),
                ],
              ),
            ),
    );
  }

  Widget _modeCard({
    required bool selected,
    required String title,
    required String description,
    String? badge,
    String? trailing,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.textHint,
                size: 22.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (badge != null) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.sp,
                        color: selected && trailing != null
                            ? AppColors.primaryDark
                            : AppColors.textHint,
                        fontWeight: selected && trailing != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(Icons.chevron_right,
                    color: AppColors.textHint, size: 20.sp),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
