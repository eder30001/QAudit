import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/checklist_template.dart';
import 'sync_service.dart';

/// Serviço de CRUD para templates de checklist.
///
/// Módulo independente — não usa nem modifica [AuditTemplateService].
/// Callers são responsáveis por try/catch; este serviço não suprime exceções.
/// Exceção: [cloneTemplate] captura erros de inserção de itens para fazer rollback
/// e depois faz rethrow.
class ChecklistTemplateService {
  final _client = Supabase.instance.client;

  // ── Queries ────────────────────────────────────────────────────────────────

  /// Retorna templates da categoria especificada (seeds + próprios do usuário).
  /// Usado nas abas Industrial e Transportadora.
  Future<List<ChecklistTemplate>> getByCategory(String category) async {
    // RLS SELECT policy enforces (is_padrao = true OR created_by = auth.uid()) server-side.
    // Use simple .eq() filter — no client-side .or() needed (consistent with codebase pattern).
    final data = await _client
        .from('checklist_templates')
        .select()
        .eq('category', category)
        .order('name');
    return (data as List).map((e) => ChecklistTemplate.fromMap(e)).toList();
  }

  /// Variante com fallback offline usando cache do SyncService.
  Future<List<ChecklistTemplate>> getAllCached() async {
    try {
      return await getAll();
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(SyncService.checklistTemplatesKey());
      if (raw != null) {
        return (jsonDecode(raw) as List)
            .map((e) => ChecklistTemplate.fromMap(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  /// Retorna todos os templates visíveis ao usuário (seeds + próprios).
  Future<List<ChecklistTemplate>> getAll() async {
    final data = await _client
        .from('checklist_templates')
        .select()
        .order('name');
    return (data as List).map((e) => ChecklistTemplate.fromMap(e)).toList();
  }

  /// Retorna templates criados pelo usuário atual (aba "Meus checklists").
  Future<List<ChecklistTemplate>> getOwned() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _client
        .from('checklist_templates')
        .select()
        .eq('created_by', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => ChecklistTemplate.fromMap(e)).toList();
  }

  /// Retorna itens de um template ordenados por order_index.
  Future<List<ChecklistTemplateItem>> getItems(String templateId) async {
    final data = await _client
        .from('checklist_template_items')
        .select()
        .eq('template_id', templateId)
        .order('order_index');
    return (data as List).map((e) => ChecklistTemplateItem.fromMap(e)).toList();
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Cria um novo template customizado (is_padrao = false).
  Future<ChecklistTemplate> createTemplate({
    required String name,
    required String category,
    String? description,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final result = await _client
        .from('checklist_templates')
        .insert({
          'name': name,
          'category': category,
          'description': description,
          'is_padrao': false,
          'created_by': userId,
        })
        .select()
        .single();
    return ChecklistTemplate.fromMap(result);
  }

  /// Insere uma lista de itens para um template.
  /// Usa batch insert (PostgREST aceita List<Map>).
  Future<void> createItems(String templateId, List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final itemsWithTemplateId = items.asMap().entries.map((e) => {
      'template_id': templateId,
      'description': e.value['description'] as String,
      'item_type': e.value['item_type'] as String,
      'order_index': e.key,
    }).toList();
    await _client.from('checklist_template_items').insert(itemsWithTemplateId);
  }

  /// Atualiza metadados de um template (nome, categoria, descrição).
  Future<void> updateTemplate(
    String id, {
    required String name,
    required String category,
    String? description,
  }) async {
    await _client
        .from('checklist_templates')
        .update({
          'name': name,
          'category': category,
          'description': description,
        })
        .eq('id', id);
  }

  /// Substitui os itens de um template: deleta todos os existentes e re-insere.
  /// Usa order_index 0..n-1 baseado na posição atual da lista (evita Pitfall #5).
  Future<void> replaceItems(String templateId, List<Map<String, dynamic>> items) async {
    await _client
        .from('checklist_template_items')
        .delete()
        .eq('template_id', templateId);
    await createItems(templateId, items);
  }

  /// Exclui um template. ON DELETE CASCADE remove os itens automaticamente.
  /// RLS garante que apenas o criador pode excluir e que seeds são protegidos.
  Future<void> deleteTemplate(String id) async {
    await _client.from('checklist_templates').delete().eq('id', id);
  }

  // ── Clone ──────────────────────────────────────────────────────────────────

  /// Clona um template (seed ou próprio) para o usuário atual.
  ///
  /// Sequência obrigatória (evita FK órfão — STATE.md Pitfall #3):
  /// 1. Inserir header do novo template
  /// 2. Buscar itens do template de origem
  /// 3. Inserir itens com o novo template_id
  /// Em caso de falha no passo 3, deleta o header (CASCADE remove itens parciais)
  /// e faz rethrow para o caller tratar.
  Future<ChecklistTemplate> cloneTemplate(ChecklistTemplate source) async {
    final userId = _client.auth.currentUser!.id;

    // Passo 1: criar header do clone
    final newTemplateResult = await _client
        .from('checklist_templates')
        .insert({
          'name': '${source.name} (cópia)',
          'category': source.category,
          'description': source.description,
          'is_padrao': false,
          'created_by': userId,
        })
        .select()
        .single();
    final newTemplate = ChecklistTemplate.fromMap(newTemplateResult);

    // Passo 2: buscar itens do template de origem
    final sourceItems = await getItems(source.id);

    // Passo 3: inserir itens — rollback do header em caso de falha
    try {
      if (sourceItems.isNotEmpty) {
        final itemMaps = sourceItems.asMap().entries.map((e) => {
          'template_id': newTemplate.id,
          'description': e.value.description,
          'item_type': e.value.itemType,
          'order_index': e.key,
        }).toList();
        await _client.from('checklist_template_items').insert(itemMaps);
      }
      return newTemplate;
    } catch (e) {
      // Rollback: deleta o header órfão (CASCADE remove quaisquer itens parciais)
      await _client.from('checklist_templates').delete().eq('id', newTemplate.id);
      rethrow;
    }
  }
}
