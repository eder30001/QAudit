# Módulo de Checklist – Prompt para Claude Code + Templates Padrão

---

## 🤖 Prompt para o Claude Code

```
Adicione ao app de auditoria existente um novo módulo chamado "Checklist".

## Contexto
O app já possui um módulo de Auditoria funcional. O módulo de Checklist deve seguir 
a mesma arquitetura, padrões de UI, banco de dados e fluxo de navegação já existentes, 
aproveitando ao máximo os componentes e serviços já criados.

## Objetivo
Permitir que usuários realizem checklists industriais e de transportadoras, 
usando templates pré-definidos ou criando os seus próprios.

---

## Estrutura do módulo

### 1. Templates (categorias iniciais obrigatórias)

**Industrial:**
- Inspeção de máquinas e equipamentos
- Verificação de EPI (Equipamento de Proteção Individual)
- PPRA / PCMSO (saúde ocupacional)
- Checklist de segurança de incêndio
- Checklist de manutenção preventiva

**Transportadora:**
- Vistoria de veículo (pré-viagem)
- Checklist de carga e amarração
- Verificação de documentação do motorista
- Inspeção de pneus e freios
- Checklist de carregamento/descarregamento

**Customizado:**
- O usuário pode criar novos tipos de checklist do zero
- Pode clonar um template existente e editá-lo
- Pode adicionar, remover e reordenar perguntas
- Pode definir o tipo de resposta de cada item (Sim/Não, múltipla escolha, texto, 
  número, foto obrigatória, assinatura)

---

### 2. Funcionalidades obrigatórias

#### Gerenciamento de templates
- Listagem de templates por categoria (Industrial / Transportadora / Meus checklists)
- CRUD completo para templates customizados
- Cada template deve ter: nome, categoria, descrição, lista de itens
- Cada item do checklist deve ter: pergunta, tipo de resposta, obrigatoriedade, 
  observação opcional, possibilidade de anexar foto

#### Execução do checklist
- Fluxo idêntico ao da auditoria: seleção do template → preenchimento → conclusão
- Campos de identificação: responsável, local, data/hora, número de identificação
- Suporte a foto por item (câmera ou galeria)
- Campo de observação por item
- Assinatura digital ao final (mesmo componente da auditoria, se já existir)
- Salvamento automático de rascunho

#### Relatório e exportação
- Geração de relatório em PDF no mesmo layout da auditoria
- Exibir: cabeçalho com dados da inspeção, itens com status (OK / NOK / N/A), 
  fotos anexadas, observações, assinatura
- Exportação e compartilhamento via e-mail / WhatsApp

#### Histórico
- Listagem de checklists realizados com filtros: data, tipo, responsável, local
- Visualização do checklist concluído
- Indicadores: % de conformidade, itens não conformes

---

### 3. Banco de dados (adaptar ao banco já existente)

Criar as seguintes entidades (ou adaptar nomenclatura ao padrão do projeto):

- **ChecklistTemplate**: id, nome, categoria, descricao, criado_por, is_padrao, ativo
- **ChecklistItem**: id, template_id, ordem, pergunta, tipo_resposta, obrigatorio, 
  opcoes (JSON para múltipla escolha)
- **ChecklistExecucao**: id, template_id, responsavel_id, local, data_inicio, 
  data_conclusao, status, numero_identificacao
- **ChecklistResposta**: id, execucao_id, item_id, resposta, observacao, foto_url, 
  conforme

---

### 4. Navegação

Adicionar "Checklist" no menu principal (mesmo nível de "Auditoria").
Estrutura de rotas:
- /checklist → tela inicial (categorias + botão novo)
- /checklist/templates → lista de templates
- /checklist/templates/novo → criação de template
- /checklist/templates/:id/editar → edição
- /checklist/executar/:templateId → execução do checklist
- /checklist/historico → listagem de execuções concluídas
- /checklist/:execucaoId → visualização de execução

---

### 5. Padrões a seguir

- Usar os mesmos componentes de UI, tema, fontes e cores do módulo de Auditoria
- Seguir os mesmos padrões de estado (loading, erro, vazio) já existentes
- Reaproveitar componentes de foto, assinatura, campo de observação se já existirem
- Manter consistência nos nomes de variáveis, serviços e arquivos com o restante 
  do projeto
- Adicionar os templates padrão via seed/migration para que já apareçam na 
  primeira execução

---

### 6. Modelos de checklist padrão (incluir no seed)

Os templates padrão estão detalhados abaixo. Incluir todos os itens de cada 
template no banco de dados como registros iniciais com `is_padrao = true`.
```

---

## 📋 Templates Padrão para o Seed

---

### 🏭 Industrial — Inspeção de máquinas e equipamentos

| # | Item | Tipo de resposta | Obrigatório |
|---|------|-----------------|-------------|
| 1 | Máquina possui identificação de risco visível? | Sim/Não | Sim |
| 2 | Proteções e guardas de segurança estão instaladas? | Sim/Não | Sim |
| 3 | Botão de emergência está funcionando? | Sim/Não | Sim |
| 4 | Aterramento elétrico verificado? | Sim/Não | Sim |
| 5 | Última manutenção preventiva realizada em: | Data | Sim |
| 6 | Operador possui treinamento específico para o equipamento? | Sim/Não | Sim |
| 7 | Ruído dentro do limite permitido (≤85dB)? | Sim/Não | Não |
| 8 | Temperatura de operação dentro do limite? | Sim/Não | Não |
| 9 | Registro fotográfico geral do equipamento | Foto | Sim |
| 10 | Observações gerais | Texto | Não |

---

### 🦺 Industrial — Verificação de EPI

