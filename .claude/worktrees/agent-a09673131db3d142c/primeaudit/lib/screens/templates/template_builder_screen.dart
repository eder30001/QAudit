import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/audit_template.dart';
import '../../services/audit_template_service.dart';

class TemplateBuilderScreen extends StatefulWidget {
  final AuditTemplate template;

  const TemplateBuilderScreen({super.key, required this.template});

  @override
  State<TemplateBuilderScreen> createState() => _TemplateBuilderScreenState();
}

class _TemplateBuilderScreenState extends State<TemplateBuilderScreen> {
  final _service = AuditTemplateService();

  List<TemplateSection> _sections = [];
  List<TemplateItem> _items = []; // itens sem seção
  bool _isLoading = true;

  static const _responseTypes = [
    ('ok_nok',     'Conforme / Não Conforme', Icons.check_circle_outline),
    ('yes_no',     'Sim / Não',               Icons.toggle_on_outlined),
    ('scale_1_5',  'Escala 1 a 5',            Icons.star_outline_rounded),
    ('text',       'Texto livre',             Icons.short_text_rounded),
    ('percentage', 'Percentual (%)',          Icons.percent_rounded),
    ('selection',  'Seleção de opções',       Icons.list_alt_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final sections = await _service.getSections(widget.template.id);
      final allItems = await _service.getItems(widget.template.id);

      for (final s in sections) {
        s.items = allItems.where((i) => i.sectionId == s.id).toList();
      }
      final noSection = allItems.where((i) => i.sectionId == null).toList();

      if (mounted) {
        setState(() {
          _sections = sections;
          _items = noSection;
        });
      }
    } catch (e) {
      _showError('Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSection() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Seção'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nome da seção'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Criar')),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    try {
      await _service.createSection(widget.template.id, ctrl.text.trim(), _sections.length);
      _load();
    } catch (e) { _showError('Erro: $e'); }
  }

