import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../../widgets/v2/v2_bottom_sheet.dart';
import '../../../widgets/v2/v2_buttons.dart';

/// `POPUP_BOOK_INITIAL_REMINDER` — fires on every dashboard reload while
/// the user hasn't booked their initial consultation. "Remind me
/// tomorrow" explicitly snoozes it for a day (server-side); the plain
/// "x" close (from the parent V2BottomSheet's default dismissible
/// shell) does NOT suppress it — it'll be back next reload. dismissCount
/// (bumped by the generic dismiss endpoint, if anything still calls it)
/// still trips a one-time BOOKING_REMINDER_5X staff escalation at 5,
/// but that's just a signal to staff now — it no longer stops the popup
/// from resurfacing.
///
/// "Book now" deliberately does NOT call completePopup — it only
/// navigates to the booking flow. Tapping the button isn't "done", an
/// actual booked Appointment is; helper/popupEligibility.js's
/// evalBookInitialReminder retires this popup server-side once a real
/// Appointment exists. Completing it here on tap used to retire the
/// active row on the spot, which (since this popup's setEligible call
/// carries no `cycle` in its metadata) meant the very next dashboard
/// evaluate pass couldn't recognize the row as "already completed" and
/// just created a brand new eligible one — the popup reappeared
/// instantly after every "Book now" tap, in a tight complete → recreate
/// loop.
class BookInitialReminderSheet extends StatelessWidget {
  static const String variable = 'POPUP_BOOK_INITIAL_REMINDER';

  /// Caller passes a `onBookNow` that opens the actual booking sheet
  /// (`BookConsultationSheet.show(...)` from popup #1). We don't import
  /// it here to keep file dependencies tight.
  /// Wave 0: async so the reminder can fully dismiss before booking opens.
  final Future<void> Function() onBookNow;

  const BookInitialReminderSheet({Key? key, required this.onBookNow})
      : super(key: key);

  static Future<void> show({required Future<void> Function() onBookNow}) {
    return V2BottomSheet.show(
      title: "Let's get you started",
      child: BookInitialReminderSheet(onBookNow: onBookNow),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ConsultationController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "You haven't booked your first consultation yet. Your dietitian needs ~20 minutes to build a plan that actually fits you — pick a slot that works.",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Color(0xFF7A8C78),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        V2PrimaryButton(
          label: 'Book now',
          onPressed: () async {
            // Do NOT completePopup here — see doc comment above. Close
            // this sheet fully, then hand off to booking so two sheets
            // never stack (Wave 0 U-01).
            Get.back<dynamic>();
            await Future<void>.delayed(const Duration(milliseconds: 280));
            await onBookNow();
          },
        ),
        const SizedBox(height: 8),
        V2GhostButton(
          label: 'Remind me tomorrow',
          onPressed: () {
            ctrl.snoozePopup(variable, days: 1);
            Get.back<dynamic>();
          },
        ),
      ],
    );
  }
}
