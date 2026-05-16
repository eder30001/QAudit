# Roadmap: QAudit

## Milestones

- ✅ **v1.0 Foundation** — Phases 1–5 (shipped 2026-04-17)
- ✅ **v1.1 Features & UX** — Phases 6–12 (shipped 2026-05-02)
- ✅ **v1.2 Checklist** — Phases 13–15 (shipped 2026-05-13)
- 🔄 **v1.3 Onboarding, Billing & Notificações** — Phases 18–23 (active)

---

## Phases

<details>
<summary>✅ v1.0 Foundation (Phases 1–5) — SHIPPED 2026-04-17</summary>

- [x] Phase 1: Data Integrity — completed 2026-04-17
- [x] Phase 2: Security — completed
- [x] Phase 3: Test Coverage — completed
- [x] Phase 4: Performance — completed
- [~] Phase 5: Server Config — Deferred to v2

</details>

<details>
<summary>✅ v1.1 Features & UX (Phases 6–12) — SHIPPED 2026-05-02</summary>

- [~] Phase 6: Templates — Cancelled 2026-05-02
- [x] Phase 7: Dashboard — completed 2026-04-25
- [x] Phase 8: Corrective Actions — completed 2026-04-27
- [x] Phase 9: Images — completed 2026-04-29
- [x] Phase 10: Reports (Calendar Dashboard) — completed 2026-05-02
- [ ] Phase 11: Notifications — Deferred to future milestone
- [~] Phase 12: Navigation Refactor — Cancelled 2026-05-02

Archive: [.planning/milestones/v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md)

</details>

<details>
<summary>✅ v1.2 Checklist (Phases 13–15) — SHIPPED 2026-05-13</summary>

- [x] Phase 13: DB Foundation + Template Management — completed 2026-05-04
- [x] Phase 14: Checklist Execution Engine — completed 2026-05-06
- [x] Phase 15: Photos per Item — completed 2026-05-07
- [~] Phase 16: Digital Signature — Cancelled 2026-05-09 → deferred to v1.4+
- [~] Phase 17: History + Conformity Indicators — Cancelled 2026-05-09 → deferred to v1.4+

Archive: [.planning/milestones/v1.2-ROADMAP.md](milestones/v1.2-ROADMAP.md)

</details>

### v1.3 Onboarding, Billing & Notificações (Phases 18–23)

- [ ] **Phase 18: Firebase Infrastructure** - Configurar FCM no Android e criar tabela device_tokens no Supabase
- [ ] **Phase 19: Token Registration** - App solicita permissão e registra device token no backend ao autenticar
- [ ] **Phase 20: Backend Triggers + Push Dispatch** - Edge Functions disparam pushes FCM nos eventos de ação e auditoria
- [ ] **Phase 21: Company Self-Registration** - Owner cria empresa no ato do cadastro quando CNPJ não existe na base
- [ ] **Phase 22: Asaas Billing Integration** - Trial 30 dias → cobrança automática Asaas → controle de licença no app
- [ ] **Phase 23: Invite Users by Email** - Admin convida usuários por email via Edge Function — conta criada já vinculada à empresa

---

## Phase Details

### Phase 18: Firebase Infrastructure
**Goal**: O projeto Android está integrado ao Firebase e o banco Supabase tem a estrutura necessária para armazenar device tokens
**Depends on**: Nothing (first phase of milestone)
**Requirements**: INFRA-03, INFRA-01
**Success Criteria** (what must be TRUE):
  1. O app Android inicia sem erros após adição do google-services.json e do plugin firebase_messaging
  2. A tabela `device_tokens` existe no banco Supabase com colunas `user_id`, `token`, `updated_at` e RLS que permite o usuário autenticado ler/escrever apenas seu próprio registro
  3. Um teste manual de envio de mensagem via console Firebase (Test Message) alcança um dispositivo Android com o app instalado
**Plans**: TBD

