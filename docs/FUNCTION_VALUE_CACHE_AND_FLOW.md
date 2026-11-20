# Function-value lifetime and union-flow corrections

Review base: `5f6dbc3` (2026-11-20). Generated ABI: `provider-defaults-v13`.
Specification 1.2 and the approved source syntax remain authoritative.

## What the review confirmed

The preceding five commits added inferred interface-default results, SDK and
value/mixin/protected default bridges, adapter identity, union argument wrapping
and remainder narrowing, and main's List<String> arguments. Their focused drivers
and compiler tests passed: 84 tests on the unmodified review base; analysis clean.
The historical Flutter engine/device observations remain historical evidence.
The engine SDK is unavailable in this execution workspace, so this review does
not independently repeat those live engine observations.

## Weak canonicalization without retaining application objects

The previous global identity HashMap strongly rooted every receiver and its
adapter. A cycle such as `receiver.back = receiver.measure` remained reachable
through that map even after the application dropped both objects.

The replacement stores weak references to cache slots in identity-hash buckets.
A slot contains the receiver, selected declaration, runtime specialization types
and the callable. The returned closure reads its receiver or target through the
slot; a live callable therefore keeps its required state and slot alive. When
neither is used, the slot/closure/receiver cycle has no strong cache root.
Finalizer tokens contain only the bucket hash and weak slot reference; cleanup
removes the weak reference and empty buckets. No receiver is used as a weak target,
so primitives and records do not trigger Expando's invalid-key exception.

Object receivers use identity. Function keys, including bound implicit-this and
local-function references, use Dart function equality/hashCode. Source declaration,
readonly adaptation and reified type arguments separate distinct operations.
Runtime function types preserve generic-owner specialization; outer callable
nullability is normalized because a non-null `owner?.method` denotes the same
operation as `owner.method`.

Executable regressions cover:

- Object containing int/bool/String, different receivers, and nullable access;
- int/String instantiations reached through the same generic source function,
  including a type parameter unused by the callable signature;
- separate lexical activations and implicit-this values on separate owners;
- receiver-dependent defaults evaluated at invocation, not reference creation;
- readonly/ordinary adapters, including zero-argument readonly result guards;
- awaited receivers kept outside synchronous cache-factory closures.

Readonly extension members use the existing `readonly` method modifier. Their
result views follow readonly propagation, and forbidden writes remain rejected.
This closes a parser/checker gap; it introduces no new keyword or alternative syntax.

## Actual collection evidence

`test/function_value_cache_gc_test.dart` compiles real Quds receiver/extension
code. Each workload makes 1,000 cyclic receivers, discards them, and keeps one
live callable. VM collection is requested through the VM service; JavaScript is
compiled and run in Node with `--expose-gc`, across separate event-loop turns.

| Revision | VM | JavaScript |
| --- | --- | --- |
| Original `5f6dbc3` | 0 collected; 1,001 cache entries | 0 collected; 1,001 cache entries |
| Revised cache | 1,000 collected; 1 live bucket | 1,000 collected; 1 live bucket |

The retained callable still returns 42 and is identical to another reference to
that operation. The test permits small collector timing variation and verifies
bucket cleanup as well as receiver reclamation. This is a targeted lifetime
regression, not a general memory/performance certification or a promise that
finalizers run immediately on every host.

## Sound union exits and scrutinee-specific unwrapping

```quds
classify(value: int | String, other: int | bool) -> String:
  if value is int:
    if other is int:
      return "nested"
  if value is int:
    return "fallback"
  return "s{value}"
```

An inner pattern may fail, so its conditional return does not prove that the
outer branch exits. Raising an event also continues execution. Throwing does exit.
Remainder narrowing now respects these distinctions. Programs that rely on the
previous false promotion are rejected at Quds coordinates rather than failing a
runtime cast. The current supported two-arm remainder slice is retained.

The emitter records which symbol the Dart pattern actually promotes. A pattern
on a second union no longer suppresses a necessary cast on the first union's
remainder. Existing local/imported raw-arm wrapping remains covered by its older
driver; this work does not certify all union conversions between library owners,
foreign implementors or all control-flow constructs.

## CLI follow-up

- Once the entry point is chosen, a plain argument ending in `.quds` is a program
  argument. Explicit duplicate `--target` selections remain errors.
- Flutter's generated-main guard matches only a top-level generated definition.
  A string containing `void main() {` no longer gets renamed in place of the
  actual entry point. A fake-Flutter preparation test proves this without claiming
  a new Flutter engine run.

The ABI bump rebuilds checksum-valid v12 consumers containing the old strong
cache. Tests and precise observed gates are recorded in [VALIDATION.md](VALIDATION.md).
Handoff: [LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
