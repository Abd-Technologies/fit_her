import '../../helper/analytics_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:fitness_zone_2/UI/plans_module/upload_slip_screen.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:fitness_zone_2/widgets/custom_button.dart';
import 'package:fitness_zone_2/widgets/toasts.dart';

/// Payment-method picker — V2 redesign.
///
/// Previous version jammed the "Direct Pay" CTA, a divider, and the slip
/// uploader onto the same screen. This version shows two clear method
/// cards and routes accordingly:
///   • Pay online  → existing _DirectPayPhoneDialog (JazzCash/EasyPaisa)
///   • Upload slip → new UploadSlipScreen
///
/// Both downstream surfaces use the original HomeController calls — no
/// API contract changes.
class SelectPaymentMode extends StatelessWidget {
  SelectPaymentMode({
    super.key,
    required this.planId,
    required this.durationId,
    required this.price,
  });

  final String planId;
  final String price;
  final int durationId;

  static const _kCanvas = Color(0xFFF9FCF7);
  static const _kCardBorder = Color(0xFFEFF4EC);
  static const _kIconWashBg = Color(0xFFF6FBF3);
  static const _kTextPrimary = Color(0xFF1A3A22);
  static const _kSage = Color(0xFF7A8C78);
  static const _kAccent = Color(0xFF6DC55A);
  static const _kAccentSoft = Color(0xFFA8F0C0);

  void _showDirectPayPhoneDialog(BuildContext context) {
    final initialPhone = HomeController.normalizeMsisdn(
            Get.find<AuthController>().logInUser?.phone) ??
        '';
    Get.dialog(
      AlertDialog(
        title: const Text("Confirm mobile number"),
        content: _DirectPayPhoneDialogContent(
          planId: planId,
          price: price,
          initialPhone: initialPhone,
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _openUploadSlip() {
    // Clear any leftover image from a previous attempt so the slip
    // screen starts fresh.
    final home = Get.find<HomeController>();
    home.planPicture = null;
    home.update();
    Get.to(() => UploadSlipScreen(
          planId: planId,
          durationId: durationId,
          price: price,
        ));
  }

  @override
  Widget build(BuildContext context) {
    AnalyticsHelper.checkoutStarted(price: price);
    return Scaffold(
      backgroundColor: _kCanvas,
      appBar: HelpingWidgets().appBarWidget(() {
        Get.back();
      }, text: "Select Payment"),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How would you like to pay?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _kTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick a payment method. You can switch later from your '
                'profile.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: _kSage,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              _methodCard(
                title: 'Pay online',
                subtitle: 'JazzCash / EasyPaisa — instant activation.',
                icon: Icons.bolt_rounded,
                accent: _kAccent,
                badge: 'Recommended',
                onTap: () {
                  AnalyticsHelper.paymentMethodChosen('directpay');
                  _showDirectPayPhoneDialog(context);
                },
              ),
              const SizedBox(height: 12),
              _methodCard(
                title: 'Upload payment slip',
                subtitle:
                    'Bank transfer / counter deposit. Verified within a '
                    'few hours.',
                icon: Icons.receipt_long_outlined,
                accent: _kTextPrimary,
                onTap: () {
                  AnalyticsHelper.paymentMethodChosen('slip');
                  _openUploadSlip();
                },
              ),
              const Spacer(),
              const _AmountFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kCardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: _kTextPrimary.withOpacity(0.06),
              offset: const Offset(0, 6),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent == _kAccent
                    ? _kAccentSoft.withOpacity(0.35)
                    : _kIconWashBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 24, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _kTextPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kAccentSoft.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _kTextPrimary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: _kSage,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                size: 18, color: Color(0xFFC8DEC4)),
          ],
        ),
      ),
    );
  }
}

class _AmountFooter extends StatelessWidget {
  const _AmountFooter();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF4EC), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline,
              size: 16, color: SelectPaymentMode._kSage),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Payments are processed securely. You will see your plan '
              'activate as soon as we confirm payment.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: SelectPaymentMode._kSage,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog content for Direct Pay: user confirms/edits phone before
/// opening the WebView. Preserved verbatim from the prior version —
/// same logic, same controller call.
class _DirectPayPhoneDialogContent extends StatefulWidget {
  final String planId;
  final String price;
  final String initialPhone;

  const _DirectPayPhoneDialogContent({
    required this.planId,
    required this.price,
    required this.initialPhone,
  });

  @override
  State<_DirectPayPhoneDialogContent> createState() =>
      _DirectPayPhoneDialogContentState();
}

class _DirectPayPhoneDialogContentState
    extends State<_DirectPayPhoneDialogContent> {
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final raw = _phoneController.text.trim();
    final normalized = HomeController.normalizeMsisdn(raw);
    if (normalized == null || !HomeController.isValidMsisdn(normalized)) {
      CustomToast.failToast(
        msg:
            "Please enter a valid Pakistan mobile number (03xxxxxxxxx, 11 digits).",
      );
      return;
    }
    Get.back();
    Get.find<HomeController>().getDirectPayPaymentLink(
      widget.price,
      widget.planId,
      msisdn: normalized,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Enter your JazzCash / EasyPaisa mobile number. We'll use it for payment.",
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            decoration: const InputDecoration(
              hintText: "03xxxxxxxxx",
              labelText: "Mobile number",
              border: OutlineInputBorder(),
              counterText: "",
            ),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: "Continue to payment",
            onPressed: _onSubmit,
          ),
        ],
      ),
    );
  }
}
