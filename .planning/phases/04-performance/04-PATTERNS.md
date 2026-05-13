# Phase 4: Performance - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 2 (1 modify, 1 create)
**Analogs found:** 2 / 2

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `primeaudit/lib/services/audit_template_service.dart` | service | CRUD (batch update) | `primeaudit/lib/services/audit_answer_service.dart` | exact — same service layer, same `.upsert()` call pattern |
| `primeaudit/test/services/audit_template_service_reorder_test.dart` | test | — | `primeaudit/test/services/audit_answer_service_test.dart` | exact — same service test structure, same pure-logic isolation pattern |

---

## Pattern Assignments

### `primeaudit/lib/services/audit_template_service.dart` (service, CRUD batch)

**Analog:** `primeaudit/lib/services/audit_answer_service.dart`

**Imports pattern** (lines 1–3 of analog):
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_answer.dart';
import '../models/audit_template.dart';
```

**Client reference pattern** (line 10 of analog):
```dart
final _client = Supabase.instance.client;
```
Copy exactly — every service in the project declares `_client` this way. No constructor injection.

**Upsert single-record pattern** (lines 29–38 of `audit_answer_service.dart`):
```dart
await _client.from('audit_answers').upsert(
  {
    'audit_id': auditId,
    'template_item_id': templateItemId,
    'response': response,
    'observation': observation,
    'answered_at': DateTime.now().toIso8601String(),
  },
  onConflict: 'audit_id,template_item_id',
);
```
This proves `.upsert(Map)` is already used in the project. The batch variant passes `List<Map>` instead of a single `Map`.

**Target pattern for `reorderItems` — batch upsert replacing the N+1 loop** (current broken code at lines 209–216 of `audit_template_service.dart`):

Current (anti-pattern — N sequential awaits in for loop):
```dart
Future<void> reorderItems(List<String> ids) async {
  for (int i = 0; i < ids.length; i++) {
    await _client
        .from('template_items')
        .update({'order_index': i})
        .eq('id', ids[i]);
  }
}
```

Target (1 batch query):
```dart
/// Reordena itens atualizando [order_index] via batch upsert (1 query).
/// Recebe a lista de IDs na nova ordem desejada.
/// Todos os IDs devem existir em `template_items` — IDs inválidos causam
/// erro de constraint (não silencioso).
Future<void> reorderItems(List<String> ids) async {
  if (ids.isEmpty) return;
  final payload = [
    for (int i = 0; i < ids.length; i++)
      {'id': ids[i], 'order_index': i},
  ];
  await _client
      .from('template_items')
      .upsert(payload);
}
```

**Key differences from the broken version:**
- Guard clause `if (ids.isEmpty) return;` at the top (same defensive pattern used throughout the codebase)
- Collection-for builds `List<Map<String, dynamic>>` payload outside the Supabase call
- Single `.upsert(payload)` call — no loop, no sequential awaits
- No `onConflict` parameter needed: PostgREST defaults to the table's PRIMARY KEY (`id`) for conflict resolution

**Error handling pattern** — services do NOT catch internally (CLAUDE.md convention):
```dart
// Callers are responsible for try/catch — service methods let exceptions propagate.
// See: audit_answer_service.dart (no try/catch anywhere in the file)
```

---

### `primeaudit/test/services/audit_template_service_reorder_test.dart` (test, pure logic)

**Analog:** `primeaudit/test/services/audit_answer_service_test.dart`

**Critical constraint (lines 1–5 of analog):**
```dart
// Uses the static form — does NOT instantiate AuditAnswerService
// (the `_client = Supabase.instance.client` field would throw in tests).
```
The same constraint applies to `AuditTemplateService`: do NOT instantiate the service class in tests. `_client = Supabase.instance.client` throws because Supabase is not initialized in the test environment. Test only the payload-construction logic as a pure function.

**Imports pattern** (lines 6–8 of analog):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/services/audit_answer_service.dart';
import 'package:primeaudit/models/audit_template.dart';
```

For the reorder test, adapt to:
```dart
import 'package:flutter_test/flutter_test.dart';
```
No service import needed — the payload construction logic is tested as a standalone pure function extracted from the method body, not by calling the service.

**Test file structure** (full pattern from `audit_answer_service_test.dart`):
```dart
void main() {
  group('GroupName — scenario category', () {
    test('description of expected behavior', () {
      // arrange
      // act
      // expect
    });
  });
}
```

**Pure-function extraction pattern for payload testing** (from RESEARCH.md Code Examples section):

The test cannot call `service.reorderItems()` (would throw on `_client`). Instead, extract the payload-building logic into a local function within the test file and test that:

