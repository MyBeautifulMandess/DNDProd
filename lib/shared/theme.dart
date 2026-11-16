import 'package:flutter/material.dart';

/// Единая тема приложения. Палитра согласована с 2D-ассетами (docs/08-assets.md):
/// тёмно-серый фон, золотой акцент.
abstract final class AppTheme {
  static const gold = Color(0xFFC9A227);
  static const background = Color(0xFF1E1E1E);
  static const surface = Color(0xFF2B2B2B);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
          surface: surface,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(backgroundColor: surface, centerTitle: true),
        // Кроссплатформенность: минимальный размер тапа — правило 44×44 из docs/01-architecture.md.
        visualDensity: VisualDensity.standard,
      );
}
