import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static final mode = ValueNotifier<ThemeMode>(ThemeMode.light);

  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFB85C38),
      brightness: brightness,
      surface: dark ? const Color(0xFF18191D) : const Color(0xFFFFFCF7),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF111216)
          : const Color(0xFFFFFCF7),
      appBarTheme: AppBarTheme(
        backgroundColor: dark
            ? const Color(0xFF18191D)
            : const Color(0xFFFFFCF7),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF1B1D22) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    );
  }
}
