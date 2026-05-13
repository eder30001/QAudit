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

  String? get activeCompanyId => _activeCompanyId;
  String? get activeCompanyName => _activeCompanyName;

  /// Chame após carregar o perfil do usuário logado.
  Future<void> init({
    required String role,
    String? profileCompanyId,
    String? profileCompanyName,
  }) async {
    if (AppRole.isSuperOrDev(role)) {
      final prefs = await SharedPreferences.getInstance();
      _activeCompanyId = prefs.getString('ctx_company_id');
      _activeCompanyName = prefs.getString('ctx_company_name');
    } else {
      _activeCompanyId = profileCompanyId;
      _activeCompanyName = profileCompanyName;
    }
  }

  /// Persiste a empresa ativa. Passe null para "todas as organizações".
  Future<void> setActiveCompany(String? id, String? name) async {
    _activeCompanyId = id;
    _activeCompanyName = name;
    final prefs = await SharedPreferences.getInstance();
    if (id != null) {
      await prefs.setString('ctx_company_id', id);
      await prefs.setString('ctx_company_name', name ?? '');
    } else {
      await prefs.remove('ctx_company_id');
      await prefs.remove('ctx_company_name');
    }
  }

  /// Limpa ao fazer logout.
  Future<void> clear() async {
    _activeCompanyId = null;
    _activeCompanyName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ctx_company_id');
    await prefs.remove('ctx_company_name');
  }
}
