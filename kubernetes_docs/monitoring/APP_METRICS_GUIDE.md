# Application Metrics Guide

This guide explains how to expose Prometheus metrics from your deployed applications and have them automatically discovered by the cluster's monitoring stack (Prometheus + Grafana).

## Overview

When you deploy an application with the `metrics` configuration, the Deploy API automatically:

1. **Adds Prometheus scrape annotations** to your pods
2. **Creates a ServiceMonitor** (if Prometheus Operator CRDs are installed)
3. **Ensures the metrics port is exposed** on the Service (even if not in your `ports` array)

This enables Prometheus to automatically discover and scrape your application's `/metrics` endpoint without manual configuration.

---

## Quick Start

### 1. Add a `/metrics` Endpoint to Your App

#### Node.js (using prom-client)

```bash
npm install prom-client
```

```typescript
// src/metrics.ts
import { Registry, collectDefaultMetrics, Counter, Histogram } from 'prom-client';

export const register = new Registry();

// Collect default Node.js metrics (CPU, memory, event loop, etc.)
collectDefaultMetrics({ register });

// Custom metrics
export const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

export const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [register],
});
```

```typescript
// src/index.ts (Express example)
import express from 'express';
import { register, httpRequestsTotal, httpRequestDuration } from './metrics';

const app = express();

// Middleware to track request metrics
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestsTotal.inc({ method: req.method, route: req.path, status: res.statusCode });
    httpRequestDuration.observe({ method: req.method, route: req.path, status: res.statusCode }, duration);
  });
  next();
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Your other routes...
app.get('/health', (req, res) => res.json({ status: 'healthy' }));

app.listen(3000, () => console.log('Server running on port 3000'));
```

#### Python (using prometheus-client)

```bash
pip install prometheus-client
```

```python
# app.py (Flask example)
from flask import Flask, Response
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY, CONTENT_TYPE_LATEST
import time

app = Flask(__name__)

# Custom metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP request latency', ['method', 'endpoint'])

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    latency = time.time() - request.start_time
    REQUEST_COUNT.labels(request.method, request.path, response.status_code).inc()
    REQUEST_LATENCY.labels(request.method, request.path).observe(latency)
    return response

@app.route('/metrics')
def metrics():
    return Response(generate_latest(REGISTRY), mimetype=CONTENT_TYPE_LATEST)

@app.route('/health')
def health():
    return {'status': 'healthy'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

#### Go (using promhttp)

```go
package main

import (
    "net/http"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "path", "status"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestsTotal)
}

func main() {
    http.Handle("/metrics", promhttp.Handler())
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.Write([]byte(`{"status":"healthy"}`))
    })
    http.ListenAndServe(":8080", nil)
}
```

---

### 2. Deploy with Metrics Enabled

#### Option A: Same Port as Application

If your `/metrics` endpoint is on the same port as your app:

```bash
curl -X POST "https://deploy.kubernetes.crianex.com/api/deploy" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $DEPLOY_API_KEY" \
  -d '{
    "app": "my-app",
    "namespace": "apps",
    "image": "registry.kubernetes.crianex.com/my-app:v1.0.0",
    "port": 3000,
    "domain": "my-app.kubernetes.crianex.com",
    "metrics": {
      "port": 3000,
      "path": "/metrics",
      "scrapeInterval": "30s"
    }
  }'
```

> ⚠️ **Warning:** If you expose port 3000 via Ingress AND have metrics on the same port, your `/metrics` endpoint will be publicly accessible. See Option B for a more secure setup.

#### Option B: Dedicated Metrics Port (Recommended)

Run a separate metrics server on a different port to keep metrics internal:

```typescript
// Metrics on separate port (recommended)
import express from 'express';
import { register } from './metrics';

const app = express();
const metricsApp = express();

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

Deploy with separate ports:

```bash
curl -X POST "https://deploy.kubernetes.crianex.com/api/deploy" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $DEPLOY_API_KEY" \
  -d '{
    "app": "my-app",
    "namespace": "apps",
    "image": "registry.kubernetes.crianex.com/my-app:v1.0.0",
    "ports": [
      { "port": 3000, "name": "http" },
      { "port": 9090, "name": "metrics" }
    ],
    "domain": "my-app.kubernetes.crianex.com",
    "metrics": {
      "port": 9090,
      "path": "/metrics",
      "scrapeInterval": "30s"
    }
  }'
```

The Ingress only routes to the first port (3000), keeping metrics internal to the cluster.

---

### 3. GitHub Actions Integration

Update your workflow to include metrics configuration:

```yaml
env:
  METRICS_PORT: "9090"        # Set to enable metrics, leave empty to disable
  METRICS_PATH: "/metrics"
  METRICS_INTERVAL: "30s"
  METRICS_SCHEME: "http"      # Use "https" if your metrics endpoint uses TLS

jobs:
  deploy:
    steps:
      - name: Build and Deploy
        run: |
          payload=$(jq -n \
            --arg app "my-app" \
            --arg namespace "apps" \
            --argjson port 3000 \
            --arg metricsPort "${{ env.METRICS_PORT }}" \
            --arg metricsPath "${{ env.METRICS_PATH }}" \
            --arg metricsInterval "${{ env.METRICS_INTERVAL }}" \
            --arg metricsScheme "${{ env.METRICS_SCHEME }}" \
            '{
              app: $app,
              namespace: $namespace,
              deploy: true,
              deployConfig: (
                { port: $port, replicas: 2 }
                + (if ($metricsPort | length) > 0 then {
                    metrics: {
                      port: ($metricsPort | tonumber),
                      path: $metricsPath,
                      scrapeInterval: $metricsInterval,
                      scheme: $metricsScheme
                    }
                  } else {} end)
              )
            }')
          # ... rest of deploy logic
```

