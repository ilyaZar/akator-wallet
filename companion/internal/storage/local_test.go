package storage

import (
	"context"
	"encoding/base64"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestLocalBackendWriteReadAndList(t *testing.T) {
	root := t.TempDir()
	if err := os.Mkdir(filepath.Join(root, "cards"), 0o700); err != nil {
		t.Fatal(err)
	}
	backend, err := NewLocalBackend("syncthing", root)
	if err != nil {
		t.Fatal(err)
	}

	entry, err := backend.Write(
		context.Background(),
		"cards/front.png",
		testPNG(t),
	)
	if err != nil {
		t.Fatal(err)
	}
	if entry.Path != "cards/front.png" || entry.MIMEType != "image/png" {
		t.Fatalf("unexpected entry: %#v", entry)
	}

	file, err := backend.Read(context.Background(), entry.Path)
	if err != nil {
		t.Fatal(err)
	}
	if file.MIMEType != "image/png" {
		t.Fatalf("unexpected MIME type: %s", file.MIMEType)
	}

	entries, err := backend.List(context.Background(), "cards")
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 || entries[0].Path != entry.Path {
		t.Fatalf("unexpected entries: %#v", entries)
	}

	temporary, err := filepath.Glob(filepath.Join(root, "cards", ".akator-*"))
	if err != nil {
		t.Fatal(err)
	}
	if len(temporary) != 0 {
		t.Fatalf("atomic temporary files remain: %v", temporary)
	}
}

func TestLocalBackendRejectsTraversalAndSymlinkEscape(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	if err := os.Mkdir(filepath.Join(root, ".stfolder"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(
		filepath.Join(outside, "outside.png"),
		testPNG(t),
		0o600,
	); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(root, "escape")); err != nil {
		t.Fatal(err)
	}
	backend, err := NewLocalBackend("syncthing", root)
	if err != nil {
		t.Fatal(err)
	}

	for _, relative := range []string{
		"../outside.png",
		"/outside.png",
		"escape/outside.png",
		`escape\outside.png`,
		".stfolder/internal.png",
	} {
		_, readErr := backend.Read(context.Background(), relative)
		if !errors.Is(readErr, ErrInvalidPath) {
			t.Fatalf("%q: got %v, want ErrInvalidPath", relative, readErr)
		}
	}

	entries, err := backend.List(context.Background(), "")
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Fatalf("symlink should not be listed: %#v", entries)
	}
}

func TestLocalBackendRejectsUnsupportedAndOversizedData(t *testing.T) {
	backend, err := NewLocalBackend("syncthing", t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	_, err = backend.Write(context.Background(), "card.txt", []byte("not image"))
	if !errors.Is(err, ErrNotImage) {
		t.Fatalf("got %v, want ErrNotImage", err)
	}
	_, err = backend.Write(
		context.Background(),
		"card.png",
		make([]byte, MaxImageBytes+1),
	)
	if !errors.Is(err, ErrTooLarge) {
		t.Fatalf("got %v, want ErrTooLarge", err)
	}
}

func TestCleanPath(t *testing.T) {
	tests := []struct {
		name      string
		value     string
		allowRoot bool
		want      string
		wantErr   bool
	}{
		{name: "root", value: "", allowRoot: true, want: ""},
		{name: "nested", value: "cards/front.png", want: "cards/front.png"},
		{name: "normalized", value: "cards/./front.png", want: "cards/front.png"},
		{name: "parent", value: "../front.png", wantErr: true},
		{name: "absolute", value: "/cards/front.png", wantErr: true},
		{name: "backslash", value: `cards\front.png`, wantErr: true},
		{name: "hidden", value: "cards/.metadata", wantErr: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := CleanPath(test.value, test.allowRoot)
			if (err != nil) != test.wantErr {
				t.Fatalf("CleanPath() error = %v, wantErr %v", err, test.wantErr)
			}
			if got != test.want {
				t.Fatalf("CleanPath() = %q, want %q", got, test.want)
			}
		})
	}
}

func testPNG(t *testing.T) []byte {
	t.Helper()
	data, err := base64.StdEncoding.DecodeString(
		"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=",
	)
	if err != nil {
		t.Fatal(err)
	}
	return data
}
