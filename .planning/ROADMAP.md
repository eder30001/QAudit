# Roadmap: PrimeAudit

## Milestones

- ✅ **v1.0 Foundation** — Phases 1–5 (shipped 2026-04-17)
- ✅ **v1.1 Features & UX** — Phases 6–12 (shipped 2026-05-02)
- 🔄 **v1.2 Checklist** — Phases 13–17 (in progress)

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

### v1.2 Checklist (Phases 13–17)

- [ ] **Phase 13: DB Foundation + Template Management** — Banco de dados, migrations com seeds e telas de gerenciamento de templates
- [ ] **Phase 14: Checklist Execution Engine** — Fluxo completo de execução com todos os tipos de resposta e auto-save de rascunho
- [ ] **Phase 15: Photos per Item** — Anexar fotos por item durante execução (câmera ou galeria)
- [ ] **Phase 16: Digital Signature** — Captura de assinatura digital como sign-off ao finalizar checklist
- [ ] **Phase 17: History + Conformity Indicators** — Listagem de checklists realizados com filtros e indicadores de conformidade

---

## Phase Details

### Phase 13: DB Foundation + Template Management
**Goal**: Auditores podem navegar, criar, editar e clonar templates de checklist por categoria
**Depends on**: Nothing (first phase of v1.2)
**Requirements**: TMPLCK-01, TMPLCK-02, TMPLCK-03, TMPLCK-04, TMPLCK-05, TMPLCK-06, NAV-01
**Success Criteria** (what must be TRUE):
  1. Usuário vê entrada "Checklist" no drawer e acessa a tela de templates sem erro
  2. Templates listados nas abas Industrial, Transportadora e Meus checklists; 10 seeds seed visíveis nas duas primeiras abas para qualquer perfil (incluindo auditor)
  3. Usuário cria template customizado com nome, categoria, descrição e itens; template aparece na aba "Meus checklists"
  4. Usuário clona qualquer template seed ou próprio; clone aparece em "Meus checklists" com todos os itens intactos (sem seções órfãs)
  5. Usuário edita e exclui apenas templates próprios; seeds não têm opção de exclusão
**Plans**: 4 plans
**UI hint**: yes

Plans:
- [x] 13-01-PLAN.md — DB migration: tables, RLS policies, 10 seed templates (commit 53a1fbf; aguarda supabase db push)
- [x] 13-02-PLAN.md — Dart model + service layer + unit tests (commits f2877b0, 0ae316c)
- [x] 13-03-PLAN.md — ChecklistTemplatesScreen (3-tab list, cards, clone, delete) + drawer entry (commits f222262, 21535d8)
- [x] 13-04-PLAN.md — ChecklistTemplateFormScreen (create/edit form with items list) (commit 2d6d899)

### Phase 14: Checklist Execution Engine
**Goal**: Auditores preenchem um checklist completo com todos os tipos de resposta e o rascunho é salvo automaticamente sem bloqueio
**Depends on**: Phase 13
**Requirements**: EXEC-01, EXEC-02, EXEC-03, EXEC-05
**Success Criteria** (what must be TRUE):
  1. Usuário inicia execução preenchendo responsável, local, data e número; execução é criada com status rascunho
  2. Usuário responde itens Sim/Não, texto, número, data e múltipla escolha; cada resposta persiste sem intervenção manual
  3. Usuário adiciona observação opcional por item; observação é salva junto com a resposta
  4. Com WiFi desligado, o preenchimento continua sem modal de erro; ao reconectar, as respostas pendentes são enviadas
  5. Usuário finaliza checklist; conformidade calculada e status muda para concluído
**Plans**: TBD

### Phase 15: Photos per Item
**Goal**: Auditores anexam fotos por item durante execução sem risco de perder respostas já salvas
**Depends on**: Phase 14
**Requirements**: EXEC-04
**Success Criteria** (what must be TRUE):
  1. Usuário abre opção de foto por item e seleciona câmera ou galeria; imagem aparece como miniatura inline
  2. Múltiplas fotos por item são suportadas; miniaturas visíveis durante o preenchimento
  3. Falha no upload de foto exibe mensagem de erro mas não interrompe o salvamento de respostas nem a finalização do checklist
**Plans**: TBD
**UI hint**: yes

### Phase 16: Digital Signature
**Goal**: Auditores assinam digitalmente ao finalizar checklist e a assinatura fica vinculada à execução
**Depends on**: Phase 14
**Requirements**: EXEC-06
**Success Criteria** (what must be TRUE):
  1. Ao finalizar, usuário vê tela/modal de assinatura digital com canvas de desenho
  2. Usuário assina, confirma e o checklist é concluído; assinatura salva como PNG no Supabase Storage
  3. Campo signature_path preenchido na execução; usuário pode visualizar a assinatura ao rever o checklist
**Plans**: TBD
**UI hint**: yes

### Phase 17: History + Conformity Indicators
**Goal**: Auditores visualizam todos os checklists realizados com filtros e indicadores de conformidade
**Depends on**: Phase 13, Phase 14
**Requirements**: HIST-01, HIST-02, HIST-03
**Success Criteria** (what must be TRUE):
  1. Tela de histórico lista checklists realizados com filtros funcionais por data, tipo, responsável e local
  2. Cada item na listagem exibe indicador de conformidade (% e total de itens NOK)
  3. Usuário abre checklist concluído em modo leitura e vê todas as respostas, observações e fotos
**Plans**: TBD
**UI hint**: yes

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
| 14. Checklist Execution Engine | v1.2 | 0/? | Not started | — |
| 15. Photos per Item | v1.2 | 0/? | Not started | — |
| 16. Digital Signature | v1.2 | 0/? | Not started | — |
| 17. History + Conformity Indicators | v1.2 | 0/? | Not started | — |

---

## Backlog

### Phase 999.1: Responsável externo por email nas ações corretivas (BACKLOG)

**Goal:** No campo de responsável das ações corretivas, adicionar opção "Convidar por email" para casos em que o responsável ainda não está cadastrado no sistema. A ação fica vinculada ao e-mail até o cadastro ser concluído.
**Requirements:** TBD
**Context:** Hoje o dropdown só lista usuários cadastrados em `profiles`. Em cenários onde o responsável é externo ou ainda não tem conta, o auditor fica bloqueado sem poder atribuir a ação. Fluxo sugerido: dropdown normal + opção de digitar e-mail manualmente; o sistema envia convite e vincula a ação ao perfil quando criado.
**Plans:** 0 plans

Plans:
- [ ] TBD (promover com /gsd-review-backlog quando pronto)
