import 'dart:async';
import '../../helper/app_update_checker.dart';
import 'dart:math' as math;
import 'package:fitness_zone_2/UI/auth_module/walt_through/walk_through_screenn.dart';
import 'package:fitness_zone_2/data/services/notification_scheduler.dart';
import 'package:fitness_zone_2/helper/notification_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../data/api_provider/app_link_handler.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../values/constants.dart';
import '../../helper/consult_presence.dart';
import '../../values/my_imgs.dart';
import 'package:fitness_zone_2/widgets/anim/splash_intro.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Colors from Light Green HTML variant ──
  // White background; only the corner bubbles stay green (Oct 2026).
  static const Color _bg = Colors.white;
  static const Color _circleColor = Color(0xFFC8E8C0);
  static const Color _dividerColor = Color(0xFFC8E8C0);
  static const Color _textDark = Color(0xFF163220);
  static const Color _textSub = Color(0xFF5A7A56);
  static const Color _versionColor = Color(0xFF9AB09A);
  static const Color _green = Color(0xFF6DC55A);

  // Cycle dot colors
  static const List<Color> _dotColors = [
    Color(0xFFFF8A8A), // pink
    Color(0xFF6DC55A), // green
    Color(0xFFA8F0C0), // mint
    Color(0xFFFAC775), // gold
  ];

  // The 4 dots' keys: before leaving, their screen positions are handed to
  // the Welcome ring, which flies them out and draws itself from them.
  final List<GlobalKey> _dotKeys = List.generate(4, (_) => GlobalKey());

  void _handDotsToWelcome() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    final pts = <Offset>[];
    for (final k in _dotKeys) {
      final box = k.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) return;
      pts.add(box.localToGlobal(box.size.center(Offset.zero)));
    }
    SplashIntro.set(pts);
  }

  // ── Animation controllers ──
  late final AnimationController _circleController;
  late final AnimationController _logoController;
  late final AnimationController _dividerController;
  late final AnimationController _taglineController;
  late final AnimationController _subtitleController;
  late final AnimationController _dotsController;
  late final AnimationController _loaderController;
  late final AnimationController _sideBounceController;

  // ── Timers (stored so dispose() can cancel them; prevents the
  // `_elements.contains(...)` assertion error that fires when an
  // un-cancelled Timer wakes up after the State is gone) ──
  Timer? _navigationTimer;
  Timer? _appLinkTimer;
  Timer? _watchdogTimer;

  AuthController authController = Get.find();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _setupAnimations();
    _runAnimationSequence();

    // ── Original navigation logic ──
    // No permission box on the splash any more (Oct 2026): the main tabs
    // show our own "Turn on notifications" sheet first.
    NotificationServices().syncTokenIfAllowed();
    // Use the widget's own context (safer than Get.context!, which can
    // be null or stale during navigation transitions).
    // Phone notifications: set up once, here (tap routing + channel).
    NotificationServices.ensureLocalNotifications();
    NotificationServices().firebaseInit(context);
    NotificationScheduler.initialize();
    // App update popup: checked once per cold start, after the first
    // screen is up (see helper/app_update_checker.dart / fitHer Flows).
    Future.delayed(const Duration(seconds: 4), AppUpdateChecker.check);
    // Nov 2026: she may have left a consultation call while Fit Her was
    // closed: report that she's back (helper/consult_presence.dart).
    Future.delayed(const Duration(seconds: 3), () {
      try {
        if (Get.find<AuthController>().loginAsA.value == Constants.user) {
          ConsultPresence.instance.start();
        }
      } catch (_) {}
    });

    _navigationTimer = Timer(const Duration(seconds: 3), () async {
      // Bail out if the user backgrounded the app or the splash already
      // disposed. Without this guard, calling Get.offAll on a dead
      // widget tree throws the `_elements.contains(...)` AssertionError
      // we were seeing in Sentry.
      if (!mounted) return;

      try {
        var share = authController.sharedPreferences;

        final email = share.getString(Constants.email);
        final password = share.getString(Constants.password);
        final loginAsa = share.getString(Constants.loginAsa);

        if (email == null || password == null || loginAsa == null) {
          if (!mounted) return;
          // The 4 dots fly on into the Welcome ring (see SplashIntro).
          _handDotsToWelcome();
          Get.offAll(
          () => const WalkThroughScreen(),
          // Quick soft fade: the splash text goes, the dots stay in place
          // and then build the ring on the Welcome screen.
          transition: Transition.fadeIn,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );

          // Init the deep-link handler one second after the new screen
          // has mounted. We store the Timer so dispose() can cancel it.
          _appLinkTimer = Timer(const Duration(seconds: 1), () {
            final ctx = Get.context;
            if (ctx != null) {
              AppLinkHandler().init(ctx);
            }
          });
        } else {
          // ── Watchdog: if login() / signInUsingGoogle() silently fail
          // or the network hangs (e.g. checkConnection returns false and
          // only fires a toast), the splash would otherwise sit forever.
          // After 20s with no navigation, force a fallback to
          // WalkThroughScreen so the user is never trapped on splash.
          _watchdogTimer = Timer(const Duration(seconds: 20), () {
            if (!mounted) return;
            // Only fall back if we are STILL the active route — i.e.
            // login never navigated us anywhere.
            if (Get.currentRoute == '/') {
              Get.offAll(
          () => const WalkThroughScreen(),
          // Smooth hand-off from the splash: soft fade, no slide.
          transition: Transition.fadeIn,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
        );
            }
          });

          if (password.isEmpty ||
              password == "google" ||
              password == "apple") {
            Get.find<AuthController>().signInUsingGoogle(
              email,
              "",
              "",
              userType: loginAsa,
              fromLocal: true,
              showLoading: false,
            );
          } else {
            Get.find<AuthController>().login(
              userType: loginAsa,
              email: email,
              password: password,
              showLoading: false,
            );
          }
        }
      } catch (e, stack) {
        // Any unexpected error → log + send the user to WalkThroughScreen
        // so they're never stranded on a frozen splash.
        debugPrint('SplashScreen navigation error: $e\n$stack');
        if (!mounted) return;
        Get.offAll(
          () => const WalkThroughScreen(),
          // Smooth hand-off from the splash: soft fade, no slide.
          transition: Transition.fadeIn,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _setupAnimations() {
    // 1. Circles scale in (0–600ms)
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // 2. Logo fade + bounce (200–900ms)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // 3. Divider grows from center (600–1000ms)
    _dividerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // 4. Tagline slides up (800–1300ms)
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 5. Subtitle fades in (1100–1500ms)
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // 6. Dots pop in one by one (1300–1900ms)
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // 7. Loader wave movement (loops continuously)
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // 8. Side circles gentle floating bounce (loops continuously)
    _sideBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  void _runAnimationSequence() {
    _circleController.forward().then((_) {
      if (mounted) {
        _sideBounceController.repeat(reverse: true);
      }
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _logoController.forward();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _dividerController.forward();
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _taglineController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _subtitleController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) _dotsController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) _loaderController.repeat();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Get.log("in app resume");
    }
  }

  @override
  void dispose() {
    // Cancel timers FIRST so a late callback can never touch a disposed
    // State (which is what was throwing `_elements.contains(...)`).
    _navigationTimer?.cancel();
    _appLinkTimer?.cancel();
    _watchdogTimer?.cancel();

    _circleController.dispose();
    _logoController.dispose();
    _dividerController.dispose();
    _taglineController.dispose();
    _subtitleController.dispose();
    _dotsController.dispose();
    _loaderController.dispose();
    _sideBounceController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Status-bar styling — declarative AnnotatedRegion replaces the
    // previous imperative `SystemChrome.setSystemUIOverlayStyle` call
    // that was here. The imperative version ran on every animation tick
    // (build is called multiple times during the 1.6s splash sequence)
    // and pushed `statusBarColor: _bg` (#EAF7E4 mint cream) to the OS
    // chrome layer. That value persisted at the OS level after splash
    // unmounted — overriding downstream screens' AnnotatedRegions on
    // Android and producing the "sticky mint band" at the top of every
    // subsequent screen. AnnotatedRegion auto-cleans up on unmount, so
    // PaidHomeV2's transparent overlay can take over cleanly afterward.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        // Transparent strip — splash bg paints under it (cream `_bg`).
        statusBarColor: Colors.transparent,
        // Android: dark icons render visible on the cream background.
        statusBarIconBrightness: Brightness.dark,
        // iOS: `Brightness.light` reads as "the surface is light" —
        // system renders status-bar content in dark/black. Inverted
        // naming relative to Android.
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // ── Background circles ──
              _buildCircles(),

              // ── Main content ──
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 22.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildLogo(),
                              SizedBox(height: 16.h),
                              _buildDivider(),
                              SizedBox(height: 16.h),
                              _buildTagline(),
                              SizedBox(height: 8.h),
                              _buildSubtitle(),
                              SizedBox(height: 20.h),
                              _buildCycleDots(),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Footer
                    Padding(
                      padding: EdgeInsets.only(bottom: 28.h),
                      child: Column(
                        children: [
                          // Bottom loader removed: the 4 cycle dots
                          // under the tagline are the loader now.
                          _buildVersionText(),
                        ],
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

  // ── Background decorative circles with gentle bounce/float ──
  Widget _buildCircles() {
    return AnimatedBuilder(
      animation: Listenable.merge([_circleController, _sideBounceController]),
      builder: (context, _) {
        final scale = CurvedAnimation(
          parent: _circleController,
          curve: Curves.easeOutBack,
        ).value;

        // Subtle floating bounce for side corner circles
        final bounceVal = CurvedAnimation(
          parent: _sideBounceController,
          curve: Curves.easeInOutSine,
        ).value;
        final floatOffset = (bounceVal - 0.5) * 12.h;
        final subtleScale = 1.0 + (bounceVal * 0.04);

        return Stack(
          children: [
            Positioned(
              top: -100.h + floatOffset,
              right: -80.w - (floatOffset * 0.5),
              child: Transform.scale(
                scale: scale * subtleScale,
                child: Container(
                  width: 280.w,
                  height: 280.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _circleColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -55.h - floatOffset,
              left: -55.w + (floatOffset * 0.5),
              child: Transform.scale(
                scale: scale * subtleScale,
                child: Container(
                  width: 190.w,
                  height: 190.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _circleColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Logo with fade + elastic bounce ──
  Widget _buildLogo() {
    final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );
    final bounceAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, _) {
        return Opacity(
          opacity: fadeAnim.value,
          child: Transform.scale(
            scale: bounceAnim.value,
            child: Image.asset(
              MyImgs.fitHerLogo,
              width: 180.w,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  // ── Divider grows from center ──
  Widget _buildDivider() {
    final widthAnim = CurvedAnimation(
      parent: _dividerController,
      curve: Curves.easeOutCubic,
    );

    return AnimatedBuilder(
      animation: _dividerController,
      builder: (context, _) {
        return Container(
          width: 32.w * widthAnim.value,
          height: 2.h,
          decoration: BoxDecoration(
            color: _dividerColor,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      },
    );
  }

  // ── Tagline slides up + fades in ──
  Widget _buildTagline() {
    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOutCubic),
    );
    final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeIn),
    );

    return SlideTransition(
      position: slideAnim,
      child: FadeTransition(
        opacity: fadeAnim,
        child: Text(
          'Your hormonal\nintelligence engine',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: _textDark,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  // ── Subtitle fades in ──
  Widget _buildSubtitle() {
    final fadeAnim = CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeIn,
    );

    return FadeTransition(
      opacity: fadeAnim,
      child: Text(
        'Built around every phase of you',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11.sp,
          fontWeight: FontWeight.w300,
          color: _textSub,
          height: 1.6,
        ),
      ),
    );
  }

  // ── 4 cycle dots pop in one by one and float gently ──
  Widget _buildCycleDots() {
    return AnimatedBuilder(
      // The 4 cycle dots ARE the loading animation now: they pop in one
      // by one, then bounce in a wave (pink → green → mint → gold).
      animation: Listenable.merge([_dotsController, _loaderController]),
      builder: (context, _) {

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final start = i * 0.2;
            final end = (start + 0.4).clamp(0.0, 1.0);
            final dotScale = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _dotsController,
                curve: Interval(start, end, curve: Curves.elasticOut),
              ),
            );
            // Wave bounce (same feel as the old bottom loader).
            final double t = _loaderController.value;
            final double phase = (t - (i * 0.15)) % 1.0;
            final double wave = (phase >= 0.0 && phase <= 0.5)
                ? math.sin(phase / 0.5 * math.pi)
                : 0.0;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Transform.translate(
                offset: Offset(0, -7.h * wave),
                child: Transform.scale(
                  scale: dotScale.value * (1.0 + 0.3 * wave),
                  child: Container(
                    key: _dotKeys[i],
                    width: 7.w,
                    height: 7.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _dotColors[i],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ── Loader: 3 dots moving in a wave bounce (loading animation) ──
  Widget _buildLoader() {
    return AnimatedBuilder(
      animation: _loaderController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            // Staggered wave progression across the 3 dots
            final double t = _loaderController.value;
            // Phase offset for wave motion
            final double phase = (t - (i * 0.18)) % 1.0;
            // Smooth sine bounce in the active half of cycle
            final double bounceFactor = (phase >= 0.0 && phase <= 0.5)
                ? math.sin(phase / 0.5 * math.pi)
                : 0.0;
            final double offsetY = -6.h * bounceFactor;
            final double scale = 1.0 + (0.28 * bounceFactor);
            final double opacity = (0.35 + (0.65 * bounceFactor)).clamp(0.35, 1.0);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.5.w),
              child: Transform.translate(
                offset: Offset(0, offsetY),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6.w,
                    height: 6.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green.withValues(alpha: opacity),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ── Version text ──
  Widget _buildVersionText() {
    final versionFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _subtitleController,
        curve: Curves.easeIn,
      ),
    );

    return AnimatedBuilder(
      animation: _subtitleController,
      builder: (context, _) {
        return Opacity(
          opacity: versionFade.value.clamp(0.0, 1.0),
          child: Text(
            'V 2.0 \u00B7 LAUNCHING NOW',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9.sp,
              letterSpacing: 0.1 * 9.sp,
              color: _versionColor,
            ),
          ),
        );
      },
    );
  }
}
