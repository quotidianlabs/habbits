package middleware

import (
	"log/slog"
	"net/http"
	"runtime/debug"
)

// Recoverer catches panics in downstream handlers, logs the stack trace
// with the request ID (if available), and responds with 500.
func Recoverer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rv := recover(); rv != nil {
				slog.Error("panic in handler",
					slog.String("request_id", GetRequestID(r.Context())),
					slog.Any("panic", rv),
					slog.String("stack", string(debug.Stack())),
				)
				http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}
