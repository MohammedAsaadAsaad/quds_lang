# Compiler validation — latest 2026-11-16

## Collection inference and generic interface contracts — L3.2b — 2026-11-16

Contract, examples and remaining limitations:
[COLLECTION_INFERENCE_INTERFACES.md](COLLECTION_INFERENCE_INTERFACES.md).

| Check | Observed result |
| --- | --- |
| Baseline probes | Map<K,V> inference and List-to-Iterable<T> inference failed with E500; an instantiated interface implementation failed with E700 |
| Primary Quds suites | **22 declarations passed**: 16 collection cases and six interface cases |
| New focused runner | **29 passed**: primary suites, 26 rejected programs, original diagnostic spans, deterministic golden and backend execution |
| Combined focused check with L3.1/L3.2a runners | **73 passed**, including all previous nullability/constraint cases |
| Generated Dart | Exact `collection_interfaces.dart.txt` golden matched; `dart analyze --fatal-infos` passed |
| Dart VM and JavaScript/Node | Quds fixture passed on both with marker `COLLECTION INTERFACES OK`; argument side effects remained once and in source order |
| `dart pub get` | Passed; dependency constraints retained |
| Isolated debugger regression | One passed, zero skips; no debugger timing fix claimed |
| Final `dart format .` | 45 files; zero pending changes |
| Final `dart analyze` | No issues |
| Final `dart test --reporter expanded` | **378 passed; zero failures; one skip** in 7m54s. The skipped debugger case passed separately on the final tree |
| `git diff --check` | Passed |

Inference uses shared structural type traversal and per-candidate evidence, with
post-substitution compatibility and bound checks. Mutable collection invariance
is maintained through generic calls. Expected context reaches nested Map values
and empty collection/return blocks. Substitution is simultaneous and preserves
nullable function/result boundaries. The emitter retains inferred function
arguments and instantiated inherited interface contracts.

The first focused regression run caught a new failure in explicit dependent
calls from L3.2a. Supplying the known explicit substitution to the same candidate
checker fixed it; the combined focused run passed all 71 tests before the two additional getter
regressions; the final focused run above passed 73.
The backend fixture also exposed unsupported `return map:` parsing; the existing
literal syntax now works there and receives declared return context.
The first full run finished with 375 passes, one failure and one skip. The
failure exposed null rejected against a concrete nullable parameter in the new
matcher; it now accepts the nullable shell without inventing inner generic
evidence. A new Quds declaration covers this, the original language test passed
in isolation, and the 71 focused tests passed again. The skipped debugger test
reported empty stackFrames after retries and passed in isolation. A subsequent
full run was deliberately interrupted to add two getter-kind rejections (a
write-only property and a method used as a function-valued getter). That
interrupted run is not a completed validation. The final stable run in the
table is authoritative; no fix to the debugger timing race is claimed.
No approved syntax was redesigned. Generic interface methods and the broader
inference/variance/external-type cases listed in the contract remain outside
this delivery; L3.2 is not declared complete.


## Generic argument constraints — L3.2a — 2026-11-16

The first part of L3.2 checks Quds generic applications, without claiming all
inference/interface work is complete. Contract and limits:
[GENERIC_CONSTRAINTS.md](GENERIC_CONSTRAINTS.md). Agent continuation plan:
[LANGUAGE_NEXT_STAGE_HANDOFF_AR.md](LANGUAGE_NEXT_STAGE_HANDOFF_AR.md).

| Check | Observed result |
| --- | --- |
| Baseline probes | Incorrect arity and invalid numeric bounds in annotations were accepted; a valid dependent bound was rejected; a nullable implementing type incorrectly satisfied a nonnullable interface bound |
| Primary `quds test test/generic_constraints.quds` | **Nine declarations passed**: explicit/inferred and dependent constructor bounds, explicit generic functions, forwarding bound evidence, nested fields, numeric/nullable/interface bounds |
| Final `dart test test/generic_constraints_test.dart --reporter expanded` | **25 passed**: primary Quds runner, 22 invalid programs, original diagnostic spans, deterministic golden and backend integration |
| Dart golden + analysis | Exact output matched `test/goldens/generic_constraints.dart.txt`; generated program passed `dart analyze --fatal-infos` |
| Dart VM + JavaScript/Node | Quds fixture executed on both with marker `GENERIC CONSTRAINTS OK`; explicit type arguments and once-only argument order retained |
| `dart pub get` | Passed; dependency constraints retained |
| Final `dart format .` | 44 files; zero pending changes |
| Final `dart analyze` | No issues |
| Final `dart test --reporter expanded` | **350 passed; zero failures; zero skips** in 7m29s |
| `git diff --check` | Passed |

The shared checker validates argument count/types and substitutes dependent
bounds for annotations, explicit functions and explicit/inferred constructors.
Bound evidence is scoped, explicit function arguments seed result inference,
and explicit arguments survive Dart emission. Interface inheritance no longer
discards whole-value nullability during compatibility checks.

