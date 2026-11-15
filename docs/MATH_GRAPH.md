# Discrete graphs in `quds:math`

This is the first expansion package from [the math roadmap](MATH_EXPANSION_ROADMAP_AR.md).
It adds eight operations; it does not supply weighted graphs, flow, matching, or
symbolic graph invariants.

## Representation and shared contract

A graph is `List<List<int>>`. There are `graph.length` vertices, numbered from
zero. `graph[u]` contains outgoing neighbor indices. Isolated vertices have an
empty row. Edges may repeat, and self-loops are permitted in the representation.
Neighbor order is meaningful when choosing among shortest paths.

Every operation validates **all** neighbor indices, including unreachable rows.
An index outside `[0, graph.length)` throws the string `graph vertex out of range`.
Endpoint-based operations then validate source and target, in that order, throwing
`graph source out of range` or `graph target out of range`. This follows the
existing SDK's string-error convention; a future typed-error migration needs its
own compatibility decision.

All results are fresh lists, including nested rows. Inputs are neither mutated
nor retained in results. Integers denote counts and indices, with exact results
within the platform's representable/container limits. No floating tolerance is
used. Algorithms impose no arbitrary vertex-count cutoff; allocation can fail
when a graph or its requested output exceeds available memory.

| Function | Meaning and deterministic order | Time | Auxiliary space, including output |
| --- | --- | --- | --- |
| `transposeGraph(graph)` | Reverse edges; each result row follows ascending original source vertex and preserves multiplicity | O(V+E) | O(V+E) |
| `bfsDistances(graph, source)` | Directed shortest edge counts; source is 0, unreachable is -1 | O(V+E) | O(V) |
| `shortestUnweightedPath(graph, source, target)` | Endpoints included; equal-distance choices follow adjacency order; no path returns `[]`; same endpoints returns `[source]` | O(V+E) | O(V) |
| `weaklyConnectedComponents(graph)` | Ignore direction; members ascend, components ascend by minimum member | O(V+E) | O(V+E) |
| `stronglyConnectedComponents(graph)` | Mutual directed reachability; same canonical ordering as weak components | O(V+E) | O(V+E) |
| `topologicalSort(graph)` | Kahn FIFO; initial zero-indegree vertices ascend, newly ready vertices follow processing/neighbor order | O(V+E) | O(V) |
| `bipartiteColoring(graph)` | Ignore direction; return a 0/1 color per vertex, with each component's minimum vertex colored 0 | O(V+E) | O(V+E) |
| `transitiveClosure(graph)` | `output[u][v]` is true iff v is reachable from u, including a length-zero path | O(V*(V+E)) | O(V²+V) |

`topologicalSort` throws `topologicalSort needs an acyclic graph` on a directed
cycle, including a self-loop. Parallel edges are counted and removed separately.
The FIFO order is deterministic, **not** necessarily lexicographically minimal.

`bipartiteColoring` treats an edge in either direction as an undirected constraint.
It throws `bipartiteColoring needs a bipartite graph` for an odd cycle or self-loop.
Disconnected graphs are supported. Duplicate edges do not change colorability.

The six operations without endpoints return an empty list for an empty graph.
The two endpoint operations reject any endpoint on an empty graph.

The implementations use queues with a moving head and iterative DFS, not recursive
DFS. Mutable private work cells support constant-time state updates without
copying an entire list; those objects never escape to public results. This is
ordinary library code and does not change Quds binding or reference semantics.

## Quds example

```quds
use quds:math

main():
  noEdges: List<int> = []
  graph: List<List<int>> = [[1, 2], [3], [3], noEdges]
  print bfsDistances(graph, 0)                 # [0, 1, 1, 2]
  print shortestUnweightedPath(graph, 0, 3)    # [0, 1, 3]
  print topologicalSort(graph)                # [0, 1, 2, 3]
  print stronglyConnectedComponents(graph)    # [[0], [1], [2], [3]]
  print bipartiteColoring(graph)              # [0, 1, 1, 0]
```

The explicitly typed empty row keeps empty-collection inference unambiguous.
The import also supports the existing `as`, `show`, and `hide` facilities.
Dart clients can import the generated bundle using the same function names and
ordinary positional arguments.

## Verification

```sh
dart test test/math_graph_test.dart --reporter expanded
dart run bin/quds.dart test test/math_graph.quds
```

The Dart tests compile the real Quds SDK and execute its unchanged generated API.
Their separate fixture uses min-plus Floyd–Warshall for distances, boolean closure
for connectivity, and exhaustive candidate colorings for bipartiteness. It checks:

- All 531 directed graphs with loops on 0–3 vertices.
- All 1100 simple undirected graphs on 0–5 vertices.
- 64 fixed-seed directed multigraphs on seven vertices: **1695 graphs total**.
- Every source/target path, every distance, partitions, reachability, edge order
  constraints, cycle rejection, input preservation, and deterministic tie examples.
- Exact error messages for malformed edges and endpoints, including unreachable
  malformed rows and empty graphs; independent output ownership checks.
- A 20,000-vertex chain, exercising iterative DFS and linear-work algorithms.

The fixture executed **119,740 exact checks on 1695 graphs on each of Dart VM
and JavaScript/Node**, with zero failures on both. Node's absence is reported
as an explicit execution skip after JavaScript compilation. The graph count and
positive assertion count are checked by the test harness. These finite checks do
not prove correctness for every graph or a measured performance bound.

The 13 Quds test declarations separately exercise language calls, prefix/show
imports, matchers and error handling through the CLI. They run as part of
`dart test` as well as the explicit CI Quds command.
