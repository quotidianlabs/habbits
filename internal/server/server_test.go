package server_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"habbits/internal/server"
)

func TestHealthz(t *testing.T) {
	h := server.NewHandler()

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status: got %d, want %d", rec.Code, http.StatusOK)
	}

	var body struct {
		Status string `json:"status"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body.Status != "ok" {
		t.Errorf("status field: got %q, want %q", body.Status, "ok")
	}

	if got := rec.Header().Get("X-Request-ID"); got == "" {
		t.Error("X-Request-ID header is empty")
	}
}