  Future<void> _showItemForm({TemplateItem? editing, String? sectionId}) async {
    final questionCtrl = TextEditingController(text: editing?.question ?? '');
    final guidanceCtrl = TextEditingController(text: editing?.guidance ?? '');
    final optionCtrl = TextEditingController();
    String selectedType = editing?.responseType ?? 'ok_nok';
    bool isRequired = editing?.required ?? true;
    int weight = editing?.weight ?? 1;
    List<String> options = List.from(editing?.options ?? []);
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SingleChildScrollView(
          padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(editing != null ? 'Editar Item' : 'Novo Item',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: questionCtrl,
                  autofocus: true,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDec('Pergunta / Critério *', Icons.help_outline_rounded, ctx),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: guidanceCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDec('Orientação ao auditor (opcional)', Icons.info_outline, ctx),
                ),
                const SizedBox(height: 16),
                Text('Tipo de resposta',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.of(ctx).textSecondary)),
                const SizedBox(height: 8),
                ..._responseTypes.map(((String, String, IconData) rt) {
                  final isSelected = selectedType == rt.$1;
                  return GestureDetector(
                    onTap: () => set(() => selectedType = rt.$1),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : AppTheme.of(ctx).background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppTheme.of(ctx).divider,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Icon(rt.$3, size: 18,
                            color: isSelected ? AppColors.primary : AppTheme.of(ctx).textSecondary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(rt.$2,
                            style: TextStyle(fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? AppColors.primary : AppTheme.of(ctx).textPrimary))),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.primary, size: 18),
                      ]),
                    ),
                  );
                }),
                // Editor de opções — só aparece quando selection está selecionado
                if (selectedType == 'selection') ...[
                  const SizedBox(height: 16),
                  Text('Opções de seleção',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.of(ctx).textSecondary)),
                  const SizedBox(height: 8),
                  if (options.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Nenhuma opção adicionada ainda.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.of(ctx).textSecondary)),
                    )
                  else
                    ...options.asMap().entries.map((e) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.of(ctx).background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.of(ctx).divider),
                          ),
                          child: Row(children: [
                            const Icon(Icons.drag_handle_rounded,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(e.value,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          AppTheme.of(ctx).textPrimary)),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  set(() => options.removeAt(e.key)),
                              child: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 18,
                                  color: Colors.redAccent),
                            ),
                          ]),
                        )),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: optionCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Nova opção...',
                          hintStyle: TextStyle(
                              color: AppTheme.of(ctx).textSecondary,
                              fontSize: 13),
                          filled: true,
                          fillColor: AppTheme.of(ctx).background,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppTheme.of(ctx).divider)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppTheme.of(ctx).divider)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: AppColors.accent, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty) {
                            set(() {
                              options.add(v.trim());
                              optionCtrl.clear();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded,
                          color: AppColors.primary),
                      onPressed: () {
                        if (optionCtrl.text.trim().isNotEmpty) {
                          set(() {
                            options.add(optionCtrl.text.trim());
                            optionCtrl.clear();
                          });
                        }
                      },
                    ),
                  ]),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: SwitchListTile(
                      title: const Text('Obrigatório', style: TextStyle(fontSize: 13)),
                      value: isRequired,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) => set(() => isRequired = v),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Peso', style: TextStyle(fontSize: 12, color: AppTheme.of(ctx).textSecondary)),
                      Row(children: [
                        IconButton(
                          onPressed: weight > 1 ? () => set(() => weight--) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          iconSize: 20,
                        ),
                        Text('$weight', style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          onPressed: weight < 5 ? () => set(() => weight++) : null,
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: 20,
                        ),
                      ]),
                    ],
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      if (selectedType == 'selection' && options.isEmpty) {
                        _showError('Adicione pelo menos uma opção de seleção.');
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        final resolvedOptions =
                            selectedType == 'selection' ? options : null;
                        if (editing != null) {
                          await _service.updateItem(editing.id,
                            question: questionCtrl.text.trim(),
                            guidance: guidanceCtrl.text.trim().isEmpty ? null : guidanceCtrl.text.trim(),
                            responseType: selectedType,
                            required: isRequired,
                            weight: weight,
                            options: resolvedOptions,
                          );
                        } else {
                          final total = _items.length +
                              _sections.fold<int>(0, (s, sec) => s + sec.items.length);
                          await _service.createItem(
                            templateId: widget.template.id,
                            sectionId: sectionId,
                            question: questionCtrl.text.trim(),
                            guidance: guidanceCtrl.text.trim().isEmpty ? null : guidanceCtrl.text.trim(),
                            responseType: selectedType,
                            required: isRequired,
                            weight: weight,
                            orderIndex: total,
                            options: resolvedOptions,
                          );
                        }
                        _load();
                      } catch (e) { _showError('Erro: $e'); }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(editing != null ? 'Salvar' : 'Adicionar',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  InputDecoration _inputDec(String label, IconData icon, BuildContext ctx) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AppTheme.of(ctx).textSecondary, size: 20),
    filled: true, fillColor: AppTheme.of(ctx).background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.of(ctx).divider)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.of(ctx).divider)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    final totalItems = _items.length + _sections.fold(0, (s, sec) => s + sec.items.length);

    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.template.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('$totalItems ${totalItems == 1 ? 'item' : 'itens'}',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_rounded),
            tooltip: 'Adicionar seção',
            onPressed: _addSection,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Item',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : totalItems == 0 && _sections.isEmpty
              ? _buildEmpty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    // Itens sem seção
                    if (_items.isNotEmpty) ...[
                      ..._items.map((item) => _buildItemCard(item)),
                      const SizedBox(height: 8),
                    ],
                    // Seções
                    ..._sections.map((s) => _buildSection(s)),
                  ],
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_rounded, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Template vazio', style: TextStyle(color: AppTheme.of(context).textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Adicione seções e itens ao template',
              style: TextStyle(color: AppTheme.of(context).textSecondary, fontSize: 12)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _addSection,
            icon: const Icon(Icons.playlist_add_rounded),
            label: const Text('Adicionar Seção'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(TemplateSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8, top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(section.name,
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.primary))),
              Text('${section.items.length} itens',
                  style: const TextStyle(fontSize: 11, color: AppColors.primary)),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                iconSize: 18,
                icon: const Icon(Icons.more_vert, color: AppColors.primary),
                onSelected: (v) async {
                  if (v == 'add') _showItemForm(sectionId: section.id);
                  if (v == 'rename') {
                    final ctrl = TextEditingController(text: section.name);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Renomear seção'),
                        content: TextField(controller: ctrl, autofocus: true),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
                        ],
                      ),
                    );
                    if (ok == true && ctrl.text.trim().isNotEmpty) {
                      await _service.updateSection(section.id, ctrl.text.trim());
                      _load();
                    }
                  }
                  if (v == 'delete') {
                    if (!mounted) return;
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Excluir seção'),
                        content: Text('Excluir "${section.name}"? Os itens da seção não serão excluídos.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(foregroundColor: AppColors.error),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && mounted) {
                      await _service.deleteSection(section.id);
                      _load();
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'add', child: Text('Adicionar item aqui')),
                  const PopupMenuItem(value: 'rename', child: Text('Renomear')),
                  const PopupMenuItem(value: 'delete',
                      child: Text('Excluir seção', style: TextStyle(color: AppColors.error))),
                ],
              ),
            ],
          ),
        ),
        if (section.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: TextButton.icon(
              onPressed: () => _showItemForm(sectionId: section.id),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar item', style: TextStyle(fontSize: 12)),
            ),
          )
        else
          ...section.items.map((item) => _buildItemCard(item, inSection: true)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildItemCard(TemplateItem item, {bool inSection = false}) {
    final typeInfo = _responseTypes.firstWhere(
      (r) => r.$1 == item.responseType,
      orElse: () => ('', item.responseType, Icons.circle_outlined),
    );

    return Container(
      margin: EdgeInsets.only(left: inSection ? 12 : 0, bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.of(context).divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(typeInfo.$3, size: 14, color: AppColors.primary),
        ),
        title: Text(item.question,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Row(
          children: [
            Text(typeInfo.$2,
                style: TextStyle(fontSize: 11, color: AppTheme.of(context).textSecondary)),
            if (item.weight > 1) ...[
              Text(' · ', style: TextStyle(color: AppTheme.of(context).textSecondary)),
              Text('Peso ${item.weight}',
                  style: TextStyle(fontSize: 11, color: AppTheme.of(context).textSecondary)),
            ],
            if (item.responseType == 'selection') ...[
              Text(' · ', style: TextStyle(color: AppTheme.of(context).textSecondary)),
              Text('${item.options.length} opções',
                  style: TextStyle(fontSize: 11, color: AppTheme.of(context).textSecondary)),
            ],
            if (!item.required) ...[
              Text(' · ', style: TextStyle(color: AppTheme.of(context).textSecondary)),
              Text('Opcional',
                  style: TextStyle(fontSize: 11, color: AppTheme.of(context).textSecondary)),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          iconSize: 18,
          icon: Icon(Icons.more_vert, color: AppTheme.of(context).textSecondary),
          onSelected: (v) async {
            if (v == 'edit') _showItemForm(editing: item, sectionId: item.sectionId);
            if (v == 'delete') {
              await _service.deleteItem(item.id);
              _load();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(value: 'delete',
                child: Text('Excluir', style: TextStyle(color: AppColors.error))),
          ],
        ),
      ),
    );
  }
}
