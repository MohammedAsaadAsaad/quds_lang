# Awaited call operands and null-aware Quds methods

Specification 1.2, especially QUDS-010, 013, 022, 026, 102 and 111, remains the
contract. This milestone changes lowering and type checking, not source syntax.
Generated cache ABI: `provider-defaults-v9`.

```quds
later(value: int) async -> int = value
join(first: int, second: int) -> int = first * 10 + second
class Reader:
  read(first: int, second: int) -> int = first + second

main() async:
  print join(second: await later(2), first: await later(1))  // 12
  absent: Reader? = null
  result: int? = absent?.read(first: await later(1), second: await later(2))
  print result                                             // null
```

The first call evaluates `later(2)` before `later(1)`, each once. The second call
skips both operands. Its result is nullable even though `Reader.read` returns int.
Assigning that result directly to int is rejected at the Quds source span.

## Lowering contract

- A reordered local call with suspending operands captures supplied values as
  arguments to a typed synchronous closure. `await` stays in the caller's scope.
  Computed defaults run in the closure after the supplied values are available.
- Supported provider-default calls likewise capture the receiver first and then
  all written operands in source order. Private defaults remain in the provider.
  Earlier packet/gap adapters keep the same two-phase evaluation contract.
- Automatic field constructors with several supplied values use this capture
  path when operands suspend, preserving source order before field arrangement.
- A null-aware Quds method call captures its receiver in a Dart switch expression.
  The non-null pattern arm emits the invocation; the null arm returns null without
  evaluating supplied operands, defaults or the method body. No async wrapper,
  hoisted shared mutable temporary, reflection or runtime registry is introduced.
- Future results, including Future<void>, remain Future values. Synchronous void
  calls remain valid expression statements. A failed awaited operand prevents
  later operands, defaults and the target body from running.
- Existing non-suspending lowering stays in place where possible. Constant
  contexts are unchanged. Await outside an async scope is still rejected.
- ABI v9 invalidates v8 and older generated caches, including otherwise valid
  output checksums. It is independent of the language specification version.

## Evidence and limits

`test/call_suspension.quds` has ten executable Quds tests, including local and
imported calls, nullable receivers, complete and gap calls, receiver suspension,
readonly views, synchronous/async void, default side effects and failure order.
`test/call_suspension_web.quds` and its golden are analyzed and actually executed
on Dart VM and JavaScript/Node with the same 24 output lines. The Dart driver adds
source-coordinate rejection checks and valid-checksum v8-cache migration.

This does not certify all callable-property, native nullable API, partial
application, generator or awaiting-default combinations. Existing native-call
adapters retain their separate signature rules. Generic/polymorphic callback
constraints and the remaining explicit E910 boundaries still need their own
conformance work. Flutter engine/device/F5 verification and cross-host CI are
separate gates. Passing this slice does not complete all 115 decisions.

Exact observed results: [VALIDATION.md](VALIDATION.md). Next-agent handoff:
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
