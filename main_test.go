package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func get(t *testing.T, path string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	newMux().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec
}

func TestHealthz(t *testing.T) {
	if rec := get(t, "/healthz"); rec.Code != http.StatusOK {
		t.Fatalf("want 200, got %d", rec.Code)
	}
}

func TestReadyz(t *testing.T) {
	if rec := get(t, "/readyz"); rec.Code != http.StatusOK {
		t.Fatalf("want 200, got %d", rec.Code)
	}
}

func TestHello(t *testing.T) {
	cases := []struct {
		path string
		want string
	}{
		{"/api/hello", "hello, world"},       // no name -> default
		{"/api/hello?name=John", "hello, John"},
		{"/api/hello?name=", "hello, world"}, // empty name -> default
	}
	for _, c := range cases {
		rec := get(t, c.path)
		var body map[string]string
		if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
			t.Fatalf("%s: bad json: %v", c.path, err)
		}
		if body["message"] != c.want {
			t.Errorf("%s: want %q, got %q", c.path, c.want, body["message"])
		}
	}
}

func TestUnknownPath(t *testing.T) {
	if rec := get(t, "/nope"); rec.Code != http.StatusNotFound {
		t.Fatalf("want 404, got %d", rec.Code)
	}
}

func TestWrongMethod(t *testing.T) {
	rec := httptest.NewRecorder()
	newMux().ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/healthz", nil))
	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("want 405, got %d", rec.Code)
	}
}
