# Changelog

All notable changes to the Quds compiler, SDK, and CLI are documented here.

## 0.1.0-alpha.1

First public alpha release of the Quds language compiler, standard library, CLI, and editor tooling (targeting language specification 1.2).

### Language & Compiler
- Full lexer, indentation-aware parser, typed AST, static semantic analyzer, Dart code generator, and `.quds` source maps.
- Indentation blocks with `:`, paren-free unified block-call syntax (`QUDS-081`) including direct `return Widget:`, generic block calls (`Widget<T>:`), list-of-block-call `children:` blocks, and block-body lambdas.
- Immutable bindings by default (`name = value`), mutable `var`, compile-time `const`, intentional `shadow`, `readonly Type` views, `Optional<T>` / `missing`, `Result<T, E>` with `?`, `sealed type`, `value class` with `copyWith`, `@Json`, `match` patterns, and loop context (`$.index`, `$.iteration`, `$.isFirst`, `$.item`) across loops and `retry`.
- Custom `implicit cast` and `explicit cast` conversions (`to` / `to?`), including primitive-to-primitive declarations.
- Direct Dart & Flutter interop: external Dart/Flutter setters and mutable fields, generic `void` top bounds (e.g. `showDialog<void>`), callable function-typed fields, and flow narrowing in `collection-if` and `if` expressions.

### Standard Library & External Packages
- Built-in `quds:core`, `quds:math` (exact `Fraction`, linear algebra, statistics, graphs, symbolic/autodiff, intervals, geometry), `quds:text`, and `quds:ext`.
- External pure-Quds packages via `pubspec.yaml` path/git dependencies, dual Quds+Dart publishing (`quds build --package`), barrel re-exports, and isolated Flutter generation under `lib/quds_gen/_packages/`.

### CLI, Editor & Debugging
- `quds` CLI: `run`, `build`, `test`, `analyze`, `format`, `doc`, `create`, `pub`, `flutter`, `doctor`, `install`, `lsp`, `debug`.
- Live step-by-step progress output on `quds run -d ...` and `quds build ...`, plus Windows-safe path handling.
- VS Code extension with TextMate grammar, LSP diagnostics/hover/completion/definition/rename, and live DAP debugging (breakpoints, Flutter hot reload, and live evaluation of `$` / `$.index` / `$.iteration` / `$.item`).
- Cross-platform Flutter example `budget_ledger` paired with standalone pure-Quds package `quds_ledger`.

### Alpha Limitations
- Not all 115 specification rules are certified yet; see `docs/LANGUAGE_READINESS.md` and `docs/OPEN_QUESTIONS.md` for current partial slices and remaining certification gates.