An initial complete-project run was intentionally interrupted to add the
confirmed nullable-interface regression and fix. Its interrupted tests are not
reported as a completed validation; the final stable run above is authoritative.
No syntax redesign or math API additions are included. Map/callback inference,
generic interface inheritance/substitution and external metadata remain future
L3.2 work; L3.3/3.4 also remain open.


## Function type nullability and composition — 2026-11-16

First implementation package from
[LANGUAGE_NEXT_STAGE_HANDOFF_AR.md](LANGUAGE_NEXT_STAGE_HANDOFF_AR.md).
Contracts and remaining scope: [FUNCTION_NULLABILITY.md](FUNCTION_NULLABILITY.md).

| Check | Observed result |
| --- | --- |
| Baseline reproduction | `((int) -> int?)?` combined with a fallback callback failed with E300 before the fix; the same program now executes |
| Primary `quds test test/function_nullability.quds` | **16 declarations passed**, covering callback/result null layers, aliases, promotion, fallback, assertions, null assignment, higher-order functions, nested collections, records, variance and evaluation order |
| `dart test test/function_nullability_test.dart --reporter expanded` | **19 passed**: Quds runner, 15 rejected programs, independent test promotion scopes, original diagnostic spans, golden output plus backend execution |
| Generated Dart golden | Exact deterministic output matched `test/goldens/function_nullability.dart.txt`; generated program analyzed with `--fatal-infos` without issues |
| Dart VM + JavaScript/Node | Quds fixture executed successfully on both; marker `FUNCTION NULLABILITY OK` |
| `dart pub get` | Passed; existing dependency constraints retained |
| `dart analyze` | No issues |
| `dart format .` | 43 Dart files; zero pending changes |
| Final `dart test --reporter expanded` | **325 passed; zero failures; zero skips** in 7m32s |
| `git diff --check` | Passed |

Shared structural type operations distinguish top-level function nullability
from nullable results, ignore arrow `>` when splitting generic parameters,
and preserve record delimiters. Invocation and compatibility use these shapes;
Dart emission recursively renders function types nested in generic and record
types. Nullable results no longer satisfy nonnullable `Object`. Test declarations
save/clear/restore promotion facts so one test cannot make another's unsafe
callback call appear valid. Existing approved syntax remains unchanged.

This delivery does not complete all generic/readonly combinations or the math
expansion. The handoff identifies L3.2 as the next implementation package.


## Typed numeric storage in core — 2026-11-16

Added the native typed-storage section to `quds:core`, with the same names
available through `quds:core::typed`. Contracts and platform/precision limits:
[CORE_TYPED_STORAGE.md](CORE_TYPED_STORAGE.md).

| Check | Observed result |
| --- | --- |
| Primary Quds storage suites | **Nine declarations passed** across typed_storage.quds, typed_storage_prefix.quds and typed_storage_core.quds |
| Focused typed storage compiler/interoperability tests | **16 passed**, including unsafe writes, readonly capture, filtered exports, nominal identity, completion and hidden names |
| Dart VM + JavaScript/Node driver | Native storage smoke checks and readonly writes blocked across Dart/dynamic boundaries; mutable aliases remain visible |
| Compiler import-completion regression | Passed after adding the newly available core:: / typed suggestions to its exact expectation |
| Final `dart test --reporter expanded` | **306 passed; zero failures; zero skips** |
| `dart analyze` | No issues |
| Final format | 41 Dart files; zero pending changes |
| Embedded core synchronization | Byte-identical on repeat using `python3 tool/sync_sdk.py core` |
| `git diff --check` | Passed |

The SDK reuses Dart storage classes; numeric payloads are not copied by views.
Compiler integration reads concrete list element/interface metadata, retains
native identities across prefixes and generic type arguments, and protects
readonly native storage through captured references and runtime unmodifiable
views. Empty re-export filter intersections no longer expose all names.
An intermediate full run found a stale completion expectation (core previously
had no sections); the final stable run above passed with the new typed section
explicitly tested. No new syntax or reinterpretation of approved rules was
introduced. Strided views, broad generic Dart interop and backend performance
guarantees are outside this delivery.


## Language foundation: indexed mutation — 2026-11-16

This delivery strengthens the compiler before further math expansion.
Contracts, examples and remaining foundation work:
[LANGUAGE_NUMERIC_FOUNDATION.md](LANGUAGE_NUMERIC_FOUNDATION.md).

| Check | Observed result |
| --- | --- |
| Primary Quds indexed mutation suite | **10 declarations passed**: shared aliases, nested targets/order, negative indices, map keys/lookups, lazy defaults, compound operations, bounds, async, Result propagation and nullable nested literals |
| Focused `dart test test/index_assignment_test.dart --reporter expanded` | **16 passed**, including readonly method aliases, original diagnostic spans and 12 unsafe-access cases |
| Quds JavaScript fixture | Compiled with Dart to JavaScript and executed with Node; marker `INDEX WEB OK` |
| Final `dart test --reporter expanded` | **290 passed; zero failures; zero skips** |
| `dart analyze` | No issues |
| Final format | 40 Dart files; zero pending changes |
| `git diff --check` | Passed |

