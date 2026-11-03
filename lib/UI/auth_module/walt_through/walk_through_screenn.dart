import '../../../helper/analytics_helper.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../values/my_imgs.dart';
import '../login/login.dart';
import '../sign_up_screen/signup_screen_user.dart';
import 'animated_cycle_wheel.dart';
import '../../../widgets/anim/splash_intro.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Sprint 1 / SA-00 V3 Refined — Welcome / Get Started landing.
///
/// Class name + constructor signature are preserved so existing callers
/// (splash.dart, app_link_handler.dart, auth_controller.dart) keep
/// working unchanged. Only the widget tree was replaced.
class WalkThroughScreen extends StatelessWidget {
  const WalkThroughScreen({Key? key}) : super(key: key);

  // ── V3 design tokens ───────────────────────────────────────────────────
  // Sourced from new screens/S01_Welcome_V3_Refined.html.
  static const Color _bgTop = Color(0xFFFAFDF9);
  static const Color _bgBottom = Color(0xFFEAF7E4);
  static const Color _textDark = Color(0xFF163220);
  static const Color _textSub = Color(0xFF5A7A56);
  static const Color _primaryGreen = Color(0xFF6DC55A);

  // Cycle-phase colors — wheel arcs + matching pill text colors.
  static const Color _menstrualArc = Color(0xFFFF8A8A);
  static const Color _follicularArc = Color(0xFF6DC55A);
  static const Color _ovulationArc = Color(0xFF5ECFB0); // Aqua / Teal
  static const Color _lutealArc = Color(0xFFFAC775);
  static const Color _menstrualLabel = Color(0xFFC45A5A);
  static const Color _follicularLabel = Color(0xFF3A8A3A);
  static const Color _ovulationLabel = Color(0xFF267D6B);
  static const Color _lutealLabel = Color(0xFF9C7430);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      // Plain white background (Oct 2026), no green gradient.
      backgroundColor: Colors.white,
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Brand mark — small wordmark sitting at the top.
              _riseIn(context, 1350, Padding(
                padding: EdgeInsets.only(top: 16.h),
                child: Opacity(
                  opacity: 0.92,
                  child: Image.asset(
                    MyImgs.fitHerLogo,
                    height: 18.h,
                    fit: BoxFit.contain,
                  ),
                ),
              )),

