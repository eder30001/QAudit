import 'package:flutter/material.dart';

enum AuditStatus {
  rascunho,
  emAndamento,
  concluida,
  atrasada,
  cancelada;

  String get label {
    switch (this) {
      case rascunho:    return 'Rascunho';
      case emAndamento: return 'Em andamento';
      case concluida:   return 'Concluída';
      case atrasada:    return 'Atrasada';
      case cancelada:   return 'Cancelada';
    }
  }

  Color get color {
    switch (this) {
      case rascunho:    return Colors.grey;
      case emAndamento: return const Color(0xFF2196F3);
      case concluida:   return const Color(0xFF43A047);
      case atrasada:    return const Color(0xFFE53935);
      case cancelada:   return const Color(0xFFFF9800);
    }
  }

  IconData get icon {
    switch (this) {
      case rascunho:    return Icons.edit_note_rounded;
      case emAndamento: return Icons.pending_rounded;
      case concluida:   return Icons.check_circle_rounded;
      case atrasada:    return Icons.warning_rounded;
      case cancelada:   return Icons.cancel_rounded;
    }
  }
}

/// Representa uma auditoria executada ou em andamento.
/// Mapeado da tabela `audits`. Uma auditoria nasce de um [templateId]
/// que pertence a um [auditTypeId].
class Audit {
  final String id;
  final String title;
  final String auditTypeId;
  final String auditTypeName;
  final String auditTypeIcon;
  final String auditTypeColor;   // hex, ex: '#2196F3'
  final String templateId;
  final String templateName;
  final String companyId;
  final String companyName;
  final bool companyRequiresPerimeter;
  final String? perimeterId;
  final String? perimeterName;
  final String auditorId;
  final String auditorName;
  final DateTime createdAt;
  final DateTime? deadline;
  final AuditStatus status;
  final double? conformityPercent; // 0.0–100.0, null se ainda não calculado

  const Audit({
    required this.id,
    required this.title,
    required this.auditTypeId,
    required this.auditTypeName,
    required this.auditTypeIcon,
    required this.auditTypeColor,
    required this.templateId,
    required this.templateName,
    required this.companyId,
    required this.companyName,
    required this.companyRequiresPerimeter,
    this.perimeterId,
    this.perimeterName,
    required this.auditorId,
    required this.auditorName,
    required this.createdAt,
    this.deadline,
    required this.status,
    this.conformityPercent,
  });

  factory Audit.fromMap(Map<String, dynamic> map) {
    return Audit(
      id: map['id'],
      title: map['title'],
      auditTypeId: map['audit_type_id'],
      auditTypeName: map['audit_types']?['name'] ?? '',
      auditTypeIcon: map['audit_types']?['icon'] ?? '📋',
      auditTypeColor: map['audit_types']?['color'] ?? '#2196F3',
      templateId: map['template_id'],
      templateName: map['audit_templates']?['name'] ?? '',
      companyId: map['company_id'],
      companyName: map['companies']?['name'] ?? '',
      companyRequiresPerimeter: map['companies']?['requires_perimeter'] ?? false,
      perimeterId: map['perimeter_id'],
      perimeterName: map['perimeters']?['name'],
      auditorId: map['auditor_id'],
      auditorName: map['auditor']?['full_name'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
      status: _statusFromString(map['status']),
      conformityPercent: (map['conformity_percent'] as num?)?.toDouble(),
    );
  }

  static AuditStatus _statusFromString(String? s) {
    switch (s) {
      case 'em_andamento': return AuditStatus.emAndamento;
      case 'concluida':    return AuditStatus.concluida;
      case 'atrasada':     return AuditStatus.atrasada;
      case 'cancelada':    return AuditStatus.cancelada;
      default:             return AuditStatus.rascunho;
    }
  }

  bool get isOverdue =>
      status == AuditStatus.atrasada ||
      (deadline != null &&
          deadline!.isBefore(DateTime.now()) &&
          status == AuditStatus.emAndamento);
}
