# Observability & Monitoring Stack

## Overview

The cluster includes a comprehensive monitoring solution using **kube-prometheus-stack**, which combines Prometheus for metrics collection and Grafana for visualization.

**Why Observ ability Matters for SRE:**
- Measure SLIs (Service Level Indicators) for SLO tracking
- Detect issues before they impact users
- Debug performance problems with data, not guesses
- Capacity planning based on actual usage
- Audit trail for incident postmortems

---

## Components Deployed

| Component | Purpose | Default Metrics |
|-----------|---------|-----------------|
| **Prometheus** | Time-series metrics storage & querying | Cluster, Node, Pod metrics |
| **Grafana** | Visualization dashboards | 20+ pre-built K8s dashboards |
| **Kube State Metrics** | Kubernetes object metrics | Deployments, Pods, Services status |
| **Node Exporter** | Node-level system metrics | CPU, Memory, Disk, Network per node |
| **Prometheus Operator** | Manages Prometheus CRDs | ServiceMonitor, PodMonitor automation |

---

## Installation

**Prerequisites:**
- EKS cluster running
- Helm 3+ installed
- kubectl configured

**Deploy Monitoring Stack:**

```bash
# Automated installation
./scripts/install-monitoring.sh

# Manual installation
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values k8s/monitoring/values.yaml \
  --wait
```

**What Gets Deployed:**
- Namespace: `monitoring`
- Pods: Prometheus, Grafana, Kube-State-Metrics, Node-Exporters (1 per node)
- Services: ClusterIP for Prometheus (9090) and Grafana (80)
- Storage: 10GB for Prometheus metrics, 5GB for Grafana dashboards

---

## Configuration

Our configuration ([k8s/monitoring/values.yaml](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/k8s/monitoring/values.yaml)):

**Prometheus:**
```yaml
retention: 7d              # Keep metrics for 7 days
retentionSize: 9GB         # Max storage before oldest data pruned
storage: 10Gi              # Persistent volume size

resources:
  requests:
    cpu: 200m
    memory: 1Gi
  limits:
    cpu: 500m
    memory: 2Gi
```

**Grafana:**
```yaml
adminPassword: admin123    # Change in production
persistence:
  enabled: true
  size: 5Gi

resources:
  requests:
    cpu: 100m
    memory: 256Mi
```

**Why These Values:**
- **7-day retention**: Balance between debugging historical issues and storage costs
- **10GB storage**: ~500,000 samples/second with 7-day retention
- **Resource limits**: Prevent monitoring from consuming excessive cluster resources

---

## Accessing Dashboards

### Grafana

**Quick Access:**
```bash
./scripts/access-grafana.sh

# Opens port-forward to localhost:3000
# Displays credentials: admin / admin123
```

**Manual Access:**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open http://localhost:3000
# Login: admin / admin123
```

**Pre-built Dashboards:**
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods)
- Kubernetes / Compute Resources / Pod
- Kubernetes / Networking / Cluster
- Node Exporter / Nodes
- And 15+ more

### Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open http://localhost:9090
```

**Use Cases:**
- Query metrics directly with PromQL
- Check target health (Status > Targets)
- Debug alerting rules (Alerts)
- View metric metadata (Status > Configuration)

---

## Metrics Collected

### Cluster-Level Metrics

**From Kubernetes API (Kube State Metrics):**
```promql
# Pod status by namespace
kube_pod_status_phase{namespace="dev"}

# Deployment replica status
kube_deployment_status_replicas{deployment="sre-demo-service"}

# Node conditions
kube_node_status_condition{condition="Ready"}

# ResourceQuota usage
kube_resourcequota{namespace="dev"}
```

**From Nodes (Node Exporter):**
```promql
# CPU usage per node
rate(node_cpu_seconds_total{mode="user"}[5m])

# Memory usage
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Disk I/O
rate(node_disk_io_time_seconds_total[5m])

# Network traffic
rate(node_network_receive_bytes_total[5m])
```

### Application Metrics (SRE Demo Service)

Our Go service exposes custom metrics:

```promql
# Request rate
rate(http_requests_total{namespace="dev"}[5m])

# Error rate
rate(http_requests_total{status!="OK"}[5m])

# p95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Memory usage
memory_allocations_bytes

# Active connections
active_connections
```

---

## Common Queries

### SLI Tracking (RED Method)

```promql
# Rate - Requests per second
sum(rate(http_requests_total[5m])) by (namespace)

# Errors - Error rate
sum(rate(http_requests_total{status!="OK"}[5m])) by (namespace)
/ sum(rate(http_requests_total[5m])) by (namespace)

# Duration - p99 latency
histogram_quantile(0.99, 
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le, namespace)
)
```