### Phase 19: Token Registration
**Goal**: O app registra e mantém atualizado o device token FCM do auditor no Supabase a cada sessão autenticada
**Depends on**: Phase 18
**Requirements**: NOTIF-04
**Success Criteria** (what must be TRUE):
  1. Na primeira execução após login, o app exibe diálogo de permissão de notificação ao auditor
  2. Após conceder permissão, um registro é inserido ou atualizado em `device_tokens` para o `user_id` da sessão ativa
  3. Se o token FCM for renovado pelo Firebase, o app atualiza o registro em `device_tokens` automaticamente sem interação do usuário
  4. Sem permissão de notificação, o fluxo de login continua normalmente sem erro (falha silenciosa)
**Plans**: TBD

### Phase 20: Backend Triggers + Push Dispatch
**Goal**: Auditores recebem push notifications descritivas no dispositivo Android quando ações corretivas são atribuídas/atualizadas e quando auditorias são criadas com eles como responsável
**Depends on**: Phase 19
**Requirements**: NOTIF-01, NOTIF-02, NOTIF-03, NOTIF-05, INFRA-02
**Success Criteria** (what must be TRUE):
  1. Quando uma ação corretiva é atribuída a um auditor, ele recebe push no dispositivo com título e corpo descritivos (ex: "Ação #42 atribuída a você")
  2. Quando o status de uma ação atribuída ao auditor ou criada por ele é alterado, ele recebe push descrevendo o novo estado (ex: "Ação #42 — status alterado para Em Análise")
  3. Quando uma auditoria é criada com o auditor como responsável, ele recebe push com o nome da auditoria (ex: "Nova auditoria: Inspeção Linha 3 — você é o responsável")
  4. Notificações chegam mesmo com o app em background ou fechado no Android
  5. O push não é disparado para o próprio usuário que executou a ação (sem auto-notificação)
**Plans**: TBD

### Phase 21: Company Self-Registration
**Goal**: Owner cria empresa no ato do cadastro quando o CNPJ informado não existe na base — sem depender de intervenção do superuser
**Depends on**: Nothing (standalone)
**Requirements**: ONBOARD-01
**Success Criteria** (what must be TRUE):
  1. Na tela de cadastro, se o CNPJ digitado não encontrar empresa existente, aparece opção "Criar minha empresa" com campo Nome da empresa
  2. Ao confirmar, a empresa é criada no banco com `status = 'trial'` e `trial_expires_at = now() + interval '30 days'`
  3. O usuário é criado com role `adm` e vinculado à empresa recém-criada automaticamente
  4. O fluxo de cadastro de usuário que JÁ encontra empresa pelo CNPJ continua funcionando sem alteração
  5. Migration idempotente adiciona colunas `status`, `trial_expires_at` e `license_expires_at` à tabela `companies`
**Plans**: 3 plans

Plans:
- [ ] 21-01-PLAN.md — DB migration: colunas de billing + RPC SECURITY DEFINER + trigger role clamping
- [ ] 21-02-PLAN.md — Model + services: Company fields, CompanyService.createForRegistration, AuthService role param
- [ ] 21-03-PLAN.md — RegisterScreen UI: branch "Criar minha empresa" quando CNPJ não encontrado

### Phase 22: Asaas Billing Integration
**Goal**: Ao fim do trial de 30 dias, a empresa recebe cobrança automática via Asaas e o acesso ao app é suspenso se o pagamento não for realizado
**Depends on**: Phase 21
**Requirements**: BILLING-01, BILLING-02, BILLING-03
**Success Criteria** (what must be TRUE):
  1. Supabase Edge Function `create-asaas-customer` cria cliente no Asaas com CNPJ + email da empresa e retorna link de pagamento (PIX, boleto ou cartão)
  2. pg_cron job diário identifica empresas com `trial_expires_at < now()` e `status = 'trial'` → envia email com link de pagamento e atualiza `status = 'payment_pending'`
  3. Webhook Supabase recebe confirmação de pagamento do Asaas → atualiza `companies.status = 'active'` e `license_expires_at = now() + interval '30 days'`
  4. pg_cron job diário identifica empresas com `license_expires_at < now()` e `status = 'active'` → atualiza `status = 'suspended'` e envia email de aviso
  5. No login do app, se `company.status = 'suspended'` ou `'payment_pending'`, exibe tela de "Licença expirada" com botão que abre link de pagamento Asaas via url_launcher — dashboard não é acessível
  6. Superuser/dev não são afetados pelo controle de licença
