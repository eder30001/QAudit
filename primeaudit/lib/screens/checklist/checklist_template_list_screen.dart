import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/checklist_execution.dart';
import '../../models/checklist_template.dart';
import '../../services/checklist_execution_service.dart';
import '../../services/checklist_template_service.dart';
import '../../services/company_context_service.dart';
import 'checklist_execution_screen.dart';
import 'checklist_template_form_screen.dart';

/// Tela de lista de templates filtrada por categoria.
///
/// Recebe [category]: 'industrial' | 'transportadora' | 'meus'.
/// Seeds (is_padrao = true) mostram badge 'Padrão' e ícone de cópia.
/// Templates próprios mostram badge 'Personalizado' e PopupMenuButton (Editar/Clonar/Excluir).
class ChecklistTemplateListScreen extends StatefulWidget {
  final String category;
  final String title;

  const ChecklistTemplateListScreen({
    super.key,
    required this.category,
    required this.title,
  });

  @override
  State<ChecklistTemplateListScreen> createState() =>
      _ChecklistTemplateListScreenState();
}

class _ChecklistTemplateListScreenState
    extends State<ChecklistTemplateListScreen> {
  final _service = ChecklistTemplateService();
  final _executionService = ChecklistExecutionService();
  List<ChecklistTemplate> _templates = [];
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<ChecklistTemplate> result;
      if (widget.category == 'meus') {
        result = await _service.getOwned();
      } else {
        result = await _service.getByCategory(widget.category);
      }
      if (mounted) setState(() => _templates = result);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erro ao carregar templates. Puxe para atualizar.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCreate() {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => const ChecklistTemplateFormScreen()))
        .then((_) => _load());
  }

  void _openEdit(ChecklistTemplate t) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => ChecklistTemplateFormScreen(editing: t)))
        .then((_) => _load());
  }

  Future<void> _confirmDelete(ChecklistTemplate t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir checklist'),
        content: Text(
            'Excluir "${t.name}"? Todos os itens serão removidos e essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir checklist'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await _service.deleteTemplate(t.id);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Checklist excluído.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao excluir. Tente novamente.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCloneSheet(ChecklistTemplate t) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CloneBottomSheet(
        template: t,
        service: _service,
        parentContext: context,
        onAfterClone: _load,
      ),
    );
  }

  Future<void> _showStartSheet(ChecklistTemplate t) async {
    final result = await showModalBottomSheet<ChecklistExecution>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _StartChecklistSheet(
        template: t,
        service: _executionService,
        parentContext: context,
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(
              builder: (_) => ChecklistExecutionScreen(execution: result)))
          .then((finished) {
        _load();
        if (finished == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Checklist finalizado com sucesso.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      });
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(
              height: 300,
              child: Center(
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_templates.isEmpty) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _templates.length,
        itemBuilder: (_, i) => _ChecklistTemplateCard(
          template: _templates[i],
          currentUserId: _currentUserId,
          onDelete: () => _confirmDelete(_templates[i]),
          onEdit: () => _openEdit(_templates[i]),
          onClone: () => _showCloneSheet(_templates[i]),
          onExecute: () => _showStartSheet(_templates[i]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final IconData icon;
    final String heading;
    final String body;

    switch (widget.category) {
      case 'industrial':
        icon = Icons.factory_outlined;
        heading = 'Nenhum template disponível';
        body = 'Os templates padrão serão carregados em breve.';
      case 'transportadora':
        icon = Icons.local_shipping_outlined;
        heading = 'Nenhum template disponível';
        body = 'Os templates padrão serão carregados em breve.';
      default:
        icon = Icons.checklist_rounded;
        heading = 'Nenhum checklist criado';
        body = 'Crie um checklist personalizado ou clone um template existente.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTheme.of(context).textSecondary),
          const SizedBox(height: 12),
          Text(
            heading,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              body,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.of(context).textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Novo checklist',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── _ChecklistTemplateCard ────────────────────────────────────────────────────

class _ChecklistTemplateCard extends StatelessWidget {
  final ChecklistTemplate template;
  final String? currentUserId;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Future<void> Function() onClone;
  final VoidCallback onExecute;

  const _ChecklistTemplateCard({
    required this.template,
    required this.currentUserId,
    required this.onDelete,
    required this.onEdit,
    required this.onClone,
    required this.onExecute,
  });

  Color get _categoryColor {
    switch (template.category) {
      case 'industrial':
        return Colors.orange;
      case 'transportadora':
        return const Color(0xFF1565C0);
      default:
        return AppColors.accent;
    }
  }

  IconData get _categoryIcon {
    switch (template.category) {
      case 'industrial':
        return Icons.factory_outlined;
      case 'transportadora':
        return Icons.local_shipping_outlined;
      default:
        return Icons.checklist_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final isOwn = template.createdBy == currentUserId && !template.isSeed;

    Widget trailing;
    if (template.isSeed) {
      trailing = IconButton(
        icon: Icon(Icons.copy_outlined, size: 20, color: t.textSecondary),
        tooltip: 'Clonar template',
        onPressed: onClone,
      );
    } else if (isOwn) {
      trailing = PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: t.textSecondary),
        onSelected: (v) {
          if (v == 'edit') onEdit();
          if (v == 'clone') onClone();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Editar'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'clone',
            child: Row(
              children: [
                Icon(Icons.copy_outlined, size: 18),
                SizedBox(width: 8),
                Text('Clonar'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                const SizedBox(width: 8),
                const Text('Excluir',
                    style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
      );
    } else {
      trailing = Icon(Icons.chevron_right_rounded, color: t.textSecondary);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.divider),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _categoryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_categoryIcon, size: 22, color: _categoryColor),
            ),
            title: Text(
              template.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (template.description != null)
                  Text(
                    template.description!,
                    style: TextStyle(fontSize: 12, color: t.textSecondary),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (template.isSeed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Padrão',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    if (isOwn)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Personalizado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: trailing,
            onTap: () {
              if (template.isSeed) {
                onClone();
              } else if (isOwn) {
                onEdit();
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onExecute,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Executar',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _CloneBottomSheet ─────────────────────────────────────────────────────────

class _CloneBottomSheet extends StatefulWidget {
  final ChecklistTemplate template;
  final ChecklistTemplateService service;
  final BuildContext parentContext;
  final VoidCallback onAfterClone;

  const _CloneBottomSheet({
    required this.template,
    required this.service,
    required this.parentContext,
    required this.onAfterClone,
  });

  @override
  State<_CloneBottomSheet> createState() => _CloneBottomSheetState();
}

class _CloneBottomSheetState extends State<_CloneBottomSheet> {
  bool _isCloning = false;

  Future<void> _clone() async {
    final messenger = ScaffoldMessenger.of(widget.parentContext);
    setState(() => _isCloning = true);
    try {
      await widget.service.cloneTemplate(widget.template);
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Checklist clonado com sucesso. Acesse "Meus checklists".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onAfterClone();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Erro ao clonar. Tente novamente.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.copy_outlined, color: t.textPrimary),
              const SizedBox(width: 12),
              Text(
                'Clonar template',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Clonar "${widget.template.name}" para Meus checklists?',
            style: TextStyle(fontSize: 14, color: t.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Você poderá editar os itens depois.',
            style: TextStyle(fontSize: 12, color: t.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isCloning ? null : _clone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isCloning
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : const Text(
                      'Clonar checklist',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: t.textSecondary),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _StartChecklistSheet ──────────────────────────────────────────────────────

class _StartChecklistSheet extends StatefulWidget {
  final ChecklistTemplate template;
  final ChecklistExecutionService service;
  final BuildContext parentContext;

  const _StartChecklistSheet({
    required this.template,
    required this.service,
    required this.parentContext,
  });

  @override
  State<_StartChecklistSheet> createState() => _StartChecklistSheetState();
}

class _StartChecklistSheetState extends State<_StartChecklistSheet> {
  final _formKey = GlobalKey<FormState>();
  final _responsavelCtrl = TextEditingController();
  final _localCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  DateTime _dataExecucao = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _responsavelCtrl.dispose();
    _localCtrl.dispose();
    _numeroCtrl.dispose();
    super.dispose();
  }

  String get _displayDate {
    final d = _dataExecucao;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataExecucao,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => _dataExecucao = picked);
    }
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    // Capturar messenger ANTES do await (use_build_context_synchronously)
    final messenger = ScaffoldMessenger.of(widget.parentContext);
    try {
      final companyId = CompanyContextService.instance.activeCompanyId;
      final execution = await widget.service.createExecution(
        templateId: widget.template.id,
        companyId: companyId,
        responsavel: _responsavelCtrl.text.trim(),
        local: _localCtrl.text.trim(),
        numero: _numeroCtrl.text.trim().isEmpty
            ? null
            : _numeroCtrl.text.trim(),
        dataExecucao: _dataExecucao,
      );
      if (mounted) Navigator.pop(context, execution);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      messenger.showSnackBar(SnackBar(
        content: const Text('Erro ao iniciar checklist. Tente novamente.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Iniciar checklist',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.template.name,
            style: TextStyle(fontSize: 13, color: t.textSecondary),
          ),
          const Divider(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _responsavelCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Responsável *'),
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _localCtrl,
                  decoration: const InputDecoration(labelText: 'Local *'),
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Data de execução *'),
                    child: Text(_displayDate),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _numeroCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Número/código (opcional)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirmar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
