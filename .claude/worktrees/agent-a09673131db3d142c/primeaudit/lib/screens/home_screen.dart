import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_roles.dart';
import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../services/company_context_service.dart';
import '../services/user_service.dart';
import 'admin/admin_screen.dart';
import 'audits_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'templates/audit_types_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _role = '';
  String _name = '';
  String _email = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      final profile = await _userService.getById(user.id);
      await CompanyContextService.instance.init(
        role: profile.role,
        profileCompanyId: profile.companyId,
        profileCompanyName: profile.companyName,
      );
      if (mounted) {
        setState(() {
          _role = profile.role;
          _name = profile.fullName;
          _email = profile.email;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    Navigator.of(context).pop(); // fecha o drawer
    await CompanyContextService.instance.clear();
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _navigate(Widget screen) {
    Navigator.of(context).pop(); // fecha o drawer
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('PrimeAudit',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {}, // futuro
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _buildDashboard(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.of(context).surface,
      child: Column(
        children: [
          // Cabeçalho do drawer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 14),
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white24,
                  child: Text(
                    _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name.isNotEmpty ? _name : 'Usuário',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _email,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppRole.label(_role),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Itens do menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(
                  icon: Icons.dashboard_rounded,
                  title: 'Dashboard',
                  onTap: () => Navigator.of(context).pop(),
                ),
                if (AppRole.canAccessAdmin(_role))
                  _drawerItem(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Administração',
                    onTap: () => _navigate(const AdminScreen()),
                  ),
                if (AppRole.canAccessAdmin(_role))
                  _drawerItem(
                    icon: Icons.assignment_rounded,
                    title: 'Templates de Auditoria',
                    onTap: () => _navigate(const AuditTypesScreen()),
                  ),
                _drawerItem(
                  icon: Icons.playlist_add_check_rounded,
                  title: 'Auditorias',
                  onTap: () => _navigate(AuditsScreen(
                    currentUserId: _authService.currentUser?.id ?? '',
                    currentUserName: _name,
                  )),
                ),
                _drawerItem(
                  icon: Icons.bar_chart_rounded,
                  title: 'Relatórios',
                  onTap: () => Navigator.of(context).pop(), // próxima tela
                ),
                const Divider(indent: 16, endIndent: 16),
                _drawerItem(
                  icon: Icons.person_outline_rounded,
                  title: 'Meu perfil',
                  onTap: () => _navigate(const ProfileScreen()),
                ),
                _drawerItem(
                  icon: Icons.settings_outlined,
                  title: 'Configurações',
                  onTap: () => _navigate(const SettingsScreen()),
                ),
              ],
            ),
          ),

          // Rodapé com logout
          const Divider(height: 1),
          _drawerItem(
            icon: Icons.logout_rounded,
            title: 'Sair',
            color: AppColors.error,
            onTap: _logout,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? AppTheme.of(context).textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: itemColor, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: itemColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      horizontalTitleGap: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Saudação
          Text(
            _name.isNotEmpty
                ? 'Olá, ${_name.split(' ').first}!'
                : 'Bem-vindo!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _roleLabel(),
            style: TextStyle(
                fontSize: 13, color: AppTheme.of(context).textSecondary),
          ),
          const SizedBox(height: 24),

          // Cards de resumo (placeholders)
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  icon: Icons.assignment_rounded,
                  label: 'Auditorias',
                  value: '—',
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  icon: Icons.check_circle_rounded,
                  label: 'Concluídas',
                  value: '—',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  icon: Icons.pending_rounded,
                  label: 'Em andamento',
                  value: '—',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              if (AppRole.canAccessAdmin(_role))
                Expanded(
                  child: _summaryCard(
                    icon: Icons.business_rounded,
                    label: 'Empresas',
                    value: '—',
                    color: Colors.purple,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 28),

          // Atividade recente
          Text(
            'Atividade recente',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: AppTheme.of(context).surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.of(context).divider),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 40, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text(
                  'Nenhuma atividade recente',
                  style: TextStyle(
                      color: AppTheme.of(context).textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel() {
    switch (_role) {
      case AppRole.superuser:
        return 'Acesso total ao sistema';
      case AppRole.dev:
        return 'Ambiente de desenvolvimento';
      case AppRole.adm:
        return 'Administrador da empresa';
      case AppRole.auditor:
        return 'Auditor';
      case AppRole.anonymous:
        return 'Acesso restrito';
      default:
        return '';
    }
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.of(context).divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.of(context).textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.of(context).textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
