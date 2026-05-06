-- =============================================================================
-- Migração: adiciona coluna options em checklist_template_items
-- Data: 2026-05-06
-- Idempotente: ADD COLUMN IF NOT EXISTS não falha em re-execução.
-- Sem constraints: TEXT[] nullable não requer CHECK constraint.
-- Sem índice: nenhuma query filtra por options (coluna de leitura por item).
-- =============================================================================

ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS options TEXT[];

NOTIFY pgrst, 'reload schema';
