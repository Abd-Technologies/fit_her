import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../widgets/v2/v2_bottom_sheet.dart';
import '../../../widgets/v2/v2_buttons.dart';
import '../../support/report_issue_screen.dart';

/// Shown instead of the booking screen when self-booking is locked
/// (change policy: a second missed session on the same package). Our
/// team books her next session with her, so we point her to support
/// rather than letting her pick a slot the server will refuse.
class BookingLockedSheet extends StatelessWidget {
  const BookingLockedSheet({super.key});

  static Future<void> show() {
    return V2BottomSheet.show<void>(
      title: "Let's find you a new time",
      child: const BookingLockedSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "You've missed two sessions on this package, so our team will "
          'book your next one with you. Send us a message and we will sort '
          'it out quickly.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF7A8C78),
          ),
        ),
        const SizedBox(height: 18),
        V2PrimaryButton(
          label: 'Contact us',
          onPressed: () {
            Get.back<dynamic>();
            Get.to<dynamic>(() => const ReportIssueScreen());
          },
        ),
        const SizedBox(height: 8),
        V2GhostButton(
          label: 'Not now',
          onPressed: () => Get.back<dynamic>(),
        ),
      ],
    );
  }
}
