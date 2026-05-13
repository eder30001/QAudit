# Phase 2: Security - Pattern Map

**Mapped:** 2026-04-17
**Files analyzed:** 7 files (2 new, 2 modified Dart; 2 new SQL migrations; 1 new documentation artifact)
**Analogs found:** 6 / 7

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `primeaudit/lib/core/cnpj_validator.dart` | utility | transform | `primeaudit/lib/core/app_roles.dart` | role-match (same `core/` utility layer, pure Dart, no dependencies) |
| `primeaudit/lib/screens/register_screen.dart` | screen (modify) | request-response | self — existing `validator:` on name/email/password fields | exact (same file, same `TextFormField.validator` pattern) |
| `primeaudit/lib/screens/admin/company_form.dart` | screen (modify) | request-response | `primeaudit/lib/screens/register_screen.dart` `_buildForm()` validators | role-match |
| `primeaudit/supabase/migrations/YYYYMMDD_fix_active_guard.sql` | migration | transform | `primeaudit/supabase/migrations/20260406_create_audits.sql` lines 97-105 | exact (same SECURITY DEFINER function pattern, same file) |
| `primeaudit/supabase/migrations/YYYYMMDD_rls_profiles_companies_perimeters.sql` | migration | CRUD | `primeaudit/supabase/migrations/20260406_create_audits.sql` lines 95-137 | exact (same idempotent RLS policy block pattern) |
| `primeaudit/test/cnpj_validator_test.dart` | test | transform | `primeaudit/test/pending_save_test.dart` | role-match (same unit test file structure, pure Dart) |
| `primeaudit/SECURITY-AUDIT.md` | documentation | — | none | no analog |

---

## Pattern Assignments

### `primeaudit/lib/core/cnpj_validator.dart` (utility, transform)

**Analog:** `primeaudit/lib/core/app_roles.dart`

**File structure pattern** (lines 1-42 of `app_roles.dart`):
```dart
// lib/core/app_roles.dart — canonical core utility style:
// - Top-level doc comment (///) describing purpose
// - Pure Dart class with only static members
// - No imports from Flutter or Supabase (pure Dart only)
// - Named with PascalCase class, snake_case file
// - Exposed via static methods/constants only — no instantiation

/// Define os papéis (roles) do sistema e utilitários de verificação de permissão.
class AppRole {
  static const String superuser = 'superuser';

  static bool canAccessAdmin(String role) =>
      role == superuser || role == dev || role == adm;
}
```

**Target implementation for `cnpj_validator.dart`** — expose two top-level functions (not a class), following the simpler function-per-file style appropriate for a single-purpose validator:
```dart
// Top-level functions, no class wrapper (D-02 discretion: function pura)
// No imports required — pure Dart arithmetic

/// Returns true if [cnpj] passes the official Brazilian checksum (Receita Federal).
/// Accepts formatted (00.000.000/0000-00) or raw 14-digit strings.
bool isValidCnpj(String cnpj) { ... }

/// Compatible with TextFormField.validator.
/// Returns null for empty/null input (CNPJ is optional in register_screen).
/// Returns null if valid; returns Portuguese error string if invalid.
String? validateCnpj(String? value) { ... }
```

**No imports pattern:** `app_roles.dart` has zero imports. `cnpj_validator.dart` must also have zero imports — algorithm is pure arithmetic.

---

### `primeaudit/lib/screens/register_screen.dart` (screen — modify, request-response)

**Analog:** self — existing `validator:` fields in `_buildForm()` (lines 207-286)

**Existing validator pattern to copy** (lines 207-220 of `register_screen.dart`):
```dart
TextFormField(
  controller: _nameController,
  textInputAction: TextInputAction.next,
  textCapitalization: TextCapitalization.words,
  decoration: _inputDecoration(
    label: 'Nome completo',
    hint: 'Seu nome',
    icon: Icons.person_outline_rounded,
  ),
  validator: (value) {
    if (value == null || value.trim().isEmpty) return 'Informe o nome';
    if (value.trim().split(' ').length < 2) return 'Informe nome e sobrenome';
    return null;
  },
),
```

