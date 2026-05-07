---
phase: 15-photos-per-item
plan: 01
subsystem: database
tags: [supabase, storage, flutter, dart, rls, migration, checklist, photos]

# Dependency graph
requires:
  - phase: 13-db-foundation-template-management
    provides: checklist_executions table, checklist_template_items table
provides:
  - Migration SQL idempotente: tabela checklist_item_images com RLS Pattern 3 e bucket privado checklist-images
  - Modelo Dart ChecklistItemImage com fromMap factory
  - Service layer ChecklistImageService (upload, getImages, getImagesByExecution, getSignedUrl, deleteImage)
  - 4 test files cobrindo fromMap, contrato de isolamento e stubs de widget
affects:
  - 15-02 (UI _ChecklistPhotoStrip depende de ChecklistImageService)
  - 15-03 (widget tests completam os stubs deste plano)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "RLS Pattern 3 para auditor via EXISTS subquery em execucao pai"
    - "Storage path hierarquico: {companyId}/{executionId}/{itemId}/{uuid}.jpg"
    - "UUID v4 gerado sem dependencia externa via dart:math Random.secure()"
    - "getImagesByExecution evita N+1 carregando todas as imagens da execucao em uma unica query"
    - "Storage delete best-effort (catch silencioso) + DB delete propaga erro ao caller"

key-files:
  created:
    - primeaudit/supabase/migrations/20260510_create_checklist_item_images.sql
    - primeaudit/lib/models/checklist_item_image.dart
    - primeaudit/lib/services/checklist_image_service.dart
    - primeaudit/test/checklist_item_image_test.dart
    - primeaudit/test/checklist_image_service_test.dart
    - primeaudit/test/checklist_photo_isolation_test.dart
    - primeaudit/test/checklist_photo_strip_test.dart
  modified: []

key-decisions:
  - "Modulo Checklist completamente independente de ImageService/AuditItemImage — sem heranca, sem import cruzado"
  - "UUID v4 gerado com dart:math sem adicionar dependencia nova ao pubspec"
  - "Storage delete e best-effort (silencioso) para tolerar objetos ja removidos; DB delete propaga erro"
  - "getImagesByExecution faz uma unica query por execucao para evitar N+1 na tela de execucao"
  - "Stubs Nyquist gate (4 test files) garantem que flutter test nao falha antes da UI ser implementada"

patterns-established:
  - "RLS auditor via EXISTS subquery: auditor acessa apenas imagens de suas proprias execucoes"
  - "Storage RLS: primeiro segmento do path = company_id do usuario (storage.foldername check)"
  - "Isolamento de estados: falha de upload nao toca _failedSaves nem bloqueia _finalize"

requirements-completed: [EXEC-04]

# Metrics
duration: N/A (retomada de execucao anterior)
completed: 2026-05-07
---

# Phase 15 Plan 01: DB Foundation + Service Layer Summary

**Migration SQL idempotente + modelo ChecklistItemImage + ChecklistImageService com RLS Pattern 3 e bucket privado isolado do modulo de auditorias**

## Performance

- **Duration:** N/A (work completed in prior session, SUMMARY created in continuation)
- **Started:** 2026-05-07
- **Completed:** 2026-05-07
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Migration SQL idempotente criando tabela `checklist_item_images` com 4 FKs, 3 indexes, RLS completo (superuser/dev/adm/auditor) e bucket Storage privado `checklist-images` com policies separadas
- Modelo Dart `ChecklistItemImage` com construtor const, todos os campos tipados e factory `fromMap` idiomatica (padrao do projeto)
- `ChecklistImageService` com 5 metodos (uploadImage, getImages, getImagesByExecution, getSignedUrl, deleteImage), UUID v4 sem dependencia externa e isolamento total do modulo de auditorias
- 4 test files cobrindo: fromMap correto, contrato de isolamento _failedSaves, stub de widget _ChecklistPhotoStrip — todos os 10 testes passando

