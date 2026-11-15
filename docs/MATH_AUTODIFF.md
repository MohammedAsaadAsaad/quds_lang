# Forward automatic differentiation

`quds:math` supplies forward-mode `Dual` values, scalar derivatives, gradients
and Jacobians. This is delivery C1 plus the first part of C2 in the expansion
roadmap. Hessians, reverse-mode AD and a tensor engine are not implemented here.

## Values and arithmetic

`Dual(value: double, tangent: double)` represents value + tangent*epsilon, with
epsilon²=0. `dualConstant(value)` seeds a zero tangent; `dualVariable(value)`
seeds one. A custom finite tangent requests a directional derivative.

Arithmetic supports `+`, binary/unary `-`, `*`, `/` between Dual values. Constants
must be lifted explicitly; there is no implicit double-to-Dual conversion.
The methods `exp`, `ln`, `sqrt`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`
and `pow(exponent)` apply analytic chain rules, not finite differences.

The public raw value constructor stores its fields unchanged. Helpers and
operations validate finite input values/tangents, and reject non-finite results.
Invalid raw input throws `Dual needs finite value and tangent`; a non-finite
computed result throws `Dual result is not finite`. Division by a zero-valued
Dual throws `Dual division by zero`.

## Real domains

- `ln` and `sqrt` require a strictly positive value. In particular sqrt at zero
  rejects even a zero tangent; this API does not silently invent a derivative at
  the boundary of the real domain.
- `asin` and `acos` require -1<value<1. Endpoint infinite derivatives reject.
- `tan` uses the Dart real trigonometric functions and rejects an exactly zero
  computed cosine. A binary64 approximation of pi/2 is not the exact real pole.
- `pow` requires a finite, constant exponent. Negative bases require an integer
  exponent. At zero, only nonnegative integer exponents are accepted: exponent 0
  returns constant one (Dart's 0^0 convention), exponent 1 retains the tangent,
  and larger integer exponents have zero tangent. Negative or noninteger
  zero-base derivative requests reject explicitly.

There is no general differentiability test. A callback must represent the desired
smooth real expression using Dual operations, and must not define its mathematical
value in terms of the seed tangent. Branches and nondifferentiable points remain
the caller's responsibility.

## Evaluation contracts

| API | Output | Callback calls |
| --- | --- | --- |
| `evaluateDual(f,x)` | Dual value and first derivative | Exactly one |
| `autoDerivative(f,x)` | First derivative only | Exactly one |
| `autoGradient(f,point)` | One derivative per input coordinate | Exactly n, zero for n=0 |
| `autoJacobian(f,point)` | Output components are rows; input coordinates are columns | Exactly n, or one for n=0 to discover output dimension |

Seeds run in ascending input-coordinate order. There are no hidden extra calls to
estimate function values. Every seed list is fresh, and output rows are separate
lists. The original point is not mutated or handed to the callback. A callback may
mutate its working seed list without altering later seeds.

For n=0 the gradient returns [] without calling f, so it does not certify f's value
or domain at that empty point. A zero-input Jacobian calls f once and returns one
empty row per output. Zero-output callbacks are supported. A changing Jacobian
output length throws `autoJacobian output shape changed` instead of returning a
partial matrix. A NaN/infinite point throws
`automatic differentiation needs a finite point` before invoking the callback.

A mathematically consistent gradient/Jacobian requires a pure value computation
across seeds. Instrumentation may count calls; arbitrary state-dependent values
cannot be certified. Shape validation is not a proof of callback purity.

Gradient cost is n callback evaluations plus O(n²) seed preparation. Jacobian cost
adds O(n*m) output work/storage for m outputs. Big expressions and callback storage
are additional costs. No performance claim for reverse-mode-sized problems is made.

## Numerical behavior

Values and tangents use binary64. AD approximates derivatives of the underlying
real expression; it is not the derivative of a quantized floating-point mapping.
Rounding and conditioning still matter.

Quotient differentiation avoids explicitly squaring the denominator and scales
products to preserve derivatives when the value underflows. atan avoids a squared
large argument. Power derivatives use a logarithmic fallback near underflow or
overflow, and preserve derivative parity for very large integer exponents.
These measures do not provide a universal error certificate. Non-finite working
terms can conservatively reject a mathematically finite result, especially after
catastrophic cancellation. Subnormal outputs retain limited absolute resolution.

## Quds examples

```quds
use quds:math

main():
  print autoDerivative((x: Dual) -> x * x * x, 3.0) # 27.0
  print autoGradient((point: List<Dual>) -> point[0] * point[1], [2.0, 3.0])
  print autoJacobian(point -> [point[0] * point[1], point[0] + point[1]], [2.0, 3.0])
```

The gradient is [3,2]; the Jacobian is [[3,2],[1,1]]. Prefix imports and filtered
imports also work, including inferred callback types:

```quds
use quds:math show autoDerivative

test "filtered AD":
  expect(autoDerivative(x -> x.sin(), 0.0), 1.0)
```

The compiler retains the nominal identity of public types in imported signatures
without exposing names removed by `show`. Generated private type imports support
inferred callback annotations. A caller class or alias named Dual remains distinct
from the SDK class. The existing container compatibility rules remain intact;
recognizing two spellings of one class does not widen numeric list element types.

## Verification

```sh
dart run bin/quds.dart test test/math_autodiff.quds
dart run bin/quds.dart test test/math_autodiff_reference.quds
dart run bin/quds.dart test test/math_autodiff_imports.quds
dart run bin/quds.dart test test/math_autodiff_alias.quds
```

The frozen suite contains **598 cases** from mpmath with 400 digits of precision,
using analytic derivatives at exact binary64 inputs, including large trig
arguments, subnormal quotients and derivatives recovered after value underflow.
Each case checks both value and tangent. The sampled-grid threshold is relative
1e-10 plus 1.5e-323 absolute (about three minimum-subnormal units); it is not a
proven global bound.

Nine hand-written declarations cover arithmetic, domain rejection, explicit
callback counts, seed order, gradient/Jacobian analytic values, empty dimensions,
changing output shapes, ownership and extreme scales. Separate Quds import/alias
suites and compiler rejection tests cover nominal identity and import filtering.
JavaScript smoke tests execute scalar, gradient and Jacobian calculations.
References regenerate with `python3 tool/generate_autodiff_reference.py` using
mpmath 1.3.0; running the committed Quds suites needs no Python.
