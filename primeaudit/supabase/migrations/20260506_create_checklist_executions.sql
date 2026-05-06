-- =============================================================================
-- Migração: checklist_executions e checklist_answers
-- Data: 2026-05-06
-- Idempotente: pode ser executado múltiplas vezes sem erro.
-- Tabelas novas; zero alterações em audits / audit_answers.
-- =============================================================================


-- ----------------------------------------------------------------------------
-- 1. Tabela checklist_executions
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS checklist_executions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
-- NOTA: template_id usa DEFAULT gen_random_uuid() apenas para satisfazer NOT NULL
-- durante ADD COLUMN IF NOT EXISTS em tabela potencialmente não-vazia (idempotência).
-- Todo row real fornecerá um template_id explícito.
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS template_id        UUID        NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS company_id         UUID;
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS created_by         UUID;
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS responsavel        TEXT        NOT NULL DEFAULT '';
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS local              TEXT        NOT NULL DEFAULT '';
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS numero             TEXT;
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS data_execucao      DATE        NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS status             TEXT        NOT NULL DEFAULT 'rascunho';
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS conformity_percent NUMERIC(5,2);
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE checklist_executions ADD COLUMN IF NOT EXISTS completed_at       TIMESTAMPTZ;


-- ----------------------------------------------------------------------------
-- 2. Constraints de checklist_executions
-- ----------------------------------------------------------------------------
ALTER TABLE checklist_executions DROP CONSTRAINT IF EXISTS checklist_executions_status_check;
ALTER TABLE checklist_executions ADD CONSTRAINT checklist_executions_status_check
  CHECK (status IN ('rascunho', 'concluido'));

ALTER TABLE checklist_executions DROP CONSTRAINT IF EXISTS checklist_executions_template_id_fkey;
ALTER TABLE checklist_executions ADD CONSTRAINT checklist_executions_template_id_fkey
  FOREIGN KEY (template_id) REFERENCES checklist_templates(id) ON DELETE RESTRICT;

ALTER TABLE checklist_executions DROP CONSTRAINT IF EXISTS checklist_executions_company_id_fkey;
ALTER TABLE checklist_executions ADD CONSTRAINT checklist_executions_company_id_fkey
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL;

ALTER TABLE checklist_executions DROP CONSTRAINT IF EXISTS checklist_executions_created_by_fkey;
ALTER TABLE checklist_executions ADD CONSTRAINT checklist_executions_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;


-- ----------------------------------------------------------------------------
-- 3. Tabela checklist_answers
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS checklist_answers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
-- NOTA: execution_id e item_id usam DEFAULT gen_random_uuid() para idempotência
-- em tabela potencialmente não-vazia. Todo row real fornecerá valores explícitos.
ALTER TABLE checklist_answers ADD COLUMN IF NOT EXISTS execution_id  UUID        NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_answers ADD COLUMN IF NOT EXISTS item_id       UUID        NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE checklist_answers ADD COLUMN IF NOT EXISTS response      TEXT        NOT NULL DEFAULT '';
ALTER TABLE checklist_answers ADD COLUMN IF NOT EXISTS observation   TEXT;
ALTER TABLE checklist_answers ADD COLUMN IF NOT EXISTS answered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW();


-- ----------------------------------------------------------------------------
-- 4. Constraints de checklist_answers
-- ----------------------------------------------------------------------------
ALTER TABLE checklist_answers DROP CONSTRAINT IF EXISTS checklist_answers_execution_id_fkey;
ALTER TABLE checklist_answers ADD CONSTRAINT checklist_answers_execution_id_fkey
  FOREIGN KEY (execution_id) REFERENCES checklist_executions(id) ON DELETE CASCADE;

ALTER TABLE checklist_answers DROP CONSTRAINT IF EXISTS checklist_answers_item_id_fkey;
ALTER TABLE checklist_answers ADD CONSTRAINT checklist_answers_item_id_fkey
  FOREIGN KEY (item_id) REFERENCES checklist_template_items(id) ON DELETE CASCADE;

