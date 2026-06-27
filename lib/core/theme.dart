import 'package:flutter/material.dart';

class MuseTheme {
  static ThemeData light() {
    return dark();
  }

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

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface.withValues(alpha: 0.92),
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFFE5E2DF),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest.withValues(alpha: 0.96),
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}
