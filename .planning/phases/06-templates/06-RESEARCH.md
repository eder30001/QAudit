# Phase 6: Templates - Research

**Researched:** 2026-04-18
**Domain:** Flutter UI (drag & drop reorder) + PostgREST query ordering
**Confidence:** HIGH

---

## Summary

Phase 6 fixes two distinct problems that share the same root concept: `order_index` must be respected everywhere. Problem 1 (TMPL-01) is a silent ordering bug in `AuditExecutionScreen._load()` — items are fetched with `.order('order_index')` at the PostgREST level, but then distributed into sections using `putIfAbsent + add`, which discards that sort order within each section bucket. A one-line sort after grouping fixes this with no schema or service changes. Problem 2 (TMPL-02) is a new capability: drag-and-drop reorder in `TemplateBuilderScreen`. The backend already has `reorderItems(List<String> ids)` via batch upsert (PERF-01, delivered in v1.0). The only work is wiring Flutter's built-in `ReorderableListView` to that service method.

No new packages, no migrations, no schema changes. All changes are UI-layer Dart code.

**Primary recommendation:** Fix the grouping sort in `AuditExecutionScreen._load()` (2-line change), then replace the flat `ListView` in `TemplateBuilderScreen` with `ReorderableListView`, calling `reorderItems` in `onReorder`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Item order in execution | Frontend (Screen) | — | Items fetched sorted by PostgREST; grouping into sections must preserve that sort |
| Drag-and-drop reorder UI | Frontend (Screen) | — | Flutter `ReorderableListView` handles gesture; screen calls service on drop |
| Persist new order | Service (`AuditTemplateService`) | Supabase/PostgREST | `reorderItems` batch upsert already exists (PERF-01) |
| RLS on `template_items` | Database (Supabase RLS) | — | Existing policies — no change needed for read/write on `order_index` |

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TMPL-01 | Perguntas são exibidas na ordem correta (order_index) na tela de execução da auditoria | Fix: sort items within each section bucket after grouping in `AuditExecutionScreen._load()`. PostgREST already orders by `order_index`; the grouping step loses that order. |
| TMPL-02 | Usuário pode reordenar perguntas no template builder via drag & drop com persistência no banco | Add: `ReorderableListView` in `TemplateBuilderScreen`; call existing `AuditTemplateService.reorderItems()` in `onReorder` callback. |
</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter` SDK (material) | `>=3.38.4` (locked) | `ReorderableListView`, `ListView`, `setState` | Built-in — no extra package needed for drag-and-drop |
| `supabase_flutter` | `2.12.2` (locked) | PostgREST `.order('order_index')` in service queries | Already in use; no change |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `AuditTemplateService.reorderItems` | — (existing) | Batch upsert of `order_index` via PostgREST upsert | Called from `onReorder` callback after user drops item |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ReorderableListView` (built-in) | `flutter_reorderable_list` (pub.dev) | External package adds dependency; built-in is sufficient and constraint-compliant |
| Optimistic local reorder | Reload from DB after upsert | Optimistic is smoother UX; reload from DB is simpler code — prefer optimistic for field-use responsiveness |

**Installation:** No new packages required.

---

## Architecture Patterns

### System Architecture Diagram

```
User drags item (TemplateBuilderScreen)
         │
         ▼
ReorderableListView.onReorder(oldIndex, newIndex)
         │
         ▼
[Screen] Adjust index (if oldIndex < newIndex: newIndex--)
         │
         ├─► setState() — update local _items list (optimistic)
         │
         └─► AuditTemplateService.reorderItems(ids)
                    │
                    ▼
             PostgREST UPSERT → template_items.order_index
                    │
                    ▼
         DB persists new order
                    │
                    ▼
         Next load reads .order('order_index') → correct order shown
```

For TMPL-01 (execution screen):

