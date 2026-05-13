# Phase 3: Test Coverage - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 8 new test files
**Analogs found:** 8 / 8

## File Classification

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `test/services/audit_answer_service_test.dart` | test | transform | `test/core/cnpj_validator_test.dart` | role-match |
| `test/models/app_role_test.dart` | test | request-response | `test/core/cnpj_validator_test.dart` | exact |
| `test/models/audit_test.dart` | test | transform | `test/pending_save_test.dart` | role-match |
| `test/models/audit_answer_test.dart` | test | transform | `test/pending_save_test.dart` | exact |
| `test/models/audit_template_test.dart` | test | transform | `test/pending_save_test.dart` | exact |
| `test/models/perimeter_test.dart` | test | transform | `test/pending_save_test.dart` | role-match |
| `test/models/company_test.dart` | test | transform | `test/pending_save_test.dart` | exact |
| `test/models/app_user_test.dart` | test | transform | `test/pending_save_test.dart` | exact |

---

## Pattern Assignments

### `test/services/audit_answer_service_test.dart` (QUAL-01)

**Analog:** `test/core/cnpj_validator_test.dart`

**Imports pattern** (cnpj_validator_test.dart lines 1-2):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/services/audit_answer_service.dart';
import 'package:primeaudit/models/audit_template.dart';
```

**CRITICAL: AuditAnswerService instantiation pitfall.**
`audit_answer_service.dart` line 10 declares `final _client = Supabase.instance.client` as a non-late field. This runs at construction time and throws `StateError: Supabase not initialized` in a test context. The plan must make `calculateConformity` a `static` method (one-line change: add `static` to the signature at line 52) before writing this test. This is permitted by CLAUDE.md — it is not a state management refactor; it is a visibility qualifier change on a pure function.

**Core pattern — group + test for each responseType** (derived from cnpj_validator_test.dart lines 4-45):
```dart
void main() {
  group('AuditAnswerService.calculateConformity', () {
    // After making the method static:
    test('empty list returns 100.0', () {
      expect(AuditAnswerService.calculateConformity([], {}), equals(100.0));
    });

    test('ok_nok — ok answer earns full weight', () {
      final items = [TemplateItem(
        id: 'i1', templateId: 't1', question: 'Q', responseType: 'ok_nok',
        required: true, weight: 2, orderIndex: 0,
      )];
      expect(AuditAnswerService.calculateConformity(items, {'i1': 'ok'}), equals(100.0));
    });

    test('ok_nok — nok answer earns zero', () {
      final items = [TemplateItem(
        id: 'i1', templateId: 't1', question: 'Q', responseType: 'ok_nok',
        required: true, weight: 2, orderIndex: 0,
      )];
      expect(AuditAnswerService.calculateConformity(items, {'i1': 'nok'}), equals(0.0));
    });

    // Replicate pattern above for: yes_no, scale_1_5, percentage, text, selection
    // scale_1_5 uses closeTo(expected, 0.01) for floating-point tolerance
  });
}
```

**All 6 branches to cover** (from `audit_answer_service.dart` lines 64-76):
- `'ok_nok'`: `'ok'` → full weight; any other value → 0
- `'yes_no'`: `'yes'` → full weight; any other value → 0
- `'scale_1_5'`: `(int / 5) * weight` — use `closeTo(expected, 0.01)`
- `'percentage'`: `(double / 100) * weight` — use `closeTo(expected, 0.01)`
- `'text'`: non-empty string → full weight; empty string → 0
- `'selection'`: non-empty string → full weight; empty string → 0

---

### `test/models/app_role_test.dart` (QUAL-02)

**Analog:** `test/core/cnpj_validator_test.dart`

**Imports pattern**:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/core/app_roles.dart';
```

