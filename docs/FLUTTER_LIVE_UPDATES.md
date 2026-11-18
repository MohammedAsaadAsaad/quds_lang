# Flutter live updates from Quds

## Start

After `flutter pub get` in a Flutter project:

```sh
quds run lib/main.quds
quds run lib/main.quds -- -d chrome
quds run lib/main.quds -- -d linux
```

The source entry point stays `.quds`. Quds generates the complete dependency
graph under `lib/quds_gen/`, launches `flutter run --machine` with the generated
target, and monitors saved Quds source files. Saving from VS Code, another editor,
or an atomic file replacement follows the same path. VS Code's **Quds: Run**
command starts this CLI path in its integrated terminal; no additional save hook
or build watcher is necessary.

| Action | Result |
| --- | --- |
| Save a Quds source or imported Quds file | Compile; request hot reload if valid |
| `r` in the running Quds terminal | Rebuild/check sources and request hot reload |
| `R` | Rebuild/check sources and request hot restart |
| `q` or Ctrl+C | Stop the running Flutter session |
| `h` | Show keyboard help |

Keys work without Enter in an interactive terminal. Flutter device/tool arguments
follow `--`. The generated target, machine transport and debug execution mode
are controlled by Quds; release/profile or target overrides are rejected.

## What happens on save

1. Two stable polls, normally about 250–500ms, coalesce editor save bursts.
   Compilation and Flutter's own reload time are additional; no end-to-end
   latency guarantee is implied.
2. The compiler validates the entry point and all imported Quds dependencies
   before writing any generated module. A file is reused from an in-process
   compilation cache only while its source and recorded dependencies match.
3. Successful output includes shared SDK libraries and Quds source maps. The
   generated entry point retains Quds runtime stack mapping.
4. After Flutter reports application startup, Quds sends `app.restart` with
   `fullRestart: false`. Manual `R` uses `fullRestart: true`.
5. Only one update is in flight. Further saves are coalesced; a pending explicit
   restart takes precedence. Saves during startup wait for application readiness.
   If sources change during compilation, another build precedes the update.

The monitor includes newly created Quds files, deletions, imported files outside
the project, and nested imports. Generated output, `.git`, `.dart_tool` and build
folders are excluded from directory scanning. It reads saved disk contents;
unsaved editor buffers are not executed.

## Errors, state and limits

A Quds compilation error is reported in original `.quds` coordinates, does not
request an update, and leaves the last valid generated graph intact. Correct the
source and save again. Non-generated files in output locations are protected;
initial ownership violations retain CLI exit code 73. Filesystem write failures
are reported, but multi-file output writes are not a crash-safe filesystem
transaction.

Hot reload normally preserves application state; it does not rerun `main()` or
`initState()`. Flutter can reject structural changes that require a restart.
Quds reports the rejection and offers `R`; it does not silently discard state by
falling back to restart. Native/plugin changes and pub dependency/configuration
changes can require stopping and relaunching the session. The source watcher is
for Quds files, not a pub dependency installer or a Dart-file watcher.

This integration is for **`quds run` / Quds: Run**. Existing `quds debug` / VS Code
F5 uses the separate Flutter debug-adapter path and is not given automatic save
reloading by this change. Direct `flutter run` after a one-off Quds build also
does not monitor Quds sources.

## Validation

`test/flutter_live_test.dart` compiles real Quds fixtures and drives an actual
child process implementing Flutter's machine-protocol messages. It verifies saved
imports, graph error protection, recovery, newly created imports, atomic saves,
manual restart, startup queues, overlapping updates, Flutter rejection/retry,
device argument forwarding and output ownership. The ordinary CLI Flutter launch
test now checks the machine-mode target.

These are compiler/protocol integration tests, not Flutter rendering tests.
The managed environment still lacks downloadable Flutter engine artifacts, so
actual device/browser hot state preservation and restart execution must be checked
with the real SDK. No such device execution is claimed here. Exact suite results
are recorded in `docs/VALIDATION.md`.
