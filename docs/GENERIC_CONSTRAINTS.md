# Generic application constraints — L3.2a

This is the first bounded package of L3.2 from
[the execution handoff](LANGUAGE_NEXT_STAGE_HANDOFF_AR.md), following function
nullability in L3.1. It strengthens existing QUDS-024/040 syntax and semantics;
it does not change the approved language design.

Follow-up collection inference and instantiated interface work is implemented
in [L3.2b](COLLECTION_INFERENCE_INTERFACES.md). The limits below describe this
L3.2a package; consult the follow-up for the current expanded subset.

## Confirmed defects and resulting behavior

Before this package, a Quds class type annotation such as `Box<int, String>`
could pass with a class declaring one parameter. `Numeric<String>` could pass
in an annotation despite `class Numeric<T: num>`. Conversely, a valid explicit
`Pair<num, int>` failed against `class Pair<A, B: A>` because the checker compared
`int` against the unsubstituted name `A`.

A common checker now validates the argument count, validates each argument as
a type, builds the substitution and checks each instantiated bound. It is used
for Quds class type annotations, explicit function calls and explicit or inferred
constructor calls. Inferred constructor bounds are checked after collecting all
arguments, so a bound can refer to another parameter.

```quds
class Pair<A, B: A>:
  first: A required
  second: B required

pick<A, B: A>(first: A, second: B) -> B = second

main():
  pair = Pair<num, int>(first: 1.5, second: 2)
  selected: int = pick<num, int>(1.5, 4)
  print pair.second
  print selected
```

`Pair<int, String>` is rejected. So are extra type arguments on a nongeneric
Quds class, unknown types in explicit generic applications, and nullable
arguments where the bound is nonnullable, including nullable implementing
classes passed to a nonnullable interface bound. Invalid type applications are rejected
in parameter/return declarations, fields, used aliases and bindings, even when
no constructor is called. These report the existing Quds diagnostics at the
original source location; no new diagnostic codes are introduced.

## Generic callers and Dart generation

The checker retains evidence about bounds of an enclosing generic parameter:

```quds
identity<T: num>(value: T) -> T = value
forward<U: num>(value: U) -> U = identity<U>(value)
```

`U` is justified by its bound `num`. Bound evidence is scoped during declaration
validation and function analysis; an unbounded method parameter cannot inherit
a same-named class parameter's bound. Explicit function arguments are carried
into return-type inference, instead of being spuriously considered uninferred.

The emitter now preserves explicit function type arguments, for example
`pick<num, int>(...)`. Dropping them and letting Dart infer again can pick
`double` from the first literal and reject the second `int` despite a valid
explicit Quds call. Both the VM and JavaScript fixture exercise that distinction.
Argument evaluation remains once, in source order, including side effects.

## Coverage and limits

Primary suite: [generic_constraints.quds](../test/generic_constraints.quds),
**nine executable declarations**. It covers explicit/inferred constructors,
dependent bounds, explicit generic functions, generic forwarding, nested bounded
fields, a non-generic interface bound, nullable numeric bounds, and nullable/nonnullable interface bounds.

The companion runner has **25 tests**: the Quds suite, 22 invalid programs,
original diagnostic coordinates, and deterministic golden output plus generated
Dart analysis and execution on VM/JavaScript. The backend fixture also exercises
a nested `List<Map<String, Numeric<int>>>`. See [VALIDATION.md](VALIDATION.md)
for the final complete-project test result.

L3.2 remains partial. This package does not expand Map/callback inference,
contextual empty literals, generic interface/superclass substitution, external
Dart generic metadata, or general variance support. Inferred generic function
calls with dependent bounds and all combinations of nominal identities across
libraries still require their own matrices. Raw generic types retain existing
behavior. This is not a proof of support for every F-bound or cyclic declaration.
Existing mutable-list invariance is retained and tested; no math API was added.

The L3.2b follow-up is now documented in
[collection inference and instantiated interfaces](COLLECTION_INFERENCE_INTERFACES.md).
Continue from the latest handoff entry rather than repeating the completed
constraint or collection packages. Keep the same acceptance gate: positive and
negative Quds programs, generated Dart verification, full project tests,
documentation, then an incremental push to main.
