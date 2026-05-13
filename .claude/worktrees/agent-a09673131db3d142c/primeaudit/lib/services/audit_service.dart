import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit.dart';

/// CRUD de auditorias (tabela `audits`).
///
/// Estrutura esperada no banco:
///   audits
///     id, title, audit_type_id, template_id, company_id,
///     perimeter_id (nullable), auditor_id, created_at,
///     deadline (nullable), status, conformity_percent (nullable)
///
/// Joins utilizados:
///   audit_types(name, icon, color)
///   audit_templates(name)
///   companies(name, requires_perimeter)
///   perimeters(name)
///   auditor:profiles!auditor_id(full_name)
class AuditService {
  final _client = Supabase.instance.client;

  static const _select = '''
    *,
    audit_types(name, icon, color),
    audit_templates(name),
    companies(name, requires_perimeter),
    perimeters(name),
    auditor:profiles!auditor_id(full_name)
  ''';

  /// Retorna todas as auditorias da empresa informada, ordenadas pela mais recente.
  /// Se [companyId] for null, retorna todas (uso restrito a superuser/dev).
  Future<List<Audit>> getAudits({String? companyId}) async {
    var query = _client.from('audits').select(_select);
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => Audit.fromMap(e)).toList();
  }

  /// Cria uma nova auditoria com status `em_andamento`.
  Future<Audit> createAudit({
    required String title,
    required String auditTypeId,
    required String templateId,
    required String companyId,
    String? perimeterId,
    required String auditorId,
    DateTime? deadline,
  }) async {
    final result = await _client
        .from('audits')
        .insert({
          'title': title,
          'audit_type_id': auditTypeId,
          'template_id': templateId,
          'company_id': companyId,
          'perimeter_id': perimeterId,
          'auditor_id': auditorId,
          'deadline': deadline?.toIso8601String(),
          'status': 'em_andamento',
        })
        .select(_select)
        .single();
    return Audit.fromMap(result);
  }

  /// Encerra uma auditoria (status → cancelada).
  Future<void> closeAudit(String id) async {
    await _client
        .from('audits')
        .update({'status': 'cancelada'})
        .eq('id', id);
  }

  /// Duplica uma auditoria existente como rascunho com novo [newTitle].
  Future<Audit> duplicateAudit(String id, {required String newTitle}) async {
    final original = await _client
        .from('audits')
        .select()
        .eq('id', id)
        .single();

    final result = await _client
        .from('audits')
        .insert({
          'title': newTitle,
          'audit_type_id': original['audit_type_id'],
          'template_id': original['template_id'],
          'company_id': original['company_id'],
          'perimeter_id': original['perimeter_id'],
          'auditor_id': original['auditor_id'],
          'deadline': original['deadline'],
          'status': 'rascunho',
        })
        .select(_select)
        .single();
    return Audit.fromMap(result);
  }

  /// Apaga uma auditoria e suas respostas (via CASCADE no banco).
  Future<void> deleteAudit(String id) async {
    await _client.from('audits').delete().eq('id', id);
  }

  /// Finaliza a auditoria: status → concluida + salva conformidade.
  Future<void> finalizeAudit({
    required String id,
    required double conformityPercent,
  }) async {
    await _client.from('audits').update({
      'status': 'concluida',
      'conformity_percent': conformityPercent,
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Atualiza o status de uma auditoria.
  Future<void> updateStatus(String id, AuditStatus status) async {
    await _client
        .from('audits')
        .update({'status': _statusStr(status)})
        .eq('id', id);
  }

  static String _statusStr(AuditStatus s) {
    switch (s) {
      case AuditStatus.emAndamento: return 'em_andamento';
      case AuditStatus.concluida:   return 'concluida';
      case AuditStatus.atrasada:    return 'atrasada';
      case AuditStatus.cancelada:   return 'cancelada';
      case AuditStatus.rascunho:    return 'rascunho';
    }
  }
}
