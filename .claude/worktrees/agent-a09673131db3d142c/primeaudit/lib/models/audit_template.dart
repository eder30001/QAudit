/// Representa um item (pergunta) dentro de um template de auditoria.
///
/// Mapeado da tabela `template_items`. Um item pertence a um [AuditTemplate]
/// e opcionalmente a uma [TemplateSection].
class TemplateItem {
  final String id;
  final String templateId;
  final String? sectionId;   // Null se o item não está em nenhuma seção
  final String question;
  final String? guidance;    // Orientação exibida ao auditor durante a execução
  final String responseType; // Tipo de resposta (ver [responseTypeLabel])
  final bool required;
  final int weight;          // Peso para cálculo do score de conformidade
  final int orderIndex;      // Posição do item dentro da seção ou template
  final List<String> options; // Usado apenas quando responseType == 'selection'

  TemplateItem({
    required this.id,
    required this.templateId,
    this.sectionId,
    required this.question,
    this.guidance,
    required this.responseType,
    required this.required,
    required this.weight,
    required this.orderIndex,
    this.options = const [],
  });

  factory TemplateItem.fromMap(Map<String, dynamic> map) {
    return TemplateItem(
      id: map['id'],
      templateId: map['template_id'],
      sectionId: map['section_id'],
      question: map['question'],
      guidance: map['guidance'],
      responseType: map['response_type'] ?? 'ok_nok',
      required: map['required'] ?? true,
      weight: map['weight'] ?? 1,
      orderIndex: map['order_index'] ?? 0,
      options: (map['options'] as List?)?.cast<String>() ?? [],
    );
  }

  /// Rótulo legível do tipo de resposta para exibição na UI.
  String get responseTypeLabel {
    switch (responseType) {
      case 'ok_nok':     return 'Conforme / Não Conforme';
      case 'yes_no':     return 'Sim / Não';
      case 'scale_1_5':  return 'Escala 1 a 5';
      case 'text':       return 'Texto livre';
      case 'percentage': return 'Percentual (0-100%)';
      case 'selection':  return 'Seleção de opções';
      default:           return responseType;
    }
  }
}

/// Agrupa [TemplateItem]s dentro de um [AuditTemplate].
///
/// Mapeado da tabela `template_sections`. Os itens são carregados
/// separadamente e associados via [AuditTemplateService].
class TemplateSection {
  final String id;
  final String templateId;
  final String name;
  final int orderIndex;
  List<TemplateItem> items; // Populado em memória após carregar os itens

  TemplateSection({
    required this.id,
    required this.templateId,
    required this.name,
    required this.orderIndex,
    this.items = const [],
  });

  factory TemplateSection.fromMap(Map<String, dynamic> map) {
    return TemplateSection(
      id: map['id'],
      templateId: map['template_id'],
      name: map['name'],
      orderIndex: map['order_index'] ?? 0,
    );
  }
}

/// Representa um template de auditoria configurável.
///
/// Mapeado da tabela `audit_templates`. Um template pertence a um [AuditType]
/// e pode ser global ([companyId] == null) ou exclusivo de uma empresa.
/// Templates globais são criados por superuser/dev e visíveis para todas as empresas.
class AuditTemplate {
  final String id;
  final String typeId;
  final String? companyId;    // Null = template global (todas as empresas)
  final String name;
  final String? description;
  final bool active;
  final String? typeName;     // Preenchido via join com audit_types
  final String? typeIcon;     // Preenchido via join com audit_types

  AuditTemplate({
    required this.id,
    required this.typeId,
    this.companyId,
    required this.name,
    this.description,
    required this.active,
    this.typeName,
    this.typeIcon,
  });

  /// Espera o join `audit_types(name, icon)` para preencher [typeName] e [typeIcon].
  factory AuditTemplate.fromMap(Map<String, dynamic> map) {
    return AuditTemplate(
      id: map['id'],
      typeId: map['type_id'],
      companyId: map['company_id'],
      name: map['name'],
      description: map['description'],
      active: map['active'] ?? true,
      typeName: map['audit_types']?['name'],
      typeIcon: map['audit_types']?['icon'],
    );
  }

  /// True se o template é global (disponível para todas as empresas).
  bool get isGlobal => companyId == null;
}
