/// Representa um perímetro (área/setor) dentro de uma empresa.
///
/// Mapeado da tabela `perimeters`. Perímetros formam uma hierarquia em árvore:
/// um perímetro pode ter um [parentId] apontando para outro perímetro da mesma empresa.
/// Usado para localizar auditorias quando [Company.requiresPerimeter] é true.
class Perimeter {
  final String id;
  final String companyId;
  final String? parentId;   // Null = nó raiz da árvore
  final String name;
  final String? description;
  final bool active;
  final DateTime createdAt;
  List<Perimeter> children; // Populado em memória via [buildTree]

  Perimeter({
    required this.id,
    required this.companyId,
    this.parentId,
    required this.name,
    this.description,
    required this.active,
    required this.createdAt,
    this.children = const [],
  });

  factory Perimeter.fromMap(Map<String, dynamic> map) {
    return Perimeter(
      id: map['id'],
      companyId: map['company_id'],
      parentId: map['parent_id'],
      name: map['name'],
      description: map['description'],
      active: map['active'] ?? true,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // Constrói árvore a partir de lista plana
  static List<Perimeter> buildTree(List<Perimeter> flat) {
    final map = {for (final p in flat) p.id: p};
    final roots = <Perimeter>[];

    for (final p in flat) {
      p.children = [];
    }
    for (final p in flat) {
      if (p.parentId == null) {
        roots.add(p);
      } else {
        map[p.parentId]?.children.add(p);
      }
    }
    return roots;
  }

  int get depth {
    if (parentId == null) return 0;
    return 1; // será calculado dinamicamente na UI
  }
}
