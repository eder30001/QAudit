---
phase: 14-checklist-execution-engine
plan: "02"
subsystem: models
tags: [models, dart, checklist, execution, data-integrity]
dependency_graph:
  requires: []
  provides:
    - ChecklistExecution model (primeaudit/lib/models/checklist_execution.dart)
    - ChecklistAnswer model (primeaudit/lib/models/checklist_execution.dart)
    - ChecklistTemplateItem.options field (primeaudit/lib/models/checklist_template.dart)
  affects:
    - 14-03 (ChecklistExecutionService usa ChecklistExecution.fromMap)
    - 14-04 (ChecklistExecutionScreen usa ChecklistAnswer para _answers)
tech_stack:
  added: []
  patterns:
    - "TEXT[] cast: (map['options'] as List?)?.cast<String>() ?? []"
    - "DATE sem timezone: DateTime.parse(map['data_execucao']) sem .toLocal()"
    - "TIMESTAMPTZ com timezone: DateTime.parse(map['created_at']).toLocal()"
    - "Join pattern: map['checklist_templates']?['name'] ?? ''"
key_files:
  created:
    - primeaudit/lib/models/checklist_execution.dart
  modified:
    - primeaudit/lib/models/checklist_template.dart
decisions:
  - "ChecklistExecution usa String para status em vez de enum — simplifica serialização para o service layer sem perda de type-safety (getter isConcluido encapsula a comparação)"
  - "dataExecucao parseado sem .toLocal() seguindo pitfall documentado em 14-RESEARCH.md — DATE columns nao carregam timezone, .toLocal() causaria deslocamento de dia em UTC-3"
  - "Sem import de material.dart — modelos sao Dart puro, status nao tem getters de Color/IconData neste plano"
metrics:
  duration: "~8 minutes"
  completed: "2026-05-06"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 14 Plan 02: Checklist Execution Models Summary

Models de execução de checklist — ChecklistExecution + ChecklistAnswer + campo options em ChecklistTemplateItem com parse correto de TEXT[] e DATE sem conversão de timezone.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Adicionar campo options em ChecklistTemplateItem | 226f582 | primeaudit/lib/models/checklist_template.dart |
| 2 | Criar checklist_execution.dart | d780dd0 | primeaudit/lib/models/checklist_execution.dart |

## What Was Built

**Task 1 — ChecklistTemplateItem.options**

Adicionado campo `final List<String> options` à classe `ChecklistTemplateItem` em `checklist_template.dart`. O campo:
- Tem valor default `const []` no construtor (parâmetro opcional)
- É deserializado no `fromMap` via `(map['options'] as List?)?.cast<String>() ?? []` — trata corretamente o retorno `TEXT[]` do PostgREST, que vem como `List<dynamic>` e precisa de `cast<String>()` para tipagem forte

`ChecklistTemplate` não foi alterada — escopo cirúrgico.

**Task 2 — checklist_execution.dart**

Criado arquivo com dois modelos:

`ChecklistExecution` (11 campos):
- `dataExecucao: DateTime.parse(map['data_execucao'])` — sem `.toLocal()`, seguindo o pitfall de timezone documentado (DATE column não tem timezone; `.toLocal()` deslocaria o dia em UTC-3)
- `templateName: map['checklist_templates']?['name'] ?? ''` — join pattern
- `conformityPercent` e `completedAt` são nullable
- `createdAt` e `completedAt` usam `.toLocal()` (TIMESTAMPTZ)
- Getters computados: `isConcluido` e `isRascunho`

`ChecklistAnswer` (6 campos):
- `executionId`, `itemId`, `response`, `observation` (nullable), `answeredAt`
- `answeredAt` usa `.toLocal()` (TIMESTAMPTZ)

Ambos os modelos são Dart puro — sem imports externos.

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

| Check | Result |
|-------|--------|
| `List<String> options` count = 1 | PASS |
| `cast<String>` presente no fromMap | PASS |
| `class ChecklistExecution` count = 1 | PASS |
| `class ChecklistAnswer` count = 1 | PASS |
| `data_execucao` sem `.toLocal()` | PASS |
| `isConcluido` getter presente | PASS |

## Known Stubs

None — modelos puros de dados, sem lógica de UI ou stubs de dados.

## Threat Surface Scan

Nenhum novo endpoint de rede ou path de auth introduzido. Os modelos apenas deserializam dados existentes do Supabase. Mitigações do threat register foram aplicadas:

- **T-14-05 (mitigate):** Null-coalescing em todos os campos de `ChecklistExecution.fromMap` — `?? ''`, `?? 'rascunho'`, `?.toDouble()` — sem crash em dados parciais.
- **T-14-06 (accept):** `(map['options'] as List?)?.cast<String>() ?? []` — retorna `[]` se null ou tipo inesperado.

## Self-Check: PASSED

- [x] `primeaudit/lib/models/checklist_template.dart` existe e modificado
- [x] `primeaudit/lib/models/checklist_execution.dart` existe e criado
- [x] Commit 226f582 existe (Task 1)
- [x] Commit d780dd0 existe (Task 2)
