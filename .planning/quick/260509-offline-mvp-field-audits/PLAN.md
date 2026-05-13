---
slug: offline-mvp-field-audits
title: Offline MVP para auditorias de campo
date: 2026-05-09
status: in-progress
---

# Offline MVP — auditorias de campo

## Objetivo
Auditor perde sinal no campo → respostas ficam em fila local → ao reconectar, sincroniza automaticamente. Sem SQLite — apenas SharedPreferences + JSON.

## Tarefas

### T1 — Adicionar connectivity_plus ao pubspec.yaml
- Adicionar `connectivity_plus: ^6.1.4` em `dependencies`
- Rodar `flutter pub get`

### T2 — PendingSave: serialização JSON
Arquivo: `primeaudit/lib/screens/pending_save.dart`
- Adicionar `factory PendingSave.fromJson(Map<String, dynamic> json)`
- Adicionar `Map<String, dynamic> toJson()`

### T3 — AuditExecutionScreen: conectividade + persistência + auto-sync
Arquivo: `primeaudit/lib/screens/audit_execution_screen.dart`

**Imports novos:**
- `dart:async`
- `dart:convert`
- `package:connectivity_plus/connectivity_plus.dart`
- `package:shared_preferences/shared_preferences.dart`

**Campos novos no State:**
- `StreamSubscription<List<ConnectivityResult>>? _connectivitySub`
- `bool _isOnline = true`
- `static String _pendingKey(String auditId) => 'pending_saves_$auditId'`

**initState:** chamar `_restorePendingSaves()` + `_listenConnectivity()`

**dispose:** cancelar `_connectivitySub`

**`_restorePendingSaves()`** — carrega fila salva do SharedPreferences
**`_persistPendingSaves()`** — serializa `_failedSaves` para SharedPreferences
**`_listenConnectivity()`** — stream de conectividade; ao voltar online dispara `_syncAll()`
**`_syncAll()`** — retry paralelo de todos os itens em `_failedSaves`

**Modificar `_saveAnswer`:**
- No bloco catch: chamar `_persistPendingSaves()` após adicionar à fila
- No bloco try (sucesso): chamar `_persistPendingSaves()` após remover da fila

**Modificar `_scheduleRetry`:**
- Após sucesso: chamar `_persistPendingSaves()`

**Modificar `_buildAppBar`:**
- Exibir banner "Sem sinal · X pendentes" quando `!_isOnline && _failedSaves.isNotEmpty`
- Exibir banner "Sincronizando…" quando `_isOnline && _failedSaves.isNotEmpty`

### T4 — Commit
Mensagem: `feat(offline): auto-sync ao reconectar + fila persistente entre sessões`
