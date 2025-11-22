package main

import (
	"context"
	"net/http"
	_ "net/http/pprof" // Enable pprof endpoints
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.uber.org/zap"

	"github.com/vibhordubey333/EKSReliabilityDashboard/app/handlers"
	"github.com/vibhordubey333/EKSReliabilityDashboard/app/middleware"
)

func main() {
	// Initialize structured logger
	logger, err := zap.NewProduction()
	if err != nil {
		panic("failed to initialize logger: " + err.Error())
	}
	defer logger.Sync()

	// Make logger available globally
	zap.ReplaceGlobals(logger)

	logger.Info("Starting SRE Demo Service",
		zap.String("version", "1.0.0"),
		zap.String("port", "8080"),
	)

	// Initialize Prometheus metrics
	handlers.InitMetrics()

	// Create router
	r := mux.NewRouter()

	// Apply logging middleware
	r.Use(middleware.LoggingMiddleware)

	// Health endpoint
	r.HandleFunc("/health", handlers.HealthHandler).Methods("GET")

	// Metrics endpoint (Prometheus)
	r.Handle("/metrics", promhttp.Handler()).Methods("GET")

	// Debug endpoints
	r.HandleFunc("/slow", handlers.SlowHandler).Methods("GET")
	r.HandleFunc("/leak", handlers.LeakHandler).Methods("GET")
	r.HandleFunc("/cpu", handlers.CPUHandler).Methods("GET")

	// Logging endpoint
	r.HandleFunc("/log", handlers.LogHandler).Methods("POST")

	// HTTP server configuration
	srv := &http.Server{
		Addr:         ":8080",
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start pprof server on separate port
	go func() {
		logger.Info("Starting pprof server", zap.String("port", "6060"))
		if err := http.ListenAndServe(":6060", nil); err != nil {
			logger.Error("pprof server failed", zap.Error(err))
		}
	}()

	// Start HTTP server in goroutine
	go func() {
		logger.Info("Starting HTTP server", zap.String("addr", srv.Addr))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("HTTP server failed", zap.Error(err))
		}
	}()

	// Wait for interrupt signal for graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Fatal("Server forced to shutdown", zap.Error(err))
	}

	logger.Info("Server exited")
}
