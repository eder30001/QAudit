---
phase: 3
slug: test-coverage
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (Flutter SDK, built-in) |
| **Config file** | none — uses Flutter defaults |
| **Quick run command** | `flutter test` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 3-01-01 | 01 | 1 | QUAL-01 | — | N/A | unit | `flutter test test/services/audit_answer_service_test.dart` | ❌ W0 | ⬜ pending |
| 3-01-02 | 01 | 1 | QUAL-02 | — | N/A | unit | `flutter test test/models/app_role_test.dart` | ❌ W0 | ⬜ pending |
| 3-01-03 | 01 | 1 | QUAL-03 | — | N/A | unit | `flutter test test/models/` | ❌ W0 | ⬜ pending |
| 3-01-04 | 01 | 1 | QUAL-04 | — | N/A | unit | `flutter test test/models/perimeter_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/audit_answer_service_test.dart` — stubs for QUAL-01
- [ ] `test/models/app_role_test.dart` — stubs for QUAL-02
- [ ] `test/models/audit_test.dart` — stubs for QUAL-03 (Audit)
- [ ] `test/models/audit_answer_test.dart` — stubs for QUAL-03 (AuditAnswer)
- [ ] `test/models/audit_template_test.dart` — stubs for QUAL-03 (AuditTemplate + TemplateItem)
- [ ] `test/models/perimeter_test.dart` — stubs for QUAL-03 (Perimeter.fromMap) + QUAL-04 (buildTree)
- [ ] `test/models/company_test.dart` — stubs for QUAL-03 (Company)
- [ ] `test/models/app_user_test.dart` — stubs for QUAL-03 (AppUser)

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
