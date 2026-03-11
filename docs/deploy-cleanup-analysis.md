# Analise de Arquivos de Deploy - O que manter e o que remover

## Contexto

O deploy atual do projeto usa o sistema em `scripts/deploy/` que faz build local de imagens Docker, push para o registry privado, e deploy via API no cluster Kubernetes em `kubernetes.crianex.com`. Os Dockerfiles ativos para producao sao os prefixados com `k8s.*`.

Este documento analisa todos os arquivos relacionados a deploy no repositorio, separando o que esta em uso do que e legado.

---

## SISTEMA ATIVO (manter)

### scripts/deploy/ - Scripts de deploy para Kubernetes

| Arquivo | Descricao |
|---------|-----------|
| `scripts/deploy/deploy_local.py` | Script principal de deploy. Faz docker build, push, e deploy via API |
| `scripts/deploy/deploy_config.py` | Configuracao dos apps (backend e frontend) com portas, dominios, env vars |
| `scripts/deploy/requirements.txt` | Dependencias Python do script de deploy |
| `scripts/deploy/.deploy/` | Cache de build IDs (gerado automaticamente) |

### Dockerfiles de producao (Kubernetes)

| Arquivo | Descricao |
|---------|-----------|
| `k8s.backend.Dockerfile` | Dockerfile de producao do backend. Multi-stage, Node 20 Alpine, roda como non-root |
| `k8s.frontend-svelte.Dockerfile` | Dockerfile de producao do frontend SvelteKit. Multi-stage, pnpm, adapter-node |

### GitHub Actions (CI/CD)

| Arquivo | Descricao |
|---------|-----------|
| `.github/workflows/ci.yml` | Deploy de documentacao MkDocs no GitHub Pages |
| `.github/workflows/pipelineCI.yml` | Pipeline de coleta de dados (scraper mensal) |
| `.github/workflows/python-tests.yml` | Testes Python |
| `.github/workflows/typescript-tests.yml` | Testes TypeScript |
| `.github/workflows/all-tests.yml` | Suite completa de testes |
| `.github/workflows/security-and-quality.yml` | Checks de qualidade e seguranca |
| `.github/workflows/actions.yml` | Automacao de scraper de curriculos |

### Outros ativos

| Arquivo | Descricao |
|---------|-----------|
| `.dockerignore` | Controla o que entra no contexto de build Docker |
| `no_fluxo_backend/.dockerignore` | Dockerignore especifico do backend |
| `run_all_tests.sh` | Script para rodar todos os testes localmente |

---

## LEGADO - NAO USADO (pode remover)

### Docker Compose + Nginx (deploy antigo em VPS com `simplifica-pbl.space`)

Estes arquivos eram usados para rodar o backend direto em uma VPS com docker-compose e nginx como reverse proxy com SSL. Agora o deploy e feito no Kubernetes, onde o ingress controller cuida do SSL e roteamento.

| Arquivo | Descricao | Por que e legado |
|---------|-----------|------------------|
| `Dockerfile` | Dockerfile monolitico do backend (Node 18 + Python + tesseract + poppler) | Substituido por `k8s.backend.Dockerfile` que e multi-stage e muito mais leve |
| `docker-compose.yml` | Orquestra backend + nginx, monta certificados SSL de `/etc/letsencrypt/live/simplifica-pbl.space/` | Deploy agora e no Kubernetes, nao em VPS com compose |
| `docker-entrypoint.sh` | Script de inicializacao do container antigo. Configura git, permissoes, etc | Nao usado pelo Dockerfile k8s (que roda `node dist/index.js` direto) |
| `nginx.conf` | Reverse proxy com SSL para dominio `simplifica-pbl.space` | Kubernetes ingress faz esse papel agora. Dominio atual e `crianex.com` |
| `view-logs.sh` | Script para ver logs via docker-compose | Nao se aplica ao deploy em Kubernetes |

### Scripts auxiliares antigos

| Arquivo | Descricao | Por que e legado |
|---------|-----------|------------------|
| `scripts/run_docker_and_follow.py` | Gerencia containers Docker locais (stop, build, run, follow logs) usando docker-compose | Substituido por `scripts/deploy/deploy_local.py` |
| `scripts/stop_docker.py` | Para containers docker-compose | Substituido pelo deploy em Kubernetes |

### kubernetes_docs/ - Documentacao/templates de referencia

Esta pasta contem documentacao e templates genericos do cluster Kubernetes (nao sao especificos do NoFluxo). Sao materiais de referencia que vieram junto com o setup do cluster.

| Pasta/Arquivo | Descricao | Acao sugerida |
|---------------|-----------|---------------|
| `kubernetes_docs/README.md` | Overview do cluster K8s | Pode remover - e doc do cluster, nao do projeto |
| `kubernetes_docs/REGISTRY_AUTH.md` | Guia de autenticacao no registry | Pode remover |
| `kubernetes_docs/BUILD_ID_REUSE_PYTHON.md` | Guia de otimizacao de builds | Pode remover |
| `kubernetes_docs/templates/` | Dockerfiles e workflows genericos | Pode remover |
| `kubernetes_docs/deploy_client/` | Codigo do client de deploy (referencia) | Pode remover - ja esta embutido no deploy_local.py |
| `kubernetes_docs/local_build_and_deploy/` | Versao template do deploy_local | Pode remover - ja temos a nossa copia em scripts/deploy/ |
| `kubernetes_docs/monitoring/` | Dashboards Grafana/Prometheus | Pode remover - e config do cluster |
| `kubernetes_docs/migration_docs/` | Planos de migracao para Kubernetes | Pode remover - migracao ja foi feita |

### .dockerignore - Referencias ao frontend Flutter antigo

O arquivo `.dockerignore` na raiz ainda referencia `no_fluxo_frontend/` (o frontend Flutter antigo, ja deletado). Nao causa problemas, mas pode ser limpo.

---

## RESUMO - Lista de arquivos para remover

```
# Deploy antigo (docker-compose + VPS)
Dockerfile
docker-compose.yml
docker-entrypoint.sh
nginx.conf
view-logs.sh

# Scripts auxiliares antigos
scripts/run_docker_and_follow.py
scripts/stop_docker.py

# Documentacao generica do cluster (opcional)
kubernetes_docs/        (pasta inteira)
```

## Arquivos para MANTER

```
# Deploy atual (Kubernetes)
k8s.backend.Dockerfile
k8s.frontend-svelte.Dockerfile
scripts/deploy/

# CI/CD
.github/workflows/

# Docker config
.dockerignore              (limpar referencias ao frontend Flutter)
no_fluxo_backend/.dockerignore

# Testes
run_all_tests.sh
```

---

## Notas adicionais

1. **O `.dockerignore` na raiz** lista `no_fluxo_frontend/` que e o frontend Flutter antigo (ja deletado do git). Apos a limpeza, vale atualizar esse arquivo tambem.

2. **O dominio `simplifica-pbl.space`** aparece apenas nos arquivos legados (nginx.conf, docker-compose.yml). O dominio atual e `*.crianex.com`.

3. **A pasta `kubernetes_docs/`** ja esta no `.dockerignore`, entao nao afeta builds. A remocao e por limpeza do repositorio.
