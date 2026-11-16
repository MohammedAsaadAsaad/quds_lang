# Math numerical audit — 2026-11-15

This section records the original numerical audit, before graph expansion.
The current SDK adds eleven graph functions, integer flow and bipartite matching, and the remaining numbered plan (380 top-level functions total, including exact arithmetic, forward AD, reverse AD, and exact planar geometry),
with exact graph contracts and separate independent tests in [MATH_GRAPH.md](MATH_GRAPH.md).
See [the expansion roadmap](MATH_EXPANSION_ROADMAP_AR.md) for further domains.

The audit covers the public surface of `lib/sdk/math.quds`: 292 top-level
functions, 20 public value classes (plus the private adaptive-step record), and
three extensions. Every public top-level function has an executable call in the
Quds suites or the frozen reference fixture; see [the inventory](MATH_COVERAGE.md).
This does **not** mean every branch, parameter combination, platform, or possible
user-supplied function has been proved correct.

## Primary Quds tests

The primary SDK checks now live in `.quds` files and run through `quds test`.
`test/math_reference.quds` contains **1167** independently generated numerical
references, with the same values/tolerances as the corresponding structured
cases in the original Dart fixture. They are shared reference data, not 1167
additional independent mathematical inputs. The explicit Quds helper preserves
strict relative checks for tiny tails instead of substituting one loose tolerance.

`test/math_graph_reference.quds` implements independent Floyd–Warshall and brute
force coloring oracles in Quds: **151,457 assertions on 1695 graphs**, plus a
20,000-vertex chain. `math_api.quds` closes the earlier Quds call-site gaps,
including distribution quantiles, typed callbacks and fixed-seed samplers.
All **380** public top-level functions now have a Quds call site.
[Exact arithmetic](MATH_EXACT.md) adds 1199 independent Quds reference cases.
[Forward AD](MATH_AUTODIFF.md) adds 598 value/derivative reference cases.
[Exact planar geometry](MATH_GEOMETRY.md) adds 738 reference cases.
[Binary64 and interval arithmetic](MATH_INTERVAL.md) adds 1138 reference cases.
[Integer flow and matching](MATH_FLOW.md) adds 58012 flow checks on 4164 networks and 5040 matching checks on 682 graphs.
[The remaining numbered plan](MATH_PLAN.md) adds Hessian, log-probability, phase-I linear programming, a once-built sparse pattern, named-rounding decimal, outward intervals, reverse-mode gradients, weighted and bootstrap statistics, a stiff-step rejection, window-sum STFT, a symbolic expression tree, tensors, prime fields, and triangle Euler characteristic. The family ledger is [MATH_CONTRACTS.md](MATH_CONTRACTS.md).
Weighted graph contracts and their Quds oracles are in [MATH_WEIGHTED_GRAPH.md](MATH_WEIGHTED_GRAPH.md). This is still
call-site traceability, not complete branch/domain coverage.

`math_quds_test.dart` only launches the Quds suites and verifies their completion
markers. Mathematical assertions live in Quds. CI runs the direct Quds commands
before the compiler/platform test suite. Running the launcher as
`dart run bin/quds.dart test ...` does not make those assertions Dart tests:
Quds source is parsed, statically checked and emitted before the Dart backend
executes it. Dart remains the backend required by the approved language design.

## Reproduce

```sh
dart pub get --enforce-lockfile
dart run bin/quds.dart test test/math.quds
dart run bin/quds.dart test test/math_accuracy.quds
dart run bin/quds.dart test test/math_reference.quds
dart run bin/quds.dart test test/math_api.quds
dart run bin/quds.dart test test/math_operators.quds
dart run bin/quds.dart test test/math_graph.quds
dart run bin/quds.dart test test/math_graph_reference.quds
dart test test/math_accuracy_test.dart test/math_graph_test.dart --reporter expanded
```

As supplemental interoperability checks, `math_accuracy_test.dart` compiles the actual Quds SDK with the Quds compiler,
writes its bundle, and executes **2591** frozen checks against that generated
public API. The same test file compiles a math consumer using `dart compile js`
and runs it with Node when available. No Python or SciPy installation is needed
to run the Dart tests. Absence of Node explicitly skips JavaScript execution;
compilation is still checked.

The frozen fixtures are `test/math_reference.quds` and
`test/fixtures/math_reference.dart.txt`. Python is needed only to deliberately
regenerate its references and coverage inventory:

```sh
python tool/generate_math_reference.py
```

