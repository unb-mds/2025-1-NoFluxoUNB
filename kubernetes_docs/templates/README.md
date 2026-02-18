# Project Deployment Templates

This folder contains templates for deploying projects to the Kubernetes cluster using the Deploy API.

## Files

| File                              | Purpose                                      |
| --------------------------------- | -------------------------------------------- |
| `github-workflow.yml`             | GitHub Actions workflow for Deploy API       |
| `Dockerfile.node`                 | Dockerfile template for Node.js apps         |
| `Dockerfile.python`               | Dockerfile template for Python apps          |
| `Dockerfile.go`                   | Dockerfile template for Go apps              |
| `.dockerignore`                   | Common files to exclude from Docker builds   |
| `grafana-dashboard.template.json` | Template Grafana dashboard with placeholders |

## Quick Start

### 1. Copy the Workflow

```bash
mkdir -p .github/workflows
cp github-workflow.yml .github/workflows/deploy.yml
```

### 2. Edit Placeholders

Open `.github/workflows/deploy.yml` and replace:

| Placeholder     | Description           | Example                        |
| --------------- | --------------------- | ------------------------------ |
| `{{APP_NAME}}`  | Your application name | `myapp`                        |
| `{{NAMESPACE}}` | Kubernetes namespace  | `apps`                         |
| `{{PORT}}`      | Application port      | `3000`                         |
| `{{DOMAIN}}`    | Your app's domain     | `myapp.kubernetes.crianex.com` |

### Optional: HTTP-only Ingress

For IoT devices (ESP32, Arduino) that can't use SSL, add `tls: false` to the deployConfig in the workflow:

```yaml
deployConfig: {
  port: $port,
  replicas: 1,
  domain: $domain,
  tls: false,
  healthPath: "/health"
}
```

### Optional: Wildcard Domains

For multi-tenant applications that need dynamic subdomains (e.g., `tenant1.myapp.com`, `tenant2.myapp.com`), use wildcard domains:

```yaml
deployConfig: {
  port: $port,
  replicas: 2,
  domains: ["*.myapp.crianex.com", "myapp.crianex.com"],
  healthPath: "/health"
}
```

> ⚠️ **Requirements:** Wildcard domains require DNS-01 challenge. The domain must be hosted on DigitalOcean (not Hostinger). The Deploy API automatically detects wildcards and uses the appropriate certificate issuer.

Your application receives the `Host` header to determine which tenant/subdomain is being accessed.

### Optional: Prometheus Metrics

To enable automatic Prometheus scraping and ServiceMonitor creation, set the `METRICS_PORT` environment variable in the workflow:

```yaml
env:
  # ... other env vars
  METRICS_PORT: "9090"        # Set to enable metrics (leave empty to disable)
  METRICS_PATH: "/metrics"    # Path to metrics endpoint
  METRICS_INTERVAL: "30s"     # Scrape interval
  METRICS_SCHEME: "http"      # Use "https" if metrics endpoint uses TLS
```

This will:
- Add Prometheus scrape annotations to your pods
- Create a ServiceMonitor resource (if Prometheus Operator is installed)
- Automatically expose the metrics port on the Service

> 🔒 **Security tip:** Use a dedicated metrics port (e.g., `9090`) separate from your main app port to keep metrics internal to the cluster.

#### Node.js Example (prom-client)

```bash
npm install prom-client
```

```typescript
// src/metrics.ts
import express from 'express';
import { Registry, collectDefaultMetrics, Counter, Histogram } from 'prom-client';

const app = express();
const metricsApp = express();
const register = new Registry();

// Collect default Node.js metrics (CPU, memory, event loop)
collectDefaultMetrics({ register });

// Custom metrics
const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

// Middleware to track requests
app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequestsTotal.inc({ method: req.method, route: req.path, status: res.statusCode });
  });
  next();
});

// Main app on port 3000
app.get('/health', (req, res) => res.json({ status: 'healthy' }));
app.listen(3000);

// Metrics on port 9090 (internal only)
metricsApp.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
metricsApp.listen(9090);
```

#### Python Example (prometheus-client)

```bash
pip install prometheus-client flask
```

```python
# app.py
from flask import Flask, Response
from prometheus_client import Counter, generate_latest, REGISTRY, CONTENT_TYPE_LATEST
import threading

app = Flask(__name__)
metrics_app = Flask(__name__)

# Custom metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])

@app.after_request
def track_metrics(response):
    REQUEST_COUNT.labels(request.method, request.path, response.status_code).inc()
    return response

@app.route('/health')
def health():
    return {'status': 'healthy'}

# Metrics endpoint on separate port
@metrics_app.route('/metrics')
def metrics():
    return Response(generate_latest(REGISTRY), mimetype=CONTENT_TYPE_LATEST)

if __name__ == '__main__':
    # Run metrics server on port 9090 in background
    threading.Thread(target=lambda: metrics_app.run(host='0.0.0.0', port=9090)).start()
    # Main app on port 8080
    app.run(host='0.0.0.0', port=8080)
```

Then deploy with:
```yaml
METRICS_PORT: "9090"
PORT: 3000  # or 8080 for Python
```

📖 **Full guide:** See [Application Metrics Guide](../monitoring/APP_METRICS_GUIDE.md) for:
- More language examples (Go, etc.)
- Viewing metrics in Grafana
- Troubleshooting common issues

### Optional: Monorepo / Subdirectory Builds

If your app is in a subdirectory (monorepo setup), add `dockerfile` and `buildContext` parameters:

