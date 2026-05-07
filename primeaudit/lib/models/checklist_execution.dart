/// Representa uma execução de checklist.
///
/// Mapeado da tabela `checklist_executions`.
/// Módulo independente do módulo de Auditoria — zero acoplamento com [Audit].
class ChecklistExecution {
  final String id;
  final String templateId;
  final String templateName; // join via checklist_templates(name)
  final String? companyId;
  final String createdBy;
  final String responsavel;
  final String local;
  final String? numero;
  final String? veiculoPlaca; // Preenchido para empresas do segmento transportador
  final DateTime dataExecucao; // DATE — sem timezone (não usar .toLocal())
  final String status; // 'rascunho' | 'concluido'
  final double? conformityPercent;
  final DateTime createdAt;
  final DateTime? completedAt;

  ChecklistExecution({
    required this.id,
    required this.templateId,
    required this.templateName,
    this.companyId,
    required this.createdBy,
    required this.responsavel,
    required this.local,
    this.numero,
    this.veiculoPlaca,
    required this.dataExecucao,
    required this.status,
    this.conformityPercent,
    required this.createdAt,
    this.completedAt,
  });

  factory ChecklistExecution.fromMap(Map<String, dynamic> map) {
    return ChecklistExecution(
      id: map['id'],
      templateId: map['template_id'],
      templateName: map['checklist_templates']?['name'] ?? '',
      companyId: map['company_id'],
      createdBy: map['created_by'] ?? '',
      responsavel: map['responsavel'] ?? '',
      local: map['local'] ?? '',
      numero: map['numero'],
      veiculoPlaca: map['veiculo_placa'],
      // DATE column — NÃO usar .toLocal() (pitfall de timezone UTC-3)
      dataExecucao: DateTime.parse(map['data_execucao']),
      status: map['status'] ?? 'rascunho',
      conformityPercent: (map['conformity_percent'] as num?)?.toDouble(),
      // TIMESTAMPTZ — usar .toLocal()
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at']).toLocal()
          : null,
    );
  }

  bool get isConcluido => status == 'concluido';
  bool get isRascunho => status == 'rascunho';
}

/// Representa uma resposta a um item de checklist.
///
/// Mapeado da tabela `checklist_answers`.
/// Usado pelos services para popular Map<String, String> _answers na screen.
class ChecklistAnswer {
  final String id;
  final String executionId;
  final String itemId;
  final String response;
  final String? observation;
  final DateTime answeredAt;

  ChecklistAnswer({
    required this.id,
    required this.executionId,
    required this.itemId,
    required this.response,
    this.observation,
    required this.answeredAt,
  });

  factory ChecklistAnswer.fromMap(Map<String, dynamic> map) {
    return ChecklistAnswer(
      id: map['id'],
      executionId: map['execution_id'],
      itemId: map['item_id'],
      response: map['response'] ?? '',
      observation: map['observation'],
      answeredAt: DateTime.parse(map['answered_at']).toLocal(),
    );
  }
}
