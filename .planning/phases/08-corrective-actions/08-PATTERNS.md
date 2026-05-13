# Phase 8: Corrective Actions - Pattern Map

**Mapped:** 2026-04-25
**Files analyzed:** 12 (8 new, 4 modified)
**Analogs found:** 12 / 12

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `primeaudit/supabase/migrations/20260425_create_corrective_actions.sql` | migration | CRUD | `primeaudit/supabase/migrations/20260406_create_audits.sql` | exact |
| `primeaudit/lib/models/corrective_action.dart` | model | transform | `primeaudit/lib/models/audit.dart` | exact |
| `primeaudit/lib/services/corrective_action_service.dart` | service | CRUD | `primeaudit/lib/services/audit_answer_service.dart` | exact |
| `primeaudit/lib/screens/corrective_actions_screen.dart` | screen | request-response | `primeaudit/lib/screens/audits_screen.dart` | exact |
| `primeaudit/lib/screens/create_corrective_action_screen.dart` | screen | request-response | `primeaudit/lib/screens/audits_screen.dart` (`_NewAuditSheet` sub-widget) | role-match |
| `primeaudit/lib/screens/corrective_action_detail_screen.dart` | screen | request-response | `primeaudit/lib/screens/audits_screen.dart` (`_confirmEncerrar` pattern) | role-match |
| `primeaudit/test/models/corrective_action_test.dart` | test | transform | `primeaudit/test/models/audit_test.dart` | exact |
| `primeaudit/test/services/corrective_action_service_test.dart` | test | transform | `primeaudit/test/services/dashboard_service_test.dart` | exact |
| `primeaudit/lib/screens/audit_execution_screen.dart` (modify) | screen | request-response | self — extend `_SectionBlock` + `_ItemCard` | exact |
| `primeaudit/lib/screens/home_screen.dart` (modify) | screen | request-response | self — extend `_drawerItem()` + `_loadDashboard()` | exact |
| `primeaudit/lib/services/user_service.dart` (modify) | service | CRUD | self — add `getByCompany()` modeled on `getAll()` | exact |
| `primeaudit/lib/services/dashboard_service.dart` (modify) | service | CRUD | self — update `getOpenActionsCount()` to use `inFilter` | exact |

---

## Pattern Assignments

### `primeaudit/supabase/migrations/20260425_create_corrective_actions.sql` (migration, CRUD)

**Analog:** `primeaudit/supabase/migrations/20260406_create_audits.sql`

**File header and table creation pattern** (lines 1-31):
```sql
-- =============================================================================
-- Migração: tabela corrective_actions e RLS
-- Data: 2026-04-25
-- Idempotente: pode ser executado múltiplas vezes sem erro.
-- =============================================================================

-- 1. Tabela base (somente id na criação — colunas adicionadas com ADD COLUMN IF NOT EXISTS)
CREATE TABLE IF NOT EXISTS corrective_actions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);

ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS audit_id            UUID NOT NULL;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS template_item_id    UUID NOT NULL;
-- ...more ADD COLUMN IF NOT EXISTS...
```

**Foreign key idempotent pattern** (lines 49-67 of analog):
```sql
ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_audit_id_fkey;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_audit_id_fkey
  FOREIGN KEY (audit_id) REFERENCES audits(id) ON DELETE CASCADE;
```

**Status CHECK constraint idempotent pattern** (lines 73-75 of analog):
```sql
ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_status_check;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_status_check
  CHECK (status IN ('aberta','em_andamento','em_avaliacao','aprovada','rejeitada','cancelada'));
```

**Index creation pattern** (lines 85-89 of analog):
```sql
CREATE INDEX IF NOT EXISTS idx_corrective_actions_company_id  ON corrective_actions (company_id);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_status      ON corrective_actions (status);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_responsible ON corrective_actions (responsible_user_id);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_audit_id    ON corrective_actions (audit_id);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_created_at  ON corrective_actions (created_at DESC);
```

**RLS pattern — DROP POLICY IF EXISTS before CREATE POLICY** (lines 107-137 of analog):
```sql
ALTER TABLE corrective_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "superuser_dev_corrective_actions_full" ON corrective_actions;
CREATE POLICY "superuser_dev_corrective_actions_full" ON corrective_actions
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

DROP POLICY IF EXISTS "adm_corrective_actions_company" ON corrective_actions;
CREATE POLICY "adm_corrective_actions_company" ON corrective_actions
  USING (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());

DROP POLICY IF EXISTS "auditor_corrective_actions_select" ON corrective_actions;
CREATE POLICY "auditor_corrective_actions_select" ON corrective_actions
  FOR SELECT
  USING (get_my_role() = 'auditor' AND company_id = get_my_company_id());

DROP POLICY IF EXISTS "auditor_corrective_actions_insert" ON corrective_actions;
CREATE POLICY "auditor_corrective_actions_insert" ON corrective_actions
  FOR INSERT
  WITH CHECK (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
    AND created_by = auth.uid()
  );

DROP POLICY IF EXISTS "auditor_corrective_actions_update" ON corrective_actions;
CREATE POLICY "auditor_corrective_actions_update" ON corrective_actions
  FOR UPDATE
  USING (get_my_role() = 'auditor' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'auditor' AND company_id = get_my_company_id());
```

