# Kubernetes Monitoring Stack

Complete observability setup for the k3s cluster with Prometheus, Grafana, Loki, and Promtail.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Monitoring Architecture                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Node: projeto │     │ Node: colima    │     │ Node: servidor  │
│   (master)      │     │ (worker)        │     │ (worker)        │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ • node-exporter │     │ • node-exporter │     │ • node-exporter │
│ • promtail      │     │ • promtail      │     │ • promtail      │
│                 │     │                 │     │                 │
│                 │     │ ┌─────────────┐ │     │                 │
│                 │     │ │ Prometheus  │ │     │                 │
│                 │     │ │ Grafana     │ │     │                 │
│                 │     │ │ Loki        │ │     │                 │
│                 │     │ │ Alertmanager│ │     │                 │
│                 │     │ └─────────────┘ │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │  Traefik Ingress    │
                    │  + Let's Encrypt    │
                    └─────────────────────┘
                               │
                               ▼
                    https://grafana.kubernetes.crianex.com
```

## Components

| Component              | Purpose                         | Runs On                          |
| ---------------------- | ------------------------------- | -------------------------------- |
| **Prometheus**         | Metrics collection and storage  | Worker nodes (`role=monitoring`) |
| **Grafana**            | Dashboards and visualization    | Worker nodes (`role=monitoring`) |
| **Alertmanager**       | Alert routing and notifications | Worker nodes (`role=monitoring`) |
| **Loki**               | Log aggregation backend         | Worker nodes (`role=monitoring`) |
| **Promtail**           | Log collection agent            | All nodes (DaemonSet)            |
| **Node Exporter**      | Node-level metrics              | All nodes (DaemonSet)            |
| **kube-state-metrics** | Kubernetes object metrics       | Worker nodes (`role=monitoring`) |

## Storage

All monitoring data is stored on worker nodes using local persistent volumes:

| PV Name               | Size | Path                   | Used By    |
| --------------------- | ---- | ---------------------- | ---------- |
| `prometheus-local-pv` | 30Gi | `/mnt/prometheus-data` | Prometheus |
| `grafana-local-pv`    | 5Gi  | `/mnt/grafana-data`    | Grafana    |
| `loki-storage-pv`     | 20Gi | `/mnt/loki-data`       | Loki       |

## Access

### Grafana Dashboard

**URL:** https://grafana.kubernetes.crianex.com

**Get credentials:**
```bash
echo "Username: admin"
echo "Password: $(kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 --decode)"
```

### Port Forwarding (Alternative)

```bash
# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Loki
kubectl port-forward -n monitoring svc/loki 3100:3100
```

## Quick Commands

```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Check pod placement (should be on worker nodes)
kubectl get pods -n monitoring -o wide

# View Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Then open http://localhost:9090/targets

# Check Loki health
kubectl exec -n monitoring loki-0 -- wget -qO- http://localhost:3100/ready

# View Promtail logs
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=50

# Restart a component
kubectl rollout restart deployment prometheus-grafana -n monitoring
kubectl rollout restart statefulset loki -n monitoring
```

## Useful Loki Queries

Use these in Grafana Explore with the Loki datasource:

```logql
# All logs from a namespace
{namespace="monitoring"}
{namespace="default"}

# Logs from a specific app
{app="prometheus"}
{app="loki"}

# Filter for errors
{namespace="default"} |= "error"
{namespace="default"} |= "Error" or |= "ERROR"

# Logs from a specific node
{node_name="colima"}
{node_name="projeto"}

# Logs from a specific pod
{pod="myapp-12345"}

# JSON parsing
{namespace="default"} | json | level="error"

# Rate of log lines
rate({namespace="default"}[5m])
```

## Recommended Dashboards

Import these in Grafana (Dashboards → Import → Enter ID):

| Dashboard ID | Name                          | Purpose                  |
| ------------ | ----------------------------- | ------------------------ |
| `1860`       | Node Exporter Full            | Detailed node metrics    |
| `315`        | Kubernetes cluster monitoring | Cluster overview         |
| `13639`      | Loki & Promtail               | Log statistics           |
| `7249`       | Kubernetes Cluster            | Alternative cluster view |

### Builds Dashboard

The custom Builds dashboard (`builds-dashboard.json`) tracks in-cluster Kaniko builds and deployed workloads. It uses a **`workload_ns`** template variable (default `apps|non-business-apps`) so you can filter panels by workload namespace. Switch between `apps`, `non-business-apps`, or view both at once.

## Troubleshooting

### Pods stuck in Pending

```bash
# Check why pod isn't scheduling
kubectl describe pod <pod-name> -n monitoring | tail -30

# Common causes:
# - Node selector not matching: Check node labels
# - PVC not binding: Check PV availability
# - Resource constraints: Check node resources
```

### Loki not receiving logs

```bash
# Check Promtail is running on all nodes
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail -o wide

# Check Promtail logs for errors
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=100

# Test Loki API
kubectl exec -n monitoring loki-0 -- wget -qO- http://localhost:3100/loki/api/v1/labels
```

### Grafana datasource issues

```bash
# Verify Loki service exists
kubectl get svc -n monitoring loki

# Test connectivity from Grafana pod
kubectl exec -n monitoring -l app.kubernetes.io/name=grafana -- \
  wget -qO- http://loki.monitoring.svc.cluster.local:3100/ready
```

### Certificate issues

```bash
# Check certificate status
kubectl get certificate -n monitoring

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50

# Describe certificate for details
kubectl describe certificate grafana-tls -n monitoring
```

## Maintenance

### Data Retention

- **Prometheus:** 15 days (configurable in Helm values)
- **Loki:** 7 days (168h, configurable in Helm values)

### Backup

The persistent volumes use `Retain` reclaim policy, so data persists even if PVCs are deleted.

To backup data:
```bash
# On the worker node
tar -czvf prometheus-backup.tar.gz /mnt/prometheus-data
tar -czvf loki-backup.tar.gz /mnt/loki-data
tar -czvf grafana-backup.tar.gz /mnt/grafana-data
```

### Upgrading

```bash
# Update Helm repos
helm repo update

# Upgrade Prometheus stack
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values.yaml

# Upgrade Loki
helm upgrade loki grafana/loki \
  --namespace monitoring \
  --values loki-values.yaml

# Upgrade Promtail
helm upgrade promtail grafana/promtail \
  --namespace monitoring \
  --values promtail-values.yaml
```

## Files Reference

| File                     | Purpose                                       |
| ------------------------ | --------------------------------------------- |
| `storage.yaml`           | PV and StorageClass definitions               |
| `prometheus-values.yaml` | Prometheus stack Helm values                  |
| `loki-values.yaml`       | Loki Helm values                              |
| `promtail-values.yaml`   | Promtail Helm values                          |
| `grafana-ingress.yaml`   | Ingress for external Grafana access           |
| `APP_METRICS_GUIDE.md`   | How to add metrics to your deployed apps      |

## Related Documentation

- [Application Metrics Guide](./APP_METRICS_GUIDE.md) - Add Prometheus metrics to your apps
- [Setup Guide](./SETUP_GUIDE.md) - Step-by-step monitoring stack installation
- [Migration Guide](../migration_docs/MIGRATION_TO_KUBERNETES.md) - Migrating from Docker to Kubernetes
