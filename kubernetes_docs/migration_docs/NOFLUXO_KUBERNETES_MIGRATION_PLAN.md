# NoFluxo Kubernetes Migration Plan

This document outlines the plan to migrate NoFluxo from Docker Compose (on `simplifica-pbl.space`) to the Kubernetes cluster as a **non-business app** using **local build and deploy**.

---

## Current Architecture

| Component          | Technology           | Port  | Details                                    |
| ------------------ | -------------------- | ----- | ------------------------------------------ |
| **Backend API**    | Node.js/TypeScript   | 3325  | Express.js, Supabase integration           |
| **AI Agent**       | Python/Flask         | 4652  | RAGFlow client, curriculum analysis        |
| **PDF Parser**     | Python               | —     | Runs on-demand via backend                 |
| **Reverse Proxy**  | Nginx                | 80/443| SSL termination with Let's Encrypt         |
| **Auto-updates**   | Python script        | —     | Polls git every 60s, rebuilds on changes   |

**Current domain:** `simplifica-pbl.space:3325` (backend), `simplifica-pbl.space:4652` (AI agent)

---

## Target Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Developer Machine                          │
│                                                              │
│  1. docker build   (multi-arch via buildx)                   │
│  2. docker push    → registry.kubernetes.crianex.com         │
│  3. python deploy_local.py backend                           │
│  4. python deploy_local.py ai-agent                          │
└──────────────────────────────────────────────────────────────┘
         │                           │
         ▼                           ▼
┌─────────────────┐     ┌──────────────────────────┐
│  Docker Registry │     │     Deploy API Server     │
│  (private)       │     │  → creates K8s manifests  │
└─────────────────┘     │  → applies deployment     │
                        │  → configures ingress/TLS │
                        │  → sets up DNS            │
                        └──────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                            │
│                 (non-business node pool)                         │
│                                                                  │
│  ┌─────────────────┐            ┌─────────────────┐             │
│  │ nofluxo-backend │            │ nofluxo-ai-agent│             │
│  │ Deployment      │            │ Deployment      │             │
│  │ (Node.js)       │───────────▶│ (Python/Flask)  │             │
│  │ Port: 3325      │  internal  │ Port: 4652      │             │
│  └────────┬────────┘            └────────┬────────┘             │
│           │                              │                       │
│           └──────────┬───────────────────┘                       │
│                      ▼                                           │
│             ┌─────────────────┐                                  │
│             │ Traefik Ingress │                                  │
│             │ + cert-manager  │                                  │
│             │ (auto TLS)      │                                  │
│             └────────┬────────┘                                  │
│                      │                                           │
│         ┌────────────┴────────────┐                              │
│         ▼                         ▼                              │
│  api-nofluxo.crianex.com    ai-nofluxo.crianex.com               │
└─────────────────────────────────────────────────────────────────┘
```

### Target Domains

| Service      | Domain                       |
| ------------ | ---------------------------- |
| Backend API  | `api-nofluxo.crianex.com`    |
| AI Agent     | `ai-nofluxo.crianex.com`     |

---

## Migration Approach: Separate Deployments

Deploy backend and AI agent as **separate Kubernetes deployments** using the **local build and deploy** workflow.

**Pros:**
- Kubernetes-native, independent scaling
- Smaller images per service
- No GitHub Actions setup needed — deploy directly from your machine
- Code doesn't need to be pushed to Git first
- Faster iteration during development

**Cons:**
- Need to update backend to call AI agent via `ai-nofluxo.crianex.com` instead of `localhost:4652`

---

## Phase 1: Set Up Local Deploy Scripts (30 mins)

### 1.1 Copy Deploy Scripts

```bash
# From repository root
mkdir -p scripts/deploy
cp kubernetes_docs/local_build_and_deploy/deploy_config.py scripts/deploy/
cp kubernetes_docs/local_build_and_deploy/deploy_local.py scripts/deploy/
cp kubernetes_docs/local_build_and_deploy/requirements.txt scripts/deploy/
```

### 1.2 Install Dependencies

```bash
pip install -r scripts/deploy/requirements.txt
```

### 1.3 Create `.env.local` at Repo Root

```bash
cp kubernetes_docs/local_build_and_deploy/.env.local.example .env.local
```

Edit `.env.local`:

```env
# Deploy API credentials
DEPLOY_API_URL=https://deploy.kubernetes.crianex.com
DEPLOY_API_KEY=your-deploy-api-key-here

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key

