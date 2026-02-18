# Migration Guide: Auto-Update System to Kubernetes

This document outlines the migration from the old Docker-based auto-update system to the new Kubernetes deployment with GitHub Actions CI/CD.

## Overview

| Aspect         | Old System                                    | New System                           |
| -------------- | --------------------------------------------- | ------------------------------------ |
| **Deployment** | Single Docker container with git auto-updates | Kubernetes pods via GitHub Actions   |
| **Updates**    | Python script polling git every 60s           | Push to a branch triggers deploy     |
| **Rollback**   | Manual git revert                             | Kubernetes rollback or redeploy      |
| **Scaling**    | Single container                              | Multiple replicas                    |
| **Logging**    | File-based (`logs/*.log`)                     | stdout → Grafana/Loki                |
| **SSL**        | nginx + certbot on host                       | Kubernetes Ingress with cert-manager |

---

## What Was Removed

### Files Deleted
```
backend/start_and_monitor.py      # Python auto-update script
backend/requirements.txt          # Python dependencies
docker-entrypoint.sh              # Complex entrypoint with git setup
how_to_setup_docker_prod_auto_update/  # Old documentation
```

### Dependencies Removed from Dockerfile
- Python 3, pip, python-dev
- Tesseract OCR (never used)
- Poppler PDF tools (never used)
- Git (no longer needed in container)
- nodemon, ts-node (dev tools)

### Environment Variables No Longer Needed
```bash
GIT_BRANCH              # Was used for auto-update branch
GIT_DISCOVERY_ACROSS_FILESYSTEM  # Git workaround
PYTHONUNBUFFERED        # Python output buffering
PYTHONIOENCODING        # Python encoding
GITHUB_TOKEN            # For private repo git pulls
```

---

## New Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ push
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Actions                              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  1. Build JSON payload safely with jq                   │    │
│  │  2. Trigger cluster build (POST /build)                 │    │
│  │  3. Kaniko builds image in cluster (~30-60s)            │    │
│  │  4. Push to registry.kubernetes.crianex.com             │    │
│  │  5. Deploy via Deploy API with auto DNS                 │    │
│  │  6. Stream build logs in real-time                      │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ app-backend     │  │ app-frontend    │  │   Ingress       │  │
│  │ pod (replicas)  │  │ pod (replicas)  │  │   Controller    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│           │                    │                    │            │
│           └────────────────────┴────────────────────┘            │
│                              │                                   │
│                    ┌─────────────────┐                          │
│                    │  Loki/Promtail  │ ──► Grafana              │
│                    │  (log collect)  │                          │
│                    └─────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## GitHub Secrets & Variables Required

Add these in **Settings → Secrets and variables → Actions**:

### Secrets
| Secret                      | Description                   | Example                   |
| --------------------------- | ----------------------------- | ------------------------- |
| `DEPLOY_API_KEY`            | Deploy API authentication     | `235340110be5a67a...`     |
| `REPO_TOKEN`                | GitHub token with repo access | `ghp_xxxx...`             |
| `SUPABASE_URL`              | Supabase project URL          | `https://xxx.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key     | `eyJhbGc...`              |
| `SUPABASE_ANON_KEY`         | Supabase anon key (frontend)  | `eyJhbGc...`              |

### Variables
| Variable         | Description    | Value                                   |
| ---------------- | -------------- | --------------------------------------- |
| `DEPLOY_API_URL` | Deploy API URL | `https://deploy.kubernetes.crianex.com` |

---

## Example GitHub Actions Workflow

