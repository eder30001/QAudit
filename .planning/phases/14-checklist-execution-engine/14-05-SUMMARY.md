---
phase: 14-checklist-execution-engine
plan: "05"
subsystem: ui
tags: [flutter, dart, checklist, execution, bottom-sheet, form, navigation]
dependency_graph:
  requires:
    - "14-03 (ChecklistExecutionService.createExecution, ChecklistExecution model)"
  provides:
    - "Botão Executar em _ChecklistTemplateCard (ElevatedButton no rodapé de cada card)"
    - "_StartChecklistSheet — modal Form com responsável, local, data, número/código"
    - "_showStartSheet — navegação para ChecklistExecutionScreen após createExecution"
  affects:
    - "14-04 (ChecklistExecutionScreen — navegação via _showStartSheet)"
    - "Merge wave 3 — stub checklist_execution_screen.dart a ser substituído"
tech_stack:
  added: []
  patterns:
    - "ElevatedButton no rodapé do card via Column wrapping ListTile — adiciona ação primária sem substituir onTap existente"
    - "showModalBottomSheet<ChecklistExecution> retornando objeto criado — caller recebe ChecklistExecution para navegar"
    - "ScaffoldMessenger capturado ANTES do await em _confirm() — use_build_context_synchronously mitigado"
    - "Navigator.push.then((result) {_load(); if (result == true) snackbar}) — refresh + feedback em Navigator.pop(true)"
    - "_isLoading flag desativa botão Confirmar durante await createExecution — sem double-tap (T-14-15)"
key_files:
  created:
    - primeaudit/lib/screens/checklist/checklist_execution_screen.dart (stub temporário — será substituído pelo 14-04 no merge)
  modified:
    - primeaudit/lib/screens/checklist/checklist_template_list_screen.dart
key-decisions:
  - "Botão Executar como ElevatedButton no rodapé do card em vez de trailing icon — mais visível, consistente com ação primária"
  - "Stub de ChecklistExecutionScreen criado no worktree para compilação paralela — será sobrescrito pelo 14-04 no merge do wave 3"
  - "onExecute como VoidCallback no _ChecklistTemplateCard — mantém onTap original do ListTile inalterado (seed → clone, isOwn → edit)"
patterns-established:
  - "showModalBottomSheet<T> com retorno tipado — modal coleta dados e retorna objeto criado para caller navegar"
  - "parentContext passado ao sheet para captura do messenger antes do await"
requirements-completed:
  - EXEC-01

duration: ~25min
completed: 2026-05-06
---

# Phase 14 Plan 05: Start Checklist Wiring Summary

**Botão Executar em cada card de template abre _StartChecklistSheet (Form: responsável, local, data, número/código) que chama createExecution e navega para ChecklistExecutionScreen via Navigator.push com snackbar de sucesso ao retornar.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-05-06T00:00:00Z
- **Completed:** 2026-05-06T00:25:00Z
- **Tasks:** 2
- **Files modified:** 1 modificado + 1 criado (stub)

## Accomplishments

- Botão "Executar" (ElevatedButton com play_arrow_rounded) adicionado ao rodapé de cada card na `ChecklistTemplateListScreen`, sem alterar o comportamento de toque existente do `ListTile` (seed → clone, isOwn → edit)
- `_showStartSheet` criado na state class: abre `_StartChecklistSheet` modal, recebe `ChecklistExecution` de retorno, navega para `ChecklistExecutionScreen`, recarrega lista ao retornar, exibe snackbar "Checklist finalizado com sucesso." quando `result == true`
- `_StartChecklistSheet` completo com Form de 4 campos (responsável obrigatório, local obrigatório, data com DatePicker default=hoje, número opcional), `_isLoading` guard no botão Confirmar, `ScaffoldMessenger` capturado antes do await

## Task Commits

1. **Task 1+2: Botão Executar + _StartChecklistSheet** — `e955a5b` (feat)
2. **Stub ChecklistExecutionScreen (worktree paralelo)** — `4c63908` (chore)

## Files Created/Modified

