// Package storage defines the narrow image storage contract exposed by the
// Akator companion.
package storage

import (
	"context"
	"errors"
	"fmt"
	"mime"
	"net/http"
	"path"
	"strings"
	"time"
)

const (
	// MaxImageBytes bounds plaintext image transfers through the companion.
	MaxImageBytes int64 = 12 << 20
)

var (
	// ErrInvalidPath means a path is outside the backend contract.
	ErrInvalidPath = errors.New("invalid storage path")
	// ErrNotFound means the requested object does not exist.
	ErrNotFound = errors.New("storage object not found")
	// ErrNotImage means the object is not a supported image.
	ErrNotImage = errors.New("unsupported image")
	// ErrTooLarge means the image exceeds MaxImageBytes.
	ErrTooLarge = errors.New("image exceeds size limit")
	// ErrUnavailable means the provider cannot currently serve requests.
	ErrUnavailable = errors.New("storage backend unavailable")
	// ErrUnsupportedVersion means provider tooling has an unverified contract.
	ErrUnsupportedVersion = errors.New("unsupported provider version")
)

// Entry describes a folder or image relative to a configured backend root.
type Entry struct {
	Path       string    `json:"path"`
	Name       string    `json:"name"`
	Kind       string    `json:"kind"`
	MIMEType   string    `json:"mimeType,omitempty"`
	Size       int64     `json:"size,omitempty"`
	ModifiedAt time.Time `json:"modifiedAt,omitempty"`
}

// File contains a bounded image returned by a backend.
type File struct {
	Data     []byte
	MIMEType string
}

// Backend is the provider-neutral image storage contract.
type Backend interface {
	ID() string
	Health(context.Context) error
	List(context.Context, string) ([]Entry, error)
	Read(context.Context, string) (File, error)
	Write(context.Context, string, []byte) (Entry, error)
}

// CleanPath validates a slash-separated path relative to a backend root.
func CleanPath(value string, allowRoot bool) (string, error) {
	if strings.ContainsRune(value, '\x00') || strings.Contains(value, "\\") {
		return "", ErrInvalidPath
	}

	cleaned := path.Clean(strings.TrimSpace(value))
	if cleaned == "." || cleaned == "" {
		if allowRoot {
			return "", nil
		}
		return "", ErrInvalidPath
	}
	if path.IsAbs(cleaned) || cleaned == ".." ||
		strings.HasPrefix(cleaned, "../") {
		return "", ErrInvalidPath
	}

	for _, segment := range strings.Split(cleaned, "/") {
		if segment == "" || segment == "." || segment == ".." ||
			strings.HasPrefix(segment, ".") {
			return "", ErrInvalidPath
		}
	}
	return cleaned, nil
}

// ValidateImage checks the filename, size, and detected content type.
func ValidateImage(name string, data []byte) (string, error) {
	if int64(len(data)) > MaxImageBytes {
		return "", ErrTooLarge
	}
	if len(data) == 0 || !supportedImageName(name) {
		return "", ErrNotImage
	}

	mimeType := http.DetectContentType(data)
	switch mimeType {
	case "image/jpeg", "image/png", "image/gif", "image/webp":
		return mimeType, nil
	default:
		return "", ErrNotImage
	}
}

func mimeTypeForName(name string) string {
	mimeType := mime.TypeByExtension(strings.ToLower(path.Ext(name)))
	if strings.HasPrefix(mimeType, "image/") {
		return strings.Split(mimeType, ";")[0]
	}
	return ""
}

func supportedImageName(name string) bool {
	switch strings.ToLower(path.Ext(name)) {
	case ".jpg", ".jpeg", ".png", ".gif", ".webp":
		return true
	default:
		return false
	}
}

func validateEntryName(name string) error {
	if name == "" || name == "." || name == ".." ||
		strings.HasPrefix(name, ".") ||
		strings.ContainsAny(name, "/\\\x00") {
		return fmt.Errorf("%w: invalid name", ErrInvalidPath)
	}
	return nil
}
