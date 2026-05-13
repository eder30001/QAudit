# Phase 1: Data Integrity - Pattern Map

**Mapped:** 2026-04-16
**Files analyzed:** 3 (1 modified + 2 new test files)
**Analogs found:** 3 / 3

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `primeaudit/lib/screens/audit_execution_screen.dart` | screen (StatefulWidget) | request-response + event-driven (retry) | itself — modificação cirúrgica de métodos existentes | exact (arquivo alvo) |
| `primeaudit/test/audit_execution_save_error_test.dart` | test (widget test) | request-response | `primeaudit/test/widget_test.dart` | role-match |
| `primeaudit/test/pending_save_test.dart` | test (unit test) | transform | `primeaudit/test/widget_test.dart` | role-match (único teste existente) |

---

## Pattern Assignments

### `primeaudit/lib/screens/audit_execution_screen.dart` (screen, request-response + retry)

**Analog:** o próprio arquivo — todas as mudanças são modificações cirúrgicas de métodos existentes e adição de campos/classe privada.

---

#### Padrão de imports — sem alteração necessária (linhas 1-8)

```dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/audit.dart';
import '../models/audit_template.dart';
import '../services/audit_answer_service.dart';
import '../services/audit_service.dart';
import '../services/audit_template_service.dart';
```

Adicionar no topo do arquivo (após imports existentes):

```dart
import 'dart:math'; // para pow() no backoff exponencial
```

---

#### Padrão de campos de estado por itemId (linhas 27-29)

Modelo estabelecido no arquivo — `Map<String, String>` com chave = `itemId`:

```dart
// itemId → resposta | itemId → observação
final Map<String, String> _answers = {};
final Map<String, String> _observations = {};
```

**Novos campos a adicionar no `_AuditExecutionScreenState` (após linha 29), seguindo o mesmo padrão:**

```dart
// Fila de retry: itemId → dados do save com falha
final Map<String, _PendingSave> _failedSaves = {};

// Controle de retry em andamento por item (evita loops duplos)
final Set<String> _retrying = {};
```

---

#### Padrão de `_saveAnswer` — bug atual (linhas 219-231)

**Código atual com catch silencioso (BUG — origem do problema):**

```dart
Future<void> _saveAnswer(String itemId, String response,
    {String? observation}) async {
  try {
    await _answerService.upsertAnswer(
      auditId: widget.audit.id,
      templateItemId: itemId,
      response: response,
      observation: observation ?? _observations[itemId],
    );
  } catch (_) {
    // Falha silenciosa — pode tentar novamente ao finalizar  ← LINHA 228, O BUG
  }
}
```

**Substituição completa (D-01, D-04, D-05):**

```dart
Future<void> _saveAnswer(String itemId, String response,
    {String? observation}) async {
  final obs = observation ?? _observations[itemId];
  try {
    await _answerService.upsertAnswer(
      auditId: widget.audit.id,
      templateItemId: itemId,
      response: response,
      observation: obs,
    );
    // Sucesso: remove da fila de falhas se estava lá
    if (_failedSaves.containsKey(itemId) && mounted) {
      setState(() => _failedSaves.remove(itemId));
    }
  } catch (e) {
    debugPrint('[_saveAnswer] itemId=$itemId erro: $e');
    if (!mounted) return;
    setState(() {
      _failedSaves[itemId] = _PendingSave(
        itemId: itemId,
        response: response,
        observation: obs,
      );
    });
    _showSaveError(itemId, response, obs);
    _scheduleRetry(itemId);
  }
}
```

---

#### Padrão de SnackBar com action button — analog: linhas 165-173 e 208-215

**Padrão existente no arquivo (sem action button — apenas notificação):**

