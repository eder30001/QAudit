/// Representa uma empresa cadastrada no sistema.
///
/// Mapeado da tabela `companies`. Empresas são criadas por superuser/dev/adm
/// e agrupam usuários, templates e perímetros.
class Company {
  final String id;
  final String name;
  final String? cnpj;
  final String? email;
  final String? phone;
  final String? address;
  final bool active;
  final bool requiresPerimeter; // Se true, auditorias exigem seleção de perímetro
  final DateTime createdAt;

  Company({
    required this.id,
    required this.name,
    this.cnpj,
    this.email,
    this.phone,
    this.address,
    required this.active,
    required this.requiresPerimeter,
    required this.createdAt,
  });

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'],
      name: map['name'],
      cnpj: map['cnpj'],
      email: map['email'],
      phone: map['phone'],
      address: map['address'],
      active: map['active'] ?? true,
      requiresPerimeter: map['requires_perimeter'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cnpj': cnpj,
      'email': email,
      'phone': phone,
      'address': address,
      'active': active,
      'requires_perimeter': requiresPerimeter,
    };
  }
}
