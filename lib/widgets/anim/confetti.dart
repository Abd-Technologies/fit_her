import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// A short, light confetti burst in brand colours (~1.3 s, plays once).
/// Paints around its own (zero-size) origin: place it where the burst
/// should start, inside a Stack with clipBehavior: Clip.none.
/// Calm mode (reduce motion): draws nothing.
class FhConfettiBurst extends StatefulWidget {
  const FhConfettiBurst({super.key, this.count = 34});

  final int count;

  @override
  State<FhConfettiBurst> createState() => _FhConfettiBurstState();
}

class _Particle {
  _Particle({
    required this.x,
    required this.u,
    required this.y,
    required this.rot,
    required this.delay,
    required this.color,
    required this.round,
  });

  final double x; // final sideways drift
  final double u; // height of the upward pop (negative = up)
  final double y; // final fall distance
  final double rot; // total rotation (radians)
  final double delay; // 0..~0.08 of the run
  final Color color;
  final bool round;
}

class _FhConfettiBurstState extends State<FhConfettiBurst>
    with SingleTickerProviderStateMixin {
  static const List<Color> _colors = [
    Color(0xFF6DC55A),
    Color(0xFFA8F0C0),
    Color(0xFFFAC775),
    Color(0xFFFF8A8A),
    Color(0xFF5ECFB0),
    Color(0xFF8AD167),
  ];

  // 1.3 s per piece + up to 120 ms stagger.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1420),
  );
  late final List<_Particle> _parts;
  bool _calm = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _parts = List.generate(widget.count, (i) {
      final a = rnd.nextDouble() * math.pi + math.pi; // upward half
      final sp = 70 + rnd.nextDouble() * 90;
      return _Particle(
        x: math.cos(a) * sp * 1.3,
        u: math.sin(a) * sp * 0.9 - 10,
        y: 160 + rnd.nextDouble() * 180,
        rot: (rnd.nextDouble() * 720 - 360) * math.pi / 180,
        delay: rnd.nextDouble() * 120 / 1420,
        color: _colors[i % _colors.length],
        round: i % 3 == 0,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _calm = Motion.calm(context);
    if (!_calm) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_calm) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.zero,
        painter: _ConfettiPainter(_c, _parts),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.anim, this.parts) : super(repaint: anim);

  final Animation<double> anim;
  final List<_Particle> parts;

  static const double _life = 1300 / 1420; // one piece's share of the run
  static const Curve _curve = Cubic(0.2, 0.6, 0.35, 1);

  @override
  void paint(Canvas canvas, Size size) {
    final v = anim.value;
    if (v <= 0 || v >= 1) return;
    final paint = Paint();
    for (final p in parts) {
      final raw = (v - p.delay) / _life;
      if (raw <= 0 || raw >= 1) continue;
      final t = _curve.transform(raw.clamp(0.0, 1.0));
      double dx, dy, sc, op, r;
      if (t < 0.35) {
        final k = t / 0.35;
        dx = p.x * 0.7 * k;
        dy = p.u * k;
        sc = 0.5 + 0.5 * k;
        op = 1;
        r = p.rot * 0.5 * k;
      } else {
        final k = (t - 0.35) / 0.65;
        dx = p.x * 0.7 + (p.x - p.x * 0.7) * k;
        dy = p.u + (p.y - p.u) * k;
        sc = 1 - 0.1 * k;
        op = 1 - k;
        r = p.rot * (0.5 + 0.5 * k);
      }
      paint.color = p.color.withValues(alpha: op.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(r);
      canvas.scale(sc, sc);
      if (p.round) {
        canvas.drawCircle(Offset.zero, 4, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 7, height: 11),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
