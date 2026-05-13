import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/checklist_execution.dart';
import '../../models/checklist_template.dart';
import '../../services/checklist_execution_service.dart';
import '../../services/checklist_template_service.dart';
import '../../services/company_context_service.dart';
import 'checklist_execution_screen.dart';
import 'checklist_templates_screen.dart';

// ---------------------------------------------------------------------------
// Filtros rápidos
// ---------------------------------------------------------------------------
enum _Filter { todos, emAndamento, concluidos }

extension _FilterLabel on _Filter {
  String get label {
    switch (this) {
      case _Filter.todos:       return 'Todos';
      case _Filter.emAndamento: return 'Em andamento';
      case _Filter.concluidos:  return 'Concluídos';
    }
  }
}

// ---------------------------------------------------------------------------
// Tela principal de checklists — lista execuções no padrão de AuditsScreen
// ---------------------------------------------------------------------------
class ChecklistsScreen extends StatefulWidget {
  final String currentUserId;

  const ChecklistsScreen({super.key, required this.currentUserId});

  @override
  State<ChecklistsScreen> createState() => _ChecklistsScreenState();
}

class _ChecklistsScreenState extends State<ChecklistsScreen> {
  final _executionService = ChecklistExecutionService();

  List<ChecklistExecution> _executions = [];
  bool _isLoading = true;
  String? _error;