---

## What Gets Created

When you deploy with `metrics` configuration, the Deploy API creates:

### 1. Pod Annotations

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
    prometheus.io/scheme: "http"
```

### 2. ServiceMonitor (if Prometheus Operator is installed)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: apps
  labels:
    app: my-app
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      path: /metrics
      interval: 30s
      scheme: http
  namespaceSelector:
    matchNames:
      - apps
```

### 3. Service Port

The metrics port is automatically added to the Service, even if not specified in your `ports` array:

```yaml
spec:
  ports:
    - name: http
      port: 80
      targetPort: 3000
    - name: metrics
      port: 9090
      targetPort: 9090
```

---

## Viewing Metrics in Grafana

### 1. Access Grafana

**URL:** https://grafana.kubernetes.crianex.com

```bash
# Get credentials
echo "Username: admin"
echo "Password: $(kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 --decode)"
```

### 2. Verify Prometheus is Scraping Your App

1. Go to **Explore** → Select **Prometheus** datasource
2. Query: `up{job="my-app"}` or `up{namespace="apps"}`
3. If value is `1`, scraping is working

### 3. Query Your Custom Metrics

```promql
# Total requests
http_requests_total{app="my-app"}

# Request rate (per second over last 5 minutes)
rate(http_requests_total{app="my-app"}[5m])

# 95th percentile latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="my-app"}[5m]))

# Error rate
sum(rate(http_requests_total{app="my-app", status=~"5.."}[5m])) 
/ 
sum(rate(http_requests_total{app="my-app"}[5m]))
```

### 4. Create a Dashboard

1. Go to **Dashboards** → **New** → **New Dashboard**
2. Add panels with your metrics queries
3. Or import a pre-built dashboard (Dashboard ID `1860` for Node Exporter, etc.)

#### Auto-Sync Dashboard from Repository (Recommended)

Instead of manually creating dashboards, you can add a `grafana-dashboard.json` file to your repository. It will be **automatically uploaded to Grafana** on each deploy!

1. Design your dashboard in Grafana
2. Go to **Dashboard Settings** → **JSON Model**
3. Copy the JSON and save as `grafana-dashboard.json` in your repo root
4. On next deploy, the dashboard is synced automatically

📖 **See:** [Templates README - Grafana Dashboard Auto-Sync](../templates/README.md#optional-grafana-dashboard-auto-sync)

---

## Metrics Configuration Reference

| Field           | Type   | Default    | Description                                       |
| --------------- | ------ | ---------- | ------------------------------------------------- |
| `port`          | number | (required) | Port where `/metrics` is exposed                  |
| `path`          | string | `/metrics` | Path to the metrics endpoint                      |
| `scrapeInterval`| string | `30s`      | How often Prometheus scrapes (e.g., `15s`, `1m`)  |
| `scheme`        | string | `http`     | Protocol: `http` or `https`                       |

---

## Troubleshooting

### Metrics Not Appearing in Prometheus

1. **Check pod annotations:**
   ```bash
   kubectl get pod -n apps -l app=my-app -o jsonpath='{.items[0].metadata.annotations}' | jq .
   ```
   Should include `prometheus.io/scrape: "true"`

2. **Check ServiceMonitor exists:**
   ```bash
   kubectl get servicemonitor -n apps my-app
   ```

3. **Check Prometheus targets:**
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
   ```
   Open http://localhost:9090/targets and look for your app

4. **Test metrics endpoint directly:**
   ```bash
   kubectl port-forward -n apps svc/my-app 9090:9090
   curl http://localhost:9090/metrics
   ```

### ServiceMonitor Not Being Picked Up

Prometheus Operator uses label selectors. Ensure your ServiceMonitor has the correct labels:

```bash
# Check Prometheus serviceMonitorSelector
kubectl get prometheus -n monitoring -o yaml | grep -A5 serviceMonitorSelector
```

### Metrics Endpoint Returns Empty

- Ensure you're collecting metrics before the endpoint is scraped
- Check that your metrics library is properly initialized
- Verify the metrics registry is being exported correctly

### High Cardinality Warning

Avoid using high-cardinality labels (like user IDs or request IDs) in metrics:

```typescript
// ❌ Bad - creates too many time series
httpRequestsTotal.inc({ userId: req.userId });

// ✅ Good - bounded cardinality
httpRequestsTotal.inc({ method: req.method, status: res.statusCode });
```

---

## Best Practices

1. **Use a dedicated metrics port** to keep metrics internal
2. **Keep label cardinality low** (avoid user IDs, session IDs, etc.)
3. **Use histograms for latency** instead of gauges
4. **Set appropriate scrape intervals** (15-60s is typical)
5. **Add meaningful labels** that help with querying and alerting
6. **Include a `/health` endpoint** separately from `/metrics`

---

## Related Documentation

- [Monitoring Stack README](./README.md) - Cluster monitoring infrastructure
- [Monitoring Setup Guide](./SETUP_GUIDE.md) - How to set up Prometheus/Grafana/Loki
- [API Reference](../../deploy-api-server/docs/API_REFERENCE.md) - Full Deploy API documentation
- [Migration Guide](../migration_docs/MIGRATION_TO_KUBERNETES.md) - Migrating from Docker to Kubernetes
