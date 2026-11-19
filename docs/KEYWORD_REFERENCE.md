# Quds keyword reference

English reference for editor hover and completion documentation.

This guide follows [the Quds 1.2 specification](QUDS_LANGUAGE_SPECIFICATION.md)
and its approved augmentation/conversion amendments. It does not redefine syntax
or promise that every combination of features is implemented. Examples are syntax
fragments: referenced types, functions, resources and imports may need to be
provided by the surrounding program. SDK functions such as `print` and `expect`
are not reserved language words.

Each entry states the purpose, relevant constraints, and a Quds example. Contextual
words retain their ordinary identifier meaning outside the matching production.
Public declarations do not need a `public` keyword; `private`, `protected`, and
underscore names follow the specification. `partial` and `shared` are not added.

## Editor behavior and maintenance

Hover on a recognized keyword shows the same English Markdown as its keyword or
snippet completion entry. Strings, comments and member names are excluded.
Contextual words require the matching syntax; ambiguous incomplete identifiers
keep their normal symbol behavior. Documentation lookup does not compile the file
or access a network service. Existing symbol/SDK hover remains available.

The sections below are the source of truth. Run
`python3 tool/sync_keyword_docs.py` after editing them; use `--check` in checks.
The generated Dart catalog is bundled with the language server. Reload the VS Code
extension/window after installing the updated extension. In the completion popup,
select a keyword and open its details pane to read the explanation and example.

## `var`

Declares a reassignable binding. A binding without `var` is not reassignable; its object may still be mutable.

```quds
var total = 0
total += 1
```

## `const`

Declares a compile-time constant, or marks a constant constructor. Initializers follow the constant-expression rules.

```quds
const limit = 10
```

## `shadow`

Intentionally introduces a new binding that hides an outer binding. It does not assign to the outer variable.

```quds
count = 1
if true:
  shadow count = 2
  print count
```

## `late`

Defers initialization. Reading before initialization fails; combine with `var` for reassignment.

```quds
late name: String
name = "Quds"
```

## `if`

Selects a branch. Also supports collection elements, expression branches, and trailing statement conditions. Expression forms require an alternative.

```quds
if score > 50:
  print "Passed"
else:
  print "Retry"
```

## `else`

Supplies an alternative branch. After a loop it runs only on completion without `break`; after `try`/`catch` it runs only when no catch was entered.

```quds
if ready:
  start()
else:
  wait()
```

## `for`

Iterates an iterable with fresh bindings per iteration. Also supports initializer/while/step loops and collection comprehensions.

```quds
for number in [1, 2, 3]:
  print number
```

## `in`

Tests membership or separates a loop pattern from its iterable. In type parameters it declares input variance, checked for soundness.

```quds
print 2 in [1, 2, 3]
```

## `while`

Repeats while a condition succeeds. Supports `let` and pattern conditions, and the condition of a C-style `for`.

```quds
var n = 0
while n < 3:
  n += 1
```

## `repeat`

Repeats a block a fixed number of times, or runs it before testing a trailing `while` condition.

```quds
repeat 3:
  print "Again"
```

## `step`

Specifies the update in an initializer/while/step loop. The step follows the body and runs after `continue`, but not after `break`.

```quds
for var i = 0 while i < 3 step i += 1:
  print i
```

## `break`

Leaves a loop, optionally naming a label. In a loop expression, `break value` supplies its result. Suppresses the loop alternative.

```quds
for n in [1, 2, 3]:
  break if n == 2
```

## `continue`

Skips to the next iteration, optionally naming a loop label. Does not suppress the loop alternative.

```quds
for n in [1, 2, 3]:
  continue if n == 2
  print n
```

## `label`

Names the immediately following loop for `break` and `continue`. Labels have their own namespace.

```quds
label outer
for row in rows:
  for cell in row:
    break outer if cell == 0
```

## `return`

Exits the enclosing function with an optional value. Multiline functions use explicit `return`; expression bodies return their expression.

```quds
sum(a: int, b: int) -> int:
  return a + b
```

## `do`

