---
slug: offline-templates-lista-vazia
status: root_cause_found
trigger: "Templates não aparecem quando o WiFi está desligado — modo offline não funciona"
created: 2026-05-10
updated: 2026-05-10
---

## Symptoms

- **Expected**: Templates aparecem na tela de nova auditoria mesmo sem conexão (cache local)
- **Actual**: Lista de templates fica vazia quando WiFi está desligado
- **Error messages**: Nenhuma mensagem de erro visível
- **Timeline**: Nunca funcionou — offline nunca foi testado antes
- **Reproduction**: 1) Abrir o app com WiFi ligado 2) Desligar WiFi 3) Tentar criar nova auditoria 4) Lista de templates vazia

## Current Focus

hypothesis: "AuditTemplateService.getTypes() e getTemplates() fazem chamadas diretas ao Supabase sem nenhum mecanismo de cache local. Quando offline, as chamadas lançam exceção de rede — a qual é silenciada pelo catch vazio em _loadSheetData e _loadTemplates — resultando em listas vazias sem feedback ao usuário."
test: "Rastreamento do fluxo: _NewAuditSheetState._loadSheetData → AuditTemplateService.getTypes() → Supabase network call → SocketException offline → catch (_) {} → _loadingData = false, _types = []"
expecting: "Confirmado"
next_action: "apply_fix"

## Evidence

- timestamp: 2026-05-10T12:00:00Z
  file: primeaudit/lib/services/audit_template_service.dart
  finding: "getTypes() e getTemplates() são chamadas diretas ao Supabase sem cache ou fallback offline. Nenhuma lógica de SharedPreferences presente."

- timestamp: 2026-05-10T12:00:01Z
  file: primeaudit/lib/screens/audits_screen.dart L878-L899
  finding: "_loadSheetData() tem catch (_) {} vazio — a exceção de rede é silenciada. Resultado: _types = [], _loadingData = false, tela exibe 'Nenhum tipo disponível' sem indicar que está offline."

- timestamp: 2026-05-10T12:00:02Z
  file: primeaudit/lib/screens/audits_screen.dart L902-L913
  finding: "_loadTemplates() também tem catch vazio. Mesmo padrão: exceção silenciada, lista vazia."

- timestamp: 2026-05-10T12:00:03Z
  file: primeaudit/lib/screens/audit_execution_screen.dart
  finding: "O commit offline MVP (06587e9) implementou cache de respostas pendentes via SharedPreferences, mas NÃO implementou cache de templates. O escopo do MVP foi limitado à fila de respostas durante execução."

## Eliminated

- Problema de RLS/permissões: eliminado — funciona com WiFi ligado
- Bug no modelo AuditType.fromMap: eliminado — dados chegam corretamente quando online
- Problema de companyId nulo: eliminado — o companyId é passado corretamente

## Resolution

root_cause: "AuditTemplateService não possui cache local. Todas as chamadas de rede falham silenciosamente quando offline (catch vazio em _loadSheetData e _loadTemplates), deixando as listas de tipos e templates vazias."
fix: "Implementar cache de tipos e templates em SharedPreferences dentro de AuditTemplateService, com write-through ao carregar online e read-from-cache quando offline. Expor _isOnline via ConnectivityPlus no _NewAuditSheetState para mostrar banner informativo."
verification: "1) Abrir app online — templates carregam e são gravados em cache. 2) Desligar WiFi. 3) Abrir nova auditoria — tipos e templates aparecem do cache. 4) Banner 'Sem conexão — dados em cache' visível."
files_changed:
  - primeaudit/lib/services/audit_template_service.dart
  - primeaudit/lib/screens/audits_screen.dart
