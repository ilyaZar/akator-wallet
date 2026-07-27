package storage

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

const maxProtonOutputBytes = 8 << 20

var errCommandOutputTooLarge = errors.New("command output exceeds limit")

// CommandRunner is the replaceable Proton CLI process boundary.
type CommandRunner interface {
	Output(context.Context, ...string) ([]byte, error)
}

// ExecRunner invokes the official Proton Drive CLI without a shell.
type ExecRunner struct {
	Binary string
}

// Output returns stdout while redacting command diagnostics from errors.
func (r ExecRunner) Output(ctx context.Context, arguments ...string) ([]byte, error) {
	command := exec.CommandContext(ctx, r.Binary, arguments...)
	output := &cappedBuffer{maximum: maxProtonOutputBytes}
	command.Stdout = output
	err := command.Run()
	if err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return nil, fmt.Errorf("%w: proton command timed out", ErrUnavailable)
		}
		return nil, fmt.Errorf("%w: proton command failed", ErrUnavailable)
	}
	return output.Bytes(), nil
}

type cappedBuffer struct {
	bytes.Buffer
	maximum int
}

func (b *cappedBuffer) Write(data []byte) (int, error) {
	if b.Len()+len(data) > b.maximum {
		return 0, errCommandOutputTooLarge
	}
	return b.Buffer.Write(data)
}

// ProtonBackend provides explicit file operations through Proton Drive CLI.
type ProtonBackend struct {
	id     string
	root   string
	runner CommandRunner
}

type protonNode struct {
	Name             protonString `json:"name"`
	Type             string       `json:"type"`
	UID              string       `json:"uid"`
	ModificationTime time.Time    `json:"modificationTime"`
}

type protonString string

func (value *protonString) UnmarshalJSON(data []byte) error {
	var direct string
	if err := json.Unmarshal(data, &direct); err == nil {
		*value = protonString(direct)
		return nil
	}

	var result struct {
		OK    bool   `json:"ok"`
		Value string `json:"value"`
	}
	if err := json.Unmarshal(data, &result); err != nil || !result.OK {
		return errors.New("unavailable encrypted value")
	}
	*value = protonString(result.Value)
	return nil
}

// NewProtonBackend creates an adapter rooted at a Proton Drive folder.
func NewProtonBackend(
	id string,
	root string,
	runner CommandRunner,
) (*ProtonBackend, error) {
	root = strings.TrimSpace(root)
	if !strings.HasPrefix(root, "/") || path.Clean(root) != root ||
		root == "/" || strings.Contains(root, "\\") {
		return nil, errors.New("invalid Proton root")
	}
	return &ProtonBackend{id: id, root: root, runner: runner}, nil
}

// ID returns the stable API identifier.
func (b *ProtonBackend) ID() string {
	return b.id
}

// Health verifies authentication and access to the configured remote root.
func (b *ProtonBackend) Health(ctx context.Context) error {
	output, err := b.runner.Output(ctx, "--version")
	if err != nil {
		return err
	}
	if !supportedProtonVersion(string(output)) {
		return ErrUnsupportedVersion
	}

	output, err = b.runner.Output(
		ctx,
		"filesystem", "info", "-j", b.root,
	)
	if err != nil {
		return err
	}
	var node protonNode
	if err := json.Unmarshal(output, &node); err != nil ||
		node.Type != "folder" {
		return fmt.Errorf("%w: malformed Proton response", ErrUnavailable)
	}
	return nil
}

// List returns child folders and supported image files.
func (b *ProtonBackend) List(
	ctx context.Context,
	relative string,
) ([]Entry, error) {
	cleaned, err := CleanPath(relative, true)
	if err != nil {
		return nil, err
	}
	output, err := b.runner.Output(
		ctx,
		"filesystem", "list", "-j", b.remotePath(cleaned),
	)
	if err != nil {
		return nil, err
	}
	var nodes []protonNode
	if err := json.Unmarshal(output, &nodes); err != nil {
		return nil, fmt.Errorf("%w: malformed Proton response", ErrUnavailable)
	}

	entries := make([]Entry, 0, len(nodes))
	for _, node := range nodes {
		name := string(node.Name)
		if validateEntryName(name) != nil {
			continue
		}
		kind := node.Type
		if kind == "file" {
			if !supportedImageName(name) {
				continue
			}
			kind = "image"
		}
		if kind != "folder" && kind != "image" {
			continue
		}
		entries = append(entries, Entry{
			Path:       path.Join(cleaned, name),
			Name:       name,
			Kind:       kind,
			MIMEType:   mimeTypeForName(name),
			ModifiedAt: node.ModificationTime.UTC(),
		})
	}
	sort.Slice(entries, func(i, j int) bool {
		if entries[i].Kind != entries[j].Kind {
			return entries[i].Kind == "folder"
		}
		return entries[i].Name < entries[j].Name
	})
	return entries, nil
}