Creates a block expression. `result` supplies its value; `return` still exits the enclosing function.

```quds
answer = do:
  n = 20
  result n + 22
```

## `result`

Ends the nearest `do` expression with a value. It is not a function return and is invalid outside `do`.

```quds
answer = do:
  result 42
```

## `and`

Short-circuit boolean conjunction. Both operands must be non-null booleans. Also combines patterns.

```quds
print ready and enabled
```

## `or`

Short-circuit boolean disjunction. The right operand runs only when the left is false.

```quds
print cached or available
```

## `not`

Negates a boolean; `not in` tests non-membership. Nullable booleans require explicit handling.

```quds
print not ready
print 4 not in [1, 2, 3]
```

## `true`

The boolean value true.

```quds
enabled = true
```

## `false`

The boolean value false.

```quds
enabled = false
```

## `null`

The absent value of a nullable type. It is distinct from the SDK sentinel `missing`, which represents an omitted argument.

```quds
name: String? = null
```

## `is`

Tests a runtime type. In an if/while condition it can match a pattern and bind names in the successful branch. `is!` negates a type test.

```quds
if value is String:
  print value.length
```

## `as`

Checks/casts a value to a type without invoking a conversion. Also names an import prefix and annotates patterns.

```quds
use quds:math as math
print math.sqrt(9.0)
```

## `to`

Converts a value to a target type. Failure throws `ConversionError`; `to?` returns null on conversion failure. Custom conversion selection is static and one hop.

```quds
number = "42" to int
```

## `to?`

Safely converts a value, returning null on conversion failure. Custom conversions catch `ConversionError`, not arbitrary exceptions. A nullable target is allowed.

```quds
number = "invalid" to? int
```

## `class`

Declares a class with an indented member body. Fields can synthesize a constructor; methods, properties and conversion declarations belong in the body.

```quds
class Point:
  x: int required
  y: int required
```

## `abstract`

Marks a class that cannot be instantiated directly and may leave members unimplemented. Class-modifier combinations must be legal.

```quds
abstract class Shape:
  title: String required
```

## `base`

Applies Dart-compatible base-class inheritance restrictions. Allowed modifier combinations are checked by the compiler.

```quds
base class Entity:
  id: int required
```

## `interface`

Declares an interface, or restricts a class to implementation by outside libraries when used as `interface class`.

```quds
interface Named:
  name: String
```

## `final`

Restricts class subtyping outside its library. This is a class modifier; ordinary immutable bindings use `name = value`.

```quds
final class Token:
  text: String required
```

## `sealed`

Closes a hierarchy for exhaustive matching. Used with `class` or `type`; cases of a sealed type are value cases.

```quds
sealed type Answer:
  Yes
  No
```

## `value`

Adds field-based equality, hashCode and copyWith to a class. Fields cannot be `var`; mutable collection contents can still affect equality.

```quds
value class Point:
  x: int required
  y: int required
```

## `singleton`

Provides a lazily created static `instance`, once per isolate, with a private constructor. Initialization cycles fail.

```quds
singleton class Settings:
  name: String = "Quds"
```

## `extends`

Declares a superclass or an interface parent. Generic arguments are checked.

```quds
class Child extends Parent:
  count: int = 0
```

## `implements`

Declares interface obligations that the class must satisfy with compatible members.

```quds
class User implements Named:
  name: String required
```

## `mixin`

Declares reusable mixin behavior, optionally constrained by `on`. `mixin class` permits class and mixin use.

```quds
mixin Printable:
  show():
    print this
```

## `on`

Constrains the receiver required by a mixin. Application must satisfy that type.

```quds
mixin Identified on Entity:
  showId():
    print id
```

## `enum`

Declares an enumeration with constant cases. Enumerations support fields, constructors and exhaustive matching.

```quds
enum Color:
  red
  green
  blue
```

## `type`

Declares a transparent alias, a distinct wrapped type using `wraps`, or a case hierarchy using `sealed type`.

```quds
type UserId = int
```

## `wraps`

Defines the representation of a distinct extension type. The body accesses its representation as `value` and may declare requirements.

