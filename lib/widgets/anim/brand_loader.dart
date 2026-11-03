import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../values/my_imgs.dart';
import 'motion.dart';

/// Branded "please wait" block: the Fit Her wordmark gently pulsing
/// (scale 0.94 <-> 1.0), three bouncing dots and a title with a ticking
/// ellipsis. Optional subtitle (e.g. class name) and caption lines below.
/// Calm mode (reduce motion): everything still, title ends in "…".
class FhBrandLoader extends StatefulWidget {
  const FhBrandLoader({
    super.key,
    this.title = 'Please wait',
    this.subtitle,
    this.caption,
    this.logoWidth = 150,
  });

  final String title;
  final String? subtitle;
  final String? caption;
  final double logoWidth;

  @override
  State<FhBrandLoader> createState() => _FhBrandLoaderState();
}

class _FhBrandLoaderState extends State<FhBrandLoader>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFF6DC55A);
  static const Color _ink = Color(0xFF1A3A22);
  static const Color _sage = Color(0xFF7A8C78);
  static const Color _mute = Color(0xFFA3B0A1);

  // One 6 s clock drives all three loops: pulse 1.5 s, dots 1.0 s,
  // ellipsis 1.2 s (6 s is a whole number of each).
  static const int _clockMs = 6000;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _clockMs),
  );
  bool _calm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = Motion.calm(context);
    if (_calm) {
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

  Widget _logo(double scale, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Image.asset(
          'assets/images/logo_wordmark.png',
          width: widget.logoWidth,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            MyImgs.fitHerLogo,
            width: widget.logoWidth * 0.6,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(height: 40),
          ),
        ),
      ),
    );
  }

  Widget _dot(double lift, double opacity) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Transform.translate(
        offset: Offset(0, -lift),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _green.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _title(int dots) {
    const style = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: _ink,
    );
    if (_calm) {
      return Text('${widget.title}…', textAlign: TextAlign.center, style: style);
    }
    // Keep the width steady: unused dots are drawn transparent.
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: widget.title),
        TextSpan(text: '.' * dots),
        TextSpan(
          text: '.' * (3 - dots),
          style: const TextStyle(color: Colors.transparent),
        ),
      ]),
      textAlign: TextAlign.center,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final ms = _calm ? 0.0 : _c.value * _clockMs;

        // Pulse: 1.0 -> 0.94 -> 1.0 every 1.5 s, soft fade with it.
        final pPhase = (ms % 1500) / 1500;
        final wave = (1 - math.cos(2 * math.pi * pPhase)) / 2; // 0..1..0
        final scale = 1 - 0.06 * wave;
        final opacity = 1 - 0.3 * wave;

        // Dots: each rises 6 px and brightens, 150 ms apart.
        final dots = List.generate(3, (i) {
          if (_calm) return _dot(0, 0.6);
          final ph = (((ms - i * 150) % 1000) + 1000) % 1000 / 1000;
          double k = 0;
          if (ph < 0.4) {
            k = Curves.easeInOut.transform(ph / 0.4);
          } else if (ph < 0.8) {
            k = 1 - Curves.easeInOut.transform((ph - 0.4) / 0.4);
          }
          return _dot(6 * k, 0.35 + 0.65 * k);
        });

        final int ell = math.min(3, ((ms % 1200) / 300).floor());

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _logo(scale, opacity),
            const SizedBox(height: 14),
            SizedBox(
              height: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: dots,
              ),
            ),
            const SizedBox(height: 12),
            _title(ell),
            if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, color: _sage),
              ),
            ],
            if (widget.caption != null && widget.caption!.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                widget.caption!.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 11.5, color: _mute),
              ),
            ],
          ],
        );
      },
    );
  }
}
