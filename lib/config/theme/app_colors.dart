import 'package:flutter/material.dart';

class AppColors {
  // ── Primary Brand Colors (Deep Navy + Luxury Crimson Direction) ──
  static const Color primaryCrimson = Color(0xFFD71920); // Vibrant ICEM Crimson Red
  static const Color crimsonRed = Color(0xFFE31B23);    // High-energy Crimson for accents/glow
  static const Color darkCrimson = Color(0xFF990000);   // Deep Crimson for gradients
  static const Color lightCrimson = Color(0x26D71920);  // Translucent crimson tint for badges
  static const Color crimsonLight = Color(0x26D71920);  // Translucent crimson tint alias
  static const Color borderCrimson = Color(0xFFD71920); // Crimson border for active cards

  // Crimson Scales
  static const Color crimson50 = Color(0x1AD71920);
  static const Color crimson100 = Color(0x2BD71920);
  static const Color crimson200 = Color(0x40D71920);
  static const Color crimson500 = Color(0xFFD71920);
  static const Color crimson600 = Color(0xFFE31B23);
  static const Color crimson700 = Color(0xFFB80F0A);
  static const Color crimson800 = Color(0xFF990000);

  // ── Deep Navy & Charcoal Backgrounds (Reference Style) ──
  static const Color background = Color(0xFF0B1118);       // Primary deep navy background
  static const Color backgroundNavy = Color(0xFF0B1118);   // #0B1118
  static const Color backgroundCharcoal = Color(0xFF101820); // #101820
  static const Color backgroundLight = Color(0xFF0B1118);  // Default dark backdrop

  // Surfaces & Cards
  static const Color surface = Color(0xFF151E28);          // Dark navy/charcoal surface #151E28
  static const Color surfaceCard = Color(0xFF151E28);      // Standard card surface
  static const Color surfaceElevated = Color(0xFF1A2432);  // Slightly lighter elevated card
  static const Color surfaceLight = Color(0xFF151E28);     // Card fallback
  static const Color cardBorder = Color(0xFF222F3E);       // Subtle slate-navy border
  static const Color cardBorderSubtle = Color(0x1FFFFFFF); // 12% white subtle border

  // Semantic Design Aliases
  static const Color bgDark = Color(0xFF0B1118);
  static const Color cardSurface = Color(0xFF151E28);
  static const Color elevatedSurface = Color(0xFF1A2432);
  static const Color borderSubtle = Color(0xFF222F3E);
  static const Color textMuted = Color(0xFF94A3B8);

  // Secondary / Accent Colors
  static const Color accentGold = Color(0xFFF59E0B);     // Warm Amber/Gold
  static const Color secondaryDark = Color(0xFF1E293B);  // Slate navy

  // Slate Neutral Scale
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);     // Soft pure white for primary text
  static const Color textSecondary = Color(0xFF94A3B8);   // Muted slate gray for secondary info
  static const Color textLight = Color(0xFF64748B);       // Subtle helper text
  static const Color textOnPrimary = Color(0xFFFFFFFF);   // White on crimson CTA

  // Feedback Colors
  static const Color success = Color(0xFF10B981);         // Emerald-500
  static const Color successLight = Color(0x2610B981);    // 15% Emerald
  static const Color warning = Color(0xFFF59E0B);         // Amber-500
  static const Color warningLight = Color(0x26F59E0B);    // 15% Amber
  static const Color error = Color(0xFFEF4444);           // Red-500
  static const Color errorLight = Color(0x26EF4444);      // 15% Red
  static const Color info = Color(0xFF3B82F6);            // Blue-500
  static const Color infoLight = Color(0x263B82F6);       // 15% Blue

  // Modern Soft Dark Shadow Presets
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 14,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x55000000),
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x70000000),
      blurRadius: 30,
      spreadRadius: 0,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> crimsonGlow = [
    BoxShadow(
      color: Color(0x40D71920),
      blurRadius: 18,
      spreadRadius: 1,
      offset: Offset(0, 4),
    ),
  ];
}

