import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

/// EKENGE PLUS — Design System « Obsidian Premium »
/// Aucun emoji. Icones vectorielles natives (Material) uniquement.
class Ek {
  Ek._();

  // ---- Palette Obsidian -------------------------------------------------
  static const Color bg = Color(0xFF0A0B0E);
  static const Color bgElevated = Color(0xFF11131A);
  static const Color surface = Color(0xFF15181F);
  static const Color surfaceHigh = Color(0xFF1C2028);
  static const Color hairline = Color(0xFF262B35);
  static const Color hairlineSoft = Color(0xFF1E222B);

  static const Color textPrimary = Color(0xFFF2F4F8);
  static const Color textSecondary = Color(0xFF9BA3B4);
  static const Color textTertiary = Color(0xFF636B7C);

  static const Color accent = Color(0xFF17C8B4); // teal signature
  static const Color accentDim = Color(0xFF0E6F65);
  static const Color danger = Color(0xFFC8102E); // crimson mat
  static const Color dangerBright = Color(0xFFE8213C);
  static const Color safe = Color(0xFF1FB877);
  static const Color warn = Color(0xFFE0A526);

  // ---- Rythme -----------------------------------------------------------
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r28 = 28;

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration med = Duration(milliseconds: 320);

  // ---- Typographie ------------------------------------------------------
  static TextStyle wordmark({double size = 15, Color color = textPrimary}) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: size * 0.22,
        height: 1.1,
      );

  static TextStyle over({double size = 10.5, Color color = textTertiary}) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: size * 0.16,
      );

  static TextStyle title({double size = 22, Color color = textPrimary}) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.2,
      );

  static TextStyle body({
    double size = 14,
    Color color = textSecondary,
    FontWeight weight = FontWeight.w400,
    double height = 1.45,
  }) => GoogleFonts.inter(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
  );

  static TextStyle num({double size = 26, Color color = textPrimary}) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ---- Ombres -----------------------------------------------------------
  static List<BoxShadow> get lift => const [
    BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static List<BoxShadow> glow(Color c, {double o = 0.34, double b = 34}) => [
    BoxShadow(
      color: c.withValues(alpha: o),
      blurRadius: b,
      spreadRadius: 1,
    ),
  ];

  // ---- Theme ------------------------------------------------------------
  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        surface: bg,
        primary: accent,
        secondary: accent,
        error: danger,
        onPrimary: Color(0xFF04120F),
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(
        base.textTheme,
      ).apply(bodyColor: textPrimary, displayColor: textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textSecondary, size: 22),
        titleTextStyle: wordmark(),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bgElevated,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF6C7486),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? safe : const Color(0x4423283A),
        ),
        trackOutlineColor: WidgetStateProperty.all(hairline),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: body(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: body(color: textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r16),
          borderSide: const BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r16),
          borderSide: const BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r16),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r16),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r16),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
      ),
    );
  }
}
