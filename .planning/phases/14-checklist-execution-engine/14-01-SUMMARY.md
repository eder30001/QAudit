---
plan: 14-01
phase: 14-checklist-execution-engine
status: complete
wave: 1
completed: 2026-05-06
checkpoint: supabase_db_push_required
---

# Summary: Plan 14-01 — SQL Migrations

## What Was Built

Dois arquivos de migration SQL idempotentes criados:

1. `primeaudit/supabase/migrations/20260506_create_checklist_executions.sql`
   - Tabela `checklist_executions` (11 colunas via ALTER TABLE ADD COLUMN IF NOT EXISTS)
   - Tabela `checklist_answers` (6 colunas via ALTER TABLE ADD COLUMN IF NOT EXISTS)
   - Constraint crítica `checklist_answers_execution_item_unique` UNIQUE (execution_id, item_id) — necessária para upsert com onConflict
   - FKs: template_id → checklist_templates, company_id → companies, created_by → profiles, execution_id → checklist_executions (CASCADE), item_id → checklist_template_items (CASCADE)
   - 4 índices para performance
   - RLS habilitada em ambas as tabelas com policies superuser/dev, adm e auditor

2. `primeaudit/supabase/migrations/20260506_add_options_to_checklist_template_items.sql`
   - `ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS options TEXT[];`

## Key Decisions

- `status CHECK IN ('rascunho', 'concluido')` — apenas dois estados válidos
- `data_execucao DATE` — sem timezone, para evitar bug de dia anterior no UTC-3
- `conformity_percent NUMERIC(5,2)` nullable — preenchido apenas ao finalizar
- RLS Pattern 3 para checklist_answers: subquery via execution FK para derivar autoria

## Self-Check

- [x] UNIQUE (execution_id, item_id) presente — upsert sem 409
- [x] RLS em ambas as tabelas
- [x] NOTIFY pgrst ao final
- [x] Padrão idempotente (DROP IF EXISTS antes de ADD CONSTRAINT)

## Checkpoint Required

**⚠ supabase db push necessário antes de Wave 2**

Os arquivos SQL estão prontos. Execute no terminal:
```
cd primeaudit
supabase db push
```

Wave 2 (services) depende dessas tabelas existirem no banco.

## key-files

### created
- primeaudit/supabase/migrations/20260506_create_checklist_executions.sql
- primeaudit/supabase/migrations/20260506_add_options_to_checklist_template_items.sql
