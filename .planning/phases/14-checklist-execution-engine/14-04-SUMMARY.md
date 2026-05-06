---
phase: 14-checklist-execution-engine
plan: "04"
subsystem: screens
tags: [screen, dart, checklist, execution, auto-save, retry, widgets]
dependency_graph:
  requires:
    - "14-03 (ChecklistAnswerService.upsertAnswer, ChecklistExecutionService.finalizeExecution)"
    - "14-02 (ChecklistExecution model, ChecklistTemplateItem com options)"
  provides:
    - ChecklistExecutionScreen (primeaudit/lib/screens/checklist/checklist_execution_screen.dart)
    - ChecklistPendingSave (primeaudit/lib/screens/checklist/checklist_pending_save.dart)
  affects:
    - 14-05 (wiring navega para ChecklistExecutionScreen)
tech_stack:
  added: []
  patterns:
    - "fire-and-forget _saveAnswer: chamado sem await em _onAnswer/_onObservation — UI nunca bloqueia"
    - "retry exponencial: pow(2, attemptCount) com _maxAutoRetryAttempts = 4 (1s, 2s, 4s, 8s)"
    - "_failedSaves guard: bloqueia _finalize quando ha respostas nao salvas (T-14-12)"
    - "messenger antes de await: ScaffoldMessenger capturado antes de gap async (Pitfall 1 / T-14-11)"
    - "Future.wait: getItems + getAnswers em paralelo na _load()"
    - "Pitfall 3: _failedSaves.responses preservados sobre dados do banco no reload"
    - "_DateAnswer: showDatePicker serializado como yyyy-MM-dd, exibido como dd/MM/yyyy — sem intl"
    - "dispose obrigatorio: _TextAnswer, _NumberAnswer e _ChecklistItemCardState dispoe controllers"
key_files:
  created:
    - primeaudit/lib/screens/checklist/checklist_pending_save.dart
    - primeaudit/lib/screens/checklist/checklist_execution_screen.dart
  modified: []
decisions:
  - "Todos os widgets de resposta implementados no mesmo arquivo da screen (convencao _PascalCase privado do projeto)"
  - "_DateAnswer como StatelessWidget: nao precisa de controller pois o valor vive em _answers no State pai"
  - "readOnly em _buildBody usa _finalizing (nao uma flag separada): enquanto finaliza, UI congela"
  - "_ChecklistItemCard como StatefulWidget: gerencia _showObs e _obsCtrl localmente"
metrics:
  duration: "~20 minutes"
  completed: "2026-05-06"
  tasks_completed: 3
  tasks_total: 3
  files_created: 2
  files_modified: 0
---

# Phase 14 Plan 04: ChecklistExecutionScreen Summary

Tela central de execucao de checklist com auto-save silencioso fire-and-forget, retry exponencial ate 4 tentativas, 6 tipos de widget de resposta (yes_no, text, number, date, multiple_choice, photo placeholder), observacao por item e finalizacao com calculo de conformidade ao vivo.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1a | Criar ChecklistPendingSave e scaffold com _load | 1cf08a7 | primeaudit/lib/screens/checklist/checklist_pending_save.dart, primeaudit/lib/screens/checklist/checklist_execution_screen.dart |
| 1b | Auto-save + _buildAppBar + _buildBottomBar | 1cf08a7 | primeaudit/lib/screens/checklist/checklist_execution_screen.dart |
| 2 | Widgets de resposta (_ChecklistItemCard + todos os tipos) | cb4fd61 | primeaudit/lib/screens/checklist/checklist_execution_screen.dart |

Nota: Tasks 1a e 1b foram desenvolvidas como um unico commit pois o arquivo foi criado completo; Task 2 recebeu commit separado.

## What Was Built

**checklist_pending_save.dart**

Data class imutavel `ChecklistPendingSave` copiada de `pending_save.dart` com rename. Campos `final`: `itemId`, `response`, `observation?`, `attemptCount`. Metodo `copyWithAttempt()` retorna nova instancia com `attemptCount + 1`. Construtor `const`. Alias `typedef _PendingSave = ChecklistPendingSave` no arquivo da screen.

**checklist_execution_screen.dart — State e _load**

- State fields: `_allItems`, `_answers`, `_observations`, `_failedSaves`, `_retrying`, `_loading`, `_finalizing`, `_error`
- `_load()` usa `Future.wait([getItems, getAnswers])` para carregamento paralelo
- Rows do banco populam `_answers` e `_observations`; `_failedSaves` sobrescreve com respostas pendentes (Pitfall 3)
- Getters `_answeredCount`, `_totalCount`, `_conformity` (`ChecklistAnswerService.calculateConformity`)
- `_conformityColor()`: verde >= 80, amarelo >= 60, vermelho < 60

**checklist_execution_screen.dart — Auto-save**