### Capacity Planning

```promql
# CPU utilization by namespace
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)
/ sum(kube_pod_container_resource_requests{resource="cpu"}) by (namespace)
* 100

# Memory utilization by namespace
sum(container_memory_working_set_bytes) by (namespace)
/ sum(kube_pod_container_resource_requests{resource="memory"}) by (namespace)
* 100

# Pod count vs quota
kube_pod_info / kube_resourcequota{resource="pods"} * 100
```

### HPA Monitoring

```promql
# Current vs desired replicas
kube_horizontalpodautoscaler_status_current_replicas{namespace="dev"}
/ kube_horizontalpodautoscaler_spec_max_replicas{namespace="dev"}
* 100

# CPU metrics driving HPA
sum(rate(container_cpu_usage_seconds_total{namespace="dev"}[5m]))
```

---

## Creating Custom Dashboards

**Example: SRE Demo Service Dashboard**

1. **Navigate to Grafana** (port-forward to 3000)
2. **Create Dashboard** (+ icon > Dashboard)
3. **Add Panels:**

**Panel 1: Request Rate**
```promql
sum(rate(http_requests_total{namespace="dev"}[5m])) by (endpoint)
```
- Visualization: Time series (line graph)
- Unit: requests/sec
- Legend: {{endpoint}}

**Panel 2: Error Rate**
```promql
sum(rate(http_requests_total{namespace="dev",status!="OK"}[5m]))
/ sum(rate(http_requests_total{namespace="dev"}[5m]))
* 100
```
- Visualization: Stat (big number)
- Unit: Percent (0-100)
- Threshold: Green < 1%, Yellow 1-5%, Red > 5%

**Panel 3: P95 Latency**
```promql
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{namespace="dev"}[5m])) by (le)
)
```
- Visualization: Gauge
- Unit: Seconds
- Threshold: Green < 0.1s, Yellow 0.1-0.5s, Red > 0.5s

**Panel 4: Active Pods**
```promql
count(kube_pod_info{namespace="dev",pod=~"sre-demo-service.*"})
```
- Visualization: Stat
- Shows current pod count vs HPA min/max

---

## Alerting (Optional Enhancement)

While AlertManager is disabled in our demo setup, here's how you'd configure production alerts:

**Example Alert Rules:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: sre-demo-alerts
  namespace: monitoring
spec:
  groups:
  - name: sre-demo-service
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: |
        sum(rate(http_requests_total{status!="OK"}[5m]))
        / sum(rate(http_requests_total[5m]))
        * 100 > 5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate in {{ $labels.namespace }}"
        description: "Error rate is {{ $value }}% (threshold: 5%)"
    
    - alert: HighLatency
      expr: |
        histogram_quantile(0.95,
          sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
        ) > 0.5
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "High latency detected"
        description: "P95 latency is {{ $value }}s (threshold: 0.5s)"
```

---

## Resource Usage

**Expected Consumption:**

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| Prometheus | 200-400m | 1-2GB | 10GB |
| Grafana | 100-150m | 256-512MB | 5GB |
| Kube State Metrics | 10-20m | 128MB | - |
| Node Exporter (per node) | 50m | 64MB | - |
| **Total** | ~500-700m | ~1.5-2.5GB | 15GB |

**Cost Impact:**
- Minimal for t3.small nodes (2 vCPU, 2GB RAM)
- Approximately 25-35% of node capacity
- Well worth it for the observability gained

---

## Verification Steps

**1. Check All Pods Running:**
```bash
kubectl get pods -n monitoring

# Expected output (all Running):
# prometheus-kube-prometheus-prometheus-0
# prometheus-grafana-xxxxx
# prometheus-kube-state-metrics-xxxxx
# prometheus-prometheus-node-exporter-xxxxx (one per node)
# prometheus-kube-prometheus-operator-xxxxx
```

**2. Verify Prometheus Targets:**
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open http://localhost:9090/targets
# All targets should show as "UP"
```

**3. Test Grafana Access:**
```bash
./scripts/access-grafana.sh

# Should display credentials and open port-forward
# Login at http://localhost:3000
# Verify dashboards display metrics
```

**4. Query Your Service Metrics:**
```bash
# Port-forward your service
kubectl port-forward -n dev svc/sre-demo-service 8080:8080

# Generate traffic
curl http://localhost:8080/health
curl http://localhost:8080/metrics

# In Grafana Explore, query:
# http_requests_total{namespace="dev"}
```