**Core pattern — one group per method** (mirroring cnpj_validator_test.dart lines 4-74 which uses separate `group()` blocks per function):
```dart
void main() {
  group('AppRole.canAccessAdmin', () {
    test('true for superuser', () => expect(AppRole.canAccessAdmin('superuser'), isTrue));
    test('true for dev',       () => expect(AppRole.canAccessAdmin('dev'), isTrue));
    test('true for adm',       () => expect(AppRole.canAccessAdmin('adm'), isTrue));
    test('false for auditor',  () => expect(AppRole.canAccessAdmin('auditor'), isFalse));
    test('false for anonymous',() => expect(AppRole.canAccessAdmin('anonymous'), isFalse));
  });

  group('AppRole.canAccessDev', () {
    // true: superuser, dev — false: adm, auditor, anonymous
  });

  group('AppRole.isSuperOrDev', () {
    // true: superuser, dev — false: adm, auditor, anonymous
  });

  group('AppRole.label', () {
    // all 5 known roles return Portuguese label; unknown role returns itself
    test('unknown role returns role itself', () =>
        expect(AppRole.label('unknown'), equals('unknown')));
  });
}
```

**NOTE:** Do NOT add a test for `canEdit` — that method does not exist in `app_roles.dart`. The roadmap success criterion referencing `canEdit` contains a phantom method. The requirement is satisfied by covering `canAccessAdmin`, `canAccessDev`, `isSuperOrDev`, and `label`.

---

### `test/models/audit_test.dart` (QUAL-03 — Audit.fromMap)

**Analog:** `test/pending_save_test.dart`

**Imports pattern**:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/audit.dart';
```

**Fixture map** — must include nested join keys (from `audit.dart` lines 88-108):
```dart
final Map<String, dynamic> _fullAuditMap = {
  'id': 'a1',
  'title': 'Auditoria Teste',
  'audit_type_id': 'at1',
  'template_id': 't1',
  'company_id': 'c1',
  'auditor_id': 'u1',
  'status': 'em_andamento',
  'created_at': '2024-01-01T00:00:00.000Z',
  'deadline': null,
  'conformity_percent': null,
  'audit_types': {'name': 'Safety', 'icon': '📋', 'color': '#2196F3'},
  'audit_templates': {'name': 'Template A'},
  'companies': {'name': 'Acme', 'requires_perimeter': false},
  'perimeters': null,
  'auditor': {'full_name': 'Ana'},
};
```

**Core pattern** (derived from pending_save_test.dart lines 9-50):
```dart
group('Audit.fromMap', () {
  test('parses required scalar fields', () {
    final audit = Audit.fromMap(_fullAuditMap);
    expect(audit.id, equals('a1'));
    expect(audit.title, equals('Auditoria Teste'));
    expect(audit.status, equals(AuditStatus.emAndamento));
    expect(audit.deadline, isNull);
    expect(audit.conformityPercent, isNull);
  });

  test('parses nested audit_types join', () {
    final audit = Audit.fromMap(_fullAuditMap);
    expect(audit.auditTypeName, equals('Safety'));
    expect(audit.auditTypeIcon, equals('📋'));
    expect(audit.auditTypeColor, equals('#2196F3'));
  });

  test('parses nested companies join — requiresPerimeter', () {
    final audit = Audit.fromMap(_fullAuditMap);
    expect(audit.companyName, equals('Acme'));
    expect(audit.companyRequiresPerimeter, isFalse);
  });

  test('parses nested auditor join', () {
    final audit = Audit.fromMap(_fullAuditMap);
    expect(audit.auditorName, equals('Ana'));
  });

  test('absent nested maps fall back to defaults', () {
    final minimal = Map<String, dynamic>.from(_fullAuditMap)
      ..['audit_types'] = null;
    final audit = Audit.fromMap(minimal);
    expect(audit.auditTypeName, equals(''));
    expect(audit.auditTypeIcon, equals('📋'));
    expect(audit.auditTypeColor, equals('#2196F3'));
  });

  test('status string mapping — all valid values', () {
    for (final entry in {
      'em_andamento': AuditStatus.emAndamento,
      'concluida':    AuditStatus.concluida,
      'atrasada':     AuditStatus.atrasada,
      'cancelada':    AuditStatus.cancelada,
      'rascunho':     AuditStatus.rascunho,
      null:           AuditStatus.rascunho,
    }.entries) {
      final m = Map<String, dynamic>.from(_fullAuditMap)..['status'] = entry.key;
      expect(Audit.fromMap(m).status, equals(entry.value));
    }
  });
});
```

---

### `test/models/audit_answer_test.dart` (QUAL-03 — AuditAnswer.fromMap)

**Analog:** `test/pending_save_test.dart`

**Imports pattern**:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/audit_answer.dart';
```

