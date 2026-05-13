# Phase 6: Templates - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 4 (2 modified source files + 2 new test files)
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `primeaudit/lib/screens/audit_execution_screen.dart` | screen | request-response | self (existing file being patched) | exact |
| `primeaudit/lib/screens/templates/template_builder_screen.dart` | screen | CRUD + event-driven | self (existing file being patched) | exact |
| `primeaudit/test/screens/audit_execution_ordering_test.dart` | test | batch/transform | `primeaudit/test/services/audit_template_service_reorder_test.dart` | role-match |
| `primeaudit/test/screens/template_builder_reorder_test.dart` | test | batch/transform | `primeaudit/test/services/audit_template_service_reorder_test.dart` | exact |

---

## Pattern Assignments

### `primeaudit/lib/screens/audit_execution_screen.dart` (screen, request-response)
**Change scope:** TMPL-01 — 2-line fix inside `_load()` at lines 74–83.

**Analog:** self — the existing `_load()` method in this file.

**Current (buggy) grouping block** (lines 74–83):
```dart
// Associates items to sections — ORDER LOST within each bucket
final itemsBySection = <String?, List<TemplateItem>>{};
for (final item in items) {
  itemsBySection.putIfAbsent(item.sectionId, () => []).add(item);
}
for (final s in sections) {
  s.items = itemsBySection[s.id] ?? [];
}

// Items sem seção ficam numa seção fictícia "Geral"
final unsectioned = itemsBySection[null] ?? [];
```

**Fixed grouping block — copy this exactly:**
```dart
// Associates items to sections — preserves order_index sort within each bucket
final itemsBySection = <String?, List<TemplateItem>>{};
for (final item in items) {
  itemsBySection.putIfAbsent(item.sectionId, () => []).add(item);
}
for (final s in sections) {
  final bucket = itemsBySection[s.id] ?? [];
  bucket.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  s.items = bucket;
}

// Items sem seção ficam numa seção fictícia "Geral"
final unsectioned = itemsBySection[null] ?? [];
unsectioned.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
```

**Key field:** `TemplateItem.orderIndex` (int, line 14 of `audit_template.dart`) — used in comparator.

**Error handling pattern** (lines 111–113 — no change needed, already correct):
```dart
} catch (e) {
  if (mounted) setState(() { _error = '$e'; _loading = false; });
}
```

**Loading state pattern** (lines 57–58 — no change needed):
```dart
Future<void> _load() async {
  setState(() { _loading = true; _error = null; });
```

---

### `primeaudit/lib/screens/templates/template_builder_screen.dart` (screen, CRUD + event-driven)
**Change scope:** TMPL-02 — replace flat `ListView` children for items with `ReorderableListView` per section.

**Analog:** self — the existing `_buildSection()` and `_buildItemCard()` methods in this file.

**Imports pattern** (lines 1–5 — no change needed):
```dart
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/audit_template.dart';
import '../../services/audit_template_service.dart';
```

**Current flat rendering inside `_buildSection()`** (lines 535–545 — to be replaced):
```dart
if (section.items.isEmpty)
  Padding(
    padding: const EdgeInsets.only(left: 12, bottom: 8),
    child: TextButton.icon(
      onPressed: () => _showItemForm(sectionId: section.id),
      icon: const Icon(Icons.add, size: 16),
      label: const Text('Adicionar item', style: TextStyle(fontSize: 12)),
    ),
  )
else
  ...section.items.map((item) => _buildItemCard(item, inSection: true)),
```

**ReorderableListView replacement — copy this for sectioned items:**
```dart
if (section.items.isEmpty)
  Padding(
    padding: const EdgeInsets.only(left: 12, bottom: 8),
    child: TextButton.icon(
      onPressed: () => _showItemForm(sectionId: section.id),
      icon: const Icon(Icons.add, size: 16),
      label: const Text('Adicionar item', style: TextStyle(fontSize: 12)),
    ),
  )
else
  ReorderableListView(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    onReorder: (int oldIndex, int newIndex) {
      if (oldIndex < newIndex) newIndex -= 1;
      setState(() {
        final item = section.items.removeAt(oldIndex);
        section.items.insert(newIndex, item);
      });
      _persistSectionOrder(section);
    },
    children: [
      for (final item in section.items)
        KeyedSubtree(
          key: ValueKey(item.id),
          child: _buildItemCard(item, inSection: true),
        ),
    ],
  ),
```

