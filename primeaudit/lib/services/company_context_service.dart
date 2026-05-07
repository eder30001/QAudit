import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_roles.dart';

/// Singleton que mantém o contexto de empresa ativo.
/// Superuser/Dev podem alternar entre empresas; outros papéis usam a empresa do perfil.
class CompanyContextService {
  static final CompanyContextService _instance = CompanyContextService._();
  static CompanyContextService get instance => _instance;
  CompanyContextService._();

  String? _activeCompanyId;
  String? _activeCompanyName;
  String _activeCompanySegment = 'industrial';
  List<String> _activeCompanyModules = ['auditoria', 'checklist'];

  String? get activeCompanyId => _activeCompanyId;
  String? get activeCompanyName => _activeCompanyName;
  String get activeCompanySegment => _activeCompanySegment;
  List<String> get activeCompanyModules => _activeCompanyModules;
  bool hasModule(String module) => _activeCompanyModules.contains(module);

  /// Chame após carregar o perfil do usuário logado.
  Future<void> init({
    required String role,
    String? profileCompanyId,
    String? profileCompanyName,
    String profileCompanySegment = 'industrial',
    List<String> profileCompanyModules = const ['auditoria', 'checklist'],
  }) async {
    if (AppRole.isSuperOrDev(role)) {
      final prefs = await SharedPreferences.getInstance();
      _activeCompanyId = prefs.getString('ctx_company_id');
      _activeCompanyName = prefs.getString('ctx_company_name');
      _activeCompanySegment = prefs.getString('ctx_company_segment') ?? 'industrial';
      final modulesRaw = prefs.getString('ctx_company_modules');
      _activeCompanyModules = modulesRaw != null
          ? modulesRaw.split(',').where((m) => m.isNotEmpty).toList()
          : ['auditoria', 'checklist'];
    } else {
      _activeCompanyId = profileCompanyId;
      _activeCompanyName = profileCompanyName;
      _activeCompanySegment = profileCompanySegment;
      _activeCompanyModules = profileCompanyModules;
    }
  }

  /// Atualiza segment e modules na sessão ativa (sem trocar de empresa).
  void updateCompanyMeta({required String segment, required List<String> modules}) {
    _activeCompanySegment = segment;
    _activeCompanyModules = modules;
  }

  /// Persiste a empresa ativa. Passe null para "todas as organizações".
  Future<void> setActiveCompany(
    String? id,
    String? name, {
    String segment = 'industrial',
    List<String> modules = const ['auditoria', 'checklist'],
  }) async {
    _activeCompanyId = id;
    _activeCompanyName = name;
    _activeCompanySegment = segment;
    _activeCompanyModules = modules;
    final prefs = await SharedPreferences.getInstance();
    if (id != null) {
      await prefs.setString('ctx_company_id', id);
      await prefs.setString('ctx_company_name', name ?? '');
      await prefs.setString('ctx_company_segment', segment);
      await prefs.setString('ctx_company_modules', modules.join(','));
    } else {
      await prefs.remove('ctx_company_id');
      await prefs.remove('ctx_company_name');
      await prefs.remove('ctx_company_segment');
      await prefs.remove('ctx_company_modules');
    }
  }

  /// Limpa ao fazer logout.
  Future<void> clear() async {
    _activeCompanyId = null;
    _activeCompanyName = null;
    _activeCompanySegment = 'industrial';
    _activeCompanyModules = ['auditoria', 'checklist'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ctx_company_id');
    await prefs.remove('ctx_company_name');
    await prefs.remove('ctx_company_segment');
    await prefs.remove('ctx_company_modules');
  }
}
