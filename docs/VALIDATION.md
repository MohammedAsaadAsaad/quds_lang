# Compiler validation — latest 2026-11-15

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
