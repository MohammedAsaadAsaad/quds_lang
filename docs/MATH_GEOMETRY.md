# Exact planar geometry for binary64 inputs

Delivery C3 provides exact 2D predicates, segment intersection, convex hulls,
polygon containment and signed area in `quds:math`. It does not provide polygon
Boolean operations, triangulation, 3D predicates, quaternions or mesh algorithms.

## Exact input meaning

`binaryFraction(value)` returns the exact `BigFraction` represented by a finite
binary64 value. For example 0.1 becomes
`3602879701896397/36028797018963968`, not 1/10. Negative zero becomes rational zero.
There is no conversion through a fixed-width integer. At most 1074 exact binary
doublings are required before conversion to BigInt, including subnormal inputs.
NaN or infinity throws `binaryFraction needs a finite value`.

The geometric predicates operate on these exact rational coordinates. They do
not recover decimal precision lost before the function call; if computing an
input already rounded away a displacement, no predicate can reconstruct it.

## Contracts

| API | Meaning |
| --- | --- |
| `orientation2D(a,b,c)` | +1 for counterclockwise, -1 for clockwise, 0 for collinear |
| `segmentsIntersect(a,b,c,d)` | Closed segments ab and cd intersect, including touches, overlaps and zero-length segments |
| `polygonSignedAreaExact(vertices)` | Rational signed shoelace area; positive for CCW orientation |
| `pointInPolygon(point,vertices,includeBoundary: true)` | Nonzero winding rule, with explicit boundary inclusion |
| `convexHull(points)` | CCW hull beginning at the lexicographically smallest vertex, without a closing duplicate |

All use the existing immutable `Vec2` values. Every coordinate must be finite;
invalid coordinates throw `geometry needs finite coordinates`, including those
in degenerate or otherwise unused portions of input lists.

Orientation and intersection do not use a rounded floating cross product or an
epsilon. Consequently a determinant as small as 1e-600 or as large as 1e616 can
still have its exact sign determined from the represented inputs.

Polygon area counts algebraic signed area of the vertex walk, not the area of a
Boolean union. Repeated closing vertices are accepted. Self-intersecting or
repeated walks have their signed shoelace area; traversing a square twice doubles
that area. Empty, single-point and two-point walks have zero area.

Containment uses nonzero winding, not even/odd filling. Empty polygons contain
nothing. Single-point and segment walks have boundary only; includeBoundary=false
rejects those boundary points. Repeated vertices and self-intersections are not
silently repaired. Multiple contours/holes need a separate future interface.

Hull duplicates are removed by coordinate equality, including +0/-0 equivalence.
No nearby distinct coordinates are merged. Interior collinear vertices are
excluded. Degenerate results contain 0, 1 or 2 vertices, with collinear extremes
in lexicographic order. Stable sorting retains the first input value for equal
coordinates. Inputs are unchanged and the result list is fresh; immutable Vec2
objects may be shared with the input.

## Cost and numerical limits

Hull construction uses stable mergesort and a monotone chain: O(n log n) point
comparisons, O(n) exact orientation evaluations, O(n) peak list storage, and
O(n log n) cumulative list allocation. Binary64-to-rational conversion and BigInt
arithmetic add costs depending on coordinate bit representation. Segment and
orientation APIs use a constant number of such operations. Polygon area and
containment perform O(n) rational/predicate steps.

There is no fixed-width cross-product overflow/underflow and no tolerance-based
collinearity test. Computation still relies on the specified BigInt backend and
available memory. Exact area is returned as a rational rather than rounded or
clipped to a double.

## Quds example

```quds
use quds:math

main():
  square = [Vec2(x: 0.0, y: 0.0), Vec2(x: 2.0, y: 0.0), Vec2(x: 2.0, y: 2.0), Vec2(x: 0.0, y: 2.0)]
  print polygonSignedAreaExact(square)           # 4/1
  print pointInPolygon(Vec2(x: 1.0, y: 1.0), square) # true
  print convexHull(square).length               # 4
```

Quds supplies includeBoundary's default. Direct generated-Dart consumers pass all
positional arguments, including includeBoundary, as in the platform smoke test.

## Verification

```sh
dart run bin/quds.dart test test/math_geometry.quds
dart run bin/quds.dart test test/math_geometry_reference.quds
```

Six Quds declarations cover exact binary conversion, cross-product underflow and
overflow cases, degeneracies, deterministic hull order, list ownership, winding
rules, signed area and consistent finite-coordinate errors.

The independent frozen Quds suite has **738 reference cases** generated using
Python's standard-library `Fraction.from_float`:

- Exact numerator/denominator anchors, minimum subnormals and maximum finite input.
- Orientation across scales from 1e-300 to 1e300 and near-collinear neighbors.
- Segment intersections checked with rational parametric solutions.
- Hulls checked by Jarvis gift wrapping, independently of the SDK's monotone chain.
- Rational ray crossings for winding and exact shoelace area anchors.

Generation is `python3 tool/generate_geometry_reference.py`; execution needs no
Python. A JavaScript smoke verifies binary conversion, tiny orientation, hull,
area and containment using the generated library. The finite reference grid is
not a formal proof of the complete implementation or a performance guarantee.
