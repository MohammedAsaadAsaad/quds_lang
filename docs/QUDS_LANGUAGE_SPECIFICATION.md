# Quds Language — Complete Design Decisions and Agent Implementation Specification

**Version:** Design baseline 1.1-draft · **Date:** 2026-11-11 · **Rules:** QUDS-001 through QUDS-115 · **Status:** Design decisions with normative conflict resolutions. Not a finished executable language, and not a claim that the compiler implements these rules.

## Agent instructions — read before implementation

You are implementing **Quds**, a general-purpose, indentation-based, strongly and statically typed programming language that compiles to Dart. It must interoperate with Dart/pub/Flutter while **not** becoming a Flutter-specific language or widget framework. The user approved QUDS-001–091 through iterative choices, and explicitly delegated QUDS-092–115 to the assistant. This file preserves those decisions in expanded, implementation-oriented form; where a detail was not explicitly decided, it is identified as an implementation task rather than fabricated as established consensus.

**Priority rules:**

1. Preserve all numbered decisions unless an explicit contradiction is found. Record conflicts in `docs/OPEN_QUESTIONS.md`, propose alternatives, and implement only non-controversial subsets until resolved.
2. Implement a proper lexer → parser → typed AST → symbol resolution → type checker → normalized IR → Dart emitter, not a regex-based translator.
3. Source locations and diagnostics must refer to original `.quds` source. Generated Dart must preserve evaluation order and side effects.
4. Start with an executable, tested MVP; do not claim 115 features are implemented until every one has positive, negative and interop conformance tests.
5. Preserve static soundness, null safety, clear scoping, explicit mutability, and deterministic overload resolution.
6. Reuse Dart runtime semantics where specified. Do not claim compile-time safety that is only enforced by a runtime wrapper, particularly for `readonly`, union types and external APIs.
7. Keep syntax short and consistent, favoring `:` plus indentation, but never introduce parsing ambiguity to save characters.
8. Generated Dart should be readable, deterministic, testable and compatible with supported Dart SDK versions.
9. Mark normative vs illustrative syntax. Some examples below are *design sketches* pending a formal EBNF and lowering specification; do not silently treat ambiguous sketches as settled grammar.
10. Report exactly what was coded, what was tested, and what remains unsupported.
11. If an illustration or an earlier sentence in a rule conflicts with **Normative resolutions**, that section wins. Illustrations stay sketches until they match it. Do not reintroduce a second meaning for a token that section assigns.

## Canonical design illustrations

```quds
# Bindings and scope
name = "Quds"       # immutable binding
var count = 0        # mutable binding
const limit = 10     # compile-time constant

# Functions
add(a: int, b: int) -> int:
  return a + b
square(x: int) = x * x

# Uniform constructor/call block — not Flutter-specific
Column:
  spacing: 12
  children:
    Text "Hello"
    Text "World"

# Explicit shadowing and closure snapshot
var value = 10
live = () -> value
saved = capture(value) -> value
value = 20

# Structural control flow
for i in 1..5:
  if i > 2:
    print i
```

## Rule catalogue

Each rule contains: **decision**, **Quds illustration**, **compiler obligations**, and **conformance cases**. A sample may omit imports or surrounding declarations to focus on the feature.

### QUDS-001 — Indentation-sensitive blocks

**Approved decision.** A colon introduces an indented block. INDENT/DEDENT are lexical structure, not cosmetic whitespace. No mandatory braces or semicolons.

**Quds syntax illustration** (may be a fragment):

```quds
if ready:
  print "Ready"
```

**Compiler / runtime requirements.** Emit structural tokens; ignore blank/comment-only lines for indentation; diagnose inconsistent dedent.

**Required conformance coverage.** Nested blocks, blank lines, dedent mismatch, multiline expressions.

### QUDS-002 — Bindings, mutability and constants

**Approved decision.** A new `name = expr` is non-reassignable; `var name = expr` is mutable; `const name = expr` requires compile-time evaluation. Optional `name: Type = expr` annotations.

**Quds syntax illustration** (may be a fragment):

```quds
name = "Quds"
var count = 0
const maxItems = 10
```

**Compiler / runtime requirements.** Symbol table tracks declaration kind; reject reassignment to immutable names.

**Required conformance coverage.** Reassignment, initialization, inference, const expression validity.

### QUDS-003 — Core collection literals

**Approved decision.** Lists use `[]`; maps and sets use the keywords `map:` and `set:` followed by an indented element block; records are parenthesized and first-class. `map:` and `set:` are not calls. A function or constructor named `map` or `set` is called with parentheses or a positional argument (`map items`), never as a bare colon block. Type inference preserves element, key, and value types. Empty lists, maps, and sets are allowed where the element type is known from context or from an explicit annotation; otherwise the program is rejected and is not given type `dynamic`.

**Quds syntax illustration** (may be a fragment):

```quds
numbers = [1, 2, 3]
settings = map:
  "mode": "dark"
```

**Compiler / runtime requirements.** Separate collection literal grammar from named-call blocks.

**Required conformance coverage.** Empty literals, duplicate keys, nesting, inferred generic types.

### QUDS-004 — Operators and boolean words

**Approved decision.** Preserve Dart arithmetic, comparison, bitwise, shift, `~/`, and null operators, using the precedence in Normative resolutions. Boolean words are `and`, `or`, and `not` (prefix `!` is the same operator as `not`). They short-circuit. `and` and `or` require `bool`; a nullable bool is a type error until promoted or handled with `??` / `!`. There is no Dart cascade token: `..` and `..<` are ranges.

**Quds syntax illustration** (may be a fragment):

```quds
if active and not blocked:
  print "OK"
```

**Compiler / runtime requirements.** Lower boolean words to Dart operators without changing evaluation order.

**Required conformance coverage.** Precedence, short circuit, nullable operands, invalid types.

### QUDS-005 — Conditionals as statements and expressions

**Approved decision.** `if` / `else if` / `else` exist as statements, as expressions, and as collection elements. The three are distinguished by position, not by a fourth spelling. An if-expression requires `else`, and its branches are expressions whose types join. A statement may omit `else`. A collection `if` contributes elements and may omit `else`. See Normative resolutions.

**Quds syntax illustration** (may be a fragment):

```quds
if score >= 50:
  print "Pass"
else:
  print "Fail"
```

**Compiler / runtime requirements.** AST distinguishes conditional statement and conditional expression.

**Required conformance coverage.** Nested branches, type joins, missing else in value context.

### QUDS-006 — Loops and ranges

**Approved decision.** Support `for x in iterable`, inclusive range `a..b`, exclusive range `a..<b` (`..<` is one token), `for` with `while` and `step` (the C-style loop), `while`, `repeat` / `while` (the do-while loop), `break`, `continue`, labeled breaks, and `await for`. `..` is never a cascade. A zero step is a compile-time error when the step is a constant, and a runtime error otherwise. `1..5` contains 1, 2, 3, 4, and 5. `1..<5` contains 1, 2, 3, and 4. A negative step walks downward and still honors the inclusive or exclusive end.

**Quds syntax illustration** (may be a fragment):

```quds
for i in 1..5:
  print i
```

**Compiler / runtime requirements.** Define range direction, endpoint, step-zero errors, iteration binding semantics.

**Required conformance coverage.** Inclusive/exclusive endpoints, negative steps, async loops.

### QUDS-007 — Function declarations

**Approved decision.** Support typed parameters and `-> Return`, block bodies with explicit return, and expression bodies with `=` and implicit result.

**Quds syntax illustration** (may be a fragment):

```quds
add(a: int, b: int) -> int:
  return a + b
square(x: int) = x * x
```

**Compiler / runtime requirements.** Distinguish function declaration from assignment; infer expression body return type.

**Required conformance coverage.** Overload parsing, void functions, missing return, recursive calls.

### QUDS-008 — Classes and synthesized constructors

**Approved decision.** Class declarations use indented fields; `required` fields and defaults synthesize a constructor unless overridden.

**Quds syntax illustration** (may be a fragment):

```quds
class Person:
  name: String required
  age: int = 0
```

**Compiler / runtime requirements.** Generate Dart fields and constructors, with consistent named/positional policy.

**Required conformance coverage.** Required fields, defaults, inheritance, duplicate constructors.

### QUDS-009 — Unified calls and configuration blocks

**Approved decision.** A call may omit parentheses only when it has at least one positional argument written by juxtaposition (`print "OK"`, `Text "Hello"`) or uses a named-argument colon block (`Column:`). A bare name is a value or tear-off, never a call. Zero-argument calls use parentheses: `toUpperCase()`. `Column:` is an ordinary constructor call, not Flutter syntax. Nested named arguments and collection blocks are classified by the syntactic test in Normative resolutions, not by the expected type.

**Quds syntax illustration** (may be a fragment):

```quds
Column:
  spacing: 12
  children:
    Text "Hello"
    Text "World"
```

**Compiler / runtime requirements.** Resolve grammar for child expression sequences versus named arguments; preserve Dart named parameters.

**Required conformance coverage.** Nested calls, ambiguity, mixed args, trailing blocks.

### QUDS-010 — Async functions and streams

**Approved decision.** Support `async`, `async*`, Future, Stream, `await` and interoperable Dart asynchronous behavior.

