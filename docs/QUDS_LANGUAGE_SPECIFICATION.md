# Quds Language — Complete Design Decisions and Agent Implementation Specification

**Version:** 1.2 · **Date:** 2026-11-11 · **Rules:** QUDS-001 through QUDS-115 · **Status:** Language design complete through Dart 3.13. The test suite covers the required conformance line of each rule. An already-started future is not aborted, and `quds migrate` does not rewrite a project whose `quds.yaml` names a version other than 1.2.

## Agent instructions — read before implementation

You are implementing **Quds**, a general-purpose, indentation-based, strongly and statically typed programming language that compiles to Dart. It must interoperate with Dart/pub/Flutter while **not** becoming a Flutter-specific language or widget framework. The user approved QUDS-001–091 through iterative choices, and explicitly delegated QUDS-092–115 to the assistant. This file preserves those decisions in expanded, implementation-oriented form; where a detail was not explicitly decided, it is identified as an implementation task rather than fabricated as established consensus.

**Priority rules:**

1. Preserve the numbered decisions and the formal grammar. A contradiction between them is a specification bug. Record it in `docs/OPEN_QUESTIONS.md` and do not invent a third meaning in the compiler.
2. Implement a proper lexer → parser → typed AST → symbol resolution → type checker → normalized IR → Dart emitter, not a regex-based translator.
3. Source locations and diagnostics must refer to original `.quds` source. Generated Dart must preserve evaluation order and side effects.
4. Start with an executable, tested MVP; do not claim 115 features are implemented until every one has positive, negative and interop conformance tests.
5. Preserve static soundness, null safety, clear scoping, explicit mutability, and deterministic overload resolution.
6. Reuse Dart runtime semantics where specified. Do not claim compile-time safety that is only enforced by a runtime wrapper, particularly for `readonly`, union types and external APIs.
7. Keep syntax short and consistent, favoring `:` plus indentation, but never introduce parsing ambiguity to save characters.
8. Generated Dart should be readable, deterministic, testable and compatible with supported Dart SDK versions.
9. Illustrations may omit imports and surrounding declarations. They are examples. The formal grammar is the syntax.
10. Report exactly what was coded, what was tested, and what remains unsupported.
11. Authority order is: the single-meaning token table, then **Formal grammar and semantics**, then **Normative resolutions**, then illustrations. An elaboration must not give a token a second meaning in the same position.

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

Each rule contains: **decision**, **Quds illustration**, **compiler obligations**, and **conformance cases**. A sample may omit imports or surrounding declarations. Illustrations are examples of the formal grammar, not a second syntax.

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
var whole = 0.0, fraction = 0.0
```

**Compiler / runtime requirements.** Symbol table tracks declaration kind; reject reassignment to immutable names. A comma on the same line declares another binding. The leading `var`, `const`, `late`, `shadow`, `state`, or `computed` applies to every name on that line. Each name may carry its own type. Initializers run from left to right, so a later one may read an earlier name. A value that opens a block ends the line.

**Required conformance coverage.** Reassignment, initialization, inference, const expression validity.

### QUDS-003 — Core collection literals

**Approved decision.** Lists use `[]`; maps and sets use the keywords `map:` and `set:` followed by an indented element block; records are parenthesized and first-class. `map:` and `set:` are not calls. A function or constructor named `map` or `set` is called with parentheses or a positional argument (`map items`), never as a bare colon block. Inside `map:`, a row is `key-expression: value-expression`; an identifier key is that variable's value, so a string key is quoted. Type inference preserves element, key, and value types. Empty lists, maps, and sets are allowed where the element type is known from context or from an explicit annotation; otherwise the program is rejected and is not given type `dynamic`. A prefix `?` on a collection element is a null-aware element: the expression runs once and is omitted when the value is null.

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

A comparison may continue: `0 <= index < items.length` and `"0" <= piece <= "9"`. Every operand runs once, from left to right, including when an earlier comparison is false. The operators are `<`, `<=`, `>`, and `>=`. `==` and `!=` do not chain. `and` still separates two comparisons. All operands are strings, or they share one numeric type. `int` and `double` are not mixed. `"-" * 12` repeats a string. `3 * "ab"` does the same after the count is evaluated. `piece in "0123456789"` and `name not in seen` test membership. A string asks whether it contains the text. A list, set, or range asks whether it contains the element. A map asks whether it contains the key. The left value runs, then the collection, each once. `not in` is one operator. Prefix `not` still binds tighter, so `not name in seen` tests the negated name. `items + more` builds a new list. `ages + extra` builds a new map, and a key on the right replaces the same key on the left. Each side runs once, from left to right. A `readonly` collection still joins into an ordinary list or map.

**Compiler / runtime requirements.** Lower boolean words to Dart operators without changing evaluation order. A chained comparison evaluates every operand before combining the results.

**Required conformance coverage.** Precedence, short circuit, nullable operands, invalid types.

### QUDS-005 — Conditionals as statements and expressions

**Approved decision.** `if` / `else if` / `else` exist as statements, as expressions, and as collection elements. The three are distinguished by position, not by a fourth spelling. An if-expression requires `else`, and its branches are expressions whose types join. A statement may omit `else`. A collection `if` contributes elements and may omit `else`. See Normative resolutions.

**Quds syntax illustration** (may be a fragment):

```quds
if score >= 50:
  print "Pass"
else:
  print "Fail"

if text.startsWith("0"): return "0"
```

A branch that is one statement may sit on the header line. An indented suite remains available, and `else` stays on its own line.

**Compiler / runtime requirements.** AST distinguishes conditional statement and conditional expression.

**Required conformance coverage.** Nested branches, type joins, missing else in value context.

### QUDS-006 — Loops and ranges

**Approved decision.** Support `for x in iterable`, inclusive range `a..b`, exclusive range `a..<b` (`..<` is one token), `for` with `while` and `step` (the C-style loop), `while`, `repeat` / `while` (the do-while loop), `break`, `continue`, labeled breaks, and `await for`. `..` is never a cascade. A zero step is a compile-time error when the step is a constant, and a runtime error otherwise. `1..5` contains 1, 2, 3, 4, and 5. `1..<5` contains 1, 2, 3, and 4. A negative step walks downward and still honors the inclusive or exclusive end. `range(start, end)` is the call form of the inclusive range `start..end`, and `range(end)` is `0..end`.

**Quds syntax illustration** (may be a fragment):

```quds
for i in 1..5:
  print i

for piece in "ab":
  print piece

for i, item in items:
  print "{i}: {item}"
```

`for piece in text` yields each character as a string of one UTF-16 code unit. `for i, item in items` binds `i` to the position, starting at 0, and `item` to the element. Both bindings are immutable. `for i, n in 1..3` gives positions 0, 1, 2 and values 1, 2, 3. When the elements are positional pairs, `for name, score in pairs` binds the two fields instead of a position. The same two names work as a collection element: `for mark, tone in marks.zip(tones)`. `names.zip(scores)` builds those pairs and stops at the shorter collection. `for i in 0..10 step 2` walks 0, 2, 4, 6, 8, and 10. `10..0 step -2` walks downward and includes the end. `10..<0 step -2` stops before the end. The step runs once, after the start and the end. A constant step of 0 is rejected. A step that cannot move from the start toward the end yields nothing. `step` follows a range, so `for x in items step 2` is rejected. `for i in 10..0` without a step still walks downward. `repeat 3:` runs the body three times. The count is an `int`, runs once, and a negative count fails at run time. `repeat 0:` does not enter the body. `repeat:` followed by `while` is still the do-while loop. The counted `for name = ... while` form is unchanged.

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
total = [1, 2, 3].sum()
doubled = items.map(n -> n * 2)
```

