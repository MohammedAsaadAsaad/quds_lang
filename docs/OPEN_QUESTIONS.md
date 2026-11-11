# Language design status

Quds 1.2 closes the language design. The grammar, the single meaning of each token, evaluation order, the Dart 3.13 parity table, the project layout, the diagnostic registry, the source-map encoding, and the macro sandbox are in `QUDS_LANGUAGE_SPECIFICATION.md`. They are not an invitation to add a second rule.

The resolutions that used to be listed here as open questions now live in that file:

- Named-argument blocks are all-label blocks. `map:` and `set:` are collections. Any other legal argument block is a collection-element block. `test` and `group` are declarations, so a test body is not a collection.
- Bare `name = expr` assigns a visible mutable binding, rejects a visible immutable binding, and otherwise declares an immutable binding. A same-name local is `shadow` or `shadow var`.
- `readonly` qualifies one reference. `to` converts. `to?` converts safely, including to a nullable target.
- Omission is `missing`. Overloads are compile-time and lower to mangled Dart names. Defaults run after supplied arguments, in declaration order.
- `return` exits a function. `result` finishes `do:`. Postfix `?` propagates `Result`. Prefix `?` on a collection element omits null. Dot shorthand is `.member` and `.new`.
- Records, holes, ranges, `with`, and `capture` keep the meanings in the token table.
- Null-aware elements, dot shorthands, private named parameters, and primary constructors are available through the spellings in the parity table.

A program that can be parsed in two ways is a compiler bug or a required rejection.

## What the current compiler still does not implement

The language rules above are settled. `MVP_0.md` lists the slice that compiles and runs. These design rules are still rejected or only partly lowered:

- Cross-file `E206` / `E207`. One compilation is one library, so `private` and `protected` are visible there. `private` still lowers to a Dart `_` name, and `protected` is emitted as a documentation comment.
- `copyWith` when a field is assigned only in the constructor body. A field that has an initializer and is not an initializing formal may be omitted. Replacing that field throws `ArgumentError` because the constructor cannot set it.
- `await all` and `task group` start every child immediately and report the first source-order failure (`TaskFailed` for a group). An already-running Dart future is not aborted, so cooperative cancellation is not performed.
- `annotation Name` is a const class with no parameters. `@Name(...)` arguments are not parsed. `@Reflectable` emits a const map of the class name and its field names.

`property`, `operator`, `private` / `protected` / `readonly` methods, `init`, `factory init`, and `const init`, `if value is Pattern`, `if let`, `defer`, `using` / `using async`, `static` members including `static var`, `part` / `part of`, and constant `when` / `use when` are implemented. Patterns in `match`, `if is`, and `if let` include or, and, relational, list rest, map, record, cast, null-check, and null-assert. Generic classes and functions, a single bound, variance (`E304`), generic extensions, `await all`, `await isolate` (`E805` for a captured local), `task group` / `spawn` (`E107` outside the group), `noSuchMethod` on a `dynamic` receiver, `symbol`, and `require` / `check` / `assert` are implemented. An intersection parameter lowers to `T extends` its first type, then checks `is!` for each later part. `config` reads the process environment, then the `config:` map in `quds.yaml`, then the source default. The environment name is the dotted name in upper case with `.` replaced by `_`. A secret has no source initializer, and a secret literal is `E908`. A missing required value throws `StateError` at the first read. `platform` is `"vm"` for `quds build`. A `when` condition that is not a constant boolean is `E902`. A file that contains both `part` and `part of` is `E903`. The unselected `when` branch is not type-checked. Aliases, extension types, the Dart class modifiers, and the diagnostic registry are implemented. An integer outside the JavaScript safe range stays exact on the VM, and Dart's web compiler rejects it. That behavior is covered by `test/language_test.dart`.