**Current flat rendering for unsectioned items inside `build()`** (lines 423–427 — to be replaced):
```dart
if (_items.isNotEmpty) ...[
  ..._items.map((item) => _buildItemCard(item)),
  const SizedBox(height: 8),
],
```

**ReorderableListView replacement — copy this for unsectioned items:**
```dart
if (_items.isNotEmpty) ...[
  ReorderableListView(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    onReorder: (int oldIndex, int newIndex) {
      if (oldIndex < newIndex) newIndex -= 1;
      setState(() {
        final item = _items.removeAt(oldIndex);
        _items.insert(newIndex, item);
      });
      _persistUnsectionedOrder();
    },
    children: [
      for (final item in _items)
        KeyedSubtree(
          key: ValueKey(item.id),
          child: _buildItemCard(item),
        ),
    ],
  ),
  const SizedBox(height: 8),
],
```

**New persist helpers — add these methods to `_TemplateBuilderScreenState`:**
```dart
Future<void> _persistSectionOrder(TemplateSection section) async {
  try {
    await _service.reorderItems(section.items.map((i) => i.id).toList());
  } catch (e) {
    _showError('Erro ao salvar nova ordem: $e');
    _load(); // restore true DB order on failure
  }
}

Future<void> _persistUnsectionedOrder() async {
  try {
    await _service.reorderItems(_items.map((i) => i.id).toList());
  } catch (e) {
    _showError('Erro ao salvar nova ordem: $e');
    _load();
  }
}
```

**Existing error pattern** (line 361–366 — `_persistX` must use this same pattern):
```dart
void _showError(String msg) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: AppColors.error,
    behavior: SnackBarBehavior.floating,
  ));
}
```

**Existing service call** (`audit_template_service.dart` lines 211–218 — no change needed):
```dart
Future<void> reorderItems(List<String> ids) async {
  if (ids.isEmpty) return;
  final payload = [
    for (int i = 0; i < ids.length; i++)
      {'id': ids[i], 'order_index': i},
  ];
  await _client.from('template_items').upsert(payload);
}
```

**`_buildItemCard` signature** (line 551 — no change needed; `KeyedSubtree` wraps it externally):
```dart
Widget _buildItemCard(TemplateItem item, {bool inSection = false}) {
```

---

### `primeaudit/test/screens/audit_execution_ordering_test.dart` (test, batch/transform)
**Change scope:** TMPL-01 — new file, Wave 0 gap.

**Analog:** `primeaudit/test/services/audit_template_service_reorder_test.dart`

**Test file structure pattern** (lines 1–17 of analog):
```dart
// Unit tests for [feature] logic ([REQUIREMENT-ID]).
// Tests the [specific logic] — does NOT instantiate [Service/Screen]
// ([reason — e.g., Supabase dependency]).

import 'package:flutter_test/flutter_test.dart';

// Pure helper mirroring the logic under test. Kept in sync manually.
List<Map<String, dynamic>> buildReorderPayload(List<String> ids) {
  return [
    for (int i = 0; i < ids.length; i++)
      {'id': ids[i], 'order_index': i},
  ];
}

void main() {
  group('[ClassName].[method] — [description] ([REQ-ID])', () {
    test('[scenario]', () {
      expect([actual], [matcher]);
    });
  });
}
```

**Copy this structure for `audit_execution_ordering_test.dart`:**
```dart
// Unit tests for AuditExecutionScreen._load() grouping sort correctness (TMPL-01).
// Tests the bucket sort logic as a pure function — does NOT instantiate the
// screen (Supabase.instance.client would throw in tests).

import 'package:flutter_test/flutter_test.dart';

// Mirrors the TemplateItem fields needed for sort testing.
// Keep in sync with lib/models/audit_template.dart manually.
class _FakeItem {
  final String id;
  final String? sectionId;
  final int orderIndex;
  _FakeItem({required this.id, this.sectionId, required this.orderIndex});
}

// Pure helper mirroring the grouping + sort logic in AuditExecutionScreen._load().
Map<String?, List<_FakeItem>> groupAndSort(List<_FakeItem> items) {
  final bySection = <String?, List<_FakeItem>>{};
  for (final item in items) {
    bySection.putIfAbsent(item.sectionId, () => []).add(item);
  }
  for (final entry in bySection.entries) {
    entry.value.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }
  return bySection;
}

void main() {
  group('AuditExecutionScreen._load() — grouping sort (TMPL-01)', () {
    test('items within a section are sorted by orderIndex after grouping', () {
      // ...
    });

    test('unsectioned items bucket is sorted by orderIndex', () {
      // ...
    });

    test('out-of-order insertion is corrected by sort', () {
      // ...
    });
  });
}
```