The typed AST now represents indexed assignment, with target/value traversal
for source maps and Result propagation. Receiver and indices are evaluated once;
indexed writes retain shared-object behavior, negative-list indexing, lazy
null-coalescing and compound-update order. Map reads correctly admit absent
keys, while writes check stored value types. Readonly instance-field views
cannot be made mutable by introducing a local alias inside a readonly method.
Contextual list element types support nullable/nested literals without relaxing
invariance of mutable collection references. Existing compiler and all math
suites passed on the final tree. No approved syntax was redesigned.


## Symbolic domain audit and imported sibling types — 2026-11-16

Public math functions remain **380**. Contracts and limitations:
[MATH_SYMBOLIC.md](MATH_SYMBOLIC.md).

| Check | Observed result |
| --- | --- |
| Primary Quds symbolic reference suite | **1475 exact cases passed on 59 polynomials**, including dense degrees 9, 12 and 16 at five rational points |
| Hand-written Quds symbolic suite | **Eight declarations passed**: singular domains, safe identities, zero powers, zero/cancelling polynomials, exactly-once nested calls and degree/work boundaries |
| Quds section import suite | Passed with hidden sibling BigFraction metadata and distinct caller BigFraction / private _PhaseState classes |
| Focused compiler regression suite | **Nine passed**: forty nested calls, hidden type rejection, foreign constructor types and existing compiler guards |
| Final `dart test --reporter expanded` | **274 passed; zero failures; zero skips** |
| `dart analyze` | No issues |
| Final `dart format --output=none --set-exit-if-changed .` | 39 files; zero pending changes |
| JavaScript + Node | Symbolic domain and zero-power checks passed alongside all existing math/graph interoperability checks |
| Repeated generators and SDK synchronization | Five artifacts byte-identical, including the supplemental Dart reference fixture |
| `git diff --check` | Passed |

The initial Quds repro showed `0*(1/x)` incorrectly simplify to zero, and the
documented degree-16 integration case incorrectly throw unsupported above
exponent 8. Zero products now require a conservative totality proof; powers up
to 16 honor the integration contract. Zero-power differentiation explicitly
avoids introducing a reciprocal singularity as that proof becomes stricter.

Class signatures are validated in the defining library, and foreign field /
constructor types retain nominal identity. Private SDK metadata uses internal
keys rather than colliding with caller private class names. Successful argument
checks are reused locally; competing overload trials retain their selected
contextual check. The new polynomial oracle only evaluates trees and compares
against Python Fraction formulas, rather than differentiating/integrating its
own expected AST.

An intermediate full run before adding the upper-degree references had 273
passes and the existing empty-frame debugger skip. The final stable tree above
passed all 274 tests without skips. No debugger retry or suppression was added;
this result does not establish that the pre-existing adapter race is fixed.


## Integrated binary64 / interval delivery — 2026-11-16

Integrated with `a5f1e6e`, preserving the concurrent library sections, flow,
matching and numbered-plan additions. Public math functions: **380**.
`RealInterval` supplements `OutwardInterval` in `interval::outward`;
its contract includes subnormals and unbounded endpoints. Neighbors are in
`scalar`. Details: [MATH_INTERVAL.md](MATH_INTERVAL.md).

| Check | Observed result |
| --- | --- |
| Full `dart test --reporter expanded --concurrency=2` | **268 passed; zero failures; one existing debugger skip** |
| Isolated debugger test | **One passed; zero skips**, using the exact name command recorded below |
| Primary interval references | **1138 passed** again on the integrated tree |
| Primary interval contracts | Five declarations passed |
| Primary section import test | Passed: prefixed sections, whole-library import, shared nominal types and both interval APIs |
| Focused compiler/parser tests | **18 passed**, including the added section identity and qualified parameter regressions |
| Concurrent plan / flow / matching Quds suites | Passed in the full run; plan marker 78, flow marker 58012 on 4164 networks; matching 5040 checks on 682 graphs |
| `dart analyze` | No issues |
| Final format | 39 Dart files; zero pending changes |
| JavaScript + Node | Math and graph checks passed, including binary64 and interval boundaries |
| Repeated generators and SDK synchronization | Four artifacts byte-identical |
| `git diff --check` | Passed |

Three compiler regressions were exposed by actual Quds imports and fixed:
SDK sections now share one parsed declaration identity, function lookahead
accepts qualified parameter types already supported by the type grammar, and
section `show` combinators retain classes referenced through prefixed types.
The debugger still skipped itself for empty frames in the parallel full run
and passed alone; no suppression was added and that race is not claimed fixed.


## Binary64 neighbors and outward-rounded intervals — pre-integration run 2026-11-16

Added `nextUp`, `nextDown`, `ulp`, `realInterval` and `RealInterval`.
The integrated SDK has **380** public top-level functions; this table records
the pre-integration run. A post-integration result will be recorded above it. Contracts and limitations:
[MATH_INTERVAL.md](MATH_INTERVAL.md).

