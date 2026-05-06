/// Representa um template de checklist.
///
/// Mapeado da tabela `checklist_templates`.
/// Módulo independente do módulo de Auditoria — zero acoplamento com [AuditTemplate].
class ChecklistTemplate {
  final String id;
  final String name;
  final String category; // 'industrial' | 'transportadora'
  final String? description;
  final bool isPadrao;
  final String? companyId;
  final String? createdBy;
  final DateTime createdAt;
  List<ChecklistTemplateItem> items; // Populado em memória após carregar os itens

  ChecklistTemplate({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.isPadrao,
    this.companyId,
    this.createdBy,
    required this.createdAt,
    this.items = const [],
  });

  factory ChecklistTemplate.fromMap(Map<String, dynamic> map) {
    return ChecklistTemplate(
      id: map['id'],
      name: map['name'],
      category: map['category'] ?? 'industrial',
      description: map['description'],
      isPadrao: map['is_padrao'] ?? false,
      companyId: map['company_id'],
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']).toLocal(),
    );
  }

  /// Returns true when this template is a system seed (is_padrao = true).
  /// Seeds cannot be edited or deleted by regular users.
  bool get isSeed => isPadrao;
}

/// Representa um item (pergunta) dentro de um template de checklist.
///
/// Mapeado da tabela `checklist_template_items`.
class ChecklistTemplateItem {
  final String id;
  final String templateId;
  final String description;
  final String itemType; // 'yes_no' | 'text' | 'number' | 'date' | 'multiple_choice' | 'photo'
  final int orderIndex;
  final List<String> options; // Opções para item_type == 'multiple_choice'; [] para outros tipos

  ChecklistTemplateItem({
    required this.id,
    required this.templateId,
    required this.description,
    required this.itemType,
    required this.orderIndex,
    this.options = const [],
  });

  factory ChecklistTemplateItem.fromMap(Map<String, dynamic> map) {
    return ChecklistTemplateItem(
      id: map['id'],
      templateId: map['template_id'],
      description: map['description'] ?? '',
      itemType: map['item_type'] ?? 'yes_no',
      orderIndex: map['order_index'] ?? 0,
      options: (map['options'] as List?)?.cast<String>() ?? [],
    );
  }
}
