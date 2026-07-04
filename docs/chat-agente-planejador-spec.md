# Chat de Agente do Planejador de Formatura — Design

Data: 2026-07-04
Status: aprovado

## Objetivo

Painel de chat com agente IA na página `/plano-formatura` que ajuda o aluno a
entender e iterar no plano de formatura (Motor 2) por conversa: responder
perguntas sobre o plano, simular cenários e executar ações (ajustar carga,
adiar/priorizar matérias) com o plano se reorganizando na tela em tempo real.

## Decisões de escopo (aprovadas)

- **Poder do agente**: explica E age no plano (tool calling).
- **LLM**: Maritaca sabiá-3 direto do backend Node (API OpenAI-compatible,
  function calling). `MARITACA_API_KEY` já configurada. Sem passar pelo
  FastAPI Python.
- **UI**: painel lateral colapsável dentro de `/plano-formatura`.
- **Tools v1**: kit essencial + mover matérias (exige suporte a restrições no
  greedy do Motor 2).
- **Estado**: stateless — frontend envia histórico + preferências + restrições
  + planoInput a cada mensagem. Sem tabela nova, sem sessão no servidor.
  Conversa dura enquanto a página está aberta.

## Arquitetura

```
Aluno ⇄ PlannerChatPanel.svelte
          ⇄ POST /planejamento/chat (stateless, JWT + User-ID)
              → loop: Maritaca ⇄ tools (gerarPlano + consultas)
              ← { reply, plano?, restricoes? }
```

## Motor 2 — suporte a restrições (única mudança no core)

`PreferenciasPlano` ganha campo opcional:

```ts
interface RestricoesPlano {
  adiar: string[];      // códigos que NÃO podem entrar no próximo semestre (recomendado)
  priorizar: string[];  // códigos forçados no semestre mais cedo possível
}
```

Semântica no greedy (distribuição por semestres):

- **adiar**: matéria removida das candidatas do semestre 1 (o "recomendado");
  volta ao pool normal a partir do semestre 2. O impacto ("+1 semestre")
  emerge naturalmente do recálculo.
- **priorizar**: matéria recebe score infinito na ordenação — entra assim que
  os pré-requisitos permitirem. Se pré-requisito insatisfeito, a tool devolve
  erro explicativo ao LLM em vez de forçar.
- Matérias **críticas podem ser adiadas** (decisão do aluno); o agente avisa o
  custo antes de aplicar.

## Agent loop + tools

Novo serviço `no_fluxo_backend/src/services/planejador_agente.service.ts`:

- Chama `https://chat.maritaca.ai/api/chat/completions` com `tools`;
  executa tool calls localmente; repete até resposta final.
- Guard-rail: máx. 5 iterações do loop.
- System prompt inclui: resumo do plano atual, preferências, restrições
  ativas, regras da UnB relevantes (`docs/unb-domain.md`).

| Tool | Faz | Muda o plano? |
|---|---|---|
| `consultar_plano` | Detalhes de matéria (score, desbloqueios, semestre alocado, motivo) ou resumo geral | Não |
| `simular_cenario` | Plano alternativo (créditos e/ou restrições hipotéticas); devolve diff: Δ semestres, formatura | Não |
| `ajustar_carga` | Muda créditos/objetivo e regenera | Sim |
| `mover_materia` | Adiciona/remove restrição adiar/priorizar e regenera | Sim |

## Endpoint e contrato

`POST /planejamento/chat` no `PlanejamentoController` (mesma auth do
`gerar-plano`):

```ts
// Request
{
  messages: { role: 'user' | 'assistant', content: string }[],
  planoInput: <mesmo body do gerar-plano>,
  restricoes: RestricoesPlano
}
// Response
{
  reply: string,
  plano?: PlanoFormaturav2,      // presente se alguma tool alterou o plano
  restricoes?: RestricoesPlano   // estado atualizado
}
```

Sem streaming na v1 (tool loop + JSON único). SSE na resposta final é
evolução futura.

## Frontend

- **`PlannerChatPanel.svelte`** (novo, `components/plano-formatura/`):
  painel direito colapsável; reusa padrão visual do chat de `/assistente`
  (bolhas, loading, quick suggestions: "Simular 16 créditos", "Qual matéria
  me atrasa mais?").
- **Store**: estende `plano-formatura.store.svelte.ts` com `chatMessages`,
  `restricoes`, `sendMessage()`. Resposta com `plano` atualiza o store →
  colunas re-renderizam.
- **Chips de restrições** acima do plano ("Adiada: FGA0108 ✕") — removível
  por clique, que remove a restrição e regenera.

## Erros e limites

- Maritaca indisponível/sem chave → painel mostra aviso e esconde input
  (padrão `isAvailable()` do SabiaService).
- Argumento de tool inválido (código inexistente) → tool devolve erro
  descritivo ao LLM, que se corrige ou pergunta ao aluno.
- Loop atinge 5 iterações → responde com o que tem + aviso.
- Histórico enviado limitado às últimas 20 mensagens.

## Testes

- **Motor 2 + restrições** (`tests-ts/`, funções puras): adiar tira do
  semestre 1; priorizar antecipa respeitando pré-requisitos; pré-requisito
  insatisfeito não é forçado; impacto em semestres recalculado.
- **Executores de tools**: unitários com plano mock, sem chamar Maritaca.
- **Agent loop**: cliente Maritaca mockado (sequência tool_call → final).
- Frontend: verificação manual via dev server (padrão atual do projeto).

## Fora de escopo (v1)

- Persistência da conversa (tabela/RLS).
- Streaming SSE da resposta.
- Previsão de turmas/horários (Motor 1).
- Onboarding conduzido pelo chat.