`map`, `take`, `skip`, `drop`, `takeLast`, `dropLast`, `sorted`, `unique`, and `flat` return a new list. `drop` is `skip`. `where` stays a view and becomes a list with `toList`. `sum` of an empty numeric collection is zero. `min` and `max` on a collection are null when it is empty. `min(a, b)` and `max(a, b)` choose between two numbers of the same type. `find` and `findLast` are null when nothing matches. `reduce` on an empty collection fails at run time. `sorted` without a comparison accepts numbers and strings. A string index is one character: `"ab"[0]` is `"a"`. A negative index counts from the end, so `text[-1]` is the last character and `items[-1]` is the last element. The same count applies to a slice: `items[-2..]` is the last two elements, and `text[..<-1]` stops before the last character. A negative bound is `length + bound`. An inclusive end then adds one. A missing start is 0 and a missing end is the length. A map key of `-1` stays the key `-1`. `substring(start, end)` stops before `end`. `text[1..]`, `text[..<n]`, and `items[1..3]` slice a string or a list. `..` includes the end and `..<` stops before it. The receiver, the start, and the end each run once. `text.chars` is the characters as `List<String>`. `text.lines` splits on line endings, drops the endings, and keeps empty lines. `take`, `drop`, `takeLast`, and `dropLast` also work on a string and return a string. A negative count fails at run time. A count past the end keeps what remains. `title.padStart(8, "0")` and `title.padEnd(12)` widen text. The fill defaults to one space, and text that is already wider is not shortened. `names.zip(scores)` pairs positions and stops at the shorter side. `n.abs`, `n.round`, `n.floor`, and `n.ceil` are written without parentheses. On an `int`, `round`, `floor`, and `ceil` are the same number. On a `double` they return `int`. `n.clamp(lower, upper)` keeps `n`'s numeric type. `n.pad(4)` is an `int` written with zeros on the left. A minus sign stays in front of the zeros, and a number that is already wider is not shortened. `n.fixed(2)` writes the number with that many digits after the decimal. `n.plain` writes it without trailing zeros, and a scientific value stays as it is. `plain` does not limit the length. A negative digit count fails at run time.

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
label = "{age=}"
letter = """
  Hello
  {name}
  """
```

A triple-quoted string that closes on its own line uses that line's leading spaces as the margin. Those spaces are removed from every content line. A blank line stays blank. A line with less indentation than the closing quotes is an error. Only U+0020 spaces count. The newline that only introduces the closing quotes is not part of the value. A triple string on one line is unchanged.

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
else:
  print "saved"
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

**Approved decision.** `test "description":` and `group "description":` are declarations whose indented blocks are function bodies. `expect` is a function. These declarations lower to the Dart `test` package. They are not call colon-blocks, so a test body is not reclassified as a collection. Async tests are `test "description" async:`. Flutter widget tests call the Flutter test library; the language adds no widget syntax.

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
a, b = b, a
(a, b) = (b, a)
[first, ...rest] = items
name, age = person
```

`a, b = b, a` reads both values before either name changes. `name, age = person` reads one positional record. `[first, ...rest] = items` binds the head and the remaining list. A list that is too short throws at run time. A new name is immutable. A visible mutable name is assigned. A visible immutable name is `E202`. `shadow name` is the new binding that hides an outer name.

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

### Local functions, nameof, events, numeric constraints, and deconstruct

These forms are part of the implemented language.

A function written inside another function is a local function. It sees the enclosing bindings, it may call itself, and `return` leaves that function. It lowers to a Dart local function.

```quds
walk(node: Node) -> int:
  depth(current: Node, level: int) -> int:
    if current.child == null: return level
    return depth(current.child!, level + 1)
  return depth(node, 0)
```

`nameof` reads a name or a member path and yields that source text. It does not evaluate the path.

```quds
label = nameof user.name
```

`require` and `check` keep their meaning. When the message is omitted, the failure text is the condition as written, for example `age >= 0`.

```quds
require age >= 0
```

`event name: Type` declares an event of a function type. Other code subscribes with `add`. A block after `add:` is a handler of type `() -> void`. Only the declaring class may `raise` the event. Raising it elsewhere is an error.

```quds
class Button:
  event clicked: () -> void
  press():
    raise clicked

button.clicked.add:
  print "pressed"
button.press()
```

`where T is Numeric` after a function signature constrains `T` to `num`. The operators are resolved from that bound when the call site knows `T`, the same way other overloads are resolved at compile time. A call that does not determine `T`, or that supplies a type outside the bound, is rejected. A plain binding is still immutable, so a total that is updated is `var`.

```quds
sum<T>(values: List<T>) -> T where T is Numeric:
  var total = values.first
  for value in values.skip(1):
    total = total + value
  return total
```

A method `deconstruct()` with no parameters and a record result is what a parallel assignment reads when the right-hand side is not already a record.

```quds
class Point:
  x: int required
  y: int required
  deconstruct() -> (int, int) = (x, y)

x, y = Point(x: 3, y: 4)
```

### Lazy fields, extension properties, callable values, and once

`name: Type by lazy:` is a getter. The block runs on the first read, its `result` is stored, and later reads return that value. A thrown block does not store a value, so the next read tries again. A `null` result is stored. The name is not a constructor parameter, not part of `copyWith`, and not an assignment target. `var` cannot use `by lazy`. `static` uses the same form. The block sees the object's fields as they are at the first read.

```quds
class Report:
  path: String required
  text: String by lazy:
    result readFile(path)
```

An extension may declare a `property`. A getter is read without parentheses.

```quds
extend String Text:
  property shouted: String:
    get = this.toUpperCase()
```

A method named `call` makes a value callable. `value(argument)` and `Greeter()(argument)` both invoke it. The generated Dart uses the same `call` method.

```quds
class Greeter:
  call(name: String) -> String = "Hello {name}"

print Greeter()("Ada")
```

`once:` runs its block the first time that activation of the enclosing function reaches it. A loop does not reset it. The next call of the function starts again. `once = 1` is still a binding.

```quds
tick():
  once:
    print "tick"
```

## Cross-feature invariants (mandatory)

- **No implicit mutation:** immutable binding, readonly reference and deeply immutable object are distinct concepts. `readonly` is transitive *through that reference* but does not freeze all aliases.
- **No implicit shadowing:** QUDS-090 requires explicit `shadow`; assignment to an existing mutable outer binding mutates it; assignment to an existing immutable outer binding is an error.
- **No implicit multiline return:** an expression-bodied function returns its expression. A block-bodied function returns only with `return`. A `do:` block and a `by lazy` block yield only with `result`.
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
| `?` before a collection element | Null-aware element. The expression runs once and is omitted when null. |
| `?.` | Null-aware member, call, or index. |
| `??` / `??=` | If-null expression and if-null assignment. The right side runs only when the left is null. |
| `to` | Explicit conversion. Failure is an error. |
| `to?` | Safe conversion. Failure is null. The target type may be nullable: `text to? int?`. |
| `with?` | Null-aware configuration. Not `with` plus Result `?`. |
| `...?` | Null-aware spread. The operand spreads only when non-null. |
| postfix `!` | Null assertion. |
| `.` before an identifier with no written receiver | Member selection whose receiver type is the expected type (dot shorthand). The same selection as `Type.member`. |
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
13. Juxtaposition call. The argument is everything tighter than this slot, including `??`, so `print a + b` is `print(a + b)`, `expect a == b` is `expect(a == b)`, and `print a ?? b` is `print(a ?? b)`. It is left-associative: `f g h` is `(f g) h`.
14. `|>`
15. Assignment and compound assignment

If-expressions, `do:`, `match`, and `with` are primary forms, not infix operators. There is no ternary and no cascade at the Dart cascade level.

### Colon blocks

Classification uses the tokens in the block, never the expected type.

1. `map:` and `set:` always open collection literals. A call to something named `map` or `set` uses `map(...)` or `map argument`.
2. `class`, `enum`, `mixin`, `interface`, `extend`, `value class`, `sealed type`, `sealed class`, and a function declaration open declaration bodies.
3. A block whose rows are all `identifier:` entries is a named-argument block. `if`, `for`, `repeat`, spread, and any row that is not an identifier label keep the block from being a named-argument block.
4. Every other indented block after `:` in argument or element position is a collection-element block. `if` and `for` there are collection forms (QUDS-080).
5. A named-argument value that is itself a nested block is classified again from that nested block alone.
6. `test "..." :` and `group "..." :` are declarations. The indented block is a function body, not an argument block and not a collection.
7. `task group:` is a statement. Its indented block is a suite of `spawn` statements and nested groups.

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
- `var whole = 0.0, fraction = 0.0` declares both names in one line, left to right. The same form works for a bare binding, `const`, `late`, `shadow`, `state`, and `computed`. A trailing comma is an error.
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
| Null-aware collection elements | Prefix `?` on an element. A null-aware dot shorthand is `?(.member)`, because `?.` stays null-aware access |
| Dot shorthands `.member` and `.new` | Same selection, written without the type when the expected type is unique. `.new` is the unnamed constructor |
| Private named initializing formals | A `private` field is initialized by a public parameter of the same Quds name. Dart receives `this._name` and callers pass `name:` |
| Primary constructors | Fields in a class body are that constructor. The emitter uses Dart's primary-constructor header when the target language version is at least 3.13, and an explicit constructor of the same shape otherwise |
| `new` and `factory` in a class body without repeating the class name | `init` and `factory` |
| Generator `return` adds no null element | Same rule as Dart 3.10. `sync*` is `Iterable<T>`, not `Iterable<T?>`, when every `yield` is `T` |
| Multiple wildcard `_` bindings | `_` never declares a name. It may be repeated |
| Semicolons | A newline ends the statement. `;` is a lexical error |
| `{` `}` collection literals | `map:` and `set:` and `[]`. Braces are interpolation and string escapes only |
| Adjacent string literals | Concatenate, as in Dart |