**Fixture map** (flat — from `audit_answer.dart` lines 21-30):
```dart
final Map<String, dynamic> _map = {
  'id': 'aa1',
  'audit_id': 'a1',
  'template_item_id': 'ti1',
  'response': 'ok',
  'observation': null,
  'answered_at': '2024-01-01T10:00:00.000Z',
};
```

**Core pattern**:
```dart
group('AuditAnswer.fromMap', () {
  test('parses required fields', () {
    final aa = AuditAnswer.fromMap(_map);
    expect(aa.id, equals('aa1'));
    expect(aa.auditId, equals('a1'));
    expect(aa.templateItemId, equals('ti1'));
    expect(aa.response, equals('ok'));
    expect(aa.answeredAt, equals(DateTime.parse('2024-01-01T10:00:00.000Z')));
  });

  test('observation is null when absent', () {
    expect(AuditAnswer.fromMap(_map).observation, isNull);
  });

  test('observation is populated when present', () {
    final m = Map<String, dynamic>.from(_map)..['observation'] = 'Observação';
    expect(AuditAnswer.fromMap(m).observation, equals('Observação'));
  });
});
```

---

### `test/models/audit_template_test.dart` (QUAL-03 — AuditTemplate + TemplateItem.fromMap)

**Analog:** `test/pending_save_test.dart`

**Imports pattern**:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/audit_template.dart';
```

**TemplateItem fixture** (from `audit_template.dart` lines 30-43):
```dart
final Map<String, dynamic> _itemMap = {
  'id': 'ti1',
  'template_id': 't1',
  'section_id': null,
  'question': 'Item conforme?',
  'guidance': null,
  'response_type': 'ok_nok',
  'required': true,
  'weight': 3,
  'order_index': 0,
  'options': [],
};
```

**AuditTemplate fixture** (from `audit_template.dart` lines 115-126):
```dart
final Map<String, dynamic> _templateMap = {
  'id': 't1',
  'type_id': 'at1',
  'company_id': null,
  'name': 'Template A',
  'description': null,
  'active': true,
  'audit_types': {'name': 'Safety', 'icon': '📋'},
};
```

**Core pattern**:
```dart
group('TemplateItem.fromMap', () {
  test('parses required fields', () {
    final item = TemplateItem.fromMap(_itemMap);
    expect(item.id, equals('ti1'));
    expect(item.responseType, equals('ok_nok'));
    expect(item.weight, equals(3));
    expect(item.options, isEmpty);
  });

  test('response_type defaults to ok_nok when absent', () {
    final m = Map<String, dynamic>.from(_itemMap)..remove('response_type');
    expect(TemplateItem.fromMap(m).responseType, equals('ok_nok'));
  });

  test('weight defaults to 1 when absent', () {
    final m = Map<String, dynamic>.from(_itemMap)..remove('weight');
    expect(TemplateItem.fromMap(m).weight, equals(1));
  });
});

group('AuditTemplate.fromMap', () {
  test('parses required fields and nested audit_types join', () {
    final t = AuditTemplate.fromMap(_templateMap);
    expect(t.id, equals('t1'));
    expect(t.name, equals('Template A'));
    expect(t.typeName, equals('Safety'));
    expect(t.typeIcon, equals('📋'));
  });

  test('isGlobal is true when company_id is null', () {
    expect(AuditTemplate.fromMap(_templateMap).isGlobal, isTrue);
  });

  test('isGlobal is false when company_id is set', () {
    final m = Map<String, dynamic>.from(_templateMap)..['company_id'] = 'c1';
    expect(AuditTemplate.fromMap(m).isGlobal, isFalse);
  });

  test('absent audit_types join leaves typeName and typeIcon null', () {
    final m = Map<String, dynamic>.from(_templateMap)..['audit_types'] = null;
    final t = AuditTemplate.fromMap(m);
    expect(t.typeName, isNull);
    expect(t.typeIcon, isNull);
  });
});
```

---

### `test/models/perimeter_test.dart` (QUAL-03 + QUAL-04)

**Analog:** `test/pending_save_test.dart`

**Imports pattern**:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/perimeter.dart';
```

