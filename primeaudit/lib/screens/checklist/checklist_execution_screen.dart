import 'dart:io';
import 'dart:math' show pow;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/checklist_execution.dart';
import '../../models/checklist_item_image.dart';
import '../../models/checklist_template.dart';
import '../../services/checklist_answer_service.dart';
import '../../services/checklist_execution_service.dart';
import '../../services/checklist_image_service.dart';
import '../../services/checklist_template_service.dart';
import '../../services/company_context_service.dart';
import 'checklist_pending_save.dart';

// Alias interno: _PendingSave dentro deste arquivo mapeia para ChecklistPendingSave
// (convenção do projeto — mesma estrutura de audit_execution_screen.dart).
typedef _PendingSave = ChecklistPendingSave;

// ---------------------------------------------------------------------------
// Tela principal de execução de checklist
// ---------------------------------------------------------------------------
class ChecklistExecutionScreen extends StatefulWidget {
  final ChecklistExecution execution;

  const ChecklistExecutionScreen({super.key, required this.execution});

  @override
  State<ChecklistExecutionScreen> createState() =>
      _ChecklistExecutionScreenState();
}

class _ChecklistExecutionScreenState extends State<ChecklistExecutionScreen> {
  static const int _maxAutoRetryAttempts = 4;

  final _templateService = ChecklistTemplateService();
  final _answerService = ChecklistAnswerService();
  final _executionService = ChecklistExecutionService();
  // Phase 15: fotos por item
  final _imageService = ChecklistImageService();
  final Map<String, List<_ChecklistPhotoEntry>> _photosPerItem = {};

  List<ChecklistTemplateItem> _allItems = [];

  // itemId → resposta | itemId → observação
  final Map<String, String> _answers = {};
  final Map<String, String> _observations = {};

  // Fila de retry: itemId → dados do save com falha
  final Map<String, _PendingSave> _failedSaves = {};

  // Controle de retry em andamento por item (evita loops duplos)
  final Set<String> _retrying = {};

  bool _loading = true;
  bool _finalizing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Carga inicial ─────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final templateId = widget.execution.templateId;

      // Carrega itens, respostas e fotos em paralelo
      final results = await Future.wait([
        _templateService.getItems(templateId),
        _answerService.getAnswers(widget.execution.id),
        _imageService.getImagesByExecution(widget.execution.id), // Phase 15
      ]);

      final items = results[0] as List<ChecklistTemplateItem>;
      final answerRows = results[1] as List<Map<String, dynamic>>;
      final imageRows = results[2] as List<ChecklistItemImage>;

      final merged = <String, String>{};
      final mergedObs = <String, String>{};
      for (final row in answerRows) {
        merged[row['item_id'] as String] = row['response'] as String? ?? '';
        if (row['observation'] != null) {
          mergedObs[row['item_id'] as String] = row['observation'] as String;
        }
      }

      // Pitfall 3: preservar respostas e observações pendentes (não salvas) sobre dados do banco
      merged.addAll(_failedSaves.map((k, v) => MapEntry(k, v.response)));
      for (final entry in _failedSaves.entries) {
        if (entry.value.observation != null) {
          mergedObs[entry.key] = entry.value.observation!;
        }
      }

      // Gerar signed URLs em paralelo (Pitfall 3: evitar N chamadas sequenciais)
      final urls = await Future.wait(
        imageRows.map((img) => _imageService
            .getSignedUrl(img.storagePath)
            .catchError((_) => '')),
      );

      final photosMap = <String, List<_ChecklistPhotoEntry>>{};
      for (var idx = 0; idx < imageRows.length; idx++) {
        final img = imageRows[idx];
        final url = urls[idx].isEmpty ? null : urls[idx];
        final entry = _ChecklistPhotoEntry(
          key: img.id,
          state: url != null ? _ChecklistPhotoState.uploaded : _ChecklistPhotoState.error,
          image: img,
          signedUrl: url,
        );
        photosMap.putIfAbsent(img.itemId, () => []).add(entry);
      }