**Schema cache reload — always last line** (line 181 of analog):
```sql
NOTIFY pgrst, 'reload schema';
```

---

### `primeaudit/lib/models/corrective_action.dart` (model, transform)

**Analog:** `primeaudit/lib/models/audit.dart`

**Enum with label, color, icon getters pattern** (lines 3-39 of analog):
```dart
// Copy enum structure from AuditStatus.
// CorrectiveActionStatus follows identical pattern: values, label switch, color switch.
enum CorrectiveActionStatus {
  aberta,
  emAndamento,
  emAvaliacao,
  aprovada,
  rejeitada,
  cancelada;

  String get label { switch (this) { ... } }   // human-readable Portuguese
  Color get color  { switch (this) { ... } }   // Material Colors.* constants
}
```

**Static status-from-string parser pattern** (lines 111-119 of analog — `_statusFromString`):
```dart
// In Audit, a static method is used. For CorrectiveAction, use a static method
// on the enum itself (cleaner when 6 states with underscore DB values exist):
static CorrectiveActionStatus fromDb(String? value) {
  switch (value) {
    case 'em_andamento':  return CorrectiveActionStatus.emAndamento;
    case 'em_avaliacao':  return CorrectiveActionStatus.emAvaliacao;
    case 'aprovada':      return CorrectiveActionStatus.aprovada;
    case 'rejeitada':     return CorrectiveActionStatus.rejeitada;
    case 'cancelada':     return CorrectiveActionStatus.cancelada;
    default:              return CorrectiveActionStatus.aberta;
  }
}

bool get isFinal =>
    this == aprovada || this == rejeitada || this == cancelada;
```

**Model constructor pattern** (lines 65-85 of analog):
```dart
// All fields required except nullable ones. const constructor.
const CorrectiveAction({
  required this.id,
  required this.auditId,
  required this.templateItemId,
  required this.title,
  this.description,           // nullable — optional field
  required this.responsibleUserId,
  this.responsibleName,       // nullable — populated via join
  required this.dueDate,
  required this.status,
  required this.companyId,
  required this.createdBy,
  required this.createdAt,
  required this.updatedAt,
  this.linkedAuditTitle,      // nullable — populated via join
});
```

**fromMap factory pattern — nested join access via `?['key']`** (lines 87-109 of analog):
```dart
factory CorrectiveAction.fromMap(Map<String, dynamic> map) {
  return CorrectiveAction(
    id: map['id'],
    auditId: map['audit_id'],
    templateItemId: map['template_item_id'],
    title: map['title'],
    description: map['description'],
    responsibleUserId: map['responsible_user_id'],
    responsibleName: map['profiles']?['full_name'],       // FK join alias
    dueDate: DateTime.parse(map['due_date']),
    status: CorrectiveActionStatus.fromDb(map['status']),
    companyId: map['company_id'],
    createdBy: map['created_by'],
    createdAt: DateTime.parse(map['created_at']),
    updatedAt: DateTime.parse(map['updated_at']),
    linkedAuditTitle: map['audits']?['title'],            // FK join
  );
}
```

**Computed getter pattern** (lines 121-125 of analog — `isOverdue`):
```dart
bool get isOverdue =>
    dueDate.isBefore(DateTime.now()) && !status.isFinal;
```

---

### `primeaudit/lib/services/corrective_action_service.dart` (service, CRUD)

**Analog:** `primeaudit/lib/services/audit_answer_service.dart`

**Service class header — `_client` field, no try/catch inside service** (lines 9-10 of analog):
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/corrective_action.dart';
import '../models/audit_template.dart'; // for TemplateItem in _isNonConforming

