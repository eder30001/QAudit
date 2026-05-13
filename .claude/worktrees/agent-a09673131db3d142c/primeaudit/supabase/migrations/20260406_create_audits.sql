-- =============================================================================
-- Migração: tabela audits e ajustes de schema
-- Data: 2026-04-06
-- Idempotente: pode ser executado múltiplas vezes sem erro.
-- =============================================================================


-- ----------------------------------------------------------------------------
-- 1. Corrigir constraint de roles em profiles
-- ----------------------------------------------------------------------------
ALTER TABLE profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('superuser', 'dev', 'adm', 'auditor', 'anonymous'));


-- ----------------------------------------------------------------------------
-- 2. Adicionar requires_perimeter em companies
-- ----------------------------------------------------------------------------
ALTER TABLE companies
  ADD COLUMN IF NOT EXISTS requires_perimeter BOOLEAN NOT NULL DEFAULT false;


-- ----------------------------------------------------------------------------
-- 3. Colunas da tabela audits
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);

ALTER TABLE audits ADD COLUMN IF NOT EXISTS title              TEXT;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS audit_type_id      UUID;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS template_id        UUID;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS company_id         UUID;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS perimeter_id       UUID;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS auditor_id         UUID;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS status             TEXT        NOT NULL DEFAULT 'rascunho';
ALTER TABLE audits ADD COLUMN IF NOT EXISTS created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE audits ADD COLUMN IF NOT EXISTS deadline           TIMESTAMPTZ;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS completed_at       TIMESTAMPTZ;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS conformity_percent NUMERIC(5, 2);


-- ----------------------------------------------------------------------------
-- 4. Foreign keys (drop + add para ser idempotente)
-- ----------------------------------------------------------------------------
ALTER TABLE audits DROP CONSTRAINT IF EXISTS audits_audit_type_id_fkey;
ALTER TABLE audits ADD CONSTRAINT audits_audit_type_id_fkey
  FOREIGN KEY (audit_type_id) REFERENCES audit_types(id) ON DELETE RESTRICT;

ALTER TABLE audits DROP CONSTRAINT IF EXISTS audits_template_id_fkey;
ALTER TABLE audits ADD CONSTRAINT audits_template_id_fkey
  FOREIGN KEY (template_id) REFERENCES audit_templates(id) ON DELETE RESTRICT;

ALTER TABLE audits DROP CONSTRAINT IF EXISTS audits_company_id_fkey;
ALTER TABLE audits ADD CONSTRAINT audits_company_id_fkey
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE RESTRICT;

ALTER TABLE audits DROP CONSTRAINT IF EXISTS audits_perimeter_id_fkey;
ALTER TABLE audits ADD CONSTRAINT audits_perimeter_id_fkey
  FOREIGN KEY (perimeter_id) REFERENCES perimeters(id) ON DELETE SET NULL;

ALTER TABLE audits DROP CONSTRAINT IF EXISTS audits_auditor_id_fkey;
ALTER TABLE audits ADD CONSTRAINT audits_auditor_id_fkey
  FOREIGN KEY (auditor_id) REFERENCES profiles(id) ON DELETE RESTRICT;


-- ----------------------------------------------------------------------------
-- 5. Constraints de valor
-- ----------------------------------------------------------------------------
ALTER TABLE audits DROP CONSTRAINT IF EXISTS audits_status_check;
ALTER TABLE audits ADD CONSTRAINT audits_status_check
  CHECK (status IN ('rascunho','em_andamento','concluida','atrasada','cancelada'));

ALTER TABLE audits DROP CONSTRAINT IF EXISTS audits_conformity_check;
ALTER TABLE audits ADD CONSTRAINT audits_conformity_check
  CHECK (conformity_percent IS NULL OR conformity_percent BETWEEN 0 AND 100);


-- ----------------------------------------------------------------------------
-- 6. Índices
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_audits_company_id  ON audits (company_id);
CREATE INDEX IF NOT EXISTS idx_audits_auditor_id  ON audits (auditor_id);
CREATE INDEX IF NOT EXISTS idx_audits_status      ON audits (status);
CREATE INDEX IF NOT EXISTS idx_audits_created_at  ON audits (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audits_deadline    ON audits (deadline) WHERE deadline IS NOT NULL;


-- ----------------------------------------------------------------------------
-- 7. Row Level Security
-- ----------------------------------------------------------------------------
ALTER TABLE audits ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION get_my_company_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT company_id FROM profiles WHERE id = auth.uid();
$$;

-- Remove policies antigas antes de recriar
DROP POLICY IF EXISTS "superuser_dev_full_access" ON audits;
DROP POLICY IF EXISTS "adm_company_access"         ON audits;
DROP POLICY IF EXISTS "auditor_select_company"     ON audits;
DROP POLICY IF EXISTS "auditor_insert_own"         ON audits;
DROP POLICY IF EXISTS "auditor_update_own"         ON audits;

-- superuser e dev: acesso total
CREATE POLICY "superuser_dev_full_access" ON audits
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- adm: todas as auditorias da sua empresa
CREATE POLICY "adm_company_access" ON audits
  USING  (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());

-- auditor: lê todas da empresa, insere/edita só as próprias
CREATE POLICY "auditor_select_company" ON audits FOR SELECT
  USING (get_my_role() = 'auditor' AND company_id = get_my_company_id());

CREATE POLICY "auditor_insert_own" ON audits FOR INSERT
  WITH CHECK (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
    AND auditor_id = auth.uid()
  );

CREATE POLICY "auditor_update_own" ON audits FOR UPDATE
  USING  (get_my_role() = 'auditor' AND auditor_id = auth.uid())
  WITH CHECK (get_my_role() = 'auditor' AND auditor_id = auth.uid());


-- ----------------------------------------------------------------------------
-- 8. Trigger: completed_at preenchido automaticamente ao concluir
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_completed_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'concluida' AND OLD.status <> 'concluida' THEN
    NEW.completed_at = NOW();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_completed_at ON audits;
CREATE TRIGGER trg_set_completed_at
  BEFORE UPDATE ON audits
  FOR EACH ROW EXECUTE FUNCTION set_completed_at();


-- ----------------------------------------------------------------------------
-- 9. Trigger: marcar como 'atrasada' automaticamente (via pg_cron)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mark_overdue_audits()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE audits
  SET status = 'atrasada'
  WHERE status = 'em_andamento'
    AND deadline IS NOT NULL
    AND deadline < NOW();
END;
$$;

-- Para agendar via pg_cron (rodar uma vez após a migração, se pg_cron estiver ativo):
-- SELECT cron.schedule('check_overdue', '0 * * * *', 'SELECT mark_overdue_audits()');


-- ----------------------------------------------------------------------------
-- 10. Recarregar schema cache do PostgREST
-- ----------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
