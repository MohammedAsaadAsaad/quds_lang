# Changelog

All notable changes to the Quds compiler, SDK, and CLI are documented here.

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
