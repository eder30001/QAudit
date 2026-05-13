---
phase: 8
slug: corrective-actions
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-25
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK — no external packages) |
| **Config file** | `primeaudit/analysis_options.yaml` (no separate test config) |
| **Quick run command** | `cd primeaudit && flutter test test/models/corrective_action_test.dart test/services/corrective_action_service_test.dart -x` |
| **Full suite command** | `cd primeaudit && flutter test` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd primeaudit && flutter test test/models/corrective_action_test.dart test/services/corrective_action_service_test.dart -x`
- **After every plan wave:** Run `cd primeaudit && flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 8-01-01 | 01 | 1 | ACT-01, ACT-02, ACT-03, ACT-04 | T-8-01 | RLS restricts corrective_actions to company scope via `get_my_company_id()` | integration (manual) | `supabase db push` | ❌ W0 | ⬜ pending |
| 8-01-02 | 01 | 1 | ACT-01, ACT-03 | — | N/A | unit | `cd primeaudit && flutter test test/models/corrective_action_test.dart -x` | ❌ W0 | ⬜ pending |
| 8-01-03 | 01 | 1 | ACT-02, ACT-03, ACT-04 | — | N/A | unit | `cd primeaudit && flutter test test/services/corrective_action_service_test.dart -x` | ❌ W0 | ⬜ pending |
| 8-02-01 | 02 | 2 | ACT-02 | T-8-02 | Form validator rejects past due dates; responsible bound to UUID from UserService (no free text) | unit + manual | `cd primeaudit && flutter test test/services/corrective_action_service_test.dart -x` | ❌ W0 | ⬜ pending |
| 8-02-02 | 02 | 2 | ACT-02 | — | N/A | manual | manual smoke test | — | ⬜ pending |
| 8-03-01 | 03 | 3 | ACT-01 | — | N/A | manual | manual smoke test | — | ⬜ pending |
| 8-04-01 | 04 | 4 | ACT-03 | T-8-03 | RBAC: buttons hidden for unauthorized roles; status escalation blocked at UI layer | unit + manual | `cd primeaudit && flutter test test/services/corrective_action_service_test.dart -x` | ❌ W0 | ⬜ pending |
| 8-04-02 | 04 | 4 | ACT-04 | — | N/A | manual | manual smoke test | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/models/corrective_action_test.dart` — stubs covering `CorrectiveAction.fromMap()` (all fields), `CorrectiveActionStatus.fromDb()` (all 6 DB values), `CorrectiveAction.isOverdue` (past date + non-final), `CorrectiveActionStatus.isFinal` (aprovada/rejeitada/cancelada) — REQ ACT-01, ACT-03
- [ ] `test/services/corrective_action_service_test.dart` — stubs covering `_isNonConforming()` pure logic (ok_nok, yes_no, scale_1_5, percentage, text, null/empty), `_canTransitionTo()` RBAC logic (admin all, responsible limited, auditor limited, cancel admin-only), open count definition — REQ ACT-02, ACT-03, ACT-04

*No new test framework installation needed — `flutter_test` SDK is already in `primeaudit/pubspec.yaml`.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| List screen renders with real Supabase data, status and responsible filters work end-to-end | ACT-01 | Requires live DB connection and real `corrective_actions` rows | Log in as auditor; navigate to Acoes Corretivas; verify list loads; apply status filter "Aberta"; verify only open actions shown; apply responsible filter and verify narrowing |
| Action icon appears on item after selecting 'nok' answer; form saves to DB; returns to execution | ACT-02 | Full UI flow requires device/emulator with Supabase connected | Execute audit; answer a ok_nok question with 'nok'; tap icon; fill form; submit; confirm snackbar "Acao corretiva criada com sucesso"; return to execution |
| Transition buttons appear/hide correctly per role on device | ACT-03 | Role-gated UI requires real auth session per role | Log in as auditor (not responsible); open action in em_avaliacao; verify "Aprovar" and "Rejeitar acao" buttons visible; verify no "Cancelar acao" button; tap "Aprovar"; confirm status chip changes to "Aprovada" |
| Badge count updates after returning from CorrectiveActionsScreen | ACT-04 | UI state update requires navigation round-trip | From HomeScreen drawer; observe badge count; navigate to list; return; verify badge count unchanged (no new actions created); create new action; return to HomeScreen; verify badge increments |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