| Check | Observed result |
| --- | --- |
| Primary `quds test test/math_interval_reference.quds` | **1138 reference cases passed**, using independent Python nextafter/ulp and Fraction extrema |
| Primary `quds test test/math_interval.quds` | **Five declarations passed**: IEEE boundaries, rounded decimal operations, unbounded reals, underflow/overflow and domain rejection |
| `dart analyze` | No issues |
| `dart format --output=none --set-exit-if-changed .` | 39 Dart files; zero changes |
| Full `dart test --reporter expanded` | **260 passed; zero failures; one skipped debugger integration test** |
| Isolated skipped debugger test | **One passed; zero skips** with `dart test test/compiler_test.dart --name 'quds debug stops on the quds line' --reporter expanded` |
| JavaScript + Node | Neighbor limits, signed zero, ULP, interval arithmetic and underflow/overflow checks passed with existing math/graph smoke suites |
| Regeneration | Embedded SDK, interval references, numerical references and API inventory byte-identical on repeat |
| `git diff --check` | Passed |

The pre-existing debugger test skipped itself in the parallel full run because
the Dart debug adapter returned an empty stack after its built-in retries.
It passed when rerun alone. No retry or suppression was added and this run does
not establish that the existing debugger race is fixed. No math test skipped.



## Numbered plan items 3–15

Public math functions: **376**. Contracts: [MATH_PLAN.md](MATH_PLAN.md) and [MATH_CONTRACTS.md](MATH_CONTRACTS.md).

| Check | Observed result |
| --- | --- |
| Quds plan suite | **78 expects, zero failures**, marker `QUDS PLAN CHECKS=78 FAILURES=0` |
| Hessian | `x*x*y` at `(2, 3)` is `[[6, 4], [4, 0]]`; `HyperDual.sqrt` at 0 throws |
| Phase I | The nonnegative example is value 12 at `[4, 0]`; a negative empty program throws `linearProgramPhase is infeasible` |
| Reverse mode | Same `[12, 4]` gradient as forward mode, from one callback |
| Exact reference | **1199 checks, zero failures** after renaming the local parameter that shadowed `decimal` |
| `dart analyze` | No issues |
| `dart test` | **264 passed, zero failures, zero skips** |

## Integer flow and bipartite matching — B4

Added `FlowEdge`, `MaximumFlow`, `maximumFlow`, `MatchEdge`, `Matching`, and
`maximumMatching` in `graph::flow` and `graph::matching`. Public math functions:
**326**. Contracts: [MATH_FLOW.md](MATH_FLOW.md).

| Check | Observed result |
| --- | --- |
| Quds flow oracle | **58012 checks on 4164 networks**, minimum cut by subset enumeration |
| Quds matching oracle | **5040 checks on 682 graphs**, maximum size by subset enumeration |
| Section import and completion | `use quds:math::graph` sees the flow, and `graph::` offers `flow`, `matching`, and `weighted` |
| `dart analyze` | No issues |
| `dart test` | **262 passed, 1 skipped, zero failures**. The skip is the existing debugger case after `debug adapter returned no stack frames after retries` |

## Exact planar geometry — C3

Added six public functions: `binaryFraction`, `orientation2D`,
`segmentsIntersect`, `polygonSignedAreaExact`, `pointInPolygon`, `convexHull`.
The SDK now has **324** public top-level functions. Contracts, exact binary64
input interpretation and exclusions: [MATH_GEOMETRY.md](MATH_GEOMETRY.md).

| Check | Observed result |
| --- | --- |
| Quds geometry references | **738 cases passed**, independently generated with Python Fraction, rational segment/ray intersections and Jarvis hulls |
| Hand-written Quds geometry suite | **Six declarations passed**, including subnormal/large coordinates, degenerate segments, winding, ownership and nonfinite rejection |
| Compiler regression suite | Six tests passed; List/Set implement Iterable with the same element type; element widening remains rejected |
| Final format | 39 Dart files; zero changes |
| `dart analyze` | No issues |
| Final `dart test --reporter expanded` | **259 passed; zero failures; zero skips** |
| JavaScript + Node | Exact binary fraction, subnormal orientation, hull, area and containment smoke checks passed |

The Quds tests exposed a missing collection interface compatibility rule, fixed
without relaxing generic element equality. The direct generated-Dart smoke
caller supplies the explicit containment boundary flag, as required by the
backend calling convention for Quds default arguments.


## Forward AD, gradients and Jacobians — C1 / first part of C2

Added `Dual`, `dualConstant`, `dualVariable`, `evaluateDual`, `autoDerivative`,
`autoGradient` and `autoJacobian`. Public math functions: **318**.
Contracts and limitations: [MATH_AUTODIFF.md](MATH_AUTODIFF.md).

