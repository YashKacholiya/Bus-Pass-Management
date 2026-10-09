// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

class AppTheme {
  AppTheme._();

  static Color getAccentColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'blue':
        return Colors.blue.shade700;
      case 'green':
        return Colors.green.shade700;
      case 'purple':
        return Colors.purple.shade700;
      case 'crimson':
      default:
        return AppColors.primaryCrimson;
    }
  }

  /// Returns the correct [ThemeData] for the given [brightness].
  /// Previously this function always returned a dark theme regardless
  /// of the [brightness] argument — that was the root cause of the
  /// theme switch not working.
  static ThemeData getTheme(String accentColorName, Brightness brightness) {
    final primaryColor = getAccentColor(accentColorName);
    return brightness == Brightness.dark
        ? _darkTheme(primaryColor)
        : _lightTheme(primaryColor);
  }

  // ─────────────────────────────────────────────────────────
  // DARK THEME — Premium Deep Navy / Charcoal
  // ─────────────────────────────────────────────────────────
  static ThemeData _darkTheme(Color primaryColor) {
    final base = ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: AppColors.surfaceElevated,
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        primaryContainer: primaryColor.withOpacity(0.18),
        onPrimaryContainer: Colors.white,
        surfaceContainerHighest: AppColors.surfaceElevated,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.cardBorder,
        outlineVariant: AppColors.cardBorderSubtle,
      ),
      scaffoldBackgroundColor: AppColors.backgroundNavy,
      dividerColor: AppColors.cardBorder,
    );

    return base.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleMedium: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 15, color: AppColors.textSecondary, height: 1.5),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 13, color: AppColors.textLight, height: 1.4),
        labelLarge: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      elevatedButtonTheme: _elevatedBtn(primaryColor),
      outlinedButtonTheme: _outlinedBtn(primaryColor),
      textButtonTheme: _textBtn(primaryColor),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.cardBorder, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        contentTextStyle: GoogleFonts.outfit(
          fontSize: 14, color: AppColors.textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundNavy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // LIGHT THEME — Premium White / Soft Gray
  // ─────────────────────────────────────────────────────────
  static ThemeData _lightTheme(Color primaryColor) {
    const bgColor = Color(0xFFF4F6FA);       // Soft cool background
    const surfaceColor = Color(0xFFFFFFFF);  // Pure white cards
    const surfaceElevated = Color(0xFFF0F2F8); // Slightly gray elevated
    const onSurfaceColor = Color(0xFF1A2030); // Near-black readable text
    const onSurfaceVariant = Color(0xFF64748B); // Muted secondary text
    const borderColor = Color(0xFFDDE3EE);   // Soft border

    final base = ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: surfaceElevated,
        onSecondary: onSurfaceColor,
        error: AppColors.error,
        onError: Colors.white,
        surface: surfaceColor,
        onSurface: onSurfaceColor,
        primaryContainer: primaryColor.withOpacity(0.10),
        onPrimaryContainer: primaryColor,
        surfaceContainerHighest: surfaceElevated,
        onSurfaceVariant: onSurfaceVariant,
        outline: borderColor,
        outlineVariant: const Color(0xFFEBEFF7),
      ),
      scaffoldBackgroundColor: bgColor,
      dividerColor: borderColor,
    );

    return base.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.bold, color: onSurfaceColor),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.bold, color: onSurfaceColor),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22, fontWeight: FontWeight.w700, color: onSurfaceColor),
        titleMedium: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w600, color: onSurfaceColor),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 15, color: onSurfaceVariant, height: 1.5),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 13, color: onSurfaceVariant, height: 1.4),
        labelLarge: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      elevatedButtonTheme: _elevatedBtn(primaryColor),
      outlinedButtonTheme: _outlinedBtn(primaryColor),
      textButtonTheme: _textBtn(primaryColor),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shadowColor: const Color(0x18000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderColor, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: borderColor, width: 1),
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.bold, color: onSurfaceColor),
        contentTextStyle: GoogleFonts.outfit(
          fontSize: 14, color: onSurfaceVariant),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0x14000000),
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.bold, color: onSurfaceColor),
        iconTheme: const IconThemeData(color: onSurfaceColor),
      ),
    );
  }

  // ── Shared button styles ──
  static ElevatedButtonThemeData _elevatedBtn(Color primary) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: GoogleFonts.outfit(
            fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      );

  static OutlinedButtonThemeData _outlinedBtn(Color primary) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 54),
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: GoogleFonts.outfit(
            fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      );

  static TextButtonThemeData _textBtn(Color primary) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.outfit(
            fontSize: 14, fontWeight: FontWeight.bold),
        ),
      );
}