**Quds syntax illustration** (may be a fragment):

```quds
load() async -> String:
  return await fetch()
```

**Compiler / runtime requirements.** Generate Dart async constructs; preserve error propagation and suspension.

**Required conformance coverage.** Future return typing, stream yield, exceptions.

### QUDS-011 — Imports via use

**Approved decision.** `use` imports Quds/Dart libraries and pub packages, with deterministic aliases and visibility.

**Quds syntax illustration** (may be a fragment):

```quds
use dart:math
```

**Compiler / runtime requirements.** Map imports to Dart, preserve package resolution and conditional imports.

**Required conformance coverage.** Aliases, duplicate imports, missing package.

### QUDS-012 — Exceptions and fallback expressions

**Approved decision.** Support try/catch/finally, throw, rethrow and concise `try expr else fallback`; Result is optional rather than forced.

**Quds syntax illustration** (may be a fragment):

```quds
value = try readFile() else "Default"
```

**Compiler / runtime requirements.** Define which errors fallback catches and evaluation timing.

**Required conformance coverage.** Typed catches, finally, rethrow, fallback laziness.

### QUDS-013 — Null safety

**Approved decision.** Follow sound Dart-style null safety with `T?`, promotion, null-aware access and explicit null assertions where appropriate.

**Quds syntax illustration** (may be a fragment):

```quds
name: String? = null
print name ?? "Guest"
```

**Compiler / runtime requirements.** Static nullability analysis and promotion invalidation.

**Required conformance coverage.** Nullable dereference, flow promotion, late initialization.

### QUDS-014 — Static type system

**Approved decision.** Use sound static typing, inference, generics, aliases and explicit `dynamic` escape hatch. No silent dynamic fallback.

**Quds syntax illustration** (may be a fragment):

```quds
var total: double = 0.0
```

**Compiler / runtime requirements.** Type checker must resolve symbols, expressions and assignments.

**Required conformance coverage.** Inference, implicit num conversions, generic mismatch.

### QUDS-015 — Properties

**Approved decision.** `property` declares getter/setter with a unified syntax; setter can validate or transform assigned values.

**Quds syntax illustration** (may be a fragment):

```quds
property name: String:
  get = _name
  set(value):
    _name = value.trim()
```

**Compiler / runtime requirements.** Generate Dart getters/setters; enforce declared type and access rights.

**Required conformance coverage.** Read-only/write-only, override, setter validation.

### QUDS-016 — Visibility

**Approved decision.** Public by default. `private` is library-private and lowers to a Dart library-private name, which Dart actually enforces. `protected` is enforced by the Quds checker for Quds subclasses and is emitted as `@protected` documentation for Dart readers. The Dart VM does not enforce `protected`; this specification does not claim that it does. Dart `_` privacy remains available on imported Dart libraries under Dart's own rule.

**Quds syntax illustration** (may be a fragment):

```quds
private token: String = "secret"
```

**Compiler / runtime requirements.** Define module/library and subclass access boundaries, including generated Dart wrappers.

**Required conformance coverage.** Cross-file private access, subclass access, exports.

### QUDS-017 — Inheritance and composition

**Approved decision.** Support `extends`, `implements`, mixin application, and Dart class modifiers. In a class header, `with` is mixin application only (`class Dog extends Animal with Walker:`). It is not object configuration. Object configuration uses statement/expression `with` and `with?` (QUDS-027, QUDS-047).

**Quds syntax illustration** (may be a fragment):

```quds
class Dog extends Animal with Walker:
```

**Compiler / runtime requirements.** Check override compatibility, mixin ordering and constructor chaining.

**Required conformance coverage.** Invalid inheritance, override, mixin conflicts.

### QUDS-018 — Collection methods and comprehensions

**Approved decision.** Keep familiar collection APIs and concise comprehensions, with statically typed results.

**Quds syntax illustration** (may be a fragment):

```quds
squares = [x * x for x in 1..5]
```

**Compiler / runtime requirements.** Desugar to efficient Dart collection constructs.

**Required conformance coverage.** Filters, nested comprehensions, lazy/eager semantics.

### QUDS-019 — Comments and metadata

**Approved decision.** Support `#` line comments, `/* ... */` block comments, `///` documentation and `@` annotations.

**Quds syntax illustration** (may be a fragment):

```quds
# note
/// Public API
@deprecated
```

**Compiler / runtime requirements.** Lexer preserves documentation and metadata source spans.

**Required conformance coverage.** Nested comments policy, docs attachment, annotation arguments.

### QUDS-020 — Strings and interpolation

**Approved decision.** Interpolation is `{expression}`. A literal brace is written by doubling: `{{` and `}}`. That is the only brace escape. Backslash escapes cover the other Dart string escapes (`\n`, `\t`, `\\`, quotes) and are not a second way to escape braces. Raw strings and triple-quoted strings exist. `$` does not start interpolation.

**Quds syntax illustration** (may be a fragment):

```quds
message = "Hello {user.name}"
```

**Compiler / runtime requirements.** Parse interpolation expressions as AST, not text substitution.

**Required conformance coverage.** Escapes, nested braces, multiline, invalid expressions.

### QUDS-021 — Compound assignment

**Approved decision.** Support `+=`, `-=`, etc. No `++` or `--`; evaluate the left-hand target exactly once.

**Quds syntax illustration** (may be a fragment):

```quds
var x = 1
x += 2
```

**Compiler / runtime requirements.** Lower complex lvalues safely with temporary values.

**Required conformance coverage.** Property getter side effects, immutable target, operator type.

### QUDS-022 — Parameter forms

**Approved decision.** Support positional, named, optional and required parameters with clear call-site matching.

**Quds syntax illustration** (may be a fragment):

```quds
send(to: String required, subject: String = ""):
  print subject
```

**Compiler / runtime requirements.** Model named/positional metadata in function types and overloads.

**Required conformance coverage.** Missing required, duplicate named, ordering.

### QUDS-023 — Lambda expressions

**Approved decision.** Support `x -> expression`, `() -> expression` and indented multiline lambda bodies.

**Quds syntax illustration** (may be a fragment):

```quds
double = x -> x * 2
```

**Compiler / runtime requirements.** Infer parameter types contextually; multiline bodies require explicit return.

**Required conformance coverage.** Nested lambda, async lambda, captures.

### QUDS-024 — Generic declarations

**Approved decision.** Classes/functions/types may declare generic parameters with Dart-compatible soundness.

**Quds syntax illustration** (may be a fragment):

```quds
identity<T>(value: T) -> T = value
```

**Compiler / runtime requirements.** Substitution, inference, bounds and runtime type handling.

**Required conformance coverage.** Generic inference, reification, variance.

### QUDS-025 — Enums

**Approved decision.** Enums may have fields and synthesized constructors while retaining exhaustiveness.

**Quds syntax illustration** (may be a fragment):

```quds
enum Color:
  red
  green
  blue
```

**Compiler / runtime requirements.** Generate Dart enum forms with associated data where valid.

**Required conformance coverage.** Duplicate values, fields, match completeness.

### QUDS-026 — Constructors

**Approved decision.** Support `init`, named, factory and const constructors with consistent field initialization.

**Quds syntax illustration** (may be a fragment):

```quds
class Point:
  x: int required
  y: int required
```

**Compiler / runtime requirements.** Check initialization order and constructor delegation.

**Required conformance coverage.** Const restrictions, factory return types, super init.

### QUDS-027 — Object configuration with with

**Approved decision.** Statement or expression `with receiver:` configures that object and evaluates the receiver once. Mixin application is only the class-header `with` (QUDS-017), never this form. `this` and `super` remain available inside instance members.

**Quds syntax illustration** (may be a fragment):

```quds
with button:
  enabled: true
```

**Compiler / runtime requirements.** Separate configuration semantics from mutation and mixin syntax.

**Required conformance coverage.** Readonly receiver, nested with, expression result.

### QUDS-028 — Deterministic resource management

**Approved decision.** `using` and `using async` dispose resources on scope exit, including exceptional paths.

**Quds syntax illustration** (may be a fragment):

```quds
using resource = openResource():
  process(resource)
```

**Compiler / runtime requirements.** Lower to try/finally; specify disposal interface contracts.

**Required conformance coverage.** Early return, exception, async disposal.

### QUDS-029 — Pattern matching

**Approved decision.** `match` supports typed cases, destructuring, guards and expressions with exhaustiveness checks.

**Quds syntax illustration** (may be a fragment):

```quds
match result:
  Success(value): print value
  Failure(error): print error
```

**Compiler / runtime requirements.** Typed pattern AST and narrowing; prevent unreachable cases.

**Required conformance coverage.** Guards, nested patterns, exhaustiveness.

### QUDS-030 — Parallel awaits and isolates

**Approved decision.** `await all:` groups asynchronous work; `await isolate:` executes isolate-compatible computation.

**Quds syntax illustration** (may be a fragment):

```quds
await all:
  loadUsers()
  loadOrders()
```

**Compiler / runtime requirements.** Define result ordering, errors, cancellation and sendability.

**Required conformance coverage.** Multiple failures, mutable capture, isolate serialization.

### QUDS-031 — Nullable binding with if let

**Approved decision.** `if let x = nullableExpr:` binds non-null value in branch.

