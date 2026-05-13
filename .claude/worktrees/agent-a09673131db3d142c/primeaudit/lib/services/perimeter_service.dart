import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/perimeter.dart';

/// CRUD de perímetros de uma empresa.
///
/// Usa [Perimeter.buildTree] para montar a hierarquia em árvore a partir
/// da lista plana retornada pelo banco.
class PerimeterService {
  final _client = Supabase.instance.client;

  Future<List<Perimeter>> getByCompany(String companyId) async {
    final data = await _client
        .from('perimeters')
        .select()
        .eq('company_id', companyId)
        .order('name');
    final flat = (data as List).map((e) => Perimeter.fromMap(e)).toList();
    return flat;
  }

  Future<List<Perimeter>> getTreeByCompany(String companyId) async {
    final flat = await getByCompany(companyId);
    return Perimeter.buildTree(flat);
  }

  Future<Perimeter> create({
    required String companyId,
    String? parentId,
    required String name,
    String? description,
  }) async {
    final result = await _client
        .from('perimeters')
        .insert({
          'company_id': companyId,
          'parent_id': parentId,
          'name': name,
          'description': description,
        })
        .select()
        .single();
    return Perimeter.fromMap(result);
  }

  Future<Perimeter> update(
      String id, String name, String? description) async {
    final result = await _client
        .from('perimeters')
        .update({'name': name, 'description': description})
        .eq('id', id)
        .select()
        .single();
    return Perimeter.fromMap(result);
  }

  Future<void> toggleActive(String id, bool active) async {
    await _client
        .from('perimeters')
        .update({'active': active})
        .eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('perimeters').delete().eq('id', id);
  }
}
