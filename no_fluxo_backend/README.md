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
Outras portas do `.env.example`: `AI_AGENT_PORT=4652`, `PDF_PARSER_PORT=3001`.

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
  `database_functions.sql`, RLS, triggers), gerados com `npm run export-schema`.
- `parse-pdf/` e `testes-web/` — legados em processo de aposentadoria; o parse de
  histórico vivo é client-side no frontend.

## Tesseract OCR (setup automático)

O parse de PDF com OCR usa Tesseract, baixado e configurado automaticamente no
`npm run build` (detecta o SO, baixa o binário e os dados de português).

- Windows: requer 7-Zip; Linux: gcc/make; macOS: nada extra.
- Problemas? Apague a pasta `tesseract/` e rode `npm run setup-tesseract`, ou instale
  manualmente (`brew install tesseract` / `apt-get install tesseract-ocr` /
  [UB-Mannheim](https://github.com/UB-Mannheim/tesseract/wiki) no Windows) e ajuste o
  caminho em `parse-pdf/pdf_parser_final.py`.