Overloads, unions, intersections, `readonly`, `Optional`, and `Result` are Quds features. Each overload and each `copyWith` remains callable from Dart through the generated names and the `quds.missing` sentinel. `readonly` is a Quds checker rule plus a boundary check where a Dart API cannot express it. It does not pretend the Dart VM tracks readonly aliases. `protected` is the same kind of honest lowering.

### Design closure

Formal grammar and semantics, later in this file, specifies the productions, the disambiguation procedures, the lowering, the project layout, the diagnostic registry, the source-map encoding, and the macro sandbox. Those items follow the token table and the resolutions above. A program that can be parsed two ways is a compiler bug or a required rejection, not a new language rule.

**Agent process:** implement from the formal grammar. If a choice would change behavior this file already fixes, do not change it without an explicit language revision.

## Formal grammar and semantics

This section is the syntax and the meaning of Quds 1.2. It elaborates the token table and the normative resolutions. It does not give a token a second meaning in the same position. A partial compiler rejects a construct it does not implement with `E910`. It does not guess a meaning.

### Notation

In the grammar, `"x"` is a terminal, `[ x ]` is optional, `{ x }` is zero or more, `( x )` groups, and `|` separates alternatives. Those meta-symbols are not Quds tokens. Words written in italics are grammar names. An indented block is written `suite` and means `":"` followed by a newline, a strictly greater indent, statements, and a dedent back to an existing indent.

### Source text

Line endings are `\n`, `\r\n`, and a lone `\r`. All three start a new line. A trailing newline at the end of the file is optional and does not create an extra empty statement.

Whitespace between tokens is a space or a tab and is not significant. Indentation is only spaces. A tab in the indentation of a line is `E002`. A tab inside a line, after the first non-space, is ordinary whitespace.

Comments do not nest. `#` and `//` comment through the end of the line. `/*` comments through the next `*/`. An unclosed comment or string is `E004`. `///` and `/**` are documentation when they sit immediately above a declaration with no blank line between the comment and the declaration. Documentation is attached to that declaration and is emitted as Dart `///`.

`;` is `E102`. `{` and `}` appear only inside strings, as interpolation delimiters or as the doubled escapes `{{` and `}}`.

### Tokens

Longest match wins for the operators in the token table, including `..<`, `?.`, `??`, `??=`, `...?`, `to?`, `with?`, `is!`, and the compound assignments. A number uses Dart's numeric lexical syntax, including hex, scientific notation, digit separators, and a trailing dot that makes a double (`1.`). There is no binary literal. The next character after a number decides: a digit or `_` continues the number when Dart's lexer would continue it; an identifier character after a finished number starts a new token, which is then a syntax error unless an operator separates them. `1.toString` is the double `1.` followed by the name `toString`, the same rejection Dart makes. Write `(1).toString` or `1 .toString`.

An identifier is a letter or `_` or `$`, then letters, digits, `_`, or `$`. The single character `_` is the wildcard token, not an identifier. `__` is an identifier. `$` is allowed so a Dart name can be spelled. Reserved words are not identifiers:

`and`, `as`, `async`, `await`, `break`, `catch`, `class`, `const`, `continue`, `do`, `else`, `enum`, `false`, `for`, `if`, `in`, `is`, `late`, `match`, `not`, `null`, `or`, `return`, `super`, `switch`, `this`, `throw`, `true`, `try`, `var`, `while`, `with`, `yield`.

Every other word in this grammar is contextual. It is a keyword only when the production that uses it matches. Otherwise it is an identifier. `map` and `set` are keywords only when the next token is `:`.

Strings use `'` , `"`, `'''`, and `"""`, with an optional raw prefix `r`. Raw strings have no backslash escapes and no interpolation. Non-raw strings use Dart's backslash escapes. `$` never starts interpolation. `{` starts an interpolation and `}` ends it. A triple-quoted string that closes on its own line drops the leading spaces of that closing line from every content line, and drops the newline that only introduces the closing quotes. `{{` and `}}` are literal braces. The interpolated text is one expression. A `}` inside that expression is the end of the interpolation, so a nested string is the way to include one. `{age=}` evaluates that expression once and writes its source text, an equals sign, and the value. A trailing `=` that belongs to `==`, `!=`, `<=`, or `>=` stays part of the expression. Adjacent string literals, with only whitespace or comments between them, concatenate. Their interpolations stay in order and run left to right when the combined string is evaluated.

### Indentation and continuation

A blank line, or a line whose only tokens are comments, does not change the indent. After a header `:` the next non-ignored line must be indented strictly deeper than the header. That depth is the block's indent. Every later line of the block uses that same indent. A smaller indent ends the block and must land on an indent that is already open. Any other indent is `E001`.

A newline does not end an expression while parentheses or brackets are open, while a string is unclosed, or when the last token is a comma, an infix operator, `|>`, or `->`. The following line continues that expression. A continuation may be indented more than the current statement without opening a block. It must not be indented less than the line where the expression started.

A header colon is not a continuation. A match arm and a named-argument row may put their expression on the same line. A statement suite may be a colon and one statement on that same line; otherwise it is an indented block.

### Compilation unit

```
file          = { libraryDirective } , { topLevel }
libraryDirective
              = "use" , uri , [ "as" , identifier ]
                  , [ "show" , nameList | "hide" , nameList ] , [ "deferred" ]
              | "use" , uri , "when" , constExpression
              | "when" , constExpression , suiteOfUse
              | "export" , uri , [ "show" , nameList | "hide" , nameList ]
              | "part" , stringLiteral
              | "part" , "of" , uri
topLevel      = declaration | statement
declaration   = classDecl | interfaceDecl | enumDecl | mixinDecl
              | extensionDecl | typeDecl | sealedTypeDecl | annotationDecl
              | function | binding | testDecl | configDecl
```

`uri` is a `dart:`, `package:`, or `quds:` name, or a relative path. `nameList` is names separated by commas. `suiteOfUse` is a suite whose statements are `use` directives. `constExpression` is an expression the constant rules accept.

`dart:core` and the prelude of `quds:core` are imported without a `use` line. That prelude is `Optional`, `missing`, `present`, `Result`, `Ok`, and `Error`. A program name hides a prelude name. `hide` on an explicit `use quds:core` removes the hidden prelude names.

`use quds:name` loads the SDK library of that name from the compiler. The first library is `quds:core`. `quds:ext` adds methods on `String`, `List`, `Map`, `Set`, `int`, and `double`. An explicit `use quds:core` keeps the prelude and also brings that library's collection aliases and collection types. `show` and `hide` apply to the prelude and to those names together. A `show` name that is in neither set is `E200`. A prefix places both sets under that prefix. An extension's methods are visible when the import has no prefix and the extension's name is imported. The generated Dart imports `quds_<name>.dart`, written beside the generated file, and does not import the Quds package. A `quds:` library that does not exist is `E900`. A `#` or `///` comment placed on the lines immediately above a declaration is that declaration's documentation. A line `Example:` begins the usage example. Hover shows the signature, the prose, and the example as formatted editor text. Go to definition of an SDK declaration opens that library as a read-only document, so editing it is rejected. Go to definition on a `use`, `export`, or `part` URI opens that library: `quds:` is the read-only SDK document, and `dart:` or `package:` is the library file.

```
use quds:core
main():
  numbers: Array<int> = [1, 2]
  ages: Dict<String, int> = map:
    "Ada": 36
  stack = Stack<int>()
  stack.push(numbers.length)
  print stack.pop()
  print ages["Ada"]
```

`Array` is `List`, `Dict` is `Map`, and `HashSet` is `Set`. `Stack<T>` is a last-in list: `push`, `pop`, `top`, `size`, `empty`, and `toList`. `Queue<T>` is a first-in list: `add`, `take`, `next`, `size`, `empty`, and `toList`. `Bag<T>` counts values: `add` records one more occurrence, `count` reads it, and `total` adds the counts. `pop`, `top`, `take`, and `next` on an empty collection throw.

