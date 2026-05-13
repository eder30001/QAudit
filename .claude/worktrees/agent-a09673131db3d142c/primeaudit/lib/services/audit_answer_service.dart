import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_answer.dart';
import '../models/audit_template.dart';

/// Gerencia respostas de auditoria (tabela `audit_answers`).
///
/// Usa upsert com UNIQUE(audit_id, template_item_id) para que cada
/// item tenha sempre uma única resposta por auditoria.
class AuditAnswerService {
  final _client = Supabase.instance.client;

  /// Carrega todas as respostas de uma auditoria.
  Future<List<AuditAnswer>> getAnswers(String auditId) async {
    final data = await _client
        .from('audit_answers')
        .select()
        .eq('audit_id', auditId)
        .order('answered_at');
    return (data as List).map((e) => AuditAnswer.fromMap(e)).toList();
  }

  /// Salva (cria ou atualiza) a resposta de um item.
  Future<void> upsertAnswer({
    required String auditId,
    required String templateItemId,
    required String response,
    String? observation,
  }) async {
    await _client.from('audit_answers').upsert(
      {
        'audit_id': auditId,
        'template_item_id': templateItemId,
        'response': response,
        'observation': observation,
        'answered_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'audit_id,template_item_id',
    );
  }

  /// Remove a resposta de um item (permite "desmarcar").
  Future<void> deleteAnswer(String auditId, String templateItemId) async {
    await _client
        .from('audit_answers')
        .delete()
        .eq('audit_id', auditId)
        .eq('template_item_id', templateItemId);
  }

  /// Calcula o percentual de conformidade com base nas respostas e nos itens.
  /// Retorna 0–100.
  double calculateConformity(
    List<TemplateItem> items,
    Map<String, String> answers,
  ) {
    double totalWeight = 0;
    double earned = 0;

    for (final item in items) {
      totalWeight += item.weight;
      final ans = answers[item.id];
      if (ans == null || ans.isEmpty) continue;

      switch (item.responseType) {
        case 'ok_nok':
          if (ans == 'ok') earned += item.weight;
        case 'yes_no':
          if (ans == 'yes') earned += item.weight;
        case 'scale_1_5':
          earned += (int.tryParse(ans) ?? 0) / 5 * item.weight;
        case 'percentage':
          earned += (double.tryParse(ans) ?? 0) / 100 * item.weight;
        case 'text':
        case 'selection':
          if (ans.isNotEmpty) earned += item.weight;
      }
    }

    if (totalWeight == 0) return 100.0;
    return (earned / totalWeight * 100).clamp(0.0, 100.0);
  }
}
