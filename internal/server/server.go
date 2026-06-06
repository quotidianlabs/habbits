package server

import "net/http"

// NewHandler returns the http.Handler for the Habbits server.
// Real routes and middleware are wired in later tasks.
func NewHandler() http.Handler {
	return http.NewServeMux()
}