**Target CNPJ field** — current state (lines 305-334 of `register_screen.dart`):
```dart
// CURRENTLY: no validator: property at all
TextFormField(
  controller: _cnpjController,
  keyboardType: TextInputType.number,
  textInputAction: TextInputAction.done,
  onChanged: _searchCompany,           // keep — fires DB lookup
  onFieldSubmitted: (_) => _register(), // keep
  decoration: _inputDecoration(...).copyWith(suffixIcon: ...),
  // ADD: validator: validateCnpj,
),
```

**Import to add** at top of `register_screen.dart` (lines 1-8, after existing imports):
```dart
import '../core/cnpj_validator.dart';
```

**CNPJ field is optional** — `validateCnpj` must return `null` for empty input. The field label is "Empresa (opcional)". Do not add `required` or non-null empty check here.

---

### `primeaudit/lib/screens/admin/company_form.dart` (screen — modify, request-response)

**Analog:** `primeaudit/lib/screens/register_screen.dart` `_buildForm()` — same `TextFormField.validator` wiring pattern

**`_buildField` helper signature** (lines 192-205 of `company_form.dart`):
```dart
Widget _buildField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  int maxLines = 1,
  String? Function(String?)? validator,  // <— already accepts validator
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    textCapitalization: TextCapitalization.words,
    validator: validator,               // <— already wired through
    decoration: InputDecoration(...),
  );
}
```

**Target CNPJ call site** — current state (lines 138-143 of `company_form.dart`):
```dart
// CURRENTLY: no validator argument
_buildField(
  controller: _cnpjController,
  label: 'CNPJ',
  icon: Icons.badge_outlined,
  keyboardType: TextInputType.number,
  // ADD: validator: validateCnpj,
),
```

**Existing working example with validator** (lines 130-136 of `company_form.dart`):
```dart
_buildField(
  controller: _nameController,
  label: 'Nome da empresa *',
  icon: Icons.business_rounded,
  validator: (v) =>
      (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
),
```

**Import to add** at top of `company_form.dart`:
```dart
import '../../core/cnpj_validator.dart';
```

---

### `primeaudit/supabase/migrations/YYYYMMDD_fix_active_guard.sql` (migration, transform)

**Analog:** `primeaudit/supabase/migrations/20260406_create_audits.sql` lines 97-105

**Current functions to replace** (lines 97-105 of `20260406_create_audits.sql`):
```sql
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION get_my_company_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT company_id FROM profiles WHERE id = auth.uid();
$$;
```

**Migration header pattern** (lines 1-5 of `20260406_create_audits.sql`):
```sql
-- =============================================================================
-- Migração: <description>
-- Data: YYYY-MM-DD
-- Idempotente: pode ser executado múltiplas vezes sem erro.
-- =============================================================================
```

**`NOTIFY pgrst` footer pattern** (line 180 of `20260406_create_audits.sql`):
```sql
NOTIFY pgrst, 'reload schema';
```

**`CREATE OR REPLACE` is safe to re-run** — no `DROP FUNCTION IF EXISTS` needed for functions (unlike policies which require `DROP POLICY IF EXISTS`). The idempotence here comes from `OR REPLACE`.

---

### `primeaudit/supabase/migrations/YYYYMMDD_rls_profiles_companies_perimeters.sql` (migration, CRUD)

**Analog:** `primeaudit/supabase/migrations/20260406_create_audits.sql` lines 95-137 (canonical RLS block)