## Task Commits

1. **Task 1: Migration SQL + Model + Service** - `3c85824` (feat)
2. **Task 2: Test stubs Nyquist gate** - `2f6742e` (test)

## Files Created/Modified

- `primeaudit/supabase/migrations/20260510_create_checklist_item_images.sql` - Tabela + bucket + RLS completo idempotente
- `primeaudit/lib/models/checklist_item_image.dart` - Modelo Dart com fromMap
- `primeaudit/lib/services/checklist_image_service.dart` - Service layer com 5 metodos
- `primeaudit/test/checklist_item_image_test.dart` - Testes unitarios de fromMap (2 testes)
- `primeaudit/test/checklist_image_service_test.dart` - Contrato de storage path e isolamento (2 testes)
- `primeaudit/test/checklist_photo_isolation_test.dart` - Invariante: falha de foto nao toca _failedSaves (2 testes)
- `primeaudit/test/checklist_photo_strip_test.dart` - Stubs de widget _ChecklistPhotoStrip (4 testes placeholder)

## Decisions Made

- Modulo Checklist completamente independente: sem import de `ImageService` ou `AuditItemImage` — garantido por revisao de codigo e documentado no docstring da classe
- UUID v4 via `dart:math Random.secure()` para nao adicionar dependencia ao pubspec
- Storage delete best-effort: `catch (_) {}` silencioso no Storage, mas DB delete propaga erro ao caller para retry
- `getImagesByExecution` como metodo dedicado para evitar N+1 ao carregar a tela de execucao
- Stubs Nyquist gate para `_ChecklistPhotoStrip` marcados explicitamente como placeholders para Plan 15-03

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

The Supabase migration `20260510_create_checklist_item_images.sql` must be applied to the remote database via `supabase db push` or via the Supabase dashboard before Plan 15-02 can be tested end-to-end.

## Known Stubs

- `primeaudit/test/checklist_photo_strip_test.dart` - 4 testes placeholder para `_ChecklistPhotoStrip` (widget ainda nao implementado). Serao completados em Plan 15-03 apos a UI ser criada em Plan 15-02.
- `primeaudit/test/checklist_image_service_test.dart` - Teste "upload failure does not touch _failedSaves" e um placeholder documentando que o isolamento real e verificado em `checklist_photo_isolation_test.dart`.

## Next Phase Readiness

- Fundacao completa: tabela + model + service prontos para consumo pelo Plan 15-02 (UI _ChecklistPhotoStrip)
- `ChecklistImageService` exportado e pronto para injecao na tela `ChecklistExecutionScreen`
- Stubs de widget aguardam implementacao da UI em 15-02 antes de serem completados em 15-03
- Nenhum bloqueio identificado

---

## Self-Check: PASSED

Files verified present:
- `primeaudit/supabase/migrations/20260510_create_checklist_item_images.sql` - FOUND
- `primeaudit/lib/models/checklist_item_image.dart` - FOUND
- `primeaudit/lib/services/checklist_image_service.dart` - FOUND
- `primeaudit/test/checklist_item_image_test.dart` - FOUND
- `primeaudit/test/checklist_image_service_test.dart` - FOUND
- `primeaudit/test/checklist_photo_isolation_test.dart` - FOUND
- `primeaudit/test/checklist_photo_strip_test.dart` - FOUND

Commits verified:
- `3c85824` (feat(15-01): migration SQL + model ChecklistItemImage + service ChecklistImageService) - FOUND
- `2f6742e` (test(15-01): stubs Nyquist gate — 4 test files para Phase 15 (Wave 0)) - FOUND

Analysis: `flutter analyze lib/models/checklist_item_image.dart lib/services/checklist_image_service.dart --no-fatal-infos` — No issues found
Tests: `flutter test` 10/10 tests passed

---
*Phase: 15-photos-per-item*
*Completed: 2026-05-07*
