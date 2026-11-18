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

When a method value would need additional transitive result protection beyond
its declared type, this slice reports E910 rather than erasing the qualification.
Declare a readonly result when that is the method's actual contract; more general
return adapters remain work.

| Invalid case | Diagnostic |
| --- | --- |
| Missing context/arguments for a generic method | E302 |
| Wrong type arguments/bounds/signature or static/instance access | E300 |
| Nullable receiver without safe access | E308 |
| Cross-library private/protected access | E206 / E207 |
| Mutating method exposed through readonly or mutation of its readonly result | E307 |
| Unsupported default/variadic/intersection/owner/result adaptation | E910 |

## Limits and handoff

This slice covers required positional class/interface methods, local and imported
static methods, inherited instance methods, explicit/contextual specialization,
nullable access and checked readonly cases. It does not certify class method
overloads, generic extension values, default/variadic/intersection adapters or
all mixed-variance constraints.

Dart does not expose a parent's static method through the child type. Inherited
static values currently report E910 and require the declaring type until
owner-qualified lowering has its own contract. This is an implementation limit,
not a replacement language inheritance rule. Explicit instantiation requires
verified callable metadata; a function-looking getter alone is insufficient.

Evidence: `test/quds_method_values.quds` (five declarations), twenty rejection
cases plus readonly-this escape, a deterministic Dart golden, entry analysis and
VM/JavaScript execution. Exact results and active next-agent steps live in
[VALIDATION.md](VALIDATION.md) and [LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
