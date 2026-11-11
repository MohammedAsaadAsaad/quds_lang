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

The language rules above are settled. The MVP-0 compiler is a smaller subset. Its limits are implementation gaps, not competing language rules. See `MVP_0.md`.

- Named-argument blocks in the compiler are `label: expression` rows only. The specification's collection-block test is not implemented yet.
- `shadow var` is specified and not implemented. The compiler's `shadow` binding is immutable.
- Parenthesis-free calls in the compiler take one positional argument. The specification's zero-argument and named-block rules are only partly implemented.
- The compiler evaluates the native Dart 3.13.7 integer and double operators. Web numeric behavior is the target SDK's behavior and has not been executed in CI.
- Prefix `+` is specified as numeric identity because Dart has no prefix `+`. The compiler lowers it that way.
- String interpolation is not a constant expression, matching Dart. The specification does not add a special const-interpolation rule.
- Const bool conditions are lowered through `_qBool` so generated Dart does not report `dead_code`. That lowering is an emitter detail, not a change to Quds boolean values.
- Top-level const initializers see earlier consts only. Function bodies see every top-level const. Const constructors wait on classes.
- Design 1.2 beyond that subset, including classes, patterns, unions, macros, source maps, and the `E` / `W` diagnostic registry, is not implemented. Unsupported syntax is a future `E910`, not a new language rule.
