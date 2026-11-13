# MVP-0 supported subset

This implements Issue #1's first compiler slice. The approved decisions are not
replaced by this document. Syntax outside this subset is deferred, not removed
from the language. Design 1.2 in `QUDS_LANGUAGE_SPECIFICATION.md` is the
language; this file is the compiler that exists today. Diagnostics use the
design registry (`E001`–`E006`, `E100`, `E102`, `E200`, `E300`, `E401`, and
the other implemented codes) with the original file, line, and column. Tokens
and AST nodes retain
source spans; there are no generated-Dart source maps yet.

## Layout and lexical rules (001, 019, 020, 021, 065)

A block uses `:` followed by a newline and increased space indentation. Any
positive width is accepted; dedents must match a previous level. Leading tabs
are rejected, including on continuation lines. Blank/comment-only lines do not
change the indentation stack. Parentheses and list brackets suppress layout
newlines/indentation; mismatched and unclosed delimiters are errors. EOF supplies
a logical newline and any remaining dedents.

`#`, `///`, and nested `/* ... */` comments are supported. Block comments are
whitespace; a leading comment preserves the indentation before its opening
delimiter. Physical newlines inside a block comment do not themselves terminate
a logical statement. LF, CRLF and CR count as one newline each. Byte offsets and
lengths address the original UTF-8 source; columns count UTF-16 code units.
Identifiers start with a Unicode letter, letter-number or `_`, followed by those,
Unicode numbers or combining marks. Spellings are preserved without normalization.

Strings use either quote, or three matching quotes for multiline content.
Escapes: `\n`, `\r`, `\t`, `\\`, `\'`, `\"`, `\{`, `\}`, `\$`.
`"Hello {name}"` and `"sum {add(1, 2)}"` parse interpolation expressions through
the same lexer/parser; `$` is ordinary Quds text. Literal braces must be escaped.
Raw strings and comments inside interpolation are deferred.

Numbers support decimal native Dart integers, finite doubles, hex, exponents,
and digit separators. A literal outside the signed 64-bit range is `E006`.
Small integers and decimal doubles match between the VM and JavaScript. An
integer outside the JavaScript safe range stays exact on the VM, and Dart's
web compiler rejects it instead of rounding it.

Examples and conformance: `test/lexer_test.dart`, `test/parser_test.dart`, and
string execution tests in `test/compiler_test.dart`.

## Expressions and calls (003, 004, 009, 081, 111)

Supported expressions: numeric/string/bool/null literals, identifiers, nonempty
homogeneous lists (numeric mixtures infer `List<num>`), grouping, unary `+`, `-`,
`not`, and binary `* / % + - < <= > >= == != and or`. Precedence follows that
order from tightest to loosest; binary operators at each level associate left.
`and` and `or` short circuit. There is no increment/decrement syntax.

Calls use parentheses for multiple arguments and nested calls. Positional
arguments precede named arguments; duplicates, unknown names, missing arguments
and incompatible types fail statically. These forms share one call AST:

```quds
add(a: int, b: int) = a + b
main():
  print add(1, 2)
  print(add(a: 1, b: 2))
  answer = add:
    b: 2
    a: 1
  print answer
```

A parenthesis-free simple call takes one expression; simple calls nest to the
right (`print add(1, 2)`). Use parentheses for unary arguments such as `print(-1)` and to disambiguate
binary operations on a call result. A named block may extend `add(1):` with `b: 2`, or follow a bare
callee, on a statement or binding RHS. Each block row has `name: expression`.
Nested child sequences, property configuration, named blocks nested inside
argument rows, defaults and optional arguments remain unresolved/deferred.

Named labels currently map to the function's declared parameter names. The Dart
ABI uses positional parameters; a closure stores named-call arguments in written
order before arranging them in declaration order. Expressions evaluate once,
left to right. There is no dynamic overload dispatch or silent overload choice.
See parser call tests, semantic negative cases, and the `mark` execution test.

## Functions and statements (005, 006, 007, 032, 084)

Modules contain function declarations and top-level `const` bindings. Any other
module-scope statement is rejected. A const initializer is evaluated in source
order and can read only consts already evaluated. Function bodies can read
every top-level const, including one declared later in the file, just as they
can call other functions. Functions accept typed,
required parameters, an optional `-> Type` result, and an indented block or
`= expression` body. This annotation spelling comes from Issue #1's acceptance
program; alternative return annotation forms are not assumed.

