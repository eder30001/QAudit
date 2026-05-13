import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_roles.dart';
import '../models/app_user.dart';

/// CRUD de usuários (tabela `profiles`) com filtro por papel do usuário logado.
///
/// Superuser/dev veem todos os usuários; adm vê apenas os da sua empresa.
class UserService {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>> _getMyProfile() async {
    return await _client
        .from('profiles')
        .select('role, company_id')
        .eq('id', _client.auth.currentUser!.id)
        .single();
  }

  Future<List<AppUser>> getAll() async {
    final me = await _getMyProfile();
    final myRole = me['role'] as String;
    final myCompanyId = me['company_id'] as String?;

    var query = _client.from('profiles').select('*, companies(name)');

    // Adm vê apenas usuários da sua empresa
    if (myRole == AppRole.adm) {
      if (myCompanyId == null) return [];
      query = query.eq('company_id', myCompanyId);
    }

    final data = await query.order('full_name');
    return (data as List).map((e) => AppUser.fromMap(e)).toList();
  }

  Future<void> updateRole(String userId, String role) async {
    await _client
        .from('profiles')
        .update({'role': role})
        .eq('id', userId);
  }

  Future<void> updateCompany(String userId, String? companyId) async {
    await _client
        .from('profiles')
        .update({'company_id': companyId})
        .eq('id', userId);
  }

  Future<void> toggleActive(String userId, bool active) async {
    await _client
        .from('profiles')
        .update({'active': active})
        .eq('id', userId);
  }

  Future<String> getMyRole() async {
    final me = await _getMyProfile();
    return me['role'] as String;
  }

  Future<Map<String, dynamic>> getMyProfile() => _getMyProfile();

  Future<void> updateFullName(String userId, String fullName) async {
    await _client
        .from('profiles')
        .update({'full_name': fullName})
        .eq('id', userId);
  }

  Future<AppUser> getById(String id) async {
    final data = await _client
        .from('profiles')
        .select('*, companies(name)')
        .eq('id', id)
        .single();
    return AppUser.fromMap(data);
  }
}
