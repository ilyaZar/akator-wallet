// Package server exposes storage backends through a narrow HTTP API.
package server

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/akator/akator-wallet/companion/internal/storage"
)

const apiVersion = 1

// Config defines the authenticated service surface.
type Config struct {
	Token    []byte
	Backends []storage.Backend
}

// New creates the companion HTTP handler.
func New(config Config) (http.Handler, error) {
	if len(config.Token) < 32 {
		return nil, errors.New("access token must contain at least 32 bytes")
	}
	if len(config.Backends) == 0 {
		return nil, errors.New("at least one storage backend is required")
	}

	service := &service{
		tokenHash: sha256.Sum256(config.Token),
		backends:  make(map[string]storage.Backend, len(config.Backends)),
	}
	for _, backend := range config.Backends {
		if _, exists := service.backends[backend.ID()]; exists {
			return nil, errors.New("duplicate storage backend")
		}
		service.backends[backend.ID()] = backend
	}
	return service.security(service.authenticate(http.HandlerFunc(service.route))), nil
}

type service struct {
	tokenHash [sha256.Size]byte
	backends  map[string]storage.Backend
}

func (s *service) route(response http.ResponseWriter, request *http.Request) {
	switch {
	case request.URL.Path == "/v1/health":
		s.health(response, request)
	case strings.HasPrefix(request.URL.Path, "/v1/backends/"):
		s.backendRoute(response, request)
	default:
		writeError(response, http.StatusNotFound, "not_found")
	}
}

func (s *service) health(response http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet {
		writeError(response, http.StatusMethodNotAllowed, "method_not_allowed")
		return
	}
	type backendHealth struct {
		ID           string   `json:"id"`
		Available    bool     `json:"available"`
		Status       string   `json:"status"`
		Capabilities []string `json:"capabilities"`
	}
	type healthResponse struct {
		APIVersion int             `json:"apiVersion"`
		Backends   []backendHealth `json:"backends"`
	}

	ids := make([]string, 0, len(s.backends))
	for id := range s.backends {
		ids = append(ids, id)
	}
	sort.Strings(ids)

	result := healthResponse{APIVersion: apiVersion}
	for _, id := range ids {
		ctx, cancel := context.WithTimeout(request.Context(), 10*time.Second)
		err := s.backends[id].Health(ctx)
		cancel()
		status := "ok"
		if errors.Is(err, storage.ErrUnsupportedVersion) {
			status = "unsupported_version"
		} else if err != nil {
			status = "unavailable"
		}
		result.Backends = append(result.Backends, backendHealth{
			ID:           id,
			Available:    err == nil,
			Status:       status,
			Capabilities: []string{"list", "read", "write"},
		})
	}
	writeJSON(response, http.StatusOK, result)
}

func (s *service) backendRoute(
	response http.ResponseWriter,
	request *http.Request,
) {
	remainder := strings.TrimPrefix(request.URL.Path, "/v1/backends/")
	parts := strings.Split(remainder, "/")
	if len(parts) != 2 {
		writeError(response, http.StatusNotFound, "not_found")
		return
	}
	backend, exists := s.backends[parts[0]]
	if !exists {
		writeError(response, http.StatusNotFound, "backend_not_found")
		return
	}

	switch parts[1] {
	case "entries":
		s.entries(response, request, backend)
	case "file":
		s.file(response, request, backend)
	default:
		writeError(response, http.StatusNotFound, "not_found")
	}
}

func (s *service) entries(
	response http.ResponseWriter,
	request *http.Request,
	backend storage.Backend,
) {
	if request.Method != http.MethodGet {
		writeError(response, http.StatusMethodNotAllowed, "method_not_allowed")
		return
	}
	ctx, cancel := context.WithTimeout(request.Context(), 30*time.Second)
	defer cancel()
	entries, err := backend.List(ctx, request.URL.Query().Get("path"))
	if err != nil {
		writeStorageError(response, err)
		return
	}
	writeJSON(response, http.StatusOK, map[string]any{"entries": entries})
}

func (s *service) file(
	response http.ResponseWriter,
	request *http.Request,
	backend storage.Backend,
) {
	relative := request.URL.Query().Get("path")
	switch request.Method {
	case http.MethodGet:
		ctx, cancel := context.WithTimeout(request.Context(), 2*time.Minute)
		defer cancel()
		file, err := backend.Read(ctx, relative)
		if err != nil {
			writeStorageError(response, err)
			return
		}
		response.Header().Set("Content-Type", file.MIMEType)
		response.Header().Set("Content-Length", fmt.Sprintf("%d", len(file.Data)))
		response.WriteHeader(http.StatusOK)
		_, _ = response.Write(file.Data)
	case http.MethodPut:
		request.Body = http.MaxBytesReader(
			response,
			request.Body,
			storage.MaxImageBytes+1,
		)
		data, err := io.ReadAll(request.Body)
		if err != nil {
			writeError(response, http.StatusRequestEntityTooLarge, "image_too_large")
			return
		}
		ctx, cancel := context.WithTimeout(request.Context(), 2*time.Minute)
		defer cancel()
		entry, err := backend.Write(ctx, relative, data)
		if err != nil {
			writeStorageError(response, err)
			return
		}
		writeJSON(response, http.StatusCreated, entry)
	default:
		writeError(response, http.StatusMethodNotAllowed, "method_not_allowed")
	}
}

func (s *service) authenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		header := request.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			writeError(response, http.StatusUnauthorized, "unauthorized")
			return
		}
		candidate := sha256.Sum256([]byte(strings.TrimPrefix(header, "Bearer ")))
		if subtle.ConstantTimeCompare(candidate[:], s.tokenHash[:]) != 1 {
			writeError(response, http.StatusUnauthorized, "unauthorized")
			return
		}
		next.ServeHTTP(response, request)
	})
}

func (s *service) security(next http.Handler) http.Handler {
	return http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		response.Header().Set("Cache-Control", "no-store")
		response.Header().Set("X-Content-Type-Options", "nosniff")
		response.Header().Set("Referrer-Policy", "no-referrer")
		next.ServeHTTP(response, request)
	})
}

func writeStorageError(response http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, storage.ErrInvalidPath):
		writeError(response, http.StatusBadRequest, "invalid_path")
	case errors.Is(err, storage.ErrNotFound):
		writeError(response, http.StatusNotFound, "object_not_found")
	case errors.Is(err, storage.ErrNotImage):
		writeError(response, http.StatusUnsupportedMediaType, "unsupported_image")
	case errors.Is(err, storage.ErrTooLarge):
		writeError(response, http.StatusRequestEntityTooLarge, "image_too_large")
	default:
		writeError(response, http.StatusServiceUnavailable, "backend_unavailable")
	}
}

func writeError(response http.ResponseWriter, status int, code string) {
	writeJSON(response, status, map[string]string{"error": code})
}

func writeJSON(response http.ResponseWriter, status int, value any) {
	response.Header().Set("Content-Type", "application/json")
	response.WriteHeader(status)
	_ = json.NewEncoder(response).Encode(value)
}
