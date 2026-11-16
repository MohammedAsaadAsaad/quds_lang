# Typed numeric storage in quds:core

General storage belongs in `quds:core`; mathematical algorithms remain in
`quds:math`. This delivery re-exports existing Dart classes rather than adding
new language keywords, numeric literal meanings, or duplicate container names.

```quds
use quds:core::typed

main():
  samples = Float64List(4)
  samples[0] = 1.5
  borrowed = Float64List.sublistView(samples, 0, 2)
  borrowed[-1] = 2.5
  print samples[1] # 2.5: shared bytes
  snapshot = Float64List.fromList(samples)
  snapshot[0] = 9.0
  print samples[0] # still 1.5: copied elements
```

`use quds:core` includes these names alongside Array/Dict/HashSet and the
existing collections. `use quds:core::typed` selects only this section.
Both forms support `show`, `hide` and prefixes. `dart:typed_data` imports have
the same native type identity, even when the caller defines a distinct class
with the same short name.

## Public names

| Names | Stored representation | Quds element type |
| --- | --- | --- |
| Float32List | IEEE-754 binary32 | double, rounded on storage |
| Float64List | IEEE-754 binary64 | double |
| Int8List, Int16List, Int32List | Signed 8/16/32-bit integers | int |
| Uint8List, Uint16List, Uint32List | Unsigned 8/16/32-bit integers | int |
| Uint8ClampedList | 8-bit integers clamped to 0 through 255 | int |
| ByteData | Byte access with explicit numeric getters/setters and endianness | As named on each method |
| ByteBuffer | The backing byte buffer and its view constructors | No direct element indexing |
| TypedData | Common offset/byte-length/buffer interface | No direct element indexing |
| Endian | little, big and host byte order descriptors | Endian |

These are the actual Dart types, not Quds wrapper classes. Constructors and
native method signatures come from the installed Dart SDK. The compiler reads
concrete list element types and transitive interfaces from those SDK sources.
This delivery is tested with Dart 3.13.7.

Int64List, Uint64List and SIMD lists are not re-exported in this core section.
Direct Dart interop remains available subject to the underlying platform's
support. In particular this delivery does not promise portable exact 64-bit
integer arithmetic on JavaScript. ByteData's 64-bit integer methods retain
Dart's platform integer/precision limits; they are not BigInt operations.

## Allocation, copies and views

- `Float64List(n)` and corresponding numeric constructors allocate zero-filled,
  fixed-length storage. A Float64List region of n elements has n*8 payload
  bytes. `lengthInBytes` describes the region, not total process/heap overhead.
- `fromList(values)` copies elements into separate typed storage. Passing an
  ordinary list does not create a view of that list.
- `view(buffer, offsetInBytes, length)` shares a buffer. Offsets are absolute
  byte offsets in that buffer; length is in target elements. Default offset
  is zero and default length covers the compatible remaining region.
- `sublistView(data, start, end)` shares a region relative to the source view.
  Start/end count source elements; crossing element widths still requires
  valid target alignment and byte length.
- `sublist(start, end)` and Quds slices copy. For these concrete native arrays,
  slices preserve the native typed array and its fixed-length behavior.
- `buffer` is the backing buffer, potentially larger than the current view.
  To preserve the view's region use sublistView or include offsetInBytes and
  length explicitly. A small view can retain a larger backing allocation.
- Views share updates; they do not imply exclusive ownership. Use an explicit
  copy when independent data or a smaller retained allocation is required.

Indexing, negative list indices, assignment and compound updates reuse Quds's
existing collection semantics. `for`, membership, eager `map`, `toList` and
`setAll` work with the concrete element type. Native sublist/view signatures
retain their optional bounds. Invalid indices, ranges and alignment retain
Dart's runtime errors. Attempts to grow/shrink fixed-length arrays fail at
runtime; passing one as a List does not make it growable.

The arrays can satisfy `List<double>` / `Iterable<double>` or the corresponding
int interfaces without forcing callers to copy into ordinary lists. This does
not permit Float64List to satisfy mutable `List<num>`: mutable element types
remain invariant. Native declarations also satisfy their TypedData interface.
Existing math APIs accepting List<double> can receive Float64List directly;
the algorithm itself may still make its own documented work copies.

Integer narrowing follows Dart: Int8List stores 130 as -126, Uint8List stores
-1 as 255, and Uint8ClampedList stores 300 as 255. Float32List stores 0.1 as the
binary32 value 0.10000000149011612 when read as double. Float64List preserves
binary64 NaN, infinity and signed zero. Storage does not enforce the finite
input restrictions of individual math algorithms.

## Readonly

```quds
use quds:core::typed

main():
  writable = Float64List.fromList([1.0, 2.0])
  observed: readonly Float64List = writable
  writable[0] = 3.0
  print observed[0] # 3.0; readonly is a view, not a snapshot
```

The compiler rejects indexed writes and mutating calls through readonly typed
references. Qualification survives `capture` and follows buffer getters and native `as...` views, so
`observed.buffer.asFloat64List()[0] = value` is also rejected. Explicit copies
remain mutable.

Generated Dart uses native unmodifiable views for readonly typed expressions,
parameters and returns, including ByteData and ByteBuffer access paths. This
preserves native types and shared storage without copying numeric payloads.
For the common TypedData interface, the runtime guard dispatches to its concrete
SDK implementation's asUnmodifiableView; the SDK implementations expose that
method even though the common interface does not declare it. The guard retains
the concrete representation, byte offsets and element width.

Thus Dart or dynamic callbacks cannot mutate the returned guarded view, while
an independent original mutable alias can still change shared data. Views may
allocate wrapper objects; this is not a claim of allocation-free execution.
Existing generic object/FFI lifetime guarantees are not expanded by this API.

## Compiler integration and tests

Native type identities are distinct from source spellings. Prefixes, filtered
imports, inferred return types and generic Quds containers retain that identity.
The backend renders native type arguments, and diagnostics/completion/hover
present public names rather than internal type keys. Importing a filtered
re-export with an empty intersection binds no names.

Primary Quds suites:

```sh
dart run bin/quds.dart test test/typed_storage.quds
dart run bin/quds.dart test test/typed_storage_prefix.quds
dart run bin/quds.dart test test/typed_storage_core.quds
```

Their nine declarations cover every exported numeric array, integer narrowing,
float32 rounding, NaN/infinity/signed zero, zero filling, shared views, copies,
nested view offsets, slices, exact-element interfaces, loops/map/membership,
byte order, bounds/alignment/fixed length, prefixed identity, Stack storage and
actual mean/matvec calls from Quds.

`test/typed_storage_test.dart` launches those suites, checks rejected writes and
hidden names, and compiles `test/typed_storage_web.quds` to Dart and JavaScript.
Its interoperability driver attempts writes from Dart/dynamic callbacks to
readonly arrays, ByteData and ByteBuffer; they must fail while mutable-alias
updates remain visible. It also verifies the common readonly TypedData guard.
Final results are in [VALIDATION.md](VALIDATION.md).

The authoritative source is `lib/sdk/core.quds`; synchronize its embedded copy:

```sh
python3 tool/sync_sdk.py core
```

The same tool accepts ext/math or no arguments to synchronize all three SDK
libraries. This delivery does not add multidimensional tensor storage, strided
views, GPU/BLAS bindings or performance guarantees; those remain separate work.
