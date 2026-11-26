package main

import (
	"archive/zip"
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func TestExtractZipAndCache(t *testing.T) {
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	f, err := zw.Create("quds_installer")
	if err != nil {
		t.Fatalf("create zip entry: %v", err)
	}
	if _, err := f.Write([]byte("#!/bin/sh\necho ok\n")); err != nil {
		t.Fatalf("write zip entry: %v", err)
	}
	nested, err := zw.Create("data/flutter_assets/test.txt")
	if err != nil {
		t.Fatalf("create nested entry: %v", err)
	}
	if _, err := nested.Write([]byte("hello quds")); err != nil {
		t.Fatalf("write nested entry: %v", err)
	}
	if err := zw.Close(); err != nil {
		t.Fatalf("close zip: %v", err)
	}

	dest := t.TempDir()
	if err := extractZip(buf.Bytes(), dest); err != nil {
		t.Fatalf("extractZip failed: %v", err)
	}

	content, err := os.ReadFile(filepath.Join(dest, "data", "flutter_assets", "test.txt"))
	if err != nil {
		t.Fatalf("read extracted file: %v", err)
	}
	if string(content) != "hello quds" {
		t.Fatalf("unexpected content: %q", string(content))
	}
}