```quds
add(a: int, b: int) = a + b
increment(var value: int) -> int:
  value += 1
  return value
main():
  numbers = [10, 20, 30]
  var total = 0
  for number in numbers:
    total += number
  if total > 50:
    print "Total: {total}"
  else if total == 0:
    print "empty"
  else:
    print total
  print add(5, 7)
```

Expression bodies infer their result. Unannotated multiline functions return
`void`; non-void blocks require explicit returns on every statically recognized
path. A loop alone does not prove a return. Parameters and loop variables are
non-reassignable unless the parameter uses `var`. `main` has no parameters and
returns void. Only call expressions may stand alone as statements. `for-in`
currently accepts lists; ranges, while, break/continue and async are deferred.
Tests: `test/parser_test.dart`, `test/semantics_test.dart`, `examples/sum.quds`.

## Bindings, scopes and types (002, 014, 090, 093)

```quds
main():
  base: int = 2
  const factor = 3
  var count = base
  if true:
    count += factor
    shadow count = count + 1
    print count
  print count
```

`name = value` declares a final binding if no symbol is visible, or assigns an
existing mutable binding. `var` explicitly declares a mutable binding; `const`
requires a compile-time constant initializer, which Quds evaluates before
emission. Typed declarations use `name: Type = value`.
`var whole = 0.0, fraction = 0.0` declares every name on that line. The leading keyword applies to each of them, and a later initializer can read an earlier name.
Compound assignment requires an existing mutable binding. `shadow` requires an
outer binding and creates a new final local binding after resolving its initializer
against the outer scope. It cannot redeclare a name in the same scope. `var` or
a typed declaration cannot implicitly shadow an existing symbol.

A final binding does not freeze/copy the referenced object. Collection mutation
APIs and readonly views are not yet available. Symbols resolve statically;
undefined names, parameter collisions and duplicate functions/overloads fail.
Function values and local function declarations are deferred.

Implemented types: `int`, `double`, `num`, `bool`, `String`, `Null`, nested
`List<T>`, and `void` results. Inference never silently falls back to `dynamic`.
Numeric values may widen to `num`; implicit `int` to `double`, nullable types,
contextual empty-list typing and generalized subtype inference are deferred.
See the explicit-shadow, mutability, parameter and type conformance tests.

## Const evaluation (002, 004, 065)

```quds
main():
  const base = 10
  const step = base - 3 - 2
  const allowed = false and (1 % 0 == 0)
  const values = [base, step]
  print step
  print allowed
  print values
```

This prints `5`, `false`, and `[10, 5]`. The supported const forms are the
MVP-0 literals, references to earlier const bindings, unary `+`, `-`, and
`not`, the arithmetic and comparison operators, `==` and `!=`, `and` and `or`,
and lists of those values. Calls, general interpolation, mutable bindings, and
final bindings are not constants. `E401` is reported on the failing subexpression
in the original `.quds` file.

Evaluation uses the host Dart `int` and `double` operators, left to right and
once. On the validated native SDK, integers wrap at signed 64 bits, so
`9223372036854775807 + 1` is `-9223372036854775808`. The positive literal
`9223372036854775808` is rejected because it is not a native `int`. Integer
remainder by zero, including a `num` const whose value is the integer `0`, is
`Integer remainder by zero`. Double remainder by zero is `NaN`. `/` by zero is
a non-finite double, not an error. `and` and `or` short-circuit: a skipped
`1 % 0` is not evaluated, but a skipped call is still rejected because both
operands must be constant expressions. Const `==` on lists follows Dart
canonical identity, so two const lists of `0.0 / 0.0` compare equal, while
`[-0.0] == [0.0]` is false. Numeric `==` stays IEEE: NaN is not equal to NaN,
and `-0.0 == 0.0`.

A `const` list is a Dart constant list. A final or `var` list remains a
mutable object; the binding's immutability does not freeze it. The same rules
apply to a top-level `const`. Inside a `const` binding, a list, map, set,
or const constructor call is constant without another `const` keyword. The
same list in an ordinary binding stays mutable. A constructor that is not
`const`, and a `const` constructor with a body, are rejected. An
interpolation whose parts are all literals is already a string literal
(`"hi {1}"` is `"hi 1"`). Any other interpolation is not a constant. Dart has
no prefix `+`, so Quds unary `+` is lowered as numeric identity, including the
sign of zero. Const initializers are emitted as expressions so Dart evaluates
them again, except `and` and `or`, which are emitted as their bool result to
avoid Dart's `dead_code` warning. A const that folding leaves unread is kept.
A local is marked `// ignore: unused_local_variable`; a top-level const is
marked `// ignore: unused_element`.

