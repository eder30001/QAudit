import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/corrective_action.dart';
import '../services/corrective_action_service.dart';
import '../services/company_context_service.dart';
import 'corrective_action_detail_screen.dart';

enum _StatusFilter { todas, abertas, emAnalise, reaberta, finalizadas }

extension _StatusFilterLabel on _StatusFilter {
  String get label {
    switch (this) {
      case _StatusFilter.todas:     return 'Todos';
      case _StatusFilter.abertas:   return 'Em aberto';
      case _StatusFilter.emAnalise: return 'Em análise';
      case _StatusFilter.reaberta:  return 'Reaberta';
      case _StatusFilter.finalizadas: return 'Finalizadas';
    }
  }

  String? get dbValue {
    switch (this) {
      case _StatusFilter.emAnalise: return 'em_analise';
      case _StatusFilter.reaberta:  return 'reaberta';
      default:                      return null;
    }
  }
}

class CorrectiveActionsScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;

  const CorrectiveActionsScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  State<CorrectiveActionsScreen> createState() =>
      _CorrectiveActionsScreenState();
}

class _CorrectiveActionsScreenState extends State<CorrectiveActionsScreen> {
  final _service = CorrectiveActionService();

  List<CorrectiveAction> _actions = [];
  bool _isLoading = true;
  String? _error;

  _StatusFilter _statusFilter = _StatusFilter.todas;
  String? _responsibleFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final companyId = CompanyContextService.instance.activeCompanyId;
      final data = await _service.getActions(
        companyId: companyId,
        statusFilter: _statusFilter.dbValue,
        responsibleFilter: _responsibleFilter,
      );
      if (mounted) setState(() => _actions = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao carregar ações.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<CorrectiveAction> get _filtered {
    List<CorrectiveAction> list = _actions;
    switch (_statusFilter) {
      case _StatusFilter.todas:
        break;
      case _StatusFilter.abertas:
        // Inclui status ativos (novos + legado)
        list = list
            .where((a) =>
                a.status == CorrectiveActionStatus.aberta ||
                a.status == CorrectiveActionStatus.reaberta ||
                a.status == CorrectiveActionStatus.emAndamento ||   // legado
                a.status == CorrectiveActionStatus.emAvaliacao)     // legado
            .toList();
        break;
      case _StatusFilter.emAnalise:
        list = list
            .where((a) => a.status == CorrectiveActionStatus.emAnalise)
            .toList();
        break;
      case _StatusFilter.reaberta:
        list = list
            .where((a) => a.status == CorrectiveActionStatus.reaberta ||
                a.status == CorrectiveActionStatus.rejeitada) // legado
            .toList();
        break;
      case _StatusFilter.finalizadas:
        list = list.where((a) => a.status.isFinal).toList();
        break;
    }
    if (_responsibleFilter != null) {
      list = list.where((a) => a.responsibleUserId == _responsibleFilter).toList();
    }
    return list;
  }

  List<MapEntry<String, String>> get _responsibles {
    final seen = <String>{};
    return _actions
        .where((a) => a.responsibleName != null && seen.add(a.responsibleUserId))
        .map((a) => MapEntry(a.responsibleUserId, a.responsibleName!))
        .toList();
  }

  void _openDetail(CorrectiveAction action) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => CorrectiveActionDetailScreen(
            action: action,
            currentUserId: widget.currentUserId,
            currentUserRole: widget.currentUserRole,
          ),
        ))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Ações Corretivas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(t),
          Expanded(child: _buildBody(t, filtered)),
        ],
      ),
    );
  }

  Widget _buildFilters(AppTheme t) {
    return Container(
      color: t.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _StatusFilter.values.map((f) {
                final selected = _statusFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? Colors.white : t.textPrimary,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _statusFilter = f;
                      _load();
                    }),
                    selectedColor: AppColors.primary,
                    backgroundColor: t.background,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                        color: selected ? AppColors.primary : t.divider),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          if (_responsibles.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: DropdownButton<String?>(
                value: _responsibleFilter,
                isExpanded: true,
                hint: Text('Responsável',
                    style:
                        TextStyle(fontSize: 13, color: t.textSecondary)),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todos os responsáveis',
                        style:
                            TextStyle(fontSize: 13, color: t.textPrimary)),
                  ),
                  ..._responsibles.map((e) => DropdownMenuItem<String?>(
                        value: e.key,
                        child: Text(e.value,
                            style: TextStyle(
                                fontSize: 13, color: t.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (val) =>
                    setState(() => _responsibleFilter = val),
                underline: const SizedBox.shrink(),
                style: TextStyle(color: t.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(AppTheme t, List<CorrectiveAction> actions) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: t.textSecondary),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar ações',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Verifique sua conexão e tente novamente.',
                style: TextStyle(fontSize: 14, color: t.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
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

    if (actions.isEmpty) {
      final hasFilter =
          _statusFilter != _StatusFilter.todas || _responsibleFilter != null;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_late_outlined,
                  size: 56, color: t.textSecondary),
              const SizedBox(height: 16),
              Text(
                hasFilter
                    ? 'Nenhuma ação encontrada'
                    : 'Nenhuma ação corretiva',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                hasFilter
                    ? 'Tente ajustar os filtros de status ou responsável.'
                    : 'Crie uma ação a partir de uma pergunta não conforme durante a execução de uma auditoria.',
                style: TextStyle(fontSize: 14, color: t.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: actions.length,
        itemBuilder: (_, i) => _ActionCard(
          action: actions[i],
          theme: t,
          onTap: () => _openDetail(actions[i]),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final CorrectiveAction action;
  final AppTheme theme;
  final VoidCallback onTap;

  const _ActionCard({
    required this.action,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final overdue = action.isOverdue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: overdue
                ? AppColors.error.withValues(alpha: 0.4)
                : t.divider,
            width: overdue ? 1.5 : 1.0,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        action.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CorrectiveActionStatusChip(status: action.status),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 14, color: t.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        action.responsibleName ?? action.responsibleUserId,
                        style:
                            TextStyle(fontSize: 12, color: t.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: overdue ? AppColors.error : t.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${action.dueDate.day}/${action.dueDate.month}/${action.dueDate.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: overdue ? AppColors.error : t.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (action.linkedAuditTitle != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.assignment_outlined,
                          size: 14, color: t.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          action.linkedAuditTitle!,
                          style: TextStyle(
                              fontSize: 12, color: t.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de status CAPA — reutilizável na tela de detalhe (Wave 4).
class CorrectiveActionStatusChip extends StatelessWidget {
  final CorrectiveActionStatus status;

  const CorrectiveActionStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: status.chipText,
        ),
      ),
      backgroundColor: status.chipBackground,
      avatar: Icon(status.icon, size: 14, color: status.chipText),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      side: BorderSide.none,
    );
  }
}
