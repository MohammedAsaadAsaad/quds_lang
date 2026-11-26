# Quds Desktop Installer (`quds_installer`)

Cross-platform desktop installer and environment analyzer for the **Quds programming language**, distributed as a **single clickable file** for **Windows (`.exe`), macOS (`.dmg`), and Linux (standalone binary)**.

## Features

- **Professional Typography & Low-Noise UI**: Bundled `IBM Plex Sans Arabic` (Arabic RTL + English LTR) and `JetBrains Mono` fonts with calm dark and light themes.
- **System & Prerequisite Analysis**: Detects your OS, Dart SDK (`>=3.3.0 <4.0.0`), Git, Flutter SDK (optional), Quds CLI (plus legacy `quds_lang`), `pub-cache/bin` on `PATH`, and 7 editors/IDEs (`VS Code`, `Cursor`, `Windsurf`, `VSCodium`, `VS Code Insiders`, `Android Studio / JetBrains`, and `Claude Code`).
- **Guided Prerequisite Assistant**: OS-specific commands (`winget`, `Homebrew` / `Xcode CLT`, `APT` / `Snap`) with one-click automated execution where supported, copyable commands, and official setup links.
- **Single-File Distribution**:
  - **Windows:** `Quds-Installer-Windows-x64.exe` (single GUI `.exe` with embedded Quds icon — no extraction folder or console window).
  - **Linux:** `Quds-Installer-Linux-x64` (single standalone executable binary — no FUSE dependency required).
  - **macOS:** `Quds-Installer-macOS.dmg` (native single-file disk image containing `Quds Installer.app`).

## Developing & Testing Locally

```bash
cd installer
flutter pub get
flutter analyze
flutter test

cd launcher
go test ./...
```

Prebuilt single-file installers are generated automatically by `.github/workflows/installer-release.yml`.
