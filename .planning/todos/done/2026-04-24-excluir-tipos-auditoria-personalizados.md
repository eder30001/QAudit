---
created: 2026-04-24T00:00:00Z
title: Adicionar opção de excluir tipos de auditoria personalizados
area: ui
files:
  - primeaudit/lib/services/audit_template_service.dart
  - primeaudit/lib/screens/admin/
---

## Problem

A tela de administração de tipos de auditoria não expõe a opção de excluir tipos personalizados (aqueles com `company_id` não-nulo). O usuário não consegue remover tipos criados por engano ou que ficaram obsoletos.

## Solution

O método `deleteType(String id)` já existe em `AuditTemplateService`. Falta expor a ação na UI:
- Adicionar botão/opção "Excluir" no card ou menu de contexto do tipo de auditoria
- Exibir diálogo de confirmação antes de excluir (padrão já usado em outras telas — `showDialog<bool>`)
- Filtrar para mostrar o botão apenas em tipos com `company_id != null` (tipos globais não devem ser excluídos por adm)
- Após exclusão bem-sucedida, recarregar a lista (`_load()`)
