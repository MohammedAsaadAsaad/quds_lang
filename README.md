# Quds Language

Quds is a general-purpose, statically typed, indentation-based programming language that compiles to Dart and interoperates with the Dart/Flutter ecosystem.

> Status: early compiler bootstrap. Language design decisions QUDS-001–115 are recorded in `docs/LANGUAGE_DECISIONS.md`. This repository is **not yet** a working Quds compiler.

## Goals

- Readable, concise, uniform syntax using indentation and `:` blocks.
- Dart-compatible semantics where possible; explicit lowering for Quds-only features.
- Static analysis, null safety, deterministic parsing, diagnostics and source maps.
- Reuse Dart packages, pubspec.yaml, tooling and Flutter without becoming a Flutter-specific language.
- Conformance tests for every approved rule.

## Proposed compiler pipeline

`.quds` source → lexer → parser/AST → name resolution → type checking → normalized IR → Dart generation → Dart tooling.

## Next steps

1. Read [AGENTS.md](AGENTS.md) and [language decisions](docs/LANGUAGE_DECISIONS.md).
2. Establish executable Dart package and tests.
3. Implement lexer with indentation-sensitive `INDENT`/`DEDENT` tokens.
4. Implement AST and Pratt expression parser, then statements and blocks.
5. Generate Dart for a narrow MVP; test execution end to end.

See [implementation plan](docs/IMPLEMENTATION_PLAN.md).
