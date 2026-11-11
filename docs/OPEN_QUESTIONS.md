# Questions to resolve in formal specification

1. **Named argument syntax:** `send("Hello"):\n  to: "..."` and `Column:\n  children:\n    Text "..."` need a grammar distinguishing named-argument blocks, property configuration, and child expression sequences.
2. **Binding vs assignment:** `name = value` both declares and reassigns in some contexts. Formalize symbol lookup and shadowing without ambiguous references in initializers.
3. **Readonly:** define transitive readonly view semantics and how external Dart mutating methods are classified.
4. **Conversion:** `to Type?` safe conversion vs nullable target type; define lexical grammar and null handling precisely.
5. **Optional/missing:** avoid collisions between omitted arguments, nullable values, defaults, and named-parameter overloading.
6. **Overloading:** resolve subtype specificity, named arguments, variadics, generic inference, tear-offs, and Dart-facing API naming.
7. **Defaults:** exact evaluation order when caller supplies named arguments out of declaration order; side effects and dependency on earlier parameters.
8. **Pipeline:** syntax for passing into multi-argument functions and method receivers; precedence.
9. **ADTs and Result:** choose generated Dart representation, exhaustiveness, error propagation and naming.
10. **Records/maps destructuring:** ensure unambiguous punctuation and runtime behavior for missing keys.
11. **Functions:** decide consistent parsing of indentation-based lambda bodies and return type annotations.
12. **Numeric types:** precise Dart int/double/num rules, especially cross-platform web semantics.
13. **Variadic functions:** positional/named boundary and spread semantics with overload resolution.
14. **Compiler compatibility:** specify Quds versioning and Dart SDK constraints.

These are specification questions, not permission to override approved design choices. Propose precise resolutions with tests before implementation.

## MVP-0 scoped resolutions and remaining conflicts

- **Questions 1/11:** Issue #1 supplies `sum(a: int, b: int) -> int:`.
  MVP-0 uses that return annotation and `= expression` bodies. Named argument
  blocks currently contain only `label: expression` rows on a call statement or
  binding RHS. Child expression sequences and property configuration still need
  reconciliation; accepting this subset does not decide their grammar.
- **Question 2 / QUDS-090:** Initializers resolve before declaring a new symbol.
  Bare assignment targets an existing visible mutable binding; otherwise it
  declares a final binding. `shadow` explicitly introduces a final binding in an
  inner scope; typed/var redeclarations cannot implicitly shadow. Supporting
  mutable explicit shadows (`shadow var` or another spelling) remains open.
- **Simple calls / QUDS-081:** MVP-0 supports one parenthesis-free argument and
  right-nested simple calls. Use parentheses for multiple arguments and unary
  arguments (`print(-1)`). Precedence between unary/binary operations and more
  general optional-parenthesis calls needs normative specification before expansion.
- **Question 12:** This slice targets native Dart integers/doubles. It rejects
  oversized positive integer literals rather than converting them to doubles.
  Const arithmetic uses native Dart 3.13.7 `int` operators, which wrap at
  signed 64 bits. Web integers remain unvalidated, and no cross-platform
  numeric guarantee is inferred from native tests. Quds spells a leading minus
  as unary `-`, and `int.tryParse` rejects `9223372036854775808`, so the
  minimum signed 64-bit value still cannot be written as one literal. It can
  be computed, for example `9223372036854775807 + 1`. No separate lexical
  exception was added.
- **Unary `+`:** MVP-0 accepts prefix `+`, but Dart has no prefix `+`, so
  emitting it produces invalid Dart. It is lowered as numeric identity,
  including the sign of zero. This does not add an operator Dart lacks.
- **Const interpolation:** an interpolation whose parts are all literals is
  reduced to one string literal by the parser. Other interpolations, including
  references to const bindings, are not constants. That matches Dart, where
  string interpolation is not a constant expression. A later Quds rule for
  const interpolation is not specified here.
- **Const bool conditions:** Dart reports `dead_code` for a const or literal
  bool used directly in `if` or `&&`/`||`, including a local Dart can prove is
  that bool. Emitting the condition unchanged makes valid Quds fail `dart
  analyze`. The emitter passes those bool leaves through `_qBool`, an identity
  function, so the generated condition is not a Dart constant. This does not
  change the value, the single read, or which side of `and`/`or` runs. Const
  initializers stay Dart constants and do not call `_qBool`.
- **Top-level const visibility:** initializers see only earlier consts, so a
  forward or cyclic reference is an error. Function bodies see every top-level
  const, including one written later, consistent with function visibility in
  this slice. Const constructors remain deferred with classes.

Implementation gaps (rather than syntax decisions): parser recovery, source
maps, and contextual inference are not complete. Const evaluation of the MVP-0
expression subset, with Q200 diagnostics in original `.quds` coordinates, is
implemented; const forms outside that subset are not. The supported subset and
further deferred features are listed in `MVP_0.md`. Original questions above
remain open beyond these scoped choices.
