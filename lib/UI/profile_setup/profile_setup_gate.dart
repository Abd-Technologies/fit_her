import '../../helper/analytics_helper.dart';
import '../../helper/popup_manager.dart';
import 'package:get/get.dart';

import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../free_trail/trial_onboarding_screen.dart';

/// Asks existing workout / combined clients to pick their class reminder
/// times, reusing the trial onboarding "Tell us when you're free" + week
/// screens. Runs only after her health form is complete (that form has
/// its own gate: POPUP_PRE_CONSULTATION_FORM).
///
/// Never compulsory (Oct 2026): she can always tap "Later". After each
/// "Later" we wait 2 days; after 2 "Later"s we stop asking. Home then
/// shows a small "Reminders for all classes, Pick my times" note.
/// Until she picks her times, she gets reminders for ALL classes
/// (server rule, see helper/classAudience.js).
/// Never asks a woman who chose "All classes" herself in Settings
/// (workoutSection.reminderMode == 'all').
class ProfileSetupGate {
  ProfileSetupGate._();

  static const int maxLater = 2;
  static const Duration askAgainAfter = Duration(days: 2);
  static bool _checkedThisSession = false;
  static bool _open = false;

  static String _laterKey(int uid) => 'profile_setup_later_$uid';
  static String _nextKey(int uid) => 'profile_setup_next_at_$uid';

  /// Call once the paid home has loaded. Shows at most once per app run.
  static Future<void> checkAndShow() async {
    if (_checkedThisSession || _open) return;
    try {
      final auth = Get.find<AuthController>();
      final user = auth.logInUser;
      if (user == null || user.status != true) return;
      if (!Get.isRegistered<HomeController>()) return;
      final home = Get.find<HomeController>();
      // Trial users have their own onboarding.
      if (home.isFreeTrialUser.value) return;

      final plans = home.userHomeData?.userAllPlans;
      if (plans == null) return; // not loaded yet: try again next time
      final real = plans.where((p) {
        final t = p.title.trim().toLowerCase();
        return t != 'free trial' && !t.startsWith('system') && p.remainingDays > 0;
      }).toList();
      if (real.isEmpty) return;
      // CategoryId: 1 diet, 2 workout, 3 combined.
      final hasWorkout = real.any((p) => p.categoryId == 2 || p.categoryId == 3);

      final profile = await Get.find<ConsultationController>().loadProfile();
      final formDone = profile?.isComplete == true;
      final ws = profile?.workoutSection;
      bool nonEmpty(Object? v) => v is List && v.isNotEmpty;
      final picks = nonEmpty(ws?['preferredSlotIds']) ||
          nonEmpty(ws?['preferredTimes']) ||
          ws?['reminderMode'] == 'all'; // she chose every class herself
      // The health form itself already has its own gate for every paid
      // client (POPUP_PRE_CONSULTATION_FORM -> PreConsultationFormScreen,
      // "Later" twice, then required). Don't ask twice: wait until it's
      // done, then ask only for her class times.
      if (!formDone) return;
      final needsTimes = hasWorkout && !picks;
      _checkedThisSession = true;
      if (!needsTimes) return;

      final prefs = auth.sharedPreferences;
      final key = _laterKey(user.id);
      final laterUsed = prefs.getInt(key) ?? 0;
      // Asked twice already: stop. The home note covers it from here.
      if (laterUsed >= maxLater) return;
      const canSkip = true;
      // After a "Later", wait 2 days before asking again.
      final nextAt = prefs.getInt(_nextKey(user.id)) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < nextAt) return;

      // Pop-up manager: waits for its turn (see PopupRank).
      bool? done;
      final shown = await PopupManager.run(
        'class_times',
        rank: PopupRank.classTimes,
        show: () async {
          _open = true;
          done = await Get.to<bool>(
            () => TrialOnboardingScreen(
              setupMode: true,
              includeClasses: true,
              timesOnly: true,
              canSkip: canSkip,
            ),
            fullscreenDialog: true,
          );
        },
      );
      _open = false;
      if (!shown) {
        // Lost its turn: ask again on the next app open.
        _checkedThisSession = false;
        return;
      }
      // Mixpanel: picked her class times, or tapped Later.
      AnalyticsHelper.track(done == true ? 'class_times_picked' : 'class_times_later',
          {'source': 'gate', 'later_used': laterUsed});
      if (done != true && canSkip) {
        await prefs.setInt(key, laterUsed + 1);
        await prefs.setInt(
          _nextKey(user.id),
          DateTime.now().add(askAgainAfter).millisecondsSinceEpoch,
        );
      }
    } catch (_) {
      _open = false;
      // Best-effort: never block the home screen on an error here.
    }
  }
}
