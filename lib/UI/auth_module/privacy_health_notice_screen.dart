import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Wave 0 trust basics — short plain-language health-data notice.
/// Full discreet mode / export-delete flows stay for later deliveries.
class PrivacyHealthNoticeScreen extends StatelessWidget {
  const PrivacyHealthNoticeScreen({super.key});

  static const _kText = Color(0xFF163220);
  static const _kMuted = Color(0xFF6F8B7A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FCF7),
      appBar: HelpingWidgets()
          .appBarWidget(() => Get.back(), text: 'Privacy & health data'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: const [
          Text(
            'Your health data',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Fit Her stores information you choose to share so we can personalise '
            'your plan. This can include cycle and period details, mood, energy, '
            'sleep, water, weight, meal logs, symptoms, and progress photos.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              height: 1.5,
              color: _kMuted,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Who can see it',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'You can see your own data in the app. Assigned dietitians or trainers '
            'may see what they need to support your plan. Admins access data only '
            'to run the service and resolve support issues.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              height: 1.5,
              color: _kMuted,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Delete or ask questions',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'To request deletion of your account or health data, or to ask what '
            'we store, email support@thefither.com. We will confirm when the '
            'request is complete.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              height: 1.5,
              color: _kMuted,
            ),
          ),
        ],
      ),
    );
  }
}
