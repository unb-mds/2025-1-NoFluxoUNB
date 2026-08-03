# Docker — Desenvolvimento Local

Setup para rodar o projeto inteiro (backend, frontend, mcp_agent) localmente via Docker, com hot-reload, sem precisar instalar Node ou Python na máquina.

Para o build de produção (Kubernetes), veja `k8s.backend.Dockerfile`, `k8s.frontend-svelte.Dockerfile` e `k8s.mcp-agent.Dockerfile` — esse README é só sobre o setup de dev local.

`docker-compose.yml`, `dev.backend.Dockerfile`, `dev.frontend-svelte.Dockerfile` e `dev.mcp-agent.Dockerfile` são conveniência individual e **não são versionados** (estão no `.gitignore`) — cada dev que quiser usar Docker localmente recria esses arquivos na própria cópia do repo.

## Pré-requisitos

- Cada subprojeto precisa do seu `.env` já preenchido:
  - `no_fluxo_backend/.env` (copie de `no_fluxo_backend/.env.example`)
  - `no_fluxo_frontend_svelte/.env` (copie de `no_fluxo_frontend_svelte/.env.example`)
  - `mcp_agent/.env`
- O banco (Supabase) é em nuvem — não tem container de banco aqui.

## Subir tudo

A partir da raiz do repositório:

```bash
docker-compose up --build
```

- Backend (Express): `http://localhost:3000` (porta vem de `PORT` em `no_fluxo_backend/.env`; se você mudar esse valor, ajuste também `ports:` em `docker-compose.yml`)
- Frontend (SvelteKit): `http://localhost:5173`
- MCP Agent / Darcy AI (FastAPI): `http://localhost:8000`

Editar código em `no_fluxo_backend/src/`, `no_fluxo_frontend_svelte/src/` ou `mcp_agent/` reflete nos containers automaticamente (nodemon, Vite HMR e uvicorn `--reload`, respectivamente) — não precisa rebuildar.

## Parar

```bash
docker-compose down
```

Os volumes nomeados (`backend_node_modules`, `frontend_node_modules`) persistem entre execuções, então o próximo `up --build` não reinstala tudo do zero a menos que o `package.json`/lockfile tenha mudado.

## Arquivos

- `dev.backend.Dockerfile`, `dev.frontend-svelte.Dockerfile`, `dev.mcp-agent.Dockerfile` — imagens de dev, só instalam dependências (código vem por bind mount).
- `docker-compose.yml` — orquestra os 3 serviços.

## Notas

- O frontend só usa `PUBLIC_API_URL` (via `$env/static/public`) para chamar o backend — como as chamadas partem do navegador (fora do container) e a porta do backend é publicada no host, `http://localhost:3000` do `.env` já funciona sem override nenhum no compose.
- Se aparecer erro de módulo nativo faltando (ex. `node-gyp`) depois de mudar dependências, rode `docker-compose up --build` (força reinstalar) em vez de só `up`.
- Primeira requisição ao frontend pode demorar ~10s (Vite otimizando dependências a frio); as próximas são rápidas.
