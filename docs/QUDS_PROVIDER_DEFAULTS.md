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
operation as its source declaration. The CLI records a generated-ABI epoch (`provider-defaults-v1`) in build caches.
Build/run invalidate older epochs and rebuild dependencies automatically, even
when their source and output checksums still match. Externally managed generated
Dart must likewise be rebuilt with the matching compiler. It is not a runtime registry or a dynamic dispatch system.

## Supported boundary

This slice covers public top-level Quds functions with an explicit return type,
a trailing group of computed defaults, no variadic/intersection parameters, no
generator and no awaiting default. It includes a synchronous default on an async
function. Native Dart function values retain their existing metadata path.

Provider methods, interface bridges, inferred provider return metadata,
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
