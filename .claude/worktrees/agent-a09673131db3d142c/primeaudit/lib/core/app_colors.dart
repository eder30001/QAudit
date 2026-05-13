import 'package:flutter/material.dart';

/// Paleta de cores estática do PrimeAudit.
/// Usado em conjunto com [AppTheme] para temas claro/escuro.
class AppColors {
  static const Color primary = Color(0xFF1E3A5F);       // Azul corporativo principal
  static const Color accent = Color(0xFF2196F3);         // Azul de destaque / ações
  static const Color background = Color(0xFFF5F7FA);    // Fundo geral (modo claro)
  static const Color surface = Colors.white;             // Superfície de cards e dialogs
  static const Color error = Color(0xFFE53935);          // Erros e alertas críticos
  static const Color textPrimary = Color(0xFF1A1A2E);   // Texto principal
  static const Color textSecondary = Color.fromARGB(255, 180, 186, 197); // Texto secundário / hints
  static const Color divider = Color(0xFFE5E7EB);       // Linhas divisórias
}
