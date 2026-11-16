# Generic methods and interface contracts — L3.2d

This package extends [generic inheritance](GENERIC_INHERITANCE.md) without
changing specification 1.2 or the approved generic syntax.

```quds
interface Transformer:
  transform<T>(value: T) -> T = value
class Identity implements Transformer:
  transform<U>(value: U) -> U = value
main():
  value: Transformer = Identity()
  print value.transform<int>(3)
  inferred: String = value.transform("Quds")
  print inferred
```

Method type parameters are local to the method. Contract checking renames both
signatures to fresh shared parameters, independently of class substitutions.
Different parameter names are equivalent; different ranks or bounds are not.
Dependent bounds and covariant returns are checked using the declared evidence,
without treating two unrelated type parameters as interchangeable. Parameters
are contravariant; results are covariant. Static, readonly, default and variadic
obligations remain part of the contract. Superclass overrides use the same check.

Instance and static Quds methods support explicit arguments and inference from
arguments and expected results. Inherited class arguments specialize method
parameters, results and bounds. A method parameter shadows a same-named class
parameter. Nullable results remain nullable. Invalid arguments, bounds and
unsafe generic bodies are rejected at original Quds source spans. Bare cyclic
bounds are rejected; this is not a ban on structured F-bounds.

Emission retains the original call identity and instantiated parameter types.
For reordered named arguments the receiver runs first, once, then arguments
run in source order. Partial calls retain their lazy evaluation behavior.
Typed variadics use instantiated element types in generated Dart.

The stricter bound checks also exposed concrete nullable-container signatures:
`remove`/`contains`/`containsKey` accept `Object?`, while `List.indexOf` accepts
its element type. Completion metadata matches semantic checking. Inference
checks concrete nullable targets as whole types instead of peeling their shell
and accidentally rejecting an unbounded generic value.

Validation includes 16 executable Quds test declarations, 26 negative programs,
a source-span check, and a deterministic Dart golden analyzed and executed on
Dart VM and JavaScript/Node. Exact commands and final results are recorded in
[VALIDATION.md](VALIDATION.md).

Explicit generic native/collection methods outside this Quds-method path remain
E910 pending their own metadata and conformance package. This does not claim
complete generic Dart interop, mixin semantics, or every higher-rank function
assignment. Existing raw-superclass and constructor limits still apply.
