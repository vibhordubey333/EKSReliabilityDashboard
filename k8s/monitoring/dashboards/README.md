# Grafana Dashboard Import Guide

## Dashboard Overview

**File**: [sre-demo-system-health.json](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/k8s/monitoring/dashboards/sre-demo-system-health.json)

**Panels Included:**
1. CPU Usage (%)
2. Memory Usage
3. Pod Restarts (1h)
4. Request Rate by Endpoint
5. Error Rate
6. Latency (p95/p99)
7. GC Pause Duration
8. Heap Usage
9. Active Pods

**Multi-Environment Support:**  
Includes namespace variable to switch between dev, qa, and prod

---

## Import Instructions

### Step 1: Access Grafana

```bash
# Start port-forward
./scripts/access-grafana.sh

# Open http://localhost:3000
# Login: admin / admin123
```

### Step 2: Import Dashboard

**Option A: Via UI (Recommended)**

1. Click **+** icon in left sidebar
2. Select **Import**
3. Click **Upload JSON file**
4. Select: `k8s/monitoring/dashboards/sre-demo-system-health.json`
5. Click **Load**
6. Select Prometheus datasource: **prometheus**
7. Click **Import**

**Option B: Copy-Paste JSON**

1. Click **+** icon → **Import**
2. Copy contents of `sre-demo-system-health.json`
3. Paste into text area  
4. Click **Load**
5. Select Prometheus datasource
6. Click **Import**

### Step 3: Select Namespace

At the top of the dashboard, you'll see a dropdown: **Namespace**

- Select **dev** to view dev environment metrics
- Select **qa** to view qa environment metrics
- Select **prod** to view prod environment metrics

---

## Dashboard Panels Explained

### 1. CPU Usage (%)
- **Query**: CPU usage as percentage of requested resources
- **Threshold**: Green < 80%, Red > 80%
- **Shows**: Per-pod CPU utilization

### 2. Memory Usage
- **Query**: Working set memory in bytes
- **Shows**: Current memory consumption per pod
- **Useful for**: Detecting memory leaks

### 3. Pod Restarts (1h)
- **Query**: Number of container restarts in last hour
- **Thresholds**: 
  - Green: 0 restarts
  - Yellow: 1-4 restarts
  - Red: 5+ restarts
- **Alert**: > 0 indicates instability

### 4. Request Rate by Endpoint
- **Query**: HTTP requests per second by endpoint
- **Shows**: Traffic distribution across endpoints
- **Useful for**: Identifying hot paths

### 5. Error Rate
- **Query**: Percentage of failed requests
- **Thresholds**:
  - Green: < 1%
  - Yellow: 1-5%
  - Red: > 5%
- **SLI Metric**: Key indicator for reliability

### 6. Latency (p95/p99)
- **Query**: 95th and 99th percentile response time
- **Thresholds**:
  - Green: < 0.1s
  - Yellow: 0.1-0.5s
  - Red: > 0.5s
- **SLI Metric**: Critical for user experience

### 7. GC Pause Duration
- **Query**: Average garbage collection pause time
- **Shows**: Go runtime GC performance
- **Useful for**: Identifying GC pressure

### 8. Heap Usage
- **Query**: Go heap memory allocation
- **Shows**: Memory trend over time
- **Test**: Use `/leak` endpoint to simulate memory leak

### 9. Active Pods
- **Query**: Number of running pods
- **Shows**: Current replicas
- **Compare with**: HPA min/max settings

---

## Testing the Dashboard

###  1. Generate Traffic

```bash
# Port-forward service
kubectl port-forward -n dev svc/sre-demo-service 8080:8080

# Generate requests
for i in {1..100}; do curl http://localhost:8080/health; done

# Test different endpoints
curl http://localhost:8080/metrics
curl http://localhost:8080/cpu?duration=1000
```

### 2. Test Memory Leak Detection

```bash
# Trigger memory leak
curl "http://localhost:8080/leak?size=100&duration=300"

# Watch Heap Usage panel
# Should show increasing memory allocation
```

### 3. Test Error Rate

```bash
# Generate errors (endpoint doesn't exist)
for i in {1..50}; do curl http://localhost:8080/nonexistent; done

# Error Rate panel should increase
```

### 4. Test Latency