      if (mounted) {
        setState(() {
          _allItems = items;
          _answers.addAll(merged);
          _observations.addAll(mergedObs);
          _photosPerItem.addAll(photosMap);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  // ── Progresso ─────────────────────────────────────────────────────────────

  int get _answeredCount => _allItems
      .where((i) => _answers.containsKey(i.id) && _answers[i.id]!.isNotEmpty)
      .length;

  int get _totalCount => _allItems.length;

  double get _conformity =>
      ChecklistAnswerService.calculateConformity(_allItems, _answers);

  static Color _conformityColor(double pct) {
    if (pct >= 80) return const Color(0xFF43A047);
    if (pct >= 60) return const Color(0xFFFFA000);
    return AppColors.error;
  }

  // ── Responder ─────────────────────────────────────────────────────────────

  void _onAnswer(String itemId, String response) {
    if (_finalizing) return;
    setState(() => _answers[itemId] = response);
    _saveAnswer(itemId, response); // fire-and-forget — sem await
  }

  void _onObservation(String itemId, String obs) {
    setState(() => _observations[itemId] = obs);
    final resp = _answers[itemId];
    if (resp != null) _saveAnswer(itemId, resp, observation: obs); // fire-and-forget
  }

  // ── Fotos por item ────────────────────────────────────────────────────────
  // CORE VALUE: _pickPhoto é completamente independente de _saveAnswer e _failedSaves.
  // Falha de upload => setState(error) + snackbar. Não toca _failedSaves. Não bloqueia _finalize.

  Future<void> _pickPhoto(String itemId) async {
    final messenger = ScaffoldMessenger.of(context); // ANTES de qualquer await (Pitfall 1)
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _PhotoSourceSheet(),
    );
    if (source == null) return;

    final file = await ImagePicker().pickImage(
        source: source, imageQuality: 85, maxWidth: 1200);
    if (file == null) return;

    final key = 'tmp_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _photosPerItem.putIfAbsent(itemId, () => []).add(
        _ChecklistPhotoEntry(
            key: key, state: _ChecklistPhotoState.uploading, file: file),
      );
    });