Dart also reports `dead_code` when a bool literal, const bool, or
definitely-assigned bool local is used directly as an `if` condition or as an
`and`/`or` operand. Those leaves are passed through an identity function
`_qBool` in the generated Dart. The binding is still read once, `and`/`or`
still short-circuit, and a taken runtime `1 % 0` is still Dart's error rather
than a Quds constant error. Const initializers do not call `_qBool`.

Tests: `test/constants_test.dart` and `test/fixtures/const_eval.quds`.

## Dart output (033, 063)

Emission is deterministic and uses unique Dart names for top-level functions so
the MVP-0 golden fixtures stay stable. Classes, cases, and methods keep their
Quds names. `quds build` writes `.dart_tool/quds/out/` inside the package,
mirroring the `.quds` path, and does not write a sibling `.dart` file. It
still refuses to overwrite an output file that does not start with the
generated header, and it writes a `.dart.map` beside that output (Source Map
Revision 3, one mapping per generated line). The `.dart` text itself is
unchanged by the map.

## Language slice beyond MVP-0

`test/language_test.dart` compiles, analyzes, and executes this slice:

- Classes, value classes (`==` and `hashCode`), and `sealed type` cases.
- Local functions, expression lambdas, function tear-offs, and function types `(parameters) -> Type`.
- Nullable types, postfix `!`, and `??`.
- `use dart:math` reads that library from the Dart SDK sources, including
  its `part` files, so the names stay in step with those files. A `dart:`
  library whose sources are not in the SDK is emitted and does not invent
  names. `package:` and `.quds` imports are unchanged.
  `use src.sum` imports `src/sum.quds` beside the file. Each `^` climbs one
  directory, so `use ^^^.sum` imports `../../../sum.quds`. In a `use` line,
  `.` completes from the files and directories beside that file, `dart:`
  completes from the SDK libraries on disk, and `package:` completes from
  `package_config.json` and this package's `lib` files.
  A `package:` URI that already ends in `.dart` is emitted unchanged, and its
  names are read from that package's sources the same way as a `dart:` library.
  `use package:flutter.material` is that same library: dots after the package
  name are directories. `Column` is the class `Column`. A name the sources do
  not declare is still passed through to Dart. `quds create flutter <name>` creates a
  Flutter app whose program is `lib/main.quds`. `quds run` on that file
  compiles it under `lib/quds_gen/` and launches `flutter run`.
- `for` over lists, sets, ranges (`..` and `..<`), and strings, including a range whose end is below its start. `for piece in text` yields each character. `for i, item in items` binds the position and the element. `range(start, end)` is `start..end`, and `range(end)` is `0..end`. Lists, sets, and ranges share `map`, `fold`, `reduce`, `sum`, `min`, `max`, `count`, `find`, `findLast`, `take`, `drop`, `takeLast`, `dropLast`, `skip`, `sorted`, `unique`, `flat`, `group`, and `join`. `map` returns a new list. `sum` of nothing is zero. Collection `min` and `max` are null when empty. `min(a, b)` and `max(a, b)` choose between two numbers. `"ab"[0]` is `"a"`. `text[1..]`, `text[..<n]`, and `items[1..3]` slice a string or a list. `substring` takes an optional end. `text.chars` is the characters. A string also has `take`, `drop`, `takeLast`, and `dropLast`. Numbers have `abs`, `round`, `floor`, `ceil`, and `clamp`. `n.pad(4)` writes an `int` with leading zeros. `"-" * 12` repeats text. `0 <= index < items.length` compares in a chain, and every operand runs once. `piece in digits` and `name not in seen` test membership. `text[-1]` and `items[-2..]` count from the end. `text.lines` splits lines. `title.padEnd(12)` and `title.padStart(8, "0")` widen text. `repeat 3:` runs a body a counted number of times. `for name, score in names.zip(scores)` pairs two collections and stops at the shorter one. A collection element uses the same pair: `for mark, tone in marks.zip(tones)`. `for i in 0..10 step 2` steps through a range, and a range with no step still walks downward when the end is below the start. `items + more` builds a new list and `ages + extra` builds a new map where the right-hand key wins. `n.fixed(2)` and `n.plain` write a number as text. A triple-quoted block drops the indent of its closing line. A misspelled name can suggest the nearest visible spelling. `while`, `break`,
  `continue`, and `label name` on a loop.
