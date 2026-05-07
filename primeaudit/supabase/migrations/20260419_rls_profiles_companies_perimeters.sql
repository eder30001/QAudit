-- =============================================================================
-- Migração: RLS policies para profiles, companies, perimeters,
--           audit_types, audit_templates, template_items (SEC-01, SEC-02)
-- Data: 2026-04-18
-- Idempotente: pode ser executado múltiplas vezes sem erro.
-- Referência: Phase 02-security, D-06, D-07, D-08, D-09
-- Depende de: 20260418_fix_active_guard.sql (get_my_role/get_my_company_id com guarda active)
-- =============================================================================


-- ============================================================================
-- 1. profiles
-- ============================================================================

-- Remover todas as policies antigas (incluindo as quebradas de schema.sql)
DROP POLICY IF EXISTS "Admin full access on profiles"  ON profiles;
DROP POLICY IF EXISTS "Users can view own profile"     ON profiles;
DROP POLICY IF EXISTS "superuser_dev_profiles_full"    ON profiles;
DROP POLICY IF EXISTS "adm_profiles_select"            ON profiles;
DROP POLICY IF EXISTS "adm_profiles_update"            ON profiles;
DROP POLICY IF EXISTS "user_select_own"                ON profiles;

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- superuser/dev: acesso total (lê, insere, altera, apaga qualquer perfil)
CREATE POLICY "superuser_dev_profiles_full" ON profiles
  USING      (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- adm: lê usuários da própria empresa
CREATE POLICY "adm_profiles_select" ON profiles FOR SELECT
  USING (get_my_role() = 'adm' AND company_id = get_my_company_id());

-- adm: atualiza usuários da própria empresa, MAS não pode escalar role.
-- O WITH CHECK compara a role proposta com a role atual via subquery —
-- se diferente, bloqueia. (SEC-02, D-08)
CREATE POLICY "adm_profiles_update" ON profiles FOR UPDATE
  USING (
    get_my_role() = 'adm'
    AND company_id = get_my_company_id()
  )
  WITH CHECK (
    get_my_role() = 'adm'
    AND company_id = get_my_company_id()
    AND role = (SELECT p.role FROM profiles p WHERE p.id = profiles.id)
  );

-- qualquer usuário ativo autenticado: lê o próprio perfil
-- (get_my_role() IS NOT NULL garante que inativos também não lêem próprio perfil)
CREATE POLICY "user_select_own" ON profiles FOR SELECT
  USING (id = auth.uid() AND get_my_role() IS NOT NULL);


-- ============================================================================
-- 2. companies
-- ============================================================================

DROP POLICY IF EXISTS "Admin full access on companies" ON companies;
DROP POLICY IF EXISTS "superuser_dev_companies_full"   ON companies;
DROP POLICY IF EXISTS "adm_companies_select"           ON companies;
DROP POLICY IF EXISTS "auditor_companies_select"       ON companies;

ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- superuser/dev: acesso total
CREATE POLICY "superuser_dev_companies_full" ON companies
  USING      (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- adm: lê apenas a própria empresa
CREATE POLICY "adm_companies_select" ON companies FOR SELECT
  USING (get_my_role() = 'adm' AND id = get_my_company_id());

-- auditor: lê apenas a própria empresa
CREATE POLICY "auditor_companies_select" ON companies FOR SELECT
  USING (get_my_role() = 'auditor' AND id = get_my_company_id());


-- ============================================================================
-- 3. perimeters
-- ============================================================================

DROP POLICY IF EXISTS "superuser_dev_perimeters_full" ON perimeters;
DROP POLICY IF EXISTS "adm_perimeters_company"        ON perimeters;
DROP POLICY IF EXISTS "auditor_perimeters_select"     ON perimeters;

ALTER TABLE perimeters ENABLE ROW LEVEL SECURITY;

-- superuser/dev: acesso total
CREATE POLICY "superuser_dev_perimeters_full" ON perimeters
  USING      (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- adm: gerencia perímetros da própria empresa
CREATE POLICY "adm_perimeters_company" ON perimeters
  USING      (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());

-- auditor: apenas lê perímetros da própria empresa
CREATE POLICY "auditor_perimeters_select" ON perimeters FOR SELECT
  USING (get_my_role() = 'auditor' AND company_id = get_my_company_id());


-- ============================================================================
-- 4. audit_types
-- ============================================================================
-- Nota: audit_types pode ter company_id IS NULL (global) — visível para qualquer
-- usuário ativo autenticado, pois app usa .or('company_id.is.null,company_id.eq.$companyId').

DROP POLICY IF EXISTS "superuser_dev_audit_types_full" ON audit_types;
DROP POLICY IF EXISTS "adm_audit_types_company"        ON audit_types;
DROP POLICY IF EXISTS "authenticated_audit_types_select" ON audit_types;

ALTER TABLE audit_types ENABLE ROW LEVEL SECURITY;

-- superuser/dev: acesso total (inclui gerenciar tipos globais)
CREATE POLICY "superuser_dev_audit_types_full" ON audit_types
  USING      (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- adm: gerencia tipos da própria empresa (não pode criar/editar globais)
CREATE POLICY "adm_audit_types_company" ON audit_types
  USING      (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());

-- qualquer usuário ativo autenticado: SELECT de globais OU da própria empresa
CREATE POLICY "authenticated_audit_types_select" ON audit_types FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND (company_id IS NULL OR company_id = get_my_company_id())
  );


-- ============================================================================
-- 5. audit_templates
-- ============================================================================

DROP POLICY IF EXISTS "superuser_dev_audit_templates_full" ON audit_templates;
DROP POLICY IF EXISTS "adm_audit_templates_company"        ON audit_templates;
DROP POLICY IF EXISTS "authenticated_audit_templates_select" ON audit_templates;

ALTER TABLE audit_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "superuser_dev_audit_templates_full" ON audit_templates
  USING      (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

CREATE POLICY "adm_audit_templates_company" ON audit_templates
  USING      (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());

-- qualquer usuário ativo autenticado: SELECT de templates globais OU da própria empresa
CREATE POLICY "authenticated_audit_templates_select" ON audit_templates FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND (company_id IS NULL OR company_id = get_my_company_id())
  );


-- ============================================================================
-- 6. template_items
-- ============================================================================
-- template_items não tem company_id direto — escopo via audit_templates.

DROP POLICY IF EXISTS "superuser_dev_template_items_full" ON template_items;
DROP POLICY IF EXISTS "adm_template_items_company"        ON template_items;
DROP POLICY IF EXISTS "authenticated_template_items_select" ON template_items;

ALTER TABLE template_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "superuser_dev_template_items_full" ON template_items
  USING      (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- adm: gerencia itens de templates da própria empresa
CREATE POLICY "adm_template_items_company" ON template_items
  USING (
    get_my_role() = 'adm'
    AND EXISTS (
      SELECT 1 FROM audit_templates t
      WHERE t.id = template_items.template_id
        AND t.company_id = get_my_company_id()
    )
  )
  WITH CHECK (
    get_my_role() = 'adm'
    AND EXISTS (
      SELECT 1 FROM audit_templates t
      WHERE t.id = template_items.template_id
        AND t.company_id = get_my_company_id()
    )
  );

-- qualquer usuário ativo autenticado: SELECT de itens de templates globais OU da própria empresa
CREATE POLICY "authenticated_template_items_select" ON template_items FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM audit_templates t
      WHERE t.id = template_items.template_id
        AND (t.company_id IS NULL OR t.company_id = get_my_company_id())
    )
  );


-- ============================================================================
-- 7. Recarregar schema cache do PostgREST
-- ============================================================================
NOTIFY pgrst, 'reload schema';