              // Cycle wheel — vertically centred in remaining space.
              // Final animated wheel (Oct 2026): draws itself, smooth
              // phase colours, travelling dot, folding centre words.
              // Sized from the free space so it fits every phone.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Use the free space: as wide as the screen allows
                    // (82%), as tall as the gap allows, capped at 340.
                    final size = math.min(
                      math.min(box.maxWidth * 0.82, box.maxHeight / 1.2),
                      340.0,
                    );
                    return Center(
                      child: Hero(
                        tag: AnimatedCycleWheel.heroTag,
                        flightShuttleBuilder: AnimatedCycleWheel.heroFlight,
                        child: RepaintBoundary(child: AnimatedCycleWheel(size: size)),
                      ),
                    );
                  },
                ),
              ),

              // Bottom body block — headline, sub-copy, CTAs.
              _riseIn(context, 1460, Padding(
                padding: EdgeInsets.fromLTRB(32.w, 0, 32.w, 28.h),
                child: Column(
                  children: [
                    Text(
                      'Welcome to your rhythm.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'DMSerifDisplay',
                        fontSize: 38.sp,
                        fontWeight: FontWeight.w400,
                        color: _textDark,
                        letterSpacing: -1.14, // -0.03em × 38
                        height: 1.05,
                      ),
                    ),
                    SizedBox(height: 22.h),
                    _buildPrimaryButton(),
                    SizedBox(height: 10.h),
                    _buildSecondaryButton(),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  /// Right after the splash (first launch): the logo and "Welcome to your
  /// rhythm" + buttons rise in once the ring has built itself from the
  /// splash dots. Any other time: shown as normal.
  static Widget _riseIn(BuildContext context, int delayMs, Widget child) {
    if (!SplashIntro.active || (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) return child;
    final delay = Duration(milliseconds: delayMs);
    return child
        .animate()
        .fadeIn(delay: delay, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic)
        .slideY(begin: 0.12, end: 0, delay: delay, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  // ── Cycle wheel ────────────────────────────────────────────────────────
  // 280-px conic ring + 244-px white inner mask + 4 phase pills positioned
  // to match S01_Welcome_V3_Refined.html (top/right/bottom/left offsets,
  // not on a uniform polar rim).
  Widget _buildWheel() {
    return SizedBox(
      // 280 wheel + buffer so the pills can extend
      // past the arc rim without being clipped.
      width: 320.w,
      height: 330.w,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 280.w,
            height: 280.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryGreen.withValues(alpha: 0.15),
                  offset: const Offset(0, 30),
                  blurRadius: 60,
                ),
                BoxShadow(
                  color: _textDark.withValues(alpha: 0.08),
                  offset: const Offset(0, 12),
                  blurRadius: 24,
                ),
              ],
            ),
            child: CustomPaint(
              size: Size(280.w, 280.w),
              painter: _CycleWheelPainter(
                colors: const [
                  _menstrualArc,
                  _follicularArc,
                  _ovulationArc,
                  _lutealArc,
                ],
                dayFractions: const [
                  5 / 28,  // 🩸 Menstrual: Day 1–5 (5 days)
                  8 / 28,  // 🌱 Follicular: Day 6–13 (8 days)
                  1 / 28,  // 🥚 Ovulation: Day 14 (1 day)
                  14 / 28, // 🌙 Luteal: Day 15–28 (14 days)
                ],
                strokeWidth: 18.w,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Inner white mask + "28 DAYS · YOUR CYCLE"
                  Center(
                    child: Container(
                      width: 244.w,
                      height: 244.w,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _bgTop,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '28',
                              style: TextStyle(
                                fontFamily: 'Fraunces',
                                fontSize: 60.sp,
                                fontWeight: FontWeight.w300,
                                color: _textDark,
                                letterSpacing: -2.4, // -0.04em × 60
                                height: 1.0,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'DAYS · YOUR CYCLE',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: _textSub,
                                letterSpacing: 1.62, // 0.18em × 9
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Phase pills — positioned on the angular midpoint of each phase:
                // 🩸 Menstrual: Day 2.5 (32.14°)
                _buildPositionedPill(
                  label: 'MENSTRUAL',
                  color: _menstrualLabel,
                  angleInDegrees: (2.5 / 28) * 360,
                  radius: 130.w,
                ),
                // 🌱 Follicular: Day 9.0 (115.71°)
                _buildPositionedPill(
                  label: 'FOLLICULAR',
                  color: _follicularLabel,
                  angleInDegrees: (9.0 / 28) * 360,
                  radius: 130.w,
                ),
                // 🥚 Ovulation: Day 13.5 (173.57°)
                // Moved under the circle (radius: 156.w) so the 1-day teal
                // arc on the wheel remains 100% visible and uncovered.
                _buildPositionedPill(
                  label: 'OVULATION',
                  color: _ovulationLabel,
                  angleInDegrees: (13.5 / 28) * 360,
                  radius: 156.w,
                ),
                // 🌙 Luteal: Day 21.0 (270.00°)
                _buildPositionedPill(
                  label: 'LUTEAL',
                  color: _lutealLabel,
                  angleInDegrees: (21.0 / 28) * 360,
                  radius: 130.w,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildPositionedPill({
    required String label,
    required Color color,
    required double angleInDegrees,
    required double radius,
  }) {
    final double rad = angleInDegrees * math.pi / 180;
    final double dx = radius * math.sin(rad);
    final double dy = -radius * math.cos(rad);

    return Center(
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: _buildPhasePill(label, color),
      ),
    );
  }

  Widget _buildPhasePill(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 1.35, // 0.15em × 9
        ),
      ),
    );
  }

  // ── Primary CTA → existing destination preserved ───────────────────────
  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _primaryGreen.withValues(alpha: 0.32),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(vertical: 17.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () {
            AnalyticsHelper.signupStepViewed('signup_form');
            // Ring shrinks up into Sign-up, the card rises (same as Log in).
            Get.to(() => SignUpNewUser(fromWelcome: true),
                transition: Transition.fadeIn,
                curve: Curves.fastOutSlowIn,
                duration: const Duration(milliseconds: 480));
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Get started',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '→',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Secondary CTA → existing destination preserved ─────────────────────
  Widget _buildSecondaryButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: _textSub,
          padding: EdgeInsets.symmetric(vertical: 14.h),
        ),
        onPressed: () {
          // Ring shrinks up into Login, the sign-in card rises (fade route
          // so only the ring and the card move).
          Get.to(() => const Login(fromWelcome: true),
              transition: Transition.fadeIn,
              curve: Curves.fastOutSlowIn,
              duration: const Duration(milliseconds: 480));
        },
        child: RichText(
          text: TextSpan(
            text: 'Already have an account? ',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: _textSub,
            ),
            children: [
              TextSpan(
                text: 'Log in',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: _primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleWheelPainter extends CustomPainter {
  final List<Color> colors;
  final List<double> dayFractions;
  final double strokeWidth;

  const _CycleWheelPainter({
    required this.colors,
    required this.dayFractions,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    double currentAngle = -math.pi / 2; // Start at 12 o'clock

    for (int i = 0; i < colors.length; i++) {
      final sweepAngle = 2 * math.pi * dayFractions[i];
      paint.color = colors[i];
      canvas.drawArc(rect, currentAngle, sweepAngle, false, paint);
      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _CycleWheelPainter oldDelegate) => false;
}