- `map:` and `set:` literals, records, and `(a, b) = record` destructuring.
- Default arguments, including defaults that read earlier parameters, and
  compile-time overloads. Identical signatures are still an error.
- `missing`, `present`, `Ok`, `Error`, and postfix `?` on `Result`.
- `async` / `await`. An async `main` returns `Future<void>`.
- `@macro` classes whose `define` body only calls `builder.addMethod`.
- `quds run`, `analyze`, `test`, `format`, `create`, `add`, `remove`, `get`,
  `doc`, and `migrate`, in addition to `build`. A thrown error from `quds run`
  is printed on the `.quds` line. The generated `.dart` line is not shown.
- `do` / `result`. `result` finishes the `do`. `return` inside `do` leaves the
  function. `E106` outside `do`, `E109` when a value `do` has no `result`.
- `readonly` on one reference. Assignment and a mutating method name are
  `E307`. Another binding of the same object may still call that method.
- `capture(names) -> expr` snapshots those bindings. Object contents are not
  copied.
- `to` and `to?`. Failure throws `ConversionError` or yields null. The target
  may be nullable.
- `with` and `with?`. The receiver runs once. `with?` yields null and skips
  the block when the receiver is null. A readonly receiver is `E307`.
- Unions. `int | double` is `num`. `T | Null` is `T?`. Any other union lowers
  to a sealed hierarchy. A statement `match` warns `W001` when a sealed type
  or union is incomplete, and an unreachable arm is `E313`. A guard does not
  cover its arm.
- Dot shorthands `.member` and `.new` when the expected type is unique
  (`E302` otherwise).
- Null-aware list and set elements, and collection-element blocks, including
  `if` and `for` in those blocks.
- `test "...":` and `group "...":`. `quds test` runs them. A function whose
  name starts with `test` still runs too.
- C-style `for var i = 0 while cond step i += 1:` and `repeat:` / `while`.
  A constant step of zero is `E801`. A non-constant step of zero throws when
  the update runs. `continue` runs the step.
- Spreads `...` and `...?` in lists, sets, maps, and collection blocks.
  `if` and `for` are collection elements there too. Inside `[]`, a comma that
  separates list elements sits after the suite, at the list's indentation.
- `if` expressions, which require `else`, and `match` expressions. A missing
  expression arm is `E314`.
- `try` / `catch` / `finally`, `throw`, `rethrow`, and `try expr else fallback`. Typed catches run in source order. `finally` runs when the suite exits, including after `rethrow`. `catch error, stack` binds the `StackTrace`. `rethrow` outside `catch` is `E107`.
- `late` and `late var`.
- `enum` declarations, including dot shorthand and exhaustive `match`.
- `sync*` / `yield` and `async*` / `await for`.
- Typed variadics `...values: Type` and call spreads `...` / `...?`. A fixed
  signature wins over a variadic one. A variadic parameter that is not last is
  `E503`.
- `mixin`, `class ... with`, `interface`, and `extend Type`. A failed mixin
  `on` constraint is `E702`. A mixin member that does not override the previous
  signature is `E300`. Two extensions for one member are `E205`.
- `singleton class` builds one instance per isolate. An initialization cycle is
  `E707`. Empty `map:` and `set:` use the expected type. A repeated map key
  keeps the later value.
- Lambdas: `x -> expr`, nested arrows, an indented body with `return`, and `await` inside the lambda. A closure sees a later assignment to a mutable binding.
- `state`, `computed`, and `watch`. A computed cycle warns `W007`. A cycle found while a computed value is already evaluating throws `CycleError`. `watch` drops its subscription when its scope exits. `batch` holds notifications until the suite exits, including an exceptional exit, then flushes once.
- Transparent aliases `type Name = Type` and extension types `type Name wraps Type`.
  `require` in the wrapped body rejects a value at construction.
- Class modifiers `abstract`, `base`, `interface`, `final`, `sealed`, `mixin`,
  `value`, and `singleton`, in the combinations Dart accepts. Any other
  combination is `E720`. A final class cannot be extended. A subtype of a
  `base` class is `base`, `final`, or `sealed`.
- Diagnostics use the design registry. Lexer errors are `E001`–`E006` and
  `E102`. A parse failure is `E100`. Semantic failures use codes such as
  `E200`, `E203`, `E300`, `E401`, and `E500`.
- `property` getters and setters, `operator` declarations, and `readonly`
  methods. A write inside a `readonly` method is `E307`.