| Check | Observed result |
| --- | --- |
| Quds analytic references | **598 cases**, each checking value and tangent against mpmath at 400 digits |
| Hand-written Quds AD suite | Nine declarations passed: arithmetic, domains, callback counts, empty dimensions, shape failures, ownership and extreme scales |
| Quds import/alias suites | Prefix and filtered imports passed, including inferred signature types and a distinct caller class/alias named Dual |
| Compiler rejection tests | Distinct nominal types, hidden source names and generated private aliases reject; existing list element compatibility remains enforced |
| `dart format --output=none --set-exit-if-changed .` | 39 Dart files; zero pending changes |
| `dart analyze` | No issues |
| Final `dart test --reporter expanded` | **256 passed; zero failures; zero skips** |
| JavaScript + Node | Scalar AD, gradient and Jacobian numeric checks passed with existing smoke tests |
| AD/numerical regeneration and embedded SDK synchronization | Byte-identical on repeat |
| `git diff --check` | Passed |

The compiler now distinguishes unary/binary operator arity and preserves nominal
identity in imported callback signatures. Inferred types hidden by source-level
show filters use private backend imports rather than leaking those source names.
Imported functions/classes resolve their own library bindings and do not let a
caller's alias redefine their mathematical types. Numeric generic widening was
not introduced: the existing List<int>-to-List<num> rejection remains tested.

An initial web smoke incorrectly compared the textual formatting of floating
numbers; it now checks numeric gradient components, since VM and JavaScript can
print integer-valued doubles differently. No numerical tolerance was weakened.

One intermediate parallel full run reported process status 113 for the old
1167-case numerical Quds suite after all its success markers, with empty stderr.
This could not be reproduced in isolation, in three concurrent runs, or in the
final complete rerun. The nonzero-status assertion remains unchanged; no retry
was added to tests or CI, and the cause is not established. This is retained as
an unresolved process anomaly rather than claimed as a fixed compiler defect.

AD thresholds are sampled-grid checks (relative 1e-10 plus three minimum-subnormal
units), not global error bounds. Hessians, reverse AD and tensors remain pending.


## Exact arithmetic foundation — delivery B3

Added BigInt interop/re-export, canonical rational arithmetic and seven exact
combinatorial functions. The SDK now has **312** public top-level functions;
all have Quds call sites. Contracts: [MATH_EXACT.md](MATH_EXACT.md).

| Check | Observed result |
| --- | --- |
| `quds test test/math_exact_reference.quds` | **1199 reference cases**, zero failures |
| `quds test test/math_exact.quds` | Six declarations passed: operators, normalization, raw/canonical distinction, imports, boundaries and errors |
| Compiler regressions | Typed BigInt result/operand checks and nullable rejection passed; filtered library imports retain their own BigInt types |
| `dart format --output=none --set-exit-if-changed .` | 39 Dart files; zero pending changes |
| `dart analyze` | No issues |
| `dart test --reporter expanded` | **251 passed; zero failures; zero skips** |
| JavaScript + Node | BigInt arithmetic, factorial/Fibonacci and rational normalization passed, alongside existing smoke checks |
| Reference generation and embedded SDK synchronization | Byte-identical on repeat |
| `git diff --check` | Passed |

Independent references use Python integers/Fraction, inclusion-exclusion for
Stirling, convolution for Catalan and Euler's pentagonal recurrence for integer
partitions. Running the committed Quds files requires no Python. Case counts
include multi-assertion rational normalization checks and are not a count of
independent mathematical theorems.

SDK operator metadata previously discarded Dart operators. They are now read and
statically checked, including the distinct unary/binary minus signatures; no
BigInt operation is hardcoded as dynamic. A filtered math import also exposed
validation of a private class's BigInt field against the caller rather than its
own library scope. The scope/type lookup was corrected, and the full rerun passed.
No syntax was added. Decimal, rigorous intervals and other roadmap work remain.


## Weighted graphs — delivery B2

Added `WeightedEdge`, `ShortestPaths`, `SpanningForest`, `dijkstra`, `bellmanFord`
and `minimumSpanningForest`. Public top-level math functions: **303**.
Contracts and numerical limits: [MATH_WEIGHTED_GRAPH.md](MATH_WEIGHTED_GRAPH.md).

| Check | Observed result |
| --- | --- |
| `quds test test/math_weighted_graph.quds` | Four declarations passed; **224,537 assertions on 4357 graphs** |
| Independent Quds oracles | Floyd–Warshall for paths/cycles, exhaustive edge subsets for forest optimality |
| `dart format .` / final format check | 39 Dart files; formatted; final check has zero changes |
| `dart analyze` | No issues |
| `dart test --reporter expanded` | **248 passed; zero failures; zero skips** |
| JavaScript + Node | Existing smoke plus all three weighted APIs and path reconstruction passed |
| Earlier Quds numerical/unweighted suites | Passed unchanged, including 1167 numerical and 151,457 unweighted graph assertions |
| `git diff --check` | Passed |

Input domains, deterministic ties, parallel edges, disconnected graphs, negative
cycles, malformed endpoints, NaN/infinity, sum overflow and invalid predecessor
chains have Quds tests. The exhaustive graph grid uses small exactly representable
integer weights; it is not a certificate for arbitrarily ill-conditioned real
weights. No language syntax changed. Other roadmap deliveries remain outstanding.


## Quds-first math tests and compiler corrections