```
AuditExecutionScreen._load()
         │
         ▼
getItems(templateId) → PostgREST .order('order_index') → sorted list
         │
         ▼
Group by sectionId (putIfAbsent + add) — ORDER CURRENTLY LOST HERE
         │
         ▼
[FIX] Sort each bucket by orderIndex before assigning to section.items
         │
         ▼
Sections rendered in UI → items in correct order
```

### Recommended Project Structure

No structural changes. All edits within existing files:

```
primeaudit/lib/screens/
├── audit_execution_screen.dart      # TMPL-01: 2-line sort fix in _load()
└── templates/
    └── template_builder_screen.dart # TMPL-02: ReorderableListView + onReorder
primeaudit/lib/services/
└── audit_template_service.dart      # No change — reorderItems() already exists
```

### Pattern 1: Grouping with Preserved Order (TMPL-01 fix)

**What:** After grouping items into section buckets, sort each bucket by `orderIndex` before assigning.
**When to use:** Any time items are fetched sorted and then redistributed into groups via a Map.

```dart
// Source: codebase analysis of AuditExecutionScreen._load()
// CURRENT (buggy) — loses PostgREST sort order within sections:
for (final item in items) {
  itemsBySection.putIfAbsent(item.sectionId, () => []).add(item);
}
for (final s in sections) {
  s.items = itemsBySection[s.id] ?? [];
}

// FIXED — preserve order_index sort within each section bucket:
for (final item in items) {
  itemsBySection.putIfAbsent(item.sectionId, () => []).add(item);
}
for (final s in sections) {
  final bucket = itemsBySection[s.id] ?? [];
  bucket.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  s.items = bucket;
}
// Also sort the unsectioned bucket:
final unsectioned = itemsBySection[null] ?? [];
unsectioned.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
```

### Pattern 2: ReorderableListView with onReorder (TMPL-02)

**What:** Flutter built-in widget that supports drag-and-drop reordering. Calls `onReorder(oldIndex, newIndex)` when user drops an item.
**When to use:** Any flat list where order must be manually reorderable.

```dart
// Source: [CITED: api.flutter.dev/flutter/material/ReorderableListView-class.html]
// Critical: every child MUST have a unique Key.
// Critical: adjust newIndex when moving down (oldIndex < newIndex).

ReorderableListView(
  onReorder: (int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    // Persist to DB after optimistic local update
    _service.reorderItems(_items.map((i) => i.id).toList());
  },
  children: [
    for (final item in _items)
      ListTile(
        key: ValueKey(item.id),   // REQUIRED — must be unique and stable
        title: Text(item.question),
      ),
  ],
)
```

### Pattern 3: Section-Scoped Reorder (important constraint)

**What:** Items belong to sections. Dragging must be scoped per section — an item cannot be dragged from one section to another via this UI.
**When to use:** This phase.

The `TemplateBuilderScreen` renders sections separately. Each section's item list should be wrapped in its own `ReorderableListView`. Items in different sections cannot be reordered relative to each other via drag (cross-section reorder is out of scope for TMPL-02).

The "no section" items (`_items`) also get their own `ReorderableListView`.

**After drop:** call `reorderItems(sectionItems.map((i) => i.id).toList())` — this correctly assigns `order_index` 0..N within that section's items. This is correct because `order_index` is scoped per-section in practice (items from different sections are never mixed in one list).

### Anti-Patterns to Avoid

- **Global `ReorderableListView` spanning sections:** Mixing items across sections in one reorderable list breaks the section grouping and would require complex index mapping. Use one `ReorderableListView` per section.
- **Reloading from DB after every onReorder:** Causes visible flash and defeats the purpose of optimistic UI. Update local state with `setState`, then fire the async upsert in the background.
- **Missing key on ReorderableListView children:** Flutter throws an assertion error at runtime if any child lacks a key. Use `ValueKey(item.id)`.
- **Not adjusting newIndex:** When `oldIndex < newIndex`, you must decrement `newIndex` by 1 or items shift by one position from where the user dropped them. This is a documented Flutter behavior.
- **Calling reorderItems with section-mixed IDs:** `reorderItems` assigns `order_index` 0..N to the IDs passed. Passing IDs from multiple sections would corrupt the ordering of items in other sections.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Drag-and-drop reorder | Custom gesture recognizer with drag handles | `ReorderableListView` | Handles long-press gesture, visual feedback, accessibility, and platform-specific drag behavior |
| Batch order persistence | Loop with sequential `await` upsert per item | `reorderItems()` (already exists, PERF-01) | Single PostgREST UPSERT request for all items |
| Sort order within groups | Custom sort during DB fetch | Sort in Dart after grouping | PostgREST already orders items; Dart sort on the grouped bucket costs O(n log n) on a small list — acceptable |

