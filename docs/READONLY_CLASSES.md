# Transitive readonly class boundaries

This extends QUDS-092 without changing source syntax. A readonly reference is a
live view. Other mutable aliases remain writable; it is not a deep freeze or a
snapshot. The compiler emits guards from typed class ASTs, not source patterns.

```quds
class Box<T>:
  values: List<T> required
  readonly first() -> readonly T = values[0]
expose<T>(value: Box<T>) -> readonly Box<T> = value
```

Supported ordinary, value, base, abstract and final Quds classes have generated
proxies. They protect fields, properties, nested collections, methods, cycles,
generic parents and private fields across libraries. Interface dispatch uses the
actual Quds implementation. A proxy does not rerun the original constructor.
Readonly method/getter bodies execute on the proxy, so an impure getter cannot
silently mutate its source. Writable setters and non-readonly methods throw
UnsupportedError when called from Dart; Quds rejects these paths with E307.
Readonly is not a callback-purity system: a function may still capture another
mutable alias.

Lazy fields share one private cache with their mutable owner. The initializer
runs once, including when the first read is through a view. A protected read
never puts an unmodifiable wrapper into the owner's mutable cache. Per-computation
origin tracking accepts only the declaring owner's actual private cache slot;
an external LazySlot cannot unwrap another object's protected field. Guard
descriptors are sealed; retained metadata cannot contain arbitrary raw-field
callbacks. Source pointers and reverse caches are library-private.

Value classes compare/hash nested lists, sets and map values structurally. Map
keys keep map equality semantics. Hashes follow alias changes, so a value holding
mutable collections must not be mutated while used as a hash key. Cyclic value
graphs use cycle-aware equality and a common cyclic hash. Readonly Quds equality
preserves underlying source equality. Native Dart identity tests and runtimeType
can observe proxies; arbitrary Dart == implementations are not rewritten.

Future and Stream views guard delivered elements; async readonly results guard
at return. Await and await-for preserve readonly qualification. Event views
protect handler lists and reject subscription writes. Functions themselves remain
callable immutable references, not promises of side-effect freedom.

## Runtime artifact and module identity

Generated programs include `quds_readonly.dart` when needed. It is a standalone
Dart library using only SDK imports. API consumers must write **all**
Compilation.bundles with writeSdkBundles, not only Compilation.dart.
`relocateReadonlyRuntime(compilation, relativeUri)` lets a multi-directory graph
share one artifact; all participating modules must resolve to the same runtime
URI. The CLI build path does this under `.dart_tool/quds/out`. Temporary Quds test
modules share a single directory. Guard caches are weak Expandos; removed source
elements are not retained solely by the cache. Descriptor tables contain types,
not source instances. Nongeneric construction adds no registration allocation.

The canonical runtime is lib/src/readonly_runtime.dart. Run
`python3 tool/sync_readonly_runtime.py` after changes. An executable test verifies
that the embedded artifact matches the canonical source.

## Honest limits

- A Dart-native final/sealed implementation cannot generally be proxied with its
  original nominal type. Unsupported exported boundaries report E910; unknown
  nested native/generic payloads throw UnsupportedError on guarded access rather
  than returning a mutable object.
- Unknown foreign subclasses need generated metadata. Raw external generic
  instantiations whose arguments were never described may require a sealed guard
  descriptor; the compiler does not infer arbitrary runtime Type arguments.
- Mixin applications and sealed class hierarchies are excluded from proxy
  generation. Adding a proxy subtype to a sealed root changes Dart exhaustiveness,
  so unsupported readonly boundaries are rejected instead. Ordinary sealed
  programs keep their existing exhaustive matching behavior.
- Typed buffers retain native asUnmodifiableView behavior. Readonly does not add
  ownership, deterministic destruction, borrow checking or an alternative GC.

Primary coverage: test/readonly_classes.quds, supplemented by negative source
checks, actual VM/JavaScript mutation attempts, lazy-slot attacks, async results,
a runtime-source consistency check and a CLI build across dependency directories.
Exact final counts belong in VALIDATION.md.

## Debugger regression discovered during validation

The real DAP transcript exposed two stopped events for one startup pause: entry,
then breakpoint. A client continuing the first event resumed the breakpoint,
then received its queued stop after the isolate had exited. Unrequested internal
entry events are now suppressed without sending a continue; explicit stopOnEntry
remains visible. The actual Quds breakpoint/locals/evaluate integration test now
fails if frames are absent instead of marking that result skipped.