```quds
type Positive wraps int:
  require value > 0
```

## `extend`

Adds extension behavior to a receiver type. An optional extension name controls import visibility. It does not add instance storage.

```quds
extend int:
  doubled() -> int = this * 2
```

## `augment`

Adds declarations to an existing type without inheritance. Local same-library Quds types can merge supported members; foreign/Dart types allow supported behavior and conversions, not new instance storage. There is no separate `partial` spelling.

```quds
use quds:math
augment int:
  explicit cast(value: int) -> Fraction:
    return Fraction(value, 1)
```

## `implicit`

Marks a conversion eligible for automatic expected-type adaptation. Declare it inside a class or augment, with one typed source parameter and a target type. Ambiguous conversions are errors.

```quds
class Box:
  value: int required
  implicit cast(source: int) -> Box:
    return Box(source)
```

## `explicit`

Marks a conversion that requires `to` or `to?`, rather than automatic assignment adaptation. The conversion body has a source parameter and no instance `this`.

```quds
class Box:
  value: int required
  explicit cast(source: Box) -> int:
    return source.value
```

## `cast`

Introduces a custom conversion after `implicit` or `explicit`, inside a class or augment. It is not a standalone cast expression; use `as`, `to` or `to?` at a call site.

```quds
augment int:
  explicit cast(source: int) -> String:
    return source.toString()
```

## `this`

Refers to the current instance; `this.field` also declares initializing parameters. Conversion declarations do not have an instance receiver.

```quds
class Counter:
  count: int = 0
  read() -> int = this.count
```

## `super`

Accesses the superclass implementation or declares a forwarded initializing parameter.

```quds
class Child extends Parent:
  init(super.id: int):
    print id
```

## `init`

Declares a constructor without repeating the class name. Supports named, factory, const and redirecting forms.

```quds
class Point:
  x: int
  init(this.x: int):
    print x
```

## `factory`

Marks a factory constructor, which returns an instance rather than initializing `this` directly.

```quds
class Box:
  value: int required
  factory init zero() -> Box = Box(0)
```

## `static`

Declares a member on the type rather than on each instance. Such members have no instance `this`.

```quds
class Numbers:
  static zero() -> int = 0
```

## `private`

Restricts a declaration to its library and lowers to a Dart underscore name. An explicitly underscored name is already library-private.

```quds
class Account:
  private balance: int = 0
```

## `protected`

Allows access from the declaring library and subtypes. Quds checks access; Dart runtime enforcement is not provided.

```quds
class Base:
  protected count: int = 0
```

## `readonly`

Restricts mutation through a reference or method. It does not freeze the object or other aliases. Nested writes and mutating calls are rejected.

```quds
read(items: readonly List<int>) -> int:
  return items.length
```

## `required`

Marks a required field or a required named-only parameter. Plain function parameters are dual positional/named parameters.

```quds
greet(name: String required):
  print name
```

## `property`

Declares a property with get and/or set accessors. Omitting set makes it read-only; omitting get makes it write-only.

```quds
class Box:
  property answer: int:
    get = 42
```

## `get`

Declares a property getter, using an expression or a block. Outside accessor syntax it remains an ordinary identifier.

```quds
class Box:
  property answer: int:
    get = 42
```

## `set`

Declares a property setter or, when followed by a colon in expression position, a set collection. Otherwise it can be an identifier.

```quds
unique = set:
  1
  2
```

## `operator`

Declares an operator overload with a parameter list and body. Dart-fixed return types still apply.

```quds
class Number:
  value: int required
  operator +(other: Number) -> Number = Number(value + other.value)
```

## `annotation`

Declares constant metadata used with @Name or @Name(...). Metadata arguments must be constant expressions.

```quds
annotation Tag(name: String):
@Tag(name: "example")
class Item:
  id: int required
```

## `out`

Declares output variance for a generic parameter. Uses must be sound in output positions.

```quds
interface Source<out T>:
  read() -> T:
    throw StateError("Abstract member")
```

## `use`

Imports a Quds, Dart, package or relative library. Supports prefixes, section selection, show/hide, conditional imports and deferred loading.

