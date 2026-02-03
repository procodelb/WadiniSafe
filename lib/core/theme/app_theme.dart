import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // Text Theme using Cairo
  static TextTheme _buildTextTheme(TextTheme base, Color primaryColor, Color secondaryColor) {
    return GoogleFonts.cairoTextTheme(base).copyWith(
      displayLarge: GoogleFonts.cairo(
        textStyle: base.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
      ),
      displayMedium: GoogleFonts.cairo(
        textStyle: base.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
      ),
      displaySmall: GoogleFonts.cairo(
        textStyle: base.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
      ),
      headlineMedium: GoogleFonts.cairo(
        textStyle: base.headlineMedium?.copyWith(fontWeight: FontWeight.w600, color: primaryColor),
      ),
      titleLarge: GoogleFonts.cairo(
        textStyle: base.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: primaryColor),
      ),
      bodyLarge: GoogleFonts.cairo(
        textStyle: base.bodyLarge?.copyWith(color: secondaryColor),
      ),
      bodyMedium: GoogleFonts.cairo(
        textStyle: base.bodyMedium?.copyWith(color: secondaryColor),
      ),
    );
  }

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surfaceLight,
      background: AppColors.backgroundLight,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: AppColors.textPrimaryLight,
      onBackground: AppColors.textPrimaryLight,
    ),
    textTheme: _buildTextTheme(
      ThemeData.light().textTheme,
      AppColors.textPrimaryLight,
      AppColors.textSecondaryLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
      ),
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.primary, // Keep brand color or adjust slightly
    scaffoldBackgroundColor: AppColors.backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surfaceDark,
      background: AppColors.backgroundDark,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: AppColors.textPrimaryDark,
      onBackground: AppColors.textPrimaryDark,
    ),
    textTheme: _buildTextTheme(
      ThemeData.dark().textTheme,
      AppColors.textPrimaryDark,
      AppColors.textSecondaryDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceDark,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
      ),
    ),
  );
}
