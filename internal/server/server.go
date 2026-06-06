package server

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
)

// NewHandler returns the http.Handler for the Habbits server.
func NewHandler() http.Handler {
	r := chi.NewRouter()
	r.Get("/healthz", healthz)
	return r
}

func healthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}
