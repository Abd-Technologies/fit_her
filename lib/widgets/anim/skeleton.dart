import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'motion.dart';

/// Grey placeholder block shaped like the real content it stands in for.
class FhSkeleton extends StatelessWidget {
  /// Soft grey-green used on the cream/white app surfaces.
  static const Color light = Color(0xFFEDF5EA);

  /// Faint white used on the dark hero.
  static const Color onDark = Color(0x14FFFFFF);

  final double? width;
  final double? height;
  final double radius;
  final Color color;
  final EdgeInsetsGeometry? margin;
  final BoxShape shape;

  const FhSkeleton({
    super.key,
    this.width,
    this.height,
    this.radius = 6,
    this.color = FhSkeleton.light,
    this.margin,
    this.shape = BoxShape.rectangle,
  });

  /// Round placeholder (avatar, icon, ring).
  const FhSkeleton.circle({
    super.key,
    required double size,
    this.color = FhSkeleton.light,
    this.margin,
  })  : width = size,
        height = size,
        radius = 0,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Wraps a group of [FhSkeleton]s with a soft moving shine (1.3 s loop).
/// The shine only paints over the child's opaque pixels.
/// With "reduce motion" on, the placeholders stay still.
class FhSkeletonShine extends StatelessWidget {
  final Widget child;

  /// Shine colour. Default suits light surfaces; use
  /// `Colors.white.withOpacity(0.13)` on the dark hero.
  final Color? color;

  const FhSkeletonShine({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    if (Motion.calm(context)) return child;
    return child
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1300),
          color: color ?? Colors.white.withOpacity(0.85),
        );
  }
}
