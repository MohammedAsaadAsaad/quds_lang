# Integer flow and bipartite matching in `quds:math`

Delivery B4 of the [expansion roadmap](MATH_EXPANSION_ROADMAP_AR.md).
The implementation is Quds source in `lib/sdk/math.quds`, sections
`graph::flow` and `graph::matching`. `use quds:math::graph` includes both.
The primary suite is `test/math_flow.quds`, executed with `quds test`.

Capacities and matching are integral. They are separate from the binary64
weights of `graph::weighted`.

## Flow

`FlowEdge(source: int, target: int, capacity: int)` is an immutable value.
`maximumFlow(vertexCount, edges, source, sink) -> MaximumFlow` computes an
integral maximum flow by Edmonds–Karp (breadth-first residual search).

`MaximumFlow.flows` follows the input edge order. `MaximumFlow.sourceSide`
is the set of vertices reachable from the source in the final residual graph,
sorted ascending. The capacity of original edges that leave this set equals
`value`. Another minimum cut may exist; the contract is this residual cut.
A feasible flow of that value is not always unique.

Zero capacity is valid and carries no flow. A self-loop is validated, rejected
when its capacity is negative, and carries zero flow. Parallel edges stay
separate. The input list is not mutated. Result lists are fresh bindings to
ordinary lists; this is not deep immutability.

Every edge is validated before search.

| Condition | Error |
| --- | --- |
| Negative vertex count | `flow vertex count must be nonnegative` |
| Invalid edge endpoint | `flow vertex out of range` |
| Negative capacity | `flow capacity must be nonnegative` |
| More than 64 vertices or 1024 edges | `flow exceeds the work limit` |
| Invalid source | `flow source out of range` |
| Invalid sink | `flow sink out of range` |
| Source equal to sink | `flow source and sink must differ` |
| A flow total outside the platform int | `integer result is outside int range` |

The work guard is a complexity bound. Edmonds–Karp is O(VE(V+E)). An internal
certificate checks capacity bounds, loop flow, conservation, and that the
returned cut capacity equals the flow. A failed certificate throws
`maximumFlow has invalid state`.

## Matching

`MatchEdge(left: int, right: int)` is one left-to-right incidence.
`maximumMatching(leftCount, rightCount, edges) -> Matching` finds a maximum
cardinality matching by iterative breadth-first augmenting paths. Unmatched
entries are `-1`. `leftMate[left] == right` exactly when `rightMate[right] == left`.

Parallel copies do not increase the size. Free left vertices are scanned in
increasing index, and neighbors in input order. Several maximum matchings may
exist; tests compare size and consistency with an independent enumeration,
and pin the mates only when that order makes them unique.

| Condition | Error |
| --- | --- |
| Negative side count | `matching side count must be nonnegative` |
| Invalid endpoint | `matching vertex out of range` |
| More than 200 vertices on a side, or 2000 edges | `matching exceeds the work limit` |

A failed internal certificate throws `maximumMatching has invalid state`.

## What the suite checks

The Quds oracle enumerates every directed 0/1 network on 2, 3, and 4 vertices
with source 0 and sink at the last vertex (4164 graphs, 58012 checks) and
compares the flow with the minimum cut over subsets of the middle vertices. It
also checks conservation, capacity, and the returned residual cut. Bipartite
graphs with at most three vertices on each side (682 graphs, 5040 checks) are
compared with a subset-enumeration maximum. Neither oracle is a second copy of
the search.
