import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../helper/analytics_helper.dart';
import '../../data/analytics/analytics_events.dart';
import '../../theme/app_colors.dart';

/// 1P6 — pending → active activation UX (gateway later).
class InstantActivationBanner extends StatefulWidget {
  const InstantActivationBanner({super.key});

  @override
  State<InstantActivationBanner> createState() =>
      _InstantActivationBannerState();
}

class _InstantActivationBannerState extends State<InstantActivationBanner> {
  static const pendingKey = 'd1_payment_pending';
  Timer? _poll;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    final prefs = Get.find<SharedPreferences>();
    _pending = prefs.getBool(pendingKey) ?? false;
    if (_pending) {
      _poll = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      final auth = Get.find<AuthController>();
      // Soft refresh: if already paid, clear pending.
      if (auth.isPaid.value) {
        await Get.find<SharedPreferences>().setBool(pendingKey, false);
        await AnalyticsHelper.track(AnalyticsEvents.paymentSuccess, props: {
          'source': 'activation_poll',
        });
        if (mounted) setState(() => _pending = false);
        _poll?.cancel();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_pending) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFAC775)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top, color: AppColors.primaryDeep),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Payment received — activating your plan…',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF163220),
              ),
            ),
          ),
          TextButton(
            onPressed: _refresh,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
