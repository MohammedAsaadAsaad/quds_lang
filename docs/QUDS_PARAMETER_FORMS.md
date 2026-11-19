# Parameter metadata — generated ABI v5

Specification 1.2 remains authoritative. This milestone preserves declaration
parameter kinds from the parser through specialization, call matching, values,
provider bridges and interface forwarding. It does not certify all QUDS-022.

| Declaration | Meaning | This slice |
| --- | --- | --- |
| `value: int` | Required dual positional/named | Existing calls retained |
| `value: int required` | Required named-only | Checked in direct calls, overloads, constructors and function values |
| `value: int = expression` | Optional named-only | Kind retained; values enforce named-only; direct calls retain the legacy exception below |
| `[value: int = expression]` | Optional positional, also callable by name | Direct calls and values, sequential computed defaults |
| `[value: int?]` | Optional positional, implicit null | Checked for null compatibility; `[value: int]` is rejected |
| `...values: int` | Trailing variadic | Existing packing retained; bracket/required combinations rejected |

```quds
read(value: int required) -> int = value
sum([first: int = 7, second: int = first]) -> int = first + second
maybe([value: int?]) -> int? = value
mixed(amount: int required, value: int) -> int = amount + value

main():
  print read(value: 8)               // 8
  print sum()                       // 14
  print sum(4)                      // 8
  print sum(first: 4, second: 5)     // 9
  print maybe()                     // null
  print mixed(3, amount: 4)          // 7
  saved = read
  print saved(value: 9)              // 9
  print saved == read               // true
```

A positional cursor skips required named slots instead of consuming them.
Unknown/duplicate/missing arguments and invalid required/default/bracket
combinations report Quds diagnostics. Overload identity includes named kinds and
labels; a typed named callback context can select the corresponding overload.
Public bridges keep ordinary bound-function equality, including supported generic
class/interface methods and readonly proxies. Method contracts preserve named
labels and kinds rather than erasing them to bare parameter types.

Supplied expressions run once in written order, before omitted defaults. Defaults
resolve once in declaration order and can read earlier resolved parameters. Null
is a supplied value; omission uses the private sentinel. Function-value signatures
put positional slots before named slots, independent of declaration layout.

Original compiler-owned Dart bodies still use positional parameters. Bridges expose
required named slots or optional positional slots and delegate to those bodies.
Provider defaults remain in the defining library; private expressions are not copied
to a consumer. Constructor signature metadata is retained even for prefixed generic
construction, fixing lost defaults and doubled import prefixes. Literal/default-null
constructor forms are covered; general computed constructor defaults are not certified.

## Explicit limits and next work

- **Known specification conflict:** direct declaration calls still accept a positional
  argument for `name: Type = expression`. The AST records `optionalNamed`, and stored
  values enforce named-only. Removing the legacy exception requires an SDK/example
  migration audit; this is not a language-design change.
- Optional positional and named groups cannot share one supported Dart function
  value; taking such a value is E910. Required positional parameters following
  defaults and default-plus-variadic values retain their E910 boundary.
- A stored optional positional value cannot omit an earlier slot and supply a later
  one; this is E910. Imported direct optional positional gaps are also E910 until a
  provider packet protocol can represent them safely. Supply preceding values
  explicitly. Same-library direct calls can resolve the omitted prefix locally.
- Imported explicit constructors with non-literal defaults need a provider-owned
  constructor protocol and are rejected with E910. Constructor default scope,
  dependency and exactly-once certification needs dedicated follow-up.
- Override parameter kinds currently need an exact kind match; safe kind-widening
  (such as a required named slot implemented as optional named) is not certified.
  This is a conformance gap, not a change to the approved override rules.
- Lambda declaration parameter forms, broader operator/constructor shapes, SDK
  section bridge support, complex intersections and foreign implementors remain
  separate work. No generic-callback or full 115-rule certification is claimed.

ABI `provider-defaults-v5` includes parameter kinds in bridge identities. The CLI
invalidates v4 caches automatically, including valid-checksum output with the new
bridges removed. Evidence: `test/parameter_forms.quds`, its VM/JS fixture and golden,
`test/fixtures/parameter_forms/provider.quds`, `test/parameter_forms_test.dart` and
the existing value-adapter regression. Exact results are in [VALIDATION.md](VALIDATION.md);
the next-agent handoff is [LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
