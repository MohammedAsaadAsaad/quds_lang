package main

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

func main() {
	if err := run(embeddedPayload, os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "Quds Installer launcher error: %v\n", err)
		os.Exit(1)
	}
}

func run(payload []byte, args []string) error {
	if len(payload) == 0 {
		return errors.New("embedded installer payload is empty")
	}
	bundleDir, err := ensureExtracted(payload)
	if err != nil {
		return err
	}

	exeName := "quds_installer"
	if runtime.GOOS == "windows" {
		exeName = "quds_installer.exe"
	}
	exePath := filepath.Join(bundleDir, exeName)
	if _, err := os.Stat(exePath); err != nil {
		return fmt.Errorf("installer executable not found at %s: %w", exePath, err)
	}

	cmd := exec.Command(exePath, args...)
	cmd.Dir = bundleDir
	cmd.Env = os.Environ()
	if runtime.GOOS != "windows" {
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
	}
	return cmd.Run()
}

func cacheRoot() string {
	if runtime.GOOS == "windows" {
		if local := os.Getenv("LOCALAPPDATA"); local != "" {
			return filepath.Join(local, "QudsInstaller")
		}
	} else if dir, err := os.UserCacheDir(); err == nil && dir != "" {
		return filepath.Join(dir, "quds-installer")
	}
	return filepath.Join(os.TempDir(), "quds-installer")
}

func ensureExtracted(payload []byte) (string, error) {
	sum := sha256.Sum256(payload)
	hash := hex.EncodeToString(sum[:])[:12]
	root := cacheRoot()
	targetDir := filepath.Join(root, "bundle-"+hash)
	readyFile := filepath.Join(targetDir, ".ready")

	if _, err := os.Stat(readyFile); err == nil {
		return targetDir, nil
	}

	if err := os.MkdirAll(root, 0o755); err != nil {
		return "", fmt.Errorf("create cache root: %w", err)
	}

	tmpDir, err := os.MkdirTemp(root, "extract-*")
	if err != nil {
		return "", fmt.Errorf("create temp extract dir: %w", err)
	}
	cleanupTmp := true
	defer func() {
		if cleanupTmp {
			_ = os.RemoveAll(tmpDir)
		}
	}()

	if err := extractZip(payload, tmpDir); err != nil {
		return "", err
	}
	if err := os.WriteFile(filepath.Join(tmpDir, ".ready"), []byte(hash), 0o644); err != nil {
		return "", err
	}

	if err := os.Rename(tmpDir, targetDir); err != nil {
		// Another process may have extracted the same bundle concurrently.
		if _, statErr := os.Stat(readyFile); statErr == nil {
			return targetDir, nil
		}
		return "", fmt.Errorf("finalize extracted bundle: %w", err)
	}
	cleanupTmp = false
	return targetDir, nil
}

func extractZip(payload []byte, dest string) error {
	zr, err := zip.NewReader(bytes.NewReader(payload), int64(len(payload)))
	if err != nil {
		return fmt.Errorf("read embedded zip: %w", err)
	}
	cleanDest := filepath.Clean(dest) + string(os.PathSeparator)

	for _, f := range zr.File {
		rel := filepath.FromSlash(f.Name)
		outPath := filepath.Join(dest, rel)
		if !strings.HasPrefix(filepath.Clean(outPath)+string(os.PathSeparator), cleanDest) &&
			filepath.Clean(outPath) != filepath.Clean(dest) {
			return fmt.Errorf("unsafe zip entry path: %s", f.Name)
		}

		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(outPath, 0o755); err != nil {
				return err
			}
			continue
		}

		if err := os.MkdirAll(filepath.Dir(outPath), 0o755); err != nil {
			return err
		}

		mode := f.Mode()
		if mode == 0 {
			mode = 0o644
		}
		if runtime.GOOS != "windows" && filepath.Base(outPath) == "quds_installer" {
			mode |= 0o755
		}

		rc, err := f.Open()
		if err != nil {
			return err
		}
		outFile, err := os.OpenFile(outPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, mode)
		if err != nil {
			_ = rc.Close()
			return err
		}
		_, copyErr := io.Copy(outFile, rc)
		closeErr := outFile.Close()
		_ = rc.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeErr != nil {
			return closeErr
		}
	}
	return nil
}