**Quds syntax illustration** (may be a fragment):

```quds
if let name = user?.name:
  print name
```

**Compiler / runtime requirements.** Evaluate expression once and promote bound variable.

**Required conformance coverage.** False branch, shadowing, nullable types.

### QUDS-032 — Explicit multiline returns

**Approved decision.** `return` always exits the nearest function, never a `do:` block. Every multiline function or lambda that produces a value uses explicit `return`. An expression-bodied function returns its expression. A `do:` block produces its value with `result`, defined in QUDS-106.

**Quds syntax illustration** (may be a fragment):

```quds
sum(a: int, b: int) = a + b
```

**Compiler / runtime requirements.** Reject accidental implicit last-expression return in block bodies.

**Required conformance coverage.** Missing return, nested branches, void functions.

### QUDS-033 — Module/project layout

**Approved decision.** Use `.quds` sources and generated `.dart` files with pubspec.yaml compatibility.

**Quds syntax illustration** (may be a fragment):

```quds
use package:my_lib
```

**Compiler / runtime requirements.** Define module-to-library mapping and generated directory strategy.

**Required conformance coverage.** Relative imports, incremental builds, exports.

### QUDS-034 — Extensions and extension types

**Approved decision.** `extend Type:` adds methods; `type Name wraps Underlying:` creates distinct wrapped type.

**Quds syntax illustration** (may be a fragment):

```quds
extend String:
  shout() = toUpperCase()
```

**Compiler / runtime requirements.** Lower to Dart extension/extension type where possible.

**Required conformance coverage.** Name collisions, generic extensions, conversion.

### QUDS-035 — Interfaces, abstract types, mixins

**Approved decision.** Support interfaces, abstract classes, and mixins with sound implementation checking. In an `interface`, `name: Type` is an abstract getter. A writable abstract member is declared with `property` (QUDS-015). It is not also a stored field. An implementing class supplies a field, getter, or property of a compatible type.

**Quds syntax illustration** (may be a fragment):

```quds
interface Named:
  name: String
```

**Compiler / runtime requirements.** Generate Dart declarations and enforce contracts.

**Required conformance coverage.** Unimplemented member, mixin constraints.

### QUDS-036 — Operator overloads

**Approved decision.** Allow operator declarations, with enclosing type as default result where appropriate, except Dart operators with mandated return types.

**Quds syntax illustration** (may be a fragment):

```quds
operator +(other: Vector) = Vector(x + other.x)
```

**Compiler / runtime requirements.** Enforce Dart operator signatures and deterministic resolution.

**Required conformance coverage.** Equality/hash, invalid arity, type compatibility.

### QUDS-037 — Generators

**Approved decision.** Support `sync*`, `async*`, `yield`, `yield*` with Dart-compatible iteration semantics.

**Quds syntax illustration** (may be a fragment):

```quds
numbers() sync*:
  yield 1
  yield 2
```

**Compiler / runtime requirements.** Infer Iterable/Stream types and preserve lazy evaluation.

**Required conformance coverage.** Yield in try/finally, nested yield*, async errors.

### QUDS-038 — Records and destructuring

**Approved decision.** Support positional and named records and destructuring. `(expr)` is grouping. A record of one element is `(expr,)`. An empty record is `()`. Named fields use `(name: expr)`. On the left of `=` the same shapes are patterns. Inside a call's parentheses, `name: expr` is a named argument, not a record. Full rules are in Normative resolutions.

**Quds syntax illustration** (may be a fragment):

```quds
(x, y) = (1, 2)
```

**Compiler / runtime requirements.** Define record typing and patterns distinct from assignment.

**Required conformance coverage.** Arity mismatch, nested records, named fields.

### QUDS-039 — Comprehensions and spreads

**Approved decision.** Support expression-first and block-first comprehensions, collection filters and spread.

**Quds syntax illustration** (may be a fragment):

```quds
values = [...first, ...second]
```

**Compiler / runtime requirements.** Preserve order and exactly-once evaluation.

**Required conformance coverage.** Nested spreads, null-aware spread, type inference.

### QUDS-040 — Dart generic semantics

**Approved decision.** Maintain Dart generic reification and constraints where representable; do not claim unsound covariant conversions.

**Quds syntax illustration** (may be a fragment):

```quds
items: List<String> = ["A"]
```

**Compiler / runtime requirements.** Specify lowering for Quds-only generic features.

**Required conformance coverage.** Runtime type tests, covariance, bounds.

### QUDS-041 — Late initialization

**Approved decision.** `late` defers initialization; `late var` is mutable, bare `late` non-reassignable.

**Quds syntax illustration** (may be a fragment):

```quds
late config: Config
```

**Compiler / runtime requirements.** Detect uninitialized reads and duplicate assignments according to Dart-like behavior.

**Required conformance coverage.** Read before write, closure capture, late final.

### QUDS-042 — Static members

**Approved decision.** Support static fields/functions and class constants with explicit initialization semantics.

**Quds syntax illustration** (may be a fragment):

```quds
class MathUtil:
  static const pi = 3.14159
```

**Compiler / runtime requirements.** Generate static Dart members; disallow instance access when invalid.

**Required conformance coverage.** Static generic context, const evaluation.

### QUDS-043 — Native Quds code generation

**Approved decision.** Generators should consume Quds models and emit `.quds` sources, not only Dart artifacts.

**Quds syntax illustration** (may be a fragment):

```quds
@GenerateModel
class User:
```

**Compiler / runtime requirements.** Provide structured source/AST APIs and deterministic generated outputs.

**Required conformance coverage.** Rebuild determinism, collisions, source maps.

### QUDS-044 — Generated file organization

**Approved decision.** Manage generated Quds/Dart files automatically; allow explicit part/part-of interop where needed.

**Quds syntax illustration** (may be a fragment):

```quds
use generated:user_models
```

**Compiler / runtime requirements.** Avoid hand-maintained generated code imports.

**Required conformance coverage.** Stale outputs, part library identity.

### QUDS-045 — Function types

**Approved decision.** In type position, function types use `(parameters) -> Return`, including named and optional parameter metadata. In expression position the same arrow is a lambda, so `(String) -> bool` as a type appears only where a type is legal. `capture` is a keyword, not a call followed by a lambda (QUDS-091).

**Quds syntax illustration** (may be a fragment):

```quds
handler: (String) -> bool = text -> text.isNotEmpty
```

**Compiler / runtime requirements.** Lower to Dart function typedefs/signatures.

**Required conformance coverage.** Nullable function, async return, variance.

### QUDS-046 — Callable objects

**Approved decision.** Classes may define `call(...)` and instances are invocable.

**Quds syntax illustration** (may be a fragment):

```quds
class Adder:
  call(a: int, b: int) = a + b
```

**Compiler / runtime requirements.** Map to Dart call methods and overload restrictions.

**Required conformance coverage.** Generic call, named arguments.

### QUDS-047 — Cascade replacement

**Approved decision.** `with` and `with?` replace Dart `..` and `?..`. The receiver runs once. `with?` skips the block when the receiver is null and the expression result is null. These keywords are not mixin `with` and not the range tokens `..` and `..<`.

**Quds syntax illustration** (may be a fragment):

```quds
with user:
  name: "Ali"
```

**Compiler / runtime requirements.** Lower to temporaries/cascades and preserve null behavior.

**Required conformance coverage.** Nullable receiver, chained config, return value.

### QUDS-048 — Assertions and contracts

**Approved decision.** `assert` is development-only; `require` validates input; `check` validates state in production.

**Quds syntax illustration** (may be a fragment):

```quds
require age >= 0
```

**Compiler / runtime requirements.** Generate correct error types and message handling.

**Required conformance coverage.** Production mode, side effects, errors.

### QUDS-049 — Exception handling details

**Approved decision.** Typed catches `catch e: Type`, stack capture, rethrow and explicit stack-preserving throw.

**Quds syntax illustration** (may be a fragment):

```quds
try:
  work()
catch e, stack:
  log.error(e)
```

**Compiler / runtime requirements.** Preserve original stack traces and typed dispatch.

**Required conformance coverage.** Catch order, finally, rethrow outside catch.

### QUDS-050 — Value classes

**Approved decision.** `value class` has immutable fields and structural equality/hashCode.

**Quds syntax illustration** (may be a fragment):

```quds
value class Point:
  x: int required
  y: int required
```

**Compiler / runtime requirements.** Generate stable equality and hash; define nested mutable-field restrictions.

**Required conformance coverage.** Equality, hash consistency, generic fields.

### QUDS-051 — Value-class copyWith

**Approved decision.** Generate `copyWith` for value classes. Omitting a field keeps the current value. Passing null sets null. The generated Dart signature defaults each parameter to the public sentinel `quds.missing`, so a Dart caller who does not have the Quds compiler can omit the argument, pass null, or pass `missing` explicitly. `missing` is not null (QUDS-083).

**Quds syntax illustration** (may be a fragment):

```quds
updated = user.copyWith(name: "Ali")
```

**Compiler / runtime requirements.** Use sentinel/Optional semantics to preserve null updates.

**Required conformance coverage.** Nullable field set null, no-op copy.

### QUDS-052 — Structured patterns

**Approved decision.** Patterns may destructure records, lists, maps and objects with static validation.

