---
gsd_state_version: 1.0
milestone: v1.3
milestone_name: Notificações
status: active
stopped_at: ""
last_updated: "2026-05-13T21:00:00Z"
last_activity: 2026-05-15
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-13)

**Core value:** Nenhum dado de auditoria preenchido em campo deve ser perdido — save silencioso ou falha de rede não pode comprometer o trabalho do auditor.
**Current focus:** v1.3 Notificações — Phase 18: Firebase Infrastructure

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|

## Current Position

Phase: 18 — Firebase Infrastructure
Plan: TBD (roadmap created, planning starts next)
Status: Not started
Progress: ░░░░░░░░░░ 0% (0 of 3 phases complete)

Roadmap: 3 phases (18–20) | 8 requirements | 0% complete

## Deferred Items (acknowledged at v1.2 close)

| Requirement | Description | Target |
|-------------|-------------|--------|
| EXEC-06 | Assinatura digital ao finalizar checklist | v1.4+ |
| HIST-01 | Histórico de checklists com filtros | v1.4+ |
| HIST-02 | Visualização de checklist concluído em modo leitura | v1.4+ |
| HIST-03 | Indicadores de conformidade no histórico | v1.4+ |

## Accumulated Context

### Decisions carryover

- Manter setState — refactor de estado é milestone separada
- RLS como camada de segurança principal
- Migrations SQL seguem padrão idempotente YYYYMMDD_description.sql
- Arquitetura 3 camadas: screens → services → models
- Módulo Checklist independente do módulo de Auditoria
- Offline mode revertido — requer sqflite + Riverpod (Phase 999.2 backlog)
- Android first para FCM — iOS (APN) é out of scope em v1.3
- Sem UI in-app de notificações (sem badge, sem tela de histórico) — v1.4+ se necessário
- device_tokens: um token por usuário (sobrescreve ao renovar) — simplifica v1.3

### v1.3 Phase Map

| Phase | Name | Requirements |
|-------|------|--------------|
| 18 | Firebase Infrastructure | INFRA-03, INFRA-01 |
| 19 | Token Registration | NOTIF-04 |
| 20 | Backend Triggers + Push Dispatch | NOTIF-01, NOTIF-02, NOTIF-03, NOTIF-05, INFRA-02 |
