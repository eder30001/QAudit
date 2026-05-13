# Phase 13: DB Foundation + Template Management — Pattern Map

**Mapped:** 2026-05-03
**Files analyzed:** 6 new/modified files
**Analogs found:** 6 / 6

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `primeaudit/supabase/migrations/20260503_create_checklist_templates.sql` | migration | batch | `primeaudit/supabase/migrations/20260406_create_audits.sql` | exact |
| `primeaudit/lib/models/checklist_template.dart` | model | transform | `primeaudit/lib/models/audit_template.dart` | exact |
| `primeaudit/lib/services/checklist_template_service.dart` | service | CRUD | `primeaudit/lib/services/audit_template_service.dart` | exact |
| `primeaudit/lib/screens/checklist/checklist_templates_screen.dart` | screen | request-response | `primeaudit/lib/screens/admin/admin_screen.dart` (tab pattern) + `primeaudit/lib/screens/templates/audit_templates_screen.dart` (card/list/delete pattern) | role-match |
| `primeaudit/lib/screens/checklist/checklist_template_form_screen.dart` | screen | request-response | `primeaudit/lib/screens/templates/audit_templates_screen.dart` (`_showTemplateForm`, `_inputDec`) | role-match |
| `primeaudit/lib/screens/home_screen.dart` (modify) | screen | request-response | `primeaudit/lib/screens/home_screen.dart` lines 340-347 (existing `_drawerItem` calls) | exact |

---

## Pattern Assignments

### `primeaudit/supabase/migrations/20260503_create_checklist_templates.sql` (migration, batch)

**Analog:** `primeaudit/supabase/migrations/20260406_create_audits.sql`

**File header / comment pattern** (lines 1-5):
```sql
-- =============================================================================
-- Migração: tabela audits e ajustes de schema
-- Data: 2026-04-06
-- Idempotente: pode ser executado múltiplas vezes sem erro.
-- =============================================================================
```

**CREATE TABLE IF NOT EXISTS + column-per-ALTER pattern** (lines 29-43):
```sql
CREATE TABLE IF NOT EXISTS audits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);

ALTER TABLE audits ADD COLUMN IF NOT EXISTS title              TEXT;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS audit_type_id      UUID;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS company_id         UUID;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS status             TEXT        NOT NULL DEFAULT 'rascunho';
ALTER TABLE audits ADD COLUMN IF NOT EXISTS created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW();
```

**DROP + ADD constraint (idempotent) pattern** (lines 49-56):
```sql
ALTER TABLE audits DROP CONSTRAINT IF EXISTS audits_audit_type_id_fkey;
ALTER TABLE audits ADD CONSTRAINT audits_audit_type_id_fkey
  FOREIGN KEY (audit_type_id) REFERENCES audit_types(id) ON DELETE RESTRICT;
```

**CHECK constraint (idempotent) pattern** (lines 73-75):
```sql
ALTER TABLE audits DROP CONSTRAINT IF EXISTS audits_status_check;
ALTER TABLE audits ADD CONSTRAINT audits_status_check
  CHECK (status IN ('rascunho','em_andamento','concluida','atrasada','cancelada'));
```

**Index pattern** (lines 85-89):
```sql
CREATE INDEX IF NOT EXISTS idx_audits_company_id  ON audits (company_id);
CREATE INDEX IF NOT EXISTS idx_audits_auditor_id  ON audits (auditor_id);
CREATE INDEX IF NOT EXISTS idx_audits_status      ON audits (status);
```

**RLS enable + DROP/CREATE policies pattern** (lines 95-137):
```sql
ALTER TABLE audits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "superuser_dev_full_access" ON audits;
CREATE POLICY "superuser_dev_full_access" ON audits
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

DROP POLICY IF EXISTS "auditor_select_company" ON audits;
CREATE POLICY "auditor_select_company" ON audits FOR SELECT
  USING (get_my_role() = 'auditor' AND company_id = get_my_company_id());

DROP POLICY IF EXISTS "auditor_insert_own" ON audits;
CREATE POLICY "auditor_insert_own" ON audits FOR INSERT
  WITH CHECK (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
    AND auditor_id = auth.uid()
  );
```

