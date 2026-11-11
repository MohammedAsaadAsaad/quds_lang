# Quds Language

Quds is a general-purpose, statically typed, indentation-based language targeting
Dart. MVP-0 implements a small compiler pipeline: source spans → indentation-aware
lexer → typed AST/Pratt parser → static semantics → deterministic Dart emitter.
Supported `const` initializers, including top-level consts, are evaluated in
the compiler, and their errors use the original `.quds` location. The 115
design decisions remain the roadmap;
most are not implemented yet.

## Build and run

With Dart installed:

```sh
dart pub get --enforce-lockfile
dart run bin/quds.dart build examples/sum.quds
dart analyze examples/sum.dart
dart examples/sum.dart
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

Build writes an adjacent `.dart` file. It refuses to overwrite a file without the
Quds generated-file header, and leaves output untouched when compilation fails.
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

See [supported grammar and limitations](docs/MVP_0.md),
[validation results](docs/VALIDATION.md), [environment setup](docs/ENVIRONMENT.md),
[approved decisions](docs/LANGUAGE_DECISIONS.md), and
[open specification questions](docs/OPEN_QUESTIONS.md).
