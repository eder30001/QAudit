import 'package:supabase_flutter/supabase_flutter.dart';

/// Gerencia autenticação via Supabase Auth.
///
/// Além do login padrão, verifica se o usuário está ativo na tabela `profiles`
/// e recusa o acesso caso [active] == false.
class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  bool get isLoggedIn => currentUser != null;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // Verifica se o usuário está ativo
    if (response.user != null) {
      final profile = await _client
          .from('profiles')
          .select('active')
          .eq('id', response.user!.id)
          .maybeSingle();

      if (profile != null && profile['active'] == false) {
        await _client.auth.signOut();
        throw AuthException('Usuário desativado. Entre em contato com o administrador.');
      }
    }

    return response;
  }

  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
    String? companyId,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );

    // Vincula a empresa ao perfil se fornecida
    if (response.user != null && companyId != null) {
      await _client
          .from('profiles')
          .update({'company_id': companyId})
          .eq('id', response.user!.id);
    }

    return response;
  }

  Future<String> getUserRole() async {
    final user = currentUser;
    if (user == null) return '';
    final profile = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();
    return profile['role'] as String;
  }

  Future<void> changePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
