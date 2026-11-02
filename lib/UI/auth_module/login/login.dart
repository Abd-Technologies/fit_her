import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../data/controllers/home_controller/home_controller.dart';
import '../../../helper/analytics_helper.dart';
import '../../../values/constants.dart';
import '../../../values/my_imgs.dart';
import '../../../widgets/toasts.dart';
import '../managePassword/forgot_password/enter_email.dart';
import '../sign_up_screen/signup_screen_user.dart';

/// Sprint 1 / S-02 Sign In — V2 redesign.
///
/// Class signature, constructor parameters, login API contract, all four
/// navigation routes (Forgot password, Create account, Sign In success,
/// failed login → WalkThroughScreen), all SharedPreferences writes, both
/// social handlers, and all five existing analytics events are preserved.
/// The Team/Admin button is the only behavioural addition: it shows a
/// bottom-sheet picker, then calls the existing `AuthController.login()`
/// with the selected userType.
class Login extends StatefulWidget {
  const Login({super.key, this.showDropDown = false});

  // Preserved per audit Q-OPEN 14 — no current callers pass this, but the
  // signature is locked.
  final bool showDropDown;

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final AuthController authController = Get.find();
  // Preserved — login flow's success path inside AuthController references
  // HomeController; we keep the binding so the page is fully wired on init.
  // ignore: unused_field
  final HomeController homeController = Get.find();

  // ── S-02 design tokens (verbatim from S02_SignIn_Final.html) ───────────
  static const Color _bg = Color(0xFFEAF7E4);
  static const Color _blob = Color(0xFFC8E8C0);
  static const Color _sheetBorder = Color(0xFFD8EDD4);
  static const Color _textDark = Color(0xFF163220);
  static const Color _textSub = Color(0xFF7B947A);
  static const Color _label = Color(0xFF5A7A56);
  static const Color _inputBorder = Color(0xFFE2E8F0);
  static const Color _placeholder = Color(0xFF9CA3AF);
  static const Color _primaryGreen = Color(0xFF6DC55A);
  static const Color _dividerLine = Color(0xFFE5F1E0);
  static const Color _dividerText = Color(0xFF9AB09A);
  static const Color _footerText = Color(0xFF9AB09A);

