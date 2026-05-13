import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/audit_type.dart';
import '../../models/audit_template.dart';
import '../../services/audit_template_service.dart';
import 'template_builder_screen.dart';

class AuditTemplatesScreen extends StatefulWidget {
  final AuditType type;
  final String? companyId;
  final bool canManage;

  const AuditTemplatesScreen({
    super.key,
    required this.type,
    required this.companyId,
    required this.canManage,
  });

  @override
  State<AuditTemplatesScreen> createState() => _AuditTemplatesScreenState();
}

class _AuditTemplatesScreenState extends State<AuditTemplatesScreen> {
  final _service = AuditTemplateService();
  List<AuditTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getTemplates(
        typeId: widget.type.id,
        companyId: widget.companyId,
      );
      if (mounted) setState(() => _templates = data);
    } catch (e) {
      _showError('Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showTemplateForm([AuditTemplate? editing]) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final descCtrl = TextEditingController(text: editing?.description ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(widget.type.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  editing != null ? 'Editar Template' : 'Novo Template',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                )),
              ]),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDec('Nome do template *', Icons.assignment_outlined, ctx),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: descCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDec('Descrição (opcional)', Icons.notes_rounded, ctx),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(editing != null ? 'Salvar' : 'Criar e configurar',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      AuditTemplate template;
      if (editing != null) {
        await _service.updateTemplate(
            editing.id, nameCtrl.text.trim(),
            descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
        _load();
      } else {
        template = await _service.createTemplate(
          typeId: widget.type.id,
          name: nameCtrl.text.trim(),
          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          companyId: widget.companyId,
        );
        if (!mounted) return;
        // Abre o builder imediatamente
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TemplateBuilderScreen(template: template),
        ));
        _load();
      }
    } catch (e) {
      _showError('Erro: $e');
    }
  }

  Future<void> _confirmDelete(AuditTemplate t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir template'),
        content: Text('Excluir "${t.name}"? Todos os itens serão removidos.'),
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
    if (confirm == true) {
      try {
        await _service.deleteTemplate(t.id);
        _load();
      } catch (e) { _showError('Erro: $e'); }
    }
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
    filled: true, fillColor: AppTheme.of(ctx).surface,
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
    final color = widget.type.colorValue;
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.type.icon}  ${widget.type.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Text('Templates', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showTemplateForm(),
              backgroundColor: color,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Novo Template',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _templates.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.type.icon, style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text('Nenhum template cadastrado',
                        style: TextStyle(color: AppTheme.of(context).textSecondary)),
                    if (widget.canManage) ...[
                      const SizedBox(height: 4),
                      Text('Toque em "Novo Template" para criar',
                          style: TextStyle(color: AppTheme.of(context).textSecondary, fontSize: 12)),
                    ],
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _templates.length,
                    itemBuilder: (_, i) => _buildCard(_templates[i], color),
                  ),
                ),
    );
  }

  Widget _buildCard(AuditTemplate t, Color typeColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.of(context).divider)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(widget.type.icon,
              style: const TextStyle(fontSize: 22))),
        ),
        title: Text(t.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (t.description != null)
              Text(t.description!,
                  style: TextStyle(fontSize: 12, color: AppTheme.of(context).textSecondary)),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: t.active ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(t.active ? 'Ativo' : 'Inativo',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: t.active ? Colors.green[700] : Colors.grey[600])),
              ),
              if (t.isGlobal) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Global',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppColors.accent)),
                ),
              ],
            ]),
          ],
        ),
        trailing: widget.canManage && (!t.isGlobal || widget.companyId == null)
            ? PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppTheme.of(context).textSecondary),
                onSelected: (v) async {
                  if (v == 'edit') _showTemplateForm(t);
                  if (v == 'build') {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TemplateBuilderScreen(template: t),
                    )).then((_) => _load());
                  }
                  if (v == 'toggle') {
                    await _service.toggleTemplate(t.id, !t.active);
                    _load();
                  }
                  if (v == 'delete') _confirmDelete(t);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'build', child: Row(children: [
                    Icon(Icons.build_outlined, size: 18), SizedBox(width: 8),
                    Text('Configurar itens'),
                  ])),
                  const PopupMenuItem(value: 'edit', child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8),
                    Text('Editar'),
                  ])),
                  PopupMenuItem(value: 'toggle', child: Row(children: [
                    Icon(t.active ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(t.active ? 'Desativar' : 'Ativar'),
                  ])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Excluir', style: TextStyle(color: AppColors.error)),
                  ])),
                ],
              )
            : Icon(Icons.chevron_right_rounded, color: AppTheme.of(context).textSecondary),
        // Qualquer usuário com permissão pode visualizar o template;
        // edição é restrita pelo trailing (PopupMenuButton só aparece quando autorizado).
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TemplateBuilderScreen(template: t),
          )).then((_) => _load()),
      ),
    );
  }
}
