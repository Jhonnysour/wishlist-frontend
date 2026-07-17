import 'package:flutter/material.dart';

/// Temas Material 3 (claro/oscuro) generados desde un único color semilla.
///
/// Paleta "Ciruela profundo": semilla ciruela con un acento verde azulado
/// grisáceo reservado para el estado "comprado".
class AppTheme {
  const AppTheme._();

  /// Color semilla del que Material 3 deriva toda la paleta tonal.
  static const _seed = Color(0xFF92355A);

  /// Acento verde azulado para el estado "comprado" (no lo deriva la semilla).
  static const purchased = Color(0xFF4F7C82);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: true,
      ),
    );
  }
}