```yaml
name: Deploy

on:
  push:
    branches: [main]

env:
  DEPLOY_API_URL: ${{ vars.DEPLOY_API_URL }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Build and Deploy
        id: build
        env:
          REPO_TOKEN: ${{ secrets.REPO_TOKEN }}
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
        run: |
          # Build JSON payload safely using jq (handles special characters in secrets)
          payload=$(jq -n \
            --arg app "myapp-backend" \
            --arg namespace "apps" \
            --arg repoUrl "https://github.com/${{ github.repository }}" \
            --arg gitRef "${{ github.sha }}" \
            --arg gitToken "$REPO_TOKEN" \
            --arg domain "api.myapp.kubernetes.crianex.com" \
            --arg supabaseUrl "$SUPABASE_URL" \
            --arg supabaseKey "$SUPABASE_KEY" \
            '{
              app: $app,
              namespace: $namespace,
              repoUrl: $repoUrl,
              gitRef: $gitRef,
              gitToken: $gitToken,
              imageTag: $gitRef,
              cache: true,
              deploy: true,
              deployConfig: {
                port: 5919,
                replicas: 2,
                domain: $domain,
                healthPath: "/health",
                env: {
                  NODE_ENV: "production",
                  SUPABASE_URL: $supabaseUrl,
                  SUPABASE_SERVICE_ROLE_KEY: $supabaseKey
                }
              }
            }')
          
          http_response=$(curl -s -w "\n%{http_code}" -X POST "${{ env.DEPLOY_API_URL }}/build" \
            -H "Content-Type: application/json" \
            -H "X-API-Key: ${{ secrets.DEPLOY_API_KEY }}" \
            -d "$payload")
          
          http_code=$(echo "$http_response" | tail -n1)
          response=$(echo "$http_response" | sed '$d')
          
          if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
            echo "❌ API request failed with HTTP $http_code"
            echo "$response" | jq . 2>/dev/null || echo "$response"
            exit 1
          fi
          
          echo "job_name=$(echo $response | jq -r '.jobName')" >> $GITHUB_OUTPUT

      - name: Stream logs and wait
        run: |
          last_line_count=0
          while true; do
            logs=$(curl -sf "${{ env.DEPLOY_API_URL }}/build/${{ steps.build.outputs.job_name }}/logs" \
              -H "X-API-Key: ${{ secrets.DEPLOY_API_KEY }}" 2>/dev/null | jq -r '.logs // ""')
            
            if [ -n "$logs" ]; then
              current_line_count=$(echo "$logs" | wc -l)
              if [ "$current_line_count" -gt "$last_line_count" ]; then
                echo "$logs" | tail -n +$((last_line_count + 1))
                last_line_count=$current_line_count
              fi
            fi
            
            status=$(curl -sf "${{ env.DEPLOY_API_URL }}/build/${{ steps.build.outputs.job_name }}" \
              -H "X-API-Key: ${{ secrets.DEPLOY_API_KEY }}" 2>/dev/null | jq -r '.status // "pending"')
            
            [ "$status" = "succeeded" ] && echo "✅ Done!" && exit 0
            [ "$status" = "failed" ] && echo "❌ Failed!" && exit 1
            sleep 3
          done
```

> **Important:** Always use `jq` to build JSON payloads when including secrets. This prevents JSON parsing errors caused by special characters (newlines, quotes) in secret values.

---

## How to Deploy

### Automatic (Recommended)
Push to the specific branch:
```bash
git push origin main
```

The GitHub Action will:
1. Build JSON payload safely with `jq`
2. Trigger a build on the Kubernetes cluster
3. Build Docker images using Kaniko (~30-60 seconds)
4. Push to the container registry
5. Deploy to Kubernetes with ingress
6. Configure DNS automatically (for Hostinger domains)

### Manual Trigger
Go to **Actions → Deploy → Run workflow**

---

## Viewing Logs

### Old Way (File-based)
```bash
docker exec my-container cat /app/backend/logs/all.log
```

### New Way (Kubernetes)
```bash
# Via kubectl
kubectl logs -n apps deployment/myapp-backend

# Via Grafana
# Navigate to Explore → Loki → {app="myapp-backend"}
```

The logger now outputs **JSON to stdout** in production, making it easy to query in Grafana:
```json
{"level":"info","message":"Server started on port 5919","timestamp":"2025-11-28T20:15:00.000Z"}
```

---

## Application Metrics (Prometheus + Grafana)

The new system supports automatic Prometheus metrics collection. If your app exposes a `/metrics` endpoint, you can have it automatically scraped by Prometheus and visualized in Grafana.

### Adding Metrics to Your App

Install a Prometheus client library and expose metrics:

```typescript
// Node.js example with prom-client
import { Registry, collectDefaultMetrics, Counter } from 'prom-client';

export const register = new Registry();
collectDefaultMetrics({ register });

export const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

// In your Express app
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

### Deploying with Metrics

Add the `metrics` block to your deploy configuration:

```yaml
# In GitHub Actions workflow
payload=$(jq -n \
  --arg app "myapp-backend" \
  --argjson port 5919 \
  '{
    app: $app,
    deploy: true,
    deployConfig: {
      port: $port,
      replicas: 2,
      metrics: {
        port: 5919,
        path: "/metrics",
        scrapeInterval: "30s"
      }
    }
  }')
```

Or via API:

```bash
curl -X POST "https://deploy.kubernetes.crianex.com/api/deploy" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $DEPLOY_API_KEY" \
  -d '{
    "app": "myapp-backend",
    "namespace": "apps",
    "image": "registry.kubernetes.crianex.com/myapp:v1.0.0",
    "port": 5919,
    "metrics": {
      "port": 5919,
      "path": "/metrics",
      "scrapeInterval": "30s"
    }
  }'