```dart
// Linha 165-173: _discardAndExit catch block
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: Text('Erro ao excluir auditoria: $e'),
  backgroundColor: AppColors.error,
  behavior: SnackBarBehavior.floating,
));

// Linha 208-215: _cancelAudit catch block (mesmo padrão)
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: Text('Erro ao cancelar: $e'),
  backgroundColor: AppColors.error,
  behavior: SnackBarBehavior.floating,
));
```

**Novo método `_showSaveError` — estende o padrão existente com `action` e `clearSnackBars`:**

```dart
void _showSaveError(String itemId, String response, String? observation) {
  if (!mounted) return;
  // Captura o messenger antes de qualquer await (evita uso de context após gap)
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars(); // descarta snackbars anteriores para evitar acúmulo
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Não foi possível salvar'),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Tentar novamente',
        textColor: Colors.white,
        onPressed: () {
          // itemId, response, observation são Strings imutáveis — captura de closure segura
          _saveAnswer(itemId, response, observation: observation);
        },
      ),
    ),
  );
}
```

---

#### Padrão de retry com backoff exponencial — sem analog (novo método)

Usa `dart:math pow()` e `Future.delayed` em loop com guard `mounted`:

```dart
static const _maxAutoRetryAttempts = 4;
// Delays: tentativa 0 = 1s, 1 = 2s, 2 = 4s, 3 = 8s

Future<void> _scheduleRetry(String itemId) async {
  if (_retrying.contains(itemId)) return; // já existe loop de retry para este item
  _retrying.add(itemId);

  try {
    while (_failedSaves.containsKey(itemId)) {
      final pending = _failedSaves[itemId]!;
      if (pending.attemptCount >= _maxAutoRetryAttempts) break; // para auto-retry

      final delaySeconds = pow(2, pending.attemptCount).toInt(); // 1, 2, 4, 8
      await Future.delayed(Duration(seconds: delaySeconds));

      // Guard mounted após cada await (padrão estabelecido no projeto — CONVENTIONS.md)
      if (!mounted || !_failedSaves.containsKey(itemId)) break;

      try {
        await _answerService.upsertAnswer(
          auditId: widget.audit.id,
          templateItemId: itemId,
          response: pending.response,
          observation: pending.observation,
        );
        if (mounted) setState(() => _failedSaves.remove(itemId));
        break;
      } catch (_) {
        if (mounted) {
          setState(() {
            _failedSaves[itemId] = pending.copyWithAttempt();
          });
        }
      }
    }
  } finally {
    _retrying.remove(itemId);
  }
}
```

---

#### Padrão de `_finalize` — guarda D-06 inserida no início

**Padrão existente de `showDialog<bool>` (linhas 235-276):**

```dart
Future<void> _finalize() async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Finalizar auditoria'),
      // ...
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Voltar'),
        ),
        ElevatedButton(
          onPressed: _canFinalize ? () => Navigator.pop(ctx, true) : null,
          // ...
        ),
      ],
    ),
  );
  if (confirm != true) return;
  // ...
}
```

**Guarda a inserir como primeiras linhas do `_finalize`, antes do `showDialog` existente:**

```dart
Future<void> _finalize() async {
  // Guarda D-06: bloqueia finalização se houver saves com falha
  if (_failedSaves.isNotEmpty) {
    final count = _failedSaves.length;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Respostas não salvas'),
        content: Text(
          '$count resposta${count > 1 ? 's' : ''} não '
          '${count > 1 ? 'foram salvas' : 'foi salva'}. '
          'Resolva as falhas antes de finalizar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    return; // NÃO prossegue para o dialog de confirmação
  }

  // Continua com o dialog de confirmação existente (sem alteração)...
```

---

#### Classe privada `_PendingSave` — inserir antes de `_Badge` (após linha 1376)

**Padrão de classe privada de dados seguindo as convenções do projeto (classes `_PascalCase`, `const` constructor, `required` params, campo `final`):**