---

### `primeaudit/test/screens/template_builder_reorder_test.dart` (test, event-driven)
**Change scope:** TMPL-02 — new file, Wave 0 gap.

**Analog:** `primeaudit/test/services/audit_template_service_reorder_test.dart` (exact match — same pure-function test approach)

**Copy this structure for `template_builder_reorder_test.dart`:**
```dart
// Unit tests for TemplateBuilderScreen onReorder index logic (TMPL-02).
// Tests the reorder state mutation as a pure function — does NOT instantiate
// the screen (Supabase dependency).

import 'package:flutter_test/flutter_test.dart';

// Pure helper mirroring the onReorder callback logic.
// Matches: if (oldIndex < newIndex) newIndex -= 1; removeAt; insert.
List<String> applyReorder(List<String> ids, int oldIndex, int newIndex) {
  final list = List<String>.from(ids);
  if (oldIndex < newIndex) newIndex -= 1;
  final item = list.removeAt(oldIndex);
  list.insert(newIndex, item);
  return list;
}

void main() {
  group('TemplateBuilderScreen onReorder — index adjustment (TMPL-02)', () {
    test('move item down: index adjustment is applied (oldIndex < newIndex)', () {
      // ...
    });

    test('move item up: no adjustment needed (oldIndex > newIndex)', () {
      // ...
    });

    test('IDs passed to reorderItems match the new list order after reorder', () {
      // ...
    });
  });
}
```

---

## Shared Patterns

### SnackBar error display
**Source:** `primeaudit/lib/screens/templates/template_builder_screen.dart` lines 361–366
**Apply to:** `_persistSectionOrder()` and `_persistUnsectionedOrder()` in `template_builder_screen.dart`
```dart
void _showError(String msg) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: AppColors.error,
    behavior: SnackBarBehavior.floating,
  ));
}
```

### `_load()` as DB state restore
**Source:** `primeaudit/lib/screens/templates/template_builder_screen.dart` lines 38–59
**Apply to:** `_persistSectionOrder()` and `_persistUnsectionedOrder()` catch blocks — call `_load()` to restore true DB order on upsert failure. This is the project convention (screens reload from DB on error rather than maintaining rollback state).

### Pure-function test helper pattern
**Source:** `primeaudit/test/services/audit_template_service_reorder_test.dart` lines 12–17
**Apply to:** Both new test files — extract the logic under test as a standalone Dart function at file scope, then test that function without Flutter or Supabase dependencies.
```dart
// Example: mirror the logic inline in the test file
List<Map<String, dynamic>> buildReorderPayload(List<String> ids) {
  return [
    for (int i = 0; i < ids.length; i++)
      {'id': ids[i], 'order_index': i},
  ];
}
```

### `mounted` guard before `setState`
**Source:** `primeaudit/lib/screens/audit_execution_screen.dart` lines 94, 319
**Apply to:** Any `setState` call inside async methods (already applied in both existing screens — maintain this pattern in new helpers).
```dart
if (mounted) {
  setState(() { /* ... */ });
}
```

### `KeyedSubtree` wrapping for `ReorderableListView` children
**Source:** Flutter SDK API (no existing codebase analog — `ReorderableListView` is new in this phase)
**Apply to:** Every child inside `ReorderableListView.children` in `template_builder_screen.dart`. Use `KeyedSubtree(key: ValueKey(item.id), child: _buildItemCard(...))` to avoid modifying `_buildItemCard`'s signature.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| — | — | — | All files have clear analogs within the existing codebase |

No files in this phase require fallback to external documentation alone. `ReorderableListView` is the only new API; its `onReorder` index-adjustment pattern is documented in the RESEARCH.md code examples and mirrored in the test helper.

---

## Metadata

**Analog search scope:** `primeaudit/lib/screens/`, `primeaudit/lib/services/`, `primeaudit/lib/models/`, `primeaudit/test/`
**Files scanned:** 14 (all `.dart` files in the glob result + 2 test files read in full)
**Pattern extraction date:** 2026-04-18
