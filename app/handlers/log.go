package handlers

import (
	"encoding/json"
	"net/http"

	"go.uber.org/zap"
)

// LogRequest represents the expected request body for /log endpoint
type LogRequest struct {
	Level   string `json:"level"`   // info, warn, error
	Message string `json:"message"` // log message
}

// LogResponse represents the response from /log endpoint
type LogResponse struct {
	Status  string `json:"status"`
	Message string `json:"message"`
}

// LogHandler emits structured logs based on request
func LogHandler(w http.ResponseWriter, r *http.Request) {
	var req LogRequest

	// Parse request body
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	// Validate level
	if req.Level == "" {
		req.Level = "info"
	}

	if req.Message == "" {
		req.Message = "empty log message"
	}

	// Emit log at requested level
	logger := zap.L()
	switch req.Level {
	case "info":
		logger.Info(req.Message,
			zap.String("source", "api"),
			zap.String("endpoint", "/log"),
		)
	case "warn":
		logger.Warn(req.Message,
			zap.String("source", "api"),
			zap.String("endpoint", "/log"),
		)
	case "error":
		logger.Error(req.Message,
			zap.String("source", "api"),
			zap.String("endpoint", "/log"),
		)
	case "debug":
		logger.Debug(req.Message,
			zap.String("source", "api"),
			zap.String("endpoint", "/log"),
		)
	default:
		logger.Info(req.Message,
			zap.String("source", "api"),
			zap.String("endpoint", "/log"),
			zap.String("original_level", req.Level),
		)
	}

	response := LogResponse{
		Status:  "logged",
		Message: req.Message,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}
