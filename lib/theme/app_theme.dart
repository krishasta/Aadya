import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ---------------------------------------------------------------------------
  // LIGHT PALETTE (ORIGINAL - 100% UNCHANGED AS REQUESTED)
  // ---------------------------------------------------------------------------
  static const Color primaryBlue = Color(0xFF0284C7); // Vibrant Sky Blue
  static const Color primaryBlueDark = Color(0xFF0369A1); // Deep Sky Blue
  static const Color primaryBlueLight = Color(0xFF38BDF8); // Bright Sky Blue
  static const Color primaryBlueSubtle = Color(0x1F0284C7); // 12% Light Blue Tint
  static const Color primaryBlueSoft = Color(0xFFE0F2FE); // Soft Ice-Blue Container
  static const Color primaryBlueBorder = Color(0xFFBAE6FD); // Border Blue

  // Status & Accent Colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color infoBlue = Color(0xFF0284C7);
  static const Color errorRed = Color(0xFFEF4444);

  // Surface & Light Background Colors (Light Blue & Crisp White Palette)
  static const Color bgLight = Color(0xFFF0F9FF); // Soft Cloud Sky Tint
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure Crisp White
  static const Color cardLight = Color(0xFFFFFFFF); // Pure Crisp White
  static const Color cardBorder = Color(0xFFE2E8F0); // Clean Slate Border
  static const Color cardBorderActive = Color(0xFFBAE6FD); // Light Blue Border
  static const Color consoleBg = Color(0xFFF1F5F9); // Clean Light Terminal Slate

  // Compatibility aliases for legacy variable names
  static const Color espressifRed = primaryBlue;
  static const Color espressifRedDark = primaryBlueDark;
  static const Color espressifRedLight = primaryBlue;
  static const Color espressifRedSubtle = primaryBlueSoft;
  static const Color bgDark = bgLight;
  static const Color surfaceDark = surfaceLight;
  static const Color cardDark = cardLight;

  // Compatibility Accent Tokens
  static const Color primaryCyan = Color(0xFF0284C7);
  static const Color secondaryCyan = Color(0xFF38BDF8);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentPurple = Color(0xFF8B5CF6);

  // Text Colors (High Contrast Deep Charcoal/Slate on White)
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // ---------------------------------------------------------------------------
  // DARK PALETTE: MIDNIGHT SLATE & ELECTRIC SKY BLUE
  // Ultra-modern, sleek dark theme matching the Aadhya brand identity
  // ---------------------------------------------------------------------------
  static const Color darkBg = Color(0xFF0A0F1D); // Deep Midnight Slate
  static const Color darkSurface = Color(0xFF131D31); // Frosted Navy Slate
  static const Color darkCard = Color(0xFF131D31); // Frosted Navy Slate Card
  static const Color darkCardElevated = Color(0xFF1C2842); // Elevated Blue Slate
  static const Color darkBorder = Color(0xFF223554); // Crisp Slate Blue Border
  static const Color darkBorderActive = Color(0xFF38BDF8); // Electric Sky Blue Active Border

  static const Color darkPrimary = Color(0xFF38BDF8); // Electric Sky Blue (Tailwind Sky 400)
  static const Color darkPrimaryDark = Color(0xFF0284C7); // Deep Sky Blue (Tailwind Sky 600)
  static const Color darkPrimaryLight = Color(0xFF7DD3FC); // Bright Ice Cyan (Tailwind Sky 300)
  static const Color darkPrimarySoft = Color(0x2638BDF8); // 15% Electric Blue Container Tint
  static const Color darkPrimaryBorder = Color(0x6638BDF8); // 40% Translucent Blue Border

  static const Color darkSecondary = Color(0xFF818CF8); // Indigo / Periwinkle (Tailwind Indigo 400)
  static const Color darkAccent = Color(0xFF67E8F9); // Luminous Ice Cyan (Tailwind Cyan 300)
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Crisp High-Contrast Snow White (Slate 50)
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Cool Slate Grey (Slate 400)
  static const Color darkTextMuted = Color(0xFF64748B); // Slate Muted (Slate 500)
  static const Color darkInputFill = Color(0xFF0F172A); // Midnight Slate Field (Slate 900)
  static const Color darkConsoleBg = Color(0xFF070B14); // Deep Obsidian Slate Terminal

  // ---------------------------------------------------------------------------
  // CONTEXT-AWARE DYNAMIC COLOR HELPERS
  // ---------------------------------------------------------------------------
  
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color getBg(BuildContext context) =>
      isDark(context) ? darkBg : bgLight;

  static Color getSurface(BuildContext context) =>
      isDark(context) ? darkSurface : surfaceLight;

  static Color getCard(BuildContext context) =>
      isDark(context) ? darkCard : cardLight;

  static Color getCardElevated(BuildContext context) =>
      isDark(context) ? darkCardElevated : const Color(0xFFF8FAFC);

  static Color getBorder(BuildContext context) =>
      isDark(context) ? darkBorder : cardBorder;

  static Color getBorderActive(BuildContext context) =>
      isDark(context) ? darkBorderActive : cardBorderActive;

  static Color getPrimary(BuildContext context) =>
      isDark(context) ? darkPrimary : primaryBlue;

  static Color getPrimaryLight(BuildContext context) =>
      isDark(context) ? darkPrimaryLight : primaryBlueLight;

  static Color getPrimarySoft(BuildContext context) =>
      isDark(context) ? darkPrimarySoft : primaryBlueSoft;

  static Color getPrimaryBorder(BuildContext context) =>
      isDark(context) ? darkPrimaryBorder : primaryBlueBorder;

  static Color getTextPrimary(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color getTextSecondary(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color getTextMuted(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;

  static Color getInputFill(BuildContext context) =>
      isDark(context) ? darkInputFill : surfaceLight;

  static Color getConsoleBg(BuildContext context) =>
      isDark(context) ? darkConsoleBg : consoleBg;

  // ---------------------------------------------------------------------------
  // LIGHT THEME (UNTOUCHED)
  // ---------------------------------------------------------------------------
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      primaryColor: primaryBlue,
      canvasColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: primaryBlueLight,
        surface: surfaceLight,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.light().textTheme.apply(
              bodyColor: textPrimary,
              displayColor: textPrimary,
            ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x1A0284C7),
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: primaryBlue),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 1,
        shadowColor: const Color(0x0D0284C7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        hintStyle: GoogleFonts.outfit(color: textMuted, fontSize: 14),
        labelStyle: GoogleFonts.outfit(color: textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x330284C7),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlueBorder, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: cardBorder,
        thickness: 1,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DARK THEME (MIDNIGHT SLATE & ELECTRIC SKY BLUE PALETTE)
  // ---------------------------------------------------------------------------
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: darkPrimary,
      canvasColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkAccent,
        surface: darkSurface,
        error: errorRed,
        onPrimary: Color(0xFF0A0F1D),
        onSecondary: Color(0xFF0A0F1D),
        onSurface: darkTextPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.apply(
              bodyColor: darkTextPrimary,
              displayColor: darkTextPrimary,
            ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x33000000),
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: darkTextPrimary,
        ),
        iconTheme: const IconThemeData(color: darkPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 1,
        shadowColor: const Color(0x33000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInputFill,
        hintStyle: GoogleFonts.outfit(color: darkTextMuted, fontSize: 14),
        labelStyle: GoogleFonts.outfit(color: darkTextSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkPrimary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: const Color(0xFF0A0F1D),
          elevation: 1,
          shadowColor: const Color(0x4038BDF8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          side: const BorderSide(color: darkBorder, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: darkPrimarySoft,
        secondarySelectedColor: darkPrimarySoft,
        disabledColor: darkSurface,
        labelStyle: GoogleFonts.outfit(color: darkTextPrimary),
        secondaryLabelStyle: GoogleFonts.outfit(color: darkPrimary),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder),
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
        ),
        contentTextStyle: GoogleFonts.outfit(
          fontSize: 14,
          color: darkTextSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        modalBackgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
