# Weighted graphs in `quds:math`

Delivery B2 of the [expansion roadmap](MATH_EXPANSION_ROADMAP_AR.md).
The implementation is Quds source in `lib/sdk/math.quds`; the primary suite is
`test/math_weighted_graph.quds`, executed with `quds test`.

## Representation

`WeightedEdge(source: int, target: int, weight: double)` is an immutable value.
Vertex count is an explicit argument, so isolated vertices are preserved.
Vertices are indexed from zero. Parallel edges and self-loops are allowed.
Shortest-path functions treat edges as directed; the spanning forest treats each
pair as undirected regardless of the stored orientation.

Every algorithm validates the whole input before traversal. The following string
errors follow the existing SDK convention:

| Condition | Error |
| --- | --- |
| Negative vertex count | `weighted graph vertex count must be nonnegative` |
| Invalid edge endpoint | `weighted graph vertex out of range` |
| NaN or infinite edge weight | `weighted graph needs finite weights` |
| Invalid source, including any source on an empty graph | `weighted graph source out of range` |
| Any negative weight passed to Dijkstra, even unreachable | `dijkstra needs nonnegative weights` |
| Non-finite working distance/forest sum | `weighted graph sum overflow` |
| Negative cycle reachable from Bellman–Ford's source | `bellmanFord found a reachable negative cycle` |

Inputs are not mutated. Result arrays are fresh. Like other SDK value classes,
`ShortestPaths` and `SpanningForest` have immutable bindings to ordinary mutable
lists; this is not deep immutability. Edge values contain only primitive fields.

## Shortest paths

- `dijkstra(vertexCount, edges, source) -> ShortestPaths` accepts nonnegative
  finite weights, including zero. It uses dense vertex selection, with
  O(V²+E) time and O(V+E) auxiliary space. Equal keys settle the smallest vertex;
  strict relaxation retains the first predecessor that achieved a distance.
- `bellmanFord(vertexCount, edges, source) -> ShortestPaths` permits negative
  finite weights. A reachable negative cycle throws, while an unreachable one
  is ignored. It uses O(V*E+V) time and O(V) auxiliary space. Equal distances
  retain the first predecessor according to edge processing order.

`ShortestPaths.source` is the requested source. `distances` has one binary64
value per vertex; positive infinity means unreachable. `predecessors` contains
`-1` for unreachable vertices and the source points to itself.
`pathTo(target)` returns a fresh list including both endpoints, or an empty list
for an unreachable vertex. Same-source paths contain just the source. It is O(V).
Invalid targets throw `path target out of range`. Invalid sizes, non-finite
reachable distances or broken/cyclic predecessor chains encountered during
reconstruction throw `ShortestPaths has invalid state`.

Public result constructors do not certify arbitrary caller-supplied data, and
mutating their lists can invalidate the result. `pathTo` guards traversal, not
recomputes shortest distances or proves that a mutated chain belongs to a graph.

## Minimum spanning forest

`minimumSpanningForest(vertexCount, edges) -> SpanningForest` uses dense Prim
with O(V²+E) time and O(V+E) auxiliary space. It accepts finite negative and zero
weights. Loops are validated but never selected. Every disconnected component,
including an isolated vertex, contributes to `componentCount`.

Results contain the vertex count, component count, selected edge list and total
weight. An empty graph has zero components, zero edges and weight 0. Components
start at the smallest unvisited vertex; equal keys settle the smallest vertex,
and equal connecting weights keep the first edge. Selected edges retain their
original input orientation. The result has V-componentCount edges.

## Numerical limits

Weights, path sums and totals use binary64 arithmetic. Comparisons are strict,
without an arbitrary epsilon. Floating-point path sums round; near-zero cycles
can be ill-conditioned, and Bellman–Ford does not certify the sign of a cycle's
exact-real sum. Representability of a final answer does not guarantee that every
working sum is representable. A non-finite working sum conservatively rejects
rather than replacing a reachable distance with the unreachable sentinel.

There is no arbitrary size limit, but dense vertex selection costs O(V²), and
allocation can fail when inputs or outputs exceed available memory. These
algorithms are a correctness-first baseline, not a heap-based sparse-graph
performance claim.

## Quds example

```quds
use quds:math::graph::weighted

main():
  edges = [WeightedEdge(source: 0, target: 1, weight: 2.0), WeightedEdge(source: 1, target: 2, weight: 3.0)]
  shortest = dijkstra(4, edges, 0)
  print shortest.pathTo(2)                       # [0, 1, 2]
  print shortest.distances[2]                    # 5.0
  print minimumSpanningForest(4, edges).componentCount # 2
```

`use quds:math::graph::weighted` binds this section and not the unweighted graph functions. `use quds:math::graph` binds both, because `weighted` is part of `graph`. `use quds:math` still binds the whole library.

## Verification

```sh
dart run bin/quds.dart test test/math_weighted_graph.quds
dart test test/math_quds_test.dart test/math_accuracy_test.dart --reporter expanded
```

The Quds suite performs **224,537 assertions on 4357 weighted graphs**. It exhausts
edge states absent/-2/0/3 on all directed graphs with loops through two vertices,
and all loopless directed graphs on three vertices. Independent min-plus
Floyd–Warshall supplies distances/reachable negative-cycle expectations;
exhaustive edge-subset enumeration supplies minimum forest weights.

It checks path endpoints, costs and uniqueness, unreachable values, forest
connectivity and input preservation. Separate cases cover parallel edges, exact
deterministic order, disconnected components, malformed endpoints/sources,
NaN/infinity, reachable overflow and corrupted predecessor chains. A JavaScript
smoke additionally executes the three APIs and `pathTo` using the generated SDK.
This finite grid does not prove correctness or a uniform error bound for all
floating-point graphs.
