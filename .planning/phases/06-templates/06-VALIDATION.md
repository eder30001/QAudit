---
phase: 6
slug: templates
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` SDK (built-in, no extra packages) |
| **Config file** | `primeaudit/analysis_options.yaml` (lints), no separate test config |
| **Quick run command** | `cd primeaudit && flutter test test/screens/ test/services/ -x` |
| **Full suite command** | `cd primeaudit && flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd primeaudit && flutter test test/screens/ test/services/ -x`
- **After every plan wave:** Run `cd primeaudit && flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 6-01-01 | 01 | 0 | TMPL-01 | — | N/A | unit | `flutter test test/screens/audit_execution_ordering_test.dart` | ❌ W0 | ⬜ pending |
| 6-01-02 | 01 | 1 | TMPL-01 | — | N/A | unit | `flutter test test/screens/audit_execution_ordering_test.dart` | ❌ W0 | ⬜ pending |
| 6-02-01 | 02 | 0 | TMPL-02 | — | N/A | unit | `flutter test test/screens/template_builder_reorder_test.dart` | ❌ W0 | ⬜ pending |
| 6-02-02 | 02 | 1 | TMPL-02 | — | N/A | unit | `flutter test test/screens/template_builder_reorder_test.dart` | ❌ W0 | ⬜ pending |
| 6-02-03 | 02 | 1 | TMPL-02 | — | Existing RLS blocks auditor UPDATE on template_items | unit (existing) | `flutter test test/services/audit_template_service_reorder_test.dart` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `primeaudit/test/screens/audit_execution_ordering_test.dart` — pure function test for TMPL-01 grouping + sort logic
- [ ] `primeaudit/test/screens/template_builder_reorder_test.dart` — pure function test for TMPL-02 onReorder index adjustment and ID ordering

*Existing `test/services/audit_template_service_reorder_test.dart` already covers the `reorderItems` payload — no changes needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Drag handle visible on item cards in TemplateBuilderScreen | TMPL-02 | Widget UI rendering requires device/emulator | Open template builder on Android emulator, confirm drag handle icon (`drag_handle_rounded`) is visible on each item card |
| Long-press to drag activates reorder on Android | TMPL-02 | Gesture requires physical/emulated touch | Long-press an item in template builder, drag to new position, release; confirm item appears in new position |
| Order persists after close + reopen | TMPL-02 | End-to-end DB round-trip | Reorder items, close template builder, reopen; confirm new order matches what was set |
| Execution screen shows items in `order_index` order | TMPL-01 | Requires real data with non-trivial `order_index` values | Open an audit with a template that has reordered items; confirm display order matches `order_index` values |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
