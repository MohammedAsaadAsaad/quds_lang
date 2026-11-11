# Questions to resolve in formal specification

Specification 1.1-draft in `QUDS_LANGUAGE_SPECIFICATION.md` resolves the logical conflicts below. Do not treat this list as permission to invent a second rule.

1. **Named argument syntax:** A block is a named-argument block only when every row is an identifier label. `map:` / `set:` are collections. Any other argument block is a collection-element block. Classification does not use the expected type.
2. **Binding vs assignment:** Bare `name = expr` assigns a visible mutable binding, errors on a visible immutable binding, and otherwise declares an immutable binding. A new same-name local is `shadow`, or `shadow var` when the new local must be mutable.
3. **Readonly:** `readonly` qualifies the reference and its nested uses through that reference. Other aliases may mutate. Dart APIs that cannot express this get a Quds checker error plus a boundary check. The VM is not claimed to track readonly.
4. **Conversion:** Explicit conversion is `to`. Safe conversion is the token `to?`. Nullable targets stay `Type?`, so `to? int?` is safe conversion to a nullable int.
5. **Optional/missing:** Omission is `missing`, not null. `copyWith` and defaults use that distinction. Generated Dart exposes the sentinel as `quds.missing`.
6. **Overloading:** Compile-time only. Ambiguity is an error. Each overload lowers to a stable Dart name (`name` or `name$...`). Tear-offs must select one signature.
7. **Defaults:** Supplied arguments run once in source order, then omitted defaults run once in declaration order. A default may read earlier parameters only.
8. **Pipeline:** `|>` is left-associative above assignment. A bare callee receives the value as its first positional argument. A call with one hole receives the value in that hole.
9. **ADTs and Result:** `sealed type` cases and `sealed class` subtypes share one exhaustiveness checker. Postfix `?` in expression position propagates `Result`. `switch` is an alias of `match`.
10. **Records:** `(expr)` groups. `(expr,)` is a one-field record. Named fields and patterns use the same parentheses. Inside a call, `name:` is an argument.
11. **Functions:** `return` exits the function. `result` finishes `do:` only. A bare name is a tear-off. Zero-argument calls use parentheses. Function types exist in type position; lambdas exist in expression position. `capture` is a keyword.
12. **Numeric types:** Hex, scientific notation, digit separators, bitwise operators, shifts, and `~/` use Dart's values. Web and native widths follow the target Dart SDK; Quds does not invent a third numeric tower.
13. **Variadic functions:** `[name: Type = default]` is optional positional. `...values: Type` is variadic. `...` spreads. `...?` is the null-aware spread. An exact fixed signature beats a variadic signature when both match.
14. **Compiler compatibility:** The language version is whatever the project declares (QUDS-068). Generated behavior follows the target Dart SDK's own rules for numbers, generics, privacy, and asynchrony.

Engineering specifications still open, without permission to contradict the resolutions above: macro sandbox limits, diagnostic code numbers, package directory layout, and source-map encoding.

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
