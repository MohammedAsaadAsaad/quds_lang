# MVP-0 validation — 2026-11-11

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

## Limits and environment persistence

This validates MVP-0 plus const evaluation of that subset, not all 115
decisions. See `MVP_0.md` and `OPEN_QUESTIONS.md` for the supported grammar,
conservative typing, unresolved syntax, source-map gap, and deferred language
features. Const forms outside the MVP-0 expressions, inferred const, web
numeric behavior, and the minimum signed 64-bit literal spelling remain open.
Native execution was tested; web/Flutter, other Dart SDK versions, and published
snapshot restoration were not tested.

The current machine supports this development workflow. Reusable draft saves
for `install_script` and `start_skill` returned `INVALID_ARGUMENT`; persistence
could not be confirmed. Tested local setup/start instructions are retained in
`ENVIRONMENT.md` and `tool/setup_environment.sh`. Publication remains unperformed.
No extra network domain is needed for the verified Docker-based SDK route.