**Full idempotent RLS block pattern** (lines 95-137 of `20260406_create_audits.sql`):
```sql
-- Idempotent RLS block structure — copy exactly:
ALTER TABLE audits ENABLE ROW LEVEL SECURITY;

-- Step 1: DROP all existing policies (idempotence — D-09)
DROP POLICY IF EXISTS "superuser_dev_full_access" ON audits;
DROP POLICY IF EXISTS "adm_company_access"         ON audits;
DROP POLICY IF EXISTS "auditor_select_company"     ON audits;
DROP POLICY IF EXISTS "auditor_insert_own"         ON audits;
DROP POLICY IF EXISTS "auditor_update_own"         ON audits;

-- Step 2: CREATE policies (superuser/dev → adm → auditor, most permissive first)
CREATE POLICY "superuser_dev_full_access" ON audits
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

CREATE POLICY "adm_company_access" ON audits
  USING  (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());

CREATE POLICY "auditor_select_company" ON audits FOR SELECT
  USING (get_my_role() = 'auditor' AND company_id = get_my_company_id());

CREATE POLICY "auditor_insert_own" ON audits FOR INSERT
  WITH CHECK (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
    AND auditor_id = auth.uid()
  );

CREATE POLICY "auditor_update_own" ON audits FOR UPDATE
  USING  (get_my_role() = 'auditor' AND auditor_id = auth.uid())
  WITH CHECK (get_my_role() = 'auditor' AND auditor_id = auth.uid());
```

**JOIN-based policy pattern for child tables** (lines 61-121 of `20260406_create_audit_answers.sql`):
```sql
-- Use EXISTS subquery when table has no direct company_id (child of audits):
CREATE POLICY "adm_answers_company" ON audit_answers
  USING (
    get_my_role() = 'adm'
    AND EXISTS (
      SELECT 1 FROM audits a
      WHERE a.id = audit_answers.audit_id
        AND a.company_id = get_my_company_id()
    )
  )
  WITH CHECK (
    get_my_role() = 'adm'
    AND EXISTS (
      SELECT 1 FROM audits a
      WHERE a.id = audit_answers.audit_id
        AND a.company_id = get_my_company_id()
    )
  );
```

**Global template visibility pattern** — for `audit_types`, `audit_templates` with `company_id IS NULL`:
```sql
-- Templates/types are global (company_id IS NULL) or company-specific.
-- Any active authenticated user can SELECT both global and own-company items.
-- This matches AuditTemplateService.getTemplates() which queries:
--   .or('company_id.is.null,company_id.eq.$companyId')
CREATE POLICY "authenticated_select_templates" ON audit_templates FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND (company_id IS NULL OR company_id = get_my_company_id())
  );
```

**Profiles UPDATE (SEC-02) — column-level role freeze for adm**:
```sql
-- adm can update full_name and active but NOT role.
-- Subquery reads the current (pre-update) role value and requires new role = current role.
DROP POLICY IF EXISTS "adm_profiles_update" ON profiles;
CREATE POLICY "adm_profiles_update" ON profiles FOR UPDATE
  USING (
    get_my_role() = 'adm'
    AND company_id = get_my_company_id()
  )
  WITH CHECK (
    get_my_role() = 'adm'
    AND company_id = get_my_company_id()
    AND role = (SELECT p.role FROM profiles p WHERE p.id = profiles.id)
  );
```

**Broken policies to DROP** — these exist in `schema.sql` lines 47-52 and reference the non-existent `admin` role:
```sql
-- Drop the broken schema.sql policies before creating correct ones:
DROP POLICY IF EXISTS "Admin full access on companies" ON companies;
DROP POLICY IF EXISTS "Admin full access on profiles"  ON profiles;
DROP POLICY IF EXISTS "Users can view own profile"     ON profiles;
```

**Tables requiring `ENABLE ROW LEVEL SECURITY`** (no migration currently enables RLS for these):
- `companies` — `schema.sql` line 44 enables it, but the existing policy is broken
- `perimeters` — no migration covers it at all
- `audit_types` — no migration covers it at all
- `audit_templates` — no migration covers it at all
- `template_items` — no migration covers it at all
- `template_sections` — existence unconfirmed; planner must verify (A3 from RESEARCH.md)

Pattern: `ALTER TABLE x ENABLE ROW LEVEL SECURITY;` is safe to re-run (no-op if already enabled).

---

### `primeaudit/test/cnpj_validator_test.dart` (test, transform)

**Analog:** `primeaudit/test/pending_save_test.dart`

