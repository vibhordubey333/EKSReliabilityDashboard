package handlers

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// HTTPRequestsTotal counts total HTTP requests by endpoint and status
	HTTPRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"endpoint", "method", "status"},
	)

	// HTTPRequestDuration tracks request latency distribution
	HTTPRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request latency in seconds",
			Buckets: prometheus.DefBuckets, // 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10
		},
		[]string{"endpoint", "method"},
	)

	// MemoryAllocations tracks current memory allocation
	MemoryAllocations = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "memory_allocations_bytes",
			Help: "Current memory allocations in bytes",
		},
	)

	// ActiveConnections tracks current active connections
	ActiveConnections = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "active_connections",
			Help: "Current number of active HTTP connections",
		},
	)
)

// InitMetrics initializes Prometheus metrics
// Call this once at application startup
func InitMetrics() {
	// Metrics are automatically registered by promauto
	// This function exists for explicit initialization if needed
}
