# Centralized Logging with EFK Stack

## Overview

The cluster uses **EFK Stack** (Elasticsearch, Fluent Bit, Kibana) for centralized log aggregation and analysis across all Kubernetes namespaces.

**Components:**
- **Elasticsearch**: Log storage and indexing
- **Fluent Bit**: Lightweight log collector (DaemonSet)
- **Kibana**: Log visualization and search UI

**Why Centralized Logging:**
- Debug issues across multiple pods
- Search logs by namespace, pod, container
- Analyze patterns and trends
- Retain logs after pod restarts
- JSON field extraction and parsing

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│ Kubernetes Nodes                                      │
│                                                       │
│  ┌────────┐  ┌────────┐  ┌────────┐                 │
│  │ Pod 1  │  │ Pod 2  │  │ Pod 3  │                 │
│  │ stdout │  │ stdout │  │ stdout │                 │
│  └───┬────┘  └───┬────┘  └───┬────┘                 │
│      │           │           │                       │
│      └───────────┼───────────┘                       │
│                  │                                   │
│          ┌───────▼────────┐                          │
│          │  Fluent Bit    │ (DaemonSet)              │
│          │  - Read logs   │                          │
│          │  - Parse JSON  │                          │
│          │  - Add K8s     │                          │
│          │    metadata    │                          │
│          └───────┬────────┘                          │
└──────────────────┼───────────────────────────────────┘
                   │
                   ▼
           ┌───────────────┐
           │ Elasticsearch │ (logging namespace)
           │  - Index logs │
           │  - Store 10GB │
           └───────┬───────┘
                   │
                   ▼
           ┌───────────────┐
           │    Kibana     │
           │  - Search UI  │
           │  - Visualize  │
           └───────────────┘
                   │
                   ▼
        http://localhost:5601
```

---

## Installation

### Prerequisites

- EKS cluster running with **t3.medium** nodes (4GB RAM per node)
- Helm 3+ installed
- kubectl configured

### Deploy EFK Stack

```bash
# Automated installation
./scripts/install-logging.sh
```

**Manual installation:**

```bash
# Create namespace
kubectl create namespace logging

# Add Helm repos
helm repo add elastic https://helm.elastic.co
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# Install Elasticsearch
helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --values k8s/logging/elasticsearch-values.yaml \
  --wait

# Install Kibana
helm install kibana elastic/kibana \
  --namespace logging \
  --values k8s/logging/kibana-values.yaml \
  --wait

# Install Fluent Bit
helm install fluent-bit fluent/fluent-bit \
  --namespace logging \
  --values k8s/logging/fluent-bit-values.yaml \
  --wait
```

**Verify deployment:**

```bash
kubectl get pods -n logging

# Expected output:
# NAME                            READY   STATUS
# elasticsearch-master-0          1/1     Running
# kibana-kibana-xxxxx             1/1     Running
# fluent-bit-xxxxx                1/1     Running (1 per node)
```

---

## Accessing Kibana

### Quick Access

```bash
./scripts/access-kibana.sh

# Opens port-forward to localhost:5601
# Open http://localhost:5601
```

### Manual Access

```bash
kubectl port-forward -n logging svc/kibana-kibana 5601:5601