**Key insight:** Both backend and Flutter SDK already provide what this phase needs. The work is wiring them together, not building new infrastructure.

---

## Common Pitfalls

### Pitfall 1: The Grouping Sort Bug (root cause of TMPL-01)

**What goes wrong:** Items appear in insertion order within each section, not `order_index` order. On small datasets this may appear correct (if items were created in order), but any reorder or out-of-order insert breaks the display.
**Why it happens:** `putIfAbsent + add` preserves insertion order of the `items` list as returned by PostgREST. PostgREST sorts the flat list by `order_index`, but once items are distributed into per-section buckets, that global sort is no longer meaningful within each bucket.
**How to avoid:** Explicitly sort each bucket after grouping: `bucket.sort((a, b) => a.orderIndex.compareTo(b.orderIndex))`.
**Warning signs:** Items within a section are not in the expected order after a manual reorder; new items appear at the top or bottom regardless of their `order_index`.

### Pitfall 2: ReorderableListView Key Assertion

**What goes wrong:** Flutter throws `FlutterError: A RenderSliverList ... does not have a key` at runtime.
**Why it happens:** `ReorderableListView` requires every direct child to have a unique `Key` to track identity during reorder animations.
**How to avoid:** Always pass `key: ValueKey(item.id)` on every child widget.
**Warning signs:** App crashes or Flutter asserts on first drag attempt.

### Pitfall 3: newIndex Not Adjusted

**What goes wrong:** After drop, the item ends up one position lower than where the user placed it.
**Why it happens:** When moving an item downward (`oldIndex < newIndex`), the item's removal shifts all subsequent indices by -1. Without adjusting `newIndex`, the insertion happens at the wrong position.
**How to avoid:** Apply `if (oldIndex < newIndex) newIndex -= 1;` before `removeAt`/`insert`.
**Warning signs:** Drag down always places item one slot too low; drag up works correctly.

### Pitfall 4: Cross-Section Reorder Confusion

**What goes wrong:** A flat `ReorderableListView` spanning all items (across sections) would allow dragging an item from Section A into Section B, but the `sectionId` foreign key on the item would not be updated, causing UI/DB inconsistency.
**Why it happens:** `ReorderableListView` only updates positional index, not domain membership.
**How to avoid:** Use one `ReorderableListView` per section. Items cannot be dragged between sections. This is the correct scope for TMPL-02.
**Warning signs:** If a single flat list is used, items can visually move to a different section group but their `section_id` remains unchanged in the DB.

### Pitfall 5: Async Error from reorderItems Not Surfaced

**What goes wrong:** The `onReorder` callback updates the local list optimistically, but if the DB upsert fails, the UI shows a different order than the DB. The user closes and reopens, and the old order is back.
**Why it happens:** Fire-and-forget async call with no error handling.
**How to avoid:** Wrap `reorderItems` in try/catch; on failure, show a SnackBar and call `_load()` to restore the true DB order.

---

## Code Examples

### TMPL-01: Full fixed grouping block (AuditExecutionScreen._load)

```dart
// Source: codebase analysis — fix for TMPL-01
final itemsBySection = <String?, List<TemplateItem>>{};
for (final item in items) {
  itemsBySection.putIfAbsent(item.sectionId, () => []).add(item);
}
// Preserve order_index sort within each section bucket
for (final s in sections) {
  final bucket = itemsBySection[s.id] ?? [];
  bucket.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  s.items = bucket;
}
final unsectioned = itemsBySection[null] ?? [];
unsectioned.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
```

