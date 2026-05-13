---
slug: offline-mvp-field-audits
status: complete
date: 2026-05-09
commit: 06587e9
---

# Offline MVP — resultado

## O que foi entregue

- `connectivity_plus 6.1.5` — detecta online/offline em tempo real
- `_listenConnectivity()` — stream que dispara `_syncAll()` ao reconectar
- `_syncAll()` — retry paralelo de todos os itens `_failedSaves` de uma vez
- `_persistPendingSaves()` / `_restorePendingSaves()` — fila sobrevive ao fechar app (SharedPreferences JSON por `audit_id`)
- `PendingSave.fromJson` / `toJson` — serialização para persistência
- Banner laranja "Sem sinal · N pendentes" e banner azul "Sincronizando…" no topo do body

## Testes: 293 passando