**NOTIFY as last line** (line 180):
```sql
NOTIFY pgrst, 'reload schema';
```

**Key divergence for checklist migration:** The checklist RLS uses `is_padrao` flag (not `company_id IS NULL`) for seed visibility, and `created_by = auth.uid()` (not `auditor_id`) for ownership. The items table RLS uses a subquery via FK instead of a direct `created_by` column. See RESEARCH.md Patterns 2 and 3 for exact policy text.

---

### `primeaudit/lib/models/checklist_template.dart` (model, transform)

**Analog:** `primeaudit/lib/models/audit_template.dart`

**Class structure pattern — no imports (pure Dart)** (line 1 — file starts directly with class doc comment):
```dart
/// Representa um item (pergunta) dentro de um template de auditoria.
///
/// Mapeado da tabela `template_items`.
class TemplateItem {
```
Note: The model file has NO import statements — it is pure Dart. `checklist_template.dart` must follow the same convention (no imports needed since no Color/IconData computed getters are planned for Phase 13).

**Named constructor with required/optional parameters** (lines 17-28):
```dart
TemplateItem({
  required this.id,
  required this.templateId,
  this.sectionId,
  required this.question,
  this.guidance,
  required this.responseType,
  required this.required,
  required this.weight,
  required this.orderIndex,
  this.options = const [],
});
```

**fromMap factory with null-aware defaults** (lines 30-43):
```dart
factory TemplateItem.fromMap(Map<String, dynamic> map) {
  return TemplateItem(
    id: map['id'],
    templateId: map['template_id'],
    sectionId: map['section_id'],
    question: map['question'],
    guidance: map['guidance'],
    responseType: map['response_type'] ?? 'ok_nok',
    required: map['required'] ?? true,
    weight: map['weight'] ?? 1,
    orderIndex: map['order_index'] ?? 0,
    options: (map['options'] as List?)?.cast<String>() ?? [],
  );
}
```

**Computed getter pattern** (lines 45-56, `responseTypeLabel`; and line 129, `isGlobal`):
```dart
bool get isGlobal => companyId == null;
```
For `ChecklistTemplate`, the equivalent is:
```dart
bool get isSeed => isPadrao;
```

**In-memory list field on parent model** (line 68):
```dart
List<TemplateItem> items; // Populado em memória após carregar os itens
```
`ChecklistTemplate` uses the same pattern: `List<ChecklistTemplateItem> items = const []`.

---

### `primeaudit/lib/services/checklist_template_service.dart` (service, CRUD)

**Analog:** `primeaudit/lib/services/audit_template_service.dart`

**Imports + client field** (lines 1-13):
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_type.dart';
import '../models/audit_template.dart';

