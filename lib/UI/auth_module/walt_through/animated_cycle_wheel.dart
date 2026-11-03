import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/anim/splash_intro.dart';

/// Welcome-screen cycle wheel (final design, Oct 2026):
///   • the ring draws itself clockwise on open (~1.3 s), phases blending
///     smoothly into each other (Menstrual → Follicular → Ovulation → Luteal)
///   • a slow dot travels round the ring (~50 s per turn), takes the colour
///     of the phase it is on (blended at the edges) with a soft pulsing glow,
///     and passes OVER the phase labels
///   • the current phase label grows a little as the dot passes
///   • the centre "folds" every 3.2 s: 28 Days → Movement → Nutrition →
///     Hormones (tap the wheel to skip ahead)
///   • everything is sized from [size], so it fits any phone
class AnimatedCycleWheel extends StatefulWidget {
  const AnimatedCycleWheel({super.key, required this.size, this.drawIn = true, this.showCaption = true});

  /// Diameter of the coloured ring.
  final double size;

  /// false = start fully drawn (used when the ring flies in from the
  /// Welcome screen, so it doesn't redraw itself).
  final bool drawIn;

  /// false = only the big word (Hormones, Nutrition, Movement…), no line
  /// under it — except "28", which keeps "DAYS · YOUR CYCLE". Login page.
  final bool showCaption;

  /// Hero tag shared by Welcome and Login: the ring flies between them.
  static const heroTag = 'fh_cycle_wheel';

  /// Flight look. The Welcome ring (big) and the Login ring (small) lay
  /// out their text differently, so a plain scale snaps at the end. Both
  /// are drawn once and scaled to the flying box, and cross-fade as it
  /// moves: at the end the flying ring IS the real one, so nothing jumps.
  /// [animation] goes 0 (Welcome) to 1 (Login) on push and back on pop.
  static Widget heroFlight(BuildContext context, Animation<double> animation,
      HeroFlightDirection direction, BuildContext fromContext, BuildContext toContext) {
    double sizeOf(BuildContext c) {
      var child = (c.widget as Hero).child;
      if (child is RepaintBoundary && child.child != null) child = child.child!;
      return child is AnimatedCycleWheel ? child.size : 200.0;
    }

    final push = direction == HeroFlightDirection.push;
    final welcomeSize = sizeOf(push ? fromContext : toContext);
    final loginSize = sizeOf(push ? toContext : fromContext);
    final welcome = RepaintBoundary(child: FittedBox(child: AnimatedCycleWheel(size: welcomeSize, drawIn: false)));
    final login = RepaintBoundary(
        child: FittedBox(child: AnimatedCycleWheel(size: loginSize, drawIn: false, showCaption: false)));
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(animation.value.clamp(0.0, 1.0));
        return Stack(fit: StackFit.expand, children: [
          Opacity(opacity: 1 - t, child: welcome),
          Opacity(opacity: t, child: login),
        ]);
      },
    );
  }

  @override
  State<AnimatedCycleWheel> createState() => _AnimatedCycleWheelState();
}

class _Phase {
  final String label;
  final double start; // day (0..28)
  final double end;
  final Color arc;
  final Color text;
  const _Phase(this.label, this.start, this.end, this.arc, this.text);
}

const _phases = <_Phase>[
  _Phase('MENSTRUAL', 0, 5, Color(0xFFFF8A8A), Color(0xFFA93F3A)),
  _Phase('FOLLICULAR', 5, 13, Color(0xFF6DC55A), Color(0xFF2F7A24)),
  _Phase('OVULATION', 13, 14, Color(0xFF5ECFB0), Color(0xFF1F7564)),
  _Phase('LUTEAL', 14, 28, Color(0xFFFAC775), Color(0xFF8F5F0E)),
];

const _kInk = Color(0xFF163220);
const _kSub = Color(0xFF2E4A33);
const _kCentre = Color(0xFFF6FBF3);

