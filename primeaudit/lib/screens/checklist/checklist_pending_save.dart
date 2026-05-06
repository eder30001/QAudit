// ---------------------------------------------------------------------------
// Dados de save pendente para retry da tela de execução de checklist.
//
// Copiado de `pending_save.dart` com rename PendingSave → ChecklistPendingSave.
// Mantém construtor `const` e campos `final` — imutável por design.
// ---------------------------------------------------------------------------
class ChecklistPendingSave {
  final String itemId;
  final String response;
  final String? observation;
  final int attemptCount;

  const ChecklistPendingSave({
    required this.itemId,
    required this.response,
    this.observation,
    this.attemptCount = 0,
  });

  ChecklistPendingSave copyWithAttempt() => ChecklistPendingSave(
        itemId: itemId,
        response: response,
        observation: observation,
        attemptCount: attemptCount + 1,
      );
}
