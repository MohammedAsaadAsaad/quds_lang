# Instructions for Codex and contributors

## Mission

Implement Quds, a **general-purpose language**, not a Flutter UI framework, as a Dart-based compiler. The design conversation established 115 numbered language decisions. Read `docs/LANGUAGE_DECISIONS.md` and `docs/IMPLEMENTATION_PLAN.md` before coding.

## Priorities

1. Preserve the intent of approved syntax and semantics. Do not silently redesign the language.
2. Write a real lexer/parser/AST/type checker/code generator. **Never** implement the language with regex-only text rewriting.
3. Work incrementally: lexer → AST/parser → static semantics → Dart generation → conformance tests.
4. Keep source spans on tokens/AST nodes and surface diagnostics in original `.quds` coordinates.
5. Preserve left-to-right, exactly-once evaluation; never silently alter null/missing/default semantics.
6. Do not confuse a non-reassignable binding with an immutable object.
7. Favor static resolution; reject ambiguous overloads and unsafe implicit conversions.
8. Generate readable Dart and add golden tests and executable integration tests.
9. Maintain Dart/Flutter interop without introducing framework-specific syntax as a core language requirement.
10. Do not claim features are implemented or tested unless they actually are.

## Important design constraints

- Blocks use `:` and indentation; no required braces/semicolons.
- `name = value` introduces immutable binding when not defined; `var name = value` mutable; `const` compile-time.
- QUDS-090: existing mutable outer bindings are assignable; intentional shadowing uses `shadow`. This requires unambiguous symbol resolution.
- QUDS-032: explicit `return` in multiline functions/lambdas; expression bodies may return implicitly.
- QUDS-081: unified call syntax, positional + named + nested calls.
- QUDS-082: `to Type` explicit conversion, `to Type?` safe conversion; `is`/`as` remain type operations.
- QUDS-083: `Optional<T>` and `missing` distinguish omitted arguments from explicit null.
- QUDS-085: compile-time function overloading; no dynamic overload dispatch by default.
- QUDS-086: computed default arguments may refer only to earlier parameters.
- QUDS-087: typed variadics `...items: T`, spread in calls.
- QUDS-091: Dart closure capture by default; `capture(...)` snapshots bindings, not object graphs.
- QUDS-092: `readonly Type` restricts mutation through a reference, including nested access.
- QUDS-094–115 are provisional decisions requiring formal grammar and semantic reconciliation before implementation.

## Development workflow

- Start with a small milestone and ship tests in the same PR.
- Run `dart format .`, `dart analyze`, `dart test` when Dart SDK is available.
- Report exact test commands/results, or explicitly say they could not be run.
- Add a conformance test and documentation example for every implemented rule.
- Record unresolved ambiguities in `docs/OPEN_QUESTIONS.md`; do not guess.

## Initial Codex task

Implement the first real vertical slice: a Dart package with source spans, tokenizer including INDENT/DEDENT/NEWLINE, a typed AST for literals/binary expressions/calls/bindings/functions/if/for, a parser, a Dart emitter, a CLI entry point `quds build`, and automated tests. Scope features carefully and do not claim all 115 rules are supported.
