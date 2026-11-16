# Readonly paths and boundary audit — L3.3

The approved QUDS-092 reference restriction is transitive through the reference;
it does not freeze another alias and does not create a snapshot.

```quds
class Counter:
  var count: int = 1
  increment():
    count += 1
  readonly read() -> int = count
main():
  owner = Counter()
  view: readonly Counter = owner
  print view.read()
  owner.increment()
  print view.read()  # 2: the alias remains mutable
```

The audit reproduced and fixes these defects:

- Arbitrary Quds methods could be called or extracted through readonly receivers.
  Only methods declared readonly can now be called or extracted, including
  inherited methods and extensions. Readonly method bodies still check `this`.
- `as` and no-op `to`/`to?` could drop readonly. They now retain qualification;
  casts through `Object`/`dynamic` do not make a mutable reference. Unclassified
  calls on readonly dynamic or Dart receivers are rejected with E307.
- Same-class nominal equality could accept readonly as a mutable class. It no
  longer bypasses qualification checking.
- Iteration did not handle readonly collections. Iterated reference elements
  now retain readonly. Collection callbacks, searches and copies likewise retain
  readonly element types. A fresh outer list can be mutated; its aliased inner
  elements cannot be mutated through the copied references.
- List/Map runtime wrappers were shallow. Lazy ListBase/MapBase views now guard
  nested lists and map values, including nullable collections. Reads follow the
  source; mutation of the independent mutable alias remains visible.

The supported erased-boundary shapes are scalar leaves, native typed storage,
recursively nested List/Iterable, maps with scalar keys and supported values,
and sets with scalar elements. The expression emitter protects local readonly
references as well as parameter/return boundaries. Each source expression is
still evaluated once. Native typed buffers retain their existing native views.
Explicit copies remain copies; wrappers do not copy data.

There is no general proxy implementing arbitrary custom classes. Such shapes,
including collections with mutable custom elements, cannot currently be erased
into dynamic/Object or passed directly to an unchecked Dart call: E300/E500 or
E910 reports the unsupported boundary rather than silently removing protection.
Readonly custom classes remain useful inside checked Quds code. A generated
Dart API returning such a custom class is **not** a runtime immutability promise
for arbitrary external Dart callers; that remains an explicit interop limit.
Nested mutable Set elements and mutable Map keys need a separate identity-aware
boundary design. Existing scalar Set wrappers are shallow by design because
those elements are immutable. Runtime wrapper identity is not snapshot identity.

Tests: `readonly_paths.quds` has six primary declarations; its runner adds
negative programs, original coordinates, and an actual VM/JavaScript driver
that attempts mutation through nested views, callbacks and dynamic results.
Existing indexed-write and native-storage suites remain regression gates.
Exact final commands/results are in [VALIDATION.md](VALIDATION.md).
