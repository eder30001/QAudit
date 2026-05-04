---
phase: 13-db-foundation-template-management
plan: "03"
subsystem: checklist-ui
tags:
  - flutter
  - screens
  - navigation
  - checklist
dependency_graph:
  requires:
    - "13-02"  # ChecklistTemplate model + ChecklistTemplateService
    - "13-04"  # ChecklistTemplateFormScreen (navigation target)
  provides:
    - ChecklistTemplatesScreen  # 3-tab list entry point
    - drawer-nav-checklist      # NAV-01 drawer entry
  affects:
    - home_screen.dart          # drawer entry added
tech_stack:
  added: []
  patterns:
    - TickerProviderStateMixin + TabController(length: 3)
    - Future.wait for parallel tab data loading
    - _ChecklistTemplateCard private widget with conditional trailing
    - _CloneBottomSheet StatefulWidget with async clone + loading state
    - ScaffoldMessenger captured before async gap (use_build_context_synchronously)
key_files:
  created:
    - primeaudit/lib/screens/checklist/checklist_templates_screen.dart
  modified:
    - primeaudit/lib/screens/home_screen.dart
decisions:
  - "ChecklistTemplatesScreen sem AppRole guard — visível a todos os perfis autenticados (NAV-01)"
  - "ScaffoldMessenger do parentContext capturado antes do await no _CloneBottomSheet para compliance com use_build_context_synchronously"
  - "_ChecklistTemplateCard como StatelessWidget separado recebendo callbacks — evita rebuild de state desnecessário"
metrics:
  duration: "~12 min"
  completed: "2026-05-04"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 13 Plan 03: ChecklistTemplatesScreen + Drawer Entry — Summary

**One-liner:** Tela de listagem de templates em 3 abas (Industrial, Transportadora, Meus checklists) com cards, clone via bottom sheet e delete via dialog, mais entry de navegação no drawer para todos os perfis.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | ChecklistTemplatesScreen com 3-tab list, cards, delete, clone | f222262 | primeaudit/lib/screens/checklist/checklist_templates_screen.dart (criado) |
| 2 | Drawer entry 'Checklist' em home_screen.dart (NAV-01) | 21535d8 | primeaudit/lib/screens/home_screen.dart (modificado) |

## What Was Built

### Task 1 — ChecklistTemplatesScreen

Arquivo `primeaudit/lib/screens/checklist/checklist_templates_screen.dart` implementando:

- `ChecklistTemplatesScreen extends StatefulWidget` com `TickerProviderStateMixin`
- `TabController(length: 3, vsync: this)` inicializado em `initState` e descartado em `dispose()`
- Carregamento paralelo via `Future.wait([getByCategory('industrial'), getByCategory('transportadora'), getOwned()])`
- Estado de carregamento com `CircularProgressIndicator(color: AppColors.primary)`
- Estado de erro com RefreshIndicator e mensagem 'Erro ao carregar templates. Puxe para atualizar.'
- Estados vazios específicos por aba (ícone + heading + body por UI-SPEC)
- FAB `FloatingActionButton.extended` 'Novo checklist' visível em todas as abas
- `_ChecklistTemplateCard`: card com container 44x44, badge 'Padrão' (seeds) ou 'Personalizado' (próprios), trailing condicional (copy icon para seeds, PopupMenuButton para próprios)
- `_confirmDelete`: AlertDialog com título 'Excluir checklist', botão destruidor em `AppColors.error`, SnackBar de sucesso/erro pós-exclusão
- `_showCloneSheet`: `showModalBottomSheet` com `_CloneBottomSheet StatefulWidget` que exibe loading state inline no botão durante `cloneTemplate()`
- Threat model respeitado: seeds nunca mostram PopupMenuButton (guarda `template.isSeed` no widget)

### Task 2 — Drawer Entry (NAV-01)

Duas edições cirúrgicas em `home_screen.dart`:

1. Import adicionado após último import existente: `import 'checklist/checklist_templates_screen.dart';`
2. `_drawerItem(icon: Icons.checklist_rounded, title: 'Checklist', onTap: () => _navigate(const ChecklistTemplatesScreen()))` inserido entre "Auditorias" e "Ações Corretivas" **sem** qualquer guarda `AppRole` — visível a todos os perfis autenticados.

## Verification Results

- `flutter analyze lib/screens/checklist/checklist_templates_screen.dart` → No issues found (0 warnings, 0 errors)
- `flutter analyze lib/screens/home_screen.dart` → No issues found
- `flutter analyze lib/screens/checklist/checklist_templates_screen.dart lib/screens/home_screen.dart` → No issues found
- `flutter test` → 264 tests passed (zero regressão)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrigido use_build_context_synchronously em _CloneBottomSheet**
- **Found during:** Task 1 — flutter analyze pós-criação
- **Issue:** `ScaffoldMessenger.of(widget.parentContext)` era chamado após `await` (linha 518 e 528), violando `use_build_context_synchronously`
- **Fix:** Capturar `final messenger = ScaffoldMessenger.of(widget.parentContext)` antes do `await widget.service.cloneTemplate(...)` e usar `messenger` nos SnackBars pós-await
- **Files modified:** `checklist_templates_screen.dart`
- **Commit:** f222262 (incluído no mesmo commit — fix inline antes do commit)

## Known Stubs

Nenhum. Todos os métodos de serviço chamados (`getByCategory`, `getOwned`, `deleteTemplate`, `cloneTemplate`) estão implementados em Plan 02 e wired corretamente na tela.

## Threat Flags

Nenhuma nova superfície de segurança introduzida além do registrado no threat model do plano (T-13-01, T-13-02, T-13-03, T-13-09). Todas as mitigações estão implementadas:

- Seeds não exibem PopupMenuButton (T-13-01): guarda `template.isSeed` em `_ChecklistTemplateCard`
- Dados filtrados server-side por RLS (T-13-02): serviço usa `getByCategory` e `getOwned` — RLS enforça a visibilidade
- Edit apenas para criador (T-13-03): guarda `template.createdBy == currentUserId && !template.isSeed`

## Self-Check: PASSED

Arquivos criados/modificados:
- FOUND: primeaudit/lib/screens/checklist/checklist_templates_screen.dart
- FOUND: primeaudit/lib/screens/home_screen.dart (modificado)

Commits:
- FOUND: f222262 (feat(13-03): create ChecklistTemplatesScreen...)
- FOUND: 21535d8 (feat(13-03): add Checklist drawer entry...)
