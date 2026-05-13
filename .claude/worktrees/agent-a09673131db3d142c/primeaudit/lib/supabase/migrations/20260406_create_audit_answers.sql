-- =============================================================================
-- Migração: tabela audit_answers
-- Data: 2026-04-06
-- Idempotente: pode ser executado múltiplas vezes sem erro.
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 1. Criar tabela (só cria se não existir, com id mínimo)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_answers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);

-- Adiciona cada coluna individualmente — ignora se já existir
ALTER TABLE audit_answers ADD COLUMN IF NOT EXISTS audit_id         UUID;
ALTER TABLE audit_answers ADD COLUMN IF NOT EXISTS template_item_id UUID;
ALTER TABLE audit_answers ADD COLUMN IF NOT EXISTS response         TEXT        NOT NULL DEFAULT '';
ALTER TABLE audit_answers ADD COLUMN IF NOT EXISTS observation      TEXT;
ALTER TABLE audit_answers ADD COLUMN IF NOT EXISTS answered_at      TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Remove defaults temporários
ALTER TABLE audit_answers ALTER COLUMN response   DROP DEFAULT;

-- ----------------------------------------------------------------------------
-- 2. Foreign keys (drop + add para ser idempotente)
-- ----------------------------------------------------------------------------
ALTER TABLE audit_answers DROP CONSTRAINT IF EXISTS audit_answers_audit_id_fkey;
ALTER TABLE audit_answers ADD CONSTRAINT audit_answers_audit_id_fkey
  FOREIGN KEY (audit_id) REFERENCES audits(id) ON DELETE CASCADE;

ALTER TABLE audit_answers DROP CONSTRAINT IF EXISTS audit_answers_template_item_id_fkey;
ALTER TABLE audit_answers ADD CONSTRAINT audit_answers_template_item_id_fkey
  FOREIGN KEY (template_item_id) REFERENCES template_items(id) ON DELETE CASCADE;

-- ----------------------------------------------------------------------------
-- 3. Constraint UNIQUE para habilitar upsert
-- ----------------------------------------------------------------------------
ALTER TABLE audit_answers
  DROP CONSTRAINT IF EXISTS audit_answers_audit_id_template_item_id_key;
ALTER TABLE audit_answers
  ADD CONSTRAINT audit_answers_audit_id_template_item_id_key
  UNIQUE (audit_id, template_item_id);

COMMENT ON TABLE audit_answers IS
  'Respostas do auditor aos itens do template durante a execução da auditoria.';

-- ----------------------------------------------------------------------------
-- 4. Índices
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_audit_answers_audit_id
  ON audit_answers (audit_id);

CREATE INDEX IF NOT EXISTS idx_audit_answers_item_id
  ON audit_answers (template_item_id);

-- ----------------------------------------------------------------------------
-- 5. Row Level Security
-- ----------------------------------------------------------------------------
ALTER TABLE audit_answers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "superuser_dev_answers_full" ON audit_answers;
DROP POLICY IF EXISTS "adm_answers_company"        ON audit_answers;
DROP POLICY IF EXISTS "auditor_answers_select"     ON audit_answers;
DROP POLICY IF EXISTS "auditor_answers_insert"     ON audit_answers;
DROP POLICY IF EXISTS "auditor_answers_update"     ON audit_answers;

-- superuser / dev: acesso total
CREATE POLICY "superuser_dev_answers_full" ON audit_answers
  USING  (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- adm: respostas de auditorias da sua empresa
CREATE POLICY "adm_answers_company" ON audit_answers
  USING (
    get_my_role() = 'adm'
    AND EXISTS (
      SELECT 1 FROM audits a
      WHERE a.id = audit_answers.audit_id
        AND a.company_id = get_my_company_id()
    )
  )
  WITH CHECK (
    get_my_role() = 'adm'
    AND EXISTS (
      SELECT 1 FROM audits a
      WHERE a.id = audit_answers.audit_id
        AND a.company_id = get_my_company_id()
    )
  );

-- auditor: lê de auditorias da sua empresa
CREATE POLICY "auditor_answers_select" ON audit_answers FOR SELECT
  USING (
    get_my_role() = 'auditor'
    AND EXISTS (
      SELECT 1 FROM audits a
      WHERE a.id = audit_answers.audit_id
        AND a.company_id = get_my_company_id()
    )
  );

-- auditor: insere/atualiza apenas em auditorias próprias
CREATE POLICY "auditor_answers_insert" ON audit_answers FOR INSERT
  WITH CHECK (
    get_my_role() = 'auditor'
    AND EXISTS (
      SELECT 1 FROM audits a
      WHERE a.id = audit_answers.audit_id
        AND a.auditor_id = auth.uid()
    )
  );

CREATE POLICY "auditor_answers_update" ON audit_answers FOR UPDATE
  USING (
    get_my_role() = 'auditor'
    AND EXISTS (
      SELECT 1 FROM audits a
      WHERE a.id = audit_answers.audit_id
        AND a.auditor_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 6. Recarregar schema cache
-- ----------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