class CorrectiveActionService {
  final _client = Supabase.instance.client;
  // No try/catch here — callers (screens) handle exceptions.
```

**List query with filters pattern** (lines 13-19 of analog — `getAnswers`):
```dart
Future<List<CorrectiveAction>> getActions({
  required String? companyId,
  String? statusFilter,
  String? responsibleFilter,
}) async {
  var query = _client
      .from('corrective_actions')
      .select('*, profiles!responsible_user_id(full_name), audits(title)');
  // Note: profiles!responsible_user_id disambiguates FK (Pitfall 5 in RESEARCH.md)
  if (companyId != null) query = query.eq('company_id', companyId);
  if (statusFilter != null) query = query.eq('status', statusFilter);
  if (responsibleFilter != null) query = query.eq('responsible_user_id', responsibleFilter);
  final data = await query.order('created_at', ascending: false);
  return (data as List).map((e) => CorrectiveAction.fromMap(e)).toList();
}
```

**Insert pattern — inline map, no toMap()** (lines 23-38 of analog — `upsertAnswer`):
```dart
Future<void> createAction({
  required String auditId,
  required String templateItemId,
  required String title,
  String? description,
  required String responsibleUserId,
  required DateTime dueDate,
  required String companyId,
  required String createdBy,
}) async {
  await _client.from('corrective_actions').insert({
    'audit_id': auditId,
    'template_item_id': templateItemId,
    'title': title,
    'description': description,
    'responsible_user_id': responsibleUserId,
    'due_date': dueDate.toIso8601String(),
    'status': 'aberta',
    'company_id': companyId,
    'created_by': createdBy,
  });
}
```

**Update pattern** (lines 42-47 of analog — `deleteAnswer`):
```dart
Future<void> updateStatus(String id, String newStatus) async {
  await _client
      .from('corrective_actions')
      .update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()})
      .eq('id', id);
}
```

**Count query using inFilter** (modeled on `DashboardService.getOpenActionsCount` lines 13-26):
```dart
Future<int> getOpenActionsCount(String? companyId) async {
  var query = _client
      .from('corrective_actions')
      .select('id')
      .inFilter('status', ['aberta', 'em_andamento', 'em_avaliacao']);
  if (companyId != null) query = query.eq('company_id', companyId);
  final data = await query;
  return (data as List).length;
}
```

**Static pure function for testability** (lines 52-53 of analog — `static double calculateConformity`):
```dart
// Extract as static method so it can be tested without Supabase client.
static bool isNonConforming(String responseType, String? answer) {
  if (answer == null || answer.isEmpty) return false;
  switch (responseType) {
    case 'ok_nok':     return answer == 'nok';
    case 'yes_no':     return answer == 'no';
    case 'scale_1_5':  return (int.tryParse(answer) ?? 0) <= 2;
    case 'percentage': return (double.tryParse(answer) ?? 100) < 50.0;
    case 'text':       return answer.isNotEmpty;
    case 'selection':  return answer.isNotEmpty;
    default:           return false;
  }
}

// RBAC transition logic — also static for testability (same pattern as calculateConformity)
static bool canTransitionTo({
  required String newStatus,
  required CorrectiveAction action,
  required String role,
  required String userId,
}) {
  final isAdmin = AppRole.canAccessAdmin(role);
  final isSuperDev = AppRole.isSuperOrDev(role);
  if (isAdmin || isSuperDev) return true;
  final isResponsible = action.responsibleUserId == userId;
  switch (newStatus) {
    case 'em_andamento':
      return isResponsible &&
          (action.status == CorrectiveActionStatus.aberta ||
           action.status == CorrectiveActionStatus.rejeitada); // re-open path
    case 'em_avaliacao':
      return isResponsible && action.status == CorrectiveActionStatus.emAndamento;
    case 'aprovada':
    case 'rejeitada':
      return !isResponsible &&
          role == AppRole.auditor &&
          action.status == CorrectiveActionStatus.emAvaliacao;
    case 'cancelada':
      return false; // only admin/superDev (already returned true above)
    default:
      return false;
  }
}
```

---

### `primeaudit/lib/screens/corrective_actions_screen.dart` (screen, request-response)

**Analog:** `primeaudit/lib/screens/audits_screen.dart`

**Screen class header — imports, enum filter, StatefulWidget** (lines 1-81 of analog):
```dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/corrective_action.dart';
import '../services/corrective_action_service.dart';
import '../services/company_context_service.dart';
import 'corrective_action_detail_screen.dart';

enum _StatusFilter { todas, abertas, emAndamento, emAvaliacao, finalizadas }

extension _StatusFilterLabel on _StatusFilter {
  String get label { switch (this) { ... } }
}

class CorrectiveActionsScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;
  const CorrectiveActionsScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserRole,
  });
  @override
  State<CorrectiveActionsScreen> createState() => _CorrectiveActionsScreenState();
}
```

**State field pattern** (lines 83-101 of analog):
```dart
class _CorrectiveActionsScreenState extends State<CorrectiveActionsScreen> {
  final _service = CorrectiveActionService();

  List<CorrectiveAction> _actions = [];
  bool _isLoading = true;
  String? _error;

