/// Resposta de um auditor a um item de template durante a execução.
/// Mapeado da tabela `audit_answers`.
/// A constraint UNIQUE(audit_id, template_item_id) garante uma resposta por item.
class AuditAnswer {
  final String id;
  final String auditId;
  final String templateItemId;
  final String response;      // Valor da resposta (ex: 'ok', 'nok', '3', '75.5', 'texto livre')
  final String? observation;  // Observação opcional do auditor
  final DateTime answeredAt;

  const AuditAnswer({
    required this.id,
    required this.auditId,
    required this.templateItemId,
    required this.response,
    this.observation,
    required this.answeredAt,
  });

  factory AuditAnswer.fromMap(Map<String, dynamic> map) {
    return AuditAnswer(
      id: map['id'],
      auditId: map['audit_id'],
      templateItemId: map['template_item_id'],
      response: map['response'],
      observation: map['observation'],
      answeredAt: DateTime.parse(map['answered_at']),
    );
  }
}
