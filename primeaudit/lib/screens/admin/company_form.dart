import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/cnpj_validator.dart';
import '../../models/company.dart';
import '../../services/company_service.dart';

// Segmentos disponíveis
const _segments = [
  ('industrial',    'Industrial',    Icons.factory_outlined),
  ('transportador', 'Transportador', Icons.local_shipping_outlined),
  ('construcao',    'Construção',    Icons.construction_outlined),
  ('alimenticio',   'Alimentício',   Icons.restaurant_outlined),
  ('logistica',     'Logística',     Icons.inventory_2_outlined),
  ('outro',         'Outro',         Icons.category_outlined),
];

// Módulos disponíveis
const _allModules = [
  ('auditoria',  'Auditoria',  Icons.playlist_add_check_rounded),
  ('checklist',  'Checklist',  Icons.checklist_rounded),
];

class CompanyForm extends StatefulWidget {
  final Company? company;

  const CompanyForm({super.key, this.company});

  @override
  State<CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends State<CompanyForm> {
  final _formKey = GlobalKey<FormState>();
  final _service = CompanyService();

  late final TextEditingController _nameController;
  late final TextEditingController _cnpjController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  bool _isLoading = false;
  bool _active = true;
  String _segment = 'industrial';
  List<String> _modules = ['auditoria', 'checklist'];

  bool get _isEditing => widget.company != null;

  @override
  void initState() {
    super.initState();
    final c = widget.company;
    _nameController = TextEditingController(text: c?.name ?? '');
    _cnpjController = TextEditingController(text: c?.cnpj ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _active = c?.active ?? true;
    _segment = c?.segment ?? 'industrial';
    _modules = List<String>.from(c?.modules ?? ['auditoria', 'checklist']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cnpjController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_modules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione ao menos um módulo.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'cnpj': _cnpjController.text.trim().isEmpty
            ? null
            : _cnpjController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'active': _active,
        'segment': _segment,
        'modules': _modules,
      };

      if (_isEditing) {
        await _service.update(widget.company!.id, data);
      } else {
        await _service.create(data);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(_isEditing ? 'Editar Empresa' : 'Nova Empresa'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Salvar',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Dados básicos ───────────────────────────────────────────────
            _buildField(
              controller: _nameController,
              label: 'Nome da empresa *',
              icon: Icons.business_rounded,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _cnpjController,
              label: 'CNPJ',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              validator: validateCnpj,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _emailController,
              label: 'E-mail',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _phoneController,
              label: 'Telefone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _addressController,
              label: 'Endereço',
              icon: Icons.location_on_outlined,
              maxLines: 2,
            ),

            // ── Segmento ────────────────────────────────────────────────────
            const SizedBox(height: 24),
            _sectionLabel(t, 'Segmento', Icons.category_outlined),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _segments.map((seg) {
                final selected = _segment == seg.$1;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(seg.$3, size: 16,
                          color: selected ? Colors.white : t.textSecondary),
                      const SizedBox(width: 6),
                      Text(seg.$2),
                    ],
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _segment = seg.$1),
                  selectedColor: AppColors.primary,
                  backgroundColor: t.surface,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : t.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                      color: selected ? AppColors.primary : t.divider),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                );
              }).toList(),
            ),

            // ── Módulos contratados ─────────────────────────────────────────
            const SizedBox(height: 24),
            _sectionLabel(t, 'Módulos contratados', Icons.extension_outlined),
            const SizedBox(height: 4),
            Text(
              'Selecione os módulos disponíveis para esta empresa.',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
            const SizedBox(height: 10),
            ..._allModules.map((mod) {
              final enabled = _modules.contains(mod.$1);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: enabled ? AppColors.primary : t.divider,
                    width: enabled ? 1.5 : 1,
                  ),
                ),
                child: CheckboxListTile(
                  value: enabled,
                  activeColor: AppColors.primary,
                  title: Row(
                    children: [
                      Icon(mod.$3, size: 20,
                          color: enabled ? AppColors.primary : t.textSecondary),
                      const SizedBox(width: 10),
                      Text(mod.$2,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 15)),
                    ],
                  ),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _modules.add(mod.$1);
                    } else {
                      _modules.remove(mod.$1);
                    }
                  }),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            }),

            // ── Status ──────────────────────────────────────────────────────
            if (_isEditing) ...[
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.divider),
                ),
                child: SwitchListTile(
                  title: const Text('Empresa ativa',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    _active ? 'Visível no sistema' : 'Desativada',
                    style: TextStyle(color: t.textSecondary, fontSize: 12),
                  ),
                  value: _active,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(AppTheme t, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final t = AppTheme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.words,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: t.textSecondary, size: 20),
        filled: true,
        fillColor: t.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: t.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: t.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
