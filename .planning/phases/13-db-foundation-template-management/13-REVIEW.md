---
phase: 13-db-foundation-template-management
reviewed: 2026-05-04T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - primeaudit/supabase/migrations/20260503_create_checklist_templates.sql
  - primeaudit/lib/models/checklist_template.dart
  - primeaudit/lib/services/checklist_template_service.dart
  - primeaudit/test/models/checklist_template_test.dart
  - primeaudit/test/services/checklist_template_service_test.dart
  - primeaudit/lib/screens/checklist/checklist_templates_screen.dart
  - primeaudit/lib/screens/home_screen.dart
  - primeaudit/lib/screens/checklist/checklist_template_form_screen.dart
findings:
  critical: 4
  warning: 6
  info: 2
  total: 12
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-05-04T00:00:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

This phase introduces the `checklist_templates` / `checklist_template_items` tables, their RLS policies, seed data, three Dart layers (model, service, screen), and a form screen. The DB migration is structurally sound and idempotent. The Dart model layer is clean. However, four blockers were found: two force-unwrap null crashes in the service, one stale-context data loss on the `parentContext` pattern in the bottom sheet, and one multi-user RLS gap that lets any authenticated user read all non-seed templates regardless of company. Six additional warnings cover async BuildContext leaks, missing rollback in edit save, TextEditingController leaks on _loadItems re-run, and an un-seeded conflict target. Two info items note the hollow service test and a cosmetic model mutability issue.

---

## Critical Issues

### CR-01: Force-unwrap `currentUser!.id` crashes when session expires mid-use

**File:** `primeaudit/lib/services/checklist_template_service.dart:58` and `:130`

**Issue:** Both `createTemplate` and `cloneTemplate` call `_client.auth.currentUser!.id` with a hard `!` dereference. If the Supabase session has expired or the user logged out in another tab/process between the time the screen was shown and the button was pressed, `currentUser` is `null` and the app throws an unhandled `Null check operator used on a null value`, crashing the auditor mid-flow — a violation of the project's core data-loss constraint.

`getOwned()` (line 30–31) uses the safe `?.` and returns early; `createTemplate` and `cloneTemplate` do not.

**Fix:**
```dart
// createTemplate (line 58) and cloneTemplate (line 130)
final userId = _client.auth.currentUser?.id;
if (userId == null) throw Exception('Sessão expirada. Faça login novamente.');
```

---

### CR-02: RLS SELECT policy leaks all user-created templates across companies

**File:** `primeaudit/supabase/migrations/20260503_create_checklist_templates.sql:87-91`

**Issue:** The `authenticated_checklist_templates_select` policy grants SELECT to any authenticated user whose `created_by = auth.uid()` **or** `is_padrao = true`. There is no `company_id` guard. As a result, a user in Company A can read templates created by a user in Company B if they somehow know or enumerate the template IDs, because the PostgREST client scoped to a valid JWT will pass `get_my_role() IS NOT NULL`.

More concretely, `getByCategory` in the service does not filter by company; it relies entirely on RLS to scope results. Because RLS only checks `created_by = auth.uid()`, a cross-company user whose `created_by` matches their own UID cannot see others' records — but the service's `getOwned()` fetches `.eq('created_by', userId)` which returns templates regardless of which company the template was associated with. When a superuser switches company context and another user's template happens to have `company_id` set to a different company, there is no server-side enforcement that the caller's company matches.

The existing audit templates pattern guards via `company_id.is.null,company_id.eq.$companyId`. This new table has `company_id` but zero SELECT-policy enforcement of it.

**Fix:**
```sql
-- Replace the authenticated SELECT policy:
CREATE POLICY "authenticated_checklist_templates_select" ON checklist_templates FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND (
      is_padrao = true
      OR created_by = auth.uid()
      -- future: OR company_id = get_my_company_id()  -- when company-shared templates are needed
    )
  );
```
For now the `created_by = auth.uid()` guard achieves single-user isolation. The larger gap is that `company_id` on the table is never enforced at the RLS layer: document explicitly in the migration that company-scoped sharing is deferred, or add the guard now.

