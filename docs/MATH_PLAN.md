# Numbered plan items 3–15

Items 3–15 of the [execution table](MATH_EXPANSION_ROADMAP_AR.md) are implemented.
The family ledger is [MATH_CONTRACTS.md](MATH_CONTRACTS.md).
The suite is `test/math_plan.quds` (`QUDS PLAN CHECKS=78 FAILURES=0`).

`Interval`, `Dual`, and `linearProgram` are unchanged.

## 3. Forward Hessian

`HyperDual` carries `value`, `dx`, `dy`, and `dxy`.
`autoHessian(f, point)` evaluates `f` once per input pair, at most 8 inputs.
`HyperDual.sqrt` rejects a nonpositive value, including 0. There is no finite-difference fallback.

At `(2, 3)`, `x*x*y` has Hessian `[[6, 4], [4, 0]]`.

## 5. Log probabilities

`normalLogPdf` is the binary64 log formula and stays finite where `normalPdf` underflows to 0.
`poissonLogPmf` and `binomialLogPmf` use the same 0 and 1 cases as `poissonPmf` and `binomialPmf`.
A probability of 0 is a log of negative infinity, written as `0.0 - 1.0 / 0.0`. They do not call `ln(0)`.

## 6. Phase-I linear programming

`linearProgramPhase(costs, rows, limits)` maximizes `costs · x` for `rows * x <= limits`, `x >= 0`.
A negative limit is allowed. Phase I minimizes artificial variables. If that sum stays positive the call throws `linearProgramPhase is infeasible` and returns no point. An unbounded ray throws `linearProgramPhase is unbounded`. At most 12 variables and 12 constraints.

`linearProgram` still requires nonnegative limits.

## 7. Sparse residual

`sparseMatrix` builds one compressed-row pattern and sets `builds` to 1.
`sparseMultiply` and `sparseResidual` read that pattern and allocate only the output vector. `builds` stays 1.
`sparseResidual` is `||A x - b||`.

## 8. Decimal

`Decimal` stores a signed `BigInt` and a scale from 0 through 100.
`decimal(text, scale, rounding)` parses text. Rounding is one of `halfEven`, `halfAway`, `floor`, `ceiling`, `towardZero`.
Any other name throws `decimal rounding must be named`. No `double` appears in the conversion or the arithmetic.
Addition aligns scales exactly. Division requires a named rounding and a result scale.

## 9. Outward intervals

`OutwardInterval` is a new type. `Interval` has no arithmetic.
Endpoints are finite and ordered. A subnormal endpoint is rejected. Zero steps out to the smallest normal (`2.2250738585072014e-308`), which still contains the exact value.
`outwardAdd`, `outwardSubtract`, `outwardMultiply`, and `outwardDivide` round the endpoint image outward by one binary64 step.
A divisor interval that contains 0 throws. Overflow throws `outward interval overflow`.
The additional `RealInterval` type in the same section supports subnormals and
unbounded endpoints, with overflow enclosures; see [MATH_INTERVAL.md](MATH_INTERVAL.md).

## 10. Reverse mode

`Reverse` records operations on a `ReverseTape`. `reverseGradient` calls the callback once and walks the tape once from the output. It is not `Dual`: there is no forward tangent.
At most 32 inputs. At `(2, 3)`, `x*x*y` has gradient `[12, 4]`, the same value as `autoGradient`.

## 11. Weights, streams, bootstrap

`weightedMean` is `sum(w*x)/sum(w)` for nonnegative finite weights. A nonpositive total throws.
`weightedVariance` is `sum(w*(x-mean)^2)/sum(w)`, not the Bessel correction.
`streamAdd` is Welford's recurrence. `streamSampleVariance` divides by `count-1` and throws before two samples.
`bootstrapMean` uses minstd: `state = seed * 48271 mod 2147483647`, then `index = state mod n`.
The seed is the first state, from 1 through 2147483646. Ranks are `floor((replicates-1)*(1-level)/2)` and `floor((replicates-1)*(1+level)/2)`.
This percentile interval is reproducible. It does not certify that the false-alarm rate equals `1-level`.

## 12. Stiff step

`implicitEuler` already checks the backward-Euler residual after the Newton iteration.
A non-finite or out-of-tolerance residual throws `implicitEuler did not converge` and does not return the last Newton state.

## 13. STFT and FIR

`stft` windows each full frame, applies `fft`, and divides every bin by the sum of the window.
A constant signal of amplitude 1 then has DC real part 1. Partial frames are not padded. The window length is a positive power of two. A zero window sum throws.
`firFilter` is causal: `y[n] = sum_k coef[k] * x[n-k]` with samples before the start equal to 0. `firGain` is the sum of the taps, the DC gain. Nothing rescales the taps.

## 14. Symbolic expressions

`Expr` is a data tree (`number`, `symbol`, `add`, `subtract`, `multiply`, `divide`, `power`, `sqrt`, `sin`). It is not the language parser.
`simplifyExpr` folds constants and the identities `+0`, `-0`, and `*1`. It folds `*0` only when the other operand is proved total, preserving the domain of `1/x`, roots and negative powers. It does not rewrite `sqrt(x*x)` or `x/x`.
`deriveExpr` differentiates polynomials and products. `sin` and other unsupported forms throw `symbolic derivative is not supported`.
`integratePolynomial` integrates one polynomial of degree at most 16 and throws `symbolic integral is not supported` otherwise. The constant of integration is omitted. The stronger domain contracts and independent reference tests are in [MATH_SYMBOLIC.md](MATH_SYMBOLIC.md).

## 15. Tensors, prime fields, triangles

`tensor` stores a dense row-major array, rank 1 through 4, at most 4096 values.
`tensorMatmul` is the rank-2 product. `[[1, 2], [3, 4]] * [[5, 6], [7, 8]] = [[19, 22], [43, 50]]`.

`fieldElement` reduces into `0 .. modulus-1`. The modulus is a prime from 2 through 1000000, proved by trial division. A composite throws `finite field needs a prime modulus`.
`fieldInverse` is the extended Euclidean algorithm. Zero throws `finite field element has no inverse`.

`eulerCharacteristic(vertexCount, faces)` is `V - E + F` for a triangle complex. Isolated vertices count. Each undirected edge counts once. A repeated face index or an out-of-range vertex throws. One triangle is 1. Two triangles sharing an edge, on 4 vertices, are 1.

The subsequent finite-domain foundation adds F2 homology and rejects repeated
Euler triangles; see [MATH_FOUNDATIONS.md](MATH_FOUNDATIONS.md).
