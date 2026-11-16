"""Independent binary64 neighbors and exact rational interval enclosures."""
from fractions import Fraction as F
from pathlib import Path
import math
import random
import struct

rng = random.Random(44919)
checks = []
def lit(x):
    if math.isnan(x): return '(0.0 / 0.0)'
    if math.isinf(x): return '(-1.0 / 0.0)' if x < 0 else '(1.0 / 0.0)'
    return repr(x)
def frac(x): return f'bigFraction(bigInt("{x.numerator}"), bigInt("{x.denominator}"))'
def span(a,b): return f'realInterval({lit(a)}, {lit(b)})'
values = [0., -0., math.inf, -math.inf, math.nan, 5e-324, -5e-324,
          math.nextafter(math.inf,0), -math.nextafter(math.inf,0)]
for exponent in [-1074,-1073,-1023,-1022,-1021,-1000,-500,-53,-52,-1,0,1,52,53,500,1000,1023]:
    base=2.**exponent
    for x in [math.nextafter(base,0),base,math.nextafter(base,math.inf)]:
        values.extend([x,-x])
for _ in range(160):
    x=struct.unpack('>d',rng.getrandbits(64).to_bytes(8,'big'))[0]
    values.append(x)
for x in values:
    for expression,expected in [(f'nextUp({lit(x)})',math.nextafter(x,math.inf)),
                                (f'nextDown({lit(x)})',math.nextafter(x,-math.inf)),
                                (f'ulp({lit(x)})',math.ulp(x))]:
        checks.append(f'  _intervalFloat(counter, {expression}, {lit(expected)})')

# Fraction endpoints are independent of the implementation's rounded operations.
# Check enclosure, and for single-step ops require bounds within eight adjacent
# floats of the correctly directed exact extrema (rules out trivial whole-line).
def guard(x,direction):
    try: rounded=float(x)
    except OverflowError: rounded=math.inf if x>0 else -math.inf
    for _ in range(8): rounded=math.nextafter(rounded,direction)
    return rounded
pairs=[(0.,0.),(-5e-324,5e-324),(5e-324,1e-323),(-1e308,1e308),
       (.1,.2),(-.3,-.1),(1e-308,1e-300),(-1e300,-1e-300),
       (1.7976931348623157e308,1.7976931348623157e308)]
for _ in range(82):
    numbers=[rng.uniform(-4,4)*10.**rng.choice([-300,-150,-10,0,10,150,300]) for _ in range(2)]
    pairs.append(tuple(sorted(numbers)))
for index,(a,b) in enumerate(pairs):
    c,d=pairs[(index*17+3)%len(pairs)]
    aa,bb,cc,dd=map(F.from_float,[a,b,c,d])
    cases=[('+',aa+cc,bb+dd),('-',aa-dd,bb-cc)]
    products=[aa*cc,aa*dd,bb*cc,bb*dd]
    cases.append(('*',min(products),max(products)))
    if not cc<=0<=dd:
        quotients=[aa/cc,aa/dd,bb/cc,bb/dd]
        cases.append(('/',min(quotients),max(quotients)))
    for op,lower,upper in cases:
        lower_guard=guard(lower,-math.inf) if op!='/' else -math.inf
        upper_guard=guard(upper,math.inf) if op!='/' else math.inf
        checks.append(f'  _intervalEnclosure(counter, {span(a,b)} {op} {span(c,d)}, {frac(lower)}, {frac(upper)}, {lit(lower_guard)}, {lit(upper_guard)})')

header='''# Generated using Python math.nextafter/math.ulp and exact Fraction arithmetic.
use quds:math

class _IntervalCount:
  var value: int = 0

_intervalFloat(counter: _IntervalCount, actual: double, expected: double):
  counter.value += 1
  if expected.isNaN:
    expect(actual.isNaN, true)
  else:
    expect(actual, expected)
    if expected == 0.0: expect(actual.isNegative, expected.isNegative)

_intervalEnclosure(counter: _IntervalCount, actual: RealInterval, lower: BigFraction, upper: BigFraction, lowerGuard: double, upperGuard: double):
  counter.value += 1
  expect(actual.low.isNaN or actual.high.isNaN, false)
  expect(actual.low <= actual.high, true)
  if actual.low.isFinite:
    expect(binaryFraction(actual.low).compareTo(lower) <= 0, true)
  else:
    expect(actual.low, -1.0 / 0.0)
  if actual.high.isFinite:
    expect(binaryFraction(actual.high).compareTo(upper) >= 0, true)
  else:
    expect(actual.high, 1.0 / 0.0)
  expect(actual.low >= lowerGuard, true)
  expect(actual.high <= upperGuard, true)

test "binary64 neighbors and intervals against independent exact references":
  counter = _IntervalCount()
'''
Path('test/math_interval_reference.quds').write_text(header+'\n'.join(checks)+
    f'\n  expect(counter.value, {len(checks)})\n  print "QUDS INTERVAL CHECKS={len(checks)} FAILURES=0"\n')
print(f'Quds interval references: {len(checks)}')
