import 'package:flutter/widgets.dart';

/// Hand-off from the splash to the Welcome ("Get started") screen.
/// The splash saves where its 4 cycle dots are on screen; the Welcome
/// ring then flies those dots to their phases and draws itself from them.
/// Only for the first few seconds after the splash (first launch path).
class SplashIntro {
  SplashIntro._();

  static List<Offset>? _dots;
  static DateTime? _at;

  /// Splash: the 4 dot centres in global (screen) coordinates.
  static void set(List<Offset> dots) {
    _dots = List.of(dots);
    _at = DateTime.now();
  }

  /// True for 3 s after the splash handed over (used by the Welcome
  /// screen to animate its title/button in).
  static bool get active => _at != null && DateTime.now().difference(_at!) < const Duration(seconds: 3);

  /// The ring takes the dots once; later rings (login, coming back) don't.
  static List<Offset>? take() {
    if (!active) return null;
    final d = _dots;
    _dots = null;
    return d;
  }
}
