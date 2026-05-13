import 'package:shared_preferences/shared_preferences.dart';

/// Persiste preferências do usuário usando SharedPreferences.
///
/// Cobre três grupos de configurações:
/// - **Aparência**: tema (claro/escuro/sistema)
/// - **Notificações**: alertas de atribuição, prazo e relatórios
/// - **Auditoria**: prazo padrão, conformidade mínima, justificativa e edição pós-envio
class SettingsService {
  static const _keyTheme = 'settings_theme';
  static const _keyNotifAssigned = 'settings_notif_assigned';
  static const _keyNotifDeadline = 'settings_notif_deadline';
  static const _keyNotifReports = 'settings_notif_reports';
  static const _keyAuditDefaultDays = 'settings_audit_default_days';
  static const _keyAuditMinCompliance = 'settings_audit_min_compliance';
  static const _keyAuditRequireJustification = 'settings_audit_require_justification';
  static const _keyAuditAllowEditAfterSubmit = 'settings_audit_allow_edit_after_submit';
  static const _keySystemMaintenance = 'settings_system_maintenance';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // Aparência
  Future<String> getTheme() async => (await _prefs).getString(_keyTheme) ?? 'system';
  Future<void> setTheme(String value) async => (await _prefs).setString(_keyTheme, value);

  // Notificações
  Future<bool> getNotifAssigned() async => (await _prefs).getBool(_keyNotifAssigned) ?? true;
  Future<void> setNotifAssigned(bool v) async => (await _prefs).setBool(_keyNotifAssigned, v);

  Future<bool> getNotifDeadline() async => (await _prefs).getBool(_keyNotifDeadline) ?? true;
  Future<void> setNotifDeadline(bool v) async => (await _prefs).setBool(_keyNotifDeadline, v);

  Future<bool> getNotifReports() async => (await _prefs).getBool(_keyNotifReports) ?? true;
  Future<void> setNotifReports(bool v) async => (await _prefs).setBool(_keyNotifReports, v);

  // Auditoria
  Future<int> getAuditDefaultDays() async => (await _prefs).getInt(_keyAuditDefaultDays) ?? 30;
  Future<void> setAuditDefaultDays(int v) async => (await _prefs).setInt(_keyAuditDefaultDays, v);

  Future<int> getAuditMinCompliance() async => (await _prefs).getInt(_keyAuditMinCompliance) ?? 80;
  Future<void> setAuditMinCompliance(int v) async => (await _prefs).setInt(_keyAuditMinCompliance, v);

  Future<bool> getAuditRequireJustification() async =>
      (await _prefs).getBool(_keyAuditRequireJustification) ?? false;
  Future<void> setAuditRequireJustification(bool v) async =>
      (await _prefs).setBool(_keyAuditRequireJustification, v);

  Future<bool> getAuditAllowEditAfterSubmit() async =>
      (await _prefs).getBool(_keyAuditAllowEditAfterSubmit) ?? false;
  Future<void> setAuditAllowEditAfterSubmit(bool v) async =>
      (await _prefs).setBool(_keyAuditAllowEditAfterSubmit, v);

  // Sistema
  Future<bool> getSystemMaintenance() async =>
      (await _prefs).getBool(_keySystemMaintenance) ?? false;
  Future<void> setSystemMaintenance(bool v) async =>
      (await _prefs).setBool(_keySystemMaintenance, v);
}
