package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"runtime"
	"strconv"
	"time"

	"go.uber.org/zap"
)

// Global slice to store leaked memory (never freed)
var leakedMemory [][]byte

// SlowHandler simulates artificial latency
// Query parameter: duration (milliseconds, default: 1000)
func SlowHandler(w http.ResponseWriter, r *http.Request) {
	durationStr := r.URL.Query().Get("duration")
	if durationStr == "" {
		durationStr = "1000" // default 1 second
	}

	duration, err := strconv.Atoi(durationStr)
	if err != nil || duration < 0 {
		http.Error(w, "invalid duration parameter", http.StatusBadRequest)
		return
	}

	// Simulate slow processing
	time.Sleep(time.Duration(duration) * time.Millisecond)

	response := map[string]interface{}{
		"message":      "slow endpoint completed",
		"duration_ms":  duration,
		"actual_delay": duration,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// LeakHandler simulates a memory leak
// Query parameter: size (KB, default: 1024)
func LeakHandler(w http.ResponseWriter, r *http.Request) {
	sizeStr := r.URL.Query().Get("size")
	if sizeStr == "" {
		sizeStr = "1024" // default 1 MB
	}

	sizeKB, err := strconv.Atoi(sizeStr)
	if err != nil || sizeKB < 0 {
		http.Error(w, "invalid size parameter", http.StatusBadRequest)
		return
	}

	// Allocate memory and store in global slice (never freed)
	bytes := make([]byte, sizeKB*1024)
	for i := range bytes {
		bytes[i] = byte(i % 256) // Fill with data to ensure allocation
	}
	leakedMemory = append(leakedMemory, bytes)

	// Get current memory stats
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	zap.L().Warn("Memory leak triggered",
		zap.Int("allocated_kb", sizeKB),
		zap.Int("total_leaks", len(leakedMemory)),
		zap.Uint64("heap_alloc_mb", m.Alloc/1024/1024),
		zap.Uint64("sys_mb", m.Sys/1024/1024),
	)

	response := map[string]interface{}{
		"message":           "memory leak triggered",
		"allocated_kb":      sizeKB,
		"total_leaks":       len(leakedMemory),
		"heap_alloc_mb":     m.Alloc / 1024 / 1024,
		"heap_sys_mb":       m.HeapSys / 1024 / 1024,
		"num_gc":            m.NumGC,
		"pprof_heap_url":    "http://localhost:6060/debug/pprof/heap",
		"pprof_profile_url": "http://localhost:6060/debug/pprof/profile?seconds=30",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// CPUHandler simulates CPU spike
// Query parameter: duration (milliseconds, default: 5000)
func CPUHandler(w http.ResponseWriter, r *http.Request) {
	durationStr := r.URL.Query().Get("duration")
	if durationStr == "" {
		durationStr = "5000" // default 5 seconds
	}

	duration, err := strconv.Atoi(durationStr)
	if err != nil || duration < 0 {
		http.Error(w, "invalid duration parameter", http.StatusBadRequest)
		return
	}

	zap.L().Info("CPU spike triggered", zap.Int("duration_ms", duration))

	// Start CPU-intensive work
	start := time.Now()
	endTime := start.Add(time.Duration(duration) * time.Millisecond)

	// Busy loop to consume CPU
	sum := 0
	for time.Now().Before(endTime) {
		for i := 0; i < 1000000; i++ {
			sum += i
		}
	}

	elapsed := time.Since(start).Milliseconds()

	response := map[string]interface{}{
		"message":            "CPU spike completed",
		"requested_duration": duration,
		"actual_duration_ms": elapsed,
		"pprof_cpu_url":      fmt.Sprintf("http://localhost:6060/debug/pprof/profile?seconds=%d", duration/1000),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
