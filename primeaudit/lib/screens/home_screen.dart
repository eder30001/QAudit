import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_roles.dart';
import '../core/app_theme.dart';
import '../models/audit.dart';
import '../services/audit_service.dart';
import '../services/auth_service.dart';
import '../models/company.dart';
import '../services/company_context_service.dart';
import '../services/company_service.dart';
import '../services/dashboard_service.dart';
import '../services/user_service.dart';
import 'admin/admin_screen.dart';
import 'audits_screen.dart';
import 'corrective_actions_screen.dart';
import '../services/corrective_action_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'templates/models_screen.dart';
import 'settings_screen.dart';
import 'checklist/checklists_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  final _companyService = CompanyService();
  final _auditService = AuditService();
  final _dashboardService = DashboardService();
  final _correctiveActionService = CorrectiveActionService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _role = '';
  String _name = '';
  String _email = '';
  bool _loading = true;
  int _totalAudits = 0;
  int _pendingAudits = 0;
  int _overdueAudits = 0;
  int _openActions = 0;
  int _companiesCount = 0;
  bool _dashboardLoading = false;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, List<Audit>> _calendarData = {};
  String? _calendarError;
  List<Audit> _allAudits = []; // retained for re-bucketing on month navigation (no extra request)

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
      // Carregar dados da empresa para segment/modules (não-superuser)
      Company? company;
      if (profile.companyId != null && !AppRole.isSuperOrDev(profile.role)) {
        try {
          final companies = await _companyService.getAll();
          company = companies.where((c) => c.id == profile.companyId).firstOrNull;
        } catch (_) {}
      }
      await CompanyContextService.instance.init(
        role: profile.role,
        profileCompanyId: profile.companyId,
        profileCompanyName: profile.companyName,
        profileCompanySegment: company?.segment ?? 'industrial',
        profileCompanyModules: company?.modules ?? ['auditoria', 'checklist'],
      );
      if (mounted) {
        setState(() {
          _role = profile.role;
          _name = profile.fullName;
          _email = profile.email;
        });
      }
      await _loadDashboard(); // chain: _role and CompanyContextService now ready
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() => _dashboardLoading = true);
    try {
      final companyId = CompanyContextService.instance.activeCompanyId;
      final currentUserId = _authService.currentUser?.id ?? '';

      // Single fetch — Dart-side filter for auditor scope (D-05/D-06)
      final all = await _auditService.getAudits(companyId: companyId);
      final audits = (AppRole.isSuperOrDev(_role) || AppRole.canAccessAdmin(_role))
          ? all
          : all.where((a) => a.auditorId == currentUserId).toList();

      // KPI counts in Dart (D-01: total excludes cancelada, D-02: pending = emAndamento, D-03: overdue = atrasada)
      final total = audits.where((a) => a.status != AuditStatus.cancelada).length;
      final pending = audits.where((a) => a.status == AuditStatus.emAndamento).length;
      final overdue = audits.where((a) => a.status == AuditStatus.atrasada).length;

      // Open actions — aberta + em_andamento + em_avaliacao (Phase 8)
      final openActions = await _correctiveActionService.getOpenActionsCount(companyId);

      // Companies count — superuser/dev only (D-07: isSuperOrDev, NOT canAccessAdmin)
      int companiesCount = 0;
      if (AppRole.isSuperOrDev(_role)) {
        companiesCount = await _dashboardService.getCompaniesCount();
      }

      // Calendar bucketing — reuses same 'audits' list, zero extra request (CAL-01)
      final calendarData = _buildCalendarData(
          audits, _calendarMonth.year, _calendarMonth.month);

      if (mounted) {
        setState(() {
          _totalAudits = total;
          _pendingAudits = pending;
          _overdueAudits = overdue;
          _openActions = openActions;
          _companiesCount = companiesCount;
          _allAudits = audits;
          _calendarData = calendarData;
          _calendarError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _calendarError = e.toString());
    } finally {
      if (mounted) setState(() => _dashboardLoading = false);
    }
  }

  // ── Calendar helpers ──────────────────────────────────────────────────────────

  Map<String, List<Audit>> _buildCalendarData(
      List<Audit> audits, int year, int month) {
    final Map<String, List<Audit>> data = {};
    for (final audit in audits) {
      if (audit.status == AuditStatus.cancelada) continue; // D-04
      final effectiveDate =
          (audit.deadline ?? audit.createdAt).toLocal(); // D-03 + UTC pitfall fix — REQUIRED
      if (effectiveDate.year == year && effectiveDate.month == month) {
        final key =
            '${effectiveDate.year}-'
            '${effectiveDate.month.toString().padLeft(2, "0")}-'
            '${effectiveDate.day.toString().padLeft(2, "0")}';
        data.putIfAbsent(key, () => []).add(audit);
      }
    }
    return data;
  }

  void _prevMonth() {
    setState(() {
      _calendarMonth =
          DateTime(_calendarMonth.year, _calendarMonth.month - 1);
      _calendarData = _buildCalendarData(
          _allAudits, _calendarMonth.year, _calendarMonth.month);
    });
  }

  void _nextMonth() {
    setState(() {
      _calendarMonth =
          DateTime(_calendarMonth.year, _calendarMonth.month + 1);
      _calendarData = _buildCalendarData(
          _allAudits, _calendarMonth.year, _calendarMonth.month);
    });
  }

  void _onDayTap(DateTime date) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AuditsScreen(
        currentUserId: _authService.currentUser?.id ?? '',
        currentUserName: _name,
        filterDate: date, // NEW optional param added in Plan 02
      ),
    ));
  }

  Widget _buildCalendar() {
    if (_dashboardLoading) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_calendarError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Erro ao carregar calendário. Puxe para atualizar.',
          style: TextStyle(
            color: AppTheme.of(context).textSecondary,
            fontSize: 13,
          ),
        ),
      );
    }
    return _CalendarWidget(
      month: _calendarMonth,
      data: _calendarData,
      onDayTap: _onDayTap,
      onPrevMonth: _prevMonth,
      onNextMonth: _nextMonth,
    );
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
        title: const Text('QAudit',
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
                    icon: Icons.folder_copy_rounded,
                    title: 'Modelos',
                    onTap: () => _navigate(const ModelsScreen()),
                  ),
                if (CompanyContextService.instance.hasModule('auditoria'))
                  _drawerItem(
                    icon: Icons.playlist_add_check_rounded,
                    title: 'Auditorias',
                    onTap: () => _navigate(AuditsScreen(
                      currentUserId: _authService.currentUser?.id ?? '',
                      currentUserName: _name,
                    )),
                  ),
                if (CompanyContextService.instance.hasModule('checklist'))
                  _drawerItem(
                    icon: Icons.checklist_rounded,
                    title: 'Checklist',
                    onTap: () => _navigate(ChecklistsScreen(
                      currentUserId: _authService.currentUser?.id ?? '',
                    )),
                  ),
                _drawerItem(
                  icon: Icons.assignment_late_outlined,
                  title: 'Ações Corretivas',
                  badgeCount: _openActions,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                          builder: (_) => CorrectiveActionsScreen(
                            currentUserId:
                                _authService.currentUser?.id ?? '',
                            currentUserRole: _role,
                          ),
                        ))
                        .then((_) => _loadDashboard());
                  },
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
    int badgeCount = 0,
  }) {
    final itemColor = color ?? AppTheme.of(context).textPrimary;
    Widget iconWidget = Icon(icon, color: itemColor, size: 22);
    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text('$badgeCount'),
        child: iconWidget,
      );
    }
    return ListTile(
      onTap: onTap,
      leading: iconWidget,
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
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
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

            // Linha 1: Total + Pendentes
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    icon: Icons.assignment_rounded,
                    label: 'Total',
                    value: _dashboardLoading ? '...' : '$_totalAudits',
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCard(
                    icon: Icons.pending_rounded,
                    label: 'Pendentes',
                    value: _dashboardLoading ? '...' : '$_pendingAudits',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Linha 2: Atrasadas + Ações abertas (ou Empresas para superuser/dev)
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    icon: Icons.warning_rounded,
                    label: 'Atrasadas',
                    value: _dashboardLoading ? '...' : '$_overdueAudits',
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 8),
                // D-07: isSuperOrDev (NOT canAccessAdmin) for Empresas card
                Expanded(
                  child: AppRole.isSuperOrDev(_role)
                      ? _summaryCard(
                          icon: Icons.business_rounded,
                          label: 'Empresas',
                          value: _dashboardLoading ? '...' : '$_companiesCount',
                          color: Colors.purple,
                        )
                      : _summaryCard(
                          // D-04: always render, value 0 until Phase 8 creates corrective_actions
                          icon: Icons.task_alt_rounded,
                          label: 'Ações abertas',
                          value: _dashboardLoading ? '...' : '$_openActions',
                          color: Colors.teal,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Calendário de Auditorias',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.of(context).textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildCalendar(),
          ],
        ),
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
              borderRadius: BorderRadius.circular(8),
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

// ── Calendar private widgets ───────────────────────────────────────────────────

const _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

class _CalendarWidget extends StatelessWidget {
  final DateTime month;
  final Map<String, List<Audit>> data;
  final void Function(DateTime) onDayTap;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  const _CalendarWidget({
    required this.month,
    required this.data,
    required this.onDayTap,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  int _daysInMonth(int year, int m) => DateTime(year, m + 1, 0).day;

  int _firstWeekdayOffset(int year, int m) {
    // Dart weekday: Mon=1, Sun=7. Calendar is Sunday-first (offset 0).
    final wd = DateTime(year, m, 1).weekday;
    return wd == 7 ? 0 : wd;
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, "0")}-'
      '${d.day.toString().padLeft(2, "0")}';

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final monthLabel = '${_monthNames[month.month - 1]} ${month.year}';

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Month navigation header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.primary,
                onPressed: onPrevMonth,
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.primary,
                onPressed: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Weekday headers: Dom Seg Ter Qua Qui Sex Sáb
          Row(
            children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
                .map(
                  (d) => Expanded(
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          // Day grid
          _buildGrid(context),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final today = DateTime.now();
    final daysCount = _daysInMonth(month.year, month.month);
    final offset = _firstWeekdayOffset(month.year, month.month);
    // Build flat list: null = padding cell, int = day number
    final cells = <int?>[
      ...List<int?>.filled(offset, null),
      ...List.generate(daysCount, (i) => i + 1),
    ];
    // Pad to multiple of 7
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final rows = <TableRow>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(TableRow(
        children: List.generate(7, (j) {
          final day = cells[i + j];
          if (day == null) return const SizedBox(height: 52);
          final date = DateTime(month.year, month.month, day);
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
          final key = _dateKey(date);
          final dayAudits = data[key] ?? [];
          return _DayCell(
            day: day,
            isToday: isToday,
            audits: dayAudits,
            onTap: dayAudits.isNotEmpty ? () => onDayTap(date) : null,
          );
        }),
      ));
    }
    return Table(
      defaultColumnWidth: const FlexColumnWidth(),
      children: rows,
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final List<Audit> audits;
  final VoidCallback? onTap; // null = not tappable (D-06)

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.audits,
    this.onTap,
  });

  int _novas() => audits
      .where((a) =>
          a.status == AuditStatus.rascunho ||
          a.status == AuditStatus.emAndamento)
      .length;

  int _atrasadas() =>
      audits.where((a) => a.status == AuditStatus.atrasada).length;

  int _concluidas() =>
      audits.where((a) => a.status == AuditStatus.concluida).length;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final hasAudits = audits.isNotEmpty;
    final novas = _novas();
    final atrasadas = _atrasadas();
    final concluidas = _concluidas();

    Widget dayNumber = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isToday
            ? AppColors.accent
            : (hasAudits ? t.surface : Colors.transparent),
        border: isToday
            ? null
            : (hasAudits ? Border.all(color: t.divider) : null),
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isToday
                ? Colors.white
                : (hasAudits ? t.textPrimary : t.textSecondary),
          ),
        ),
      ),
    );

    Widget dotRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (novas > 0)
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
            ),
          ),
        if (novas > 0 && (atrasadas > 0 || concluidas > 0))
          const SizedBox(width: 4),
        if (atrasadas > 0)
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error,
            ),
          ),
        if (atrasadas > 0 && concluidas > 0) const SizedBox(width: 4),
        if (concluidas > 0)
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
            ),
          ),
        // If no dots, reserve space to maintain cell height
        if (novas == 0 && atrasadas == 0 && concluidas == 0)
          const SizedBox(height: 10),
      ],
    );

    Widget cell = SizedBox(
      height: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          dayNumber,
          const SizedBox(height: 4),
          dotRow,
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: cell);
    }
    return cell;
  }
}

