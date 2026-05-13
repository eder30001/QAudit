import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sincronização proativa offline.
///
/// Chamado pelo HomeScreen ao inicializar e ao reconectar.
/// Salva os dados em SharedPreferences com as mesmas chaves usadas pelos
/// métodos getCached() de cada serviço, que caem no cache quando offline.
class SyncService {
  static final _instance = SyncService._();
  static SyncService get instance => _instance;
  SyncService._();

  final _client = Supabase.instance.client;
  bool _syncing = false;

  // ── Chaves públicas ────────────────────────────────
  // As chaves de tipos/templates coincidem com AuditTemplateService para
  // reutilizar o fallback já existente em getTypesCached/getTemplatesCached.
  static String auditTypesKey(String? companyId) =>
      'cache_audit_types_${companyId ?? 'global'}';

  static String auditTemplatesKey(String typeId, String? companyId) =>
      'cache_audit_templates_${typeId}_${companyId ?? 'global'}';

  static String auditsKey(String? companyId) =>
      'sync_audits_${companyId ?? 'any'}';

  static String correctiveActionsKey(String? companyId) =>
      'sync_ca_${companyId ?? 'any'}';

  static String checklistTemplatesKey() => 'sync_cl_templates';

  static String checklistExecutionsKey(String? companyId) =>
      'sync_cl_exec_${companyId ?? 'any'}';

  static String perimetersKey(String? companyId) =>
      'sync_perimeters_${companyId ?? 'any'}';

  // ── Sync principal ─────────────────────────────────
  Future<void> syncAll(String? companyId) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        _syncAuditTypes(prefs, companyId),
        _syncAllAuditTemplates(prefs, companyId),
        _syncAudits(prefs, companyId),
        _syncCorrectiveActions(prefs, companyId),
        _syncChecklistTemplates(prefs),
        _syncChecklistExecutions(prefs, companyId),
        _syncPerimeters(prefs, companyId),
      ], eagerError: false);
    } finally {
      _syncing = false;
    }
  }

  // ── Sync individuais ───────────────────────────────
  Future<void> _syncAuditTypes(SharedPreferences prefs, String? companyId) async {
    try {
      var q = _client.from('audit_types').select();
      if (companyId != null) {
        q = q.or('company_id.is.null,company_id.eq.$companyId');
      } else {
        q = q.filter('company_id', 'is', null);
      }
      final data = await q.eq('active', true).order('name');
      await prefs.setString(auditTypesKey(companyId), jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _syncAllAuditTemplates(SharedPreferences prefs, String? companyId) async {
    try {
      var q = _client
          .from('audit_templates')
          .select('*, audit_types(name, icon)');
      if (companyId != null) {
        q = q.or('company_id.is.null,company_id.eq.$companyId');
      } else {
        q = q.filter('company_id', 'is', null);
      }
      final allData = await q.order('name') as List;

      // Agrupa por type_id e salva com a mesma chave que getTemplatesCached usa,
      // garantindo que TODOS os templates fiquem no cache antes de abrir a sheet.
      final Map<String, List<dynamic>> byType = {};
      for (final row in allData) {
        final typeId = row['type_id'] as String;
        byType.putIfAbsent(typeId, () => []).add(row);
      }
      for (final entry in byType.entries) {
        await prefs.setString(
          auditTemplatesKey(entry.key, companyId),
          jsonEncode(entry.value),
        );
      }
    } catch (_) {}
  }

  Future<void> _syncAudits(SharedPreferences prefs, String? companyId) async {
    try {
      const select = '''
        *,
        audit_types(name, icon, color),
        audit_templates(name),
        companies(name, requires_perimeter),
        perimeters(name),
        auditor:profiles!auditor_id(full_name)
      ''';
      var q = _client.from('audits').select(select);
      if (companyId != null) q = q.eq('company_id', companyId);
      final data = await q.order('created_at', ascending: false);
      await prefs.setString(auditsKey(companyId), jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _syncCorrectiveActions(SharedPreferences prefs, String? companyId) async {
    try {
      var q = _client
          .from('corrective_actions')
          .select('*, profiles!responsible_user_id(full_name), audits(title)');
      if (companyId != null) q = q.eq('company_id', companyId);
      final data = await q.order('created_at', ascending: false);
      await prefs.setString(correctiveActionsKey(companyId), jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _syncChecklistTemplates(SharedPreferences prefs) async {
    try {
      final data = await _client
          .from('checklist_templates')
          .select()
          .order('name');
      await prefs.setString(checklistTemplatesKey(), jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _syncChecklistExecutions(SharedPreferences prefs, String? companyId) async {
    try {
      const select = '*, checklist_templates(name)';
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      final List data;
      if (companyId != null) {
        data = await _client
            .from('checklist_executions')
            .select(select)
            .eq('company_id', companyId)
            .order('created_at', ascending: false);
      } else {
        data = await _client
            .from('checklist_executions')
            .select(select)
            .eq('created_by', userId)
            .order('created_at', ascending: false);
      }
      await prefs.setString(checklistExecutionsKey(companyId), jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _syncPerimeters(SharedPreferences prefs, String? companyId) async {
    if (companyId == null) return;
    try {
      final data = await _client
          .from('perimeters')
          .select()
          .eq('company_id', companyId)
          .order('name');
      await prefs.setString(perimetersKey(companyId), jsonEncode(data));
    } catch (_) {}
  }
}
