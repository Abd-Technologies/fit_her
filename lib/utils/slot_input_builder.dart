/// Adapter functions that bridge the app's data models to the pure
/// resolver in `slot_ui_state.dart`. The resolver intentionally has no
/// dependency on these models; this file is the only place that knows
/// how to translate between them.
library;

import 'package:intl/intl.dart';

import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/models/get_user_plan/get_workout_user_plan_details.dart';
import 'package:fitness_zone_2/utils/app_clock.dart';
import 'package:fitness_zone_2/utils/slot_ui_state.dart';

/// Parses a wall-clock string like "08:00 AM" against [anchorDate].
/// Returns null on malformed input — caller decides the fallback.
DateTime? parseSlotWallClock(String? hhmma, DateTime anchorDate) {
  if (hhmma == null || hhmma.isEmpty) return null;
  try {
    final parsed = DateFormat('hh:mm a').parseStrict(hhmma);
    return DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day,
      parsed.hour,
      parsed.minute,
    );
  } catch (_) {
    return null;
  }
}

/// Build a [SlotInput] from a [Slot] anchored to [anchorDate]. Returns
/// null if start/end can't be parsed — UI should treat that as
/// non-actionable (no Join button), same as a hidden state.
SlotInput? buildSlotInput(Slot slot, DateTime anchorDate) {
  final start = parseSlotWallClock(slot.start, anchorDate);
  final end = parseSlotWallClock(slot.end, anchorDate);
  if (start == null || end == null) return null;
  return SlotInput(
    status: slot.status,
    start: start,
    end: end,
    trainerLink: slot.trainerLink,
  );
}

/// Pull the freeze + remainingDays gates from [HomeController]. Defaults
/// to "expired" when home data hasn't loaded — safe-fail (locks the
/// button) rather than letting an empty payload look healthy.
UserAccessInput buildUserAccess(HomeController homeController) {
  // Old admin freeze OR her own pause (freeze v2): no classes (Oct 2026).
  final isFrozen = homeController.userHomeData?.userData.freeze.value == true ||
      homeController.planFrozen.value;
  final plans = homeController.userHomeData?.userAllPlans;
  final planRemainingDays =
      (plans != null && plans.isNotEmpty) ? plans.first.remainingDays : 0;
  final remainingDays =
      hasActiveThreeDayTrial(homeController) ? 1 : planRemainingDays;
  return UserAccessInput(
    isFrozen: isFrozen,
    remainingDays: remainingDays,
  );
}

/// Returns true when the user has a TrialJourney that is still within the
/// 3-day window and has not been converted to a paid plan.
/// Public so other widgets (e.g. WorkPlansOfUser) can gate UI on trial state
/// without duplicating the logic.
bool hasActiveThreeDayTrial(HomeController homeController) {
  final journey = homeController.trialJourney;
  if (journey == null || journey["convertedAt"] != null) return false;

  final rawStartedAt = journey["startedAt"];
  if (rawStartedAt == null) return false;

  final startedAt = DateTime.tryParse(rawStartedAt.toString());
  if (startedAt == null) return false;

  return AppClock.now().isBefore(startedAt.add(homeController.kTrialLength));
}

/// Pick the right block reason for [SlotUIState.liveBlocked] given the
/// current access state. Frozen takes precedence — the freeze message is
/// more actionable to the user than "renew your plan".
SlotBlockReason blockReasonFor(UserAccessInput user) {
  return user.isFrozen ? SlotBlockReason.frozen : SlotBlockReason.expired;
}

/// Whole minutes between [now] and [start]. Returns null if [start] is
/// already in the past. Used for the "Starts in Xm" countdown label on
/// upcomingSoon. Anchors to whole-minute granularity to match the 60s
/// rebuild cadence — second-level precision would show jitter.
int? minutesUntilStart(DateTime start, DateTime now) {
  if (!now.isBefore(start)) return null;
  final diff = start.difference(now);
  return diff.inMinutes;
}