**Quds syntax illustration** (may be a fragment):

```quds
match data:
  [first, ...rest]: print first
```

**Compiler / runtime requirements.** Lower to Dart patterns or explicit tests when needed.

**Required conformance coverage.** Partial matches, map missing keys, guards.

### QUDS-053 — Deferred cleanup

**Approved decision.** `defer` executes at scope exit in LIFO order, including sync/async cleanup.

**Quds syntax illustration** (may be a fragment):

```quds
defer closeResource()
```

**Compiler / runtime requirements.** Lower to nested try/finally; avoid duplicate execution.

**Required conformance coverage.** Early exit, exception, async ordering.

### QUDS-054 — Safe const inference

**Approved decision.** Implicit const exists only inside an already constant context, as in Dart: an inner literal or constructor does not need its own `const` keyword when the enclosing context is const. A normal binding `colors = ["red", "blue"]` is not const. The list remains mutable and keeps ordinary identity. Inference must not change mutation or identity.

**Quds syntax illustration** (may be a fragment):

```quds
const palette = ["red", "blue"]
colors = ["red", "blue"]
```

**Compiler / runtime requirements.** Never alter mutation behavior or object identity by optimization.

**Required conformance coverage.** Mutable literals, constant contexts.

### QUDS-055 — Factories and singleton classes

**Approved decision.** Support factory constructors and lazy isolate-local `singleton class`.

**Quds syntax illustration** (may be a fragment):

```quds
singleton class Cache:
  entries = map:
```

**Compiler / runtime requirements.** Generate lazy initialization per isolate.

**Required conformance coverage.** Initialization cycles, test isolation.

### QUDS-056 — Mixin declarations

**Approved decision.** Support `mixin`, `mixin class`, `on`, and application via `with`.

**Quds syntax illustration** (may be a fragment):

```quds
mixin Walkable on Animal:
```

**Compiler / runtime requirements.** Check on-constraints and mixin member resolution.

**Required conformance coverage.** Invalid target, diamond conflicts.

### QUDS-057 — Class modifiers

**Approved decision.** Support Dart-like final/base/interface/sealed/abstract class restrictions.

**Quds syntax illustration** (may be a fragment):

```quds
sealed class State:
```

**Compiler / runtime requirements.** Validate subclassing across library boundaries.

**Required conformance coverage.** External extends/implements, sealed cases.

### QUDS-058 — Dynamic invocation hooks

**Approved decision.** Support `noSuchMethod` only under Dart-compatible rules and explicit dynamic contexts.

**Quds syntax illustration** (may be a fragment):

```quds
class Proxy:
  noSuchMethod(invocation): ...
```

**Compiler / runtime requirements.** Do not weaken sound static analysis implicitly.

**Required conformance coverage.** Dynamic calls, missing member, overrides.

### QUDS-059 — Compile-time reflection metadata

**Approved decision.** `@Reflectable` produces AOT-safe metadata at compile time; no unrestricted runtime mirrors.

**Quds syntax illustration** (may be a fragment):

```quds
@Reflectable
class User:
```

**Compiler / runtime requirements.** Generate explicit metadata tables and registration.

**Required conformance coverage.** Private fields, generics, tree shaking.

### QUDS-060 — Compile-time Quds macros

**Approved decision.** Macros are authored in Quds, run with a safe structured compiler API, and cannot arbitrarily rewrite syntax.

**Quds syntax illustration** (may be a fragment):

```quds
@GenerateJson
value class User:
```

**Compiler / runtime requirements.** Sandbox expansion; deterministic and cacheable; maintain spans.

**Required conformance coverage.** Expansion errors, cycles, reproducibility.

### QUDS-061 — Annotation shorthand

**Approved decision.** `annotation Name:` declares a concise constant annotation definition.

**Quds syntax illustration** (may be a fragment):

```quds
annotation Serializable:
```

**Compiler / runtime requirements.** Lower to const annotation class/constructor.

**Required conformance coverage.** Annotation parameters, target restrictions.

### QUDS-062 — Conditional imports and compilation

**Approved decision.** Compile-time `when` and conditional imports exclude non-selected branches.

**Quds syntax illustration** (may be a fragment):

```quds
when platform == "web":
  use web_impl
```

**Compiler / runtime requirements.** Resolve conditions before incompatible platform code is analyzed.

**Required conformance coverage.** Unknown condition, dead branches, platform targets.

### QUDS-063 — Quds CLI

**Approved decision.** Provide `quds create/add/remove/get/run/build/test/analyze/format` integrated with Dart/pub.

**Quds syntax illustration** (may be a fragment):

```quds
quds build app.quds
```

**Compiler / runtime requirements.** Implement consistent exit codes, help and workspace resolution.

**Required conformance coverage.** CLI smoke tests, pub interop.

### QUDS-064 — Testing DSL

**Approved decision.** Support test/group/expect, async tests and Flutter widget tests via Dart ecosystem.

**Quds syntax illustration** (may be a fragment):

```quds
test "adds":
  expect add(2, 3) == 5
```

**Compiler / runtime requirements.** Lower test declarations to Dart test framework.

**Required conformance coverage.** Async failure, discovery, source diagnostics.

### QUDS-065 — Diagnostics and linting

**Approved decision.** Emit stable diagnostic IDs, precise `.quds` spans, hints, warnings, lint and fix suggestions.

**Quds syntax illustration** (may be a fragment):

```quds
# QUDS-E001 undefined name
```

**Compiler / runtime requirements.** Keep source spans throughout pipeline and code generation.

**Required conformance coverage.** Error recovery, fix-it accuracy.

### QUDS-066 — IDE and debugger

**Approved decision.** Provide LSP, debug adapter, `.quds` breakpoints and Flutter hot reload integration.

**Quds syntax illustration** (may be a fragment):

```quds
# IDE protocol feature
```

**Compiler / runtime requirements.** Maintain source maps and incremental parse/analyze APIs.

**Required conformance coverage.** Rename, go-to-definition, breakpoints.

### QUDS-067 — Documentation tooling

**Approved decision.** Use `///` documentation, API website generation and doctests via `quds doc test`.

**Quds syntax illustration** (may be a fragment):

```quds
/// Returns the sum.
```

**Compiler / runtime requirements.** Extract examples and compile/run them with diagnostics.

**Required conformance coverage.** Broken links, doctest failures.

### QUDS-068 — Language versioning

**Approved decision.** Each project declares its Quds language version in project metadata, not in a comment. `# quds: 1.0` is an ordinary comment and does not select a language version. `quds migrate` upgrades sources between declared versions. The compiler must not silently change the meaning of a project pinned to an older version.

**Quds syntax illustration** (may be a fragment):

```quds
# version lives in project metadata, not in this comment
```

**Compiler / runtime requirements.** Version-gate syntax and semantics, never silently change old projects.

**Required conformance coverage.** Migration fixtures, version diagnostics.

### QUDS-069 — Optimization and benchmarks

**Approved decision.** Optimize only when semantics preserved; benchmark compiler/runtime/size.

**Quds syntax illustration** (may be a fragment):

```quds
# optimization configuration
```

**Compiler / runtime requirements.** Use typed IR, avoid repeated evaluation and source-map loss.

**Required conformance coverage.** Debug/release parity, benchmark regressions.

### QUDS-070 — Platform interoperability

**Approved decision.** Provide Dart FFI, JS interop, Flutter platform channels and generated bindings where supported.

**Quds syntax illustration** (may be a fragment):

```quds
use dart:ffi
```

**Compiler / runtime requirements.** Check platform availability and types at compile time.

**Required conformance coverage.** Web/native targets, ABI, sendability.

### QUDS-071 — Package publication

**Approved decision.** Publish `.quds` sources plus generated `.dart` to pub.dev so Dart consumers need no Quds compiler.

**Quds syntax illustration** (may be a fragment):

```quds
# package layout
```

**Compiler / runtime requirements.** Define generated API stability and pub packaging rules.

**Required conformance coverage.** Dart-only consumer smoke test.

### QUDS-072 — Incremental compilation

**Approved decision.** Use dependency graph, content-addressed cache, watch and hot reload support.

**Quds syntax illustration** (may be a fragment):

```quds
quds build --watch
```

**Compiler / runtime requirements.** Invalidate only affected modules, preserve determinism.

**Required conformance coverage.** Changed imports, macro dependencies.

### QUDS-073 — Dependency management

**Approved decision.** Resolve Dart/Flutter/Quds dependencies through pub with compatibility diagnostics.

**Quds syntax illustration** (may be a fragment):

```quds
quds add collection
```

**Compiler / runtime requirements.** Delegate version solving to pub, avoid duplicate ecosystem.

**Required conformance coverage.** Conflicts, offline cache, lockfile.

### QUDS-074 — Deterministic formatter

**Approved decision.** Provide stable formatting with configurable indentation and line width; formatting must preserve semantics.

**Quds syntax illustration** (may be a fragment):

```quds
quds format lib/
```

**Compiler / runtime requirements.** Parse/format/parse equivalence; stable idempotence.

**Required conformance coverage.** Comments, multiline strings, nested calls.

### QUDS-075 — Runtime error mapping

**Approved decision.** Map Dart stack traces/errors back to original `.quds` lines; support error hooks.

**Quds syntax illustration** (may be a fragment):

