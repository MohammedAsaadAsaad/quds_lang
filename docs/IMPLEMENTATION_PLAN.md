# Compiler implementation plan

Language design 1.2 is complete in `QUDS_LANGUAGE_SPECIFICATION.md`. The milestones below are implementation work. A compiler that has not reached a milestone rejects those constructs with `E910` instead of inventing a meaning.

## Current readiness work — 2026-11-18

The nine-track working plan and next-agent handoff are in
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md). The machine-checked
[115-rule inventory](LANGUAGE_READINESS.md) distinguishes candidate evidence,
verified slices and full certification. This milestone adds native required
function/method values, target-aware conditional dependency loading, native
Flutter build commands, F5 live updates and cross-host/Flutter CI configuration.
Native function values now include optional/named metadata and explicit generic
instantiation and concrete contextual inference. Unconstrained polymorphic values,
full constraint solving and generic callback types remain limited.
Actual remote CI/engine evidence and the remaining tracks stay explicit gates;
this is not a claim of complete Dart parity.

The Quds-side function-value slice and remaining adapters/import contracts are
tracked in [QUDS_FUNCTION_VALUES.md](QUDS_FUNCTION_VALUES.md). Required-positional
class method values and receiver/visibility contracts are tracked separately in
[QUDS_METHOD_VALUES.md](QUDS_METHOD_VALUES.md).

Provider-owned computed defaults for supported top-level imports and direct
calls are documented in [QUDS_PROVIDER_DEFAULTS.md](QUDS_PROVIDER_DEFAULTS.md).
Supported ordinary public class methods now publish provider-owned bridges too.
The first non-generic declaring-interface bridge slice is documented in
[QUDS_INTERFACE_DEFAULTS.md](QUDS_INTERFACE_DEFAULTS.md). Generic interfaces,
lexical type qualification and full parameter metadata remain separate work.

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

## 2026-11-17 editor responsiveness and debugging

Completed the editor follow-up in EDITOR_PERFORMANCE_DEBUG_AR.md: analysis skips
SDK output generation, a bounded latest-per-document background queue preserves
all open documents, and live completion uses cached semantic metadata. Generic
inheritance, SDK extensions, native parameters, indentation call blocks, Arabic
identifiers and signature help have regression coverage. Generated helper/import
and const-comment insertion now adjusts source maps. Real DAP execution verifies
Quds breakpoints, original/nested variable names and Watch evaluation. Final gate:
517 pass, zero skipped/failing; analysis and formatting clean. See VALIDATION.md
and bench/results/editor_latency.json for exact evidence and measurement limits.

## 2026-11-17 — approved augment and conversions follow-up

Stage 1 implements local/part class augmentation and imported behavioral
augmentation, preserving member spans and rejecting structural conflicts.
All 528 tests pass, analyzer clean. Stage 2 adds typed custom conversion
resolution and runtime behavior; it is not included in the stage-1 claim.
See AUGMENT_AND_CONVERSIONS_AR.md for the explicit owner-approved syntax amendment.

Stage 2 now implements the approved class/augment conversion declarations,
static one-hop contextual resolution, imported/generic/part identities,
ConversionError-safe `to?`, and ordinary SDK Fraction conversions. The feature
handoff and exact scope are in AUGMENT_AND_CONVERSIONS_AR.md; final gate evidence
is recorded in VALIDATION.md. Unsupported container-wide transformations,
third-type operator searches and external structural/static changes are not
claimed. QUDS-082 type operations retain their meaning.

## 2026-11-17 — completion degradation as files grow

Reproduced quadratic semantic-token coordinate conversion and receiver searches,
plus digit-suffixed receivers incorrectly treated as decimal literals. Added a
shared source-coordinate index, background/cached live semantic tokens, bounded
incomplete-line recovery with truthful diagnostics, worker failure handling,
and cancellation/timeouts/stale-version checks in VS Code. Regression coverage
includes repeated growing edits, 5,000 bindings, deep failed analysis and actual
stdio LSP traffic. See EDITOR_COMPLETION_GROWTH_AR.md for measurements, reload
instructions and scope; VALIDATION.md records the final complete test gate.

## 2026-11-17 — staged colors and diagnostics during continuous typing

Bound trailing change debounces in both client and server, project untouched
semantic tokens through edits, send provisional AST declaration colors, and
publish actual diagnostics before completion recovery. Complete semantic and
lowering checks still run; provisional syntax never clears semantic errors or
feeds unchecked completion types. Serialize stdio frames to prevent notification/
flush races. See EDITOR_DIAGNOSTICS_LATENCY_AR.md and editor_diagnostics.json for
before/after phase timings, continuous-typing coverage and full-check costs.

## 2026-11-17 — exported SDK conversions in run/debug output graphs

Reproduced the user's src.some re-export of quds:math with an external explicit
int-to-Fraction cast. Run and DAP now prepare dependencies before VM startup;
indirectly used SDK libraries are bundled and routed to a shared project output
directory. Cache validity includes bundle/map hashes and is rechecked after a
dependency rebuild. Existing Flutter output preparation uses the same graph
builder. Source syntax, explicit/implicit selection and E310 ambiguity rules
remain unchanged. See SDK_EXPORT_RUN_DEBUG_AR.md for the reproduction and tests.
