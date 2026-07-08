import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MuseHub design system — "SoundSync" cohesive dark language.
///
/// Principles:
///  • One deep cool-black canvas everywhere. No warm tint.
///  • Borderless elevated surfaces. Cards are *lighter*, never outlined.
///  • Bold, oversized headers with tight tracking.
///  • Coral accent used sparingly; a vibrant color is pulled from artwork.
class MuseTheme {
  MuseTheme._();

  // ── Core palette ──────────────────────────────────────────────────
  static const bg = Color(0xFF0D0D0F); // app canvas
  static const surface1 = Color(0xFF161618); // resting card
  static const surface2 = Color(0xFF1D1D20); // elevated card
  static const surface3 = Color(0xFF26262A); // highest / inputs
  static const textPrimary = Color(0xFFF3F2F0);
  static const textSecondary = Color(0xFF9C968F); // warm muted gray
  static const accent = Color(0xFFF06E43); // coral
  static const accentSoft = Color(0xFFFF9E7D);

  static ThemeData light() => dark();

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: Color(0xFF2A0A00),
      primaryContainer: accent,
      onPrimaryContainer: Colors.white,
      secondary: accentSoft,
      onSecondary: Color(0xFF3A1305),
      secondaryContainer: Color(0xFF3A2A24),
      onSecondaryContainer: Color(0xFFFFD9C9),
      tertiary: Color(0xFF5CD8E0),
      onTertiary: Color(0xFF00373A),
      tertiaryContainer: Color(0xFF00A4AC),
      onTertiaryContainer: Color(0xFF003235),
      error: Color(0xFFFF6B6B),
      onError: Color(0xFF3A0000),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: bg,
      onSurface: textPrimary,
      surfaceContainerLowest: Color(0xFF090909),
      surfaceContainerLow: Color(0xFF131315),
      surfaceContainer: surface1,
      surfaceContainerHigh: surface2,
      surfaceContainerHighest: surface3,
      onSurfaceVariant: textSecondary,
      outline: Color(0xFF3A3A3E),
      outlineVariant: Color(0xFF2A2A2E),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFF3F2F0),
      onInverseSurface: Color(0xFF2A2A2A),
      inversePrimary: accent,
    );
    return _base(scheme);
  }

  static TextTheme _buildTextTheme() {
    return GoogleFonts.soraTextTheme().copyWith(
      bodyLarge: GoogleFonts.hankenGrotesk(
          fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
      bodyMedium: GoogleFonts.hankenGrotesk(
          fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
      bodySmall: GoogleFonts.hankenGrotesk(
          fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary),
      labelLarge: GoogleFonts.hankenGrotesk(
          fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
      labelMedium: GoogleFonts.hankenGrotesk(
          fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary),
      labelSmall: GoogleFonts.hankenGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: textSecondary),
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    final textTheme = _buildTextTheme();

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      useMaterial3: true,
      textTheme: textTheme,
      splashColor: accent.withValues(alpha: 0.08),
      highlightColor: accent.withValues(alpha: 0.04),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.sora(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? accent
                : scheme.onSurfaceVariant,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.hankenGrotesk(
            color: states.contains(WidgetState.selected)
                ? accent
                : scheme.onSurfaceVariant,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      // Borderless elevated cards — the core of the look.
      cardTheme: const CardThemeData(
        color: surface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.onSurface,
        inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.14),
        thumbColor: scheme.onSurface,
        overlayColor: scheme.onSurface.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: GoogleFonts.hankenGrotesk(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
    );
  }
}