```quds
# generated source maps
```

**Compiler / runtime requirements.** Emit mapping metadata and decode runtime traces.

**Required conformance coverage.** Async stacks, isolates, minified web.

### QUDS-076 — Structured logging

**Approved decision.** Provide typed structured logs, severity levels and pluggable sinks.

**Quds syntax illustration** (may be a fragment):

```quds
log.info "Loaded", data: map:
  "count": 3
```

**Compiler / runtime requirements.** Keep logging runtime library independent of compiler core.

**Required conformance coverage.** Sink failures, filtering, privacy.

### QUDS-077 — Typed configuration

**Approved decision.** Support typed configuration across environments with precedence and safe secret handling.

**Quds syntax illustration** (may be a fragment):

```quds
config.port: int = 8080
```

**Compiler / runtime requirements.** Separate compile-time and runtime config; avoid embedding secrets.

**Required conformance coverage.** Precedence, missing required, secrets.

### QUDS-078 — Structured concurrency

**Approved decision.** Support task groups, `spawn`, cooperative cancellation, lifecycle and aggregated errors.

**Quds syntax illustration** (may be a fragment):

```quds
task group:
  spawn fetchA()
  spawn fetchB()
```

**Compiler / runtime requirements.** Define task ownership, cancellation and isolate boundaries.

**Required conformance coverage.** Nested groups, errors, cancellation races.

### QUDS-079 — Reactive primitives

**Approved decision.** `state name = expr` is a mutable binding, like `var`, that also notifies reactive subscribers. It is not the immutable binding of bare `name =`. `computed` and `watch` are part of the same library feature and are not Flutter widgets.

**Quds syntax illustration** (may be a fragment):

```quds
state count = 0
computed doubled = count * 2
```

**Compiler / runtime requirements.** Specify dependency tracking and disposal as library/runtime feature.

**Required conformance coverage.** Cycles, disposal, batching.

### QUDS-080 — Declarative collection conditionals

**Approved decision.** `if` and `for` inside a collection literal or a syntactically classified collection block are collection elements, not statements and not if-expressions. This is generic collection syntax. The block is recognized by the syntactic test in Normative resolutions, not by the expected type.

**Quds syntax illustration** (may be a fragment):

```quds
children:
  if visible:
    Text "Shown"
```

**Compiler / runtime requirements.** Lower to Dart collection if/for; retain typed child elements.

**Required conformance coverage.** Nested conditionals, else, iteration.

### QUDS-081 — Unified function call grammar

**Approved decision.** Calls support positional/named arguments and nested calls with uniform syntax and no ambiguity.

**Quds syntax illustration** (may be a fragment):

```quds
sendEmail:
  to: "a@example.com"
  subject: "Hi"
```

**Compiler / runtime requirements.** Formalize parser precedence between declarations, blocks and calls.

**Required conformance coverage.** Positional/named mix, duplicate names.

### QUDS-082 — Explicit and safe conversion

**Approved decision.** `expr to Type` converts explicitly and fails on failure. Safe conversion is the token `to?`: `expr to? Type` returns null on failure. The target may itself be nullable (`expr to? int?`). `is` and `as` keep Dart's test and cast meanings. Custom types participate through a declared conversion protocol. `to?` is not the nullable-type suffix and not Result `?`.

**Quds syntax illustration** (may be a fragment):

```quds
age = input to? int
```

**Compiler / runtime requirements.** Specify whether conversion can parse strings, numeric coercion, and custom hooks.

**Required conformance coverage.** Null input, failure, overflow, generic target.

### QUDS-083 — Optional and missing values

**Approved decision.** `Optional<T>`, `missing`, `present` distinguish absent argument from explicit null; no `Type??` encoding.

**Quds syntax illustration** (may be a fragment):

```quds
update(name: Optional<String?> = missing)
```

**Compiler / runtime requirements.** Represent omission with tagged sentinel, not null.

**Required conformance coverage.** Omitted, present(null), overload/default.

### QUDS-084 — Parameter binding mutability

**Approved decision.** Parameters are immutable bindings by default; `var parameter` permits local reassignment but never mutates caller binding.

**Quds syntax illustration** (may be a fragment):

```quds
increment(var x: int):
  x += 1
```

**Compiler / runtime requirements.** Lower to local variable if Dart parameter semantics differ.

**Required conformance coverage.** Closure capture, caller unchanged.

### QUDS-085 — Static overload resolution

**Approved decision.** Multiple Quds functions may share a name when signatures are distinguishable. Resolution is compile-time; ambiguity is an error. Each overload is emitted as its own Dart function with a stable public name: the bare name when there is only one, otherwise `name$` plus a documented encoding of the parameter types. Dart has no overload set, so a Dart caller uses those generated names. A Quds tear-off must select one signature from context or from an explicit type; if it does not, the program is rejected.

**Quds syntax illustration** (may be a fragment):

```quds
parse(x: String) = ...
parse(x: int) = ...
```

**Compiler / runtime requirements.** Rank candidates using types, named args, defaults and variadics.

**Required conformance coverage.** Ambiguous overload, tear-offs, generic calls.

### QUDS-086 — Computed defaults

**Approved decision.** A default runs on each call where that argument is omitted, may read earlier parameters, and is not the same as passing null. Evaluation order is the two-phase order in QUDS-111: supplied argument expressions run once, left to right in source order; omitted defaults then run once, in declaration order.

**Quds syntax illustration** (may be a fragment):

```quds
greet(name: String, label: String = "Hi {name}") = label
```

**Compiler / runtime requirements.** Generate wrapper/body that evaluates defaults in declaration order.

**Required conformance coverage.** Side effects, dependencies, named args order.

### QUDS-087 — Typed variadics

**Approved decision.** `...values: Type` accepts variable argument counts; `...` spreads call arguments. Exact fixed signatures win when otherwise equal.

**Quds syntax illustration** (may be a fragment):

```quds
sum(...values: int) = values.fold(0, (a,b) -> a+b)
```

**Compiler / runtime requirements.** Specify collection representation, named boundary and overload precedence.

**Required conformance coverage.** Empty variadic, spread, wrong type.

### QUDS-088 — Destructuring and parallel assignment

**Approved decision.** Support records/lists destructuring and `(a,b)=(b,a)`; evaluate all RHS before any LHS assignment.

**Quds syntax illustration** (may be a fragment):

```quds
var a = 1
var b = 2
(a, b) = (b, a)
```

**Compiler / runtime requirements.** Use temporaries; validate target mutability and arity.

**Required conformance coverage.** Swap, side effects, nested destructuring.

### QUDS-089 — Named destructuring

**Approved decision.** Distinct syntaxes for record `(name: alias)`, object `Person(name: alias)` and map `{"name": alias}` patterns; aliases are explicit.

**Quds syntax illustration** (may be a fragment):

```quds
(name: userName, age:) = record
```

**Compiler / runtime requirements.** Use typed pattern AST; prevent key/property ambiguity.

**Required conformance coverage.** Missing map key, aliases, nested patterns.

### QUDS-090 — Lexical scopes and explicit shadowing

**Approved decision.** Scopes are lexical. Assigning an existing mutable outer binding updates it. A new local with the same name requires `shadow` and is immutable. A mutable new local is `shadow var`. An immutable outer binding cannot be reassigned. Initializers resolve before the new binding is declared, so the initializer still sees the outer name.

**Quds syntax illustration** (may be a fragment):

```quds
var count = 1
if true:
  count = 2
  shadow count = 100
```

**Compiler / runtime requirements.** Resolve names before deciding assignment/declaration; forbid implicit shadowing.

**Required conformance coverage.** Nested scopes, closure writes, shadow keyword.

### QUDS-091 — Closure capture and snapshots

**Approved decision.** Closures use Dart capture by default: a mutable binding stays live. `capture` is a keyword. `capture(x, ...) -> body` snapshots the listed binding values when the closure is created. It does not deep-copy object graphs. It is not a call of a function named `capture` followed by a lambda. A `for-in` binding is a fresh binding per iteration.

**Quds syntax illustration** (may be a fragment):

```quds
var count = 10
live = () -> count
saved = capture(count) -> count
count = 20
```

**Compiler / runtime requirements.** Lower snapshot to immutable local copies; loop for-in has per-iteration binding.

**Required conformance coverage.** Mutable capture, loop closures, async callbacks.

### QUDS-092 — Transitive readonly references

**Approved decision.** `readonly Type` forbids mutation through that reference, including nested paths. Other aliases may still mutate the object. Static enforcement where possible; runtime guards at interop boundaries.

**Quds syntax illustration** (may be a fragment):

```quds
items: readonly List<int> = [1,2,3]
```

**Compiler / runtime requirements.** Track readonly qualification through member/index access; classify mutating methods.

**Required conformance coverage.** Nested list mutation, external Dart API, aliases.

### QUDS-093 — Aliasing without mandatory ownership

**Approved decision.** Keep Dart reference identity and shared aliases. Optional static diagnostics for dangerous mutable aliasing; no Rust-like mandatory borrow/move system.

**Quds syntax illustration** (may be a fragment):

```quds
var items = [1]
other = items
other.add(2)
```

**Compiler / runtime requirements.** Do not silently copy objects when assigning or passing.

