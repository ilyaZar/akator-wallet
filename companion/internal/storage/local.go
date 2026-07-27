package storage

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
)

// LocalBackend serves a directory managed by the host Syncthing daemon.
type LocalBackend struct {
	id   string
	root string
}

// NewLocalBackend creates a backend rooted at an existing real directory.
func NewLocalBackend(id, root string) (*LocalBackend, error) {
	absolute, err := filepath.Abs(root)
	if err != nil {
		return nil, fmt.Errorf("resolve local root: %w", err)
	}
	realRoot, err := filepath.EvalSymlinks(absolute)
	if err != nil {
		return nil, fmt.Errorf("resolve local root: %w", err)
	}
	info, err := os.Stat(realRoot)
	if err != nil {
		return nil, fmt.Errorf("stat local root: %w", err)
	}
	if !info.IsDir() {
		return nil, errors.New("local root is not a directory")
	}
	return &LocalBackend{id: id, root: realRoot}, nil
}

// ID returns the stable API identifier.
func (b *LocalBackend) ID() string {
	return b.id
}

// Health verifies that the configured root is still accessible.
func (b *LocalBackend) Health(context.Context) error {
	info, err := os.Stat(b.root)
	if err != nil || !info.IsDir() {
		return ErrUnavailable
	}
	return nil
}

// List returns child folders and supported images.
func (b *LocalBackend) List(_ context.Context, relative string) ([]Entry, error) {
	resolved, cleaned, err := b.resolveExisting(relative, true)
	if err != nil {
		return nil, err
	}
	info, err := os.Stat(resolved)
	if err != nil {
		return nil, mapLocalError(err)
	}
	if !info.IsDir() {
		return nil, ErrInvalidPath
	}

	children, err := os.ReadDir(resolved)
	if err != nil {
		return nil, mapLocalError(err)
	}
	entries := make([]Entry, 0, len(children))
	for _, child := range children {
		if strings.HasPrefix(child.Name(), ".") ||
			child.Type()&os.ModeSymlink != 0 {
			continue
		}
		childInfo, childErr := child.Info()
		if childErr != nil {
			continue
		}
		if !childInfo.IsDir() && !supportedImageName(child.Name()) {
			continue
		}

		kind := "folder"
		mimeType := ""
		if !childInfo.IsDir() {
			kind = "image"
			mimeType = mimeTypeForName(child.Name())
		}
		entries = append(entries, Entry{
			Path:       path.Join(cleaned, child.Name()),
			Name:       child.Name(),
			Kind:       kind,
			MIMEType:   mimeType,
			Size:       childInfo.Size(),
			ModifiedAt: childInfo.ModTime().UTC(),
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

// Read returns a supported image without following symlinks outside the root.
func (b *LocalBackend) Read(_ context.Context, relative string) (File, error) {
	resolved, cleaned, err := b.resolveExisting(relative, false)
	if err != nil {
		return File{}, err
	}
	info, err := os.Stat(resolved)
	if err != nil {
		return File{}, mapLocalError(err)
	}
	if !info.Mode().IsRegular() || info.Size() > MaxImageBytes {
		if info.Size() > MaxImageBytes {
			return File{}, ErrTooLarge
		}
		return File{}, ErrNotImage
	}

	data, err := os.ReadFile(resolved)
	if err != nil {
		return File{}, mapLocalError(err)
	}
	mimeType, err := ValidateImage(path.Base(cleaned), data)
	if err != nil {
		return File{}, err
	}
	return File{Data: data, MIMEType: mimeType}, nil
}

// Write atomically stores a supported image in an existing folder.
func (b *LocalBackend) Write(
	_ context.Context,
	relative string,
	data []byte,
) (Entry, error) {
	cleaned, err := CleanPath(relative, false)
	if err != nil {
		return Entry{}, err
	}
	if err := validateEntryName(path.Base(cleaned)); err != nil {
		return Entry{}, err
	}
	mimeType, err := ValidateImage(path.Base(cleaned), data)
	if err != nil {
		return Entry{}, err
	}

	parentRelative := path.Dir(cleaned)
	if parentRelative == "." {
		parentRelative = ""
	}
	parent, _, err := b.resolveExisting(parentRelative, true)
	if err != nil {
		return Entry{}, err
	}
	parentInfo, err := os.Stat(parent)
	if err != nil || !parentInfo.IsDir() {
		return Entry{}, ErrInvalidPath
	}

	target := filepath.Join(parent, path.Base(cleaned))
	if targetInfo, targetErr := os.Lstat(target); targetErr == nil &&
		targetInfo.Mode()&os.ModeSymlink != 0 {
		return Entry{}, ErrInvalidPath
	}

	temporary, err := os.CreateTemp(parent, ".akator-upload-*")
	if err != nil {
		return Entry{}, mapLocalError(err)
	}
	temporaryName := temporary.Name()
	removeTemporary := true
	defer func() {
		if removeTemporary {
			_ = os.Remove(temporaryName)
		}
	}()

	if err := temporary.Chmod(0o600); err != nil {
		_ = temporary.Close()
		return Entry{}, errors.New("prepare atomic image")
	}
	if _, err := temporary.Write(data); err != nil {
		_ = temporary.Close()
		return Entry{}, errors.New("write atomic image")
	}
	if err := temporary.Sync(); err != nil {
		_ = temporary.Close()
		return Entry{}, errors.New("sync atomic image")
	}
	if err := temporary.Close(); err != nil {
		return Entry{}, errors.New("close atomic image")
	}
	if err := os.Rename(temporaryName, target); err != nil {
		return Entry{}, errors.New("commit atomic image")
	}
	removeTemporary = false

	info, err := os.Stat(target)
	if err != nil {
		return Entry{}, mapLocalError(err)
	}
	return Entry{
		Path:       cleaned,
		Name:       path.Base(cleaned),
		Kind:       "image",
		MIMEType:   mimeType,
		Size:       info.Size(),
		ModifiedAt: info.ModTime().UTC(),
	}, nil
}

func (b *LocalBackend) resolveExisting(
	relative string,
	allowRoot bool,
) (string, string, error) {
	cleaned, err := CleanPath(relative, allowRoot)
	if err != nil {
		return "", "", err
	}
	candidate := filepath.Join(b.root, filepath.FromSlash(cleaned))
	realCandidate, err := filepath.EvalSymlinks(candidate)
	if err != nil {
		return "", "", mapLocalError(err)
	}
	if !withinRoot(b.root, realCandidate) {
		return "", "", ErrInvalidPath
	}
	return realCandidate, cleaned, nil
}

func withinRoot(root, candidate string) bool {
	relative, err := filepath.Rel(root, candidate)
	return err == nil && relative != ".." &&
		!filepath.IsAbs(relative) &&
		!startsWithParent(relative)
}

func startsWithParent(value string) bool {
	return value == ".." ||
		len(value) > 3 && value[:3] == ".."+string(filepath.Separator)
}

func mapLocalError(err error) error {
	if errors.Is(err, os.ErrNotExist) {
		return ErrNotFound
	}
	if errors.Is(err, os.ErrPermission) {
		return ErrUnavailable
	}
	return ErrUnavailable
}
