# Kubernetes Cluster Documentation

This folder contains documentation and templates for managing the Kubernetes cluster.

## Cluster Overview

- **Platform**: K3s on mixed nodes (cloud + local machines via Tailscale)
- **Ingress**: Traefik (default k3s ingress controller)
- **TLS**: cert-manager with Let's Encrypt (HTTP-01 + DNS-01 for wildcards)
- **Registry**: Private Docker registry at `registry.kubernetes.crianex.com`
- **Deploy API**: REST API for builds and deployments at `deploy.kubernetes.crianex.com`
- **Networking**: Flannel over Tailscale for cross-node communication
- **Monitoring**: Prometheus + Grafana + Loki (see [monitoring/](./monitoring/))

## Documentation

| Document                                     | Description                                     |
| -------------------------------------------- | ----------------------------------------------- |
| [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) | How to deploy projects to the cluster           |
| [REGISTRY_AUTH.md](./REGISTRY_AUTH.md)       | How to manage registry users and authentication |
| [BUILD_ID_REUSE_PYTHON.md](./BUILD_ID_REUSE_PYTHON.md) | Reuse image digests (`buildId`) to skip builds (Python helper) |
| [local_build_and_deploy/](./local_build_and_deploy/) | **Build locally with Docker & deploy via API** (Python scripts + templates) |
| [monitoring/](./monitoring/)                 | Observability stack (Prometheus, Grafana, Loki) |
| [templates/](./templates/)                   | Ready-to-copy templates for new projects        |
| [scripts/](./scripts/)                       | Bootstrap scripts for new projects              |
| [setup/](./setup/)                           | Scripts for setting up new cluster nodes        |

## Quick Start: Deploy a New Project

Deployments use the **Deploy API** which builds images directly on the cluster using Kaniko. This is much faster than building on GitHub Actions runners (~30-60 seconds vs 3-5 minutes).

### Step 1: Set Up GitHub Secrets

In your repository, go to **Settings → Secrets and variables → Actions**:

**Secrets:**
| Secret           | Description                                            |
| ---------------- | ------------------------------------------------------ |
| `DEPLOY_API_KEY` | Deploy API authentication key                          |
| `REPO_TOKEN`     | GitHub token with repo access (for private repos only) |

**Variables:**
| Variable         | Description    | Value                                   |
| ---------------- | -------------- | --------------------------------------- |
| `DEPLOY_API_URL` | Deploy API URL | `https://deploy.kubernetes.crianex.com` |

### Step 2: Add GitHub Actions Workflow

Copy the workflow template to your project:

```bash
mkdir -p .github/workflows
cp templates/github-workflow.yml .github/workflows/deploy.yml
```

Edit the workflow and replace the placeholders:
- `{{APP_NAME}}` → your app name (e.g., `myapp`)
- `{{NAMESPACE}}` → kubernetes namespace (e.g., `apps`)
- `{{PORT}}` → your app port (e.g., `3000`)
- `{{DOMAIN}}` → your domain (e.g., `myapp.kubernetes.crianex.com`)

### Step 3: Add a Dockerfile

Copy the appropriate Dockerfile template:

```bash
# For Node.js
cp templates/Dockerfile.node Dockerfile

# For Python
cp templates/Dockerfile.python Dockerfile

# For Go
cp templates/Dockerfile.go Dockerfile
```

### Step 4: Push to Deploy

```bash
git add .
git commit -m "Add deployment workflow"
git push origin main
```

The GitHub Action will:
1. ✅ Trigger an in-cluster build via the Deploy API
2. ✅ Build your Docker image using Kaniko (fast, no Docker-in-Docker)
3. ✅ Push to the private registry
4. ✅ Deploy to Kubernetes with proper ingress/TLS
5. ✅ Automatically configure DNS (if using Hostinger domains)

### Getting Your API Key

If you don't have an API key, ask an admin or retrieve it from the cluster:

```bash
kubectl get secret deploy-api-secrets -n deploy-system -o jsonpath='{.data.DEPLOY_API_KEY}' | base64 -d
```

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ git push
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Actions                              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  POST /build → Deploy API                               │    │
│  │  (sends repo URL, git ref, deploy config)               │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Deploy API Server                             │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  1. Validate domain ownership (Hostinger API)           │    │
│  │  2. Create Kaniko build job                             │    │
│  │  3. Build & push image to registry                      │    │
│  │  4. Generate K8s manifests                              │    │
│  │  5. Apply deployment, service, ingress                  │    │
│  │  6. Configure DNS A record (automatic)                  │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  App Pods   │  │   Ingress   │  │   TLS Cert  │              │
│  │  (replicas) │  │  (Traefik)  │  │ (cert-mgr)  │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

