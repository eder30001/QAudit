import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_roles.dart';
import '../../core/app_theme.dart';
import '../../models/audit_type.dart';
import '../../services/audit_template_service.dart';
import '../../services/company_context_service.dart';
import '../../services/user_service.dart';
import 'audit_templates_screen.dart';

class AuditTypesScreen extends StatefulWidget {
  const AuditTypesScreen({super.key});

  @override
  State<AuditTypesScreen> createState() => _AuditTypesScreenState();
}

class _AuditTypesScreenState extends State<AuditTypesScreen> {
  final _service = AuditTemplateService();
  final _userService = UserService();

  List<AuditType> _types = [];
  bool _isLoading = true;
  String _myRole = '';
  String? _myCompanyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _userService.getMyProfile();
      _myRole = profile['role'] as String;
      // Superuser/dev usam o contexto de empresa selecionado no perfil
      _myCompanyId = AppRole.isSuperOrDev(_myRole)
          ? CompanyContextService.instance.activeCompanyId
          : profile['company_id'] as String?;
      final types = await _service.getTypes(companyId: _myCompanyId);
      if (mounted) setState(() => _types = types);
    } catch (e) {
      _showError('Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _canManage =>
      _myRole == AppRole.superuser ||
      _myRole == AppRole.dev ||
      _myRole == AppRole.adm;

  Future<void> _showTypeForm([AuditType? editing]) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    String selectedIcon = editing?.icon ?? '📋';
    String selectedColor = editing?.color ?? '#2196F3';
    final formKey = GlobalKey<FormState>();

    final icons = ['📋','🏭','🔐','⚙️','🌱','🔁','🚚','🧹','👥','🧾','✅','⚠️','📊','🎯','🔍'];
    final colors = [
      '#1565C0','#B71C1C','#4527A0','#2E7D32',
      '#E65100','#00838F','#4E342E','#F9A825',
      '#6A1B9A','#283593','#00695C','#37474F',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(editing != null ? 'Editar Tipo' : 'Novo Tipo de Auditoria',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: _inputDec('Nome do tipo *', Icons.label_outline, ctx),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 16),
                const Text('Ícone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: icons.map((ic) => GestureDetector(
                    onTap: () => set(() => selectedIcon = ic),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: selectedIcon == ic
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppTheme.of(ctx).background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selectedIcon == ic ? AppColors.primary : AppTheme.of(ctx).divider,
                          width: selectedIcon == ic ? 2 : 1,
                        ),
                      ),
                      child: Center(child: Text(ic, style: const TextStyle(fontSize: 20))),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Cor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: colors.map((c) {
                    final color = Color(int.parse('FF${c.replaceAll('#', '')}', radix: 16));
                    return GestureDetector(
                      onTap: () => set(() => selectedColor = c),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == c ? Colors.black54 : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: selectedColor == c
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);
                      try {
                        if (editing != null) {
                          await _service.updateType(
                              editing.id, nameCtrl.text.trim(), selectedIcon, selectedColor);
                        } else {
                          await _service.createType(
                            name: nameCtrl.text.trim(),
                            icon: selectedIcon,
                            color: selectedColor,
                            companyId: _myCompanyId,
                          );
                        }
                        _load();
                      } catch (e) { _showError('Erro: $e'); }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(editing != null ? 'Salvar' : 'Criar',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Tipos de Auditoria',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showTypeForm(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Novo Tipo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _types.isEmpty
              ? Center(child: Text('Nenhum tipo disponível',
                  style: TextStyle(color: AppTheme.of(context).textSecondary)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _types.length,
                    itemBuilder: (_, i) => _buildTypeCard(_types[i]),
                  ),
                ),
    );
  }

  Widget _buildTypeCard(AuditType type) {
    final color = type.colorValue;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.of(context).divider),
      ),
      color: AppTheme.of(context).surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AuditTemplatesScreen(
            type: type,
            companyId: _myCompanyId,
            canManage: _canManage,
          ),
        )),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(type.icon, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(
          type.name,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textPrimary),
        ),
        subtitle: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: type.isGlobal
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                type.isGlobal ? 'Global' : 'Personalizado',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: type.isGlobal ? AppColors.accent : color,
                ),
              ),
            ),
          ],
        ),
        trailing: _canManage && !type.isGlobal
            ? PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: AppTheme.of(context).textSecondary),
                onSelected: (v) {
                  if (v == 'edit') _showTypeForm(type);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                ],
              )
            : Icon(Icons.chevron_right_rounded,
                color: AppTheme.of(context).textSecondary),
      ),
    );
  }
}