Mathematical behavior is now tested primarily in `.quds` suites through
`quds test`. Dart/JavaScript numerical fixtures remain supplemental platform
checks. This policy is recorded in `AGENTS.md`, and CI executes the direct Quds
suites before `dart test`. The SDK still has 300 public top-level functions;
this change adds tests and compiler fixes, not new mathematical domains.

| Command/check | Observed outcome |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | 39 Dart files; zero pending formatting changes |
| `dart analyze` | No issues |
| Final `dart test --reporter expanded` | **247 passed; zero failures; zero skips** |
| `quds test test/math_reference.quds` | **1167 numerical reference checks**, zero failures |
| `quds test test/math_graph_reference.quds` | **151,457 assertions on 1695 graphs**, zero failures; separate 20,000-vertex chain passed |
| Primary math suites | All **51** test declarations passed across eight `.quds` files |
| Quds matcher/negative fixtures | Matcher suite passed with its intentional skipped assertions; four negative files each exited 65 with the expected diagnostic |
| Public API call inventory | **300/300** public functions have Quds call sites; generation rejects any missing Quds call |
| Supplemental Dart numerical fixture | Original 2591 checks unchanged and passed |
| Supplemental graph VM/JavaScript fixtures | Original 119,740 assertions on each platform passed |
| Generation/source synchronization | Byte-identical numerical fixtures/inventory and embedded SDK on repeat |

`test/math_quds_test.dart` launches seven Quds files and checks all parsed
completion titles and the numerical/graph execution markers. The eighth primary
file, `math_graph.quds`, is launched by the existing graph integration test.
Assertions and independent graph oracles live in Quds, not the Dart launcher.

The 1167 numerical values are the same independently generated values/tolerances
as their corresponding structured cases in the supplemental Dart fixture;
they are not additional independent reference inputs. Raw Dart-only expressions
(BigInt oracles and additional matrix/sampling checks) remain clearly supplemental.
Every API having a Quds call is traceability, not proof of every branch or domain.

### Defects corrected

- `quds test` no longer lets a source `main()` bypass test discovery. It uses a
  separate driver and a collision-free bridge inside the compiled suite.
- Files with no actual tests fail with `No tests found`; they cannot report an
  empty successful run. Legacy zero-argument test functions remain supported and
  asynchronous legacy tests are awaited in sequence.
- Any counted test failure produces exit 1. The old raw count made 256 failures
  appear successful on POSIX. Reproduction against the prior committed CLI gave
  exit 0 for an empty file, a test file with `main`, and 256 failing tests;
  all three regressions are now covered and fail correctly.
- The Quds graph oracle exposed missing parsing for approved `&`, `|`, `^`,
  `<<`, `>>`, `>>>` and `~`. Their precedence follows the existing specification;
  integer and eager boolean operations, const evaluation, invalid operands and
  exactly-once operand order have regressions. No new syntax was invented.
- `isFinite`, `isInfinite`, `isNaN`, `isNegative` and collection `single` have
  static getter shapes, mirrored in completion metadata.
- Imported Quds functions retain their own filtered/prefixed and unprefixed Dart
  imports even when the caller uses only `use quds:math as m show ...`.
- A filtered/prefixed `dart:core` import no longer removes core types needed by
  generated code. Source-level import filters remain checked by Quds semantics.
- Cross-library underscore fields/methods now receive `E206` in the original
  `.quds` coordinates, matching explicit `private`; same-library access remains
  valid. `protected` and the approved accessibility syntax were not redesigned.

One earlier full run found an existing negative fixture expecting `E200` for
`List<int> + Map<String, int>`. That is a type mismatch, which the diagnostic
specification assigns `E300`; the expected code was corrected precisely, with no
loosening to accept arbitrary errors. The final full rerun passed all 247 tests.


## Math expansion: unweighted graphs

Added eight graph functions to `quds:math`, bringing its top-level public
function inventory to **300**. The broader missing-domain roadmap is in
[MATH_EXPANSION_ROADMAP_AR.md](MATH_EXPANSION_ROADMAP_AR.md); only its first graph
package is implemented here. Contracts, complexity, examples and limits are in
[MATH_GRAPH.md](MATH_GRAPH.md). No language syntax or existing math API changed.

Validation used Dart 3.13.7 on Linux x64 and Node for JavaScript execution.

| Command/check | Observed outcome |
| --- | --- |
| Baseline `dart test` before additions | 228 passed; 1 existing debug test skipped |
| `dart format --output=none --set-exit-if-changed .` | 36 Dart files; zero changes |
| `dart analyze` | No issues |
| Final `dart test --reporter expanded` | **232 passed; zero failures; zero skips** |
| Isolated `dart test test/math_graph_test.dart --reporter expanded` | All 3 tests passed |
| Independent graph fixture, Dart VM | **119,740 checks; 1695 graphs; zero failures** |
| Same fixture, compiled JavaScript + Node | **119,740 checks; 1695 graphs; zero failures** |
| Deep-chain graph checks | 20,000 vertices; iterative SCC, BFS, path, topology, weak components and coloring passed on VM/JS |
| `dart run bin/quds.dart test test/math_graph.quds` | All 13 test declarations and enclosing group reported `ok` |
| Existing math, math-accuracy, prefix and matcher Quds suites | All commands exited 0; matcher suite retains its intentional skipped assertions |
| Four existing negative CLI fixtures | Each exited 65 and matched its intended diagnostic |
| `dart run bin/quds.dart run examples/math_graph.quds` | Five output lines match the documented example |
| Embedded source sync and numerical fixture/inventory regeneration | Byte-identical on repeat; original 2591 numerical reference cases unchanged |
| `git diff --check` | Passed |

