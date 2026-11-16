# Exact integers, rationals and combinatorial counts

Delivery B3 provides an exact-arithmetic foundation in `quds:math`. It does not
replace the existing bounded `int` or binary64 functions. Decimal arithmetic is now in `exact::decimal`, and limited symbolic trees
are in `symbolic`; see [MATH_PLAN.md](MATH_PLAN.md). General symbolic algebra
remains outside this delivery.
Outward-rounded binary64 intervals are now documented in [MATH_INTERVAL.md](MATH_INTERVAL.md).

## Integer interop

The SDK re-exports Dart's `BigInt`. `bigInt(text)` parses a signed integer with
`BigInt.parse`, without passing through machine `int` or `double`. Decimal and
hexadecimal forms accepted by Dart are supported; malformed input propagates
`FormatException`. Large numeric data should arrive as text, not as an already
rounded `double` passed to `BigInt.from`.

BigInt values have no fixed bit-width, but parsing and arithmetic can exhaust
available time or memory. The same exact algorithms are available on VM and
JavaScript. The compiler now reads SDK operator signatures rather than treating
BigInt arithmetic as dynamic: `+ - * ~/ % & | ^ << >>`, unary `-`/`~` and comparisons
retain their declared types; `/` returns `double` as specified by Dart. There
is no implicit int-to-BigInt conversion or invented BigInt `>>>` operation.
Nullable receivers must be handled before arithmetic.

## Exact rationals

`bigFraction(numerator: BigInt, denominator: BigInt)` creates a canonical
`BigFraction`: gcd-reduced terms, positive denominator, and zero as `0/1`.
A zero denominator throws `bigFraction needs a non-zero denominator`.

The value supports binary `+`, `-`, `*`, `/`, `negated()`, `reciprocal()`,
`compareTo(other)` and `toString()`. Multiplication/division cross-cancel before
forming large products; addition uses the gcd of denominators. Arithmetic
validates operand denominators and normalizes outputs. Dividing by a zero-valued
fraction throws `division by zero`.

As with the existing `Fraction`, the public raw `BigFraction(...)` value
constructor stores the supplied fields unchanged. It is not the normalizing
factory. Raw `2/4` and canonical `1/2` differ under structural equality;
`compareTo` correctly reports mathematical equality after normalization. Raw
zero denominators are rejected by arithmetic. `toString()` prints the stored
`numerator/denominator`, including raw noncanonical values.

There is no rounding or fixed precision for integer/rational operations. No
floating conversion API is provided here: dividing two huge BigInts as doubles
would not, by itself, be a reliable rational-to-double conversion.

## Combinatorial functions and work contracts

| API | Definition | Explicit input/work guard |
| --- | --- | --- |
| `bigFactorial(n)` | Exact n!, with 0!=1 | 0<=n<=100000 |
| `bigCombinations(n,k)` | Exact binomial coefficient; k>n gives 0 | 0<=n<=100000; k>=0 |
| `bigFibonacci(n)` | F0=0, F1=1, fast doubling | 0<=n<=1000000 |
| `bigCatalan(n)` | choose(2n,n)/(n+1) | 0<=n<=50000 |
| `bigStirlingSecond(n,k)` | Set partitions into k nonempty groups; S(0,0)=1; k>n gives 0 | 0<=n<=10000; k>=0; n*k<=1000000 when k<=n |
| `bigBell(n)` | Number of set partitions; B0=1 | 0<=n<=1000 |
| `bigPartitions(n)` | Unrestricted unordered integer partitions; p(0)=1 | 0<=n<=2000 |

Guards bound algorithmic work, not integer precision. Invalid n throws
`<operation> needs n from 0 through <limit>`. Negative k has an operation-specific
`needs nonnegative k` error. Exceeding Stirling's work budget throws
`bigStirlingSecond work limit exceeded`. Guards run before expensive work.

Fast doubling uses O(log n) BigInt steps; factorial and binomial use O(n) steps;
Catalan delegates to binomial. Stirling uses O(n*k+n) steps and O(k) storage;
Bell and partitions use O(n²) additions and O(n) storage. BigInt operation cost
grows with operand bit-length; these are not fixed-cost or latency guarantees.

## Quds example

```quds
use quds:math

main():
  amount = bigInt("1208925819614629174706176")
  print amount + BigInt.one
  print bigFraction(amount, amount)       # 1/1
  print bigFactorial(30)                  # 265252859812191058636308480000000
  print bigFibonacci(100)                 # 354224848179261915075
  print bigPartitions(100)                # 190569292
```

Prefix/show imports are tested, as are cross-cancellation far beyond machine
ranges, raw/canonical distinctions, zero and negative inputs, and work guards.

## Verification

```sh
dart run bin/quds.dart test test/math_exact.quds
dart run bin/quds.dart test test/math_exact_reference.quds
```

The six hand-written Quds declarations check interop, domains, normalization,
errors and boundary conventions. The frozen Quds suite contains **1199 reference
cases** generated independently with Python integers and `fractions.Fraction`:

- Integer factorial/Fibonacci/binomial anchors, including results beyond 64 bits.
- Stirling by exact inclusion/exclusion, independently of the SDK's recurrence.
- Bell by sums of independent Stirling values, not the SDK's Bell triangle.
- Catalan by convolution, not the SDK's binomial formula.
- Partitions by Euler's pentagonal recurrence, not coin-change DP.
- Signed 160-bit rational arithmetic and canonical numerator/denominator checks.

Generation uses only Python's standard library:

```sh
python3 tool/generate_exact_math_reference.py
```

Running the committed suites needs no Python. Supplemental JavaScript tests
execute BigInt arithmetic, exact factorial/Fibonacci and rational normalization.
Compiler tests additionally inspect operator result types and reject mixed or
nullable operands, instead of relying on eventual Dart compilation errors.
These finite checks do not prove every input or validate Dart's entire BigInt
implementation; exactness relies on the specified BigInt arithmetic backend.
