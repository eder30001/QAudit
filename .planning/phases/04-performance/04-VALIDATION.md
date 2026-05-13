---
phase: 4
slug: performance
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK bundled) |
| **Config file** | `primeaudit/analysis_options.yaml` (lint); sem config de test separada |
| **Quick run command** | `flutter test test/services/audit_template_service_reorder_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/services/audit_template_service_reorder_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 0 | PERF-01 | — | N/A | unit scaffold | `flutter test test/services/audit_template_service_reorder_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | PERF-01 | — | N/A | unit | `flutter test test/services/audit_template_service_reorder_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | PERF-01 | — | N/A | static (grep) | `grep -c "await _client" primeaudit/lib/services/audit_template_service.dart` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `primeaudit/test/services/audit_template_service_reorder_test.dart` — stubs/testes para PERF-01 (payload batch, lista vazia, 1 item, 20 itens)

*Infraestrutura de teste já existe (Fases 1–3). Apenas o arquivo de teste específico precisa ser criado.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| RLS de `template_items` permite upsert batch por adm/superuser | PERF-01 | Requer ambiente Supabase real com dados de teste | Executar `reorderItems(['id1','id2'])` como usuário `adm` no app; confirmar no Supabase Dashboard que nenhum erro RLS é lançado |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
