import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Fit Her loader (replaces the plain spinning circle app-wide).
/// A white badge with a soft shadow, a green arc going round and a small
/// leaf that gently breathes. Works on white pages and on the dim
/// background of a "please wait" dialog. Shrinks to just the arc when the
/// space is small. With "reduce motion" on, it turns slowly without the
/// breathing.
class FhLoader extends StatefulWidget {
  const FhLoader({super.key, this.size = 52});
  final double size;

  @override
  State<FhLoader> createState() => _FhLoaderState();
}

class _FhLoaderState extends State<FhLoader> with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF6DC55A);
  static const _greenDark = Color(0xFF3F8F3A);
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return LayoutBuilder(builder: (context, box) {
      final room = math.min(box.maxWidth.isFinite ? box.maxWidth : widget.size,
          box.maxHeight.isFinite ? box.maxHeight : widget.size);
      final size = math.min(widget.size, room);
      final compact = size < 36;
      return Semantics(
        label: 'Loading',
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final arc = CustomPaint(
                painter: _ArcPainter(turn: calm ? t * 0.5 : t, stroke: compact ? 2.5 : 3),
              );
              if (compact) return arc;
              final breathe = calm ? 1.0 : 0.9 + 0.1 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _greenDark.withValues(alpha: 0.14), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                child: Stack(fit: StackFit.expand, children: [
                  Padding(padding: EdgeInsets.all(size * 0.1), child: arc),
                  Center(
                    child: Transform.scale(
                      scale: breathe,
                      child: Icon(Icons.spa_rounded, size: size * 0.36, color: _green),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      );
    });
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.turn, required this.stroke});
  final double turn;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final track = Paint()
      ..color = const Color(0xFFE3ECDD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, 2 * math.pi, false, track);
    final start = turn * 2 * math.pi - math.pi / 2;
    final sweep = math.pi * (0.55 + 0.25 * math.sin(turn * 2 * math.pi));
    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: const [Color(0x006DC55A), Color(0xFF6DC55A), Color(0xFF3F8F3A)],
        stops: const [0.0, 0.6, 1.0],
        transform: GradientRotation(start),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(r, start, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.turn != turn || old.stroke != stroke;
}
