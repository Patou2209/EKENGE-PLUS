import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

/// EKENGE PLUS — Design System « Clarity » (theme clair professionnel).
/// Aucun emoji. Icones vectorielles natives (Material) uniquement.
/// Fond creme, cartes blanches, boutons sombres en pilule, accent teal
/// repris du logo officiel.
class Ek {
  Ek._();

  // ---- Palette Clarity ----------------------------------------------------
  static const Color bg = Color(0xFFF4F4F2); // fond creme clair
  static const Color bgElevated = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceHigh = Color(0xFFF0F1F3);
  static const Color hairline = Color(0xFFE5E7EB);
  static const Color hairlineSoft = Color(0xFFEEF0F2);

  static const Color textPrimary = Color(0xFF15181D); // quasi noir
  static const Color textSecondary = Color(0xFF5A6270);
  static const Color textTertiary = Color(0xFF9AA1AD);

  /// Encre : couleur des boutons principaux (pilule sombre, cf. references).
  static const Color ink = Color(0xFF16181D);

  static const Color accent = Color(0xFF0F8478); // teal du logo
  static const Color accentDim = Color(0xFF0B655C);
  static const Color danger = Color(0xFFC8102E);
  static const Color dangerBright = Color(0xFFE8213C);
  static const Color safe = Color(0xFF13915F);
  static const Color warn = Color(0xFFB07C13);

  // ---- Rythme -------------------------------------------------------------
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r28 = 28;

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration med = Duration(milliseconds: 320);

  // ---- Typographie --------------------------------------------------------
  static TextStyle wordmark({double size = 15, Color color = textPrimary}) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: size * 0.18,
        height: 1.1,
      );

  static TextStyle over({double size = 10.5, Color color = textTertiary}) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: size * 0.14,
      );

  static TextStyle title({double size = 22, Color color = textPrimary}) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w700,
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
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ---- Ombres -------------------------------------------------------------
  static List<BoxShadow> get lift => const [
    BoxShadow(color: Color(0x14101828), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static List<BoxShadow> glow(Color c, {double o = 0.22, double b = 26}) => [
    BoxShadow(
      color: c.withValues(alpha: o),
      blurRadius: b,
      spreadRadius: 1,
    ),
  ];

  // ---- Theme --------------------------------------------------------------
  static ThemeData theme() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.light(
        surface: bg,
        primary: accent,
        secondary: accent,
        error: danger,
        onPrimary: Colors.white,
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
              : const Color(0xFFB4BAC4),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? safe : const Color(0xFFE8EAEE),
        ),
        trackOutlineColor: WidgetStateProperty.all(hairline),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: body(color: Colors.white),
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