Two unprefixed imports that bring in the same name from different declarations are `E204`. The same declaration imported twice is one binding.

`part` and `part of` follow Dart: parts share one library privacy scope. A mismatched `part of` is `E903`.

A `when` condition is a constant boolean. The names available in it are `platform` (`"vm"`, `"web"`, or `"flutter"`) and the Dart `dart.library.*` flags. The branch that is not selected is not type-checked and is not emitted. A condition that is not a constant boolean is `E902`.

### Declarations and statements

A statement that starts with an identifier, or with a contextual keyword whose keyword production does not match, is a binding, an assignment, or an expression statement. The choice is fixed by the tokens, in this order:

1. `shadow`, `var`, `const`, `late`, or `late var`, followed by a name, is a binding.
2. A name, optional `: type`, then `=`, is a binding when no binding of that name is visible. It is an assignment when a mutable binding is visible. It is `E202` when an immutable binding is visible.
3. In statement or member position, a name followed by a parameter list and then `->`, `:`, `=`, `async`, or `sync` is a function declaration. A parameter list is a parenthesized group whose every item is a parameter. In expression position those parentheses are a call.
4. `test` or `group`, followed by a string literal and `:`, is a test declaration. `test` or `group`, followed by a string, `async`, and `:`, is an async test declaration.
5. A list, map, record, or object pattern followed by `=` is destructuring. Names separated by commas are the same assignment: `a, b = b, a` reads every right-hand value, and `name, age = person` reads one record. The right-hand side runs completely before any name is written. Each name follows the binding rule: an invisible name is declared immutable, a visible mutable name is assigned, and a visible immutable name is `E202`. `shadow` before a name declares a new immutable binding that hides an outer one. `var` before the pattern declares every new name mutable. A list pattern of names is assigned, and a list with too few elements throws at run time. A pattern that tests a value — a literal, a relation, an alternative, a type test, or an object case — is `E100`.
6. Otherwise a name followed by an argument is a call statement. A name alone is an expression statement, which is a tear-off or a value. A zero-argument call is `name()`. A bare name is never a call (`E110`).

```
binding       = [ "shadow" ] , ( "var" | "const" | "late" "var" | "late" | "state" )
                  , name , [ ":" , type ] , [ "=" , expression ]
              | [ "shadow" ] , name , [ ":" , type ] , "=" , expression
function      = name , [ typeParameters ] , parameterList
                  , [ "async" | "sync" "*" | "async" "*" ]
                  , [ "->" , type ]
                  , ( suite | "=" , expression )
testDecl      = ( "test" | "group" ) , stringLiteral , [ "async" ] , suite
parameterList = "(" , [ parameter , { "," , parameter } ] , ")"
parameter     = [ "var" ] , name , ":" , type , [ "required" ]
              | [ "var" ] , name , ":" , type , "=" , expression
              | "[" , parameter , { "," , parameter } , "]"
              | "..." , name , ":" , type
              | "this" "." , name , ":" , type , [ "required" | "=" , expression ]
              | "super" "." , name , ":" , type , [ "required" | "=" , expression ]
```

`name: Type` is a dual parameter: a Quds caller may pass it by position or by name. `name: Type required` is named-only and required. `name: Type = default` is named-only and optional. A bracket group is optional positional, and a Quds caller may also pass those by name. `...name: Type` is the last positional parameter and has no default; omitting it passes an empty list. A variadic parameter that is not last, or that has a default, is `E503`. A default expression may mention only parameters that appear earlier in the same list (`E503`).

`state name = expression` declares a reactive cell and requires the initializer. `computed name = expression` declares a reactive value that is not assignable and requires the initializer. Both are statement forms, not calls. `test` and `group` are legal at library scope and nested inside `group` only. `config` followed by a dotted name, `:`, and a type is a configuration declaration, not member access:

```
configDecl    = "config" , [ "secret" ] , dottedName , ":" , type , [ "=" , expression ]
computedDecl  = "computed" , name , [ ":" , type ] , "=" , expression
dottedName    = identifier , { "." , identifier }
```

`config name: Type` is required at startup. `config name: Type = expression` uses the expression when the environment does not supply a value. `config secret name: Type` reads the environment and has no source initializer. A literal assigned to a secret key is `E908`. Lookup order is the process environment, then the `config:` map in `quds.yaml`, then the source default. The environment name is the dotted name in upper case with `.` replaced by `_`.

Other statements:

```
statement     = binding | computedDecl | function | testDecl | configDecl
              | ifStatement | loop | matchStatement
              | "return" , [ expression ]
              | "result" , expression
              | "yield" , expression | "yield" "*" , expression
              | "throw" , expression | "rethrow"
              | "break" , [ name | expression ] | "continue" , [ name ]
              | "assert" , expression , [ "," , expression ]
              | "require" , expression , [ "," , expression ]
              | "check" , expression , [ "," , expression ]
              | "defer" , expression
              | "label" , name
              | usingStatement | withStatement | watchStatement
              | "batch" , suite
              | "task" "group" , suite
              | "spawn" , expression
              | tryStatement
              | expression
ifStatement   = "if" , condition , suite , { "else" "if" , condition , suite } , [ "else" , suite ]
condition     = expression | expression , "is" , pattern | "let" , name , "=" , expression
loop          = "for" , pattern , "in" , expression , suite , [ "else" , suite ]
              | "await" "for" , pattern , "in" , expression , suite , [ "else" , suite ]
              | "for" , forInit , "while" , expression , [ "step" , expression ] , suite , [ "else" , suite ]
              | "while" , condition , suite , [ "else" , suite ]
              | "repeat" , suite , "while" , expression , [ "else" , suite ]
              | "repeat" , expression , suite , [ "else" , suite ]
forInit       = binding | expression
tryStatement  = "try" , suite , { catchClause } , [ "else" , suite ] , [ "finally" , suite ]
              | "try" , expression , "else" , expression
catchClause   = "catch" , name , [ ":" , type ] , [ "," , name ] , suite
usingStatement= "using" , [ "async" ] , name , "=" , expression , suite
withStatement = "with" , [ name "=" ] , expression , suite
              | "with?" , [ name "=" ] , expression , suite
watchStatement= "watch" , expression , suite
matchStatement= ( "match" | "switch" ) , expression , matchArms
```

`result` outside `do:` is `E106`. `return` and `yield` outside the function or generator that can accept them are `E107` and `E804`. `break` and `continue` outside a loop, or with an unknown label, are `E105` and `E800`. `await` outside `async` is `E803`. `spawn` outside `task group` is `E107`. `rethrow` outside `catch` is `E107`.

An `if` statement may omit `else`. Its branches are suites. A suite that is a single statement may share the `if`, `else if`, or `else` line. An `if` in expression position is not this statement.

A single-line statement may end with `if` and a condition. The condition runs first. When it is false, a `let` value is null, or an `is` pattern does not match, the statement does not run. `return text if text.isNotEmpty` and `continue if name in seen` are that form. A `let` or `is` name is visible only to that statement, and it is immutable. `while let name = expr` binds the same way and stops when the value is null. `while expr is pattern` uses the pattern grammar and binds in the body only. The expression runs once per test.

The same line may end with `else` and one expression. That expression fills the statement's value: the returned value, the assigned value, or the single argument of a call. The side that is not chosen does not run. The two expressions share a type. A `let` or `is` name is not visible in the `else` expression. `return text if text.isNotEmpty else "empty"` returns one string or the other. `caption = line if let line = read() else "فارغ"` assigns one of those values.

`else:` after `for`, `while`, or `repeat` runs only when that loop finishes without `break`. `continue` does not open it. `return` and `throw` leave before it is considered. The `else` lines up with the loop, so an `else` inside the body still belongs to an `if`. `else:` after `catch` runs only when `try` finishes without entering a `catch`. It needs a `catch`. `return`, `throw`, and `rethrow` leave before it is considered. `finally` still runs afterwards.

```
for user in users:
  if user.id == id:
    print user.name
    break
else:
  print "غير موجود"
```

A loop in expression position produces a value. `break expr` supplies that value and is evaluated once. `else:` on that loop is one expression, used when the loop does not break. Without `else`, the type is nullable and the value is null. A `break` without a value inside such a loop is rejected. A `break` with a value outside such a loop is rejected. `yield` is not valid inside it.

```
found = for user in users:
  if user.id == id: break user
else:
  null
```

`where` binds immutable names before an expression, from left to right, each once. A later name sees an earlier one. The names do not escape. A comma list stays on the line. A colon introduces an indented list.

