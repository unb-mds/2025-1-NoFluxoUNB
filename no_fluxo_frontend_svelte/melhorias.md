# Tarefas de Melhoria e Débitos Técnicos

Lista de tarefas (to-do) com as melhorias sugeridas para o projeto e seus status.

---

## 🔧 Débitos Técnicos e Melhorias

### ✅ Concluído

- [x] **Arquitetura de navegação — 7 abas é demais para o topo** *(Por Antigravity)*
  O próprio código admitia o problema (Navbar.svelte:97-98): com 6-7 links, larguras md/lg davam overlap e forçavam cair no hambúrguer até 1280px, escondendo o menu em telas de notebook comuns (1366×768).
  Havia também sobreposição conceitual entre "Meu Fluxograma", "Plano de Formatura", "Assistente" e "Disciplinas". Resolvido agrupando em um hub de planejamento (dropdown "Planejamento" com Plano + Assistente), deixando no topo: Fluxogramas · Meu Fluxograma · Planejamento · Disciplinas.
  _(Nota: também foram enriquecidas a interface do Fluxograma com dados do usuário e os cards de pré-requisitos.)_

- [x] **Inconsistência visual entre abas**
  Unificado em um único componente `PageBackground.svelte` (`$lib/components/effects/`), substituindo `GraffitiBackground` e `AnimatedBackground`. Usado em todas as páginas que precisam de fundo, incluindo `assistente` (que tinha import morto). `plano-formatura` também tinha esse problema (nenhum fundo), mas essa página só existe na branch do Motor 2 (`feature/motor-planejador-formatura`) — ainda pendente de aplicar lá quando ela for mergeada.

- [x] **Footer morto e duplicação no Navbar**
  - O código inativo do Footer foi limpo do layout.
  - O menu de conta duplicado foi centralizado no componente `<AccountMenu />`.

- [x] **Débito técnico: assistente ainda não migrou para runes**
  O arquivo `assistente/+page.svelte` já foi completamente refatorado para usar Runes. Todo o estado local legado (`let mensagem = ''`, `let historico = []`) foi removido e a página agora consome perfeitamente a `assistenteChatStore` (`.svelte.ts`), padronizando com o resto da aplicação.

### ⏳ Pendente

- [ ] **Auth só client-side → flash de conteúdo**
  Os guards são todos `onMount(() => goto(...))` (ex.: meu-fluxograma:82-86, plano-formatura:13-40). Sem `load`/`hooks.server`, o usuário vê a tela por um instante antes do redirect. Migrar para load functions elimina o flash e melhora SEO/perf.

- [ ] **Riscos já mapeados no CLAUDE.md que continuam abertos**
  Vale priorizar: `helmet` não aplicado, CORS aberto (`callback(null, true)`), e `SERVICE_ROLE_KEY` em todas as ops do Supabase (bypassa RLS mesmo em endpoint público). E zero testes — sendo que `casar_disciplinas` (540 linhas, coração do fluxograma) não tem cobertura.

---

## 🚀 Features Recomendadas (por impacto)

- [ ] **1. Montador de grade horária (schedule builder)** — maior valor, dados já existem
  `turmas` já tem `horario`, `vagas_sobrando`, `ano_periodo`. Deixar o aluno pegar as matérias recomendadas (do Plano/Assistente) e montar uma grade visual com detecção de conflito de horário fecha o loop "o que curso → quando curso". É a evolução natural que conecta Assistente + Plano + turmas.

- [ ] **2. Persistir o chat do assistente**
  Hoje `historico` é in-memory; refresh perde tudo. Salvar conversas (por usuário) é barato e melhora muito a percepção de produto.

- [ ] **3. Alerta de vagas**
  `turmas.vagas_sobrando` já existe. Notificar quando uma matéria da lista do aluno abre vaga é um "hook" de retenção forte em época de matrícula.

- [ ] **4. Comparar currículos/matrizes**
  Já existe `MudancaCursoModal` e o conceito de mudança de curso; uma view de comparação lado a lado (o que aproveita, o que falta) ajudaria quem troca de matriz.

- [x] **5. PWA / offline**
  O código tem tratamento mobile pesadíssimo (safe-area, landscape, focus-mode no fluxograma). É claramente usado no celular. Transformar em PWA instalável com cache do fluxograma dá um salto de UX com pouco esforço.
