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
