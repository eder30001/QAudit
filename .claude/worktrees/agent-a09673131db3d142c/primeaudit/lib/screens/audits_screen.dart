import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import 'audit_execution_screen.dart';
import '../models/audit.dart';
import '../models/audit_template.dart';
import '../models/audit_type.dart';
import '../models/perimeter.dart';
import '../services/audit_service.dart';
import '../services/audit_template_service.dart';
import '../services/company_context_service.dart';
import '../services/perimeter_service.dart';

// ---------------------------------------------------------------------------
// Geração de ID de auditoria (usado na criação e na duplicação)
// Formato: SIGLA-YYYYMMDD-HHMM-INICIAIS  ex: EHS-20260406-1929-EM
// ---------------------------------------------------------------------------
String _auditTypePrefix(String typeName) {
  final inParens = RegExp(r'\(([^)]+)\)').firstMatch(typeName);
  if (inParens != null) return inParens.group(1)!.toUpperCase();
  final clean = typeName.replaceAll(RegExp(r'\s+'), '');
  if (clean.length <= 5) return clean.toUpperCase();
  return typeName
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase())
      .join();
}

String _buildAuditId(String typeName, String userName) {
  final now = DateTime.now();
  final prefix = _auditTypePrefix(typeName);
  final date = '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
  final time = '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}';
  final initials = userName
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(3)
      .map((w) => w[0].toUpperCase())
      .join();
  return '$prefix-$date-$time-$initials';
}

// ---------------------------------------------------------------------------
// Filtros rápidos
// ---------------------------------------------------------------------------
enum _AuditFilter { todas, emAndamento, concluidas, atrasadas, minhas }

extension _AuditFilterLabel on _AuditFilter {
  String get label {
    switch (this) {
      case _AuditFilter.todas:       return 'Todas';
      case _AuditFilter.emAndamento: return 'Em andamento';
      case _AuditFilter.concluidas:  return 'Concluídas';
      case _AuditFilter.atrasadas:   return 'Atrasadas';
      case _AuditFilter.minhas:      return 'Minhas';
    }
  }
}

// ---------------------------------------------------------------------------
// Tela principal
// ---------------------------------------------------------------------------
class AuditsScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const AuditsScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<AuditsScreen> createState() => _AuditsScreenState();
}

class _AuditsScreenState extends State<AuditsScreen> {
  final _auditService = AuditService();

  List<Audit> _audits = [];
  bool _isLoading = true;
  String? _error;