The graph fixture exhausts all directed graphs with loops through 3 vertices and
all simple undirected graphs through 5 vertices, plus 64 fixed-seed multigraphs.
Its oracles use Floyd–Warshall and exhaustive coloring, independently of the
SDK's BFS, Kosaraju and Kahn implementations. Invalid-edge/endpoint checks require
the exact error strings, and the harness checks execution counts. These finite
checks do not establish correctness for every possible input or a measured
universal performance guarantee.

An intermediate full run failed only the source/embedded equality check because
SDK example comments were edited after that test process had loaded the older
embedded constant. With both files synchronized and frozen, the complete rerun
passed all 232 tests. No assertion was removed or relaxed. The baseline's debug
skip did not recur in the final run.


## Math audit and compiler prerequisites

Validated with Dart 3.13.7 on Linux x64. See [MATH_ACCURACY.md](MATH_ACCURACY.md)
for numerical contracts, reference versions, tolerances and limitations, and
[MATH_COVERAGE.md](MATH_COVERAGE.md) for the 292-function inventory.

| Command/check | Observed outcome |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | 35 files; zero changes |
| `dart analyze` | No issues |
| `dart test --reporter expanded` | 228 passed; 1 skipped; no failures |
| Frozen native math reference runner | 2591 checks; zero failures |
| JavaScript math smoke | `dart compile js` passed; Node printed `WEB MATH OK` |
| `quds test test/math.quds` | All 14 test declarations passed |
| `quds test test/math_accuracy.quds` | All 10 former failing regressions passed |
| Prefix and matcher suites | Passed; matcher fixture intentionally skips two assertions |
| Four negative CLI fixtures in CI | Each exited 65 with its expected diagnostic |
| Embedded SDK/source equality | Passed |
| Reference regeneration | Byte-identical fixture and coverage inventory |
| `git diff --check` | Passed |

The skipped full-suite test is the existing debug-adapter integration test:
`test/compiler_test.dart` skips after retrying a breakpoint stop that has no stack
frames. It is unrelated to the numerical changes; no numerical reference or math
regression was skipped. The precision and JavaScript test file also passed in
isolation (2 tests), and embedded math-source equality passed in isolation (1 test).
No debug-adapter fix or Flutter UI validation is claimed here.

The original review's ten failing math cases now pass. Frozen cases use SciPy,
NumPy, selected 80-digit mpmath anchors, analytic identities, exact integer
comparisons and fixed-seed sampling. The detailed document distinguishes sampled
accuracy from a global error guarantee and explains the corrected constant-sample
Kendall expectation and floating least-squares assertions.

---

The sections below are historical records from 2026-11-11. Their older test counts,
implementation gaps and environment-publication statements are retained as history,
not as claims about the current compiler or environment.

Validated on Linux x64 with Dart **3.13.7 (stable)**. The package's locked
development dependencies require Dart >=3.13.0. No Flutter installation, service,
or additional credential is required for this workflow.

## Original baseline

An archive of commit `e1760fc5fa0ce202241343a4cb2a5b48cc21e449` was checked in
`/tmp/quds-baseline`, separately from the working implementation:

| Command | Result |
| --- | --- |
| `dart pub get` | Passed; dependencies installed |
| `dart analyze` | Passed; no issues |
| `dart test` | Passed; **4 tests**, none skipped |
| `dart format --output=none --set-exit-if-changed .` | Exit 1; original lexer needed formatting |

Initial attempts were blocked by a missing SDK and then read-only per-user tool
cache paths. The SDK was obtained from the official digest-pinned Dart Docker
image, and approved tool initialization created Dart's per-user settings/cache.
These were environment prerequisites, not lexer test failures.

## Final implementation

Commands run from `/workspace/quds_lang`, with SDK/Pub activation documented in
`ENVIRONMENT.md`:

| Command | Result |
| --- | --- |
| `bash tool/setup_environment.sh` | Passed; package restore and CLI activation; repeated successfully |
| `dart pub get --enforce-lockfile` | Passed; no dependency changes |
| `dart format .` | Passed; compiler and tests formatted |
| `dart format --output=none --set-exit-if-changed .` | Passed; zero changed files |
| `dart analyze` | Passed; no issues |
| `dart test --reporter expanded` | Passed; **69 tests**, zero failures/skips |
| `quds build examples/sum.quds` | Passed; generated adjacent Dart |
| `dart analyze examples/sum.dart` | Passed; no issues |
| `dart examples/sum.dart` | Exit 0; exact expected output below |
| `git diff --check` | Passed |

