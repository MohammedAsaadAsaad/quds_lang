# Collection inference and instantiated interfaces — L3.2b

This package follows [generic constraints](GENERIC_CONSTRAINTS.md) and implements
a bounded part of L3.2 in the [agent handoff](LANGUAGE_NEXT_STAGE_HANDOFF_AR.md).
It strengthens QUDS-003/012/024/035/040 under specification 1.2. It introduces
no replacement syntax and makes no claim of complete Dart generic parity.

Follow-up superclass/constructor work is documented in
[L3.2c](GENERIC_INHERITANCE.md). Limits below describe this L3.2b package.

## Collection inference

Generic function and constructor inference now traverses balanced generic
arguments, including independent Map keys/values, nested collections, nullable
types and function signatures. Iterable parameters accept List/Set element
types; native typed storage contributes its actual metadata element type.

```quds
lookup<K, V>(values: Map<K, V>, key: K) -> V? = values[key]
main():
  values = map:
    "count": 3
  selected: int? = lookup(values, "count")
  print selected
```

Each overload candidate collects type evidence across its arguments, then
checks the actual arguments against the fully instantiated parameter types.
Dependent bounds are checked against the complete substitution. Numeric scalar
arguments can join at `num`, and nullability is preserved. These joins do not
relax mutable collection reference invariance: an existing `List<int>` cannot
become `List<num>`, including through `identity<T>` or repeated `T` arguments.
The same protection applies to Map references and nested collection aliases.

Expected result types and preceding arguments can provide context for empty
literals. For example, `values: List<int> = identity([])` succeeds, as does a
later empty list after an earlier argument establishes its element type.
`identity([])` without enough context reports E302. This package does not
implement arbitrary later-to-earlier argument inference.

Map literals propagate separate expected types into their keys and values,
allowing nested empty lists and mixed nullable/nonnullable entries when their
declared type permits them. Spreads use balanced type arguments, rather than
splitting on a comma inside a function or nested type. Copying entries into a
new literal remains distinct from widening an existing collection reference.

The compiler retains inferred function type arguments for Dart emission instead
of asking Dart to infer them independently. Type substitution is simultaneous:
substituting `A -> B, B -> A` cannot cascade both into `A`. Adding `?` through a
substitution is idempotent and wraps a nullable function at the correct layer.

## Instantiated interface contracts

```quds
interface Container<T>:
  value: T
interface Group<U> extends Container<List<U>>:
  size: int
class IntGroup implements Group<int>:
  value: List<int> required
  size: int required
read(group: Group<int>) -> int = group.value[0]
```

The checker resolves the generic interface head, validates its arguments and
substitutes the actual arguments into field, property and method requirements.
It checks inherited interface requirements as well. A generic implementing
class can forward its own parameter, such as `implements Container<T>`.

Getter results and the covered fixed-arity method signatures must be compatible with the instantiated
contract. A missing method, incompatible parameter/result, static field used
as an instance getter, or a required parameter replacing an optional one is
rejected. A write-only property cannot implement a getter, and a method
cannot substitute for a getter returning a function. A writable property needs an actual setter/mutable field with the
same instantiated type; a narrower setter cannot satisfy a wider contract.
Readonly method requirements cannot be implemented by a mutating method.

Interface inheritance retains its instantiated arguments during subtype checks,
member reads and inherited method invocation. Cyclic interface inheritance is
rejected. Dart emission represents the inherited contract with `implements`
on an `abstract interface class`, including abstract getter/setter declarations.
Writes through directly instantiated generic properties/fields check the target
type and compound operation result, including rejecting integer `/=` results.

## Return blocks and conformance

The backend integration fixture exposed a parser gap in `return map:`. Return
statements now accept the existing Map/Set block literal syntax, and semantic
checking supplies the declared return type as context. An empty `return map:`
can therefore satisfy `Map<String, List<int>>` without inventing a new token or
literal spelling.

Primary Quds suites:

- `test/collection_inference.quds`: **16 declarations**, including native typed
  storage, callbacks, nullable values, contextual empties, spreads/conditionals,
  simultaneous substitution and safe numeric/nullable scalar joins and concrete nullable-argument regression coverage.
- `test/generic_interfaces.quds`: **six declarations**, covering concrete and
  generic implementers, inherited nested getter contracts, direct/inherited
  methods and writing through an instantiated setter contract.

`test/collection_interfaces_test.dart` has **29 tests**: the primary runner,
26 invalid programs, original Quds diagnostic spans, and a deterministic golden
plus generated-Dart analysis and VM/JavaScript execution. The integration
fixture verifies that source argument side effects occur once, left to right.
The previous constraint/nullability runners are included in the focused check;
see [VALIDATION.md](VALIDATION.md) for final project-wide results.

## Remaining scope

L3.2 remains partial. General expected-type constraint solving, arbitrary
argument-order inference, generic/variadic interface method combinations, multiple interface
`extends` clauses, full variance conversion, generic superclass storage and
constructor synthesis, and all nominal/prefixed external Dart metadata cases
still need independent conformance work. Generic methods required by an
interface report E910 in this package rather than claiming support. Raw and
phantom generic parameters retain existing behavior; this is not a complete
type IR. No math API or performance optimization is added here.