class AuditTemplateService {
  final _client = Supabase.instance.client;
```
For the new service, replace imports with `checklist_template.dart` only. No `audit_type` dependency.

**List query with filter chain** (lines 16-25):
```dart
Future<List<AuditType>> getTypes({String? companyId}) async {
  var query = _client.from('audit_types').select();
  if (companyId != null) {
    query = query.or('company_id.is.null,company_id.eq.$companyId');
  } else {
    query = query.filter('company_id', 'is', null);
  }
  final data = await query.eq('active', true).order('name');
  return (data as List).map((e) => AuditType.fromMap(e)).toList();
}
```

**Insert + select().single() returning typed model** (lines 27-39):
```dart
Future<AuditType> createType({...}) async {
  final result = await _client
      .from('audit_types')
      .insert({'name': name, 'icon': icon, 'color': color, 'company_id': companyId})
      .select()
      .single();
  return AuditType.fromMap(result);
}
```

**Update with .eq() filter** (lines 41-46):
```dart
Future<void> updateType(String id, String name, String icon, String color) async {
  await _client
      .from('audit_types')
      .update({'name': name, 'icon': icon, 'color': color})
      .eq('id', id);
}
```

**Delete with .eq() filter** (lines 48-50):
```dart
Future<void> deleteType(String id) async {
  await _client.from('audit_types').delete().eq('id', id);
}
```

**getItems pattern with order_index** (lines 147-154):
```dart
Future<List<TemplateItem>> getItems(String templateId) async {
  final data = await _client
      .from('template_items')
      .select()
      .eq('template_id', templateId)
      .order('order_index');
  return (data as List).map((e) => TemplateItem.fromMap(e)).toList();
}
```

**No exception handling inside service** — callers do try/catch. This is enforced by CLAUDE.md: "Does not handle exceptions internally — callers are responsible for try/catch."

**Clone flow divergence:** The clone method (no analog in existing service) must:
1. Insert new template header with `.select().single()` to capture the new `id`
2. Fetch source items via `getItems(source.id)`
3. Batch-insert items: `await _client.from('checklist_template_items').insert(itemMaps)`
4. On any exception from step 3: `await _client.from('checklist_templates').delete().eq('id', newTemplate.id)` then `rethrow`

See RESEARCH.md Pattern 6 for the complete clone method body.

---

### `primeaudit/lib/screens/checklist/checklist_templates_screen.dart` (screen, request-response)

**Analogs:**
- Tab/AppBar pattern: `primeaudit/lib/screens/admin/admin_screen.dart`
- Card/list/FAB/error/empty pattern: `primeaudit/lib/screens/templates/audit_templates_screen.dart`

**Imports pattern** — follow `audit_templates_screen.dart` lines 1-7:
```dart
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/audit_template.dart';
import '../../services/audit_template_service.dart';
```
For the new screen:
```dart
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/checklist_template.dart';
import '../../services/checklist_template_service.dart';
import 'checklist_template_form_screen.dart';
```

**StatefulWidget + SingleTickerProviderStateMixin + TabController** (`admin_screen.dart` lines 15-36):
```dart
class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
```
For 3 tabs, change `length: 2` to `length: 3`. Use `TickerProviderStateMixin` (not `SingleTickerProviderStateMixin`) per UI-SPEC.

**AppBar with TabBar bottom** (`admin_screen.dart` lines 48-70):
```dart
appBar: AppBar(
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  title: const Text(
    'Administração',
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
  bottom: TabBar(
    controller: _tabController,
    indicatorColor: Colors.white,
    indicatorWeight: 3,
    labelColor: Colors.white,
    unselectedLabelColor: Colors.white60,
    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    tabs: const [
      Tab(icon: Icon(Icons.business_rounded), text: 'Empresas'),
      Tab(icon: Icon(Icons.people_rounded), text: 'Usuários'),
    ],
  ),
),
```
For checklist: 3 tabs; unselectedLabelColor is `Colors.white70` (not `Colors.white60`) per UI-SPEC; `indicatorColor: Colors.white`.

**Loading state** (`audit_templates_screen.dart` line 217):
```dart
_isLoading
    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
```

**Empty state** (`audit_templates_screen.dart` lines 218-231):
```dart
: _templates.isEmpty
    ? Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.type.icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Nenhum template cadastrado',
              style: TextStyle(color: AppTheme.of(context).textSecondary)),
        ],
      ))
```

**RefreshIndicator + ListView with FAB bottom clearance** (`audit_templates_screen.dart` lines 233-241):
```dart
: RefreshIndicator(
    onRefresh: _load,
    color: AppColors.primary,
    child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _templates.length,
      itemBuilder: (_, i) => _buildCard(_templates[i], color),
    ),
  ),