```

### What Gets Created

- **Pod annotations** for Prometheus scraping (`prometheus.io/scrape: "true"`)
- **ServiceMonitor** resource (if Prometheus Operator CRDs are installed)
- **Service port** for metrics (automatically added even if not in your `ports` array)

### Viewing Metrics in Grafana

1. Access Grafana at https://grafana.kubernetes.crianex.com
2. Go to **Explore** → Select **Prometheus** datasource
3. Query your metrics: `http_requests_total{app="myapp-backend"}`

### Security: Keep Metrics Private

> 🔒 **Important:** If your metrics endpoint is on the same port as your app AND you expose that port via Ingress, your `/metrics` will be publicly accessible. 

**Recommended:** Use a dedicated metrics port (e.g., `9090`) that is NOT routed by your Ingress:

```json
{
  "ports": [
    { "port": 5919, "name": "http" },
    { "port": 9090, "name": "metrics" }
  ],
  "domain": "api.myapp.kubernetes.crianex.com",
  "metrics": {
    "port": 9090,
    "path": "/metrics"
  }
}
```

The Ingress only routes to the first port, keeping metrics internal to the cluster.

📖 **See the full guide:** [Application Metrics Guide](../monitoring/APP_METRICS_GUIDE.md)

---

## Rollback

### Using Deploy API
```bash
curl -X POST "https://deploy.kubernetes.crianex.com/api/apps/apps/myapp-backend/rollback" \
  -H "X-API-Key: $DEPLOY_API_KEY"
```

### Using kubectl
```bash
# View rollout history
kubectl rollout history deployment/myapp-backend -n apps

# Rollback to previous version
kubectl rollout undo deployment/myapp-backend -n apps

# Rollback to specific revision
kubectl rollout undo deployment/myapp-backend -n apps --to-revision=2
```

### Redeploy Previous Commit
Re-run the GitHub Action workflow for a previous commit.

---

## Local Development

Local development remains unchanged:
```bash
cd backend
npm run dev  # Uses nodemon for hot reload
```

For Docker Compose (local testing):
```bash
docker-compose up --build
```

---

## Dockerfile Best Practices

Use this pattern for reliable builds:

```dockerfile
FROM registry.kubernetes.crianex.com/library/node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
# Try npm ci first, fall back to npm install if lock file is out of sync
RUN npm ci || (npm install && npm ci)

COPY . .
RUN npm run build

FROM registry.kubernetes.crianex.com/library/node:20-alpine
WORKDIR /app
RUN addgroup -g 1001 -S app && adduser -u 1001 -S app -G app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./

USER app
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

---

## Checklist for Migration

- [ ] Add all required GitHub secrets
- [ ] Add `DEPLOY_API_URL` variable
- [ ] Create GitHub Actions workflow using `jq` for JSON payloads
- [ ] Push changes to the branch
- [ ] Verify GitHub Action runs successfully
- [ ] Check pods are running: `kubectl get pods -n apps`
- [ ] Test your app's health endpoint
- [ ] Verify logs appear in Grafana (Loki datasource)
- [ ] (Optional) Add `/metrics` endpoint to your app
- [ ] (Optional) Enable metrics in deploy config
- [ ] (Optional) Verify metrics appear in Grafana (Prometheus datasource)
- [ ] Decommission old Docker host (if applicable)

---

## Troubleshooting

### JSON Parse Error (400 Bad Request)
If you see errors like `Bad control character in string literal`:
- **Cause:** Secrets contain special characters (newlines, tabs) that break JSON
- **Fix:** Use `jq` to build JSON payloads (see workflow example above)

### Build Fails
Check the GitHub Actions logs for the HTTP response from the Deploy API. The API now provides detailed error hints.

### Pod CrashLoopBackOff
```bash
kubectl logs -n apps <pod-name> --previous
kubectl describe pod -n apps <pod-name>
```

### Logs Not Appearing in Grafana
Ensure the app logs to stdout (not files). Check that Promtail/Loki is collecting from the `apps` namespace.

### Metrics Not Appearing in Prometheus/Grafana
1. Verify your app exposes `/metrics` endpoint
2. Check pod annotations: `kubectl get pod -n apps -l app=myapp -o jsonpath='{.items[0].metadata.annotations}'`
3. Ensure ServiceMonitor exists: `kubectl get servicemonitor -n apps myapp`
4. Check Prometheus targets at http://localhost:9090/targets (after port-forwarding)
5. See [Application Metrics Guide](../monitoring/APP_METRICS_GUIDE.md) for detailed troubleshooting

### 502 Bad Gateway
The pod might not be ready. Check:
```bash
kubectl get pods -n apps
kubectl describe ingress -n apps
```

### npm ci fails with lock file mismatch
The Dockerfile template now handles this automatically:
```dockerfile
RUN npm ci || (npm install && npm ci)
```
This tries `npm ci` first, falls back to `npm install` to fix the lock file, then retries.