---

### CR-03: `_confirmDelete` calls `_load()` without `await`, then uses `context` after an async gap

**File:** `primeaudit/lib/screens/checklist/checklist_templates_screen.dart:115-118`

**Issue:** After `await _service.deleteTemplate(t.id)` completes, the code calls `_load()` (unawaited) and immediately calls `ScaffoldMessenger.of(context)` on the same `if (mounted)` branch. The `_load()` invocation starts a new async chain that calls `setState`, but there is also a `mounted` guard below. The immediate problem is that `_load()` triggers a `setState` call that may run concurrently with the snackbar display. If the widget is disposed while `_load()` is in-flight (user navigates away during the async gap in deleteTemplate), the `_load()` body's inner `setState` will fire on a dead widget. This is a use-after-dispose pattern the `mounted` guard inside `_load` does cover — but only because `_load` checks `mounted` itself. However, the outer `_confirmDelete` does NOT await `_load()`, meaning any error thrown by `_load()` after the `try/catch` block in `_confirmDelete` is silently swallowed with no handler.

More critically: the snackbar is shown before `_load()` completes, meaning the UI shows "Excluído" while the list may still contain the deleted item until the async load completes — inconsistent visual state is confusing for the auditor.

**Fix:**
```dart
if (confirm == true && mounted) {
  try {
    await _service.deleteTemplate(t.id);
    await _load(); // await so list is fresh before showing snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checklist excluído.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) { ... }
}
```

---

### CR-04: `parentContext` passed into `_CloneBottomSheet` is stale and may be unmounted

**File:** `primeaudit/lib/screens/checklist/checklist_templates_screen.dart:149`, `515`

**Issue:** `_CloneBottomSheet` receives the parent screen's `BuildContext` via a constructor field (`parentContext`) and stores it as `widget.parentContext`. It then calls `ScaffoldMessenger.of(widget.parentContext)` after an async gap (`await widget.service.cloneTemplate(...)`).

This pattern is fragile for two reasons:

1. `parentContext` is captured at `showModalBottomSheet` call time. By the time `cloneTemplate` resolves (possibly seconds later), the parent screen may have been disposed (user navigated back, session expired). `ScaffoldMessenger.of(widget.parentContext)` on a disposed context throws or shows a misleading snackbar on a dead tree.

2. Even if the parent is not disposed, Dart's `use_build_context_synchronously` lint fires for exactly this pattern — `context` captured before `await`, then used after. The comment on line 514 claims the capture "before async gap" fixes the lint, but the captured reference is `widget.parentContext` (a field, not a local), so the capture only appears local — the underlying `BuildContext` object is still the parent widget's context which can become invalid.

The correct fix is to look up the `ScaffoldMessenger` from the **bottom sheet's own context** before the await, or — per project convention — use `ScaffoldMessenger.maybeOf` with a null check.

**Fix:**
```dart
Future<void> _clone() async {
  // Capture messenger from the bottom sheet's OWN context before any async gap.
  final messenger = ScaffoldMessenger.of(context);
  setState(() => _isCloning = true);
  try {
    await widget.service.cloneTemplate(widget.template);
    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(/* success */);
    widget.onAfterClone();
  } catch (e) {
    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(/* error */);
  }
}
```
This is safe because `messenger` is resolved from the bottom sheet's own context (which has an active `ScaffoldMessenger` ancestor via the app root), and it is resolved before the `await`.

---

## Warnings

### WR-01: `updateTemplate` + `replaceItems` in `_save` has no rollback on partial failure

**File:** `primeaudit/lib/screens/checklist/checklist_template_form_screen.dart:100-108`

**Issue:** Edit mode calls `updateTemplate` then `replaceItems` sequentially with no transaction. If `replaceItems`'s `DELETE` succeeds but the subsequent `createItems` `INSERT` fails (network drop, constraint violation), the template header is updated with the new metadata but **all items are deleted** — the template is left in a corrupted state with zero items.

