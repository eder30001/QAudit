import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_roles.dart';
import '../../core/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/company.dart';
import '../../services/company_service.dart';
import '../../services/user_service.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final _userService = UserService();
  final _companyService = CompanyService();

  List<AppUser> _users = [];
  List<AppUser> _filtered = [];
  List<Company> _companies = [];
  bool _isLoading = true;
  String _search = '';
  String _myRole = '';

  List<String> get _availableRoles {
    if (_myRole == AppRole.adm) {
      return [AppRole.adm, AppRole.auditor, AppRole.anonymous];
    }
    return AppRole.all;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _userService.getAll(),
        _companyService.getAll(),
        _userService.getMyRole(),
      ]);
      setState(() {
        _users = results[0] as List<AppUser>;
        _companies = results[1] as List<Company>;
        _myRole = results[2] as String;
        _applySearch();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    final q = _search.toLowerCase();
    _filtered = _users.where((u) {
      return u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.roleLabel.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmToggleActive(AppUser user) async {
    final desativar = user.active;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(desativar ? 'Desativar usuário' : 'Ativar usuário'),
        content: Text(
          desativar
              ? 'Desativar "${user.fullName}"? Ele não conseguirá mais fazer login.'
              : 'Ativar "${user.fullName}"? Ele poderá fazer login novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: desativar ? AppColors.error : Colors.green,
            ),
            child: Text(desativar ? 'Desativar' : 'Ativar'),
          ),
        ],
      ),
    );
    if (confirm == true) await _toggleActive(user);
  }

  Future<void> _editUser(AppUser user) async {
    String selectedRole = user.role;
    String? selectedCompanyId = user.companyId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Text(
                      user.fullName[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(user.email,
                            style: TextStyle(
                                color: AppTheme.of(ctx).textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Perfil de acesso',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.of(ctx).textSecondary,
                      fontSize: 12)),
              const SizedBox(height: 10),
              ..._availableRoles.map((role) => _roleOption(
                    role: role,
                    selected: selectedRole,
                    onTap: () => setModalState(() => selectedRole = role),
                    ctx: ctx,
                  )),
              const SizedBox(height: 20),
              Text('Empresa vinculada',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.of(ctx).textSecondary,
                      fontSize: 12)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: selectedCompanyId,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.of(ctx).surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.of(ctx).divider)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.of(ctx).divider)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Nenhuma empresa')),
                  ..._companies.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )),
                ],
                onChanged: (v) => setModalState(() => selectedCompanyId = v),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Usuário ativo',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        user.active
                            ? 'Pode fazer login no sistema'
                            : 'Login bloqueado',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.of(ctx).textSecondary),
                      ),
                    ],
                  ),
                  Switch(
                    value: user.active,
                    activeThumbColor: AppColors.primary,
                    onChanged: (_) {
                      Navigator.pop(ctx);
                      _confirmToggleActive(user);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await Future.wait([
                        _userService.updateRole(user.id, selectedRole),
                        _userService.updateCompany(
                            user.id, selectedCompanyId),
                      ]);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _load();
                    } catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                            content: Text('Erro: $e'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Salvar alterações',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleActive(AppUser user) async {
    try {
      await _userService.toggleActive(user.id, !user.active);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() {
              _search = v;
              _applySearch();
            }),
            decoration: InputDecoration(
              hintText: 'Buscar usuário...',
              prefixIcon:
                  Icon(Icons.search, color: AppTheme.of(context).textSecondary),
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
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 2)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _filtered.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _buildCard(_filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            _search.isEmpty ? 'Nenhum usuário encontrado' : 'Nenhum resultado',
            style: TextStyle(color: AppTheme.of(context).textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _roleOption({
    required String role,
    required String selected,
    required VoidCallback onTap,
    required BuildContext ctx,
  }) {
    final isSelected = role == selected;
    final user = AppUser(
      id: '', fullName: '', email: '', role: role,
      active: true, createdAt: DateTime.now(),
    );
    final color = user.roleColor;

    final descriptions = {
      AppRole.superuser: 'CRUD completo em toda a base de dados',
      AppRole.dev:       'Acesso total + bases de desenvolvimento',
      AppRole.adm:       'CRUD dos dados e usuários da sua empresa',
      AppRole.auditor:   'Cria e exclui apenas seus próprios registros',
      AppRole.anonymous: 'Acesso via link, sem cadastro',
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.of(ctx).surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppTheme.of(ctx).divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : AppTheme.of(ctx).divider,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppRole.label(role),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? color : AppTheme.of(ctx).textPrimary,
                    ),
                  ),
                  Text(
                    descriptions[role] ?? '',
                    style: TextStyle(fontSize: 11, color: AppTheme.of(ctx).textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(AppUser user) {
    final roleColor = user.roleColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.of(context).divider),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              user.active ? AppColors.primary : Colors.grey[300],
          child: Text(
            user.fullName[0].toUpperCase(),
            style: TextStyle(
              color: user.active ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(user.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email,
                style: TextStyle(
                    fontSize: 12, color: AppTheme.of(context).textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    user.roleLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: roleColor,
                    ),
                  ),
                ),
                if (user.companyName != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      user.companyName!,
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.of(context).textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon:
              Icon(Icons.more_vert, color: AppTheme.of(context).textSecondary),
          onSelected: (value) {
            if (value == 'edit') _editUser(user);
            if (value == 'toggle') _confirmToggleActive(user);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar perfil')),
            PopupMenuItem(
              value: 'toggle',
              child: Text(user.active ? 'Desativar' : 'Ativar'),
            ),
          ],
        ),
      ),
    );
  }
}
