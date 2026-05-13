---
slug: foto-wifi-perde-tudo
status: resolved
trigger: "Ao tirar uma foto em item do tipo 'photo' no ChecklistExecutionScreen e depois desligar o WiFi, tudo é perdido (foto e respostas)."
created: 2026-05-09
updated: 2026-05-09
---

## Symptoms

- **Expected**: Miniatura com ícone de erro, snackbar de falha, mas o preenchimento das demais respostas continua e a finalização não é bloqueada
- **Actual**: Ao tirar foto e desligar WiFi, tudo é perdido (foto E respostas de outros itens)
- **Error messages**: Não reportadas pelo usuário
- **Timeline**: Identificado durante UAT da Fase 15
- **Reproduction**: 1) Abrir execução de checklist 2) Responder alguns itens 3) Ir em item do tipo 'photo' e tirar foto 4) Desligar WiFi 5) Observar que foto e respostas são perdidas

## Current Focus

hypothesis: "RESOLVIDO — dois bugs em _load() causavam perda de dados visíveis"
test: "Análise estática completa de _load(), _pickPhoto, _saveAnswer e merge de estado"
expecting: "Ambos os bugs corrigidos em primeaudit/lib/screens/checklist/checklist_execution_screen.dart"
next_action: "none"
reasoning_checkpoint: ""
tdd_checkpoint: ""

## Evidence

- timestamp: 2026-05-09
  type: code_analysis
  finding: |
    Bug 1 — _load() como recarga silenciosa: quando _load() era chamado após a carga
    inicial (RefreshIndicator, botão retry na error screen), ele definia _loading = true,
    removendo o ListView inteiro da árvore de widgets. Se a recarga falhasse (WiFi off),
    _error era definido e a error screen substituía o corpo — todas as respostas visíveis
    "desapareciam" da tela mesmo com _answers intacto em memória. O usuário via a tela de
    erro e concluía que tudo havia sido perdido.

- timestamp: 2026-05-09
  type: code_analysis
  finding: |
    Bug 2 — _photosPerItem.addAll(photosMap) sobrescrevia entradas locais: photosMap era
    construído apenas com dados do banco. Como Map.addAll substitui valores de chaves
    existentes, qualquer foto em estado uploading ou error (image == null, não ainda no
    banco) era descartada do map e desaparecia do strip de fotos do item após qualquer
    recarga. Mesmo que a tela sobrevivesse, o thumbnail da foto com falha sumia.

- timestamp: 2026-05-09
  type: code_analysis
  finding: |
    Bug 3 (defensivo) — _photosPerItem[itemId]! no catch block de _pickPhoto: o operador
    ! poderia lançar um Null check operator error em condição de corrida extrema onde
    _photosPerItem tivesse sido modificado entre o setState de adição e o catch. Trocado
    para null-safe check.

## Eliminated

- Auth session invalidation por queda de WiFi: _AuthGate usa currentSession como fallback;
  tokens JWT têm validade longa e não expiram instantaneamente por queda de rede.
- _saveAnswer propagando para limpar _answers: confirmado que o catch de _saveAnswer apenas
  adiciona ao _failedSaves, nunca remove de _answers.
- Flutter element reconciliation por falta de Keys: _allItems não muda durante upload/retry,
  posições do ListView são estáveis, estado dos StatefulWidget filhos é preservado.

## Resolution

root_cause: |
  Dois bugs em _load() causavam perda visual de dados. (1) Recargas definiam _loading = true
  removendo o corpo inteiro da tela — se falhassem, a error screen substituía as respostas
  visíveis. (2) _photosPerItem.addAll(photosMap) descartava entradas locais (uploading/error)
  não confirmadas no banco ao fazer addAll de qualquer recarga.

fix: |
  Adicionado bool _initialLoadDone para distinguir carga inicial de recargas.
  Na carga inicial: comportamento original (spinner + error screen se falhar).
  Em recargas: _loading NÃO é alterado; falha exibe snackbar com retry, conteúdo permanece.
  
  No merge de fotos: antes do addAll, as entradas locais (image == null) são coletadas do
  _photosPerItem existente e reinseridas em photosMap; depois _photosPerItem é substituído
  com clear + addAll garantindo que entradas locais não se percam.
  
  No catch block de _pickPhoto: trocado _photosPerItem[itemId]! por null-safe check.

verification: |
  dart analyze: 1 warning pré-existente (_Badge unused), zero erros, zero novos warnings.
  Diff focado: apenas _load(), campo _initialLoadDone, e catch block de _pickPhoto alterados.

files_changed:
  - primeaudit/lib/screens/checklist/checklist_execution_screen.dart