  // Show/hide toggle for the password field's eye icon (matches the
  // pattern already used on the sign-up screen — was missing here).
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    AnalyticsHelper.trackScreenView('login_screen');
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: _bg,
      statusBarIconBrightness: Brightness.dark,
    ));

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            _buildBlobs(),
            SafeArea(
              child: Column(
                children: [
                  _buildBackArrow(),
                  _buildHero(),
                  Expanded(child: _buildSheet()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Background blobs ──────────────────────────────────────────────────
  Widget _buildBlobs() {
    return Stack(
      children: [
        Positioned(
          top: -130.h,
          right: -110.w,
          child: Container(
            width: 360.w,
            height: 360.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _blob.withValues(alpha: 0.55),
            ),
          ),
        ),
        Positioned(
          top: 90.h,
          left: -100.w,
          child: Container(
            width: 240.w,
            height: 240.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _blob.withValues(alpha: 0.40),
            ),
          ),
        ),
      ],
    );
  }

  // ── Back arrow (Q-OPEN 13b — small dark icon, 16px from edges) ────────
  Widget _buildBackArrow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => Get.back(),
          child: Icon(
            Icons.arrow_back_ios_new,
            color: _textDark,
            size: 22.w,
          ),
        ),
      ),
    );
  }

  // ── Hero with FitHer wordmark ──────────────────────────────────────────
  Widget _buildHero() {
    return Padding(
      padding: EdgeInsets.fromLTRB(36.w, 16.h, 36.w, 24.h),
      child: GestureDetector(
        // Wave 0 — hidden staff entry (long-press logo).
        onLongPress: _onTeamAdminTapped,
        child: SizedBox(
          height: 68.h,
          child: Image.asset(
            MyImgs.fitHerLogo,
            width: 200.w,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // ── White rounded-top sheet ────────────────────────────────────────────
  Widget _buildSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32.r),
          topRight: Radius.circular(32.r),
        ),
        border: const Border(
          top: BorderSide(color: _sheetBorder, width: 1),
          left: BorderSide(color: _sheetBorder, width: 1),
          right: BorderSide(color: _sheetBorder, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28.w, 30.h, 28.w, 28.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitle(),
            SizedBox(height: 6.h),
            _buildSub(),
            SizedBox(height: 22.h),
            _buildSocialRow(),
            SizedBox(height: 18.h),
            _buildEmailDivider(),
            SizedBox(height: 18.h),
            _buildEmailInput(),
            SizedBox(height: 14.h),
            _buildPasswordInput(),
            SizedBox(height: 8.h),
            _buildForgotRow(),
            SizedBox(height: 18.h),
            _buildSignInButton(),
            SizedBox(height: 14.h),
            _buildCreateAccountFooter(),
            // Wave 0 — Team/Admin CTA removed from the public login surface.
            // Staff access: long-press the Fit Her logo in the hero.
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Welcome back',
      style: TextStyle(
        fontFamily: 'DMSerifDisplay',
        fontWeight: FontWeight.w400,
        fontSize: 32.sp,
        color: _textDark,
        height: 1.1,
        letterSpacing: -0.16, // -0.005em × 32
      ),
    );
  }

  Widget _buildSub() {
    return Text(
      'Sign in to continue your journey.',
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13.sp,
        color: _textSub,
        height: 1.5,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  // ── Social row — Google + Apple (Q1 deviation: NOT Facebook) ──────────
  // Existing handlers preserved exactly.
  Widget _buildSocialRow() {
    return Row(
      children: [
        Expanded(
          child: _socialButton(
            label: 'Google',
            iconPath: MyImgs.googleIcon,
            onTap: () async {
              await AnalyticsHelper.trackLogin('google');
              authController.showEmailsDialog();
            },
          ),
        ),
        SizedBox(width: 11.w),
        Expanded(
          child: _socialButton(
            label: 'Apple',
            iconPath: MyImgs.appleIcon,
            onTap: () async {
              await AnalyticsHelper.trackLogin('apple');
              authController.handleappleLogin();
            },
          ),
        ),
      ],
    );
  }

  Widget _socialButton({
    required String label,
    required String iconPath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 13.h),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _inputBorder, width: 1.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(iconPath, width: 16.w, height: 16.w),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Email-form divider ─────────────────────────────────────────────────
  Widget _buildEmailDivider() {
    return Row(
      children: [
        const Expanded(child: SizedBox(child: Divider(color: _dividerLine, height: 1, thickness: 1))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text(
            'or sign in with email',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.sp,
              color: _dividerText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: SizedBox(child: Divider(color: _dividerLine, height: 1, thickness: 1))),
      ],
    );
  }

  // ── Email + Password inputs ────────────────────────────────────────────
  Widget _buildEmailInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inputLabel('Email address'),
        SizedBox(height: 6.h),
        _inputField(
          controller: authController.loginUserPhone, // legacy name; holds email
          keyboardType: TextInputType.emailAddress,
          obscure: false,
        ),
      ],
    );
  }

  Widget _buildPasswordInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inputLabel('Password'),
        SizedBox(height: 6.h),
        _inputField(
          controller: authController.loginUserPassword,
          keyboardType: TextInputType.text,
          obscure: _obscurePassword,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _label,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11.5.sp,
        fontWeight: FontWeight.w600,
        color: _label,
        letterSpacing: 0.23, // 0.02em × 11.5
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required TextInputType keyboardType,
    required bool obscure,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      cursorColor: _primaryGreen,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14.sp,
        color: _textDark,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        hintStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13.sp,
          color: _placeholder,
        ),
        suffixIcon: suffixIcon == null
            ? null
            : Padding(
                padding: EdgeInsets.only(right: 14.w),
                child: suffixIcon,
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _inputBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _primaryGreen, width: 1.5),
        ),
      ),
    );
  }

  // ── Forgot password (route preserved → ForgotPassword) ────────────────
  Widget _buildForgotRow() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => Get.to(() => ForgotPassword()),
        child: Text(
          'Forgot password?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: _primaryGreen,
            decoration: TextDecoration.underline,
            decorationColor: _primaryGreen,
          ),
        ),
      ),
    );
  }

  // ── Primary CTA — Sign in (login API call preserved) ──────────────────
  Widget _buildSignInButton() {
    return Obx(() {
      final loading = authController.isLoggingIn.value;
      return SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _primaryGreen.withValues(alpha: 0.28),
                offset: const Offset(0, 4),
                blurRadius: 14,
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _primaryGreen.withValues(alpha: 0.6),
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: loading ? null : _onSignInTapped,
            child: loading
                ? SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Sign in',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.15,
                    ),
                  ),
          ),
        ),
      );
    });
  }

  // ── Sign In tap — preserves all original analytics + validation ───────
  Future<void> _onSignInTapped() async {
    await AnalyticsHelper.trackButtonClick(
      'continue_button',
      screenName: 'login_screen',
    );
    if (!_validateInputs()) return;
    await AnalyticsHelper.trackLogin('email');
    authController.login();
  }

  // Mirrors the original login.dart validation block verbatim — same toasts,
  // same analytics events, same checks (empty fields + GetUtils isEmail).
  bool _validateInputs() {
    if (authController.loginUserPhone.text.isEmpty ||
        authController.loginUserPassword.text.isEmpty) {
      CustomToast.failToast(msg: "Please provide all information");
      AnalyticsHelper.trackError(
        'validation_error',
        errorMessage: 'Missing required fields',
        screenName: 'login_screen',
      );
      return false;
    }
    if (!authController.loginUserPhone.text.removeAllWhitespace.isEmail) {
      CustomToast.failToast(msg: "Please provide valid email");
      AnalyticsHelper.trackError(
        'validation_error',
        errorMessage: 'Invalid email format',
        screenName: 'login_screen',
      );
      return false;
    }
    return true;
  }

  // ── Create Account footer (route preserved → SignUpNewUser) ───────────
  Widget _buildCreateAccountFooter() {
    return GestureDetector(
      onTap: () async {
        await AnalyticsHelper.trackButtonClick(
          'create_account_link',
          screenName: 'login_screen',
        );
        Get.off(() => SignUpNewUser());
      },
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.sp,
            color: _footerText,
          ),
          children: const [
            TextSpan(text: 'New here? '),
            TextSpan(
              text: 'Create account',
              style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hidden staff entry (long-press logo) → validate → role picker →
  // existing AuthController.login(userType:).
  Future<void> _onTeamAdminTapped() async {
    await AnalyticsHelper.trackButtonClick(
      'team_admin_login',
      screenName: 'login_screen',
    );
    if (!_validateInputs()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Get.bottomSheet(
      _TeamRolePicker(onPick: _onTeamRolePicked),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Future<void> _onTeamRolePicked(_TeamRole role) async {
    Get.back(); // close the picker
    await AnalyticsHelper.trackButtonClick(
      'team_role_selected_${role.userType}',
      screenName: 'login_screen',
    );
    await AnalyticsHelper.trackLogin('email');
    // Existing API — sets loginAsA.value internally then POSTs /users/login.
    authController.login(userType: role.userType);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Team role picker (Q-OPEN 11c).
// Six roles map to the same userType strings the backend already accepts:
// Constants.{trainer, dietitian, customerSupport, admin} plus the two raw
// strings from AuthController.addTeamMember (Gynecologist, Psychiatrist).
// ─────────────────────────────────────────────────────────────────────────
class _TeamRole {
  final String label;
  final String userType;
  const _TeamRole(this.label, this.userType);
}

class _TeamRolePicker extends StatelessWidget {
  final Future<void> Function(_TeamRole role) onPick;
  const _TeamRolePicker({required this.onPick});

  static const Color _textDark = Color(0xFF163220);
  static const Color _label = Color(0xFF5A7A56);
  static const Color _divider = Color(0xFFEEEEE8);
  static const Color _accent = Color(0xFF6DC55A);

  // `static final` (not const) so we can reference Constants.* — those are
  // declared as `static String` (mutable), not const.
  static final List<_TeamRole> _roles = [
    _TeamRole('Trainer', Constants.trainer),
    _TeamRole('Dietitian', Constants.dietitian),
    const _TeamRole('Gynecologist', 'Gynecologist'),
    const _TeamRole('Psychiatrist', 'Psychiatrist'),
    _TeamRole('Customer Support', Constants.customerSupport),
    _TeamRole('Admin', Constants.admin),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            topRight: Radius.circular(24.r),
          ),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: _divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Login as',
              style: TextStyle(
                fontFamily: 'DMSerifDisplay',
                fontWeight: FontWeight.w400,
                fontSize: 22.sp,
                color: _textDark,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Pick the role you signed up with.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.sp,
                color: _label,
              ),
            ),
            SizedBox(height: 12.h),
            ..._roles.map((r) => _RoleTile(role: r, onTap: onPick)),
          ],
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final _TeamRole role;
  final Future<void> Function(_TeamRole role) onTap;
  const _RoleTile({required this.role, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onTap(role),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 4.w),
        child: Row(
          children: [
            Expanded(
              child: Text(
                role.label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: _TeamRolePicker._textDark,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: _TeamRolePicker._accent,
            ),
          ],
        ),
      ),
    );
  }
}
