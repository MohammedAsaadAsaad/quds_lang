# Provider-owned computed defaults

A supported top-level Quds function publishes a stable Dart bridge for its
computed defaults. The bridge is emitted by the defining library even when that
library never takes its own function reference. Consumers reference that bridge;
they do not copy the default expression into their own scope.

`provider.quds`:

```quds
use dart:math as internalMath

_hiddenNumber() -> int = 7
report(first: int = _hiddenNumber(), second: int = internalMath.max(first, 9)) -> String = "{first}:{second}"
```

`main.quds`:

```quds
use provider as api

main():
  saved = api.report
  print saved()                  // 7:9
  print api.report(first: 12)     // 12:12
  print saved == api.report      // true
```

The internal helper and `internalMath` resolve in the provider. Neither name is
added to the consumer's Quds namespace. Existing visibility checks still apply.
The example uses the existing internal top-level underscore convention; this
milestone does not redefine the approved visibility syntax.

## Contract

- Omitted defaults resolve once, in declaration order, after every written
  argument expression has run in source order. A later default sees the resolved
  earlier parameter. Reference creation does not execute defaults.
- Omission uses a private provider token, distinct from explicit null and public
  `missing`. Supplied values are not mistaken for omitted arguments.
- Repeated references share Dart tear-off equality through prefixed, unprefixed
  and re-exported imports. Explicit and contextual generic specialization remain
  checked; Future-valued targets retain their signatures without an async wrapper.
- Direct calls with omitted defaults capture supplied values first, then invoke
  the provider bridge. Calls that supply every argument retain the original path.
  This does not finish legacy direct-call parameter-form matching: required-named,
  optional-positional and dual metadata still need their own milestone.
- `show` and `hide` propagate the corresponding generated bridge names for the
  actual imported library, including filtered re-exports. Native Dart imports do
  not acquire unrelated Quds helper names. The checker still exposes source names.

The generated `$QudsDefault...` identifier is a reserved Dart ABI detail derived
from the declaration signature, not absolute paths or backend temporary numbers.
The source helper remains private; the bridge provides the same public callable
operation as its source declaration. The CLI records a generated-ABI epoch (`provider-defaults-v7`; earlier epochs covered functions, methods, generic interfaces, parameter kinds, and gap packets) in build caches.
Build/run invalidate older epochs and rebuild dependencies automatically, even
when their source and output checksums still match. Externally managed generated
Dart must likewise be rebuilt with the matching compiler. It is not a runtime registry or a dynamic dispatch system.

## Supported boundary

This slice covers public top-level Quds functions with an explicit return type,
a trailing group of computed defaults, no variadic/intersection parameters, no
generator and no awaiting default. It includes a synchronous default on an async
function. Native Dart function values retain their existing metadata path.

Non-class/protected provider methods, interface bridges, inferred provider return metadata,
SDK-section APIs, defaults with variadics/intersections, and awaiting defaults
remain outside this ABI slice. Existing paths and limitations remain for them.
Parts, cycles, conditional exports, cross-package publication and compatibility
with previously generated Dart require expanded certification; they are not
claimed complete by the local import/re-export tests.

Evidence: `test/quds_value_adapters.quds`, the web fixture and Dart driver,
`test/fixtures/quds_value_adapters/helpers.quds`, `facade.quds`, and the generated
Dart golden. Exact observed results are in [VALIDATION.md](VALIDATION.md).

## Compiler maintenance

When a lowering change introduces helper names that old generated dependencies
cannot satisfy, bump `_generatedAbi` in `bin/quds.dart`. This version identifies
generated Dart compatibility; it does not change language specification 1.2.
The upgrade regression deliberately keeps a legacy provider's output checksum
valid after removing bridge functions, so ordinary corruption repair cannot
mask a missing ABI check.

## Imported concrete class methods — ABI v2

Public methods declared in ordinary public `class` declarations now publish
reserved `$QudsMethodDefault...` member bridges. The owner name, class binders and
source method signature determine the name; consumer prefixes and backend
variable numbers do not. The provider emits every supported bridge even when
it never takes a reference locally. Readonly proxy classes implement the same
members, including guarded throwing paths for methods unavailable through readonly.

```quds
use provider as api
main():
  owner = api.DefaultBox<int>(stored: 8)
  saved = owner.read
  print saved == owner.read
  print saved()
  print owner.read()
```

The fixture provider's `read` default reads a private field and a private Dart
import alias. Its method body and defaults are analyzed in the defining library,
with active-library visibility checks, rather than in the consumer. Ordinary
consumer access to private fields/methods still reports an error.

Both references and direct calls with omitted defaults stay on the captured
receiver. A direct call evaluates that receiver before written arguments.
Class/method generics, static declaring owners, inheritance, live fields and
readonly/nullable references retain their existing checks. Base-typed references
keep base defaults while their target bodies dispatch virtually.

For supported null-aware calls, a null receiver short-circuits before supplied
arguments or defaults. The inferred result type remains nullable. The VM/JS
fixture covers direct null-aware calls as well as nullable method values.

The method slice requires an explicit result and synchronous trailing defaults,
and excludes duplicate method names, intersections, variadics and generators.
Interfaces, value/mixin/extension kinds, protected/private exported bridges,
SDK methods and expanded cross-package/part certification remain separate work.
A generic field read that could expose mutable data is not made readonly by this
feature: source readonly qualifications and result guard restrictions still apply.

The generated-ABI epoch is v2. The upgrade regression keeps valid checksums on a
v1 provider with method bridge definitions removed; `quds run` rebuilds it and
prints both the function result and the imported method result automatically.

## Interface continuation — ABI v3

Supported non-generic declaring interfaces now publish resolver/member bridges;
implementing Quds classes and readonly proxies forward through the defining library.
See [interface default bridges](QUDS_INTERFACE_DEFAULTS.md) for the exact signature
slice, distinct-contract equality, unsupported forms and v2-cache migration.
Earlier sections describe the function and concrete-method slices.

## Generic interface continuation — ABI v4

Generic owner specialization and provider lexical signature types now use the
interface resolver protocol. See [interface default bridges](QUDS_INTERFACE_DEFAULTS.md)
for binder hygiene, bounds, records/callbacks and automatic v3-cache migration.

## Parameter-kind continuation — ABI v5

Public bridge identities now include parameter kinds. Required named and optional
positional declarations retain their shape across imports, generics, methods and
interfaces. See [parameter forms](QUDS_PARAMETER_FORMS.md) for current evidence,
legacy direct named-default matching, positional gaps and constructor limits.