-- CRÍTICA: constraint UNIQUE necessária para upsert com onConflict: 'execution_id,item_id'
-- Sem ela, o upsertAnswer do ChecklistAnswerService retorna erro 409.
ALTER TABLE checklist_answers DROP CONSTRAINT IF EXISTS checklist_answers_execution_item_unique;
ALTER TABLE checklist_answers ADD CONSTRAINT checklist_answers_execution_item_unique
  UNIQUE (execution_id, item_id);


-- ----------------------------------------------------------------------------
-- 5. Índices
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_checklist_executions_created_by     ON checklist_executions (created_by, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_checklist_executions_template_id    ON checklist_executions (template_id);
CREATE INDEX IF NOT EXISTS idx_checklist_executions_company_status ON checklist_executions (company_id, status);
CREATE INDEX IF NOT EXISTS idx_checklist_answers_execution_id      ON checklist_answers (execution_id);


-- ----------------------------------------------------------------------------
-- 6. RLS para checklist_executions
-- ----------------------------------------------------------------------------
ALTER TABLE checklist_executions ENABLE ROW LEVEL SECURITY;

-- Pattern 1: superuser/dev — acesso total
DROP POLICY IF EXISTS "superuser_dev_checklist_executions_full" ON checklist_executions;
CREATE POLICY "superuser_dev_checklist_executions_full" ON checklist_executions
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- Pattern 2: adm vê todas da empresa; auditor vê apenas as próprias
DROP POLICY IF EXISTS "checklist_executions_select" ON checklist_executions;
CREATE POLICY "checklist_executions_select" ON checklist_executions FOR SELECT
  USING (
    (get_my_role() = 'adm' AND company_id = get_my_company_id())
    OR created_by = auth.uid()
  );

-- Auditor insere apenas execuções próprias (created_by = auth.uid())
DROP POLICY IF EXISTS "checklist_executions_insert" ON checklist_executions;
CREATE POLICY "checklist_executions_insert" ON checklist_executions FOR INSERT
  WITH CHECK (created_by = auth.uid());

-- Auditor atualiza apenas execuções próprias (ex: status rascunho → concluido)
DROP POLICY IF EXISTS "checklist_executions_update" ON checklist_executions;
CREATE POLICY "checklist_executions_update" ON checklist_executions FOR UPDATE
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());


-- ----------------------------------------------------------------------------
-- 7. RLS para checklist_answers
-- ----------------------------------------------------------------------------
ALTER TABLE checklist_answers ENABLE ROW LEVEL SECURITY;

-- Pattern 1: superuser/dev — acesso total
DROP POLICY IF EXISTS "superuser_dev_checklist_answers_full" ON checklist_answers;
CREATE POLICY "superuser_dev_checklist_answers_full" ON checklist_answers
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- Pattern 3: subquery via FK — permissão derivada da execução pai
-- SELECT: auditor lê respostas de suas próprias execuções
DROP POLICY IF EXISTS "checklist_answers_select" ON checklist_answers;
CREATE POLICY "checklist_answers_select" ON checklist_answers FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM checklist_executions e
      WHERE e.id = checklist_answers.execution_id
        AND e.created_by = auth.uid()
    )
  );

-- WRITE (sem FOR = ALL): auditor escreve respostas de suas próprias execuções
DROP POLICY IF EXISTS "checklist_answers_write" ON checklist_answers;
CREATE POLICY "checklist_answers_write" ON checklist_answers
  USING (
    get_my_role() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM checklist_executions e
      WHERE e.id = checklist_answers.execution_id
        AND e.created_by = auth.uid()
    )
  )
  WITH CHECK (
    get_my_role() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM checklist_executions e
      WHERE e.id = checklist_answers.execution_id
        AND e.created_by = auth.uid()
    )
  );


-- ----------------------------------------------------------------------------
-- 8. Recarregar schema cache do PostgREST
-- ----------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
