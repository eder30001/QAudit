-- =============================================================================
-- Migracao: tabela audit_item_images + bucket audit-images (Storage)
-- Data: 2026-04-27
-- Idempotente: pode ser executado multiplas vezes sem erro.
-- =============================================================================

-- 1. Tabela base
CREATE TABLE IF NOT EXISTS audit_item_images (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);

-- 2. Colunas (idempotentes)
ALTER TABLE audit_item_images ADD COLUMN IF NOT EXISTS audit_id          UUID NOT NULL;
ALTER TABLE audit_item_images ADD COLUMN IF NOT EXISTS template_item_id  UUID NOT NULL;
ALTER TABLE audit_item_images ADD COLUMN IF NOT EXISTS company_id        UUID NOT NULL;
ALTER TABLE audit_item_images ADD COLUMN IF NOT EXISTS storage_path      TEXT NOT NULL;
ALTER TABLE audit_item_images ADD COLUMN IF NOT EXISTS created_by        UUID NOT NULL;
ALTER TABLE audit_item_images ADD COLUMN IF NOT EXISTS created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 3. Foreign keys (drop + add para idempotencia)
ALTER TABLE audit_item_images DROP CONSTRAINT IF EXISTS audit_item_images_audit_id_fkey;
ALTER TABLE audit_item_images ADD CONSTRAINT audit_item_images_audit_id_fkey
  FOREIGN KEY (audit_id) REFERENCES audits(id) ON DELETE CASCADE;

ALTER TABLE audit_item_images DROP CONSTRAINT IF EXISTS audit_item_images_template_item_id_fkey;
ALTER TABLE audit_item_images ADD CONSTRAINT audit_item_images_template_item_id_fkey
  FOREIGN KEY (template_item_id) REFERENCES template_items(id) ON DELETE RESTRICT;

ALTER TABLE audit_item_images DROP CONSTRAINT IF EXISTS audit_item_images_company_id_fkey;
ALTER TABLE audit_item_images ADD CONSTRAINT audit_item_images_company_id_fkey
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE RESTRICT;

ALTER TABLE audit_item_images DROP CONSTRAINT IF EXISTS audit_item_images_created_by_fkey;
ALTER TABLE audit_item_images ADD CONSTRAINT audit_item_images_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE RESTRICT;

-- 4. Indexes
CREATE INDEX IF NOT EXISTS idx_audit_item_images_audit_item
  ON audit_item_images (audit_id, template_item_id);
CREATE INDEX IF NOT EXISTS idx_audit_item_images_company_id
  ON audit_item_images (company_id);
CREATE INDEX IF NOT EXISTS idx_audit_item_images_created_at
  ON audit_item_images (created_at DESC);

-- 5. RLS
ALTER TABLE audit_item_images ENABLE ROW LEVEL SECURITY;

-- superuser e dev: acesso total
DROP POLICY IF EXISTS "superuser_dev_audit_item_images_full" ON audit_item_images;
CREATE POLICY "superuser_dev_audit_item_images_full" ON audit_item_images
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- adm: CRUD na propria empresa
DROP POLICY IF EXISTS "adm_audit_item_images_company" ON audit_item_images;
CREATE POLICY "adm_audit_item_images_company" ON audit_item_images
  USING (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());

-- auditor: SELECT na propria empresa
DROP POLICY IF EXISTS "auditor_audit_item_images_select" ON audit_item_images;
CREATE POLICY "auditor_audit_item_images_select" ON audit_item_images
  FOR SELECT
  USING (get_my_role() = 'auditor' AND company_id = get_my_company_id());

-- auditor: INSERT na propria empresa (apenas proprias imagens)
DROP POLICY IF EXISTS "auditor_audit_item_images_insert" ON audit_item_images;
CREATE POLICY "auditor_audit_item_images_insert" ON audit_item_images
  FOR INSERT
  WITH CHECK (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
    AND created_by = auth.uid()
  );

-- auditor: DELETE na propria empresa (apenas proprias imagens)
DROP POLICY IF EXISTS "auditor_audit_item_images_delete" ON audit_item_images;
CREATE POLICY "auditor_audit_item_images_delete" ON audit_item_images
  FOR DELETE
  USING (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
    AND created_by = auth.uid()
  );

-- 6. Storage bucket audit-images (bucket privado)
-- Insere apenas se ainda nao existir -- idempotente
INSERT INTO storage.buckets (id, name, public)
VALUES ('audit-images', 'audit-images', false)
ON CONFLICT (id) DO NOTHING;

-- 7. Storage RLS: upload autenticado restrito ao proprio company_id
-- O path segue o padrao: {companyId}/{auditId}/{itemId}/{uuid}.jpg
-- A policy verifica que o primeiro segmento do path corresponde ao company_id do usuario

-- Politica de INSERT (upload) no Storage
DROP POLICY IF EXISTS "authenticated_upload_audit_images" ON storage.objects;
CREATE POLICY "authenticated_upload_audit_images" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'audit-images'
    AND (storage.foldername(name))[1] = get_my_company_id()::text
  );

-- Politica de SELECT (leitura para signed URL) no Storage
DROP POLICY IF EXISTS "authenticated_read_audit_images" ON storage.objects;
CREATE POLICY "authenticated_read_audit_images" ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'audit-images'
    AND (storage.foldername(name))[1] = get_my_company_id()::text
  );

-- Politica de DELETE no Storage
DROP POLICY IF EXISTS "authenticated_delete_audit_images" ON storage.objects;
CREATE POLICY "authenticated_delete_audit_images" ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'audit-images'
    AND (storage.foldername(name))[1] = get_my_company_id()::text
  );

-- 8. Recarregar schema do PostgREST (sempre ultima linha)
NOTIFY pgrst, 'reload schema';
