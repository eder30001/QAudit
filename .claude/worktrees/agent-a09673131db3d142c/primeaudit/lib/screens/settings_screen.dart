import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_roles.dart';
import '../core/app_theme.dart';
import '../main.dart' show appThemeMode, themeFromString;
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _userService = UserService();
  final _authService = AuthService();

  String _role = '';
  bool _loading = true;

  // Aparência
  String _theme = 'system';

  // Notificações
  bool _notifAssigned = true;
  bool _notifDeadline = true;
  bool _notifReports = true;

  // Auditoria
  int _auditDefaultDays = 30;
  int _auditMinCompliance = 80;
  bool _auditRequireJustification = false;
  bool _auditAllowEditAfterSubmit = false;

  // Sistema
  bool _systemMaintenance = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final profile = await _userService.getById(user.id);
        _role = profile.role;
      }

      _theme = await _settings.getTheme();
      _notifAssigned = await _settings.getNotifAssigned();
      _notifDeadline = await _settings.getNotifDeadline();
      _notifReports = await _settings.getNotifReports();
      _auditDefaultDays = await _settings.getAuditDefaultDays();
      _auditMinCompliance = await _settings.getAuditMinCompliance();
      _auditRequireJustification = await _settings.getAuditRequireJustification();
      _auditAllowEditAfterSubmit = await _settings.getAuditAllowEditAfterSubmit();
      _systemMaintenance = await _settings.getSystemMaintenance();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green[700],
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
        title: const Text('Configurações',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAppearanceSection(),
                const SizedBox(height: 16),
                _buildNotificationsSection(),
                if (AppRole.canAccessAdmin(_role)) ...[
                  const SizedBox(height: 16),
                  _buildAuditSection(),
                ],
                if (AppRole.isSuperOrDev(_role)) ...[
                  const SizedBox(height: 16),
                  _buildSystemSection(),
                ],
                const SizedBox(height: 16),
                _buildAboutSection(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // ── Aparência ──────────────────────────────────────────────────────────────

  Widget _buildAppearanceSection() {
    return _sectionCard(
      title: 'Aparência',
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tema do aplicativo',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.of(context).textPrimary),
          ),
          const SizedBox(height: 10),
          _themeOption(
            value: 'light',
            label: 'Claro',
            icon: Icons.light_mode_outlined,
          ),
          _themeOption(
            value: 'dark',
            label: 'Escuro',
            icon: Icons.dark_mode_outlined,
          ),
          _themeOption(
            value: 'system',
            label: 'Seguir sistema',
            icon: Icons.brightness_auto_outlined,
          ),
        ],
      ),
    );
  }

  Widget _themeOption({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _theme == value;
    return InkWell(
      onTap: () async {
        await _settings.setTheme(value);
        appThemeMode.value = themeFromString(value);
        setState(() => _theme = value);
        _showSuccess('Tema atualizado');
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppTheme.of(context).background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppTheme.of(context).divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? AppColors.primary : AppTheme.of(context).textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected
                          ? AppColors.primary
                          : AppTheme.of(context).textPrimary)),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ── Notificações ───────────────────────────────────────────────────────────

  Widget _buildNotificationsSection() {
    return _sectionCard(
      title: 'Notificações',
      icon: Icons.notifications_outlined,
      child: Column(
        children: [
          _switchTile(
            icon: Icons.assignment_ind_outlined,
            iconColor: AppColors.accent,
            title: 'Auditorias atribuídas a mim',
            subtitle: 'Quando uma nova auditoria for designada para você',
            value: _notifAssigned,
            onChanged: (v) async {
              await _settings.setNotifAssigned(v);
              setState(() => _notifAssigned = v);
            },
          ),
          _divider(),
          _switchTile(
            icon: Icons.schedule_rounded,
            iconColor: Colors.orange,
            title: 'Próximas do prazo',
            subtitle: 'Alertas para auditorias com prazo se aproximando',
            value: _notifDeadline,
            onChanged: (v) async {
              await _settings.setNotifDeadline(v);
              setState(() => _notifDeadline = v);
            },
          ),
          _divider(),
          _switchTile(
            icon: Icons.bar_chart_rounded,
            iconColor: Colors.purple,
            title: 'Relatórios gerados',
            subtitle: 'Quando um relatório estiver disponível para download',
            value: _notifReports,
            onChanged: (v) async {
              await _settings.setNotifReports(v);
              setState(() => _notifReports = v);
            },
          ),
        ],
      ),
    );
  }

  // ── Auditoria ──────────────────────────────────────────────────────────────

  Widget _buildAuditSection() {
    return _sectionCard(
      title: 'Auditoria',
      icon: Icons.assignment_rounded,
      child: Column(
        children: [
          _tappableTile(
            icon: Icons.calendar_today_outlined,
            iconColor: AppColors.accent,
            title: 'Prazo padrão',
            subtitle: '$_auditDefaultDays dias para conclusão',
            onTap: () => _editDaysDialog(
              title: 'Prazo padrão (dias)',
              value: _auditDefaultDays,
              min: 1,
              max: 365,
              onSave: (v) async {
                await _settings.setAuditDefaultDays(v);
                setState(() => _auditDefaultDays = v);
                _showSuccess('Prazo padrão atualizado');
              },
            ),
          ),
          _divider(),
          _tappableTile(
            icon: Icons.percent_rounded,
            iconColor: Colors.green,
            title: 'Percentual mínimo de conformidade',
            subtitle: '$_auditMinCompliance% para aprovação',
            onTap: () => _editDaysDialog(
              title: 'Conformidade mínima (%)',
              value: _auditMinCompliance,
              min: 1,
              max: 100,
              onSave: (v) async {
                await _settings.setAuditMinCompliance(v);
                setState(() => _auditMinCompliance = v);
                _showSuccess('Percentual mínimo atualizado');
              },
            ),
          ),
          _divider(),
          _switchTile(
            icon: Icons.rate_review_outlined,
            iconColor: Colors.orange,
            title: 'Exigir justificativa',
            subtitle: 'Obrigatório ao registrar não conformidades',
            value: _auditRequireJustification,
            onChanged: (v) async {
              await _settings.setAuditRequireJustification(v);
              setState(() => _auditRequireJustification = v);
            },
          ),
          _divider(),
          _switchTile(
            icon: Icons.edit_note_rounded,
            iconColor: Colors.blueGrey,
            title: 'Permitir edição após envio',
            subtitle: 'Auditor pode editar respostas depois de finalizar',
            value: _auditAllowEditAfterSubmit,
            onChanged: (v) async {
              await _settings.setAuditAllowEditAfterSubmit(v);
              setState(() => _auditAllowEditAfterSubmit = v);
            },
          ),
        ],
      ),
    );
  }

  // ── Sobre ──────────────────────────────────────────────────────────────────

  Widget _buildAboutSection() {
    return _sectionCard(
      title: 'Sobre',
      icon: Icons.info_outline_rounded,
      child: _infoTile(
        icon: Icons.assignment_turned_in_rounded,
        title: 'PrimeAudit',
        value: 'Versão 1.0.0',
      ),
    );
  }

  // ── Sistema ────────────────────────────────────────────────────────────────

  Widget _buildSystemSection() {
    return _sectionCard(
      title: 'Sistema',
      icon: Icons.settings_applications_rounded,
      child: Column(
        children: [
          _switchTile(
            icon: Icons.construction_rounded,
            iconColor: AppColors.error,
            title: 'Modo de manutenção',
            subtitle: 'Bloqueia o acesso de auditores ao sistema',
            value: _systemMaintenance,
            onChanged: (v) => _confirmMaintenance(v),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmMaintenance(bool enable) async {
    if (!enable) {
      await _settings.setSystemMaintenance(false);
      setState(() => _systemMaintenance = false);
      _showSuccess('Modo de manutenção desativado');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ativar modo de manutenção?'),
        content: const Text(
          'Auditores não conseguirão acessar o sistema enquanto este modo estiver ativo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _settings.setSystemMaintenance(true);
      setState(() => _systemMaintenance = true);
      _showSuccess('Modo de manutenção ativado');
    }
  }

  // ── Helpers de UI ──────────────────────────────────────────────────────────

  Future<void> _editDaysDialog({
    required String title,
    required int value,
    required int min,
    required int max,
    required void Function(int) onSave,
  }) async {
    final ctrl = TextEditingController(text: value.toString());
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Valor ($min–$max)',
                  filled: true,
                  fillColor: AppTheme.of(ctx).background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppTheme.of(ctx).divider)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppTheme.of(ctx).divider)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.accent, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null) return 'Informe um número válido';
                  if (n < min || n > max) return 'Deve ser entre $min e $max';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    onSave(int.parse(ctrl.text));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Salvar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.of(context).textPrimary)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.of(context).textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _tappableTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.of(context).textPrimary)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.of(context).textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.of(context).textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.of(context).textPrimary)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.of(context).textSecondary)),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 8, color: AppTheme.of(context).divider);

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
            Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
