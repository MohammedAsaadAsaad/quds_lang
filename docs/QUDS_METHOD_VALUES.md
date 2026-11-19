# Quds class method values

Required-positional class methods can be stored or passed as function values.
Explicit type arguments and a concrete expected function signature specialize
method generics independently of the enclosing class arguments.

```quds
class Box<T>:
  stored: T required
  echo<U>(value: U) -> U = value
  keep<U: T>(value: U) -> U = value

main():
  box = Box<num>(stored: 1)
  explicit = box.echo<int>
  contextual: (String) -> String = box.echo
  constrained = box.keep<int>
  print explicit(value: 3)
  print contextual("Quds")
  print constrained(4)
```

Output: `3`, `Quds`, `4`. A bound receiver is evaluated when its reference is
created. Later calls use the saved receiver. Inferred signatures retain Quds
positional labels; explicit function annotations define their exposed labels.

## Default-bearing method bridges — 2026-11-19

```quds
class Counter:
  var seed: int = 2
  readonly read(value: int = seed) -> int = value
main():
  counter = Counter()
  saved = counter.read
  print saved == counter.read // true
  print saved()               // 2
  counter.seed = 5
  print saved()               // 5
```

Concrete methods declared in the current source file now use a named private
bridge alongside the original method. Repeated references on the same receiver
retain ordinary bound-method equality, including generic specialization and
nullable access. Taking a reference evaluates its receiver once; omitted
defaults run at each call and observe the receiver's current fields.
Static bridges use the declaring type, without attempting to capture a Type
as an instance. No receiver cache or global closure registry is introduced.

Bridge names include the declaring class. A base-typed reference keeps defaults
from its selected declaration while the original method body still dispatches
virtually. A child override therefore cannot silently replace the base default.
Readonly proxies provide the same private bridge members; disallowed mutating
methods still reject access in Quds and retain a throwing body in the proxy.

Direct method calls with defaults that read fields now evaluate those fields
against the captured call receiver, rather than emitting an unbound field name.

The identity guarantee does not cover unsupported imported providers or interface-declared
references or default-plus-intersection adapters. Those retain the earlier
closure lowering. In particular, interface defaults keep their selected static
contract instead of being replaced by an implementation's defaults. Provider
bridges, full parameter metadata and parameterized readonly result guards remain
separate work. Required `readonly`/visibility checks have not been relaxed.

Evidence: `test/quds_value_adapters.quds` (15 declarations), its Dart driver,
and `test/goldens/quds_value_adapters.dart.txt`; the web fixture analyzes and
executes on VM and JavaScript. Historical sections below describe earlier slices.

## Type and dispatch rules

The checker locates the method's declaring owner through the receiver's
inheritance graph, substitutes that owner's class arguments, then handles the
method's own arguments and bounds. A method parameter shadows an equally named
class parameter. Existing qualified provider types and Self handling are reused.
The final signature must satisfy its expected function type.

Static values use their declaring type, including an imported prefix such as
`helpers.Vault.staticEcho<int>`. Prefix-qualified Quds type expressions now emit
the import prefix once; their static/instance classification also works for
direct calls. Interface references retain normal runtime override dispatch.
Single imported providers and private method references created inside their
own library are exercised by the executable fixtures.

`receiver?.echo<int>` produces a nullable function value. The emitter captures
the receiver once, checks null, and instantiates the method in the non-null arm.
A nullable function needs promotion or `!` before invocation. Future-valued
methods preserve their Future signature.

A qualified static method also works in the existing VM `await isolate` path:
owner lookup uses reference metadata rather than casting a qualified type AST
node to an identifier. The primary Quds suite executes this regression; the
JavaScript fixture does not execute isolates.

## Visibility and readonly

Private/protected access and static/instance checks run before a value is
created. Obtaining a reference to a mutating method through a readonly receiver
is E307, including readonly `this`. Safe readonly scalar reads and declared
readonly collection results keep their qualifications and observe mutable aliases.
A readonly collection result cannot be assigned to a mutable-return signature or
mutated through the saved callback.

A zero-parameter method whose readonly view is wider than its declared result
stores a guard around the tear-off. A method with parameters stores the same
guard on the value and the adapter wraps the invocation result, so the
tear-off is not rejected with E910 for that reason alone. Declare an explicit
readonly result when the qualification itself is part of the signature. The
qualification is not erased.

| Invalid case | Diagnostic |
| --- | --- |
| Missing context/arguments for a generic method | E302 |
| Wrong type arguments/bounds/signature or static/instance access | E300 |
| Nullable receiver without safe access | E308 |
| Cross-library private/protected access | E206 / E207 |
| Mutating method exposed through readonly or mutation of its readonly result | E307 |
| Required or variadic parameter after a default, or an ambiguous method owner | E910 |

## Limits and handoff

Required positional class/interface methods, local and imported static methods,
inherited instance methods, explicit/contextual specialization, nullable access
and checked readonly cases remain covered. The value-adapter batch adds trailing
defaults, variadic methods, generic extension values, and a zero-argument
readonly result guard.

Dart does not inherit static methods. A child-type reference to a parent static,
whether stored or called, lowers to the declaring type (`Utility.echo`, not
`Derived.echo`). That is an implementation lowering, not a change to the
language inheritance rule. Class methods with different signatures emit
`name$1` and `name$2` in source order. A same-signature override copies the
ancestor Dart name. Calls select one candidate at compile time (`E310` when
two non-variadic candidates both apply). A tear-off needs one expected
signature (`E311`). A required or variadic parameter after a default remains
E910. Full mixed-variance constraint solving is not part of this slice.
Explicit instantiation requires verified callable metadata;
a function-looking getter alone is insufficient.

Evidence: `test/quds_method_values.quds` (five declarations), the current
rejection map in its driver, `test/quds_value_adapters.quds`, a deterministic
Dart golden, entry analysis and VM/JavaScript execution. Exact results and the
active next-agent steps live in [VALIDATION.md](VALIDATION.md) and
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).

## Default adapter correction — 2026-11-19

Defaulted slots on stored methods are named optional slots, as required by spec
1.2. For example, `kept = Limited().keep<int>` uses `kept(8, times: 2)`.
Defaults resolve once in declaration order and distinguish explicit missing
from omission. Method adapters still use closures; stable repeated bound-method
identity is not claimed by this correction. See [QUDS_FUNCTION_VALUES.md](QUDS_FUNCTION_VALUES.md).

## Imported public default methods — 2026-11-19

Supported ordinary public class methods now use provider-owned public member
bridges, including generic/static/inherited methods and readonly proxies.
Consumer analysis enters the defining library for private defaults and aliases;
source access checks remain active outside it. Direct omitted-default calls
capture the receiver once, and supported null-aware calls skip argument/default
evaluation on null. The contract and remaining shape restrictions are in
[QUDS_PROVIDER_DEFAULTS.md](QUDS_PROVIDER_DEFAULTS.md#imported-concrete-class-methods--abi-v2).
Interfaces and other excluded provider shapes retain the earlier lowering.

## Interface continuation — 2026-11-19

The first interface-default bridge slice now preserves repeated contract references
and static defaults across virtual implementation dispatch. It supports non-generic
declaring interfaces with the core-type/method-parameter signatures described in
[QUDS_INTERFACE_DEFAULTS.md](QUDS_INTERFACE_DEFAULTS.md). Other interface shapes
retain the earlier lowering; no full interface or function-type certification is claimed.