**Test file structure pattern** (lines 1-10 of `pending_save_test.dart`):
```dart
// Unit tests para <Subject> (lib/<path>/<file>.dart).
// Cobre <what the tests verify>.

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/<path>/<subject>.dart';

void main() {
  group('<ClassName>', () {
    test('<description of behavior>', () {
      // arrange
      // act
      // assert with expect(...)
    });
  });
}
```

**Test group naming:** Use the function name as the group label, e.g. `group('isValidCnpj', ...)` and `group('validateCnpj', ...)`.

**Required test cases** (from RESEARCH.md Validation Architecture):
```dart
group('isValidCnpj', () {
  test('aceita CNPJ com dígitos verificadores corretos', ...);
  test('rejeita CNPJ com dígito verificador errado', ...);
  test('rejeita sequência de dígitos iguais (ex: 00.000.000/0000-00)', ...);
  test('aceita CNPJ com formatação (pontos, barra, hífen)', ...);
});

group('validateCnpj', () {
  test('retorna null para entrada vazia (campo opcional)', ...);
  test('retorna null para null', ...);
  test('retorna mensagem de erro para CNPJ inválido', ...);
  test('retorna null para CNPJ válido', ...);
});
```

**Run command:** `flutter test test/cnpj_validator_test.dart`

---

## Shared Patterns

### Idempotent Migration Structure
**Source:** `primeaudit/supabase/migrations/20260406_create_audits.sql` (full file structure)
**Apply to:** Both new SQL migrations

```sql
-- =============================================================================
-- Migração: <description>
-- Data: YYYY-MM-DD
-- Idempotente: pode ser executado múltiplas vezes sem erro.
-- =============================================================================

-- <section separator style>
-- Section N. <description>
-- ----------------------------------------------------------------------------

-- ... body ...

NOTIFY pgrst, 'reload schema';
```

### RLS Policy Naming Convention
**Source:** `primeaudit/supabase/migrations/20260406_create_audits.sql` lines 108-137
**Apply to:** All new policies in the RLS migration

Pattern: `"<role>_<table_short>_<operation>"` e.g.:
- `"superuser_dev_full_access"` (omit table name when block is scoped to one table)
- `"adm_company_access"`
- `"auditor_select_company"`
- `"adm_profiles_select"`, `"adm_profiles_update"` (when multiple per-operation policies exist)

### Role Constants in SQL Policies
**Source:** `primeaudit/lib/core/app_roles.dart` lines 6-11 + `primeaudit/supabase/migrations/20260406_create_audits.sql` lines 115-117
**Apply to:** All new SQL policies

Valid roles: `'superuser'`, `'dev'`, `'adm'`, `'auditor'`, `'anonymous'`.
The role `'admin'` does NOT exist — it is the broken value in `schema.sql` that phase 2 replaces.

```sql
-- Correct: use these role string literals only
get_my_role() IN ('superuser', 'dev')
get_my_role() = 'adm'
get_my_role() = 'auditor'
```

### `TextFormField.validator` Wiring Pattern
**Source:** `primeaudit/lib/screens/register_screen.dart` lines 216-220
**Apply to:** CNPJ field in `register_screen.dart` and `company_form.dart`

```dart
validator: (value) {
  // inline lambda for simple cases
  if (value == null || value.trim().isEmpty) return 'Informe o nome';
  return null;
},

// OR — pass function reference for reusable validators (target pattern for CNPJ):
validator: validateCnpj,  // function reference from cnpj_validator.dart
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `primeaudit/SECURITY-AUDIT.md` | documentation | — | No documentation artifacts of this type exist in the repo; content is specified entirely in D-10 and RESEARCH.md RLS Gap Analysis table |

---

## Metadata

**Analog search scope:** `primeaudit/supabase/migrations/`, `primeaudit/lib/supabase/migrations/`, `primeaudit/lib/core/`, `primeaudit/lib/screens/`, `primeaudit/lib/screens/admin/`, `primeaudit/test/`
**Files read:** 8 source files
**Pattern extraction date:** 2026-04-17