```bash
# Generate slow requests
for i in {1..20}; do curl "http://localhost:8080/cpu?duration=5000"; done

# Latency panel (p95/p99) should spike
```

---

## Switching Between Environments

1. **Top of dashboard**: Namespace dropdown
2. **Select environment**:
   - `dev` - Development environment
   - `qa` - QA/Testing environment
   - `prod` - Production environment
3. **All panels update automatically** to show selected namespace

---

## Customization

### Add New Panel

1. Click **Add panel** (top right)
2. Select **Add a new panel**
3. Enter PromQL query
4. Configure visualization
5. Click **Apply**

### Edit Existing Panel

1. Click panel title → **Edit**
2. Modify query or visualization
3. Click **Apply**
4. Save dashboard

### Export Modified Dashboard

1. Click **Settings** (gear icon, top right)
2. Select **JSON Model**
3. Click **Copy to clipboard**
4. Save to file

---

## Common PromQL Queries

```promql
# Total requests across all pods
sum(rate(http_requests_total{namespace="dev"}[5m]))

# Memory as % of limit
sum(container_memory_working_set_bytes{namespace="dev",pod=~"sre-demo-service.*"}) 
/ sum(kube_pod_container_resource_limits{namespace="dev",pod=~"sre-demo-service.*",resource="memory"})
* 100

# Goroutines count
go_goroutines{namespace="dev",job="sre-demo-service"}

# HTTP 500 errors
sum(rate(http_requests_total{namespace="dev",status=~"5.."}[5m]))
```

---

## Troubleshooting

### No Data Showing

1. **Check ServiceMonitor**:
   ```bash
   kubectl get servicemonitor -n dev
   ```

