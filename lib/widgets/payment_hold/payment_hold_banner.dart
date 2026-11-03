import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../UI/support/report_issue_screen.dart';
import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../values/constants.dart';
import '../toasts.dart';

/// Red banner on home when her plan is paused because the team couldn't
/// confirm her payment (AI-approved slip not confirmed in 48 h, or marked
/// "not received"). She can send her transaction ID or report a problem.
class PaymentHoldBanner extends StatefulWidget {
  const PaymentHoldBanner({super.key});

  @override
  State<PaymentHoldBanner> createState() => _PaymentHoldBannerState();
}

class _PaymentHoldBannerState extends State<PaymentHoldBanner> {
  static const _red = Color(0xFFC24A4A);
  static const _redBg = Color(0xFFFDEEEE);
  static const _ink = Color(0xFF1F2A1E);

  Map<String, dynamic>? _hold;

  String get _token => Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Get.find<ApiProvider>().getData('/users/payment-hold', headers: {'accessToken': _token});
      final b = r.body;
      final h = b is Map && b['status'] == '1' && b['data'] is Map ? b['data']['hold'] : null;
      if (mounted) setState(() => _hold = h is Map ? Map<String, dynamic>.from(h) : null);
    } catch (_) {}
  }

  TextStyle _t(double s, {FontWeight w = FontWeight.w400, Color c = _ink}) =>
      TextStyle(fontFamily: 'Poppins', fontSize: s, fontWeight: w, color: c, height: 1.4);

  Future<void> _sendProof() async {
    final ctrl = TextEditingController();
    final text = await Get.dialog<String>(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Send your payment proof', style: _t(16, w: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Write the transaction ID (TID) from your JazzCash, EasyPaisa or bank app, and the time you paid.',
            style: _t(12.5, c: const Color(0xFF66705F))),
        const SizedBox(height: 10),
        TextField(
          controller: ctrl,
          maxLength: 200,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'e.g. TID 01234567890, paid 18 Oct 3:40 PM',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Get.back(result: ctrl.text.trim()),
          child: const Text('Send', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ));
    if (text == null || text.isEmpty) return;
    try {
      final r = await Get.find<ApiProvider>()
          .postData('/users/payment-hold/proof', body: {'text': text}, headers: {'accessToken': _token});
      final b = r.body;
      if (b is Map && b['status'] == '1') {
        FhToast.show(FhToastKind.success, 'Sent to our team',
            sub: "We'll check it and switch your plan back on.");
        _load();
      } else {
        CustomToast.failToast(msg: b is Map ? b['message'] : null);
      }
    } catch (_) {
      CustomToast.failToast(msg: "Couldn't send. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _hold;
    if (h == null) return const SizedBox.shrink();
    final amount = h['amount'];
    final plan = h['planTitle'];
    final sent = h['proofSent'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _redBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0B8B5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Payment not confirmed', style: _t(14.5, w: FontWeight.w700, c: _red))),
        ]),
        const SizedBox(height: 4),
        Text(
          'We couldn\'t confirm your payment${amount != null ? ' of PKR $amount' : ''}'
          '${plan != null ? ' for $plan' : ''}, so your plan is paused. '
          '${sent ? 'Thanks for sending your proof. Our team is checking it.' : 'Send your proof and we\'ll switch it back on.'}',
          style: _t(12.5),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _sendProof,
              child: Text(sent ? 'Send again' : 'Send proof', style: _t(13, w: FontWeight.w600, c: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: const BorderSide(color: _red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Get.to(() => const ReportIssueScreen()),
              child: Text('Report a problem', style: _t(13, w: FontWeight.w600, c: _red)),
            ),
          ),
        ]),
      ]),
    );
  }
}
