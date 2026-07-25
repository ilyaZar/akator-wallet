package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/akator/akator-wallet/companion/internal/server"
	"github.com/akator/akator-wallet/companion/internal/storage"
)

const version = "0.1.0"

type options struct {
	listen            string
	tokenFile         string
	syncthingRoot     string
	protonRoot        string
	protonCLI         string
	tlsCertificate    string
	tlsKey            string
	allowInsecureHTTP bool
	showVersion       bool
}

func main() {
	if err := run(context.Background(), os.Args[1:]); err != nil {
		log.Printf("companion stopped: %v", err)
		os.Exit(1)
	}
}

func run(parent context.Context, arguments []string) error {
	opts, err := parseOptions(arguments)
	if err != nil {
		return err
	}
	if opts.showVersion {
		fmt.Println(version)
		return nil
	}
	if err := validateTransport(opts); err != nil {
		return err
	}

	token, err := readToken(opts.tokenFile)
	if err != nil {
		return err
	}
	backends, err := buildBackends(opts)
	if err != nil {
		return err
	}
	handler, err := server.New(server.Config{Token: token, Backends: backends})
	if err != nil {
		return err
	}

	httpServer := &http.Server{
		Addr:              opts.listen,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       2 * time.Minute,
		WriteTimeout:      2 * time.Minute,
		IdleTimeout:       30 * time.Second,
		MaxHeaderBytes:    16 << 10,
	}
	ctx, stop := signal.NotifyContext(parent, os.Interrupt, syscall.SIGTERM)
	defer stop()

	errorsChannel := make(chan error, 1)
	go func() {
		if opts.tlsCertificate != "" {
			errorsChannel <- httpServer.ListenAndServeTLS(
				opts.tlsCertificate,
				opts.tlsKey,
			)
			return
		}
		errorsChannel <- httpServer.ListenAndServe()
	}()

	log.Printf("Akator storage companion %s listening on %s", version, opts.listen)
	select {
	case <-ctx.Done():
		shutdownContext, cancel := context.WithTimeout(
			context.Background(),
			10*time.Second,
		)
		defer cancel()
		return httpServer.Shutdown(shutdownContext)
	case serverErr := <-errorsChannel:
		if errors.Is(serverErr, http.ErrServerClosed) {
			return nil
		}
		return serverErr
	}
}

func parseOptions(arguments []string) (options, error) {
	flags := flag.NewFlagSet("akator-storage-companion", flag.ContinueOnError)
	var opts options
	flags.StringVar(&opts.listen, "listen", "127.0.0.1:8787", "listen address")
	flags.StringVar(&opts.tokenFile, "token-file", "", "access token file")
	flags.StringVar(
		&opts.syncthingRoot,
		"syncthing-root",
		"",
		"Syncthing-managed wallet directory",
	)
	flags.StringVar(
		&opts.protonRoot,
		"proton-root",
		"",
		"Proton Drive wallet root such as /my-files/Akator Wallet",
	)
	flags.StringVar(
		&opts.protonCLI,
		"proton-cli",
		"proton-drive",
		"official Proton Drive CLI path",
	)
	flags.StringVar(&opts.tlsCertificate, "tls-cert", "", "TLS certificate")
	flags.StringVar(&opts.tlsKey, "tls-key", "", "TLS private key")
	flags.BoolVar(
		&opts.allowInsecureHTTP,
		"allow-insecure-http",
		false,
		"allow explicit non-loopback plaintext HTTP",
	)
	flags.BoolVar(&opts.showVersion, "version", false, "show version")
	if err := flags.Parse(arguments); err != nil {
		return options{}, err
	}
	return opts, nil
}

func validateTransport(opts options) error {
	if (opts.tlsCertificate == "") != (opts.tlsKey == "") {
		return errors.New("TLS certificate and key must be configured together")
	}
	host, _, err := net.SplitHostPort(opts.listen)
	if err != nil {
		return errors.New("listen address must include host and port")
	}
	if opts.tlsCertificate == "" && !isLoopback(host) &&
		!opts.allowInsecureHTTP {
		return errors.New(
			"non-loopback HTTP requires TLS or --allow-insecure-http",
		)
	}
	return nil
}

func isLoopback(host string) bool {
	if host == "localhost" {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

func readToken(fileName string) ([]byte, error) {
	if fileName == "" {
		return nil, errors.New("--token-file is required")
	}
	info, err := os.Stat(fileName)
	if err != nil {
		return nil, errors.New("access token file is unavailable")
	}
	if info.Mode().Perm()&0o077 != 0 {
		return nil, errors.New("access token file must not be group/world readable")
	}
	token, err := os.ReadFile(fileName)
	if err != nil {
		return nil, errors.New("access token file is unavailable")
	}
	token = []byte(strings.TrimSpace(string(token)))
	if len(token) < 32 {
		return nil, errors.New("access token must contain at least 32 bytes")
	}
	return token, nil
}

func buildBackends(opts options) ([]storage.Backend, error) {
	backends := make([]storage.Backend, 0, 2)
	if opts.syncthingRoot != "" {
		backend, err := storage.NewLocalBackend("syncthing", opts.syncthingRoot)
		if err != nil {
			return nil, err
		}
		backends = append(backends, backend)
	}
	if opts.protonRoot != "" {
		binary, err := execPath(opts.protonCLI)
		if err != nil {
			return nil, err
		}
		backend, err := storage.NewProtonBackend(
			"proton_drive",
			opts.protonRoot,
			storage.ExecRunner{Binary: binary},
		)
		if err != nil {
			return nil, err
		}
		backends = append(backends, backend)
	}
	return backends, nil
}

func execPath(binary string) (string, error) {
	pathValue, err := exec.LookPath(binary)
	if err != nil {
		return "", errors.New("proton drive CLI is unavailable")
	}
	return pathValue, nil
}
