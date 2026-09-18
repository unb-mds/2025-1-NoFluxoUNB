# Darcy AI (agente Sabiá) — serviço de IA

API **FastAPI** de recomendação de disciplinas da UnB por busca semântica vetorial.
É um dos 3 alvos de deploy do projeto (`k8s.mcp-agent.Dockerfile`).

```
Frontend (Svelte) → Backend (Node/TS) → FastAPI (este serviço) → Gemini + Maritaca + Supabase (pgvector)
```

> **Nota histórica:** o nome da pasta vem da v1, que usava MCP + modelo de embeddings
> local (SentenceTransformer 420MB) chamado via stdin/stdout pelo Node. Essa
> arquitetura foi substituída pela v2 (FastAPI + embeddings Gemini 256D via API);
> os arquivos da v1 (`servidor_mcp_sabia.py`, `agente_sabia.py`) não existem mais.

## Arquivos

| Arquivo | Papel |
|---|---|
| `api_producao.py` | Servidor FastAPI — o coração da pasta. Endpoint `POST /recomendar`. |
| `jobs/databaseScript_gemini.py` | Popula embeddings (Gemini, 256D) na tabela `materias_vetorizadas`. Versão atual. |
| `jobs/databaseScript.py` | Idem com SentenceTransformer local (legado da v1). |
| `tool_call_utils.py` / `test_tool_call_utils.py` | Utilitários de tool-calling + teste (pytest). |
| `start_api.{sh,bat}` / `start_api_production.{sh,bat}` | Subida em dev / produção (uvicorn). |

## Rodando

```bash
cd mcp_agent
pip install -r requirements.txt
./start_api.sh          # dev — http://localhost:8000
```

> **Windows:** use Python 3.11/3.12 — o 3.14 não tem wheels para dependências
> indiretas do `supabase` e exige o Microsoft C++ Build Tools.

`.env` desta pasta (fail-fast: sem as vars, os scripts abortam; a API responde 503
a tudo sem `MCP_AGENT_API_KEY` — fail-closed):

```env
MARITACA_API_KEY=...             # Sabiá-4 / Sabiázinho-4
GOOGLE_API_KEY=...               # Gemini embeddings
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...    # nunca expor no frontend
MCP_AGENT_API_KEY=$(openssl rand -hex 32)  # exigida no header X-API-Key (exceto GET /health)
```

As mesmas chaves + `SABIA_API_URL=http://localhost:8000` vão no `.env` do
`backend` (quem chama este serviço). Para subir backend + agente juntos:
`npm run dev:full` no `backend`.

## Endpoint

```bash
curl -X POST http://localhost:8000/recomendar \
  -H "Content-Type: application/json" -H "X-API-Key: $MCP_AGENT_API_KEY" \
  -d '{"interesse": "inteligência artificial"}'
```

Retorna `{success, disciplinas: [{codigo, nome, nota, justificativa}], resposta_completa}`.

## Como funciona

1. Sabiázinho-4 (Maritaca) expande o interesse em ~4 termos de busca.
2. Gemini gera embeddings 256D dos termos em 1 chamada.
3. Busca vetorial no Supabase (pgvector, threshold 0.55, top 10 por termo, dedup).
4. Sabiá-4 ranqueia (nota 1–10) e justifica cada disciplina.

Detalhes de integração com o backend: `SABIA_INTEGRATION.md` na raiz do repo.
Performance típica: primeira query ~3–5s (cold start das APIs), depois ~2–3s.
