package storage

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"
)

type runnerFunc func(context.Context, ...string) ([]byte, error)

func (function runnerFunc) Output(
	ctx context.Context,
	arguments ...string,
) ([]byte, error) {
	return function(ctx, arguments...)
}

func TestProtonBackendHealthAndList(t *testing.T) {
	var calls [][]string
	runner := runnerFunc(func(
		_ context.Context,
		arguments ...string,
	) ([]byte, error) {
		calls = append(calls, append([]string(nil), arguments...))
		if arguments[0] == "--version" {
			return []byte(
				"Proton Drive CLI cli-drive@0.6.0\n" +
					"Proton Drive SDK js@0.19.0\n",
			), nil
		}
		switch arguments[1] {
		case "info":
			return json.Marshal(protonNode{
				Name: protonString("Akator Wallet"),
				Type: "folder",
			})
		case "list":
			return json.Marshal([]protonNode{
				{
					Name:             protonString("cards"),
					Type:             "folder",
					ModificationTime: time.Unix(10, 0),
				},
				{Name: protonString("front.png"), Type: "file"},
				{Name: protonString("notes.txt"), Type: "file"},
				{Name: protonString(".metadata"), Type: "folder"},
				{Name: protonString(".hidden.png"), Type: "file"},
			})
		default:
			t.Fatalf("unexpected arguments: %v", arguments)
			return nil, nil
		}
	})
	backend, err := NewProtonBackend(
		"proton_drive",
		"/my-files/Akator Wallet",
		runner,
	)
	if err != nil {
		t.Fatal(err)
	}

	if err := backend.Health(context.Background()); err != nil {
		t.Fatal(err)
	}
	entries, err := backend.List(context.Background(), "")
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 2 {
		t.Fatalf("unexpected entries: %#v", entries)
	}
	wantInfo := []string{
		"filesystem",
		"info",
		"-j",
		"/my-files/Akator Wallet",
	}
	if !reflect.DeepEqual(calls[1], wantInfo) {
		t.Fatalf("info arguments = %v, want %v", calls[1], wantInfo)
	}
}

func TestProtonBackendRead(t *testing.T) {
	runner := runnerFunc(func(
		_ context.Context,
		arguments ...string,
	) ([]byte, error) {
		directory := arguments[len(arguments)-1]
		if err := os.WriteFile(
			filepath.Join(directory, "front.png"),
			testPNG(t),
			0o600,
		); err != nil {
			t.Fatal(err)
		}
		return []byte(`{}`), nil
	})
	backend, err := NewProtonBackend(
		"proton_drive",
		"/my-files/Akator Wallet",
		runner,
	)
	if err != nil {
		t.Fatal(err)
	}

	file, err := backend.Read(context.Background(), "cards/front.png")
	if err != nil {
		t.Fatal(err)
	}
	if file.MIMEType != "image/png" {
		t.Fatalf("unexpected MIME type: %s", file.MIMEType)
	}
}

func TestProtonBackendWriteUsesSeparateArguments(t *testing.T) {
	var upload []string
	runner := runnerFunc(func(
		_ context.Context,
		arguments ...string,
	) ([]byte, error) {
		switch arguments[1] {
		case "upload":
			upload = append([]string(nil), arguments...)
			return []byte(`{}`), nil
		case "info":
			return json.Marshal(protonNode{
				Name:             protonString("front.png"),
				Type:             "file",
				ModificationTime: time.Unix(20, 0),
			})
		default:
			t.Fatalf("unexpected arguments: %v", arguments)
			return nil, nil
		}
	})
	backend, err := NewProtonBackend(
		"proton_drive",
		"/my-files/Akator Wallet",
		runner,
	)
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
	if entry.Path != "cards/front.png" {
		t.Fatalf("unexpected entry: %#v", entry)
	}
	if upload[len(upload)-1] != "/my-files/Akator Wallet/cards" {
		t.Fatalf("remote parent is not one argument: %v", upload)
	}
}

func TestProtonBackendSupportsEncryptedNameResults(t *testing.T) {
	var node protonNode
	err := json.Unmarshal(
		[]byte(`{"name":{"ok":true,"value":"front.png"},"type":"file"}`),
		&node,
	)
	if err != nil {
		t.Fatal(err)
	}
	if node.Name != "front.png" {
		t.Fatalf("name = %q", node.Name)
	}

	for _, version := range []string{
		"Proton Drive CLI cli-drive@0.4.6+build",
		"Proton Drive CLI cli-drive@0.6.0",
	} {
		if !supportedProtonVersion(version) {
			t.Fatalf("version should be supported: %q", version)
		}
	}
	for _, version := range []string{
		"Proton Drive CLI cli-drive@0.4.5",
		"Proton Drive CLI cli-drive@0.7.0",
		"Proton Drive CLI cli-drive@1.0.0",
		"unexpected",
	} {
		if supportedProtonVersion(version) {
			t.Fatalf("version should be rejected: %q", version)
		}
	}
}

func TestProtonBackendRedactsCommandAndJSONFailures(t *testing.T) {
	commandFailure := runnerFunc(func(
		context.Context,
		...string,
	) ([]byte, error) {
		return nil, ErrUnavailable
	})
	backend, err := NewProtonBackend(
		"proton_drive",
		"/my-files/Akator Wallet",
		commandFailure,
	)
	if err != nil {
		t.Fatal(err)
	}
	if !errors.Is(backend.Health(context.Background()), ErrUnavailable) {
		t.Fatal("command failure should be unavailable")
	}

	malformed := runnerFunc(func(
		_ context.Context,
		arguments ...string,
	) ([]byte, error) {
		if arguments[0] == "--version" {
			return []byte("Proton Drive CLI cli-drive@0.6.0"), nil
		}
		return []byte("secret malformed response"), nil
	})
	backend, err = NewProtonBackend(
		"proton_drive",
		"/my-files/Akator Wallet",
		malformed,
	)
	if err != nil {
		t.Fatal(err)
	}
	healthErr := backend.Health(context.Background())
	if !errors.Is(healthErr, ErrUnavailable) {
		t.Fatalf("got %v, want unavailable", healthErr)
	}
	if healthErr.Error() == "secret malformed response" {
		t.Fatal("provider output leaked through error")
	}
}
