import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_roles.dart';
import '../models/company.dart';

/// CRUD de empresas com filtro por papel do usuário logado.
///
/// Superuser/dev veem todas as empresas; adm vê apenas a sua própria.
class CompanyService {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>> _getMyProfile() async {
    return await _client
        .from('profiles')
        .select('role, company_id')
        .eq('id', _client.auth.currentUser!.id)
        .single();
  }

  Future<List<Company>> getAll() async {
    final me = await _getMyProfile();
    final myRole = me['role'] as String;
    final myCompanyId = me['company_id'] as String?;

    var query = _client.from('companies').select();

    // Adm vê apenas a sua empresa
    if (myRole == AppRole.adm) {
      if (myCompanyId == null) return [];
      query = query.eq('id', myCompanyId);
    }

    final data = await query.order('name');
    return (data as List).map((e) => Company.fromMap(e)).toList();
  }

  Future<Company> create(Map<String, dynamic> data) async {
    final result = await _client
        .from('companies')
        .insert(data)
        .select()
        .single();
    return Company.fromMap(result);
  }

  Future<Company> update(String id, Map<String, dynamic> data) async {
    final result = await _client
        .from('companies')
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return Company.fromMap(result);
  }

  Future<void> toggleActive(String id, bool active) async {
    await _client
        .from('companies')
        .update({'active': active})
        .eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('companies').delete().eq('id', id);
  }

  Future<Company?> findByCnpj(String cnpj) async {
    final clean = cnpj.replaceAll(RegExp(r'[.\-/]'), '');
    final data = await _client
        .from('companies')
        .select()
        .eq('active', true)
        .or('cnpj.eq.$cnpj,cnpj.eq.$clean')
        .maybeSingle();
    return data != null ? Company.fromMap(data) : null;
  }
}
