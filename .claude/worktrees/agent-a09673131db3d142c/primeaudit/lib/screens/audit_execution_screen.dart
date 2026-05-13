import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/audit.dart';
import '../models/audit_template.dart';
import '../services/audit_answer_service.dart';
import '../services/audit_service.dart';
import '../services/audit_template_service.dart';

class AuditExecutionScreen extends StatefulWidget {
  final Audit audit;

  const AuditExecutionScreen({super.key, required this.audit});

  @override
  State<AuditExecutionScreen> createState() => _AuditExecutionScreenState();
}

class _AuditExecutionScreenState extends State<AuditExecutionScreen> {
  final _templateService = AuditTemplateService();
  final _answerService = AuditAnswerService();
  final _auditService = AuditService();

  List<TemplateSection> _sections = [];   // seções com items populados
  List<TemplateItem> _allItems = [];      // todos os items para cálculos

  // itemId → resposta | itemId → observação
  final Map<String, String> _answers = {};
  final Map<String, String> _observations = {};

  bool _loading = true;
  bool _finalizing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final templateId = widget.audit.templateId;

      // Carrega seções, items e respostas em paralelo
      final results = await Future.wait([
        _templateService.getSections(templateId),
        _templateService.getItems(templateId),
        _answerService.getAnswers(widget.audit.id),
      ]);

      final sections = results[0] as List<TemplateSection>;
      final items    = results[1] as List<TemplateItem>;
      final answers  = results[2] as List;

      // Associa items às seções
      final itemsBySection = <String?, List<TemplateItem>>{};
      for (final item in items) {
        itemsBySection.putIfAbsent(item.sectionId, () => []).add(item);
      }
      for (final s in sections) {
        s.items = itemsBySection[s.id] ?? [];
      }

      // Items sem seção ficam numa seção fictícia "Geral"
      final unsectioned = itemsBySection[null] ?? [];

      // Popula respostas existentes
      for (final a in answers) {
        final ans = a as dynamic;
        _answers[ans.templateItemId] = ans.response;
        if (ans.observation != null) {
          _observations[ans.templateItemId] = ans.observation!;
        }
      }

