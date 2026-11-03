import 'package:flutter/material.dart';

/// Fit Her Design System — Color Tokens
///
/// NOTE (Oct 2026): these are the OLD (V1) colours. The design that ships
/// today (V2 screens) uses brand green #6DC55A and forest ink #163220;
/// see lib/docs/newdesign.md. `primary` below (#8AD167) is kept only
/// because 130 older widgets still use it.
///
/// Semantic color names organized by role.
/// Migration from MyColors → AppColors happens in Phase 3.
///
/// old token → new token mapping is documented inline.
class AppColors {
  AppColors._();

  // ─── Brand / Primary ─────────────────────────────────────
  /// The main brand green. Used for buttons, highlights, active states.
  static const Color primary = Color(0xFF8AD167);           // was: buttonColor (130 uses)
  static const Color primaryDark = Color(0xFF4CCB28);       // was: primaryGradient1 (28 uses)
  static const Color primaryMedium = Color(0xFF6FD251);     // was: primaryGradient2 (8 uses)
  static const Color primaryDeep = Color(0xFF4C6A4B);       // was: primaryGradient3 (6 uses)
  static const Color accent = Color(0xFFEB5729);            // was: primary2 (4 uses)

  static const List<Color> primaryGradient = [
    Color(0xFF89CB68),
    Color(0xFF8AD167),
  ];                                                        // was: mainGradient (3 uses)

  // ─── Backgrounds & Surfaces ──────────────────────────────
  static const Color background = Color(0xFFFFFFFF);        // was: bodyBackground, appBackground, primaryColor
  static const Color surface = Color(0xFFF5F5F5);           // was: grey100 (6 uses)
  static const Color surfaceBorder = Color(0xFFEEEEEE);     // was: grey200 (2 uses)
  static const Color inputBackground = Color(0xFFF5FDF2);   // was: textFieldColor (13 uses)
  static const Color cardGreen = Color(0xFFE4F9D7);         // was: planColor (15 uses)
  static const Color cardGreenLight = Color(0xFFEDF5EA);    // was: healthTipsColor (1 use)

  // ─── Text ────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF000000);       // was: textColor (62), black (56)
  static const Color textSecondary = Color(0xFF1D1B20);     // was: textColor3 (20 uses)
  static const Color textTertiary = Color(0xFF525252);      // was: grey (19 uses)
  static const Color textHint = Color(0xFF969696);          // was: hintText (7 uses)
  static const Color textOnPrimary = Color(0xFFFFFFFF);     // was: textColor2 (7 uses)

  // ─── Icons ───────────────────────────────────────────────
  static const Color iconDark = Color(0xFF000000);          // was: iconColor2 (6 uses)
  static const Color iconLight = Color(0xFFFFFFFF);         // was: iconColor1 (1 use)

  // ─── Dividers & Borders ──────────────────────────────────
  static const Color divider = Color(0xFFE5E7EB);          // was: dividerColor (3 uses)

  // ─── State / Feedback ────────────────────────────────────
  static const Color error = Color(0xFFFF5740);             // was: error (1 use)
  static const Color errorDark = Color(0xFFF50606);         // was: red1 (1 use)
  static const Color errorBright = Color(0xFFFC0000);       // was: red500 (1 use)
  static const Color success = Color(0xFF5AAC63);           // was: dialog

  // ─── Workout Section ─────────────────────────────────────
  static const Color workoutLight = Color(0xFFCBF0BC);      // was: workOut1 (5 uses)
  static const Color workoutDark = Color(0xFF8AD167);       // was: workOut2 (3 uses)
  static const Color workoutTextMuted = Color(0xFFA0B695);  // was: workOutTextColor (3 uses)

  // ─── Accent / One-off ────────────────────────────────────
  static const Color blue = Color(0xFF49A2DA);              // was: darkBlue (1 use)
  static const Color lime = Color(0xFFEBFD6C);              // was: yellow, green (1 use each)
  static const Color limeGreen = Color(0xFFB5FB1E);         // was: green100 (1 use)
  static const Color mintGreen = Color.fromARGB(255, 129, 248, 139); // was: green50 (1 use)
  static const Color offWhite = Color(0xFFF1F8FF);          // was: white200 (1 use)
}