```dart
// ---------------------------------------------------------------------------
// Dados de save pendente para retry
// ---------------------------------------------------------------------------
class _PendingSave {
  final String itemId;
  final String response;
  final String? observation;
  final int attemptCount;

  const _PendingSave({
    required this.itemId,
    required this.response,
    this.observation,
    this.attemptCount = 0,
  });

  _PendingSave copyWithAttempt() => _PendingSave(
    itemId: itemId,
    response: response,
    observation: observation,
    attemptCount: attemptCount + 1,
  );
}
```

**Localização no arquivo:** inserir entre a linha 1375 (fechamento da classe `_AuditExecutionScreenState`) e a linha 1377 (início de `// Bloco de seção`). Na prática, antes da classe `_Badge` ao final do arquivo (linha 1377 em diante).

---

### `primeaudit/test/audit_execution_save_error_test.dart` (test, widget test)

**Analog:** `primeaudit/test/widget_test.dart`

O único teste existente é um widget test boilerplate do Flutter. A estrutura de `group`/`testWidgets`/`setUp` deve seguir a convenção Flutter.

**Padrão de imports do arquivo de teste existente (linhas 1-10):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:primeaudit/main.dart';
```

**Padrão de estrutura do teste existente (linhas 13-29):**

```dart
void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PrimeAuditApp());

    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
```

**Estrutura alvo para o novo arquivo de widget test — copia a estrutura e expande com `group`, mock service, e `pumpWidget` com `MaterialApp`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Imports do domínio
import 'package:primeaudit/screens/audit_execution_screen.dart';
import 'package:primeaudit/models/audit.dart';
import 'package:primeaudit/services/audit_answer_service.dart';

void main() {
  group('AuditExecutionScreen — save error handling', () {
    testWidgets('DINT-01: exibe snackbar quando upsertAnswer lança exceção',
        (WidgetTester tester) async {
      // Setup: mock service que lança exceção
      // ...
      await tester.pumpWidget(MaterialApp(home: AuditExecutionScreen(audit: mockAudit)));
      // ...
      expect(find.text('Não foi possível salvar'), findsOneWidget);
    });

    testWidgets('DINT-03: snackbar action "Tentar novamente" chama _saveAnswer novamente',
        (WidgetTester tester) async {
      // ...
    });

    testWidgets('D-06: _finalize() exibe dialog de bloqueio quando _failedSaves não está vazio',
        (WidgetTester tester) async {
      // ...
    });
  });
}
```

**Nota de implementação:** `AuditAnswerService` não tem interface abstrata — o mock precisará ser injetado por subclasse ou o teste precisará de um wrapper. Avaliar durante implementação se injeção por construtor é necessária (mínima invasão) ou se usar `Fake` via herança.

---

### `primeaudit/test/pending_save_test.dart` (test, unit test)

**Analog:** `primeaudit/test/widget_test.dart` (único arquivo de teste existente — usado como referência de estrutura mínima)

**Estrutura alvo para o novo arquivo de unit test — sem `tester`, apenas `test()` e `expect()`:**

```dart
import 'package:flutter_test/flutter_test.dart';

// _PendingSave é uma classe privada do arquivo de tela —
// precisará ser tornada interna-testável (ex: extraída para arquivo separado)
// ou testada via comportamento observável da tela.
// Avaliar durante implementação.

void main() {
  group('_PendingSave', () {
    test('copyWithAttempt incrementa attemptCount', () {
      const pending = _PendingSave(
        itemId: 'item-1',
        response: 'ok',
        attemptCount: 2,
      );
      final next = pending.copyWithAttempt();
      expect(next.attemptCount, equals(3));
      expect(next.itemId, equals('item-1'));
      expect(next.response, equals('ok'));
    });

    test('attemptCount inicial é 0 quando não informado', () {
      const pending = _PendingSave(itemId: 'x', response: 'yes');
      expect(pending.attemptCount, equals(0));
    });
  });
}
```

