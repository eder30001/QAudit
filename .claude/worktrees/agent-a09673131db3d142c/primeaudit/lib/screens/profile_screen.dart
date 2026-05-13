import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_roles.dart';
import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/company.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';
import '../services/company_context_service.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  final _companyService = CompanyService();
  final _ctx = CompanyContextService.instance;

  AppUser? _user;
  List<Company> _companies = [];
  bool _loading = true;
  bool _savingName = false;

  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final current = _authService.currentUser;
      if (current == null) return;
      final user = await _userService.getById(current.id);
      _nameCtrl.text = user.fullName;

      List<Company> companies = [];
      if (AppRole.isSuperOrDev(user.role)) {
        companies = await _companyService.getAll();
      }

      if (mounted) {
        setState(() {
          _user = user;
          _companies = companies;
        });
      }
    } catch (e) {
      _showError('Erro ao carregar perfil: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || name == _user?.fullName) return;
    setState(() => _savingName = true);
    try {
      await _userService.updateFullName(_user!.id, name);
      if (mounted) {
        setState(() => _user = AppUser(
          id: _user!.id,
          fullName: name,
          email: _user!.email,
          role: _user!.role,
          companyId: _user!.companyId,
          companyName: _user!.companyName,
          active: _user!.active,
          createdAt: _user!.createdAt,
        ));
        _showSuccess('Nome atualizado!');
      }
    } catch (e) {
      _showError('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePassword() async {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure1 = true, obscure2 = true;

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
                const Text('Alterar senha',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: passCtrl,
                  obscureText: obscure1,
                  decoration: InputDecoration(
                    labelText: 'Nova senha *',
                    prefixIcon: Icon(Icons.lock_outline, size: 20,
                        color: AppTheme.of(ctx).textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(obscure1 ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined, size: 20),
                      onPressed: () => set(() => obscure1 = !obscure1),
                    ),
                    filled: true, fillColor: AppTheme.of(ctx).surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.of(ctx).divider)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.of(ctx).divider)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: obscure2,
                  decoration: InputDecoration(
                    labelText: 'Confirmar senha *',
                    prefixIcon: Icon(Icons.lock_outline, size: 20,
                        color: AppTheme.of(ctx).textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(obscure2 ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined, size: 20),
                      onPressed: () => set(() => obscure2 = !obscure2),
                    ),
                    filled: true, fillColor: AppTheme.of(ctx).surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.of(ctx).divider)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.of(ctx).divider)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (v) => v != passCtrl.text ? 'Senhas não conferem' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);
                      try {
                        await _authService.changePassword(passCtrl.text);
                        if (mounted) _showSuccess('Senha alterada com sucesso!');
                      } catch (e) {
                        if (mounted) _showError('Erro: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Salvar senha',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectCompany() async {
    // Retorna: null = fechou sem escolher, {'id': null} = Todas, {'id': '...'} = empresa
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final currentId = _ctx.activeCompanyId;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(children: [
                  const Icon(Icons.business_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Selecionar organização',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.grid_view_rounded,
                            color: AppColors.accent, size: 20),
                      ),
                      title: const Text('Todas as organizações',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Exibe dados de todas as empresas',
                          style: TextStyle(fontSize: 12)),
                      trailing: currentId == null
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.accent)
                          : null,
                      onTap: () => Navigator.pop(ctx, {'id': null, 'name': null}),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ..._companies.map((c) => ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(c.name[0].toUpperCase(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 16)),
                        ),
                      ),
                      title: Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: c.cnpj != null
                          ? Text(c.cnpj!, style: const TextStyle(fontSize: 12))
                          : null,
                      trailing: currentId == c.id
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.accent)
                          : null,
                      onTap: () => Navigator.pop(ctx, {'id': c.id, 'name': c.name}),
                    )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    await _ctx.setActiveCompany(result['id'], result['name']);
    setState(() {});
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: Colors.green[700],
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
        title: const Text('Meu Perfil',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _user == null
              ? const Center(child: Text('Erro ao carregar perfil'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildNameSection(),
                    const SizedBox(height: 16),
                    if (AppRole.isSuperOrDev(_user!.role)) ...[
                      _buildOrgSection(),
                      const SizedBox(height: 16),
                    ],
                    _buildSecuritySection(),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    final initial = _user!.fullName.isNotEmpty ? _user!.fullName[0].toUpperCase() : '?';
    final roleColor = _user!.roleColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.of(context).divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_user!.fullName,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: AppTheme.of(context).textPrimary)),
                const SizedBox(height: 2),
                Text(_user!.email,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.of(context).textSecondary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(AppRole.label(_user!.role),
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: roleColor)),
                  ),
                  if (_user!.companyName != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('· ${_user!.companyName}',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.of(context).textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection() {
    return _sectionCard(
      title: 'Informações',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nome completo',
              prefixIcon: Icon(Icons.badge_outlined, size: 20,
                  color: AppTheme.of(context).textSecondary),
              filled: true, fillColor: AppTheme.of(context).background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.of(context).divider)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.of(context).divider)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 44,
            child: ElevatedButton(
              onPressed: _savingName ? null : _saveName,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _savingName
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Salvar nome',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrgSection() {
    final activeId = _ctx.activeCompanyId;
    final activeName = _ctx.activeCompanyName;

    return _sectionCard(
      title: 'Contexto de organização',
      icon: Icons.business_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecione qual organização deseja visualizar. '
            'Os dados de templates e auditorias serão filtrados por esta seleção.',
            style: TextStyle(fontSize: 12, color: AppTheme.of(context).textSecondary),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectCompany,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.of(context).background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.of(context).divider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: activeId != null
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      activeId != null ? Icons.business_rounded : Icons.grid_view_rounded,
                      size: 18,
                      color: activeId != null ? AppColors.primary : AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeId != null
                              ? (activeName ?? 'Organização selecionada')
                              : 'Todas as organizações',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.of(context).textPrimary),
                        ),
                        Text(
                          activeId != null
                              ? 'Toque para trocar de organização'
                              : 'Exibindo dados de todas as empresas',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.of(context).textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.of(context).textSecondary),
                ],
              ),
            ),
          ),
          if (activeId != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await _ctx.setActiveCompany(null, null);
                setState(() {});
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Limpar seleção', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: AppTheme.of(context).textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return _sectionCard(
      title: 'Segurança',
      icon: Icons.security_rounded,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.lock_outline_rounded,
              color: Colors.orange, size: 20),
        ),
        title: const Text('Alterar senha',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: const Text('Defina uma nova senha de acesso',
            style: TextStyle(fontSize: 12)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: AppTheme.of(context).textSecondary),
        onTap: _changePassword,
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.of(context).divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
