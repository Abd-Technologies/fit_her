import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shared motion rules for the app (Oct 2026 animation pass).
/// - Keep animations short (<= 600 ms) and calm.
/// - When the phone's "reduce motion" setting is on, show the end state.
/// - Never animate payment forms, medical forms, number entry, or the live class itself.
class Motion {
  Motion._();

  static const Duration fast = Duration(milliseconds: 220);
  static const Duration normal = Duration(milliseconds: 420);
  static const Duration slow = Duration(milliseconds: 600);
  static const Curve ease = Curves.easeOutCubic;

  /// True when the user asked the phone for less motion.
  static bool calm(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

extension FhMotion on Widget {
  /// Fade + slide up, for items that appear one after another.
  /// [index] staggers the start (70 ms apart).
  Widget fhEnter(BuildContext context, {int index = 0, double dy = 0.12}) {
    if (Motion.calm(context)) return this;
    final delay = Duration(milliseconds: 60 + index * 70);
    return animate()
        .fadeIn(delay: delay, duration: Motion.normal, curve: Motion.ease)
        .slideY(begin: dy, end: 0, delay: delay, duration: Motion.normal, curve: Motion.ease);
  }
}
