# Phase 7: Dashboard - Pattern Map

**Mapped:** 2026-04-23
**Files analyzed:** 4 (2 modified, 1 created, 1 test created)
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `primeaudit/lib/screens/home_screen.dart` | screen (modify) | request-response | `primeaudit/lib/screens/audits_screen.dart` | exact — same load/setState/error pattern |
| `primeaudit/lib/services/dashboard_service.dart` | service (create) | request-response | `primeaudit/lib/services/company_service.dart` | role-match — same Supabase client + query pattern |
| `primeaudit/pubspec.yaml` | config (modify) | — | `primeaudit/pubspec.yaml` lines 30-37 | exact — add dependency under `dependencies:` |
| `primeaudit/test/services/dashboard_service_test.dart` | test (create) | — | `primeaudit/test/services/audit_answer_service_test.dart` | exact — pure-function unit test structure |

---

## Pattern Assignments

### `primeaudit/lib/screens/home_screen.dart` (screen, request-response — MODIFY)

**Primary analog:** `primeaudit/lib/screens/audits_screen.dart`
**Secondary analog (self):** `primeaudit/lib/screens/home_screen.dart` (existing `_loadProfile()`, `_summaryCard()`)

---

#### State fields to add to `_HomeScreenState` (new fields, alongside existing `_role`, `_name`, `_loading`)

Pattern source: project's `_isLoading`/`_error` convention visible in `audits_screen.dart` lines 109-120 and `home_screen.dart` lines 38-58.

```dart
// Add inside _HomeScreenState — after existing _loading field
int _totalAudits = 0;
int _pendingAudits = 0;
int _overdueAudits = 0;
int _openActions = 0;
int _companiesCount = 0;        // only populated for superuser/dev (D-07)
List<_TemplateConformity> _chartData = [];
bool _dashboardLoading = false;
String? _dashboardError;
```

---

#### Import additions (lines 1-13 of `home_screen.dart` — add 2 imports)

Existing import block (`home_screen.dart` lines 1-13):
```dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_roles.dart';
import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../services/company_context_service.dart';
import '../services/user_service.dart';
import 'admin/admin_screen.dart';
import 'audits_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'templates/audit_types_screen.dart';
import 'settings_screen.dart';
```

