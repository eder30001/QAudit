---
phase: 7
slug: dashboard
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-23
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` SDK (bundled with Flutter — no version) |
| **Config file** | none — standard Flutter test discovery |
| **Quick run command** | `flutter test test/services/dashboard_service_test.dart` |
| **Full suite command** | `flutter test` (run from `primeaudit/` directory) |
| **Estimated runtime** | ~10 seconds (unit tests only) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/services/dashboard_service_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 7-01-01 | 01 | 1 | DASH-01 | — | KPI total excludes cancelled audits | unit | `flutter test test/services/dashboard_service_test.dart` | ❌ W0 | ⬜ pending |
| 7-01-02 | 01 | 1 | DASH-01 | — | Auditor sees only own audits in KPI counts | unit | `flutter test test/services/dashboard_service_test.dart` | ❌ W0 | ⬜ pending |
| 7-01-03 | 01 | 1 | DASH-01 | — | Open actions returns 0 when corrective_actions table missing | unit | `flutter test test/services/dashboard_service_test.dart` | ❌ W0 | ⬜ pending |
| 7-01-04 | 01 | 1 | DASH-02 | — | Pull-to-refresh triggers _loadDashboard() | manual | — | manual only | ⬜ pending |
| 7-01-05 | 01 | 1 | DASH-03 | — | Chart data groups audits by templateName, averages conformityPercent | unit | `flutter test test/services/dashboard_service_test.dart` | ❌ W0 | ⬜ pending |
| 7-01-06 | 01 | 1 | DASH-03 | — | Empty chart state shown (no crash) when no concluida audits exist | unit | `flutter test test/services/dashboard_service_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `primeaudit/test/services/dashboard_service_test.dart` — unit tests for DASH-01 KPI counts, role scope filter, corrective_actions fallback, DASH-03 chart data grouping, empty chart state

*Note: If `DashboardService` is not created as a standalone class, aggregation helpers must be extracted to a testable location (pure functions or `@visibleForTesting` annotation on `_HomeScreenState` private methods).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Pull-to-refresh reloads all KPI cards and chart | DASH-02 | Widget test requires full Supabase initialization — too complex to mock for this phase | 1. Open dashboard, 2. Pull down from top of screen, 3. Verify loading spinner appears and all card values refresh |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
