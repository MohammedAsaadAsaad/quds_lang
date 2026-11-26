# Changelog

All notable changes to the Quds compiler, SDK, and CLI are documented here.

## 0.1.0-alpha.2

Maintenance and package-quality release targeting full Windows compatibility and 160/160 pub.dev score readiness:

- Fixed a Windows `Uri.file` path crash when analyzing `quds:` SDK libraries that re-export `dart:` libraries (such as `quds:math` exporting `dart:math`).
- Tightened `analyzer` lower bound to `^14.0.0` so `dart pub downgrade && dart analyze` passes cleanly.
- Enabled `package:lints/core.yaml` in `analysis_options.yaml` and resolved all core lint infos (`dart analyze --fatal-infos` passes with 0 issues).
- Expanded public API dartdoc coverage across `lib/quds.dart`, `lib/migrate.dart`, AST nodes, lexer, and source spans (well above the 20% pub.dev threshold).
- Fixed `quds install` when activated from `pub.dev` so users can install VS Code/Cursor/Windsurf/JetBrains/Claude editor support directly without `--no-update` or mutating the pub cache.
- Added automated VS Code extension packaging & release workflow (`.github/workflows/vscode-release.yml`) attaching `quds-<version>.vsix` to GitHub Releases and supporting automated VS Code Marketplace / Open VSX publishing.
- Updated GitHub Actions CI (`dart.yml`) to Dart `3.14.0` and verified Linux, macOS, Windows, and Flutter pipelines.

## 0.1.0-alpha.1

First public alpha release of the Quds language compiler, standard library, CLI, and editor tooling (targeting language specification 1.2).

### Language & Compiler
- Full lexer, indentation-aware parser, typed AST, static semantic analyzer, Dart code generator, and `.quds` source maps.
- Indentation blocks with `:`, paren-free unified block-call syntax (`QUDS-081`) including direct `return Widget:`, generic block calls (`Widget<T>:`), list-of-block-call `children:` blocks, and block-body lambdas.
- Immutable bindings by default (`name = value`), mutable `var`, compile-time `const`, intentional `shadow`, `readonly Type` views, `Optional<T>` / `missing`, `Result<T, E>` with `?`, `sealed type`, `value class` with `copyWith`, `@Json`, `match` patterns, and loop context (`$.index`, `$.iteration`, `$.isFirst`, `$.item`) across loops and `retry`.
- Dart 3 language features: explicit `init(...) super(...)` / `super.named(...)` forwarding, redirecting generative constructors `init(...) this(...)` / `this.named(...)`, initializer-only `const init` bodies, enhanced enums (`QUDS-025`) with fields/properties/methods/interfaces, named records `(a: 1, b: 2)`, `if ... is ...` and collection `if-is` patterns with `when` guards and `else`, inline `map("k": pat)` patterns, and mutable `var (...)` / `var [...]` destructuring.
- Expanded sound `readonly` runtime boundaries (`QUDS-092`) across Dart and erased (`Object?`) calls for positional/named records, `Result<T, E>`, `MapEntry<K, V>`, `Optional<T>`, `Range<T>`, `StackTrace`, `Runes`, function values, `extensionType`, and deeply immutable `sealedType`, while rejecting unproxyable mutable native classes (such as `dart:io File`) with `E910`.
- Expanded checked cross-library union boundaries (`QUDS-094`) supporting local union type aliases (including `if is`, `guard is`, and exhaustive `match` narrowing), `async` union functions (`Future<A | B>`), and imported union partial applications.
- Custom `implicit cast` and `explicit cast` conversions (`to` / `to?`), including primitive-to-primitive declarations.
- Direct Dart & Flutter interop: external Dart/Flutter setters and mutable fields, generic `void` top bounds (e.g. `showDialog<void>`), callable function-typed fields, and flow narrowing in `collection-if` and `if` expressions.

### Standard Library & External Packages
- Built-in `quds:core`, `quds:math` (exact `Fraction`, linear algebra, statistics, graphs, symbolic/autodiff, intervals, geometry), `quds:text`, and `quds:ext`.
- External pure-Quds packages via `pubspec.yaml` path/git dependencies, dual Quds+Dart publishing (`quds build --package`), barrel re-exports, and isolated Flutter generation under `lib/quds_gen/_packages/`.

### CLI, Editor & Debugging
- `quds` CLI: `run`, `build`, `test`, `analyze`, `format`, `doc`, `create` (including `quds create --f <name>` for Flutter apps), `migrate` (AST-based Dart/Flutter → Quds migrator with feasibility check, semantic compile verification, `lib/` backup excluded from analyzer/editor, before/after line-count summary, and Dart 3 support for `super(...)`, redirecting `this(...)`, enhanced enums, `if-case`, `MapPattern`, destructuring declarations/assignments, and pattern `for-in` loops), `pub`, `flutter`, `doctor`, `install`, `lsp`, `debug`.
- Live step-by-step progress output on `quds run -d ...` and `quds build ...`, plus Windows-safe path handling.
- VS Code extension with TextMate grammar, LSP diagnostics/hover/completion/definition/rename, and live DAP debugging (breakpoints, Flutter hot reload, and live evaluation of `$` / `$.index` / `$.iteration` / `$.item`).
- Cross-platform Flutter example `budget_ledger` paired with standalone pure-Quds package `quds_ledger`.

### Alpha Limitations
- Not all 115 specification rules are certified yet; see `docs/LANGUAGE_READINESS.md` and `docs/OPEN_QUESTIONS.md` for current partial slices and remaining certification gates.