  _StatusFilter _filter = _StatusFilter.todas;
  // Optional: responsible filter via dropdown (second filter axis per ACT-01)
```

**`_load()` pattern with CompanyContextService** (lines 109-120 of analog):
```dart
Future<void> _load() async {
  setState(() { _isLoading = true; _error = null; });
  try {
    final companyId = CompanyContextService.instance.activeCompanyId;
    final data = await _service.getActions(companyId: companyId);
    if (mounted) setState(() => _actions = data);
  } catch (e) {
    if (mounted) setState(() => _error = 'Erro ao carregar ações.\n$e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

**`_snack()` helper pattern** (lines 228-233 of analog):
```dart
void _snack(String msg) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    behavior: SnackBarBehavior.floating,
  ));
}
```

**Scaffold with AppBar + refresh IconButton pattern** (lines 241-254 of analog):
```dart
return Scaffold(
  backgroundColor: t.background,
  appBar: AppBar(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    title: const Text('Ações Corretivas',
        style: TextStyle(fontWeight: FontWeight.bold)),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh_rounded),
        tooltip: 'Atualizar',
        onPressed: _load,
      ),
    ],
  ),
  body: Column(
    children: [
      _buildFilters(t),
      Expanded(child: _buildBody(t, _filtered)),
    ],
  ),
);
```

**FilterChip row pattern** (lines 310-343 of analog — `_buildSearchAndFilters`):
```dart
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: _StatusFilter.values.map((f) {
      final selected = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(f.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : t.textPrimary,
              )),
          selected: selected,
          onSelected: (_) => setState(() => _filter = f),
          selectedColor: AppColors.primary,
          backgroundColor: t.background,
          checkmarkColor: Colors.white,
          side: BorderSide(color: selected ? AppColors.primary : t.divider),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        ),
      );
    }).toList(),
  ),
),
```

**Loading/error/empty body pattern** (lines 346-359 of analog — `_buildBody`):
```dart
Widget _buildBody(AppTheme t, List<CorrectiveAction> actions) {
  if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
  if (_error != null) return Center(child: Column(children: [
    Text(_error!, style: TextStyle(color: t.textSecondary)),
    TextButton(onPressed: _load, child: const Text('Tentar novamente')),
  ]));
  if (actions.isEmpty) return Center(child: Text('Nenhuma ação encontrada.',
      style: TextStyle(color: t.textSecondary)));
  return ListView.builder(
    padding: const EdgeInsets.all(12),
    itemCount: actions.length,
    itemBuilder: (_, i) => _ActionCard(action: actions[i], onTap: () => _openDetail(actions[i])),
  );
}
```

---

### `primeaudit/lib/screens/create_corrective_action_screen.dart` (screen, request-response)

**Analog:** `primeaudit/lib/screens/audits_screen.dart` (form pattern inside `_NewAuditSheet`)

**StatefulWidget with required audit + item context** (pattern from screen passing data via constructor):
```dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/audit.dart';
import '../models/audit_template.dart';
import '../models/app_user.dart';
import '../services/corrective_action_service.dart';
import '../services/user_service.dart';
import '../services/company_context_service.dart';

class CreateCorrectiveActionScreen extends StatefulWidget {
  final Audit audit;
  final TemplateItem item;

  const CreateCorrectiveActionScreen({
    super.key,
    required this.audit,
    required this.item,
  });

  @override
  State<CreateCorrectiveActionScreen> createState() =>
      _CreateCorrectiveActionScreenState();
}
```

**State: pre-load users in `_load()`, form key + controllers** (modeled on `_AuditsScreenState`):
```dart
class _CreateCorrectiveActionScreenState
    extends State<CreateCorrectiveActionScreen> {
  final _service = CorrectiveActionService();
  final _userService = UserService();
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  List<AppUser> _users = [];
  AppUser? _selectedUser;
  DateTime? _dueDate;
  bool _isLoading = true;   // loading users
  bool _isSaving = false;   // saving action
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final companyId = CompanyContextService.instance.activeCompanyId;
      if (companyId == null) throw Exception('Empresa não selecionada');
      final users = await _userService.getByCompany(companyId);
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao carregar usuários.\n$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
```

**Date picker call pattern** (Flutter SDK built-in — no analog needed):
```dart
Future<void> _pickDate() async {
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now().add(const Duration(days: 7)),
    firstDate: DateTime.now(),   // validator: must be future
    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
  );
  if (picked != null && mounted) setState(() => _dueDate = picked);
}
```

**Save method — try/catch in screen, no try/catch in service** (lines 182-200 of analog `_duplicar`):
```dart
Future<void> _save() async {
  if (!_formKey.currentState!.validate()) return;
  if (_dueDate == null) { _snack('Selecione o prazo'); return; }
  if (_selectedUser == null) { _snack('Selecione o responsável'); return; }
  setState(() => _isSaving = true);
  try {
    final companyId = CompanyContextService.instance.activeCompanyId!;
    final currentUser = Supabase.instance.client.auth.currentUser!;
    await _service.createAction(
      auditId: widget.audit.id,
      templateItemId: widget.item.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      responsibleUserId: _selectedUser!.id,
      dueDate: _dueDate!,
      companyId: companyId,
      createdBy: currentUser.id,
    );
    if (!mounted) return;
    Navigator.pop(context, true); // true = action created successfully
  } catch (e) {
    _snack('Erro ao criar ação: $e');
  } finally {
    if (mounted) setState(() => _isSaving = false);
  }
}
```

---

### `primeaudit/lib/screens/corrective_action_detail_screen.dart` (screen, request-response)

**Analog:** `primeaudit/lib/screens/audits_screen.dart` (`_confirmEncerrar` dialog + action buttons)

**Constructor pattern — receives full action object**:
```dart
class CorrectiveActionDetailScreen extends StatefulWidget {
  final CorrectiveAction action;
  final String currentUserId;
  final String currentUserRole;

  const CorrectiveActionDetailScreen({
    super.key,
    required this.action,
    required this.currentUserId,
    required this.currentUserRole,
  });
```

**Confirmation dialog before irreversible transition** (lines 193-226 of analog — `_confirmEncerrar`):
```dart
Future<bool?> _confirmTransition(String title, String body) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Voltar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
}
```

**Role-block SnackBar pattern** (lines 228-233 of analog — `_snack`):
```dart
// When a button is visible but role is blocked (should not normally show,
// but as safety net):
void _snack(String msg) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    behavior: SnackBarBehavior.floating,
  ));
}
```

**Status transition execution — try/catch in screen** (lines 182-200 of analog — `_duplicar`):
```dart
Future<void> _doTransition(String newStatus) async {
  final confirmed = await _confirmTransition('Alterar status', 'Mover para "$newStatus"?');
  if (confirmed != true) return;
  setState(() => _isSaving = true);
  try {
    await _service.updateStatus(_action.id, newStatus);
    // Reload updated action from DB or setState with updated local copy
    if (!mounted) return;
    Navigator.pop(context, true); // signal caller to reload list
  } catch (e) {
    _snack('Erro ao atualizar status: $e');
  } finally {
    if (mounted) setState(() => _isSaving = false);
  }
}
```

**RBAC button visibility — conditional rendering**:
```dart
// Use CorrectiveActionService.canTransitionTo() (static) to show/hide each button:
if (CorrectiveActionService.canTransitionTo(
  newStatus: 'em_andamento',
  action: _action,
  role: widget.currentUserRole,
  userId: widget.currentUserId,
))
  ElevatedButton(
    onPressed: () => _doTransition('em_andamento'),
    child: const Text('Iniciar andamento'),
  ),
```

---

### `primeaudit/lib/screens/audit_execution_screen.dart` (modify — _SectionBlock + _ItemCard)

**Analog:** self — lines 779-878

**Current `_SectionBlock` constructor** (lines 789-798):
```dart
const _SectionBlock({
  required this.section,
  required this.answers,
  required this.observations,
  required this.indexMap,
  required this.readOnly,
  required this.onAnswer,
  required this.onObservation,
  required this.theme,
});
```

**Add these two parameters to `_SectionBlock`** (copy existing `readOnly` pattern):
```dart
// New fields to add to _SectionBlock:
final Audit? audit;                                  // needed by _ItemCard for Navigator
final void Function(TemplateItem)? onCreateAction;  // null when readOnly

// Add to const constructor:
this.audit,
this.onCreateAction,
```

**Current `_ItemCard` constructor** (lines 869-878):
```dart
const _ItemCard({
  required this.item,
  required this.index,
  required this.answer,
  required this.observation,
  required this.readOnly,
  required this.onAnswer,
  required this.onObservation,
  required this.theme,
});
```

**Add to `_ItemCard`** (same pattern):
```dart
// New fields to add to _ItemCard:
final Audit? audit;
final void Function(TemplateItem)? onCreateAction;

// Add to const constructor:
this.audit,
this.onCreateAction,
```

**Icon injection point — after the "Ver observacao" GestureDetector block** (lines 1004-1030):
```dart
// Insert after the _showObs TextField block, before the closing ],
// at the bottom of the Column children in _ItemCardState.build():
if (widget.onCreateAction != null &&
    CorrectiveActionService.isNonConforming(widget.item.responseType, widget.answer) &&
    !widget.readOnly) ...[
  const SizedBox(height: 8),
  GestureDetector(
    onTap: () => widget.onCreateAction!(widget.item),
    child: Row(children: [
      Icon(Icons.assignment_add_rounded, size: 16, color: AppColors.accent),
      const SizedBox(width: 6),
      Text('Criar ação corretiva',
          style: TextStyle(fontSize: 12, color: AppColors.accent)),
    ]),
  ),
],
```

**Caller site update — `_buildBody()` → `_SectionBlock` call** (lines 585-594):
```dart
// Current call at lines 585-594 — add audit and onCreateAction:
_SectionBlock(
  section: _sections[i],
  answers: _answers,
  observations: _observations,
  indexMap: indexMap,
  readOnly: _isReadOnly,
  onAnswer: _onAnswer,
  onObservation: _onObservation,
  theme: t,
  audit: widget.audit,                // ADD
  onCreateAction: _isReadOnly ? null  // ADD — null suppresses icon in read-only
      : (item) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateCorrectiveActionScreen(
              audit: widget.audit,
              item: item,
            ),
          ),
        ),
),
```

---

### `primeaudit/lib/screens/home_screen.dart` (modify — `_drawerItem` + `_loadDashboard`)

**Analog:** self — lines 318-338

**Current `_drawerItem()` signature** (lines 318-323):
```dart
Widget _drawerItem({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
  Color? color,
}) {
  final itemColor = color ?? AppTheme.of(context).textPrimary;
  return ListTile(
    onTap: onTap,
    leading: Icon(icon, color: itemColor, size: 22),
    title: Text(title, style: TextStyle(color: itemColor, fontSize: 15, fontWeight: FontWeight.w500)),
    horizontalTitleGap: 8,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
  );
}
```

**Modified `_drawerItem()` — add optional `badgeCount` parameter**:
```dart
Widget _drawerItem({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
  Color? color,
  int badgeCount = 0,   // ADD
}) {
  final itemColor = color ?? AppTheme.of(context).textPrimary;
  Widget iconWidget = Icon(icon, color: itemColor, size: 22);
  if (badgeCount > 0) {
    iconWidget = Badge(
      label: Text('$badgeCount'),
      child: iconWidget,
    );
  }
  return ListTile(
    onTap: onTap,
    leading: iconWidget,           // was: Icon(icon, ...) directly
    title: Text(title, style: TextStyle(color: itemColor, fontSize: 15, fontWeight: FontWeight.w500)),
    horizontalTitleGap: 8,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
  );
}
```

**New drawer item for Ações Corretivas** (insert after "Auditorias" item at lines 276-283):
```dart
_drawerItem(
  icon: Icons.assignment_late_rounded,
  title: 'Ações Corretivas',
  badgeCount: _openActions,   // renders badge when > 0
  onTap: () => _navigate(CorrectiveActionsScreen(
    currentUserId: _authService.currentUser?.id ?? '',
    currentUserRole: _role,
  )),
),
```

**Update `_loadDashboard()` — replace `DashboardService.getOpenActionsCount` call** (line 99):
```dart
// Current (line 99):
final openActions = await _dashboardService.getOpenActionsCount(companyId);

// Replace with (or update DashboardService.getOpenActionsCount to use inFilter):
final openActions = await _correctiveActionService.getOpenActionsCount(companyId);
// OR update DashboardService.getOpenActionsCount() to use:
//   .inFilter('status', ['aberta', 'em_andamento', 'em_avaliacao'])
// and remove the try/catch wrapper (table now exists after migration)
```

---

### `primeaudit/lib/services/user_service.dart` (modify — add `getByCompany`)

**Analog:** self — lines 19-33 (`getAll()`)

**Current `getAll()` method** (lines 19-33):
```dart
Future<List<AppUser>> getAll() async {
  final me = await _getMyProfile();
  final myRole = me['role'] as String;
  final myCompanyId = me['company_id'] as String?;

  var query = _client.from('profiles').select('*, companies(name)');
  if (myRole == AppRole.adm) {
    if (myCompanyId == null) return [];
    query = query.eq('company_id', myCompanyId);
  }
  final data = await query.order('full_name');
  return (data as List).map((e) => AppUser.fromMap(e)).toList();
}
```

**New `getByCompany()` method — direct company scope, no role check, `active=true` filter**:
```dart
// Add after getAll() — used by CreateCorrectiveActionScreen responsible dropdown.
// Does NOT call _getMyProfile() — scoped by caller-provided companyId.
Future<List<AppUser>> getByCompany(String companyId) async {
  final data = await _client
      .from('profiles')
      .select('*, companies(name)')
      .eq('company_id', companyId)
      .eq('active', true)
      .order('full_name');
  return (data as List).map((e) => AppUser.fromMap(e)).toList();
}
```

---

### `primeaudit/lib/services/dashboard_service.dart` (modify — fix `getOpenActionsCount`)

**Analog:** self — lines 13-27

**Current method** (lines 13-27):
```dart
Future<int> getOpenActionsCount(String? companyId) async {
  try {
    var query = _client
        .from('corrective_actions')
        .select('id')
        .eq('status', 'aberta');        // BUG: only counts 'aberta', not all non-final
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    final data = await query;
    return (data as List).length;
  } catch (_) {
    return 0; // tabela corrective_actions ainda não existe (Phase 8)
  }
}
```

**Updated method — `inFilter` for all non-final statuses, remove try/catch after migration**:
```dart
Future<int> getOpenActionsCount(String? companyId) async {
  var query = _client
      .from('corrective_actions')
      .select('id')
      .inFilter('status', ['aberta', 'em_andamento', 'em_avaliacao']);
  if (companyId != null) {
    query = query.eq('company_id', companyId);
  }
  final data = await query;
  return (data as List).length;
  // try/catch removed: table exists after Phase 8 migration
}
```

---

### `primeaudit/test/models/corrective_action_test.dart` (test, transform)

**Analog:** `primeaudit/test/models/audit_test.dart`

**File header + test factory function pattern** (lines 1-26 of analog):
```dart
// Unit tests for CorrectiveAction.fromMap, CorrectiveActionStatus enum, isOverdue.

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/corrective_action.dart';

Map<String, dynamic> _fullActionMap() => <String, dynamic>{
  'id': 'ca1',
  'audit_id': 'a1',
  'template_item_id': 'ti1',
  'title': 'Ação teste',
  'description': 'Descrição',
  'responsible_user_id': 'u1',
  'due_date': '2027-01-01',      // DATE format — PostgREST returns ISO date string
  'status': 'aberta',
  'company_id': 'c1',
  'created_by': 'u2',
  'created_at': '2026-04-25T00:00:00.000Z',
  'updated_at': '2026-04-25T00:00:00.000Z',
  'profiles': {'full_name': 'Ana'},       // FK join alias
  'audits': {'title': 'Auditoria X'},     // FK join
};
```

**Group/test structure pattern** (lines 27-161 of analog):
```dart
void main() {
  group('CorrectiveAction.fromMap — scalar fields', () {
    test('parses id, auditId, templateItemId, title', () { ... });
    test('parses dueDate as DateTime', () { ... });
    test('description is null when absent', () { ... });
  });

  group('CorrectiveAction.fromMap — nested joins', () {
    test('parses responsibleName from profiles join', () { ... });
    test('responsibleName is null when profiles join absent', () { ... });
    test('parses linkedAuditTitle from audits join', () { ... });
  });

  group('CorrectiveActionStatus.fromDb — all 6 DB values', () {
    test("'aberta' -> CorrectiveActionStatus.aberta", () { ... });
    test("'em_andamento' -> CorrectiveActionStatus.emAndamento", () { ... });
    // ... all 6 values + unknown fallback
  });

  group('CorrectiveActionStatus.isFinal', () {
    test('aprovada is final', () { ... });
    test('rejeitada is final', () { ... });
    test('cancelada is final', () { ... });
    test('aberta is NOT final', () { ... });
    test('emAndamento is NOT final', () { ... });
    test('emAvaliacao is NOT final', () { ... });
  });

  group('CorrectiveAction.isOverdue', () {
    test('true when dueDate past and status not final', () { ... });
    test('false when status is final (aprovada)', () { ... });
    test('false when dueDate is future', () { ... });
  });
}
```

---

### `primeaudit/test/services/corrective_action_service_test.dart` (test, transform)

**Analog:** `primeaudit/test/services/dashboard_service_test.dart`

**File structure — pure function extraction pattern** (lines 1-67 of analog):
```dart
// Unit tests for pure logic extracted from CorrectiveActionService.
// Does NOT instantiate CorrectiveActionService (Supabase.instance.client throws in tests).
// Tests CorrectiveActionService.isNonConforming (static) and
// CorrectiveActionService.canTransitionTo (static).

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/services/corrective_action_service.dart';
import 'package:primeaudit/models/corrective_action.dart';

// Factory for CorrectiveAction (mirrors _audit() helper in dashboard_service_test.dart):
CorrectiveAction _action({
  String id = 'ca1',
  String responsibleUserId = 'user1',
  CorrectiveActionStatus status = CorrectiveActionStatus.aberta,
}) {
  return CorrectiveAction(
    id: id,
    auditId: 'a1',
    templateItemId: 'ti1',
    title: 'Test',
    responsibleUserId: responsibleUserId,
    dueDate: DateTime(2027, 1, 1),
    status: status,
    companyId: 'c1',
    createdBy: 'u2',
    createdAt: DateTime(2026, 4, 25),
    updatedAt: DateTime(2026, 4, 25),
  );
}
```

**Test group structure** (mirrors `dashboard_service_test.dart` group pattern):
```dart
void main() {
  group('CorrectiveActionService.isNonConforming — ok_nok', () {
    test("'ok' returns false", () {
      expect(CorrectiveActionService.isNonConforming('ok_nok', 'ok'), isFalse);
    });
    test("'nok' returns true", () {
      expect(CorrectiveActionService.isNonConforming('ok_nok', 'nok'), isTrue);
    });
  });
  // ... groups for yes_no, scale_1_5, percentage, text, selection, null/empty

  group('CorrectiveActionService.canTransitionTo — admin', () {
    test('admin can transition any status', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'cancelada',
        action: _action(status: CorrectiveActionStatus.aberta),
        role: 'adm',
        userId: 'other',
      ), isTrue);
    });
  });

  group('CorrectiveActionService.canTransitionTo — responsible', () {
    test('responsible can move aberta -> em_andamento', () { ... });
    test('responsible can move em_andamento -> em_avaliacao', () { ... });
    test('responsible CANNOT cancel', () { ... });
  });

  group('CorrectiveActionService.canTransitionTo — auditor (non-responsible)', () {
    test('auditor can approve em_avaliacao -> aprovada', () { ... });
    test('auditor can reject em_avaliacao -> rejeitada', () { ... });
    test('auditor cannot approve if still aberta', () { ... });
  });
}
```

---

## Shared Patterns

### Service instantiation in screens
**Source:** `primeaudit/lib/screens/audits_screen.dart` line 84
**Apply to:** All new screen files
```dart
final _service = CorrectiveActionService();
// Each screen owns its own service instance — no DI, no singleton
```

### `_load()` + `initState()` pattern
**Source:** `primeaudit/lib/screens/audits_screen.dart` lines 95-120
**Apply to:** `CorrectiveActionsScreen`, `CreateCorrectiveActionScreen`, `CorrectiveActionDetailScreen`
```dart
@override
void initState() {
  super.initState();
  _load();   // always called here, never in build()
}

Future<void> _load() async {
  setState(() { _isLoading = true; _error = null; });
  try {
    // ... async work
    if (mounted) setState(() => _data = result);
  } catch (e) {
    if (mounted) setState(() => _error = 'Erro ...\n$e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

### `!mounted` guard after every `await`
**Source:** `primeaudit/lib/screens/audits_screen.dart` lines 113-119 + all screens
**Apply to:** Every async method in every new screen
```dart
// Pattern: check mounted after every await before calling setState
if (mounted) setState(() => ...);
// Or in navigation:
if (!mounted) return;
Navigator.pop(context);
```

### Navigator.push pattern
**Source:** `primeaudit/lib/screens/audits_screen.dart` lines 156-159
**Apply to:** All navigation calls in new screens
```dart
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => TargetScreen(arg: value),
)).then((_) => _load()); // reload list after returning from detail
```

### CompanyContextService scoping
**Source:** `primeaudit/lib/screens/audits_screen.dart` line 112 + `home_screen.dart` line 84
**Apply to:** All service calls that need company scope
```dart
final companyId = CompanyContextService.instance.activeCompanyId;
// Pass to service method — never assume non-null; handle null in service
```

### AppRole checks for RBAC
**Source:** `primeaudit/lib/screens/home_screen.dart` lines 89-91 + 264
**Apply to:** `CorrectiveActionDetailScreen` transition buttons, `_drawerItem` badge
```dart
AppRole.canAccessAdmin(_role)   // true for 'adm', 'superuser', 'dev'
AppRole.isSuperOrDev(_role)     // true for 'superuser', 'dev' only
```

---

## No Analog Found

All files have strong analogs in the codebase. No files require falling back to RESEARCH.md-only patterns.

---

## Metadata

**Analog search scope:**
- `primeaudit/lib/screens/` (audits_screen.dart, audit_execution_screen.dart, home_screen.dart)
- `primeaudit/lib/services/` (audit_answer_service.dart, dashboard_service.dart, user_service.dart)
- `primeaudit/lib/models/` (audit.dart, app_user.dart)
- `primeaudit/supabase/migrations/` (20260406_create_audits.sql)
- `primeaudit/test/` (audit_test.dart, audit_answer_service_test.dart, dashboard_service_test.dart)

**Files scanned:** 13 source files read directly
**Pattern extraction date:** 2026-04-25
