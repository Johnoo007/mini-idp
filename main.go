package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

// version is set at build time: go build -ldflags "-X main.version=1.0.0"
var version = "dev"

func newMux() *http.ServeMux {
	mux := http.NewServeMux()

	// liveness: process is alive
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	// readiness: ready to receive traffic
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ready"))
	})

	mux.HandleFunc("GET /api/hello", func(w http.ResponseWriter, r *http.Request) {
		name := r.URL.Query().Get("name")
		if name == "" {
			name = "world"
		}
		writeJSON(w, map[string]string{"message": "hello, " + name})
	})

	mux.HandleFunc("GET /api/version", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]string{"version": version})
	})

	return mux
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("mini-idp %s listening on :%s", version, port)
	log.Fatal(http.ListenAndServe(":"+port, newMux()))
}
