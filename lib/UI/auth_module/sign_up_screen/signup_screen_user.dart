import 'package:fitness_zone_2/UI/auth_module/login/login.dart';
import 'package:fitness_zone_2/UI/auth_module/privacy_health_notice_screen.dart';
import 'package:fitness_zone_2/UI/web_view.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../values/my_imgs.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../widgets/toasts.dart';
import '../../../helper/analytics_helper.dart';

class SignUpNewUser extends StatefulWidget {
  SignUpNewUser({Key? key, this.supporterId, this.isSocial = false})
      : super(key: key);
  final String? supporterId;
  final bool isSocial;

  @override
  State<SignUpNewUser> createState() => _SignUpNewUserState();
}

class _SignUpNewUserState extends State<SignUpNewUser> {
  final AuthController authController = Get.find();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneFieldController = TextEditingController();
  String _completePhoneNumber = '';
  bool _isPhoneValid = false;
  bool _obscurePassword = true;

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // ── Design colors from S02_Final_Clean.html ──
  static const Color _bg = Color(0xFFEAF7E4);
  static const Color _circleColor = Color(0xFFC8E8C0);
  static const Color _textDark = Color(0xFF163220);
  static const Color _textSub = Color(0xFF5A7A56);
  static const Color _textMuted = Color(0xFF9AB09A);
  static const Color _green = Color(0xFF6DC55A);
  static const Color _dividerLine = Color(0xFFE5E7EB);
  static const Color _inputBorder = Color(0xFFE2E8F0);
  static const Color _placeholder = Color(0xFF9CA3AF);

  // Neha's customer support ID
  static const int _defaultCustomerSupportId = 44;

