package middleware

import (
	"log/slog"
	"net/http"
	"time"
)

// statusRecorder captures the status code written by the handler so it can be logged.
type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

// SlogLogger emits one structured log line per request including method,
// path, status, duration, and request ID (read from context).
func SlogLogger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sr := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(sr, r)
		slog.Info("http request",
			slog.String("method", r.Method),
			slog.String("path", r.URL.Path),
			slog.Int("status", sr.status),
			slog.Int64("duration_ms", time.Since(start).Milliseconds()),
			slog.String("request_id", GetRequestID(r.Context())),
		)
	})
}
