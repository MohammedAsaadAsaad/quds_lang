# Quds

Quds is a general-purpose, statically typed, indentation-based language that compiles to Dart. The language design is version 1.2 in [the specification](docs/QUDS_LANGUAGE_SPECIFICATION.md). The compiler implements the MVP-0 subset.

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

`lib/main.quds` is the program. The platform folders stay as Flutter created them. `quds run` compiles the file to `lib/quds_gen/` and launches it with `flutter run`.

In VS Code, **Quds: Show Generated Dart** opens the source and the generated file together.

## Editor

The [`editors/vscode`](editors/vscode) extension highlights `.quds` files, formats the open buffer, and shows compiler diagnostics. Hover shows a name's type. F12 and Ctrl+click open its declaration. Above `main`, Run, Debug, and Profile start the program, stop on a `.quds` line, and benchmark it.

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
