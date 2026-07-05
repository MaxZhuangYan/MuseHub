import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MuseTheme {
  static ThemeData light() => dark();

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFB59E),
      onPrimary: Color(0xFF5E1700),
      primaryContainer: Color(0xFFEB6F47),
      onPrimaryContainer: Color(0xFF571500),
      secondary: Color(0xFFC8C6C4),
      onSecondary: Color(0xFF30312F),
      secondaryContainer: Color(0xFF494947),
      onSecondaryContainer: Color(0xFFB9B8B6),
      tertiary: Color(0xFF5CD8E0),
      onTertiary: Color(0xFF00373A),
      tertiaryContainer: Color(0xFF00A4AC),
      onTertiaryContainer: Color(0xFF003235),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF131312),
      onSurface: Color(0xFFE5E2DF),
      surfaceContainerLowest: Color(0xFF0E0E0D),
      surfaceContainerLow: Color(0xFF1B1C1A),
      surfaceContainer: Color(0xFF1F201E),
      surfaceContainerHigh: Color(0xFF2A2A28),
      surfaceContainerHighest: Color(0xFF353533),
      onSurfaceVariant: Color(0xFFDEC0B7),
      outline: Color(0xFFA68B83),
      outlineVariant: Color(0xFF57423B),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE5E2DF),
      onInverseSurface: Color(0xFF30302E),
      inversePrimary: Color(0xFFA53C18),
    );
    return _base(scheme);
  }

  static TextTheme _buildTextTheme() {
    return GoogleFonts.soraTextTheme().copyWith(
      bodyLarge: GoogleFonts.hankenGrotesk(
          fontSize: 16, fontWeight: FontWeight.w400, color: const Color(0xFFE5E2DF)),
      bodyMedium: GoogleFonts.hankenGrotesk(
          fontSize: 14, fontWeight: FontWeight.w400, color: const Color(0xFFE5E2DF)),
      bodySmall: GoogleFonts.hankenGrotesk(
          fontSize: 12, fontWeight: FontWeight.w400, color: const Color(0xFFDEC0B7)),
      labelLarge: GoogleFonts.hankenGrotesk(
          fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFFE5E2DF)),
      labelMedium: GoogleFonts.hankenGrotesk(
          fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFFDEC0B7)),
      labelSmall: GoogleFonts.hankenGrotesk(
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5,
          color: const Color(0xFFDEC0B7)),
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    final textTheme = _buildTextTheme();

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      useMaterial3: true,
      textTheme: textTheme,
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
        height: 62,
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            size: 22,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.hankenGrotesk(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF252523),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.12),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252523),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.hankenGrotesk(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
    );
  }
}