```text
Total: 60
12
```

The suite exercises:

- Original lexer tests plus exact token/coordinate expectations, continuation
  layout, EOF dedents, Unicode/UTF-8 offsets, CRLF/CR, comments, longest-match
  operators and lexical errors.
- AST shape, precedence/associativity, functions, if/else-if, named blocks,
  malformed programs, original interpolation coordinates and oversized literals.
- Symbols, immutable/mutable assignment, explicit shadowing, lexical scope,
  parameter mutability, type/return checks, constant-initializer structure,
  named-argument validation and rejected overloads.
- Exact deterministic generated-Dart golden output.
- Real Dart analysis and execution for the acceptance program, strings and
  interpolation, scopes/Unicode/const, named argument side-effect order, and
  runtime boolean short circuiting/arithmetic.
- CLI subprocesses: build/rebuild, actual Dart execution, usage, missing input,
  original-source diagnostics, and preservation of user-owned/existing output.

Validation caught and corrected four test-harness references to the wrong class
for `resolvedExecutable`, an off-by-one token golden, and constant boolean test
inputs that caused Dart dead-code warnings. The short-circuit regression now
uses runtime boolean values and still asserts that the side-effecting branch
never executes. No failing assertions were disabled.

The initial lexer formatting issue is resolved in the new implementation.
GitHub Actions configuration was added for the same format/analyze/test workflow;
remote CI execution has not been observed.

## Const evaluation — 2026-11-11

Re-validated from the repository root on Linux x64 with Dart **3.13.7 (stable)**
after evaluating the supported `const` subset in Quds. The SDK used for this
run is the official `3.13.7` archive; the digest-pinned Docker extraction in
`ENVIRONMENT.md` was not repeated because Docker was not installed. No
application dependency or lockfile changed.

| Command | Result |
| --- | --- |
| `dart pub get --enforce-lockfile` | Passed; no dependency changes |
| `dart format --output=none --set-exit-if-changed .` | Passed; zero changed files |
| `dart analyze` | Passed; no issues |
| `dart test --reporter expanded` | Passed; **97 tests**, zero failures/skips |
| `quds build examples/sum.quds` | Passed; generated adjacent Dart |
| `dart analyze examples/sum.dart` | Passed; no issues |
| `dart examples/sum.dart` | Exit 0; exact output below |
| `git diff --check` | Passed |

```text
Total: 60
12
```

The added tests cover const arithmetic and wrapping, numeric and list equality,
references to earlier constants, short-circuit `and`/`or` (including a skipped
integer remainder and a rejected skipped call), original-source Q200/Q100
coordinates, unary `+` lowered once, runtime remainder left to Dart, and the
const CLI diagnostic. Generated const Dart is checked against
`test/goldens/const_eval.dart.txt` and executed. No assertion was disabled.

## Top-level const and bool conditions — 2026-11-11

Re-validated from the repository root on Linux x64 with Dart **3.13.7 (stable)**
after accepting top-level `const` bindings and lowering bool conditions so
generated Dart does not report `dead_code`. No dependency or lockfile changed.
`examples/sum.dart` was regenerated and stayed identical to its golden.

| Command | Result |
| --- | --- |
| `dart pub get --enforce-lockfile` | Passed; no dependency changes |
| `dart format --output=none --set-exit-if-changed .` | Passed; zero changed files |
| `dart analyze` | Passed; no issues |
| `dart test --reporter expanded` | Passed; **107 tests**, zero failures/skips |
| `dart run bin/quds.dart build examples/sum.quds` | Passed; generated adjacent Dart |
| `dart analyze examples/sum.dart` | Passed; no issues |
| `dart examples/sum.dart` | Exit 0; exact output below |
| `git diff --check` | Passed |

```text
Total: 60
12
```

The added tests cover top-level arithmetic, earlier-const references, a skipped
remainder, list equality, a const declared after `main`, original Q200
coordinates for remainder, forward reference, calls, module-scope `var`, and a
repeated name. Bool literals, const bools, and reassigned bool locals used in
`if`/`and`/`or` are executed under `dart analyze`. A taken runtime `true and
(1 % 0 == 0)` still throws Dart's integer remainder error. No assertion was
disabled.

## Limits and environment persistence

This validates MVP-0 plus const evaluation of that subset, including top-level
consts, not all 115 decisions. See `MVP_0.md` and `OPEN_QUESTIONS.md` for the
supported grammar, conservative typing, unresolved syntax, source-map gap, and
deferred language features. Const forms outside the MVP-0 expressions, inferred
const, const constructors, web numeric behavior, and the minimum signed 64-bit
literal spelling remain open.
Native execution was tested; web/Flutter, other Dart SDK versions, and published
snapshot restoration were not tested.

The current machine supports this development workflow. Reusable draft saves
for `install_script` and `start_skill` returned `INVALID_ARGUMENT`; persistence
could not be confirmed. Tested local setup/start instructions are retained in
`ENVIRONMENT.md` and `tool/setup_environment.sh`. Publication remains unperformed.
No extra network domain is needed for the verified Docker-based SDK route.