**Helper function** — construct fresh instances per test to avoid mutable-children cross-contamination (from `perimeter.dart` lines 14-25 and Pitfall 3 in RESEARCH.md):
```dart
Perimeter _p(String id, {String? parentId}) => Perimeter(
  id: id,
  companyId: 'co1',
  parentId: parentId,
  name: 'Perimeter $id',
  active: true,
  createdAt: DateTime(2024),
);
```

**fromMap fixture** (from `perimeter.dart` lines 27-37):
```dart
final Map<String, dynamic> _map = {
  'id': 'p1',
  'company_id': 'c1',
  'parent_id': null,
  'name': 'Area A',
  'description': null,
  'active': true,
  'created_at': '2024-01-01T00:00:00.000Z',
};
```

**Core pattern**:
```dart
group('Perimeter.fromMap', () {
  test('parses flat required fields', () {
    final p = Perimeter.fromMap(_map);
    expect(p.id, equals('p1'));
    expect(p.companyId, equals('c1'));
    expect(p.parentId, isNull);
    expect(p.name, equals('Area A'));
    expect(p.active, isTrue);
  });

  test('active defaults to true when absent', () {
    final m = Map<String, dynamic>.from(_map)..remove('active');
    expect(Perimeter.fromMap(m).active, isTrue);
  });
});

group('Perimeter.buildTree', () {
  test('empty list returns empty roots', () {
    expect(Perimeter.buildTree([]), isEmpty);
  });

  test('single root has no children', () {
    final roots = Perimeter.buildTree([_p('root')]);
    expect(roots.length, equals(1));
    expect(roots.first.children, isEmpty);
  });

  test('one parent one child — child attached to parent', () {
    final roots = Perimeter.buildTree([_p('parent'), _p('child', parentId: 'parent')]);
    expect(roots.length, equals(1));
    expect(roots.first.children.length, equals(1));
    expect(roots.first.children.first.id, equals('child'));
  });

  test('two roots, no children', () {
    final roots = Perimeter.buildTree([_p('r1'), _p('r2')]);
    expect(roots.length, equals(2));
  });

  test('3-level hierarchy — grandchild nested inside child', () {
    final flat = [
      _p('root'),
      _p('child', parentId: 'root'),
      _p('grandchild', parentId: 'child'),
    ];
    final roots = Perimeter.buildTree(flat);
    expect(roots.length, equals(1));
    expect(roots.first.children.length, equals(1));
    expect(roots.first.children.first.children.length, equals(1));
    expect(roots.first.children.first.children.first.id, equals('grandchild'));
  });
});
```

---

### `test/models/company_test.dart` (QUAL-03 — Company.fromMap)

**Analog:** `test/pending_save_test.dart`

**Imports pattern**:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/company.dart';
```

**Fixture map** (from `company.dart` lines 28-40):
```dart
final Map<String, dynamic> _map = {
  'id': 'c1',
  'name': 'Acme',
  'cnpj': null,
  'email': null,
  'phone': null,
  'address': null,
  'active': true,
  'requires_perimeter': false,
  'created_at': '2024-01-01T00:00:00.000Z',
};
```

**Core pattern**:
```dart
group('Company.fromMap', () {
  test('parses required fields', () {
    final c = Company.fromMap(_map);
    expect(c.id, equals('c1'));
    expect(c.name, equals('Acme'));
    expect(c.active, isTrue);
    expect(c.requiresPerimeter, isFalse);
  });

  test('optional fields are null when absent', () {
    final c = Company.fromMap(_map);
    expect(c.cnpj, isNull);
    expect(c.email, isNull);
    expect(c.phone, isNull);
    expect(c.address, isNull);
  });

  test('requiresPerimeter is true when set', () {
    final m = Map<String, dynamic>.from(_map)..['requires_perimeter'] = true;
    expect(Company.fromMap(m).requiresPerimeter, isTrue);
  });

  test('active defaults to true when absent', () {
    final m = Map<String, dynamic>.from(_map)..remove('active');
    expect(Company.fromMap(m).active, isTrue);
  });
});
```

---

### `test/models/app_user_test.dart` (QUAL-03 — AppUser.fromMap)

**Analog:** `test/pending_save_test.dart`

**Imports pattern**:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/app_user.dart';
```

