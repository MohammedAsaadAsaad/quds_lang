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

A zero-parameter method whose readonly view is wider than its declared result
stores a guard around the tear-off. A method with parameters that would need
the same transitive protection still reports E910; declare the readonly result
explicitly. The qualification is not erased.

| Invalid case | Diagnostic |
| --- | --- |
| Missing context/arguments for a generic method | E302 |
| Wrong type arguments/bounds/signature or static/instance access | E300 |
| Nullable receiver without safe access | E308 |
| Cross-library private/protected access | E206 / E207 |
| Mutating method exposed through readonly or mutation of its readonly result | E307 |
| Required or variadic parameter after a default, ambiguous owner, or a readonly result adapter on a method with parameters | E910 |

## Limits and handoff

Required positional class/interface methods, local and imported static methods,
inherited instance methods, explicit/contextual specialization, nullable access
and checked readonly cases remain covered. The value-adapter batch adds trailing
defaults, variadic methods, generic extension values, and a zero-argument
readonly result guard.

Dart does not inherit static methods. A child-type reference to a parent static,
whether stored or called, lowers to the declaring type (`Utility.echo`, not
`Derived.echo`). That is an implementation lowering, not a change to the
language inheritance rule. Class method overloads are still unresolved: the
checker returns the first method of that name. A required or variadic parameter
after a default remains E910. Full mixed-variance constraint solving is not
part of this slice. Explicit instantiation requires verified callable metadata;
a function-looking getter alone is insufficient.

Evidence: `test/quds_method_values.quds` (five declarations), the current
rejection map in its driver, `test/quds_value_adapters.quds`, a deterministic
Dart golden, entry analysis and VM/JavaScript execution. Exact results and the
active next-agent steps live in [VALIDATION.md](VALIDATION.md) and
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