```
print total / count where total = items.sum(), count = items.length
title = "{name} ({age})" where:
  name = user.name
  age = user.age
```

`label name` applies to the next statement, which must be a loop (`E800` otherwise). The name lives in the label namespace and does not hide a variable.

`for name in expression` binds a fresh immutable name on each iteration. `for var name in expression` binds a fresh mutable name. A range `a..b` or `a..<b` is a legal iterable. `await for` requires an async function and a stream.

The C-style loop runs the initializer once, tests the condition before each iteration, and runs the step after the body. `break` leaves without running the step. `continue` runs the step, then the condition. A constant step of `0` is `E801`. A non-constant step of `0` throws at runtime.

`repeat` runs the suite, then the condition, and repeats while the condition is true. `continue` goes to that condition.

### Expressions

From tightest to loosest:

```
primary       = literal | list | "map" suite | "set" suite
              | identifier | dotShorthand | "(" , expression , ")"
              | record | "do" suite | ifExpression | matchExpression
              | loopExpression | lambda | captureLambda | withExpression
              | "await" "all" suite | "await" "isolate" suite
loopExpression= "for" , pattern , "in" , expression , suite , [ "else" , suiteOfExpression ]
              | "while" , condition , suite , [ "else" , suiteOfExpression ]
              | "repeat" , suite , "while" , expression , [ "else" , suiteOfExpression ]
whereClause   = "where" , name , "=" , expression , { "," , name , "=" , expression }
              | "where" , suiteOfBindings
dotShorthand  = "." , ( identifier | "new" ) , [ arguments ]
record        = "(" , ")"
              | "(" , expression , "," , [ recordField , { "," , recordField } ] , [ "," ] , ")"
              | "(" , name , ":" , expression , { "," , recordField } , [ "," ] , ")"
recordField   = expression | name , ":" , expression
matchExpression = ( "match" | "switch" ) , expression , matchArms
withExpression = withStatement
ifExpression  = "if" , condition , suiteOfExpression
                  , { "else" "if" , condition , suiteOfExpression }
                  , "else" , suiteOfExpression
postfix       = primary , { call | index | "." , identifier | "?." , identifier
                  | "?." , call | "?." , index | "!" | "?" }
prefix        = ( "await" | "not" | "!" | "~" | "-" | "+" ) , prefix | postfix
multiplicative= prefix , { ( "*" | "/" | "~/" | "%" ) , prefix }
additive      = multiplicative , { ( "+" | "-" ) , multiplicative }
shift         = additive , { ( "<<" | ">>" | ">>>" ) , additive }
bitAnd        = shift , { "&" , shift }
bitXor        = bitAnd , { "^" , bitAnd }
bitOr         = bitXor , { "|" , bitXor }
range         = bitOr , [ ( ".." | "..<" ) , bitOr ]
relational    = range , [ ( "<" | ">" | "<=" | ">=" ) , range
                  | ( "is" | "is!" | "as" | "to" | "to?" ) , type ]
equality      = relational , [ ( "==" | "!=" ) , relational ]
conjunction   = equality , { "and" , equality }
disjunction   = conjunction , { "or" , conjunction }
ifNull        = disjunction , { "??" , disjunction }
application   = ifNull , { ifNull }
pipeline      = application , { "|>" , application }
assignment    = pipeline , [ assignOp , assignment ]
expression    = assignment
```

`application`'s extra `ifNull` is juxtaposition: a call written beside its argument. The argument includes `??` and stops before `|>` and assignment.

`assignOp` is `=` or a compound assignment. `++` and `--` do not exist. Assignment is right-associative. Every other binary operator above is left-associative. Relational operators do not chain: `a < b < c` is `E100`. A bare name followed by `=` declares or assigns only in statement position. In expression position those tokens assign to an existing binding. No binding is `E200`. An immutable binding is `E202`.

`await all:` and `await isolate:` are the primary forms. `await for` is the loop. Any other `await` is the prefix operator.

Juxtaposition is left-associative. It is looser than `??` and tighter than `|>`. `print a + b` is `print(a + b)`. `expect a == b` is `expect(a == b)`. `print a ?? b` is `print(a ?? b)`. `f g h` is `(f g) h`. `print a |> f` is `(print a) |> f`, so a pipeline used as the argument is `print (a |> f)`.

`and`, `or`, and prefix `not` / `!` require `bool`. A nullable bool is `E308` until it is promoted or handled with `??` or `!`. Prefix `+` is numeric identity. `/` is Dart's `/`. Integer division is `~/`.

`is` in a relational expression requires a type and produces `bool`. `is` in an `if` or `while` condition accepts a pattern. `as` is a cast. `to` converts and throws `ConversionError` on failure. `to?` converts and yields null on failure. The target of either conversion may be nullable.

A pipeline whose right side is a name or a function value calls it with the left value as the first positional argument. A pipeline whose right side is a call with exactly one hole fills that hole. Any other right side is `E512`.

`suiteOfExpression` is a colon and one expression, which may be a `do` expression. It is not a statement suite (`E108`). A one-field record needs a trailing comma. Named record fields use `name: expression` and follow positional fields. `()` is the empty record. `.name` and `.new` are dot shorthands, and a following argument list is part of the same primary. The shorthand is legal only when the expected type has exactly one matching static member or constructor (`E302` when the type or the member is not unique). `new` here is contextual and is not a reserved word.

```
lambda        = identifier , "->" , ( expression | suite )
              | parameterList , [ "->" , type ] , "->" , ( expression | suite )
              | "(" , ")" , "->" , ( expression | suite )
captureLambda = "capture" , "(" , [ name , { "," , name } ] , ")" , "->" , ( expression | suite )
```

A parameter type is `name: Type`. In expression position, `(String) -> bool` is a lambda whose parameter is named `String` only when `String` is not a type name. A type name in that slot is the parameter's type, and the parameter needs a separate name: `(s: String) -> bool`. The function type `(String) -> bool` is legal in type position.

`capture` snapshots the listed bindings by value when the closure is created. The copies are immutable. Object contents are not copied. A closure without `capture` keeps Dart's live capture. A `for-in` binding is a new binding on every iteration, so a closure created in the body captures that iteration.

`do` is an expression. `result` ends it with a value and does not return from the function. `return` inside `do` returns from the function and the `do` does not complete. A path that finishes a value `do` without `result` is `E109`.

```
list          = "[" , [ element , { "," , element } ] , "]"
element       = "?" , expression
              | "..." , expression
              | "...?" , expression
              | "if" , condition , suite , [ "else" , suite ]
              | "for" , pattern , "in" , expression , suite
              | expression , [ "for" , pattern , "in" , expression , [ "if" , expression ] ]
```

The same elements appear in `set:` and, as key or value, in `map:`. A `map:` row is `expression ":" expression`. A collection `if` or `for` may omit `else`. Prefix `?` omits a null value and does not change a non-null value's type. `?.member` is not this prefix. A null-aware element that is a dot shorthand is `? ( .member )`.

A call is parentheses immediately after a postfix, or juxtaposition of one `ifNull` argument, or a colon block in argument position, or a combination of those. Parentheses that belong to a call are arguments, never a record. A record argument is wrapped again: `f((1, 2))` and `f((name: 1))`. `f(1, 2)` is two arguments. `f(name: 1)` is one named argument.

```
arguments     = "(" , [ argument , { "," , argument } ] , ")" , [ argumentBlock ]
              | expression , [ argumentBlock ]
              | argumentBlock
argument      = expression | name ":" , expression | "..." , expression | "...?" , expression
argumentBlock = ":" , newline , INDENT , { row } , DEDENT
```

An argument block is classified from its rows, never from the expected type:

1. Every row is `identifier ":" expression` (the expression may be a nested block): named arguments. The block must contain one row. A call with no arguments is `name()`.
2. Every row is a collection element: a collection-element block.
3. Any other row is `E100`.

A named-argument block is not a collection. A collection whose only elements would look like labels is written with `[]`, `map:`, or `set:`. Inside `map:`, identifier keys are values, not labels, because `map:` is production 1 of the colon-block rules and never reaches this classifier.

A hole is an argument whose expression is exactly `_`. If any argument is a hole, the call is not evaluated. It produces a function. The function's parameters are positional, one per hole, in source order, with the parameter types of those slots. When that function is called, the callee and the non-hole arguments are evaluated once, in normal call order, with the holes filled by the invocation arguments.

