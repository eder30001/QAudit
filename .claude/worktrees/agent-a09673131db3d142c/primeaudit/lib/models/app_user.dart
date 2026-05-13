import 'package:flutter/material.dart';
import '../core/app_roles.dart';

/// Representa um usuário do sistema, mapeado da tabela `profiles` do Supabase.
///
/// O campo [companyName] é populado via join com a tabela `companies`
/// usando a query `profiles.select('*, companies(name)')`.
class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? companyId;    // Null para superuser/dev sem empresa vinculada
  final String? companyName;  // Preenchido via join; null se sem empresa
  final bool active;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.companyId,
    this.companyName,
    required this.active,
    required this.createdAt,
  });

  /// Constrói a partir de uma linha retornada pelo Supabase.
  /// Espera o join `companies(name)` para preencher [companyName].
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'],
      fullName: map['full_name'],
      email: map['email'],
      role: map['role'],
      companyId: map['company_id'],
      companyName: map['companies']?['name'],
      active: map['active'] ?? true,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  /// Rótulo legível do papel (ex: 'Administrador').
  String get roleLabel => AppRole.label(role);

  /// Cor de badge associada ao papel do usuário.
  Color get roleColor {
    switch (role) {
      case AppRole.superuser:
        return const Color(0xFF6A0DAD); // Roxo
      case AppRole.dev:
        return const Color(0xFF0277BD); // Azul escuro
      case AppRole.adm:
        return const Color(0xFF00838F); // Teal
      case AppRole.auditor:
        return const Color(0xFF2E7D32); // Verde
      case AppRole.anonymous:
        return const Color(0xFF757575); // Cinza
      default:
        return const Color(0xFF757575);
    }
  }

  /// Atalho: true se o papel permite acesso ao painel admin.
  bool get canAccessAdmin => AppRole.canAccessAdmin(role);

  /// Atalho: true se o papel é superuser ou dev (pode trocar de empresa).
  bool get isSuperOrDev => AppRole.isSuperOrDev(role);
}
