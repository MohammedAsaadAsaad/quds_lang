# Native Dart generic metadata

This package follows READONLY_CLASSES and preserves approved Quds generic and
unified-call syntax. Dart remains the backend ABI. The original execution plan
is retained in git history; this file describes the resulting implementation.

The importer previously replaced native formal variables with their bounds,
defaulted unbounded variables to num, and erased some class arguments. It now
retains class/method formals and bounds, parameter names, named/optional layout,
and instantiated superclass edges. Source file/line/column/offset metadata is
preserved. Hover signatures display retained generic parameters.

```quds
use "fixtures/dart_generics/api.dart"
owner = NativeChild<int>([1, 2])
parent: NativeParent<List<int>> = owner
value: String = owner.identity<String>("typed")
```

## Instantiation and nominal identity

Members of `Derived<U> extends Base<List<U>>` retain List<U> until the receiver
is instantiated, then become List<int> through Derived<int>. Method-local
formals shadow class formals rather than being substituted as class variables.
Subtype checks retain actual generic supertype arguments. Mixin implementation
signatures override earlier superclass/mixin signatures in Dart order;
interfaces supply fallback signatures, and `on` constraints are not invented
as nominal supertypes.

Local/package Dart classes have declaration identities independent of caller
names and import prefixes. Re-exporting the same declaration through another
file retains its identity. A same-named Quds class cannot impersonate it. Within
a package, generated alias hashes use package identity plus declaration-relative
path, not checkout location. Backend imports use original declaration URIs;
existing temporary-module staging preserves access to those Dart files.

Nongeneric shapes reuse their immutable metadata. Generic instantiated shapes
are cached within one analyzer, keyed by the resolved nonnullable receiver type;
no process-wide cache retains individual compilation models.

## Calls and defaults

Direct native function, constructor and instance-method calls support explicit
and inferred generic arguments, arity/bound checking and inference through
nested containers and ordinary positional callbacks. A declared constructor
result supplies context for an empty list argument. Initializing-formal types
are resolved after fields have been read, including fields declared after the
constructor. Implicit accessible constructors are represented; abstract classes
without a callable unnamed constructor are rejected.

Quds unified arguments map to Dart's positional/named ABI. When a rearrangement
is needed, a typed immediate closure receives the receiver first and written
arguments in their original order, each once. Await operands stay outside that
closure in their original async scope. Future results are not accidentally
flattened. The runtime tests exercise a receiver with effects, reordered effectful
arguments, and awaited arguments to a Future-returning native function.

Omitted Dart arguments stay omitted. No default expression is manufactured or
copied from native source. A sentinel default therefore stays distinguishable
from an explicitly supplied null. Omitting an earlier optional positional value
while supplying a later one requires the earlier value explicitly (E910), since
the importer does not execute or duplicate Dart defaults.

## Validation and scope

Primary suites: dart_generics.quds (seven declarations) and
 dart_generics_prefix.quds (one). The driver adds invalid arity/bound/argument/
constructor/tear-off/signature programs at original Quds coordinates, a nominal
identity rejection, normalized deterministic golden output, actual Dart analysis,
and VM/JavaScript execution. The golden normalizes only the checkout URI; it
keeps generated type arguments, calls, order and stable aliases intact.

This is direct-call conformance, not complete Dart-language parity. Unsupported
record signatures and generic, optional or named callback signatures report E910
rather than being guessed as dynamic. Native generic/optional/named function
tear-offs retain explicit limits. Required-positional native function and method
values (including zero arguments, static/bound receivers, generic-class
substitution and null-aware access) are now supported; generic methods and
optional/named method values still report E910. Bound receivers are captured once.
`test/native_function_values.quds` is the primary executable suite, supplemented
by generated Dart analysis and VM/JavaScript execution. Typedef,
record, extension-type, recursive instantiate-to-bound and every possible
foreign-source grammar combination are not claimed complete. Unknown package
APIs retain the existing dynamic interop path; it is not a static safety promise.
Readonly native final/sealed classes retain the limits in READONLY_CLASSES.

Exact final commands and counts are recorded in VALIDATION.md.


## Function-value metadata follow-up — 2026-11-18

Native non-generic function and method values now preserve optional positional
and required/optional named parameters, including nested native callback types.
Structural annotations use the approved parameter grammar, for example
`([value: int = 0]) -> int` and `(value: int required) -> int`.
A default in a function type records optionality; it does not replace the
underlying callable's default. Native defaults execute in Dart when omitted;
explicit null remains explicit null. Function subtyping checks parameter kinds,
labels, omission and contravariance. Reordered calls capture the callable and
arguments exactly once in source order. Earlier optional/named limitations in
this document are superseded for this slice. Generic function values, richer
record signatures and full Quds declaration/lambda parameter-form parity remain
unfinished. Tests: native_function_values.quds (eight declarations), fourteen
negative cases, deterministic Dart golden, actual Dart analysis and VM/JS runs.


## Explicit native generic function values — 2026-11-18

A native function can now be instantiated before storing or passing its value:

```quds
use dart:math as math

main():
  larger = math.max<int>
  print larger(3, 7)
```

The same path supports imported unprefixed functions, prefixed functions,
static methods and bound methods, including methods on generic classes. Every
explicit type argument is validated against arity and substituted bounds before
the required/optional/named function signature is constructed. A bound receiver
is evaluated once. A nullable receiver's `?.method<Type>` is emitted through a
single receiver capture and null branch, because Dart cannot instantiate the
nullable generic function value directly.

`test/native_function_values.quds` now has ten declarations. Negative fixtures
check invalid bounds/arity, applying arguments to a non-generic function, wrong
call arguments and incompatible annotations. The Dart golden and VM/JavaScript
program cover specialization and nullable bound methods too.

This does not implement polymorphic generic callback types, unconstrained bare
native generic function values, or explicit specialization
of Quds overload/function values. Those cases remain explicit limitations. The
approved `name<Type>` grammar is preserved; no new keyword or conversion syntax
was added. For active handoff state, see LANGUAGE_READINESS_AR.md.


## Contextual native function instantiation — 2026-11-18

A concrete expected function signature now supplies native generic arguments:

```quds
use dart:math as math

main():
  larger: (int, int) -> int = math.max
  print larger(3, 7)
```

This also works in checked callback argument positions, for static/bound methods,
optional/named signatures, nullable receivers and Future results. Parameter
constraints are collected by position or label, not named-parameter declaration
order. An already inferred input type is not widened just because the result
context is broader. The complete specialized function must still be assignable
to the expected type, and all declared bounds must hold.

Native formal names are freshened during inference so a caller's `type T =
String` cannot capture the native function's own T. The emitter records and emits
explicit type arguments, including nullable bound-method capture, rather than
asking Dart to independently infer a potentially different instantiation.

Every formal needs evidence. No context retains E910 for unsupported polymorphic
values; a function context that leaves a formal undetermined reports E302.
Conflicting signatures, bad bounds or incompatible variance are rejected in
Quds coordinates. Type aliases and nullable expected function types are resolved
before matching. Quds generic/overload values and polymorphic callback types are
still separate unfinished work.

This is structural contextual inference with a final subtype check, not a full
Dart constraint solver or recursive instantiate-to-bound. More complex mixed
variance and bound-only solutions can still require explicit type arguments.
The handoff lists these limits; no complete QUDS-014/045 certification is claimed.