## Deploy API Features

| Feature                  | Description                                                      |
| ------------------------ | ---------------------------------------------------------------- |
| **In-cluster builds**    | Kaniko builds images directly on the cluster (2-3x faster)       |
| **Auto-deploy**          | Build and deploy in a single API call                            |
| **Multi-port support**   | Deploy apps with multiple ports (HTTP, WebSocket, metrics)       |
| **Wildcard domains**     | Support for `*.app.example.com` via DNS-01 challenge (DigitalOcean) |
| **Automatic DNS**        | DNS A records configured automatically via Hostinger API         |
| **App classes**          | Route workloads to dedicated nodes (`business` / `non-business`) |
| **Health checks**        | Configurable liveness and readiness probes                       |
| **Resource limits**      | CPU and memory limits/requests                                   |
| **Rolling updates**      | Zero-downtime deployments                                        |

## Common Operations

### Check Deployment Status

```bash
curl -s "https://deploy.kubernetes.crianex.com/api/apps/apps/myapp" \
  -H "X-API-Key: $DEPLOY_API_KEY" | jq .
```

### View Build Logs

```bash
curl -s "https://deploy.kubernetes.crianex.com/build/build-myapp-xxx/logs" \
  -H "X-API-Key: $DEPLOY_API_KEY" | jq -r '.logs'
```

### Manual Deploy (without build)

```bash
curl -X POST "https://deploy.kubernetes.crianex.com/api/deploy" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $DEPLOY_API_KEY" \
  -d '{
    "app": "myapp",
    "namespace": "apps",
    "image": "registry.kubernetes.crianex.com/myapp:v1.0.0",
    "port": 3000,
    "domain": "myapp.kubernetes.crianex.com",
    "appClass": "business",
    "metrics": {
      "port": 3000,
      "path": "/metrics",
      "scrapeInterval": "30s",
      "scheme": "http"
    }
  }'
```

The `metrics` block automatically adds Prometheus pod scrape annotations and emits a namespaced `ServiceMonitor` (when the Prometheus Operator CRDs are available) so Grafana can discover your app's `/metrics` endpoint without manual configs.

> 🔒 **Keep metrics private:** Services are internal (`ClusterIP`), so Prometheus scrapes `/metrics` from inside the cluster. If
> you expose the same port through an Ingress/domain, the `/metrics` path will also be publicly reachable. Prefer a dedicated
> metrics port (e.g., `9090`) that is **not** the port routed by your Ingress to keep the metrics endpoint internal.

### Rollback

```bash
curl -X POST "https://deploy.kubernetes.crianex.com/api/apps/apps/myapp/rollback" \
  -H "X-API-Key: $DEPLOY_API_KEY"
```

### Delete Application

```bash
curl -X DELETE "https://deploy.kubernetes.crianex.com/api/apps/apps/myapp" \
  -H "X-API-Key: $DEPLOY_API_KEY"
```

## Cluster Access (Admin Only)

### Via kubectl (from master node)
```bash
ssh root@projeto
kubectl get nodes
kubectl get pods -A
```

### Common kubectl Commands

```bash
# View all pods
kubectl get pods -A

# View logs
kubectl logs -l app=myapp -f

# Restart a deployment
kubectl rollout restart deployment/myapp -n apps

# Check certificate status
kubectl get certificates -A

# View ingresses
kubectl get ingress -A
```

## Troubleshooting

### Build Failed

Check the build logs:
```bash
curl -s "https://deploy.kubernetes.crianex.com/build/$JOB_NAME/logs" \
  -H "X-API-Key: $DEPLOY_API_KEY" | jq -r '.logs'
```

Common issues:
- **Dockerfile not found**: Ensure Dockerfile is in the repo root
- **Build context issues**: Check `buildContext` parameter if using subdirectories
- **Private repo**: Ensure `REPO_TOKEN` secret is set with repo access

### Deployment Not Working

Check deployment status:
```bash
curl -s "https://deploy.kubernetes.crianex.com/api/apps/apps/myapp" \
  -H "X-API-Key: $DEPLOY_API_KEY" | jq .
```

### DNS Not Resolving

DNS is automatically configured for Hostinger domains. For other DNS providers, manually add an A record:
```
myapp.kubernetes.crianex.com  A  31.97.86.71
```

### TLS Certificate Issues

```bash
# Check certificate status (admin)
kubectl describe certificate myapp-tls -n apps

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```
