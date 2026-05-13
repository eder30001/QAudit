import 'package:flutter/material.dart';

/// Representa uma categoria de auditoria (ex: "Segurança", "5S", "Qualidade").
///
/// Mapeado da tabela `audit_types`. Tipos podem ser globais ([companyId] == null)
/// ou exclusivos de uma empresa, definidos pelo superuser/dev ou adm respectivamente.
class AuditType {
  final String id;
  final String name;
  final String icon;    // Emoji ou identificador de ícone (ex: '📋')
  final String color;   // Cor em hex (ex: '#2196F3')
  final String? companyId; // Null = tipo global
  final bool active;

  AuditType({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.companyId,
    required this.active,
  });

  factory AuditType.fromMap(Map<String, dynamic> map) {
    return AuditType(
      id: map['id'],
      name: map['name'],
      icon: map['icon'] ?? '📋',
      color: map['color'] ?? '#2196F3',
      companyId: map['company_id'],
      active: map['active'] ?? true,
    );
  }

  /// True se o tipo é global (disponível para todas as empresas).
  bool get isGlobal => companyId == null;

  /// Converte a string hex [color] para um [Color] Flutter.
  /// Retorna azul padrão se o valor for inválido.
  Color get colorValue {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }
}
