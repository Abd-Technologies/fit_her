import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../UI/admin_module/payment_checks/payment_checks_screen.dart';
import '../UI/admin_module/emergency_days/emergency_day_requests_screen.dart';
import '../UI/dashboard_module/get_all_new_user_images/get_new_user_images.dart';
import '../data/api_provider/api_provider.dart';
import '../data/controllers/auth_controller/auth_controller.dart';
import '../data/controllers/home_controller/home_controller.dart';
import '../values/constants.dart';

/// Admin home (Oct 2026): two buttons at the top that show what needs her
/// now. Hidden when the count is 0.
///   "N payments to confirm" → AI-approved slips (48 h money check).
///   "N slips to approve"    → slips the AI could not approve.
class AdminPaymentAlerts extends StatefulWidget {
  const AdminPaymentAlerts({super.key});

  @override
  State<AdminPaymentAlerts> createState() => _AdminPaymentAlertsState();
}

class _AdminPaymentAlertsState extends State<AdminPaymentAlerts> {
  static const _kRed = Color(0xFFC24A4A);
  static const _kRedWash = Color(0xFFFDECEC);
  static const _kAmber = Color(0xFFC77B2B);
  static const _kAmberWash = Color(0xFFFFF4E0);

  int _toConfirm = 0;
  int _toApprove = 0;
  int _emergency = 0; // dietitian emergency days waiting (Oct 2026)

  String get _token =>
      Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = Get.find<ApiProvider>();
    var confirm = 0;
    var approve = 0;
    try {
      final r = await api.getData('/admin/payment-checks', headers: {'accessToken': _token});
      final b = r.body;
      if (b is Map && b['status'] == '1' && b['data'] is Map && b['data']['items'] is List) {
        confirm = (b['data']['items'] as List)
            .whereType<Map>()
            .where((e) => e['status'] == 'pending')
            .length;
      }
    } catch (_) {}
    try {
      final r = await api.getData(Constants.getAllUsersPlanImages, headers: {'accessToken': _token});
      final b = r.body;
      final d = b is Map ? b['data'] : null;
      final list = d is Map ? d['data'] : d;
      if (b is Map && b['status'] == '1' && list is List) approve = list.length;
    } catch (_) {}
    var emergency = 0;
    try {
      final r = await api.getData('/emergency-day/awaiting', headers: {'accessToken': _token});
      final b = r.body;
      if (b is Map && b['status'] == '1' && b['data'] is Map && b['data']['items'] is List) {
        emergency = (b['data']['items'] as List).length;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _toConfirm = confirm;
      _toApprove = approve;
      _emergency = emergency;
    });
  }

  Widget _button({
    required String text,
    required Color color,
    required Color wash,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: wash,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Row(children: [
              Icon(icon, color: color, size: 22.w),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(text,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp, fontWeight: FontWeight.w700, color: color)),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_toConfirm == 0 && _toApprove == 0 && _emergency == 0) return const SizedBox.shrink();
    return Column(children: [
      if (_toConfirm > 0)
        _button(
          text: '$_toConfirm payment${_toConfirm == 1 ? '' : 's'} to confirm',
          color: _kRed,
          wash: _kRedWash,
          icon: Icons.verified_outlined,
          onTap: () async {
            await Get.to(() => const PaymentChecksScreen());
            _load();
          },
        ),
      if (_emergency > 0)
        _button(
          text: '$_emergency emergency day${_emergency == 1 ? '' : 's'} to approve',
          color: _kRed,
          wash: _kRedWash,
          icon: Icons.emergency_outlined,
          onTap: () async {
            await Get.to(() => const EmergencyDayRequestsScreen());
            _load();
          },
        ),
      if (_toApprove > 0)
        _button(
          text: '$_toApprove slip${_toApprove == 1 ? '' : 's'} to approve',
          color: _kAmber,
          wash: _kAmberWash,
          icon: Icons.receipt_long_outlined,
          onTap: () async {
            Get.find<HomeController>().getAllImagesPlan();
            await Get.to(() => AllNewUserImages());
            _load();
          },
        ),
    ]);
  }
}
