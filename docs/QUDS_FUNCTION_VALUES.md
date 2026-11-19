# Quds generic function values and overload selection

The approved `name<Type>` syntax can instantiate a Quds function before storing
or passing it. A concrete expected function signature can infer its arguments.

```quds
identity<T>(value: T) -> T = value
classify(value: int) -> String = "integer"
classify(value: String) -> String = "text"

main():
  saved = identity<int>
  contextual: (int) -> int = identity
  integerLabel: (int) -> String = classify
  print saved(value: 3)
  print contextual(4)
  print integerLabel(5)
```

Output is `3`, `4`, `integer`. A value with an inferred signature retains the
Quds positional parameter label; the call checker maps a supplied label to the
actual positional Dart slot. An explicit function-type annotation defines the
labels available through that reference.

## Resolution

Explicit type arguments are checked against each declaration's arity and bounds
before the expected function signature selects a candidate. With no explicit
arguments, a concrete function context supplies generic arguments using the
structural inference described in [DART_GENERIC_METADATA.md](DART_GENERIC_METADATA.md).
The final specialized signature must be assignable to that context. Callback
argument positions provide the same context as typed bindings.

One compatible declaration selects its existing generated implementation name.
Resolution happens at compile time. The ordinary Dart function value preserves
argument evaluation order and normal closure behavior. Local forward references
can trigger return-type analysis before selection. Async functions keep their
Future return type.

A single imported generic function with a declared return type works through its
public reference, including a prefix. The executable VM/JavaScript fixture imports
`fixtures/quds_function_values/helpers.quds` and stages its generated dependency.

| Situation | Diagnostic |
| --- | --- |
| Overload without enough context, no compatible overload, or multiple compatible declarations | E311 |
| Single generic function without type arguments/function context, or with undetermined formals | E302 |
| Wrong arity/bounds, incompatible signature or later call argument | E300 |
| A required or variadic parameter follows a default, so the stored value has no single Dart closure | E910 |

If `(int) -> int` accepts both an `(int) -> int` and a `(num) -> int` declaration,
selection is ambiguous and reports E311. An explicit type list can also leave
multiple declarations; a typed binding must then distinguish them. Direct call
overload behavior follows its existing call-resolution path.

## Supported slice and next work

Ordinary Quds functions with required positional parameters, local overload sets,
explicit/contextual generic specialization, callback contexts, local inferred
returns and single-function imports with declared return types remain covered.
The later value-adapter batch also stores functions that have defaults, variadic
parameters, or intersection parameters.

### Computed defaults: corrected value contract (2026-11-19)

```quds
combine(first: int = 3, second: int = first) -> int = first * 10 + second
main():
  saved = combine
  print saved()                // 33
  print saved(first: 4)        // 44
  print saved == combine      // true: local named bridge
```

As required by specification 1.2, a defaulted parameter is named-only through
these function and method values. The earlier adapter batch exposed it as an
optional positional parameter; this was an implementation conflict, not an
approved syntax change. Explicit function signatures use
`(value: int? = missing) -> int?`, rather than `([value: int?]) -> int?`.
Direct declaration calls still use their legacy matching path, which remains
more permissive and needs a separate parameter-metadata milestone.

Supplied expressions execute first, once in source order. Omitted defaults then
resolve to typed locals once in declaration order; later defaults see the
resolved earlier value. A thrown default prevents entering the target body.
The internal omission token is distinct from both explicit null and the public
`missing` value. No default is evaluated while taking a reference.

Local and same-file function definitions emit a named bridge beside the
original definition. Lexical-local bridges remain private; eligible public
top-level providers publish the reserved ABI bridge described below. Repeated references share normal Dart tear-off equality,
including generic specialization; lexical mutable captures remain live.
Concrete same-file method references now use declaring-owner bridges as well;
see [QUDS_METHOD_VALUES.md](QUDS_METHOD_VALUES.md). Supported imported top-level providers now publish stable bridges as described
in [QUDS_PROVIDER_DEFAULTS.md](QUDS_PROVIDER_DEFAULTS.md). Unsupported imported methods,
unsupported interface signatures and default-plus-intersection adapters retain
closure lowering without the same identity guarantee. Supported provider bridges
resolve private default expressions in their defining library. Broader readonly
boundary and unsupported-signature certification remain separate work.

A variadic value has the Quds type `(...items: T) -> R` and the Dart type
`R Function(List<T>)`; call sites pack arguments and spreads. An intersection
parameter keeps its hidden Dart type parameter and runtime check.

Imported overloads with different signatures keep the holder name and publish
`name$1`, `name$2`, and so on, in source order. The same signature, or a class
with the same name, is still E204. A named default before a required parameter
is one reordered Dart signature. A default together with a variadic, and mixed
optional groups, are packet values.

Further work:

- Required-positional, default, and variadic method values are documented in
  [QUDS_METHOD_VALUES.md](QUDS_METHOD_VALUES.md). Class method overloads now
  emit `name$1` and `name$2`.
- Propagation of inferred return metadata from imported providers.
- Full mixed-variance constraint solving and polymorphic generic callback types.

Passing these slices does not certify all QUDS-024/045/085 behavior. Evidence
lives in `test/quds_function_values.quds`, `test/quds_value_adapters.quds`, their
drivers, and [VALIDATION.md](VALIDATION.md). The active next-agent handoff is
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).

The initial [interface-default bridge slice](QUDS_INTERFACE_DEFAULTS.md) now keeps
supported generic and non-generic declaring-interface contracts and repeated-reference
equality across virtual dispatch. Provider class/alias, record and callback signatures
are covered by the ABI v4 continuation; union/intersection and foreign implementor
certification remain separate work.

The ABI v5 [parameter-form continuation](QUDS_PARAMETER_FORMS.md) preserves
required named and bracketed optional positional declaration kinds, including
contextual generic values and overload labels. Direct named-default calls still
have their documented legacy exception; lambda parity and mixed optional groups
remain separate work.