`cloneTemplate` in the service already implements a delete-then-rethrow rollback (lines 161–165), but `replaceItems`/`updateTemplate` has no equivalent.

**Fix:** Either (a) add a rollback in the service for `replaceItems` that re-inserts the old items on failure, or (b) move the two-step operation into a single Supabase RPC that wraps both in a DB transaction. At minimum, re-order the calls so items are replaced before metadata is updated, limiting damage:
```dart
// Replace items first; if this fails, metadata is unchanged.
await _service.replaceItems(widget.editing!.id, itemMaps);
// Only update header after items are safely replaced.
await _service.updateTemplate(widget.editing!.id, name: name, category: category, description: description);
```

---

### WR-02: `TextEditingController`s created in `_loadItems` are leaked on re-entrant calls

**File:** `primeaudit/lib/screens/checklist/checklist_template_form_screen.dart:51-59`

**Issue:** `_loadItems` clears `_items` with `_items.clear()` and adds new maps with fresh `TextEditingController` instances. `dispose()` at line 73 iterates `_items` and disposes each controller, so controllers that are in `_items` at dispose time are handled. However, if `_loadItems` is called more than once (e.g., if the user somehow triggers it twice before the first completes — the `_isLoadingItems` guard prevents this, but there is also no guard that prevents a second navigation push/pop triggering it again via `initState` on a new instance), or if an exception is thrown midway through re-populating `_items`, controllers already removed from `_items` by `_items.clear()` but not yet replaced are lost.

The more concrete risk: `_items.clear()` runs inside `setState` on line 53, which discards the old controller references held in the old list entries. Those old controllers are now unreferenced and will not be disposed by `dispose()`. Flutter will warn "A TextEditingController was disposed of prematurely" or silently leak.

**Fix:**
```dart
// In _loadItems, dispose existing controllers before clearing:
if (mounted) {
  setState(() {
    for (final e in _items) {
      (e['ctrl'] as TextEditingController).dispose();
    }
    _items.clear();
    for (final item in items) {
      _items.add({
        'ctrl': TextEditingController(text: item.description),
        'item_type': item.itemType,
      });
    }
  });
}
```

---

### WR-03: `BuildContext` used after `await` in `_confirmDelete` without pre-capture

**File:** `primeaudit/lib/screens/checklist/checklist_templates_screen.dart:113-135`

**Issue:** After `await _service.deleteTemplate(t.id)` (line 115), the code accesses `ScaffoldMessenger.of(context)` on line 118. There is a `mounted` check on line 117, which prevents a crash, but `use_build_context_synchronously` lint will fire for this pattern in Dart 3. Beyond the lint, `context` is used after an async suspension point without being captured as a local before the `await`.

**Fix:**
```dart
Future<void> _confirmDelete(ChecklistTemplate t) async {
  final messenger = ScaffoldMessenger.of(context); // capture before any await
  final confirm = await showDialog<bool>(...);
  if (confirm == true && mounted) {
    try {
      await _service.deleteTemplate(t.id);
      await _load();
      messenger.showSnackBar(const SnackBar(content: Text('Checklist excluído.'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: const Text('Erro ao excluir. Tente novamente.'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
    }
  }
}
```

---

### WR-04: `checklist_template_items` seed uses bare `ON CONFLICT DO NOTHING` without a conflict target

**File:** `primeaudit/supabase/migrations/20260503_create_checklist_templates.sql:222` and `:257`

**Issue:** The item seeds use `ON CONFLICT DO NOTHING` without specifying a conflict target column (e.g., `ON CONFLICT (id) DO NOTHING`). PostgreSQL requires a conflict target for `ON CONFLICT DO UPDATE`, but `DO NOTHING` without a target is syntactically valid — however, it matches **any** unique constraint or primary key conflict. This is fine as long as there is only one unique constraint (the primary key `id`). The risk is that if a future migration adds another unique constraint (e.g., `UNIQUE (template_id, order_index)`), re-running this migration could silently skip rows that should fail with a real error, making idempotency behavior less predictable.

