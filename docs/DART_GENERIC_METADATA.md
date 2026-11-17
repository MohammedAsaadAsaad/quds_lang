# Native Dart generic metadata — execution plan

This is the next package after READONLY_CLASSES. It preserves approved Quds
calls and generic syntax; Dart remains the backend ABI.

The current importer simplifies native formal parameters to bounds, defaults an
unbounded parameter to num, and drops some generic class arguments. That loses
information before type checking. The correction must retain class/method
formal parameters and bounds, parameter names and named/optional layout, and
instantiated superclass edges. An inherited Base<List<U>> member must be checked
as List<int> through Derived<int>, not as a raw head or a numeric placeholder.

Implementation order and review gates:

1. Extend DartTop/DartMember/DartShape metadata without replacing their source
   locations. Preserve bounds and method-local variable shadowing.
2. Instantiate each superclass edge and specialize members at the receiver;
   retain both nominal heads and actual supertype arguments for subtyping.
3. Check explicit/inferred native function, constructor and method calls. Check
   generic arity and bounds at original Quds spans; infer through nested generic
   containers and ordinary positional callbacks.
4. Preserve Dart's positional/named ABI while accepting Quds unified calls. If
   arguments must be rearranged, evaluate the receiver then written arguments
   exactly once, left to right. Never manufacture Dart default expressions.
5. Add native fixtures split across Dart files and primary .quds conformance,
   negative arity/bound/type/named cases, deterministic output and VM/JS runs.
6. Re-run format/analyze/the entire suite, document unsupported signatures
   explicitly, and push the completed package to main.

This file records intended work, not an implementation or validation claim.
