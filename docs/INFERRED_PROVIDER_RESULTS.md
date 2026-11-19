# Inferred results across Quds imports

Specification 1.2 syntax is unchanged. This continuation uses generated ABI
`provider-defaults-v10` and fixes expression-bodied functions imported from Quds.

`provider.quds`:

```quds
_seed() = 7
inferred(value: int = _seed()) = value
plain(value: int) = value + 1
identity<T>(value: T, other: T = value) = other
future(value: int = _seed()) async = value
```

`main.quds`:

```quds
use provider as api

main() async:
  print api.inferred()                 // 7
  saved = api.inferred
  print saved()                       // 7
  plain: (int) -> int = api.plain
  print plain(4)                      // 5
  copy = api.identity<String>
  print copy("Quds")                  // Quds
  pending: Future<int> = api.future()
  print await pending                 // 7
```

## Type and lowering contract

- Import registration preserves the unresolved result of an expression body.
  It does not replace it with void or dynamic. Analysis resolves the expression
  in its defining library, including private helpers, native import aliases,
  generic binders and earlier default parameters.
- Direct calls resolve that result before consuming the call's result type.
  Function values likewise use a real function signature, even for ordinary
  non-generic imports without defaults. Explicit/contextual generic values and
  typed overload selection retain their existing checks.
- Provider-defined class and alias types in function signatures keep the
  provider's lexical identity before specialization. Nullable and record results
  retain their structure. Re-exported/show-filtered function references retain
  ordinary tear-off equality and expose the corresponding generated bridges.
- Supported ordinary public class methods may publish default bridges with
  inferred results. Owner arguments substitute into default types. Imported
  inherited fields/override receivers resolve in their declaring library.
- Method backend names are assigned from parameter contracts while results are
  unresolved. Full result compatibility is checked after inference. Inferred
  results never permit an override to weaken a declared base result contract.
  Already resolved result contracts retain their early checks.
- Reference creation does not execute defaults. Supplied arguments precede
  omitted defaults, which run per call in declaration order. Private defaults
  remain in the provider. Future results remain Future values.
- A recursive expression function without enough result information is rejected
  with E300 and a return-annotation diagnostic at its declaration. Unknown,
  ambiguous, incompatible or inaccessible consumer uses keep Quds coordinates.
- ABI v10 invalidates otherwise valid v9 caches, including matching output
  checksums, because older providers do not publish these inferred-result bridges.

## Evidence and scope

`test/inferred_provider.quds` contains 13 executable Quds declarations. Its
fixtures include a provider, a filtered facade and deliberately invalid recursive
functions used only by negative tests. The driver covers consumer type errors,
generic bounds, private access, ambiguous values, direct/mutual recursion, unsafe
inferred overrides, and the existing multiline-body rule.

`test/inferred_provider_web.quds` and its deterministic golden are analyzed
**without suppressing analyzer warnings**, then executed on Dart VM and compiled
JavaScript/Node with the same 41 output lines. Cache migration keeps a v9 provider
checksum valid after removing its new bridge, then verifies automatic rebuilding.

This milestone implements existing expression-body inference across imports.
Ordinary multiline bodies still need an explicit result annotation to return a
value. Inferred declaring-interface default bridges, SDK-section defaults,
polymorphic callback constraint solving, private nominal return-type publication,
generator inference and expanded cross-package/part/cycle certification remain
separate work. The alias test covers provider lexical signature identities;
it does not certify Dart publication of exported erased aliases. No approved
syntax is redesigned and no whole rule is promoted to complete.

Observed gates: [VALIDATION.md](VALIDATION.md). Handoff:
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
