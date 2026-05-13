import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/checklist_execution.dart';

/// CRUD de execuções de checklist (tabela `checklist_executions`).
///
/// Estrutura esperada no banco:
///   checklist_executions
///     id, template_id, company_id, created_by,
///     responsavel, local, numero (nullable),
///     data_execucao (DATE), status, conformity_percent (nullable),
///     created_at, completed_at (nullable)
///
/// Join utilizado:
///   checklist_templates(name) — popula templateName em ChecklistExecution
///
/// Sem try/catch interno — callers (screens) são responsáveis por capturar exceções.
class ChecklistExecutionService {
  final _client = Supabase.instance.client;

  static const _select = '''
    *,
    checklist_templates(name)
  ''';

  /// Cria execução com status 'rascunho'. Retorna o objeto com templateName populado.
  ///
  /// [dataExecucao] é serializado como 'yyyy-MM-dd' via toIso8601String().substring(0, 10)
  /// — sem timezone, evitando deslocamento de dia em UTC-3 (pitfall documentado em 14-RESEARCH.md).
  ///
  /// [companyId] é recebido como parâmetro (vem de CompanyContextService no caller).
  ///
  /// T-14-09 mitigation: [createdBy] obtido de _client.auth.currentUser!.id — não recebido
  /// como parâmetro, impedindo spoofing.
  Future<ChecklistExecution> createExecution({
    required String templateId,
    required String? companyId,
    required String responsavel,
    required String local,
    String? numero,
    String? veiculoPlaca,
    required DateTime dataExecucao,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final result = await _client
        .from('checklist_executions')
        .insert({
          'template_id': templateId,
          'company_id': companyId,
          'created_by': userId,
          'responsavel': responsavel,
          'local': local,
          'numero': numero,
          'veiculo_placa': veiculoPlaca,
          // DATE sem timezone: toIso8601String().substring(0, 10) = 'yyyy-MM-dd'
          'data_execucao': dataExecucao.toIso8601String().substring(0, 10),
          'status': 'rascunho',
        })
        .select(_select)
        .single();
    return ChecklistExecution.fromMap(result);
  }

  /// Lista execuções da empresa ordenadas por created_at DESC.
  Future<List<ChecklistExecution>> getExecutions({required String? companyId}) async {
    final userId = _client.auth.currentUser!.id;
    final List data;
    if (companyId != null) {
      data = await _client
          .from('checklist_executions')
          .select(_select)
          .eq('company_id', companyId)
          .order('created_at', ascending: false);
    } else {
      data = await _client
          .from('checklist_executions')
          .select(_select)
          .eq('created_by', userId)
          .order('created_at', ascending: false);
    }
    return data.map((r) => ChecklistExecution.fromMap(r)).toList();
  }

  /// Busca execução por id com join do nome do template.
  Future<ChecklistExecution> getExecution(String id) async {
    final result = await _client
        .from('checklist_executions')
        .select(_select)
        .eq('id', id)
        .single();
    return ChecklistExecution.fromMap(result);
  }

  /// Finaliza execução: seta status='concluido', conformity_percent e completed_at.
  ///
  /// Chamado após calculateConformity retornar o valor final.
  Future<void> finalizeExecution({
    required String id,
    required double conformityPercent,
  }) async {
    await _client.from('checklist_executions').update({
      'status': 'concluido',
      'conformity_percent': conformityPercent,
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Remove execução e suas respostas (cascade definido no banco via ON DELETE CASCADE).
  Future<void> deleteExecution(String id) async {
    await _client.from('checklist_executions').delete().eq('id', id);
  }
}
