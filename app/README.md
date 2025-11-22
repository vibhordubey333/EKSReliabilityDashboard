# SRE Demo Service

A Go microservice demonstrating SRE observability best practices including health checks, Prometheus metrics, pprof profiling, and debugging endpoints.

## Features

- Health check endpoint for Kubernetes probes
- Prometheus metrics exposition
- pprof profiling endpoints
- Structured JSON logging
- Debug endpoints for testing (latency, memory, CPU)
- Graceful shutdown
- Multi-stage Docker build

## Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check (returns JSON status) |
| `/metrics` | GET | Prometheus metrics |
| `/slow?duration=<ms>` | GET | Artificial latency (default: 1000ms) |
| `/leak?size=<kb>` | GET | Memory leak simulation (default: 1024KB) |
| `/cpu?duration=<ms>` | GET | CPU spike simulation (default: 5000ms) |
| `/log` | POST | Emit structured logs |

### pprof Endpoints (port 6060)

- `/debug/pprof/` - Index of available profiles
- `/debug/pprof/heap` - Heap profile
- `/debug/pprof/goroutine` - Goroutine dump
- `/debug/pprof/profile?seconds=30` - CPU profile

## Quick Start

### Run Locally

```bash
# Download dependencies
go mod download

# Run the service
go run main.go

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/metrics
```

### Run with Docker

#### Option 1: Build and Run Locally

```bash
# Build image
docker build -t sre-demo-service:latest .

# Run container
docker run -p 8080:8080 -p 6060:6060 sre-demo-service:latest

# Test
curl http://localhost:8080/health
```

#### Option 2: Use ECR (Production Workflow)

**ECR Repository**:
```
911723818034.dkr.ecr.us-east-1.amazonaws.com/sre-demo-service
```

**Build, Tag, and Push to ECR**:
```bash
# Automated script (recommended)
cd /Users/infinitelearner/Code-Repos/EKSReliabilityDashboard
./scripts/build-and-push.sh

# Manual workflow
# 1. Build image
docker build -t sre-demo-service:$(git rev-parse --short HEAD) .

# 2. Tag for ECR
docker tag sre-demo-service:$(git rev-parse --short HEAD) \
  911723818034.dkr.ecr.us-east-1.amazonaws.com/sre-demo-service:$(git rev-parse --short HEAD)
docker tag sre-demo-service:$(git rev-parse --short HEAD) \
  911723818034.dkr.ecr.us-east-1.amazonaws.com/sre-demo-service:latest

# 3. Authenticate to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 911723818034.dkr.ecr.us-east-1.amazonaws.com

# 4. Push to ECR
docker push 911723818034.dkr.ecr.us-east-1.amazonaws.com/sre-demo-service:$(git rev-parse --short HEAD)
docker push 911723818034.dkr.ecr.us-east-1.amazonaws.com/sre-demo-service:latest
```

**Pull and Run from ECR**:
```bash
# Authenticate
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 911723818034.dkr.ecr.us-east-1.amazonaws.com

# Pull specific version by Git SHA
docker pull 911723818034.dkr.ecr.us-east-1.amazonaws.com/sre-demo-service:7ea6fa4

# Pull latest
docker pull 911723818034.dkr.ecr.us-east-1.amazonaws.com/sre-demo-service:latest

# Run from ECR
docker run -d -p 8080:8080 -p 6060:6060 \
  911723818034.dkr.ecr.us-east-1.amazonaws.com/sre-demo-service:latest

# Test
curl http://localhost:8080/health
```

**Git SHA Tagging Strategy**:

Images are tagged with both Git SHA and `latest`:
- **Git SHA tag** (e.g., `7ea6fa4`): Immutable reference to specific code version, enables rollback and auditing
- **Latest tag**: Always points to most recent build for development/testing

**Interview Talking Point**:
> "I implemented Git SHA-based image tagging to ensure traceability between deployed containers and source code. Each image can be traced back to the exact commit, which is critical for debugging production issues and maintaining audit trails in regulated environments."


## Testing

```bash
# Run all tests
go test ./... -v

# Run tests with coverage
go test ./... -cover

# Run specific test
go test ./handlers -run TestHealthHandler -v
```

## Example Usage

### Health Check
```bash
curl http://localhost:8080/health
```

Response:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-22T10:30:00Z"
}
```

### Trigger Memory Leak (10MB)
```bash
curl "http://localhost:8080/leak?size=10240"
```

### CPU Spike (2 seconds)
```bash
curl "http://localhost:8080/cpu?duration=2000"
```

### Emit Custom Log
```bash
curl -X POST http://localhost:8080/log \
  -H "Content-Type: application/json" \
  -d '{"level": "warn", "message": "custom warning message"}'
