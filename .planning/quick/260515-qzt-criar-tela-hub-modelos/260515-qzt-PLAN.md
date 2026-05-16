---
quick_id: 260515-qzt
slug: criar-tela-hub-modelos
description: Criar tela hub "Modelos" substituindo "Templates de Auditoria" no drawer
date: 2026-05-15
status: planned
---

# Quick Task 260515-qzt: Criar tela hub "Modelos"

## Objective

Substituir o item "Templates de Auditoria" no drawer por "Modelos", que abre uma nova tela hub com 5 cards de navegação: Auditorias (→ AuditTypesScreen), Checklists (→ ChecklistTemplatesScreen), e 3 stubs "em breve" (Feedback, Controle de equipamentos, Treinamentos).

## Tasks

### Task 1: Criar ModelsScreen

**File:** `primeaudit/lib/screens/templates/models_screen.dart`
**Action:** Criar nova tela hub com 5 cards de navegação
**Verify:** Arquivo criado, cards renderizam, navegação funciona para Auditorias e Checklists
**Done:** ModelsScreen compilado e navegável

### Task 2: Atualizar HomeScreen

**File:** `primeaudit/lib/screens/home_screen.dart`
**Action:** Substituir import de `audit_types_screen.dart` e item do drawer por `models_screen.dart` com label "Modelos"
**Verify:** Drawer exibe "Modelos" em vez de "Templates de Auditoria", abre ModelsScreen ao tocar
**Done:** HomeScreen atualizado, sem referências diretas ao AuditTypesScreen no drawer

## must_haves

- [ ] `models_screen.dart` criado em `primeaudit/lib/screens/templates/`
- [ ] Drawer exibe "Modelos" (não "Templates de Auditoria")
- [ ] Card "Auditorias" navega para AuditTypesScreen
- [ ] Card "Checklists" navega para ChecklistTemplatesScreen
- [ ] Cards "Feedback", "Controle de equipamentos", "Treinamentos" visíveis como stubs desabilitados
- [ ] Visibilidade respeitada: apenas `canAccessAdmin`