```dart
// Helper that mirrors the payload logic inside reorderItems — testable without Supabase
List<Map<String, dynamic>> buildReorderPayload(List<String> ids) {
  return [
    for (int i = 0; i < ids.length; i++)
      {'id': ids[i], 'order_index': i},
  ];
}

void main() {
  group('reorderItems payload construction', () {
    test('empty list returns empty payload', () {
      expect(buildReorderPayload([]), isEmpty);
    });

    test('single id produces order_index 0', () {
      expect(buildReorderPayload(['id-a']), [
        {'id': 'id-a', 'order_index': 0},
      ]);
    });

    test('three ids produce ascending order_index', () {
      expect(buildReorderPayload(['id-a', 'id-b', 'id-c']), [
        {'id': 'id-a', 'order_index': 0},
        {'id': 'id-b', 'order_index': 1},
        {'id': 'id-c', 'order_index': 2},
      ]);
    });

    test('20 ids produce correct order_index for last element', () {
      final ids = List.generate(20, (i) => 'id-$i');
      final payload = buildReorderPayload(ids);
      expect(payload.length, equals(20));
      expect(payload.last['order_index'], equals(19));
    });
  });
}
```

**Assertion style** (from `audit_answer_service_test.dart` lines 29–31):
```dart
expect(result, equals(expectedValue));     // exact equality
expect(result, closeTo(71.43, 0.01));      // floating point
expect(result, isEmpty);                   // collection empty
```

**File header comment pattern** (lines 1–4 of `audit_answer_service_test.dart`):
```dart
// Unit tests for AuditAnswerService.calculateConformity (QUAL-01).
// All 6 response types + empty list + multi-weight scenarios.
// Uses the static form — does NOT instantiate AuditAnswerService
// (the `_client = Supabase.instance.client` field would throw in tests).
```

Adapt for the new file:
```dart
// Unit tests for AuditTemplateService.reorderItems payload logic (PERF-01).
// Tests the payload construction — does NOT instantiate AuditTemplateService
// (the `_client = Supabase.instance.client` field would throw in tests).
// Static verification: after applying the fix, audit_template_service.dart
// must NOT contain 'await _client' inside a for loop (grep check).
```

---

## Shared Patterns

### Service client reference
**Source:** Every file in `primeaudit/lib/services/` (e.g., `audit_answer_service.dart` line 10, `audit_template_service.dart` line 13)
**Apply to:** `audit_template_service.dart` (already present — do not change)
```dart
final _client = Supabase.instance.client;
```

### No internal exception handling in services
**Source:** `audit_answer_service.dart` (no try/catch anywhere)
**Apply to:** `audit_template_service.dart` reorderItems — do not add try/catch
Convention from CLAUDE.md: "Does not handle exceptions internally — callers are responsible for try/catch."

### Dart collection-for (list comprehension) for payload building
**Source:** RESEARCH.md Code Examples — same Dart 3 feature used throughout the codebase
**Apply to:** `reorderItems` payload construction and test helper
```dart
final payload = [
  for (int i = 0; i < ids.length; i++)
    {'id': ids[i], 'order_index': i},
];
```
This is idiomatic Dart 3 and consistent with the `switch` expression patterns already used in the models layer.

### Test file location convention
**Source:** `primeaudit/test/services/audit_answer_service_test.dart`
**Apply to:** New test file must be at `primeaudit/test/services/audit_template_service_reorder_test.dart`
Convention: test files mirror the source path under `test/`, suffixed `_test.dart`.

### Test run command
**Source:** RESEARCH.md Validation Architecture section
```
flutter test test/services/audit_template_service_reorder_test.dart
```
Run from `primeaudit/` directory.

---

## No Analog Found

None — both files have exact analogs in the codebase.

---

## Static Verification (Non-test Check)

After modifying `reorderItems`, the planner must include this grep check as a validation step:

```bash
# Must return 0 (no sequential awaits inside the method body):
grep -c "await _client" primeaudit/lib/services/audit_template_service.dart
# Expected: 1 (the single upsert call at the end of reorderItems)
```

The old code had N occurrences inside a `for` loop. After the fix there is exactly 1 `await _client` in `reorderItems`.

---

## Metadata

**Analog search scope:** `primeaudit/lib/services/`, `primeaudit/test/services/`, `primeaudit/test/models/`
**Files scanned:** `audit_template_service.dart`, `audit_answer_service.dart`, `audit_answer_service_test.dart`, `audit_template_test.dart`
**Pattern extraction date:** 2026-04-18