Reference generation used Python 3 with NumPy 2.3.5, SciPy 1.17.0 and mpmath
1.3.0. Random matrices and integer inputs use fixed seeds. Selected tiny gamma
and Lambert-W anchors use 80-digit mpmath calculations. Sample checks use fixed
seeds, 20,000 draws, and explicit sampling-error tolerances; they are not proofs
of a random generator's distribution.

After editing the Quds library, synchronize the embedded distributable copy:

```sh
python tool/sync_math_sdk.py
dart format lib/src/sdk.dart
```

The existing language test verifies that `mathSdkSource` equals the `.quds` file.

## What the checks establish

- References for elementary, hyperbolic, special and orthogonal-polynomial
  functions; PMFs, CDFs, quantiles, moments and rank/inference statistics.
- Exact integer comparisons for modular exponentiation/inversion, small primes,
  combinations and Bezout identities. BigInt is used by the **Dart test oracle**,
  not by the Quds SDK or its compiler.
- Random rectangular/square matrices, including rank-deficient inputs and scales
  from 1e-120 to 1e120. Singular/eigenvalues and pseudoinverses are compared after
  normalization so small inputs cannot pass just because of an absolute tolerance.
- Orthogonality/reconstruction, linear-system residuals, polynomial/interpolation
  identities, FFTs at power-of-two and other lengths, DCT/Haar round trips,
  quadrature, ODEs, event location, and bounded linear optimization, including a
  classical simplex cycling example.
- Complex and vector operations, all three extensions, and deliberately invalid
  domains, integer overflow, and an implicit equation without a converged solution.
- Separate strict-relative checks for tiny hyperbolic functions, small probability
  tails, Bessel K/J, Airy Ai, and subnormal/large arguments. Ordinary reference
  checks generally use relative 1e-7 and absolute 1e-11; each case records its
  tolerance. Statistical sampling has separate, wider error bars. These are
  acceptance thresholds for the sampled grid, not global error bounds.

## Corrected defects

### Integers and fractions

- Modular multiplication no longer wraps before reduction. Miller–Rabin handles
  a base equal to the candidate and uses safe modular squaring. Pollard steps use
  the same safe operations.
- Modular inverses keep coefficients modulo the modulus. General CRT accepts a
  redundant modulus of one after gcd reduction and rejects an unrepresentable
  working modulus instead of wrapping.
- Checked arithmetic protects factorial, powers, permutations, combinations,
  Fibonacci, LCM and fraction operations. Combinations reduce factors before
  multiplication, and fractions cross-cancel before forming products.
- GCD/extended-GCD and fraction normalization handle signed-minimum corner cases
  or explicitly reject a positive result that cannot be represented.

### Scalar and special functions

- Stable tiny/large-argument `sinh`, `cosh`, `tanh`, `asinh`, `acosh`, `atanh`,
  `log1p` and `expm1`, including the positive overflow and negative underflow tails.
- Angle wrapping uses a remainder rather than converting a huge quotient to int.
  Interpolation avoids overflowing the difference of opposite large endpoints.
- `logGamma` explicitly means log(abs(Gamma(x))) on negative non-poles; gamma
  preserves the sign without overflowing its reflected denominator. Incomplete
  gamma/beta and hypergeometric calculations require convergence.
- Error functions use incomplete-gamma evaluation, preserving complementary tails;
  inverse erf/normal quantiles consequently no longer refine against the older
  low-accuracy error-function approximation.
- Bessel evaluation switches between convergent series and Schlaefli integrals
  rather than summing catastrophically cancelling large-argument series. Airy
  functions use stable Bessel representations away from zero. Elliptic E uses AGM.
- Lambert W uses a branch-point expansion and a logarithmic equation for large
  positive arguments rather than overflowing `w * exp(w)`.

### Statistics and random draws

- PMFs use log-gamma/log-combinations, not overflowing int factorials. Binomial,
  Poisson and negative-binomial CDFs use incomplete beta/gamma functions.
- Beta densities have the correct finite endpoint limits. Small exponential and
  Weibull CDFs/quantiles use `expm1`/`log1p`; density denominators avoid unnecessary
  overflow. Mean, spread, line fitting and correlation use stable scaling/centering.
- Poisson sampling switches to transformed rejection for larger means. Gamma and
  beta samplers no longer silently return a failed iterate or a 0/0 ratio.
- Mann–Whitney uses tie-corrected variance (asymptotic, without continuity correction).
  The Kolmogorov survival approximation uses a Jacobi-transformed series near zero.
  Kendall sign comparisons do not multiply subnormal differences; undefined
  constant samples fail explicitly. Constant separated ANOVA groups yield an
  infinite statistic, not an arbitrary 1e16 sentinel.

