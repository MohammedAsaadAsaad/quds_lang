# Language foundations for numerical libraries

The compiler work precedes further math expansion. This ledger distinguishes
implemented compiler support from the remaining foundation work; it does not
change Quds 1.2 syntax or the approved language decisions.

## Delivery 1: indexed mutation

Lists and maps now support indexed assignment statements. The existing
assignment tokens apply: `=`, `+=`, `-=`, `*=`, `/=` and `??=`. Operand types
must make the selected operation valid and its result assignable to the stored
element type. A list's negative index counts from its end; a negative map key
remains an ordinary key. Strings and unsupported indexable types cannot be
written through this feature.

```quds
main():
  matrix = [[1, 2], [3, 4]]
  alias = matrix[0]
  matrix[0][-1] *= 3
  print alias[1] # 6: immutable bindings still refer to mutable objects

  counts: Map<String, int> = map:
  counts["visits"] ??= 0
  counts["visits"] = (counts["visits"] ?? 0) + 1
```

Receiver and index expressions run once, in source order, before the value.
Nested targets preserve the same order. List negative-index normalization
captures the target position before the RHS executes. Compound updates read
the old element before evaluating the RHS. `??=` evaluates the RHS only if the
lookup is null. Map-joining `+=` on a list element uses the same collection-join
semantics as binary map addition, including right-hand replacement of keys.
The emitted block keeps `await` in the surrounding async function. `Result`
propagation on the RHS exits before performing the write.

Indexing a `Map<K,V>` has nullable result `V?`, consistent with Dart: a key can
be absent even when stored values are non-nullable. Nested generic/record map
key types are split structurally. A write is checked against stored `V`, not
against lookup `V?`. Consequently `counts[key] += 1` is rejected because its
read may be null; use an explicit fallback as above. `??=` can insert into an
absent map key. Nullable list slots support `??=`, including nullable RHS values.
Out-of-range list writes retain Dart's runtime range errors.

The compiler rejects mutation through a readonly reference, including nested
paths. Reads of instance fields and `this` in a readonly method also preserve
readonly qualification, so borrowing a local alias does not bypass the rule.
An independent mutable alias remains mutable, as QUDS-092/093 require.

Expected list element types are now passed to element expressions. Annotated
nullable and nested lists such as `List<List<int?>> = [[], [null, 2]]` retain
those types. This contextual literal inference does not make existing
`List<int>` references assignable to `List<num>`.

Source spans are retained on the new typed AST statement, and AST walking,
source maps and Result-propagation discovery visit its target and value.
Invalid writes report diagnostics in the original Quds source.

### Verification

Primary behavior assertions live in `test/index_assignment.quds`, with ten
native Quds declarations. They cover shared aliases, matrix updates, negative
indices, map keys and absent lookups, compound collection/user operations,
lazy defaults, range errors, await order, Result propagation and nested
nullable list typing.

`test/index_assignment_test.dart` launches the Quds suite and checks negative
compiler cases and diagnostic spans. `test/index_assignment_web.quds` is
compiled to JavaScript and executed with Node to check the same backend
semantics. Commands and final observed results are in [VALIDATION.md](VALIDATION.md).

## Delivery 2: native typed storage

Implemented the concrete numeric storage bridge in `quds:core::typed`, also
available from `quds:core`. Float32/64 and signed/unsigned 8/16/32-bit arrays,
clamped bytes, ByteData, ByteBuffer, TypedData and Endian keep their Dart names.
Copies, shared views, byte offsets, readonly runtime guards, source-visible
native identities, generic Quds containers and existing List<double> math calls
are covered by executable Quds tests and VM/JavaScript interoperability checks.
See [CORE_TYPED_STORAGE.md](CORE_TYPED_STORAGE.md) for the exact scope and limits.

## Next foundation deliveries

1. **Storage follow-up.** Concrete native storage and contiguous shared views
   are delivered above. Strided/multidimensional storage, broader external
   generic interfaces and performance measurements remain separate milestones.
2. **Complete collection/type conformance.** Expand contextual inference,
   generic constraints, imported nominal types, nullable access and readonly
   boundaries using executable Quds programs. Keep invariant mutable collection
   parameters and explicitly supported interface conversions.
3. **Numeric/platform contracts.** Test VM/JS integer limits, explicit exact to
   approximate conversions, and failure behavior. Do not silently reinterpret
   an int or lose BigInt/decimal precision.
4. **Compiler lowering and measurement.** Introduce the planned typed lowering
   stages incrementally. Add reproducible compile/runtime/memory benchmarks;
   preserve evaluation order and original source spans through each stage.
5. **Optional high-performance backends.** Evaluate native and web numerical
   interop only after buffers and benchmarks establish the required contract.
   A native dependency must not become a prerequisite for basic web math.

These are implementation milestones, not completed features. Each delivery
ships Quds conformance, relevant rejection/runtime/backend tests, documented
limits and a tested incremental push to main.