`with expression` evaluates the receiver once and yields it after the block. `with?` yields null and skips the block when the receiver is null; inside the block the receiver is non-null. A row `name: expression` writes that setter. An unqualified name inside the block resolves to a member of the receiver when exactly one of the member and the outer scope defines it. When both define it, the program is `E204` and must write the receiver binding or an outer prefix. The receiver binding is `it` when `it` is not already in scope. When `it` is in scope, the form `with name = expression` is the way to name the receiver. The implicit name is not created in that case, so no outer binding is shadowed. A readonly receiver rejects setters (`E307`).

`await all:` starts every child expression immediately. The value is a record of the results in source order. If a child throws, the others are cancelled cooperatively and the first error in source order propagates after cancellation is requested. `await isolate:` runs the expression on a new isolate. The expression is a top-level or static call. Its arguments are sendable. Capturing a local binding is `E805`.

`task group` waits for its `spawn` children. A child failure cancels the remaining children and throws `TaskFailed` with the child errors in source order. `spawn` schedules work on the current isolate. It is not `await isolate`.

`watch expression` subscribes for the rest of the enclosing scope and disposes the subscription on every exit. `batch` holds reactive notifications until the suite exits, including an exceptional exit, then flushes once. `state` and `computed` track reads. A cycle discovered while a computed value is already evaluating throws `CycleError`. A cycle visible from the static dependency graph is `W007`.

### Types, patterns, and matches

```
type          = union
union         = intersection , { "|" , intersection }
intersection  = postfixType , { "&" , postfixType }
postfixType   = primaryType , [ "?" ]
primaryType   = "readonly" , primaryType
              | name , [ "<" , type , { "," , type } , ">" ]
              | functionType
              | "(" , type , ")"
functionType  = [ typeParameters ] , "(" , [ functionParameter , { "," , functionParameter } ] , ")" , "->" , type
functionParameter = parameter | type
typeParameters = "<" , typeParameter , { "," , typeParameter } , ">"
typeParameter = [ "in" | "out" ] , name , [ ":" , type ]
```

`|` and `&` are left-associative. `&` binds tighter than `|`. `?` binds tighter than both, so `A | B?` is `A | (B?)`. A nullable union is `(A | B)?`. `readonly` applies to the type it prefixes, including a parenthesized union.

`T | Null` is exactly `T?`. `int | double` is `num`. Any other union lowers to a sealed hierarchy named by mangling the alternatives, in the library's generated part. After `is` or a matching pattern narrows the union, the checker sees the alternative and the emitter unwraps the case. A Dart caller of a public union sees that sealed hierarchy. The name is stable: `QudsUnion_` plus the mangled alternatives.

`A & B` is one object that is a subtype of both. It is not a merged wrapper. A parameter of that type lowers to a generic `T extends A` plus a `is! B` check so a Dart caller is rejected at runtime. A Quds caller is rejected at compile time (`E306` when no type can satisfy both).

```
pattern       = literal | "null" | "_" | identifier
              | "(" , pattern , ")"
              | listPattern | mapPattern | recordPattern | objectPattern
              | pattern "|" , pattern | pattern "and" , pattern
              | relationalOp , expression | pattern "as" , type
              | pattern "?" | pattern "!"
              | name , ":" , pattern
objectPattern = name , "(" , [ patternField , { "," , patternField } ] , ")"
```

List, map, and record patterns use the same brackets and parentheses as the literals, with `...` and a rest pattern. A parenthesized pattern of one element without a trailing comma is a grouped pattern. A one-field record pattern has a trailing comma. `_` binds nothing and may be repeated. A name in a `for` pattern, an `if` or `while` pattern, or a match arm declares an immutable binding in that branch. `shadow` is required there when the name is already visible (`E203`). A name in a destructuring assignment follows the statement rule instead: it assigns a visible mutable binding and does not implicitly shadow it.

`match` and `switch` accept the same grammar. In statement position each arm is a suite, and a missing case is `W001`. In expression position each arm is an expression, a missing case is `E314`, and the arm types join. An unreachable arm is `E313`. Guards use `when expression` before the arm colon. The sealed cases of a `sealed type` and the same-library subtypes of a `sealed class` are the finite set. `if value is pattern` and `while value is pattern` use the same patterns and bind in the successful branch only. The scrutinee runs once.

A `sealed type` case is a value class. A case with no fields is a constant. `match` on that type is exhaustive only when every case is covered or a wildcard is present.

### Names, scopes, and overloads

A scope is a library, a type body, a function, a suite, a `do`, a catch, a `with`, or a pattern arm. Resolution order is: the innermost scope, then enclosing scopes, then the current library, then an explicit import prefix, then unprefixed imports. A member access `a.b` looks only at the type of `a` and at extensions on that type. An extension is applicable when the receiver type matches its `on` type. If two extensions are applicable and neither receiver type is more specific, the call is `E205`.

A new binding is visible after its initializer. The initializer still sees the outer name. `shadow name = expression` and `shadow var name = expression` are the only ways to declare a local when that name is already visible.

Imports, members, and locals occupy one namespace per kind: values, types, and labels are separate, as in Dart. A value and a type may share a spelling. A label and a value may share a spelling.

Overload resolution considers every visible function of that name. A candidate is applicable when the supplied arguments match its parameter types, every required parameter is supplied, extra arguments are absent, and a variadic parameter absorbs only the remaining positional arguments of its element type. Among applicable candidates, a signature that does not use a variadic parameter beats one that does. Otherwise a candidate whose every parameter type is a subtype of the other's, with at least one strict subtype, wins. If more than one candidate remains, the program is `E310`. There is no runtime overload dispatch.

A tear-off is a bare name in expression position. One visible signature selects that function. An overload set uses the expected function type. If that does not select one signature, the program is `E311`. An explicit type-argument list `name<Type>` instantiates that function before overload resolution.

The emitted Dart name is the Quds name when it is the only signature. Otherwise it is the name, `$`, and a suffix built from the parameters in declaration order, joined by `_`: a dual or positional parameter contributes its mangled type; a named parameter contributes its name, `_`, and the mangled type; an optional positional contributes `opt_` and the mangled type; a variadic contributes `rest_` and the mangled element type. Mangling writes a named type as its name, type arguments as `_of_` joined by `_and_`, `T?` as the inner mangle plus `_nullable`, a union with `_or_`, an intersection with `_and_`, and a function type as `fn_`, the parameter mangles, `_to_`, and the return mangle. A suffix collision appends `_2`, `_3`, in source order. `parse(x: String)` and `parse(x: int)` become `parse$String` and `parse$int`.

### Types of declarations

A class body is a suite of fields, functions, properties, operators, and constructors.

```
classDecl     = { classModifier } , "class" , name , [ typeParameters ]
                  , [ "extends" , type ] , [ "with" , type , { "," , type } ]
                  , [ "implements" , type , { "," , type } ] , suite
classModifier = "abstract" | "base" | "interface" | "final" | "sealed" | "mixin" | "singleton" | "value"
interfaceDecl = "interface" , name , [ typeParameters ] , [ "extends" , type , { "," , type } ] , suite
enumDecl      = "enum" , name , [ typeParameters ] , suite
mixinDecl     = "mixin" , name , [ typeParameters ] , [ "on" , type , { "," , type } ] , suite
extensionDecl = "extend" , type , [ name ] , [ typeParameters ] , suite
typeDecl      = "type" , name , [ typeParameters ] , "=" , type
              | "type" , name , [ typeParameters ] , "wraps" , type , [ suite ]
sealedTypeDecl= "sealed" , "type" , name , [ typeParameters ] , suite
annotationDecl= "annotation" , name , [ parameterList ] , suite
matchArms     = ":" , INDENT , { pattern , [ "when" , expression ] , ":" , arm } , DEDENT
```

`arm` is one expression when the match is an expression, and a suite or one expression statement when the match is a statement. `interface` members are abstract. `sealed type` cases are value-class constructors. `annotation` defines a const metadata class. `type Name = Type` is the transparent alias. `type Name wraps Type` is the distinct wrapped type. In a function type, a bare type is a positional parameter and `name: Type` uses the parameter grammar, so `(String) -> bool` is the type of a function from `String` to `bool`. On `extend`, a type-argument name that is not already a type declares a type parameter of the extension. `extend List<T>:` declares `T`. `extend List<String>:` extends that instantiation only.

Where a form is listed in both `declaration` and `statement`, it is one production. A line that contains `class` before the type name is a class, including `mixin class`, `value class`, and `singleton class`. `mixin` followed by a name is a mixin. `interface` followed by a name is an interface. `interface` followed by `class` is a class modifier. `sealed class` is a class. `sealed type` is the algebraic declaration.