### TMPL-02: Section-scoped ReorderableListView widget

```dart
// Source: [CITED: api.flutter.dev/flutter/material/ReorderableListView-class.html]
// + codebase patterns (AppTheme, AppColors, project conventions)

Widget _buildReorderableSection(TemplateSection section) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionHeader(section),
      if (section.items.isEmpty)
        _buildAddItemHint(sectionId: section.id)
      else
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) {
            if (oldIndex < newIndex) newIndex -= 1;
            setState(() {
              final item = section.items.removeAt(oldIndex);
              section.items.insert(newIndex, item);
            });
            _persistSectionOrder(section);
          },
          children: [
            for (final item in section.items)
              _buildItemCard(item, key: ValueKey(item.id), inSection: true),
          ],
        ),
    ],
  );
}

Future<void> _persistSectionOrder(TemplateSection section) async {
  try {
    await _service.reorderItems(section.items.map((i) => i.id).toList());
  } catch (e) {
    _showError('Erro ao salvar nova ordem: $e');
    _load(); // restore from DB
  }
}
```

### TMPL-02: Unsectioned items ReorderableListView

```dart
// Items sem seção — mesma lógica, usa _items da tela
Widget _buildReorderableUnsectioned() {
  if (_items.isEmpty) return const SizedBox.shrink();
  return ReorderableListView(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    onReorder: (oldIndex, newIndex) {
      if (oldIndex < newIndex) newIndex -= 1;
      setState(() {
        final item = _items.removeAt(oldIndex);
        _items.insert(newIndex, item);
      });
      _persistUnsectionedOrder();
    },
    children: [
      for (final item in _items)
        _buildItemCard(item, key: ValueKey(item.id)),
    ],
  );
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

**Note:** `_buildItemCard` must accept an optional `key` parameter. The current signature does not accept `key` explicitly — the plan must add `{Key? key}` or use `Container(key: ..., child: _buildItemCard(...))` as a wrapper.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `flutter_reorderable_list` (external package) | `ReorderableListView` built-in | Flutter 2.x | No extra dependency; API is stable |
| Sequential `await` per item in reorder | Batch upsert `reorderItems()` | Phase 4 (PERF-01) | Already delivered; just needs to be called |

**Deprecated/outdated:**
- Nothing applicable to this phase.

---

## Open Questions (RESOLVED)

1. **Should `_buildItemCard` show a drag handle icon?**
   - **RESOLVED (Plan 06-02):** Yes — add `Icons.drag_handle_rounded` as drag handle via `ReorderableListView` with `buildDefaultDragHandles: true` (Flutter default). UI-SPEC.md confirms: drag handle icon `Icons.drag_handle_rounded`, size 20, `textSecondary` color, placed as leading widget in each tile. This is consistent with the existing handle icon used in `_showItemForm` options list (line ~195).

2. **`TemplateBuilderScreen._buildItemCard` key parameter**
   - **RESOLVED (Plan 06-02):** Use `KeyedSubtree(key: ValueKey(item.id), child: _buildItemCard(item))` wrapper inside `ReorderableListView.children`. This avoids changing `_buildItemCard`'s signature. Confirmed in 06-02 `must_haves`, `key_links`, and PATTERNS.md.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is purely Dart/Flutter code changes. No new external tools, services, CLIs, or runtimes are required beyond the existing Flutter SDK already in use.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` SDK (built-in, no extra packages) |
