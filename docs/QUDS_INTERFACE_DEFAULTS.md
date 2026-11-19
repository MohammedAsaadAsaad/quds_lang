# Interface default bridges — generated ABI v3

This slice preserves a selected Quds interface's computed defaults while the
original method body dispatches to the implementation. Taking the same contract
reference repeatedly retains normal Dart bound-method equality.

`provider.quds`:

```quds
_defaultRead() -> int = 7
interface Contract:
  readonly read(value: int = _defaultRead()) -> int = value
class Implementation implements Contract:
  readonly read(value: int = 4) -> int = value * 10
```

`main.quds`:

```quds
use provider as api
main():
  owner = api.Implementation()
  face: api.Contract = owner
  saved = face.read
  print saved()                  // 70: interface default
  print owner.read()             // 40: class default
  print saved == face.read       // true
```

## Lowering and ownership

The defining library publishes a reserved `$QudsInterfaceDefaults...` resolver.
It receives the interface receiver, supplied values and presence flags, resolves
omitted defaults once in declaration order, and returns a typed Dart record.
Earlier resolved parameters are available to later defaults. Private helpers,
Dart import aliases and receiver getters resolve in the interface's library.
Generated packet names are reserved, so an alias such as `values` is not shadowed.

The interface declares a reserved `$QudsMethodDefault...` member. Every generated
implementing class supplies a forwarding member that calls the resolver, then
calls its original method with the resolved record fields. Interface inheritance
and multiple contracts retain their declaring owners; the implementation body
still dispatches virtually. No reflection, `Function.apply`, regex transpilation
or runtime receiver registry is used.

References with the same receiver, selected contract and method type arguments
compare equal. Different selected contracts can have different defaults on the
same receiver and have distinct bridge operations. This does not promise Dart
`identical` or allocation-free execution.

Readonly proxies provide the same members. Mutating contracts remain unavailable
through readonly and keep throwing proxy paths. An implementation that weakens a
readonly contract is rejected by the checker. Null-aware references and supported
null-aware direct calls preserve null and skip argument/default evaluation.
Explicit null and public `missing` are supplied values, not omission. A thrown
default prevents entering the target method body.

Cross-library forwarders use compiler-owned backend imports for the resolver.
Those imports do not add private source names to the consumer namespace and also
work when a source import only exposes the interface. Declaring-provider identities
are used for inherited method lookup, so inherited defaults keep their metadata.

## First supported signature slice

The declaring interface must be public and have no interface type parameters.
Public instance methods need an explicit result and synchronous trailing computed
defaults; generators, variadics, intersection parameters, duplicate method names,
static/operator methods and awaiting defaults remain outside this slice.

Declaration type names may use `bool`, `int`, `num`, `double`, `String`, `Object`,
`dynamic`, `Never`, `Null`, `void` where legal, `List`, `Set`, `Map`, `Iterable`,
`Future`, `Stream`, nullable/readonly forms and method type parameters. Method
type parameters and compatible bounds using those names are supported, independently
of the implementing class's method binder names. Existing argument/bound/variance
checks remain active.

Generic declaring interfaces and other declaration types, aliases, function/record
signatures or union/intersection forms retain their previous lowering. Their
acceptance is not redesigned; their repeated-reference identity is not certified.
A regression verifies that an ordinary generic declaring interface still executes
on that earlier path. Extending the slice requires lexical type qualification and
binder hygiene, not changing approved language syntax.

## Compatibility and evidence

Generated interface/implementation ABIs now contain companion members. Generated
Quds implementations and readonly proxies must be rebuilt together. The CLI's
`provider-defaults-v3` epoch invalidates v2 caches automatically, even when a legacy
provider's output checksum remains valid. Manually authored Dart implementors need
the generated protocol or an explicit Quds adapter; arbitrary foreign implementations
are not certified by this slice. Parts/cycles/conditional exports, cross-package
publication, new resolver debugger-frame projection and performance certification
remain separate work.

Evidence is in `test/quds_value_adapters.quds`, its Dart driver and VM/JS fixture,
`test/fixtures/quds_value_adapters/helpers.quds`, and the Dart golden. Exact observed
commands/results are recorded in [VALIDATION.md](VALIDATION.md). The active next-agent
plan is [LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