- `private` members lower to Dart `_` names. `protected` members are visible
  in the same library and are emitted with a `/// protected` comment.
- `init`, `init name`, `factory init`, and initializing formals `this.field`.
  A final field missed by a constructor is `E704`. A `var` field on a value
  class is `E706`. Value classes without their own `init` also get `copyWith`.
- `if value is Pattern`, `if let name = expr`, `using` / `using async`, and
  `defer`. Deferred calls run at scope exit, last in first out, before `using`
  disposal. An async `defer` outside an async function is `E803`.
- `static const`, `static var`, `static final`, and `static` functions. A
  static member used on an instance, or an instance member used on the class,
  is `E300`.
- `const init` with initializing formals. A value class `copyWith` copies
  every instance field through a generated constructor, including a field
  assigned in the constructor body. The user constructor body is not run
  again. An omitted argument and an explicit `missing` keep the field. An
  explicit null stores null when the field is nullable.
- `part` / `part of`, and constant `when` / `use when`. On the VM, `platform`
  is `"vm"`. A non-constant `when` is `E902`. Both `part` and `part of` in one
  file is `E903`. The `when` branch that is not selected is neither type-checked
  nor emitted.
- Patterns: `or` (`|`), `and`, relational (`<`, `<=`, `>`, `>=`, `==`, `!=`),
  list rest (`...` and `...name`), indented `map:` patterns, records, `as`,
  null-check `?`, and null-assert `!`. A parenthesized pattern with no comma
  is grouping. `(pattern,)` is a one-field record.
- Generic classes and functions, written `<T: Bound>`, and variance `in` /
  `out`. A use in the wrong position is `E304`. `in` and `out` are dropped in
  Dart; a bound is `extends`. A constructor call infers type arguments from
  named arguments, and `Box<String>(...)` passes them explicitly.
- Intersection types `A & B`. `&` binds tighter than `|`. A parameter lowers
  to `T extends` the first type, then checks `is!` for each later part. Two
  disjoint concrete types are `E306`. A member that belongs to a later part is
  cast to that part in the generated Dart.
- `extend List<T>:` treats an unbound type argument as an extension type
  parameter and emits `extension<T> on List<T>`.
- `await all:` starts every child immediately and yields a record in source
  order. The first source-order error propagates. The form requires `async`
  (`E803`). `await isolate:` lowers a top-level or static call to
  `Isolate.run`. A captured local is `E805`.
- `task group:` / `spawn`, including a nested group. `spawn` outside the group is `E107`. The group
  requires `async` (`E803`). Child errors are collected in source order into
  `TaskFailed`. A nested group is not entered after an earlier child has failed.
- `noSuchMethod` on a `dynamic` receiver. A typed missing member is still
  `E300`. `symbol "name"` is `#name` when the text is an identifier.
- `require`, `check`, and `assert`, with an optional message after a comma.
  `require` throws `ArgumentError` and stays in release. `check` throws
  `StateError` and stays in release. `assert` is Dart's `assert`. The message
  runs only when the condition is false. `dart run --no-enable-asserts` skips
  the assert, so its condition does not run. `require` and `check` still run.
- `annotation Name:` and `annotation Name(parameters)` emit a const class.
  `@Name` and `@Name(name: value)` emit that metadata. Arguments are named
  constants. A missing required argument is `E500`. A non-constant argument is
  `E401`. `@Reflectable` on a class emits `qudsReflectName` with the class
  name and field names.
- `log.info "message", data: map:` writes a structured line. Levels are
  `debug`, `info`, `warning`, and `error`. `log.minimum = "info"` drops
  anything below that level. `log.sink writer` replaces the default printer.
  A map key named `secret`, or ending in `_secret` or `.secret`, is written
  as `***`. An exception from the sink propagates. An unknown literal level
  is `E300`.
- `task group` and `await all` enter each child immediately until one throws
  before returning. Later children are then not entered. A child that has
  already started still runs, and the group reports `TaskFailed` in source
  order. `await all` rethrows the first source-order error.
- `config name: Type = expression` reads the process environment, then the
  `config:` map in `quds.yaml` beside the working directory, then the source
  default. A dotted name such as `server.host` is read as `config.server.host`
  and as the environment variable `SERVER_HOST`. `config name: Type` is
  required and throws `StateError` when every layer is absent. The value is
  `int`, `double`, `bool`, or `String`. `config secret name: Type` has no
  source initializer. A secret literal is `E908`.

