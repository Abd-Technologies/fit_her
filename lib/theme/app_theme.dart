import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import '../widgets/anim/fh_page_transition.dart';

/// Fit Her Design System — App Theme
///
/// Combines all design tokens into a single ThemeData.
/// Replaces Styles.appTheme from values/styles.dart.
///
/// Wire in main.dart:
///   theme: AppTheme.light,
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.textPrimary,
      surface: AppColors.background,
      error: AppColors.error,
      onPrimary: AppColors.textOnPrimary,
      onSecondary: AppColors.accent,
      onSurface: AppColors.textPrimary,
      onError: AppColors.textOnPrimary,
    );

    final baseTheme = ThemeData.from(
      colorScheme: colorScheme,
      textTheme: Typography.material2018().black.apply(
            fontFamily: AppTypography.fontFamily,
            displayColor: AppColors.textPrimary,
            bodyColor: AppColors.textPrimary,
          ),
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      // Same soft fade-and-slide for Navigator.push screens (Android).
      // iOS keeps its native swipe-back transition.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FhPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),

      // ─── Icons ──────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 20,
      ),

      // ─── Cards ──────────────────────────────────────────
      cardTheme: baseTheme.cardTheme.copyWith(
        margin: EdgeInsets.zero,
      ),

      // ─── Text Selection ─────────────────────────────────
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.textPrimary,
        selectionHandleColor: AppColors.textPrimary,
      ),

      // ─── App Bar ────────────────────────────────────────
      appBarTheme: AppBarTheme(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.primary,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 24.sp,
          fontStyle: FontStyle.normal,
          color: AppColors.textPrimary,
          fontFamily: AppTypography.fontFamily,
        ),
      ),

      // ─── Dividers ───────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),

      // ─── Scrollbar ──────────────────────────────────────
      scrollbarTheme: ScrollbarThemeData(
        interactive: true,
        trackColor: MaterialStateProperty.all(AppColors.limeGreen),
        trackBorderColor: MaterialStateProperty.all(AppColors.lime),
        thickness: MaterialStateProperty.all(5.0),
        thumbColor: MaterialStateProperty.all(AppColors.blue),
        radius: const Radius.circular(10),
        minThumbLength: 10,
      ),

      // ─── Tabs ───────────────────────────────────────────
      // Oct 2026: a TabBar without its own label style took titleSmall
      // from the text theme below, which is 8 px. The text theme itself is
      // left as it is (69 + 20 screens use titleLarge/Medium/Small and
      // expect those sizes); tabs get a readable size here instead.
      tabBarTheme: TabBarThemeData(
        labelStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, fontWeight: FontWeight.w500),
      ),

      // ─── Text Theme ─────────────────────────────────────
      textTheme: _textTheme(baseTheme.textTheme),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      headlineLarge: base.headlineLarge!.copyWith(
        color: AppColors.textPrimary,
        fontSize: 32,
        fontFamily: AppTypography.fontFamily,
        fontWeight: AppTypography.bold,
      ),
      headlineMedium: base.headlineMedium!.copyWith(
        color: AppColors.textPrimary,
        fontSize: 24,
        fontFamily: AppTypography.fontFamily,
        fontStyle: FontStyle.normal,
      ),
      headlineSmall: base.headlineSmall!.copyWith(
        fontSize: 20,
        color: AppColors.textPrimary,
        fontFamily: AppTypography.fontFamily,
        fontWeight: AppTypography.bold,
        fontStyle: FontStyle.normal,
      ),
      bodyLarge: base.bodyLarge!.copyWith(
        fontSize: 18,
        color: AppColors.textPrimary,
        fontWeight: AppTypography.medium,
        fontFamily: AppTypography.fontFamily,
      ),
      bodyMedium: base.bodyMedium!.copyWith(
        fontSize: 16,
        color: AppColors.textPrimary,
        fontFamily: AppTypography.fontFamily,
        fontStyle: FontStyle.normal,
      ),
      bodySmall: base.bodySmall!.copyWith(
        fontSize: 14,
        color: AppColors.textPrimary,
        fontFamily: AppTypography.fontFamily,
        fontStyle: FontStyle.normal,
      ),
      titleLarge: base.titleLarge!.copyWith(
        fontSize: 12,
        color: AppColors.textPrimary,
        fontFamily: AppTypography.fontFamily,
        fontWeight: AppTypography.bold,
      ),
      titleMedium: base.labelLarge!.copyWith(
        fontSize: 10,
        color: AppColors.textPrimary,
        fontFamily: AppTypography.fontFamily,
        fontWeight: AppTypography.regular,
      ),
      titleSmall: base.labelMedium!.copyWith(
        fontSize: 8,
        color: AppColors.textTertiary,
        fontFamily: AppTypography.fontFamily,
      ),
    );
  }
}
