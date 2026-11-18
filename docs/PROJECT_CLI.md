# Familiar project commands

## Pub

```sh
quds pub get
quds pub add sqlite_plus
quds pub remove sqlite_plus
quds pub upgrade --major-versions
quds pub outdated
quds pub deps --json
quds pub cache repair
quds pub global list
quds pub publish --dry-run
quds pub --help
```

All arguments are passed as separate arguments to the native pub tool, without
a command whitelist or shell interpolation. Native stdout/stderr, stdin and exit
status are preserved. Non-Flutter projects use `dart pub`; projects declaring a
Flutter SDK dependency use `flutter pub`. The `-C`/`--directory` pub option is
considered when choosing the backend. SDK dependencies are read as YAML, including
flow mappings, rather than inferred from comments or string matching.

Existing `quds get`, `quds add` and `quds remove` remain aliases using the same
backend selection. Pub subcommands retain their native behavior; the CLI does
not add approvals or run other subcommands on the user's behalf.

## Add platforms in place

Inside an existing project:

```sh
quds create .
quds create . --platforms=linux,web,android
quds create . --platforms=windows,macos,ios --no-pub
quds create . --org com.example --platforms=android,ios
```

This is Flutter application scaffolding, so it needs the Flutter SDK. It invokes
Flutter create for platform files, preserves existing `pubspec.yaml` content and
adds the Flutter SDK dependency with a YAML-aware editor when needed. Existing
Quds sources, `quds.yaml`, custom `lib/main.dart`, and custom widget tests remain.
New Dart application/test boilerplate created by Flutter is removed when there
was no corresponding user file. `lib/main.quds` gets the Quds starter only if it
does not already exist, and generated output is added to `.gitignore`.

Pub resolution runs after the preserved configuration is restored, unless
`--no-pub` was requested. Flutter controls host/toolchain platform availability.
Existing platform files follow Flutter's default no-overwrite behavior; explicit
`--overwrite` is rejected. A failed scaffold restores protected existing files,
but platform generation is not a crash-safe filesystem transaction. Existing
root-level `main.quds` is preserved rather than silently moved to `lib/`.

`quds create <name>` still creates a plain Quds console project; the existing
`quds create flutter <name>` command remains available for a new Flutter app.

## Run with a default entry point

```sh
quds run
quds run -d linux
quds run -d chrome --debug
quds run -d android --release
quds run -d linux --profile
quds run lib/custom.quds -d linux --release
quds run --target=lib/custom.quds -d chrome
quds run -d chrome --dart-define=FLAVOR=demo --web-port=8080
```

Without an explicit source, the nearest project uses `lib/main.quds`, falling
back to `main.quds` for console projects. A Quds target can be supplied as a
positional source or `-t`/`--target`. The CLI generates and passes the matching
Dart target to Flutter. Native device/define/flavor/web and other tool arguments
are forwarded. The older `quds run lib/main.quds -- -d chrome` spelling remains
supported. Target selection must precede that optional `--` separator.

Debug is the default. Debug runs keep save-triggered hot reload and `r`/`R`/`q`.
Release, profile and `--no-hot` use ordinary Flutter execution after compiling
Quds; they do not install a hot-reload watcher. Conflicting execution modes and
attempts to override the internal machine transport are rejected. A Dart target
cannot replace the Quds entry point. Non-Flutter console runs retain their own
execution path; Flutter-only flags are not interpreted as console arguments.

## Validation scope

`test/project_cli_test.dart` exercises actual offline Dart pub get/deps, arbitrary
Flutter pub argument forwarding and error codes, protected-file platform setup,
YAML flow mappings, no-pub behavior, source autodiscovery, target/device selection
and all three execution modes. Flutter-side tests use a subprocess peer because
the managed environment lacks the engine SDK; no native platform build or device
execution is claimed. See `docs/VALIDATION.md` for exact results.

## Build a Flutter platform

```sh
quds build apk --release
quds build appbundle --release
quds build web
quds build linux --debug
quds build windows
quds build macos
quds build ios --no-codesign
quds build ipa
quds build bundle
quds build web -t lib/alternate.quds
```

These compile the selected Quds dependency graph, then invoke `flutter build`
with the generated target and forwarded native options/exit code. The default
entry is `lib/main.quds`. Platform builds require a Flutter project and its host
SDK/toolchains; source emission via `quds build file.quds` is unchanged. No live
watcher runs during platform builds.

A web build or explicit Chrome/Edge/web-server run selects `platform == "web"`;
native Flutter uses `"flutter"`, and plain compiler builds use `"vm"`.
`dart.library.io`, `dart.library.js_interop` and `dart.library.ui` follow that
compilation environment. Select a browser device explicitly when conditional
imports depend on the backend; automatic interactive device choice does not yet
reconfigure the compiler after Flutter selects a device. The LSP default is the
project's native environment, not every possible deployment target.

CLI integration tests validate real Quds compilation with a simulated Flutter
executable. Native artifacts and signing are not certified by those tests.
