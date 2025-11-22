package middleware

import (
	"net/http"
	"time"

	"github.com/vibhordubey333/EKSReliabilityDashboard/app/handlers"
	"go.uber.org/zap"
)

// responseWriter wraps http.ResponseWriter to capture status code
type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// LoggingMiddleware logs HTTP requests and tracks metrics
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Wrap response writer to capture status code
		rw := &responseWriter{
			ResponseWriter: w,
			statusCode:     http.StatusOK, // default
		}

		// Increment active connections
		handlers.ActiveConnections.Inc()
		defer handlers.ActiveConnections.Dec()

		// Call next handler
		next.ServeHTTP(rw, r)

		// Calculate duration
		duration := time.Since(start)

		// Log request with Elasticsearch-friendly fields
		zap.L().Info("HTTP request",
			zap.String("method", r.Method),
			zap.String("path", r.URL.Path),
			zap.String("route", r.URL.Path), // Alias for Elasticsearch
			zap.Int("status", rw.statusCode),
			zap.Int("status_code", rw.statusCode), // Alias for Elasticsearch
			zap.Duration("duration", duration),
			zap.Float64("latency", duration.Seconds()), // Latency in seconds for Elasticsearch
			zap.String("remote_addr", r.RemoteAddr),
			zap.String("user_agent", r.UserAgent()),
		)

		// Update Prometheus metrics
		handlers.HTTPRequestsTotal.WithLabelValues(
			r.URL.Path,
			r.Method,
			http.StatusText(rw.statusCode),
		).Inc()

		handlers.HTTPRequestDuration.WithLabelValues(
			r.URL.Path,
			r.Method,
		).Observe(duration.Seconds())
	})
}