# Open http://localhost:5601
```

---

## First-Time Setup

### 1. Create Index Pattern

After accessing Kibana:

1. Navigate to **Stack Management** (gear icon in sidebar)
2. Click **Index Patterns** under Kibana
3. Click **Create index pattern**
4. Enter: `logstash-*`
5. Click **Next step**
6. Select time field: `@timestamp`
7. Click **Create index pattern**

### 2. View Logs

1. Click **Discover** (compass icon in sidebar)
2. Select index pattern: `logstash-*`
3. Logs will appear in chronological order

---

## Querying Logs

### Basic Queries

**Logs from specific namespace:**
```
kubernetes.namespace_name: "dev"
```

**Logs from specific pod:**
```
kubernetes.pod_name: "sre-demo-service-*"
```

**Logs from specific container:**
```
kubernetes.container_name: "sre-demo-service"
```

**Combine filters:**
```
kubernetes.namespace_name: "prod" AND kubernetes.pod_name: "sre-demo-service-*"
```

### Advanced Queries

**Error logs:**
```
level: "error"
```

**HTTP requests:**
```
endpoint: "/health"
```

**Status codes:**
```
status_code: 500
```

**Time range:**
```
@timestamp: [now-15m TO now]
```

**Complex query:**
```
kubernetes.namespace_name: "prod" AND level: "error" AND status_code: 500
```

**Wildcard search:**
```
message: *timeout*
```

**Range query:**
```
response_time: [100 TO 500]
```

---

## JSON Field Parsing

Fluent Bit automatically parses JSON logs and extracts fields.

### Example Application Log

**Raw log output (JSON):**
```json
{
  "timestamp": "2024-01-15T10:30:45Z",
  "level": "info",
  "endpoint": "/health",
  "method": "GET",
  "status_code": 200,
  "response_time": 5,
  "message": "Health check successful"
}
```

**Indexed fields in Elasticsearch:**
- `timestamp`
- `level`
- `endpoint`
- `method`
- `status_code`
- `response_time`
- `message`
- `kubernetes.namespace_name`
- `kubernetes.pod_name`
- `kubernetes.container_name`
- `kubernetes.labels.*`

**Query by any field:**
```
status_code: 200 AND response_time: >10
```

---

## Kubernetes Metadata

Fluent Bit enriches every log with Kubernetes metadata:

| Field | Description | Example |
|-------|-------------|---------|
| `kubernetes.namespace_name` | Namespace | `dev` |
| `kubernetes.pod_name` | Pod name | `sre-demo-service-abc123` |
| `kubernetes.container_name` | Container | `sre-demo-service` |
| `kubernetes.host` | Node name | `ip-10-0-1-5.ec2.internal` |
| `kubernetes.labels.app` | App label | `sre-demo-service` |
| `kubernetes.labels.environment` | Env label | `dev` |

---

## Common Use Cases

### 1. Debug Pod Issues

```
kubernetes.pod_name: "sre-demo-service-abc123" AND level: "error"
```

### 2. Monitor All Errors

```
level: "error" OR level: "fatal"
```

### 3. Track API Requests

```
endpoint: "/api/*" AND method: "POST"
```

### 4. Performance Analysis

```
response_time: >1000
```

Sort by `response_time` descending to find slowest requests.

### 5. Security Monitoring

```
kubernetes.namespace_name: "prod" AND (status_code: 401 OR status_code: 403)
```

### 6. Application Startup

```
message: *started* OR message: *listening*
```

### 7. Memory Leaks

```
message: *out of memory* OR message: *OOM*
```

---

## Visualization

### Create Dashboard

1. Navigate to **Dashboard**
2. Click **Create dashboard**
3. Click **Create visualization**

**Example visualizations:**

**Request Rate by Namespace:**
- Type: Line chart
- Y-axis: Count
- X-axis: @timestamp
- Split series: kubernetes.namespace_name

**Error Rate:**
- Type: Metric
- Aggregation: Count
- Filter: level: "error"

**Top Endpoints:**
- Type: Pie chart
- Slice by: endpoint.keyword
- Metric: Count

---

## Configuration Details

### Elasticsearch

Configuration: [k8s/logging/elasticsearch-values.yaml](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/k8s/logging/elasticsearch-values.yaml)

- **Replicas**: 1 (single-node for demo)
- **Storage**: 10GB persistent volume
- **Memory**: 1GB (512MB JVM heap)
- **CPU**: 500m request, 1000m limit

### Fluent Bit

Configuration: [k8s/logging/fluent-bit-values.yaml](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/k8s/logging/fluent-bit-values.yaml)

- **Deployment**: DaemonSet (1 pod per node)
- **Inputs**: Read from `/var/log/containers/*.log`
- **Filters**: 
  - Kubernetes metadata enrichment
  - JSON parsing
- **Output**: Elasticsearch in logstash format

### Kibana

Configuration: [k8s/logging/kibana-values.yaml](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/k8s/logging/kibana-values.yaml)

- **Memory**: 512MB
- **CPU**: 200m request, 500m limit
- **Elasticsearch URL**: `http://elasticsearch-master:9200`

---

## Resource Usage

| Component | CPU | Memory | Storage | Replicas |
|-----------|-----|--------|---------|----------|
| Elasticsearch | 500-1000m | 1-2GB | 10GB PV | 1 |
| Kibana | 200-500m | 512MB-1GB | - | 1 |
| Fluent Bit | 100m/node | 128MB/node | - | 1/node |
| **Total** | ~1-1.7 CPU | ~1.6-3.1GB | 10GB | 2+nodes |

---

## Troubleshooting

### No Logs in Kibana

**1. Check Fluent Bit pods:**
```bash
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit

# Should see 1 pod per node, all Running
```

**2. Check Fluent Bit logs:**
```bash
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=50

# Look for connection errors to Elasticsearch
```

**3. Verify Elasticsearch is ready:**
```bash
kubectl get pods -n logging -l app=elasticsearch-master

# Should be Running with 1/1 ready
```

**4. Check Elasticsearch indices:**
```bash
kubectl exec -n logging elasticsearch-master-0 -- curl -s localhost:9200/_cat/indices

# Should see logstash-* indices
```

### Index Pattern Not Found

**Create it manually:**
1. Stack Management > Index Patterns
2. Create pattern: `logstash-*`
3. Time field: `@timestamp`

### Elasticsearch Pod Pending

**Check storage:**
```bash
kubectl get pvc -n logging

# PVC should be Bound
kubectl describe pvc -n logging
```

**If storage issue:**
- Ensure StorageClass exists: `kubectl get storageclass`
- On EKS, `gp2` is default

### Fluent Bit Not Collecting Logs

**Check permissions:**
```bash
kubectl describe pod -n logging -l app.kubernetes.io/name=fluent-bit

# Check for permission errors
```

**Verify configuration:**
```bash
kubectl get configmap -n logging fluent-bit -o yaml
```

### High Memory Usage

**Reduce Elasticsearch heap:**

Edit `k8s/logging/elasticsearch-values.yaml`:
```yaml
esJavaOpts: "-Xmx256m -Xms256m"  # Reduce from 512m
```

Upgrade:
```bash
helm upgrade elasticsearch elastic/elasticsearch \
  --namespace logging \
  --values k8s/logging/elasticsearch-values.yaml
```

---

## Cleanup

### Uninstall EFK Stack

```bash
helm uninstall elasticsearch -n logging
helm uninstall kibana -n logging
helm uninstall fluent-bit -n logging

# Delete namespace (also deletes PVCs)
kubectl delete namespace logging
```

### Delete PVC Only

```bash
kubectl delete pvc -n logging elasticsearch-master-elasticsearch-master-0
```

---

## Production Considerations

### Security

**Enable X-Pack Security:**
```yaml
# elasticsearch-values.yaml
xpack:
  security:
    enabled: true
```

**Set Kibana password:**
```bash
kubectl exec -n logging elasticsearch-master-0 -- \
  bin/elasticsearch-setup-passwords auto
```

### High Availability

**3-node Elasticsearch cluster:**
```yaml
# elasticsearch-values.yaml
replicas: 3
minimumMasterNodes: 2
```

### Performance

**Increase resources for production:**
```yaml
resources:
  requests:
    cpu: "2000m"
    memory: "4Gi"
  limits:
    cpu: "4000m"
    memory: "8Gi"

esJavaOpts: "-Xmx2g -Xms2g"
```

### Retention

**Curator for log rotation:**
- Install Elasticsearch Curator
- Delete indices older than X days
- Reduce storage costs

---

## Scenario-Based Interview Questions

###  Scenario 1: Logs Not Appearing in Kibana

**Situation**: Kibana shows no logs for the dev namespace.

**Debugging approach:**
> "First, verify Fluent Bit is running on all nodes: `kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit`. Then check Fluent Bit logs for errors: `kubectl logs -n logging fluent-bit-xxxxx --tail=100`. Look for 'connection refused' to Elasticsearch. Verify Elasticsearch is accessible from Fluent Bit: `kubectl exec -n logging fluent-bit-xxxxx -- curl http://elasticsearch-master:9200`. Check if logs exist in Elasticsearch: `kubectl exec -n logging elasticsearch-master-0 -- curl localhost:9200/_cat/indices` - you should see logstash indices. If indices exist but Kibana shows no data, recreate the index pattern in Kibana."

### Scenario 2: High Elasticsearch Disk Usage

**Situation**: Elasticsearch PVC is 95% full after only 3 days.

**Root cause and solution:**
> "This indicates either excessive log volume or no retention policy. First, check index sizes: `kubectl exec -n logging elasticsearch-master-0 -- curl localhost:9200/_cat/indices?v&s=store.size:desc`. Identify which indices are largest. Check if there's a chatty application logging excessively - query Kibana for log count by namespace. Implement ILM (Index Lifecycle Management) to delete indices older than 7 days. Consider increasing PV size from 10GB to 20GB. Add log sampling in Fluent Bit to reduce volume - only send 10% of debug logs."

### Scenario 3: JSON Parsing Not Working

**Situation**: Logs appear in Kibana but JSON fields are not parsed.

**How to fix:**
> "The issue is likely with Fluent Bit's JSON parser configuration. Check if logs are actually in JSON format: view raw logs in Kibana and look at the 'log' field. If it's a JSON string, the parser isn't configured correctly. Verify Fluent Bit values.yaml has the JSON parser in filters section. The parser must be applied AFTER the Kubernetes filter. Test the parser: `kubectl exec -n logging  fluent-bit-xxxxx -- cat /fluent-bit/etc/parsers.conf` to see if JSON parser exists. If not, update values.yaml and upgrade the Helm release."

### Scenario 4: Correlating Logs with Metrics

**Situation**: Grafana shows latency spike at 14:30, need to find related logs.

**Investigation steps:**
> "First, note the exact timestamp range from Grafana (e.g., 14:30-14:35). In Kibana, set the time range to that window. Query for the specific namespace and pod: `kubernetes.namespace_name: 'prod' AND kubernetes.pod_name: 'sre-demo-service-*' AND @timestamp: [14:30 TO 14:35]`. Look for error-level logs or high response times. Sort by response_time descending to find slowest requests. Check for patterns - are all errors on one endpoint? Is it affecting one pod or all? Correlate with Prometheus: query `rate(http_requests_total{namespace='prod',status!='OK'}[5m])` at that time to confirm error rate spike."

### Scenario 5: Fluent Bit Memory Leak

**Situation**: Fluent Bit pods consuming 1GB+ memory each.

**Diagnosis and fix:**
> "Fluent Bit should use approximately 100-200MB. High memory indicates buffering issues or misconfiguration. Check if Elasticsearch is reachable - if logs can't be shipped, they buffer in memory. Verify: `kubectl logs -n logging fluent-bit-xxxxx | grep -i error`. Check Fluent Bit backpressure settings in values.yaml - ensure `Mem_Buf_Limit` is set (e.g., `5MB`). If memory grows continuously, it's a leak - restart pods: `kubectl delete pod -n logging -l app.kubernetes.io/name=fluent-bit`. Consider downgrading Fluent Bit version if issue persists - check GitHub issues for known memory leaks."

---

## Interview Talking Points

**Q: Why EFK instead of CloudWatch Logs?**

> "EFK gives me more control and flexibility. CloudWatch Logs is great for AWS services, but EFK excels at Kubernetes-native logging. Fluent Bit automatically enriches logs with pod, namespace, and label metadata. The query language is more powerful, and I can create custom dashboards. For a complete solution, I'd use both - EFK for application logs, CloudWatch for infrastructure."

**Q: Why Fluent Bit instead of Fluentd?**

> "Fluent Bit is more resource-efficient. It uses 450MB less memory per node compared to Fluentd. For a DaemonSet running on every node, this adds up. Fluent Bit is purpose-built for forwarding, while Fluentd is better for complex transformations. For our use case - collect, parse JSON, send to Elasticsearch - Fluent Bit is the right tool."

**Q: How does JSON parsing work?**

> "Fluent Bit has a JSON parser filter. When it reads a log line, it attempts to parse it as JSON. If successful, it extracts all fields into the log record. Combined with the Kubernetes filter, each log entry has both application fields and Kubernetes metadata. This enables queries like 'find all error logs from prod namespace' - combining app-level and cluster-level information."

**Q: What about log retention and storage costs?** > "I've configured 10GB storage with no retention policy for this demo. In production, I'd use Index Lifecycle Management (ILM) to automatically delete old indices. For example, keep hot data for 7 days on fast storage, move to warm storage for 30 days, then delete. This balances debugging needs with costs. Alternative: archive to S3 for compliance."
