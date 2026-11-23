# `quds:collection` API Reference

General-purpose collections, algorithms, and data structures library for Quds, implemented in `lib/sdk/collection.quds` and organized into 12 importable sections.

```quds
use quds:collection
use quds:collection::transform as col
use quds:collection::queue show Deque, PriorityQueue
use quds:collection::extensions
```

## Sections

### `:: types`
- `IndexedValue<T>(index: int, value: T)`
- `CollectionPair<A, B>(first: A, second: B)`
- `PartitionResult<T>(matching: List<T>, nonMatching: List<T>)`
- `MinMaxResult<T>(minimum: T, maximum: T)`
- `MapConflictPolicy` (`keepFirst`, `keepLast`, `fail`)
- `SetDiff<T>(added, removed, common)` (`isEmpty`)
- `MapDiff<K, V>(added, removed, changed, unchanged)` (`isEmpty`)
- `ListDiffOp` (`keep`, `insert`, `delete`) and `ListDiffStep<T>(op, value)`
- `CollectionError(operation: String, message: String)`

### `:: query`
- `firstOrNull<T>(items: Iterable<T>) -> T?`
- `lastOrNull<T>(items: Iterable<T>) -> T?`
- `singleOrNull<T>(items: Iterable<T>) -> T?`
- `firstWhereOrNull<T>(items: Iterable<T>, test: (T) -> bool) -> T?`
- `lastWhereOrNull<T>(items: Iterable<T>, test: (T) -> bool) -> T?`
- `elementAtOrNull<T>(items: List<T>, index: int) -> T?`
- `indexWhereFrom<T>(items: List<T>, test: (T) -> bool, start: int = 0) -> int`
- `lastIndexWhereFrom<T>(items: List<T>, test: (T) -> bool, start: int? = null) -> int`
- `countWhere<T>(items: Iterable<T>, test: (T) -> bool) -> int`
- `noneMatch<T>(items: Iterable<T>, test: (T) -> bool) -> bool`
- `allEqual<T>(items: Iterable<T>) -> bool`
- `isListSorted<T>(items: List<T>, compare: (T, T) -> int, strict: bool = false) -> bool`
- `minBy<T>(items: Iterable<T>, compare: (T, T) -> int) -> T?`
- `maxBy<T>(items: Iterable<T>, compare: (T, T) -> int) -> T?`
- `minMaxBy<T>(items: Iterable<T>, compare: (T, T) -> int) -> MinMaxResult<T>?`

### `:: transform`
- `indexedValues<T>(items: Iterable<T>) -> List<IndexedValue<T>>`
- `chunkList<T>(items: List<T>, size: int) -> List<List<T>>` (throws `CollectionError` if `size < 1`)
- `windowList<T>(items: List<T>, size: int, step: int = 1, partial: bool = false) -> List<List<T>>`
- `partitionList<T>(items: Iterable<T>, test: (T) -> bool) -> PartitionResult<T>`
- `groupBy<T, K>(items: Iterable<T>, keyOf: (T) -> K) -> Map<K, List<T>>`
- `groupFold<T, K, R>(items: Iterable<T>, keyOf: (T) -> K, initial: R, combine: (R, T) -> R) -> Map<K, R>`
- `associateBy<T, K>(items: Iterable<T>, keyOf: (T) -> K, onConflict: MapConflictPolicy = MapConflictPolicy.keepLast) -> Map<K, T>`
- `zipLists<A, B>(left: List<A>, right: List<B>) -> List<CollectionPair<A, B>>`
- `unzipPairs<A, B>(pairs: Iterable<CollectionPair<A, B>>) -> CollectionPair<List<A>, List<B>>`
- `flattenOnce<T>(nested: Iterable<Iterable<T>>) -> List<T>`
- `distinctBy<T, K>(items: Iterable<T>, keyOf: (T) -> K) -> List<T>`
- `interleave<T>(left: List<T>, right: List<T>) -> List<T>`
- `intersperse<T>(items: Iterable<T>, separator: T) -> List<T>`
- `scanLeft<T, R>(items: Iterable<T>, initial: R, combine: (R, T) -> R) -> List<R>`

### `:: sort`
- `sortedWith<T>(items: Iterable<T>, compare: (T, T) -> int) -> List<T>` (stable merge sort)
- `sortedByKey<T, K>(items: Iterable<T>, keyOf: (T) -> K, compareKeys: (K, K) -> int, descending: bool = false) -> List<T>`
- `lowerBound<T>(items: List<T>, target: T, compare: (T, T) -> int) -> int`
- `upperBound<T>(items: List<T>, target: T, compare: (T, T) -> int) -> int`
- `binarySearch<T>(items: List<T>, target: T, compare: (T, T) -> int) -> int`
- `topK<T>(items: Iterable<T>, k: int, compare: (T, T) -> int) -> List<T>`
- `bottomK<T>(items: Iterable<T>, k: int, compare: (T, T) -> int) -> List<T>`
- `reverseRange<T>(items: List<T>, start: int, end: int) -> List<T>`
- `rotateList<T>(items: List<T>, shift: int) -> List<T>`
- `shuffleSeeded<T>(items: Iterable<T>, seed: int) -> List<T>` (portable 31-bit Park-Miller LCG identical on VM and JS)

### `:: maps`
- `mapKeys<K, V, K2>(source, transform, onConflict: MapConflictPolicy = MapConflictPolicy.keepLast)`
- `mapValues<K, V, V2>(source, transform)`
- `filterMap<K, V>(source, test)` / `filterKeys<K, V>(source, test)` / `filterValues<K, V>(source, test)`
- `mergeMaps<K, V>(first, second, onConflict: MapConflictPolicy = MapConflictPolicy.keepLast)`
- `mergeMapsWith<K, V>(first, second, combine)`
- `invertMap<K, V>(source, onConflict: MapConflictPolicy = MapConflictPolicy.keepLast)` / `invertMapMulti<K, V>(source)`
- `pickKeys<K, V>(source, keys)` / `omitKeys<K, V>(source, keys)`
- `getOrPut<K, V>(target, key, create)`
- `mapFromPairs<K, V>(pairs, onConflict: MapConflictPolicy = MapConflictPolicy.keepLast)`