  @override
  void initState() {
    super.initState();
    AnalyticsHelper.trackScreenView('signup_screen');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _bg,
        body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // ── Background circles ──
            Positioned(
              top: -100.h,
              right: -90.w,
              child: Container(
                width: 300.w,
                height: 300.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _circleColor.withValues(alpha: 0.45),
                ),
              ),
            ),
            Positioned(
              top: 160.h,
              left: -70.w,
              child: Container(
                width: 200.w,
                height: 200.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _circleColor.withValues(alpha: 0.3),
                ),
              ),
            ),

            // ── Main content ──
            SafeArea(
              child: Column(
                children: [
                  // ── Back button ──
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 8.w, top: 8.h),
                      child: IconButton(
                        onPressed: () {
                          if (widget.supporterId == null) {
                            Get.back();
                          } else {
                            Get.off(() => Login());
                          }
                        },
                        icon: Icon(Icons.arrow_back_ios_new,
                            color: _textDark, size: 20.sp),
                      ),
                    ),
                  ),

                  // ── Hero logo ──
                  Padding(
                    padding: EdgeInsets.only(top: 4.h, bottom: 16.h),
                    child: Image.asset(
                      MyImgs.fitHerLogo,
                      width: 120.w,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // ── Bottom sheet ──
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(25.r)),
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.w, vertical: 28.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              'Create account',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'Join FitHer — built for every phase of you',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w300,
                                color: _textSub,
                              ),
                            ),
                            SizedBox(height: 24.h),

                            // ── Social buttons ──
                            Row(
                              children: [
                                // Apple
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      await AnalyticsHelper.trackLogin('apple');
                                      authController.handleappleLogin();
                                    },
                                    child: Container(
                                      height: 52.h,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius:
                                            BorderRadius.circular(14.r),
                                      ),
                                      child: Center(
                                        child: Image.asset(
                                          MyImgs.appleIcon,
                                          width: 22.w,
                                          height: 22.w,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                // Google
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      await AnalyticsHelper.trackLogin(
                                          'google');
                                      authController.showEmailsDialog();
                                    },
                                    child: Container(
                                      height: 52.h,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(14.r),
                                        border: Border.all(
                                            color: _inputBorder, width: 1.2),
                                      ),
                                      child: Center(
                                        child: Image.asset(
                                          MyImgs.googleIcon,
                                          width: 22.w,
                                          height: 22.w,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24.h),

                            // ── Divider "or sign up with email" ──
                            Row(
                              children: [
                                Expanded(
                                    child: Container(
                                        height: 1, color: _dividerLine)),
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 12.w),
                                  child: Text(
                                    'or sign up with email',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.sp,
                                      color: _textMuted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                    child: Container(
                                        height: 1, color: _dividerLine)),
                              ],
                            ),
                            SizedBox(height: 24.h),

                            // ── Full name ──
                            if (!widget.isSocial) ...[
                              _buildLabel('Full name'),
                              SizedBox(height: 5.h),
                              _buildTextField(
                                controller: _fullNameController,
                                hint: 'Ayesha Khan',
                                keyboardType: TextInputType.name,
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .singleLineFormatter
                                ],
                              ),
                              SizedBox(height: 16.h),

                              // ── Email ──
                              _buildLabel('Email address'),
                              SizedBox(height: 5.h),
                              _buildTextField(
                                controller:
                                    authController.emailNameController,
                                hint: 'you@email.com',
                                keyboardType: TextInputType.emailAddress,
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .singleLineFormatter
                                ],
                              ),
                              SizedBox(height: 16.h),
                            ],

                            // ── Phone ──
                            _buildLabel('Phone number'),
                            SizedBox(height: 5.h),
                            IntlPhoneField(
                              controller: _phoneFieldController,
                              initialCountryCode: 'PK',
                              disableLengthCheck: false,
                              autovalidateMode: AutovalidateMode.disabled,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14.sp,
                                color: _textDark,
                              ),
                              dropdownTextStyle: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14.sp,
                                color: _textDark,
                              ),
                              showCountryFlag: true,
                              showDropdownIcon: true,
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '300 1234567',
                                hintStyle: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.sp,
                                  color: _placeholder,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 14.h),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide:
                                      const BorderSide(color: _inputBorder, width: 1.2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide:
                                      BorderSide(color: _green, width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: const BorderSide(
                                      color: Colors.red, width: 1),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: const BorderSide(
                                      color: Colors.red, width: 1.5),
                                ),
                              ),
                              onChanged: (phone) {
                                _completePhoneNumber = phone.completeNumber;
                                try {
                                  _isPhoneValid = phone.isValidNumber();
                                } catch (_) {
                                  _isPhoneValid = false;
                                }
                              },
                            ),
                            SizedBox(height: 16.h),

                            // ── Password ──
                            _buildLabel('Password'),
                            SizedBox(height: 5.h),
                            TextField(
                              controller: authController.passwordController,
                              obscureText: _obscurePassword,
                              inputFormatters: [
                                FilteringTextInputFormatter
                                    .singleLineFormatter
                              ],
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14.sp,
                                color: _textDark,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Create a password',
                                hintStyle: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.sp,
                                  color: _placeholder,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 14.h),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: const BorderSide(
                                      color: _inputBorder, width: 1.2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: BorderSide(
                                      color: _green, width: 1.5),
                                ),
                                suffixIcon: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: _textMuted,
                                    size: 20.sp,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 28.h),

                            // ── Create account button ──
                            SizedBox(
                              width: double.infinity,
                              height: 52.h,
                              child: ElevatedButton(
                                onPressed: _onCreateAccount,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14.r),
                                  ),
                                ),
                                child: Text(
                                  'Create my account →',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),

                            // ── Terms + privacy (Wave 0 — tappable) ──
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'By continuing, I agree to ',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.sp,
                                    color: _textMuted,
                                    height: 1.6,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Get.to(
                                    () => const WebViewScreen(
                                      url: 'https://thefither.com/terms',
                                    ),
                                  ),
                                  child: Text(
                                    'Terms of Services',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.sp,
                                      color: _green,
                                      fontWeight: FontWeight.w500,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                                Text(
                                  ' and acknowledge the ',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.sp,
                                    color: _textMuted,
                                    height: 1.6,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Get.to(
                                      () => const PrivacyHealthNoticeScreen()),
                                  child: Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.sp,
                                      color: _green,
                                      fontWeight: FontWeight.w500,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                                Text(
                                  '.',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.sp,
                                    color: _textMuted,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Get.to(
                                  () => const PrivacyHealthNoticeScreen()),
                              child: Text(
                                'We store cycle, mood, sleep, meals and related '
                                'health logs to personalise your plan. Tap to '
                                'read what we store and how to request deletion.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.sp,
                                  height: 1.45,
                                  color: _textMuted,
                                ),
                              ),
                            ),
                            SizedBox(height: 20.h),

                            // ── Sign in link ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account?',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13.sp,
                                    color: _textMuted,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Get.off(() => Login()),
                                  child: Text(
                                    ' Sign in',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color: _green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ── Label widget ──
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        color: _textSub,
      ),
    );
  }

  // ── Text field widget ──
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14.sp,
        color: _textDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13.sp,
          color: _placeholder,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: _inputBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: _green, width: 1.5),
        ),
      ),
    );
  }

  // ── Create account handler ──
  Future<void> _onCreateAccount() async {
    await AnalyticsHelper.trackButtonClick('continue_button',
        screenName: 'signup_screen');

    final fullName = _fullNameController.text.trim();
    final email = authController.emailNameController.text.trim();
    final password = authController.passwordController.text.trim();
    final phone = _completePhoneNumber;

    // Split full name into first + last
    String firstName = '';
    String lastName = '';
    if (!widget.isSocial) {
      if (fullName.isEmpty) {
        CustomToast.failToast(msg: 'Please enter your name');
        return;
      }
      final nameParts = fullName.split(' ');
      firstName = nameParts.first;
      lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      if (email.isEmpty) {
        CustomToast.failToast(msg: 'Please enter your email');
        return;
      }
      if (!_emailRegex.hasMatch(email)) {
        CustomToast.failToast(msg: 'Please provide a valid email address');
        await AnalyticsHelper.trackError('validation_error',
            errorMessage: 'Invalid email format',
            screenName: 'signup_screen');
        return;
      }
    } else {
      firstName = authController.firstNameController.text.trim();
      lastName = authController.lastNameController.text.trim();
    }

    if (!_isPhoneValid) {
      CustomToast.failToast(msg: 'Please enter a valid phone number');
      return;
    }

    if (password.length < 6) {
      CustomToast.failToast(msg: 'Password must be at least 6 characters');
      return;
    }

    // Sync controllers for downstream use
    authController.firstNameController.text = firstName;
    authController.lastNameController.text = lastName;
    authController.phoneNumberController.text = phone;

    await AnalyticsHelper.trackSignUp('email');

    Get.find<HomeController>().addUser(
      status: false,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      password: password,
      customerSupportId: _defaultCustomerSupportId,
    );
  }
}