```quds
use quds:math
print sqrt(9.0)
```

## `export`

Re-exports selected public library declarations to callers. Supports show/hide filters and sections.

```quds
export quds:math
```

## `show`

Limits an import or export to the listed names. A missing exported name is an error.

```quds
use quds:math show Fraction, gcd
```

## `hide`

Excludes listed names from an import or export. Explicit core filters also apply to prelude names.

```quds
use quds:math hide Fraction
```

## `deferred`

Loads an imported library lazily. The import needs a prefix. `prefix.loadLibrary()` returns `Future<void>` and completes before the prefix's names are used.

```quds
use dart:math as math deferred
main() async:
  await math.loadLibrary()
  print math.min(1, 2)
```

## `when`

Guards a match arm or selects a compile-time library branch. Library conditions must be constant booleans; standalone `when condition:` selects a compile-time block.

```quds
use dart:io when platform == "vm"
```

## `part`

Includes a source part in one library. Write an unquoted module path, as with use/export: `details` means `details.quds`, and `src.details` means `src/details.quds`. Parts share privacy and must declare a matching `part of`. Quoted literal file paths remain accepted for compatibility.

```quds
part src.details
```

## `of`

Completes a `part of` directive that identifies the owning library. Use an unquoted module path; `^.main` names `../main.quds`. Local path completion is available after both `part` and `part of`. The word is contextual, not a general operator.

```quds
part of ^.main
```

## `async`

Marks an asynchronous function or async disposal. Combine with * for an asynchronous generator. Await operations require an async context.

```quds
load() async -> int:
  return await fetch()
```

## `await`

Waits for asynchronous work. Also starts `await for`, `await all:` and `await isolate:` forms.

```quds
load() async:
  value = await fetch()
  print value
```

## `sync`

With *, marks a synchronous generator returning an Iterable. Ordinary synchronous functions need no sync marker.

```quds
numbers() sync* -> int:
  yield 1
  yield 2
```

## `yield`

Emits a generator element. `yield*` delegates to another iterable or stream; it does not return from an ordinary function.

```quds
numbers() sync* -> int:
  yield 1
```

## `all`

In `await all:`, starts child expressions together and returns results as a record in source order. Failure requests cooperative cancellation.

```quds
load() async:
  values = await all:
    fetchFirst()
    fetchSecond()
```

## `isolate`

In `await isolate:`, runs a top-level or static call in a new isolate. Arguments must be sendable; local captures are rejected.

```quds
load() async:
  value = await isolate:
    compute(42)
```

## `task`

Starts a structured `task group:` that waits for spawned children. Child failures cancel remaining work and produce TaskFailed.

```quds
run() async:
  task group:
    spawn fetch()
```

## `group`

Groups tests when followed by a string, or completes `task group:` for structured concurrency.

```quds
group "arithmetic":
  test "addition":
    expect(1 + 1, 2)
```

## `spawn`

Schedules child work in the current task group and isolate. It is invalid outside a task group.

```quds
run() async:
  task group:
    spawn fetch()
```

## `try`

Handles exceptions with catch/finally, or supplies an expression fallback with `try expression else expression`. Does not inspect Result errors.

```quds
number = try parse() else 0
```

## `catch`

Handles an exception, optionally with a type and a stack-trace binding. A catch body may rethrow.

```quds
try:
  work()
catch error:
  print error
```

## `finally`

Runs cleanup when leaving try, including exceptional exits and returns.

```quds
try:
  work()
finally:
  cleanup()
```

## `throw`

Raises an exception and leaves the normal execution path.

```quds
throw StateError("Invalid state")
```

## `rethrow`

Propagates the current caught exception with its stack trace. Only valid inside catch.

```quds
try:
  work()
catch error:
  print error
  rethrow
```

## `assert`

Checks a condition in assertion-enabled builds. Release builds can remove it; the optional message is evaluated only on failure.

```quds
assert count >= 0, "Negative count"
```

## `require`

Checks a precondition in every build and throws ArgumentError on failure. Its message is evaluated only on failure.