Numbers also accept hex (`0x10`), exponents (`1e2`), and `_` separators.
A value outside the signed 64-bit range is `E006`. An integer that does not
fit in a JavaScript number stays exact on the VM. Dart's web compiler rejects
that literal, and `test/language_test.dart` executes both results.

`use "other.quds"` loads that library. Public classes and functions are
visible. `show` keeps only the named ones, and `hide` drops them. A `show`
name that is not in the library is `E200`. `use "other.quds" as math` binds
`math.Box` and `math.doubleIt`. `export "other.quds" show doubleIt`
re-exports that name. A private member used from another library is `E206`.
A protected member used outside the library and its subtypes is `E207`. A
subtype in another library may read `protected`. A public function is also
emitted under its Quds name. `part "detail.quds"` and `part of "parent.quds"`
share that privacy scope. A missing part is `E900`, and a mismatched
`part of` is `E903`.

`quds.yaml` beside the source may set `language: "1.2"`. Any other declared
version is `E901`. A `# quds:` comment does not select a version.

`@Reflectable` emits `qudsReflectName` with the public fields, a separate
`private` list, and `typeParameters`. `qudsReflectable` lists those const
maps. A class without the annotation is absent from the list.

`quds build` writes `.dart_tool/quds/cache/` with a hash of the source and
the `.quds` files it loads. A second build of the same bytes prints
`Unchanged` and does not rewrite the output. Changing an imported library,
or a macro in the same file, rebuilds the generated Dart. `quds build
--watch` repeats that build when one of those files changes.

The generated `.dart` has no import of the Quds package. `dart analyze` and
`dart run` execute it on their own.

`use package:name` loads `lib/name.quds` beside `pubspec.yaml` and emits
`import 'package:name/name.dart'`. `use package:name/src/util` loads
`lib/src/util.quds`. A missing file is `E900`. `use generated:user_models`
loads `lib/generated/user_models.quds`. `declare` copies a method to a
top-level function. `define` copies methods, fields, properties, and
constructors. A macro cycle is `E904`. Source text and a forbidden
capability are `E905`. Depth past 8, and more than 1000 declarations from
one annotation, are `E906`. A class `call` method is invoked by calling the
instance, including a generic class and named arguments. `protected` is
emitted as `@protected` when the package depends on `package:meta`, and as
a documentation comment otherwise. `quds migrate` leaves a `quds.yaml`
pinned to a version other than 1.2 unchanged. `quds lsp` answers completion, definition,
hover, code lenses on `main`, rename, formatting, and diagnostics for an open buffer. Hover reports `var name: Type` for a mutable binding, `property name: Type` for a getter/setter, and `name() -> Type` for a function. Semantic tokens use those same three kinds, so a property is not colored as a function. The lenses are Run, Debug, and Profile. Run and Profile execute in a terminal. Debug builds the generated Dart and launches it under `quds debug`. A breakpoint in a `.quds` file is moved to the generated line, and a stop is shown on the `.quds` line. The language server itself does not launch a program. Hover reuses the analysis of the current buffer. `mapStack` rewrites a stack frame
that hits the source map. `quds format` rewrites indentation outside a
multiline string to two spaces, keeps comments and string contents, drops
trailing whitespace, and ends the file with a newline. A second format is
identical. Lines wrap at 80 columns after a comma. A condition with one
statement is written on the header line when that line fits. The editor
formats a `.quds` file on save. Tab size, `quds.format.lineWidth`, and
`quds.format.singleLineIf` change that formatting. `if cond: return 1` is a
statement suite, and the indented form remains. `quds doc` lists `///`
lines. `quds doc test` compiles and runs a fenced example. A `[Name]` that
is not a top-level function or class in that file is `E200` (`Broken link:
Name`). An example that fails to compile or run exits 65. No HTML API site
is written.

`??=` assigns only when the binding is null, and the right side does not run
otherwise. After that assignment, or after `if name != null`, a local nullable
binding is promoted. Using it while it is still nullable is `E308`. Assigning
it again removes the promotion. `List<List<int>>` and
`List<List<List<int>>>` close every type argument. An index or member read
through `readonly` stays readonly, so a nested write is `E307`. Another alias
of the same object can still write.

A list or set element `value for name in iterable if condition` builds that
collection immediately. The iterable runs once. A false filter skips the
element expression. A comprehension may contain another comprehension. A
`sync*` generator does not run until something iterates it.

The parity table still includes aborting a future that has already started.
No claim of full 115-decision conformance is made.
