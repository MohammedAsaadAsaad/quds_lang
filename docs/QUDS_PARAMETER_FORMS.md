# Parameter metadata — generated ABI v9

Specification 1.2 remains authoritative. This milestone preserves declaration
parameter kinds from the parser through specialization, call matching, values,
provider bridges and interface forwarding. It does not certify all QUDS-022.

| Declaration | Meaning | This slice |
| --- | --- | --- |
| `value: int` | Required dual positional/named | Existing calls retained |
| `value: int required` | Required named-only | Checked in direct calls, overloads, constructors and function values |
| `value: int = expression` | Optional named-only | Named-only in direct calls and values |
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
constructor forms are covered. A computed default whose type uses a class type
parameter is checked in the declaring library and substituted at the call.

## Explicit limits and next work

- Direct calls of `name: Type = expression` are named-only, including the SDK.
  A leading dual parameter such as `normalCdf(x)` still accepts a positional
  argument. Optional parameters that follow it are passed by name.
- Optional positional and named groups, and a default or optional positional
  together with a variadic, are stored as packet values
  `(List<Object?>, List<bool>)`. A named default before a required positional
  parameter stays one reordered Dart signature.
- An imported or stored optional positional value may omit an earlier slot and
  supply a later one. The provider owns the defaults in `$QudsGap` /
  `$QudsMethodGap` packets `(List<Object?>, List<bool>)`. The stored value
  remains the positional tear-off; an `Expando` recovers the packet. An opaque
  Dart function value still reports E910. Same-library direct calls evaluate
  the omitted prefix locally.
- A generative constructor with any non-literal default calls the provider
  static `$QudsCtor...`, including local/named constructors and fully supplied
  calls. Literal-only defaults stay at the call site. A child with
  no constructor forwards exactly one unnamed generative parent constructor;
  a named-only, factory, variadic, or field-name collision stays E910.
  An imported non-literal parent default is evaluated by `$QudsCtorSlots`.
- A required named parameter may be implemented by an optional named parameter
  with the same name and a default. A dual parameter does not satisfy a
  required named parameter.
- Lambda parameters accept `name: Type required`, `[name: Type]`, and defaults,
  including a default that reads an earlier parameter. Class method overloads
  emit `name$1` and `name$2`. SDK section bridges, intersections and foreign
  implementors remain separate work. No full 115-rule certification is claimed.

ABI `provider-defaults-v8` repairs sequential constructor slots, bounded generic
bridge calls and named-constructor default ownership. Each resolved slot is
available to later defaults; reserved generated slot names do not shadow native
import aliases. Generic declarations retain bounds, while invocations use only
type arguments. Explicit constant contexts keep constant evaluation.

Packet calls evaluate the callable/receiver first, then supplied operands once in
source order, outside the synchronous packing closure. This permits `await` and
spread operands without flattening Future results or losing void behavior.
Imported method defaults and prefixed function values retain provider ownership.
The CLI invalidates v7 and earlier caches, including valid-checksum output.
Additional evidence: `test/constructor_packet_regressions.quds`, its VM/JS fixture,
provider, golden and Dart driver (negative diagnostics and cache migration).
Evidence: `test/parameter_forms.quds`, its VM/JS fixture and golden,
`test/fixtures/parameter_forms/provider.quds` and `test/parameter_forms_test.dart`.
The v9 continuation covers awaited ordinary/provider operands, automatic
constructors, nullable Quds method calls and Future<void> results. See
[CALL_SUSPENSION.md](CALL_SUSPENSION.md) for semantics, evidence and limits.
Exact results are in [VALIDATION.md](VALIDATION.md); the handoff is
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
