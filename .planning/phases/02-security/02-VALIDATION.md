---
phase: 2
slug: security
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-17
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | primeaudit/pubspec.yaml |
| **Quick run command** | `flutter test primeaudit/test/core/cnpj_validator_test.dart` |
| **Full suite command** | `flutter test primeaudit/test/` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test primeaudit/test/core/cnpj_validator_test.dart`
- **After every plan wave:** Run `flutter test primeaudit/test/`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 1 | SEC-03 | — | get_my_role() retorna NULL para usuário inativo | manual-sql | — | ❌ W0 | ⬜ pending |
| 2-01-02 | 01 | 1 | SEC-03 | — | get_my_company_id() retorna NULL para usuário inativo | manual-sql | — | ❌ W0 | ⬜ pending |
| 2-02-01 | 02 | 1 | SEC-01 | — | RLS habilitado em perimeters, audit_types, audit_templates, template_items | manual-sql | — | ❌ W0 | ⬜ pending |
| 2-02-02 | 02 | 1 | SEC-02 | — | auditor não pode fazer UPDATE em profiles.role | manual-sql | — | ❌ W0 | ⬜ pending |
| 2-03-01 | 03 | 2 | SEC-04 | — | CNPJ com checksum inválido rejeitado no validator | unit | `flutter test primeaudit/test/core/cnpj_validator_test.dart` | ❌ W0 | ⬜ pending |
| 2-03-02 | 03 | 2 | SEC-04 | — | CNPJ válido aceito no validator | unit | `flutter test primeaudit/test/core/cnpj_validator_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `primeaudit/test/core/cnpj_validator_test.dart` — stubs para SEC-04 (isValidCnpj, validateCnpj)
- [ ] `primeaudit/test/` — diretório de testes (criar se não existir)

*RLS/SQL verifications are manual-only — no Wave 0 test stubs required for SEC-01, SEC-02, SEC-03.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| get_my_role() retorna NULL para active=false | SEC-03 | Requer execução de SQL no Supabase dashboard | Execute `SELECT get_my_role()` autenticado como usuário inativo; deve retornar NULL |
| Usuário inativo não lê registros protegidos | SEC-03 | Requer JWT válido de usuário inativo | Usar Supabase REST API com JWT do usuário inativo; esperar 0 rows |
| auditor não pode alterar profiles.role | SEC-02 | Requer teste com token de role auditor | Usar client autenticado como auditor; chamar UPDATE em profiles; esperar erro PostgREST |
| SECURITY-AUDIT.md documenta todas as tabelas | SEC-01 | Revisão manual do documento | Ler SECURITY-AUDIT.md e verificar que cada tabela tem entrada de policy |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
