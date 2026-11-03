import 'package:flutter/material.dart';

/// Fit Her staff portal look (same colours as the app).
class PT {
  PT._();
  static const green = Color(0xFF6DC55A);
  static const greenDark = Color(0xFF4C6A4B);
  static const ink = Color(0xFF1A3A22);
  static const sage = Color(0xFF7A8C78);
  static const wash = Color(0xFFF6FBF3);
  static const canvas = Color(0xFFF7F9F5);
  static const line = Color(0xFFE3ECDD);
  static const red = Color(0xFFC24A4A);
  static const amber = Color(0xFFC77B2B);

  static TextStyle t(double size, {FontWeight w = FontWeight.w400, Color c = ink, double? h}) =>
      TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: w, color: c, height: h);

  static ThemeData theme() => ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: green, width: 1.5)),
        ),
      );

  /// White card with the soft green border.
  static BoxDecoration card() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      );
}

/// Small toast at the top right (portal only; no app dependencies).
void portalToast(String title, {String? sub, bool error = false}) {
  final ctx = portalNavKey.currentContext;
  if (ctx == null) return;
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    width: 380,
    backgroundColor: Colors.white,
    elevation: 6,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: PT.line)),
    duration: Duration(seconds: error ? 4 : 3),
    content: Row(children: [
      Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(color: Color(0xFFEAF7E4), shape: BoxShape.circle),
        child: Icon(error ? Icons.error_outline_rounded : Icons.check_rounded, size: 17, color: PT.green),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: PT.t(13.5, w: FontWeight.w600)),
          if (sub != null) Text(sub, style: PT.t(12, c: PT.sage)),
        ]),
      ),
    ]),
  ));
}

final GlobalKey<NavigatorState> portalNavKey = GlobalKey<NavigatorState>();