    try {
      final companyId = CompanyContextService.instance.activeCompanyId!;
      final img = await _imageService.uploadImage(
        companyId: companyId,
        executionId: widget.execution.id,
        itemId: itemId,
        file: file,
      );
      final url = await _imageService.getSignedUrl(img.storagePath);
      if (!mounted) return;
      setState(() {
        final photos = _photosPerItem[itemId]!;
        final i = photos.indexWhere((p) => p.key == key);
        if (i >= 0) {
          photos[i] = photos[i].copyWith(
            state: _ChecklistPhotoState.uploaded,
            image: img,
            signedUrl: url,
          );
        }
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('[ChecklistPhoto] upload error: $e\n$st');
      if (!mounted) return;
      setState(() {
        final photos = _photosPerItem[itemId]!;
        final i = photos.indexWhere((p) => p.key == key);
        if (i >= 0) {
          photos[i] = photos[i].copyWith(state: _ChecklistPhotoState.error);
        }
      });
      messenger.showSnackBar(
        SnackBar(
            content: Text('Upload falhou: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _retryPhoto(String itemId, String key) async {
    final photos = _photosPerItem[itemId];
    if (photos == null) return;
    final idx = photos.indexWhere((p) => p.key == key);
    if (idx < 0 || photos[idx].file == null) return;
    final file = photos[idx].file!;
    setState(() {
      photos[idx] = photos[idx].copyWith(state: _ChecklistPhotoState.uploading);
    });
    try {
      final companyId = CompanyContextService.instance.activeCompanyId!;
      final img = await _imageService.uploadImage(
        companyId: companyId,
        executionId: widget.execution.id,
        itemId: itemId,
        file: file,
      );
      final url = await _imageService.getSignedUrl(img.storagePath);
      if (!mounted) return;
      setState(() {
        final i = photos.indexWhere((p) => p.key == key);
        if (i >= 0) {
          photos[i] = photos[i].copyWith(
            state: _ChecklistPhotoState.uploaded,
            image: img,
            signedUrl: url,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = photos.indexWhere((p) => p.key == key);
        if (i >= 0) {
          photos[i] = photos[i].copyWith(state: _ChecklistPhotoState.error);
        }
      });
    }
  }

  Future<void> _removePhoto(String itemId, String key) async {
    final photos = _photosPerItem[itemId];
    if (photos == null) return;
    final idx = photos.indexWhere((p) => p.key == key);
    if (idx < 0) return;
    final entry = photos[idx];
    setState(() => photos.removeWhere((p) => p.key == key));
    if (entry.image != null) {
      try {
        await _imageService.deleteImage(
            imageId: entry.image!.id, storagePath: entry.image!.storagePath);
      } catch (_) {}
    }
  }

  // ── Auto-save (fire-and-forget) ───────────────────────────────────────────

  Future<void> _saveAnswer(
    String itemId,
    String response, {
    String? observation,
  }) async {
    // Resolve observação: parâmetro explícito vence, senão o map, senão null.
    final obs = observation ?? _observations[itemId];
    try {
      await _answerService.upsertAnswer(
        executionId: widget.execution.id,
        itemId: itemId,
        response: response,
        observation: obs,
      );
      // Sucesso: se esse item estava na fila de falhas, remove.
      if (_failedSaves.containsKey(itemId) && mounted) {
        setState(() => _failedSaves.remove(itemId));
      }
    } catch (e) {
      debugPrint('[_saveAnswer] itemId=$itemId erro: $e');
      if (!mounted) return;
      setState(() {
        _failedSaves[itemId] = _PendingSave(
          itemId: itemId,
          response: response,
          observation: obs,
        );
      });
      _showSaveError(itemId, response, obs);
      _scheduleRetry(itemId);
    }
  }

  // Pitfall 1: captura o messenger ANTES de qualquer async gap
  void _showSaveError(String itemId, String response, String? observation) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context); // ANTES de qualquer await
    messenger.clearSnackBars(); // evita acúmulo de snackbars em falhas sucessivas
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Não foi possível salvar'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Tentar novamente',
          textColor: Colors.white,
          onPressed: () {
            _saveAnswer(itemId, response, observation: observation);
          },
        ),
      ),
    );
  }

  // Retry automático com backoff exponencial:
  // delays: tentativa 0 = 1s, 1 = 2s, 2 = 4s, 3 = 8s. Após 4 falhas auto, para.
  Future<void> _scheduleRetry(String itemId) async {
    if (_retrying.contains(itemId)) return; // já existe loop para este item
    _retrying.add(itemId);
    try {
      while (_failedSaves.containsKey(itemId)) {
        final pending = _failedSaves[itemId]!;
        if (pending.attemptCount >= _maxAutoRetryAttempts) break;

        final delaySeconds = pow(2, pending.attemptCount).toInt(); // 1, 2, 4, 8
        await Future.delayed(Duration(seconds: delaySeconds));

        if (!mounted || !_failedSaves.containsKey(itemId)) break;

        try {
          await _answerService.upsertAnswer(
            executionId: widget.execution.id,
            itemId: itemId,
            response: pending.response,
            observation: pending.observation,
          );
          if (mounted) {
            setState(() => _failedSaves.remove(itemId));
            ScaffoldMessenger.of(context).clearSnackBars();
          }
          break; // sucesso — sai do loop
        } catch (_) {
          if (mounted) {
            setState(() {
              _failedSaves[itemId] = pending.copyWithAttempt();
            });
          }
        }
      }
    } finally {
      _retrying.remove(itemId);
    }
  }

  // ── Finalizar ─────────────────────────────────────────────────────────────

  Future<void> _finalize() async {
    // Guard: bloqueia finalização se há respostas com falha (T-14-12)
    if (_failedSaves.isNotEmpty) {
      final count = _failedSaves.length;
      final respostas = count > 1 ? 'respostas' : 'resposta';
      final verbo = count > 1 ? 'foram salvas' : 'foi salva';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Respostas não salvas'),
          content: Text(
            '$count $respostas não $verbo. '
            'Resolva as falhas antes de finalizar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return; // NÃO prossegue para o dialog de confirmação
    }

    if (!mounted) return;

    // Dialog de confirmação com progresso e conformidade
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar checklist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_answeredCount de $_totalCount itens respondidos.'),
            const SizedBox(height: 8),
            Text(
              'Conformidade: ${_conformity.toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
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
      await _executionService.finalizeExecution(
        id: widget.execution.id,
        conformityPercent: _conformity,
      );
      if (mounted) {
        Navigator.of(context).pop(true); // retorna true = concluído
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
      bottomNavigationBar: (!_loading && _error == null) ? _buildBottomBar(t) : null,
    );
  }

  AppBar _buildAppBar(AppTheme t) {
    final answered = _answeredCount;
    final total = _totalCount;
    final pct = total > 0 ? answered / total : 0.0;

    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.execution.templateName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            widget.execution.responsavel,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
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
                '$answered/$total itens',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
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
            Text(
              'Este template não possui itens cadastrados.',
              style: TextStyle(color: t.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _allItems.length,
        itemBuilder: (_, i) {
          final item = _allItems[i];
          return _ChecklistItemCard(
            item: item,
            itemNumber: i + 1,
            answer: _answers[item.id],
            observation: _observations[item.id],
            readOnly: _finalizing,
            onAnswer: (r) => _onAnswer(item.id, r),
            onObservation: (o) => _onObservation(item.id, o),
            theme: t,
            photos: item.itemType == 'photo' ? (_photosPerItem[item.id] ?? []) : null,
            onPickPhoto: _pickPhoto,
            onRetryPhoto: _retryPhoto,
            onRemovePhoto: _removePhoto,
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(AppTheme t) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 12;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.divider)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
      child: Row(
        children: [
          // Conformidade ao vivo
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Conformidade',
                style: TextStyle(fontSize: 11, color: t.textSecondary),
              ),
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
              onPressed: !_finalizing ? _finalize : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _finalizing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Finalizar checklist',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card de item de checklist
// ---------------------------------------------------------------------------
class _ChecklistItemCard extends StatefulWidget {
  final ChecklistTemplateItem item;
  final int itemNumber;
  final String? answer;
  final String? observation;
  final bool readOnly;
  final void Function(String) onAnswer;
  final void Function(String) onObservation;
  final AppTheme theme;
  // Phase 15: fotos por item
  final List<_ChecklistPhotoEntry>? photos;
  final void Function(String itemId)? onPickPhoto;
  final void Function(String itemId, String key)? onRetryPhoto;
  final void Function(String itemId, String key)? onRemovePhoto;

  const _ChecklistItemCard({
    required this.item,
    required this.itemNumber,
    required this.answer,
    required this.observation,
    required this.readOnly,
    required this.onAnswer,
    required this.onObservation,
    required this.theme,
    this.photos,
    this.onPickPhoto,
    this.onRetryPhoto,
    this.onRemovePhoto,
  });

  @override
  State<_ChecklistItemCard> createState() => _ChecklistItemCardState();
}

class _ChecklistItemCardState extends State<_ChecklistItemCard> {
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

  bool get _answered =>
      widget.answer != null && widget.answer!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final answered = _answered;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: answered
              ? AppColors.primary.withValues(alpha: 0.3)
              : t.divider,
          width: answered ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Número badge + texto da pergunta
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge numérico com indicador de respondido
                Container(
                  width: 28,
                  height: 28,
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
                        : Text(
                            '${widget.itemNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.textSecondary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.description,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: t.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _Badge(
                        label: widget.item.itemType,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Widget de resposta
            _AnswerWidget(
              item: widget.item,
              answer: widget.answer,
              readOnly: widget.readOnly,
              onAnswer: widget.onAnswer,
              theme: t,
            ),

            // Strip de fotos (Phase 15) — renderizado abaixo do _AnswerWidget para itens 'photo'
            if (widget.item.itemType == 'photo' && widget.photos != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _ChecklistPhotoStrip(
                  itemId: widget.item.id,
                  photos: widget.photos!,
                  readOnly: widget.readOnly,
                  onPickPhoto: widget.onPickPhoto!,
                  onRetryPhoto: widget.onRetryPhoto!,
                  onRemovePhoto: widget.onRemovePhoto!,
                  theme: widget.theme,
                ),
              ),

            // Campo de observação colapsável
            const SizedBox(height: 10),
            GestureDetector(
              onTap: widget.readOnly
                  ? null
                  : () => setState(() => _showObs = !_showObs),
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
                    _showObs ? 'Ocultar observação' : 'Adicionar observação',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.readOnly
                          ? t.textSecondary.withValues(alpha: 0.4)
                          : t.textSecondary,
                    ),
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
                  hintText: 'Observação (opcional)…',
                  hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
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
                    borderSide:
                        const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget de resposta — switch por tipo de item
// ---------------------------------------------------------------------------
class _AnswerWidget extends StatelessWidget {
  final ChecklistTemplateItem item;
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
    switch (item.itemType) {
      case 'yes_no':
        return _TwoOptionButtons(
          options: const [
            _OptionDef('yes', 'Sim', Icons.thumb_up_rounded, Color(0xFF43A047)),
            _OptionDef('no', 'Não', Icons.thumb_down_rounded, AppColors.error),
          ],
          selected: answer,
          readOnly: readOnly,
          onSelect: onAnswer,
          theme: theme,
        );

      case 'text':
        return _TextAnswer(
          initial: answer,
          readOnly: readOnly,
          onChanged: onAnswer,
          theme: theme,
        );

      case 'number':
        return _NumberAnswer(
          initial: answer,
          readOnly: readOnly,
          onChanged: onAnswer,
          theme: theme,
        );

      case 'date':
        return _DateAnswer(
          value: answer,
          readOnly: readOnly,
          onAnswer: onAnswer,
          theme: theme,
        );

      case 'multiple_choice':
        return _MultipleChoiceAnswer(
          options: item.options,
          selected: answer,
          readOnly: readOnly,
          onSelect: onAnswer,
          theme: theme,
        );

      case 'photo':
        return const SizedBox.shrink(); // Strip é gerenciado pelo _ChecklistItemCard pai

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

// ── Dois botões (yes/no) ───────────────────────────────────────────────────
class _TwoOptionButtons extends StatelessWidget {
  final List<_OptionDef> options;
  final String? selected;
  final bool readOnly;
  final void Function(String) onSelect;
  final AppTheme theme;

  const _TwoOptionButtons({
    required this.options,
    required this.selected,
    required this.readOnly,
    required this.onSelect,
    required this.theme,
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
                    Icon(
                      opt.icon,
                      color: sel ? opt.color : theme.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.normal,
                        color: sel ? opt.color : theme.textSecondary,
                      ),
                    ),
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

// ── Texto livre ───────────────────────────────────────────────────────────
class _TextAnswer extends StatefulWidget {
  final String? initial;
  final bool readOnly;
  final void Function(String) onChanged;
  final AppTheme theme;

  const _TextAnswer({
    this.initial,
    required this.readOnly,
    required this.onChanged,
    required this.theme,
  });

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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

// ── Número ────────────────────────────────────────────────────────────────
class _NumberAnswer extends StatefulWidget {
  final String? initial;
  final bool readOnly;
  final void Function(String) onChanged;
  final AppTheme theme;

  const _NumberAnswer({
    this.initial,
    required this.readOnly,
    required this.onChanged,
    required this.theme,
  });

  @override
  State<_NumberAnswer> createState() => _NumberAnswerState();
}

class _NumberAnswerState extends State<_NumberAnswer> {
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
      maxLines: 1,
      readOnly: widget.readOnly,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onChanged: widget.readOnly ? null : widget.onChanged,
      decoration: InputDecoration(
        hintText: 'Digite um número…',
        hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────
class _DateAnswer extends StatelessWidget {
  final String? value;
  final bool readOnly;
  final void Function(String) onAnswer;
  final AppTheme theme;

  const _DateAnswer({
    required this.value,
    required this.readOnly,
    required this.onAnswer,
    required this.theme,
  });

  DateTime? get _parsedDate =>
      (value != null && value!.isNotEmpty) ? DateTime.tryParse(value!) : null;

  String get _displayDate {
    final d = _parsedDate;
    if (d == null) return 'Selecionar data';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text(_displayDate),
      onPressed: readOnly
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _parsedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                onAnswer(picked.toIso8601String().substring(0, 10));
              }
            },
    );
  }
}

// ── Múltipla escolha ─────────────────────────────────────────────────────
class _MultipleChoiceAnswer extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final bool readOnly;
  final void Function(String) onSelect;
  final AppTheme theme;

  const _MultipleChoiceAnswer({
    required this.options,
    required this.selected,
    required this.readOnly,
    required this.onSelect,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (options.isEmpty) {
      return Text(
        'Nenhuma opção configurada.',
        style: TextStyle(color: t.textSecondary, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
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
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                color: sel ? AppColors.primary : t.textPrimary,
              ),
            ),
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
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Tipos auxiliares — fotos por item ────────────────────────────────────

enum _ChecklistPhotoState { uploading, uploaded, error }

class _ChecklistPhotoEntry {
  final String key;
  final _ChecklistPhotoState state;
  final XFile? file;
  final ChecklistItemImage? image;
  final String? signedUrl;

  const _ChecklistPhotoEntry({
    required this.key,
    required this.state,
    this.file,
    this.image,
    this.signedUrl,
  });

  _ChecklistPhotoEntry copyWith({
    _ChecklistPhotoState? state,
    ChecklistItemImage? image,
    String? signedUrl,
  }) =>
      _ChecklistPhotoEntry(
        key: key,
        state: state ?? this.state,
        file: file,
        image: image ?? this.image,
        signedUrl: signedUrl ?? this.signedUrl,
      );
}

// ── Seletor de fonte de foto ──────────────────────────────────────────────
// Copiado verbatim de create_corrective_action_screen.dart linhas 546-571

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.camera_alt_rounded, color: AppColors.accent),
          title: const Text('Tirar foto', style: TextStyle(fontSize: 14)),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_rounded, color: AppColors.accent),
          title: const Text('Escolher da galeria', style: TextStyle(fontSize: 14)),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Strip de miniaturas de foto por item ──────────────────────────────────
// StatelessWidget — estado vive no _ChecklistExecutionScreenState._photosPerItem

class _ChecklistPhotoStrip extends StatelessWidget {
  final String itemId;
  final List<_ChecklistPhotoEntry> photos;
  final bool readOnly;
  final void Function(String itemId) onPickPhoto;
  final void Function(String itemId, String key) onRetryPhoto;
  final void Function(String itemId, String key) onRemovePhoto;
  final AppTheme theme;

  const _ChecklistPhotoStrip({
    required this.itemId,
    required this.photos,
    required this.readOnly,
    required this.onPickPhoto,
    required this.onRetryPhoto,
    required this.onRemovePhoto,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!readOnly)
          GestureDetector(
            onTap: () => onPickPhoto(itemId),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.photo_camera_outlined,
                  size: 22, color: AppColors.accent),
            ),
          ),
        if (photos.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: photos
                    .map((p) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _buildThumb(p),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildThumb(_ChecklistPhotoEntry p) {
    return SizedBox(
      width: 72,
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onTap: p.state == _ChecklistPhotoState.error
              ? () => onRetryPhoto(itemId, p.key)
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (p.state == _ChecklistPhotoState.uploaded &&
                  p.signedUrl != null)
                Image.network(p.signedUrl!, fit: BoxFit.cover)
              else if (p.file != null)
                Opacity(
                  opacity:
                      p.state == _ChecklistPhotoState.error ? 0.4 : 0.6,
                  child: kIsWeb
                      ? Image.network(p.file!.path, fit: BoxFit.cover)
                      : Image.file(File(p.file!.path), fit: BoxFit.cover),
                )
              else
                Container(color: theme.background),
              if (p.state == _ChecklistPhotoState.uploading)
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                  ),
                ),
              if (p.state == _ChecklistPhotoState.error)
                const Center(
                  child: Icon(Icons.error_rounded,
                      color: AppColors.error, size: 20),
                ),
              if (p.state == _ChecklistPhotoState.uploaded && !readOnly)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => onRemovePhoto(itemId, p.key),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