```quds
require count >= 0, "Negative count"
```

## `check`

Checks an invariant in every build and throws StateError on failure. Its message is evaluated only on failure.

```quds
check ready, "Not ready"
```

## `defer`

Schedules an expression for scope exit, last in first out. Deferred work runs on returns and exceptions too.

```quds
defer cleanup()
work()
```

## `using`

Binds a disposable resource and disposes it on every exit. `using async` awaits disposal and requires an async function.

```quds
using resource = openResource():
  resource.read()
```

## `with`

Evaluates a receiver once, applies a block of member operations, and yields that receiver. In class headers, applies mixins.

```quds
updated = with item:
  name: "Updated"
```

## `with?`

Skips the receiver block when its receiver is null, yielding null; otherwise behaves as with on a promoted non-null receiver.

```quds
updated = with? item:
  name: "Updated"
```

## `where`

Introduces immutable names scoped to one expression. Bindings evaluate left to right before that expression. After a generic function signature, it also declares constraints such as `where T is Numeric`.

```quds
print total / count where total = 12, count = 3
```

## `let`

Introduces a non-null binding in if/while or trailing conditions. The binding exists only in the successful branch or guarded statement.

```quds
if let name = nullableName:
  print name
```

## `match`

Matches a value against ordered patterns with optional when guards. Expression matches must be exhaustive.

```quds
text = match enabled:
  true: "yes"
  false: "no"
```

## `switch`

Uses the same pattern matching grammar as match. Arms do not require C-style fallthrough or break.

```quds
switch enabled:
  true:
    print "yes"
  false:
    print "no"
```

## `map`

Introduces a map collection only when followed by a colon. Rows are key: value expressions; outside this form map is an identifier.

```quds
ages = map:
  "Ada": 36
```

## `state`

Declares a reactive cell with an initializer. Reads participate in dependency tracking.

```quds
state count = 0
```

## `computed`

Declares a non-assignable reactive value computed from tracked reads. Requires an initializer; dependency cycles are diagnosed or fail at runtime.

```quds
state count = 1
computed doubled = count * 2
```

## `watch`

Subscribes to a reactive expression for the enclosing scope. Subscription cleanup runs on every exit.

```quds
state count = 1
watch count:
  print count
```

## `batch`

Delays reactive notifications until block exit and flushes once, including on exceptional exit.

```quds
batch:
  count = 2
  total = 4
```

## `event`

Declares a typed event member. Handlers subscribe to the event; raise emits it.

```quds
class Button:
  event clicked: (int) -> void
```

## `raise`

Emits a declared event with its arguments.

```quds
raise clicked(1)
```

## `once`

Runs a statement block at most once for its generated call site, even if the enclosing function is called repeatedly. Outside `once:` it remains an identifier.

```quds
tick():
  once:
    print "First call"
```

## `config`

Declares a typed configuration key. Lookup order is environment, quds.yaml config, then the source default. Dotted keys map to uppercase environment names with underscores.

```quds
config server.port: int = 8080
```

## `secret`

Marks a configuration key that must not have a source initializer.

```quds
config secret server.token: String
```

## `test`

Declares a named test at library scope or inside a test group. Run Quds tests with quds test.

```quds
test "addition":
  expect(1 + 1, 2)
```

## `by`

Starts `by lazy:` initialization. A lazy immutable binding computes its value on first access.

```quds
class Answer:
  value: int by lazy:
    result 42
```

## `lazy`

Completes `by lazy:` for deferred immutable initialization. It cannot be combined with var.

```quds
class Answer:
  value: int by lazy:
    result 42
```

## `capture`

Creates a closure that snapshots the listed bindings. Snapshots are immutable and do not deep-copy object contents.

```quds
var count = 1
read = capture(count) -> count
count = 2
```

## `nameof`

Produces a source-level name rather than evaluating an arbitrary expression. Use it with a supported name reference.

```quds
name = nameof count
```

## `new`

Selects a constructor in a contextual dot shorthand. The expected type must determine a unique constructor.

```quds
point: Point = .new(1, 2)
```