The legal combinations of `abstract`, `base`, `interface`, `final`, `sealed`, and `mixin` are exactly the combinations Dart accepts. Any other combination is `E720`. `value` may accompany a legal combination and adds value-class equality. `singleton` may accompany a legal combination and adds the instance rule below. `with` in this header is mixin application only.

A field is `name: Type`, with `required`, `= expression`, or both, and with the binding modifiers `var`, `const`, `late`, `private`, `protected`, and `readonly`. `name: Type` in an `interface` is an abstract getter. A writable interface member uses `property`. An implementing class supplies a field, a getter, or a property of a compatible type (`E700`).

When a class declares no `init`, the fields synthesize one constructor. `required` fields are required dual parameters. Fields with defaults are optional named parameters. A `private` field lowers to a Dart `_` field and a public initializing parameter of the Quds name, which is Dart's private named parameter. When the target Dart language version is at least 3.13 and the synthesized constructor fits a primary constructor, the emitter uses that header. Otherwise it emits an explicit constructor. The behavior is the same.

`init`, `init name`, `factory init`, `factory init name`, `const init`, and `init = other` are the generative, named, factory, const, and redirecting constructors. The class name is not repeated. `this.field` and `super.field` are initializing formals. A concrete class with an abstract method is `E700` unless the class is `abstract` or `sealed` or an interface. A final field that is not initialized on every constructor path is `E704`.

`singleton class` has a private constructor and a static `instance` member, created on first use, once per isolate. A cycle in that initialization is `E707`.

`enum` uses the same body. Values are the constant cases. Fields and a synthesized or explicit constructor are allowed. Enumerations are exhaustive in `match`.

`mixin name [on type] :` and `mixin class` follow Dart's mixin rules, including `on`. An application that fails `on` is `E702`.

```
property      = [ "private" | "protected" ] , "property" , name , ":" , type , suite
operatorDecl  = "operator" , operatorToken , parameterList , [ "->" , type ]
                  , ( suite | "=" , expression )
```

A property suite contains `get = expression` or `get suite`, and optionally `set ( value ) suite`. Missing `set` is read-only. Missing `get` is write-only. Operators that Dart fixes to a result type use that type. Other operators default to the enclosing type when `->` is omitted. `==` returns `bool` and is paired with `hashCode` on a value class.

`value class` fields are immutable. `var` on one of those fields is `E706`. Equality and `hashCode` use the fields. Nested value classes use their own equality. `List`, `Map`, and `Set` fields use deep collection equality. A mutable collection field is `W004` because mutation changes later equality results. Assignment does not copy that collection.

`copyWith` is generated. Each parameter defaults to `quds.missing`. An omitted argument, and an explicit `missing`, keep the current field. An explicit null stores null when the field is nullable.

`extend type :` is a Dart extension. `extend type name :` is an extension with a name. Generic and bounded extensions are allowed. `type Name = Type` is a transparent alias. `type Name wraps Type :` is a distinct extension type. Its constructor rejects a value that fails a `require` in the body, and a constant that fails is `E401`. The representation is named `value` inside that body.

`annotation Name :` defines a const class used as metadata. `@Name` and `@Name(...)` attach const metadata. The arguments are constant expressions.

`private` is library-private and lowers to a Dart `_` name. `protected` is visible to the declaring library and to subtypes; the Quds checker enforces it, and the emitter writes `@protected` when `package:meta` is a dependency, otherwise a documentation comment. The Dart VM does not enforce `protected`. A Quds name that itself starts with `_` is already the Dart private spelling.

`readonly` on a reference rejects assignment, compound assignment, and any call that is not a read. Reads are getters, `[]` when it does not write, `==`, `hashCode`, `toString`, and a method declared `readonly`. For `List`, `Map`, and `Set`, methods that add, remove, reorder, or replace elements are writes, and methods that only return a value or a new collection are reads. A `readonly` method may itself perform only reads on `this` (`E307`). Another alias of the same object is not affected.

`in` and `out` are accepted only when every use of the type parameter is in the matching variance position and the emitted Dart type is sound. A violation is `E304`. Dart generics without `in` or `out` keep Dart's generic rules.

A function type in type position uses the parameter grammar. A lambda in expression position uses the lambda grammar. The two arrows are the same token in different positions.

### Evaluation

Every expression runs once, left to right, except the short-circuit operators `and`, `or`, `??`, `?.`, `...?`, `with?`, a pipeline's right side before the left value exists, and a partial application, which runs nothing until the resulting function is called. Each invocation of that function then follows the call rule once.

Call order is the callee, then the supplied arguments in the order written, then the omitted defaults in declaration order. Compound assignment reads the target once, evaluates the right side, and writes once. A multi-assignment evaluates the whole right side, then writes the left side from left to right. A pipeline evaluates the left side once.

`defer` statements in a scope run at scope exit, last in first out, after the body and before that scope's `using` disposal finishes. `using` disposal is the outer `finally` of its scope. An explicit `finally` runs when its `try` exits, inside this order. A `defer` or disposal that throws replaces a pending success and follows Dart's `finally` rule: the new error propagates, and the previous error is chained when the target can chain it. `using async` and an async `defer` require an async function.

`assert` is removed from a release build, the same builds that remove Dart's `assert`. `require` throws `ArgumentError` and remains in release. `check` throws `StateError` and remains in release. All three evaluate a message expression only when the condition is false.

`try expression else expression` evaluates the first expression. If it throws, the second expression runs and its value is the result. It does not catch `Result` errors. Postfix `?` does that. `?` requires `Result<T, E>`, has type `T`, and returns `Error` from the nearest function whose result is `Result<R, F>` or `Future<Result<R, F>>` with `E` a subtype of `F`. There is no such function: `E600`. The error types are incompatible: `E601`. `?` returns from the function, including through a `do`.

Constant evaluation follows Dart's constant rules for the shared operators, literals, and const constructors. Implicit const applies only inside a constant context. A top-level or static const initializer may mention consts that are already initialized: earlier in the same library, or imported. A later const in the same library is `E402`. A function body may mention any const in the library. A cycle is `E401`. String interpolation is not a constant expression.

### Lowering

Generated Dart is a library a Dart caller can import. Quds-only values use these public spellings:

| Quds | Dart |
| --- | --- |
| Dual parameter | `{required T name}` and a Quds call rewritten to the named argument |
| Optional named, optional positional, variadic | Dart optional named, optional positional, and a `List<T>` parameter |
| Overload | The mangled name above |
| `missing` | `quds.missing`, one sentinel identity |
| `Optional<T>` | `Optional<T>` with present and missing tags. Present null is not missing |
| Union that is not a Dart type | The stable sealed hierarchy |
| `readonly` | The same Dart type, plus checker errors and a boundary check where a Dart signature cannot say `readonly` |
| `private` / `protected` | `_name` / `@protected` or a documentation comment |
| Range | `quds.Range`, iterated by `for` |
| `with` / `with?` | A temporary, then the assignments. `with?` is a null check around that temporary |
| Partial application | A closure |
| `do` | A local function invoked immediately, or a block in the IR that preserves `return` |
| `test` / `group` | `package:test` declarations |
| `state` / `computed` / `watch` | `quds:reactive` cells |

`copyWith` defaults every parameter to `quds.missing`. A Dart caller omits the argument, passes null, or passes `missing`.

### Project layout

```
pubspec.yaml
quds.yaml
lib/<package>.quds
lib/src/<library>.quds
bin/<tool>.quds
test/<name>_test.quds
.dart_tool/quds/cache/
```

`quds.yaml` holds `language: "1.2"` and any `config:` map. The language version is this field. A comment does not select a version. `pubspec.yaml` holds the package name and the Dart SDK constraint. Published packages commit the generated `.dart` next to each `.quds` file so a Dart consumer needs no Quds compiler. `.dart_tool/quds/cache/` is the incremental cache and is not published.

`use package:name` is `lib/name.quds`. `use package:name/src/util` is `lib/src/util.quds`. `use package:flutter.material` is `package:flutter/material.dart`: the first segment is the package, and each later dot is a directory. A `.quds` file at that path is the Quds library. Otherwise the `.dart` file is read, including a Flutter library. `use dart:math` is that Dart library. Its public names are read from the library sources in the Dart SDK, including `part` files, and a change to those files is visible on the next analysis. `use util` is `util.quds` beside the current file. `use src.sum` is `src/sum.quds` relative to that file, and each `^` climbs one directory: `use ^^^.sum` is `../../../sum.quds`. The generated import uses the `.dart` path. `use generated:user_models` is the generated library of that name in the same package.