  _AuditFilter _filter = _AuditFilter.todas;
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
      final data = await _auditService.getAudits(companyId: companyId);
      if (mounted) setState(() => _audits = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao carregar auditorias.\n$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Audit> get _filtered {
    var list = _audits.where((a) {
      switch (_filter) {
        case _AuditFilter.todas:       return true;
        case _AuditFilter.emAndamento: return a.status == AuditStatus.emAndamento;
        case _AuditFilter.concluidas:  return a.status == AuditStatus.concluida;
        case _AuditFilter.atrasadas:   return a.isOverdue;
        case _AuditFilter.minhas:      return a.auditorId == widget.currentUserId;
      }
    }).toList();

    if (_searchQuery.isNotEmpty) {
      list = list.where((a) =>
        a.title.toLowerCase().contains(_searchQuery) ||
        a.auditTypeName.toLowerCase().contains(_searchQuery) ||
        a.templateName.toLowerCase().contains(_searchQuery) ||
        a.perimeterName?.toLowerCase().contains(_searchQuery) == true ||
        a.companyName.toLowerCase().contains(_searchQuery),
      ).toList();
    }

    return list;
  }

  void _openNewAuditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewAuditSheet(
        companyId: CompanyContextService.instance.activeCompanyId,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
        onAuditCreated: (audit) {
          _load();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AuditExecutionScreen(audit: audit),
          )).then((_) => _load());
        },
      ),
    );
  }

  Future<void> _handleAction(String action, Audit audit) async {
    switch (action) {
      case 'abrir':
      case 'continuar':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AuditExecutionScreen(audit: audit),
        )).then((_) => _load());
        break;
      case 'duplicar':
        await _duplicar(audit);
        break;
      case 'encerrar':
        await _confirmEncerrar(audit);
        break;
    }
  }

  Future<void> _duplicar(Audit audit) async {
    try {
      final newTitle = _buildAuditId(audit.auditTypeName, widget.currentUserName);
      await _auditService.duplicateAudit(audit.id, newTitle: newTitle);
      _snack('Auditoria duplicada com sucesso');
      _load();
    } catch (e) {
      _snack('Erro ao duplicar: $e');
    }
  }

  Future<void> _confirmEncerrar(Audit audit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar auditoria'),
        content: Text('Deseja encerrar "${audit.title}"?\nEssa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        if (audit.status == AuditStatus.rascunho) {
          await _auditService.deleteAudit(audit.id);
          _snack('"${audit.title}" descartada');
        } else {
          await _auditService.closeAudit(audit.id);
          _snack('"${audit.title}" encerrada');
        }
        _load();
      } catch (e) {
        _snack('Erro ao encerrar: $e');
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
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
        title: const Text('Auditorias',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewAuditSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova auditoria',
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
              hintText: 'Buscar por nome, tipo, template ou perímetro…',
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
              children: _AuditFilter.values.map((f) {
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
                    side: BorderSide(
                        color: selected ? AppColors.primary : t.divider),
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

  Widget _buildBody(AppTheme t, List<Audit> audits) {
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
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
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

    if (audits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 56, color: t.textSecondary),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty || _filter != _AuditFilter.todas
                    ? 'Nenhuma auditoria encontrada'
                    : 'Nenhuma auditoria ainda',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: t.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty || _filter != _AuditFilter.todas
                    ? 'Tente ajustar os filtros ou a busca.'
                    : 'Crie a primeira auditoria para começar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSecondary, fontSize: 13),
              ),
              if (_filter == _AuditFilter.todas && _searchQuery.isEmpty) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _openNewAuditSheet,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nova auditoria'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
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
        itemCount: audits.length,
        itemBuilder: (_, i) => _AuditCard(
          audit: audits[i],
          onAction: _handleAction,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card de auditoria
// ---------------------------------------------------------------------------
class _AuditCard extends StatelessWidget {
  final Audit audit;
  final Future<void> Function(String action, Audit audit) onAction;

  const _AuditCard({required this.audit, required this.onAction});

  Color get _typeColor {
    try {
      final hex = audit.auditTypeColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final typeColor = _typeColor;
    final status = audit.status;
    final overdue = audit.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: overdue ? AppColors.error.withValues(alpha: 0.4) : t.divider,
          width: overdue ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onAction('abrir', audit),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha 1: ícone + título + menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (overdue)
                    Container(
                      width: 4, height: 44,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(audit.auditTypeIcon,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          audit.title,
                          style: TextStyle(fontWeight: FontWeight.w600,
                              fontSize: 14, color: t.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6, runSpacing: 4,
                          children: [
                            _Tag(label: audit.auditTypeName, color: typeColor),
                            _Tag(label: audit.templateName,
                                color: t.textSecondary, outlined: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded,
                        color: t.textSecondary, size: 20),
                    onSelected: (v) => onAction(v, audit),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'abrir',
                          child: _PopupItem(icon: Icons.open_in_new_rounded,
                              label: 'Abrir')),
                      if (audit.status == AuditStatus.emAndamento ||
                          audit.status == AuditStatus.rascunho)
                        const PopupMenuItem(value: 'continuar',
                            child: _PopupItem(icon: Icons.play_arrow_rounded,
                                label: 'Continuar')),
                      const PopupMenuItem(value: 'duplicar',
                          child: _PopupItem(icon: Icons.copy_rounded,
                              label: 'Duplicar')),
                      if (audit.status != AuditStatus.concluida &&
                          audit.status != AuditStatus.cancelada)
                        const PopupMenuItem(value: 'encerrar',
                            child: _PopupItem(
                                icon: Icons.stop_circle_outlined,
                                label: 'Encerrar',
                                destructive: true)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Divider(height: 1, color: t.divider),
              const SizedBox(height: 10),

              // Linha 2: empresa, perímetro, auditor, prazo
              _InfoGrid(audit: audit, theme: t),

              const SizedBox(height: 10),

              // Linha 3: status + conformidade
              Row(
                children: [
                  _StatusBadge(status: status),
                  const Spacer(),
                  if (audit.conformityPercent != null)
                    _ConformityBar(percent: audit.conformityPercent!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets do card
// ---------------------------------------------------------------------------
class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;

  const _Tag({required this.label, required this.color, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: outlined ? Border.all(color: color.withValues(alpha: 0.4)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final Audit audit;
  final AppTheme theme;

  const _InfoGrid({required this.audit, required this.theme});

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final deadlineStr = audit.deadline != null ? _fmtDate(audit.deadline!) : '—';
    final deadlineColor = audit.isOverdue ? AppColors.error : t.textSecondary;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(icon: Icons.business_rounded,
                  text: audit.companyName, color: t.textSecondary),
              const SizedBox(height: 4),
              _InfoRow(icon: Icons.place_rounded,
                  text: audit.perimeterName ?? 'Sem perímetro',
                  color: audit.perimeterName != null
                      ? t.textSecondary
                      : t.textSecondary.withValues(alpha: 0.5)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(icon: Icons.person_outline_rounded,
                  text: audit.auditorName, color: t.textSecondary),
              const SizedBox(height: 4),
              _InfoRow(icon: Icons.event_rounded,
                  text: 'Prazo: $deadlineStr',
                  color: deadlineColor, bold: audit.isOverdue),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool bold;

  const _InfoRow({
    required this.icon, required this.text,
    required this.color, this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
            style: TextStyle(fontSize: 11, color: color,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AuditStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 5),
          Text(status.label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: status.color)),
        ],
      ),
    );
  }
}

class _ConformityBar extends StatelessWidget {
  final double percent;
  const _ConformityBar({required this.percent});

  Color get _barColor {
    if (percent >= 80) return const Color(0xFF43A047);
    if (percent >= 60) return const Color(0xFFFFA000);
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${percent.toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: _barColor)),
        const SizedBox(width: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 60, height: 6,
            child: Stack(
              children: [
                Container(color: t.divider),
                FractionallySizedBox(
                  widthFactor: percent / 100,
                  child: Container(color: _barColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PopupItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;

  const _PopupItem({
    required this.icon, required this.label, this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : null;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet — Nova auditoria (fluxo multi-passo com dados reais)
// ---------------------------------------------------------------------------
class _NewAuditSheet extends StatefulWidget {
  final String? companyId;
  final String currentUserId;
  final String currentUserName;
  final void Function(Audit audit) onAuditCreated;

  const _NewAuditSheet({
    required this.companyId,
    required this.currentUserId,
    required this.currentUserName,
    required this.onAuditCreated,
  });

  @override
  State<_NewAuditSheet> createState() => _NewAuditSheetState();
}

class _NewAuditSheetState extends State<_NewAuditSheet> {
  // Dados carregados do banco
  List<AuditType> _types = [];
  List<AuditTemplate> _templates = [];
  List<Perimeter> _perimeterRoots = [];
  bool _loadingData = true;

  // Seleções do usuário
  AuditType? _selectedType;
  AuditTemplate? _selectedTemplate;
  Perimeter? _selectedPerimeter;
  DateTime? _deadline;

  int _step = 0;
  bool _loadingTemplates = false;
  bool _submitting = false;

  static const _totalSteps = 4;

  final _templateService = AuditTemplateService();
  final _perimeterService = PerimeterService();
  final _auditService = AuditService();

  @override
  void initState() {
    super.initState();
    _loadSheetData();
  }


  Future<void> _loadSheetData() async {
    try {
      final companyId = widget.companyId;
      final results = await Future.wait([
        _templateService.getTypes(companyId: companyId),
        companyId != null
            ? _perimeterService.getByCompany(companyId)
            : Future.value(<Perimeter>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _types = results[0] as List<AuditType>;
        final flatPerimeters = (results[1] as List<Perimeter>)
            .where((p) => p.active)
            .toList();
        _perimeterRoots = Perimeter.buildTree(flatPerimeters);
        _loadingData = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _loadTemplates(String typeId) async {
    setState(() { _loadingTemplates = true; _templates = []; _selectedTemplate = null; });
    try {
      final data = await _templateService.getTemplates(
        typeId: typeId,
        companyId: widget.companyId,
      );
      if (mounted) setState(() => _templates = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingTemplates = false);
    }
  }

  bool get _canAdvance {
    switch (_step) {
      case 0: return _selectedType != null;
      case 1: return _selectedTemplate != null;
      case 2: return true; // perímetro é opcional
      case 3: return true; // prazo é opcional
      default: return false;
    }
  }

  String get _stepTitle {
    switch (_step) {
      case 0: return 'Tipo de auditoria';
      case 1: return 'Template';
      case 2: return 'Perímetro';
      case 3: return 'Prazo';
      default: return '';
    }
  }

  Future<void> _submit() async {
    final companyId = widget.companyId;
    if (companyId == null) {
      _snack('Selecione uma empresa ativa antes de criar uma auditoria.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final audit = await _auditService.createAudit(
        title: _buildAuditId(_selectedType!.name, widget.currentUserName),
        auditTypeId: _selectedType!.id,
        templateId: _selectedTemplate!.id,
        companyId: companyId,
        perimeterId: _selectedPerimeter?.id,
        auditorId: widget.currentUserId,
        deadline: _deadline,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onAuditCreated(audit);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack('Erro ao criar auditoria: $e');
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final viewInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, viewInset + 24),
      child: _loadingData
          ? const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: t.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cabeçalho
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nova auditoria',
                              style: TextStyle(fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            'Passo ${_step + 1} de $_totalSteps — $_stepTitle',
                            style: TextStyle(fontSize: 12, color: t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (_step > 0)
                      TextButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Voltar'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Barra de progresso
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _totalSteps,
                    backgroundColor: t.divider,
                    color: AppColors.primary,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 20),

                // Conteúdo do passo
                _buildStepContent(t),

                const SizedBox(height: 20),

                // Botão de ação
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: _canAdvance && !_submitting
                        ? () {
                            if (_step < _totalSteps - 1) {
                              setState(() => _step++);
                            } else {
                              _submit();
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: t.divider,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            _step < _totalSteps - 1
                                ? 'Próximo'
                                : 'Iniciar auditoria',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStepContent(AppTheme t) {
    switch (_step) {
      case 0:
        return _types.isEmpty
            ? _emptyStep('Nenhum tipo de auditoria disponível.', t)
            : _SelectionStep<AuditType>(
                options: _types,
                selected: _selectedType,
                labelOf: (t) => '${t.icon}  ${t.name}',
                iconOf: (_) => Icons.category_rounded,
                onSelect: (v) {
                  setState(() { _selectedType = v; });
                  _loadTemplates(v.id);
                },
                theme: t,
              );

      case 1:
        if (_loadingTemplates) {
          return const SizedBox(
            height: 80,
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        return _templates.isEmpty
            ? _emptyStep(
                'Nenhum template disponível para "${_selectedType?.name}".\n'
                'Cadastre um template antes de criar a auditoria.', t)
            : _SelectionStep<AuditTemplate>(
                options: _templates,
                selected: _selectedTemplate,
                labelOf: (t) => t.name,
                iconOf: (_) => Icons.assignment_outlined,
                onSelect: (v) => setState(() => _selectedTemplate = v),
                theme: t,
              );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selecione um perímetro (opcional)',
                style: TextStyle(fontSize: 13, color: t.textSecondary)),
            const SizedBox(height: 10),
            _perimeterRoots.isEmpty
                ? _emptyStep('Nenhum perímetro cadastrado para esta empresa.', t)
                : _PerimeterTreeStep(
                    roots: _perimeterRoots,
                    selected: _selectedPerimeter,
                    onSelect: (v) => setState(() => _selectedPerimeter = v),
                    theme: t,
                  ),
          ],
        );

      case 3:
        return _DeadlineStep(
          deadline: _deadline,
          onChanged: (d) => setState(() => _deadline = d),
          theme: t,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _emptyStep(String msg, AppTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(msg,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textSecondary, fontSize: 13)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget genérico de seleção por lista
// ---------------------------------------------------------------------------
class _SelectionStep<T> extends StatelessWidget {
  final List<T> options;
  final T? selected;
  final String Function(T) labelOf;
  final IconData Function(T) iconOf;
  final void Function(T) onSelect;
  final AppTheme theme;

  const _SelectionStep({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.iconOf,
    required this.onSelect,
    required this.theme,
  });

  bool _isSelected(T opt) {
    if (selected == null) return false;
    // Comparação por identidade de objeto — funciona para os modelos usados
    return identical(selected, opt) || selected == opt;
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Column(
      children: options.map((opt) {
        final sel = _isSelected(opt);
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: sel
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : t.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: sel ? AppColors.primary : t.divider,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(iconOf(opt), size: 18,
                    color: sel ? AppColors.primary : t.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(labelOf(opt),
                    style: TextStyle(fontSize: 14,
                        fontWeight:
                            sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? AppColors.primary : t.textPrimary),
                  ),
                ),
                if (sel)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Seleção de perímetro em árvore hierárquica
// ---------------------------------------------------------------------------
class _PerimeterTreeStep extends StatefulWidget {
  final List<Perimeter> roots;
  final Perimeter? selected;
  final void Function(Perimeter?) onSelect;
  final AppTheme theme;

  const _PerimeterTreeStep({
    required this.roots,
    required this.selected,
    required this.onSelect,
    required this.theme,
  });

  @override
  State<_PerimeterTreeStep> createState() => _PerimeterTreeStepState();
}

class _PerimeterTreeStepState extends State<_PerimeterTreeStep> {
  // Pilha de navegação: cada item é um nó que foi "aberto"
  final List<Perimeter> _breadcrumb = [];

  List<Perimeter> get _currentLevel =>
      _breadcrumb.isEmpty ? widget.roots : _breadcrumb.last.children;

  void _drillInto(Perimeter p) => setState(() => _breadcrumb.add(p));

  void _navigateTo(int index) => setState(() {
        if (index < 0) {
          _breadcrumb.clear();
        } else {
          _breadcrumb.removeRange(index + 1, _breadcrumb.length);
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb de navegação
        if (_breadcrumb.isNotEmpty) _buildBreadcrumb(t),
        // Opção "Sem perímetro" aparece sempre no nível raiz
        if (_breadcrumb.isEmpty)
          _PerimeterTile(
            name: 'Sem perímetro',
            subtitle: null,
            isSelected: widget.selected == null,
            hasChildren: false,
            onSelect: () => widget.onSelect(null),
            onDrillIn: null,
            icon: Icons.not_listed_location_outlined,
            theme: t,
          ),
        // Nós do nível atual
        ..._currentLevel.map((p) {
          final isSelected = widget.selected?.id == p.id;
          final hasChildren = p.children.isNotEmpty;
          return _PerimeterTile(
            name: p.name,
            subtitle: hasChildren
                ? '${p.children.length} sub-área${p.children.length > 1 ? 's' : ''}'
                : null,
            isSelected: isSelected,
            hasChildren: hasChildren,
            onSelect: () => widget.onSelect(isSelected ? null : p),
            onDrillIn: hasChildren ? () => _drillInto(p) : null,
            icon: Icons.place_rounded,
            theme: t,
          );
        }),
      ],
    );
  }

  Widget _buildBreadcrumb(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            InkWell(
              onTap: () => _navigateTo(-1),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text('Todos',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ),
            ..._breadcrumb.asMap().entries.map((e) => Row(
                  children: [
                    Icon(Icons.chevron_right, size: 14, color: t.textSecondary),
                    InkWell(
                      onTap: () => _navigateTo(e.key),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Text(
                          e.value.name,
                          style: TextStyle(
                            color: e.key == _breadcrumb.length - 1
                                ? t.textPrimary
                                : AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}

class _PerimeterTile extends StatelessWidget {
  final String name;
  final String? subtitle;
  final bool isSelected;
  final bool hasChildren;
  final VoidCallback onSelect;
  final VoidCallback? onDrillIn;
  final IconData icon;
  final AppTheme theme;

  const _PerimeterTile({
    required this.name,
    required this.subtitle,
    required this.isSelected,
    required this.hasChildren,
    required this.onSelect,
    required this.onDrillIn,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : t.background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : t.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: isSelected ? AppColors.primary : t.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color:
                                isSelected ? AppColors.primary : t.textPrimary,
                          )),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: TextStyle(
                                fontSize: 11, color: t.textSecondary)),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 18),
                if (hasChildren)
                  IconButton(
                    icon: Icon(Icons.chevron_right,
                        color: t.textSecondary, size: 20),
                    onPressed: onDrillIn,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    tooltip: 'Ver sub-áreas',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seleção de prazo
// ---------------------------------------------------------------------------
class _DeadlineStep extends StatelessWidget {
  final DateTime? deadline;
  final void Function(DateTime?) onChanged;
  final AppTheme theme;

  const _DeadlineStep({
    required this.deadline,
    required this.onChanged,
    required this.theme,
  });

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: 'Selecionar prazo',
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
    );
    if (picked != null) onChanged(picked);
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Defina um prazo para a auditoria (opcional)',
            style: TextStyle(fontSize: 13, color: t.textSecondary)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _pickDate(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: t.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: deadline != null ? AppColors.primary : t.divider,
                width: deadline != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.event_rounded,
                    color: deadline != null
                        ? AppColors.primary
                        : t.textSecondary,
                    size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    deadline != null
                        ? _fmtDate(deadline!)
                        : 'Selecionar data de prazo',
                    style: TextStyle(
                      fontSize: 14,
                      color: deadline != null ? t.textPrimary : t.textSecondary,
                      fontWeight: deadline != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (deadline != null)
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: t.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sem prazo definido, a auditoria ficará em aberto indefinidamente.',
          style: TextStyle(fontSize: 11, color: t.textSecondary),
        ),
      ],
    );
  }
}
