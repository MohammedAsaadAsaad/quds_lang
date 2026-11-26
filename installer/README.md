# Quds Desktop Installer (`quds_installer`)

Cross-platform desktop installer and environment analyzer for the **Quds programming language**, targeting **Windows, macOS, and Linux**.

## Features

- **System & Prerequisite Analysis**: Detects your OS, Dart SDK (`>=3.3.0 <4.0.0`), Git, Flutter SDK (optional), Quds CLI (plus legacy `quds_lang` detection), `pub-cache/bin` on `PATH`, and 7 editors/IDEs (`VS Code`, `Cursor`, `Windsurf`, `VSCodium`, `VS Code Insiders`, `Android Studio / JetBrains`, and `Claude Code`).
- **Guided Prerequisite Assistant**: Provides OS-specific installation instructions (`winget` on Windows, `Homebrew` / `Xcode CLT` on macOS, `APT` / `Snap` on Linux), one-click automated installation where supported, copyable commands, and official setup links.
- **Customizable Setup**: Choose between official `pub.dev` releases (`quds 0.1.0-alpha.2` or a custom version) and a local repository checkout, configure `PATH` automatically, clean up legacy `quds_lang`, select editor support, and run `quds doctor`.
- **Live Installation Console**: Real-time step progress checklist and color-coded command output with log copying.
- **Bilingual & Branded UI**: Arabic (RTL) and English (LTR), Midnight Navy + Dome Gold dark theme and light theme, official Quds app icon on Windows (`.ico`), macOS (`.appiconset`), and Linux (`.png` + `.desktop`).

## Building Locally

```bash
cd installer
flutter pub get
flutter analyze
flutter test

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux (requires libgtk-3-dev, clang, cmake, ninja-build)
flutter build linux --release
```

Prebuilt release archives (`Quds-Installer-Windows-x64.zip`, `Quds-Installer-Linux-x64.tar.gz`, `Quds-Installer-macOS.zip`) are built automatically by `.github/workflows/installer-release.yml`.