```

### Capture Heap Profile
```bash
curl http://localhost:6060/debug/pprof/heap -o heap.prof
go tool pprof -http=:8081 heap.prof
```

## Prometheus Metrics

The service exposes comprehensive metrics following Prometheus best practices:

### Custom Application Metrics

#### 1. `http_requests_total` (Counter)
- **Type**: Counter
- **Description**: Total number of HTTP requests received
- **Labels**:
  - `endpoint` - The request path (e.g., `/health`, `/metrics`)
  - `method` - HTTP method (GET, POST, etc.)
  - `status` - HTTP status text (OK, Bad Request, etc.)
- **Use Case**: Track request volume, error rates, and calculate success rate
- **Example Query**: `rate(http_requests_total{status!="OK"}[5m])` (error rate)

#### 2. `http_request_duration_seconds` (Histogram)
- **Type**: Histogram
- **Description**: Duration of HTTP requests in seconds
- **Labels**:
  - `endpoint` - The request path
  - `method` - HTTP method
- **Buckets**: 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10 seconds
- **Use Case**: Calculate latency percentiles (p50, p95, p99) for SLI tracking
- **Example Query**: `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))` (p99 latency)

#### 3. `memory_allocations_bytes` (Gauge)
- **Type**: Gauge
- **Description**: Current memory allocations in bytes
- **Labels**: None
- **Use Case**: Monitor memory usage, detect memory leaks
- **Example Query**: `memory_allocations_bytes / 1024 / 1024` (memory in MB)

#### 4. `active_connections` (Gauge)
- **Type**: Gauge
- **Description**: Number of currently active HTTP connections
- **Labels**: None
- **Use Case**: Monitor concurrent connections, identify connection leaks
- **Example Query**: `active_connections > 100` (alert on high concurrency)

### Standard Go Runtime Metrics

Automatically exposed by Prometheus client library:

- `go_goroutines` - Number of goroutines
- `go_threads` - Number of OS threads
- `go_memstats_alloc_bytes` - Bytes allocated and in use
- `go_memstats_heap_objects` - Number of allocated objects
- `go_gc_duration_seconds` - GC pause duration
- `process_cpu_seconds_total` - Total CPU time
- `process_resident_memory_bytes` - Resident memory size

### Metric Types Explained

**Counter**: Monotonically increasing value (never decreases). Use for counting events.
- Example: Total requests, total errors

**Histogram**: Samples observations and counts them in configurable buckets.
- Example: Request duration, response size
- Automatically creates `_bucket`, `_sum`, and `_count` time series

**Gauge**: Value that can go up and down.
- Example: Memory usage, active connections, queue size

### Accessing Metrics

```bash
# View all metrics
curl http://localhost:8080/metrics

# Filter specific metric
curl http://localhost:8080/metrics | grep http_requests_total

# Example output:
# http_requests_total{endpoint="/health",method="GET",status="OK"} 142
# http_request_duration_seconds_bucket{endpoint="/health",method="GET",le="0.005"} 140
```

### RED Metrics Pattern

This service implements the RED (Rate, Errors, Duration) metrics pattern:

- **Rate**: `rate(http_requests_total[5m])` - Request rate per second
- **Errors**: `rate(http_requests_total{status!="OK"}[5m])` - Error rate
- **Duration**: `rate(http_request_duration_seconds_sum[5m])` - Average latency

**Interview Talking Point**:
> "I implemented the RED metrics pattern which covers the three golden signals for monitoring request-driven services: request rate, error rate, and latency distribution. These metrics enable effective SLI/SLO tracking and alert on user-impacting issues."

## Development

```bash
# Format code
go fmt ./...

# Lint code
golangci-lint run

# Build binary
go build -o bin/sre-demo-service .
```

## Architecture

```
app/
├── main.go              # HTTP server setup, routing
├── handlers/            # HTTP handlers
│   ├── health.go       # Health check
│   ├── metrics.go      # Prometheus metrics
│   ├── debug.go        # Debug endpoints
│   └── log.go          # Logging endpoint
└── middleware/         # HTTP middleware
    └── logging.go      # Request logging
```

## Interview Talking Points

- **Observability**: Demonstrates three pillars - metrics (Prometheus), logs (JSON), traces (pprof)
- **Production-ready**: Graceful shutdown, structured logging, health checks
- **SRE debugging**: Endpoints simulate real-world issues for testing monitoring/alerting
- **Container-ready**: Multi-stage build, non-root user, minimal attack surface
- **Testing**: Unit tests for critical handlers

## License

MIT