- `_onAnswer`: `setState` + `_saveAnswer(itemId, response)` sem await (fire-and-forget)
- `_onObservation`: atualiza `_observations` + `_saveAnswer` sem await se ja ha resposta
- `_saveAnswer`: try/await upsert; em catch: `debugPrint`, `setState(_failedSaves)`, `_showSaveError`, `_scheduleRetry`
- `_showSaveError`: captura `ScaffoldMessenger.of(context)` antes de qualquer gap async (Pitfall 1); snackbar floating 6s com action 'Tentar novamente'
- `_scheduleRetry`: Set `_retrying` previne loop duplo por item; while loop com `pow(2, attemptCount).toInt()` delay; break apos 4 tentativas ou montage destruida; `finally` remove do Set

**checklist_execution_screen.dart — _finalize**

1. Guard `_failedSaves.isNotEmpty`: AlertDialog "Respostas nao salvas" com count, TextButton 'Entendido', `return` — nao prossegue
2. Dialog de confirmacao com `_answeredCount/_totalCount` e `_conformity.toStringAsFixed(1)%`
3. Se confirmado: `setState(_finalizing = true)`, `finalizeExecution`, `Navigator.pop(true)`
4. Catch: snackbar erro, `setState(_finalizing = false)`

**checklist_execution_screen.dart — Build**

- `_buildAppBar`: AppColors.primary, titulo templateName + responsavel, LinearProgressIndicator no bottom com progresso
- `_buildBody`: RefreshIndicator + ListView.builder + `_ChecklistItemCard` por item
- `_buildBottomBar`: conformidade ao vivo com cor semantica + ElevatedButton 'Finalizar checklist' (desabilitado durante _finalizing)
- `_buildError`: icon cloud_off, texto, OutlinedButton 'Tentar novamente'

**Widgets de resposta**

- `_ChecklistItemCard`: StatefulWidget com badge numerico, descricao, `_AnswerWidget`, campo observacao colapsavel (TextEditingController com dispose())
- `_AnswerWidget`: switch em `item.itemType` com 6 casos
- `_TwoOptionButtons`: Row de `AnimatedContainer` com icone + label, borda colorida quando selecionado
- `_TextAnswer`: StatefulWidget, TextEditingController, dispose(), TextField multiline
- `_NumberAnswer`: StatefulWidget, TextEditingController, dispose(), keyboardType numerico, FilteringTextInputFormatter `[0-9.]`
- `_DateAnswer`: StatelessWidget, `showDatePicker`, serializa `yyyy-MM-dd`, exibe `dd/MM/yyyy` via `padLeft` sem intl
- `_MultipleChoiceAnswer`: Wrap de AnimatedContainer chips; exibe 'Nenhuma opcao configurada' quando `options.isEmpty`
- `_PhotoPlaceholder`: Container nao interativo com icon + texto informativo (Phase 15)
- `_Badge`: badge com background `color.withValues(alpha: 0.1)` e texto colorido

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

| Check | Result |
|-------|--------|
| `class ChecklistPendingSave` count = 1 | PASS |
| `copyWithAttempt` count = 1 | PASS |
| `class ChecklistExecutionScreen` count = 1 | PASS |
| `_saveAnswer(itemId` sem await (fire-and-forget) | PASS |
| `pow(2, pending.attemptCount)` presente | PASS |
| `_failedSaves.isNotEmpty` guard presente | PASS |
| `case 'number'` presente no switch | PASS |
| `case 'date'` presente no switch | PASS |
| `ctrl.dispose` minimo 2 ocorrencias | PASS (2: _TextAnswer + _NumberAnswer) |
| `flutter analyze` zero erros | PASS |

## Known Stubs

- `_PhotoPlaceholder`: placeholder nao interativo para tipo `photo`. Dados reais serao implementados na Phase 15 (captura de imagens). A tela renderiza o badge informativo mas nao registra nenhuma resposta para itens do tipo photo — nao impede o objetivo do plano (execucao dos demais tipos de item).

## Threat Surface Scan

Nenhum novo endpoint de rede ou path de auth introduzido alem do que o plano previa.

Mitigacoes do threat register aplicadas:

- **T-14-10 (mitigate):** `_maxAutoRetryAttempts = 4` + Set `_retrying` — impede loop infinito e retry duplo por item
- **T-14-11 (mitigate):** `if (!mounted) return` antes de todo setState/context apos await; messenger capturado antes de gap async
- **T-14-12 (mitigate):** Guard `_failedSaves.isNotEmpty` bloqueia `_finalize` com dialog explicativo — dados nao sao perdidos

## Self-Check: PASSED

- [x] `primeaudit/lib/screens/checklist/checklist_pending_save.dart` existe no worktree
- [x] `primeaudit/lib/screens/checklist/checklist_execution_screen.dart` existe no worktree
- [x] Commit 1cf08a7 existe (Task 1a+1b)
- [x] Commit cb4fd61 existe (Task 2)
