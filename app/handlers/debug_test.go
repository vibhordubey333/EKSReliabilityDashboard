package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestSlowHandler(t *testing.T) {
	tests := []struct {
		name           string
		duration       string
		expectStatus   int
		expectDuration int
	}{
		{"default duration", "", http.StatusOK, 1000},
		{"custom duration", "500", http.StatusOK, 500},
		{"invalid duration", "invalid", http.StatusBadRequest, 0},
		{"negative duration", "-1", http.StatusBadRequest, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			url := "/slow"
			if tt.duration != "" {
				url += "?duration=" + tt.duration
			}

			req, _ := http.NewRequest("GET", url, nil)
			rr := httptest.NewRecorder()

			handler := http.HandlerFunc(SlowHandler)
			handler.ServeHTTP(rr, req)

			if status := rr.Code; status != tt.expectStatus {
				t.Errorf("handler returned wrong status code: got %v want %v",
					status, tt.expectStatus)
			}

			if tt.expectStatus == http.StatusOK {
				var response map[string]interface{}
				json.NewDecoder(rr.Body).Decode(&response)

				if response["message"] != "slow endpoint completed" {
					t.Errorf("unexpected message: got %v", response["message"])
				}
			}
		})
	}
}

func TestLeakHandler(t *testing.T) {
	req, _ := http.NewRequest("GET", "/leak?size=10", nil)
	rr := httptest.NewRecorder()

	handler := http.HandlerFunc(LeakHandler)
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	var response map[string]interface{}
	json.NewDecoder(rr.Body).Decode(&response)

	if response["message"] != "memory leak triggered" {
		t.Errorf("unexpected message: got %v", response["message"])
	}

	if response["allocated_kb"] != float64(10) {
		t.Errorf("unexpected allocated_kb: got %v want 10", response["allocated_kb"])
	}
}

func TestCPUHandler(t *testing.T) {
	req, _ := http.NewRequest("GET", "/cpu?duration=100", nil)
	rr := httptest.NewRecorder()

	handler := http.HandlerFunc(CPUHandler)
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	var response map[string]interface{}
	json.NewDecoder(rr.Body).Decode(&response)

	if response["message"] != "CPU spike completed" {
		t.Errorf("unexpected message: got %v", response["message"])
	}
}
