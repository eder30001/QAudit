import 'package:flutter/material.dart';

/// Extensão de tema que fornece cores adaptadas ao modo claro/escuro.
///
/// Uso nas telas:
/// ```dart
/// final t = AppTheme.of(context);
/// Container(color: t.background)
/// ```
class AppTheme {
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;

  const AppTheme._({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
  });

  /// Tema claro.
  static const _light = AppTheme._(
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF6B7280),
    divider: Color(0xFFE5E7EB),
  );

  /// Tema escuro.
  static const _dark = AppTheme._(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    textPrimary: Color(0xFFE8EAED),
    textSecondary: Color(0xFF9AA0A6),
    divider: Color(0xFF3C4043),
  );

  /// Retorna o tema correspondente ao brilho atual do [context].
  static AppTheme of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}