# RAGFlow
RAGFLOW_API_KEY=your-ragflow-api-key
RAGFLOW_URL=https://your-ragflow-url
```

### 1.4 Add to `.gitignore`

```
.env.local
.deploy/
```

### 1.5 Login to Docker Registry

```bash
docker login registry.kubernetes.crianex.com
```

---

## Phase 2: Create Dockerfiles (1-2 hours)

### 2.1 Backend Dockerfile

Create `k8s.backend.Dockerfile` in repository root:

```dockerfile
# NoFluxo Backend Kubernetes Dockerfile
# Node.js + TypeScript + PDF Parser

FROM registry.kubernetes.crianex.com/library/node:20-bullseye AS builder

WORKDIR /app

# Install Python for PDF parser
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/python3 /usr/bin/python

# Install Node.js dependencies
COPY no_fluxo_backend/package*.json ./
RUN npm ci --omit=dev || (npm install --omit=dev && npm ci --omit=dev)

# Install Python dependencies for PDF parser
COPY no_fluxo_backend/parse-pdf/requirements.txt ./parse-pdf/
RUN pip3 install --no-cache-dir -r parse-pdf/requirements.txt

# Copy source code
COPY no_fluxo_backend/src/ ./src/
COPY no_fluxo_backend/parse-pdf/ ./parse-pdf/
COPY no_fluxo_backend/tsconfig.json ./

# Build TypeScript
RUN npm run build

# Production image
FROM registry.kubernetes.crianex.com/library/node:20-bullseye-slim

WORKDIR /app

# Install Python runtime for PDF parser
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/python3 /usr/bin/python

# Create non-root user
RUN useradd -r -u 1001 -m appuser

# Copy Python packages
COPY --from=builder /usr/local/lib/python3.11/dist-packages /usr/local/lib/python3.11/dist-packages

# Copy from builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/parse-pdf ./parse-pdf
COPY no_fluxo_backend/package.json ./

# Create log directories
RUN mkdir -p logs parse-pdf/logs \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 3325

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3325/health || exit 1

CMD ["node", "dist/index.js"]
```

### 2.2 AI Agent Dockerfile

Create `k8s.ai-agent.Dockerfile` in repository root:

```dockerfile
# NoFluxo AI Agent Kubernetes Dockerfile
# Python/Flask + RAGFlow

FROM registry.kubernetes.crianex.com/library/python:3.11-slim AS builder

WORKDIR /app

# Install dependencies
COPY no_fluxo_backend/ai_agent/requirements.txt ./
RUN pip install --no-cache-dir --user -r requirements.txt

# Production image
FROM registry.kubernetes.crianex.com/library/python:3.11-slim

WORKDIR /app

# Create non-root user
RUN useradd -r -u 1001 -m appuser

# Copy dependencies from builder
COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH

# Copy source code
COPY no_fluxo_backend/ai_agent/ ./

# Create log directory
RUN mkdir -p logs && chown -R appuser:appuser /app

USER appuser

EXPOSE 4652

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:4652/health')" || exit 1

