# Family contracts for `quds:math`

One row per section. Precision is the representation the section returns.
Domain is the input the section accepts before it starts work.
Failure is how a rejected input or a failed search is reported.
A function-specific throw string inside that rule is the string in the function comment.

| Section | Domain | Failure | Precision |
| --- | --- | --- | --- |
| `scalar` | Real `double` or platform `int` as named on the function | The function's throw string, or a non-finite `double` when the function does not throw | `binary64` for real functions; exact platform `int` for the integer helpers, which throw `integer result is outside int range` |
| `number` | Platform integers in the range named on the function | Throw string from that function | Exact platform `int` |
| `complex` | Finite `Complex` components | Throw when a component is non-finite or a shape does not match | `binary64` real and imaginary parts |
| `vector` | Finite coordinates | Throw `geometry needs finite coordinates` only in geometry; vector helpers throw their own non-finite string | `binary64` |
| `interval` | Two `double` ends, ordered by `interval` | No arithmetic and no throw for a reversed constructor `Interval`; `interval` swaps the ends | `binary64` ends, no rounding mode |
| `interval::outward` | `OutwardInterval`: finite ordered ends with documented subnormal limits. `RealInterval`: ordered non-NaN endpoints, permits subnormals and unbounded real intervals | The existing outward errors remain; `RealInterval` rejects invalid endpoints and any divisor containing zero; see [MATH_INTERVAL.md](MATH_INTERVAL.md) | Outward-rounded binary64 bounds; RealInterval supports subnormal spacing and overflow enclosures |
| `stats` | Finite samples; weights nonnegative for the weighted pair | Empty mean throws `mean of an empty list`; weighted and stream and bootstrap strings are in [MATH_PLAN.md](MATH_PLAN.md) | `binary64`; bootstrap is a seeded percentile interval, not a certified false-alarm rate |
| `distribution` | The parameter domain in each function comment (`sigma > 0`, `0 <= p <= 1`, `lambda >= 0`) | Throw the function string; a probability outside the support returns `0` | `binary64`; `normalPdf` may underflow to `0`; `normalLogPdf` keeps the log formula finite |
| `calculus` | Finite state and a positive step count | `implicitEuler did not converge` discards the last Newton state; other solvers throw their own `did not converge` or `did not finish` string | `binary64` |
| `interp` | Finite samples and a length the function names | Throw the function string before an interpolated value | `binary64` |
| `linalg` | Finite rectangular entries; sparse indices inside the declared size | Throw the function string; `sparse solver did not converge` when the measured residual is too large | `binary64`; `sparseMatrix.builds` stays `1` across products |
| `polynomial` | Finite coefficients | Throw the function string | `binary64` coefficients |
| `signal` | Finite samples; FFT length a positive power of two unless the function says `Any` | Throw the function string; `stft window sum must be nonzero` | `binary64`; `fft` is unnormalized and `ifft` is its inverse; `stft` divides by the window sum; `firFilter` does not rescale taps |
| `optimize` | Finite costs and rows; `linearProgram` also needs nonnegative limits | `linearProgram is unbounded` or `linearProgram did not converge`; `linearProgramPhase is infeasible` returns no point | `binary64` |
| `special` | The argument limits in [MATH_ACCURACY.md](MATH_ACCURACY.md) | Throw when the limit is exceeded, including `Bessel argument or order exceeds the numerical work limit` | `binary64` approximation inside those limits |
| `support` | Not imported | Private helpers throw into the caller | Not a public precision |
| `graph` | Nonnegative vertex count and in-range endpoints | Throw the graph string before traversal | Exact platform `int` distances and component ids |
| `graph::weighted` | Finite weights; Dijkstra weights nonnegative | Throw the weighted-graph string; unreachable distance is `+infinity` | `binary64` weights |
| `graph::flow` | Nonnegative integer capacities; source different from sink | Throw the flow string; the returned cut capacity equals the flow | Exact platform `int` |
| `graph::matching` | Nonnegative side counts and in-range endpoints | Throw the matching string | Exact platform `int` |
| `exact` | `BigInt` text or the named nonnegative bounds | Throw the function string; `bigFraction` rejects a zero denominator | Exact `BigInt` and reduced `BigFraction` |
| `exact::decimal` | Scale 0 through 100 and a named rounding | `decimal rounding must be named`, `decimal text is not a number`, `division by zero` | Exact base-10 `BigInt` digits; rounding is the named mode |
| `autodiff` | Finite point; `Dual` operations on their documented open domains | `Dual` throw strings; `HyperDual.sqrt needs a positive value` | `binary64` value and tangents, from the chain rule, not from differences |
| `autodiff::reverse` | Finite point, at most 32 inputs, one tape | `reverseGradient needs a finite point`, `reverse result is not finite`, `reverse operation needs one tape` | `binary64` adjoints from one backward walk |
| `geometry` | Finite `Vec2` coordinates | `geometry needs finite coordinates` | Exact `BigFraction` of the binary64 inputs for the predicates; the hull uses those signs |
| `symbolic` | An `Expr` tree, not source text | `symbolic derivative is not supported`, `symbolic integral is not supported`, `division by zero` | Exact `BigFraction` coefficients; zero products retain potentially undefined factors; `sqrt(x*x)` and `x/x` are not rewritten; see [MATH_SYMBOLIC.md](MATH_SYMBOLIC.md) |
| `tensor` | Rank 1 through 4, nonnegative extents, finite values, at most 4096 values | `tensor values must match the shape`, `tensor matmul needs compatible shapes` | `binary64` row-major values |
| `algebra` | Prime modulus from 2 through 1000000 | `finite field needs a prime modulus`, `finite field element has no inverse` | Exact residue in `0 .. modulus-1` |
| `topology` | Unique triangle faces; vertex count 0 through 5000 and triangles of distinct in-range indices, at most 2000 faces | `topology face must be a triangle`, `topology vertex out of range` | Exact platform `int` `V - E + F` |
| `timeseries` | Finite series, valid lags; AR p<=128 and <=10000 steps; Markov size 1–128; scalar Kalman P,Q>=0/R>0 | Invalid shape/domain and nonfinite intermediates throw; undefined ACF throws; normalization tolerance 1e-12, no correction | binary64, with explicit conventions in [MATH_FOUNDATIONS.md](MATH_FOUNDATIONS.md) |
| `logic` | CNF <=16 variables/512 clauses/16M work units; square relation <=128 | Invalid literals/work limits/shapes throw; unsat is a separate SatResult flag | Exact finite Boolean operations |
| `topology::homology` | F2 complex: <=128 vertices, <=128 triangles, <=256 edges after closure | Invalid/duplicate faces and invalid edges/work limits throw | Exact ordinary b0/b1/b2, not integral or higher-dimensional homology |