class _Slide {
  final String? emoji;
  final String big;
  final String caption;
  final bool isNumber;
  const _Slide(this.emoji, this.big, this.caption, {this.isNumber = false});
}

const _slides = <_Slide>[
  _Slide(null, '28', 'DAYS · YOUR CYCLE', isNumber: true),
  _Slide('🏃‍♀️', 'Movement', 'Workouts that match your energy'),
  _Slide('🥗', 'Nutrition', 'Meals that match your phase'),
  _Slide('🌸', 'Hormones', 'One plan that follows your body'),
];

class _AnimatedCycleWheelState extends State<AnimatedCycleWheel>
    with TickerProviderStateMixin {
  late final AnimationController _draw; // ring draw-in
  late final AnimationController _orbit; // dot, 50 s per turn
  late final AnimationController _fold; // centre fold between slides
  // Splash hand-off: the 4 splash dots fly to their phases, then each
  // draws its colour along the ring (first launch only).
  late final AnimationController _intro;
  List<Offset>? _introFrom; // splash dots, screen coordinates
  List<Offset>? _introLocal; // same, in this ring's coordinates
  bool get _introPending => _introFrom != null && _introLocal == null;
  bool get _introOn => _introLocal != null && !_intro.isCompleted;
  Timer? _slideTimer;
  int _slide = 0;
  int _prevSlide = 0;
  // Words currently shown on any ring, so the ring that flies to Login
  // keeps the same words instead of jumping back to the first one.
  static int _lastSlide = 0;
  static bool _everDrawn = false;
  static final DateTime _orbitEpoch = DateTime.now();
  static double _sharedOrbit() =>
      (DateTime.now().difference(_orbitEpoch).inMilliseconds % 50000) / 50000.0;

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
    // Colours draw in only the first time the app shows a ring. Rings
    // built later (coming back from Login / Sign-up, the flying ring)
    // start full and carry on with the same words.
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    final fromSplash = widget.drawIn && !_everDrawn ? SplashIntro.take() : null;
    if (fromSplash != null && fromSplash.length == 4) {
      _everDrawn = true;
      _draw.value = 1;
      _introFrom = fromSplash;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startIntro());
    } else if (widget.drawIn && !_everDrawn) {
      _everDrawn = true;
      _draw.forward();
    } else {
      _draw.value = 1;
      _slide = _prevSlide = _lastSlide;
    }
    // One shared clock for every ring (Welcome, the flying ring, Login):
    // the dot is always at the same point of the cycle, so it carries on
    // smoothly across screens instead of starting again.
    _orbit = AnimationController(vsync: this, duration: const Duration(seconds: 50))
      ..value = _sharedOrbit()
      ..repeat();
    _fold = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))
      ..value = 1;
    // Words start changing once the ring has drawn.
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) _startLoop();
    });
  }

  /// Convert the splash dots to this ring's coordinates, hold them still
  /// while the splash fades out, then fly + draw.
  void _startIntro() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      setState(() => _introFrom = null); // fall back: ring just shows
      return;
    }
    setState(() => _introLocal = [for (final g in _introFrom!) box.globalToLocal(g)]);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) _intro.forward();
    });
  }

  void _startLoop() {
    _slideTimer?.cancel();
    _slideTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) => _next());
  }

  void _next() {
    if (!mounted) return;
    setState(() {
      _prevSlide = _slide;
      _slide = (_slide + 1) % _slides.length;
      _lastSlide = _slide;
    });
    _fold.forward(from: 0);
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _draw.dispose();
    _orbit.dispose();
    _fold.dispose();
    _intro.dispose();
    super.dispose();
  }

  // ── Colour helpers ─────────────────────────────────────────────────────
  static int _phaseIndexAt(double day) {
    for (var i = 0; i < _phases.length; i++) {
      if (day < _phases[i].end) return i;
    }
    return _phases.length - 1;
  }

  /// Phase colour at [day], blended over ~1.5 days at each edge.
  static Color _colorAt(double day) {
    const blend = 1.5;
    final i = _phaseIndexAt(day);
    final p = _phases[i];
    final next = _phases[(i + 1) % _phases.length];
    final prev = _phases[(i + _phases.length - 1) % _phases.length];
    if (p.end - day < blend) {
      return Color.lerp(p.arc, next.arc, (1 - (p.end - day) / blend) / 2)!;
    }
    if (day - p.start < blend) {
      return Color.lerp(p.arc, prev.arc, (1 - (day - p.start) / blend) / 2)!;
    }
    return p.arc;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final pad = s * 0.08; // labels may overflow (Clip.none); keep layout tight
    final box = s + pad * 2;
    final stroke = s * 0.066;
    final centre = s - stroke * 2 - s * 0.035;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _next();
        _startLoop();
      },
      child: SizedBox(
        width: box,
        height: box,
        child: AnimatedBuilder(
          animation: Listenable.merge([_draw, _orbit, _intro]),
          builder: (context, _) {
            // Splash hand-off timeline (u: 0 → 1 over 1.4 s).
            final u = _intro.value;
            final intro = _introOn || _introPending;
            final grow = _introPending ? 0.0 : Curves.easeOut.transform(((u - 0.38) / 0.42).clamp(0.0, 1.0));
            final centreIn = _introPending ? 0.0 : Curves.easeOutBack.transform(((u - 0.62) / 0.3).clamp(0.0, 1.0));
            double labelIn(int i) =>
                _introPending ? 0.0 : Curves.easeOutBack.transform(((u - 0.72 - i * 0.04) / 0.24).clamp(0.0, 1.0));
            // Position from the shared clock (not this ring's own timer,
            // which pauses while the screen is hidden behind Login).
            final orbit = _sharedOrbit();
            final angle = orbit * 2 * math.pi; // 0 = 12 o'clock
            final day = orbit * 28;
            final current = _phaseIndexAt(day);
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1) Ring (smooth colours, draws itself in).
                Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      // Neutral soft shadow (no green haze on white).
                      BoxShadow(
                        color: const Color(0xFF163220).withValues(alpha: 0.07),
                        offset: const Offset(0, 22),
                        blurRadius: 48,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: Curves.easeInOut.transform(_draw.value),
                      stroke: stroke,
                      grow: intro ? grow : null,
                    ),
                  ),
                ),
                // 2) White centre with the folding words.
                if (intro)
                  Opacity(
                    opacity: centreIn.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * centreIn,
                      child: _centreDisc(centre),
                    ),
                  )
                else
                  _centreDisc(centre),
                // 3) Phase labels (current one grows a little).
                for (var i = 0; i < _phases.length; i++)
                  if (intro)
                    Opacity(
                      opacity: labelIn(i).clamp(0.0, 1.0),
                      child: Transform.scale(scale: 0.6 + 0.4 * labelIn(i), child: _label(i, s, active: false)),
                    )
                  else
                    _label(i, s, active: i == current && _draw.isCompleted),
                // 3b) Splash dots flying to their phases.
                if (_introOn)
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size(box, box),
                      painter: _IntroDotsPainter(
                        from: _introLocal!,
                        u: u,
                        ringRadius: s / 2 - stroke / 2,
                        stroke: stroke,
                      ),
                    ),
                  ),
                // 4) The dot, on top of everything.
                if (_draw.isCompleted && !intro)
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size(box, box),
                      painter: _DotPainter(
                        angle: angle,
                        radius: s / 2 - stroke / 2,
                        color: _colorAt(day),
                        dotRadius: s * 0.034,
                        pulse: 0.5 + 0.5 * math.sin(orbit * 2 * math.pi * 18),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _centreDisc(double centre) => Container(
        width: centre,
        height: centre,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _kCentre,
          boxShadow: [
            BoxShadow(
              color: _kInk.withValues(alpha: 0.08),
              offset: const Offset(0, 12),
              blurRadius: 24,
            ),
          ],
        ),
        child: ClipOval(child: _centre(centre)),
      );

  // Label positions: angle from 12 o'clock (clockwise) and distance from
  // the centre, as a share of the ring size.
  static const _labelAt = <List<double>>[
    // Pulled inward to sit on the ring (ring centre ≈ 0.467), so the
    // labels hug the wheel instead of floating off the screen edge.
    [32, 0.47], // menstrual
    [116, 0.47], // follicular
    [174, 0.54], // ovulation (just under the thin teal arc so it stays visible)
    [270, 0.46], // luteal
  ];

  Widget _label(int i, double s, {required bool active}) {
    final p = _phases[i];
    final a = _labelAt[i][0] * math.pi / 180;
    final r = _labelAt[i][1] * s;
    final fs = (s * 0.038).clamp(8.5, 11.0);
    return Transform.translate(
      offset: Offset(r * math.sin(a), -r * math.cos(a)),
      child: AnimatedScale(
        // The phase the dot is in grows a bit more (looks livelier).
        scale: active ? 1.22 : 1.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: s * 0.034, vertical: s * 0.017),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: active ? 0.12 : 0.06),
                blurRadius: active ? 16 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            p.label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: fs,
              fontWeight: FontWeight.w700,
              color: p.text,
              letterSpacing: fs * 0.12,
            ),
          ),
        ),
      ),
    );
  }

  // ── Centre: Fold between slides ───────────────────────────────────────
  Widget _centre(double d) {
    return AnimatedBuilder(
      animation: _fold,
      builder: (context, _) {
        final t = _fold.value;
        // 0..0.45: old folds away (0° → 90°); 0.45..1: new unfolds (-90° → 0°)
        final outT = (t / 0.45).clamp(0.0, 1.0);
        final inT = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
        final showingOld = t < 0.45 && _prevSlide != _slide;
        final idx = showingOld ? _prevSlide : _slide;
        final rot = showingOld
            ? Curves.easeIn.transform(outT) * math.pi / 2
            : -(1 - Curves.easeOut.transform(inT)) * math.pi / 2;
        final opacity = showingOld ? 1 - outT : inT;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(rot),
            child: _slideView(_slides[idx], d, captionT: showingOld ? 1 : inT),
          ),
        );
      },
    );
  }

  Widget _slideView(_Slide sl, double d, {required double captionT}) {
    final w = widget.size;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sl.emoji != null)
            Padding(
              padding: EdgeInsets.only(bottom: w * 0.02),
              child: Text(sl.emoji!, style: TextStyle(fontSize: w * 0.09)),
            ),
          Text(
            sl.big,
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: sl.isNumber ? w * 0.207 : w * 0.131,
              fontWeight: FontWeight.w300,
              color: _kInk,
              letterSpacing: sl.isNumber ? -w * 0.008 : -w * 0.0026,
              height: 1.0,
            ),
          ),
          if (widget.showCaption || sl.isNumber) SizedBox(height: w * 0.028),
          if (widget.showCaption || sl.isNumber)
          Opacity(
            opacity: Curves.easeOut.transform(captionT.clamp(0.0, 1.0)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: d * 0.68),
              child: Text(
                sl.caption,
                textAlign: TextAlign.center,
                style: sl.isNumber
                    ? TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (w * 0.038).clamp(9.0, 11.0),
                        fontWeight: FontWeight.w700,
                        color: _kSub,
                        letterSpacing: 1.6,
                      )
                    : TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (w * 0.043).clamp(10.5, 12.5),
                        fontWeight: FontWeight.w600,
                        color: _kSub,
                        height: 1.35,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Smooth-colour ring, drawn clockwise from 12 o'clock up to [progress].
class _RingPainter extends CustomPainter {
  final double progress;
  final double stroke;
  /// Splash hand-off: each phase grows from its own start (0 → 1).
  final double? grow;
  _RingPainter({required this.progress, required this.stroke, this.grow});

  @override
  void paint(Canvas canvas, Size size) {
    if (grow != null && grow! <= 0) return;
    if (progress <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    // Stops in days/28; each phase blends into the next.
    final shader = const SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [
        Color(0xFFFF8A8A),
        Color(0xFFFF8A8A),
        Color(0xFF6DC55A),
        Color(0xFF6DC55A),
        Color(0xFF5ECFB0),
        Color(0xFFFAC775),
        Color(0xFFFAC775),
        Color(0xFFFF8A8A),
      ],
      stops: [0.0, 0.128, 0.233, 0.439, 0.481, 0.533, 0.917, 1.0],
      transform: GradientRotation(-math.pi / 2),
    ).createShader(rect);
    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;
    if (grow != null) {
      // Four arcs at once, each from its phase start towards the next.
      for (final p in _phases) {
        final a0 = -math.pi / 2 + p.start / 28 * 2 * math.pi;
        final sweep = (p.end - p.start) / 28 * 2 * math.pi * grow!;
        canvas.drawArc(rect, a0, sweep, false, paint);
      }
      return;
    }
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.grow != grow;
}

/// The travelling dot: soft glow + coloured dot with a white border.
class _DotPainter extends CustomPainter {
  final double angle; // 0 = 12 o'clock, clockwise
  final double radius;
  final Color color;
  final double dotRadius;
  final double pulse; // 0..1
  _DotPainter({
    required this.angle,
    required this.radius,
    required this.color,
    required this.dotRadius,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = c + Offset(radius * math.sin(angle), -radius * math.cos(angle));
    // Glow
    canvas.drawCircle(
      p,
      dotRadius * (1.45 + 0.25 * pulse),
      Paint()..color = color.withValues(alpha: 0.25),
    );
    // Shadow
    canvas.drawCircle(
      p + const Offset(0, 1),
      dotRadius + 1,
      Paint()
        ..color = const Color(0xFF163220).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // White border + dot
    canvas.drawCircle(p, dotRadius + dotRadius * 0.36, Paint()..color = Colors.white);
    canvas.drawCircle(p, dotRadius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) =>
      old.angle != angle || old.color != color || old.pulse != pulse;
}

/// Splash hand-off: the 4 splash dots fly (curved path) from where they
/// were on the splash to the start of their phase on the ring, growing to
/// the ring's thickness; they fade into the arcs as those start drawing.
class _IntroDotsPainter extends CustomPainter {
  _IntroDotsPainter({required this.from, required this.u, required this.ringRadius, required this.stroke});
  final List<Offset> from;
  final double u;
  final double ringRadius;
  final double stroke;

  static const _splashColors = [Color(0xFFFF8A8A), Color(0xFF6DC55A), Color(0xFFA8F0C0), Color(0xFFFAC775)];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 4 && i < from.length; i++) {
      final p = _phases[i];
      final a = -math.pi / 2 + p.start / 28 * 2 * math.pi;
      final to = c + Offset(math.cos(a), math.sin(a)) * ringRadius;
      final m = Curves.easeInOutCubic.transform(((u - i * 0.03) / 0.4).clamp(0.0, 1.0));
      // Control point pulled outward and up, for a soft curve.
      final mid = Offset((from[i].dx + to.dx) / 2, (from[i].dy + to.dy) / 2);
      final ctrl = mid + Offset((to.dx - c.dx) * 0.6, -size.height * 0.18);
      final x = (1 - m) * (1 - m) * from[i].dx + 2 * (1 - m) * m * ctrl.dx + m * m * to.dx;
      final y = (1 - m) * (1 - m) * from[i].dy + 2 * (1 - m) * m * ctrl.dy + m * m * to.dy;
      final fade = 1 - ((u - 0.78) / 0.12).clamp(0.0, 1.0);
      if (fade <= 0) continue;
      final r = 3.5 + (stroke / 2 - 3.5) * m;
      final col = Color.lerp(_splashColors[i], p.arc, m)!;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = col.withValues(alpha: fade));
    }
  }

  @override
  bool shouldRepaint(covariant _IntroDotsPainter old) => old.u != u || old.from != from;
}
