# Quds

Quds is a general-purpose, statically typed, indentation-based language that compiles to Dart. The language design is version 1.2 in [the specification](docs/QUDS_LANGUAGE_SPECIFICATION.md). Compiler coverage and remaining certification work are tracked in the [language readiness inventory](docs/LANGUAGE_READINESS.md) and [working plan](docs/LANGUAGE_READINESS_AR.md); not all 115 decisions are certified.

## Example

```quds
square(n: int) -> int = n * n

main():
  name = "Quds"
  print "Hello {name}"
  print square(6)
```

`name = "Quds"` is a fixed binding. `square` is one line and returns its result. Running it prints:

```text
Hello Quds
36
```

[`examples/sum.quds`](examples/sum.quds) is a slightly longer program. It prints:

```text
Total: 60
12
```

## Install

Install [Dart](https://dart.dev/get-dart) 3.3 or newer, below 4. Then activate Quds from Git and install it:

```sh
dart pub global activate --source git https://github.com/MohammedAsaadAsaad/quds_lang.git
quds install
```

The first command puts `quds` on your `PATH` through the pub cache bin directory: `~/.pub-cache/bin` on Linux and macOS, and `%LOCALAPPDATA%\Pub\Cache\bin` on Windows. Open a new terminal if the shell does not see `quds` yet.

`quds install` prepares the editors on this machine. VS Code, Cursor, and other editors from that family receive the extension. Android Studio and other JetBrains IDEs receive highlighting for `.quds` files. Claude Code receives a Quds skill and the language server when Claude Code is installed. If a directory is protected, the command asks for administrator permission. Quit an open JetBrains IDE before this step. Reload the editors afterward and open a `.quds` file.

`quds doctor` reports Dart, Flutter, the `quds` command, and those editors. `quds help` lists every command.

A Flutter app also needs Flutter installed.

Inside a project, `quds pub get` (and all other native pub subcommands) selects
Dart or Flutter automatically. `quds create . --platforms=linux,web,android` adds
Flutter platforms in place while preserving Quds sources and existing user files.
`quds run -d linux` selects `lib/main.quds` automatically; `--debug`, `--profile`
and `--release` are supported. See [project commands](docs/PROJECT_CLI.md).

[Quds Academy](examples/flutter_app/quds_academy/README.md) is an Arabic/English
learning application written in Quds, with animated Flutter screens and direct
`sqlite_plus` integration. Its README records the run commands and the remaining
Flutter engine validation requirement.

## Run

```sh
quds run examples/sum.quds
```

`quds build examples/sum.quds` writes Dart under `.dart_tool/quds/out/`, following the source path. A `.quds` file does not gain a sibling `.dart` file. Build overwrites a file only when that file carries the Quds generated header, and it leaves the output untouched when compilation fails.

A Flutter app whose program is Quds:

```sh
quds create flutter hello
quds run hello/lib/main.quds
```

`lib/main.quds` is the program. The platform folders stay as Flutter created them. `quds run` compiles the file to `lib/quds_gen/` and launches it with `flutter run`. Saved Quds files trigger compilation and hot reload automatically in Run and Flutter F5 debug sessions. In the running terminal, `r` reloads, `R` hot restarts, and `q` quits. Select a device with `quds run lib/main.quds -- -d chrome`. See [Flutter live updates](docs/FLUTTER_LIVE_UPDATES.md) for behavior, validation and debug-adapter scope.

In VS Code, **Quds: Show Generated Dart** opens the source and the generated file together.

## Editor

The [`editors/vscode`](editors/vscode) extension highlights `.quds` files, formats the open buffer, and shows compiler diagnostics. Hover shows a name's type. Keywords show an English purpose, constraints, and Quds example in hover and completion details; see the [keyword reference](docs/KEYWORD_REFERENCE.md). F12 and Ctrl+click open its declaration. Above `main`, Run, Debug, and Profile start the program, stop on a `.quds` line, and benchmark it.

Inside this repository the editor starts `dart run bin/quds.dart lsp`. Elsewhere it starts `quds lsp`. `quds.serverCommand` replaces that command.

## Development

```sh
dart pub get --enforce-lockfile
dart format .
dart analyze
dart test --reporter expanded
```

Tests cover parsing, compilation, execution of the generated Dart, and the CLI. CI uses Dart 3.13.7 and the committed lockfile.

In the managed build environment:

```sh
bash tool/setup_environment.sh
export PATH="/workspace/toolchains/dart/bin:/workspace/.pub-cache/bin:$PATH"
export PUB_CACHE=/workspace/.pub-cache
```

See [what the compiler implements](docs/MVP_0.md), [validation results](docs/VALIDATION.md), [environment setup](docs/ENVIRONMENT.md), [approved decisions](docs/LANGUAGE_DECISIONS.md), and [what the design closed](docs/OPEN_QUESTIONS.md).

The SDK math precision contract and numerical regression checks are documented in
[math accuracy](docs/MATH_ACCURACY.md) and [the API inventory](docs/MATH_COVERAGE.md).
The [math expansion roadmap (Arabic)](docs/MATH_EXPANSION_ROADMAP_AR.md) maps missing
domains; its first addition is [unweighted graph algorithms](docs/MATH_GRAPH.md).

Math behavior is tested primarily through `quds test` on `.quds` suites; see
[the testing policy and commands](docs/MATH_ACCURACY.md#primary-quds-tests).

The next compiler-foundation packages and agent handoff are recorded in
[the detailed Arabic execution plan](docs/LANGUAGE_NEXT_STAGE_HANDOFF_AR.md).
The first package's supported behavior is documented in
[function types and nullability](docs/FUNCTION_NULLABILITY.md).

Generic application checks and the remaining L3.2 scope are documented in
[generic constraints](docs/GENERIC_CONSTRAINTS.md).

The next bounded generic package is described in
[collection inference and instantiated interfaces](docs/COLLECTION_INFERENCE_INTERFACES.md).

[Generic class inheritance and multi-file Quds testing](docs/GENERIC_INHERITANCE.md)
documents the L3.2c subset and its remaining constructor/interop limits.


Native Dart/Flutter hover examples can be previewed as Quds without changing
upstream documentation. An optional background worker converts supported snippets
and preserves unsupported Dart examples. See [tooltip previews](docs/DART_TOOLTIP_PREVIEWS.md).

## Readiness and native builds

`quds build apk --release`, `quds build web` and `quds build linux` compile
`lib/main.quds` and its dependencies before invoking Flutter. Native toolchains
remain necessary. [Project commands](docs/PROJECT_CLI.md) cover all platforms.
VS Code offers **Quds: Hot Reload** and **Quds: Hot Restart** during Quds debug
sessions; see [live updates](docs/FLUTTER_LIVE_UPDATES.md) for validation limits.

Imported Dart functions and methods with required positional parameters can be
stored and passed as typed function values, including bound methods and zero-arg
functions. Optional/named signatures and explicit native generic specialization such as
`math.max<int>` are supported. Generic values can also specialize from a concrete expected function signature.
Unconstrained generic values and polymorphic callback signatures remain limited.
The [readiness handoff](docs/LANGUAGE_READINESS_AR.md) separates implemented
slices, pending conformance and real-platform release gates.

Quds functions also support explicit/contextual generic values and local overload
selection from an expected signature; ambiguous values report E311. See
[Quds function values](docs/QUDS_FUNCTION_VALUES.md) for examples and limits.

Required-positional Quds class method values support class/method substitution,
static and inherited instance methods, nullable access and checked readonly
results. See [method values](docs/QUDS_METHOD_VALUES.md) for examples and limits.

Supported top-level Quds imports keep computed defaults inside their defining
library for references and calls with omitted arguments. See
[provider-owned defaults](docs/QUDS_PROVIDER_DEFAULTS.md) for the ABI contract,
filter/re-export behavior and remaining limits.

Public ordinary-class methods in imported Quds providers also publish stable
default bridges, preserving receiver identity and readonly checks. Interface
bridges and complete parameter-form metadata remain separate work.

An initial [interface-default bridge slice](docs/QUDS_INTERFACE_DEFAULTS.md)
keeps contract defaults and repeated-reference equality across implementation
dispatch. Generic declaring interfaces and broader type signatures remain limited.
