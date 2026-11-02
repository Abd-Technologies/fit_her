import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/services/smart_reminder_service.dart';
import '../../theme/app_colors.dart';

/// Embeddable 1NH15 reminder type toggles + quiet hours.
class D1ReminderToggles extends StatefulWidget {
  const D1ReminderToggles({super.key});

  @override
  State<D1ReminderToggles> createState() => _D1ReminderTogglesState();
}

class _D1ReminderTogglesState extends State<D1ReminderToggles> {
  late SmartReminderService _svc;

  @override
  void initState() {
    super.initState();
    _svc = Get.find<SmartReminderService>();
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SmartReminderService>()) {
      return const SizedBox.shrink();
    }
    final types = const [
      ('checkin', 'Daily check-in'),
      ('water', 'Water'),
      ('symptoms', 'Symptoms'),
      ('meal', 'Meals'),
      ('phase', 'Phase nudges'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Smart log reminders',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF163220),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Max ${_svc.maxPerDay}/day · quiet ${_svc.quietStart}:00–${_svc.quietEnd}:00',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: Color(0xFF6F8B7A),
          ),
        ),
        ...types.map((t) {
          final on = _svc.isTypeEnabled(t.$1);
          return SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(t.$2,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
            value: on,
            activeThumbColor: AppColors.primary,
            onChanged: (v) async {
              await _svc.setTypeEnabled(t.$1, v);
              setState(() {});
              if (v) await _svc.scheduleDailyLogReminders();
            },
          );
        }),
        TextButton(
          onPressed: () => _svc.scheduleDailyLogReminders(),
          child: const Text('Reschedule reminders'),
        ),
      ],
    );
  }
}
