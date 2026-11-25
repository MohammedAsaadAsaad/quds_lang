# Checked union exchange between Quds libraries

This is an incremental implementation of QUDS-094, on top of `20949f6`.
It preserves specification 1.2 syntax and the existing sealed Dart representation.
The generated ABI is `provider-defaults-v14`. It is not a claim that all union,
callback or Dart interoperability combinations are complete.

## Reproduced defect

Two libraries each generated their own `QudsUnion_int_or_String`. Dart treats
these as different nominal types. Passing a stored Quds union to an imported
function, or assigning its union result locally, failed during Dart compilation.
Returning a raw arm from a union-returning function also produced invalid Dart.

## Supported contract

A public, synchronous, non-generic top-level function may take and return direct
unions of primitive and nominal non-generic types. This includes ordinary calls,
stored callable values, computed defaults, prefix/unprefixed imports, filtered
`show` imports and filtered re-exports. An inferred result is supported when an
explicit union parameter already identifies the function's boundary contract.

```quds
# provider.quds
class Payload:
  value: int required
identity(value: int | String) -> int | String = value
produce() -> Payload | String = Payload(value: 12)

# main.quds
use provider as api
main():
  held: int | String = 3
  saved = api.identity
  result: int | String = saved(held)
  print api.identity(result) is int
```

Each original Dart function retains its typed sealed signature. Its generated
reserved `$QudsUnionCall…` bridge accepts signature-order payload/presence packets.
The provider checks each supplied union payload, wraps it in its own family,
resolves omitted defaults in declaration scope, and invokes the original function.
The bridge returns a union result's payload; the caller validates and wraps it in
its own family. Invalid foreign payloads throw `ArgumentError` before entering the
original typed function. There is no reflective overload dispatch or `dynamic`
union representation. Normal non-union signatures retain their existing lowering.

The sealed base exposes `Object? get value`, with covariant typed getters in each
arm. A checked factory chooses a declared arm; `int` fits a declared `num` arm.
Union-to-union assignment checks every source arm against the destination union,
then converts the wrapper once if the families differ. The same expected-type
coercion covers bindings, assignments, defaults and returns. `is`/`as` expressions
with an arm target on a direct union inspect its payload. Narrowed reads and patterns render imported
nominal identities through the same backend type mapping as declarations.

A call captures its target before its written arguments, from left to right,
exactly once. Awaited arguments remain in the original async context. Packet
slots are reordered only after operand evaluation. Defaults run in the provider,
so private helpers are never copied into the consumer. Explicit null is distinct
from an omitted argument.

Stored adapters keep the source function signature and omission behavior. They
use the existing weak-slot cache, keyed by provider bridge function equality and
local signature/readonly contract. Repeated references through a re-export retain
identity. A live adapter retains its cache slot; the cache does not become a new
strong receiver root. ABI v14 invalidates otherwise checksum-valid v13 output.

## Evidence

- `test/union_exchange.quds`: eight Quds execution cases, including stored unions,
  union results, reassignment, defaults, function identity, provider-owned objects,
  inferred results, narrowing an inferred imported nominal union, and an unsupported
  overload candidate that must not block a different valid overload.
- `test/union_exchange_web.quds`: deterministic golden; strict generated Dart
  analysis and actual VM/JavaScript execution. Covers a second consumer library,
  `show` re-export, reordered named arguments, side effects and awaited arguments.
- `test/union_exchange_test.dart`: positive and negative source diagnostics,
  reserved-bridge rejection of an invalid foreign payload, and a checksum-valid
  legacy-output cache upgrade.
- Existing union-flow and union-boundary golden/VM/JS tests remain required.

The portable CI matrix now selects all three union drivers on Linux, Windows
and macOS. This configuration is not evidence that those remote runs passed.
Exact final commands and results are recorded at the top of `VALIDATION.md`.

## Expanded certified slice (aliases, async, partial application)

Building on ABI `provider-defaults-v16`, the checked union boundary also certifies:

- **Local union type aliases**: top-level functions referencing local aliases such as `type Choice = int | String` (including `if is`, `guard is`, and `match` narrowing on alias-typed parameters).
- **Async union signatures**: `async` top-level functions taking union parameters and returning `Future<T>` or `Future<A | B>`, with checked `async` `$QudsUnionCall…` bridges that reject invalid foreign payloads before invoking the provider and validate/wrap resolved union values on the consumer side.
- **Imported union partial application**: placeholder expressions such as `api.describeAlias(_)`, `api.combine(_, expr)`, and `api.asyncEcho(_)` lowered through the checked union bridge while preserving left-to-right, once-only evaluation of bound arguments.

Additional evidence:
- `test/fixtures/union_exchange/expanded.quds`
- `test/union_exchange_expanded.quds`
- `test/union_exchange_expanded_test.dart` (Quds execution, strict generated Dart analysis, VM/JS parity, and invalid foreign payload rejection on the async bridge).

## Limits and next work

Imported generic functions, nested unions (such as `List<int | String>`), union
callbacks, variadics/mixed packet layouts, intersections combined with this ABI,
and class/interface union boundaries are not certified by this slice.
The tested unsupported top-level call/value contracts produce Quds `E910`
rather than being advertised as working. Foreign Dart implementors and
conditional/section/part/cycle export combinations need separate conformance.