One library is one `.quds` file plus its `part` files. Library privacy is that set. The emitter writes a generated-file header. `quds build` refuses to overwrite a `.dart` file that lacks the header.

### Diagnostics

The MVP-0 compiler reports `Q001`, `Q100`, and `Q200`. Those categories belong to that compiler. Design 1.2 uses the registry below and does not also use the `Q` categories.

A diagnostic is `path:line:column: severity[CODE]: message`, using the original `.quds` coordinate. The object also carries related spans and, when one edit is determined by this specification, a replacement. Wording may change. A published code is never renumbered or reused. A new code takes the next free number in its class.

`E` is an error, `W` a warning, `L` a lint. `W001` through `W007` are enabled by default. Lints are enabled only by `quds analyze`.

| Code | Condition |
| --- | --- |
| `E001` | Indent is inconsistent |
| `E002` | A tab is used to indent |
| `E003` | A character is not part of a token |
| `E004` | A comment or string is not closed |
| `E005` | A string escape is invalid |
| `E006` | A number is invalid |
| `E100` | The tokens do not match a production, including a colon block that is neither names nor elements |
| `E102` | A semicolon appears |
| `E105` | `break` or `continue` is outside a loop |
| `E106` | `result` is outside `do` |
| `E107` | `return`, `rethrow`, or `spawn` is outside the form that accepts it |
| `E108` | An if-expression has no `else` or has a statement branch |
| `E109` | A value `do` ends without `result` |
| `E110` | A zero-argument call has no parentheses |
| `E200` | A name is not defined |
| `E201` | A name is already defined in this scope |
| `E202` | An immutable binding is assigned |
| `E203` | A new local needs `shadow` |
| `E204` | An import or a `with` name is ambiguous |
| `E205` | Two extensions apply and neither is more specific |
| `E206` | A private name is used outside its library |
| `E207` | A protected name is used outside a subtype or its library |
| `E300` | A type does not match |
| `E302` | A type cannot be inferred, including an empty literal with no expected type |
| `E304` | A variance annotation is not sound |
| `E306` | An intersection cannot be satisfied |
| `E307` | A readonly reference is mutated |
| `E308` | A nullable value is used where a non-null value is required |
| `E310` | An overload is ambiguous |
| `E311` | A tear-off does not select one signature |
| `E312` | A value-returning path has no `return` |
| `E313` | A match arm is unreachable |
| `E314` | A match expression is not exhaustive |
| `E401` | A constant cannot be evaluated |
| `E402` | A const initializer uses a const declared later in the library |
| `E500` | A required argument is missing or an argument is unexpected or duplicated |
| `E503` | A default reads a later parameter, or a variadic parameter is illegal |
| `E512` | A pipeline is not a bare callee or a one-hole call |
| `E600` | Postfix `?` has no compatible `Result` function |
| `E601` | A `Result` error type does not fit the function |
| `E700` | A member is not implemented, or a concrete class has an abstract member |
| `E702` | A mixin `on` constraint fails |
| `E703` | A sealed type is extended outside its library |
| `E704` | A final field is not initialized |
| `E706` | A value class field is mutable |
| `E707` | Singleton initialization cycles |
| `E720` | Class modifiers are not a combination Dart accepts |
| `E800` | A label is unknown or is not on a loop |
| `E801` | A constant loop step is zero |
| `E803` | `await` or async disposal is outside `async` |
| `E804` | `yield` is outside a generator |
| `E805` | An isolate argument is not sendable, or the isolate call captures a local |
| `E900` | A library is not found |
| `E901` | The declared language version is not supported |
| `E902` | A `when` condition is not a constant boolean |
| `E903` | `part of` does not match the library |
| `E904` | Macro expansion cycles |
| `E905` | A macro uses a forbidden capability |
| `E906` | Macro expansion fails |
| `E908` | A secret configuration has a source literal |
| `E910` | This compiler does not implement the construct |
| `W001` | A match statement is not exhaustive |
| `W002` | A binding or import is unused |
| `W003` | Code is unreachable |
| `W004` | A value-class field has a mutable collection type |
| `W007` | A computed dependency cycle is visible statically |

`E203` suggests inserting `shadow`. `E110` suggests `()`. No other fix is required by this version.

### Source maps

Each generated `.dart` file has a sibling `.quds.map` and a final line `//# sourceMappingURL=<file>.quds.map`. The map is Source Map Revision 3 JSON: `version` is 3, `file` is the generated file name, `sources` are paths of `.quds` files relative to the package root, `names` lists original identifiers, and `mappings` is the standard base64 VLQ. Generated helpers that have no source span are omitted from `mappings`. A synthetic macro node maps to the annotation that created it and records the macro declaration as a related source in `x_quds_macro`.

`quds.mapStack` rewrites a Dart stack string. Each frame that hits the map is reported with the `.quds` path, line, and column. A frame that does not hit stays as a Dart frame. Async and isolate stacks are mapped one frame at a time. A web stack is mapped by composing this map under the Dart-to-JavaScript map; the composition is ordinary source-map composition, not a second encoding.

### Macros

A macro is a const class marked `@macro` that implements `Macro`. It has one or both of `declare(library, builder)` and `define(type, builder)`. `declare` may add top-level declarations. `define` may add fields, methods, getters, and constructors to the annotated type. There is no phase that replaces, deletes, or rewrites an existing node. The builder accepts structured descriptors only. Emitting source text is `E905`.

Macro code may use `quds:macro` and the const subset of `dart:core`. It cannot use `dart:io`, `dart:isolate`, the clock, randomness, or the network. Those uses are `E905`. Expansion is a pure function of the language version, the macro's transitive source, and the typed AST of the annotated declaration. The cache key is the SHA-256 of those bytes. One annotation may add at most 1000 declarations. Expansion that re-enters the same macro on a node it created stops at depth 8 (`E904` on a cycle, `E906` past the depth). A macro exception is `E906` and points at the annotation. Generated nodes are synthetic and are not formatted as hand-written source.

Introspection exposes names, type parameters, supertypes, fields, signatures, and annotations. Existing method bodies are readable as typed AST and cannot be edited.

### Tooling and versioning

`quds create`, `add`, `remove`, `get`, `run`, `build`, `test`, `analyze`, `format`, `doc`, and `migrate` are the tools. Exit `0` is success, `1` is a source diagnostic, `2` is bad usage, and `3` is a tool failure. `quds migrate` edits source from one declared language version to a newer one and does not change a project whose `quds.yaml` still names the old version.

The formatter uses two-space indents and a width of 80. It preserves comments, documentation, and string contents. Formatting is idempotent and does not change which production a program uses. A newline ends the file. Trailing whitespace is removed.

The LSP and the debugger use these diagnostics and these source maps. A breakpoint binds to a `.quds` span. Hot reload follows the target Flutter tool and does not add a language rule.

### Parses that this grammar fixes

| Program | Parse |
| --- | --- |
| `Column:` then `spacing: 12` and `children:` then `Text "Hello"` | Named arguments. The inner block is a collection because `Text "Hello"` is not a label |
| `settings = map:` then `"mode": "dark"` | Map literal. `"mode"` is a key expression |
| `map items` | A call of `map`, one positional argument |
| `(a)` and `(a,)` and `(a, b)` | Grouping, one-field record, two-field record |
| `name = 1` when `var name` is visible | Assignment. When nothing is visible, an immutable binding. When `name` is immutable, `E202` |
| `shadow name = 1` | A new immutable local |
| `process(item: Widget):` | A function declaration, because the parentheses are parameters and `:` follows |
| `process:` then `item: Widget` | A call with one named argument |
| `text to? int?` | Safe conversion to a nullable int |
| `value?` and `List<int>?` and `[?name]` | Result propagation, nullable type, null-aware element |
| `class Dog extends Animal with Walker:` | Mixin application |
| `with button:` then `enabled: true` | Configuration. The receiver runs once |
| `for i in 1..5:` and `for i in 1..<5:` | Inclusive range and exclusive range |
| `test "adds":` then `expect ...` | A test declaration. The body is not a collection |
| `multiply(2, _)` | A function of the remaining parameter. Nothing runs yet |
| `capture(count) -> count` | A snapshot lambda, not a call of a function named `capture` |
| `.running` where the expected type is one enum | That enum's value. `.new` is the unnamed constructor |
| `Point:` then `private x: int required` | A private field initialized by the public argument `x:` |

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