      if (mounted) {
        setState(() {
          _sections = sections;
          _allItems = [...items];
          // Adiciona seção fictícia se houver itens sem seção
          if (unsectioned.isNotEmpty) {
            _sections.insert(0, TemplateSection(
              id: '__unsectioned__',
              templateId: templateId,
              name: 'Geral',
              orderIndex: -1,
              items: unsectioned,
            ));
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  // ── Progresso ────────────────────────────────────────────────────────────

  int get _totalRequired =>
      _allItems.where((i) => i.required).length;

  int get _answeredRequired =>
      _allItems.where((i) => i.required && _answers.containsKey(i.id)).length;

  int get _totalItems => _allItems.length;

  int get _answeredItems =>
      _allItems.where((i) => _answers.containsKey(i.id)).length;

  bool get _canFinalize => _answeredRequired == _totalRequired;

  bool get _isReadOnly =>
      widget.audit.status == AuditStatus.concluida ||
      widget.audit.status == AuditStatus.cancelada;

  double get _conformity =>
      _answerService.calculateConformity(_allItems, _answers);

  // ── Responder (bloqueado em modo leitura) ─────────────────────────────────

  void _onAnswer(String itemId, String response) {
    if (_isReadOnly) return;
    setState(() => _answers[itemId] = response);
    _saveAnswer(itemId, response);
  }

  void _onObservation(String itemId, String obs) {
    if (_isReadOnly) return;
    _observations[itemId] = obs;
    final resp = _answers[itemId];
    if (resp != null) _saveAnswer(itemId, resp, observation: obs);
  }

  // ── Cancelar ─────────────────────────────────────────────────────────────

  Future<void> _discardAndExit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar e não salvar'),
        content: const Text(
            'Esta auditoria será excluída permanentemente.\n'
            'Todas as respostas serão perdidas e a ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir auditoria'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _auditService.deleteAudit(widget.audit.id);
      if (mounted) Navigator.of(context).pop(false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao excluir auditoria: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _cancelAudit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar auditoria'),
        content: const Text(
            'Esta ação não pode ser desfeita.\n'
            'A auditoria será marcada como cancelada e não poderá ser editada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Confirmar cancelamento'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _finalizing = true);
    try {
      if (widget.audit.status == AuditStatus.rascunho) {
        await _auditService.deleteAudit(widget.audit.id);
      } else {
        await _auditService.closeAudit(widget.audit.id);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _finalizing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao cancelar: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _saveAnswer(String itemId, String response,
      {String? observation}) async {
    try {
      await _answerService.upsertAnswer(
        auditId: widget.audit.id,
        templateItemId: itemId,
        response: response,
        observation: observation ?? _observations[itemId],
      );
    } catch (_) {
      // Falha silenciosa — pode tentar novamente ao finalizar
    }
  }

  // ── Finalizar ────────────────────────────────────────────────────────────

  Future<void> _finalize() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar auditoria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_answeredItems de $_totalItems itens respondidos.'),
            const SizedBox(height: 8),
            Text(
              'Conformidade: ${_conformity.toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (!_canFinalize) ...[
              const SizedBox(height: 8),
              Text(
                '${_totalRequired - _answeredRequired} item(ns) obrigatório(s) sem resposta.',
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: _canFinalize ? () => Navigator.pop(ctx, true) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _finalizing = true);

    try {
      await _auditService.finalizeAudit(
        id: widget.audit.id,
        conformityPercent: _conformity,
      );
      if (mounted) {
        Navigator.of(context).pop(true); // retorna true = concluída
      }
    } catch (e) {
      if (mounted) {
        setState(() => _finalizing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao finalizar: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);

    return Scaffold(
      backgroundColor: t.background,
      appBar: _buildAppBar(t),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError(t)
              : _buildBody(t),
      bottomNavigationBar: (!_loading && _error == null)
          ? _buildBottomBar(t)
          : null,
    );
  }

  AppBar _buildAppBar(AppTheme t) {
    final answered = _answeredItems;
    final total = _totalItems;
    final pct = total > 0 ? answered / total : 0.0;

    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.audit.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(
            '${widget.audit.auditTypeIcon}  ${widget.audit.auditTypeName}  •  ${widget.audit.templateName}',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
      actions: _isReadOnly
          ? null
          : [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'discard') _discardAndExit();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'discard',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Cancelar e não salvar',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$answered/$total',
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(AppTheme t) {
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

  Widget _buildBody(AppTheme t) {
    if (_allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: t.textSecondary),
            const SizedBox(height: 12),
            Text('Este template não possui itens cadastrados.',
                style: TextStyle(color: t.textSecondary)),
          ],
        ),
      );
    }

    // Numera os itens globalmente
    int globalIndex = 0;
    final indexMap = <String, int>{};
    for (final s in _sections) {
      for (final item in s.items) {
        indexMap[item.id] = ++globalIndex;
      }
    }

    return Column(
      children: [
        // Banner de somente leitura
        if (_isReadOnly)
          _ReadOnlyBanner(status: widget.audit.status, theme: t),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _sections.length,
              itemBuilder: (_, i) => _SectionBlock(
                section: _sections[i],
                answers: _answers,
                observations: _observations,
                indexMap: indexMap,
                readOnly: _isReadOnly,
                onAnswer: _onAnswer,
                onObservation: _onObservation,
                theme: t,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(AppTheme t) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 12;

    // Auditoria cancelada: apenas informa
    if (widget.audit.status == AuditStatus.cancelada) {
      return Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(top: BorderSide(color: t.divider)),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_rounded, color: t.textSecondary, size: 18),
            const SizedBox(width: 8),
            Text('Auditoria cancelada — somente leitura',
                style: TextStyle(color: t.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    // Auditoria concluída: apenas cancelar
    if (widget.audit.status == AuditStatus.concluida) {
      return Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(top: BorderSide(color: t.divider)),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
        child: Row(
          children: [
            // Conformidade final
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conformidade final',
                    style: TextStyle(fontSize: 11, color: t.textSecondary)),
                Text(
                  '${_conformity.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _conformityColor(_conformity),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: !_finalizing ? _cancelAudit : null,
                icon: _finalizing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.error))
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancelar auditoria'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Em andamento / rascunho / atrasada: finalizar
    final unanswered = _totalRequired - _answeredRequired;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.divider)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
      child: Row(
        children: [
          // Conformidade atual
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conformidade',
                  style: TextStyle(fontSize: 11, color: t.textSecondary)),
              Text(
                '${_conformity.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _conformityColor(_conformity),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _canFinalize && !_finalizing ? _finalize : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: t.divider,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _finalizing
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      unanswered > 0
                          ? 'Finalizar ($unanswered obrig. pendente${unanswered > 1 ? 's' : ''})'
                          : 'Finalizar auditoria',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _conformityColor(double pct) {
    if (pct >= 80) return const Color(0xFF43A047);
    if (pct >= 60) return const Color(0xFFFFA000);
    return AppColors.error;
  }
}

// ---------------------------------------------------------------------------
// Bloco de seção
// ---------------------------------------------------------------------------
// Banner de somente leitura
// ---------------------------------------------------------------------------
class _ReadOnlyBanner extends StatelessWidget {
  final AuditStatus status;
  final AppTheme theme;

  const _ReadOnlyBanner({required this.status, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isCancelled = status == AuditStatus.cancelada;
    final color = isCancelled ? AppColors.error : const Color(0xFF43A047);
    final icon = isCancelled ? Icons.cancel_rounded : Icons.verified_rounded;
    final label = isCancelled
        ? 'Auditoria cancelada — somente leitura'
        : 'Auditoria concluída — somente leitura';

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _SectionBlock extends StatelessWidget {
  final TemplateSection section;
  final Map<String, String> answers;
  final Map<String, String> observations;
  final Map<String, int> indexMap;
  final bool readOnly;
  final void Function(String itemId, String response) onAnswer;
  final void Function(String itemId, String obs) onObservation;
  final AppTheme theme;

  const _SectionBlock({
    required this.section,
    required this.answers,
    required this.observations,
    required this.indexMap,
    required this.readOnly,
    required this.onAnswer,
    required this.onObservation,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da seção
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                '${section.items.length} ite${section.items.length == 1 ? 'm' : 'ns'}',
                style: TextStyle(fontSize: 11, color: t.textSecondary),
              ),
            ],
          ),
        ),

        // Itens da seção
        ...section.items.map((item) => _ItemCard(
          item: item,
          index: indexMap[item.id] ?? 0,
          answer: answers[item.id],
          observation: observations[item.id],
          readOnly: readOnly,
          onAnswer: (r) => onAnswer(item.id, r),
          onObservation: (o) => onObservation(item.id, o),
          theme: t,
        )),

        const SizedBox(height: 4),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Card de item/pergunta
// ---------------------------------------------------------------------------
class _ItemCard extends StatefulWidget {
  final TemplateItem item;
  final int index;
  final String? answer;
  final String? observation;
  final bool readOnly;
  final void Function(String) onAnswer;
  final void Function(String) onObservation;
  final AppTheme theme;

  const _ItemCard({
    required this.item,
    required this.index,
    required this.answer,
    required this.observation,
    required this.readOnly,
    required this.onAnswer,
    required this.onObservation,
    required this.theme,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _showObs = false;
  late final TextEditingController _obsCtrl;

  @override
  void initState() {
    super.initState();
    _obsCtrl = TextEditingController(text: widget.observation ?? '');
    _showObs = (widget.observation?.isNotEmpty ?? false);
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  bool get _answered => widget.answer != null && widget.answer!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final item = widget.item;
    final answered = _answered;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: answered
              ? AppColors.primary.withValues(alpha: 0.3)
              : (item.required ? AppColors.error.withValues(alpha: 0.25) : t.divider),
          width: answered ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Número + pergunta + badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Número + indicador de respondido
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: answered
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : t.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: answered ? AppColors.primary : t.divider,
                    ),
                  ),
                  child: Center(
                    child: answered
                        ? const Icon(Icons.check_rounded,
                            size: 15, color: AppColors.primary)
                        : Text('${widget.index}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: t.textSecondary)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.question,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: t.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6, runSpacing: 4,
                        children: [
                          if (item.required)
                            _Badge(label: 'Obrigatório',
                                color: AppColors.error),
                          _Badge(label: item.responseTypeLabel,
                              color: AppColors.accent),
                          if (item.weight > 1)
                            _Badge(label: 'Peso ${item.weight}',
                                color: const Color(0xFF9C27B0)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Orientação (guidance) colapsável
            if (item.guidance != null && item.guidance!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _GuidanceTile(guidance: item.guidance!, theme: t),
            ],

            const SizedBox(height: 12),

            // Widget de resposta
            _AnswerWidget(
              item: item,
              answer: widget.answer,
              readOnly: widget.readOnly,
              onAnswer: widget.onAnswer,
              theme: t,
            ),

            // Observação
            const SizedBox(height: 10),
            GestureDetector(
              onTap: widget.readOnly ? null : () => setState(() => _showObs = !_showObs),
              child: Row(
                children: [
                  Icon(
                    _showObs
                        ? Icons.expand_less_rounded
                        : Icons.add_comment_outlined,
                    size: 16,
                    color: widget.readOnly
                        ? t.textSecondary.withValues(alpha: 0.4)
                        : t.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showObs ? 'Ocultar observação' : 'Ver observação',
                    style: TextStyle(
                        fontSize: 12,
                        color: widget.readOnly
                            ? t.textSecondary.withValues(alpha: 0.4)
                            : t.textSecondary),
                  ),
                ],
              ),
            ),
            if (_showObs) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _obsCtrl,
                maxLines: 2,
                readOnly: widget.readOnly,
                textCapitalization: TextCapitalization.sentences,
                onChanged: widget.readOnly ? null : widget.onObservation,
                decoration: InputDecoration(
                  hintText: 'Observação do auditor…',
                  hintStyle: TextStyle(color: t.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: t.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: t.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: t.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.accent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget de orientação colapsável
// ---------------------------------------------------------------------------
class _GuidanceTile extends StatefulWidget {
  final String guidance;
  final AppTheme theme;
  const _GuidanceTile({required this.guidance, required this.theme});

  @override
  State<_GuidanceTile> createState() => _GuidanceTileState();
}

class _GuidanceTileState extends State<_GuidanceTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _expanded ? widget.guidance : widget.guidance,
                maxLines: _expanded ? null : 1,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, color: t.textSecondary, height: 1.4),
              ),
            ),
            Icon(
              _expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 16, color: t.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget de resposta — switch por tipo
// ---------------------------------------------------------------------------
class _AnswerWidget extends StatelessWidget {
  final TemplateItem item;
  final String? answer;
  final bool readOnly;
  final void Function(String) onAnswer;
  final AppTheme theme;

  const _AnswerWidget({
    required this.item,
    required this.answer,
    required this.readOnly,
    required this.onAnswer,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    switch (item.responseType) {
      case 'ok_nok':
        return _TwoOptionButtons(
          options: const [
            _OptionDef('ok',  'Conforme',     Icons.check_circle_rounded, Color(0xFF43A047)),
            _OptionDef('nok', 'Não conforme', Icons.cancel_rounded,       AppColors.error),
          ],
          selected: answer,
          readOnly: readOnly,
          onSelect: onAnswer,
          theme: theme,
        );

      case 'yes_no':
        return _TwoOptionButtons(
          options: const [
            _OptionDef('yes', 'Sim', Icons.thumb_up_rounded,   Color(0xFF43A047)),
            _OptionDef('no',  'Não', Icons.thumb_down_rounded, AppColors.error),
          ],
          selected: answer,
          readOnly: readOnly,
          onSelect: onAnswer,
          theme: theme,
        );

      case 'scale_1_5':
        return _ScaleButtons(
            selected: answer, readOnly: readOnly,
            onSelect: onAnswer, theme: theme);

      case 'percentage':
        return _PercentageSlider(
            value: double.tryParse(answer ?? '') ?? 0,
            readOnly: readOnly,
            onChanged: (v) => onAnswer(v.toStringAsFixed(0)),
            theme: theme);

      case 'text':
        return _TextAnswer(
            initial: answer, readOnly: readOnly,
            onChanged: onAnswer, theme: theme);

      case 'selection':
        return _SelectionAnswer(
            options: item.options,
            selected: answer,
            readOnly: readOnly,
            onSelect: onAnswer,
            theme: theme);

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Definição de opção (imutável) ──────────────────────────────────────────
class _OptionDef {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _OptionDef(this.value, this.label, this.icon, this.color);
}

// ── Dois botões (ok/nok, yes/no) ───────────────────────────────────────────
class _TwoOptionButtons extends StatelessWidget {
  final List<_OptionDef> options;
  final String? selected;
  final bool readOnly;
  final void Function(String) onSelect;
  final AppTheme theme;

  const _TwoOptionButtons({
    required this.options, required this.selected,
    required this.readOnly, required this.onSelect, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((opt) {
        final sel = selected == opt.value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: readOnly ? null : () => onSelect(opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? opt.color.withValues(alpha: 0.1)
                      : theme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? opt.color : theme.divider,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(opt.icon,
                        color: sel ? opt.color : theme.textSecondary,
                        size: 22),
                    const SizedBox(height: 4),
                    Text(opt.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                          color: sel ? opt.color : theme.textSecondary,
                        )),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Escala 1–5 ────────────────────────────────────────────────────────────
class _ScaleButtons extends StatelessWidget {
  final String? selected;
  final bool readOnly;
  final void Function(String) onSelect;
  final AppTheme theme;

  const _ScaleButtons({
      required this.selected, required this.readOnly,
      required this.onSelect, required this.theme});

  static const _labels = ['Péssimo', 'Ruim', 'Regular', 'Bom', 'Ótimo'];

  Color _colorFor(int n) {
    const colors = [
      AppColors.error,
      Color(0xFFFF7043),
      Color(0xFFFFA000),
      Color(0xFF8BC34A),
      Color(0xFF43A047),
    ];
    return colors[n - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final n = i + 1;
            final sel = selected == '$n';
            final color = _colorFor(n);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
                child: GestureDetector(
                  onTap: readOnly ? null : () => onSelect('$n'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 44,
                    decoration: BoxDecoration(
                      color: sel ? color.withValues(alpha: 0.12) : theme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? color : theme.divider,
                          width: sel ? 2 : 1),
                    ),
                    child: Center(
                      child: Text('$n',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: sel ? color : theme.textSecondary,
                          )),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (selected != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              _labels[(int.parse(selected!) - 1)],
              style: TextStyle(
                  fontSize: 11,
                  color: _colorFor(int.parse(selected!)),
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Percentual (slider) ────────────────────────────────────────────────────
class _PercentageSlider extends StatelessWidget {
  final double value;
  final bool readOnly;
  final void Function(double) onChanged;
  final AppTheme theme;

  const _PercentageSlider({
      required this.value, required this.readOnly,
      required this.onChanged, required this.theme});

  Color get _color {
    if (value >= 80) return const Color(0xFF43A047);
    if (value >= 60) return const Color(0xFFFFA000);
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _color,
              thumbColor: _color,
              inactiveTrackColor: theme.divider,
              overlayColor: _color.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: 0, max: 100, divisions: 100,
              onChanged: readOnly ? null : onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            '${value.toStringAsFixed(0)}%',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _color),
          ),
        ),
      ],
    );
  }
}

// ── Texto livre ───────────────────────────────────────────────────────────
class _TextAnswer extends StatefulWidget {
  final String? initial;
  final bool readOnly;
  final void Function(String) onChanged;
  final AppTheme theme;

  const _TextAnswer({this.initial, required this.readOnly,
      required this.onChanged, required this.theme});

  @override
  State<_TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<_TextAnswer> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return TextField(
      controller: _ctrl,
      maxLines: 3,
      readOnly: widget.readOnly,
      textCapitalization: TextCapitalization.sentences,
      onChanged: widget.readOnly ? null : widget.onChanged,
      decoration: InputDecoration(
        hintText: 'Digite a resposta…',
        hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
        filled: true, fillColor: t.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: t.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: t.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

// ── Seleção de opções ─────────────────────────────────────────────────────
class _SelectionAnswer extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final bool readOnly;
  final void Function(String) onSelect;
  final AppTheme theme;

  const _SelectionAnswer({
    required this.options, required this.selected,
    required this.readOnly, required this.onSelect, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (options.isEmpty) {
      return Text('Nenhuma opção configurada.',
          style: TextStyle(color: t.textSecondary, fontSize: 12));
    }
    return Wrap(
      spacing: 8, runSpacing: 6,
      children: options.map((opt) {
        final sel = selected == opt;
        return GestureDetector(
          onTap: readOnly ? null : () => onSelect(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : t.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel ? AppColors.primary : t.divider,
                  width: sel ? 1.5 : 1),
            ),
            child: Text(opt,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  color: sel ? AppColors.primary : t.textPrimary,
                )),
          ),
        );
      }).toList(),
    );
  }
}

// ── Badge pequeno ─────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