### `:: sets`
- `symmetricDifference<T>(first, second)`
- `isSubsetOf<T>(subset, superset)` / `isSupersetOf<T>(superset, subset)` / `isDisjoint<T>(first, second)`
- `frequencies<T>(items)` / `cartesianProduct<A, B>(left, right)`
- `Multiset<T>`: `Multiset.from`, `length`, `distinctCount`, `isEmpty`, `isNotEmpty`, `distinctElements`, `countOf`, `contains`, `add`, `remove`, `removeAll`, `clear`, `toCountMap`, `mostCommon`, `sum`, `intersect`

### `:: queue`
- `Deque<T>` (growable circular buffer, amortized O(1) at both ends): `Deque.from`, `addFirst`, `addLast`, `removeFirst`, `removeFirstOrNull`, `removeLast`, `removeLastOrNull`, `peekFirst`, `peekLast`, `at`, `setAt`, `clear`, `toList`, `length`, `isEmpty`, `isNotEmpty`
- `RingBuffer<T>(capacity: int)`: `push`, `tryPush`, `pop`, `popOrNull`, `peekOldest`, `peekNewest`, `at`, `clear`, `toList`, `capacity`, `length`, `isEmpty`, `isNotEmpty`, `isFull`
- `PriorityQueue<T>(compare: (T, T) -> int)` (binary min-heap): `PriorityQueue.from`, `add`, `addAll`, `peek`, `peekOrNull`, `removeFirst`, `removeFirstOrNull`, `clear`, `toSortedList`, `length`, `isEmpty`, `isNotEmpty`

### `:: assoc`
- `LruCache<K, V>(capacity: int, onEvict: ((K, V) -> void)? = null)`: `get`, `peek`, `put`, `remove`, `containsKey`, `clear`, `keys`, `capacity`, `length`, `isEmpty`, `isNotEmpty`
- `MultiMap<K, V>`: `add`, `addAll`, `valuesFor`, `containsKey`, `containsEntry`, `removeValue`, `removeKey`, `clear`, `toMap`, `keys`, `keyCount`, `totalLength`, `isEmpty`, `isNotEmpty`
- `BiMap<K, V>`: `put(key, value, force: false)`, `getByKey`, `getByValue`, `containsKey`, `containsValue`, `removeByKey`, `removeByValue`, `clear`, `inverse`, `toMap`, `keys`, `values`, `length`, `isEmpty`, `isNotEmpty`

### `:: specialized`
- `BitSet(bitLength: int)` (backed by `Uint32List`): `length`, `cardinality`, `isEmpty`, `isNotEmpty`, `getBit`, `setBit`, `clearBit`, `toggleBit`, `setAll`, `clearAll`, `nextSetBit(fromIndex)`, `setIndices`, `bitAnd`, `bitOr`, `bitXor`, `inverted`, `equalsBitSet`
- `DisjointSet(size: int)`: `size`, `componentCount`, `find`, `unite`, `connected`, `componentSize`, `components`
- `Trie<V>`: `length`, `isEmpty`, `isNotEmpty`, `put`, `get`, `containsKey`, `hasPrefix`, `remove`, `clear`, `entriesWithPrefix`, `keysWithPrefix`, `longestPrefixMatch`

### `:: equality`
- `listEquals<T>(first, second, itemEquals: null)` / `setEquals<T>(first, second)` / `mapEquals<K, V>(first, second, valueEquals: null)`
- `listHash<T>(items, hashOf: null)` / `unorderedHash<T>(items, hashOf: null)` / `mapHash<K, V>(source, keyHash: null, valueHash: null)`
- `Equality<T>`: `Equality.defaultOf<E>()`, `Equality.custom<E>(itemEquals, itemHash)`, `isEqual`, `hashOf`, `listsEqual`, `hashList`

### `:: diff`
- `diffSets<T>(before, after) -> SetDiff<T>`
- `diffMaps<K, V>(before, after, valueEquals: null) -> MapDiff<K, V>`
- `longestCommonSubsequence<T>(first, second, itemEquals: null) -> List<T>`
- `diffLists<T>(before, after, itemEquals: null) -> List<ListDiffStep<T>>`
- `applyListDiff<T>(before, steps, itemEquals: null) -> List<T>`

### `:: extensions`
- **Migrated from `quds:ext` (original contracts preserved, removed from `quds:ext` with no alias):**
  - `extend List<T> Lists`: `second`, `third`, `reversedCopy`, `without`, `keeping`, `chunk`
  - `extend Map<K, V> Maps`: `keysOf`, `missing`
  - `extend Set<T> Sets`: `without`
- **Opt-in forwarding extensions:**
  - `extend List<T> ListCollectionExtensions`: `firstItemOrNull`, `lastItemOrNull`, `elementOrNull`, `chunked`, `windowed`, `partitioned`, `rotated`
  - `extend Map<K, V> MapCollectionExtensions`: `pickedKeys`, `omittedKeys`, `filteredValues`, `invertedMulti`
  - `extend Set<T> SetCollectionExtensions`: `symmetricDiff`, `subsetOf`, `supersetOf`, `disjointWith`

`quds:core` (`Array`, `Dict`, `HashSet`, `Stack`, `Queue`, `Bag`, `:: typed`) remains intact and coexists cleanly with `quds:collection`.
