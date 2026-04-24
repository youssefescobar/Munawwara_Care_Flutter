import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

// Lexend is declared in pubspec.yaml fonts section.
// Do NOT use GoogleFonts.lexend() at runtime — it makes network requests that
// cause ANR on emulators. Use TextStyle(fontFamily: 'Lexend') directly.

class AppTheme {
  AppTheme._();

  static const _textTheme = TextTheme(
    displayLarge: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w700),
    displayMedium: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w700),
    displaySmall: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w600),
    headlineLarge: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(
      fontFamily: 'Lexend',
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w500),
    titleLarge: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w500),
    titleSmall: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w400),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.backgroundLight,
      ),
      textTheme: _textTheme.apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 14.sp,
          color: AppColors.textMutedDark,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.backgroundDark,
      ),
      textTheme: _textTheme.apply(
        bodyColor: AppColors.textLight,
        displayColor: AppColors.textLight,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 14.sp,
          color: AppColors.textMutedLight,
        ),
      ),
    );
  }
}