CMD ["python", "app.py"]
```

### 2.3 Add .dockerignore

Create `.dockerignore` in repository root:

```
.git
.github
node_modules
dist
logs
*.log
.env
.env.*
.env.local
.deploy/
coverage
*.md
!README.md
tests-*
documentation
documentacao
prototipo
no_fluxo_frontend*
coleta_dados
scripts/deploy
kubernetes_docs
```

---

## Phase 3: Configure Deploy Config (30 mins)

Edit `scripts/deploy/deploy_config.py`:

```python
"""
deploy_config.py — NoFluxo app configuration for local deploys.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping, Sequence


@dataclass(frozen=True)
class AppConfig:
    """Configuration for a single deployable application."""

    key: str
    app_name: str
    namespace: str
    image_name: str
    dockerfile: str
    build_context: str
    port: int
    replicas: int
    health_path: str

    domain: str | None = None
    domains: Sequence[str] | None = None

    env_folder: str | None = None

    build_arg_keys: Sequence[str] = ()
    build_arg_static: Mapping[str, str] | None = None

    deploy_env_keys: Sequence[str] = ()
    deploy_env_static: Mapping[str, str] | None = None

    app_class: str = "non-business"  # Route to non-business nodes


# ---------------------------------------------------------------------------
# NoFluxo Apps
# ---------------------------------------------------------------------------

APPS: dict[str, AppConfig] = {
    # ── Backend API ────────────────────────────────────────────────────────
    "backend": AppConfig(
        key="backend",
        app_name="nofluxo-backend",
        namespace="non-business-apps",
        image_name="nofluxo-backend",
        dockerfile="k8s.backend.Dockerfile",
        build_context=".",
        port=3325,
        replicas=1,
        health_path="/health",
        domain="api-nofluxo.crianex.com",
        app_class="non-business",
        deploy_env_keys=(
            "SUPABASE_URL",
            "SUPABASE_SERVICE_ROLE_KEY",
            "SUPABASE_ANON_KEY",
        ),
        deploy_env_static={
            "NODE_ENV": "production",
            "PORT": "3325",
            "AI_AGENT_URL": "https://ai-nofluxo.crianex.com",
        },
    ),

    # ── AI Agent ───────────────────────────────────────────────────────────
    "ai-agent": AppConfig(
        key="ai-agent",
        app_name="nofluxo-ai-agent",
        namespace="non-business-apps",
        image_name="nofluxo-ai-agent",
        dockerfile="k8s.ai-agent.Dockerfile",
        build_context=".",
        port=4652,
        replicas=1,
        health_path="/health",
        domain="ai-nofluxo.crianex.com",
        app_class="non-business",
        deploy_env_keys=(
            "RAGFLOW_API_KEY",
            "RAGFLOW_URL",
            "SUPABASE_URL",
            "SUPABASE_ANON_KEY",
        ),
        deploy_env_static={
            "NODE_ENV": "production",
            "AI_AGENT_PORT": "4652",
        },
    ),
}


def get_app_config(key: str) -> AppConfig:
    """Get app config by key, supporting 'all' as a special value."""
    if key not in APPS:
        raise ValueError(f"Unknown app: {key}. Available: {list(APPS.keys())}")
    return APPS[key]
```

### Update deploy_local.py Argument Choices

In `scripts/deploy/deploy_local.py`, find the argument parser and update the choices:

```python
parser.add_argument(
    "target",
    choices=["backend", "ai-agent", "all"],
    help="Which app to deploy",
)
```

---

## Phase 4: Update Backend to Use External AI Agent URL (15 mins)

The backend currently calls the AI agent at `localhost:4652`. Update it to use the environment variable `AI_AGENT_URL`.

Find references to `localhost:4652` or hardcoded AI agent URLs in:
- `no_fluxo_backend/src/` 

Replace with:
```typescript
const AI_AGENT_URL = process.env.AI_AGENT_URL || 'http://localhost:4652';
```

---

## Phase 5: Deploy (30 mins)

`deploy_local.py` handles the **entire workflow automatically**:
1. `docker build` (using the Dockerfile specified in config)
2. `docker push` (to `registry.kubernetes.crianex.com`)
3. Resolve image digest via Deploy API
4. Deploy to Kubernetes via Deploy API
5. Stream logs until deployment completes

### 5.1 Deploy Backend (builds automatically)

```bash
# From repository root - this single command does everything
python scripts/deploy/deploy_local.py backend
```

### 5.2 Deploy AI Agent (builds automatically)

```bash
python scripts/deploy/deploy_local.py ai-agent
```

### 5.3 Deploy Both at Once

```bash
python scripts/deploy/deploy_local.py all
```

### 5.4 Redeploy Without Rebuilding

If you only changed environment variables (no code changes):

```bash
python scripts/deploy/deploy_local.py backend --redeploy
python scripts/deploy/deploy_local.py ai-agent --redeploy
```

### 5.5 Faster Builds (Single Architecture)

For faster iteration, skip multi-arch builds:

```bash
python scripts/deploy/deploy_local.py backend --platform native
```

---

## Phase 6: Verify Deployment (15 mins)

### Check Pods

```bash
kubectl get pods -n non-business-apps -l app=nofluxo-backend
kubectl get pods -n non-business-apps -l app=nofluxo-ai-agent
```

### Check Logs

```bash
kubectl logs -n non-business-apps deployment/nofluxo-backend
kubectl logs -n non-business-apps deployment/nofluxo-ai-agent
```

### Test Endpoints

```bash
curl https://api-nofluxo.crianex.com/health
curl https://ai-nofluxo.crianex.com/health
```

### Check Ingress

```bash
kubectl get ingress -n non-business-apps
```

---

## Phase 7: Decommission Old Infrastructure (30 mins)

After verifying the Kubernetes deployment works:

1. **Stop Docker containers** on old server
   ```bash
   docker-compose down
   ```

2. **Archive old files** (optional)
   ```bash
   mv docker-compose.yml docker-compose.yml.old
   mv Dockerfile Dockerfile.old
   mv docker-entrypoint.sh docker-entrypoint.sh.old
   ```

3. **Delete files no longer needed:**
   - `start_and_monitor.py` (auto-update script)
   - `requirements_monitor.txt`
   - `nginx.conf` (Traefik handles this)

4. **Update DNS** if migrating from `simplifica-pbl.space`

5. **Update documentation** (README, DOCKER_README.md)

---

## Files to Create/Modify Summary

| File                              | Action | Purpose                              |
| --------------------------------- | ------ | ------------------------------------ |
| `k8s.backend.Dockerfile`          | Create | Backend Dockerfile for Kubernetes    |
| `k8s.ai-agent.Dockerfile`         | Create | AI Agent Dockerfile for Kubernetes   |
| `.dockerignore`                   | Create | Exclude unnecessary files from build |
| `scripts/deploy/deploy_config.py` | Create | NoFluxo app configuration            |
| `scripts/deploy/deploy_local.py`  | Copy   | Deploy CLI script                    |
| `.env.local`                      | Create | Deploy API credentials (gitignored)  |
| Backend source code               | Update | Use `AI_AGENT_URL` env var           |

---

## Rollback Plan

If issues occur:

### Rollback Kubernetes Deployment
```bash
kubectl rollout undo deployment/nofluxo-backend -n non-business-apps
kubectl rollout undo deployment/nofluxo-ai-agent -n non-business-apps
```

### Revert to Docker Compose
```bash
# On old server
docker-compose up -d
```

### Redeploy Previous Image
```bash
# Uses last successful buildId from .deploy/
python scripts/deploy/deploy_local.py backend --redeploy
python scripts/deploy/deploy_local.py ai-agent --redeploy
```

---

## Monitoring & Observability

After migration, logs and metrics are available in Grafana:

| What          | Where                                                        |
| ------------- | ------------------------------------------------------------ |
| **Logs**      | Grafana → Explore → Loki → `{app="nofluxo-backend"}`         |
| **Logs**      | Grafana → Explore → Loki → `{app="nofluxo-ai-agent"}`        |
| **Metrics**   | Grafana → Explore → Prometheus (if metrics endpoint added)   |
| **Pods**      | `kubectl get pods -n non-business-apps`                      |

---

## Migration Checklist

- [ ] Copy deploy scripts to `scripts/deploy/`
- [ ] Install Python dependencies (`pip install -r scripts/deploy/requirements.txt`)
- [ ] Create `.env.local` with credentials
- [ ] Login to Docker registry (`docker login registry.kubernetes.crianex.com`)
- [ ] Create `k8s.backend.Dockerfile`
- [ ] Create `k8s.ai-agent.Dockerfile`
- [ ] Create `.dockerignore`
- [ ] Configure `scripts/deploy/deploy_config.py`
- [ ] Update backend to use `AI_AGENT_URL` environment variable
- [ ] Deploy backend: `python scripts/deploy/deploy_local.py backend` (builds + pushes + deploys automatically)
- [ ] Deploy AI agent: `python scripts/deploy/deploy_local.py ai-agent` (builds + pushes + deploys automatically)
- [ ] Verify pods are running in `non-business-apps` namespace
- [ ] Test `https://api-nofluxo.crianex.com/health`
- [ ] Test `https://ai-nofluxo.crianex.com/health`
- [ ] Verify via Grafana logs
- [ ] Stop old Docker Compose deployment
- [ ] Archive old Docker files
- [ ] Update project documentation

---

## Estimated Timeline

| Phase | Task                        | Time       |
| ----- | --------------------------- | ---------- |
| 1     | Set up deploy scripts       | 30 mins    |
| 2     | Create Dockerfiles          | 1-2 hours  |
| 3     | Configure deploy_config.py  | 30 mins    |
| 4     | Update backend AI agent URL | 15 mins    |
| 5     | Deploy                      | 30 mins    |
| 6     | Verify deployment           | 15 mins    |
| 7     | Decommission old infra      | 30 mins    |
| **Total** |                         | **3-4 hours** |

---

## Deploy Commands Quick Reference

```bash
# Full deploy (build + push + deploy) - all automatic!
python scripts/deploy/deploy_local.py backend      # Backend API
python scripts/deploy/deploy_local.py ai-agent     # AI Agent
python scripts/deploy/deploy_local.py all          # Both

# Redeploy without rebuilding (uses cached image from last deploy)
python scripts/deploy/deploy_local.py backend --redeploy

# Dry run (see what would happen without executing)
python scripts/deploy/deploy_local.py backend --dry-run

# Single-platform build (faster, skips multi-arch)
python scripts/deploy/deploy_local.py backend --platform native

# Force rebuild even if nothing changed
python scripts/deploy/deploy_local.py backend --no-cache
```

The script handles everything:
1. **Builds** the Docker image using the Dockerfile specified in `deploy_config.py`
2. **Pushes** to `registry.kubernetes.crianex.com`
3. **Resolves** the image digest (buildId) via Deploy API
4. **Deploys** to Kubernetes with proper ingress, TLS, and DNS
5. **Streams** logs until deployment completes
