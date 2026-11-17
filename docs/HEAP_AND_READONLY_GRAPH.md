# Heap measurements and identity-aware readonly collections

This package closes the collection and measurement gaps recorded in
LANGUAGE_MEMORY_COMPLETION_AR. This originally shipped before the custom-class
and native-generic packages; their subsequent completion is documented in
READONLY_CLASSES.md and DART_GENERIC_METADATA.md.

## Primary Quds behavior

`test/readonly_graph.quds` executes mutable Set elements, mutable Map keys,
stable nested collection views, and a method-default scope regression.
The views are lazy and follow the original storage. Independent mutable aliases
remain writable. Set contains/lookup and Map lookup accept both the original
key and its protected view, including a protected key from another generated
Dart library. Repeated element reads return the same protected element.

The emitter uses typed ListBase/SetBase/MapBase views, with weak Expando caches
keyed by original object and instantiated type. Reverse caches remain private.
A cross-library matching protocol returns only a Boolean, never the original
mutable source. Keys and values are guarded recursively. Writes throw
UnsupportedError at runtime and statically known nested writes are E307.
Readonly keys may be used for reads; insertion still requires the declared
mutable key type. This does not turn a protected reference into a mutable one.
Native typed-data views retain their native unmodifiable implementation.

Guard views are distinct runtime objects; they do not promise Dart identical
with a mutable source. The supported identity contract is stable protected
elements and correct membership/lookup while original storage remains shared.
The cache is weak: the heap workload keeps a protected outer view alive, removes
its inner source list, requests GC, and verifies that its 1000 HeapCell objects
are no longer alive. It does not keep removed elements alive through the cache.

The memory workload exposed another compiler defect: a method with defaults
could be analyzed as a free function before its class was analyzed. Declaration
owners now restore its class scope, and the Quds regression mutates a field
through both omitted and explicit arguments.

## Dart VM heap and allocation measurements

```sh
dart run tool/profile_heap.dart
```

The actual Quds program is `bench/memory_workload.quds`. After warm-up it stops
at six explicit instrumentation points. The driver connects to VM Service on
loopback, waits for a runnable isolate, and records heapUsage, heapCapacity,
externalUsage, live class counts and allocation traces. It enables the VM
profiler before class allocation tracing: Dart 3.13.7 crashed in its allocation
sampler when tracing was enabled without that initialization. No fallback to
RSS or skipped measurement is counted as success.

HeapCell: zero live at baseline, 20000 retained, zero after release/requested
GC. The eight 65536-element Float64List buffers have 4194304 requested payload
bytes. This VM accounts their live data in its Dart heap (externalUsage is zero),
so the report does not assume every typed buffer uses external memory.

ClassHeapStats counters alone did not preserve the collected temporary copies
at these observation points. Cumulative allocation traces, including collected
objects, show Float64List counts 8 → 109 → 110: the copy phase allocates one
source plus 100 copies; the view phase one source plus 100 Float64ArrayView
objects sharing that source. Trace counts are actual recorded allocations;
requested buffer capacity is separately labelled payload, not total allocated
heap bytes. Exact observations and tool version are in bench/results/heap_vm.json.
GC and allocation tracing perturb execution; this is not a throughput benchmark.

## JavaScript/V8 measurements

```sh
dart run tool/profile_web_memory.dart
```

The same Quds source is compiled with Dart's JavaScript backend and run in Node.
Dart 3.13.7's developer patch calls a host debugger function; the profiling host
supplies a synchronous phase hook. It records V8 heap statistics and
process.memoryUsage after requested GC, and Inspector allocation sampling at
128-byte intervals with collected objects included. Sampling totals are
estimates, not exact allocation counts. Program-stack totals are separated from
all sampled instrumentation/runtime allocations. Raw Node/V8 versions and
phase records are in bench/results/heap_web.json.

ArrayBuffer backing-store reclamation can lag a GC request: transient copies
may remain accounted at the copy stop and disappear at a later stop. These
observations must not be labelled a leak or a guaranteed immediate free.
Checksum 213097200 is verified independently in both drivers. RSS, heap usage,
heap capacity, external backing stores and sampled allocation volume are distinct
metrics. There are no brittle timing/heap-byte thresholds in CI.

Final commands, pass counts and any debugger skip are in VALIDATION.md.

## Class-guard follow-up

The follow-up run in READONLY_CLASSES repeats both VM/V8 drivers after the class
guard changes. The weak graph now also reads `view[0][0].value`, so it creates a
HeapCell proxy before removal. VM live source counts remain 0 → 20000 → 0, and
zero after removing the weak graph. Raw files were refreshed; allocation trace
counts remain 8 → 109 → 110 Float64List and 100 view allocations.
