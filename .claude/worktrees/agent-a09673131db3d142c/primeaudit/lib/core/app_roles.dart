/// Define os papéis (roles) do sistema e utilitários de verificação de permissão.
///
/// Hierarquia de acesso (do maior para o menor):
///   superuser > dev > adm > auditor > anonymous
class AppRole {
  static const String superuser = 'superuser'; // Acesso total, sem restrições
  static const String dev = 'dev';             // Igual ao superuser, uso interno de desenvolvimento
  static const String adm = 'adm';             // Administrador de empresa: gerencia usuários e dados da sua empresa
  static const String auditor = 'auditor';     // Executa auditorias; sem acesso ao painel admin
  static const String anonymous = 'anonymous'; // Acesso mínimo, sem empresa vinculada

  /// Lista completa de papéis válidos.
  static const List<String> all = [superuser, dev, adm, auditor, anonymous];

  /// Retorna o rótulo legível do papel para exibição na UI.
  static String label(String role) {
    switch (role) {
      case superuser:
        return 'Super Usuário';
      case dev:
        return 'Desenvolvedor';
      case adm:
        return 'Administrador';
      case auditor:
        return 'Auditor';
      case anonymous:
        return 'Anônimo';
      default:
        return role;
    }
  }

  /// Retorna true se o papel tem acesso ao painel administrativo (AdminScreen).
  static bool canAccessAdmin(String role) =>
      role == superuser || role == dev || role == adm;

  /// Retorna true se o papel tem acesso às funcionalidades de desenvolvimento.
  static bool canAccessDev(String role) => role == superuser || role == dev;

  /// Retorna true para superuser e dev — papéis que podem alternar entre empresas.
  static bool isSuperOrDev(String role) => role == superuser || role == dev;
}