By contrast, the template seeds correctly use `ON CONFLICT (id) DO NOTHING`. The item seeds should match this pattern.

**Fix:**
```sql
-- Lines 222 and 257: specify the conflict target
ON CONFLICT (id) DO NOTHING;
```
Note: The item inserts do not provide explicit `id` values, so there can never be a PK conflict on re-run — these rows will always be re-inserted. The `ON CONFLICT DO NOTHING` is therefore also logically incorrect: it does not prevent duplicate rows on re-execution. The correct approach for idempotent item seeds is to provide explicit UUIDs for each item row, as done for the template headers.

---

### WR-05: `_currentUserId` captured in `initState` is never refreshed; can be stale after session change

**File:** `primeaudit/lib/screens/checklist/checklist_templates_screen.dart:37`

**Issue:** `_currentUserId` is set once in `initState` from `Supabase.instance.client.auth.currentUser?.id`. If the auth session changes while this screen is in the back-stack (e.g., session refresh rotates the user ID, or the user logs out and back in — unlikely but possible on long-running sessions), `_currentUserId` will be stale. The ownership badge logic `template.createdBy == currentUserId && !template.isSeed` and the action menu gating (edit/delete for own templates) will then incorrectly deny actions on the user's own templates or incorrectly show actions on templates they don't own.

**Fix:** Move the `_currentUserId` refresh into `_load()` so it is refreshed alongside data:
```dart
Future<void> _load() async {
  setState(() { _isLoading = true; _error = null; });
  _currentUserId = Supabase.instance.client.auth.currentUser?.id; // refresh here
  // ... rest of load
}
```

---

### WR-06: `_save` in form screen force-unwraps `_category!` — will crash if validator is bypassed

**File:** `primeaudit/lib/screens/checklist/checklist_template_form_screen.dart:89`

**Issue:** `_save` calls `_formKey.currentState!.validate()` and returns early if validation fails. However, `_category` has a separate form validator (`validator: (v) => v == null ? 'Obrigatório' : null`) on the `DropdownButtonFormField`. If `validate()` passes (all other fields valid) but `_category` is somehow `null` — which can occur if `widget.editing?.category` returns a value not in the dropdown's item list, making `initialValue` unrecognised and resetting to `null` after a rebuild — then `_category!` on line 89 throws a null-safety crash.

The validator on `DropdownButtonFormField` should prevent this in normal flow, but the force-unwrap is unnecessary and unsafe.

**Fix:**
```dart
final category = _category;
if (category == null) {
  _showError('Selecione uma categoria');
  return;
}
```

---

## Info

### IN-01: Service integration test file is a hollow stub with no real assertions

**File:** `primeaudit/test/services/checklist_template_service_test.dart:18-27`

**Issue:** The service test file contains two test cases that only assert `expect(ChecklistTemplateService, isNotNull)` — checking that the class symbol exists, not that any service behaviour is correct. This gives false confidence in CI (tests pass but exercise nothing). The comments acknowledge this is a "stub", but the test file as committed will be counted as passing coverage when it covers zero code paths.

**Fix:** Either mark each test as `skip: 'Requires live Supabase'` explicitly, or remove the hollow assertions and use `markTestSkipped(...)` / `group(..., skip: '...')` at the group level so the skip is visible in test output rather than silently passing.

---

### IN-02: `ChecklistTemplate.items` field is mutable (`List`) on an otherwise immutable model

**File:** `primeaudit/lib/models/checklist_template.dart:14`

**Issue:** All other fields on `ChecklistTemplate` are `final`. `items` is declared as `List<ChecklistTemplateItem> items` (no `final`) and defaults to `const []`. This breaks the model's value-object contract: any caller can mutate `someTemplate.items.add(...)` without going through a service call, producing invisible state divergence between the in-memory model and the database.

**Fix:** Declare it `final` and accept it in the constructor. If mutation is needed, use `copyWith` or re-fetch from service:
```dart
final List<ChecklistTemplateItem> items;
```

---

_Reviewed: 2026-05-04T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