**Fixture map** (from `app_user.dart` lines 31-41 — includes nested companies join):
```dart
final Map<String, dynamic> _map = {
  'id': 'u1',
  'full_name': 'Ana',
  'email': 'ana@example.com',
  'role': 'adm',
  'company_id': 'c1',
  'active': true,
  'created_at': '2024-01-01T00:00:00.000Z',
  'companies': {'name': 'Acme'},
};
```

**Core pattern**:
```dart
group('AppUser.fromMap', () {
  test('parses required scalar fields', () {
    final u = AppUser.fromMap(_map);
    expect(u.id, equals('u1'));
    expect(u.fullName, equals('Ana'));
    expect(u.email, equals('ana@example.com'));
    expect(u.role, equals('adm'));
    expect(u.active, isTrue);
  });

  test('parses nested companies join for companyName', () {
    expect(AppUser.fromMap(_map).companyName, equals('Acme'));
  });

  test('companyName is null when companies join is absent', () {
    final m = Map<String, dynamic>.from(_map)..['companies'] = null;
    expect(AppUser.fromMap(m).companyName, isNull);
  });

  test('companyId is populated', () {
    expect(AppUser.fromMap(_map).companyId, equals('c1'));
  });

  test('active defaults to true when absent', () {
    final m = Map<String, dynamic>.from(_map)..remove('active');
    expect(AppUser.fromMap(m).active, isTrue);
  });
});
```

**NOTE:** `AppUser` is the model that maps the `profiles` table. The roadmap's reference to `UserProfile` is incorrect — that class does not exist. This test file satisfies QUAL-03 for profiles.

---

## Shared Patterns

### Test File Structure
**Source:** `primeaudit/test/core/cnpj_validator_test.dart` and `primeaudit/test/pending_save_test.dart`
**Apply to:** All 8 test files in this phase

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/<layer>/<target>.dart';

void main() {
  group('<TargetClass>.<methodOrConcept>', () {
    test('<specific behavior description>', () {
      // Arrange — construct inline fixture
      // Act — call target
      // Assert — expect(actual, matcher)
    });
  });
}
```

Rules derived from both analog files:
- One `import` for `flutter_test`, one for the target class — nothing else
- `void main()` wrapping all groups
- `group()` per method or concept; `test()` per case
- No `setUp`/`tearDown` — construct fixtures inline per test (pending_save_test.dart line 11-14)
- Descriptive test names in lowercase prose form (cnpj_validator_test.dart style)

### Inline Fixture Pattern
**Source:** `primeaudit/test/pending_save_test.dart` lines 11-15
**Apply to:** All fromMap tests and calculateConformity tests

```dart
// Construct inside test() body or as a top-level final in main()
final Map<String, dynamic> _map = { ... };
// Variations via Map.from() + spread update:
final m = Map<String, dynamic>.from(_map)..['key'] = newValue;
```

### Float Comparison Pattern
**Source:** `flutter_test` built-in matchers
**Apply to:** `calculateConformity` tests for `scale_1_5` and `percentage` response types

```dart
// Use closeTo instead of equals for floating-point arithmetic results
expect(result, closeTo(40.0, 0.01));
```

---

## Pre-Conditions for the Planner

### Wave 0, Task 0 — Make calculateConformity testable (prerequisite for QUAL-01)

Before writing `audit_answer_service_test.dart`, the plan must include a task that changes `audit_answer_service.dart` line 52 from:

```dart
double calculateConformity(
```

to:

```dart
static double calculateConformity(
```

This is a one-line change. All existing callers that call it as `_auditAnswerService.calculateConformity(...)` must be updated to `AuditAnswerService.calculateConformity(...)` (or the instance call still works on a static method if accessed through an instance — Dart allows this with a warning, but the planner should fix callers for cleanliness).

**Existing callers to check:** Search for `calculateConformity` in `primeaudit/lib/` — the planner should grep for all call sites before the edit.

---

## No Analog Found

All 8 files have analogs. No entries in this section.

---

## Metadata

**Analog search scope:** `primeaudit/test/` (all existing test files)
**Source files read:** `audit_answer_service.dart`, `app_roles.dart`, `audit.dart`, `audit_answer.dart`, `audit_template.dart`, `perimeter.dart`, `app_user.dart`, `company.dart`, `cnpj_validator_test.dart`, `pending_save_test.dart`
**Pattern extraction date:** 2026-04-18
