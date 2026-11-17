# Measured compiler/runtime baseline — L3.4

No approved syntax or evaluation order changes. No timing thresholds were added
to CI. This package measures phases and fixes one demonstrated emitter cost;
it does not introduce a speculative IR rewrite.

## Emitter experiment

`dart run tool/benchmark_emitter.dart` emits 250/1000/4000 typed functions after
lexing, parsing and analysis have finished. One warm-up, five measured samples,
Dart 3.13.7 Linux x64, five reported processors. The before run used `32e06c9`;
the after run replaces repeated scans of the entire accumulated output with an
incremental line counter. Multiline text still contributes all its newlines.
Redirected output does not advance the main output counter.

| Functions | Before median µs | After median µs |
| --- | ---: | ---: |
| 250 | 19151 | 4848 |
| 1000 | 235399 | 10615 |
| 4000 | 3248090 | 18919 |

All three emitted Dart SHA-256 values and all three mapping SHA-256 values match
before/after. Raw samples, bytes and tool metadata are in
`bench/results/emitter_before.jsonl` and `emitter_after.jsonl`. These are local
JIT diagnostic samples, with visible warm-up/noise, not application speed
promises or a statistical cross-machine benchmark. The scaling and code path
justify removing the repeated scan. Existing source-map and execution tests
remain correctness gates. Identical generated import directives are now emitted
once, preventing duplicate-import warnings for repeated imported nominal types.

## Existing CLI extended

```sh
dart run bin/quds.dart benchmark bench/language_workloads.quds \
  --measure --warmup 1 --repeat 5
```

The default command still checks assert-enabled/disabled VM output parity,
prints `parity ok` and aggregate `elapsed`; `--baseline` retains that aggregate
meaning. In measured mode the aggregate also includes the requested measurement
work, so compare only like-for-like invocations.

`--measure` adds one `metrics` JSON line (schema 1): initial Quds compile,
module/SDK staging, warm in-process Quds compilation samples, Dart AOT compilation,
and repeated AOT **process execution including startup**. Every AOT result must
match the debug/release checksum output. Compiler samples must retain identical
Dart text. Counts are bounded, repeat must be positive, and subprocess failures
produce a nonzero exit. SDK/metadata caches remain warm during warm compiler
samples; this is not a cold compiler measurement. Runtime warm-up means discarded
process launches, not shared JIT state.

The Quds workload covers fill/sum at 128, 8192 and 65536 elements, diagonal matvec,
copy versus shared view behavior, generic calls and closures. Expected output:
`2181009417.0` then `99990000`. The recorded run in
`bench/results/language_workloads.json` has a warm compiler median of 28084 µs,
Dart AOT compilation 1202555 µs, and AOT launch/execution median 10797 µs.
Those include the labels above; none is an isolated kernel throughput claim.
Source/Dart byte counts describe artifacts, not heap allocation or RSS.
Heap/allocation profiling, JS throughput and native BLAS/GPU are not measured here.

## Multi-file correctness

Benchmark now uses the same temporary module graph as test/analyze. Imported
nominal type annotations also redirect their generated Dart imports to that
graph. Previously a function returning an imported class tried to load an
unbuilt source-side `.dart` file. A regression runs Quds tests, analysis, and the
measured benchmark over such a module, and checks that no source-side Dart was
created. Exact validation results are in [VALIDATION.md](VALIDATION.md).

## Linux process RSS follow-up

`python3 tool/profile_workload_memory.py` uses Linux `wait4.ru_maxrss` for five
separate checksum-verified AOT child lifetimes after one discarded launch. It
compiles the fixed Quds workload in a temporary tree, and cleans that tree. Raw
results and tool version are in `bench/results/language_workloads_memory.json`.
This metric includes fork/exec and the pre-exec high-water mark: it can have a
launcher RSS floor. It is not an isolated Dart heap, allocation count, or payload
size, and cannot establish per-kernel memory efficiency. Python standard library
only; the script explicitly requires Linux for the KiB convention.

## Subsequent heap measurements

HEAP_AND_READONLY_GRAPH.md and bench/results/heap_vm.json / heap_web.json add
VM Service live heap/class counts/allocation traces and separate V8 allocation
sampling. They supersede the earlier absence of heap measurements, while keeping
RSS, payload, live heap and allocation-volume meanings distinct.