### Linear algebra and numerical algorithms

- SVD uses scaled one-sided Jacobi rotations instead of A-transpose-A, avoiding
  squaring the condition number. Thin null spaces are completed with an orthogonal
  basis. Least squares uses the pseudoinverse. Numerical rank is relative.
- QR uses scaling and two modified Gram–Schmidt passes. Symmetric eigenproblems,
  matrix square roots/logarithms and iterative solvers use scale-aware operations
  and stopping/residual checks. Tiny right-hand sides no longer count as zero.
- Simplex uses Bland's pivot rule and refuses a non-converged result. Quadratic
  roots use a stable q formula and scale-aware coefficients; tiny leading
  polynomial coefficients are not automatically discarded.
- Interpolation validates increasing coordinates; heat rejects negative diffusion;
  event/root bracketing compares signs without underflowing their product.
- Adaptive quadrature sums accepted local Richardson error estimates and fails
  when its depth budget cannot meet the requested tolerance. Implicit ODE steps
  check the final equation residual instead of trusting the eighth Newton iterate.

## Explicit numerical contracts and limits

- The floating-point APIs use binary64 arithmetic; the separate `BigInt` and
  `BigFraction` APIs provide [exact arithmetic](MATH_EXACT.md). The numerical
  subset is not a replacement for a
  mature verified scientific computing package. Rounding and conditioning matter.
  Finite-difference derivatives, quadrature, optimization and ODE results depend
  on smoothness, resolution/step choices and the user's function. An error estimate
  is a heuristic, not a rigorous universal bound.
- Exact integer work must stay in the platform's exact integer range: signed
  64-bit on the VM and +/- (2^53-1) on JavaScript. Guarded operations throw when
  their result/intermediate working modulus does not fit; no silent wrap is used
  to manufacture a mathematical result. Fraction arithmetic can conservatively
  reject an unrepresentable intermediate.
- On the VM, factorial is representable through 20 and Fibonacci through 92. On
  JavaScript, the smaller exact-integer range can reject earlier. A JS smoke test
  checks both correct modular reduction and overflow rejection.
- `rank` counts singular values above 1e-12 of the largest; pseudoinverse keeps
  its documented numerical singular-value cutoff. Near-singular inputs cannot
  promise full relative accuracy. A rejected solver/domain is distinct from a
  verified numerical answer.
- Airy functions retain their documented |x| <= 12 range. Bessel methods impose
  a numerical work limit (|order| and argument at most 10,000), and can reject
  tails/series that do not converge. Those limits are work guards, not a claim of
  a uniform proven error bound up to their endpoints.
- Poisson sampling accepts finite means through 1e8; larger means are explicitly
  rejected. Extreme beta shapes whose two gamma draws underflow are rejected.
  Singular beta/chi-square densities at endpoints retain their explicit errors.
  Quantile APIs that require 0 < p < 1 retain that contract.
- Matrix entries for scaled decompositions/solvers must be finite. Unrepresentable
  floating results can still overflow. `Summary.stddev()` is the square root of
  its stored variance; it cannot recover information if that variance overflowed.
  No blanket behavior for all NaN/infinity parameter combinations is asserted.
- `linearProgram` still solves the documented feasible-start form with nonnegative
  limits; a general phase-I feasibility solver is not supplied. Rank-based and
  Kolmogorov/Mann–Whitney significance calculations remain asymptotic where stated.

## Compiler prerequisites and test adjustments

Two small compiler fixes were necessary for the larger, guarded library:

1. Throw/rethrow paths satisfy a non-void function's no-fallthrough contract.
   Positive and negative semantic regressions cover that distinction.
2. The lexer indexes UTF-8 offsets once and reads a code point without copying
   the remaining source. UTF-16 columns, astral characters and CRLF byte offsets
   have explicit regression coverage. A diagnostic local benchmark for 8000
   lines fell from about 1468 ms to 16 ms; this is not a statistical benchmark.

Two pre-existing bit-exact assertions for floating least-squares coefficients
were changed to an explicit 1e-12 tolerance after switching from normal equations
(the result differed by a few ulps). No failing mathematical answer was made
acceptable by disabling an assertion or weakening the new reference thresholds.
The old constant-sample Kendall assertion incorrectly expected perfect association;
it now asserts the explicit undefined-correlation error instead.

## Next work

See [the detailed strengthening plan](MATH_STRENGTHENING_PLAN_AR.md) for proposed
phases, dependencies, numerical contracts, validation gates and release criteria.
