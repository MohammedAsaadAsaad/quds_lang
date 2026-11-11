# MVP-0 supported subset

This implements Issue #1's first compiler slice. The approved decisions are not
replaced by this document. Syntax outside this subset is deferred, not removed
from the language. Design 1.2 in `QUDS_LANGUAGE_SPECIFICATION.md` is the
language; this file is the compiler that exists today. Its lexer, parser and
semantic failures still carry category codes Q001, Q100 and Q200 with original
file, line and column. The design registry is the `E` / `W` codes, and a
compiler that implements 1.2 uses those instead. Tokens and AST nodes retain
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

Numbers support decimal native Dart integer and finite decimal-double literals;
exponents, radix syntax and digit separators are deferred. Out-of-range positive
integer literals are rejected instead of silently becoming doubles. Cross-platform
integer guarantees remain open. Small integers and decimal doubles were executed
with `dart compile js` and Node.

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
final bindings are not constants. Q200 is reported on the failing subexpression
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
apply to a top-level `const`. Inferred const is not implemented. An
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
Quds names. `quds build` still refuses to overwrite a file that does not start
with the generated header, and it writes a sibling `.dart.map` (Source Map
Revision 3, one mapping per generated line). The `.dart` text itself is
unchanged by the map.

## Language slice beyond MVP-0

`test/language_test.dart` compiles, analyzes, and executes this slice:

- Classes, value classes (`==` and `hashCode`), and `sealed type` cases.
- Local functions, expression lambdas, and function tear-offs.
- Nullable types, postfix `!`, and `??`.
- `use dart:math` for `sqrt`, `sin`, `cos`, `min`, `max`, and `pi`. Other
  `dart:`, `package:`, and `.quds` imports are emitted and do not invent names.
- `for` over lists, sets, and ranges (`..` and `..<`), `while`, `break`,
  `continue`, and `label name` on a loop.
- `map:` and `set:` literals, records, and `(a, b) = record` destructuring.
- Default arguments, including defaults that read earlier parameters, and
  compile-time overloads. Identical signatures are still an error.
- `missing`, `present`, `Ok`, `Error`, and postfix `?` on `Result`.
- `async` / `await`. An async `main` returns `Future<void>`.
- `@macro` classes whose `define` body only calls `builder.addMethod`.
- `quds run`, `analyze`, `test`, `format`, `create`, `add`, `remove`, `get`,
  `doc`, and `migrate`, in addition to `build`.
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
- `try` / `catch` / `finally`, `throw`, `rethrow`, and `try expr else fallback`.
- `late` and `late var`.
- `enum` declarations, including dot shorthand and exhaustive `match`.
- `sync*` / `yield` and `async*` / `await for`.
- Typed variadics `...values: Type` and call spreads `...` / `...?`. A fixed
  signature wins over a variadic one. A variadic parameter that is not last is
  `E503`.
- `mixin`, `class ... with`, `interface`, and `extend Type`. A failed mixin
  `on` constraint is `E702`. Two extensions for one member are `E205`.
- `state`, `computed`, and `watch`. A computed cycle warns `W007`.

Numbers also accept hex (`0x10`), exponents (`1e2`), and `_` separators.

Still rejected, rather than given an invented meaning: extension types,
`type Name = Type` aliases, and the remaining class modifiers beyond `mixin`
and `interface`. Older diagnostics stay `Q100` and `Q200`. Integers that do not
fit in a JavaScript number keep Dart's web limit. No claim of full
115-decision conformance is made.
