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

  static ThemeData getTheme(String accentColorName, Brightness brightness) {
    final primaryColor = getAccentColor(accentColorName);
    final isDark = brightness == Brightness.dark;

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: isDark ? const Color(0xFF475569) : AppColors.secondaryDark,
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surface: isDark ? const Color(0xFF1E293B) : Colors.white,
        onSurface: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        primaryContainer: primaryColor.withOpacity(0.14),
        onPrimaryContainer: primaryColor,
        surfaceContainerHighest: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        onSurfaceVariant: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        outline: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
        outlineVariant: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      ),
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      dividerColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          height: 1.4,
        ),
        labelLarge: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(double.infinity, 54),
          side: BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        ),
        contentTextStyle: GoogleFonts.outfit(
          fontSize: 14,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        ),
        iconTheme: IconThemeData(
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        ),
      ),
    );
  }
}