| Config file | `primeaudit/analysis_options.yaml` (lints), no separate test config |
| Quick run command | `cd primeaudit && flutter test test/screens/ test/services/ -x` |
| Full suite command | `cd primeaudit && flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TMPL-01 | Items within a section are sorted by `orderIndex` after grouping | Unit | `flutter test test/screens/audit_execution_ordering_test.dart` | Wave 0 |
| TMPL-01 | Unsectioned items bucket is sorted by `orderIndex` | Unit | `flutter test test/screens/audit_execution_ordering_test.dart` | Wave 0 |
| TMPL-02 | `onReorder` index adjustment is correct (oldIndex < newIndex decrements newIndex) | Unit | `flutter test test/screens/template_builder_reorder_test.dart` | Wave 0 |
| TMPL-02 | After reorder, IDs passed to `reorderItems` match new order | Unit | `flutter test test/screens/template_builder_reorder_test.dart` | Wave 0 |
| TMPL-02 | `reorderItems` payload assigns correct `order_index` values | Unit (existing) | `flutter test test/services/audit_template_service_reorder_test.dart` | EXISTING |

**Notes on testability:**
- `AuditExecutionScreen._load()` grouping logic cannot be tested as a widget test easily (requires Supabase). Extract the grouping + sort logic into a pure static function or test the sort behavior with a standalone helper (mirror pattern used in `audit_template_service_reorder_test.dart`).
- The `onReorder` index adjustment logic (`if (oldIndex < newIndex) newIndex--; removeAt; insert`) is pure state manipulation. Test it as a helper function mirroring the screen logic, without instantiating the widget.

### Sampling Rate

- **Per task commit:** `cd primeaudit && flutter test test/screens/ test/services/ -x`
- **Per wave merge:** `cd primeaudit && flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `primeaudit/test/screens/audit_execution_ordering_test.dart` — covers TMPL-01 (grouping sort correctness as pure function test)
- [ ] `primeaudit/test/screens/template_builder_reorder_test.dart` — covers TMPL-02 (onReorder index logic as pure function test)

*(Existing `test/services/audit_template_service_reorder_test.dart` already covers the reorderItems payload — no changes needed.)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | yes (partial) | Existing RLS on `template_items` — only `adm`, `superuser`, `dev` can write; UI already gates the template builder to admin roles |
| V5 Input Validation | no | No new user input — drag reorder only modifies order, not content |
| V6 Cryptography | no | — |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Auditor reorders items via direct API call | Tampering | Existing RLS on `template_items` blocks UPDATE for `auditor` role at DB level |
| Out-of-bounds index in onReorder | Tampering (local) | Index adjustment pattern + Dart List bounds check (throws RangeError before DB call) |

**No new security surface introduced by this phase.** The `reorderItems` upsert only updates `order_index` on existing rows. RLS already restricts writes to `template_items` to admin roles.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `template_items` RLS already restricts UPDATE to admin roles (`adm`, `superuser`, `dev`) | Security Domain | If auditors can write `order_index`, they could reorder other companies' templates — needs RLS verification before Phase 6 deploy |
| A2 | Items without a section (`sectionId == null`) have `order_index` values that are meaningful and continuous within that group | Common Pitfalls | If all unsectioned items share `order_index = 0`, the sort has no effect and reorder persistence is broken |

---

## Sources

### Primary (HIGH confidence)
- Codebase: `primeaudit/lib/screens/audit_execution_screen.dart` — verified grouping code (lines 74-106)
- Codebase: `primeaudit/lib/screens/templates/template_builder_screen.dart` — verified current builder structure
- Codebase: `primeaudit/lib/services/audit_template_service.dart` — verified `reorderItems` exists (line 211-218)
- Codebase: `primeaudit/lib/models/audit_template.dart` — verified `TemplateItem.orderIndex` field
- [CITED: api.flutter.dev/flutter/material/ReorderableListView-class.html] — `onReorder` signature, key requirement, index adjustment pattern

### Secondary (MEDIUM confidence)
- WebSearch: Flutter `ReorderableListView` 2024 community articles — confirmed standard index adjustment pattern and `ValueKey` requirement (multiple sources agree)

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — built-in Flutter widget, verified existing service method
- Architecture: HIGH — codebase directly inspected, bug root cause confirmed
- Pitfalls: HIGH — verified from direct code inspection (grouping bug is deterministic)

**Research date:** 2026-04-18
**Valid until:** 2026-07-18 (stable Flutter SDK APIs; 90-day estimate)