```yaml
payload=$(jq -n \
  --arg app "myapp-backend" \
  --arg namespace "apps" \
  --arg repoUrl "https://github.com/${{ github.repository }}" \
  --arg gitRef "${{ github.sha }}" \
  --arg gitToken "$REPO_TOKEN" \
  --arg dockerfile "backend/Dockerfile" \
  --arg buildContext "backend" \
  --arg domain "api.myapp.kubernetes.crianex.com" \
  '{
    app: $app,
    namespace: $namespace,
    repoUrl: $repoUrl,
    gitRef: $gitRef,
    gitToken: $gitToken,
    dockerfile: $dockerfile,
    buildContext: $buildContext,
    deploy: true,
    deployConfig: {
      port: 3000,
      domain: $domain,
      healthPath: "/health"
    }
  }')
```

**Important:** Use `buildContext` (not `context`) for the subdirectory parameter.

### 3. Copy the Dockerfile

```bash
# For Node.js
cp Dockerfile.node Dockerfile

# For Python
cp Dockerfile.python Dockerfile

# For Go
cp Dockerfile.go Dockerfile
```

### 4. Configure GitHub Secrets

Go to your repository → **Settings → Secrets and variables → Actions**

**Secrets:**
- `DEPLOY_API_KEY` - Deploy API authentication key
- `REPO_TOKEN` - GitHub token (only for private repos)

**Variables:**
- `DEPLOY_API_URL` = `https://deploy.kubernetes.crianex.com`

### 5. Push to Deploy

```bash
git add .
git commit -m "Add deployment"
git push origin main
```

## How It Works

The workflow:
1. Triggers the Deploy API with your repo URL and git ref
2. Kaniko builds your Docker image directly on the cluster
3. The image is pushed to the private registry
4. Kubernetes deployment, service, and ingress are created
5. DNS is automatically configured (for Hostinger domains)
6. **Grafana dashboard is synced** (if `grafana-dashboard.json` exists in repo)

**Build time:** ~30-60 seconds (much faster than GitHub Actions builds!)

## Optional: Grafana Dashboard Auto-Sync

Add a `grafana-dashboard.json` file to your repository root, and it will be automatically uploaded to Grafana on each deploy!

### How It Works

1. When your build completes and deployment succeeds
2. The Deploy API checks for `grafana-dashboard.json` in your repo
3. If found, it uploads/updates the dashboard in Grafana
4. Dashboards are organized in an "Application Dashboards" folder
5. Dashboards are tagged with `app`, `namespace`, and app name

### Creating a Dashboard

**Option A: Use the Template**

Copy and customize the provided template:

```bash
cp grafana-dashboard.template.json grafana-dashboard.json
```

Then replace the placeholders:
- `{{APP_NAME}}` → your app name (e.g., `my-app`)
- `{{NAMESPACE}}` → your namespace (e.g., `apps`)

**Option B: Export from Grafana**

1. Create your dashboard in Grafana (https://grafana.kubernetes.crianex.com)
2. Design panels for your app's metrics
3. Go to **Dashboard Settings** → **JSON Model**
4. Copy the JSON and save as `grafana-dashboard.json` in your repo root

### Example Dashboard JSON

```json
{
  "title": "My App Dashboard",
  "tags": ["my-app"],
  "timezone": "browser",
  "schemaVersion": 39,
  "panels": [
    {
      "type": "stat",
      "title": "Total Requests",
      "gridPos": { "x": 0, "y": 0, "w": 6, "h": 4 },
      "targets": [
        {
          "expr": "sum(http_requests_total{app=\"my-app\"})",
          "refId": "A"
        }
      ]
    },
    {
      "type": "timeseries",
      "title": "Request Rate",
      "gridPos": { "x": 6, "y": 0, "w": 18, "h": 8 },
      "targets": [
        {
          "expr": "rate(http_requests_total{app=\"my-app\"}[5m])",
          "legendFormat": "{{method}} {{route}}",
          "refId": "A"
        }
      ]
    }
  ],
  "templating": {
    "list": [
      {
        "name": "namespace",
        "type": "query",
        "query": "label_values(up, namespace)",
        "current": { "text": "apps", "value": "apps" }
      }
    ]
  }
}
```

### Monorepo Support

For monorepos, place `grafana-dashboard.json` in your app's subdirectory:
```
my-monorepo/
├── backend/
│   ├── Dockerfile
│   ├── grafana-dashboard.json  ← Detected automatically
│   └── src/
└── frontend/
    ├── Dockerfile
    └── grafana-dashboard.json
```

The Deploy API checks both the `buildContext` subdirectory and repo root.

### Tips

- Use **template variables** (`$namespace`, `$app`) to make dashboards reusable
- Include **Node.js/Python default metrics** panels (CPU, memory, event loop)
- Add **HTTP request** panels (rate, latency histogram, error rate)
- Version your dashboard JSON with your code

📖 **More info:** See [API Reference - Dashboard Management](../../deploy-api-server/docs/API_REFERENCE.md#grafana-dashboard-management)

## Notes

- The `k8s/` folder with manual manifests is **no longer needed** - the Deploy API generates them automatically
- You only need a `Dockerfile` and the GitHub Actions workflow
- DNS records are created automatically when using Hostinger-managed domains

## Documentation

| Document | Description |
| -------- | ----------- |
| [API Reference](../../deploy-api-server/docs/API_REFERENCE.md) | Full Deploy API documentation |
| [Build Guide](../../deploy-api-server/docs/BUILD_GUIDE.md) | In-cluster builds with Kaniko |
| [Application Metrics Guide](../monitoring/APP_METRICS_GUIDE.md) | Add Prometheus metrics to your apps |
| [Monitoring Setup Guide](../monitoring/SETUP_GUIDE.md) | Cluster monitoring infrastructure |
| [Migration Guide](../migration_docs/MIGRATION_TO_KUBERNETES.md) | Migrating from Docker to Kubernetes |

