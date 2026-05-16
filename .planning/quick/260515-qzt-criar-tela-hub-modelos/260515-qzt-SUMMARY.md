---
quick_id: 260515-qzt
slug: criar-tela-hub-modelos
status: complete
date: 2026-05-15
---

# Summary: Criar tela hub "Modelos"

## What was done

Criada nova tela hub `ModelsScreen` e atualizado o drawer do `HomeScreen`.

### Task 1 — ModelsScreen criado
- `primeaudit/lib/screens/templates/models_screen.dart` — nova tela com 5 cards:
  - **Auditorias** → navega para `AuditTypesScreen`
  - **Checklists** → navega para `ChecklistTemplatesScreen`
  - **Feedback** — stub desabilitado (opacity 0.5, sem onTap)
  - **Controle de equipamentos** — stub desabilitado
  - **Treinamentos** — stub desabilitado

### Task 2 — HomeScreen atualizado
- Import de `audit_types_screen.dart` substituído por `models_screen.dart`
- Item do drawer "Templates de Auditoria" → "Modelos" com ícone `folder_copy_rounded`
- Navega para `ModelsScreen` em vez de `AuditTypesScreen` diretamente

## Verification

- `dart analyze` — No issues found
- `flutter analyze` (background) — exit code 0
- Referências ao `AuditTypesScreen` no drawer removidas — confirmado por grep

## No regressions

O `AuditTypesScreen` continua existindo e é acessado via `ModelsScreen`. Nenhuma tela existente foi removida ou alterada além do drawer.
