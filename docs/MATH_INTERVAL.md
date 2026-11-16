# Binary64 neighbors and outward-rounded intervals

This delivery adds `nextUp`, `nextDown`, `ulp`, `realInterval` and the immutable
`RealInterval` value class in `quds:math`. The existing `Interval` and `interval`
retain their original contracts. The SDK now has 380 public top-level functions.
The new neighbors are in `scalar`; `RealInterval` and `realInterval` are in
`interval::outward`. Both remain available through `use quds:math`.

The concurrently published `OutwardInterval` API is retained in the same
section, with its documented finite-endpoint, subnormal and overflow limits.
`RealInterval` supplies a separate extended contract: subnormal inputs,
unbounded endpoints, arithmetic operators and validation on every operation.
The existing `outwardPoint`/`outwardAdd` family keeps its names and behavior;
no automatic conversion between the two types is introduced.

## Adjacent values

- `nextUp(x)` gives the adjacent binary64 value toward positive infinity.
  Positive infinity stays fixed; negative infinity becomes negative max-finite.
- `nextDown(x)` gives the adjacent value toward negative infinity.
- `ulp(x)` gives the positive spacing in the binade containing `abs(x)`.
  At a power of two it uses the spacing above that magnitude. At max-finite it
  returns the finite spacing, rather than the distance to infinity. Both zeros
  and all subnormals have spacing `5e-324`. Either infinity gives positive
  infinity. All three functions propagate NaN.

Neighbors preserve the zero approached from a given side: `nextUp(-5e-324)`
is negative zero and `nextDown(5e-324)` is positive zero. From either zero,
`nextUp` gives positive min-subnormal and `nextDown` negative min-subnormal.

The implementation normalizes using exact powers of two and constructs the
spacing using exact binary scaling. It avoids logarithm-based exponent estimates
and fixed-width bit reinterpretation. A call uses O(1074) bounded scalar work
in the worst case; this is a portable reference implementation rather than a
claim of hardware-level throughput. The normal/subnormal boundary and the
smaller upward step at negative powers of two are handled explicitly.

## Intervals of finite real numbers

`realInterval(low, high)` requires ordered, non-NaN endpoints. It does not
reorder them. A lower endpoint of negative infinity or an upper endpoint of
positive infinity denotes an unbounded interval of **finite real values**.
A lower endpoint of positive infinity or an upper endpoint of negative infinity
is rejected. Empty intervals and singleton infinities are not represented.

The raw `RealInterval(low: ..., high: ...)` constructor stores its inputs;
all public operations validate these inputs again. `contains(x)` accepts only
finite values and checks both closed endpoints. It returns false for NaN and
both infinities even on the whole real line.

`+`, binary `-`, `*` and `/` return an enclosure of all exact real arithmetic
results on the input intervals. Unary `-` exactly reverses and negates endpoints.
Addition and subtraction evaluate extremal endpoints and extend by one binary64
neighbor in each direction. Multiplication bounds all four endpoint products
and extends outward. A zero point interval times any valid interval is exactly
`[0, 0]`; the endpoint convention `0 * infinity = 0` is used only in endpoint
bounds for unbounded real intervals. No infinite real operand is admitted.
Division encloses the reciprocal and then multiplies. A denominator containing
zero, including a zero endpoint, throws; split intervals are not returned.

The enclosure argument relies on IEEE-754 binary64 correctly rounded basic
arithmetic on the supported Dart VM and JavaScript backends. Extending each
rounded result by one adjacent representable value encloses the corresponding
exact result, including underflow and overflow. An overflowed positive lower
bound becomes max-finite while its upper bound remains positive infinity.
Reciprocal endpoints are extended before multiplication; their known sign is
retained when rounding away from zero would otherwise cross it.

Results may be wider than the tightest representable enclosure. Division may
be especially wide when its intermediate reciprocal overflows. Repeated
variables are treated independently: `x - x` need not be the zero interval.
There is no configurable rounding mode, decimal arithmetic, empty-set algebra,
transcendental interval evaluation or automatic proof system in this delivery.

```quds
use quds:math

main():
  a = realInterval(0.1, 0.1)
  b = realInterval(0.2, 0.2)
  print (a + b).contains(0.3) # true
  print nextUp(1.0) > 1.0    # true
  print ulp(0.0)            # minimum positive subnormal
```

Errors are explicit strings:

- `RealInterval needs ordered non-NaN endpoints`
- `RealInterval endpoints enclose no finite reals`
- `RealInterval division contains zero`

## Primary Quds verification

```sh
dart run bin/quds.dart test test/math_interval.quds
dart run bin/quds.dart test test/math_interval_reference.quds
dart run bin/quds.dart test test/math_interval_imports.quds
```

The hand-written suite has five declarations covering boundary neighbors,
signed zeros, decimal rounding, unbounded intervals, underflow/overflow,
immutability, invalid raw constructors and division-domain errors.

The generated suite has **1138 cases**. Python `math.nextafter` and `math.ulp`
provide independent adjacent-value references, including random binary64 bit
patterns and neighbors of powers of two from the smallest subnormal to large
normal numbers. Exact Python `Fraction.from_float` arithmetic supplies interval
extrema. Quds converts finite result bounds to exact `BigFraction` and checks
containment of those extrema. Single-step operations also have an eight-neighbor
width guard to reject a trivial whole-line implementation; division is tested
for enclosure without a tightness promise. The generator uses only the Python
standard library and a fixed seed:

```sh
python3 tool/generate_interval_reference.py
```

The Dart suite launches these actual Quds declarations. Supplemental JavaScript
and Node checks exercise signed zeros, limits, ULPs, interval arithmetic,
underflow and overflow. Finite case coverage supports the contracts; it is not
an exhaustive enumeration of all binary64 operand combinations.

The additional section-import Quds test covers prefixed `scalar` and
`interval::outward` imports and both interval APIs together.
