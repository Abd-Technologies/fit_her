import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// One soft fade-and-slide for every screen change (Get.to and Navigator).
/// The new screen fades in while sliding a little from the right (6%).
/// With "reduce motion" on, it simply fades.
Widget _fhFadeSlide(BuildContext context, Animation<double> animation, Widget child) {
  final calm = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  final fade = FadeTransition(opacity: curved, child: child);
  if (calm) return fade;
  return SlideTransition(
    position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
    child: fade,
  );
}

/// For GetMaterialApp(customTransition: FhPageTransition()).
class FhPageTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      _fhFadeSlide(context, animation, child);
}

/// For ThemeData.pageTransitionsTheme (covers Navigator.push / MaterialPageRoute).
class FhPageTransitionsBuilder extends PageTransitionsBuilder {
  const FhPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      _fhFadeSlide(context, animation, child);
}