**Plans**: TBD

### Phase 23: Invite Users by Email
**Goal**: Admin convida novos membros da equipe por email — conta criada já vinculada à empresa, sem o convidado precisar digitar CNPJ
**Depends on**: Phase 21
**Requirements**: ONBOARD-02
**Success Criteria** (what must be TRUE):
  1. Na UsersTab, existe botão/FAB "Convidar usuário" visível para role `adm` e `superuser`
  2. Um bottom sheet permite digitar email e escolher role (`adm` ou `auditor`)
  3. Supabase Edge Function `invite-user` chama `supabase.auth.admin.inviteUserByEmail` com metadados `{company_id, role}` no user_metadata
  4. O convidado recebe email do Supabase com link de definição de senha — ao clicar, seu perfil é inserido na tabela `profiles` já com `company_id` e `role` corretos via trigger de banco
  5. Após aceitar o convite, o usuário aparece normalmente na lista de usuários com role e empresa vinculados
**Plans**: TBD

---

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Data Integrity | v1.0 | 3/3 | Complete | 2026-04-17 |
| 2. Security | v1.0 | 4/4 | Complete | — |
| 3. Test Coverage | v1.0 | 4/4 | Complete | — |
| 4. Performance | v1.0 | 1/1 | Complete | — |
| 5. Server Config | v1.0 | 0/? | Deferred to v2 | — |
| 6. Templates | v1.1 | 0/2 | Cancelled | 2026-05-02 |
| 7. Dashboard | v1.1 | 2/2 | Complete | 2026-04-25 |
| 8. Corrective Actions | v1.1 | 4/4 | Complete | 2026-04-27 |
| 9. Images | v1.1 | 3/3 | Complete | 2026-04-29 |
| 10. Reports (Calendar) | v1.1 | 3/3 | Complete | 2026-05-02 |
| 11. Notifications | v1.1 | 0/? | Deferred | — |
| 12. Navigation Refactor | v1.1 | 0/? | Cancelled | 2026-05-02 |
| 13. DB Foundation + Template Management | v1.2 | 4/4 | Complete | 2026-05-04 |
| 14. Checklist Execution Engine | v1.2 | 5/5 | Complete | 2026-05-06 |
| 15. Photos per Item | v1.2 | 3/3 | Complete | 2026-05-07 |
| 16. Digital Signature | v1.2 | 0/? | Cancelled → v1.4+ | 2026-05-09 |
| 17. History + Conformity | v1.2 | 0/? | Cancelled → v1.4+ | 2026-05-09 |
| 18. Firebase Infrastructure | v1.3 | 0/? | Not started | — |
| 19. Token Registration | v1.3 | 0/? | Not started | — |
| 20. Backend Triggers + Push Dispatch | v1.3 | 0/? | Not started | — |
| 21. Company Self-Registration | v1.3 | 0/3 | In progress | — |
| 22. Asaas Billing Integration | v1.3 | 0/? | Not started | — |
| 23. Invite Users by Email | v1.3 | 0/? | Not started | — |

---

## Backlog

### Phase 999.1: Responsável externo por email nas ações corretivas (BACKLOG)

**Goal:** No campo de responsável das ações corretivas, adicionar opção "Convidar por email" para casos em que o responsável ainda não está cadastrado no sistema.
**Plans:** 0 plans

Plans:
- [ ] TBD (promover com /gsd-review-backlog quando pronto)

### Phase 999.2: Modo offline para auditorias e checklists (BACKLOG)

**Goal:** Auditores conseguem executar auditorias e checklists sem sinal de rede com sync automático ao reconectar.
**Context:** Explorado em v1.2 com SharedPreferences — revertido. Requer sqflite/Hive + refactor de estado (Riverpod).
**Plans:** 0 plans

Plans:
- [ ] TBD (promover com /gsd-review-backlog quando pronto)
