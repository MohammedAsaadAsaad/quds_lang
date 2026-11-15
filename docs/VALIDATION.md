# Compiler validation — latest 2026-11-15

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
