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
  Web integer guarantees and spelling the minimum signed integer literal remain
  follow-up work. No cross-platform numeric guarantee is inferred from native tests.

Implementation gaps (rather than syntax decisions): parser recovery, source maps,
Quds-side constant evaluation with source diagnostics, and contextual inference
are not complete. The supported subset and further deferred features are listed
in `MVP_0.md`. Original questions above remain open beyond these scoped choices.
