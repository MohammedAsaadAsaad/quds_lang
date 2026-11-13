# Quds Language

Quds is a general-purpose, statically typed, indentation-based language targeting
Dart. MVP-0 implements a small compiler pipeline: source spans → indentation-aware
lexer → typed AST/Pratt parser → static semantics → deterministic Dart emitter.
Supported `const` initializers, including top-level consts, are evaluated in
the compiler, and their errors use the original `.quds` location. The language design is version 1.2 in
[the specification](docs/QUDS_LANGUAGE_SPECIFICATION.md).
The compiler implements the MVP-0 subset only.

## Build and run

With Dart installed:

```sh
dart pub get --enforce-lockfile
dart run bin/quds.dart build examples/sum.quds
dart analyze .dart_tool/quds/out/examples/sum.dart
dart .dart_tool/quds/out/examples/sum.dart
```

The example prints:

```text
Total: 60
12
```

To install the `quds build <input.quds>` executable:

```sh
dart pub global activate --source path .
# Add your Pub cache's bin directory to PATH.
quds build examples/sum.quds
```

A Flutter app whose program is Quds:

```sh
quds create flutter hello
quds run hello/lib/main.quds
```

`lib/main.quds` is the app. Android, iOS, and the other platform folders stay
as `flutter create` made them. `quds run` compiles the Quds file to
`lib/quds_gen/` and launches it with `flutter run`.

Build writes the generated Dart under `.dart_tool/quds/out/`, mirroring the
source path, so a `.quds` file does not gain a sibling `.dart` file. It refuses
to overwrite an output file without the Quds generated-file header, and leaves
output untouched when compilation fails. In VS Code, **Quds: Show Generated Dart**
opens that file beside the source for comparison.
The compiler is an AST-based implementation, not text rewriting.

## Development

```sh
dart format .
dart analyze
dart test --reporter expanded
```

Tests include lexical/parser/semantic conformance, invalid programs, a generated
Dart golden, actual Dart analysis/execution, and CLI subprocess checks. CI uses
Dart 3.13.7 and the committed dependency lockfile.

In this managed cloud environment, run `bash tool/setup_environment.sh`, then:

```sh
export PATH="/workspace/toolchains/dart/bin:/workspace/.pub-cache/bin:$PATH"
export PUB_CACHE=/workspace/.pub-cache
```

## Install on Linux

From this checkout:

```sh
bash install.sh
```

The script installs Dart 3.13 or newer from Google's signed apt repository
when the system copy is missing or older, accepting the package install
without a license prompt. Package signatures stay enabled. It then activates
the `quds` command, adds `$HOME/.pub-cache/bin` to `~/.bashrc` and
`~/.profile`, and installs the editor extension into VS Code and Cursor when
their commands are on `PATH`. Otherwise it copies the extension into
`~/.vscode/extensions` and `~/.cursor/extensions`. Open a new terminal and
reload the editor afterward.

## Editor

[`editors/vscode`](editors/vscode) highlights `.quds` files, formats the open
buffer with `quds format`, and shows diagnostics from that buffer. Hover shows
the type under the cursor, and a getter/setter is labeled `property`, not as
a function. F12 and Ctrl+click open that name's declaration in the `.quds` file. Semantic tokens keep that distinction in the highlighting. Above `main`, Run, Debug, and Profile start
the program, stop on a breakpoint in the `.quds` file, and benchmark it. In this package it starts
`dart run bin/quds.dart lsp`, including when only a file from the package is
open. Elsewhere it starts `quds lsp`. `quds.serverCommand` replaces that command.

See [supported grammar and limitations](docs/MVP_0.md),
[validation results](docs/VALIDATION.md), [environment setup](docs/ENVIRONMENT.md),
[approved decisions](docs/LANGUAGE_DECISIONS.md), and
[what the design closed](docs/OPEN_QUESTIONS.md).
