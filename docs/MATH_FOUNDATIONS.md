# Time series, finite logic and two-dimensional homology

This is a bounded foundation for roadmap domains 18/19/20, not completion of
those domains or of all twenty mathematical fields. Nine public functions and
three result classes are added to the existing SDK. Language syntax 1.2 is
unchanged. Source is `lib/sdk/math.quds`; `tool/sync_sdk.py math` updates the
embedded source. Root imports and the sections below share the same types.

## `quds:math::timeseries`

```quds
use quds:math::timeseries
main():
  print seriesDifference([1.0, 3.0, 6.0])
  print arForecast([1.0, 2.0], [1.0, 1.0], 0.0, 3)
  estimate = kalmanScalar(0.0, 1.0, 2.0, 0.0, 1.0)
  print estimate.meanValue
```

All results are binary64 approximations. Nonfinite inputs or nonfinite measured
intermediates/results throw; finite inputs are not a promise that every true
finite answer survives intermediate overflow/underflow.

| API | Contract |
| --- | --- |
| `seriesAutocovariance(samples, lag)` | Nonempty finite samples, `0 <= lag < n`. Whole-series mean, `sum((x[i]-mean)*(x[i-lag]-mean))/n`; denominator is **n**, not n-lag. Compensated accumulation. |
| `seriesAutocorrelation(samples, lag)` | Autocovariance divided by lag-zero autocovariance. Throws if computed variance is zero, including underflow; no invented correlation for constant input. |
| `seriesDifference(samples, lag=1)` | `x[i]-x[i-lag]`, `1 <= lag <= n`. Lag n yields a fresh empty list. Inputs are not modified. |
| `arForecast(history, coefficients, intercept, steps)` | Given coefficients in lag-1 through lag-p order, recursively predicts `intercept + sum(a[j]*latest[j])`. At least p historical samples; p <= 128; 0–10000 steps. Returns only forecast samples. This does not estimate parameters or fit ARIMA. |
| `markovStep(probabilities, rows)` | Row-vector distribution times row-stochastic matrix, size 1–128. Nonnegative finite probabilities and square rows; sums within absolute 1e-12 of one, and components at most 1+1e-12 to retain that same rounding tolerance on repeated steps. No silent normalization or clipping. Returns a new distribution. |
| `kalmanScalar(priorMean, varianceValue, observation, processVariance, measurementVariance)` | Scalar identity transition/observation model. P,Q >= 0, R > 0. Predict P'=P+Q, gain K=P'/(P'+R). Complement R/(P'+R) is computed independently, preserving a small prior contribution when K rounds to 1. Posterior variance uses Joseph form `complement²*P' + K²*R`. Overflow of P'+R throws. |

`KalmanEstimate` contains `meanValue`, `variance`, and `gain`. It represents one
predict/update step, not a multidimensional filter, smoothing or noise fitting.
No random draws or implicit sampling occur in these functions.

## `quds:math::logic`

```quds
use quds:math::logic
main():
  answer = solveCnf(2, [[1], [-1, 2]])
  print answer.satisfiable
  print answer.assignment
  print isPartialOrder([[true, true], [false, true]])
```

`solveCnf(variableCount, clauses)` enumerates assignments for 0–16 variables.
Signed literals are 1-based; zero and out-of-range literals throw. At most 512
clauses, and `(literalCount + clauseCount) * 2^variableCount <= 16000000` work
units. This is deliberately bounded enumeration, not an industrial SAT solver.

`SatResult.satisfiable` distinguishes an empty satisfying assignment from unsat.
Empty CNF is true, an empty clause is false, and repeated/tautological literals
have their normal Boolean meaning. The returned assignment is fresh, with
variable 1 in slot 0. The first satisfying binary mask is deterministic; variable
1 is its least significant bit. Unsat returns false and an empty assignment.
A work-limit failure throws and is never presented as proof of unsatisfiability.

`isPartialOrder(relation)` accepts a square Boolean matrix of size 0–128. It
checks reflexivity, antisymmetry and transitivity. Malformed shape/work limits
throw; a well-formed relation that is not an order returns false. The empty order
is valid. No lattice construction, SMT or theorem-proving engine is implied.

## `quds:math::topology::homology`

The parent `quds:math::topology` also imports this section.

```quds
use quds:math::topology
main():
  circle = simplicialHomology(3, [[0, 1], [1, 2], [2, 0]], [])
  print circle.betti1  # 1
  disk = simplicialHomology(3, [], [[0, 1, 2]])
  print disk.betti1    # 0
```

`simplicialHomology(vertexCount, edges, faces)` returns `Homology2` with the
ordinary (not reduced) Betti numbers `betti0`, `betti1`, `betti2` over F2.
Vertex count 0–128 includes isolated vertices. At most 256 supplied edges, 128
triangles and 256 edges after closure. Edges contain two distinct in-range
vertices; repeated undirected edges collapse. Faces contain three distinct
in-range vertices; repeated faces, regardless of ordering, throw. Triangle
boundaries are automatically included. No tetrahedron interior/3-simplex is
filled implicitly: its four boundary triangles form a 2-sphere with b2=1.

The edge incidence rank is V-b0; Gaussian elimination of the triangle boundary
matrix is exact over F2. Then b1=E-V+b0-rank(boundary2) and
b2=F-rank(boundary2). Empty complex returns all zeros. These integer operations
stay within both VM and JavaScript exact ranges under the work limits. No claim
is made for higher dimensions, integral torsion, persistent homology or manifolds.

The existing `eulerCharacteristic` keeps its 5000-vertex/2000-face limits, but
now rejects repeated triangles with `topology repeats a face`. Its documented
triangle-complex representation describes abstract simplices: counting repeated
faces twice while counting their edges once gave a different object. Multiple
2-cells with the same vertices would require a separate Delta/CW-complex
representation and contract. This explicitly tightens input validation; it does
not redesign an approved language syntax or silently deduplicate faces.

## Evidence and limits

- `math_foundations.quds`: 11 primary declarations, including invalid inputs,
  overflow, nonmutation, near-unit Kalman gain, **all 512** subsets of the nine
  normalized two-variable clauses against fixed truth masks, all 512 Boolean
  three-element relations (19 labelled partial orders), and all 16 subsets of
  tetrahedron boundary triangles with known ranks.
- `math_foundations_reference.quds`: **686** frozen references generated with
  Python standard-library Fraction arithmetic, covering covariance/ACF, AR,
  repeated Markov steps and scalar filtering. Generator has a fixed seed and
  is not needed to run tests. Mixed absolute/relative tolerance is 1e-12.
- `math_foundations_imports.quds`: section prefixes and nominal result types.
- `math_foundations_web.quds`: actual Quds API consumer analyzed and executed
  on VM and JavaScript/Node, including the 512 SAT families and homology.
- Generated private function aliases are omitted for standalone libraries;
  part-library private bridges are retained. This removes an unused generated
  alias exposed by analysis of the new private platform assertion helper.
  Automatically generated section combinators suppress unused_shown_name when
  an inferred nominal result is spelled through a backend alias; the unannotated
  prefixed SAT result in the platform fixture exercises this path.

This is reference/call-site coverage, not a proof of all numerical inputs or
all branches. [The twenty-domain review](MATH_20_DOMAIN_STATUS_AR.md) records
what remains. Final commands and results are in [VALIDATION.md](VALIDATION.md).