// Read downloads one remote image into a short-lived private directory.
func (b *ProtonBackend) Read(
	ctx context.Context,
	relative string,
) (File, error) {
	cleaned, err := CleanPath(relative, false)
	if err != nil {
		return File{}, err
	}
	if err := validateEntryName(path.Base(cleaned)); err != nil {
		return File{}, err
	}

	temporary, err := os.MkdirTemp("", "akator-proton-download-*")
	if err != nil {
		return File{}, ErrUnavailable
	}
	defer os.RemoveAll(temporary)

	_, err = b.runner.Output(
		ctx,
		"filesystem", "download", "-j",
		"--file-conflict-strategy", "replace",
		b.remotePath(cleaned), temporary,
	)
	if err != nil {
		return File{}, err
	}
	localPath := filepath.Join(temporary, path.Base(cleaned))
	info, err := os.Lstat(localPath)
	if err != nil {
		return File{}, fmt.Errorf("%w: Proton download missing", ErrUnavailable)
	}
	if !info.Mode().IsRegular() {
		return File{}, ErrNotImage
	}
	if info.Size() > MaxImageBytes {
		return File{}, ErrTooLarge
	}
	data, err := os.ReadFile(localPath)
	if err != nil {
		return File{}, fmt.Errorf("%w: Proton download missing", ErrUnavailable)
	}
	mimeType, err := ValidateImage(path.Base(cleaned), data)
	if err != nil {
		return File{}, err
	}
	return File{Data: data, MIMEType: mimeType}, nil
}

// Write uploads one image with deterministic conflict replacement.
func (b *ProtonBackend) Write(
	ctx context.Context,
	relative string,
	data []byte,
) (Entry, error) {
	cleaned, err := CleanPath(relative, false)
	if err != nil {
		return Entry{}, err
	}
	name := path.Base(cleaned)
	if err := validateEntryName(name); err != nil {
		return Entry{}, err
	}
	mimeType, err := ValidateImage(name, data)
	if err != nil {
		return Entry{}, err
	}

	temporary, err := os.MkdirTemp("", "akator-proton-upload-*")
	if err != nil {
		return Entry{}, ErrUnavailable
	}
	defer os.RemoveAll(temporary)
	localPath := filepath.Join(temporary, name)
	if err := os.WriteFile(localPath, data, 0o600); err != nil {
		return Entry{}, ErrUnavailable
	}

	parent := path.Dir(cleaned)
	if parent == "." {
		parent = ""
	}
	_, err = b.runner.Output(
		ctx,
		"filesystem", "upload", "-j",
		"--file-conflict-strategy", "replace",
		localPath, b.remotePath(parent),
	)
	if err != nil {
		return Entry{}, err
	}
	output, err := b.runner.Output(
		ctx,
		"filesystem", "info", "-j", b.remotePath(cleaned),
	)
	if err != nil {
		return Entry{}, err
	}
	var node protonNode
	if err := json.Unmarshal(output, &node); err != nil ||
		node.Type != "file" {
		return Entry{}, fmt.Errorf("%w: malformed Proton response", ErrUnavailable)
	}
	return Entry{
		Path:       cleaned,
		Name:       name,
		Kind:       "image",
		MIMEType:   mimeType,
		Size:       int64(len(data)),
		ModifiedAt: node.ModificationTime.UTC(),
	}, nil
}

func supportedProtonVersion(output string) bool {
	const prefix = "Proton Drive CLI cli-drive@"
	start := strings.Index(output, prefix)
	if start == -1 {
		return false
	}
	version := strings.TrimSpace(
		strings.SplitN(output[start+len(prefix):], "\n", 2)[0],
	)
	parts := strings.SplitN(version, ".", 3)
	if len(parts) != 3 {
		return false
	}
	major, majorErr := strconv.Atoi(parts[0])
	minor, minorErr := strconv.Atoi(parts[1])
	patchEnd := 0
	for patchEnd < len(parts[2]) &&
		parts[2][patchEnd] >= '0' &&
		parts[2][patchEnd] <= '9' {
		patchEnd++
	}
	if patchEnd == 0 {
		return false
	}
	patchText := parts[2][:patchEnd]
	patch, patchErr := strconv.Atoi(patchText)
	if majorErr != nil || minorErr != nil || patchErr != nil {
		return false
	}
	if major != 0 {
		return false
	}
	return minor == 4 && patch >= 6 || minor == 5 || minor == 6
}

func (b *ProtonBackend) remotePath(relative string) string {
	if relative == "" {
		return b.root
	}
	return b.root + "/" + relative
}