**Required conformance coverage.** Alias mutation, readonly views, isolate boundaries.

### QUDS-094 — Union types

**Approved decision.** `A | B` is a genuine union with flow narrowing and safe representation in Dart. Only operations valid for all alternatives before narrowing.

**Quds syntax illustration** (may be a fragment):

```quds
value: int | String = "42"
if value is String:
  print value.length
```

**Compiler / runtime requirements.** Define normalization, subtype unions and runtime tagging when needed.

**Required conformance coverage.** Narrowing, generic union, null union.

### QUDS-095 — Intersection types

**Approved decision.** `A & B` requires satisfying both type contracts; do not merge unrelated object instances automatically.

**Quds syntax illustration** (may be a fragment):

```quds
show(item: Named & Identifiable):
  print item.name
```

**Compiler / runtime requirements.** Lower using generated interface constraints or validated wrappers.

**Required conformance coverage.** Incompatible members, generic intersections.

### QUDS-096 — Type aliases

**Approved decision.** `type Name = ExistingType` creates alias only; `type Name wraps ExistingType` is distinct.

**Quds syntax illustration** (may be a fragment):

```quds
type UserId = int
type Validator<T> = (T) -> bool
```

**Compiler / runtime requirements.** Preserve alias transparency and wrapped type identity.

**Required conformance coverage.** Recursive alias, generic alias, casts.

### QUDS-097 — Algebraic data types

**Approved decision.** `sealed type` defines finite alternatives, including payload-bearing cases; `match` can destructure cases.

**Quds syntax illustration** (may be a fragment):

```quds
sealed type LoadResult<T>:
  Loading
  Success(value: T)
  Failure(message: String)
```

**Compiler / runtime requirements.** Generate sealed Dart hierarchy with stable case constructors.

**Required conformance coverage.** Generic cases, equality, exhaustive match.

### QUDS-098 — Match exhaustiveness

**Approved decision.** One exhaustiveness checker covers every finite type: a `sealed type`'s declared cases and a `sealed class`'s same-library subtypes. A `match` or `switch` expression must be exhaustive. A statement form warns when incomplete. Unreachable cases are errors. `switch` is an alias of `match` with the same grammar.

**Quds syntax illustration** (may be a fragment):

```quds
text = match result:
  Loading: "wait"
  Success(v): v
  Failure(e): e
```

**Compiler / runtime requirements.** Implement pattern coverage and type joins.

**Required conformance coverage.** Wildcard, guarded cases, unions.

### QUDS-099 — Generic constraints

**Approved decision.** Generic parameters support one or more bounds, including intersections.

**Quds syntax illustration** (may be a fragment):

```quds
find<T: Identifiable>(items: List<T>, id: int) -> T?:
  ...
```

**Compiler / runtime requirements.** Check constraints during inference and instantiation.

**Required conformance coverage.** Multiple bounds, override, inference.

### QUDS-100 — Variance declarations

**Approved decision.** `out` and `in` are allowed only when every use site is in the matching position and the Dart lowering is sound. Otherwise the declaration is rejected. It is not silently weakened. Dart's ordinary generic types, without `in` or `out`, remain available with Dart's own generic rules.

**Quds syntax illustration** (may be a fragment):

```quds
interface Producer<out T>:
  get() -> T
```

**Compiler / runtime requirements.** Variance checker tracks producer/consumer positions.

**Required conformance coverage.** Invariant field, contravariant return.

### QUDS-101 — Contextual inference

**Approved decision.** Infer from expected type only when unambiguous; never silently fall back to dynamic.

**Quds syntax illustration** (may be a fragment):

```quds
handler: (int) -> int = x -> x * 2
```

**Compiler / runtime requirements.** Bidirectional typing for lambdas and collection literals.

**Required conformance coverage.** Empty list inference, ambiguous lambda.

### QUDS-102 — Safe null operators

**Approved decision.** Keep `?.`, `??`, `??=` with Dart-like lazy evaluation and flow typing.

**Quds syntax illustration** (may be a fragment):

```quds
city = user?.address?.city ?? "Unknown"
```

**Compiler / runtime requirements.** Preserve short-circuit and nullable receiver evaluation.

**Required conformance coverage.** Side effects, nullable lvalues.

### QUDS-103 — Validated wrapped types

**Approved decision.** Wrapped types may declare `require` invariants enforced at construction; reject statically provable invalid constants.

**Quds syntax illustration** (may be a fragment):

```quds
type Percentage wraps int:
  require value >= 0 and value <= 100
```

**Compiler / runtime requirements.** Generate validating constructors and preserve wrapper identity.

**Required conformance coverage.** Boundary, runtime failure, unsafe bypass.

### QUDS-104 — Generic extensions

**Approved decision.** `extend List<T>:` and bounded generic extensions add statically resolved methods.

**Quds syntax illustration** (may be a fragment):

```quds
extend List<T>:
  secondOrNull() -> T?:
    if length < 2:
      return null
    return this[1]
```

**Compiler / runtime requirements.** Resolve extension member conflicts deterministically.

**Required conformance coverage.** Ambiguous extension, nullable receiver.

### QUDS-105 — Pipeline operator

**Approved decision.** `expr |> callee` evaluates `expr` once and passes it to `callee`. If `callee` is a name or function value, the value is the first positional argument. If `callee` is a call with exactly one hole, the value fills that hole and the call's other arguments then run in source order. Overload resolution uses the type of the piped value. The operator is left-associative and sits just above assignment.

**Quds syntax illustration** (may be a fragment):

```quds
result = loadData()
  |> filterValid
  |> normalize
```

**Compiler / runtime requirements.** Lower with temporaries to avoid duplicate side effects.

**Required conformance coverage.** Precedence, multi-argument call, overloads.

### QUDS-106 — Value-producing do blocks

**Approved decision.** `do:` is a lexical expression scope. Its value is `result expr`, which does not exit the enclosing function. `return` inside `do:` still returns from the function, and the `do:` does not complete. A missing `result` on a path that finishes the block is an error when the `do:` is used as a value.

**Quds syntax illustration** (may be a fragment):

```quds
total = do:
  price = 100
  tax = price * 0.15
  result price + tax
```

**Compiler / runtime requirements.** Lower to local function/IIFE or IR block preserving control flow.

**Required conformance coverage.** Missing return, async do, shadowing.

### QUDS-107 — Partial application

**Approved decision.** In an argument position, `_` is a hole and the call produces a function whose signature is inferred. That form is not evaluated as a call. In a pattern, `_` is a wildcard and binds nothing. A local or parameter may not be named `_`. The two uses meet only in different grammar positions, so they are not ambiguous.

**Quds syntax illustration** (may be a fragment):

```quds
multiply(a: int,b: int)=a*b
double = multiply(2, _)
```

**Compiler / runtime requirements.** Disambiguate wildcard `_` in patterns vs argument hole.

**Required conformance coverage.** Multiple holes, named holes, overloads.

### QUDS-108 — Typed Result

**Approved decision.** Standard `Result<T,E>` with `Ok` and `Error`; exceptions remain supported.

**Quds syntax illustration** (may be a fragment):

```quds
divide(a: double,b: double) -> Result<double,String>:
  if b == 0:
    return Error("zero")
  return Ok(a / b)
```

**Compiler / runtime requirements.** Specify tagged cases, generic variance, equality.

**Required conformance coverage.** Success/error patterns, interop, nested Result.

### QUDS-109 — Result error propagation

**Approved decision.** In expression position, postfix `?` unwraps `Result` or returns the error from the nearest function whose result type is a compatible `Result`. In type position, postfix `?` is the nullable type. The two positions do not overlap. Null-aware access is the token `?.`. Safe conversion is the token `to?`. `with?` is a keyword. None of these is the Result suffix.

**Quds syntax illustration** (may be a fragment):

```quds
calculate() -> Result<int,String>:
  value = parseInt("10")?
  return Ok(value + 1)
```

**Compiler / runtime requirements.** Lower to match/early return, preserving errors and evaluation once.

**Required conformance coverage.** Incompatible error type, async function, nested call.

### QUDS-110 — Function contracts

**Approved decision.** `require` validates preconditions, `check` validates state/postconditions; production validations must not be erased.

**Quds syntax illustration** (may be a fragment):

```quds
withdraw(balance: double, amount: double) -> double:
  require amount <= balance
  result = balance - amount
  check result >= 0
  return result
```

**Compiler / runtime requirements.** Define failure classes and evaluation order.

**Required conformance coverage.** Side effects, production mode, error messages.

### QUDS-111 — Evaluation order

**Approved decision.** Every expression runs once, left to right, unless a rule explicitly short-circuits it. At a call, supplied argument expressions run once in source order, then omitted defaults run once in declaration order. A default sees parameters that are already available: earlier defaults and any supplied argument. Compound-assignment targets, pipeline inputs, and multi-assignment right-hand sides also run once.

**Quds syntax illustration** (may be a fragment):

```quds
result = f(next(), next())
```

**Compiler / runtime requirements.** IR lowering must introduce temporaries when necessary.

**Required conformance coverage.** Side effects, getters, named args, pipelines.

### QUDS-112 — Name resolution

**Approved decision.** Define deterministic precedence for local names, imported symbols, members and extensions; reject ambiguity rather than guessing.

