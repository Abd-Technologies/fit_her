import 'package:get/get.dart';

import '../data/controllers/home_controller/home_controller.dart';
import '../helper/class_join_memory.dart';
import 'app_clock.dart';
import 'slot_ui_state.dart';

/// Free-trial join window on class LISTS (Oct 2026).
///
/// A trial woman can only join in the first N minutes of a class
/// (server: TRIAL_JOIN_WINDOW_MINUTES). Home already hides a class once
/// that window has passed; the Workout schedule and the class sheet still
/// showed a green "Join now". This turns that button into a grey
/// "Joining closed" with the reason, so every screen agrees.
///
/// Not changed: paid women, classes not live yet, and a REJOIN of a class
/// she already joined on time today (allowed until it ends, like the server).
SlotPresentation applyTrialJoinWindow(
  SlotPresentation p,
  SlotUIState state, {
  required DateTime? start,
  required Object? slotId,
}) {
  if (state != SlotUIState.liveReady && state != SlotUIState.liveNotReady) return p;
  if (start == null || !Get.isRegistered<HomeController>()) return p;
  final home = Get.find<HomeController>();
  if (!home.isFreeTrialUser.value) return p;
  final window = home.joinWindowMinutes.value;
  if (!AppClock.now().isAfter(start.add(Duration(minutes: window)))) return p;
  if (ClassJoinMemory.joinedToday(slotId)) return p;
  return SlotPresentation(
    appearance: SlotButtonAppearance.disabled,
    buttonLabel: 'Joining closed',
    buttonColor: SlotButtonColor.grey,
    toastMessage: 'Trial classes can be joined in the first $window minutes. See you at the next one 💚',
    action: SlotButtonAction.showToast,
  );
}
