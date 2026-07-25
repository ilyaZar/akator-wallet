package server

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/akator/akator-wallet/companion/internal/storage"
)

const testToken = "0123456789abcdef0123456789abcdef"

func TestServerRequiresAuthentication(t *testing.T) {
	handler := testHandler(t)
	request := httptest.NewRequest(http.MethodGet, "/v1/health", nil)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusUnauthorized)
	}
	if strings.Contains(response.Body.String(), testToken) {
		t.Fatal("token leaked in response")
	}
}

func TestServerHealthAndImageRoundTrip(t *testing.T) {
	handler := testHandler(t)

	health := authenticatedRequest(t, http.MethodGet, "/v1/health", nil)
	healthResponse := httptest.NewRecorder()
	handler.ServeHTTP(healthResponse, health)
	if healthResponse.Code != http.StatusOK {
		t.Fatalf("health status = %d", healthResponse.Code)
	}
	var healthPayload struct {
		APIVersion int `json:"apiVersion"`
	}
	if err := json.Unmarshal(healthResponse.Body.Bytes(), &healthPayload); err != nil {
		t.Fatal(err)
	}
	if healthPayload.APIVersion != 1 {
		t.Fatalf("API version = %d", healthPayload.APIVersion)
	}

	png := serverTestPNG(t)
	put := authenticatedRequest(
		t,
		http.MethodPut,
		"/v1/backends/syncthing/file?path=front.png",
		bytes.NewReader(png),
	)
	putResponse := httptest.NewRecorder()
	handler.ServeHTTP(putResponse, put)
	if putResponse.Code != http.StatusCreated {
		t.Fatalf("put status = %d body = %s", putResponse.Code, putResponse.Body)
	}

	get := authenticatedRequest(
		t,
		http.MethodGet,
		"/v1/backends/syncthing/file?path=front.png",
		nil,
	)
	getResponse := httptest.NewRecorder()
	handler.ServeHTTP(getResponse, get)
	if getResponse.Code != http.StatusOK {
		t.Fatalf("get status = %d body = %s", getResponse.Code, getResponse.Body)
	}
	if !bytes.Equal(getResponse.Body.Bytes(), png) {
		t.Fatal("round-trip image differs")
	}
}

func TestServerRejectsTraversalAndOversizedBodies(t *testing.T) {
	handler := testHandler(t)

	traversal := authenticatedRequest(
		t,
		http.MethodGet,
		"/v1/backends/syncthing/file?path=../outside.png",
		nil,
	)
	traversalResponse := httptest.NewRecorder()
	handler.ServeHTTP(traversalResponse, traversal)
	if traversalResponse.Code != http.StatusBadRequest {
		t.Fatalf("traversal status = %d", traversalResponse.Code)
	}

	oversized := authenticatedRequest(
		t,
		http.MethodPut,
		"/v1/backends/syncthing/file?path=large.png",
		bytes.NewReader(make([]byte, storage.MaxImageBytes+1)),
	)
	oversizedResponse := httptest.NewRecorder()
	handler.ServeHTTP(oversizedResponse, oversized)
	if oversizedResponse.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("oversized status = %d", oversizedResponse.Code)
	}
}

func testHandler(t *testing.T) http.Handler {
	t.Helper()
	root := t.TempDir()
	backend, err := storage.NewLocalBackend("syncthing", root)
	if err != nil {
		t.Fatal(err)
	}
	handler, err := New(Config{
		Token:    []byte(testToken),
		Backends: []storage.Backend{backend},
	})
	if err != nil {
		t.Fatal(err)
	}
	return handler
}

func authenticatedRequest(
	t *testing.T,
	method string,
	target string,
	body *bytes.Reader,
) *http.Request {
	t.Helper()
	var request *http.Request
	if body == nil {
		request = httptest.NewRequest(method, target, nil)
	} else {
		request = httptest.NewRequest(method, target, body)
	}
	request.Header.Set("Authorization", "Bearer "+testToken)
	return request
}

func serverTestPNG(t *testing.T) []byte {
	t.Helper()
	data, err := base64.StdEncoding.DecodeString(
		"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=",
	)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func TestServerSkipsNonImageFiles(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "notes.txt"), []byte("no"), 0o600); err != nil {
		t.Fatal(err)
	}
	backend, err := storage.NewLocalBackend("syncthing", root)
	if err != nil {
		t.Fatal(err)
	}
	handler, err := New(Config{
		Token:    []byte(testToken),
		Backends: []storage.Backend{backend},
	})
	if err != nil {
		t.Fatal(err)
	}
	request := authenticatedRequest(
		t,
		http.MethodGet,
		"/v1/backends/syncthing/entries",
		nil,
	)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d", response.Code)
	}
	if strings.Contains(response.Body.String(), "notes.txt") {
		t.Fatal("non-image file was exposed")
	}
}
