# Function types and nullability — L3.1

This package strengthens the existing QUDS-045 function types and null-safety
rules in specification 1.2. It introduces no syntax change. The primary
conformance suite is [function_nullability.quds](../test/function_nullability.quds).
The execution handoff for this and subsequent packages is
[LANGUAGE_NEXT_STAGE_HANDOFF_AR.md](LANGUAGE_NEXT_STAGE_HANDOFF_AR.md).

## Contract

| Quds type | Meaning | Dart type |
| --- | --- | --- |
| `(int) -> int` | Present function, nonnullable result | `int Function(int)` |
| `(int) -> int?` | Present function, nullable result | `int? Function(int)` |
| `((int) -> int)?` | Nullable function, nonnullable result when called | `int Function(int)?` |
| `((int) -> int?)?` | Nullable function and nullable result | `int? Function(int)?` |

The last `?` in a textual function type can belong to its **result**. Checking
only the last character is insufficient to decide whether calling the function
is safe. A map lookup adds nullability to its **value**, including a function
value, because the key can be absent:

```quds
maybe(value: int) -> int? = value
main():
  callbacks: Map<String, (int) -> int?> = map:
    "present": maybe
  selected = callbacks["absent"] ?? maybe
  answer: int? = selected(3)
  print answer
```

`callbacks["absent"](3)` is rejected with E308. So is an unchecked call through
a nullable local, parameter, alias, or function result. `null` cannot initialize
a nonnullable function, even if the function returns a nullable value.
`??`, `??=`, a null check and `!` unwrap the function layer; they do not change
its return type. A nullable result cannot initialize `int` or nonnullable
`Object`. Unsafe diagnostics retain original Quds file/line/column locations.

Function parameters are contravariant and results are covariant; a callback
returning a nullable result cannot satisfy a nonnullable result contract.
Mutable collection references remain invariant. For example, an existing
`List<(int) -> int?>` cannot be assigned to `List<((int) -> int?)?>`.

## Covered composition

- Function aliases, nullable function aliases, callback parameters and functions
  returning functions.
- Multiple parameters including parameters that are themselves functions;
  function-type parameter labels, including nested labels, do not change the
  positional callback convention.
- Nested List/Map types containing callbacks, nullable containers, and maps
  keyed by a function.
- Functions returning nullable positional records or lists, and positional
  records containing functions.
- Null-check promotion, null assertion, lazy fallback and null assignment.
- Callee and arguments evaluated once, in source order; an unnecessary
  fallback remains unevaluated.
- Independent test declarations cannot inherit a previous test's promotions.

## Implementation

`lib/src/type_syntax.dart` supplies shared structural operations over the
compiler's existing textual type encoding: balanced parameter/type-argument
lists, top-level function arrows and whole-value nullability. An arrow's `>`
is not a closing generic delimiter. Removing whole-value nullability unwraps
the extra grouping around a function without removing record delimiters.
This is type-shape handling inside the typed compiler, not source transpilation.

The analyzer uses those operations for validation, compatibility, callback
invocation, map lookup, promotion and relevant nullable access checks. The Dart
emitter recursively renders function types inside generic and record types;
it preserves both nullable layers. The existing AST and source spans remain
in use. Promotion information is saved, cleared and restored for each test
body, as it already was for function bodies.

## Validation and remaining scope

`test/function_nullability_test.dart` runs the **16 Quds declarations**, checks
15 invalid programs, test-scope isolation and diagnostic spans. It also compares
the complete deterministic Dart output against
`test/goldens/function_nullability.dart.txt`, analyzes that generated program,
and executes the Quds fixture on Dart VM and JavaScript/Node.

See [VALIDATION.md](VALIDATION.md) for the final full-project run and exact
results. These tests establish the combinations listed above, not exhaustive
support for every Dart function-type feature. Named/optional/variadic callback
type subtyping, all combinations of function types with unions/intersections,
named record type composition, generic inference and every readonly boundary
need their own conformance matrices. The compiler still uses textual type
encodings; this package does not claim a complete type IR or backend speedup.
L3.2, L3.3 and L3.4 remain separate tasks in the handoff. No math API was added
by this compiler-foundation package.
