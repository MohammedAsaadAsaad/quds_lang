# MVP-0 supported subset

This implements Issue #1's first compiler slice. The approved decisions are not
replaced by this document. Syntax outside this subset is deferred, not removed
from the language. Lexer, parser and semantic failures carry stable category
codes Q001, Q100 and Q200 with original file, line and column. Tokens and AST
nodes retain source spans; there are no generated-Dart source maps yet.

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
integer guarantees remain open; web compilation is not validated.

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

Modules currently contain only function declarations. Functions accept typed,
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
requires a structurally constant initializer. Constant arithmetic errors are
currently diagnosed by Dart tooling on the generated file; evaluating them in
Quds with mapped diagnostics remains follow-up work. Typed declarations use `name: Type = value`.
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

## Dart output and remaining work (033, 063, 085, 114)

Emission is deterministic and uses unique Dart names to avoid keyword/internal
name collisions. The golden fixture records exact output; integration tests
analyze and execute it. `quds build` is the only CLI command implemented. Public
Dart-facing wrappers, imports and dependencies in Quds, arbitrary Dart interop,
source maps, error recovery and runtime stack remapping remain future work.

QUDS-082–089 advanced conversions/Optional/defaults/overloads/variadics,
091–092 capture/readonly, and 094–115 provisional advanced features are not
implemented by this slice. Classes, maps/sets/records, lambdas, generics beyond
`List<T>`, patterns, concurrency, macros and tooling beyond build are also deferred.
No claim of full 115-decision conformance is made.