**Nota de implementação:** `_PendingSave` é definida como classe privada de arquivo em `audit_execution_screen.dart`. Para ser unit-testável diretamente, deve ser movida para um arquivo próprio (ex: `lib/screens/pending_save.dart`) ou declarada no nível do arquivo sem o prefixo `_`. Alternativamente, os testes de backoff podem ser feitos via comportamento observável (widget test que verifica `_failedSaves` state indiretamente). Decisão fica para o implementador.

---

## Shared Patterns

### Mounted Guard após await
**Fonte:** Padrão estabelecido em todo o projeto (ex: `audit_execution_screen.dart` linhas 78, 95, 164, 206, 284)
**Aplicar em:** `_scheduleRetry` (após cada `await Future.delayed` e `await upsertAnswer`), `_saveAnswer` (após `await upsertAnswer`)

```dart
// Padrão do projeto — verificar antes de qualquer setState após await
if (!mounted) return;
setState(() { ... });

// No loop de retry — usar break em vez de return
if (!mounted || !_failedSaves.containsKey(itemId)) break;
```

### SnackBar com AppColors.error e SnackBarBehavior.floating
**Fonte:** `audit_execution_screen.dart` linhas 167-173, 210-215, 290-295
**Aplicar em:** `_showSaveError` — mantém consistência visual com os outros 3 snackbars de erro da tela

```dart
// Padrão de todos os snackbars de erro da tela
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: Text('...'),
  backgroundColor: AppColors.error,
  behavior: SnackBarBehavior.floating,
));
```

### showDialog com await e guard `if (confirm != true) return`
**Fonte:** `audit_execution_screen.dart` linhas 140-160 (`_discardAndExit`), 178-197 (`_cancelAudit`), 235-276 (`_finalize`)
**Aplicar em:** dialog de bloqueio D-06 dentro de `_finalize`

```dart
// Padrão estabelecido: await showDialog + guard de retorno
final confirm = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
      // ...
    ],
  ),
);
if (confirm != true) return;
```

### Map privado com chave itemId para estado por item
**Fonte:** `audit_execution_screen.dart` linhas 27-29
**Aplicar em:** `_failedSaves` (`Map<String, _PendingSave>`) e `_retrying` (`Set<String>`)

```dart
final Map<String, String> _answers = {};      // padrão existente
final Map<String, String> _observations = {}; // padrão existente

// Novos campos seguem o mesmo padrão:
final Map<String, _PendingSave> _failedSaves = {};
final Set<String> _retrying = {};
```

### Assinatura de service: exceção propagada, caller faz catch
**Fonte:** `audit_answer_service.dart` linhas 23-38 — `upsertAnswer` não tem try/catch interno, propaga exceções para o caller
**Aplicar em:** `_saveAnswer` (caller) usa `catch (e)` amplo para capturar todos os tipos: `PostgrestException`, `ClientException`, `SocketException`, `TimeoutException`

```dart
// audit_answer_service.dart linha 23-38: sem try/catch, exceção sobe
Future<void> upsertAnswer({...}) async {
  await _client.from('audit_answers').upsert({...});
  // qualquer exceção propaga para o caller
}

// _saveAnswer: catch (e) amplo — correto para todos os tipos de falha
} catch (e) {
  debugPrint('[_saveAnswer] itemId=$itemId erro: $e');
  // ...
}
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| — | — | — | Todos os arquivos têm analog adequado |

O único gap é que `_PendingSave` e o retry com backoff exponencial não têm precedente no projeto, mas o padrão de `Map` de estado e `Future.delayed` com guard `mounted` são suficientemente bem estabelecidos para guiar a implementação.

---

## Metadata

**Analog search scope:** `primeaudit/lib/screens/`, `primeaudit/lib/services/`, `primeaudit/lib/core/`, `primeaudit/test/`
**Files scanned:** 5 (`audit_execution_screen.dart`, `audit_answer_service.dart`, `app_colors.dart`, `app_theme.dart`, `widget_test.dart`)
**Pattern extraction date:** 2026-04-16
