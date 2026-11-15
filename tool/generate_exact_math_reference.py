"""Frozen Quds exact-arithmetic references; Python standard library only."""
from fractions import Fraction
from math import comb, factorial
from pathlib import Path
import random

checks = []
def integer(expression, expected):
    checks.append(f'  _expectBig(counter, {expression}, "{expected}")')
def rational(expression, expected):
    checks.append(f'  _expectRational(counter, {expression}, "{expected.numerator}", "{expected.denominator}")')
def b(value):
    return f'bigInt("{value}")'
def f(value):
    return f'bigFraction({b(value.numerator)}, {b(value.denominator)})'

for n in list(range(41)) + [50, 75, 100, 150, 200]:
    integer(f'bigFactorial({n})', factorial(n))
a, bval = 0, 1
for n in range(1001):
    if n <= 100 or n in [150, 200, 500, 1000]:
        integer(f'bigFibonacci({n})', a)
    a, bval = bval, a + bval
rng = random.Random(58219)
for _ in range(160):
    n = rng.randrange(501)
    k = rng.randrange(n + 1)
    integer(f'bigCombinations({n}, {k})', comb(n, k))
# Inclusion/exclusion is independent of the SDK's descending Stirling DP.
def stirling(n, k):
    return sum((-1)**(k-j) * comb(k,j) * j**n for j in range(k+1)) // factorial(k)
for n in range(21):
    for k in range(n + 2):
        integer(f'bigStirlingSecond({n}, {k})', stirling(n,k))
for n in list(range(21)) + [30,40,50]:
    integer(f'bigBell({n})', sum(stirling(n,k) for k in range(n+1)))
# Catalan convolution instead of the SDK's binomial formula.
catalan = [1]
for n in range(1,41):
    catalan.append(sum(catalan[i] * catalan[n-1-i] for i in range(n)))
for n,value in enumerate(catalan):
    integer(f'bigCatalan({n})', value)
# Euler pentagonal recurrence, independent of coin-change DP in the SDK.
partitions = [1]
for n in range(1,151):
    total = 0
    k = 1
    while k*(3*k-1)//2 <= n:
        sign = 1 if k % 2 else -1
        total += sign * partitions[n-k*(3*k-1)//2]
        second = k*(3*k+1)//2
        if second <= n:
            total += sign * partitions[n-second]
        k += 1
    partitions.append(total)
for n,value in enumerate(partitions):
    integer(f'bigPartitions({n})', value)
# Signed, highly cancellable rationals far beyond machine integer ranges.
for _ in range(60):
    a = Fraction(rng.randrange(-2**160, 2**160), rng.randrange(1, 2**110))
    c = Fraction(rng.randrange(-2**160, 2**160), rng.randrange(1, 2**110))
    rational(f(a), a)
    rational(f'({f(a)} + {f(c)})', a+c)
    rational(f'({f(a)} - {f(c)})', a-c)
    rational(f'({f(a)} * {f(c)})', a*c)
    rational(f'({f(a)} / {f(c)})', a/c)
    rational(f'{f(a)}.negated()', -a)
    rational(f'{f(a)}.reciprocal()', 1/a)

header = '''# Generated using independent Python integers and fractions.Fraction.
# Running this Quds suite requires no Python installation.
use quds:math

class _ExactCount:
  var value: int = 0

_expectBig(counter: _ExactCount, actual: BigInt, decimal: String):
  counter.value += 1
  expect(actual.toString(), decimal)

_expectRational(counter: _ExactCount, actual: BigFraction, top: String, bottom: String):
  counter.value += 1
  expect(actual.numerator.toString(), top)
  expect(actual.denominator.toString(), bottom)
  expect(actual.denominator > BigInt.zero, true)
  expect(actual.numerator.gcd(actual.denominator), BigInt.one)

test "exact arithmetic against frozen independent Quds references":
  counter = _ExactCount()
'''
Path('test/math_exact_reference.quds').write_text(header + '\n'.join(checks) +
    f'\n  expect(counter.value, {len(checks)})\n  print "QUDS EXACT CHECKS={len(checks)} FAILURES=0"\n')
print(f'Quds exact references: {len(checks)}')