**Quds syntax illustration** (may be a fragment):

```quds
use package:foo
```

**Compiler / runtime requirements.** Symbol resolution includes namespaces, aliases and overload sets.

**Required conformance coverage.** Conflicting imports, extension collisions.

### QUDS-113 — Type compatibility

**Approved decision.** Enforce soundness for unions, generics, readonly and nullability; no unsafe implicit conversions.

**Quds syntax illustration** (may be a fragment):

```quds
value: int = 10
```

**Compiler / runtime requirements.** Type-check all assignments, returns, calls and casts.

**Required conformance coverage.** Subtyping, variance, readonly escape.

### QUDS-114 — Dart interoperability

**Approved decision.** Generated Dart APIs must remain usable from Dart; Quds-only features get explicit wrappers and stable public names.

**Quds syntax illustration** (may be a fragment):

```quds
# generated Dart package
```

**Compiler / runtime requirements.** Document ABI/API mapping, error propagation and package publication.

**Required conformance coverage.** Dart caller integration, nullable boundaries.

### QUDS-115 — Uniform and unambiguous syntax

**Approved decision.** Calls, properties and blocks follow one coherent grammar. Reject shortcuts that cannot be parsed deterministically.

**Quds syntax illustration** (may be a fragment):

```quds
Column:
  spacing: 12
  children:
    Text "Hello"
```

**Compiler / runtime requirements.** Maintain grammar specification, parser precedence and ambiguity tests.

**Required conformance coverage.** Nested named blocks, declaration/call conflicts.


## Cross-feature invariants (mandatory)

- **No implicit mutation:** immutable binding, readonly reference and deeply immutable object are distinct concepts. `readonly` is transitive *through that reference* but does not freeze all aliases.
- **No implicit shadowing:** QUDS-090 requires explicit `shadow`; assignment to an existing mutable outer binding mutates it; assignment to an existing immutable outer binding is an error.
- **No implicit multiline return:** an expression-bodied function returns its expression. A block-bodied function returns only with `return`. A `do:` block yields only with `result`.
- **No silent dynamic fallback:** inference failures produce actionable diagnostics, not untyped behavior.
- **Omission differs from null:** `Optional<T>`, `missing`, `copyWith`, and computed defaults keep that distinction in generated Dart. The public sentinel is `quds.missing`.
- **Exactly-once evaluation:** the right-hand side of a multi-assignment, a pipeline input, a compound-assignment receiver, each supplied argument, and each default expression run once. Supplied arguments run in source order before defaults run in declaration order.
- **Dart-compatible closures:** captured mutable bindings are live; `capture(...)` freezes the binding value only, not object graph contents.
- **Dart-first interoperability:** emit usable Dart, even for Quds-only constructs requiring generated adapters.
- **Not a Flutter DSL:** `Column:` and `children:` are demonstrations of generic call/collection syntax; the core grammar must work with any library.

## Normative resolutions

This section removes the contradictions between numbered rules. It is grammar and semantics, not a compiler status report. An illustration elsewhere is wrong if it disagrees with this section.

### Tokens that share a character

Longest match wins. These are single tokens: `..<`, `??`, `??=`, `?.`, `...?`, `to?`, `with?`, `is!`, `~/`, `<<`, `>>`, `>>>`, and the compound assignments. A following shorter token must not be split out of one of these.

| Token | Only meaning |
| --- | --- |
| `#` | Line comment through the end of the line. Not a Dart symbol. |
| `//` | Also a line comment, so Dart line comments are legal Quds. Not division. |
| `..` | Inclusive range. Not a cascade. |
| `..<` | Exclusive range. Not a range followed by `<`. |
| `with` in a class header (`extends Super with Mixin`) | Mixin application. Not legal after `implements`. |
| `with expr:` / `with? expr:` | Object configuration. Receiver runs once. `with?` yields null without entering the block when the receiver is null. |
| `?` in type position | Nullable type `T?`. |
| `?` in expression position, postfix | Unwrap `Result` or return its error from the nearest compatible `Result` function. |
| `?.` | Null-aware member, call, or index. |
| `??` / `??=` | If-null expression and if-null assignment. The right side runs only when the left is null. |
| `to` | Explicit conversion. Failure is an error. |
| `to?` | Safe conversion. Failure is null. The target type may be nullable: `text to? int?`. |
| `with?` | Null-aware configuration. Not `with` plus Result `?`. |
| `...?` | Null-aware spread. The operand spreads only when non-null. |
| postfix `!` | Null assertion. |
| prefix `!` or `not` | Boolean negation. |
| `++` / `--` | Not in the language. The effect is `+= 1` or `-= 1`, and the target runs once. |
| `?:` | Not in the language. The effect is an if-expression. |

`#name` as a Dart symbol is written `symbol "name"` and lowers to Dart `#name`.

### Precedence

From tightest to loosest, with Dart's order where Quds keeps the operator:

1. Postfix `.` `?.` `!` `?` calls `()` `[]`
2. Prefix `-` `not` / `!` `~` `await`
3. Multiplicative `*` `/` `~/` `%`
4. Additive `+` `-`
5. Shift `<<` `>>` `>>>`
6. Bitwise `&` then `^` then `|`
7. Range `..` `..<`
8. Relational `<` `>` `<=` `>=` `as` `is` `is!` `to` `to?`
9. Equality `==` `!=`
10. `and`
11. `or`
12. `??`
13. `|>`
14. Assignment and compound assignment

If-expressions, `do:`, `match`, and `with` are primary forms, not infix operators. There is no ternary and no cascade at the Dart cascade level.

### Colon blocks

Classification uses the tokens in the block, never the expected type.

1. `map:` and `set:` always open collection literals. A call to something named `map` or `set` uses `map(...)` or `map argument`.
2. `class`, `enum`, `mixin`, `interface`, `extend`, `value class`, `sealed type`, `sealed class`, and a function declaration open declaration bodies.
3. A block whose rows are all `identifier:` entries is a named-argument block. `if`, `for`, `repeat`, spread, and any row that is not an identifier label keep the block from being a named-argument block.
4. Every other indented block after `:` in argument or element position is a collection-element block. `if` and `for` there are collection forms (QUDS-080).
5. A named-argument value that is itself a nested block is classified again from that nested block alone.

```quds
Column:
  spacing: 12
  children:
    Text "Hello"
    if visible:
      Text "Shown"
settings = map:
  "mode": "dark"
```

The outer `Column:` block is only identifier labels, so it is named arguments. The `children:` block contains a call and an `if`, so it is a collection. `map:` cannot be read as a call.

A named-argument block must contain at least one row. A zero-argument call is `name()`. A bare `name` is a tear-off or value.

### Statements, functions, and calls

In statement or member position, `name(parameters) ->`, `name(parameters):`, and `name(parameters) =` are function declarations when every item in the parentheses is a parameter. A parameter is `name: Type`, `var name: Type`, `name: Type required`, `name: Type = default`, or one of those forms inside an optional-positional `[...]` group.

`name(arguments)` with any non-parameter item is a call. `name argument` is a one-argument call. `name:` plus a named-argument block is a call. `name(...) :` with a parameter list is a declaration, not a call. To pass a type as a value, put it in a named-argument block or in a call that is not a declaration:

```quds
process:
  item: Widget
```

Parameter kinds, all four Dart kinds:

| Kind | Quds | Dart lowering |
| --- | --- | --- |
| Required positional, also passable by name from Quds | `a: int` | `{required int a}` so the Dart name survives. Quds may still pass it by position. |
| Required named | `to: String required` | `{required String to}` |
| Optional named | `subject: String = ""` | `{String subject = ""}` |
| Optional positional | `[times: int = 1]` | `[int times = 1]` |

A Quds positional call of a dual parameter is rewritten to the Dart named argument. A Dart caller of the generated API uses the name. Calling a Dart positional-only API from Quds stays positional.

### `if`, loops, and `match`

- Statement `if` may omit `else`.
- Expression `if` is legal in expression position, requires `else`, and each branch is an expression. A branch that needs statements is a `do:` expression.
- Collection `if` exists only in collection position.
- `for x in iterable:` iterates. `for x in 1..5:` uses an inclusive range. `for x in 1..<5:` is exclusive.
- `for var i = 0 while i < n step i += 1:` is the C-style loop. `step` may be omitted when there is no update. The condition is an expression, not a `while` statement.
- `while cond:` is the while loop.
- `repeat:` body then `while cond` is do-while. Expression `do:` is not this form; `repeat` is the only do-while head.
- `label name` before a loop names it. `break` and `continue` may take that name. A label is not `name:`, so it is not a call.
- `await for x in stream:` is asynchronous iteration.
- `match` and `switch` are the same grammar in statement and expression position. Patterns cover Dart patterns: constant, variable, identifier, parenthesized, list, map, record, object, wildcard `_`, rest, logical-or, logical-and, relational, cast, null-check, and null-assert, plus `when` guards. `if value is Pattern:` is the if-case form. `if let name = expr:` binds a non-null value and evaluates `expr` once.

### Arrows, records, holes, and capture

