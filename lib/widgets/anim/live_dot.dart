import 'package:flutter/material.dart';

import 'motion.dart';

/// Small "LIVE" dot that gently breathes, with a soft ring that grows and
/// fades (1.6 s loop). With "reduce motion" on it is a plain still dot.
/// Takes exactly [size] x [size] of layout; the ring paints outside it.
class FhLiveDot extends StatefulWidget {
  final double size;
  final Color color;

  const FhLiveDot({super.key, this.size = 5, this.color = Colors.white});

  @override
  State<FhLiveDot> createState() => _FhLiveDotState();
}

class _FhLiveDotState extends State<FhLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.calm(context)) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _dot() => DecoratedBox(
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    if (Motion.calm(context)) {
      return SizedBox(width: s, height: s, child: _dot());
    }
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value; // 0..1
          // Breathe: 1 -> 0.72 -> 1 (scale), 1 -> 0.55 -> 1 (opacity).
          final b = Curves.easeInOut.transform(t < 0.5 ? t * 2 : (1 - t) * 2);
          final ringT = Curves.easeOut.transform(t);
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Ring: grows from the dot outwards and fades away.
              Positioned.fill(
                child: Transform.scale(
                  scale: 1 + ringT * 1.6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withOpacity(0.45 * (1 - ringT)),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Transform.scale(
                  scale: 1 - 0.28 * b,
                  child: Opacity(opacity: 1 - 0.45 * b, child: _dot()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