| # | Item | Tipo de resposta | Obrigatório |
|---|------|-----------------|-------------|
| 1 | Capacete de segurança presente e em bom estado? | Sim/Não | Sim |
| 2 | Óculos de proteção adequados ao risco? | Sim/Não | Sim |
| 3 | Protetor auricular disponível? | Sim/Não | Sim |
| 4 | Luvas adequadas ao tipo de atividade? | Sim/Não | Sim |
| 5 | Calçado de segurança com CA válido? | Sim/Não | Sim |
| 6 | Número do CA do calçado | Texto | Sim |
| 7 | Cinto de segurança (se trabalho em altura)? | Sim/Não | Não |
| 8 | Máscara de proteção respiratória (se aplicável)? | Sim/Não | Não |
| 9 | Todos os EPIs possuem CA válido? | Sim/Não | Sim |
| 10 | Foto do trabalhador com os EPIs | Foto | Sim |

---

### 🔥 Industrial — Segurança contra incêndio

| # | Item | Tipo de resposta | Obrigatório |
|---|------|-----------------|-------------|
| 1 | Extintores sinalizados e acessíveis? | Sim/Não | Sim |
| 2 | Extintores dentro do prazo de validade? | Sim/Não | Sim |
| 3 | Saídas de emergência desobstruídas? | Sim/Não | Sim |
| 4 | Sinalização de emergência visível e legível? | Sim/Não | Sim |
| 5 | Detectores de fumaça funcionando? | Sim/Não | Sim |
| 6 | Mangueira de incêndio inspecionada? | Sim/Não | Não |
| 7 | Plano de evacuação afixado? | Sim/Não | Sim |
| 8 | Data da última simulação de incêndio | Data | Sim |
| 9 | Quadro elétrico organizado e sem sobrecargas? | Sim/Não | Sim |
| 10 | Foto do local de armazenamento de produtos inflamáveis | Foto | Não |

---

### 🚛 Transportadora — Vistoria de veículo (pré-viagem)

| # | Item | Tipo de resposta | Obrigatório |
|---|------|-----------------|-------------|
| 1 | Pneus (calibragem e desgaste) em boas condições? | Sim/Não | Sim |
| 2 | Freios funcionando corretamente? | Sim/Não | Sim |
| 3 | Faróis, lanternas e sinaleiros funcionando? | Sim/Não | Sim |
| 4 | Nível de óleo verificado? | Sim/Não | Sim |
| 5 | Nível de água do radiador verificado? | Sim/Não | Sim |
| 6 | Extintor de incêndio presente no veículo? | Sim/Não | Sim |
| 7 | Triângulo de sinalização presente? | Sim/Não | Sim |
| 8 | Espelhos retrovisores ajustados? | Sim/Não | Sim |
| 9 | Limpadores de para-brisa funcionando? | Sim/Não | Sim |
| 10 | Foto frontal do veículo | Foto | Sim |
| 11 | Foto traseira do veículo | Foto | Sim |
| 12 | Placa do veículo | Texto | Sim |
| 13 | KM atual do veículo | Número | Sim |
| 14 | Observações do motorista | Texto | Não |

---

### 📄 Transportadora — Documentação do motorista

| # | Item | Tipo de resposta | Obrigatório |
|---|------|-----------------|-------------|
| 1 | CNH válida e categoria compatível com o veículo? | Sim/Não | Sim |
| 2 | Vencimento da CNH | Data | Sim |
| 3 | MOPP válido (transporte de produtos perigosos, se aplicável)? | Sim/Não | Não |
| 4 | Exame toxicológico dentro do prazo? | Sim/Não | Sim |
| 5 | CRLV do veículo em dia? | Sim/Não | Sim |
| 6 | Seguro obrigatório (DPVAT/DPEM) vigente? | Sim/Não | Sim |
| 7 | Tacógrafo calibrado e com disco inserido (se aplicável)? | Sim/Não | Não |
| 8 | Jornada de trabalho dentro do limite legal? | Sim/Não | Sim |
| 9 | Foto da CNH | Foto | Sim |
| 10 | Foto do CRLV | Foto | Sim |

---

### 📦 Transportadora — Checklist de carga e amarração

| # | Item | Tipo de resposta | Obrigatório |
|---|------|-----------------|-------------|
| 1 | Tipo de carga | Múltipla escolha (Geral / Frigorificada / Perigosa / Granel / Viva) | Sim |
| 2 | Peso da carga (kg) | Número | Sim |
| 3 | Carga distribuída de forma uniforme? | Sim/Não | Sim |
| 4 | Amarrações/cintas em boas condições? | Sim/Não | Sim |
| 5 | Quantidade de cintas utilizada | Número | Sim |
| 6 | Carga ultrapassa as dimensões permitidas? | Sim/Não | Sim |
| 7 | Documentação da carga (NF) conferida? | Sim/Não | Sim |
| 8 | Carga está coberta/protegida adequadamente? | Sim/Não | Sim |
| 9 | Foto da carga carregada | Foto | Sim |
| 10 | Foto das amarrações | Foto | Sim |
| 11 | Observações sobre a carga | Texto | Não |

---

## 📌 Legenda de tipos de resposta

| Tipo | Descrição |
|------|-----------|
| `Sim/Não` | Botão de escolha binária (conforme / não conforme) |
| `Texto` | Campo de texto livre |
| `Número` | Campo numérico |
| `Data` | Seletor de data |
| `Foto` | Captura via câmera ou galeria |
| `Múltipla escolha` | Lista de opções pré-definidas (uma ou mais seleções) |
| `Assinatura` | Campo de assinatura digital |