```

**FAB** (`audit_templates_screen.dart` lines 206-215):
```dart
floatingActionButton: widget.canManage
    ? FloatingActionButton.extended(
        onPressed: () => _showTemplateForm(),
        backgroundColor: color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Template',
            style: TextStyle(fontWeight: FontWeight.w600)),
      )
    : null,
```
For checklist: no `canManage` guard (FAB visible to all roles); `backgroundColor: AppColors.primary`.

**Card with 44x44 leading icon container + badges + PopupMenuButton trailing** (`audit_templates_screen.dart` lines 245-343):
```dart
Widget _buildCard(AuditTemplate t, Color typeColor) {
  return Card(
    margin: const EdgeInsets.only(bottom: 10),
    elevation: 0,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.of(context).divider)),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: typeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: Text(widget.type.icon,
            style: const TextStyle(fontSize: 22))),
      ),
      title: Text(t.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.description != null)
            Text(t.description!,
                style: TextStyle(fontSize: 12, color: AppTheme.of(context).textSecondary)),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: t.active ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(t.active ? 'Ativo' : 'Inativo',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: t.active ? Colors.green[700] : Colors.grey[600])),
            ),
            if (t.isGlobal) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Global',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppColors.accent)),
              ),
            ],
          ]),
        ],
      ),
      trailing: widget.canManage && (!t.isGlobal || widget.companyId == null)
          ? PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppTheme.of(context).textSecondary),
              onSelected: (v) async {
                if (v == 'edit') _showTemplateForm(t);
                if (v == 'delete') _confirmDelete(t);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8),
                  Text('Editar'),
                ])),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Excluir', style: TextStyle(color: AppColors.error)),
                ])),
              ],
            )
          : Icon(Icons.chevron_right_rounded, color: AppTheme.of(context).textSecondary),
    ),
  );
}
```
For `_ChecklistTemplateCard`: replace the `canManage` guard with `template.createdBy == currentUserId`; add a copy icon trailing for seeds; adapt badge chip text to "Padrão" / "Personalizado" with correct colors.

**Delete confirmation dialog** (`audit_templates_screen.dart` lines 144-166):
```dart
Future<void> _confirmDelete(AuditTemplate t) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Excluir template'),
      content: Text('Excluir "${t.name}"? Todos os itens serão removidos.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  if (confirm == true) {
    try {
      await _service.deleteTemplate(t.id);
      _load();
    } catch (e) { _showError('Erro: $e'); }
  }
}
```

**SnackBar error** (`audit_templates_screen.dart` lines 168-174):
```dart
void _showError(String msg) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: AppColors.error,
    behavior: SnackBarBehavior.floating,
  ));
}
```

**Clone bottom sheet:** No direct analog in codebase. Pattern follows `_showTemplateForm` structure (lines 51-115) using `showModalBottomSheet` with `isScrollControlled: true`, inner `Padding` with `MediaQuery.of(ctx).viewInsets.bottom + 24`, and a single `ElevatedButton`. The loading state inside the button replaces `Text` child with `CircularProgressIndicator(color: Colors.white, strokeWidth: 2)` via `setState` before the async call (same pattern used by form save buttons throughout the codebase).

---

### `primeaudit/lib/screens/checklist/checklist_template_form_screen.dart` (screen, request-response)

**Analog:** `primeaudit/lib/screens/templates/audit_templates_screen.dart` (`_showTemplateForm` and `_inputDec` methods)

**Input decoration helper** (`audit_templates_screen.dart` lines 176-187):
```dart
InputDecoration _inputDec(String label, IconData icon, BuildContext ctx) => InputDecoration(
  labelText: label,
  prefixIcon: Icon(icon, color: AppTheme.of(ctx).textSecondary, size: 20),
  filled: true, fillColor: AppTheme.of(ctx).surface,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppTheme.of(ctx).divider)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppTheme.of(ctx).divider)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.accent, width: 2)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
);
```
For `checklist_template_form_screen.dart`: promote `_inputDec` to a top-level private method on the State class (same approach — takes `BuildContext ctx` parameter for theme-awareness). The UI-SPEC specifies `vertical: 16` (not 14) for `contentPadding`; use the UI-SPEC value.

**TextFormField with validator** (`audit_templates_screen.dart` lines 80-86):
```dart
TextFormField(
  controller: nameCtrl,
  autofocus: true,
  textCapitalization: TextCapitalization.words,
  decoration: _inputDec('Nome do template *', Icons.assignment_outlined, ctx),
  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
),
```

**Full-width ElevatedButton CTA** (`audit_templates_screen.dart` lines 95-109):
```dart
SizedBox(
  width: double.infinity, height: 48,
  child: ElevatedButton(
    onPressed: () {
      if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    ),
    child: Text(editing != null ? 'Salvar' : 'Criar e configurar',
        style: const TextStyle(fontWeight: FontWeight.w600)),
  ),
),
```

**Edit mode pattern** (`audit_templates_screen.dart` lines 116-141):
```dart
if (editing != null) {
  await _service.updateTemplate(
      editing.id, nameCtrl.text.trim(),
      descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
  _load();
} else {
  template = await _service.createTemplate(...);
  ...
}
```

**_load() async pattern with setState loading flag** (`audit_templates_screen.dart` lines 36-49):
```dart
Future<void> _load() async {
  setState(() => _isLoading = true);
  try {
    final data = await _service.getTemplates(...);
    if (mounted) setState(() => _templates = data);
  } catch (e) {
    _showError('Erro ao carregar: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```
This pattern wraps every async call in the form screen's save handler too: `setState(() => _isSaving = true)` → try/catch → `finally setState(() => _isSaving = false)`.

**Form screen divergence from analog:** The form is a full `Scaffold` screen (not a bottom sheet) because items list can be long. The `editing` parameter is `ChecklistTemplate? editing` (passed via constructor, not via `showModalBottomSheet`). The screen's `AppBar` has title (not a sheet header). Items list is managed in `_items` list state with add/remove operations. `DropdownButtonFormField<String>` for category has no analog in existing codebase — it is a standard Flutter SDK widget; use `validator: (v) => v == null ? 'Obrigatório' : null`.

---

### `primeaudit/lib/screens/home_screen.dart` (modify — drawer entry)

**Analog:** Same file, lines 340-347 (existing `_drawerItem` call for "Auditorias")

**Insertion target** (`home_screen.dart` lines 340-347):
```dart
_drawerItem(
  icon: Icons.playlist_add_check_rounded,
  title: 'Auditorias',
  onTap: () => _navigate(AuditsScreen(
    currentUserId: _authService.currentUser?.id ?? '',
    currentUserName: _name,
  )),
),
```

**New entry to insert immediately after the "Auditorias" block and before "Ações Corretivas":**
```dart
_drawerItem(
  icon: Icons.checklist_rounded,
  title: 'Checklist',
  onTap: () => _navigate(ChecklistTemplatesScreen()),
),
```

**`_drawerItem` signature** (lines 394-423) — no new parameters needed:
```dart
Widget _drawerItem({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
  Color? color,
  int badgeCount = 0,
}) { ... }
```

**`_navigate` helper pattern** — used by all existing simple drawer items (e.g., `_navigate(const ProfileScreen())`). `ChecklistTemplatesScreen()` has no required constructor parameters.

**Import to add at top of `home_screen.dart`** (after line 18, the last import):
```dart
import 'checklist/checklist_templates_screen.dart';
```

---

### `primeaudit/test/models/checklist_template_test.dart` (test, transform)

**Analog:** `primeaudit/test/models/audit_template_test.dart`

**File structure pattern** (lines 1-28):
```dart
// Unit tests for TemplateItem.fromMap and AuditTemplate.fromMap (QUAL-03).

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/audit_template.dart';

Map<String, dynamic> _itemMap() => <String, dynamic>{
  'id': 'ti1',
  'template_id': 't1',
  ...
};

Map<String, dynamic> _templateMap() => <String, dynamic>{
  'id': 't1',
  ...
};
```

**group() + test() structure** (lines 29-128):
```dart
void main() {
  group('TemplateItem.fromMap — required fields', () {
    test('parses id, templateId, question, responseType, weight', () {
      final item = TemplateItem.fromMap(_itemMap());
      expect(item.id, equals('ti1'));
      ...
    });
  });

  group('TemplateItem.fromMap — defaults', () {
    test('response_type defaults to ok_nok when key absent', () {
      final m = _itemMap()..remove('response_type');
      expect(TemplateItem.fromMap(m).responseType, equals('ok_nok'));
    });
  });
}
```

**Key test cases to cover** (from RESEARCH.md Validation Architecture):
- `ChecklistTemplate.fromMap` parses `category`, `name`, `isPadrao` (TMPLCK-01)
- `ChecklistTemplateItem.fromMap` parses `description`, `itemType`, `orderIndex` with defaults (TMPLCK-02)
- `ChecklistTemplate.isSeed` returns `true` when `isPadrao == true` (TMPLCK-03)
- `ChecklistTemplate.fromMap` sets `isPadrao = false` when key absent (TMPLCK-04)

---

## Shared Patterns

### Loading State
**Source:** `primeaudit/lib/screens/templates/audit_templates_screen.dart` line 37 and 217
**Apply to:** `checklist_templates_screen.dart`, `checklist_template_form_screen.dart`
```dart
// Toggle pattern around every async call:
setState(() => _isLoading = true);
try { ... } catch (e) { _showError('...'); } finally {
  if (mounted) setState(() => _isLoading = false);
}

// Loading widget:
const Center(child: CircularProgressIndicator(color: AppColors.primary))
```

### Error Surfacing (SnackBar)
**Source:** `primeaudit/lib/screens/templates/audit_templates_screen.dart` lines 168-174
**Apply to:** All new screen files
```dart
void _showError(String msg) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: AppColors.error,
    behavior: SnackBarBehavior.floating,
  ));
}
```
Success snackbars omit `backgroundColor` (uses default) per existing pattern.

### Service Instantiation in State
**Source:** `primeaudit/lib/screens/templates/audit_templates_screen.dart` line 26
**Apply to:** All new screen files
```dart
final _service = ChecklistTemplateService();
```
Declared as a field on the `State` class, not `late`, not `final` with `initState`.

### AppBar Style
**Source:** `primeaudit/lib/screens/templates/audit_templates_screen.dart` lines 194-196 and `primeaudit/lib/screens/admin/admin_screen.dart` lines 51-53
**Apply to:** All new screens
```dart
appBar: AppBar(
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  title: Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
  ...
),
```

### mounted Guard in Async Callbacks
**Source:** `primeaudit/lib/screens/templates/audit_templates_screen.dart` line 43
**Apply to:** Every `setState` call after an `await` in new screens
```dart
if (mounted) setState(() => _data = data);
```

### No Exception Handling in Services
**Source:** CLAUDE.md + `primeaudit/lib/services/audit_template_service.dart` (no try/catch in any method)
**Apply to:** `checklist_template_service.dart` — all methods throw; callers wrap in try/catch
Exception: `cloneTemplate()` has an internal catch solely to delete the orphaned header row before rethrowing — this is a rollback, not error suppression.

---

## No Analog Found

No files in this phase lack a codebase analog. All patterns map to existing files.

---

## Metadata

**Analog search scope:**
- `primeaudit/lib/models/` — all model files
- `primeaudit/lib/services/` — all service files
- `primeaudit/lib/screens/` and `primeaudit/lib/screens/admin/` — all screen files
- `primeaudit/supabase/migrations/` — all migration files
- `primeaudit/test/models/` — all test files

**Files scanned:** 6 analog files read in full
**Pattern extraction date:** 2026-05-03
