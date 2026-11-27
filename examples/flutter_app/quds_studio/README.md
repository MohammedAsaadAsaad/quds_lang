# Quds Scientific Studio (Flutter Demo App)

An interactive cross-platform Flutter scientific workspace showcasing both pure-Dart embeddable Quds libraries:

- **`package:quds/interpreter.dart`**: `QudsSession`, `QudsExecutionPolicy` (`scientific`, `strictSandbox`, `systemBridge`), `QudsHostModule` (`host:sensors`), `QudsDebugController` (breakpoints, stepping, live frame evaluation), and `quds:viz` interactive geometry & plotting.
- **`package:quds/editor_engine.dart`**: `QudsEditorEngine` live syntax & semantic highlighting, official formatting (`formatQuds`), real-time syntax & policy diagnostics with one-click Quick Fixes, context-aware autocomplete, signature help, and indentation helpers.

## Run

```bash
cd examples/flutter_app/quds_studio
flutter pub get
flutter run -d linux   # or macos / windows / chrome
```

## Test

```bash
flutter analyze
flutter test
```
