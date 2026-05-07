-- =============================================================================
-- Migração: segmento e módulos em companies; placa em checklist_executions
-- Data: 2026-05-06
-- Idempotente: ADD COLUMN IF NOT EXISTS + DROP/ADD CONSTRAINT não falham em re-execução.
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 1. companies.segment — segmento de mercado da empresa
-- ----------------------------------------------------------------------------
ALTER TABLE companies ADD COLUMN IF NOT EXISTS segment TEXT NOT NULL DEFAULT 'industrial';

ALTER TABLE companies DROP CONSTRAINT IF EXISTS companies_segment_check;
ALTER TABLE companies
  ADD CONSTRAINT companies_segment_check
  CHECK (segment IN ('industrial', 'transportador', 'construcao', 'alimenticio', 'logistica', 'outro'));

-- ----------------------------------------------------------------------------
-- 2. companies.modules — módulos contratados pela empresa
-- Padrão: ambos habilitados para empresas existentes.
-- ----------------------------------------------------------------------------
ALTER TABLE companies ADD COLUMN IF NOT EXISTS modules TEXT[] NOT NULL DEFAULT ARRAY['auditoria', 'checklist'];

-- ----------------------------------------------------------------------------
-- 3. checklist_executions.veiculo_placa — placa do veículo (transportadores)
-- ----------------------------------------------------------------------------
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS veiculo_placa TEXT;

NOTIFY pgrst, 'reload schema';