- Type position `(parameters) -> Type` is a function type. Named and optional parameters use the same parameter grammar as declarations.
- Expression position `x -> expr`, `(x) -> expr`, and `(x: int) -> expr` are lambdas. A parameter type is written `name: Type`. A bare `(String) -> bool` in expression position is a lambda with a parameter named `String` only if `String` is not parsed as a type keyword; type keywords in that slot are parameter types, so write a value parameter as `(s: String) -> ...`.
- `capture(names) -> expr` is the snapshot keyword. The names are bindings, snapshotted by value, not deep-copied.
- `(a)` groups. `(a,)` is a one-field record. `(a, b)` and `(name: expr, other: expr)` are records. The same forms on the left of `=` are patterns. Call parentheses do not form a record; their `name:` items are arguments.
- Argument `_` is a hole (QUDS-107). Pattern `_` is a wildcard. No binding is named `_`.

### Evaluation

Short-circuit operators are `and`, `or`, `??`, `?.`, `...?`, and `with?`. Everything else runs once.

Call order:

1. The callee expression.
2. Supplied argument expressions, source order, left to right, including named arguments in the order written.
3. Omitted defaults, declaration order. A default may read earlier parameters only. Those parameters are already supplied or already defaulted.

`return` exits the function. `result` finishes a `do:` only. `yield` and `yield*` belong to generators and do not exit an outer function.

`defer` statements in a scope run at scope exit in LIFO order, after the body and before the scope's `using` disposal completes. `using` disposal is the outermost `finally` of that scope. `finally` on an explicit `try` runs when that `try` exits, inside this order. A `defer` or disposal that throws replaces a pending success and follows Dart `finally` exception rules: the new error propagates, and the previous error is not dropped silently if the platform error object can chain it.

`require` fails as an argument error before the callee body. `check` fails as a state error and is not removed in production. `assert` is removed from production. Production here means a release build, the same notion as Dart's `assert`.

### Constants, bindings, and reactive state

- Bare `name = expr` declares an immutable binding if no visible binding exists. If a mutable binding is visible, it assigns that binding. If an immutable binding is visible, it is an error. A new same-name local is `shadow name = expr` and is immutable. A mutable shadow is `shadow var name = expr`.
- `var` is mutable. `const` is a compile-time constant. `late` is immutable and assigned once. `late var` is mutable and may be read only after assignment.
- Implicit const applies only inside a constant context. `colors = ["red", "blue"]` is a mutable list. `const palette = ["red", "blue"]` is a constant list. Inference must not take mutability or identity away.
- `state name = expr` is mutable storage with notifications. It is not an immutable binding.

### Dart parity

Every Dart language rule below is either the same rule, a renamed spelling, or an honest lowered spelling. Library APIs (`dart:isolate`, `dart:ffi`, `dart:async`, `dart:core`) are usable through `use`.

| Dart rule | Quds availability |
| --- | --- |
| `var`, `final`, `const`, `late`, `late final` | `var`, bare binding, `const`, `late var`, `late` |
| Local functions | Allowed with the function-declaration grammar |
| Type inference and explicit types | Same. No silent `dynamic` |
| `int`, `double`, `num`, bitwise, shifts, `~/`, hex, scientific, digit separators | Same tokens and Dart values, including `0xFF`, `1e-3`, `1_000` |
| Strings, raw strings, multiline strings | Quotes and triple quotes. Raw prefix `r`. Interpolation is `{expr}` |
| `//`, `/* */`, `///` | `//` and `#`, plus `/* */` and `///` |
| Booleans and logical operators | `and`, `or`, `not` / prefix `!` |
| Lists, sets, maps, spreads, null-aware spreads, collection if/for | `[]`, `set:`, `map:`, `...`, `...?`, collection `if`/`for` |
| Records and record equality | Parentheses form above. Equality is Dart record equality |
| `null`, `T?`, `!`, `??`, `??=`, `?.`, `?..` | Same, except `?..` is `with?` |
| Promotion, `is`, `is!`, `as` | Same |
| `Never`, `void`, `dynamic`, `Object` | Same, and `dynamic` is explicit only |
| Functions, closures, tear-offs | Closures are lambdas. A bare name is the tear-off. Zero-arg calls use `()` |
| Optional positional, named, `required`, defaults | Parameter table above |
| `sync*`, `async*`, `yield`, `yield*` | Same keywords |
| `async`, `await`, `Future`, `Stream` | Same. `await for` is asynchronous iteration |
| Classes, abstract members, `this`, `super` | `class`. Interface members as specified in QUDS-035 |
| Generative, named, redirecting, factory, and const constructors, initializer lists, initializing formals, super parameters | `init`, `init name`, `init = other`, `factory`, `const init`, with `this.field` and `super.field` |
| `extends`, `implements`, `with`, `on` | Same words, with `with` restricted to the class header for mixins |
| `base`, `interface`, `final`, `sealed`, `mixin`, `mixin class` | Same modifiers |
| Getters, setters, operators | `property` and `operator`. Dart-mandated operator result types stay mandated |
| `covariant`, `external`, `static` | Same modifiers |
| `noSuchMethod` | Available only on a class that opts into dynamic dispatch. It does not weaken static checks on typed receivers |
| Enums with fields | `enum` |
| Extensions and extension types | `extend Type:` and `type Name wraps Type:` |
| Generics, bounds, generic methods, typedefs | Same. A transparent alias is `type Name = Type`. `in` / `out` only when the lowering is sound |
| Patterns, switch statements and expressions, if-case, guards, exhaustiveness, sealed types | `match` / `switch`, `if value is Pattern:`, `when`, QUDS-098 |
| `import`, `export`, `show`, `hide`, `as`, deferred, `part`, `part of` | `use`, `export`, `show`, `hide`, `as`, `deferred`, `part`, `part of` |
| Conditional import | `when` (QUDS-062), resolved before the discarded branch is analyzed |
| Library privacy | `private`, lowered to Dart `_` privacy |
| Annotations and `Symbol` | `@Name` arguments. `symbol "name"` lowers to `#name` |
| `assert`, `try`, `on`, `catch`, `finally`, `throw`, `rethrow`, stack traces | Same. `catch e: Type` is the typed catch. `require` and `check` stay in production; `assert` does not |
| C-style `for`, `while`, do-while, `break`, `continue`, labels | `for`/`while`/`step`, `while`, `repeat`/`while`, `label` |
| Cascades | `with` and `with?` |
| Ternary `?:` and `++` / `--` | If-expression, `+= 1`, `-= 1`. The Dart tokens are not reused |
| `augment` | Allowed with the target Dart SDK's augmentation grammar when that SDK supports it |
| Isolates, FFI, zones, core libraries | `use dart:isolate`, `use dart:ffi`, and the corresponding Dart libraries. No second runtime |
| Const contexts and implicit const | Same as Dart, and only inside a const context |

Overloads, unions, intersections, `readonly`, `Optional`, and `Result` are Quds features. Each overload and each `copyWith` remains callable from Dart through the generated names and the `quds.missing` sentinel. `readonly` is a Quds checker rule plus a boundary check where a Dart API cannot express it. It does not pretend the Dart VM tracks readonly aliases. `protected` is the same kind of honest lowering.

### Still not a second language design

Macro sandbox limits, diagnostic code numbers, package layout details, and source-map encoding still need engineering specifications. They must follow the rules above. They must not invent a second meaning for a token, a second evaluation order, or a Dart feature with no row in the parity table.

**Agent process:** implement from this section. If a program can be parsed two ways, that is a compiler bug or a missing rejection, not a new language rule. If a choice would change behavior this section already fixes, do not change it without an explicit language revision.

## Suggested compiler milestones and gates

| Milestone | Deliverables | Gate |
|---|---|---|
| M0 | Dart package, source manager, diagnostics, CI | `dart format`, `dart analyze`, `dart test` pass |
| M1 | Lexer with INDENT/DEDENT, strings, operators | Token goldens + negative lexical tests |
| M2 | Pratt parser, typed AST, statement blocks | AST snapshots + syntax error recovery |
| M3 | Name resolution, mutability, types, functions | Scope/type positive and negative tests |
| M4 | Dart emitter, CLI, source mapping | Golden Dart + real execution integration tests |
| M5 | Classes, generics, interop, async | Dart/Flutter interop test matrix |
| M6 | Quds-only advanced semantics | Per-rule conformance suite |
| M7 | Tooling, packaging, performance | LSP/formatter/CLI + benchmarks |

### First executable acceptance program

```quds
sum(a: int, b: int) -> int:
  return a + b

main():
  numbers = [10, 20, 30]
  var total = 0

  for number in numbers:
    total += number

  if total > 50:
    print "Total: {total}"

  print sum(5, 7)
```

Expected standard output:

```text
Total: 60
12
```

**Definition of done:** the Quds source lexes, parses, type-checks, emits Dart, passes `dart analyze`, executes with exactly this output, and produces a diagnostic tied to original source coordinates when intentionally broken.

## Repository handoff

Repository: `MohammedAsaadAsaad/quds_lang`.

Recommended files: `AGENTS.md`, `docs/LANGUAGE_DECISIONS.md`, `docs/OPEN_QUESTIONS.md`, this full specification, `docs/IMPLEMENTATION_PLAN.md`, source under `lib/src/`, tests under `test/`, examples under `examples/`.

**Do not mark a rule implemented merely because it appears in this document.** Every feature requires compiler support, diagnostics, documentation, and tests.