package main

import (
	"log/slog"
	"net/http"
	"os"

	"habbits/internal/server"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stderr, nil)))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	addr := ":" + port
	slog.Info("server starting", slog.String("addr", addr))

	if err := http.ListenAndServe(addr, server.NewHandler()); err != nil {
		slog.Error("server stopped", slog.Any("err", err))
		os.Exit(1)
	}
}
