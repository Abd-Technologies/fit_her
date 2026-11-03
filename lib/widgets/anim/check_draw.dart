import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// A green tick in a soft circle that draws itself (~650 ms):
/// the ring sweeps round, then the tick strokes in, then a tiny pop.
/// Calm mode (reduce motion): the finished tick, no movement.
class FhCheckDraw extends StatefulWidget {
  const FhCheckDraw(
    this.size,
    this.color, {
    super.key,
    this.delay = const Duration(milliseconds: 150),
  });

  final double size;
  final Color color;

  /// Wait before drawing starts (lets the dialog fade in first).
  final Duration delay;

  @override
  State<FhCheckDraw> createState() => _FhCheckDrawState();
}

class _FhCheckDrawState extends State<FhCheckDraw>
    with SingleTickerProviderStateMixin {
  // Ring 0-430 ms, tick 360-650 ms, pop 520-800 ms.
  static const int _totalMs = 800;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.calm(context)) {
      _c.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double t, int fromMs, int toMs, Curve curve) {
    final ms = t * _totalMs;
    if (ms <= fromMs) return 0;
    if (ms >= toMs) return 1;
    return curve.transform((ms - fromMs) / (toMs - fromMs));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final ring = _seg(t, 0, 430, const Cubic(0.6, 0, 0.3, 1));
        final tick = _seg(t, 360, 650, Curves.easeInOut);
        final pop = _seg(t, 520, 800, Curves.easeInOut);
        final scale = 1 + 0.08 * math.sin(pop * math.pi);
        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _CheckPainter(
              color: widget.color,
              ring: ring,
              tick: tick,
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.color, required this.ring, required this.tick});

  final Color color;
  final double ring;
  final double tick;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 72 x 72 grid, scaled to [size].
    final s = size.width / 72.0;
    canvas.save();
    canvas.scale(s, s);

    final center = const Offset(36, 36);
    canvas.drawCircle(
      center,
      36,
      Paint()..color = color.withValues(alpha: 0.14),
    );

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (ring > 0) {
      stroke.strokeWidth = 4;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 30),
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        stroke,
      );
    }

    if (tick > 0) {
      stroke.strokeWidth = 5;
      final path = Path()
        ..moveTo(23, 37.5)
        ..lineTo(32, 46.5)
        ..lineTo(49, 27.5);
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * tick), stroke);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.ring != ring || old.tick != tick || old.color != color;
}