  _Filter _filter = _Filter.todos;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(
      () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final companyId = CompanyContextService.instance.activeCompanyId;
      final data = await _executionService.getExecutions(companyId: companyId);
      if (mounted) setState(() => _executions = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao carregar checklists.\n$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ChecklistExecution> get _filtered {
    var list = _executions.where((e) {
      switch (_filter) {
        case _Filter.todos:       return true;
        case _Filter.emAndamento: return e.isRascunho;
        case _Filter.concluidos:  return e.isConcluido;
      }
    }).toList();

    if (_searchQuery.isNotEmpty) {
      list = list.where((e) =>
        e.templateName.toLowerCase().contains(_searchQuery) ||
        e.responsavel.toLowerCase().contains(_searchQuery) ||
        e.local.toLowerCase().contains(_searchQuery) ||
        (e.numero?.toLowerCase().contains(_searchQuery) ?? false) ||
        (e.veiculoPlaca?.toLowerCase().contains(_searchQuery) ?? false),
      ).toList();
    }

    return list;
  }

  void _openNewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewChecklistSheet(
        onCreated: (execution) {
          _load();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChecklistExecutionScreen(execution: execution),
          )).then((result) {
            _load();
            if (result == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Checklist finalizado com sucesso.'),
                behavior: SnackBarBehavior.floating,
              ));
            }
          });
        },
      ),
    );
  }

  Future<void> _openExecution(ChecklistExecution e) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChecklistExecutionScreen(execution: e),
    ));
    _load();
  }

  Future<void> _confirmDelete(ChecklistExecution e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir checklist'),
        content: Text(
          'Deseja excluir "${e.templateName}" de ${_fmtDate(e.dataExecucao)}?\n'
          'Todas as respostas serão removidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _executionService.deleteExecution(e.id);
        _load();
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao excluir: $err'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Checklists',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Gerenciar templates',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ChecklistTemplatesScreen(),
            )).then((_) => _load()),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo checklist',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(t),
          Expanded(child: _buildBody(t, filtered)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(AppTheme t) {
    return Container(
      color: t.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por template, responsável ou local…',
              hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: t.textSecondary, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: t.textSecondary, size: 18),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              filled: true,
              fillColor: t.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: t.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: t.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _Filter.values.map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? Colors.white : t.textPrimary,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: AppColors.primary,
                    backgroundColor: t.background,
                    checkmarkColor: Colors.white,
                    side: BorderSide(color: selected ? AppColors.primary : t.divider),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildBody(AppTheme t, List<ChecklistExecution> executions) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: t.textSecondary),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: TextStyle(color: t.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (executions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.checklist_rounded, size: 56, color: t.textSecondary),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty || _filter != _Filter.todos
                    ? 'Nenhum checklist encontrado'
                    : 'Nenhum checklist ainda',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: t.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty || _filter != _Filter.todos
                    ? 'Tente ajustar os filtros ou a busca.'
                    : 'Toque em "Novo checklist" para começar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: executions.length,
        itemBuilder: (_, i) => _ExecutionCard(
          execution: executions[i],
          currentUserId: widget.currentUserId,
          onTap: () => _openExecution(executions[i]),
          onDelete: () => _confirmDelete(executions[i]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card de execução
// ---------------------------------------------------------------------------
class _ExecutionCard extends StatelessWidget {
  final ChecklistExecution execution;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExecutionCard({
    required this.execution,
    required this.currentUserId,
    required this.onTap,
    required this.onDelete,
  });

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final e = execution;
    final isConcluido = e.isConcluido;
    final isOwn = e.createdBy == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: template name + status badge + menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      e.templateName.isEmpty ? 'Checklist' : e.templateName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(isConcluido: isConcluido),
                  if (isOwn) ...[
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded,
                          size: 20, color: t.textSecondary),
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Excluir', style: TextStyle(color: Colors.red)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Info grid
              _InfoRow(
                icon: Icons.person_outline_rounded,
                text: e.responsavel,
                color: t.textSecondary,
              ),
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: e.local,
                color: t.textSecondary,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: _fmtDate(e.dataExecucao),
                    color: t.textSecondary,
                  ),
                  if (e.numero != null) ...[
                    const SizedBox(width: 16),
                    _InfoRow(
                      icon: Icons.tag_rounded,
                      text: e.numero!,
                      color: t.textSecondary,
                    ),
                  ],
                  if (e.veiculoPlaca != null) ...[
                    const SizedBox(width: 16),
                    _InfoRow(
                      icon: Icons.directions_car_outlined,
                      text: e.veiculoPlaca!,
                      color: t.textSecondary,
                    ),
                  ],
                ],
              ),
              // Conformidade (apenas para concluídos)
              if (isConcluido && e.conformityPercent != null) ...[
                const SizedBox(height: 10),
                _ConformityBar(percent: e.conformityPercent!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isConcluido;
  const _StatusBadge({required this.isConcluido});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isConcluido
            ? const Color(0xFF43A047).withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isConcluido ? 'Concluído' : 'Em andamento',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isConcluido ? const Color(0xFF2E7D32) : AppColors.primary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

class _ConformityBar extends StatelessWidget {
  final double percent;
  const _ConformityBar({required this.percent});

  Color get _color {
    if (percent >= 80) return const Color(0xFF43A047);
    if (percent >= 60) return const Color(0xFFFFA000);
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: t.divider,
              valueColor: AlwaysStoppedAnimation(_color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${percent.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _color,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet de criação de nova execução
// ---------------------------------------------------------------------------
class _NewChecklistSheet extends StatefulWidget {
  final void Function(ChecklistExecution) onCreated;

  const _NewChecklistSheet({required this.onCreated});

  @override
  State<_NewChecklistSheet> createState() => _NewChecklistSheetState();
}

class _NewChecklistSheetState extends State<_NewChecklistSheet> {
  final _formKey = GlobalKey<FormState>();
  final _templateService = ChecklistTemplateService();
  final _executionService = ChecklistExecutionService();

  final _responsavelCtrl = TextEditingController();
  final _localCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();

  List<ChecklistTemplate> _templates = [];
  ChecklistTemplate? _selectedTemplate;
  DateTime _dataExecucao = DateTime.now();
  bool _loadingTemplates = true;
  bool _isLoading = false;

  bool get _showPlaca {
    final segment = CompanyContextService.instance.activeCompanySegment;
    final templateCategory = _selectedTemplate?.category ?? '';
    return segment == 'transportador' || templateCategory == 'transportadora';
  }

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _responsavelCtrl.dispose();
    _localCtrl.dispose();
    _placaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final data = await _templateService.getAll();
      if (mounted) setState(() { _templates = data; _loadingTemplates = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTemplates = false);
    }
  }

  String get _displayDate {
    final d = _dataExecucao;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataExecucao,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) setState(() => _dataExecucao = picked);
  }

  Future<void> _confirm() async {
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione um template.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    try {
      final companyId = CompanyContextService.instance.activeCompanyId;
      final execution = await _executionService.createExecution(
        templateId: _selectedTemplate!.id,
        companyId: companyId,
        responsavel: _responsavelCtrl.text.trim(),
        local: _localCtrl.text.trim(),
        veiculoPlaca: _showPlaca && _placaCtrl.text.trim().isNotEmpty
            ? _placaCtrl.text.trim().toUpperCase()
            : null,
        numero: null,
        dataExecucao: _dataExecucao,
      );
      if (mounted) Navigator.pop(context);
      widget.onCreated(execution);
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
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Novo checklist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: t.textPrimary)),
            const SizedBox(height: 16),
            // Template selector
            Text('Template *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: t.textSecondary)),
            const SizedBox(height: 6),
            _loadingTemplates
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<ChecklistTemplate>(
                    initialValue: _selectedTemplate,
                    isExpanded: true,
                    hint: Text('Selecione um template',
                        style: TextStyle(color: t.textSecondary, fontSize: 14)),
                    items: _templates.map((tpl) => DropdownMenuItem(
                      value: tpl,
                      child: Text(tpl.name, overflow: TextOverflow.ellipsis, maxLines: 1),
                    )).toList(),
                    onChanged: (v) => setState(() {
                      _selectedTemplate = v;
                      _placaCtrl.clear(); // limpa placa ao mudar template
                    }),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: t.background,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: t.divider)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: t.divider)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _responsavelCtrl,
                    decoration: const InputDecoration(labelText: 'Responsável *'),
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
                  if (_showPlaca) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _placaCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Placa do veículo',
                        hintText: 'Ex: ABC-1234',
                        prefixIcon: Icon(Icons.directions_car_outlined),
                      ),
                    ),
                  ],
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
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Iniciar',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
