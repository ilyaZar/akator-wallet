package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestValidateTransport(t *testing.T) {
	tests := []struct {
		name    string
		options options
		wantErr bool
	}{
		{
			name:    "loopback HTTP",
			options: options{listen: "127.0.0.1:8787"},
		},
		{
			name: "non-loopback TLS",
			options: options{
				listen:         "0.0.0.0:8787",
				tlsCertificate: "server.crt",
				tlsKey:         "server.key",
			},
		},
		{
			name:    "non-loopback HTTP rejected",
			options: options{listen: "0.0.0.0:8787"},
			wantErr: true,
		},
		{
			name: "incomplete TLS rejected",
			options: options{
				listen:         "127.0.0.1:8787",
				tlsCertificate: "server.crt",
			},
			wantErr: true,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := validateTransport(test.options)
			if (err != nil) != test.wantErr {
				t.Fatalf("validateTransport() error = %v", err)
			}
		})
	}
}

func TestReadTokenRequiresPrivateStrongFile(t *testing.T) {
	directory := t.TempDir()
	tokenFile := filepath.Join(directory, "token")
	if err := os.WriteFile(
		tokenFile,
		[]byte("0123456789abcdef0123456789abcdef\n"),
		0o600,
	); err != nil {
		t.Fatal(err)
	}
	token, err := readToken(tokenFile)
	if err != nil {
		t.Fatal(err)
	}
	if string(token) != "0123456789abcdef0123456789abcdef" {
		t.Fatal("token was not trimmed")
	}

	if err := os.Chmod(tokenFile, 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := readToken(tokenFile); err == nil ||
		!strings.Contains(err.Error(), "group/world") {
		t.Fatalf("public token mode should fail, got %v", err)
	}
}

func TestBuildBackendsDetectsMissingProtonCLI(t *testing.T) {
	_, err := buildBackends(options{
		protonRoot: "/my-files/Akator Wallet",
		protonCLI:  filepath.Join(t.TempDir(), "missing"),
	})
	if err == nil || !strings.Contains(err.Error(), "CLI is unavailable") {
		t.Fatalf("missing CLI should fail, got %v", err)
	}
}
