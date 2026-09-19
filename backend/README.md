# NoFluxo — Backend (Node/TypeScript)

API REST do NoFluxoUNB: **Node 20 + TypeScript + Express**, com Supabase como banco
(`@supabase/supabase-js`) e integração com o serviço de IA (`mcp_agent/`, FastAPI).
Servida em produção via `k8s.backend.Dockerfile`.

## Rodando

```bash
npm install
cp .env.example .env   # e preencha as chaves
npm run dev            # nodemon em src/index.ts
npm run dev:full       # sobe backend + mcp_agent juntos (scripts/dev-full.sh)
npm run build && npm start
```

**Porta:** `3325` com o `.env.example`; sem `PORT` definido o default do código é `3000`.
Outra porta do `.env.example`: `AI_AGENT_PORT=4652`.

## Testes e qualidade

```bash
npm test               # Jest (ts-jest) — suíte em tests-ts/ (~30 arquivos)
npm run test:coverage
npm run type-check     # tsc --noEmit
npm run lint
```

## Onde estão as coisas

- `src/index.ts` — entrada; `src/controllers/` — rotas por domínio
  (`fluxograma_controller.ts`, `PlanejamentoController.ts`, `assistente_controller.ts`,
  `chat_controller.ts`, `cursos/materias/users`).
- `src/services/` — regras de negócio: `plano_formatura.service.ts` (Motor 2),
  `sabia.service.ts` (ponte com o mcp_agent), `services/chat/`, `services/agente/`.
  Specs do Motor 2 e do orquestrador de chat em `docs/` na raiz do repo.
- `docs/` (desta pasta) — dumps do schema Supabase (`database_schema.json`,
  `database_functions.sql`, RLS, triggers), gerados com `npm run export-schema`;
  o baseline de migration gerado vai para `supabase/migrations/` na raiz do repo.

O parse de histórico em PDF **não passa pelo backend**: é client-side no frontend
(`pdfjs-dist`) seguido da RPC `casar_disciplinas` no Supabase. O antigo serviço
Python `parse-pdf/` e a UI manual `testes-web/` foram removidos na reorganização
(fase 3); o histórico está no git.
