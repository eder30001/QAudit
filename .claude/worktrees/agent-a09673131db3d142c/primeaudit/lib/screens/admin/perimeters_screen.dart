import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/company.dart';
import '../../models/perimeter.dart';
import '../../services/perimeter_service.dart';
import '../../services/company_service.dart';

class PerimetersScreen extends StatefulWidget {
  final Company company;

  const PerimetersScreen({super.key, required this.company});

  @override
  State<PerimetersScreen> createState() => _PerimetersScreenState();
}

class _PerimetersScreenState extends State<PerimetersScreen> {
  final _service = PerimeterService();
  final _companyService = CompanyService();

  List<Perimeter> _tree = [];
  List<Perimeter> _flat = [];
  bool _isLoading = true;
  late bool _requiresPerimeter;

  @override
  void initState() {
    super.initState();
    _requiresPerimeter = widget.company.requiresPerimeter;
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final flat = await _service.getByCompany(widget.company.id);
      setState(() {
        _flat = flat;
        _tree = Perimeter.buildTree(List.from(flat));
      });
    } catch (e) {
      _showError('Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleRequiresPerimeter(bool value) async {
    try {
      await _companyService.update(
        widget.company.id,
        {'requires_perimeter': value},
      );
      setState(() => _requiresPerimeter = value);
    } catch (e) {
      _showError('Erro ao atualizar: $e');
    }
  }

  Future<void> _showForm({Perimeter? editing, Perimeter? parent}) async {
    final nameCtrl =
        TextEditingController(text: editing?.name ?? '');
    final descCtrl =
        TextEditingController(text: editing?.description ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing != null
                    ? 'Editar Perímetro'
                    : parent != null
                        ? 'Novo Subperímetro de "${parent.name}"'
                        : 'Novo Perímetro',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDec('Nome *', Icons.folder_outlined, ctx),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: descCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDec('Descrição (opcional)',
                    Icons.notes_rounded, ctx),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    editing != null ? 'Salvar' : 'Criar',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      if (editing != null) {
        await _service.update(
            editing.id, nameCtrl.text.trim(), descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
      } else {
        await _service.create(
          companyId: widget.company.id,
          parentId: parent?.id,
          name: nameCtrl.text.trim(),
          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        );
      }
      _load();
    } catch (e) {
      _showError('Erro ao salvar: $e');
    }
  }

  Future<void> _confirmDelete(Perimeter p) async {
    final hasChildren = _flat.any((f) => f.parentId == p.id);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir perímetro'),
        content: Text(hasChildren
            ? 'Este perímetro possui subperímetros. Ao excluí-lo, todos os subperímetros também serão excluídos.\n\nDeseja continuar?'
            : 'Excluir "${p.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _service.delete(p.id);
        _load();
      } catch (e) {
        _showError('Erro ao excluir: $e');
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  InputDecoration _inputDec(String label, IconData icon, BuildContext ctx) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.of(ctx).textSecondary, size: 20),
      filled: true,
      fillColor: AppTheme.of(ctx).surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.of(ctx).divider)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.of(ctx).divider)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Perímetros',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.company.name,
                style:
                    const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Perímetro',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Toggle obrigatório
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.of(context).surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.of(context).divider),
            ),
            child: SwitchListTile(
              title: const Text('Exigir perímetro nas auditorias',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(
                'O auditor deverá selecionar um perímetro ao criar uma auditoria',
                style:
                    TextStyle(fontSize: 12, color: AppTheme.of(context).textSecondary),
              ),
              value: _requiresPerimeter,
              activeThumbColor: AppColors.primary,
              onChanged: _toggleRequiresPerimeter,
            ),
          ),

          // Árvore
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _tree.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: ListView(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          children: _tree
                              .map((p) => _buildNode(p, depth: 0))
                              .toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_tree_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Nenhum perímetro cadastrado',
              style: TextStyle(color: AppTheme.of(context).textSecondary)),
          const SizedBox(height: 4),
          Text('Toque em "Novo Perímetro" para começar',
              style:
                  TextStyle(color: AppTheme.of(context).textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildNode(Perimeter p, {required int depth}) {
    final hasChildren = p.children.isNotEmpty;
    final leftPad = depth * 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(left: leftPad, bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.of(context).surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: p.active ? AppTheme.of(context).divider : Colors.grey[200]!,
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Icon(
              hasChildren
                  ? Icons.account_tree_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: p.active ? AppColors.primary : Colors.grey[400],
              size: 20,
            ),
            title: Text(
              p.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: p.active
                    ? AppTheme.of(context).textPrimary
                    : AppTheme.of(context).textSecondary,
                decoration:
                    p.active ? null : TextDecoration.lineThrough,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.description != null && p.description!.isNotEmpty)
                  Text(p.description!,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.of(context).textSecondary)),
                if (depth > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Nível ${depth + 1}',
                      style: TextStyle(
                          fontSize: 10, color: AppTheme.of(context).textSecondary),
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  color: AppTheme.of(context).textSecondary, size: 20),
              onSelected: (v) {
                if (v == 'add') _showForm(parent: p);
                if (v == 'edit') _showForm(editing: p);
                if (v == 'toggle') _service.toggleActive(p.id, !p.active).then((_) => _load());
                if (v == 'delete') _confirmDelete(p);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'add',
                    child: Row(children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 8),
                      Text('Adicionar subperímetro'),
                    ])),
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ])),
                PopupMenuItem(
                    value: 'toggle',
                    child: Row(children: [
                      Icon(
                          p.active
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18),
                      const SizedBox(width: 8),
                      Text(p.active ? 'Desativar' : 'Ativar'),
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18,
                          color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Excluir',
                          style: TextStyle(color: AppColors.error)),
                    ])),
              ],
            ),
          ),
        ),
        // Filhos recursivos
        ...p.children.map((child) => _buildNode(child, depth: depth + 1)),
      ],
    );
  }
}
