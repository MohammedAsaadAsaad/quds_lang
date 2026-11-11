# Language design status

Quds 1.2 closes the language design. The grammar, the single meaning of each token, evaluation order, the Dart 3.13 parity table, the project layout, the diagnostic registry, the source-map encoding, and the macro sandbox are in `QUDS_LANGUAGE_SPECIFICATION.md`. They are not an invitation to add a second rule.

The resolutions that used to be listed here as open questions now live in that file:

- Named-argument blocks are all-label blocks. `map:` and `set:` are collections. Any other legal argument block is a collection-element block. `test` and `group` are declarations, so a test body is not a collection.
- Bare `name = expr` assigns a visible mutable binding, rejects a visible immutable binding, and otherwise declares an immutable binding. A same-name local is `shadow` or `shadow var`.
- `readonly` qualifies one reference. `to` converts. `to?` converts safely, including to a nullable target.
- Omission is `missing`. Overloads are compile-time and lower to mangled Dart names. Defaults run after supplied arguments, in declaration order.
- `return` exits a function. `result` finishes `do:`. Postfix `?` propagates `Result`. Prefix `?` on a collection element omits null. Dot shorthand is `.member` and `.new`.
- Records, holes, ranges, `with`, and `capture` keep the meanings in the token table.
- Null-aware elements, dot shorthands, private named parameters, and primary constructors are available through the spellings in the parity table.

A program that can be parsed in two ways is a compiler bug or a required rejection.

## What the current compiler still does not implement

The language rules above are settled. `MVP_0.md` lists the slice that compiles and runs. These design rules are still rejected instead of being given a meaning:

- Spreads `...` and `...?`, and `if` / `for` elements inside `[]`, `map:`, and `set:`. Collection-element blocks do accept `if` and `for`.
- `await for`, enums, mixins, extensions, generators, `try` / `catch`, `late`, `state`, and `computed`.
- A runtime error for a non-constant loop step of zero. A constant step of zero is `E801`.
- Match expressions. Statement `match` warns `W001` and rejects an unreachable arm with `E313`.
- The full `E` / `W` registry. New errors from this slice use their registry codes. Older diagnostics still use `Q100` and `Q200`.
- Web numeric behavior has not been executed in CI.

`do` / `result`, `readonly`, `capture`, `to` / `to?`, `with` / `with?`, general unions, dot shorthands, null-aware elements, `test` / `group`, collection-element blocks, C-style `for`, and `repeat` / `while` are implemented and covered by `test/language_test.dart`.
