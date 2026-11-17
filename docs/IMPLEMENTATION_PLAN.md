# Compiler implementation plan

Language design 1.2 is complete in `QUDS_LANGUAGE_SPECIFICATION.md`. The milestones below are implementation work. A compiler that has not reached a milestone rejects those constructs with `E910` instead of inventing a meaning.

## Architecture

Source manager → indentation-aware lexer → token stream → parser → typed AST → symbol table/name resolution → type checking → lowering IR → Dart emitter → diagnostics/source maps.

## Milestone 0 — bootstrap

- Dart package layout: `bin/`, `lib/src/`, `test/`, `examples/`.
- CI: Dart format, analyze, test.
- Source positions: byte offset, line, column, file path.
- Diagnostic codes and stable test fixtures.

## Milestone 1 — lexical analysis

- Normalize line endings; reject inconsistent indentation according to a documented policy.
- Produce INDENT, DEDENT, NEWLINE, EOF; ignore blank/comment-only lines for indentation.
- Identifiers, keywords, numeric/string literals, escapes, operators and punctuation.
- Bracket-aware newline continuation; multiline strings and interpolation boundaries.
- Golden token tests and invalid-input diagnostics.

## Milestone 2 — parsing

- Typed AST with source spans.
- Pratt parser for precedence and associativity.
- Bindings, function declarations, expression bodies, block bodies, return, if/else, for-in, calls.
- Named argument blocks and positional/named mixing, collection literals.
- Error recovery and parser snapshot tests.

## Milestone 3 — semantics

- Scope and symbol resolution; explicit shadowing; mutable vs immutable assignments.
- Type inference, static checks, nullable types, function signatures.
- Overload resolution and ambiguous-call diagnostics.
- Computed defaults and omission vs explicit null.

## Milestone 4 — Dart output

- Deterministic Dart emitter; preserve expression evaluation order.
- Source mapping and compiler diagnostics.
- Golden generated-Dart tests plus Dart execution tests.
- MVP example: sum function, list iteration, mutable accumulator, interpolation.

## Milestone 5 — advanced features

- Class declarations, generics, constructors, properties, extensions.
- Patterns, union/intersection types, sealed ADTs, result propagation.
- Readonly, macros, codegen, FFI/JS interop, async/concurrency.
- Separate each feature behind a conformance test suite.

## Acceptance

A milestone is done only after syntax examples parse, invalid cases fail predictably, generated Dart passes `dart analyze`, runtime tests pass, and documentation is updated.

## MVP-0 implementation status

Issue #1 now has a working first slice through the lexer, typed AST/Pratt parser,
scoped static semantics, deterministic Dart emission and `quds build`. The native
acceptance program is analyzed and executed in integration tests. This does not
complete every item in milestones 0–4: recovery, source maps, contextual typing,
full collection/call grammar and advanced semantics remain incremental work.
See `MVP_0.md` for the exact supported subset and `VALIDATION.md` for commands and
results. Const initializers in that subset, including top-level consts, are
evaluated in Quds, and failures are reported at the original `.quds` span.
Generated bool conditions stay analyzable without changing short-circuit
behavior. The approved language decisions remain unchanged.


## 2026-11-17 language and memory handoff closure

The finite follow-up in LANGUAGE_MEMORY_COMPLETION_AR.md is complete: actual
VM/V8 heap/allocation measurements, deep readonly collection and supported class
guards, a debugger startup race fix, and preserved/instantiated native Dart
generic metadata with direct-call conformance. The final suite reports 501 pass,
zero failures and zero skips. See VALIDATION.md for exact commands and the linked
feature documents for unsupported native/readonly shapes. This supersedes the
old MVP-only progress snapshot above without changing approved language syntax
or claiming complete implementation of every approved feature.