2. **Verify Prometheus targets**:
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
   # Open http://localhost:9090/targets
   # Look for "sre-demo-service" targets (should be UP)
   ```

3. **Check pods are running**:
   ```bash
   kubectl get pods -n dev -l app=sre-demo-service
   ```

4. **Test /metrics endpoint**:
   ```bash
   kubectl port-forward -n dev svc/sre-demo-service 8080:8080
   curl http://localhost:8080/metrics
   ```

### Metrics Not Updating

- **Refresh interval**: Dashboard refreshes every 10 seconds
- **Time range**: Check time range selector (top right)
- **Namespace variable**: Ensure correct namespace selected

### Panel Shows "No Data"

- **Query**: Click panel → Edit → Check query for errors
- **Metric exists**: Run query in Prometheus UI first
- **Time range**: Expand time range to see historical data

---

## Next Steps

1. **Create alerts**: Set up Prometheus AlertManager rules
2. **Add more panels**: Service-specific metrics
3. **Create SLO dashboard**: Track error budget
4. **Export dashboard**: Save to Git for version control

---

## Scenario-Based Interview Questions

### Scenario 1: High Latency Alert

**Situation**: The dashboard shows p95 latency spiking to 2 seconds (threshold is 0.5s).

**Questions to expect:**
1. How would you investigate this issue using the dashboard?
2. What other panels would you check?
3. How would you determine if it's affecting all pods or just one?

**Answer approach:**
> "I'd start by checking the time correlation - does the latency spike align with CPU or memory spikes? I'd switch the namespace variable between dev/qa/prod to see if it's environment-specific. Then I'd check the Request Rate panel to see if there's a traffic spike. If only one pod shows high latency from the CPU Usage panel, it might be a pod-specific issue. I'd also check Pod Restarts to see if containers are crashing. Finally, I'd correlate with Heap Usage and GC Pause Duration to see if garbage collection is blocking requests."

### Scenario 2: Memory Leak Detection

**Situation**: Production team reports the application becomes slow after 24 hours.

**Questions to expect:**
1. Which panels would help diagnose a memory leak?
2. How would you use the dashboard to confirm it's a leak vs. normal growth?
3. What endpoint could you test to simulate the leak?

**Answer approach:**
> "I'd use the Heap Usage panel and set the time range to 24 hours. A memory leak shows as a continuous upward trend without drops (GC not reclaiming memory). I'd compare this with the Memory Usage panel - if heap grows but working set stays stable, it might not be a leak. The GC Pause Duration panel would show if GC is running more frequently trying to reclaim memory. To test, I'd use the `/leak` endpoint with parameters to simulate allocation, then watch the dashboard. If heap grows continuously without plateauing, that confirms a leak."

### Scenario 3: Error Rate Spike

**Situation**: Error Rate panel suddenly  shows 15% (threshold is 5%).

**Questions to expect:**
1. How would you identify which endpoint is causing errors?
2. How would you determine if it's a deployment issue?
3. What would you check in logs?

**Answer approach:**
> "First, I'd note the exact time of the spike and check Pod Restarts - if pods restarted at the same time, it might be a bad deployment. I'd check the Request Rate by Endpoint panel to see which endpoint has traffic during the error period. I'd switch to Prometheus directly to query `rate(http_requests_total{namespace='prod',status!='OK'}[5m]) by (endpoint, status_code)` to see the exact status codes and endpoints. Then I'd check the logs in Kibana: `kubernetes.namespace_name: 'prod' AND level: 'error' AND @timestamp: [spike_time]` to see error messages."

### Scenario 4: Autoscaling Not Working

**Situation**: Active Pods panel shows 2 pods but CPU Usage is at 90%.

**Questions to expect:**
1. Why isn't HPA scaling up?
2. How would you verify HPA configuration?
3. What metrics does HPA use?

**Answer approach:**
> "The HPA might not scale for several reasons. First, I'd check if metrics-server is running: `kubectl get deployment metrics-server -n kube-system`. Then verify HPA sees the metrics: `kubectl get hpa -n prod` to check TARGETS column. If it shows `unknown`, metrics aren't available. I'd check the HPA YAML to see if the CPU target (70%) matches the current usage. The dashboard CPU Usage panel shows usage as % of requests, but HPA uses absolute CPU. I'd also check if we've hit maxReplicas. Finally, I'd check HPA events: `kubectl describe hpa -n prod`."

### Scenario 5: Cross-Environment Comparison

**Situation**: QA tests pass but prod has issues.

**Questions to expect:**
1. How would you use the dashboard to compare environments?
2. What differences should you look for?
3. How do you account for traffic volume differences?

**Answer approach:**
> "I'd use the namespace variable to compare prod vs qa side-by-side. First, I'd check if the issue is traffic-related - prod likely has higher request rates. I'd look at Request Rate to see the difference in scale. Then compare Error Rate percentages (not absolute numbers) - if both show 2%, it's proportional. For Latency p95/p99, I'd check if prod is consistently higher or just during traffic spikes. I'd also compare Active Pods - prod should have more (3 min vs 2 in qa). If prod shows higher GC Pause Duration with more pods, it might be memory pressure. The key is looking at rates and percentages, not absolute numbers."

### Scenario 6: GC Performance Issues

**Situation**: GC Pause Duration panel shows pauses over 100ms.

**Questions to expect:**
1. What causes long GC pauses?
2. How would you optimize this?
3. What's acceptable GC pause time?

**Answer approach:**
> "Long GC pauses typically mean the heap is too small or there's too much garbage. I'd check the Heap Usage panel - if it's near the limit, we need more memory. If it's low but GC pauses are high, we might be allocating/deallocating excessively. I'd increase the memory limits in the deployment YAML and adjust `GOGC` environment variable (default 100%). For a web service, pauses under 10ms are ideal, under 50ms is acceptable, over 100ms will impact latency. I'd correlate this with the Latency panel - if p99 latency spikes align with GC pauses, that confirms GC is blocking HTTP handlers."

### Scenario 7: Multiple Pod Restarts

**Situation**: Pod Restarts panel shows 8 restarts in the last hour.

**Questions to expect:**
1. What could cause frequent restarts?
2. How would you diagnose the root cause?
3. What's the impact on users?

**Answer approach:**
> "Frequent restarts indicate OOMKilled, failed health checks, or crashes. I'd check Memory Usage panel - if it reaches the limit before restarts, it's OOM. I'd check the logs in Kibana filtering by the pod name and looking for 'panic', 'fatal', or 'kill'. I'd also run `kubectl describe pod` to see the termination reason. For user impact, check the Error Rate and Latency panels during restart times - errors spike because the pod is unavailable, and latency increases as traffic redistributes. If we have 3 pods and 1 is restarting frequently, users see approximately 33% capacity loss."

## Files

- **Dashboard JSON**: [k8s/monitoring/dashboards/sre-demo-system-health.json](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/k8s/monitoring/dashboards/sre-demo-system-health.json)
- **Import Guide**: This document
