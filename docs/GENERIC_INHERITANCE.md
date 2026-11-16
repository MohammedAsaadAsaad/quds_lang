# Instantiated class inheritance and multi-file Quds tests — L3.2c

This package follows [L3.2b](COLLECTION_INFERENCE_INTERFACES.md) and the
[agent handoff](LANGUAGE_NEXT_STAGE_HANDOFF_AR.md). It strengthens the existing
QUDS-008/016/017/024/026 rules in specification 1.2 without changing their syntax.
It is a bounded implementation package, not complete Dart inheritance parity.

## Confirmed defects

A class such as `Derived<U> extends Base<List<U>>` previously lost inherited
fields during constructor checking, so a valid constructor call failed with
E500. Private writes through a generic receiver could emit `stored` while the
field was declared as `_stored`. Superclass overrides were compared without
substituting the ancestor's arguments. Multi-file Quds suites exposed missing
dependency files in the temporary `quds test` directory.

```quds
class Base<T>:
  var value: T required
  read() -> T = value
class Derived<U> extends Base<List<U>>:
  tag: String required
  ownRead() -> List<U> = value
main():
  value = Derived<int>(value: [1, 2], tag: "example")
  print value.read()[0]
```

## Shared field views and constructor layout

The semantic model retains a stable field view for each class. Inherited fields
are specialized through each superclass edge in that class's formal parameters:
`Base<T>` → `Middle<V> extends Base<Map<String,V>>` →
`Derived<U> extends Middle<List<U>>` produces `Map<String,List<U>>` storage.
The original declarations and spans are retained; the parent AST is not rewritten
for a particular child. Views preserve mutability, visibility and storage flags.

Constructor inference, initializing formals, implicit field reads in methods,
and Dart constructor argument layout use these views. The emitter no longer
performs a separate raw-name walk that can disagree with the checker. Static,
event and lazy fields do not occupy constructor argument positions. A primary
Quds case and the VM/JavaScript golden fixture specifically cover static fields
before actual instance arguments, which previously shifted argument names.

Explicit superclass arguments are validated for arity and bounds in the child's
generic scope. A synthesized constructor can forward inherited fields across
multiple synthesized superclass levels, including required/default fields.

An explicit `init(super.value)` works with a synthesized named parent constructor
by emitting a typed positional Quds parameter and a named `super(value: value)`
initializer. When the parent has an explicit positional constructor, the matching
Dart `super.value` forwarding remains positional. Required parent arguments must
be forwarded; `this.field` must name a field declared by the child, and
`super.field` must refer to a superclass field. Constructor argument expressions
retain source order and execute once, including named arguments supplied in a
different order from the field layout.

## Methods, properties and visibility

Method override checking specializes the signature at the actual declaring
ancestor. It checks parameter/result compatibility, static/instance agreement,
readonly obligations, optional defaults and variadic metadata. The tested
subset uses nongeneric method declarations on generic classes; generic-method
override combinations still need their own conformance matrix.

Class generic parameters and bounds stay in scope during explicit constructor
and property analysis. Declared result/property types provide context for
expression bodies such as `empty() -> List<U> = []` and `get = []`.

Dart member lookup follows generic superclass heads. A `private` keyword field
uses its `_name` spelling on both reads and writes, while a source underscore
name retains that spelling. The language's visibility policy is unchanged:
private is library-private, and protected permits the declaring library and
subtypes. Prefixed cross-file tests accept protected access inside a subtype
and reject private access or unrelated external protected access at Quds source
coordinates.

## Temporary module staging for test/analyze

`quds test` and `quds analyze` now stage the Quds dependency graph in a temporary
directory, with unique module URIs and shared SDK bundles. Imports and Quds
`part`/`part of` directives are re-emitted from AST metadata; no source rewriting
transpiler is used. Relative Dart imports resolve against their original source
file, including when used inside an imported Quds function's lexical scope.
A bare filename ending `.dart` is kept as a Dart filename rather than being
normalized into a dotted Quds module path.

The staging helper regenerates the source map for the staged output, preserves
the separate test entry bridge, and cleans its temporary directory in `finally`.
It does not create generated Dart beside the user's input files. SDK bundles
share one location so a `Stack<int>` crossing modules retains one Dart identity.

Part files receive a deterministic path-derived internal symbol prefix, preventing
collisions with the owning file's `_q0` names. Generated runtime imports precede
part directives. The regression executes a private helper from a Quds part;
it is not a claim that every part/helper/generic combination is complete.

## Validation and remaining scope

- `generic_inheritance.quds`: **11 declarations** covering nested chains,
  inference, methods, explicit constructors, private/underscore fields, bounds,
  overrides, getters/contextual empties and static-field constructor layout.
- `generic_inheritance_prefix.quds`: **two declarations**, using the supporting
  `generic_inheritance_library.quds` module.
- `generic_inheritance_test.dart`: **28 tests**, including the primary runner,
  20 invalid type/constructor/override programs, five cross-file visibility
  rejections, original spans, and a deterministic Dart golden analyzed and run
  on VM and JavaScript/Node.
- Two additional test-runner regressions execute temporary multi-file Quds
  programs: shared SDK identity with a relative Dart helper plus `quds analyze`,
  and a private Quds part helper. They assert no generated source-side Dart files.

Exact focused and full-project results are in [VALIDATION.md](VALIDATION.md).
An intermediate focused check exposed the expression/getter-context and module
staging defects above; those were fixed and covered in the same delivery.

The approved grammar remains broader than this tested subset. Raw generic
superclasses and automatic constructor synthesis over explicit parent
constructors report E910 rather than generating an invalid call. Use explicit
super initializing formals for the covered explicit-constructor cases. Arbitrary
parent constructor parameter-to-field transformations, inherited stored-field
shadowing, full generic method overrides, const/factory/redirecting inheritance,
and complete mixin/external Dart superclass substitution need later packages.
Complex Quds part graphs, Dart part files, helper sharing across parts and general
Dart re-export/nominal metadata combinations also require separate matrices.
No math API or performance improvement is claimed by this package.