---

## Troubleshooting

### No Metrics Appearing

**Symptom:** Dashboards show "No data"

**Solutions:**
```bash
# 1. Check Prometheus is scraping
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/targets - all should be UP

# 2. Verify ServiceMonitors exist
kubectl get servicemonitors -n monitoring

# 3. Check Prometheus logs
kubectl logs -n monitoring prometheus-kube-prometheus-prometheus-0
```

### Grafana Login Issues

**Symptom:** Cannot login to Grafana

**Solutions:**
```bash
# Get password from secret
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d

# Reset password if needed
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana
```

### High Memory Usage

**Symptom:** Prometheus consuming excessive memory

**Solutions:**
1. Reduce retention: Edit `values.yaml`, set `retention: 3d`
2. Increase storage limit: `retentionSize: 9GB` ensures pruning
3. Reduce scrape intervals in ServiceMonitors

---

## Scenario-Based Interview Questions

### Scenario 1: Prometheus Disk Full

**Situation**: Prometheus pod crashes with OOMKilled, disk usage at 100%.

**How to resolve:**
> "First, check retention settings in values.yaml. If `retention: 7d` and `retentionSize: 9GB` but PV is only 10GB, there's no buffer. I'd increase PV size to 15GB or reduce retention to 5 days. Check if there are too many high-cardinality metrics (many unique label combinations) causing excessive storage. Use `promtool tsdb analyze` to identify problematic metrics. Consider adding recording rules to pre-aggregate high-cardinality queries, reducing raw sample storage."

### Scenario 2: ServiceMonitor Not Working

**Situation**: Created ServiceMonitor but Prometheus shows no targets.

**Debugging steps:**
> "First verify the ServiceMonitor has `release: prometheus` label - kube-prometheus-stack only discovers ServiceMonitors with this label. Check if the selector matches the Service labels exactly:  `kubectl get svc -n dev -o yaml | grep labels`. Verify the Service has endpoints: `kubectl get endpoints -n dev`. Check Prometheus config to see if the ServiceMonitor was discovered: port-forward Prometheus, check Status > Configuration. Look for errors in Prometheus operator logs: `kubectl logs -n monitoring prometheus-operator`."

### Scenario 3: Missing Custom Metrics

**Situation**: Grafana shows standard K8s metrics but not application metrics.

**Root cause analysis:**
> "The issue is likely that the Service doesn't have a ServiceMonitor or the ServiceMonitor port doesn't match. Verify the application exposes `/metrics`: `curl pod-ip:8080/metrics`. Check if a ServiceMonitor exists for the service. Verify the port name in ServiceMonitor matches the Service port name (not number). Test the endpoint directly in Prometheus: query `up{job='service-name'}` - if it returns 0 or nothing, Prometheus can't reach it. Check network policies aren't blocking Prometheus."

---

## Interview Talking Points

**Q: Why use Prometheus instead of CloudWatch?**

> "Prometheus is purpose-built for Kubernetes with automatic service discovery and native support for multi-dimensional metrics. CloudWatch is great for AWS resources, but Prometheus excels at container and application metrics. The pull-based model means I can scrape services without configuring each one to push, and PromQL is more powerful than CloudWatch Insights for complex queries. For a complete solution, I'd use both - Prometheus for K8s/app metrics, CloudWatch for AWS infrastructure."

**Q: How does this support SRE practices?**

> "Prometheus enables data-driven SRE. I can define SLIs like request latency and error rate, then track them against SLOs. The histogram metrics support accurate percentile calculations (p95, p99) which are critical for latency SLIs. Combined with Grafana alerting, this creates a feedback loop - monitor SLOs, alert when burning error budget, investigate with dashboards, implement fixes. This is the foundation of error budget management."

**Q: What would you add for production?**

> "For production, I'd enable AlertManager for automated alerting to Slack/PagerDuty. I'd configure remote write to Thanos or Cortex for long-term storage and high availability. I'd implement recording rules to pre-aggregate expensive queries. I'd enable authentication via OAuth or LDAP for Grafana. I'd also set up distributed tracing with Jaeger to complement metrics and logs - that gives you the complete observability stack (metrics, logs, traces)."

**Q: How do you prevent monitoring from impacting performance?**

> "Resource limits prevent monitoring from starving applications. The 7-day retention limits storage growth. I use recording rules to pre-compute expensive aggregations rather than calculating them on every dashboard load. Node exporters are lightweight by design. For very large clusters (100+ nodes), I'd implement federation - multiple Prometheus instances scraping subsets of targets, with a global Prometheus aggregating them."
