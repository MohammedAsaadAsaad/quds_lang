# Quds language decisions — 001–115

This is a **faithful concise handoff** of decisions from the design conversation, not a verbatim transcript. The first 91 were approved interactively; QUDS-092–115 were selected by the assistant after the user explicitly delegated the remaining choices. Normative grammar and the resolutions of later conflicts live in `QUDS_LANGUAGE_SPECIFICATION.md` version 1.1-draft. Where this handoff and that file disagree, the specification wins.

## Core philosophy

General-purpose, concise, readable, indentation-based, statically typed, extensible, Dart/Flutter interoperable. The language must **not** become a Flutter-specific framework. Prefer one uniform syntax for constructor/function/method calls and configuration blocks, e.g.:

```quds
Column:
  spacing: 12
  children:
    Text "Hello"
    Text "World"
```

## Numbered decisions

- **QUDS-001** Indentation blocks with colon; no required braces or semicolons.
- **QUDS-002** Immutable bindings by default; var mutable; const compile-time; optional type annotations.
- **QUDS-003** Lists, maps, sets, records with concise literals.
- **QUDS-004** Dart operators plus and/or/not and null-aware operators.
- **QUDS-005** if/else-if/else statements and expressions.
- **QUDS-006** for-in, ranges inclusive/exclusive, step, while, break/continue, await-for.
- **QUDS-007** Typed function declarations and expression-bodied functions.
- **QUDS-008** Classes with fields and generated constructors.
- **QUDS-009** Parentheses-optional simple calls; named argument blocks; unified widget-like constructor calls.
- **QUDS-010** async/async* and Future/Stream interoperability.
- **QUDS-011** use imports and pub dependencies.
- **QUDS-012** try/catch/finally, throw, try-expression fallback, optional Result.
- **QUDS-013** Dart null safety.
- **QUDS-014** Static typing, inference, generics, aliases, explicit dynamic.
- **QUDS-015** Properties with get/set.
- **QUDS-016** Public/private/protected visibility.
- **QUDS-017** extends/implements/with and class modifiers.
- **QUDS-018** Collection operations and comprehensions.
- **QUDS-019** #, /* */, /// comments and annotations.
- **QUDS-020** Interpolation "Hello {name}", escaped braces, raw/triple strings.
- **QUDS-021** Compound assignments, no ++ or --.
- **QUDS-022** Positional, named, optional, required parameters.
- **QUDS-023** Single- and multi-line lambdas.
- **QUDS-024** Generics.
- **QUDS-025** Enums with fields and generated constructors.
- **QUDS-026** init constructors, named, factory, const.
- **QUDS-027** with object configuration, this/super, mixins.
- **QUDS-028** using/using async deterministic cleanup.
- **QUDS-029** match patterns.
- **QUDS-030** await all and await isolate.
- **QUDS-031** if let for nullable binding.
- **QUDS-032** Explicit return in multiline functions and lambdas.
- **QUDS-033** .quds modules and generated .dart files; pubspec compatibility.
- **QUDS-034** Extensions and extension types (type ... wraps ...).
- **QUDS-035** Interfaces, abstract classes and mixins.
- **QUDS-036** Operator overloading with Dart-compatible fixed return constraints.
- **QUDS-037** sync*/async*, yield/yield*.
- **QUDS-038** Records and destructuring.
- **QUDS-039** Expression-first and block-first comprehensions and spread.
- **QUDS-040** Dart generic semantics.
- **QUDS-041** late immutable/mutable bindings.
- **QUDS-042** static and class const.
- **QUDS-043** Native Quds code generation targeting .quds.
- **QUDS-044** Generated file management and optional part/part of.
- **QUDS-045** Function types (Args) -> Return.
- **QUDS-046** Callable classes via call.
- **QUDS-047** with and with? replace Dart cascades.
- **QUDS-048** assert (dev), require (input), check (state).
- **QUDS-049** Typed catch, stack trace, rethrow, stack-aware throw.
- **QUDS-050** value class with structural equality and immutable fields.
- **QUDS-051** Auto copyWith for value classes; omitted differs from explicit null.
- **QUDS-052** Record/list/map/object patterns.
- **QUDS-053** defer sync/async, LIFO cleanup.
- **QUDS-054** Safe inferred const and canonicalization.
- **QUDS-055** factory and lazy isolate-local singleton class.
- **QUDS-056** mixin/mixin class/on/with.
- **QUDS-057** Dart class modifiers.
- **QUDS-058** noSuchMethod under Dart constraints.
- **QUDS-059** @Reflectable compile-time metadata generation compatible with AOT.
- **QUDS-060** Native Quds compile-time macros with structured safe APIs.
- **QUDS-061** annotation Name shorthand.
- **QUDS-062** Conditional imports and compile-time when.
- **QUDS-063** quds create/add/remove/get/run/build/test/analyze/format CLI.
- **QUDS-064** test/group/expect and async/widget tests using Dart ecosystem.
- **QUDS-065** Source-aware diagnostics, warnings, lint and fixes.
- **QUDS-066** LSP, debug adapter, .quds breakpoints, Flutter hot reload.
- **QUDS-067** /// docs, generated API docs, doctests.
- **QUDS-068** Project language versions and migration.
- **QUDS-069** Safe compiler optimization, performance/size benchmarks.
- **QUDS-070** Dart FFI, JS interop, platform channels, binding generation.
- **QUDS-071** Publish .quds and generated .dart to pub.dev.
- **QUDS-072** Incremental compilation, caching, watch and hot reload.
- **QUDS-073** Pub-based dependency resolution.
- **QUDS-074** Deterministic formatter with project config.
- **QUDS-075** Runtime stack traces mapped back to Quds.
- **QUDS-076** Structured logging with pluggable sinks.
- **QUDS-077** Typed configuration with environment precedence and secrets.
- **QUDS-078** Structured concurrency task group/spawn/cancellation.
- **QUDS-079** Generic state/computed/watch reactive primitives.
- **QUDS-080** Declarative if/for inside collection/children contexts; not Flutter-specific framework features.
- **QUDS-081** Unified calls: positional+named arguments, nested calls, precise parsing.
- **QUDS-082** `to Type` explicit conversion, `to? Type` safe conversion, `is`/`as` type tests and casts, explicit custom conversion protocol. `Type?` remains the nullable type.
- **QUDS-083** Optional<T>, missing, present distinguish omission from explicit null.
- **QUDS-084** Parameters non-reassignable by default; var parameter allows local reassignment only.
- **QUDS-085** Static function overloading; deterministic compile-time resolution, reject ambiguity, unique Dart internal names.
- **QUDS-086** Computed defaults evaluated per call; may reference earlier parameters; distinguish omission and null.
- **QUDS-087** Typed variadics ...values: Type, argument spreading and overload rules.
- **QUDS-088** Record/list destructuring and parenthesized multi-assignment; evaluate RHS fully before mutation.
- **QUDS-089** Named destructuring/aliasing for records, objects and maps with structure-specific syntax.
- **QUDS-090** Lexical scope; explicit shadow keyword; outer mutable bindings can be assigned.
- **QUDS-091** Dart-like closure capture; capture(...) snapshots bindings without deep copy.
- **QUDS-092** readonly Type transitive through reference; static checking and runtime guard when needed.
- **QUDS-093** Dart reference/alias semantics; optional static aliasing diagnostics; no mandatory Rust-style ownership.
- **QUDS-094** Union types A | B with narrowing and safe Dart lowering.
- **QUDS-095** Intersection types A & B for combined type contracts.
- **QUDS-096** type aliases; wraps remains distinct extension type.
- **QUDS-097** sealed type algebraic data types and match.
- **QUDS-098** Exhaustiveness checking of match, strict for expressions.
- **QUDS-099** Generic bounds including multiple constraints.
- **QUDS-100** Safe declared in/out generic variance subject to Dart lowering constraints.
- **QUDS-101** Contextual type inference; no unsafe implicit conversions or silent dynamic.
- **QUDS-102** Preserve ?. ?? ??= safe operators.
- **QUDS-103** Type wrapping with checked range/value invariants.
- **QUDS-104** Generic extensions with bounds.
- **QUDS-105** Pipeline |> with static resolution and deterministic evaluation.
- **QUDS-106** do: expression blocks with explicit return.
- **QUDS-107** Partial application using _ placeholders when type unambiguous.
- **QUDS-108** Standard Result<T,E>, Ok/Error; exceptions remain supported.
- **QUDS-109** Result propagation suffix ? with compatible error type.
- **QUDS-110** Function contracts using require/check and result validation.
- **QUDS-111** Left-to-right, exactly-once evaluation including defaults.
- **QUDS-112** Deterministic name resolution; reject ambiguous symbols/extensions.
- **QUDS-113** Type compatibility with no unsafe implicit conversions, union/generic/readonly checks.
- **QUDS-114** Dart-facing API compatibility and explicit wrappers for Quds-only features.
- **QUDS-115** Uniform syntax and unambiguous parser for calls, properties, blocks.

## Examples requiring conformance

```quds
add(a: int, b: int) = a + b

main():
  var count = 0
  for i in 1..5:
    count += i
  print count

  var x = 10
  var y = 20
  (x, y) = (y, x)

  result = match parseValue("42"):
    Success(value): value
    Failure(message): message
```

Do not infer that the examples are already executable; implement and validate incrementally.
