import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/checklist_template.dart';
import '../../services/checklist_template_service.dart';

/// Tela de criação e edição de templates de checklist.
///
/// Create mode: [editing] é null — cria um novo template via [ChecklistTemplateService.createTemplate].
/// Edit mode: [editing] é um [ChecklistTemplate] existente — atualiza metadados e substituiu itens.
class ChecklistTemplateFormScreen extends StatefulWidget {
  final ChecklistTemplate? editing; // null = create mode

  const ChecklistTemplateFormScreen({super.key, this.editing});

  @override
  State<ChecklistTemplateFormScreen> createState() =>
      _ChecklistTemplateFormScreenState();
}

class _ChecklistTemplateFormScreenState
    extends State<ChecklistTemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ChecklistTemplateService();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _category;
  bool _isSaving = false;
  bool _isLoadingItems = false;

  // Items list — cada map tem 'ctrl' (TextEditingController) e 'item_type' (String)
  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.editing?.name ?? '';
    _descCtrl.text = widget.editing?.description ?? '';
    _category = widget.editing?.category;
    if (widget.editing != null) {
      _loadItems();
    }
  }

  /// Carrega os itens existentes do template em modo de edição.
  Future<void> _loadItems() async {
    if (widget.editing == null) return;
    setState(() => _isLoadingItems = true);
    try {
      final items = await _service.getItems(widget.editing!.id);
      if (mounted) {
        setState(() {
          _items.clear();
          for (final item in items) {
            _items.add({
              'ctrl': TextEditingController(text: item.description),
              'item_type': item.itemType,
            });
          }
        });
      }
    } catch (e) {
      if (mounted) _showError('Erro ao carregar itens.');
    } finally {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final e in _items) {
      (e['ctrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  /// Salva o template: cria ou atualiza conforme o modo.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      _showError('Adicione ao menos um item');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final name = _nameCtrl.text.trim();
      final category = _category!;
      final description =
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      final itemMaps = _items
          .map((e) => {
                'description':
                    (e['ctrl'] as TextEditingController).text.trim(),
                'item_type': e['item_type'] as String,
              })
          .toList();

      if (widget.editing != null) {
        // Edit mode: atualiza metadados + substitui itens
        await _service.updateTemplate(
          widget.editing!.id,
          name: name,
          category: category,
          description: description,
        );
        await _service.replaceItems(widget.editing!.id, itemMaps);
      } else {
        // Create mode: cria template + insere itens
        final newTemplate = await _service.createTemplate(
          name: name,
          category: category,
          description: description,
        );
        await _service.createItems(newTemplate.id, itemMaps);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        _showError('Erro ao salvar. Verifique os dados e tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon:
            Icon(icon, color: AppTheme.of(context).textSecondary, size: 20),
        filled: true,
        fillColor: AppTheme.of(context).surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.of(context).divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.of(context).divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          widget.editing != null ? 'Editar checklist' : 'Novo checklist',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Campo Nome
              TextFormField(
                controller: _nameCtrl,
                autofocus: widget.editing == null,
                textCapitalization: TextCapitalization.words,
                decoration:
                    _inputDec('Nome do checklist *', Icons.assignment_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              // 2. Dropdown Categoria
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration:
                    _inputDec('Categoria *', Icons.category_outlined),
                items: const [
                  DropdownMenuItem(
                      value: 'industrial', child: Text('Industrial')),
                  DropdownMenuItem(
                      value: 'transportadora',
                      child: Text('Transportadora')),
                ],
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => v == null ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              // 3. Campo Descrição
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration:
                    _inputDec('Descrição (opcional)', Icons.notes_rounded),
              ),
              const SizedBox(height: 24),

              // 4. Cabeçalho da seção de itens
              const Text(
                'Itens do checklist',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              // 5. Lista de itens
              if (_isLoadingItems)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                Column(
                  children: _items
                      .asMap()
                      .entries
                      .map(
                        (e) => _ItemRow(
                          ctrl: e.value['ctrl'] as TextEditingController,
                          itemType: e.value['item_type'] as String,
                          onRemove: () =>
                              setState(() => _items.removeAt(e.key)),
                          onTypeChanged: (t) =>
                              setState(() => _items[e.key]['item_type'] = t),
                        ),
                      )
                      .toList(),
                ),

              // 6. Botão adicionar item
              TextButton.icon(
                onPressed: () => setState(() => _items.add({
                      'ctrl': TextEditingController(),
                      'item_type': 'yes_no',
                    })),
                icon: const Icon(Icons.add, color: AppColors.accent),
                label: const Text(
                  'Adicionar item',
                  style: TextStyle(color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 24),

              // 7. Botão primário — Salvar / Criar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text(
                          widget.editing != null
                              ? 'Salvar alterações'
                              : 'Criar checklist',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha de item do checklist com campo de texto, seletor de tipo e botão de remoção.
class _ItemRow extends StatelessWidget {
  final TextEditingController ctrl;
  final String itemType;
  final VoidCallback onRemove;
  final ValueChanged<String> onTypeChanged;

  const _ItemRow({
    required this.ctrl,
    required this.itemType,
    required this.onRemove,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextFormField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Descrição do item',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: itemType,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'yes_no', child: Text('Sim/Não')),
              DropdownMenuItem(value: 'text', child: Text('Texto')),
              DropdownMenuItem(value: 'number', child: Text('Número')),
              DropdownMenuItem(value: 'date', child: Text('Data')),
              DropdownMenuItem(
                  value: 'multiple_choice', child: Text('Múltipla escolha')),
              DropdownMenuItem(value: 'photo', child: Text('Foto')),
            ],
            onChanged: (v) {
              if (v != null) onTypeChanged(v);
            },
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: AppColors.error),
            onPressed: onRemove,
            tooltip: 'Remover item',
          ),
        ],
      ),
    );
  }
}
