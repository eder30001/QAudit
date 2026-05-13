import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/corrective_action.dart';
import '../core/app_roles.dart';

// Sem try/catch dentro do service — callers (screens) são responsáveis pelo tratamento de erros.
class CorrectiveActionService {
  final _client = Supabase.instance.client;

  Future<List<CorrectiveAction>> getActions({
    required String? companyId,
    String? statusFilter,
    String? responsibleFilter,
  }) async {
    // profiles!responsible_user_id(...) desambigua FK — múltiplas FKs para profiles
    var query = _client
        .from('corrective_actions')
        .select('*, profiles!responsible_user_id(full_name), audits(title)');
    if (companyId != null) query = query.eq('company_id', companyId);
    if (statusFilter != null) query = query.eq('status', statusFilter);
    if (responsibleFilter != null) {
      query = query.eq('responsible_user_id', responsibleFilter);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => CorrectiveAction.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<String> createAction({
    required String auditId,
    required String templateItemId,
    required String title,
    String? description,
    required String responsibleUserId,
    required DateTime dueDate,
    required String companyId,
    required String createdBy,
  }) async {
    final row = await _client.from('corrective_actions').insert({
      'audit_id': auditId,
      'template_item_id': templateItemId,
      'title': title,
      'description': description,
      'responsible_user_id': responsibleUserId,
      'due_date': dueDate.toIso8601String().substring(0, 10),
      'status': 'aberta',
      'company_id': companyId,
      'created_by': createdBy,
    }).select('id').single();
    return row['id'] as String;
  }

  Future<void> updateStatus(String id, String newStatus,
      {String? resolutionNotes}) async {
    final updates = <String, dynamic>{
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (resolutionNotes != null && resolutionNotes.isNotEmpty) {
      updates['resolution_notes'] = resolutionNotes;
    }
    await _client.from('corrective_actions').update(updates).eq('id', id);
  }

  Future<List<CorrectiveAction>> getActionsByAudit(String auditId) async {
    final data = await _client
        .from('corrective_actions')
        .select('*, profiles!responsible_user_id(full_name), audits(title)')
        .eq('audit_id', auditId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => CorrectiveAction.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Set<String>> getItemIdsWithActions(String auditId) async {
    final data = await _client
        .from('corrective_actions')
        .select('template_item_id')
        .eq('audit_id', auditId);
    return (data as List).map((e) => e['template_item_id'] as String).toSet();
  }

  Future<void> deleteAction(String id) async {
    await _client.from('corrective_actions').delete().eq('id', id);
  }

  Future<void> updateResponsible(String id, String newResponsibleUserId) async {
    await _client.from('corrective_actions').update({
      'responsible_user_id': newResponsibleUserId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<int> getOpenActionsCount(String? companyId) async {
    var query = _client
        .from('corrective_actions')
        .select('id')
        .inFilter('status', ['aberta', 'em_andamento', 'em_avaliacao', 'em_analise', 'reaberta']);
    if (companyId != null) query = query.eq('company_id', companyId);
    final data = await query;
    return (data as List).length;
  }

  /// Cancela todas as ações corretivas abertas vinculadas a uma auditoria.
  /// Chamado quando uma auditoria é cancelada (D-08: cascade cancel).
  Future<void> cancelByAuditId(String auditId) async {
    await _client
        .from('corrective_actions')
        .update({
          'status': 'cancelada',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('audit_id', auditId)
        .not('status', 'in', '("cancelada","finalizada","aprovada")');
  }

  /// Determina se uma resposta para um item é não-conforme.
  /// Estático para testabilidade sem instância do Supabase client.
  static bool isNonConforming(String responseType, String? answer) {
    if (answer == null || answer.isEmpty) return false;
    switch (responseType) {
      case 'ok_nok':
        return answer == 'nok';
      case 'yes_no':
        return answer == 'no';
      case 'scale_1_5':
        return (int.tryParse(answer) ?? 99) <= 2;
      case 'percentage':
        return (double.tryParse(answer) ?? 100.0) < 50.0;
      case 'text':
        return answer.isNotEmpty;
      case 'selection':
        return answer.isNotEmpty;
      default:
        return false;
    }
  }

  /// RBAC matrix de transição de status — novo fluxo:
  ///   aberta → em_analise (responsável ou auditor envia resposta)
  ///   em_analise → finalizada | reaberta (auditor/ADM analisa)
  ///   reaberta → em_analise (responsável reenvia)
  ///
  /// Legado (backward compat para registros antigos):
  ///   em_andamento → em_analise
  ///   em_avaliacao → finalizada | reaberta
  ///   rejeitada → em_analise
  static bool canTransitionTo({
    required String newStatus,
    required CorrectiveAction action,
    required String role,
    required String userId,
  }) {
    if (AppRole.canAccessAdmin(role) || AppRole.isSuperOrDev(role)) return true;

    final isResponsible = action.responsibleUserId == userId;
    final isCreator = action.createdBy == userId;
    final isAuditor = role == AppRole.auditor;

    switch (newStatus) {
      // Responsável (ou auditor/criador) envia resposta → em análise
      case 'em_analise':
        return (isResponsible || isAuditor || isCreator) &&
            (action.status == CorrectiveActionStatus.aberta ||
                action.status == CorrectiveActionStatus.reaberta ||
                // legado
                action.status == CorrectiveActionStatus.emAndamento ||
                action.status == CorrectiveActionStatus.rejeitada);
      // Auditor ou criador finaliza
      case 'finalizada':
        return (isAuditor || isCreator) &&
            (action.status == CorrectiveActionStatus.emAnalise ||
                action.status == CorrectiveActionStatus.emAvaliacao); // legado
      // Auditor ou criador rejeita → vai para reaberta
      case 'reaberta':
        return (isAuditor || isCreator) &&
            (action.status == CorrectiveActionStatus.emAnalise ||
                action.status == CorrectiveActionStatus.emAvaliacao); // legado
      // Legado: transições do fluxo antigo
      case 'em_andamento':
        return (isResponsible || isCreator) &&
            (action.status == CorrectiveActionStatus.aberta ||
                action.status == CorrectiveActionStatus.rejeitada);
      case 'em_avaliacao':
        return isResponsible &&
            action.status == CorrectiveActionStatus.emAndamento;
      case 'aprovada':
      case 'rejeitada':
        return isCreator &&
            !isResponsible &&
            action.status == CorrectiveActionStatus.emAvaliacao;
      case 'cancelada':
        return false;
      default:
        return false;
    }
  }
}