- `primeaudit/lib/screens/checklist/checklist_template_list_screen.dart` — imports adicionados, `_executionService`, `_showStartSheet`, `onExecute` no card, ElevatedButton Executar, classe `_StartChecklistSheet` + `_StartChecklistSheetState`
- `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` — stub mínimo criado para compilação no worktree paralelo (plano 14-04 cria a versão completa)

## Decisions Made

- Botão "Executar" como `ElevatedButton.icon` no rodapé do card (dentro de `Column` que envolve o `ListTile`) em vez de um ícone no trailing — garante que o trailing existente (clonar/menu/chevron) não é removido e a ação de execução é mais visível como ação primária do card
- Stub de `ChecklistExecutionScreen` criado no worktree para que `flutter analyze` passe durante execução paralela dos planos 14-04 e 14-05 — será sobrescrito no merge do wave 3

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Criado stub de ChecklistExecutionScreen para compilação paralela**
- **Found during:** Task 1 (verificação de imports)
- **Issue:** `checklist_execution_screen.dart` não existe no worktree (criado pelo plano 14-04, executado em paralelo); import no `checklist_template_list_screen.dart` causaria erro de compilação e falha no flutter analyze
- **Fix:** Stub mínimo criado com construtor idêntico ao esperado — `ChecklistExecutionScreen({required this.execution})` — suficiente para satisfazer o analisador estático
- **Files modified:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` (criado)
- **Verification:** `flutter analyze lib/screens/checklist/checklist_template_list_screen.dart` → `No issues found!`
- **Committed in:** `4c63908`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Fix necessário para execução paralela de worktrees. O stub será sobrescrito pelo plano 14-04 no merge do wave 3 sem conflito, pois a assinatura do construtor é idêntica.

## Issues Encountered

Edições feitas inicialmente no diretório raiz do projeto em vez do worktree (`agent-a87550d6599949a28`). Corrigido ao reescrever os arquivos no path absoluto correto do worktree.

## Known Stubs

- `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` — stub que renderiza `CircularProgressIndicator` em vez da tela completa de execução. Plano 14-04 (executado em worktree paralelo) cria a versão completa. O stub será sobrescrito no merge do wave 3.

## Threat Surface Scan

Nenhum novo endpoint de rede ou path de auth introduzido. Mitigações do threat register aplicadas:

- **T-14-13 (mitigate):** `validator` em campos obrigatórios (responsável, local); todos os valores passam por `.trim()` antes de `createExecution`
- **T-14-14 (mitigate):** `companyId` obtido de `CompanyContextService.instance.activeCompanyId` — derivado da sessão; RLS do banco adiciona segunda camada
- **T-14-15 (mitigate):** `_isLoading` flag desativa botão Confirmar durante `await createExecution` — sem insert duplicado por double-tap

## Next Phase Readiness

- Ponto de entrada de execução completo: auditor pode tocar "Executar" em qualquer card, preencher identificação e iniciar uma execução
- Requer `ChecklistExecutionScreen` completa (plano 14-04) para que o fluxo funcione end-to-end
- Merge do wave 3 combinará 14-04 (screen completa) e 14-05 (wiring) — nenhum conflito esperado

## Self-Check: PASSED

- [x] `primeaudit/lib/screens/checklist/checklist_template_list_screen.dart` modificado no worktree
- [x] `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` criado (stub) no worktree
- [x] `flutter analyze lib/screens/checklist/checklist_template_list_screen.dart` → `No issues found!`
- [x] Commit `e955a5b` existe (Task 1+2: feat)
- [x] Commit `4c63908` existe (stub chore)
- [x] `class _StartChecklistSheet` presente no arquivo (count=2: widget + state)
- [x] `Navigator.pop(context, execution)` presente em `_confirm()`
- [x] `ScaffoldMessenger.of(widget.parentContext)` capturado antes do await
- [x] Botão "Executar" com `ElevatedButton.icon` e `Icons.play_arrow_rounded` presente
- [x] `onTap` do `ListTile` inalterado (seed → clone, isOwn → edit)

---
*Phase: 14-checklist-execution-engine*
*Completed: 2026-05-06*