Add these two imports (after `user_service.dart` import):
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/audit_service.dart';
import '../services/dashboard_service.dart';
```

And add the service instance to `_HomeScreenState` fields (after `_userService`):
```dart
final _auditService = AuditService();
final _dashboardService = DashboardService();
```

---

#### `_loadProfile()` chain pattern — call `_loadDashboard()` after role is set

Existing `_loadProfile()` (`home_screen.dart` lines 38-59) — the chaining point is after `setState()` sets `_role`:
```dart
// EXISTING (home_screen.dart lines 38-59):
Future<void> _loadProfile() async {
  try {
    final user = _authService.currentUser;
    if (user == null) return;
    final profile = await _userService.getById(user.id);
    await CompanyContextService.instance.init(
      role: profile.role,
      profileCompanyId: profile.companyId,
      profileCompanyName: profile.companyName,
    );
    if (mounted) {
      setState(() {
        _role = profile.role;
        _name = profile.fullName;
        _email = profile.email;
      });
    }
    // ADD: chain dashboard load here — _role and CompanyContextService now ready
    await _loadDashboard();
  } catch (_) {
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

---

#### `_loadDashboard()` core pattern

Source: mirrors `_load()` in `audits_screen.dart` lines 109-120, extended for multi-fetch and role scoping.

```dart
Future<void> _loadDashboard() async {
  if (!mounted) return;
  setState(() { _dashboardLoading = true; _dashboardError = null; });
  try {
    final companyId = CompanyContextService.instance.activeCompanyId;
    final currentUserId = _authService.currentUser?.id ?? '';

    // Fetch audits (single fetch, Dart-side filter for auditor role — D-05/D-06)
    final all = await _auditService.getAudits(companyId: companyId);
    final audits = (AppRole.isSuperOrDev(_role) || AppRole.canAccessAdmin(_role))
        ? all
        : all.where((a) => a.auditorId == currentUserId).toList();

    // Compute KPIs in Dart (D-01/D-02/D-03)
    final total   = audits.where((a) => a.status != AuditStatus.cancelada).length;
    final pending = audits.where((a) => a.status == AuditStatus.emAndamento).length;
    final overdue = audits.where((a) => a.status == AuditStatus.atrasada).length;

    // Open actions — fallback 0 until Phase 8 creates the table (D-04)
    final openActions = await _dashboardService.getOpenActionsCount(companyId);

    // Companies count — superuser/dev only (D-07)
    int companiesCount = 0;
    if (AppRole.isSuperOrDev(_role)) {
      companiesCount = await _dashboardService.getCompaniesCount();
    }

    // Chart data aggregation (pure Dart)
    final chartData = _buildChartData(audits);

    if (mounted) {
      setState(() {
        _totalAudits     = total;
        _pendingAudits   = pending;
        _overdueAudits   = overdue;
        _openActions     = openActions;
        _companiesCount  = companiesCount;
        _chartData       = chartData;
      });
    }
  } catch (e) {
    if (mounted) setState(() => _dashboardError = 'Erro ao carregar dashboard.\n$e');
  } finally {
    if (mounted) setState(() => _dashboardLoading = false);
  }
}
```

---

#### `_buildChartData()` pure helper pattern

Source: pure Dart Map grouping — no analog in codebase; pattern from RESEARCH.md Pattern 4.

```dart
// Private data class — defined at file scope, below _HomeScreenState
class _TemplateConformity {
  final String templateName;
  final double avgConformity; // 0.0–100.0
  const _TemplateConformity(this.templateName, this.avgConformity);
}

// Inside _HomeScreenState:
List<_TemplateConformity> _buildChartData(List<Audit> audits) {
  final Map<String, List<double>> byTemplate = {};
  for (final a in audits) {
    if (a.status == AuditStatus.concluida && a.conformityPercent != null) {
      byTemplate.putIfAbsent(a.templateName, () => []).add(a.conformityPercent!);
    }
  }
  return byTemplate.entries.map((e) {
    final avg = e.value.reduce((a, b) => a + b) / e.value.length;
    return _TemplateConformity(e.key, avg);
  }).toList()
    ..sort((a, b) => b.avgConformity.compareTo(a.avgConformity));
}
```

---

#### `_buildDashboard()` replacement pattern — RefreshIndicator + real cards

Existing `_buildDashboard()` (`home_screen.dart` lines 258-365) is replaced wholesale. Key structural changes:

1. Wrap `SingleChildScrollView` in `RefreshIndicator` (see `audits_screen.dart` line 420-424 for pattern)
2. Replace `'—'` placeholder values with real state fields
3. Replace second row's admin-only card with correct role logic (D-07: `isSuperOrDev` not `canAccessAdmin`)
4. Replace "Atividade recente" placeholder section with conformity chart

```dart
// RefreshIndicator wrapping pattern (analog: audits_screen.dart lines 420-424)
Widget _buildDashboard() {
  return RefreshIndicator(
    onRefresh: _loadDashboard,
    color: AppColors.primary,
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(), // required — short content won't scroll without it
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ... greeting (unchanged) ...

          // Row 1: Total + Pendentes
          Row(
            children: [
              Expanded(child: _summaryCard(
                icon: Icons.assignment_rounded,
                label: 'Total',
                value: _dashboardLoading ? '…' : '$_totalAudits',
                color: AppColors.accent,
              )),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard(
                icon: Icons.pending_rounded,
                label: 'Pendentes',
                value: _dashboardLoading ? '…' : '$_pendingAudits',
                color: Colors.orange,
              )),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Atrasadas + Ações abertas (always rendered) / Empresas for superuser/dev
          Row(
            children: [
              Expanded(child: _summaryCard(
                icon: Icons.warning_rounded,
                label: 'Atrasadas',
                value: _dashboardLoading ? '…' : '$_overdueAudits',
                color: AppColors.error,
              )),
              const SizedBox(width: 12),
              Expanded(child: AppRole.isSuperOrDev(_role)   // D-07: isSuperOrDev, NOT canAccessAdmin
                ? _summaryCard(
                    icon: Icons.business_rounded,
                    label: 'Empresas',
                    value: _dashboardLoading ? '…' : '$_companiesCount',
                    color: Colors.purple,
                  )
                : _summaryCard(                              // D-04: always show, value = 0 until Phase 8
                    icon: Icons.task_alt_rounded,
                    label: 'Ações abertas',
                    value: _dashboardLoading ? '…' : '$_openActions',
                    color: Colors.teal,
                  ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Conformity chart (replaces "Atividade recente" placeholder)
          Text('Conformidade por template', style: ...),
          const SizedBox(height: 12),
          _buildConformityChart(_chartData),
        ],
      ),
    ),
  );
}
```

---

#### `_buildConformityChart()` fl_chart widget pattern

Source: RESEARCH.md Code Examples (fl_chart, pub.dev verified). Empty state guard pattern from RESEARCH.md Pitfall 1.

```dart
Widget _buildConformityChart(List<_TemplateConformity> data) {
  if (data.isEmpty) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.of(context).divider),
      ),
      child: Text(
        'Nenhuma auditoria concluída para exibir',
        style: TextStyle(color: AppTheme.of(context).textSecondary, fontSize: 13),
      ),
    );
  }

  return SizedBox(
    height: data.length * 48.0 + 40,
    child: BarChart(
      BarChartData(
        rotationQuarterTurns: 1,
        maxY: 100,
        barGroups: List.generate(data.length, (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: data[i].avgConformity,
              color: AppColors.primary,
              width: 20,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        )),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 120,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                return Text(
                  data[idx].templateName,
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) =>
                  Text('${value.toInt()}%', style: const TextStyle(fontSize: 9)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    ),
  );
}
```

---

### `primeaudit/lib/services/dashboard_service.dart` (service, request-response — CREATE)

**Analog:** `primeaudit/lib/services/company_service.dart` (lines 1-10, 19-33)

---

#### Imports and class skeleton pattern

Source: `company_service.dart` lines 1-10, `audit_service.dart` lines 1-19.

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Agregações de dados para o dashboard da HomeScreen.
///
/// Métodos que dependem de tabelas ainda não existentes (Phase 8+)
/// implementam fallback try/catch retornando 0.
class DashboardService {
  final _client = Supabase.instance.client;
  // ... methods below
}
```

---

#### `getOpenActionsCount()` — try/catch fallback pattern

Source: pattern established in RESEARCH.md Pattern 3. No existing `FetchOptions` usage found in codebase — use `count()` via PostgREST instead.

```dart
/// Retorna o total de ações corretivas abertas da empresa.
/// Retorna 0 enquanto a tabela `corrective_actions` não existir (Phase 8).
Future<int> getOpenActionsCount(String? companyId) async {
  try {
    var query = _client
        .from('corrective_actions')
        .select('id')
        .eq('status', 'aberta');
    if (companyId != null) query = query.eq('company_id', companyId);
    final data = await query;
    return (data as List).length;
  } catch (_) {
    return 0; // table does not exist yet (Phase 8)
  }
}
```

---

#### `getCompaniesCount()` — simple count pattern

Source: `company_service.dart` lines 19-33 (basic `.select()` then `.length`).

```dart
/// Retorna o total de empresas cadastradas.
/// Uso exclusivo de superuser/dev (D-07).
Future<int> getCompaniesCount() async {
  final data = await _client.from('companies').select('id');
  return (data as List).length;
}
```

---

### `primeaudit/pubspec.yaml` (config — MODIFY)

**Analog:** Existing `pubspec.yaml` lines 30-37.

Add `fl_chart: ^1.2.0` under the `dependencies:` block, after `shared_preferences`:

```yaml
# EXISTING (lines 30-37):
dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8
  supabase_flutter: ^2.8.4
  shared_preferences: ^2.3.3

# ADD fl_chart after shared_preferences:
  fl_chart: ^1.2.0
```

Note: Do NOT add this line again in Phase 10 — it will already be present.

---

### `primeaudit/test/services/dashboard_service_test.dart` (test — CREATE)

**Analog:** `primeaudit/test/services/audit_answer_service_test.dart` (full file)

---

#### File header and import pattern

Source: `audit_answer_service_test.dart` lines 1-9. Tests exercise pure Dart logic only — do NOT instantiate service classes that hold `_client = Supabase.instance.client` (would throw in test environment).

```dart
// Unit tests for dashboard aggregation logic (DASH-01, DASH-03).
// Tests pure computation helpers — does NOT instantiate DashboardService
// (the `_client = Supabase.instance.client` field would throw in tests).
// DashboardService.getOpenActionsCount fallback tested via isolation helper.

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/audit.dart';
```

---

#### Helper factory function pattern

Source: `audit_answer_service_test.dart` lines 10-24. Create minimal `Audit` factory for test data:

```dart
// Mirrors _item() factory in audit_answer_service_test.dart lines 10-24
// and _fullAuditMap() in audit_test.dart lines 8-25.
Audit _audit({
  String id = 'a1',
  String templateName = 'Template A',
  AuditStatus status = AuditStatus.emAndamento,
  double? conformityPercent,
  String auditorId = 'user1',
}) {
  return Audit(
    id: id,
    title: 'Test',
    auditTypeId: 'at1',
    auditTypeName: 'Type',
    auditTypeIcon: '📋',
    auditTypeColor: '#2196F3',
    templateId: 't1',
    templateName: templateName,
    companyId: 'c1',
    companyName: 'Acme',
    companyRequiresPerimeter: false,
    auditorId: auditorId,
    auditorName: 'Ana',
    createdAt: DateTime(2024, 1, 1),
    status: status,
    conformityPercent: conformityPercent,
  );
}
```

---

#### Test group structure pattern

Source: `audit_answer_service_test.dart` lines 26-213 — `group()` + `test()` structure.

```dart
// Pure helper mirrors the logic inside _HomeScreenState._buildChartData
// (extract to @visibleForTesting or test the logic directly as pure function)
List<({String templateName, double avgConformity})> buildChartData(List<Audit> audits) {
  final Map<String, List<double>> byTemplate = {};
  for (final a in audits) {
    if (a.status == AuditStatus.concluida && a.conformityPercent != null) {
      byTemplate.putIfAbsent(a.templateName, () => []).add(a.conformityPercent!);
    }
  }
  return byTemplate.entries.map((e) {
    final avg = e.value.reduce((a, b) => a + b) / e.value.length;
    return (templateName: e.key, avgConformity: avg);
  }).toList()
    ..sort((a, b) => b.avgConformity.compareTo(a.avgConformity));
}

void main() {
  // DASH-01: KPI count helpers
  group('KPI counts — total excludes cancelled', () {
    test('cancelled audit not counted in total', () { ... });
    test('all non-cancelled statuses counted in total', () { ... });
  });

  group('KPI counts — pending = emAndamento only', () {
    test('rascunho is not pending', () { ... });
    test('emAndamento is pending', () { ... });
  });

  group('KPI counts — overdue = atrasada only', () {
    test('atrasada counted as overdue', () { ... });
    test('emAndamento not counted as overdue', () { ... });
  });

  // DASH-01: Role scope (auditor filter)
  group('Role scope — auditor sees only own audits', () {
    test('auditor filter keeps only matching auditorId', () { ... });
    test('admin gets all audits unfiltered', () { ... });
  });

  // DASH-03: Chart data grouping
  group('Chart data — grouping by templateName', () {
    test('empty list returns empty chart data', () {
      expect(buildChartData([]), isEmpty);
    });
    test('emAndamento audits excluded from chart', () { ... });
    test('single concluida audit produces one entry', () { ... });
    test('two templates produce two entries', () { ... });
    test('average conformity computed correctly across multiple audits', () { ... });
    test('entries sorted descending by avgConformity', () { ... });
  });
}
```

---

## Shared Patterns

### Service instantiation in screen
**Source:** `primeaudit/lib/screens/home_screen.dart` lines 23-25
**Apply to:** `home_screen.dart` state class — add `_auditService` and `_dashboardService`
```dart
final _authService = AuthService();
final _userService = UserService();
// ADD:
final _auditService = AuditService();
final _dashboardService = DashboardService();
```

### Load/setState/error/finally pattern
**Source:** `primeaudit/lib/screens/audits_screen.dart` lines 109-120
**Apply to:** `_loadDashboard()` in `home_screen.dart`
```dart
Future<void> _load() async {
  setState(() { _isLoading = true; _error = null; });
  try {
    // ... fetch ...
    if (mounted) setState(() => _data = data);
  } catch (e) {
    if (mounted) setState(() => _error = 'Erro ao carregar...\n$e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

### Dart-side role filter
**Source:** `primeaudit/lib/screens/audits_screen.dart` line 129
**Apply to:** `_loadDashboard()` auditor scope block
```dart
case _AuditFilter.minhas: return a.auditorId == widget.currentUserId;
// Pattern: filter fetched list in Dart rather than separate DB query
```

### Supabase client in service
**Source:** `primeaudit/lib/services/audit_service.dart` line 19, `company_service.dart` line 9
**Apply to:** `DashboardService`
```dart
final _client = Supabase.instance.client;
```

### AppRole permission guards
**Source:** `primeaudit/lib/core/app_roles.dart` lines 34-41
**Apply to:** `_loadDashboard()` and `_buildDashboard()` role conditionals
```dart
// D-06: admin scope — canAccessAdmin includes adm + superuser + dev
AppRole.canAccessAdmin(_role)   // true for adm, superuser, dev

// D-07: companies card — isSuperOrDev ONLY, not adm
AppRole.isSuperOrDev(_role)     // true for superuser, dev only
```

### color.withValues(alpha:) — not .withOpacity()
**Source:** `primeaudit/lib/screens/home_screen.dart` line 403 (existing `_summaryCard`)
**Apply to:** Any color transparency in new widgets
```dart
color: color.withValues(alpha: 0.12),  // correct API — project already uses this
// NOT: color.withOpacity(0.12)        // deprecated in Flutter 3.x
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| fl_chart `BarChart` widget | UI widget | — | No chart library exists in codebase; RESEARCH.md pub.dev patterns apply directly |

---

## Key Anti-Patterns Identified

From reading `home_screen.dart` lines 317-329 (existing card row):

The existing second row uses `AppRole.canAccessAdmin(_role)` for the "Empresas" card. **This is wrong for Phase 7** — D-07 specifies `isSuperOrDev` only, not all admins. The new implementation must use `AppRole.isSuperOrDev(_role)` for the companies count card.

From reading `home_screen.dart` lines 259 and RESEARCH.md Pitfall 4:

The existing `SingleChildScrollView` has no `physics` set. `RefreshIndicator` requires `AlwaysScrollableScrollPhysics()` — must be added when wrapping.

---

## Metadata

**Analog search scope:** `primeaudit/lib/screens/`, `primeaudit/lib/services/`, `primeaudit/test/services/`, `primeaudit/test/models/`
**Files read:** 12 source files + 2 test files
**Pattern extraction date:** 2026-04-23
