import 'dart:io';

import 'libraries.dart';

/// Source of `quds:core`. Kept equal to `lib/sdk/core.quds`.
const coreSdkSource = '''# A list under another name.
# Example:
#   numbers: Array<int> = [1, 2, 3]
type Array = List

# A map under another name.
# Example:
#   ages: Dict<String, int> = map:
#     "Ada": 36
type Dict = Map

# A set under another name.
# Example:
#   seen: HashSet<int> = set:
#     1
type HashSet = Set

# Values kept in last-in, first-out order.
# Example:
#   stack = Stack<int>()
#   stack.push(1)
class Stack<T>:
  private var items: List<T>? = null
  # Puts [value] on top.
  # Example:
  #   stack.push(1)
  push(value: T):
    local = items
    if local == null:
      items = [value]
    else:
      local.add(value)
  # Removes and returns the top value.
  # Example:
  #   stack.push(1)
  #   print stack.pop()
  pop() -> T:
    local = items
    if local == null:
      blank: List<T> = []
      return blank.removeLast()
    else:
      return local.removeLast()
  # The top value, leaving it in place.
  # Example:
  #   stack.push(1)
  #   print stack.top()
  top() -> T:
    local = items
    if local == null:
      blank: List<T> = []
      return blank.last
    else:
      return local.last
  # How many values are stored.
  # Example:
  #   print stack.size()
  size() -> int:
    local = items
    if local == null:
      return 0
    else:
      return local.length
  # True when nothing is stored.
  # Example:
  #   print stack.empty()
  empty() -> bool:
    local = items
    if local == null:
      return true
    else:
      return local.isEmpty
  # A list of the stored values, from bottom to top.
  # Example:
  #   print stack.toList()
  toList() -> List<T>:
    local = items
    if local == null:
      empty: List<T> = []
      return empty
    else:
      return local.toList()

# Values kept in first-in, first-out order.
# Example:
#   line = Queue<String>()
#   line.add("a")
class Queue<T>:
  private var items: List<T>? = null
  # Adds [value] at the end.
  # Example:
  #   line.add("a")
  add(value: T):
    local = items
    if local == null:
      items = [value]
    else:
      local.add(value)
  # Removes and returns the earliest value.
  # Example:
  #   line.add("a")
  #   print line.take()
  take() -> T:
    local = items
    if local == null:
      blank: List<T> = []
      return blank.removeAt(0)
    else:
      return local.removeAt(0)
  # The earliest value, leaving it in place.
  # Example:
  #   line.add("a")
  #   print line.next()
  next() -> T:
    local = items
    if local == null:
      blank: List<T> = []
      return blank.first
    else:
      return local.first
  # How many values are waiting.
  # Example:
  #   print line.size()
  size() -> int:
    local = items
    if local == null:
      return 0
    else:
      return local.length
  # True when nothing is waiting.
  # Example:
  #   print line.empty()
  empty() -> bool:
    local = items
    if local == null:
      return true
    else:
      return local.isEmpty
  # A list of the waiting values, from earliest to latest.
  # Example:
  #   print line.toList()
  toList() -> List<T>:
    local = items
    if local == null:
      empty: List<T> = []
      return empty
    else:
      return local.toList()

# Counts how many times each value was added.
# Example:
#   bag = Bag<String>()
#   bag.add("go")
class Bag<T>:
  private var counts: Map<T, int>? = null
  # Records one more occurrence of [value].
  # Example:
  #   bag.add("go")
  add(value: T):
    local = counts
    if local == null:
      made: Map<T, int> = map:
        value: 1
      counts = made
    else:
      found = local[value] ?? 0
      local.remove(value)
      next = found + 1
      local.putIfAbsent(value, () -> next)
  # How many times [value] was added.
  # Example:
  #   print bag.count("go")
  count(value: T) -> int:
    local = counts
    if local == null:
      return 0
    else:
      return local[value] ?? 0
  # The sum of every count.
  # Example:
  #   print bag.total()
  total() -> int:
    local = counts
    if local == null:
      return 0
    else:
      return local.values.sum()


:: typed

# Contiguous fixed-length numeric storage from Dart. Views share bytes; fromList
# copies. Names and narrowing/rounding follow dart:typed_data.
# Example:
#   samples = Float64List(4)
#   samples[0] = 1.5
#   alias = Float64List.view(samples.buffer)
#   print alias[0]
use dart:typed_data show Float32List, Float64List, Int8List, Uint8List, Uint8ClampedList, Int16List, Uint16List, Int32List, Uint32List, ByteData, ByteBuffer, Endian, TypedData
export dart:typed_data show Float32List, Float64List, Int8List, Uint8List, Uint8ClampedList, Int16List, Uint16List, Int32List, Uint32List, ByteData, ByteBuffer, Endian, TypedData
''';

const extSdkSource = r'''extend List<T> Lists:
  # The value at index 1, or null when it is missing.
  # Example:
  #   numbers: List<int> = [1, 2, 3]
  #   print numbers.second()
  second() -> T?:
    if length < 2:
      return null
    return this[1]
  # The value at index 2, or null when it is missing.
  # Example:
  #   numbers: List<int> = [1, 2, 3]
  #   print numbers.third()
  third() -> T?:
    if length < 3:
      return null
    return this[2]
  # A new list from last to first.
  # Example:
  #   print numbers.reversedCopy()
  reversedCopy() -> List<T>:
    made: List<T> = []
    var index = length - 1
    while index >= 0:
      made.add(this[index])
      index = index - 1
    return made
  # A new list without [value].
  # Example:
  #   print numbers.without(2)
  without(value: T) -> List<T>:
    made: List<T> = []
    for item in this:
      if item != value:
        made.add(item)
    return made
  # A new list containing only [value].
  # Example:
  #   print numbers.keeping(2)
  keeping(value: T) -> List<T>:
    made: List<T> = []
    for item in this:
      if item == value:
        made.add(item)
    return made
  # Groups of [size] values. The last group may be shorter.
  # Example:
  #   print numbers.chunk(2).length
  chunk(size: int) -> List<List<T>>:
    groups: List<List<T>> = []
    if size < 1:
      return groups
    var index = 0
    while index < length:
      row: List<T> = []
      var taken = 0
      while taken < size:
        if index >= length:
          break
        row.add(this[index])
        index = index + 1
        taken = taken + 1
      groups.add(row)
    return groups

extend Map<K, V> Maps:
  # The keys whose value is [value].
  # Example:
  #   ages: Map<String, int> = map:
  #     "Ada": 1
  #   print ages.keysOf(1)
  keysOf(value: V) -> List<K>:
    found: List<K> = []
    for key in this.keys:
      if this[key] == value:
        found.add(key)
    return found
  # True when [key] is absent.
  # Example:
  #   print ages.missing("Cara")
  missing(key: K) -> bool:
    if this.containsKey(key):
      return false
    return true

extend Set<T> Sets:
  # A new set without [value].
  # Example:
  #   flags: Set<int> = set:
  #     1
  #     2
  #   print flags.without(1)
  without(value: T) -> Set<T>:
    made: Set<T> = set:
    for item in this:
      if item != value:
        made.add(item)
    return made

extend int Ints:
  # True when this integer is divisible by 2.
  # Example:
  #   print 4.even()
  even() -> bool = this % 2 == 0
  # True when this integer is not divisible by 2.
  # Example:
  #   print 5.odd()
  odd() -> bool = this % 2 != 0
  # -1 when negative, 1 when positive, and 0 at zero.
  # Example:
  #   print negative.signum()
  signum() -> int:
    if this > 0:
      return 1
    if this < 0:
      return -1
    return 0
  # True when this integer is from [low] through [high].
  # Example:
  #   print 3.between(1, 3)
  between(low: int, high: int) -> bool:
    if this < low:
      return false
    return this <= high
  # True when this integer is greater than zero.
  # Example:
  #   print 4.positive()
  positive() -> bool = this > 0
  # How many digits are used, ignoring the sign.
  # Example:
  #   print 100.digits()
  digits() -> int:
    var left = this
    if left < 0:
      left = 0 - left
    if left == 0:
      return 1
    var total = 0
    while left > 0:
      left = left ~/ 10
      total = total + 1
    return total
  # True when [by] divides this integer.
  # Example:
  #   print 12.divisible(3)
  divisible(by: int) -> bool:
    if by == 0:
      return false
    return this % by == 0
  # This integer multiplied by itself.
  # Example:
  #   print 4.squared()
  squared() -> int = this * this

extend double Doubles:
  # -1 when negative, 1 when positive, and 0 at zero.
  # Example:
  #   print 1.5.signum()
  signum() -> int:
    if this > 0.0:
      return 1
    if this < 0.0:
      return -1
    return 0
  # The integer at or just below this number.
  # Example:
  #   print 1.5.whole()
  whole() -> int = this.floor
  # True when this number is from [low] through [high].
  # Example:
  #   print 1.5.between(1.0, 2.0)
  between(low: double, high: double) -> bool:
    if this < low:
      return false
    return this <= high
''';

/// Source of `quds:math`. Kept equal to `lib/sdk/math.quds`.
const mathSdkSource = '''# Mathematics that dart:math does not provide.
# Every public dart:math name is still re-exported: pi, sqrt, sin, Random,
# Point, and the rest. Names added here are the ones Dart leaves out,
# including statistics, polynomials, dense linear algebra, calculus,
# transforms, special functions, optimization, and elementary number theory.
# log stays the logger. Natural log is ln, and a prefix still sees dart's log.
# min and max stay the language functions for two numbers of one type.
# A column-0 :: name opens a section. use quds:math::stats imports that section
# and every section named stats::something. This file is divided into scalar,
# number, complex, vector, interval, stats, distribution, calculus, interp,
# linalg, polynomial, signal, special, optimize, graph, graph::weighted,
# graph::flow, graph::matching, exact, exact::decimal, timeseries, logic,
# topology::homology, autodiff,
# autodiff::reverse, geometry, symbolic, tensor, algebra, and topology. Each
# of those sections is opened once. interval::outward is the outward-rounded
# interval type. support collects
# private helpers and exports nothing.
# A bare :: returns the following declarations to the library root.
# use quds:math still imports the whole library, including dart:math.
# Example:
#   print sqrt(9.0)
#   print pi
#   print ln(e)
#   print mean([1.0, 2.0, 3.0])
use dart:core show BigInt
export dart:core show BigInt
use dart:math as math
use dart:math
export dart:math

:: scalar

# Natural logarithm. log itself stays the logger.
# Example:
#   print ln(e)
ln(value: double) -> double = math.log(value)

# One full turn, in radians.
# Example:
#   print tau() > 6.0
tau() -> double = math.pi * 2.0

# The golden ratio.
# Example:
#   print phi() > 1.0
phi() -> double = (1.0 + math.sqrt(5.0)) / 2.0

# [value] degrees, written in radians.
# Example:
#   print radians(180.0)
radians(value: double) -> double = value * math.pi / 180.0

# [value] radians, written in degrees.
# Example:
#   print degrees(pi)
degrees(value: double) -> double = value * 180.0 / math.pi

# [angle] radians moved into the range (-pi, pi].
# Example:
#   print wrapRadians(tau())
wrapRadians(angle: double) -> double:
  shifted = angle % tau()
  if shifted > math.pi: return shifted - tau()
  return shifted

# The point [t] of the way from [a] to [b]. [t] is not clamped.
# Example:
#   print lerp(0.0, 10.0, 0.5)
lerp(a: double, b: double, t: double) -> double:
  if t == 0.0: return a
  if t == 1.0 or a == b: return b
  if (a < 0.0 and b > 0.0) or (a > 0.0 and b < 0.0):
    return (1.0 - t) * a + t * b
  return a + (b - a) * t

# Where [value] sits between [a] and [b], as a fraction of that span.
# Example:
#   print inverseLerp(0.0, 10.0, 5.0)
inverseLerp(a: double, b: double, value: double) -> double:
  if a == b: throw "inverseLerp needs two different ends"
  if not _finite(b - a) or not _finite(value - a):
    return (value / 2.0 - a / 2.0) / (b / 2.0 - a / 2.0)
  return (value - a) / (b - a)

# [value] read on one span and written on another.
# Example:
#   print remap(5.0, 0.0, 10.0, 0.0, 1.0)
remap(
    value: double,
    inLow: double,
    inHigh: double,
    outLow: double,
    outHigh: double) -> double:
  return lerp(outLow, outHigh, inverseLerp(inLow, inHigh, value))

# [value] limited to the closed span from [low] through [high].
# Example:
#   print bounded(5.0, 0.0, 1.0)
bounded(value: double, low: double, high: double) -> double:
  if low > high: throw "bounded needs low at or below high"
  if value < low: return low
  if value > high: return high
  return value

# True when [a] and [b] differ by at most [tolerance].
# Example:
#   print approximately(1.0, 1.0000001, 1.0e-6)
approximately(a: double, b: double, tolerance: double = 1.0e-9) -> bool:
  var gap = a - b
  if gap < 0.0: gap = 0.0 - gap
  return gap <= tolerance

# -1, 0, or 1, from the sign of [value].
# Example:
#   print signOf(-2.0)
signOf(value: double) -> int:
  if value > 0.0: return 1
  if value < 0.0: return -1
  return 0

# The non-negative fractional part of [value].
# Example:
#   print fractional(1.25)
fractional(value: double) -> double:
  return value - (value.floor to double)

# The remainder of [value] / [modulus] shifted into [0, modulus).
# Example:
#   print modulo(-1.0, 3.0)
modulo(value: double, modulus: double) -> double:
  if modulus == 0.0: throw "modulo by zero"
  var span = modulus
  if span < 0.0: span = 0.0 - span
  left = value % span
  if left < 0.0: return left + span
  return left

# The Euclidean length of the vector ([x], [y]), without overflow.
# Example:
#   print hypot(3.0, 4.0)
hypot(x: double, y: double) -> double:
  var ax = x
  var ay = y
  if ax < 0.0: ax = 0.0 - ax
  if ay < 0.0: ay = 0.0 - ay
  if ax > 1.7976931348623157e308: return ax
  if ay > 1.7976931348623157e308: return ay
  if ax != ax or ay != ay: return ax + ay
  if ax < ay:
    saved = ax
    ax = ay
    ay = saved
  if ax == 0.0: return 0.0
  ratio = ay / ax
  return ax * math.sqrt(1.0 + ratio * ratio)

# Base-2 logarithm.
# Example:
#   print log2(8.0)
log2(value: double) -> double = math.log(value) / math.ln2

# Base-10 logarithm.
# Example:
#   print log10(100.0)
log10(value: double) -> double = math.log(value) / math.ln10

# 10 to the power [places], for rounding to decimal places.
# Example:
#   print decimalScale(2)
decimalScale(places: int) -> double:
  if places < 0 or places > 308: throw "places must be from 0 through 308"
  var scale = 1.0
  var left = places
  while left > 0:
    scale = scale * 10.0
    left = left - 1
  return scale

# [value] rounded to [places] digits after the decimal point.
# Example:
#   print roundTo(1.235, 2)
roundTo(value: double, places: int) -> double:
  scale = decimalScale(places)
  if not _finite(value * scale): return value
  return ((value * scale).round to double) / scale

# [value] rounded down to [places] digits after the decimal point.
# Example:
#   print floorTo(1.239, 2)
floorTo(value: double, places: int) -> double:
  scale = decimalScale(places)
  if not _finite(value * scale): return value
  return ((value * scale).floor to double) / scale

# [value] rounded up to [places] digits after the decimal point.
# Example:
#   print ceilTo(1.231, 2)
ceilTo(value: double, places: int) -> double:
  scale = decimalScale(places)
  if not _finite(value * scale): return value
  return ((value * scale).ceil to double) / scale

# Smooth step from 0 at [edge0] to 1 at [edge1].
# Example:
#   print smoothstep(0.0, 1.0, 0.5)
smoothstep(edge0: double, edge1: double, value: double) -> double:
  if edge0 == edge1:
    if value < edge0: return 0.0
    return 1.0
  var t = (value - edge0) / (edge1 - edge0)
  if t < 0.0: t = 0.0
  if t > 1.0: t = 1.0
  return t * t * (3.0 - 2.0 * t)

# Interpolation of two angles in radians, along the short way around.
# Example:
#   print lerpAngle(0.0, pi / 2.0, 0.5)
lerpAngle(a: double, b: double, t: double) -> double:
  return a + wrapRadians(b - a) * t

# sin(x) / x, and 1 at zero. This is the unnormalized sinc.
# Example:
#   print sinc(0.0)
sinc(x: double) -> double:
  if x == 0.0: return 1.0
  return math.sin(x) / x

# The logistic function, in (0, 1).
# Example:
#   print sigmoid(0.0)
sigmoid(x: double) -> double = 1.0 / (1.0 + math.exp(0.0 - x))

# The inverse of [sigmoid]. [p] must sit strictly between 0 and 1.
# Example:
#   print logit(0.5)
logit(p: double) -> double:
  if p <= 0.0 or p >= 1.0:
    throw "logit needs a probability strictly between 0 and 1"
  return math.log(p / (1.0 - p))

# Hyperbolic sine. dart:math has sin, and does not have sinh.
# Example:
#   print sinh(0.0)
sinh(x: double) -> double:
  if x < 0.0: return 0.0 - sinh(0.0 - x)
  if x > 20.0: return math.exp(x - math.ln2)
  return (expm1(x) - expm1(0.0 - x)) / 2.0

# Hyperbolic cosine.
# Example:
#   print cosh(0.0)
cosh(x: double) -> double:
  mag = _abs(x)
  if mag > 20.0: return math.exp(mag - math.ln2)
  return (math.exp(mag) + math.exp(0.0 - mag)) / 2.0

# Hyperbolic tangent, in (-1, 1).
# Example:
#   print tanh(0.0)
tanh(x: double) -> double:
  if x > 20.0: return 1.0
  if x < -20.0: return -1.0
  rise = expm1(2.0 * x)
  return rise / (rise + 2.0)

# Inverse hyperbolic sine.
# Example:
#   print asinh(0.0)
asinh(x: double) -> double:
  if x < 0.0: return 0.0 - asinh(0.0 - x)
  if x < 1.0e-8: return x
  if x > 1.0e150: return math.log(x) + math.ln2
  return log1p(x + x * x / (1.0 + hypot(x, 1.0)))

# Inverse hyperbolic cosine. [x] must be at least 1.
# Example:
#   print acosh(1.0)
acosh(x: double) -> double:
  if x < 1.0: throw "acosh needs a value at least 1"
  if x > 1.0e150: return math.log(x) + math.ln2
  gap = x - 1.0
  return log1p(gap + math.sqrt(gap * (x + 1.0)))

# Inverse hyperbolic tangent. [x] must sit strictly between -1 and 1.
# Example:
#   print atanh(0.0)
atanh(x: double) -> double:
  if x <= 0.0 - 1.0 or x >= 1.0:
    throw "atanh needs a value strictly between -1 and 1"
  return 0.5 * (log1p(x) - log1p(0.0 - x))

# Real cube root, including for negative [x].
# Example:
#   print approximately(cbrt(8.0), 2.0, 1.0e-9)
cbrt(x: double) -> double:
  if x < 0.0: return 0.0 - cbrt(0.0 - x)
  if x == 0.0: return 0.0
  return math.exp(math.log(x) / 3.0)

# ln(1 + [x]), accurate when [x] is near zero. [x] must be greater than -1.
# Example:
#   print log1p(0.0)
log1p(x: double) -> double:
  if x <= 0.0 - 1.0: throw "log1p needs a value greater than -1"
  if x == 0.0: return x
  if x > 1.7976931348623157e308: return x
  shifted = 1.0 + x
  if shifted == 1.0: return x
  return math.log(shifted) * (x / (shifted - 1.0))

# exp([x]) - 1, accurate when [x] is near zero.
# Example:
#   print expm1(0.0)
expm1(x: double) -> double:
  if x == 0.0: return x
  if x < -37.0: return -1.0
  risen = math.exp(x)
  if _abs(risen) > 1.7976931348623157e308: return risen
  if risen == 1.0: return x
  return (risen - 1.0) * (x / math.log(risen))

extend double Reals:
  # This number of radians, written in degrees.
  # Example:
  #   print pi.toDegrees()
  toDegrees() -> double = degrees(this)
  # This number of degrees, written in radians.
  # Example:
  #   print 180.0.toRadians()
  toRadians() -> double = radians(this)
  # The non-negative fractional part.
  # Example:
  #   print 1.25.fractionalPart()
  fractionalPart() -> double = fractional(this)
  # True when this number is within 1e-9 of [other].
  # Example:
  #   print 1.0.about(1.0)
  about(other: double) -> bool = approximately(this, other, tolerance: 1.0e-9)

# Adjacent binary64 value toward positive infinity, including signed zero.
# NaN propagates; positive infinity is fixed. No logarithm or bit-width cast.
# Example:
#   print nextUp(1.0) > 1.0
nextUp(value: double) -> double:
  if value.isNaN: return value
  if value == 1.0 / 0.0: return value
  if value == -1.0 / 0.0: return -1.7976931348623157e308
  if value == 0.0: return 5.0e-324
  if value == -5.0e-324: return -0.0
  var magnitude = value.abs()
  var exponent = 0
  while magnitude >= 2.0:
    magnitude = magnitude * 0.5
    exponent += 1
  while magnitude < 1.0:
    magnitude = magnitude * 2.0
    exponent -= 1
  var step = _binarySpacing(exponent)
  if value < 0.0 and magnitude == 1.0 and exponent > -1022:
    step = step * 0.5
  return value + step

# Adjacent binary64 toward negative infinity. NaN propagates.
# Example:
#   print nextDown(1.0) < 1.0
nextDown(value: double) -> double = -nextUp(-value)

# Positive spacing at abs(value); at powers of two this uses the upper binade.
# Both zeros/subnormals have spacing 2^-1074; infinity maps to +infinity.
# Example:
#   print ulp(1.0)
ulp(value: double) -> double:
  if value.isNaN: return value
  if value.isInfinite: return 1.0 / 0.0
  var magnitude = value.abs()
  if magnitude < 2.2250738585072014e-308: return 5.0e-324
  var exponent = 0
  while magnitude >= 2.0:
    magnitude = magnitude * 0.5
    exponent += 1
  while magnitude < 1.0:
    magnitude = magnitude * 2.0
    exponent -= 1
  return _binarySpacing(exponent)

_binarySpacing(exponent: int) -> double:
  var power = exponent - 52
  if power < -1074: return 5.0e-324
  var spacing = 1.0
  while power < 0:
    spacing = spacing * 0.5
    power += 1
  while power > 0:
    spacing = spacing * 2.0
    power -= 1
  return spacing


:: number

# The greatest common divisor of [a] and [b]. The result is never negative.
# Example:
#   print gcd(12, 18)
gcd(a: int, b: int) -> int:
  var x = a
  var y = b
  while y != 0:
    next = x % y
    x = y
    y = next
  if x < 0 - _maxInt(): throw "gcd result is outside int range"
  if x < 0: return 0 - x
  return x

# The least common multiple of [a] and [b]. Zero when either argument is zero.
# Example:
#   print lcm(4, 6)
lcm(a: int, b: int) -> int:
  if a == 0 or b == 0: return 0
  answer = _checkedMultiply(a ~/ gcd(a, b), b)
  if answer < 0 - _maxInt(): throw "lcm result is outside int range"
  if answer < 0: return 0 - answer
  return answer

# [base] raised to a non-negative integer [exponent].
# Example:
#   print ipow(2, 10)
ipow(base: int, exponent: int) -> int:
  if exponent < 0: throw "ipow needs a non-negative exponent"
  var total = 1
  var left = exponent
  var factor = base
  while left > 0:
    if left % 2 == 1: total = _checkedMultiply(total, factor)
    left = left ~/ 2
    if left > 0: factor = _checkedMultiply(factor, factor)
  return total

# n! for a non-negative [n]. 0! is 1.
# Example:
#   print factorial(5)
factorial(n: int) -> int:
  if n < 0: throw "factorial of a negative"
  var total = 1
  var i = 2
  while i <= n:
    total = _checkedMultiply(total, i)
    i = i + 1
  return total

# Ordered selections of [k] items from [n].
# Example:
#   print permutations(5, 2)
permutations(n: int, k: int) -> int:
  if n < 0 or k < 0: throw "permutations needs non-negative arguments"
  if k > n: return 0
  var total = 1
  var i = 0
  while i < k:
    total = _checkedMultiply(total, n - i)
    i = i + 1
  return total

# Unordered selections of [k] items from [n].
# Example:
#   print combinations(5, 2)
combinations(n: int, k: int) -> int:
  if n < 0 or k < 0: throw "combinations needs non-negative arguments"
  if k > n: return 0
  var taken = k
  if taken > n - taken: taken = n - taken
  var total = 1
  var i = 0
  while i < taken:
    numerator = n - i
    denominator = i + 1
    common = gcd(numerator, denominator)
    reduced = numerator ~/ common
    rest = denominator ~/ common
    total = _checkedMultiply(total ~/ rest, reduced)
    i = i + 1
  return total

# True when [n] is a prime number.
# Example:
#   print isPrime(7)
isPrime(n: int) -> bool:
  return isProbablePrime(n)

# The least prime strictly greater than [n].
# Example:
#   print nextPrime(14)
nextPrime(n: int) -> int:
  if n < 2: return 2
  var candidate = _checkedAdd(n, 1)
  while not isPrime(candidate):
    candidate = _checkedAdd(candidate, 1)
  return candidate

# The [n]th Fibonacci number. fibonacci(0) is 0 and fibonacci(1) is 1.
# Example:
#   print fibonacci(10)
fibonacci(n: int) -> int:
  if n < 0: throw "fibonacci of a negative"
  if n == 0: return 0
  var previous = 0
  var current = 1
  var left = n - 1
  while left > 0:
    next = _checkedAdd(previous, current)
    previous = current
    current = next
    left = left - 1
  return current

# [base] ^ [exponent] modulo [modulus], in the range 0 through modulus - 1.
# Example:
#   print modPow(2, 10, 1000)
modPow(base: int, exponent: int, modulus: int) -> int:
  if modulus <= 0: throw "modPow needs a positive modulus"
  if exponent < 0: throw "modPow needs a non-negative exponent"
  var left = exponent
  var factor = base % modulus
  var total = 1 % modulus
  while left > 0:
    if left % 2 == 1: total = _mulMod(total, factor, modulus)
    left = left ~/ 2
    if left > 0: factor = _mulMod(factor, factor, modulus)
  return total

# The inverse of [a] modulo [modulus]. The arguments must be coprime.
# Example:
#   print modInverse(3, 11)
modInverse(a: int, modulus: int) -> int:
  if modulus <= 1: throw "modInverse needs a modulus above 1"
  var t = 0
  var newT = 1
  var r = modulus
  var newR = a % modulus
  while newR != 0:
    quote = r ~/ newR
    nextT = (t - _mulMod(quote % modulus, newT, modulus)) % modulus
    t = newT
    newT = nextT
    nextR = r - quote * newR
    r = newR
    newR = nextR
  if r != 1: throw "modInverse needs coprime arguments"
  return t

# Prime factors of [n], with repetition, in ascending order. 1 has none.
# Example:
#   print factorize(12)[2]
factorize(n: int) -> List<int>:
  if n <= 0: throw "factorize needs a positive integer"
  if n == 1:
    empty: List<int> = []
    return empty
  return _factorTree(n)

# Euler's totient of [n].
# Example:
#   print totient(10)
totient(n: int) -> int:
  if n < 1: throw "totient needs a positive integer"
  var total = n
  var last = 0
  for prime in factorize(n):
    if prime != last:
      total = total - total ~/ prime
      last = prime
  return total

# Primes from 2 through [n].
# Example:
#   print primesUpTo(10)[3]
primesUpTo(n: int) -> List<int>:
  if n < 2:
    empty: List<int> = []
    return empty
  var marks = _zeroInts(n + 1)
  var i = 2
  while i <= n:
    marks = _setInt(marks, i, 1)
    i = i + 1
  var p = 2
  while p * p <= n:
    if marks[p] == 1:
      var m = p * p
      while m <= n:
        marks = _setInt(marks, m, 0)
        m = m + p
    p = p + 1
  made: List<int> = []
  i = 2
  while i <= n:
    if marks[i] == 1: made.add(i)
    i = i + 1
  return made

# Miller-Rabin test. Deterministic for integers up to 3.8e18, probable beyond that.
# Example:
#   print isProbablePrime(97)
isProbablePrime(n: int) -> bool:
  if n < 2: return false
  if n == 2 or n == 3: return true
  if n % 2 == 0: return false
  var d = n - 1
  var s = 0
  while d % 2 == 0:
    d = d ~/ 2
    s = s + 1
  bases: List<int> = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]
  for base in bases:
    if n == base: return true
    var x = modPow(base, d, n)
    if x != 1 and x != n - 1:
      var r = 1
      var witness = false
      while r < s and not witness:
        x = _mulMod(x, x, n)
        if x == n - 1: witness = true
        else: r = r + 1
      if not witness: return false
  return true

# Solution of simultaneous congruences. The moduli need not be prime.
# Example:
#   print chineseRemainder([2, 3, 2], [3, 5, 7])
chineseRemainder(residues: List<int>, moduli: List<int>) -> int:
  if residues.isEmpty or residues.length != moduli.length:
    throw "chineseRemainder needs one residue per modulus"
  if moduli[0] <= 0: throw "chineseRemainder needs positive moduli"
  var acc = residues[0] % moduli[0]
  if acc < 0: acc = acc + moduli[0]
  var mod = moduli[0]
  var i = 1
  while i < residues.length:
    if moduli[i] <= 0: throw "chineseRemainder needs positive moduli"
    var a = residues[i] % moduli[i]
    if a < 0: a = a + moduli[i]
    g = gcd(mod, moduli[i])
    gap = a - acc
    if gap % g != 0: throw "chineseRemainder needs consistent residues"
    reduced = moduli[i] ~/ g
    var t = 0
    if reduced > 1:
      step = (mod ~/ g) % reduced
      t = _mulMod(modInverse(step, reduced), (gap ~/ g) % reduced, reduced)
    if t < 0: t = t + reduced
    modNext = _checkedMultiply(mod, reduced)
    acc = _addMod(acc % modNext, _mulMod(mod, t, modNext), modNext)
    mod = modNext
    i = i + 1
  acc = acc % mod
  if acc < 0: acc = acc + mod
  return acc

# Integers [x] and [y] with a x + b y = divisor, and divisor positive.
# Example:
#   print extendedGcd(240, 46).divisor
value class Bezout:
  divisor: int
  x: int
  y: int

extendedGcd(a: int, b: int) -> Bezout:
  var oldR = a
  var r = b
  var oldS = 1
  var s = 0
  var oldT = 0
  var t = 1
  while r != 0:
    q = oldR ~/ r
    nextR = oldR - q * r
    nextS = oldS - q * s
    nextT = oldT - q * t
    oldR = r
    r = nextR
    oldS = s
    s = nextS
    oldT = t
    t = nextT
  if oldR < 0 - _maxInt(): throw "extendedGcd result is outside int range"
  if oldR < 0:
    oldR = 0 - oldR
    oldS = 0 - oldS
    oldT = 0 - oldT
  return Bezout(divisor: oldR, x: oldS, y: oldT)


# GMRES solution of a square linear system. The start is the zero vector.
# Example:
#   print gmres([[4.0, 1.0], [1.0, 3.0]], [1.0, 2.0])[0]
_gmresUnit(rows: List<List<double>>, values: List<double>) -> List<double>:
  grid = _squareCopy(rows)
  n = grid.length
  if values.length != n: throw "gmres needs one value per row"
  residual = _copyDoubles(values)
  norm0 = vectorLength(residual)
  if norm0 == 0.0: return _zeroDoubles(n)
  var basis: List<List<double>> = []
  basis.add(_scaleVector(residual, 1.0 / norm0))
  var tall = _filled(n + 1, n, 0.0)
  var columns = 0
  var guard = 0
  while columns < n and guard < n:
    var image = matvec(grid, basis[columns])
    var i = 0
    while i <= columns:
      coef = dot(basis[i], image)
      tall = _put(tall, i, columns, coef)
      image = _axpy(image, basis[i], 0.0 - coef)
      i = i + 1
    below = vectorLength(image)
    tall = _put(tall, columns + 1, columns, below)
    columns = columns + 1
    if below <= 1.0e-12: guard = n
    else:
      basis.add(_scaleVector(image, 1.0 / below))
      guard = guard + 1
  gram = _hessGram(tall, columns)
  rhs = _hessRhs(tall, columns, norm0)
  weights = solveLinear(gram, rhs)
  var answer = _zeroDoubles(n)
  var j = 0
  while j < columns:
    answer = _axpy(answer, basis[j], weights[j])
    j = j + 1
  return answer

# BiCGSTAB solution of a square linear system.
# Example:
#   print bicgstab([[1.0, 2.0], [3.0, 4.0]], [5.0, 6.0])[0]
_bicgstabUnit(rows: List<List<double>>, values: List<double>) -> List<double>:
  grid = _squareCopy(rows)
  n = grid.length
  if values.length != n: throw "bicgstab needs one value per row"
  var x = _zeroDoubles(n)
  var residual = _copyDoubles(values)
  hat = _copyDoubles(residual)
  var rho = 1.0
  var alpha = 1.0
  var omega = 1.0
  var v = _zeroDoubles(n)
  var p = _zeroDoubles(n)
  var guard = 0
  while guard < n * 8 and dot(residual, residual) > 1.0e-20:
    nextRho = dot(hat, residual)
    if nextRho == 0.0: throw "bicgstab stagnated"
    pace = (nextRho / rho) * (alpha / omega)
    p = _axpy(residual, _axpy(p, v, 0.0 - omega), pace)
    v = matvec(grid, p)
    denom = dot(hat, v)
    if denom == 0.0: throw "bicgstab stagnated"
    alpha = nextRho / denom
    s = _axpy(residual, v, 0.0 - alpha)
    if dot(s, s) <= 1.0e-20: return _axpy(x, p, alpha)
    t = matvec(grid, s)
    tt = dot(t, t)
    if tt == 0.0: throw "bicgstab stagnated"
    omega = dot(t, s) / tt
    x = _axpy(_axpy(x, p, alpha), s, omega)
    residual = _axpy(s, t, 0.0 - omega)
    rho = nextRho
    guard = guard + 1
  return x

# A reduced fraction. The denominator is positive.
# Example:
#   print fraction(2, 4).numerator
value class Fraction:
  numerator: int required
  denominator: int required
  # Every integer has an exact fractional representation.
  implicit cast(value: int) -> Fraction = fraction(value, 1)
  # Conversion is exact: fractional values need an explicit rounding operation.
  explicit cast(value: Fraction) -> int:
    if value.denominator == 0:
      throw ConversionError("Fraction denominator is zero")
    if value.numerator % value.denominator != 0:
      throw ConversionError("Fraction is not a whole number")
    if value.denominator == -1 and value.numerator < 0 - _maxInt():
      throw ConversionError("Fraction is outside int range")
    return value.numerator ~/ value.denominator
  operator +(other: Fraction) -> Fraction:
    return _fractionAdd(this, other, false)
  operator -(other: Fraction) -> Fraction:
    return _fractionAdd(this, other, true)
  operator *(other: Fraction) -> Fraction:
    a = gcd(numerator, other.denominator)
    b = gcd(other.numerator, denominator)
    return fraction(_checkedMultiply(numerator ~/ a, other.numerator ~/ b),
    _checkedMultiply(denominator ~/ b, other.denominator ~/ a))
  operator /(other: Fraction) -> Fraction:
    if other.numerator == 0: throw "division by zero"
    a = gcd(numerator, other.numerator)
    b = gcd(denominator, other.denominator)
    return fraction(_checkedMultiply(numerator ~/ a, other.denominator ~/ b),
    _checkedMultiply(denominator ~/ b, other.numerator ~/ a))

fraction(numerator: int, denominator: int) -> Fraction:
  if denominator == 0: throw "fraction needs a non-zero denominator"
  if numerator == 0: return Fraction(numerator: 0, denominator: 1)
  if numerator == _minInt() and denominator == numerator:
    return Fraction(numerator: 1, denominator: 1)
  divisor = gcd(numerator, denominator)
  var top = numerator ~/ divisor
  var bottom = denominator ~/ divisor
  if bottom < 0:
    top = _checkedMultiply(top, -1)
    bottom = _checkedMultiply(bottom, -1)
  return Fraction(numerator: top, denominator: bottom)

extend int Factors:
  # This integer's factorial. Negative values throw.
  # Example:
  #   print 5.factorial()
  factorial() -> int = factorial(this)
  # True when this integer is prime.
  # Example:
  #   print 7.prime()
  prime() -> bool = isPrime(this)

:: complex

# A complex number. Addition, subtraction, multiplication, and division use
# the operators. Point from dart:math stays a 2D position, not a complex value.
# Example:
#   z = Complex(real: 3.0, imag: 4.0)
#   print z.abs()
value class Complex:
  real: double required
  imag: double required
  # Radius and angle, in radians, written as a complex number.
  # Example:
  #   print Complex.polar(1.0, 0.0).real
  static polar(radius: double, angle: double) -> Complex:
    return Complex(real: radius * math.cos(angle),
    imag: radius * math.sin(angle))
  # The distance from the origin.
  # Example:
  #   print z.abs()
  abs() -> double = hypot(real, imag)
  # The angle in radians, in the range (-pi, pi].
  # Example:
  #   print Complex(real: 0.0, imag: 1.0).argument()
  argument() -> double = math.atan2(imag, real)
  # The same real part and the negated imaginary part.
  # Example:
  #   print z.conjugate().imag
  conjugate() -> Complex = Complex(real: real, imag: 0.0 - imag)
  # This number multiplied by a real [factor].
  # Example:
  #   print z.scale(2.0).real
  scale(factor: double) -> Complex:
    return Complex(real: real * factor, imag: imag * factor)
  # 1 / this number.
  # Example:
  #   print Complex(real: 2.0, imag: 0.0).reciprocal().real
  reciprocal() -> Complex:
    return Complex(real: 1.0, imag: 0.0) / this
  # e raised to this number.
  # Example:
  #   print Complex(real: 0.0, imag: 0.0).exponential().real
  exponential() -> Complex:
    mag = math.exp(real)
    return Complex(real: mag * math.cos(imag), imag: mag * math.sin(imag))
  # Natural logarithm. The imaginary part is the argument.
  # Example:
  #   print Complex(real: 1.0, imag: 0.0).logarithm().real
  logarithm() -> Complex:
    if real == 0.0 and imag == 0.0: throw "logarithm of zero"
    mag = max(_abs(real), _abs(imag))
    return Complex(real: math.log(mag) + math.log(hypot(real / mag, imag / mag)), imag: argument())
  # Principal square root. The real part is non-negative.
  # Example:
  #   print Complex(real: 0.0 - 1.0, imag: 0.0).squareRoot().imag
  squareRoot() -> Complex:
    if real == 0.0 and imag == 0.0: return Complex(real: 0.0, imag: 0.0)
    mag = max(_abs(real), _abs(imag))
    root = math.sqrt(mag) * math.sqrt(hypot(real / mag, imag / mag))
    half = argument() / 2.0
    return Complex(real: root * math.cos(half), imag: root * math.sin(half))
  # This number raised to [exponent], through the principal logarithm.
  # Example:
  #   print Complex(real: 0.0, imag: 1.0).power(Complex(real: 2.0, imag: 0.0)).real
  power(exponent: Complex) -> Complex:
    if real == 0.0 and imag == 0.0:
      if exponent.real == 0.0 and exponent.imag == 0.0:
        return Complex(real: 1.0, imag: 0.0)
      if exponent.real > 0.0 and exponent.imag == 0.0:
        return Complex(real: 0.0, imag: 0.0)
      throw "power of zero is undefined"
    return (logarithm() * exponent).exponential()
  # Sine of this number.
  # Example:
  #   print Complex(real: 0.0, imag: 0.0).sine().real
  sine() -> Complex:
    rise = math.exp(imag)
    fall = math.exp(0.0 - imag)
    sh = (rise - fall) / 2.0
    ch = (rise + fall) / 2.0
    return Complex(real: math.sin(real) * ch, imag: math.cos(real) * sh)
  # Cosine of this number.
  # Example:
  #   print Complex(real: 0.0, imag: 0.0).cosine().real
  cosine() -> Complex:
    rise = math.exp(imag)
    fall = math.exp(0.0 - imag)
    sh = (rise - fall) / 2.0
    ch = (rise + fall) / 2.0
    return Complex(
        real: math.cos(real) * ch, imag: 0.0 - math.sin(real) * sh)
  operator +(other: Complex) -> Complex:
    return Complex(real: real + other.real, imag: imag + other.imag)
  operator -(other: Complex) -> Complex:
    return Complex(real: real - other.real, imag: imag - other.imag)
  operator *(other: Complex) -> Complex:
    nextReal = real * other.real - imag * other.imag
    nextImag = real * other.imag + imag * other.real
    return Complex(real: nextReal, imag: nextImag)
  operator /(other: Complex) -> Complex:
    scale = max(_abs(other.real), _abs(other.imag))
    if scale == 0.0: throw "division by zero"
    br = other.real / scale
    bi = other.imag / scale
    topScale = max(_abs(real), _abs(imag))
    if topScale == 0.0: return Complex(real: 0.0, imag: 0.0)
    ar = real / topScale
    ai = imag / topScale
    den = br * br + bi * bi
    nextReal = _scaleRatio((ar * br + ai * bi) / den, topScale, scale)
    nextImag = _scaleRatio((ai * br - ar * bi) / den, topScale, scale)
    return Complex(real: nextReal, imag: nextImag)

# Complex matrix product.
# Example:
#   print complexMatmul([[Complex(real: 2.0, imag: 0.0)]], [[Complex(real: 3.0, imag: 1.0)]])[0][0].real
complexMatmul(
    left: List<List<Complex>>,
    right: List<List<Complex>>) -> List<List<Complex>>:
  if left.isEmpty or right.isEmpty: throw "complexMatmul needs a matrix"
  width = right[0].length
  var made: List<List<Complex>> = []
  for row in left:
    if row.length != right.length: throw "complexMatmul needs compatible shapes"
    var line: List<Complex> = []
    var column = 0
    while column < width:
      var acc = Complex(real: 0.0, imag: 0.0)
      var k = 0
      while k < row.length:
        acc = acc + row[k] * right[k][column]
        k = k + 1
      line.add(acc)
      column = column + 1
    made.add(line)
  return made

# Solution of a complex square linear system.
# Example:
#   print complexSolve([[Complex(real: 2.0, imag: 0.0)]], [Complex(real: 4.0, imag: 2.0)])[0].real
complexSolve(
    rows: List<List<Complex>>, values: List<Complex>) -> List<Complex>:
  if values.length != rows.length: throw "complexSolve needs one value per row"
  return _csolve(rows, values)

:: vector

# A 2D vector. Point from dart:math remains available for positions.
# Example:
#   v = Vec2(x: 3.0, y: 4.0)
#   print v.length()
value class Vec2:
  x: double required
  y: double required
  # The Euclidean length.
  # Example:
  #   print v.length()
  length() -> double = hypot(x, y)
  # This vector divided by its length, or the zero vector.
  # Example:
  #   print v.normalized().length()
  normalized() -> Vec2:
    mag = max(_abs(x), _abs(y))
    if mag == 0.0: return Vec2(x: 0.0, y: 0.0)
    nx = x / mag
    ny = y / mag
    len = hypot(nx, ny)
    return Vec2(x: nx / len, y: ny / len)
  # This vector multiplied by a real [factor].
  # Example:
  #   print v.scale(2.0).x
  scale(factor: double) -> Vec2 = Vec2(x: x * factor, y: y * factor)
  # The dot product.
  # Example:
  #   print v.dot(v)
  dot(other: Vec2) -> double = x * other.x + y * other.y
  # The 2D cross magnitude, x * other.y - y * other.x.
  # Example:
  #   print Vec2(x: 1.0, y: 0.0).cross(Vec2(x: 0.0, y: 1.0))
  cross(other: Vec2) -> double = x * other.y - y * other.x
  # The distance to [other].
  # Example:
  #   print v.distance(Vec2(x: 0.0, y: 0.0))
  distance(other: Vec2) -> double = hypot(x - other.x, y - other.y)
  # The point [t] of the way toward [other].
  # Example:
  #   print v.lerpTo(Vec2(x: 0.0, y: 0.0), 0.5).x
  lerpTo(other: Vec2, t: double) -> Vec2:
    return Vec2(x: lerp(x, other.x, t), y: lerp(y, other.y, t))
  operator +(other: Vec2) -> Vec2 = Vec2(x: x + other.x, y: y + other.y)
  operator -(other: Vec2) -> Vec2 = Vec2(x: x - other.x, y: y - other.y)

# A 3D vector.
# Example:
#   v = Vec3(x: 1.0, y: 2.0, z: 2.0)
#   print v.length()
value class Vec3:
  x: double required
  y: double required
  z: double required
  # The Euclidean length.
  # Example:
  #   print v.length()
  length() -> double = hypot(hypot(x, y), z)
  # This vector divided by its length, or the zero vector.
  # Example:
  #   print v.normalized().x
  normalized() -> Vec3:
    mag = max(_abs(x), max(_abs(y), _abs(z)))
    if mag == 0.0: return Vec3(x: 0.0, y: 0.0, z: 0.0)
    nx = x / mag
    ny = y / mag
    nz = z / mag
    len = hypot(hypot(nx, ny), nz)
    return Vec3(x: nx / len, y: ny / len, z: nz / len)
  # This vector multiplied by a real [factor].
  # Example:
  #   print v.scale(2.0).z
  scale(factor: double) -> Vec3:
    return Vec3(x: x * factor, y: y * factor, z: z * factor)
  # The dot product.
  # Example:
  #   print v.dot(v)
  dot(other: Vec3) -> double = x * other.x + y * other.y + z * other.z
  # The cross product.
  # Example:
  #   print Vec3(x: 1.0, y: 0.0, z: 0.0).cross(Vec3(x: 0.0, y: 1.0, z: 0.0)).z
  cross(other: Vec3) -> Vec3:
    return Vec3(
        x: y * other.z - z * other.y,
        y: z * other.x - x * other.z,
        z: x * other.y - y * other.x)
  # The distance to [other].
  # Example:
  #   print v.distance(Vec3(x: 0.0, y: 0.0, z: 0.0))
  distance(other: Vec3) -> double:
    return hypot(hypot(x - other.x, y - other.y), z - other.z)
  operator +(other: Vec3) -> Vec3:
    return Vec3(x: x + other.x, y: y + other.y, z: z + other.z)
  operator -(other: Vec3) -> Vec3:
    return Vec3(x: x - other.x, y: y - other.y, z: z - other.z)

:: interval

# A closed span of real numbers. [low] is expected to be at or below [high].
# Example:
#   span = Interval(low: 0.0, high: 1.0)
#   print span.contains(0.5)
value class Interval:
  low: double required
  high: double required
  # True when the ends are in order.
  # Example:
  #   print span.valid()
  valid() -> bool = low <= high
  # high - low.
  # Example:
  #   print span.width()
  width() -> double = high - low
  # True when [value] is inside this span, including the ends.
  # Example:
  #   print span.contains(0.0)
  contains(value: double) -> bool:
    if value < low: return false
    return value <= high
  # True when the spans share a point.
  # Example:
  #   print span.overlaps(Interval(low: 1.0, high: 2.0))
  overlaps(other: Interval) -> bool:
    if other.high < low: return false
    return other.low <= high
  # [value] moved inside this span.
  # Example:
  #   print span.limit(2.0)
  limit(value: double) -> double = bounded(value, low, high)

# A closed span whose ends are [a] and [b], written in order.
# Example:
#   print interval(3.0, 1.0).low
interval(a: double, b: double) -> Interval:
  if a <= b: return Interval(low: a, high: b)
  return Interval(low: b, high: a)

:: interval::outward

# A new closed interval with outward binary64 rounding. This is not Interval:
# Interval stays an unordered-end span with no arithmetic. Endpoints must be
# finite and ordered. Zero steps out to the smallest normal, so a subnormal
# gap is still an enclosure. A subnormal input endpoint is rejected.
value class OutwardInterval:
  low: double required
  high: double required

# The point interval containing one finite binary64 value.
# Example:
#   print outwardPoint(1.0).low
outwardPoint(value: double) -> OutwardInterval:
  if not _finite(value): throw "outward interval needs finite endpoints"
  return OutwardInterval(low: value, high: value)

# Outward sum. The exact sum of the endpoint values lies inside the result.
# Example:
#   print outwardAdd(outwardPoint(1.0), outwardPoint(1.0)).high > 2.0
outwardAdd(left: OutwardInterval, right: OutwardInterval) -> OutwardInterval:
  _checkOutward(left)
  _checkOutward(right)
  return _outwardEnds(_nextDown(left.low + right.low), _nextUp(left.high + right.high))

# Outward difference, containing every exact left endpoint minus right endpoint.
outwardSubtract(left: OutwardInterval, right: OutwardInterval) -> OutwardInterval:
  _checkOutward(left)
  _checkOutward(right)
  return _outwardEnds(_nextDown(left.low - right.high), _nextUp(left.high - right.low))

# Outward product of every endpoint pair.
outwardMultiply(left: OutwardInterval, right: OutwardInterval) -> OutwardInterval:
  _checkOutward(left)
  _checkOutward(right)
  a = left.low * right.low
  b = left.low * right.high
  c = left.high * right.low
  d = left.high * right.high
  return _outwardEnds(_nextDown(_outwardMin4(a, b, c, d)), _nextUp(_outwardMax4(a, b, c, d)))

# Outward quotient. An interval containing zero cannot be a divisor.
outwardDivide(left: OutwardInterval, right: OutwardInterval) -> OutwardInterval:
  _checkOutward(left)
  _checkOutward(right)
  if right.low <= 0.0 and right.high >= 0.0: throw "outward division by an interval containing zero"
  a = left.low / right.low
  b = left.low / right.high
  c = left.high / right.low
  d = left.high / right.high
  return _outwardEnds(_nextDown(_outwardMin4(a, b, c, d)), _nextUp(_outwardMax4(a, b, c, d)))

_checkOutward(span: OutwardInterval):
  if not _finite(span.low) or not _finite(span.high) or span.low > span.high:
    throw "outward interval needs finite ordered endpoints"

_outwardEnds(low: double, high: double) -> OutwardInterval:
  if not _finite(low) or not _finite(high): throw "outward interval overflow"
  return OutwardInterval(low: low, high: high)

_outwardMin4(a: double, b: double, c: double, d: double) -> double:
  var best = a
  if b < best: best = b
  if c < best: best = c
  if d < best: best = d
  return best

_outwardMax4(a: double, b: double, c: double, d: double) -> double:
  var best = a
  if b > best: best = b
  if c > best: best = c
  if d > best: best = d
  return best

_nextDown(value: double) -> double:
  return 0.0 - _nextUp(0.0 - value)

_nextUp(value: double) -> double:
  if not _finite(value): throw "outward interval needs finite endpoints"
  if value == 0.0: return 2.2250738585072014e-308
  var negative = value < 0.0
  var magnitude = value
  if negative: magnitude = 0.0 - value
  if magnitude < 2.2250738585072014e-308: throw "outward interval endpoint is subnormal"
  var scaled = magnitude
  var exponent = 0
  var guard = 0
  while scaled >= 2.0 and guard < 2000:
    scaled = scaled / 2.0
    exponent += 1
    guard += 1
  while scaled < 1.0 and guard < 4000:
    scaled = scaled * 2.0
    exponent -= 1
    guard += 1
  var unit = 1.0
  var shift = exponent - 52
  if shift >= 0:
    var step = 0
    while step < shift:
      unit = unit * 2.0
      step += 1
  else:
    var step = 0
    while step < 0 - shift:
      unit = unit / 2.0
      step += 1
  if negative:
    var toward = magnitude - unit
    if scaled == 1.0: toward = magnitude - unit / 2.0
    if toward == magnitude: throw "outward interval step underflowed"
    return 0.0 - toward
  raised = magnitude + unit
  if raised == magnitude: throw "outward interval step underflowed"
  return raised

# Enclosure of finite real values, with possibly unbounded endpoints.
# Use realInterval() for checked construction. Every operation revalidates raw
# constructors. Basic operations round outward; this is distinct from Interval.
value class RealInterval:
  low: double required
  high: double required

  contains(value: double) -> bool:
    _checkRealInterval(this)
    return value.isFinite and value >= low and value <= high

  operator +(other: RealInterval) -> RealInterval:
    _checkRealInterval(this)
    _checkRealInterval(other)
    return realInterval(nextDown(low + other.low), nextUp(high + other.high))

  operator -(other: RealInterval) -> RealInterval:
    _checkRealInterval(this)
    _checkRealInterval(other)
    return realInterval(nextDown(low - other.high), nextUp(high - other.low))

  operator -() -> RealInterval:
    _checkRealInterval(this)
    return realInterval(-high, -low)

  operator *(other: RealInterval) -> RealInterval:
    _checkRealInterval(this)
    _checkRealInterval(other)
    if low == 0.0 and high == 0.0: return realInterval(0.0, 0.0)
    if other.low == 0.0 and other.high == 0.0: return realInterval(0.0, 0.0)
    products = [_intervalProduct(low, other.low), _intervalProduct(low, other.high), _intervalProduct(high, other.low), _intervalProduct(high, other.high)]
    var lower = products[0]
    var upper = products[0]
    for corner in products:
      if corner < lower: lower = corner
      if corner > upper: upper = corner
    return realInterval(nextDown(lower), nextUp(upper))

  operator /(other: RealInterval) -> RealInterval:
    _checkRealInterval(this)
    _checkRealInterval(other)
    if other.low <= 0.0 and other.high >= 0.0:
      throw "RealInterval division contains zero"
    var lower = nextDown(1.0 / other.high)
    var upper = nextUp(1.0 / other.low)
    if other.low > 0.0 and lower < 0.0: lower = 0.0
    if other.high < 0.0 and upper > 0.0: upper = 0.0
    return this * realInterval(lower, upper)

# Checked, ordered endpoints. Unlike interval(), does not reorder arguments.
# Infinity denotes an unbounded real endpoint, never a member of the interval.
# Example:
#   print (realInterval(0.1, 0.1) + realInterval(0.2, 0.2)).contains(0.3)
realInterval(low: double, high: double) -> RealInterval:
  output = RealInterval(low: low, high: high)
  _checkRealInterval(output)
  return output

_checkRealInterval(span: RealInterval):
  if span.low.isNaN or span.high.isNaN or span.low > span.high:
    throw "RealInterval needs ordered non-NaN endpoints"
  if span.low == 1.0 / 0.0 or span.high == -1.0 / 0.0:
    throw "RealInterval endpoints enclose no finite reals"

_intervalProduct(a: double, b: double) -> double:
  if a == 0.0 or b == 0.0: return 0.0
  return a * b

:: stats

# The sum of [values]. An empty list is 0.
# Example:
#   print sumOf([1.0, 2.0, 3.0])
sumOf(values: List<double>) -> double:
  var total = 0.0
  for value in values:
    total = total + value
  return total

# The product of [values]. An empty list is 1.
# Example:
#   print product([2.0, 3.0, 4.0])
product(values: List<double>) -> double:
  var total = 1.0
  for value in values:
    total = total * value
  return total

# The arithmetic mean. An empty list throws.
# Example:
#   print mean([1.0, 2.0, 3.0])
mean(values: List<double>) -> double:
  if values.isEmpty: throw "mean of an empty list"
  scaled: List<double> = []
  for value in values:
    scaled.add(value / (values.length to double))
  return kahanSum(scaled)

# The middle value. An even count uses the mean of the two middle values.
# Example:
#   print median([1.0, 3.0, 2.0])
median(values: List<double>) -> double:
  if values.isEmpty: throw "median of an empty list"
  ordered: List<double> = []
  for value in values:
    ordered.add(value)
  ordered.sort()
  mid = ordered.length ~/ 2
  if ordered.length % 2 == 1: return ordered[mid]
  return ordered[mid - 1] / 2.0 + ordered[mid] / 2.0

# The smallest value. An empty list throws.
# Example:
#   print minimum([3.0, 1.0, 2.0])
minimum(values: List<double>) -> double:
  if values.isEmpty: throw "minimum of an empty list"
  var best = values[0]
  for value in values:
    if value < best: best = value
  return best

# The largest value. An empty list throws.
# Example:
#   print maximum([3.0, 1.0, 2.0])
maximum(values: List<double>) -> double:
  if values.isEmpty: throw "maximum of an empty list"
  var best = values[0]
  for value in values:
    if value > best: best = value
  return best

# maximum(values) - minimum(values).
# Example:
#   print sampleRange([1.0, 4.0, 2.0])
sampleRange(values: List<double>) -> double:
  return maximum(values) - minimum(values)

# The sample variance, divided by n - 1. Fewer than two values throws.
# Example:
#   print variance([1.0, 2.0, 3.0])
variance(values: List<double>) -> double:
  if values.length < 2: throw "variance needs at least two values"
  center = mean(values)
  denominator = (values.length - 1) to double
  terms: List<double> = []
  for value in values:
    delta = value - center
    terms.add((delta / denominator) * delta)
  return kahanSum(terms)

# The population variance, divided by n. An empty list throws.
# Example:
#   print populationVariance([1.0, 2.0, 3.0])
populationVariance(values: List<double>) -> double:
  if values.isEmpty: throw "populationVariance of an empty list"
  center = mean(values)
  denominator = values.length to double
  terms: List<double> = []
  for value in values:
    delta = value - center
    terms.add((delta / denominator) * delta)
  return kahanSum(terms)

# The sample standard deviation.
# Example:
#   print stddev([1.0, 2.0, 3.0])
stddev(values: List<double>) -> double:
  if values.length < 2: throw "stddev needs at least two values"
  return _spread(values, (values.length - 1) to double)

# The population standard deviation.
# Example:
#   print populationStddev([1.0, 2.0, 3.0])
populationStddev(values: List<double>) -> double:
  if values.isEmpty: throw "populationStddev of an empty list"
  return _spread(values, values.length to double)

# The value at [percent] of the way through the sorted sample.
# [percent] runs from 0 through 100. Ties are interpolated.
# Example:
#   print percentile([1.0, 2.0, 3.0, 4.0], 50.0)
percentile(values: List<double>, percent: double) -> double:
  if values.isEmpty: throw "percentile of an empty list"
  if percent < 0.0 or percent > 100.0:
    throw "percent must be from 0 through 100"
  ordered: List<double> = []
  for value in values:
    ordered.add(value)
  ordered.sort()
  if ordered.length == 1: return ordered[0]
  place = percent / 100.0 * ((ordered.length - 1) to double)
  lo = place.floor
  hi = place.ceil
  if lo == hi: return ordered[lo]
  frac = place - (lo to double)
  return ordered[lo] * (1.0 - frac) + ordered[hi] * frac

# [percentile] with [q] running from 0 through 1.
# Example:
#   print quantile([1.0, 2.0, 3.0, 4.0], 0.5)
quantile(values: List<double>, q: double) -> double:
  if q < 0.0 or q > 1.0: throw "quantile must be from 0 through 1"
  return percentile(values, q * 100.0)

# The sample covariance of two lists of the same length.
# Example:
#   print covariance([1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
covariance(xs: List<double>, ys: List<double>) -> double:
  if xs.length != ys.length: throw "covariance needs lists of the same length"
  if xs.length < 2: throw "covariance needs at least two pairs"
  mx = mean(xs)
  my = mean(ys)
  var total = 0.0
  var i = 0
  while i < xs.length:
    total = total + (xs[i] - mx) * (ys[i] - my)
    i = i + 1
  return total / ((xs.length - 1) to double)

# The Pearson correlation, from -1 through 1.
# Example:
#   print correlation([1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
correlation(xs: List<double>, ys: List<double>) -> double:
  if xs.length != ys.length: throw "correlation needs matching lists"
  sx = stddev(xs)
  sy = stddev(ys)
  if sx == 0.0 or sy == 0.0: throw "correlation is undefined for a constant list"
  mx = mean(xs)
  my = mean(ys)
  terms: List<double> = []
  var i = 0
  while i < xs.length:
    terms.add(_differenceRatio(xs[i], mx, sx) * _differenceRatio(ys[i], my, sy) / ((xs.length - 1) to double))
    i = i + 1
  return bounded(kahanSum(terms), -1.0, 1.0)

# Each value rewritten as a population z-score.
# Example:
#   print zScores([1.0, 2.0, 3.0]).length
zScores(values: List<double>) -> List<double>:
  center = mean(values)
  spread = populationStddev(values)
  if spread == 0.0: throw "z-scores need a non-zero spread"
  made: List<double> = []
  for value in values:
    made.add((value - center) / spread)
  return made

# Softmax of [values], stable for large inputs. The results add up to 1.
# Example:
#   print softmax([0.0, 0.0]).length
softmax(values: List<double>) -> List<double>:
  if values.isEmpty: throw "softmax of an empty list"
  peak = maximum(values)
  weights: List<double> = []
  var total = 0.0
  for value in values:
    weight = math.exp(value - peak)
    weights.add(weight)
    total = total + weight
  made: List<double> = []
  for weight in weights:
    made.add(weight / total)
  return made

# A short description of a sample. [variance] is the sample variance, or 0
# when the sample has a single value.
# Example:
#   report = summarize([1.0, 2.0, 3.0])
#   print report.mean
value class Summary:
  count: int required
  total: double required
  mean: double required
  minimum: double required
  maximum: double required
  variance: double required
  # The square root of [variance].
  # Example:
  #   print report.stddev()
  stddev() -> double = math.sqrt(variance)

# Count, sum, mean, extremes, and sample variance of [values].
# Example:
#   print summarize([1.0, 2.0, 3.0]).count
summarize(values: List<double>) -> Summary:
  if values.isEmpty: throw "summarize of an empty list"
  center = mean(values)
  var spread = 0.0
  if values.length >= 2: spread = variance(values)
  return Summary(
      count: values.length,
      total: sumOf(values),
      mean: center,
      minimum: minimum(values),
      maximum: maximum(values),
      variance: spread)

# The geometric mean of positive numbers.
# Example:
#   print approximately(geometricMean([1.0, 4.0]), 2.0, 1.0e-9)
geometricMean(values: List<double>) -> double:
  if values.isEmpty: throw "geometricMean of an empty list"
  var total = 0.0
  for value in values:
    if value <= 0.0: throw "geometricMean needs positive values"
    total = total + math.log(value)
  return math.exp(total / (values.length to double))

# The harmonic mean. A zero value throws.
# Example:
#   print harmonicMean([1.0, 4.0])
harmonicMean(values: List<double>) -> double:
  if values.isEmpty: throw "harmonicMean of an empty list"
  var total = 0.0
  for value in values:
    if value == 0.0: throw "harmonicMean cannot include zero"
    total = total + 1.0 / value
  return (values.length to double) / total

# Running totals, one per input, in the same order.
# Example:
#   print cumsum([1.0, 2.0, 3.0])[2]
cumsum(values: List<double>) -> List<double>:
  made: List<double> = []
  var total = 0.0
  for value in values:
    total = total + value
    made.add(total)
  return made

# First differences. The result is one shorter than [values].
# Example:
#   print diff([1.0, 4.0, 6.0])[1]
diff(values: List<double>) -> List<double>:
  made: List<double> = []
  var i = 1
  while i < values.length:
    made.add(values[i] - values[i - 1])
    i = i + 1
  return made

# Sum that keeps the bits a naive total would drop.
# Example:
#   print kahanSum([1.0e16, 1.0, 1.0, 0.0 - 1.0e16])
kahanSum(values: List<double>) -> double:
  var sum = 0.0
  var compensation = 0.0
  for value in values:
    t = sum + value
    if not _finite(t):
      sum = t
      compensation = 0.0
    else:
      if _abs(sum) >= _abs(value): compensation = compensation + ((sum - t) + value)
      else: compensation = compensation + ((value - t) + sum)
      sum = t
  return sum + compensation

# Adjusted Fisher-Pearson sample skewness. A constant sample throws.
# Example:
#   print skewness([1.0, 2.0, 3.0, 4.0, 5.0])
skewness(values: List<double>) -> double:
  if values.length < 3: throw "skewness needs at least three values"
  center = mean(values)
  var m2 = 0.0
  var m3 = 0.0
  for value in values:
    delta = value - center
    m2 = m2 + delta * delta
    m3 = m3 + delta * delta * delta
  if m2 == 0.0: throw "skewness is undefined for a constant sample"
  n = values.length to double
  g1 = m3 / math.pow(m2, 1.5) * math.sqrt(n)
  return math.sqrt(n * (n - 1.0)) / (n - 2.0) * g1

# Sample excess kurtosis. A normal sample is near zero. Fewer than four throws.
# Example:
#   print kurtosis([1.0, 2.0, 3.0, 4.0, 5.0])
kurtosis(values: List<double>) -> double:
  if values.length < 4: throw "kurtosis needs at least four values"
  center = mean(values)
  var moment = 0.0
  for value in values:
    delta = value - center
    moment = moment + delta * delta * delta * delta
  spread = variance(values)
  if spread == 0.0: throw "kurtosis is undefined for a constant sample"
  n = values.length to double
  scale = n * (n + 1.0) / ((n - 1.0) * (n - 2.0) * (n - 3.0))
  correction = 3.0 * (n - 1.0) * (n - 1.0) / ((n - 2.0) * (n - 3.0))
  return scale * moment / (spread * spread) - correction

# The distance from the 25th percentile to the 75th.
# Example:
#   print iqr([1.0, 2.0, 3.0, 4.0])
iqr(values: List<double>) -> double:
  return percentile(values, 75.0) - percentile(values, 25.0)

# The most frequent value. Ties keep the smaller one. Equality is exact.
# Example:
#   print mode([1.0, 2.0, 2.0, 3.0])
mode(values: List<double>) -> double:
  if values.isEmpty: throw "mode of an empty list"
  var best = values[0]
  var bestCount = 0
  var i = 0
  while i < values.length:
    var count = 0
    var j = 0
    while j < values.length:
      if values[j] == values[i]: count = count + 1
      j = j + 1
    if count > bestCount or (count == bestCount and values[i] < best):
      best = values[i]
      bestCount = count
    i = i + 1
  return best

# y minus the fitted line at each x.
# Example:
#   print residuals([0.0, 1.0, 2.0], [1.0, 3.0, 5.0])[1]
residuals(xs: List<double>, ys: List<double>) -> List<double>:
  fit = lineFit(xs, ys)
  made: List<double> = []
  var i = 0
  while i < xs.length:
    made.add(ys[i] - (fit.slope * xs[i] + fit.intercept))
    i = i + 1
  return made

# Coefficient of determination of the least-squares line, from 0 through 1.
# Example:
#   print rSquared([0.0, 1.0, 2.0], [1.0, 3.0, 5.0])
rSquared(xs: List<double>, ys: List<double>) -> double:
  return _determination(ys, residuals(xs, ys))

# Observations minus the least-squares fit of [rows] * coef = [values].
# Example:
#   print fitResiduals([[1.0], [1.0]], [2.0, 2.0])[0]
fitResiduals(rows: List<List<double>>, values: List<double>) -> List<double>:
  coefs = leastSquares(rows, values)
  predicted = matvec(rows, coefs)
  made: List<double> = []
  var i = 0
  while i < values.length:
    made.add(values[i] - predicted[i])
    i = i + 1
  return made

# Coefficient of determination of a least-squares fit.
# Example:
#   print fitRSquared([[1.0, 0.0], [1.0, 1.0], [1.0, 2.0]], [1.0, 3.0, 5.0])
fitRSquared(rows: List<List<double>>, values: List<double>) -> double:
  return _determination(values, fitResiduals(rows, values))

# Sample covariance of the columns. Each inner list is one observation.
# Example:
#   print covarianceMatrix([[1.0, 1.0], [2.0, 2.0], [3.0, 3.0]])[0][1]
covarianceMatrix(observations: List<List<double>>) -> List<List<double>>:
  grid = _rectCopy(observations)
  if grid.length < 2: throw "covarianceMatrix needs at least two rows"
  width = grid[0].length
  centers: List<double> = []
  var column = 0
  while column < width:
    centers.add(mean(_column(grid, column)))
    column = column + 1
  scale = (grid.length - 1) to double
  made: List<List<double>> = []
  var row = 0
  while row < width:
    line: List<double> = []
    var col = 0
    while col < width:
      var total = 0.0
      var i = 0
      while i < grid.length:
        total = total + (grid[i][row] - centers[row]) * (grid[i][col] - centers[col])
        i = i + 1
      line.add(total / scale)
      col = col + 1
    made.add(line)
    row = row + 1
  return made

# A statistic and its upper-tail probability.
# Example:
#   print oneSampleT([1.0, 2.0, 3.0], 2.0).statistic
value class Inference:
  statistic: double
  probability: double

# Two-sided one-sample t test of the mean against [center].
# Example:
#   print oneSampleT([1.0, 2.0, 3.0], 2.0).probability
oneSampleT(values: List<double>, center: double) -> Inference:
  if values.length < 2: throw "oneSampleT needs at least two values"
  spread = stddev(values)
  delta = mean(values) - center
  if spread == 0.0:
    if delta == 0.0: return Inference(statistic: 0.0, probability: 1.0)
    throw "oneSampleT is undefined for a constant sample"
  stat = delta / (spread / math.sqrt(values.length to double))
  tail = 1.0 - studentCdf(_abs(stat), (values.length - 1) to double)
  return Inference(statistic: stat, probability: 2.0 * tail)

# Two-sided two-sample t test with a pooled variance.
# Example:
#   print twoSampleT([1.0, 2.0, 3.0], [1.0, 2.0, 3.0]).statistic
twoSampleT(left: List<double>, right: List<double>) -> Inference:
  if left.length < 2 or right.length < 2:
    throw "twoSampleT needs at least two values in each sample"
  n1 = left.length to double
  n2 = right.length to double
  pooled = ((n1 - 1.0) * variance(left) + (n2 - 1.0) * variance(right)) / (n1 + n2 - 2.0)
  if pooled == 0.0:
    if mean(left) == mean(right): return Inference(statistic: 0.0,
    probability: 1.0)
    throw "twoSampleT is undefined for constant samples"
  stat = (mean(left) - mean(right)) / math.sqrt(pooled * (1.0 / n1 + 1.0 / n2))
  tail = 1.0 - studentCdf(_abs(stat), n1 + n2 - 2.0)
  return Inference(statistic: stat, probability: 2.0 * tail)

# One-way analysis of variance. Each inner list is one group.
# Example:
#   print oneWayAnova([[1.0, 2.0], [1.0, 2.0]]).statistic
oneWayAnova(groups: List<List<double>>) -> Inference:
  if groups.length < 2: throw "oneWayAnova needs at least two groups"
  var count = 0
  var total = 0.0
  for group in groups:
    if group.isEmpty: throw "oneWayAnova rejects an empty group"
    count = count + group.length
    total = total + sumOf(group)
  if count <= groups.length: throw "oneWayAnova needs residual degrees of freedom"
  grand = total / (count to double)
  var between = 0.0
  var within = 0.0
  for group in groups:
    shift = mean(group) - grand
    between = between + (group.length to double) * shift * shift
    for value in group:
      gap = value - mean(group)
      within = within + gap * gap
  df1 = (groups.length - 1) to double
  df2 = (count - groups.length) to double
  if within == 0.0:
    if between == 0.0: return Inference(statistic: 0.0, probability: 1.0)
    return Inference(statistic: between / within, probability: 0.0)
  stat = (between / df1) / (within / df2)
  return Inference(statistic: stat, probability: 1.0 - fisherCdf(stat, df1,
  df2))

# Spearman rank correlation.
# Example:
#   print spearman([1.0, 2.0, 3.0], [3.0, 2.0, 1.0])
spearman(xs: List<double>, ys: List<double>) -> double:
  if xs.length != ys.length or xs.length < 2:
    throw "spearman needs matching lists of at least two pairs"
  return correlation(_ranks(xs), _ranks(ys))

# Kendall tau. Ties in either coordinate are ignored.
# Example:
#   print kendall([1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
kendall(xs: List<double>, ys: List<double>) -> double:
  if xs.length != ys.length or xs.length < 2:
    throw "kendall needs matching lists of at least two pairs"
  var agree = 0
  var differ = 0
  var i = 0
  while i < xs.length:
    var j = i + 1
    while j < xs.length:
      dx = xs[i] - xs[j]
      dy = ys[i] - ys[j]
      if _sameSign(dx, dy): agree = agree + 1
      if _differentSigns(dx, dy): differ = differ + 1
      j = j + 1
    i = i + 1
  pairs = agree + differ
  if pairs == 0: throw "kendall is undefined without comparable pairs"
  return ((agree - differ) to double) / (pairs to double)

# Kendall tau-b. Ties reduce the denominator.
# Example:
#   print kendallB([1.0, 2.0, 3.0], [3.0, 2.0, 1.0])
kendallB(xs: List<double>, ys: List<double>) -> double:
  if xs.length != ys.length or xs.length < 2:
    throw "kendallB needs matching lists of at least two pairs"
  var agree = 0
  var differ = 0
  var i = 0
  while i < xs.length:
    var j = i + 1
    while j < xs.length:
      dx = xs[i] - xs[j]
      dy = ys[i] - ys[j]
      if _sameSign(dx, dy): agree = agree + 1
      if _differentSigns(dx, dy): differ = differ + 1
      j = j + 1
    i = i + 1
  pairs = xs.length * (xs.length - 1) ~/ 2
  leftTies = _tiePairs(xs)
  rightTies = _tiePairs(ys)
  den = (pairs - leftTies) * (pairs - rightTies)
  if den <= 0: throw "kendallB is undefined for a constant sample"
  return ((agree - differ) to double) / math.sqrt(den to double)

# Chi-square goodness of fit. Expected counts are fully specified.
# Example:
#   print chiSquareGoodness([10.0, 10.0], [10.0, 10.0]).statistic
chiSquareGoodness(observed: List<double>, expected: List<double>) -> Inference:
  if observed.length != expected.length or observed.length < 2:
    throw "chiSquareGoodness needs at least two matching bins"
  var stat = 0.0
  var i = 0
  while i < observed.length:
    if expected[i] <= 0.0: throw "chiSquareGoodness needs positive expected counts"
    gap = observed[i] - expected[i]
    stat = stat + gap * gap / expected[i]
    i = i + 1
  df = (observed.length - 1) to double
  return Inference(statistic: stat, probability: 1.0 - chiSquareCdf(stat, df))

# One-sample Kolmogorov-Smirnov statistic and its asymptotic probability.
# Example:
#   print kolmogorovSmirnov([0.25, 0.75], (x: double) -> x).statistic
kolmogorovSmirnov(
    values: List<double>,
    cdf: (double) -> double) -> Inference:
  if values.length < 1: throw "kolmogorovSmirnov needs a sample"
  var ordered = _copyDoubles(values)
  var i = 1
  while i < ordered.length:
    var j = i
    while j > 0 and ordered[j] < ordered[j - 1]:
      saved = ordered[j - 1]
      ordered = _setAt(ordered, j - 1, ordered[j])
      ordered = _setAt(ordered, j, saved)
      j = j - 1
    i = i + 1
  var gap = 0.0
  i = 0
  while i < ordered.length:
    fitted = cdf(ordered[i])
    high = ((i + 1) to double) / (ordered.length to double) - fitted
    low = fitted - (i to double) / (ordered.length to double)
    if _abs(high) > gap: gap = _abs(high)
    if _abs(low) > gap: gap = _abs(low)
    i = i + 1
  root = math.sqrt(ordered.length to double)
  lam = (root + 0.12 + 0.11 / root) * gap
  if lam == 0.0: return Inference(statistic: gap, probability: 1.0)
  var probability = 0.0
  if lam < 1.18:
    var series = 0.0
    var k = 1
    while k <= 100:
      odd = (2 * k - 1) to double
      term = math.exp(0.0 - odd * odd * math.pi * math.pi / (8.0 * lam * lam))
      series = series + term
      if term < 1.0e-16 * series: k = 101
      else: k = k + 1
    probability = 1.0 - math.sqrt(2.0 * math.pi) / lam * series
  else:
    var series = 0.0
    var sign = 1.0
    var k = 1
    while k <= 100:
      term = math.exp(0.0 - 2.0 * (k to double) * (k to double) * lam * lam)
      series = series + sign * term
      sign = 0.0 - sign
      if term < 1.0e-16: k = 101
      else: k = k + 1
    probability = 2.0 * series
  return Inference(statistic: gap, probability: bounded(probability, 0.0, 1.0))


# Two-sided Mann-Whitney test. Ties score one half.
# Example:
#   print mannWhitney([1.0, 2.0, 3.0], [1.0, 2.0, 3.0]).probability
mannWhitney(left: List<double>, right: List<double>) -> Inference:
  if left.isEmpty or right.isEmpty: throw "mannWhitney needs two samples"
  var wins = 0.0
  for a in left:
    for b in right:
      if a > b: wins = wins + 1.0
      if a == b: wins = wins + 0.5
  n1 = left.length to double
  n2 = right.length to double
  center = n1 * n2 / 2.0
  combined = _copyDoubles(left)
  for value in right:
    combined.add(value)
  n = n1 + n2
  correction = _tieCubic(combined)
  spread2 = n1 * n2 / 12.0 * (n + 1.0 - correction / (n * (n - 1.0)))
  if wins == center or spread2 == 0.0: return Inference(statistic: wins,
  probability: 1.0)
  z = (wins - center) / math.sqrt(spread2)
  tail = 1.0 - normalCdf(_abs(z))
  return Inference(statistic: wins, probability: 2.0 * tail)

# Least-squares coefficients, standard errors, and two-sided t probabilities.
# Example:
#   print regression([[1.0, 0.0], [1.0, 1.0], [1.0, 2.0]], [1.0, 3.0, 5.0]).coefficients[1]
value class Regression:
  coefficients: List<double>
  errors: List<double>
  probabilities: List<double>

regression(rows: List<List<double>>, values: List<double>) -> Regression:
  solved = leastSquares(rows, values)
  fitted = matvec(rows, solved)
  var rss = 0.0
  var i = 0
  while i < values.length:
    gap = values[i] - fitted[i]
    rss = rss + gap * gap
    i = i + 1
  width = solved.length
  df = values.length - width
  if df <= 0: throw "regression needs residual degrees of freedom"
  if rss == 0.0:
    zeros = _zeroDoubles(width)
    var ones = _zeroDoubles(width)
    var i2 = 0
    while i2 < width:
      ones = _setAt(ones, i2, 1.0)
      i2 = i2 + 1
    return Regression(coefficients: solved, errors: zeros, probabilities: ones)
  sigma2 = rss / (df to double)
  gram = matmul(transpose(rows), rows)
  cov = inverse(gram)
  errors: List<double> = []
  probabilities: List<double> = []
  i = 0
  while i < width:
    se = math.sqrt(sigma2 * cov[i][i])
    errors.add(se)
    if se == 0.0: probabilities.add(1.0)
    else:
      tail = 1.0 - studentCdf(_abs(solved[i] / se), df to double)
      probabilities.add(2.0 * tail)
    i = i + 1
  return Regression(coefficients: solved, errors: errors,
  probabilities: probabilities)

extend List<double> Samples:
  # The sum of these numbers.
  # Example:
  #   print numbers.sumOf()
  sumOf() -> double = sumOf(this)
  # The arithmetic mean.
  # Example:
  #   print numbers.mean()
  mean() -> double = mean(this)
  # The middle value.
  # Example:
  #   print numbers.median()
  median() -> double = median(this)
  # The sample standard deviation.
  # Example:
  #   print numbers.stddev()
  stddev() -> double = stddev(this)
  # The smallest value.
  # Example:
  #   print numbers.minimum()
  minimum() -> double = minimum(this)
  # The largest value.
  # Example:
  #   print numbers.maximum()
  maximum() -> double = maximum(this)

# Arithmetic mean with nonnegative reliability weights. An empty list, a
# negative weight, or a zero total weight throws. The result is sum(w*x)/sum(w).
# Example:
#   print weightedMean([1.0, 3.0], [1.0, 1.0])
weightedMean(values: List<double>, weights: List<double>) -> double:
  if values.isEmpty or values.length != weights.length: throw "weightedMean needs values and matching weights"
  var weightSum = 0.0
  var total = 0.0
  var index = 0
  while index < values.length:
    weight = weights[index]
    value = values[index]
    if not _finite(weight) or not _finite(value) or weight < 0.0: throw "weight must be nonnegative and finite"
    weightSum = weightSum + weight
    total = total + weight * value
    index += 1
  if weightSum == 0.0: throw "weights must have a positive sum"
  return total / weightSum

# Population variance for the same reliability weights: sum(w*(x-mean)^2)/sum(w).
# This is not the Bessel-corrected sample variance.
weightedVariance(values: List<double>, weights: List<double>) -> double:
  center = weightedMean(values, weights)
  var weightSum = 0.0
  var total = 0.0
  var index = 0
  while index < values.length:
    gap = values[index] - center
    weightSum = weightSum + weights[index]
    total = total + weights[index] * gap * gap
    index += 1
  return total / weightSum

# Welford moments. count, mean, and the sum of squared deviations are updated
# in place. The sample variance divides by count-1 and needs two samples.
class StreamMoments:
  var count: int = 0
  var mean: double = 0.0
  var second: double = 0.0

streamMoments() -> StreamMoments:
  return StreamMoments()

streamAdd(moments: StreamMoments, value: double) -> StreamMoments:
  if not _finite(value): throw "stream sample must be finite"
  moments.count = moments.count + 1
  delta = value - moments.mean
  moments.mean = moments.mean + delta / (moments.count to double)
  after = value - moments.mean
  moments.second = moments.second + delta * after
  return moments

streamMean(moments: StreamMoments) -> double:
  if moments.count < 1: throw "stream mean needs a sample"
  return moments.mean

streamSampleVariance(moments: StreamMoments) -> double:
  if moments.count < 2: throw "stream variance needs two samples"
  return moments.second / ((moments.count - 1) to double)

# Percentile bootstrap of the sample mean. The generator is minstd:
# state = seed * 48271 mod 2147483647, then index = state mod n.
# [seed] is the first state and must be from 1 through 2147483646.
# [level] is the nominal central probability, strictly between 0 and 1.
# Ranks are floor((replicates-1)*(1-level)/2) and
# floor((replicates-1)*(1+level)/2) of the sorted resample means.
# This is a reproducible percentile interval. It does not certify that the
# false-alarm rate equals 1-level.
value class BootstrapInterval:
  low: double required
  high: double required
  seed: int required
  replicates: int required
  level: double required

bootstrapMean(values: List<double>, replicates: int, seed: int, level: double) -> BootstrapInterval:
  if values.isEmpty or values.length > 10000: throw "bootstrap needs from 1 through 10000 values"
  if replicates < 1 or replicates > 10000: throw "bootstrap replicates must be from 1 through 10000"
  if seed < 1 or seed > 2147483646: throw "bootstrap seed must be from 1 through 2147483646"
  if not (level > 0.0 and level < 1.0): throw "bootstrap level must be strictly between 0 and 1"
  for value in values:
    if not _finite(value): throw "bootstrap sample must be finite"
  means: List<double> = []
  var generator = seed
  var copy = 0
  while copy < replicates:
    var total = 0.0
    var draw = 0
    while draw < values.length:
      generator = (generator * 48271) % 2147483647
      total = total + values[generator % values.length]
      draw += 1
    means.add(total / (values.length to double))
    copy += 1
  means.sort()
  span = (replicates - 1) to double
  lowIndex = (span * (1.0 - level) / 2.0).floor
  highIndex = (span * (1.0 + level) / 2.0).floor
  return BootstrapInterval(low: means[lowIndex], high: means[highIndex], seed: seed, replicates: replicates, level: level)

:: distribution

# The error function, from the regularized incomplete gamma function.
# Example:
#   print approximately(erf(0.0), 0.0, 1.0e-6)
erf(x: double) -> double:
  if x < 0.0: return 0.0 - erf(0.0 - x)
  if x == 0.0: return x
  if x >= 6.0: return 1.0
  if x * x < 1.5: return _gammaSeries(0.5, x * x)
  return 1.0 - _gammaFraction(0.5, x * x)

# Complementary error function, using the upper gamma tail directly.
# Example:
#   print approximately(erfc(0.0), 1.0, 1.0e-6)
erfc(x: double) -> double:
  if x < 0.0: return 2.0 - erfc(0.0 - x)
  if x == 0.0: return 1.0
  if x > 27.3: return 0.0
  if x * x < 1.5: return 1.0 - _gammaSeries(0.5, x * x)
  return _gammaFraction(0.5, x * x)

# Normal density. [center] defaults to 0 and [sigma] defaults to 1.
# Example:
#   print normalPdf(0.0) > 0.0
normalPdf(x: double, center: double = 0.0, sigma: double = 1.0) -> double:
  if sigma <= 0.0: throw "sigma must be positive"
  z = _differenceRatio(x, center, sigma)
  return exp(0.0 - 0.5 * z * z) / sqrt(2.0 * pi) / sigma

# Normal cumulative probability, from the error function.
# Example:
#   print approximately(normalCdf(0.0), 0.5, 1.0e-6)
normalCdf(x: double, center: double = 0.0, sigma: double = 1.0) -> double:
  if sigma <= 0.0: throw "sigma must be positive"
  z = _differenceRatio(x, center, sigma)
  return 0.5 * erfc(0.0 - z / sqrt(2.0))

# Natural log of the absolute gamma function, using Lanczos.
# Undefined at non-positive integers.
# Example:
#   print approximately(logGamma(1.0), 0.0, 1.0e-6)
logGamma(x: double) -> double:
  if x == 1.0 or x == 2.0: return 0.0
  whole = x.floor to double
  if x <= 0.0 and x == whole:
    throw "logGamma is undefined at a non-positive integer"
  if _abs(x) < 1.0e-8: return -math.log(_abs(x)) - 0.5772156649015329 * x
  if x < 0.5:
    return math.log(math.pi) - math.log(_abs(math.sin(math.pi * x))) - logGamma(1.0 - x)
  z = x - 1.0
  var sum = 0.99999999999980993
  sum = sum + 676.5203681218851 / (z + 1.0)
  sum = sum - 1259.1392167224028 / (z + 2.0)
  sum = sum + 771.32342877765313 / (z + 3.0)
  sum = sum - 176.61502916214059 / (z + 4.0)
  sum = sum + 12.507343278686905 / (z + 5.0)
  sum = sum - 0.13857109526572012 / (z + 6.0)
  sum = sum + 9.9843695780195716e-6 / (z + 7.0)
  sum = sum + 1.5056327351493116e-7 / (z + 8.0)
  t = z + 7.5
  return 0.5 * math.log(2.0 * math.pi) + (z + 0.5) * math.log(t) - t + math.log(sum)

# The gamma function. gamma(n) is (n - 1)! for a positive integer n.
# Example:
#   print approximately(gamma(5.0), 24.0, 1.0e-6)
gamma(x: double) -> double:
  if x <= 0.0 and x % 1.0 == 0.0: throw "gamma is undefined at a non-positive integer"
  magnitude = math.exp(logGamma(x))
  if x < 0.0 and math.sin(math.pi * x) < 0.0: return 0.0 - magnitude
  return magnitude

# Binomial probability of [k] successes in [n] trials of chance [p].
# Example:
#   print binomialPmf(1, 1, 1.0)
binomialPmf(k: int, n: int, p: double) -> double:
  if k < 0 or n < 0 or k > n: return 0.0
  if p < 0.0 or p > 1.0: throw "probability must be from 0 through 1"
  if p == 0.0:
    if k == 0: return 1.0
    return 0.0
  if p == 1.0:
    if k == n: return 1.0
    return 0.0
  logged = _logChoose(n, k) + (k to double) * math.log(p) + ((n - k) to double) * log1p(0.0 - p)
  return math.exp(logged)

# Poisson probability of [k] events when the mean count is [lambda].
# Example:
#   print poissonPmf(0, 0.0)
poissonPmf(k: int, lambda: double) -> double:
  if k < 0: return 0.0
  if lambda < 0.0: throw "lambda cannot be negative"
  if lambda == 0.0:
    if k == 0: return 1.0
    return 0.0
  return math.exp(0.0 - lambda + (k to double) * math.log(lambda) - logGamma((k to double) + 1.0))

# Natural log of the normal density. Finite for every finite z, including
# tails where normalPdf underflows to 0. At those tails the density contract
# remains 0, and this log contract remains the exact log formula in binary64.
# Example:
#   print normalLogPdf(0.0)
normalLogPdf(x: double, center: double = 0.0, sigma: double = 1.0) -> double:
  if sigma <= 0.0: throw "sigma must be positive"
  z = _differenceRatio(x, center, sigma)
  return 0.0 - 0.5 * math.log(2.0 * math.pi) - math.log(sigma) - 0.5 * z * z

# Natural log of the Poisson probability. A negative count is -infinity, matching
# poissonPmf returning 0. lambda 0 is 0 at k 0 and -infinity otherwise.
# The log stays finite when the probability itself underflows.
poissonLogPmf(k: int, lambda: double) -> double:
  if lambda < 0.0: throw "lambda cannot be negative"
  if k < 0: return 0.0 - 1.0 / 0.0
  if lambda == 0.0:
    if k == 0: return 0.0
    return 0.0 - 1.0 / 0.0
  return 0.0 - lambda + (k to double) * math.log(lambda) - logGamma((k to double) + 1.0)

# Natural log of the binomial probability. p of 0 or 1 uses the same 0 and 1
# cases as binomialPmf, without calling ln(0).
binomialLogPmf(k: int, n: int, p: double) -> double:
  if k < 0 or n < 0 or k > n: return 0.0 - 1.0 / 0.0
  if p < 0.0 or p > 1.0: throw "probability must be from 0 through 1"
  if p == 0.0:
    if k == 0: return 0.0
    return 0.0 - 1.0 / 0.0
  if p == 1.0:
    if k == n: return 0.0
    return 0.0 - 1.0 / 0.0
  return _logChoose(n, k) + (k to double) * math.log(p) + ((n - k) to double) * log1p(0.0 - p)

# Beta function.
# Example:
#   print beta(1.0, 1.0)
beta(a: double, b: double) -> double:
  if a <= 0.0 or b <= 0.0: throw "beta needs positive arguments"
  return math.exp(logGamma(a) + logGamma(b) - logGamma(a + b))

# Regularized lower incomplete gamma P(s, x).
# Example:
#   print lowerGamma(1.0, 0.0)
lowerGamma(s: double, x: double) -> double:
  if s <= 0.0: throw "lowerGamma needs a positive shape"
  if x < 0.0: throw "lowerGamma needs a non-negative x"
  if x == 0.0: return 0.0
  if x < s + 1.0: return _gammaSeries(s, x)
  return 1.0 - _gammaFraction(s, x)

# Regularized incomplete beta I_x(a, b).
# Example:
#   print incompleteBeta(1.0, 1.0, 0.5)
incompleteBeta(a: double, b: double, x: double) -> double:
  if a <= 0.0 or b <= 0.0: throw "incompleteBeta needs positive arguments"
  if x < 0.0 or x > 1.0: throw "incompleteBeta needs x from 0 through 1"
  if x == 0.0 or x == 1.0: return x
  var logBt = logGamma(a + b) - logGamma(a) - logGamma(b)
  logBt = logBt + a * math.log(x) + b * math.log(1.0 - x)
  bt = math.exp(logBt)
  if x < (a + 1.0) / (a + b + 2.0): return bt * _betaFraction(a, b, x) / a
  return 1.0 - bt * _betaFraction(b, a, 1.0 - x) / b

# Inverse of the standard normal cdf, then shifted by [center] and [sigma].
# Example:
#   print normalQuantile(0.5)
normalQuantile(
    p: double,
    center: double = 0.0,
    sigma: double = 1.0) -> double:
  if p <= 0.0 or p >= 1.0: throw "probability must sit strictly between 0 and 1"
  if sigma <= 0.0: throw "sigma must be positive"
  return center + sigma * _normalTail(p)

# Sum of the binomial masses from 0 through [k].
# Example:
#   print binomialCdf(1, 2, 0.5)
binomialCdf(k: int, n: int, p: double) -> double:
  if n < 0 or k < 0: return 0.0
  if p < 0.0 or p > 1.0: throw "probability must be from 0 through 1"
  if k >= n or p == 0.0: return 1.0
  if p == 1.0: return 0.0
  return incompleteBeta((n - k) to double, (k to double) + 1.0, 1.0 - p)

# Sum of the Poisson masses from 0 through [k].
# Example:
#   print poissonCdf(0, 0.0)
poissonCdf(k: int, lambda: double) -> double:
  if k < 0: return 0.0
  if lambda < 0.0: throw "lambda cannot be negative"
  if lambda == 0.0: return 1.0
  shape = (k to double) + 1.0
  if lambda < shape + 1.0: return 1.0 - _gammaSeries(shape, lambda)
  return _gammaFraction(shape, lambda)

# Density of Student's t with [df] degrees of freedom.
# Example:
#   print studentPdf(0.0, 1.0) > 0.0
studentPdf(t: double, df: double) -> double:
  if df <= 0.0: throw "degrees must be positive"
  half = (df + 1.0) / 2.0
  var logged = logGamma(half) - logGamma(df / 2.0)
  logged = logged - 0.5 * math.log(df * math.pi)
  logged = logged - half * math.log(1.0 + t * t / df)
  return math.exp(logged)

# Cumulative probability of Student's t.
# Example:
#   print studentCdf(0.0, 5.0)
studentCdf(t: double, df: double) -> double:
  if df <= 0.0: throw "degrees must be positive"
  x = df / (df + t * t)
  tail = 0.5 * incompleteBeta(df / 2.0, 0.5, x)
  if t >= 0.0: return 1.0 - tail
  return tail

# The t value whose cumulative probability is [p].
# Example:
#   print studentQuantile(0.5, 5.0)
studentQuantile(p: double, df: double) -> double:
  if df <= 0.0: throw "degrees must be positive"
  if p == 0.5: return 0.0
  return _bisectIncreasing(
      (t: double) -> studentCdf(t, df), p, 0.0 - 8.0, 8.0)

# Density of the chi-square distribution.
# Example:
#   print chiSquarePdf(2.0, 2.0)
chiSquarePdf(x: double, df: double) -> double:
  if df <= 0.0: throw "degrees must be positive"
  if x < 0.0: throw "chiSquarePdf needs a non-negative x"
  if x == 0.0:
    if df < 2.0: throw "chiSquarePdf is infinite at zero"
    if df > 2.0: return 0.0
  half = df / 2.0
  var logged = 0.0 - half * math.log(2.0) - logGamma(half)
  if x > 0.0: logged = logged + (half - 1.0) * math.log(x)
  logged = logged - x / 2.0
  return math.exp(logged)

# Cumulative probability of chi-square.
# Example:
#   print chiSquareCdf(0.0, 2.0)
chiSquareCdf(x: double, df: double) -> double:
  if df <= 0.0: throw "degrees must be positive"
  if x < 0.0: return 0.0
  return lowerGamma(df / 2.0, x / 2.0)

# The chi-square value whose cumulative probability is [p].
# Example:
#   print chiSquareQuantile(0.5, 2.0)
chiSquareQuantile(p: double, df: double) -> double:
  if df <= 0.0: throw "degrees must be positive"
  return _bisectIncreasing(
      (x: double) -> chiSquareCdf(x, df), p, 0.0, df)

# Density of the Fisher-Snedecor F distribution.
# Example:
#   print fisherPdf(1.0, 2.0, 2.0) > 0.0
fisherPdf(x: double, d1: double, d2: double) -> double:
  if d1 <= 0.0 or d2 <= 0.0: throw "degrees must be positive"
  if x < 0.0: throw "fisherPdf needs a non-negative x"
  if x == 0.0:
    if d1 < 2.0: throw "fisherPdf is infinite at zero"
    if d1 > 2.0: return 0.0
  half1 = d1 / 2.0
  half2 = d2 / 2.0
  var logged = logGamma(half1 + half2) - logGamma(half1) - logGamma(half2)
  logged = logged + half1 * math.log(d1 / d2)
  if x > 0.0: logged = logged + (half1 - 1.0) * math.log(x)
  logged = logged - (half1 + half2) * math.log(1.0 + d1 * x / d2)
  return math.exp(logged)

# Cumulative probability of F.
# Example:
#   print fisherCdf(1.0, 1.0, 1.0)
fisherCdf(x: double, d1: double, d2: double) -> double:
  if d1 <= 0.0 or d2 <= 0.0: throw "degrees must be positive"
  if x < 0.0: return 0.0
  if x == 0.0: return 0.0
  ratio = d2 / d1
  if x < ratio:
    z = _scaleRatio(x, d1, d2)
    return incompleteBeta(d1 / 2.0, d2 / 2.0, z / (1.0 + z))
  return incompleteBeta(d1 / 2.0, d2 / 2.0, 1.0 / (1.0 + ratio / x))

# The F value whose cumulative probability is [p].
# Example:
#   print fisherQuantile(0.5, 1.0, 1.0)
fisherQuantile(p: double, d1: double, d2: double) -> double:
  if d1 <= 0.0 or d2 <= 0.0: throw "degrees must be positive"
  return _bisectIncreasing((x: double) -> fisherCdf(x, d1, d2), p, 0.0, 1.0)

# One normal draw. [random] supplies the two uniform values.
# Example:
#   print normalSample(Random(1))
normalSample(
    random: Random,
    center: double = 0.0,
    sigma: double = 1.0) -> double:
  if sigma <= 0.0: throw "sigma must be positive"
  var u = random.nextDouble()
  var guard = 0
  while u == 0.0 and guard < 8:
    u = random.nextDouble()
    guard = guard + 1
  if u == 0.0: u = 1.0e-16
  angle = random.nextDouble()
  z = math.sqrt(0.0 - 2.0 * math.log(u)) * math.cos(2.0 * math.pi * angle)
  return center + sigma * z

# [n] Bernoulli trials of chance [p].
# Example:
#   print binomialSample(Random(1), 0, 0.5)
binomialSample(random: Random, n: int, p: double) -> int:
  if n < 0: throw "binomialSample needs a non-negative count"
  if p < 0.0 or p > 1.0: throw "probability must be from 0 through 1"
  var hits = 0
  var i = 0
  while i < n:
    if random.nextDouble() < p: hits = hits + 1
    i = i + 1
  return hits

# Poisson draw: Knuth for small means, transformed rejection for larger means.
# Example:
#   print poissonSample(Random(1), 0.0)
poissonSample(random: Random, lambda: double) -> int:
  if not _finite(lambda) or lambda < 0.0: throw "lambda must be finite and non-negative"
  if lambda > 1.0e8: throw "poissonSample mean exceeds the numerical accuracy limit"
  if lambda == 0.0: return 0
  if lambda < 30.0:
    limit = math.exp(0.0 - lambda)
    var mass = 1.0
    var count = 0
    while mass > limit:
      mass = mass * random.nextDouble()
      count = count + 1
    return count - 1
  root = math.sqrt(lambda)
  b = 0.931 + 2.53 * root
  a = -0.059 + 0.02483 * b
  invAlpha = 1.1239 + 1.1328 / (b - 3.4)
  vr = 0.9277 - 3.6224 / (b - 2.0)
  var guard = 0
  while guard < 10000:
    u = random.nextDouble() - 0.5
    v = random.nextDouble()
    us = 0.5 - _abs(u)
    if us > 0.0:
      k = ((2.0 * a / us + b) * u + lambda + 0.43).floor
      if k >= 0:
        if us >= 0.07 and v <= vr: return k
        if us >= 0.013 or v <= us:
          logged = math.log(v * invAlpha / (a / (us * us) + b))
          if logged <= -lambda + (k to double) * math.log(lambda) - logGamma((k to double) + 1.0): return k
    guard = guard + 1
  throw "poissonSample did not converge"

# Exponential density with rate [rate].
# Example:
#   print exponentialPdf(0.0, 1.0)
exponentialPdf(x: double, rate: double) -> double:
  if rate <= 0.0: throw "rate must be positive"
  if x < 0.0: return 0.0
  return rate * math.exp(0.0 - rate * x)

# Exponential cumulative probability.
# Example:
#   print exponentialCdf(1.0, 1.0)
exponentialCdf(x: double, rate: double) -> double:
  if rate <= 0.0: throw "rate must be positive"
  if x < 0.0: return 0.0
  return 0.0 - expm1(0.0 - rate * x)

# Exponential quantile.
# Example:
#   print exponentialQuantile(0.5, 1.0)
exponentialQuantile(p: double, rate: double) -> double:
  if rate <= 0.0: throw "rate must be positive"
  if p <= 0.0 or p >= 1.0: throw "probability must sit strictly between 0 and 1"
  return (0.0 - log1p(0.0 - p)) / rate

# One exponential draw.
# Example:
#   print exponentialSample(Random(1), 1.0) >= 0.0
exponentialSample(random: Random, rate: double) -> double:
  if rate <= 0.0: throw "rate must be positive"
  var u = random.nextDouble()
  if u == 0.0: u = 1.0e-16
  return (0.0 - math.log(u)) / rate

# Weibull density. [shape] and [scale] are positive.
# Example:
#   print weibullPdf(1.0, 1.0, 1.0)
weibullPdf(x: double, shape: double, scale: double) -> double:
  if shape <= 0.0 or scale <= 0.0: throw "shape and scale must be positive"
  if x < 0.0: return 0.0
  if x == 0.0 and shape < 1.0: throw "weibullPdf is infinite at zero"
  ratio = x / scale
  rise = math.pow(ratio, shape - 1.0) to double
  fall = math.pow(ratio, shape) to double
  return shape / scale * rise * math.exp(0.0 - fall)

# Weibull cumulative probability.
# Example:
#   print weibullCdf(1.0, 1.0, 1.0)
weibullCdf(x: double, shape: double, scale: double) -> double:
  if shape <= 0.0 or scale <= 0.0: throw "shape and scale must be positive"
  if x < 0.0: return 0.0
  power = math.pow(x / scale, shape) to double
  return 0.0 - expm1(0.0 - power)

# Weibull quantile.
# Example:
#   print weibullQuantile(1.0 - 1.0 / e, 1.0, 1.0)
weibullQuantile(p: double, shape: double, scale: double) -> double:
  if shape <= 0.0 or scale <= 0.0: throw "shape and scale must be positive"
  if p <= 0.0 or p >= 1.0: throw "probability must sit strictly between 0 and 1"
  power = math.pow(0.0 - log1p(0.0 - p), 1.0 / shape) to double
  return scale * power

# One Weibull draw.
# Example:
#   print weibullSample(Random(1), 1.0, 1.0) >= 0.0
weibullSample(random: Random, shape: double, scale: double) -> double:
  var u = random.nextDouble()
  if u == 0.0: u = 1.0e-16
  return weibullQuantile(u, shape, scale)

# Geometric probability of [k] failures before the first success.
# Example:
#   print geometricPmf(0, 0.5)
geometricPmf(k: int, chance: double) -> double:
  if chance <= 0.0 or chance > 1.0: throw "probability must be from 0 through 1"
  if k < 0: return 0.0
  power = math.pow(1.0 - chance, k to double) to double
  return power * chance

# Geometric cumulative probability.
# Example:
#   print geometricCdf(1, 0.5)
geometricCdf(k: int, chance: double) -> double:
  if chance <= 0.0 or chance > 1.0: throw "probability must be from 0 through 1"
  if k < 0: return 0.0
  power = math.pow(1.0 - chance, (k + 1) to double) to double
  return 1.0 - power

# Smallest geometric count whose cumulative probability reaches [p].
# Example:
#   print geometricQuantile(0.5, 0.5)
geometricQuantile(p: double, chance: double) -> int:
  if chance <= 0.0 or chance > 1.0: throw "probability must be from 0 through 1"
  if p <= 0.0 or p >= 1.0: throw "probability must sit strictly between 0 and 1"
  if chance == 1.0: return 0
  raw = log1p(0.0 - p) / log1p(0.0 - chance)
  var whole = raw.floor
  if (whole to double) < raw: whole = whole + 1
  if whole > 0: whole = whole - 1
  return whole

# One geometric draw.
# Example:
#   print geometricSample(Random(1), 1.0)
geometricSample(random: Random, chance: double) -> int:
  var u = random.nextDouble()
  if u == 0.0: u = 1.0e-16
  return geometricQuantile(u, chance)

# Hypergeometric probability. [population] items, [marked] of them special,
# [draws] taken, and [k] special items observed.
# Example:
#   print hypergeometricPmf(2, 5, 3, 2)
hypergeometricPmf(k: int, population: int, marked: int, draws: int) -> double:
  if population < 0 or marked < 0 or draws < 0 or marked > population or draws > population:
    throw "hypergeometric needs a feasible population"
  if k < 0 or k > marked or k > draws: return 0.0
  if draws - k > population - marked: return 0.0
  logged = _logChoose(marked, k) + _logChoose(population - marked, draws - k) - _logChoose(population, draws)
  return math.exp(logged)

# Hypergeometric cumulative probability.
# Example:
#   print hypergeometricCdf(0, 5, 3, 2)
hypergeometricCdf(k: int, population: int, marked: int, draws: int) -> double:
  if k < 0: return 0.0
  var total = 0.0
  var i = 0
  while i <= k:
    total = total + hypergeometricPmf(i, population, marked, draws)
    i = i + 1
  return total

# Gamma draw with [shape] and [scale]. The mean is shape times scale.
# Example:
#   print gammaSample(Random(1), 1.0, 1.0) >= 0.0
gammaSample(random: Random, shape: double, scale: double) -> double:
  if shape <= 0.0 or scale <= 0.0: throw "shape and scale must be positive"
  if shape < 1.0:
    unit = gammaSample(random, shape + 1.0, 1.0)
    var u = random.nextDouble()
    if u == 0.0: u = 1.0e-16
    power = math.pow(u, 1.0 / shape) to double
    return scale * unit * power
  return scale * _gammaMarsaglia(random, shape)

# Beta draw.
# Example:
#   print betaSample(Random(1), 1.0, 1.0)
betaSample(random: Random, a: double, b: double) -> double:
  if a <= 0.0 or b <= 0.0: throw "beta needs positive arguments"
  left = gammaSample(random, a, 1.0)
  right = gammaSample(random, b, 1.0)
  if left + right == 0.0: throw "betaSample underflow for these shapes"
  return left / (left + right)

# Chi-square draw with [df] degrees of freedom.
# Example:
#   print chiSquareSample(Random(1), 2.0) >= 0.0
chiSquareSample(random: Random, df: double) -> double:
  if df <= 0.0: throw "degrees must be positive"
  return gammaSample(random, df / 2.0, 2.0)

# Student t draw with [df] degrees of freedom.
# Example:
#   print studentSample(Random(1), 5.0)
studentSample(random: Random, df: double) -> double:
  if df <= 0.0: throw "degrees must be positive"
  width = chiSquareSample(random, df) / df
  return normalSample(random) / math.sqrt(width)

# Fisher F draw.
# Example:
#   print fisherSample(Random(1), 2.0, 2.0) >= 0.0
fisherSample(random: Random, d1: double, d2: double) -> double:
  if d1 <= 0.0 or d2 <= 0.0: throw "degrees must be positive"
  return (chiSquareSample(random, d1) / d1) / (chiSquareSample(random, d2) / d2)

# Digamma function, the logarithmic derivative of gamma.
# Example:
#   print digamma(1.0)
digamma(x: double) -> double:
  if x == 0.0: throw "digamma is undefined at zero"
  if x < 0.0 and x == (x.floor to double):
    throw "digamma is undefined at a non-positive integer"
  if x < 0.5: return digamma(1.0 - x) - math.pi / math.tan(math.pi * x)
  var y = x
  var acc = 0.0
  while y < 8.0:
    acc = acc - 1.0 / y
    y = y + 1.0
  z = 1.0 / y
  z2 = z * z
  var series = math.log(y) - 0.5 * z - z2 / 12.0 + z2 * z2 / 120.0
  series = series - z2 * z2 * z2 / 252.0
  return acc + series

# Inverse of the error function, on (-1, 1).
# Example:
#   print inverseErf(0.0)
inverseErf(y: double) -> double:
  if y <= -1.0 or y >= 1.0: throw "inverseErf needs a value strictly between -1 and 1"
  if y == 0.0: return y
  if y < 0.0: return 0.0 - inverseErf(0.0 - y)
  return (0.0 - _normalTail((1.0 - y) / 2.0)) / math.sqrt(2.0)

# Gamma density. The mean is shape times scale.
# Example:
#   print gammaPdf(1.0, 1.0, 1.0)
gammaPdf(x: double, shape: double, scale: double) -> double:
  if shape <= 0.0 or scale <= 0.0: throw "shape and scale must be positive"
  if x < 0.0: return 0.0
  if x == 0.0:
    if shape < 1.0: throw "gammaPdf is infinite at zero"
    if shape > 1.0: return 0.0
    return 1.0 / scale
  var logP = (shape - 1.0) * math.log(x) - x / scale - logGamma(shape)
  logP = logP - shape * math.log(scale)
  return math.exp(logP)

# Gamma cumulative probability.
# Example:
#   print gammaCdf(1.0, 1.0, 1.0)
gammaCdf(x: double, shape: double, scale: double) -> double:
  if shape <= 0.0 or scale <= 0.0: throw "shape and scale must be positive"
  if x <= 0.0: return 0.0
  return lowerGamma(shape, x / scale)

# Gamma quantile.
# Example:
#   print gammaQuantile(0.5, 1.0, 1.0)
gammaQuantile(p: double, shape: double, scale: double) -> double:
  if shape <= 0.0 or scale <= 0.0: throw "shape and scale must be positive"
  unit = _bisectIncreasing((x: double) -> gammaCdf(x, shape, 1.0), p, 0.0,
  shape)
  return scale * unit

# Beta density on (0, 1).
# Example:
#   print betaPdf(0.5, 1.0, 1.0)
betaPdf(x: double, a: double, b: double) -> double:
  if a <= 0.0 or b <= 0.0: throw "betaPdf needs positive arguments"
  if x <= 0.0 or x >= 1.0:
    if x == 0.0 and a < 1.0: throw "betaPdf is infinite at an endpoint"
    if x == 1.0 and b < 1.0: throw "betaPdf is infinite at an endpoint"
    if x == 0.0 and a == 1.0: return b
    if x == 1.0 and b == 1.0: return a
    return 0.0
  var logP = (a - 1.0) * math.log(x) + (b - 1.0) * math.log(1.0 - x)
  logP = logP - logGamma(a) - logGamma(b) + logGamma(a + b)
  return math.exp(logP)

# Beta cumulative probability.
# Example:
#   print betaCdf(0.5, 1.0, 1.0)
betaCdf(x: double, a: double, b: double) -> double:
  if a <= 0.0 or b <= 0.0: throw "betaCdf needs positive arguments"
  if x <= 0.0: return 0.0
  if x >= 1.0: return 1.0
  return incompleteBeta(a, b, x)

# Beta quantile.
# Example:
#   print betaQuantile(0.5, 1.0, 1.0)
betaQuantile(p: double, a: double, b: double) -> double:
  if a <= 0.0 or b <= 0.0: throw "betaQuantile needs positive arguments"
  if p <= 0.0 or p >= 1.0: throw "probability must sit strictly between 0 and 1"
  var lo = 0.0
  var hi = 1.0
  var i = 0
  while i < 80:
    mid = (lo + hi) / 2.0
    if betaCdf(mid, a, b) < p: lo = mid
    else: hi = mid
    i = i + 1
  return (lo + hi) / 2.0

# Lognormal density. [center] and [sigma] describe the underlying normal.
# Example:
#   print lognormalPdf(1.0, 0.0, 1.0)
lognormalPdf(x: double, center: double, sigma: double) -> double:
  if sigma <= 0.0: throw "sigma must be positive"
  if x <= 0.0: return 0.0
  z = (math.log(x) - center) / sigma
  return math.exp(0.0 - 0.5 * z * z) / math.sqrt(2.0 * math.pi) / sigma / x

# Lognormal cumulative probability.
# Example:
#   print lognormalCdf(1.0, 0.0, 1.0)
lognormalCdf(x: double, center: double, sigma: double) -> double:
  if sigma <= 0.0: throw "sigma must be positive"
  if x <= 0.0: return 0.0
  return normalCdf(math.log(x), center: center, sigma: sigma)

# Lognormal quantile.
# Example:
#   print lognormalQuantile(0.5, 0.0, 1.0)
lognormalQuantile(p: double, center: double, sigma: double) -> double:
  return math.exp(normalQuantile(p, center: center, sigma: sigma))

# One lognormal draw.
# Example:
#   print lognormalSample(Random(1), 0.0, 1.0) > 0.0
lognormalSample(random: Random, center: double, sigma: double) -> double:
  return math.exp(normalSample(random, center: center, sigma: sigma))

# Cauchy density.
# Example:
#   print cauchyPdf(0.0, 0.0, 1.0)
cauchyPdf(x: double, center: double, spread: double) -> double:
  if spread <= 0.0: throw "spread must be positive"
  z = (x - center) / spread
  return (1.0 / (1.0 + z * z)) / math.pi / spread

# Cauchy cumulative probability.
# Example:
#   print cauchyCdf(0.0, 0.0, 1.0)
cauchyCdf(x: double, center: double, spread: double) -> double:
  if spread <= 0.0: throw "spread must be positive"
  return 0.5 + math.atan((x - center) / spread) / math.pi

# Cauchy quantile.
# Example:
#   print cauchyQuantile(0.5, 0.0, 1.0)
cauchyQuantile(p: double, center: double, spread: double) -> double:
  if spread <= 0.0: throw "spread must be positive"
  if p <= 0.0 or p >= 1.0: throw "probability must sit strictly between 0 and 1"
  return center + spread * math.tan(math.pi * (p - 0.5))

# One Cauchy draw.
# Example:
#   print cauchySample(Random(1), 0.0, 1.0)
cauchySample(random: Random, center: double, spread: double) -> double:
  var u = random.nextDouble()
  if u <= 0.0: u = 1.0e-16
  if u >= 1.0: u = 1.0 - 1.0e-16
  return cauchyQuantile(u, center, spread)

# Negative binomial probability of [failures] before [successes] successes.
# Example:
#   print negativeBinomialPmf(0, 1, 0.5)
negativeBinomialPmf(failures: int, successes: int, chance: double) -> double:
  if successes < 1: throw "negativeBinomial needs at least one success"
  if chance <= 0.0 or chance > 1.0: throw "probability must be from 0 through 1"
  if failures < 0: return 0.0
  if successes == 1: return geometricPmf(failures, chance)
  if chance == 1.0:
    if failures == 0: return 1.0
    return 0.0
  logged = _logChoose(_checkedAdd(failures, successes - 1), failures) + (failures to double) * log1p(0.0 - chance) + (successes to double) * math.log(chance)
  return math.exp(logged)

# Negative binomial cumulative probability.
# Example:
#   print negativeBinomialCdf(0, 1, 0.5)
negativeBinomialCdf(failures: int, successes: int, chance: double) -> double:
  if successes < 1: throw "negativeBinomial needs at least one success"
  if chance <= 0.0 or chance > 1.0: throw "probability must be from 0 through 1"
  if failures < 0: return 0.0
  return incompleteBeta(successes to double, (failures to double) + 1.0, chance)

:: calculus

# [count] evenly spaced values from [start] through [end], including both ends.
# Example:
#   print linspace(0.0, 1.0, 3).length
linspace(start: double, end: double, count: int) -> List<double>:
  if count < 2: throw "linspace needs at least two points"
  made: List<double> = []
  step = (end - start) / ((count - 1) to double)
  var i = 0
  while i < count:
    if i == count - 1: made.add(end)
    else: made.add(start + step * (i to double))
    i = i + 1
  return made

# Trapezoidal integral of [samples] separated by [step].
# Example:
#   print trapezoid([0.0, 1.0, 0.0], 1.0)
trapezoid(samples: List<double>, step: double) -> double:
  if samples.length < 2: throw "trapezoid needs at least two samples"
  if step == 0.0: throw "step cannot be zero"
  var total = 0.0
  var i = 0
  while i < samples.length - 1:
    total = total + (samples[i] + samples[i + 1]) * 0.5 * step
    i = i + 1
  return total

# Trapezoidal integral of [f] from [start] to [end], using [steps] panels.
# Example:
#   print integrate((x: double) -> x, 0.0, 1.0, 2)
integrate(
    f: (double) -> double, start: double, end: double, steps: int) -> double:
  if steps < 1: throw "steps must be positive"
  width = (end - start) / (steps to double)
  var total = 0.5 * (f(start) + f(end))
  var i = 1
  while i < steps:
    total = total + f(start + width * (i to double))
    i = i + 1
  return total * width

# The symmetric difference quotient of [f] at [x].
# Example:
#   print approximately(derivative((x: double) -> x, 2.0), 1.0, 1.0e-5)
derivative(f: (double) -> double, x: double, step: double = 1.0e-6) -> double:
  if step == 0.0: throw "step cannot be zero"
  return (f(x + step) - f(x - step)) / (2.0 * step)

# A root of [f] between [low] and [high], by bisection.
# The ends must have opposite signs, or one of them must be a root.
# Example:
#   print approximately(bisect((x: double) -> x - 2.0, 0.0, 4.0), 2.0, 1.0e-6)
bisect(
    f: (double) -> double,
    low: double,
    high: double,
    steps: int = 60) -> double:
  if steps < 1: throw "steps must be positive"
  var a = low
  var b = high
  var fa = f(a)
  var fb = f(b)
  if fa == 0.0: return a
  if fb == 0.0: return b
  if (fa > 0.0 and fb > 0.0) or (fa < 0.0 and fb < 0.0): throw "bisect needs a sign change"
  var i = 0
  while i < steps:
    mid = (a + b) / 2.0
    fm = f(mid)
    if fm == 0.0: return mid
    if (fa < 0.0 and fm > 0.0) or (fa > 0.0 and fm < 0.0):
      b = mid
      fb = fm
    else:
      a = mid
      fa = fm
    i = i + 1
  return (a + b) / 2.0

# The second derivative of [f] at [x], from three samples.
# Example:
#   print secondDerivative((x: double) -> x * x, 0.0)
secondDerivative(f: (double) -> double, x: double) -> double:
  step = 1.0 / 1024.0
  return (f(x + step) - 2.0 * f(x) + f(x - step)) / (step * step)

# Partial derivative of [f] at ([x], [y]). [axis] 0 moves x, and 1 moves y.
# Example:
#   print partial((x: double, y: double) -> x * y, 3.0, 4.0, 0)
partial(
    f: (double, double) -> double,
    x: double,
    y: double,
    axis: int) -> double:
  if axis != 0 and axis != 1: throw "partial axis must be 0 or 1"
  step = 1.0 / 1024.0
  if axis == 0: return (f(x + step, y) - f(x - step, y)) / (2.0 * step)
  return (f(x, y + step) - f(x, y - step)) / (2.0 * step)

# Both partial derivatives, with respect to x and then y.
# Example:
#   print gradient((x: double, y: double) -> x + y, 1.0, 2.0)[0]
gradient(
    f: (double, double) -> double,
    x: double,
    y: double) -> List<double>:
  made: List<double> = []
  made.add(partial(f, x, y, 0))
  made.add(partial(f, x, y, 1))
  return made

# A root of the derivative of [f] between [low] and [high].
# Example:
#   print criticalPoint((x: double) -> x * x, 0.0 - 2.0, 2.0)
criticalPoint(f: (double) -> double, low: double, high: double) -> double:
  return bisect((x: double) -> derivative(f, x), low, high)

# Simpson integral of [f] from [start] to [end]. [steps] must be even.
# Example:
#   print simpson((x: double) -> x, 0.0, 2.0, 2)
simpson(
    f: (double) -> double, start: double, end: double, steps: int) -> double:
  if steps < 2 or steps % 2 != 0:
    throw "simpson needs a positive even step count"
  width = (end - start) / (steps to double)
  var total = f(start) + f(end)
  var i = 1
  while i < steps:
    var weight = 4.0
    if i % 2 == 0: weight = 2.0
    total = total + weight * f(start + width * (i to double))
    i = i + 1
  return total * width / 3.0

# Simpson integral of [samples] separated by [step]. The panel count is even.
# Example:
#   print simpsonSamples([0.0, 1.0, 2.0], 1.0)
simpsonSamples(samples: List<double>, step: double) -> double:
  if step == 0.0: throw "step cannot be zero"
  panels = samples.length - 1
  if panels < 2 or panels % 2 != 0:
    throw "simpsonSamples needs an even number of panels"
  var total = samples[0] + samples[samples.length - 1]
  var i = 1
  while i < panels:
    var weight = 4.0
    if i % 2 == 0: weight = 2.0
    total = total + weight * samples[i]
    i = i + 1
  return total * step / 3.0

# Running trapezoidal integrals. The first entry is 0.
# Example:
#   print cumulativeIntegral([0.0, 1.0, 2.0], 1.0)[2]
cumulativeIntegral(samples: List<double>, step: double) -> List<double>:
  if samples.isEmpty: throw "cumulativeIntegral needs a sample"
  if step == 0.0: throw "step cannot be zero"
  made: List<double> = []
  made.add(0.0)
  var total = 0.0
  var i = 0
  while i < samples.length - 1:
    total = total + (samples[i] + samples[i + 1]) * 0.5 * step
    made.add(total)
    i = i + 1
  return made

# Integral of [f] divided by the length of the span.
# Example:
#   print meanValue((x: double) -> x, 0.0, 2.0, 2)
meanValue(
    f: (double) -> double, start: double, end: double, steps: int) -> double:
  if start == end: throw "meanValue needs a span"
  return integrate(f, start, end, steps) / (end - start)

# Integral of [f] over the rectangle [x0]..[x1] by [y0]..[y1].
# Example:
#   print doubleIntegral((x: double, y: double) -> 1.0, 0.0, 2.0, 0.0, 3.0, 2)
doubleIntegral(
    f: (double, double) -> double,
    x0: double,
    x1: double,
    y0: double,
    y1: double,
    steps: int) -> double:
  slice(y: double) -> double:
    return integrate((x: double) -> f(x, y), x0, x1, steps)
  return integrate(slice, y0, y1, steps)

# Length of the graph of [f] from [start] to [end].
# Example:
#   print arcLength((x: double) -> 2.0, 0.0, 1.0, 2)
arcLength(
    f: (double) -> double, start: double, end: double, steps: int) -> double:
  speed(x: double) -> double:
    return hypot(1.0, derivative(f, x))
  return integrate(speed, start, end, steps)

# A root of [f] by the secant method, starting from [low] and [high].
# Example:
#   print secant((x: double) -> x - 2.0, 0.0, 4.0, 1)
secant(
    f: (double) -> double,
    low: double,
    high: double,
    steps: int) -> double:
  if steps < 1: throw "steps must be positive"
  var a = low
  var b = high
  var i = 0
  while i < steps:
    fa = f(a)
    fb = f(b)
    if fb == fa: throw "secant needs a changing function"
    next = b - fb * (b - a) / (fb - fa)
    a = b
    b = next
    i = i + 1
  return b

# A root of [f] by Newton iteration, starting at [guess].
# Example:
#   print newton((x: double) -> x - 2.0, 0.0, 1)
newton(f: (double) -> double, guess: double, steps: int) -> double:
  if steps < 1: throw "steps must be positive"
  var x = guess
  var i = 0
  step = 1.0 / 1024.0
  while i < steps:
    slope = (f(x + step) - f(x - step)) / (2.0 * step)
    if slope == 0.0: throw "newton needs a non-zero derivative"
    x = x - f(x) / slope
    i = i + 1
  return x

# Euler step for y' = [f](x, y) from ([x0], [y0]) until [x1].
# Example:
#   print euler((x: double, y: double) -> 2.0, 0.0, 1.0, 1.0, 2)
euler(
    f: (double, double) -> double,
    x0: double,
    y0: double,
    x1: double,
    steps: int) -> double:
  if steps < 1: throw "steps must be positive"
  width = (x1 - x0) / (steps to double)
  var x = x0
  var y = y0
  var i = 0
  while i < steps:
    y = y + width * f(x, y)
    x = x + width
    i = i + 1
  return y

# Fourth-order Runge-Kutta for y' = [f](x, y) from ([x0], [y0]) until [x1].
# Example:
#   print rungeKutta((x: double, y: double) -> x, 0.0, 0.0, 1.0, 1)
rungeKutta(
    f: (double, double) -> double,
    x0: double,
    y0: double,
    x1: double,
    steps: int) -> double:
  if steps < 1: throw "steps must be positive"
  width = (x1 - x0) / (steps to double)
  var x = x0
  var y = y0
  var i = 0
  while i < steps:
    k1 = f(x, y)
    k2 = f(x + width * 0.5, y + width * 0.5 * k1)
    k3 = f(x + width * 0.5, y + width * 0.5 * k2)
    k4 = f(x + width, y + width * k3)
    y = y + width * (k1 + 2.0 * k2 + 2.0 * k3 + k4) / 6.0
    x = x + width
    i = i + 1
  return y

# A value and an estimate of its absolute error.
# Example:
#   print romberg((x: double) -> x, 0.0, 1.0, 4).value
value class Estimate:
  value: double
  error: double

# Romberg integral of [f] from [start] to [end]. [levels] is at least 2.
# Example:
#   print romberg((x: double) -> x * x, 0.0, 1.0, 4).value
romberg(
    f: (double) -> double,
    start: double,
    end: double,
    levels: int = 6) -> Estimate:
  if levels < 2: throw "romberg needs at least two levels"
  if start == end: return Estimate(value: 0.0, error: 0.0)
  var h = end - start
  var previous: List<double> = [0.5 * h * (f(start) + f(end))]
  var segments = 1
  var row = 1
  var value = previous[0]
  var error = _abs(value)
  while row < levels:
    h = h / 2.0
    var extra = 0.0
    var k = 1
    while k <= segments:
      extra = extra + f(start + ((2 * k - 1) to double) * h)
      k = k + 1
    trap = 0.5 * previous[0] + extra * h
    current: List<double> = [trap]
    var j = 1
    var factor = 4.0
    while j <= row:
      refined = (factor * current[j - 1] - previous[j - 1]) / (factor - 1.0)
      current.add(refined)
      factor = factor * 4.0
      j = j + 1
    value = current[row]
    error = _abs(current[row] - current[row - 1])
    previous = current
    segments = segments * 2
    row = row + 1
  return Estimate(value: value, error: error)

# Gauss-Legendre integral. [points] is 2 through 8.
# Example:
#   print gaussLegendre((x: double) -> x * x * x, 0.0, 1.0, 2)
gaussLegendre(
    f: (double) -> double,
    start: double,
    end: double,
    points: int = 5) -> double:
  if points < 2 or points > 8: throw "gaussLegendre supports 2 through 8 points"
  mid = (start + end) / 2.0
  half = (end - start) / 2.0
  if points == 2: return _gaussPair(f, mid, half, 0.5773502691896257, 1.0)
  if points == 3:
    center = _gaussPair(f, mid, half, 0.0, 0.8888888888888888)
    return center + _gaussPair(f, mid, half, 0.7745966692414834,
    0.5555555555555556)
  if points == 4:
    inner = _gaussPair(f, mid, half, 0.3399810435848563, 0.6521451548625461)
    ends = _gaussPair(f, mid, half, 0.8611363115940526, 0.34785484513745385)
    return inner + ends
  if points == 5:
    center = _gaussPair(f, mid, half, 0.0, 0.5688888888888889)
    inner = _gaussPair(f, mid, half, 0.5384693101056831, 0.47862867049936647)
    ends = _gaussPair(f, mid, half, 0.9061798459386640, 0.23692688505618908)
    return center + inner + ends
  if points == 6:
    low = _gaussPair(f, mid, half, 0.2386191860831969, 0.4679139345726910)
    midNode = _gaussPair(f, mid, half, 0.6612093864662645, 0.3607615730481386)
    high = _gaussPair(f, mid, half, 0.9324695142031521, 0.1713244923791704)
    return low + midNode + high
  if points == 7:
    center = _gaussPair(f, mid, half, 0.0, 0.4179591836734694)
    low = _gaussPair(f, mid, half, 0.4058451513773972, 0.3818300505051189)
    midNode = _gaussPair(f, mid, half, 0.7415311855993945, 0.2797053914892766)
    high = _gaussPair(f, mid, half, 0.9491079123427585, 0.1294849661688697)
    return center + low + midNode + high
  low = _gaussPair(f, mid, half, 0.1834346424956498, 0.3626837833783620)
  midLow = _gaussPair(f, mid, half, 0.5255324099163290, 0.3137066458778873)
  midHigh = _gaussPair(f, mid, half, 0.7966664774136267, 0.2223810344533745)
  high = _gaussPair(f, mid, half, 0.9602898564975363, 0.1012285362903763)
  return low + midLow + midHigh + high

# Euler steps for a first-order system. The result is the state at [x1].
# Example:
#   print eulerSystem((x: double, y: List<double>) -> [2.0], 0.0, [1.0], 1.0, 2)[0]
eulerSystem(
    f: (double, List<double>) -> List<double>,
    x0: double,
    y0: List<double>,
    x1: double,
    steps: int) -> List<double>:
  if steps < 1: throw "steps must be positive"
  if y0.isEmpty: throw "eulerSystem needs a state"
  width = (x1 - x0) / (steps to double)
  var x = x0
  var y = _copyDoubles(y0)
  var i = 0
  while i < steps:
    slope = f(x, y)
    if slope.length != y.length: throw "the derivative must match the state"
    y = _axpy(y, slope, width)
    x = x + width
    i = i + 1
  return y

# Fourth-order Runge-Kutta for a first-order system.
# Example:
#   print rungeKuttaSystem((x: double, y: List<double>) -> [x], 0.0, [0.0], 1.0, 1)[0]
rungeKuttaSystem(
    f: (double, List<double>) -> List<double>,
    x0: double,
    y0: List<double>,
    x1: double,
    steps: int) -> List<double>:
  if steps < 1: throw "steps must be positive"
  if y0.isEmpty: throw "rungeKuttaSystem needs a state"
  width = (x1 - x0) / (steps to double)
  var x = x0
  var y = _copyDoubles(y0)
  var i = 0
  while i < steps:
    y = _rk4(f, x, y, width)
    x = x + width
    i = i + 1
  return y

# Adaptive Runge-Kutta-Fehlberg for one equation, within [tolerance].
# Example:
#   print rungeKuttaAdaptive((x: double, y: double) -> y, 0.0, 1.0, 1.0)
rungeKuttaAdaptive(
    f: (double, double) -> double,
    x0: double,
    y0: double,
    x1: double,
    tolerance: double = 1.0e-6) -> double:
  answer = rungeKuttaAdaptiveSystem(
      (x: double, y: List<double>) -> [f(x, y[0])],
      x0,
      [y0],
      x1,
      tolerance: tolerance)
  return answer[0]

# Adaptive Runge-Kutta-Fehlberg for a system, within [tolerance].
# Example:
#   print rungeKuttaAdaptiveSystem((x: double, y: List<double>) -> [y[0]], 0.0, [1.0], 1.0)[0]
rungeKuttaAdaptiveSystem(
    f: (double, List<double>) -> List<double>,
    x0: double,
    y0: List<double>,
    x1: double,
    tolerance: double = 1.0e-6) -> List<double>:
  if y0.isEmpty: throw "rungeKuttaAdaptiveSystem needs a state"
  if tolerance <= 0.0: throw "tolerance must be positive"
  if x0 == x1: return _copyDoubles(y0)
  var x = x0
  var y = _copyDoubles(y0)
  var h = (x1 - x0) / 20.0
  var guard = 0
  while guard < 20000:
    remaining = x1 - x
    if _abs(remaining) <= 1.0e-14 * (1.0 + _abs(x1)): return y
    if _abs(h) > _abs(remaining): h = remaining
    step = _rkf45(f, x, y, h)
    if step.error <= tolerance or _abs(h) <= 1.0e-14:
      x = x + h
      y = step.state
    var factor = 2.0
    if step.error > 0.0:
      ratio = tolerance / step.error
      factor = 0.9 * (math.pow(ratio, 0.2) to double)
    if factor < 0.2: factor = 0.2
    if factor > 5.0: factor = 5.0
    h = h * factor
    guard = guard + 1
  throw "rungeKuttaAdaptiveSystem did not finish"
  return y

# Samples of y for y'' = [f](x, y, y') with y(x0) = y0 and y(x1) = y1.
# [slopeLow] and [slopeHigh] must miss [y1] on opposite sides.
# Example:
#   print solveBoundary((x: double, y: double, yp: double) -> 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 2.0, 4)[4]
solveBoundary(
    f: (double, double, double) -> double,
    x0: double,
    y0: double,
    x1: double,
    y1: double,
    slopeLow: double,
    slopeHigh: double,
    steps: int = 32) -> List<double>:
  if steps < 1: throw "steps must be positive"
  lowMiss = _boundaryMiss(f, x0, y0, x1, y1, slopeLow, steps)
  highMiss = _boundaryMiss(f, x0, y0, x1, y1, slopeHigh, steps)
  var lo = slopeLow
  var hi = slopeHigh
  var missLo = lowMiss
  if lowMiss * highMiss > 0.0: throw "solveBoundary needs opposite misses"
  var i = 0
  while i < 48:
    mid = (lo + hi) / 2.0
    miss = _boundaryMiss(f, x0, y0, x1, y1, mid, steps)
    if missLo * miss <= 0.0: hi = mid
    else:
      lo = mid
      missLo = miss
    i = i + 1
  chosen = (lo + hi) / 2.0
  states = _rkSamples(
      (x: double, state: List<double>) -> _boundaryField(f, x, state),
      x0,
      [y0, chosen],
      x1,
      steps)
  made: List<double> = []
  for state in states:
    made.add(state[0])
  return made

# Backward Euler for a stiff system. The result is the state at [x1].
# Each step runs a short Newton iteration and then checks the backward-Euler
# residual. If that residual is not finite or not within tolerance, this throws
# and does not return the last Newton state.
# Example:
#   print implicitEuler((x: double, y: List<double>) -> [0.0 - 50.0 * y[0]], 0.0, [1.0], 1.0, 4)[0]
implicitEuler(
    f: (double, List<double>) -> List<double>,
    x0: double,
    y0: List<double>,
    x1: double,
    steps: int) -> List<double>:
  if steps < 1: throw "steps must be positive"
  if y0.isEmpty: throw "implicitEuler needs a state"
  width = (x1 - x0) / (steps to double)
  var x = x0
  var y = _copyDoubles(y0)
  var step = 0
  while step < steps:
    var z = _copyDoubles(y)
    var guard = 0
    while guard < 8:
      slope = f(x + width, z)
      if slope.length != z.length: throw "the derivative must match the state"
      jac = subtractMatrices(identity(z.length),
      scaleMatrix(_jacobian(f, x + width, z), width))
      var rhs = _zeroDoubles(z.length)
      var i = 0
      while i < z.length:
        rhs = _setAt(rhs, i, 0.0 - (z[i] - y[i] - width * slope[i]))
        i = i + 1
      delta = solveLinear(jac, rhs)
      z = _axpy(z, delta, 1.0)
      if vectorLength(delta) < 1.0e-10: guard = 8
      else: guard = guard + 1
    slope = f(x + width, z)
    residual = _axpy(_axpy(z, y, -1.0), slope, 0.0 - width)
    if not _finite(vectorLength(residual)) or vectorLength(residual) > 1.0e-8 * (1.0 + vectorLength(z)):
      throw "implicitEuler did not converge"
    y = z
    x = x + width
    step = step + 1
  return y

# First place on [x0, x1] where [guard] changes sign along the trajectory.
# Example:
#   print firstEvent((x: double, y: List<double>) -> [1.0], (x: double, y: List<double>) -> y[0] - 0.5, 0.0, [0.0], 1.0).at
value class Crossing:
  at: double
  state: List<double>

firstEvent(
    f: (double, List<double>) -> List<double>,
    guard: (double, List<double>) -> double,
    x0: double,
    y0: List<double>,
    x1: double) -> Crossing:
  if y0.isEmpty: throw "firstEvent needs a state"
  start = guard(x0, y0)
  if start == 0.0: return Crossing(at: x0, state: _copyDoubles(y0))
  finished = rungeKuttaSystem(f, x0, y0, x1, 32)
  end = guard(x1, finished)
  if end == 0.0: return Crossing(at: x1, state: finished)
  if _sameSign(start, end): throw "firstEvent needs a sign change"
  var lo = x0
  var hi = x1
  var here = _copyDoubles(y0)
  var i = 0
  while i < 40:
    mid = (lo + hi) / 2.0
    reached = rungeKuttaSystem(f, lo, here, mid, 8)
    probe = guard(mid, reached)
    if not _sameSign(guard(lo, here), probe): hi = mid
    else:
      lo = mid
      here = reached
    i = i + 1
  at = (lo + hi) / 2.0
  return Crossing(at: at, state: rungeKuttaSystem(f, lo, here, at, 8))

# Adaptive Simpson integral. Error is the sum of accepted local Richardson estimates.
# Example:
#   print adaptiveIntegral((x: double) -> x * x, 0.0, 1.0).value
adaptiveIntegral(f: (double) -> double, start: double, end: double, tolerance: double = 1.0e-8) -> Estimate:
  if tolerance <= 0.0: throw "tolerance must be positive"
  whole = _simpson3(f, start, end)
  return _adaptEstimate(f, start, end, tolerance, whole, 0)

# Integral of [f] over a box, by nested trapezoids.
# Example:
#   print tripleIntegral((x: double, y: double, z: double) -> 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 2)
tripleIntegral(
    f: (double, double, double) -> double,
    x0: double,
    x1: double,
    y0: double,
    y1: double,
    z0: double,
    z1: double,
    steps: int) -> double:
  slice(z: double) -> double:
    return doubleIntegral((x: double, y: double) -> f(x, y, z), x0, x1, y0,
    y1, steps)
  return integrate(slice, z0, z1, steps)

# Backward differentiation formula of order 2. The result is the state at [x1].
# Example:
#   print bdf2((x: double, y: List<double>) -> [0.0 - y[0]], 0.0, [1.0], 1.0, 8)[0]
bdf2(
    f: (double, List<double>) -> List<double>,
    x0: double,
    y0: List<double>,
    x1: double,
    steps: int) -> List<double>:
  if steps < 1: throw "steps must be positive"
  if steps == 1: return implicitEuler(f, x0, y0, x1, 1)
  width = (x1 - x0) / (steps to double)
  var previous = _copyDoubles(y0)
  var y = implicitEuler(f, x0, y0, x0 + width, 1)
  var x = x0 + width
  var step = 1
  while step < steps:
    var z = _copyDoubles(y)
    var guard = 0
    while guard < 8:
      slope = f(x + width, z)
      if slope.length != z.length: throw "the derivative must match the state"
      jac = subtractMatrices(identity(z.length), scaleMatrix(_jacobian(f,
      x + width, z), 2.0 * width / 3.0))
      var rhs = _zeroDoubles(z.length)
      var i = 0
      while i < z.length:
        gap = z[i] - 4.0 / 3.0 * y[i] + previous[i] / 3.0 - 2.0 * width / 3.0 * slope[i]
        rhs = _setAt(rhs, i, 0.0 - gap)
        i = i + 1
      delta = solveLinear(jac, rhs)
      z = _axpy(z, delta, 1.0)
      if vectorLength(delta) < 1.0e-10: guard = 8
      else: guard = guard + 1
    slope = f(x + width, z)
    residual = _axpy(_axpy(_axpy(z, y, -4.0 / 3.0), previous, 1.0 / 3.0), slope, 0.0 - 2.0 * width / 3.0)
    if not _finite(vectorLength(residual)) or vectorLength(residual) > 1.0e-8 * (1.0 + vectorLength(z)):
      throw "bdf2 did not converge"
    previous = y
    y = z
    x = x + width
    step = step + 1
  return y

# Every detected sign change of [guard] from [x0] to [x1].
# Example:
#   print signEvents((x: double, y: List<double>) -> [1.0], (x: double, y: List<double>) -> y[0] - 0.5, 0.0, [0.0], 1.0, 8)[0].at
signEvents(
    f: (double, List<double>) -> List<double>,
    guard: (double, List<double>) -> double,
    x0: double,
    y0: List<double>,
    x1: double,
    pieces: int) -> List<Crossing>:
  if pieces < 1: throw "signEvents needs at least one piece"
  if y0.isEmpty: throw "signEvents needs a state"
  var made: List<Crossing> = []
  var here = _copyDoubles(y0)
  var t = x0
  width = (x1 - x0) / (pieces to double)
  var i = 0
  while i < pieces:
    g0 = guard(t, here)
    nxt = rungeKuttaSystem(f, t, here, t + width, 4)
    g1 = guard(t + width, nxt)
    if i == 0 and g0 == 0.0: made.add(Crossing(at: t,
    state: _copyDoubles(here)))
    if g1 == 0.0: made.add(Crossing(at: t + width, state: nxt))
    else: if _differentSigns(g0, g1): made.add(firstEvent(f, guard, t, here, t + width))
    here = nxt
    t = t + width
    i = i + 1
  return made

# Implicit finite-difference step for the heat equation. Ends stay fixed.
# Example:
#   print heat([0.0, 1.0, 0.0], 1.0, 1.0, 1.0, 1)[1]
heat(
    initial: List<double>,
    diffusivity: double,
    dx: double,
    dt: double,
    steps: int) -> List<double>:
  if initial.length < 2: throw "heat needs at least the two boundaries"
  if diffusivity < 0.0: throw "diffusivity cannot be negative"
  if dx <= 0.0 or dt <= 0.0 or steps < 1: throw "heat needs positive spacing and steps"
  r = diffusivity * dt / (dx * dx)
  var current = _copyDoubles(initial)
  var step = 0
  while step < steps:
    unknowns = current.length - 2
    if unknowns < 1: step = steps
    else:
      below: List<double> = []
      diag: List<double> = []
      above: List<double> = []
      rhs: List<double> = []
      var i = 0
      while i < unknowns:
        diag.add(1.0 + 2.0 * r)
        var load = current[i + 1]
        if i == 0: load = load + r * current[0]
        if i == unknowns - 1: load = load + r * current[current.length - 1]
        rhs.add(load)
        if i > 0: below.add(0.0 - r)
        if i < unknowns - 1: above.add(0.0 - r)
        i = i + 1
      solved = tridiagonalSolve(below, diag, above, rhs)
      var next = _copyDoubles(current)
      i = 0
      while i < unknowns:
        next = _setAt(next, i + 1, solved[i])
        i = i + 1
      current = next
      step = step + 1
  return current

# Adaptive integral of [f] over a rectangle.
# Example:
#   print adaptiveDoubleIntegral((x: double, y: double) -> 1.0, 0.0, 1.0, 0.0, 1.0)
adaptiveDoubleIntegral(
    f: (double, double) -> double,
    x0: double,
    x1: double,
    y0: double,
    y1: double,
    tolerance: double = 1.0e-6) -> double:
  if tolerance <= 0.0: throw "tolerance must be positive"
  outer(y: double) -> double:
    inner(x: double) -> double = f(x, y)
    whole = _simpson3(inner, x0, x1)
    return _adapt(inner, x0, x1, tolerance, whole, 0)
  whole = _simpson3(outer, y0, y1)
  return _adapt(outer, y0, y1, tolerance, whole, 0)

:: interp

# Piecewise linear value of [ys] at [x]. [xs] must increase.
# Outside the span, the nearest end value is returned.
# Example:
#   print interp(1.5, [1.0, 2.0], [10.0, 20.0])
interp(x: double, xs: List<double>, ys: List<double>) -> double:
  if xs.length != ys.length or xs.length < 2:
    throw "interp needs matching lists of at least two points"
  _increasing(xs)
  if x <= xs[0]: return ys[0]
  last = xs.length - 1
  if x >= xs[last]: return ys[last]
  var i = 1
  while i < xs.length:
    if x <= xs[i]:
      span = xs[i] - xs[i - 1]
      if span == 0.0: return ys[i]
      t = (x - xs[i - 1]) / span
      return ys[i - 1] + t * (ys[i] - ys[i - 1])
    i = i + 1
  return ys[last]

# A straight line, slope * x + intercept.
# Example:
#   fit = lineFit([0.0, 1.0], [1.0, 3.0])
#   print fit.slope
value class Line:
  slope: double
  intercept: double

# Least-squares line through the pairs ([xs], [ys]).
# Example:
#   print lineFit([0.0, 1.0, 2.0], [1.0, 3.0, 5.0]).slope
lineFit(xs: List<double>, ys: List<double>) -> Line:
  if xs.length != ys.length or xs.length < 2:
    throw "lineFit needs matching lists of at least two points"
  mx = mean(xs)
  my = mean(ys)
  var xx = 0.0
  var xy = 0.0
  var i = 0
  while i < xs.length:
    dx = xs[i] - mx
    xx = xx + dx * dx
    xy = xy + dx * (ys[i] - my)
    i = i + 1
  if xx == 0.0: throw "lineFit needs more than one x value"
  slope = xy / xx
  return Line(slope: slope, intercept: my - slope * mx)

# Bilinear interpolation. [grid] rows follow [ys] and columns follow [xs].
# Example:
#   print bilinear(0.5, 0.5, [0.0, 1.0], [0.0, 1.0], [[0.0, 2.0], [4.0, 6.0]])
bilinear(
    x: double,
    y: double,
    xs: List<double>,
    ys: List<double>,
    grid: List<List<double>>) -> double:
  if xs.length < 2 or ys.length < 2 or grid.length != ys.length:
    throw "bilinear needs a grid on increasing axes"
  _increasing(xs)
  _increasing(ys)
  for row in grid:
    if row.length != xs.length: throw "bilinear needs a rectangular grid"
  var i = 0
  while i < xs.length - 2 and x > xs[i + 1]:
    i = i + 1
  var j = 0
  while j < ys.length - 2 and y > ys[j + 1]:
    j = j + 1
  if x < xs[0] or x > xs[xs.length - 1] or y < ys[0] or y > ys[ys.length - 1]:
    throw "bilinear sample is outside the grid"
  if grid[j].length != xs.length: throw "bilinear needs a rectangular grid"
  tx = (x - xs[i]) / (xs[i + 1] - xs[i])
  ty = (y - ys[j]) / (ys[j + 1] - ys[j])
  v00 = grid[j][i]
  v10 = grid[j][i + 1]
  v01 = grid[j + 1][i]
  v11 = grid[j + 1][i + 1]
  low = v00 * (1.0 - tx) + v10 * tx
  high = v01 * (1.0 - tx) + v11 * tx
  return low * (1.0 - ty) + high * ty

:: linalg

# Rows turned into columns.
# Example:
#   print transpose([[1.0, 2.0]])[1][0]
transpose(rows: List<List<double>>) -> List<List<double>>:
  if rows.isEmpty:
    empty: List<List<double>> = []
    return empty
  width = rows[0].length
  made: List<List<double>> = []
  var column = 0
  while column < width:
    across: List<double> = []
    for row in rows:
      if row.length != width: throw "transpose needs a rectangular matrix"
      across.add(row[column])
    made.add(across)
    column = column + 1
  return made

# Matrix product. Columns of [left] must match rows of [right].
# Example:
#   print matmul([[1.0, 2.0]], [[3.0], [4.0]])[0][0]
matmul(
    left: List<List<double>>,
    right: List<List<double>>) -> List<List<double>>:
  if left.isEmpty or right.isEmpty: throw "matmul needs non-empty matrices"
  shared = left[0].length
  if right.length != shared:
    throw "matmul columns of the left must match rows of the right"
  outWidth = right[0].length
  made: List<List<double>> = []
  for row in left:
    if row.length != shared: throw "matmul needs rectangular matrices"
    next: List<double> = []
    var column = 0
    while column < outWidth:
      var total = 0.0
      var k = 0
      while k < shared:
        if right[k].length != outWidth:
          throw "matmul needs rectangular matrices"
        total = total + row[k] * right[k][column]
        k = k + 1
      next.add(total)
      column = column + 1
    made.add(next)
  return made

# Determinant of a square matrix.
# Example:
#   print determinant([[1.0, 0.0], [0.0, 1.0]])
determinant(rows: List<List<double>>) -> double:
  n = rows.length
  if n == 0: throw "determinant needs a square matrix"
  var grid = _squareCopy(rows)
  var sign = 1.0
  var col = 0
  while col < n:
    pivot = _pivotRow(grid, col)
    if grid[pivot][col] == 0.0: return 0.0
    if pivot != col:
      grid = _swapRows(grid, col, pivot)
      sign = 0.0 - sign
    var below = col + 1
    while below < n:
      factor = grid[below][col] / grid[col][col]
      cleared = _cancel(grid[below], grid[col], factor, col)
      grid = _replaceRow(grid, below, cleared)
      below = below + 1
    col = col + 1
  var diag = sign
  var i = 0
  while i < n:
    diag = diag * grid[i][i]
    i = i + 1
  return diag

# Solution of matrix * x = [values]. The matrix must be square and invertible.
# Example:
#   print solveLinear([[2.0, 0.0], [0.0, 3.0]], [4.0, 9.0])[0]
solveLinear(rows: List<List<double>>, values: List<double>) -> List<double>:
  n = rows.length
  if n == 0 or values.length != n: throw "solveLinear needs a square system"
  var grid = _squareCopy(rows)
  var rhs = _copyDoubles(values)
  var col = 0
  while col < n:
    pivot = _pivotRow(grid, col)
    if grid[pivot][col] == 0.0: throw "solveLinear needs an invertible matrix"
    if pivot != col:
      grid = _swapRows(grid, col, pivot)
      rhs = _swapDoubles(rhs, col, pivot)
    var other = 0
    while other < n:
      if other != col:
        factor = grid[other][col] / grid[col][col]
        cleared = _cancel(grid[other], grid[col], factor, col)
        grid = _replaceRow(grid, other, cleared)
        rhs = _setAt(rhs, other, rhs[other] - factor * rhs[col])
      other = other + 1
    col = col + 1
  answer: List<double> = []
  var i = 0
  while i < n:
    answer.add(rhs[i] / grid[i][i])
    i = i + 1
  return answer

# The n by n identity. [n] must be positive.
# Example:
#   print identity(2)[1][1]
identity(n: int) -> List<List<double>>:
  if n < 1: throw "identity needs a positive size"
  var grid = _filled(n, n, 0.0)
  var i = 0
  while i < n:
    grid = _replaceRow(grid, i, _setAt(grid[i], i, 1.0))
    i = i + 1
  return grid

# The product of a matrix and a column vector.
# Example:
#   print matvec([[1.0, 2.0]], [3.0, 4.0])[0]
matvec(rows: List<List<double>>, values: List<double>) -> List<double>:
  grid = _rectCopy(rows)
  if values.length != grid[0].length:
    throw "matvec columns must match the vector"
  made: List<double> = []
  for row in grid:
    made.add(_dot(row, values))
  return made

# Element-wise sum. The matrices must have the same shape.
# Example:
#   print addMatrices([[1.0, 2.0]], [[3.0, 4.0]])[0][1]
addMatrices(
    left: List<List<double>>,
    right: List<List<double>>) -> List<List<double>>:
  return _blend(left, right, 1.0)

# Element-wise difference, left minus right.
# Example:
#   print subtractMatrices([[5.0]], [[2.0]])[0][0]
subtractMatrices(
    left: List<List<double>>,
    right: List<List<double>>) -> List<List<double>>:
  return _blend(left, right, 0.0 - 1.0)

# Every entry multiplied by [factor].
# Example:
#   print scaleMatrix([[1.0, 2.0]], 3.0)[0][1]
scaleMatrix(rows: List<List<double>>, factor: double) -> List<List<double>>:
  grid = _rectCopy(rows)
  made: List<List<double>> = []
  for row in grid:
    made.add(_scaleList(row, factor))
  return made

# Element-wise product. The matrices must have the same shape.
# Example:
#   print hadamard([[1.0, 2.0]], [[3.0, 4.0]])[0][0]
hadamard(
    left: List<List<double>>,
    right: List<List<double>>) -> List<List<double>>:
  width = _sameShape(left, right)
  made: List<List<double>> = []
  var row = 0
  while row < left.length:
    line: List<double> = []
    var column = 0
    while column < width:
      line.add(left[row][column] * right[row][column])
      column = column + 1
    made.add(line)
    row = row + 1
  return made

# The sum of the diagonal. The matrix must be square.
# Example:
#   print trace([[1.0, 2.0], [3.0, 4.0]])
trace(rows: List<List<double>>) -> double:
  grid = _squareCopy(rows)
  var total = 0.0
  var i = 0
  while i < grid.length:
    total = total + grid[i][i]
    i = i + 1
  return total

# The Euclidean norm of every entry.
# Example:
#   print frobenius([[3.0, 4.0]])
frobenius(rows: List<List<double>>) -> double:
  grid = _rectCopy(rows)
  var total = 0.0
  for row in grid:
    total = hypot(total, vectorLength(row))
  return total

# The dot product of two vectors of the same length.
# Example:
#   print dot([1.0, 2.0], [3.0, 4.0])
dot(left: List<double>, right: List<double>) -> double:
  if left.length != right.length or left.isEmpty:
    throw "dot needs two vectors of the same length"
  return _dot(left, right)

# The outer product, a matrix whose [i][j] entry is left[i] * right[j].
# Example:
#   print outer([1.0, 2.0], [3.0, 4.0])[1][0]
outer(left: List<double>, right: List<double>) -> List<List<double>>:
  if left.isEmpty or right.isEmpty: throw "outer needs non-empty vectors"
  made: List<List<double>> = []
  for item in left:
    made.add(_scaleList(right, item))
  return made

# The diagonal entries of a rectangular matrix.
# Example:
#   print diagonal([[1.0, 2.0], [3.0, 4.0]])[1]
diagonal(rows: List<List<double>>) -> List<double>:
  grid = _rectCopy(rows)
  made: List<double> = []
  var count = grid.length
  if grid[0].length < count: count = grid[0].length
  var i = 0
  while i < count:
    made.add(grid[i][i])
    i = i + 1
  return made

# A square matrix with [values] on the diagonal and zeros elsewhere.
# Example:
#   print diagonalMatrix([1.0, 2.0])[1][1]
diagonalMatrix(values: List<double>) -> List<List<double>>:
  if values.isEmpty: throw "diagonalMatrix needs a value"
  var grid = _filled(values.length, values.length, 0.0)
  var i = 0
  while i < values.length:
    grid = _replaceRow(grid, i, _setAt(grid[i], i, values[i]))
    i = i + 1
  return grid

# The Euclidean length of a vector.
# Example:
#   print vectorLength([3.0, 4.0])
vectorLength(values: List<double>) -> double:
  if values.isEmpty: throw "vectorLength needs a vector"
  var total = 0.0
  for value in values:
    total = hypot(total, value)
  return total

# The sum of each row.
# Example:
#   print rowSums([[1.0, 2.0], [3.0, 4.0]])[1]
rowSums(rows: List<List<double>>) -> List<double>:
  grid = _rectCopy(rows)
  made: List<double> = []
  for row in grid:
    var total = 0.0
    for value in row:
      total = total + value
    made.add(total)
  return made

# The sum of each column.
# Example:
#   print columnSums([[1.0, 2.0], [3.0, 4.0]])[0]
columnSums(rows: List<List<double>>) -> List<double>:
  grid = _rectCopy(rows)
  made: List<double> = []
  var column = 0
  while column < grid[0].length:
    var total = 0.0
    for row in grid:
      total = total + row[column]
    made.add(total)
    column = column + 1
  return made

# The inverse of a square invertible matrix.
# Example:
#   print inverse([[2.0, 0.0], [0.0, 4.0]])[0][0]
inverse(rows: List<List<double>>) -> List<List<double>>:
  n = rows.length
  eye = identity(n)
  _squareCopy(rows)
  columns: List<List<double>> = []
  var col = 0
  while col < n:
    columns.add(solveLinear(rows, eye[col]))
    col = col + 1
  return transpose(columns)

# Numerical rank: singular values above 1e-12 times the largest count.
# Example:
#   print rank([[1.0, 2.0], [2.0, 4.0]])
rank(rows: List<List<double>>) -> int:
  if rows.isEmpty: return 0
  vals = svd(rows).values
  var found = 0
  for value in vals:
    if value > 1.0e-12 * vals[0]: found = found + 1
  return found

# Least-squares solution of matrix * x = [values].
# The columns must be independent, and there must be at least as many rows.
# Example:
#   print leastSquares([[1.0, 0.0], [1.0, 1.0]], [1.0, 3.0])[1]
leastSquares(rows: List<List<double>>, values: List<double>) -> List<double>:
  grid = _rectCopy(rows)
  if values.length != grid.length: throw "leastSquares needs one value per row"
  return matvec(pseudoinverse(grid), values)

# [rows] raised to a non-negative integer power. Power 0 is the identity.
# Example:
#   print matpow([[1.0, 1.0], [0.0, 1.0]], 2)[0][1]
matpow(rows: List<List<double>>, exponent: int) -> List<List<double>>:
  if exponent < 0: throw "matpow needs a non-negative power"
  n = rows.length
  _squareCopy(rows)
  if exponent == 0: return identity(n)
  var acc = identity(n)
  var base = _squareCopy(rows)
  var left = exponent
  while left > 0:
    if left % 2 == 1: acc = matmul(acc, base)
    left = left ~/ 2
    if left > 0: base = matmul(base, base)
  return acc

# Lower-triangular Cholesky factor of a positive definite matrix.
# Example:
#   print cholesky([[4.0, 0.0], [0.0, 9.0]])[1][1]
cholesky(rows: List<List<double>>) -> List<List<double>>:
  grid = _squareCopy(rows)
  n = grid.length
  var lower = _filled(n, n, 0.0)
  var i = 0
  while i < n:
    var j = 0
    while j <= i:
      var sum = grid[i][j]
      var k = 0
      while k < j:
        sum = sum - lower[i][k] * lower[j][k]
        k = k + 1
      if i == j:
        if sum <= 0.0: throw "cholesky needs a positive definite matrix"
        lower = _replaceRow(lower, i, _setAt(lower[i], j, math.sqrt(sum)))
      else:
        lower = _replaceRow(lower, i, _setAt(lower[i], j, sum / lower[j][j]))
      j = j + 1
    i = i + 1
  return lower

# Thin QR by Gram-Schmidt. [q] has orthonormal columns and [r] is upper triangular.
# Example:
#   print qr(identity(2)).r[0][0]
value class QR:
  q: List<List<double>>
  r: List<List<double>>

# Columns of [rows] must be independent, and there must be enough rows.
# Example:
#   print qr([[0.0, 1.0], [1.0, 0.0]]).q[1][0]
qr(rows: List<List<double>>) -> QR:
  original = _rectCopy(rows)
  height = original.length
  width = original[0].length
  if height < width: throw "qr needs at least as many rows as columns"
  scale = _matrixScale(original)
  if scale == 0.0: throw "qr needs independent columns"
  grid = _divideMatrix(original, scale)
  var q = _filled(height, width, 0.0)
  var r = _filled(width, width, 0.0)
  var j = 0
  while j < width:
    var col = _column(grid, j)
    var pass = 0
    while pass < 2:
      var i = 0
      while i < j:
        basis = _column(q, i)
        projection = dot(basis, col)
        r = _put(r, i, j, r[i][j] + projection)
        col = _axpy(col, basis, 0.0 - projection)
        i = i + 1
      pass = pass + 1
    length = vectorLength(col)
    if length <= 2.22e-16 * (width to double): throw "qr needs independent columns"
    r = _put(r, j, j, length)
    q = _setColumn(q, j, _divideVector(col, length))
    j = j + 1
  return QR(q: q, r: scaleMatrix(r, scale))

# Maximum absolute column sum.
# Example:
#   print norm1([[1.0, 0.0 - 2.0], [3.0, 4.0]])
norm1(rows: List<List<double>>) -> double:
  grid = _rectCopy(rows)
  var best = 0.0
  var column = 0
  while column < grid[0].length:
    var total = 0.0
    for row in grid:
      total = total + _abs(row[column])
    if total > best: best = total
    column = column + 1
  return best

# Maximum absolute row sum.
# Example:
#   print normInf([[1.0, 0.0 - 2.0], [3.0, 4.0]])
normInf(rows: List<List<double>>) -> double:
  grid = _rectCopy(rows)
  var best = 0.0
  for row in grid:
    var total = 0.0
    for value in row:
      total = total + _abs(value)
    if total > best: best = total
  return best

# Infinity-norm condition number, normInf(A) * normInf(inverse(A)).
# Example:
#   print conditionNumber([[2.0, 0.0], [0.0, 4.0]])
conditionNumber(rows: List<List<double>>) -> double:
  return normInf(rows) * normInf(inverse(rows))

# PA = LU with partial pivoting. [permutation] maps a row back to its source.
# Example:
#   print lu(identity(2)).upper[0][0]
value class LU:
  permutation: List<int>
  lower: List<List<double>>
  upper: List<List<double>>

# Factors of a square invertible matrix.
# Example:
#   print lu([[2.0, 0.0], [0.0, 3.0]]).lower[1][1]
lu(rows: List<List<double>>) -> LU:
  var grid = _squareCopy(rows)
  n = grid.length
  if n == 0: throw "lu needs a matrix"
  var perm: List<int> = []
  var i = 0
  while i < n:
    perm.add(i)
    i = i + 1
  var col = 0
  while col < n:
    pivot = _pivotRow(grid, col)
    if _abs(grid[pivot][col]) <= 1.0e-12: throw "lu needs a nonzero pivot"
    if pivot != col:
      grid = _swapRows(grid, col, pivot)
      perm = _swapInts(perm, col, pivot)
    var row = col + 1
    while row < n:
      factor = grid[row][col] / grid[col][col]
      var cleared = _setAt(grid[row], col, factor)
      var k = col + 1
      while k < n:
        cleared = _setAt(cleared, k, cleared[k] - factor * grid[col][k])
        k = k + 1
      grid = _replaceRow(grid, row, cleared)
      row = row + 1
    col = col + 1
  var lower = _filled(n, n, 0.0)
  var upper = _filled(n, n, 0.0)
  var r = 0
  while r < n:
    var c = 0
    while c < n:
      if r > c: lower = _put(lower, r, c, grid[r][c])
      else: upper = _put(upper, r, c, grid[r][c])
      c = c + 1
    lower = _put(lower, r, r, 1.0)
    r = r + 1
  return LU(permutation: perm, lower: lower, upper: upper)

# Solves factors.matrix * x = [values], where [factors] came from [lu].
# Example:
#   print luSolve(lu([[2.0, 0.0], [0.0, 3.0]]), [4.0, 9.0])[0]
luSolve(factors: LU, values: List<double>) -> List<double>:
  n = values.length
  if factors.lower.length != n or factors.permutation.length != n:
    throw "luSolve needs a matching right-hand side"
  permuted: List<double> = []
  var i = 0
  while i < n:
    permuted.add(values[factors.permutation[i]])
    i = i + 1
  forward: List<double> = []
  i = 0
  while i < n:
    var total = permuted[i]
    var j = 0
    while j < i:
      total = total - factors.lower[i][j] * forward[j]
      j = j + 1
    forward.add(total)
    i = i + 1
  var answer: List<double> = []
  i = 0
  while i < n:
    answer.add(0.0)
    i = i + 1
  i = n - 1
  while i >= 0:
    var total = forward[i]
    var j = i + 1
    while j < n:
      total = total - factors.upper[i][j] * answer[j]
      j = j + 1
    diag = factors.upper[i][i]
    if diag == 0.0: throw "luSolve needs a nonzero pivot"
    answer = _setAt(answer, i, total / diag)
    i = i - 1
  return answer

# Eigenvalues and eigenvectors of a real symmetric matrix.
# [values] are ascending. Column i of [vectors] belongs to values[i].
# Example:
#   print eigenSymmetric([[2.0, 1.0], [1.0, 2.0]]).values[1]
value class Eigen:
  values: List<double>
  vectors: List<List<double>>

# Jacobi eigenvalues. The matrix must be symmetric.
# Example:
#   print eigenSymmetric([[2.0, 0.0], [0.0, 5.0]]).values[0]
eigenSymmetric(rows: List<List<double>>) -> Eigen:
  var grid = _squareCopy(rows)
  n = grid.length
  if n == 0: throw "eigenSymmetric needs a matrix"
  scale = _matrixScale(grid)
  if scale > 0.0: grid = _divideMatrix(grid, scale)
  var i = 0
  while i < n:
    var j = i + 1
    while j < n:
      if _abs(grid[i][j] - grid[j][i]) > 1.0e-8:
        throw "eigenSymmetric needs a symmetric matrix"
      j = j + 1
    i = i + 1
  var vectors = identity(n)
  var sweeps = 0
  var limit = n * n * 30
  if limit < 30: limit = 30
  var biggest = 0.0
  while sweeps < limit:
    var p = 0
    var q = 0
    biggest = 0.0
    i = 0
    while i < n:
      var j = i + 1
      while j < n:
        mag = _abs(grid[i][j])
        if mag > biggest:
          biggest = mag
          p = i
          q = j
        j = j + 1
      i = i + 1
    if biggest <= 1.0e-12: sweeps = limit
    else:
      app = grid[p][p]
      aqq = grid[q][q]
      apq = grid[p][q]
      diag = (aqq - app) / (2.0 * apq)
      root = math.sqrt(1.0 + diag * diag)
      var t = 1.0 / (diag + root)
      if diag < 0.0: t = 0.0 - 1.0 / (0.0 - diag + root)
      c = 1.0 / math.sqrt(1.0 + t * t)
      s = t * c
      var next = _rectCopy(grid)
      var k = 0
      while k < n:
        if k != p and k != q:
          aik = grid[k][p]
          akq = grid[k][q]
          kp = c * aik - s * akq
          kq = s * aik + c * akq
          next = _put(next, k, p, kp)
          next = _put(next, p, k, kp)
          next = _put(next, k, q, kq)
          next = _put(next, q, k, kq)
        k = k + 1
      next = _put(next, p, p, app - t * apq)
      next = _put(next, q, q, aqq + t * apq)
      next = _put(next, p, q, 0.0)
      next = _put(next, q, p, 0.0)
      var nextV = _rectCopy(vectors)
      k = 0
      while k < n:
        vip = vectors[k][p]
        viq = vectors[k][q]
        nextV = _put(nextV, k, p, c * vip - s * viq)
        nextV = _put(nextV, k, q, s * vip + c * viq)
        k = k + 1
      grid = next
      vectors = nextV
      sweeps = sweeps + 1
  if biggest > 1.0e-8: throw "eigenSymmetric did not converge"
  var vals: List<double> = []
  i = 0
  while i < n:
    vals.add(grid[i][i] * scale)
    i = i + 1
  i = 0
  while i < n:
    var j = i + 1
    while j < n:
      if vals[j] < vals[i]:
        vals = _swapDoubles(vals, i, j)
        vectors = _swapColumns(vectors, i, j)
      j = j + 1
    i = i + 1
  return Eigen(values: vals, vectors: vectors)

# Thin singular value decomposition. [values] descend.
# Column i of [u] and of [v] belongs to values[i].
# Example:
#   print svd([[3.0, 0.0], [0.0, 4.0]]).values[0]
value class SVD:
  u: List<List<double>>
  values: List<double>
  v: List<List<double>>

# One-sided Jacobi SVD: avoids squaring the condition number in A transpose A.
# Example:
#   print svd([[5.0]]).values[0]
svd(rows: List<List<double>>) -> SVD:
  original = _rectCopy(rows)
  m = original.length
  n = original[0].length
  if m < n:
    tall = svd(transpose(original))
    return SVD(u: tall.v, values: tall.values, v: tall.u)
  scale = _matrixScale(original)
  var work = original
  if scale > 0.0: work = _divideMatrix(original, scale)
  var vectors = identity(n)
  var sweep = 0
  var changed = true
  while changed and sweep < 100:
    changed = false
    var p = 0
    while p < n:
      var q = p + 1
      while q < n:
        left = _column(work, p)
        right = _column(work, q)
        aa = dot(left, left)
        bb = dot(right, right)
        ab = dot(left, right)
        if aa > 0.0 and bb > 0.0 and _abs(ab) > 1.0e-14 * math.sqrt(aa) * math.sqrt(bb):
          jacobiTau = (bb - aa) / (2.0 * ab)
          var t = 1.0 / (_abs(jacobiTau) + hypot(1.0, jacobiTau))
          if jacobiTau < 0.0: t = 0.0 - t
          c = 1.0 / hypot(1.0, t)
          sn = t * c
          work = _setColumn(work, p, _axpy(_scaleList(left, c), right, 0.0 - sn))
          work = _setColumn(work, q, _axpy(_scaleList(right, c), left, sn))
          vp = _column(vectors, p)
          vq = _column(vectors, q)
          vectors = _setColumn(vectors, p, _axpy(_scaleList(vp, c), vq, 0.0 - sn))
          vectors = _setColumn(vectors, q, _axpy(_scaleList(vq, c), vp, sn))
          changed = true
        q = q + 1
      p = p + 1
    sweep = sweep + 1
  if changed: throw "svd did not converge"
  var values: List<double> = []
  var i = 0
  while i < n:
    values.add(vectorLength(_column(work, i)))
    i = i + 1
  i = 0
  while i < n:
    var j = i + 1
    while j < n:
      if values[j] > values[i]:
        values = _swapDoubles(values, i, j)
        work = _swapColumns(work, i, j)
        vectors = _swapColumns(vectors, i, j)
      j = j + 1
    i = i + 1
  var u = _filled(m, n, 0.0)
  sigmas: List<double> = []
  i = 0
  while i < n:
    if values[i] > 0.0:
      u = _setColumn(u, i, _divideVector(_column(work, i), values[i]))
    else:
      u = _setColumn(u, i, _orthogonalColumn(u, i))
    sigmas.add(values[i] * scale)
    i = i + 1
  return SVD(u: u, values: sigmas, v: vectors)

# Moore-Penrose inverse from the thin SVD. Tiny singular values are dropped.
# Example:
#   print pseudoinverse([[2.0, 0.0], [0.0, 4.0]])[0][0]
pseudoinverse(rows: List<List<double>>) -> List<List<double>>:
  factors = svd(rows)
  k = factors.values.length
  m = rows.length
  var tol = 0.0
  if k > 0: tol = 1.0e-10 * factors.values[0]
  var middle = _filled(k, m, 0.0)
  var i = 0
  while i < k:
    var scale = 0.0
    if factors.values[i] > tol: scale = 1.0 / factors.values[i]
    middle = _replaceRow(middle, i, _scaleList(_column(factors.u, i), scale))
    i = i + 1
  return matmul(factors.v, middle)

# exp(A) by scaling and squaring a Taylor polynomial.
# Example:
#   print matrixExp([[0.0, 1.0], [0.0, 0.0]])[0][1]
matrixExp(rows: List<List<double>>) -> List<List<double>>:
  source = _squareCopy(rows)
  n = source.length
  var scaled = source
  var squares = 0
  var size = normInf(scaled)
  while size > 0.5 and squares < 24:
    scaled = scaleMatrix(scaled, 0.5)
    size = size * 0.5
    squares = squares + 1
  var term = identity(n)
  var sum = identity(n)
  var k = 1
  while k <= 16:
    term = scaleMatrix(matmul(term, scaled), 1.0 / (k to double))
    sum = addMatrices(sum, term)
    k = k + 1
  while squares > 0:
    sum = matmul(sum, sum)
    squares = squares - 1
  return sum

# Euclidean length of the largest singular value.
# Example:
#   print norm2([[3.0, 0.0], [0.0, 0.0 - 4.0]])
norm2(rows: List<List<double>>) -> double:
  values = svd(rows).values
  if values.isEmpty: return 0.0
  return values[0]

# Eigenvalues of a real square matrix, ordered by real part, then imaginary.
# Example:
#   print eigenvalues([[0.0, 0.0 - 1.0], [1.0, 0.0]])[1].imag
eigenvalues(rows: List<List<double>>) -> List<Complex>:
  return _qrEigen(rows)

# Eigenvalues and one eigenvector for each, for a real square matrix.
# Example:
#   print eigenGeneral([[2.0, 0.0], [0.0, 5.0]]).values[1].real
value class Spectrum:
  values: List<Complex>
  vectors: List<List<Complex>>

eigenGeneral(rows: List<List<double>>) -> Spectrum:
  values = eigenvalues(rows)
  var columns: List<List<Complex>> = []
  for value in values:
    columns.add(_eigenVector(rows, value))
  return Spectrum(values: values, vectors: columns)

# Principal square root of a matrix with no non-positive eigenvalues.
# Example:
#   print matrixSqrt([[4.0, 0.0], [0.0, 9.0]])[1][1]
matrixSqrt(rows: List<List<double>>) -> List<List<double>>:
  original = _squareCopy(rows)
  n = original.length
  scale = _matrixScale(original)
  if scale == 0.0: return _filled(n, n, 0.0)
  grid = _divideMatrix(original, scale)
  var y = grid
  var z = identity(n)
  var k = 0
  while k < 100:
    yNext = scaleMatrix(addMatrices(y, inverse(z)), 0.5)
    zNext = scaleMatrix(addMatrices(z, inverse(y)), 0.5)
    y = yNext
    z = zNext
    residual = normInf(subtractMatrices(matmul(y, y), grid))
    if residual <= 1.0e-13 * normInf(grid): return scaleMatrix(y, math.sqrt(scale))
    k = k + 1
  throw "matrixSqrt did not converge"

# Principal matrix logarithm. The spectrum must not meet the non-positive reals.
# Example:
#   print matrixLog(matrixExp([[0.0, 0.5], [0.0, 0.0]]))[0][1]
matrixLog(rows: List<List<double>>) -> List<List<double>>:
  var scaled = _squareCopy(rows)
  n = scaled.length
  _matrixScale(scaled)
  var count = 0
  while normInf(subtractMatrices(scaled, identity(n))) > 0.5 and count < 60:
    scaled = matrixSqrt(scaled)
    count = count + 1
  if count == 60: throw "matrixLog did not converge"
  z = matmul(subtractMatrices(scaled, identity(n)), inverse(addMatrices(scaled, identity(n))))
  zz = matmul(z, z)
  var term = z
  var total = z
  var k = 1
  while k <= 32:
    term = matmul(term, zz)
    total = addMatrices(total, scaleMatrix(term, 1.0 / ((2 * k + 1) to double)))
    if normInf(term) <= 1.0e-16 * (1.0 + normInf(total)):
      return scaleMatrix(total, math.pow(2.0, count + 1) to double)
    k = k + 1
  throw "matrixLog series did not converge"

# Conjugate gradient for a symmetric positive definite system.
# Example:
#   print conjugateGradient([[4.0, 1.0], [1.0, 3.0]], [1.0, 2.0])[0]
_conjugateGradientUnit(
    rows: List<List<double>>, values: List<double>) -> List<double>:
  grid = _squareCopy(rows)
  n = grid.length
  if values.length != n: throw "conjugateGradient needs one value per row"
  var x = _zeroDoubles(n)
  var residual = _axpy(values, matvec(grid, x), 0.0 - 1.0)
  var direction = _copyDoubles(residual)
  var rr = dot(residual, residual)
  var guard = 0
  while guard < n * 4 and rr > 1.0e-20:
    image = matvec(grid, direction)
    denom = dot(direction, image)
    if denom <= 0.0: throw "conjugateGradient needs a positive definite matrix"
    alpha = rr / denom
    x = _axpy(x, direction, alpha)
    residual = _axpy(residual, image, 0.0 - alpha)
    next = dot(residual, residual)
    direction = _axpy(residual, direction, next / rr)
    rr = next
    guard = guard + 1
  return x

# Solves a tridiagonal system. [below] and [above] have one fewer entry than [diag].
# Example:
#   print tridiagonalSolve([1.0, 1.0], [2.0, 2.0, 2.0], [1.0, 1.0], [1.0, 0.0, 1.0])[1]
tridiagonalSolve(
    below: List<double>,
    diag: List<double>,
    above: List<double>,
    rhs: List<double>) -> List<double>:
  n = diag.length
  if rhs.length != n or below.length != n - 1 or above.length != n - 1:
    throw "tridiagonalSolve needs matching lengths"
  if n < 1: throw "tridiagonalSolve needs an equation"
  var upper = _copyDoubles(above)
  var scaled = _copyDoubles(rhs)
  if diag[0] == 0.0: throw "tridiagonalSolve needs a nonzero diagonal"
  scaled = _setAt(scaled, 0, rhs[0] / diag[0])
  if n > 1: upper = _setAt(upper, 0, above[0] / diag[0])
  var i = 1
  while i < n:
    denom = diag[i] - below[i - 1] * upper[i - 1]
    if denom == 0.0: throw "tridiagonalSolve needs a nonzero diagonal"
    if i < n - 1: upper = _setAt(upper, i, above[i] / denom)
    scaled = _setAt(scaled, i, (rhs[i] - below[i - 1] * scaled[i - 1]) / denom)
    i = i + 1
  var answer = _copyDoubles(scaled)
  var k = n - 2
  while k >= 0:
    answer = _setAt(answer, k, scaled[k] - upper[k] * answer[k + 1])
    k = k - 1
  return answer

# Product of a coordinate matrix and a vector. Equal-length index lists.
# Example:
#   print sparseMatvec([0, 1], [0, 1], [4.0, 3.0], [1.0, 2.0])[1]
sparseMatvec(
    rowIndex: List<int>,
    columnIndex: List<int>,
    entries: List<double>,
    vector: List<double>) -> List<double>:
  if rowIndex.length != columnIndex.length or rowIndex.length != entries.length:
    throw "sparseMatvec needs one entry per index"
  var made = _zeroDoubles(vector.length)
  var k = 0
  while k < entries.length:
    row = rowIndex[k]
    column = columnIndex[k]
    if row < 0 or column < 0 or row >= vector.length or column >= vector.length:
      throw "sparseMatvec index is outside the vector"
    made = _setAt(made, row, made[row] + entries[k] * vector[column])
    k = k + 1
  return made

# Conjugate gradient for a symmetric positive definite coordinate matrix.
# Example:
#   print sparseConjugateGradient([0, 1, 0, 1], [0, 1, 1, 0], [4.0, 3.0, 1.0, 1.0], [1.0, 2.0], 2)[0]
_sparseConjugateGradientUnit(
    rowIndex: List<int>,
    columnIndex: List<int>,
    entries: List<double>,
    values: List<double>,
    size: int) -> List<double>:
  if values.length != size: throw "sparseConjugateGradient needs one value per row"
  var x = _zeroDoubles(size)
  var residual = _axpy(values, sparseMatvec(rowIndex, columnIndex, entries, x),
  0.0 - 1.0)
  var direction = _copyDoubles(residual)
  var rr = dot(residual, residual)
  var guard = 0
  while guard < size * 4 and rr > 1.0e-20:
    image = sparseMatvec(rowIndex, columnIndex, entries, direction)
    denom = dot(direction, image)
    if denom <= 0.0: throw "sparseConjugateGradient needs a positive definite matrix"
    alpha = rr / denom
    x = _axpy(x, direction, alpha)
    residual = _axpy(residual, image, 0.0 - alpha)
    next = dot(residual, residual)
    direction = _axpy(residual, direction, next / rr)
    rr = next
    guard = guard + 1
  return x

# Conjugate gradient for a symmetric positive definite system.
# Example:
#   print conjugateGradient([[4.0, 1.0], [1.0, 3.0]], [1.0, 2.0])[0]
conjugateGradient(rows: List<List<double>>, values: List<double>) -> List<double>:
  return _solveScaled(rows, values, 0)

# BiCGSTAB solution, with relative residual validation.
# Example:
#   print bicgstab([[1.0, 2.0], [3.0, 4.0]], [5.0, 6.0])[0]
bicgstab(rows: List<List<double>>, values: List<double>) -> List<double>:
  return _solveScaled(rows, values, 1)

# GMRES solution, with scaling and relative residual validation.
# Example:
#   print gmres([[4.0, 1.0], [1.0, 3.0]], [1.0, 2.0])[0]
gmres(rows: List<List<double>>, values: List<double>) -> List<double>:
  return _solveScaled(rows, values, 2)

_solveScaled(rows: List<List<double>>, values: List<double>, method: int) -> List<double>:
  grid = _squareCopy(rows)
  if values.length != grid.length: throw "solver needs one value per row"
  aScale = _matrixScale(grid)
  var bScale = 0.0
  for value in values:
    if not _finite(value): throw "solver values must be finite"
    if _abs(value) > bScale: bScale = _abs(value)
  if bScale == 0.0: return _zeroDoubles(values.length)
  if aScale == 0.0: throw "system is singular"
  a = _divideMatrix(grid, aScale)
  b = _divideVector(values, bScale)
  var answer: List<double> = []
  if method == 0: answer = _conjugateGradientUnit(a, b)
  else:
    if method == 1: answer = _bicgstabUnit(a, b)
    else: answer = _gmresUnit(a, b)
  residual = vectorLength(_axpy(matvec(a, answer), b, -1.0))
  if not _finite(residual) or residual > 1.0e-8 * (1.0 + vectorLength(b)):
    throw "iterative solver did not converge"
  made: List<double> = []
  for value in answer:
    made.add(_scaleRatio(value, bScale, aScale))
  return made

_sameSign(a: double, b: double) -> bool:
  return (a > 0.0 and b > 0.0) or (a < 0.0 and b < 0.0)

_differentSigns(a: double, b: double) -> bool:
  return (a > 0.0 and b < 0.0) or (a < 0.0 and b > 0.0)

_scaleRatio(coefficient: double, numerator: double, denominator: double) -> double:
  if coefficient == 0.0: return coefficient
  ratio = numerator / denominator
  if _finite(ratio) and ratio != 0.0: return coefficient * ratio
  return (coefficient * numerator) / denominator

_spread(values: List<double>, denominator: double) -> double:
  center = mean(values)
  scale = math.sqrt(denominator)
  var total = 0.0
  for value in values:
    total = hypot(total, _differenceRatio(value, center, scale))
  return total

_differenceRatio(left: double, right: double, scale: double) -> double:
  delta = left - right
  if _finite(delta): return delta / scale
  return left / scale - right / scale

_tieCubic(values: List<double>) -> double:
  ordered = _copyDoubles(values)
  ordered.sort()
  var i = 0
  var total = 0.0
  while i < ordered.length:
    var j = i + 1
    while j < ordered.length and ordered[j] == ordered[i]:
      j = j + 1
    count = (j - i) to double
    total = total + count * (count - 1.0) * (count + 1.0)
    i = j
  return total

# Conjugate gradient on a symmetric positive definite coordinate matrix.
# Example:
#   print sparseConjugateGradient([0, 1], [0, 1], [4.0, 3.0], [1.0, 2.0], 2)[0]
sparseConjugateGradient(rowIndex: List<int>, columnIndex: List<int>, entries: List<double>, values: List<double>, size: int) -> List<double>:
  if values.length != size: throw "sparseConjugateGradient needs one value per row"
  if rowIndex.length != columnIndex.length or rowIndex.length != entries.length:
    throw "sparseConjugateGradient needs matching coordinates"
  var aScale = 0.0
  var bScale = 0.0
  for entry in entries:
    if not _finite(entry): throw "matrix entries must be finite"
    if _abs(entry) > aScale: aScale = _abs(entry)
  for value in values:
    if not _finite(value): throw "solver values must be finite"
    if _abs(value) > bScale: bScale = _abs(value)
  if bScale == 0.0: return _zeroDoubles(size)
  if aScale == 0.0: throw "system is singular"
  scaled = _divideVector(entries, aScale)
  rhs = _divideVector(values, bScale)
  answer = _sparseConjugateGradientUnit(rowIndex, columnIndex, scaled, rhs, size)
  residual = vectorLength(_axpy(sparseMatvec(rowIndex, columnIndex, scaled, answer), rhs, -1.0))
  if not _finite(residual) or residual > 1.0e-8 * (1.0 + vectorLength(rhs)):
    throw "sparse solver did not converge"
  made: List<double> = []
  for value in answer:
    made.add(_scaleRatio(value, bScale, aScale))
  return made

# Compressed-row pattern built once. [builds] stays 1: later products read this
# pattern and allocate only the output vector. [rowStart] has size+1 entries.
class SparseMatrix:
  var builds: int = 1
  var size: int = 0
  rowStart: List<int>
  columns: List<int>
  entries: List<double>

# One coordinate pass builds the pattern. Duplicate positions stay separate.
# Example:
#   print sparseMatrix(2, [0, 1], [0, 1], [4.0, 3.0]).builds
sparseMatrix(size: int, rowIndex: List<int>, columnIndex: List<int>, entries: List<double>) -> SparseMatrix:
  if size < 0 or size > 256: throw "sparseMatrix size must be from 0 through 256"
  if rowIndex.length != columnIndex.length or rowIndex.length != entries.length:
    throw "sparseMatrix needs one entry per index"
  if entries.length > 4096: throw "sparseMatrix exceeds the work limit"
  var counts = _zeroInts(size)
  var index = 0
  while index < entries.length:
    row = rowIndex[index]
    column = columnIndex[index]
    if row < 0 or column < 0 or row >= size or column >= size: throw "sparseMatrix index is outside the matrix"
    if not _finite(entries[index]): throw "matrix entries must be finite"
    counts = _setInt(counts, row, counts[row] + 1)
    index += 1
  var rowStart = _zeroInts(size + 1)
  var row = 0
  while row < size:
    rowStart = _setInt(rowStart, row + 1, rowStart[row] + counts[row])
    row += 1
  var cursor = _zeroInts(size)
  var columns = _zeroInts(entries.length)
  var stored: List<double> = []
  var fill = 0
  while fill < entries.length:
    stored.add(0.0)
    fill += 1
  index = 0
  while index < entries.length:
    row = rowIndex[index]
    place = rowStart[row] + cursor[row]
    columns = _setInt(columns, place, columnIndex[index])
    stored = _setAt(stored, place, entries[index])
    cursor = _setInt(cursor, row, cursor[row] + 1)
    index += 1
  return SparseMatrix(builds: 1, size: size, rowStart: rowStart, columns: columns, entries: stored)

# Product using the stored pattern. Does not allocate another copy of the indices.
sparseMultiply(matrix: SparseMatrix, vector: List<double>) -> List<double>:
  if vector.length != matrix.size: throw "sparseMultiply needs one value per row"
  var made = _zeroDoubles(matrix.size)
  var row = 0
  while row < matrix.size:
    var cursor = matrix.rowStart[row]
    var stop = matrix.rowStart[row + 1]
    var total = 0.0
    while cursor < stop:
      total = total + matrix.entries[cursor] * vector[matrix.columns[cursor]]
      cursor += 1
    made = _setAt(made, row, total)
    row += 1
  return made

# Euclidean residual ||A x - b||. The pattern is not rebuilt.
sparseResidual(matrix: SparseMatrix, solution: List<double>, rhs: List<double>) -> double:
  if rhs.length != matrix.size: throw "sparseResidual needs one value per row"
  image = sparseMultiply(matrix, solution)
  return vectorLength(_axpy(image, rhs, -1.0))

_adaptEstimate(f: (double) -> double, a: double, b: double, eps: double, whole: double, depth: int) -> Estimate:
  mid = (a + b) / 2.0
  left = _simpson3(f, a, mid)
  right = _simpson3(f, mid, b)
  delta = left + right - whole
  if not _finite(delta): throw "non-finite integrand or quadrature overflow"
  if _abs(delta) <= 15.0 * eps:
    return Estimate(value: left + right + delta / 15.0, error: _abs(delta) / 15.0)
  if depth >= 18: throw "adaptive integration did not converge"
  l = _adaptEstimate(f, a, mid, eps / 2.0, left, depth + 1)
  r = _adaptEstimate(f, mid, b, eps / 2.0, right, depth + 1)
  return Estimate(value: l.value + r.value, error: l.error + r.error)

# VM integers are signed 64-bit; JavaScript uses exactly representable integers
# through 2^53-1. Detect its rounding without emitting an unsafe int literal.
_maxInt() -> int:
  safe = 9007199254740991
  if safe + 1 == safe + 2: return safe
  return safe * 1024 + 1023

_minInt() -> int:
  largest = _maxInt()
  if largest == 9007199254740991: return 0 - largest
  return 0 - largest - 1

:: polynomial

# Coefficients are constant-term first: index k belongs to x^k.
# Example:
#   print polyEval([1.0, 2.0, 3.0], 2.0)
polyEval(coeffs: List<double>, x: double) -> double:
  if coeffs.isEmpty: return 0.0
  var total = 0.0
  var i = coeffs.length - 1
  while i >= 0:
    total = total * x + coeffs[i]
    i = i - 1
  return total

# Derivative of a polynomial, still constant-term first.
# Example:
#   print polyDerivative([1.0, 2.0, 3.0])[1]
polyDerivative(coeffs: List<double>) -> List<double>:
  made: List<double> = []
  var i = 1
  while i < coeffs.length:
    made.add((i to double) * coeffs[i])
    i = i + 1
  if made.isEmpty: made.add(0.0)
  return made

# Roots of a x^2 + b x + c, ordered by real part, then imaginary part.
# Example:
#   print quadraticRoots(1.0, 0.0 - 3.0, 2.0)[0].real
quadraticRoots(a: double, b: double, c: double) -> List<Complex>:
  scale = max(_abs(a), max(_abs(b), _abs(c)))
  if scale == 0.0: throw "zero polynomial has no isolated roots"
  aa = a / scale
  bb = b / scale
  cc = c / scale
  if a == 0.0:
    if b == 0.0: throw "constant polynomial has no roots"
    return [Complex(real: -cc / bb, imag: 0.0)]
  disc = bb * bb - 4.0 * aa * cc
  roots: List<Complex> = []
  if disc >= 0.0:
    rad = math.sqrt(disc)
    var signed = rad
    if bb < 0.0: signed = -rad
    q = -0.5 * (bb + signed)
    if q == 0.0:
      roots.add(Complex(real: -bb / (2.0 * aa), imag: 0.0))
      roots.add(Complex(real: -bb / (2.0 * aa), imag: 0.0))
    else:
      roots.add(Complex(real: q / aa, imag: 0.0))
      roots.add(Complex(real: cc / q, imag: 0.0))
  else:
    realPart = -bb / (2.0 * aa)
    imagPart = math.sqrt(-disc) / (2.0 * _abs(aa))
    roots.add(Complex(real: realPart, imag: -imagPart))
    roots.add(Complex(real: realPart, imag: imagPart))
  return _sortRoots(roots)

# Roots of a x^3 + b x^2 + c x + d. A leading zero falls back to quadratic.
# Example:
#   print cubicRoots(1.0, 0.0 - 6.0, 11.0, 0.0 - 6.0)[1].real
cubicRoots(a: double, b: double, c: double, d: double) -> List<Complex>:
  if a == 0.0: return quadraticRoots(b, c, d)
  aa = b / a
  bb = c / a
  cc = d / a
  shift = aa / 3.0
  p = bb - aa * aa / 3.0
  q = cc + 2.0 * aa * aa * aa / 27.0 - aa * bb / 3.0
  disc = q * q / 4.0 + p * p * p / 27.0
  roots: List<Complex> = []
  if disc > 1.0e-15 * (_abs(q * q / 4.0) + _abs(p * p * p / 27.0)):
    s = math.sqrt(disc)
    u = cbrt(0.0 - q / 2.0 + s)
    v = cbrt(0.0 - q / 2.0 - s)
    first = u + v
    real2 = 0.0 - first / 2.0
    imag2 = (u - v) * math.sqrt(3.0) / 2.0
    roots.add(Complex(real: first - shift, imag: 0.0))
    roots.add(Complex(real: real2 - shift, imag: imag2))
    roots.add(Complex(real: real2 - shift, imag: 0.0 - imag2))
  else:
    if p == 0.0:
      y = cbrt(0.0 - q)
      roots.add(Complex(real: y - shift, imag: 0.0))
      roots.add(Complex(real: y - shift, imag: 0.0))
      roots.add(Complex(real: y - shift, imag: 0.0))
    else:
      var angleArg = (0.0 - q / 2.0) / math.sqrt(0.0 - p * p * p / 27.0)
      if angleArg > 1.0: angleArg = 1.0
      if angleArg < 0.0 - 1.0: angleArg = 0.0 - 1.0
      theta = math.acos(angleArg)
      radius = 2.0 * math.sqrt(0.0 - p / 3.0)
      roots.add(Complex(
          real: radius * math.cos(theta / 3.0) - shift, imag: 0.0))
      roots.add(Complex(
          real: radius * math.cos(theta / 3.0 - 2.0 * math.pi / 3.0) - shift,
          imag: 0.0))
      roots.add(Complex(
          real: radius * math.cos(theta / 3.0 - 4.0 * math.pi / 3.0) - shift,
          imag: 0.0))
  return _sortRoots(roots)

# Lagrange interpolation of the pairs ([xs], [ys]) at [x].
# Example:
#   print lagrange(1.5, [1.0, 2.0], [10.0, 20.0])
lagrange(x: double, xs: List<double>, ys: List<double>) -> double:
  if xs.length != ys.length or xs.isEmpty: throw "lagrange needs matching lists"
  var total = 0.0
  var i = 0
  while i < xs.length:
    var term = ys[i]
    var j = 0
    while j < xs.length:
      if j != i:
        span = xs[i] - xs[j]
        if span == 0.0: throw "lagrange needs distinct xs"
        term = term * (x - xs[j]) / span
      j = j + 1
    total = total + term
    i = i + 1
  return total

# Sum of two polynomials, constant term first.
# Example:
#   print polyAdd([1.0, 2.0], [3.0])[0]
polyAdd(left: List<double>, right: List<double>) -> List<double>:
  return _trimPoly(_polyZip(left, right, 1.0))

# Difference of two polynomials, constant term first.
# Example:
#   print polySubtract([5.0, 1.0], [2.0])[0]
polySubtract(left: List<double>, right: List<double>) -> List<double>:
  return _trimPoly(_polyZip(left, right, 0.0 - 1.0))

# Product of two polynomials, constant term first.
# Example:
#   print polyMultiply([1.0, 2.0], [3.0, 4.0])[2]
polyMultiply(left: List<double>, right: List<double>) -> List<double>:
  if left.isEmpty or right.isEmpty: return [0.0]
  var made = _zeroDoubles(left.length + right.length - 1)
  var i = 0
  while i < left.length:
    var j = 0
    while j < right.length:
      made = _setAt(made, i + j, made[i + j] + left[i] * right[j])
      j = j + 1
    i = i + 1
  return _trimPoly(made)

# Quotient and remainder of two polynomials, constant term first.
# Example:
#   print polyDivide([3.0, 10.0, 8.0], [1.0, 2.0]).quotient[1]
value class Quotient:
  quotient: List<double>
  remainder: List<double>

polyDivide(dividend: List<double>, divisor: List<double>) -> Quotient:
  var rem = _trimPoly(dividend)
  v = _trimPoly(divisor)
  if v.length == 1 and _abs(v[0]) <= 1.0e-14: throw "polyDivide by zero"
  if rem.length < v.length: return Quotient(quotient: [0.0], remainder: rem)
  degV = v.length - 1
  var quot = _zeroDoubles(rem.length - v.length + 1)
  while rem.length - 1 >= degV and not _tinyPoly(rem):
    coef = rem[rem.length - 1] / v[v.length - 1]
    shift = rem.length - 1 - degV
    quot = _setAt(quot, shift, coef)
    saved = rem
    var i = 0
    while i < v.length:
      rem = _setAt(rem, i + shift, saved[i + shift] - coef * v[i])
      i = i + 1
    rem = _setAt(rem, rem.length - 1, 0.0)
    rem = _trimPoly(rem)
  return Quotient(quotient: _trimPoly(quot), remainder: rem)

# Monic greatest common divisor of two polynomials.
# Example:
#   print polyGcd([1.0, 0.0, 0.0 - 1.0], [1.0, 0.0 - 1.0])[1]
polyGcd(left: List<double>, right: List<double>) -> List<double>:
  var a = _trimPoly(left)
  var b = _trimPoly(right)
  var guard = 0
  while b.length > 1 or (b.length == 1 and _abs(b[0]) > 1.0e-10):
    if guard > 32: throw "polyGcd did not finish"
    parts = polyDivide(a, b)
    a = b
    b = _trimPoly(parts.remainder)
    guard = guard + 1
  return _monicPoly(a)

# All complex roots, ordered by real part, then imaginary part.
# Example:
#   print polyRoots([2.0, 0.0 - 3.0, 1.0])[0].real
polyRoots(coeffs: List<double>) -> List<Complex>:
  cleaned = _trimPoly(coeffs)
  if cleaned.length < 2: throw "polyRoots needs a degree"
  return _durand(cleaned)

# Natural cubic spline through the pairs ([xs], [ys]). [x] lies in the span.
# Example:
#   print spline(0.5, [0.0, 1.0, 2.0], [0.0, 1.0, 0.0])
spline(x: double, xs: List<double>, ys: List<double>) -> double:
  if xs.length != ys.length or xs.length < 2:
    throw "spline needs matching lists of at least two points"
  var i = 1
  while i < xs.length:
    if xs[i] <= xs[i - 1]: throw "spline needs strictly increasing xs"
    i = i + 1
  if x < xs[0] or x > xs[xs.length - 1]: throw "spline x is outside the span"
  moments = _splineMoments(xs, ys)
  var segment = 0
  while segment < xs.length - 2 and x > xs[segment + 1]:
    segment = segment + 1
  return _splinePiece(x, xs, ys, moments, segment)

# Least-squares polynomial, constant term first.
# Example:
#   print polyfit([0.0, 1.0], [1.0, 3.0], 1)[1]
polyfit(xs: List<double>, ys: List<double>, degree: int) -> List<double>:
  if degree < 0: throw "polyfit needs a non-negative degree"
  if xs.length != ys.length or xs.length <= degree:
    throw "polyfit needs more points than the degree"
  var grid: List<List<double>> = []
  for x in xs:
    var row: List<double> = []
    var power = 1.0
    var k = 0
    while k <= degree:
      row.add(power)
      power = power * x
      k = k + 1
    grid.add(row)
  return leastSquares(grid, ys)

:: signal

# Discrete Fourier transform. The length must be a positive power of two.
# Example:
#   print fft([Complex(real: 1.0, imag: 0.0), Complex(real: 0.0, imag: 0.0), Complex(real: 0.0, imag: 0.0), Complex(real: 0.0, imag: 0.0)])[0].real
fft(values: List<Complex>) -> List<Complex>:
  return _transform(values, 0.0 - 1.0)

# Inverse of [fft]. A round trip returns the original samples.
# Example:
#   print ifft(fft([Complex(real: 1.0, imag: 0.0), Complex(real: 1.0, imag: 0.0), Complex(real: 1.0, imag: 0.0), Complex(real: 1.0, imag: 0.0)]))[0].real
ifft(values: List<Complex>) -> List<Complex>:
  return _transform(values, 1.0)

# [fft] of real samples, with a zero imaginary part.
# Example:
#   print fftReal([1.0, 1.0, 1.0, 1.0])[0].real
fftReal(values: List<double>) -> List<Complex>:
  made: List<Complex> = []
  for value in values:
    made.add(Complex(real: value, imag: 0.0))
  return fft(made)

# Linear convolution. The result has length left + right - 1.
# Example:
#   print convolve([1.0, 2.0], [3.0, 4.0])[1]
convolve(left: List<double>, right: List<double>) -> List<double>:
  if left.isEmpty or right.isEmpty: throw "convolve needs non-empty lists"
  n = left.length + right.length - 1
  made: List<double> = []
  var k = 0
  while k < n:
    var total = 0.0
    var i = 0
    while i < left.length:
      j = k - i
      if j >= 0 and j < right.length: total = total + left[i] * right[j]
      i = i + 1
    made.add(total)
    k = k + 1
  return made

# Fourier transform of any positive length.
# Example:
#   print fftAny([Complex(real: 1.0, imag: 0.0), Complex(real: 0.0, imag: 0.0), Complex(real: 0.0, imag: 0.0)])[1].real
fftAny(values: List<Complex>) -> List<Complex>:
  return _chirpTransform(values, 0.0 - 1.0)

# Inverse of [fftAny].
# Example:
#   print ifftAny(fftAny([Complex(real: 1.0, imag: 0.0), Complex(real: 2.0, imag: 0.0), Complex(real: 3.0, imag: 0.0)]))[1].real
ifftAny(values: List<Complex>) -> List<Complex>:
  return _chirpTransform(values, 1.0)

# Convolution through the Fourier transform.
# Example:
#   print fftConvolve([1.0, 2.0], [3.0, 4.0])[1]
fftConvolve(left: List<double>, right: List<double>) -> List<double>:
  if left.isEmpty or right.isEmpty: throw "fftConvolve needs non-empty lists"
  n = left.length + right.length - 1
  var m = 1
  while m < n:
    m = m * 2
  var a: List<Complex> = []
  var b: List<Complex> = []
  var i = 0
  while i < m:
    var ar = 0.0
    var br = 0.0
    if i < left.length: ar = left[i]
    if i < right.length: br = right[i]
    a.add(Complex(real: ar, imag: 0.0))
    b.add(Complex(real: br, imag: 0.0))
    i = i + 1
  fa = fft(a)
  fb = fft(b)
  var prod: List<Complex> = []
  i = 0
  while i < m:
    prod.add(fa[i] * fb[i])
    i = i + 1
  back = ifft(prod)
  made: List<double> = []
  i = 0
  while i < n:
    made.add(back[i].real)
    i = i + 1
  return made

# Unnormalized DCT-II.
# Example:
#   print dct([1.0, 0.0])[1]
dct(values: List<double>) -> List<double>:
  if values.isEmpty: throw "dct needs a sample"
  n = values.length
  made: List<double> = []
  var k = 0
  while k < n:
    var total = 0.0
    var i = 0
    while i < n:
      angle = math.pi / (n to double) * ((i to double) + 0.5) * (k to double)
      total = total + values[i] * math.cos(angle)
      i = i + 1
    made.add(total)
    k = k + 1
  return made

# Two-dimensional Fourier transform. Each row has the same length.
# Example:
#   print fft2([[Complex(real: 1.0, imag: 0.0), Complex(real: 0.0, imag: 0.0)], [Complex(real: 0.0, imag: 0.0), Complex(real: 0.0, imag: 0.0)]])[0][1].real
fft2(rows: List<List<Complex>>) -> List<List<Complex>>:
  if rows.isEmpty or rows[0].isEmpty: throw "fft2 needs a matrix"
  width = rows[0].length
  var wide: List<List<Complex>> = []
  for row in rows:
    if row.length != width: throw "fft2 needs a rectangular matrix"
    wide.add(fftAny(row))
  var out: List<List<Complex>> = []
  var r = 0
  while r < wide.length:
    var blank: List<Complex> = []
    var c = 0
    while c < width:
      blank.add(Complex(real: 0.0, imag: 0.0))
      c = c + 1
    out.add(blank)
    r = r + 1
  var col = 0
  while col < width:
    var column: List<Complex> = []
    for row in wide:
      column.add(row[col])
    transformed = fftAny(column)
    var rowIndex = 0
    while rowIndex < transformed.length:
      out = _putCGrid(out, rowIndex, col, transformed[rowIndex])
      rowIndex = rowIndex + 1
    col = col + 1
  return out

# Inverse of the unnormalized DCT-II from [dct].
# Example:
#   print idct(dct([1.0, 2.0]))[1]
idct(values: List<double>) -> List<double>:
  if values.isEmpty: throw "idct needs a sample"
  n = values.length
  made: List<double> = []
  var i = 0
  while i < n:
    var total = values[0]
    var k = 1
    while k < n:
      angle = math.pi / (n to double) * ((i to double) + 0.5) * (k to double)
      total = total + 2.0 * values[k] * math.cos(angle)
      k = k + 1
    made.add(total / (n to double))
    i = i + 1
  return made

# Periodic Hann window.
# Example:
#   print hann(2)[1]
hann(n: int) -> List<double>:
  return _window(n, 0.5, 0.5, 0.0)

# Periodic Hamming window.
# Example:
#   print hamming(2)[0]
hamming(n: int) -> List<double>:
  return _window(n, 0.54, 0.46, 0.0)

# Periodic Blackman window.
# Example:
#   print blackman(2)[0]
blackman(n: int) -> List<double>:
  return _window(n, 0.42, 0.5, 0.08)

# Orthonormal Haar transform. The length must be a power of two.
# Example:
#   print inverseHaar(haar([1.0, 3.0, 2.0, 4.0]))[2]
haar(values: List<double>) -> List<double>:
  if values.isEmpty or not _powerOfTwo(values.length):
    throw "haar needs a positive power-of-two length"
  var data = _copyDoubles(values)
  var length = values.length
  while length > 1:
    half = length ~/ 2
    var next = _copyDoubles(data)
    var i = 0
    while i < half:
      a = data[2 * i]
      b = data[2 * i + 1]
      next = _setAt(next, i, (a + b) / math.sqrt(2.0))
      next = _setAt(next, half + i, (a - b) / math.sqrt(2.0))
      i = i + 1
    var j = 0
    while j < length:
      data = _setAt(data, j, next[j])
      j = j + 1
    length = half
  return data

# Inverse of [haar].
# Example:
#   print inverseHaar(haar([1.0, 3.0]))[0]
inverseHaar(values: List<double>) -> List<double>:
  if values.isEmpty or not _powerOfTwo(values.length):
    throw "inverseHaar needs a positive power-of-two length"
  var data = _copyDoubles(values)
  var length = 2
  while length <= values.length:
    half = length ~/ 2
    var next = _copyDoubles(data)
    var i = 0
    while i < half:
      a = data[i]
      b = data[half + i]
      next = _setAt(next, 2 * i, (a + b) / math.sqrt(2.0))
      next = _setAt(next, 2 * i + 1, (a - b) / math.sqrt(2.0))
      i = i + 1
    var j = 0
    while j < length:
      data = _setAt(data, j, next[j])
      j = j + 1
    length = length * 2
  return data

# Short-time transform. Each full frame is windowed, transformed by fft, then
# divided by the sum of the window. That window-sum normalization makes a
# constant signal of amplitude 1 have DC real part 1. No partial frame is
# padded. The window length must be a positive power of two, and hop at least 1.
# Example:
#   print stft([1.0, 1.0], [1.0, 1.0], 2)[0][0].real
stft(samples: List<double>, window: List<double>, hop: int) -> List<List<Complex>>:
  if window.isEmpty or not _powerOfTwo(window.length): throw "stft window must be a positive power of two"
  if hop < 1: throw "stft hop must be positive"
  var gain = 0.0
  for weight in window:
    if not _finite(weight): throw "stft window must be finite"
    gain = gain + weight
  if gain == 0.0: throw "stft window sum must be nonzero"
  frames: List<List<Complex>> = []
  var start = 0
  while start + window.length <= samples.length:
    frame: List<Complex> = []
    var index = 0
    while index < window.length:
      sample = samples[start + index]
      if not _finite(sample): throw "stft samples must be finite"
      frame.add(Complex(real: sample * window[index], imag: 0.0))
      index += 1
    spectrum = fft(frame)
    scaled: List<Complex> = []
    for bin in spectrum:
      scaled.add(Complex(real: bin.real / gain, imag: bin.imag / gain))
    frames.add(scaled)
    start += hop
  return frames

# Causal FIR. y[n] = sum_k coef[k] * x[n-k], with x before the start equal to 0.
# There is no hidden gain: firGain is the sum of the taps, which is the DC gain.
firFilter(samples: List<double>, coefficients: List<double>) -> List<double>:
  if coefficients.isEmpty: throw "firFilter needs coefficients"
  made: List<double> = []
  var index = 0
  while index < samples.length:
    var total = 0.0
    var tap = 0
    while tap < coefficients.length:
      source = index - tap
      if source >= 0: total = total + coefficients[tap] * samples[source]
      tap += 1
    made.add(total)
    index += 1
  return made

# Sum of FIR taps. This is the DC gain under the causal convention above.
firGain(coefficients: List<double>) -> double:
  var total = 0.0
  for coefficient in coefficients:
    total = total + coefficient
  return total

:: optimize

# A root of [f] bracketed by a sign change, by Brent's method.
# Example:
#   print brent((x: double) -> x - 2.0, 0.0, 4.0)
brent(
    f: (double) -> double,
    low: double,
    high: double,
    tolerance: double = 1.0e-10) -> double:
  if tolerance <= 0.0: throw "tolerance must be positive"
  var a = low
  var b = high
  var fa = f(a)
  var fb = f(b)
  if (fa > 0.0 and fb > 0.0) or (fa < 0.0 and fb < 0.0): throw "brent needs a sign change"
  if _abs(fa) < _abs(fb):
    saved = a
    a = b
    b = saved
    savedF = fa
    fa = fb
    fb = savedF
  var c = a
  var fc = fa
  var d = 0.0
  var bisecting = true
  var guard = 0
  while guard < 80 and fb != 0.0 and _abs(b - a) > tolerance:
    var s = 0.0
    if fa != fc and fb != fc:
      s = a * fb * fc / ((fa - fb) * (fa - fc))
      s = s + b * fa * fc / ((fb - fa) * (fb - fc))
      s = s + c * fa * fb / ((fc - fa) * (fc - fb))
    else: s = b - fb * (b - a) / (fb - fa)
    outside = (s - b) * (s - (3.0 * a + b) / 4.0) > 0.0
    far = bisecting and _abs(s - b) >= _abs(b - c) / 2.0
    farther = not bisecting and _abs(s - b) >= _abs(c - d) / 2.0
    tiny = bisecting and _abs(b - c) < tolerance
    tinier = not bisecting and _abs(c - d) < tolerance
    if outside or far or farther or tiny or tinier:
      s = (a + b) / 2.0
      bisecting = true
    else: bisecting = false
    fs = f(s)
    d = c
    c = b
    fc = fb
    if (fa < 0.0 and fs > 0.0) or (fa > 0.0 and fs < 0.0):
      b = s
      fb = fs
    else:
      a = s
      fa = fs
    if _abs(fa) < _abs(fb):
      saved = a
      a = b
      b = saved
      savedF = fa
      fa = fb
      fb = savedF
    guard = guard + 1
  return b

# Minimum of a unimodal [f] on a closed interval, by golden-section search.
# Example:
#   print minimize((x: double) -> (x - 3.0) * (x - 3.0), 0.0, 8.0)
minimize(
    f: (double) -> double,
    low: double,
    high: double,
    tolerance: double = 1.0e-8) -> double:
  if tolerance <= 0.0: throw "tolerance must be positive"
  if high < low: throw "minimize needs the low end first"
  ratio = (math.sqrt(5.0) + 1.0) / 2.0
  var a = low
  var b = high
  var guard = 0
  while b - a > tolerance and guard < 80:
    c = b - (b - a) / ratio
    d = a + (b - a) / ratio
    if f(c) < f(d): b = d
    else: a = c
    guard = guard + 1
  return (a + b) / 2.0

# Nonlinear least squares. [residual] maps parameters to residuals.
# Example:
#   print nonlinearFit((p: List<double>) -> [p[0] - 2.0, p[0] * 2.0 - 4.0], [0.0]).parameters[0]
value class Fit:
  parameters: List<double>
  cost: double

nonlinearFit(
    residual: (List<double>) -> List<double>,
    start: List<double>) -> Fit:
  if start.isEmpty: throw "nonlinearFit needs a parameter"
  var p = _copyDoubles(start)
  var lam = 1.0e-3
  var best = residual(p)
  var cost = dot(best, best)
  var guard = 0
  while guard < 24:
    jac = _residualJacobian(residual, p)
    gram = _gram(jac)
    slope = _applyTranspose(jac, best)
    var shifted = gram
    var i = 0
    while i < p.length:
      shifted = _put(shifted, i, i, gram[i][i] + lam)
      i = i + 1
    delta = solveLinear(shifted, slope)
    trial = _axpy(p, delta, 0.0 - 1.0)
    next = residual(trial)
    nextCost = dot(next, next)
    if nextCost < cost:
      p = trial
      best = next
      cost = nextCost
      lam = lam * 0.3
      if vectorLength(delta) < 1.0e-10: guard = 24
    else: lam = lam * 3.0
    guard = guard + 1
  return Fit(parameters: p, cost: cost)

# Nelder-Mead minimum of a scalar function of several reals.
# Example:
#   print nelderMead((p: List<double>) -> (p[0] - 2.0) * (p[0] - 2.0), [0.0])[0]
nelderMead(f: (List<double>) -> double, start: List<double>) -> List<double>:
  if start.isEmpty: throw "nelderMead needs a start"
  var points: List<List<double>> = []
  points.add(_copyDoubles(start))
  var i = 0
  while i < start.length:
    bumped = _setAt(start, i, start[i] + 0.1)
    points.add(bumped)
    i = i + 1
  var scores: List<double> = []
  for point in points:
    scores.add(f(point))
  var guard = 0
  var order = _orderScores(scores)
  while guard < 200:
    order = _orderScores(scores)
    best = order[0]
    worst = order[order.length - 1]
    var span = 0.0
    for point in points:
      gap = vectorLength(_axpy(point, points[best], 0.0 - 1.0))
      if gap > span: span = gap
    if span < 1.0e-8: guard = 200
    else:
      centroid = _simplexCentroid(points, worst)
      reflected = _axpy(centroid, _axpy(centroid, points[worst], 0.0 - 1.0),
      1.0)
      reflectScore = f(reflected)
      if reflectScore < scores[best]:
        expanded = _axpy(centroid, _axpy(reflected, centroid, 0.0 - 1.0), 2.0)
        if f(expanded) < reflectScore:
          points = _replaceRow(points, worst, expanded)
          scores = _setAt(scores, worst, f(expanded))
        else:
          points = _replaceRow(points, worst, reflected)
          scores = _setAt(scores, worst, reflectScore)
      else:
        second = order[order.length - 2]
        if reflectScore < scores[second]:
          points = _replaceRow(points, worst, reflected)
          scores = _setAt(scores, worst, reflectScore)
        else:
          var contracted = centroid
          if reflectScore < scores[worst]:
            contracted = _axpy(centroid, _axpy(reflected, centroid, 0.0 - 1.0),
            0.5)
          else:
            contracted = _axpy(centroid, _axpy(points[worst], centroid,
            0.0 - 1.0), 0.5)
          contractScore = f(contracted)
          var compared = scores[worst]
          if reflectScore < scores[worst]: compared = reflectScore
          if contractScore < compared:
            points = _replaceRow(points, worst, contracted)
            scores = _setAt(scores, worst, contractScore)
          else:
            var k = 0
            while k < points.length:
              if k != best:
                pulled = _axpy(points[best], _axpy(points[k], points[best],
                0.0 - 1.0), 0.5)
                points = _replaceRow(points, k, pulled)
                scores = _setAt(scores, k, f(pulled))
              k = k + 1
      guard = guard + 1
  order = _orderScores(scores)
  return points[order[0]]

# Maximum of costs · x subject to rows * x <= limits and x >= 0.
# Example:
#   print linearProgram([3.0, 2.0], [[1.0, 1.0], [1.0, 3.0]], [4.0, 6.0]).value
value class Optimum:
  value: double
  position: List<double>

linearProgram(
    costs: List<double>,
    rows: List<List<double>>,
    limits: List<double>) -> Optimum:
  if costs.isEmpty or rows.isEmpty or rows.length != limits.length:
    throw "linearProgram needs costs, constraints, and limits"
  m = rows.length
  n = costs.length
  width = n + m + 1
  var board = _filled(m + 1, width, 0.0)
  var basis = _zeroInts(m)
  var i = 0
  while i < m:
    if limits[i] < 0.0: throw "linearProgram needs non-negative limits"
    if rows[i].length != n: throw "linearProgram needs one column per cost"
    var j = 0
    while j < n:
      board = _put(board, i, j, rows[i][j])
      j = j + 1
    board = _put(board, i, n + i, 1.0)
    board = _put(board, i, width - 1, limits[i])
    basis = _setInt(basis, i, n + i)
    j = 0
    while j < n:
      board = _put(board, m, j, 0.0 - costs[j])
      j = j + 1
    i = i + 1
  var guard = 0
  var optimal = false
  while guard < 1000 * (n + m):
    var pivotColumn = 0 - 1
    var j = 0
    while j < width - 1:
      if pivotColumn < 0 and board[m][j] < -1.0e-12:
        pivotColumn = j
      j = j + 1
    if pivotColumn < 0:
      optimal = true
      guard = 1000 * (n + m)
    else:
      var pivotRow = 0 - 1
      var best = 0.0
      var seen = false
      i = 0
      while i < m:
        if board[i][pivotColumn] > 1.0e-12:
          ratio = board[i][width - 1] / board[i][pivotColumn]
          if not seen or ratio < best or (ratio == best and basis[i] < basis[pivotRow]):
            best = ratio
            pivotRow = i
            seen = true
        i = i + 1
      if pivotRow < 0: throw "linearProgram is unbounded"
      pivot = board[pivotRow][pivotColumn]
      var col = 0
      while col < width:
        board = _put(board, pivotRow, col, board[pivotRow][col] / pivot)
        col = col + 1
      i = 0
      while i <= m:
        if i != pivotRow:
          factor = board[i][pivotColumn]
          col = 0
          while col < width:
            board = _put(board, i, col,
            board[i][col] - factor * board[pivotRow][col])
            col = col + 1
        i = i + 1
      basis = _setInt(basis, pivotRow, pivotColumn)
      guard = guard + 1
  if not optimal: throw "linearProgram did not converge"
  var position = _zeroDoubles(n)
  i = 0
  while i < m:
    if basis[i] < n: position = _setAt(position, basis[i], board[i][width - 1])
    i = i + 1
  return Optimum(value: board[m][width - 1], position: position)

# Same shape as linearProgram, except a negative limit is allowed. Phase I
# minimizes the sum of artificial variables. A positive sum throws
# "linearProgramPhase is infeasible" and does not return a point. An unbounded
# ray throws. x stays nonnegative. At most 12 variables and 12 constraints.
# Example:
#   print linearProgramPhase([1.0], [[-1.0], [1.0]], [-1.0, 3.0]).value
linearProgramPhase(costs: List<double>, rows: List<List<double>>, limits: List<double>) -> Optimum:
  if costs.isEmpty or rows.isEmpty or rows.length != limits.length:
    throw "linearProgramPhase needs costs, constraints, and limits"
  m = rows.length
  n = costs.length
  if n > 12 or m > 12: throw "linearProgramPhase exceeds the work limit"
  var artificials = 0
  var i = 0
  while i < m:
    if rows[i].length != n: throw "linearProgramPhase needs one column per cost"
    if not _finite(limits[i]): throw "linearProgramPhase needs finite entries"
    if limits[i] < 0.0: artificials += 1
    var j = 0
    while j < n:
      if not _finite(rows[i][j]): throw "linearProgramPhase needs finite entries"
      j += 1
    i += 1
  for cost in costs:
    if not _finite(cost): throw "linearProgramPhase needs finite entries"
  width = n + m + artificials + 1
  var board = _filled(m + 1, width, 0.0)
  var basis = _zeroInts(m)
  var artColumn = n + m
  i = 0
  while i < m:
    var sign = 1.0
    var rhs = limits[i]
    if limits[i] < 0.0:
      sign = -1.0
      rhs = 0.0 - limits[i]
    var j = 0
    while j < n:
      board = _put(board, i, j, sign * rows[i][j])
      j += 1
    board = _put(board, i, n + i, sign)
    if limits[i] < 0.0:
      board = _put(board, i, artColumn, 1.0)
      basis = _setInt(basis, i, artColumn)
      artColumn += 1
    else:
      basis = _setInt(basis, i, n + i)
    board = _put(board, i, width - 1, rhs)
    i += 1
  var art = 0
  while art < artificials:
    board = _put(board, m, n + m + art, 1.0)
    art += 1
  i = 0
  while i < m:
    if basis[i] >= n + m:
      factor = board[m][basis[i]]
      var col = 0
      while col < width:
        board = _put(board, m, col, board[m][col] - factor * board[i][col])
        col += 1
    i += 1
  var solved = _phaseSimplex(board, basis, m, width)
  if solved.grid[m][width - 1] < 0.0 - 1.0e-7: throw "linearProgramPhase is infeasible"
  board = solved.grid
  basis = solved.basis
  var col = 0
  while col < width:
    board = _put(board, m, col, 0.0)
    col += 1
  var j = 0
  while j < n:
    board = _put(board, m, j, 0.0 - costs[j])
    j += 1
  i = 0
  while i < m:
    if basis[i] < n:
      factor = board[m][basis[i]]
      col = 0
      while col < width:
        board = _put(board, m, col, board[m][col] - factor * board[i][col])
        col += 1
    i += 1
  art = 0
  while art < artificials:
    board = _put(board, m, n + m + art, 1.0)
    art += 1
  solved = _phaseSimplex(board, basis, m, width)
  var position = _zeroDoubles(n)
  i = 0
  while i < m:
    if solved.basis[i] < n: position = _setAt(position, solved.basis[i], solved.grid[i][width - 1])
    i += 1
  return Optimum(value: solved.grid[m][width - 1], position: position)

class _PhaseState:
  grid: List<List<double>>
  basis: List<int>

_phaseSimplex(board: List<List<double>>, basis: List<int>, m: int, width: int) -> _PhaseState:
  var grid = board
  var base = basis
  var guard = 0
  var optimal = false
  limit = 1000 * width
  while guard < limit and not optimal:
    var column = 0 - 1
    var j = 0
    while j < width - 1:
      if column < 0 and grid[m][j] < 0.0 - 1.0e-9: column = j
      j += 1
    if column < 0:
      optimal = true
    else:
      var pivotRow = 0 - 1
      var best = 0.0
      var seen = false
      var i = 0
      while i < m:
        if grid[i][column] > 1.0e-12:
          ratio = grid[i][width - 1] / grid[i][column]
          var take = false
          if not seen: take = true
          else:
            if ratio < best - 1.0e-15: take = true
            else:
              if _abs(ratio - best) <= 1.0e-15 and base[i] < base[pivotRow]: take = true
          if take:
            best = ratio
            pivotRow = i
            seen = true
        i += 1
      if pivotRow < 0: throw "linearProgramPhase is unbounded"
      pivot = grid[pivotRow][column]
      var col = 0
      while col < width:
        grid = _put(grid, pivotRow, col, grid[pivotRow][col] / pivot)
        col += 1
      i = 0
      while i <= m:
        if i != pivotRow:
          factor = grid[i][column]
          col = 0
          while col < width:
            grid = _put(grid, i, col, grid[i][col] - factor * grid[pivotRow][col])
            col += 1
        i += 1
      base = _setInt(base, pivotRow, column)
      guard += 1
  if not optimal: throw "linearProgramPhase did not converge"
  return _PhaseState(grid: grid, basis: base)

:: special

# Riemann zeta for real [s] other than 1.
# Example:
#   print zeta(2.0)
zeta(s: double) -> double:
  if s == 1.0: throw "zeta is undefined at 1"
  if s < 0.0:
    scale2 = math.pow(2.0, s) to double
    scalePi = math.pow(math.pi, s - 1.0) to double
    var reflect = scale2 * scalePi
    reflect = reflect * math.sin(math.pi * s / 2.0) * gamma(1.0 - s)
    return reflect * zeta(1.0 - s)
  var eta = 0.0
  var n = 0
  while n <= 32:
    var inner = 0.0
    var term = 1.0
    var k = 0
    while k <= n:
      power = math.pow((k + 1) to double, s) to double
      inner = inner + term / power
      term = (0.0 - term) * ((n - k) to double) / ((k + 1) to double)
      k = k + 1
    half = math.pow(2.0, (n + 1) to double) to double
    eta = eta + inner / half
    n = n + 1
  factor = math.pow(2.0, 1.0 - s) to double
  return eta / (1.0 - factor)

# Bessel function of the first kind for an integer order.
# Example:
#   print besselJ(0, 0.0)
besselJ(order: int, x: double) -> double:
  if order < 0:
    if order == _minInt(): throw "Bessel order outside supported range"
    flipped = besselJ(0 - order, x)
    if (0 - order) % 2 == 1: return 0.0 - flipped
    return flipped
  if x < 0.0:
    flipped = besselJ(order, 0.0 - x)
    if order % 2 == 1: return 0.0 - flipped
    return flipped
  return _besselJReal(order to double, x)

# Bessel function of the second kind, order zero. [x] must be positive.
# Example:
#   print besselY0(1.0)
besselY0(x: double) -> double:
  return besselY(0, x)

# Legendre polynomial P_n(x).
# Example:
#   print legendre(2, 0.0)
legendre(n: int, x: double) -> double:
  if n < 0: throw "legendre needs a non-negative degree"
  if n == 0: return 1.0
  if n == 1: return x
  var older = 1.0
  var recent = x
  var k = 1
  while k < n:
    var nxt = ((2 * k + 1) to double) * x * recent - (k to double) * older
    nxt = nxt / ((k + 1) to double)
    older = recent
    recent = nxt
    k = k + 1
  return recent

# Physicist's Hermite polynomial H_n(x).
# Example:
#   print hermite(2, 0.0)
hermite(n: int, x: double) -> double:
  if n < 0: throw "hermite needs a non-negative degree"
  if n == 0: return 1.0
  if n == 1: return 2.0 * x
  var older = 1.0
  var recent = 2.0 * x
  var k = 1
  while k < n:
    nxt = 2.0 * x * recent - (2 * k to double) * older
    older = recent
    recent = nxt
    k = k + 1
  return recent

# Laguerre polynomial L_n(x).
# Example:
#   print laguerre(2, 0.0)
laguerre(n: int, x: double) -> double:
  if n < 0: throw "laguerre needs a non-negative degree"
  if n == 0: return 1.0
  if n == 1: return 1.0 - x
  var older = 1.0
  var recent = 1.0 - x
  var k = 1
  while k < n:
    var nxt = ((2 * k + 1) to double) - x
    nxt = nxt * recent - (k to double) * older
    nxt = nxt / ((k + 1) to double)
    older = recent
    recent = nxt
    k = k + 1
  return recent

# Principal branch of the Lambert W function.
# Example:
#   print lambertW(e)
lambertW(x: double) -> double:
  floor = -1.0 / math.e
  if x < floor: throw "lambertW needs x at least -1/e"
  if x == floor: return -1.0
  if x == 0.0: return x
  if x - floor < 1.0e-8:
    p = math.sqrt(2.0 * math.e * (x - floor))
    return -1.0 + p - p * p / 3.0 + 11.0 * p * p * p / 72.0 - 43.0 * p * p * p * p / 540.0 + 769.0 * p * p * p * p * p / 17280.0
  if x > 1.0:
    logged = math.log(x)
    var w = logged
    if logged > 1.0: w = logged - math.log(logged)
    var i = 0
    while i < 50:
      delta = (w + math.log(w) - logged) * (w / (w + 1.0))
      w = w - delta
      if _abs(delta) <= 1.0e-15 * (1.0 + _abs(w)): return w
      i = i + 1
    throw "lambertW did not converge"
  var w = x
  if x < 0.0: w = -0.5
  var i = 0
  while i < 50:
    rise = math.exp(w)
    gap = w * rise - x
    den = rise * (w + 1.0) - (w + 2.0) * gap / (2.0 * w + 2.0)
    delta = gap / den
    w = w - delta
    if _abs(delta) <= 1.0e-15 * (1.0 + _abs(w)): return w
    i = i + 1
  throw "lambertW did not converge"

# Airy function Ai for a moderate real argument.
# Example:
#   print airyAi(0.0)
airyAi(x: double) -> double:
  if _abs(x) > 12.0: throw "airyAi needs a moderate argument"
  if _abs(x) < 1.0: return _airyC1() * _airyF(x) - _airyC2() * _airyG(x)
  if x > 0.0:
    z = 2.0 / 3.0 * x * math.sqrt(x)
    return math.sqrt(x / 3.0) * _besselKReal(1.0 / 3.0, z) / math.pi
  mag = 0.0 - x
  z = 2.0 / 3.0 * mag * math.sqrt(mag)
  return math.sqrt(mag) / 3.0 * (_besselJReal(-1.0 / 3.0, z) + _besselJReal(1.0 / 3.0, z))

# Airy function Bi for a moderate real argument.
# Example:
#   print airyBi(0.0)
airyBi(x: double) -> double:
  if _abs(x) > 12.0: throw "airyBi needs a moderate argument"
  if _abs(x) < 1.0: return math.sqrt(3.0) * (_airyC1() * _airyF(x) + _airyC2() * _airyG(x))
  if x > 0.0:
    z = 2.0 / 3.0 * x * math.sqrt(x)
    return math.sqrt(x / 3.0) * (_besselIReal(-1.0 / 3.0, z) + _besselIReal(1.0 / 3.0, z))
  mag = 0.0 - x
  z = 2.0 / 3.0 * mag * math.sqrt(mag)
  return math.sqrt(mag / 3.0) * (_besselJReal(-1.0 / 3.0, z) - _besselJReal(1.0 / 3.0, z))

# Complete elliptic integral of the first kind. [k] is the modulus.
# Example:
#   print ellipticK(0.0)
ellipticK(k: double) -> double:
  if _abs(k) >= 1.0: throw "ellipticK needs a modulus strictly inside (-1, 1)"
  var a = 1.0
  var g = math.sqrt(1.0 - k * k)
  var i = 0
  while i < 20:
    nextA = (a + g) / 2.0
    g = math.sqrt(a * g)
    a = nextA
    i = i + 1
  return math.pi / (2.0 * a)

# Complete elliptic integral of the second kind.
# Example:
#   print ellipticE(0.0)
ellipticE(k: double) -> double:
  if _abs(k) > 1.0: throw "ellipticE needs a modulus from -1 through 1"
  if _abs(k) == 1.0: return 1.0
  var a = 1.0
  var b = math.sqrt((1.0 - k) * (1.0 + k))
  var correction = k * k / 2.0
  var weight = 1.0
  var i = 0
  while i < 30:
    c = (a - b) / 2.0
    correction = correction + weight * c * c
    next = (a + b) / 2.0
    b = math.sqrt(a * b)
    a = next
    weight = weight * 2.0
    if _abs(c) <= 1.0e-16 * a: return math.pi / (2.0 * a) * (1.0 - correction)
    i = i + 1
  throw "ellipticE did not converge"

# Gauss hypergeometric 2F1(a, b; c; z) for |z| < 1.
# Example:
#   print hypergeometric(1.0, 1.0, 2.0, 0.5)
hypergeometric(a: double, b: double, c: double, z: double) -> double:
  if _abs(z) >= 1.0: throw "hypergeometric needs |z| < 1"
  if c <= 0.0 and c % 1.0 == 0.0: throw "hypergeometric hit a pole"
  if z < 0.0:
    return (math.pow(1.0 - z, 0.0 - a) to double) * hypergeometric(a, c - b, c, z / (z - 1.0))
  var term = 1.0
  var total = 1.0
  var n = 0
  while n < 100000:
    den = (c + (n to double)) * ((n + 1) to double)
    term = term * (a + (n to double)) * (b + (n to double)) / den * z
    total = total + term
    if not _finite(total): throw "hypergeometric overflow"
    if _abs(term) <= 1.0e-15 * _abs(total): return total
    n = n + 1
  throw "hypergeometric did not converge"

# Bessel J for a real order and a non-negative argument.
# Example:
#   print besselJReal(0.0, 1.0)
besselJReal(nu: double, x: double) -> double:
  if nu % 1.0 == 0.0: return besselJ(nu.round, x)
  if x < 0.0: throw "besselJReal needs a non-negative argument"
  return _besselJReal(nu, x)

# Bessel Y for an integer order. [x] must be positive.
# Example:
#   print besselY(1, 1.0)
besselY(order: int, x: double) -> double:
  if x <= 0.0: throw "besselY needs a positive argument"
  if order < 0:
    if order == _minInt(): throw "Bessel order outside supported range"
    flipped = besselY(0 - order, x)
    if (0 - order) % 2 == 1: return 0.0 - flipped
    return flipped
  nu = order to double
  pieces = _besselPieces(nu, x)
  angular = simpson((t: double) -> math.sin(x * math.sin(t) - nu * t), 0.0, math.pi, pieces)
  limit = _besselLimit(nu, x)
  parity = 1.0
  var sign = parity
  if order % 2 == 1: sign = -1.0
  tail = simpson((t: double) -> math.exp(nu * t - x * sinh(t)) + sign * math.exp(0.0 - nu * t - x * sinh(t)), 0.0, limit, 2048)
  return (angular - tail) / math.pi

# Modified Bessel function of the first kind, integer order.
# Example:
#   print besselI(0, 0.0)
besselI(order: int, x: double) -> double:
  if order == _minInt(): throw "Bessel order outside supported range"
  var n = order
  if n < 0: n = 0 - n
  var sign = 1.0
  if x < 0.0 and n % 2 == 1: sign = -1.0
  return sign * _besselIReal(n to double, _abs(x))

# Modified Bessel function of the second kind, integer order. [x] is positive.
# Example:
#   print besselK(0, 1.0)
besselK(order: int, x: double) -> double:
  if x <= 0.0: throw "besselK needs a positive argument"
  return _besselKReal(_abs(order to double), x)

# Private helpers shared across sections. This section exports nothing.
:: support

_scaleVector(values: List<double>, factor: double) -> List<double>:
  made: List<double> = []
  for value in values:
    made.add(value * factor)
  return made

_hessGram(tall: List<List<double>>, columns: int) -> List<List<double>>:
  var made = _filled(columns, columns, 0.0)
  var a = 0
  while a < columns:
    var b = 0
    while b < columns:
      var total = 0.0
      var r = 0
      while r <= columns:
        total = total + tall[r][a] * tall[r][b]
        r = r + 1
      made = _put(made, a, b, total)
      b = b + 1
    a = a + 1
  return made

_hessRhs(tall: List<List<double>>, columns: int, norm0: double) -> List<double>:
  made: List<double> = []
  var c = 0
  while c < columns:
    made.add(norm0 * tall[0][c])
    c = c + 1
  return made

_window(n: int, a0: double, a1: double, a2: double) -> List<double>:
  if n < 1: throw "a window needs a positive length"
  if n == 1: return [1.0]
  made: List<double> = []
  var i = 0
  while i < n:
    angle = 2.0 * math.pi * (i to double) / (n to double)
    made.add(a0 - a1 * math.cos(angle) + a2 * math.cos(2.0 * angle))
    i = i + 1
  return made

_tiePairs(values: List<double>) -> int:
  var ordered = _copyDoubles(values)
  var i = 1
  while i < ordered.length:
    var j = i
    while j > 0 and ordered[j] < ordered[j - 1]:
      saved = ordered[j - 1]
      ordered = _setAt(ordered, j - 1, ordered[j])
      ordered = _setAt(ordered, j, saved)
      j = j - 1
    i = i + 1
  var total = 0
  i = 0
  while i < ordered.length:
    var j = i
    while j + 1 < ordered.length and ordered[j + 1] == ordered[i]:
      j = j + 1
    run = j - i + 1
    total = total + run * (run - 1) ~/ 2
    i = j + 1
  return total

_airyC1() -> double = 0.35502805388781724

_airyC2() -> double = 0.2588194037928068

_airyF(z: double) -> double:
  var series = 1.0
  var term = 1.0
  var k = 1
  while k <= 40:
    term = term * z * z * z / ((3 * k to double) * ((3 * k - 1) to double))
    series = series + term
    k = k + 1
  return series

_airyG(z: double) -> double:
  var series = z
  var term = z
  var k = 1
  while k <= 40:
    term = term * z * z * z / ((3 * k to double) * ((3 * k + 1) to double))
    series = series + term
    k = k + 1
  return series

_besselK0(x: double) -> double:
  return _besselKReal(0.0, x)

_besselK1(x: double) -> double:
  return _besselKReal(1.0, x)

_orderScores(scores: List<double>) -> List<int>:
  var order = _zeroInts(scores.length)
  var i = 0
  while i < scores.length:
    order = _setInt(order, i, i)
    i = i + 1
  i = 1
  while i < order.length:
    var j = i
    while j > 0 and scores[order[j]] < scores[order[j - 1]]:
      order = _swapInts(order, j, j - 1)
      j = j - 1
    i = i + 1
  return order

_simplexCentroid(points: List<List<double>>, skip: int) -> List<double>:
  var made = _zeroDoubles(points[0].length)
  var count = 0
  var i = 0
  while i < points.length:
    if i != skip:
      made = _axpy(made, points[i], 1.0)
      count = count + 1
    i = i + 1
  return _scaleVector(made, 1.0 / (count to double))

_joinFactors(left: List<int>, right: List<int>) -> List<int>:
  made: List<int> = []
  var i = 0
  var j = 0
  while i < left.length or j < right.length:
    takeLeft = j >= right.length or (i < left.length and left[i] <= right[j])
    if takeLeft:
      made.add(left[i])
      i = i + 1
    else:
      made.add(right[j])
      j = j + 1
  return made

_trialFactors(n: int) -> List<int>:
  made: List<int> = []
  var left = n
  var d = 2
  while d <= left ~/ d:
    while left % d == 0:
      made.add(d)
      left = left ~/ d
    d = d + 1
  if left > 1: made.add(left)
  return made

_pollard(n: int) -> int:
  if n % 2 == 0: return 2
  bumps: List<int> = [1, 2, 3, 5]
  for bump in bumps:
    var x = 2
    var y = 2
    var divisor = 1
    var guard = 0
    while divisor == 1 and guard < 20000:
      x = _addMod(_mulMod(x, x, n), bump % n, n)
      y = _addMod(_mulMod(y, y, n), bump % n, n)
      y = _addMod(_mulMod(y, y, n), bump % n, n)
      var gap = x - y
      if gap < 0: gap = 0 - gap
      divisor = gcd(gap, n)
      guard = guard + 1
    if divisor > 1 and divisor < n: return divisor
  return n

_factorTree(n: int) -> List<int>:
  if n == 1:
    empty: List<int> = []
    return empty
  if isProbablePrime(n):
    one: List<int> = [n]
    return one
  var d = 2
  while d <= 1000 and d <= n ~/ d:
    if n % d == 0: return _joinFactors(_factorTree(d), _factorTree(n ~/ d))
    if d == 2: d = 3
    else: d = d + 2
  if isProbablePrime(n):
    one: List<int> = [n]
    return one
  split = _pollard(n)
  if split > 1 and split < n and n % split == 0:
    return _joinFactors(_factorTree(split), _factorTree(n ~/ split))
  return _trialFactors(n)

_appendEigen(found: List<Complex>, grid: List<List<double>>,
at: int) -> List<Complex>:
  a = grid[at][at]
  b = grid[at][at + 1]
  c = grid[at + 1][at]
  d = grid[at + 1][at + 1]
  mid = (a + d) / 2.0
  var disc = (a - d) / 2.0
  disc = disc * disc + b * c
  if disc >= 0.0:
    root = math.sqrt(disc)
    found.add(Complex(real: mid + root, imag: 0.0))
    found.add(Complex(real: mid - root, imag: 0.0))
  else:
    root = math.sqrt(0.0 - disc)
    found.add(Complex(real: mid, imag: 0.0 - root))
    found.add(Complex(real: mid, imag: root))
  return found

_hessenberg(rows: List<List<double>>) -> List<List<double>>:
  var grid = _squareCopy(rows)
  n = grid.length
  var k = 0
  while k < n - 2:
    var norm = 0.0
    var i = k + 1
    while i < n:
      norm = hypot(norm, grid[i][k])
      i = i + 1
    if norm != 0.0:
      head = grid[k + 1][k]
      var alpha = 0.0 - norm
      if head < 0.0: alpha = norm
      u: List<double> = []
      i = k + 1
      while i < n:
        var value = grid[i][k]
        if i == k + 1: value = value - alpha
        u.add(value)
        i = i + 1
      var uu = 0.0
      for entry in u:
        uu = uu + entry * entry
      if uu != 0.0:
        house = 2.0 / uu
        var j = k
        while j < n:
          var proj = 0.0
          var r = 0
          while r < u.length:
            proj = proj + u[r] * grid[k + 1 + r][j]
            r = r + 1
          r = 0
          while r < u.length:
            grid = _put(grid, k + 1 + r, j,
            grid[k + 1 + r][j] - house * u[r] * proj)
            r = r + 1
          j = j + 1
        var row = 0
        while row < n:
          var proj = 0.0
          var c = 0
          while c < u.length:
            proj = proj + grid[row][k + 1 + c] * u[c]
            c = c + 1
          c = 0
          while c < u.length:
            grid = _put(grid, row, k + 1 + c,
            grid[row][k + 1 + c] - house * proj * u[c])
            c = c + 1
          row = row + 1
    k = k + 1
  return grid

_qrShift(grid: List<List<double>>, p: int) -> List<List<double>>:
  a = grid[p - 2][p - 2]
  b = grid[p - 2][p - 1]
  c = grid[p - 1][p - 2]
  d = grid[p - 1][p - 1]
  mid = (a + d) / 2.0
  var disc = (a - d) / 2.0
  disc = disc * disc + b * c
  var mu = mid
  if disc >= 0.0:
    root = math.sqrt(disc)
    e1 = mid + root
    e2 = mid - root
    if _abs(e1 - d) <= _abs(e2 - d): mu = e1
    else: mu = e2
  var h = grid
  var i = 0
  while i < p:
    h = _put(h, i, i, h[i][i] - mu)
    i = i + 1
  cs: List<double> = []
  sn: List<double> = []
  var k = 0
  while k < p - 1:
    x = h[k][k]
    y = h[k + 1][k]
    radius = hypot(x, y)
    var cosine = 1.0
    var sine = 0.0
    if radius != 0.0:
      cosine = x / radius
      sine = y / radius
    cs.add(cosine)
    sn.add(sine)
    var j = k
    while j < p:
      left = h[k][j]
      right = h[k + 1][j]
      h = _put(h, k, j, cosine * left + sine * right)
      h = _put(h, k + 1, j, 0.0 - sine * left + cosine * right)
      j = j + 1
    k = k + 1
  k = 0
  while k < p - 1:
    cq = cs[k]
    sq = sn[k]
    var row = 0
    while row < p:
      left = h[row][k]
      right = h[row][k + 1]
      h = _put(h, row, k, cq * left + sq * right)
      h = _put(h, row, k + 1, 0.0 - sq * left + cq * right)
      row = row + 1
    k = k + 1
  i = 0
  while i < p:
    h = _put(h, i, i, h[i][i] + mu)
    i = i + 1
  return h

_qrEigen(rows: List<List<double>>) -> List<Complex>:
  var grid = _hessenberg(rows)
  n = grid.length
  if n == 0: throw "eigenvalues need a matrix"
  var found: List<Complex> = []
  var p = n
  var guard = 0
  limit = 40 * n
  while p > 0 and guard < limit:
    guard = guard + 1
    if p == 1:
      found.add(Complex(real: grid[0][0], imag: 0.0))
      p = 0
    else:
      scale = _abs(grid[p - 1][p - 1]) + _abs(grid[p - 2][p - 2])
      if _abs(grid[p - 1][p - 2]) <= 1.0e-12 * (scale + 1.0):
        found.add(Complex(real: grid[p - 1][p - 1], imag: 0.0))
        p = p - 1
      else:
        var split = p == 2
        if p > 2:
          scale2 = _abs(grid[p - 2][p - 2]) + _abs(grid[p - 3][p - 3])
          if _abs(grid[p - 2][p - 3]) <= 1.0e-12 * (scale2 + 1.0): split = true
        if split:
          var at = 0
          if p > 2: at = p - 2
          found = _appendEigen(found, grid, at)
          if p == 2: p = 0
          else: p = p - 2
        else: grid = _qrShift(grid, p)
  if p > 0: throw "eigenvalues did not converge"
  return _sortRoots(found)

# Absolute value used by elimination. Private, so it is not part of the API.
_abs(x: double) -> double:
  if x < 0.0: return 0.0 - x
  return x

# A square copy. A row of the wrong length throws.
_squareCopy(rows: List<List<double>>) -> List<List<double>>:
  n = rows.length
  made: List<List<double>> = []
  for row in rows:
    if row.length != n: throw "matrix must be square"
    made.add(_copyDoubles(row))
  return made

_copyDoubles(values: List<double>) -> List<double>:
  made: List<double> = []
  for value in values:
    made.add(value)
  return made

# Row with the largest absolute value in [column], at or below [column].
_pivotRow(grid: List<List<double>>, column: int) -> int:
  var pivot = column
  var row = column + 1
  while row < grid.length:
    if _abs(grid[row][column]) > _abs(grid[pivot][column]): pivot = row
    row = row + 1
  return pivot

_swapRows(grid: List<List<double>>, i: int, j: int) -> List<List<double>>:
  made: List<List<double>> = []
  var row = 0
  while row < grid.length:
    if row == i: made.add(grid[j])
    else:
      if row == j: made.add(grid[i])
      else: made.add(grid[row])
    row = row + 1
  return made

_replaceRow(
    grid: List<List<double>>,
    index: int,
    row: List<double>) -> List<List<double>>:
  made: List<List<double>> = []
  var i = 0
  while i < grid.length:
    if i == index: made.add(row)
    else: made.add(grid[i])
    i = i + 1
  return made

# [row] minus [factor] times [pivot], starting at column [from].
_cancel(
    row: List<double>,
    pivot: List<double>,
    factor: double,
    from: int) -> List<double>:
  made: List<double> = []
  var k = 0
  while k < row.length:
    if k < from: made.add(row[k])
    else: made.add(row[k] - factor * pivot[k])
    k = k + 1
  return made

_swapDoubles(values: List<double>, i: int, j: int) -> List<double>:
  made: List<double> = []
  var index = 0
  while index < values.length:
    if index == i: made.add(values[j])
    else:
      if index == j: made.add(values[i])
      else: made.add(values[index])
    index = index + 1
  return made

_filled(rows: int, columns: int, value: double) -> List<List<double>>:
  made: List<List<double>> = []
  var row = 0
  while row < rows:
    line: List<double> = []
    var column = 0
    while column < columns:
      line.add(value)
      column = column + 1
    made.add(line)
    row = row + 1
  return made

_rectCopy(rows: List<List<double>>) -> List<List<double>>:
  if rows.isEmpty: throw "matrix must not be empty"
  width = rows[0].length
  if width == 0: throw "matrix must not be empty"
  made: List<List<double>> = []
  for row in rows:
    if row.length != width: throw "matrix must be rectangular"
    made.add(_copyDoubles(row))
  return made

_sameShape(left: List<List<double>>, right: List<List<double>>) -> int:
  if left.length != right.length: throw "matrices must have the same shape"
  grid = _rectCopy(left)
  other = _rectCopy(right)
  if grid[0].length != other[0].length:
    throw "matrices must have the same shape"
  return grid[0].length

_blend(
    left: List<List<double>>,
    right: List<List<double>>,
    sign: double) -> List<List<double>>:
  width = _sameShape(left, right)
  made: List<List<double>> = []
  var row = 0
  while row < left.length:
    line: List<double> = []
    var column = 0
    while column < width:
      line.add(left[row][column] + sign * right[row][column])
      column = column + 1
    made.add(line)
    row = row + 1
  return made

_dot(left: List<double>, right: List<double>) -> double:
  var total = 0.0
  var i = 0
  while i < left.length:
    total = total + left[i] * right[i]
    i = i + 1
  return total

_scaleList(values: List<double>, factor: double) -> List<double>:
  made: List<double> = []
  for value in values:
    made.add(value * factor)
  return made

_axpy(
    left: List<double>,
    right: List<double>,
    factor: double) -> List<double>:
  made: List<double> = []
  var i = 0
  while i < left.length:
    made.add(left[i] + factor * right[i])
    i = i + 1
  return made

_column(rows: List<List<double>>, index: int) -> List<double>:
  made: List<double> = []
  for row in rows:
    made.add(row[index])
  return made

_setAt(values: List<double>, index: int, value: double) -> List<double>:
  made: List<double> = []
  var i = 0
  while i < values.length:
    if i == index: made.add(value)
    else: made.add(values[i])
    i = i + 1
  return made

# Shared positive-x tail of erf and erfc.
# [asErf] selects erf; otherwise the value is erfc.
_positiveErfTail(x: double, asErf: bool) -> double:
  t = 1.0 / (1.0 + 0.3275911 * x)
  var poly = 1.061405429
  poly = poly * t - 1.453152027
  poly = poly * t + 1.421413741
  poly = poly * t - 0.284496736
  poly = poly * t + 0.254829592
  poly = poly * t
  tail = poly * math.exp(0.0 - x * x)
  if asErf: return 1.0 - tail
  return tail

# 1 - ssRes / ssTot. A constant target that is fitted exactly is 1.
_determination(actual: List<double>, gaps: List<double>) -> double:
  if actual.length != gaps.length or actual.isEmpty:
    throw "a fit needs matching values"
  center = mean(actual)
  var total = 0.0
  var residual = 0.0
  var i = 0
  while i < actual.length:
    delta = actual[i] - center
    total = total + delta * delta
    residual = residual + gaps[i] * gaps[i]
    i = i + 1
  if total == 0.0: return 1.0
  return 1.0 - residual / total

_sortRoots(roots: List<Complex>) -> List<Complex>:
  var made: List<Complex> = []
  for root in roots:
    made.add(root)
  var i = 0
  while i < made.length:
    var j = i + 1
    while j < made.length:
      var earlier = made[j].real < made[i].real
      if made[j].real == made[i].real and made[j].imag < made[i].imag:
        earlier = true
      if earlier: made = _swapComplex(made, i, j)
      j = j + 1
    i = i + 1
  return made

_swapComplex(values: List<Complex>, i: int, j: int) -> List<Complex>:
  if i == j: return values
  return _putComplex(_putComplex(values, i, values[j]), j, values[i])

_putComplex(
    values: List<Complex>,
    index: int,
    value: Complex) -> List<Complex>:
  made: List<Complex> = []
  var i = 0
  while i < values.length:
    if i == index: made.add(value)
    else: made.add(values[i])
    i = i + 1
  return made

_swapInts(values: List<int>, i: int, j: int) -> List<int>:
  made: List<int> = []
  var index = 0
  while index < values.length:
    if index == i: made.add(values[j])
    else:
      if index == j: made.add(values[i])
      else: made.add(values[index])
    index = index + 1
  return made

_put(
    grid: List<List<double>>,
    row: int,
    column: int,
    value: double) -> List<List<double>>:
  return _replaceRow(grid, row, _setAt(grid[row], column, value))

_swapColumns(
    grid: List<List<double>>,
    i: int,
    j: int) -> List<List<double>>:
  if i == j: return grid
  var next = grid
  var row = 0
  while row < grid.length:
    var line = _setAt(grid[row], i, grid[row][j])
    line = _setAt(line, j, grid[row][i])
    next = _replaceRow(next, row, line)
    row = row + 1
  return next

_setColumn(
    grid: List<List<double>>,
    index: int,
    column: List<double>) -> List<List<double>>:
  if column.length != grid.length: throw "column length must match the matrix"
  var next = grid
  var row = 0
  while row < grid.length:
    next = _put(next, row, index, column[row])
    row = row + 1
  return next

_reverseColumns(grid: List<List<double>>) -> List<List<double>>:
  if grid.isEmpty: return grid
  width = grid[0].length
  made: List<List<double>> = []
  for row in grid:
    line: List<double> = []
    var column = width - 1
    while column >= 0:
      line.add(row[column])
      column = column - 1
    made.add(line)
  return made

_symmetrize(rows: List<List<double>>) -> List<List<double>>:
  var grid = _squareCopy(rows)
  n = grid.length
  var i = 0
  while i < n:
    var j = i + 1
    while j < n:
      shared = (grid[i][j] + grid[j][i]) / 2.0
      grid = _put(grid, i, j, shared)
      grid = _put(grid, j, i, shared)
      j = j + 1
    i = i + 1
  return grid

_gammaSeries(s: double, x: double) -> double:
  var ap = s
  var sum = 1.0 / s
  var del = sum
  var n = 0
  while n < 100000:
    ap = ap + 1.0
    del = del * x / ap
    sum = sum + del
    if _abs(del) <= _abs(sum) * 1.0e-14:
      return sum * math.exp(0.0 - x + s * math.log(x) - logGamma(s))
    n = n + 1
  throw "incomplete gamma series did not converge"

_gammaFraction(s: double, x: double) -> double:
  tiny = 1.0e-30
  var b = x + 1.0 - s
  var c = 1.0 / tiny
  var d = 1.0 / b
  var h = d
  var i = 1
  while i <= 10000:
    an = (0.0 - (i to double)) * ((i to double) - s)
    b = b + 2.0
    d = an * d + b
    if _abs(d) < tiny: d = tiny
    c = b + an / c
    if _abs(c) < tiny: c = tiny
    d = 1.0 / d
    del = d * c
    h = h * del
    if _abs(del - 1.0) < 1.0e-14:
      return math.exp(0.0 - x + s * math.log(x) - logGamma(s)) * h
    i = i + 1
  throw "incomplete gamma fraction did not converge"

_betaFraction(a: double, b: double, x: double) -> double:
  tiny = 1.0e-30
  qab = a + b
  qap = a + 1.0
  qam = a - 1.0
  var c = 1.0
  var d = 1.0 - qab * x / qap
  if _abs(d) < tiny: d = tiny
  d = 1.0 / d
  var h = d
  var m = 1
  while m <= 10000:
    m2 = 2 * m
    var aa = (m to double) * (b - (m to double)) * x / ((qam + (m2 to double)) * (a + (m2 to double)))
    d = 1.0 + aa * d
    if _abs(d) < tiny: d = tiny
    c = 1.0 + aa / c
    if _abs(c) < tiny: c = tiny
    d = 1.0 / d
    h = h * d * c
    aa = 0.0 - (a + (m to double)) * (qab + (m to double)) * x
    aa = aa / ((a + (m2 to double)) * (qap + (m2 to double)))
    d = 1.0 + aa * d
    if _abs(d) < tiny: d = tiny
    c = 1.0 + aa / c
    if _abs(c) < tiny: c = tiny
    d = 1.0 / d
    del = d * c
    h = h * del
    if _abs(del - 1.0) < 1.0e-14: return h
    m = m + 1
  throw "incomplete beta fraction did not converge"

_normalTail(p: double) -> double:
  a1 = 0.0 - 3.969683028665376e1
  a2 = 2.209460984245205e2
  a3 = 0.0 - 2.759285104469687e2
  a4 = 1.383577518672690e2
  a5 = 0.0 - 3.066479806614716e1
  a6 = 2.506628277459239
  b1 = 0.0 - 5.447609879822406e1
  b2 = 1.615858368580409e2
  b3 = 0.0 - 1.556989798598866e2
  b4 = 6.680131188771972e1
  b5 = 0.0 - 1.328068155288572e1
  c1 = 0.0 - 7.784894002430293e-3
  c2 = 0.0 - 3.223964580411365e-1
  c3 = 0.0 - 2.400758277161838
  c4 = 0.0 - 2.549732539343734
  c5 = 4.374664141464968
  c6 = 2.938163982698783
  d1 = 7.784695709041462e-3
  d2 = 3.224671290700398e-1
  d3 = 2.445134137142996
  d4 = 3.754408661907416
  plow = 0.02425
  var x = 0.0
  if p < plow:
    q = math.sqrt(0.0 - 2.0 * math.log(p))
    num = polyEval([c6, c5, c4, c3, c2, c1], q)
    den = polyEval([1.0, d4, d3, d2, d1], q)
    x = num / den
  else:
    if p <= 1.0 - plow:
      q = p - 0.5
      r = q * q
      num = polyEval([a6, a5, a4, a3, a2, a1], r) * q
      den = polyEval([1.0, b5, b4, b3, b2, b1], r)
      x = num / den
    else:
      q = math.sqrt(0.0 - 2.0 * log1p(0.0 - p))
      num = polyEval([c6, c5, c4, c3, c2, c1], q)
      den = polyEval([1.0, d4, d3, d2, d1], q)
      x = 0.0 - num / den
  var step = 0
  while step < 2:
    density = normalPdf(x)
    if density > 0.0: x = x - (normalCdf(x) - p) / density
    step = step + 1
  return x

_bisectIncreasing(
    f: (double) -> double,
    target: double,
    low: double,
    high: double) -> double:
  if target <= 0.0 or target >= 1.0:
    throw "probability must sit strictly between 0 and 1"
  var lo = low
  var hi = high
  var guard = 0
  while f(lo) > target and guard < 60:
    lo = lo * 2.0 - 1.0
    guard = guard + 1
  guard = 0
  while f(hi) < target and guard < 60:
    hi = hi * 2.0 + 1.0
    guard = guard + 1
  if f(lo) > target or f(hi) < target: throw "quantile bracket did not expand"
  var i = 0
  while i < 80:
    mid = (lo + hi) / 2.0
    if f(mid) < target: lo = mid
    else: hi = mid
    i = i + 1
  return (lo + hi) / 2.0

_gaussPair(
    f: (double) -> double,
    mid: double,
    half: double,
    node: double,
    weight: double) -> double:
  if node == 0.0: return weight * half * f(mid)
  left = f(mid - half * node)
  right = f(mid + half * node)
  return weight * half * (left + right)

# One classical fourth-order step. [y] is not modified.
_rk4(
    f: (double, List<double>) -> List<double>,
    x: double,
    y: List<double>,
    h: double) -> List<double>:
  s1 = f(x, y)
  if s1.length != y.length: throw "the derivative must match the state"
  s2 = f(x + h * 0.5, _axpy(y, s1, h * 0.5))
  s3 = f(x + h * 0.5, _axpy(y, s2, h * 0.5))
  s4 = f(x + h, _axpy(y, s3, h))
  var acc = _axpy(s1, s2, 2.0)
  acc = _axpy(acc, s3, 2.0)
  acc = _axpy(acc, s4, 1.0)
  return _axpy(y, acc, h / 6.0)

# Fifth-order Fehlberg step and the absolute error against the fourth order.
_rkf45(
    f: (double, List<double>) -> List<double>,
    x: double,
    y: List<double>,
    h: double) -> _Step:
  s1 = f(x, y)
  if s1.length != y.length: throw "the derivative must match the state"
  y2 = _axpy(y, s1, h * 0.25)
  s2 = f(x + h * 0.25, y2)
  var y3 = _axpy(y, s1, h * 3.0 / 32.0)
  y3 = _axpy(y3, s2, h * 9.0 / 32.0)
  s3 = f(x + h * 3.0 / 8.0, y3)
  var y4 = _axpy(y, s1, h * 1932.0 / 2197.0)
  y4 = _axpy(y4, s2, h * (0.0 - 7200.0 / 2197.0))
  y4 = _axpy(y4, s3, h * 7296.0 / 2197.0)
  s4 = f(x + h * 12.0 / 13.0, y4)
  var y5 = _axpy(y, s1, h * 439.0 / 216.0)
  y5 = _axpy(y5, s2, h * (0.0 - 8.0))
  y5 = _axpy(y5, s3, h * 3680.0 / 513.0)
  y5 = _axpy(y5, s4, h * (0.0 - 845.0 / 4104.0))
  s5 = f(x + h, y5)
  var y6 = _axpy(y, s1, h * (0.0 - 8.0 / 27.0))
  y6 = _axpy(y6, s2, h * 2.0)
  y6 = _axpy(y6, s3, h * (0.0 - 3544.0 / 2565.0))
  y6 = _axpy(y6, s4, h * 1859.0 / 4104.0)
  y6 = _axpy(y6, s5, h * (0.0 - 11.0 / 40.0))
  s6 = f(x + h * 0.5, y6)
  var acc4 = _scaleList(s1, 25.0 / 216.0)
  acc4 = _axpy(acc4, s3, 1408.0 / 2565.0)
  acc4 = _axpy(acc4, s4, 2197.0 / 4104.0)
  acc4 = _axpy(acc4, s5, 0.0 - 0.2)
  fourth = _axpy(y, acc4, h)
  var acc5 = _scaleList(s1, 16.0 / 135.0)
  acc5 = _axpy(acc5, s3, 6656.0 / 12825.0)
  acc5 = _axpy(acc5, s4, 28561.0 / 56430.0)
  acc5 = _axpy(acc5, s5, 0.0 - 9.0 / 50.0)
  acc5 = _axpy(acc5, s6, 2.0 / 55.0)
  fifth = _axpy(y, acc5, h)
  var err = 0.0
  var i = 0
  while i < y.length:
    var scale = _abs(fifth[i])
    if scale < 1.0: scale = 1.0
    gap = _abs(fifth[i] - fourth[i]) / scale
    if gap > err: err = gap
    i = i + 1
  return _Step(state: fifth, error: err)

_boundaryField(
    f: (double, double, double) -> double,
    x: double,
    state: List<double>) -> List<double>:
  made: List<double> = [state[1], f(x, state[0], state[1])]
  return made

_boundaryMiss(
    f: (double, double, double) -> double,
    x0: double,
    y0: double,
    x1: double,
    y1: double,
    slope: double,
    steps: int) -> double:
  end = rungeKuttaSystem(
      (x: double, state: List<double>) -> _boundaryField(f, x, state),
      x0,
      [y0, slope],
      x1,
      steps)
  return end[0] - y1

_rkSamples(
    f: (double, List<double>) -> List<double>,
    x0: double,
    y0: List<double>,
    x1: double,
    steps: int) -> List<List<double>>:
  width = (x1 - x0) / (steps to double)
  var x = x0
  var y = _copyDoubles(y0)
  made: List<List<double>> = [y]
  var i = 0
  while i < steps:
    y = _rk4(f, x, y, width)
    made.add(y)
    x = x + width
    i = i + 1
  return made

_powerOfTwo(n: int) -> bool:
  if n < 1: return false
  var p = 1
  while p < n:
    p = p * 2
  return p == n

_reverseBits(index: int, bits: int) -> int:
  var out = 0
  var value = index
  var i = 0
  while i < bits:
    out = out * 2 + value % 2
    value = value ~/ 2
    i = i + 1
  return out

_transform(values: List<Complex>, sign: double) -> List<Complex>:
  n = values.length
  if not _powerOfTwo(n): throw "fft needs a positive power of two"
  var bits = 0
  var p = 1
  while p < n:
    p = p * 2
    bits = bits + 1
  ordered: List<Complex> = []
  var i = 0
  while i < n:
    ordered.add(values[_reverseBits(i, bits)])
    i = i + 1
  var data = ordered
  var length = 2
  while length <= n:
    half = length ~/ 2
    angle = sign * 2.0 * math.pi / (length to double)
    wlen = Complex.polar(1.0, angle)
    var start = 0
    while start < n:
      var w = Complex(real: 1.0, imag: 0.0)
      var k = 0
      while k < half:
        u = data[start + k]
        v = data[start + k + half] * w
        data = _putComplex(data, start + k, u + v)
        data = _putComplex(data, start + k + half, u - v)
        w = w * wlen
        k = k + 1
      start = start + length
    length = length * 2
  if sign > 0.0:
    scale = 1.0 / (n to double)
    scaled: List<Complex> = []
    var j = 0
    while j < n:
      scaled.add(data[j].scale(scale))
      j = j + 1
    return scaled
  return data

# Accepted state and its discrepancy from the lower-order step.
value class _Step:
  state: List<double>
  error: double

_zeroDoubles(n: int) -> List<double>:
  made: List<double> = []
  var i = 0
  while i < n:
    made.add(0.0)
    i = i + 1
  return made

_zeroInts(n: int) -> List<int>:
  made: List<int> = []
  var i = 0
  while i < n:
    made.add(0)
    i = i + 1
  return made

_setInt(values: List<int>, index: int, value: int) -> List<int>:
  made: List<int> = []
  var i = 0
  while i < values.length:
    if i == index: made.add(value)
    else: made.add(values[i])
    i = i + 1
  return made

_polyZip(left: List<double>, right: List<double>, sign: double) -> List<double>:
  var n = left.length
  if right.length > n: n = right.length
  made: List<double> = []
  var i = 0
  while i < n:
    var a = 0.0
    var b = 0.0
    if i < left.length: a = left[i]
    if i < right.length: b = right[i]
    made.add(a + sign * b)
    i = i + 1
  return made

_trimPoly(coeffs: List<double>) -> List<double>:
  if coeffs.isEmpty: return [0.0]
  var end = coeffs.length - 1
  while end > 0 and coeffs[end] == 0.0:
    end = end - 1
  made: List<double> = []
  var i = 0
  while i <= end:
    made.add(coeffs[i])
    i = i + 1
  return made

_tinyPoly(coeffs: List<double>) -> bool:
  for value in coeffs:
    if value != 0.0: return false
  return true

_monicPoly(coeffs: List<double>) -> List<double>:
  cleaned = _trimPoly(coeffs)
  lead = cleaned[cleaned.length - 1]
  if lead == 0.0: return [0.0]
  made: List<double> = []
  for value in cleaned:
    made.add(value / lead)
  return made

_atComplex(coeffs: List<double>, z: Complex) -> Complex:
  var acc = Complex(real: 0.0, imag: 0.0)
  var i = coeffs.length - 1
  while i >= 0:
    acc = acc * z + Complex(real: coeffs[i], imag: 0.0)
    i = i - 1
  return acc

_durand(coeffs: List<double>) -> List<Complex>:
  cleaned = _trimPoly(coeffs)
  degree = cleaned.length - 1
  if degree < 1: throw "a root needs a degree"
  if degree == 1:
    one: List<Complex> = [Complex(real: (0.0 - cleaned[0]) / cleaned[1],
    imag: 0.0)]
    return one
  if degree == 2: return quadraticRoots(cleaned[2], cleaned[1], cleaned[0])
  if degree == 3: return cubicRoots(cleaned[3], cleaned[2], cleaned[1],
  cleaned[0])
  lead = cleaned[degree]
  monic: List<double> = []
  for value in cleaned:
    monic.add(value / lead)
  var roots: List<Complex> = []
  step = Complex(real: 0.4, imag: 0.9)
  var guess = step
  var i = 0
  while i < degree:
    roots.add(guess)
    guess = guess * step
    i = i + 1
  var sweep = 0
  while sweep < 80:
    var next: List<Complex> = []
    var moved = 0.0
    i = 0
    while i < degree:
      var denom = Complex(real: 1.0, imag: 0.0)
      var j = 0
      while j < degree:
        if j != i:
          var gap = roots[i] - roots[j]
          if gap.abs() < 1.0e-14: gap = Complex(real: 1.0e-14, imag: 0.0)
          denom = denom * gap
        j = j + 1
      delta = _atComplex(monic, roots[i]) / denom
      if delta.abs() > moved: moved = delta.abs()
      next.add(roots[i] - delta)
      i = i + 1
    roots = next
    if moved < 1.0e-12: sweep = 80
    else: sweep = sweep + 1
  for root in roots:
    if _atComplex(monic, root).abs() > 1.0e-8 * (1.0 + root.abs()): throw "polynomial roots did not converge"
  return _sortRoots(roots)

_characteristic(rows: List<List<double>>) -> List<double>:
  grid = _squareCopy(rows)
  n = grid.length
  if n == 0: throw "eigenvalues need a matrix"
  var mk = grid
  var found = _zeroDoubles(n)
  var k = 1
  while k <= n:
    ck = 0.0 - trace(mk) / (k to double)
    found = _setAt(found, k - 1, ck)
    if k < n: mk = matmul(grid, addMatrices(mk, scaleMatrix(identity(n), ck)))
    k = k + 1
  coeffs: List<double> = []
  var i = n - 1
  while i >= 0:
    coeffs.add(found[i])
    i = i - 1
  coeffs.add(1.0)
  return coeffs

_copyC(values: List<Complex>) -> List<Complex>:
  made: List<Complex> = []
  for value in values:
    made.add(value)
  return made

_setC(values: List<Complex>, index: int, value: Complex) -> List<Complex>:
  made: List<Complex> = []
  var i = 0
  while i < values.length:
    if i == index: made.add(value)
    else: made.add(values[i])
    i = i + 1
  return made

_replaceCRow(
    grid: List<List<Complex>>,
    index: int,
    row: List<Complex>) -> List<List<Complex>>:
  made: List<List<Complex>> = []
  var i = 0
  while i < grid.length:
    if i == index: made.add(row)
    else: made.add(grid[i])
    i = i + 1
  return made

_swapCRows(
    grid: List<List<Complex>>, i: int, j: int) -> List<List<Complex>>:
  if i == j: return grid
  made: List<List<Complex>> = []
  var r = 0
  while r < grid.length:
    if r == i: made.add(grid[j])
    else:
      if r == j: made.add(grid[i])
      else: made.add(grid[r])
    r = r + 1
  return made

_putCGrid(
    grid: List<List<Complex>>,
    row: int,
    column: int,
    value: Complex) -> List<List<Complex>>:
  return _replaceCRow(grid, row, _setC(grid[row], column, value))

_csolve(rows: List<List<Complex>>, rhs: List<Complex>) -> List<Complex>:
  n = rows.length
  var grid: List<List<Complex>> = []
  for row in rows:
    grid.add(_copyC(row))
  var b = _copyC(rhs)
  var i = 0
  while i < n:
    var pivot = i
    var j = i + 1
    while j < n:
      if grid[j][i].abs() > grid[pivot][i].abs(): pivot = j
      j = j + 1
    grid = _swapCRows(grid, i, pivot)
    left = b[i]
    right = b[pivot]
    b = _setC(b, i, right)
    b = _setC(b, pivot, left)
    if grid[i][i].abs() < 1.0e-14: i = i + 1
    else:
      var k = i + 1
      while k < n:
        factor = grid[k][i] / grid[i][i]
        saved = grid[k]
        pivotRow = grid[i]
        var row = saved
        var col = i
        while col < n:
          row = _setC(row, col, saved[col] - factor * pivotRow[col])
          col = col + 1
        grid = _replaceCRow(grid, k, row)
        b = _setC(b, k, b[k] - factor * b[i])
        k = k + 1
      i = i + 1
  var x = _copyC(b)
  var r = 0
  while r < n:
    x = _setC(x, r, Complex(real: 0.0, imag: 0.0))
    r = r + 1
  i = n - 1
  while i >= 0:
    var acc = b[i]
    var col = i + 1
    while col < n:
      acc = acc - grid[i][col] * x[col]
      col = col + 1
    if grid[i][i].abs() < 1.0e-14: x = _setC(x, i, Complex(real: 1.0,
    imag: 0.0))
    else: x = _setC(x, i, acc / grid[i][i])
    i = i - 1
  return x

_eigenVector(rows: List<List<double>>, value: Complex) -> List<Complex>:
  n = rows.length
  shift = value + Complex(real: 1.0e-6 * (1.0 + value.abs()), imag: 0.0)
  var grid: List<List<Complex>> = []
  var rhs: List<Complex> = []
  var r = 0
  while r < n:
    var row: List<Complex> = []
    var c = 0
    while c < n:
      var real = rows[r][c]
      var imag = 0.0
      if r == c:
        real = real - shift.real
        imag = 0.0 - shift.imag
      row.add(Complex(real: real, imag: imag))
      c = c + 1
    grid.add(row)
    rhs.add(Complex(real: 1.0, imag: 0.0))
    r = r + 1
  solved = _csolve(grid, rhs)
  var mag = 0.0
  for item in solved:
    mag = mag + item.real * item.real + item.imag * item.imag
  mag = math.sqrt(mag)
  if mag == 0.0: return solved
  made: List<Complex> = []
  for item in solved:
    made.add(item.scale(1.0 / mag))
  return made

_splineMoments(xs: List<double>, ys: List<double>) -> List<double>:
  n = xs.length
  if n == 2: return [0.0, 0.0]
  below: List<double> = []
  diag: List<double> = []
  above: List<double> = []
  rhs: List<double> = []
  unknowns = n - 2
  var i = 0
  while i < unknowns:
    point = i + 1
    h0 = xs[point] - xs[point - 1]
    h1 = xs[point + 1] - xs[point]
    diag.add((h0 + h1) / 3.0)
    rise1 = (ys[point + 1] - ys[point]) / h1
    rise0 = (ys[point] - ys[point - 1]) / h0
    rhs.add(rise1 - rise0)
    if i > 0: below.add(h0 / 6.0)
    if i < unknowns - 1: above.add(h1 / 6.0)
    i = i + 1
  inner = tridiagonalSolve(below, diag, above, rhs)
  made: List<double> = [0.0]
  for value in inner:
    made.add(value)
  made.add(0.0)
  return made

_splinePiece(
    x: double,
    xs: List<double>,
    ys: List<double>,
    moments: List<double>,
    segment: int) -> double:
  h = xs[segment + 1] - xs[segment]
  a = (xs[segment + 1] - x) / h
  b = (x - xs[segment]) / h
  cubic = ((a * a * a - a) * moments[segment] + (b * b * b - b) * moments[segment + 1]) * h * h / 6.0
  return a * ys[segment] + b * ys[segment + 1] + cubic

_jacobian(
    f: (double, List<double>) -> List<double>,
    x: double,
    y: List<double>) -> List<List<double>>:
  base = f(x, y)
  var grid = _filled(y.length, y.length, 0.0)
  var j = 0
  while j < y.length:
    bumped = _setAt(y, j, y[j] + 1.0e-6)
    slope = f(x, bumped)
    var i = 0
    while i < y.length:
      grid = _put(grid, i, j, (slope[i] - base[i]) / 1.0e-6)
      i = i + 1
    j = j + 1
  return grid

_simpson3(f: (double) -> double, a: double, b: double) -> double:
  mid = (a + b) / 2.0
  return (b - a) / 6.0 * (f(a) + 4.0 * f(mid) + f(b))

_adapt(f: (double) -> double, a: double, b: double, eps: double, whole: double, depth: int) -> double:
  return _adaptEstimate(f, a, b, eps, whole, depth).value

_gammaMarsaglia(random: Random, shape: double) -> double:
  d = shape - 1.0 / 3.0
  c = 1.0 / math.sqrt(9.0 * d)
  var guard = 0
  while guard < 1000:
    var z = normalSample(random)
    var v = 1.0 + c * z
    if v > 0.0:
      v = v * v * v
      var u = random.nextDouble()
      if u == 0.0: u = 1.0e-16
      if math.log(u) < 0.5 * z * z + d * (1.0 - v + math.log(v)): return d * v
    guard = guard + 1
  throw "gammaSample did not converge"

_ranks(values: List<double>) -> List<double>:
  var order = _zeroInts(values.length)
  var i = 0
  while i < values.length:
    order = _setInt(order, i, i)
    i = i + 1
  i = 1
  while i < order.length:
    var j = i
    while j > 0 and values[order[j]] < values[order[j - 1]]:
      order = _swapInts(order, j, j - 1)
      j = j - 1
    i = i + 1
  var ranks = _zeroDoubles(values.length)
  i = 0
  while i < order.length:
    var j = i
    while j + 1 < order.length and values[order[j + 1]] == values[order[i]]:
      j = j + 1
    average = (((i + 1) + (j + 1)) to double) / 2.0
    var k = i
    while k <= j:
      ranks = _setAt(ranks, order[k], average)
      k = k + 1
    i = j + 1
  return ranks

_residualJacobian(
    residual: (List<double>) -> List<double>,
    p: List<double>) -> List<List<double>>:
  base = residual(p)
  var grid = _filled(base.length, p.length, 0.0)
  var j = 0
  while j < p.length:
    bumped = _setAt(p, j, p[j] + 1.0e-6)
    shifted = residual(bumped)
    var i = 0
    while i < base.length:
      grid = _put(grid, i, j, (shifted[i] - base[i]) / 1.0e-6)
      i = i + 1
    j = j + 1
  return grid

_gram(rows: List<List<double>>) -> List<List<double>>:
  width = rows[0].length
  var made = _filled(width, width, 0.0)
  var c = 0
  while c < width:
    var d = 0
    while d < width:
      var total = 0.0
      for row in rows:
        total = total + row[c] * row[d]
      made = _put(made, c, d, total)
      d = d + 1
    c = c + 1
  return made

_applyTranspose(rows: List<List<double>>, values: List<double>) -> List<double>:
  width = rows[0].length
  made: List<double> = []
  var c = 0
  while c < width:
    var total = 0.0
    var r = 0
    while r < rows.length:
      total = total + rows[r][c] * values[r]
      r = r + 1
    made.add(total)
    c = c + 1
  return made

_chirp(index: int, n: int, sign: double) -> Complex:
  angle = sign * math.pi * (index to double) * (index to double) / (n to double)
  return Complex.polar(1.0, angle)

_chirpTransform(values: List<Complex>, sign: double) -> List<Complex>:
  n = values.length
  if n < 1: throw "fft needs a positive length"
  if _powerOfTwo(n): return _transform(values, sign)
  var m = 1
  while m < 2 * n - 1:
    m = m * 2
  var a: List<Complex> = []
  var i = 0
  while i < m:
    if i < n: a.add(values[i] * _chirp(i, n, sign))
    else: a.add(Complex(real: 0.0, imag: 0.0))
    i = i + 1
  var b: List<Complex> = []
  i = 0
  while i < m:
    b.add(Complex(real: 0.0, imag: 0.0))
    i = i + 1
  b = _setC(b, 0, _chirp(0, n, 0.0 - sign))
  var k = 1
  while k < n:
    cw = _chirp(k, n, 0.0 - sign)
    b = _setC(b, k, cw)
    b = _setC(b, m - k, cw)
    k = k + 1
  fa = _transform(a, 0.0 - 1.0)
  fb = _transform(b, 0.0 - 1.0)
  var prod: List<Complex> = []
  i = 0
  while i < m:
    prod.add(fa[i] * fb[i])
    i = i + 1
  conv = _transform(prod, 1.0)
  made: List<Complex> = []
  k = 0
  while k < n:
    var item = conv[k] * _chirp(k, n, sign)
    if sign > 0.0: item = item.scale(1.0 / (n to double))
    made.add(item)
    k = k + 1
  return made

# Overflow-safe modular addition for canonical residues.
_addMod(a: int, b: int, modulus: int) -> int:
  if a >= modulus - b: return a - (modulus - b)
  return a + b

_mulMod(a: int, b: int, modulus: int) -> int:
  var left = a % modulus
  var right = b % modulus
  var total = 0
  while right > 0:
    if right % 2 == 1: total = _addMod(total, left, modulus)
    right = right ~/ 2
    if right > 0: left = _addMod(left, left, modulus)
  return total

_checkedMultiply(a: int, b: int) -> int:
  largest = _maxInt()
  smallest = _minInt()
  if a > 0:
    if b > 0 and a > largest ~/ b: throw "integer result is outside int range"
    if b < 0 and b < smallest ~/ a: throw "integer result is outside int range"
  if a < 0:
    if b > 0 and a < smallest ~/ b: throw "integer result is outside int range"
    if b < 0 and a < largest ~/ b: throw "integer result is outside int range"
  return a * b

_checkedAdd(a: int, b: int) -> int:
  if b > 0 and a > _maxInt() - b: throw "integer result is outside int range"
  if b < 0 and a < _minInt() - b: throw "integer result is outside int range"
  return a + b

_logChoose(n: int, k: int) -> double:
  return logGamma((n to double) + 1.0) - logGamma((k to double) + 1.0) - logGamma(((n - k) to double) + 1.0)

# Schlaefli integrals avoid catastrophic cancellation of large-argument series.
_besselPieces(nu: double, x: double) -> int:
  if not _finite(x) or not _finite(nu) or _abs(nu) > 10000.0 or x > 10000.0:
    throw "Bessel argument or order exceeds the numerical work limit"
  var pieces = ((x + _abs(nu)) * 32.0).ceil
  if pieces < 1024: pieces = 1024
  if pieces % 2 == 1: pieces = pieces + 1
  return pieces

_besselLimit(nu: double, x: double) -> double:
  var limit = 1.0
  while limit < 710.0:
    if x * sinh(limit) - _abs(nu) * limit > x + 50.0: return limit
    limit = limit + 0.5
  throw "Bessel tail did not converge"

_besselJReal(nu: double, x: double) -> double:
  pieces = _besselPieces(nu, x)
  if x == 0.0:
    if nu == 0.0: return 1.0
    if nu > 0.0: return 0.0
    throw "besselJReal is undefined at zero for a negative order"
  if x <= 10.0:
    var term = math.exp(nu * math.log(x / 2.0) - logGamma(nu + 1.0))
    if nu + 1.0 < 0.0 and math.sin(math.pi * (nu + 1.0)) < 0.0: term = 0.0 - term
    var total = term
    var k = 1
    while k <= 10000:
      term = term * (0.0 - (x / (2.0 * (k to double))) * (x / (2.0 * ((k to double) + nu))))
      total = total + term
      if _abs(term) <= 1.0e-16 * _abs(total): return total
      k = k + 1
    throw "Bessel series did not converge"
  angular = simpson((t: double) -> math.cos(nu * t - x * math.sin(t)), 0.0, math.pi, pieces)
  if nu % 1.0 == 0.0: return angular / math.pi
  limit = _besselLimit(nu, x)
  tail = simpson((t: double) -> math.exp(0.0 - x * sinh(t) - nu * t), 0.0, limit, 2048)
  return (angular - math.sin(math.pi * nu) * tail) / math.pi

_besselIReal(nu: double, x: double) -> double:
  _besselPieces(nu, x)
  if x == 0.0:
    if nu == 0.0: return 1.0
    if nu > 0.0: return 0.0
    throw "Bessel I is undefined at zero for a negative order"
  var term = math.exp(nu * math.log(x / 2.0) - logGamma(nu + 1.0))
  var total = term
  var k = 1
  while k <= 10000:
    term = term * ((x / (2.0 * (k to double))) * (x / (2.0 * ((k to double) + nu))))
    total = total + term
    if _abs(total) > 1.7976931348623157e308: return total
    if _abs(term) <= 1.0e-16 * _abs(total): return total
    k = k + 1
  throw "Bessel I series did not converge"

_besselKReal(nu: double, x: double) -> double:
  _besselPieces(nu, x)
  limit = _besselLimit(nu, x)
  return simpson((t: double) -> 0.5 * (math.exp(nu * t - x * cosh(t)) + math.exp(0.0 - nu * t - x * cosh(t))), 0.0, limit, 2048)

_finite(x: double) -> bool:
  return x == x and _abs(x) <= 1.7976931348623157e308

_matrixScale(rows: List<List<double>>) -> double:
  var scale = 0.0
  for row in rows:
    for value in row:
      if not _finite(value): throw "matrix entries must be finite"
      if _abs(value) > scale: scale = _abs(value)
  return scale

_divideVector(values: List<double>, divisor: double) -> List<double>:
  made: List<double> = []
  for value in values:
    made.add(value / divisor)
  return made

_divideMatrix(rows: List<List<double>>, divisor: double) -> List<List<double>>:
  made: List<List<double>> = []
  for row in rows:
    made.add(_divideVector(row, divisor))
  return made

_orthogonalColumn(previous: List<List<double>>, count: int) -> List<double>:
  var k = 0
  while k < previous.length:
    var candidate = _zeroDoubles(previous.length)
    candidate = _setAt(candidate, k, 1.0)
    var j = 0
    while j < count:
      col = _column(previous, j)
      candidate = _axpy(candidate, col, 0.0 - dot(col, candidate))
      j = j + 1
    length = vectorLength(candidate)
    if length > 1.0e-10: return _divideVector(candidate, length)
    k = k + 1
  throw "could not complete an orthogonal basis"

_increasing(values: List<double>):
  var i = 1
  while i < values.length:
    if values[i] <= values[i - 1]: throw "coordinates must be strictly increasing"
    i = i + 1

_fractionAdd(left: Fraction, right: Fraction, subtract: bool) -> Fraction:
  common = gcd(left.denominator, right.denominator)
  a = _checkedMultiply(left.numerator, right.denominator ~/ common)
  var b = _checkedMultiply(right.numerator, left.denominator ~/ common)
  if subtract: b = _checkedMultiply(b, -1)
  top = _checkedAdd(a, b)
  trim = gcd(top, common)
  bottom = _checkedMultiply(left.denominator ~/ common, right.denominator ~/ trim)
  return fraction(top ~/ trim, bottom)

:: graph

# Discrete graph algorithms. Vertices are 0..<graph.length; graph[u] lists
# outgoing neighbors. Parallel edges and self-loops are allowed. All algorithms
# validate even unreachable edges, preserve inputs and return fresh lists.

# Reverse every directed edge, retaining isolated vertices and multiplicities.
# Time and auxiliary space O(V+E). Result rows follow source-vertex order.
# Example:
#   noEdges: List<int> = []
#   print transposeGraph([[1], [2], noEdges])
transposeGraph(graph: List<List<int>>) -> List<List<int>>:
  _validateGraph(graph)
  return _transposeGraph(graph)

# Directed, unweighted shortest distances; -1 means unreachable, source is 0.
# BFS runs in O(V+E) time with O(V) auxiliary space (excluding input).
# Example:
#   noEdges: List<int> = []
#   print bfsDistances([[1, 2], [3], [3], noEdges], 0)
bfsDistances(graph: List<List<int>>, source: int) -> List<int>:
  _validateGraph(graph)
  _graphVertex(graph, source, "source")
  states = _graphStates(graph.length, -1)
  states[source].mark = 0
  queue: List<int> = [source]
  var head = 0
  while head < queue.length:
    vertex = queue[head]
    head += 1
    for neighbor in graph[vertex]:
      if states[neighbor].mark == -1:
        states[neighbor].mark = states[vertex].mark + 1
        queue.add(neighbor)
  output: List<int> = []
  for cell in states:
    output.add(cell.mark)
  return output

# One shortest directed unweighted path, including both endpoints, or [].
# Ties follow input neighbor order. source==target returns [source].
# Time O(V+E), auxiliary space O(V). Invalid endpoints throw, even on [].
# Example:
#   noEdges: List<int> = []
#   print shortestUnweightedPath([[1, 2], [3], [3], noEdges], 0, 3)
shortestUnweightedPath(graph: List<List<int>>, source: int, target: int) -> List<int>:
  _validateGraph(graph)
  _graphVertex(graph, source, "source")
  _graphVertex(graph, target, "target")
  states = _graphStates(graph.length, -1)
  states[source].mark = source
  queue: List<int> = [source]
  var head = 0
  while head < queue.length and states[target].mark == -1:
    vertex = queue[head]
    head += 1
    for neighbor in graph[vertex]:
      if states[neighbor].mark == -1:
        states[neighbor].mark = vertex
        queue.add(neighbor)
  output: List<int> = []
  if states[target].mark == -1: return output
  backward: List<int> = []
  var current = target
  while current != source:
    backward.add(current)
    current = states[current].mark
  output.add(source)
  var index = backward.length - 1
  while index >= 0:
    output.add(backward[index])
    index -= 1
  return output

# Components after ignoring edge direction. Includes isolated vertices.
# Members and components are ordered by vertex/minimum vertex, respectively.
# Time and auxiliary space O(V+E). Empty graph returns [].
# Example:
#   noEdges: List<int> = []
#   print weaklyConnectedComponents([[1], noEdges, [3], noEdges])
weaklyConnectedComponents(graph: List<List<int>>) -> List<List<int>>:
  _validateGraph(graph)
  reverse = _transposeGraph(graph)
  states = _graphStates(graph.length, -1)
  var count = 0
  var root = 0
  while root < graph.length:
    if states[root].mark == -1:
      states[root].mark = count
      queue: List<int> = [root]
      var head = 0
      while head < queue.length:
        vertex = queue[head]
        head += 1
        for neighbor in graph[vertex]:
          if states[neighbor].mark == -1:
            states[neighbor].mark = count
            queue.add(neighbor)
        for neighbor in reverse[vertex]:
          if states[neighbor].mark == -1:
            states[neighbor].mark = count
            queue.add(neighbor)
      count += 1
    root += 1
  return _graphGroups(states, count)

# Maximal mutually reachable vertex groups (iterative Kosaraju).
# Canonical member/component ordering matches weaklyConnectedComponents.
# Time and auxiliary space O(V+E); no recursive DFS stack. Empty returns [].
# Example:
#   noEdges: List<int> = []
#   print stronglyConnectedComponents([[1], [0, 2], noEdges])
stronglyConnectedComponents(graph: List<List<int>>) -> List<List<int>>:
  _validateGraph(graph)
  states = _graphStates(graph.length, -1)
  finished: List<int> = []
  var root = 0
  while root < graph.length:
    if states[root].mark == -1:
      states[root].mark = 0
      stack: List<int> = [root]
      while stack.length > 0:
        vertex = stack.last
        cell = states[vertex]
        if cell.next < graph[vertex].length:
          neighbor = graph[vertex][cell.next]
          cell.next += 1
          if states[neighbor].mark == -1:
            states[neighbor].mark = 0
            stack.add(neighbor)
        else:
          finished.add(stack.removeLast())
    root += 1
  reverse = _transposeGraph(graph)
  labels = _graphStates(graph.length, -1)
  var count = 0
  var index = finished.length - 1
  while index >= 0:
    start = finished[index]
    if labels[start].mark == -1:
      labels[start].mark = count
      stack: List<int> = [start]
      while stack.length > 0:
        vertex = stack.removeLast()
        for neighbor in reverse[vertex]:
          if labels[neighbor].mark == -1:
            labels[neighbor].mark = count
            stack.add(neighbor)
      count += 1
    index -= 1
  return _graphGroups(labels, count)

# A topological vertex order (Kahn FIFO). Throws on any directed cycle.
# Initial zero-indegree vertices are queued in ascending order; later ties
# follow input adjacency order. Does not promise the lexicographically least
# order. Duplicate edges count separately. O(V+E) time, O(V) auxiliary space.
# Example:
#   noEdges: List<int> = []
#   print topologicalSort([[2], [2], [3], noEdges])
topologicalSort(graph: List<List<int>>) -> List<int>:
  _validateGraph(graph)
  states = _graphStates(graph.length, 0)
  for row in graph:
    for neighbor in row:
      states[neighbor].mark += 1
  queue: List<int> = []
  var vertex = 0
  while vertex < graph.length:
    if states[vertex].mark == 0: queue.add(vertex)
    vertex += 1
  var head = 0
  while head < queue.length:
    current = queue[head]
    head += 1
    for neighbor in graph[current]:
      states[neighbor].mark -= 1
      if states[neighbor].mark == 0: queue.add(neighbor)
  if queue.length != graph.length: throw "topologicalSort needs an acyclic graph"
  return queue

# Color the underlying undirected graph with 0/1. Each component's minimum
# vertex receives 0. Throws for odd cycles (including a self-loop), returns []
# for no vertices. O(V+E) time and auxiliary space. Input need not be symmetric.
# Example:
#   noEdges: List<int> = []
#   print bipartiteColoring([[1], [2], noEdges])
bipartiteColoring(graph: List<List<int>>) -> List<int>:
  _validateGraph(graph)
  reverse = _transposeGraph(graph)
  states = _graphStates(graph.length, -1)
  var root = 0
  while root < graph.length:
    if states[root].mark == -1:
      states[root].mark = 0
      queue: List<int> = [root]
      var head = 0
      while head < queue.length:
        vertex = queue[head]
        head += 1
        for neighbor in graph[vertex]:
          _graphColorNeighbor(states, queue, vertex, neighbor)
        for neighbor in reverse[vertex]:
          _graphColorNeighbor(states, queue, vertex, neighbor)
    root += 1
  output: List<int> = []
  for cell in states:
    output.add(cell.mark)
  return output

# Reflexive directed reachability: output[u][v] includes length-zero paths.
# O(V*(V+E)) time, O(V^2+V) auxiliary/output space. Empty returns [].
# Example:
#   noEdges: List<int> = []
#   print transitiveClosure([[1], [2], noEdges])[0]
transitiveClosure(graph: List<List<int>>) -> List<List<bool>>:
  _validateGraph(graph)
  output: List<List<bool>> = []
  var source = 0
  while source < graph.length:
    states = _graphStates(graph.length, -1)
    states[source].mark = 0
    queue: List<int> = [source]
    var head = 0
    while head < queue.length:
      vertex = queue[head]
      head += 1
      for neighbor in graph[vertex]:
        if states[neighbor].mark == -1:
          states[neighbor].mark = 0
          queue.add(neighbor)
    row: List<bool> = []
    for cell in states:
      row.add(cell.mark == 0)
    output.add(row)
    source += 1
  return output

# Mutable work cells avoid copying an entire list per vertex-cell change.
# They belong only to one algorithm call and never escape into public results.
class _GraphState:
  var mark: int = -1
  var next: int = 0

_graphStates(count: int, mark: int) -> List<_GraphState>:
  states: List<_GraphState> = []
  var index = 0
  while index < count:
    states.add(_GraphState(mark: mark))
    index += 1
  return states

_validateGraph(graph: List<List<int>>):
  for row in graph:
    for vertex in row:
      if vertex < 0 or vertex >= graph.length: throw "graph vertex out of range"

_graphVertex(graph: List<List<int>>, vertex: int, role: String):
  if vertex < 0 or vertex >= graph.length: throw "graph {role} out of range"

_transposeGraph(graph: List<List<int>>) -> List<List<int>>:
  output: List<List<int>> = []
  for row in graph:
    empty: List<int> = []
    output.add(empty)
  var vertex = 0
  while vertex < graph.length:
    for neighbor in graph[vertex]:
      output[neighbor].add(vertex)
    vertex += 1
  return output

_graphGroups(states: List<_GraphState>, count: int) -> List<List<int>>:
  buckets: List<List<int>> = []
  var index = 0
  while index < count:
    empty: List<int> = []
    buckets.add(empty)
    index += 1
  var vertex = 0
  while vertex < states.length:
    buckets[states[vertex].mark].add(vertex)
    vertex += 1
  output: List<List<int>> = []
  vertex = 0
  while vertex < states.length:
    bucket = buckets[states[vertex].mark]
    if bucket[0] == vertex: output.add(bucket)
    vertex += 1
  return output

_graphColorNeighbor(states: List<_GraphState>, queue: List<int>, vertex: int, neighbor: int):
  if states[neighbor].mark == -1:
    states[neighbor].mark = 1 - states[vertex].mark
    queue.add(neighbor)
  else:
    if states[neighbor].mark == states[vertex].mark:
      throw "bipartiteColoring needs a bipartite graph"

:: graph::weighted

# One finite-weight edge. Shortest-path APIs interpret it as source -> target;
# minimumSpanningForest interprets the same pair as an undirected edge.
value class WeightedEdge:
  source: int
  target: int
  weight: double

# A shortest-path result. Infinity denotes an unreachable vertex; predecessor
# indices and distances are fresh, mutable lists (not immutable object graphs).
value class ShortestPaths:
  source: int
  distances: List<double>
  predecessors: List<int>

  # A fresh endpoint-inclusive path, or [] if target is unreachable. Work is
  # O(V). Reject invalid targets or corrupted predecessor chains explicitly.
  pathTo(target: int) -> List<int>:
    if target < 0 or target >= distances.length: throw "path target out of range"
    if source < 0 or source >= distances.length or predecessors.length != distances.length:
      throw "ShortestPaths has invalid state"
    if distances[target] == 1.0 / 0.0:
      empty: List<int> = []
      return empty
    if not _finite(distances[target]): throw "ShortestPaths has invalid state"
    backward: List<int> = []
    var current = target
    while current != source:
      if current < 0 or current >= distances.length or backward.length >= distances.length:
        throw "ShortestPaths has invalid state"
      backward.add(current)
      current = predecessors[current]
    output: List<int> = [source]
    var index = backward.length - 1
    while index >= 0:
      output.add(backward[index])
      index -= 1
    return output

# Minimum spanning forest, including isolated vertices in componentCount.
# Selected edge values retain their original orientation. The result list is
# fresh; edge values themselves contain only immutable primitive fields.
value class SpanningForest:
  vertexCount: int
  componentCount: int
  edges: List<WeightedEdge>
  weight: double

# Directed shortest paths for nonnegative finite weights. All edges, including
# unreachable ones, are validated. Ties settle the smallest vertex and keep the
# first predecessor that achieved a distance. Dense Dijkstra: O(V^2+E) time,
# O(V+E) auxiliary space. A non-finite working sum throws rather than masquerading
# as unreachable. Binary64 weights use strict comparisons, without an epsilon.
# Example:
#   edges = [WeightedEdge(source: 0, target: 1, weight: 2.0)]
#   print dijkstra(3, edges, 0).pathTo(1)
dijkstra(vertexCount: int, edges: List<WeightedEdge>, source: int) -> ShortestPaths:
  _validateWeightedGraph(vertexCount, edges)
  _weightedSource(vertexCount, source)
  for edge in edges:
    if edge.weight < 0.0: throw "dijkstra needs nonnegative weights"
  adjacency = _weightedAdjacency(vertexCount, edges, false)
  work = _weightedWork(vertexCount)
  work[source].distance = 0.0
  work[source].parent = source
  var step = 0
  while step < vertexCount:
    vertex = _weightedMinimum(work)
    if vertex == -1: break
    work[vertex].settled = true
    for index in adjacency[vertex]:
      edge = edges[index]
      if not work[edge.target].settled:
        candidate = _weightedSum(work[vertex].distance, edge.weight)
        if candidate < work[edge.target].distance:
          work[edge.target].distance = candidate
          work[edge.target].parent = vertex
    step += 1
  return _shortestPaths(source, work)

# Directed shortest paths with finite, possibly negative weights. A negative
# cycle reachable from source throws; an unreachable negative cycle is ignored.
# Edge order determines equal-distance ties. Bellman-Ford: O(V*E+V) time,
# O(V) auxiliary space. Reachable non-finite working sums throw. Cycle detection
# is for binary64 relaxation arithmetic; near-zero real-weight cycles can be
# ill-conditioned and are not certified by an arbitrary tolerance.
# Example:
#   edges = [WeightedEdge(source: 0, target: 1, weight: -2.0)]
#   print bellmanFord(2, edges, 0).distances
bellmanFord(vertexCount: int, edges: List<WeightedEdge>, source: int) -> ShortestPaths:
  _validateWeightedGraph(vertexCount, edges)
  _weightedSource(vertexCount, source)
  work = _weightedWork(vertexCount)
  work[source].distance = 0.0
  work[source].parent = source
  var pass = 1
  while pass < vertexCount:
    var changed = false
    for edge in edges:
      if _finite(work[edge.source].distance):
        candidate = _weightedSum(work[edge.source].distance, edge.weight)
        if candidate < work[edge.target].distance:
          work[edge.target].distance = candidate
          work[edge.target].parent = edge.source
          changed = true
    if not changed: break
    pass += 1
  for edge in edges:
    if _finite(work[edge.source].distance):
      candidate = _weightedSum(work[edge.source].distance, edge.weight)
      if candidate < work[edge.target].distance:
        throw "bellmanFord found a reachable negative cycle"
  return _shortestPaths(source, work)

# Undirected minimum spanning forest, accepting finite negative/zero weights,
# parallel edges, self-loops and disconnected inputs. Loops are never selected.
# Dense Prim: O(V^2+E) time and O(V+E) auxiliary space. Components start at their
# smallest unvisited vertex. Equal keys settle the smallest vertex and retain
# the first connecting edge. Empty input has zero weight and zero components.
# A non-finite accumulated forest weight throws.
# Example:
#   edges = [WeightedEdge(source: 0, target: 1, weight: 2.0)]
#   print minimumSpanningForest(3, edges).componentCount
minimumSpanningForest(vertexCount: int, edges: List<WeightedEdge>) -> SpanningForest:
  _validateWeightedGraph(vertexCount, edges)
  adjacency = _weightedAdjacency(vertexCount, edges, true)
  work = _weightedWork(vertexCount)
  selected: List<WeightedEdge> = []
  var components = 0
  var total = 0.0
  var step = 0
  while step < vertexCount:
    var vertex = _weightedMinimum(work)
    if vertex == -1:
      var root = 0
      while root < vertexCount:
        if not work[root].settled:
          vertex = root
          work[root].distance = 0.0
          components += 1
          break
        root += 1
    work[vertex].settled = true
    if work[vertex].edgeIndex >= 0:
      edge = edges[work[vertex].edgeIndex]
      selected.add(edge)
      total = _weightedSum(total, edge.weight)
    for index in adjacency[vertex]:
      edge = edges[index]
      var neighbor = edge.target
      if neighbor == vertex: neighbor = edge.source
      if not work[neighbor].settled and edge.weight < work[neighbor].distance:
        work[neighbor].distance = edge.weight
        work[neighbor].parent = vertex
        work[neighbor].edgeIndex = index
    step += 1
  return SpanningForest(vertexCount: vertexCount, componentCount: components, edges: selected, weight: total)

class _WeightedState:
  var distance: double = 0.0
  var parent: int = -1
  var edgeIndex: int = -1
  var settled: bool = false

_validateWeightedGraph(vertexCount: int, edges: List<WeightedEdge>):
  if vertexCount < 0: throw "weighted graph vertex count must be nonnegative"
  for edge in edges:
    if edge.source < 0 or edge.source >= vertexCount or edge.target < 0 or edge.target >= vertexCount:
      throw "weighted graph vertex out of range"
    if not _finite(edge.weight): throw "weighted graph needs finite weights"

_weightedSource(vertexCount: int, source: int):
  if source < 0 or source >= vertexCount: throw "weighted graph source out of range"

_weightedWork(vertexCount: int) -> List<_WeightedState>:
  work: List<_WeightedState> = []
  var index = 0
  while index < vertexCount:
    cell = _WeightedState()
    cell.distance = 1.0 / 0.0
    work.add(cell)
    index += 1
  return work

_weightedMinimum(work: List<_WeightedState>) -> int:
  var selected = -1
  var best = 1.0 / 0.0
  var index = 0
  while index < work.length:
    if not work[index].settled and work[index].distance < best:
      selected = index
      best = work[index].distance
    index += 1
  return selected

_weightedSum(left: double, right: double) -> double:
  total = left + right
  if not _finite(total): throw "weighted graph sum overflow"
  return total

_weightedAdjacency(vertexCount: int, edges: List<WeightedEdge>, undirected: bool) -> List<List<int>>:
  adjacency: List<List<int>> = []
  var vertex = 0
  while vertex < vertexCount:
    row: List<int> = []
    adjacency.add(row)
    vertex += 1
  var index = 0
  while index < edges.length:
    edge = edges[index]
    adjacency[edge.source].add(index)
    if undirected and edge.target != edge.source: adjacency[edge.target].add(index)
    index += 1
  return adjacency

_shortestPaths(source: int, work: List<_WeightedState>) -> ShortestPaths:
  distances: List<double> = []
  parents: List<int> = []
  for cell in work:
    distances.add(cell.distance)
    parents.add(cell.parent)
  return ShortestPaths(source: source, distances: distances, predecessors: parents)

:: graph::flow

# One directed capacity. Zero is allowed. A self-loop is validated and carries
# no source-sink flow. Parallel edges stay separate.
value class FlowEdge:
  source: int
  target: int
  capacity: int

# An integral maximum flow and one minimum cut. flows follows the input edge
# order. sourceSide is the residual source component, sorted, and its leaving
# capacity equals value. Lists are fresh; this is not deep immutability.
value class MaximumFlow:
  source: int
  sink: int
  value: int
  flows: List<int>
  sourceSide: List<int>

# Integral maximum flow by Edmonds-Karp. Capacities are nonnegative ints.
# Every edge is validated before search. Source and sink must differ. The
# reachable residual set is a minimum cut. Work guard: at most 64 vertices and
# 1024 edges; this is a complexity bound, not a mathematical restriction.
# A sum that does not fit the platform int throws. Inputs are not mutated.
# Example:
#   edges = [FlowEdge(source: 0, target: 1, capacity: 5)]
#   print maximumFlow(2, edges, 0, 1).value
maximumFlow(vertexCount: int, edges: List<FlowEdge>, source: int, sink: int) -> MaximumFlow:
  if vertexCount < 0: throw "flow vertex count must be nonnegative"
  for edge in edges:
    if edge.source < 0 or edge.source >= vertexCount or edge.target < 0 or edge.target >= vertexCount:
      throw "flow vertex out of range"
    if edge.capacity < 0: throw "flow capacity must be nonnegative"
  if vertexCount > 64 or edges.length > 1024: throw "flow exceeds the work limit"
  if source < 0 or source >= vertexCount: throw "flow source out of range"
  if sink < 0 or sink >= vertexCount: throw "flow sink out of range"
  if source == sink: throw "flow source and sink must differ"
  sent = _flowSlots(edges.length, 0)
  net = _flowNetwork(vertexCount, edges)
  var total = 0
  while true:
    path = _flowPath(vertexCount, net, source, sink)
    if path.length == 0: break
    var bottleneck = net.arcs[path[0]].cap
    for index in path:
      if net.arcs[index].cap < bottleneck: bottleneck = net.arcs[index].cap
    if bottleneck <= 0: throw "maximumFlow has invalid state"
    for index in path:
      arc = net.arcs[index]
      arc.cap = arc.cap - bottleneck
      net.arcs[arc.rev].cap = _checkedAdd(net.arcs[arc.rev].cap, bottleneck)
      sent[arc.origin].value = _checkedAdd(sent[arc.origin].value, bottleneck * arc.sign)
    total = _checkedAdd(total, bottleneck)
  flows = _flowInts(sent)
  _flowCertify(vertexCount, edges, source, sink, flows, total)
  side = _flowSourceSide(vertexCount, net, edges, source, sink, total)
  return MaximumFlow(source: source, sink: sink, value: total, flows: flows, sourceSide: side)

class _FlowArc:
  var to: int = 0
  var rev: int = 0
  var origin: int = 0
  var cap: int = 0
  var sign: int = 1

class _FlowSlot:
  var value: int = 0

class _FlowNet:
  arcs: List<_FlowArc>
  adjacency: List<List<int>>

_flowSlots(count: int, fill: int) -> List<_FlowSlot>:
  made: List<_FlowSlot> = []
  var index = 0
  while index < count:
    slot = _FlowSlot()
    slot.value = fill
    made.add(slot)
    index += 1
  return made

_flowInts(slots: List<_FlowSlot>) -> List<int>:
  made: List<int> = []
  for slot in slots:
    made.add(slot.value)
  return made

_flowRows(count: int) -> List<List<int>>:
  rows: List<List<int>> = []
  var index = 0
  while index < count:
    row: List<int> = []
    rows.add(row)
    index += 1
  return rows

_flowNetwork(vertexCount: int, edges: List<FlowEdge>) -> _FlowNet:
  arcs: List<_FlowArc> = []
  adjacency = _flowRows(vertexCount)
  var index = 0
  while index < edges.length:
    edge = edges[index]
    if edge.source != edge.target:
      forward = arcs.length
      go = _FlowArc()
      go.to = edge.target
      go.rev = forward + 1
      go.origin = index
      go.cap = edge.capacity
      go.sign = 1
      back = _FlowArc()
      back.to = edge.source
      back.rev = forward
      back.origin = index
      back.cap = 0
      back.sign = -1
      arcs.add(go)
      arcs.add(back)
      adjacency[edge.source].add(forward)
      adjacency[edge.target].add(forward + 1)
    index += 1
  return _FlowNet(arcs: arcs, adjacency: adjacency)

_flowPath(vertexCount: int, net: _FlowNet, source: int, sink: int) -> List<int>:
  parent = _flowSlots(vertexCount, -1)
  parent[source].value = -2
  queue: List<int> = [source]
  var head = 0
  var found = false
  while head < queue.length and not found:
    vertex = queue[head]
    head += 1
    for arcIndex in net.adjacency[vertex]:
      arc = net.arcs[arcIndex]
      if arc.cap > 0 and parent[arc.to].value == -1:
        parent[arc.to].value = arcIndex
        if arc.to == sink: found = true
        else: queue.add(arc.to)
  empty: List<int> = []
  if not found: return empty
  path: List<int> = []
  var current = sink
  while current != source:
    if path.length >= vertexCount or current < 0 or current >= vertexCount: throw "maximumFlow has invalid state"
    arcIndex = parent[current].value
    if arcIndex < 0: throw "maximumFlow has invalid state"
    path.add(arcIndex)
    current = net.arcs[net.arcs[arcIndex].rev].to
  return path

_flowCertify(vertexCount: int, edges: List<FlowEdge>, source: int, sink: int, flows: List<int>, total: int):
  balance = _flowSlots(vertexCount, 0)
  var index = 0
  while index < edges.length:
    edge = edges[index]
    flow = flows[index]
    if flow < 0 or flow > edge.capacity: throw "maximumFlow has invalid state"
    if edge.source == edge.target:
      if flow != 0: throw "maximumFlow has invalid state"
    else:
      balance[edge.source].value = _checkedAdd(balance[edge.source].value, flow)
      balance[edge.target].value = _checkedAdd(balance[edge.target].value, 0 - flow)
    index += 1
  if balance[source].value != total or balance[sink].value != 0 - total: throw "maximumFlow has invalid state"
  var vertex = 0
  while vertex < vertexCount:
    if vertex != source and vertex != sink and balance[vertex].value != 0: throw "maximumFlow has invalid state"
    vertex += 1

_flowSourceSide(vertexCount: int, net: _FlowNet, edges: List<FlowEdge>, source: int, sink: int, total: int) -> List<int>:
  seen = _flowSlots(vertexCount, 0)
  seen[source].value = 1
  queue: List<int> = [source]
  var head = 0
  while head < queue.length:
    vertex = queue[head]
    head += 1
    for arcIndex in net.adjacency[vertex]:
      arc = net.arcs[arcIndex]
      if arc.cap > 0 and seen[arc.to].value == 0:
        seen[arc.to].value = 1
        queue.add(arc.to)
  if seen[sink].value != 0: throw "maximumFlow has invalid state"
  side: List<int> = []
  var vertex = 0
  while vertex < vertexCount:
    if seen[vertex].value != 0: side.add(vertex)
    vertex += 1
  var leaving = 0
  var index = 0
  while index < edges.length:
    edge = edges[index]
    if edge.source != edge.target and seen[edge.source].value != 0 and seen[edge.target].value == 0:
      leaving = _checkedAdd(leaving, edge.capacity)
    index += 1
  if leaving != total: throw "maximumFlow has invalid state"
  return side

:: graph::matching

# One left-to-right incidence. Parallel copies do not raise the matching size.
value class MatchEdge:
  left: int
  right: int

# A maximum cardinality matching. Unmatched entries are -1. Mate lists are
# fresh and consistent: leftMate[left] == right exactly when rightMate[right] == left.
value class Matching:
  size: int
  leftMate: List<int>
  rightMate: List<int>

# Maximum bipartite cardinality by augmenting paths. Endpoints are validated
# before search. Ties follow increasing left index and input edge order.
# Work guard: at most 200 vertices on a side and 2000 edges. Inputs are not mutated.
# Example:
#   edges = [MatchEdge(left: 0, right: 0)]
#   print maximumMatching(1, 1, edges).size
maximumMatching(leftCount: int, rightCount: int, edges: List<MatchEdge>) -> Matching:
  if leftCount < 0 or rightCount < 0: throw "matching side count must be nonnegative"
  for edge in edges:
    if edge.left < 0 or edge.left >= leftCount or edge.right < 0 or edge.right >= rightCount:
      throw "matching vertex out of range"
  if leftCount > 200 or rightCount > 200 or edges.length > 2000: throw "matching exceeds the work limit"
  adjacency = _flowRows(leftCount)
  for edge in edges:
    adjacency[edge.left].add(edge.right)
  pairL = _flowSlots(leftCount, -1)
  pairR = _flowSlots(rightCount, -1)
  var augmented = true
  while augmented:
    augmented = _matchAugment(adjacency, pairL, pairR)
  var size = 0
  for slot in pairL:
    if slot.value >= 0: size += 1
  _matchCertify(adjacency, pairL, pairR, size)
  return Matching(size: size, leftMate: _flowInts(pairL), rightMate: _flowInts(pairR))

_matchAugment(adjacency: List<List<int>>, pairL: List<_FlowSlot>, pairR: List<_FlowSlot>) -> bool:
  seen = _flowSlots(pairL.length, 0)
  queue: List<int> = []
  var left = 0
  while left < pairL.length:
    if pairL[left].value < 0:
      seen[left].value = 1
      queue.add(left)
    left += 1
  parent = _flowSlots(pairR.length, -1)
  var head = 0
  var found = -1
  while head < queue.length and found < 0:
    vertex = queue[head]
    head += 1
    for right in adjacency[vertex]:
      if pairL[vertex].value == right or parent[right].value >= 0: continue
      parent[right].value = vertex
      if pairR[right].value < 0:
        found = right
      else:
        mate = pairR[right].value
        if seen[mate].value == 0:
          seen[mate].value = 1
          queue.add(mate)
  if found < 0: return false
  var right = found
  while right >= 0:
    left = parent[right].value
    if left < 0: throw "maximumMatching has invalid state"
    previous = pairL[left].value
    pairL[left].value = right
    pairR[right].value = left
    right = previous
  return true

_matchCertify(adjacency: List<List<int>>, pairL: List<_FlowSlot>, pairR: List<_FlowSlot>, size: int):
  var matched = 0
  var left = 0
  while left < pairL.length:
    right = pairL[left].value
    if right >= 0:
      if right >= pairR.length or pairR[right].value != left: throw "maximumMatching has invalid state"
      var linked = false
      for neighbor in adjacency[left]:
        if neighbor == right: linked = true
      if not linked: throw "maximumMatching has invalid state"
      matched += 1
    left += 1
  if matched != size: throw "maximumMatching has invalid state"
  var right = 0
  while right < pairR.length:
    left = pairR[right].value
    if left >= 0 and (left >= pairL.length or pairL[left].value != right): throw "maximumMatching has invalid state"
    right += 1

:: exact

# Parse an arbitrary-precision integer using Dart's BigInt literal grammar.
# Invalid text throws FormatException. No conversion through int or double.
# Example:
#   print bigInt("1208925819614629174706176")
bigInt(text: String) -> BigInt = BigInt.parse(text)

# Exact rational storage. Use bigFraction() for canonical normalization; this
# raw value constructor intentionally stores its arguments as given, just as
# Fraction does. Arithmetic rejects a zero denominator and normalizes results.
value class BigFraction:
  numerator: BigInt required
  denominator: BigInt required

  operator +(other: BigFraction) -> BigFraction:
    return _bigFractionAdd(this, other, false)

  operator -(other: BigFraction) -> BigFraction:
    return _bigFractionAdd(this, other, true)

  operator *(other: BigFraction) -> BigFraction:
    _checkBigFraction(this)
    _checkBigFraction(other)
    a = numerator.gcd(other.denominator)
    b = other.numerator.gcd(denominator)
    return bigFraction((numerator ~/ a) * (other.numerator ~/ b), (denominator ~/ b) * (other.denominator ~/ a))

  operator /(other: BigFraction) -> BigFraction:
    _checkBigFraction(this)
    _checkBigFraction(other)
    if other.numerator == BigInt.zero: throw "division by zero"
    a = numerator.gcd(other.numerator)
    b = denominator.gcd(other.denominator)
    return bigFraction((numerator ~/ a) * (other.denominator ~/ b), (denominator ~/ b) * (other.numerator ~/ a))

  negated() -> BigFraction = bigFraction(-numerator, denominator)

  reciprocal() -> BigFraction = bigFraction(denominator, numerator)

  compareTo(other: BigFraction) -> int:
    left = bigFraction(numerator, denominator)
    right = bigFraction(other.numerator, other.denominator)
    difference = left.numerator * right.denominator - right.numerator * left.denominator
    return difference.sign

  toString() -> String = "{numerator}/{denominator}"

# Canonical exact rational: reduced terms, positive denominator, zero as 0/1.
# No fixed precision limit; operations are limited by available memory.
# Example:
#   print bigFraction(bigInt("-12"), bigInt("-18"))
bigFraction(numerator: BigInt, denominator: BigInt) -> BigFraction:
  if denominator == BigInt.zero: throw "bigFraction needs a non-zero denominator"
  divisor = numerator.gcd(denominator)
  var top = numerator ~/ divisor
  var bottom = denominator ~/ divisor
  if bottom < BigInt.zero:
    top = -top
    bottom = -bottom
  return BigFraction(numerator: top, denominator: bottom)

# Exact factorial, with 0! = 1. Work guard: 0 <= n <= 100000.
# Example:
#   print bigFactorial(30)
bigFactorial(n: int) -> BigInt:
  _bigWorkLimit(n, 100000, "bigFactorial")
  var total = BigInt.one
  var index = 2
  while index <= n:
    total = total * BigInt.from(index)
    index += 1
  return total

# Exact binomial coefficient; k>n returns zero, as combinations() does.
# Work guard: 0 <= n <= 100000; k must be nonnegative.
# Example:
#   print bigCombinations(100, 50)
bigCombinations(n: int, k: int) -> BigInt:
  _bigWorkLimit(n, 100000, "bigCombinations")
  if k < 0: throw "bigCombinations needs nonnegative k"
  if k > n: return BigInt.zero
  var count = k
  if n - k < count: count = n - k
  var total = BigInt.one
  var index = 1
  while index <= count:
    total = (total * BigInt.from(n - count + index)) ~/ BigInt.from(index)
    index += 1
  return total

# Exact Fibonacci with F0=0, F1=1, using fast doubling (O(log n) big-integer
# steps). Work guard: 0 <= n <= 1000000; bit-operation cost grows with output.
# Example:
#   print bigFibonacci(100)
bigFibonacci(n: int) -> BigInt:
  _bigWorkLimit(n, 1000000, "bigFibonacci")
  var left = BigInt.zero
  var right = BigInt.one
  var bit = 1
  while bit <= n ~/ 2:
    bit *= 2
  while bit > 0:
    even = left * (BigInt.from(2) * right - left)
    odd = left * left + right * right
    if (n & bit) == 0:
      left = even
      right = odd
    else:
      left = odd
      right = even + odd
    bit = bit ~/ 2
  return left

# Exact Catalan number Cn = choose(2n,n)/(n+1). Work guard: n <= 50000.
# Example:
#   print bigCatalan(30)
bigCatalan(n: int) -> BigInt:
  _bigWorkLimit(n, 50000, "bigCatalan")
  return bigCombinations(2 * n, n) ~/ BigInt.from(n + 1)

# Exact set-partition count S(n,k), with S(0,0)=1 and k>n giving zero.
# Descending recurrence uses O(k) storage. Guards: n<=10000, n*k<=1000000.
# Example:
#   print bigStirlingSecond(20, 10)
bigStirlingSecond(n: int, k: int) -> BigInt:
  _bigWorkLimit(n, 10000, "bigStirlingSecond")
  if k < 0: throw "bigStirlingSecond needs nonnegative k"
  if k > n: return BigInt.zero
  if n * k > 1000000: throw "bigStirlingSecond work limit exceeded"
  row = _bigCells(k + 1)
  row[0].value = BigInt.one
  var index = 1
  while index <= n:
    var column = k
    if column > index: column = index
    while column > 0:
      row[column].value = BigInt.from(column) * row[column].value + row[column - 1].value
      column -= 1
    row[0].value = BigInt.zero
    index += 1
  return row[k].value

# Exact Bell number using the Bell triangle. Guards: 0<=n<=1000.
# O(n^2) big-integer additions and O(n) storage, not fixed-cost arithmetic.
# Example:
#   print bigBell(20)
bigBell(n: int) -> BigInt:
  _bigWorkLimit(n, 1000, "bigBell")
  row = _bigCells(n + 1)
  row[0].value = BigInt.one
  var index = 1
  while index <= n:
    var previous = row[0].value
    row[0].value = row[index - 1].value
    var column = 1
    while column <= index:
      saved = row[column].value
      row[column].value = row[column - 1].value + previous
      previous = saved
      column += 1
    index += 1
  return row[0].value

# Exact unrestricted integer partition count, p(0)=1, via coin-change DP.
# O(n^2) big-integer additions, O(n) storage. Guards: 0<=n<=2000.
# Example:
#   print bigPartitions(100)
bigPartitions(n: int) -> BigInt:
  _bigWorkLimit(n, 2000, "bigPartitions")
  row = _bigCells(n + 1)
  row[0].value = BigInt.one
  var part = 1
  while part <= n:
    var total = part
    while total <= n:
      row[total].value = row[total].value + row[total - part].value
      total += 1
    part += 1
  return row[n].value

class _BigCell:
  var value: BigInt required

_bigCells(count: int) -> List<_BigCell>:
  row: List<_BigCell> = []
  var index = 0
  while index < count:
    row.add(_BigCell(value: BigInt.zero))
    index += 1
  return row

_bigWorkLimit(n: int, limit: int, operation: String):
  if n < 0 or n > limit: throw "{operation} needs n from 0 through {limit}"

_checkBigFraction(value: BigFraction):
  if value.denominator == BigInt.zero: throw "bigFraction needs a non-zero denominator"

_bigFractionAdd(left: BigFraction, right: BigFraction, subtract: bool) -> BigFraction:
  _checkBigFraction(left)
  _checkBigFraction(right)
  common = left.denominator.gcd(right.denominator)
  leftScale = right.denominator ~/ common
  rightScale = left.denominator ~/ common
  var top = left.numerator * leftScale
  if subtract: top = top - right.numerator * rightScale
  else: top = top + right.numerator * rightScale
  return bigFraction(top, left.denominator * leftScale)

:: exact::decimal

# A base-10 fixed scale stored as a signed BigInt. No conversion through double.
# [rounding] is one of halfEven, halfAway, floor, ceiling, towardZero.
# Scale is the number of digits after the decimal point, from 0 through 100.
value class Decimal:
  digits: BigInt required
  scale: int required

# Parse decimal text at [scale], rounding extra digits by the named mode.
# Example:
#   print decimal("1.50", 2, "halfEven").digits
decimal(text: String, scale: int, rounding: String) -> Decimal:
  _decimalScale(scale)
  _decimalMode(rounding)
  if text.isEmpty: throw "decimal text is not a number"
  var index = 0
  var negative = false
  if text[0] == "+": index = 1
  else:
    if text[0] == "-":
      negative = true
      index = 1
  if index >= text.length: throw "decimal text is not a number"
  var whole = BigInt.zero
  var fracPart = BigInt.zero
  var fractionDigits = 0
  var sawDigit = false
  var sawDot = false
  while index < text.length:
    ch = text[index]
    if ch == ".":
      if sawDot: throw "decimal text is not a number"
      sawDot = true
    else:
      fractionDigits = _decimalAbsorb(ch, sawDot, fractionDigits)
      if sawDot: fracPart = fracPart * BigInt.from(10) + BigInt.from(_decimalValue(ch))
      else: whole = whole * BigInt.from(10) + BigInt.from(_decimalValue(ch))
      sawDigit = true
    index += 1
  if not sawDigit: throw "decimal text is not a number"
  var digits = whole * _decimalTen(fractionDigits) + fracPart
  if fractionDigits > scale:
    digits = _decimalRound(digits, _decimalTen(fractionDigits - scale), rounding)
  else:
    digits = digits * _decimalTen(scale - fractionDigits)
  if negative: digits = BigInt.zero - digits
  return Decimal(digits: digits, scale: scale)

# Exact sum. The result scale is the larger input scale.
decimalAdd(left: Decimal, right: Decimal) -> Decimal:
  _decimalPair(left, right)
  var scale = left.scale
  var a = left.digits
  var b = right.digits
  if right.scale > scale:
    a = a * _decimalTen(right.scale - scale)
    scale = right.scale
  else: b = b * _decimalTen(scale - right.scale)
  return Decimal(digits: a + b, scale: scale)

decimalSubtract(left: Decimal, right: Decimal) -> Decimal:
  return decimalAdd(left, Decimal(digits: BigInt.zero - right.digits, scale: right.scale))

# Exact product. Scales add, and the sum must stay within 100.
decimalMultiply(left: Decimal, right: Decimal) -> Decimal:
  _decimalPair(left, right)
  scale = left.scale + right.scale
  _decimalScale(scale)
  return Decimal(digits: left.digits * right.digits, scale: scale)

# Quotient stored at [scale] after the named rounding. The divisor must be nonzero.
decimalDivide(left: Decimal, right: Decimal, scale: int, rounding: String) -> Decimal:
  _decimalPair(left, right)
  _decimalScale(scale)
  _decimalMode(rounding)
  if right.digits == BigInt.zero: throw "division by zero"
  var numerator = left.digits * _decimalTen(scale + right.scale)
  var denominator = right.digits
  if denominator < BigInt.zero:
    numerator = BigInt.zero - numerator
    denominator = BigInt.zero - denominator
  else: numerator = numerator * _decimalTen(0)
  digits = _decimalRound(numerator, denominator * _decimalTen(left.scale), rounding)
  return Decimal(digits: digits, scale: scale)

_decimalScale(scale: int):
  if scale < 0 or scale > 100: throw "decimal scale is outside 0 through 100"

_decimalMode(rounding: String):
  if rounding == "halfEven" or rounding == "halfAway" or rounding == "floor" or rounding == "ceiling" or rounding == "towardZero": return
  throw "decimal rounding must be named"

_decimalTen(scale: int) -> BigInt:
  var power = BigInt.one
  var index = 0
  while index < scale:
    power = power * BigInt.from(10)
    index += 1
  return power

_decimalValue(ch: String) -> int:
  if ch == "0": return 0
  if ch == "1": return 1
  if ch == "2": return 2
  if ch == "3": return 3
  if ch == "4": return 4
  if ch == "5": return 5
  if ch == "6": return 6
  if ch == "7": return 7
  if ch == "8": return 8
  if ch == "9": return 9
  throw "decimal text is not a number"

_decimalAbsorb(ch: String, sawDot: bool, digits: int) -> int:
  _decimalValue(ch)
  if sawDot: return digits + 1
  return digits

_decimalPair(left: Decimal, right: Decimal):
  _decimalScale(left.scale)
  _decimalScale(right.scale)

_decimalRound(numerator: BigInt, denominator: BigInt, rounding: String) -> BigInt:
  if denominator <= BigInt.zero: throw "decimal rounding needs a positive divisor"
  quotient = numerator ~/ denominator
  var remainder = numerator - quotient * denominator
  if remainder < BigInt.zero: remainder = BigInt.zero - remainder
  if rounding == "towardZero": return quotient
  if rounding == "floor":
    if numerator < BigInt.zero and remainder != BigInt.zero: return quotient - BigInt.one
    return quotient
  if rounding == "ceiling":
    if numerator > BigInt.zero and remainder != BigInt.zero: return quotient + BigInt.one
    return quotient
  twice = remainder * BigInt.from(2)
  var bump = false
  if twice > denominator: bump = true
  if twice == denominator:
    if rounding == "halfAway": bump = true
    if rounding == "halfEven" and quotient % BigInt.from(2) != BigInt.zero: bump = true
  if not bump: return quotient
  if numerator >= BigInt.zero: return quotient + BigInt.one
  return quotient - BigInt.one

:: autodiff

# Forward-mode automatic differentiation: value + tangent*epsilon, epsilon^2=0.
# All operations require finite values/tangents and reject non-finite results.
# Use dualConstant for constants and dualVariable for a unit derivative seed.
value class Dual:
  value: double required
  tangent: double required

  operator +(other: Dual) -> Dual:
    _checkDual(this)
    _checkDual(other)
    return _dualResult(value + other.value, tangent + other.tangent)

  operator -(other: Dual) -> Dual:
    _checkDual(this)
    _checkDual(other)
    return _dualResult(value - other.value, tangent - other.tangent)

  operator -() -> Dual:
    _checkDual(this)
    return _dualResult(-value, -tangent)

  operator *(other: Dual) -> Dual:
    _checkDual(this)
    _checkDual(other)
    return _dualResult(value * other.value, tangent * other.value + value * other.tangent)

  operator /(other: Dual) -> Dual:
    _checkDual(this)
    _checkDual(other)
    if other.value == 0.0: throw "Dual division by zero"
    quotient = value / other.value
    slope = tangent / other.value - _dualProductOverSquare(value, other.tangent, other.value)
    return _dualResult(quotient, slope)

  exp() -> Dual:
    _checkDual(this)
    output = math.exp(value)
    return _dualResult(output, output * tangent)

  ln() -> Dual:
    _checkDual(this)
    if value <= 0.0: throw "Dual.ln needs a positive value"
    return _dualResult(math.log(value), tangent / value)

  sqrt() -> Dual:
    _checkDual(this)
    if value <= 0.0: throw "Dual.sqrt needs a positive value"
    output = math.sqrt(value)
    return _dualResult(output, tangent / (2.0 * output))

  sin() -> Dual:
    _checkDual(this)
    return _dualResult(math.sin(value), math.cos(value) * tangent)

  cos() -> Dual:
    _checkDual(this)
    return _dualResult(math.cos(value), -math.sin(value) * tangent)

  tan() -> Dual:
    _checkDual(this)
    cosine = math.cos(value)
    if cosine == 0.0: throw "Dual.tan is undefined at a pole"
    return _dualResult(math.tan(value), (tangent / cosine) / cosine)

  asin() -> Dual:
    _checkDual(this)
    if value <= -1.0 or value >= 1.0: throw "Dual.asin needs a value strictly between -1 and 1"
    return _dualResult(math.asin(value), tangent / math.sqrt((1.0 - value) * (1.0 + value)))

  acos() -> Dual:
    _checkDual(this)
    if value <= -1.0 or value >= 1.0: throw "Dual.acos needs a value strictly between -1 and 1"
    return _dualResult(math.acos(value), -tangent / math.sqrt((1.0 - value) * (1.0 + value)))

  atan() -> Dual:
    _checkDual(this)
    var slope = tangent / (1.0 + value * value)
    if _abs(value) > 1.0: slope = (tangent / value) / (value + 1.0 / value)
    return _dualResult(math.atan(value), slope)

  # Constant real exponent. Negative bases require an integer exponent. At
  # zero only nonnegative integer exponents are accepted; 0^0 follows Dart's
  # constant-one convention, while noninteger zero-base derivatives reject.
  pow(exponent: double) -> Dual:
    _checkDual(this)
    if not _finite(exponent): throw "Dual.pow needs a finite exponent"
    if exponent == 0.0: return _dualResult(1.0, 0.0)
    if value <= 0.0 and exponent != exponent.truncateToDouble():
      throw "Dual.pow needs an integer exponent at a nonpositive base"
    if value == 0.0:
      if exponent < 0.0: throw "Dual.pow has an undefined zero-base derivative"
      if exponent == 1.0: return _dualResult(0.0, tangent)
      return _dualResult(0.0, 0.0)
    output = math.pow(value, exponent) to double
    slope = _dualPowerSlope(value, exponent, tangent)
    return _dualResult(output, slope)

# A constant's derivative seed is zero.
dualConstant(value: double) -> Dual = _dualResult(value, 0.0)

# A variable's derivative seed is one.
dualVariable(value: double) -> Dual = _dualResult(value, 1.0)

# Evaluate f exactly once at a unit seed and return both value and derivative.
# The callback must use smooth Dual operations on the desired real domain.
# Example:
#   print evaluateDual((x: Dual) -> x * x, 3.0).tangent
evaluateDual(f: (Dual) -> Dual, x: double) -> Dual:
  output = f(dualVariable(x))
  _checkDual(output)
  return output

# First derivative by forward AD, not finite differences. One callback call.
# Example:
#   print autoDerivative((x: Dual) -> x.sin(), 0.0)
autoDerivative(f: (Dual) -> Dual, x: double) -> double:
  return evaluateDual(f, x).tangent

# Gradient in input-coordinate order. Evaluates the callback exactly n times,
# once per unit seed, and zero times for n=0. Inputs/seeds/results are fresh.
# A pure callback is required for a meaningful gradient across those calls.
autoGradient(f: (List<Dual>) -> Dual, point: List<double>) -> List<double>:
  _checkDualPoint(point)
  output: List<double> = []
  var column = 0
  while column < point.length:
    evaluated = f(_dualSeed(point, column))
    _checkDual(evaluated)
    output.add(evaluated.tangent)
    column += 1
  return output

# Jacobian rows index output components; columns index input coordinates.
# Evaluates f n times, or once when n=0 to discover the output dimension.
# A changing output length throws. No extra callback calls estimate a value.
autoJacobian(f: (List<Dual>) -> List<Dual>, point: List<double>) -> List<List<double>>:
  _checkDualPoint(point)
  output: List<List<double>> = []
  if point.length == 0:
    empty: List<Dual> = []
    evaluated = f(empty)
    for item in evaluated:
      _checkDual(item)
      row: List<double> = []
      output.add(row)
    return output
  var column = 0
  while column < point.length:
    evaluated = f(_dualSeed(point, column))
    if column != 0 and evaluated.length != output.length:
      throw "autoJacobian output shape changed"
    var index = 0
    while index < evaluated.length:
      _checkDual(evaluated[index])
      if column == 0:
        row: List<double> = []
        output.add(row)
      output[index].add(evaluated[index].tangent)
      index += 1
    column += 1
  return output

_checkDual(value: Dual):
  if not _finite(value.value) or not _finite(value.tangent):
    throw "Dual needs finite value and tangent"

_dualResult(value: double, tangent: double) -> Dual:
  if not _finite(value) or not _finite(tangent): throw "Dual result is not finite"
  return Dual(value: value, tangent: tangent)

_checkDualPoint(point: List<double>):
  for value in point:
    if not _finite(value): throw "automatic differentiation needs a finite point"

_dualSeed(point: List<double>, column: int) -> List<Dual>:
  seed: List<Dual> = []
  var index = 0
  while index < point.length:
    var tangent = 0.0
    if index == column: tangent = 1.0
    seed.add(Dual(value: point[index], tangent: tangent))
    index += 1
  return seed

# Compute a*b/c^2 without first rounding a/c to zero, or squaring c.
_dualProductOverSquare(a: double, b: double, c: double) -> double:
  if a == 0.0 or b == 0.0: return 0.0
  var larger = a
  var smaller = b
  if _abs(larger) < _abs(smaller):
    saved = larger
    larger = smaller
    smaller = saved
  ratio = larger / c
  if _finite(ratio):
    otherRatio = smaller / c
    if _abs(otherRatio) < 2.2250738585072014e-308:
      return (ratio * smaller) / c
    return ratio * otherRatio
  other = smaller / c
  if _finite(other) and _abs(other) >= 2.2250738585072014e-308:
    return _scaleRatio(other, larger, c)
  return ((larger * smaller) / c) / c

_dualPowerSlope(value: double, exponent: double, tangent: double) -> double:
  if tangent == 0.0: return 0.0
  magnitude = _abs(value)
  power = math.pow(magnitude, exponent - 1.0) to double
  var slope = exponent * power * tangent
  if not _finite(slope) or slope == 0.0 or power < 2.2250738585072014e-308 or _abs(exponent) > 9007199254740991.0:
    logMagnitude = math.log(_abs(exponent)) + (exponent - 1.0) * math.log(magnitude) + math.log(_abs(tangent))
    slope = math.exp(logMagnitude)
    if (exponent < 0.0) != (tangent < 0.0): slope = -slope
  if value < 0.0 and exponent % 2.0 == 0.0: slope = -slope
  return slope

# Second-order forward number: value + dx*e1 + dy*e2 + dxy*e1*e2.
# Nonpositive sqrt and ln are rejected, including the nonsmooth point 0.
value class HyperDual:
  value: double required
  dx: double required
  dy: double required
  dxy: double required

  operator +(other: HyperDual) -> HyperDual:
    return _hyper(value + other.value, dx + other.dx, dy + other.dy, dxy + other.dxy)

  operator -(other: HyperDual) -> HyperDual:
    return _hyper(value - other.value, dx - other.dx, dy - other.dy, dxy - other.dxy)

  operator *(other: HyperDual) -> HyperDual:
    return _hyper(value * other.value, dx * other.value + value * other.dx, dy * other.value + value * other.dy, dxy * other.value + value * other.dxy + dx * other.dy + dy * other.dx)

  sin() -> HyperDual:
    sine = math.sin(value)
    cosine = math.cos(value)
    return _hyper(sine, cosine * dx, cosine * dy, cosine * dxy - sine * dx * dy)

  sqrt() -> HyperDual:
    if value <= 0.0: throw "HyperDual.sqrt needs a positive value"
    root = math.sqrt(value)
    slope = 1.0 / (2.0 * root)
    curve = 0.0 - 1.0 / (4.0 * root * root * root)
    return _hyper(root, slope * dx, slope * dy, slope * dxy + curve * dx * dy)

# Hessian by one forward HyperDual evaluation per input pair, in coordinate
# order. At most 8 inputs. A nonsmooth callback throws from the HyperDual
# operation and no finite-difference substitute is used.
# Example:
#   print autoHessian((v: List<HyperDual>) -> v[0] * v[0], [3.0])[0][0]
autoHessian(f: (List<HyperDual>) -> HyperDual, point: List<double>) -> List<List<double>>:
  if point.length > 8: throw "autoHessian exceeds the work limit"
  for value in point:
    if not _finite(value): throw "automatic differentiation needs a finite point"
  rows: List<List<double>> = []
  var i = 0
  while i < point.length:
    row: List<double> = []
    var j = 0
    while j < point.length:
      seed: List<HyperDual> = []
      var k = 0
      while k < point.length:
        var dx = 0.0
        var dy = 0.0
        if k == i: dx = 1.0
        if k == j: dy = 1.0
        seed.add(HyperDual(value: point[k], dx: dx, dy: dy, dxy: 0.0))
        k += 1
      output = f(seed)
      if not _finite(output.value) or not _finite(output.dxy): throw "HyperDual result is not finite"
      row.add(output.dxy)
      j += 1
    rows.add(row)
    i += 1
  return rows

_hyper(value: double, dx: double, dy: double, dxy: double) -> HyperDual:
  if not _finite(value) or not _finite(dx) or not _finite(dy) or not _finite(dxy):
    throw "HyperDual result is not finite"
  return HyperDual(value: value, dx: dx, dy: dy, dxy: dxy)

:: autodiff::reverse

class ReverseNode:
  var adjoint: double = 0.0
  value: double
  left: int
  right: int
  leftSlope: double
  rightSlope: double

class ReverseTape:
  nodes: List<ReverseNode>

# Reverse-mode value. The tape is recorded by the operations and walked once
# from the output. This type is not Dual and does not store a forward tangent.
value class Reverse:
  tape: ReverseTape
  index: int

  operator +(other: Reverse) -> Reverse:
    _revSame(tape, other.tape)
    return _revPush(tape, _revAt(this) + _revAt(other), index, other.index, 1.0, 1.0)

  operator *(other: Reverse) -> Reverse:
    _revSame(tape, other.tape)
    return _revPush(tape, _revAt(this) * _revAt(other), index, other.index, _revAt(other), _revAt(this))

  sin() -> Reverse:
    value = _revAt(this)
    return _revPush(tape, math.sin(value), index, -1, math.cos(value), 0.0)

# Gradient from one recording of [f] and one backward walk. The callback is
# called once. At most 32 inputs. Variable order matches [point].
# Example:
#   print reverseGradient((v: List<Reverse>) -> v[0] * v[0], [3.0])[0]
reverseGradient(f: (List<Reverse>) -> Reverse, point: List<double>) -> List<double>:
  if point.length > 32: throw "reverseGradient exceeds the work limit"
  tape = ReverseTape(nodes: [])
  variables: List<Reverse> = []
  for value in point:
    if not _finite(value): throw "reverseGradient needs a finite point"
    variables.add(_revPush(tape, value, -1, -1, 0.0, 0.0))
  output = f(variables)
  _revSame(tape, output.tape)
  _revBack(tape, output.index)
  made: List<double> = []
  var index = 0
  while index < point.length:
    made.add(tape.nodes[index].adjoint)
    index += 1
  return made

_revAt(value: Reverse) -> double:
  return value.tape.nodes[value.index].value

_revSame(left: ReverseTape, right: ReverseTape):
  if left.nodes.length != right.nodes.length: throw "reverse operation needs one tape"

_revPush(tape: ReverseTape, value: double, left: int, right: int, leftSlope: double, rightSlope: double) -> Reverse:
  if not _finite(value) or not _finite(leftSlope) or not _finite(rightSlope): throw "reverse result is not finite"
  tape.nodes.add(ReverseNode(value: value, left: left, right: right, leftSlope: leftSlope, rightSlope: rightSlope))
  return Reverse(tape: tape, index: tape.nodes.length - 1)

_revBack(tape: ReverseTape, output: int):
  tape.nodes[output].adjoint = 1.0
  var index = tape.nodes.length - 1
  while index >= 0:
    node = tape.nodes[index]
    if node.left >= 0:
      left = tape.nodes[node.left]
      left.adjoint = left.adjoint + node.adjoint * node.leftSlope
    if node.right >= 0:
      right = tape.nodes[node.right]
      right.adjoint = right.adjoint + node.adjoint * node.rightSlope
    index -= 1

:: geometry

# Exact rational representation of a finite binary64 value, not of its decimal
# spelling. Repeated powers of two are exact; BigInt.from sees an integer.
# At most 1074 doubling steps are needed, including minimum subnormals.
# Example:
#   print binaryFraction(0.1)
binaryFraction(value: double) -> BigFraction:
  if not _finite(value): throw "binaryFraction needs a finite value"
  var scaled = value
  var denominator = BigInt.one
  while scaled != scaled.truncateToDouble():
    scaled *= 2.0
    denominator = denominator * BigInt.from(2)
  return bigFraction(BigInt.from(scaled), denominator)

# Exact orientation sign of the supplied binary64 coordinates: +1 CCW,
# -1 clockwise, 0 collinear. Uses BigInt rationals, without an epsilon or an
# overflow-prone double cross product. All coordinates must be finite.
orientation2D(a: Vec2, b: Vec2, c: Vec2) -> int:
  _checkGeometryPoint(a)
  _checkGeometryPoint(b)
  _checkGeometryPoint(c)
  return _orientationExact(a, b, c)

# Closed segment intersection, including endpoint touches, collinear overlaps
# and zero-length segments. Exact for the represented finite coordinates.
segmentsIntersect(a: Vec2, b: Vec2, c: Vec2, d: Vec2) -> bool:
  _checkGeometryPoint(a)
  _checkGeometryPoint(b)
  _checkGeometryPoint(c)
  _checkGeometryPoint(d)
  first = _orientationExact(a, b, c)
  second = _orientationExact(a, b, d)
  third = _orientationExact(c, d, a)
  fourth = _orientationExact(c, d, b)
  if first == 0 and _pointOnSegment(a, b, c): return true
  if second == 0 and _pointOnSegment(a, b, d): return true
  if third == 0 and _pointOnSegment(c, d, a): return true
  if fourth == 0 and _pointOnSegment(c, d, b): return true
  return first * second < 0 and third * fourth < 0

# Signed shoelace area, exactly as a rational for the given binary64 vertices.
# Positive for CCW order. Empty, point and segment polygons have zero area.
# A repeated closing vertex is permitted; self-intersections give signed area.
polygonSignedAreaExact(polygon: List<Vec2>) -> BigFraction:
  for point in polygon:
    _checkGeometryPoint(point)
  var total = bigFraction(BigInt.zero, BigInt.one)
  var index = 0
  while index < polygon.length:
    next = (index + 1) % polygon.length
    a = polygon[index]
    b = polygon[next]
    total = total + binaryFraction(a.x) * binaryFraction(b.y) - binaryFraction(a.y) * binaryFraction(b.x)
    index += 1
  return total / bigFraction(BigInt.from(2), BigInt.one)

# Nonzero winding rule, with explicit boundary inclusion (default true).
# Works with concave and self-intersecting vertex walks. A point/segment walk
# has boundary only and no interior. No automatic polygon repair is attempted.
pointInPolygon(point: Vec2, polygon: List<Vec2>, includeBoundary: bool = true) -> bool:
  _checkGeometryPoint(point)
  for vertex in polygon:
    _checkGeometryPoint(vertex)
  var winding = 0
  var index = 0
  while index < polygon.length:
    a = polygon[index]
    b = polygon[(index + 1) % polygon.length]
    side = _orientationExact(a, b, point)
    if side == 0 and _pointOnSegment(a, b, point): return includeBoundary
    if a.y <= point.y:
      if b.y > point.y and side > 0: winding += 1
    else:
      if b.y <= point.y and side < 0: winding -= 1
    index += 1
  return winding != 0

# CCW convex hull, starting at the lexicographically smallest vertex. No closing
# duplicate or interior collinear vertices. Degenerate hulls contain 0, 1 or 2
# vertices. Stable mergesort plus monotone chain: O(n log n) point comparisons
# and O(n) exact orientations; BigInt cost depends on coordinate bit length.
# The input list is not mutated; immutable Vec2 values may be shared.
convexHull(points: List<Vec2>) -> List<Vec2>:
  for point in points:
    _checkGeometryPoint(point)
  ordered = _sortGeometryPoints(points)
  unique: List<Vec2> = []
  for point in ordered:
    if unique.length == 0 or point.x != unique.last.x or point.y != unique.last.y:
      unique.add(point)
  if unique.length < 2: return unique
  lower: List<Vec2> = []
  for point in unique:
    _appendHullPoint(lower, point)
  upper: List<Vec2> = []
  var index = unique.length - 1
  while index >= 0:
    _appendHullPoint(upper, unique[index])
    index -= 1
  output: List<Vec2> = []
  index = 0
  while index + 1 < lower.length:
    output.add(lower[index])
    index += 1
  index = 0
  while index + 1 < upper.length:
    output.add(upper[index])
    index += 1
  return output

_checkGeometryPoint(point: Vec2):
  if not _finite(point.x) or not _finite(point.y): throw "geometry needs finite coordinates"

_orientationExact(a: Vec2, b: Vec2, c: Vec2) -> int:
  ax = binaryFraction(a.x)
  ay = binaryFraction(a.y)
  bx = binaryFraction(b.x)
  by = binaryFraction(b.y)
  cx = binaryFraction(c.x)
  cy = binaryFraction(c.y)
  crossValue = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
  return crossValue.numerator.sign

_pointOnSegment(a: Vec2, b: Vec2, point: Vec2) -> bool:
  return point.x >= min(a.x, b.x) and point.x <= max(a.x, b.x) and point.y >= min(a.y, b.y) and point.y <= max(a.y, b.y)

_pointOrdered(a: Vec2, b: Vec2) -> bool:
  return a.x < b.x or (a.x == b.x and a.y <= b.y)

_sortGeometryPoints(points: List<Vec2>) -> List<Vec2>:
  if points.length < 2:
    output: List<Vec2> = []
    for point in points:
      output.add(point)
    return output
  left: List<Vec2> = []
  right: List<Vec2> = []
  var index = 0
  while index < points.length:
    if index < points.length ~/ 2: left.add(points[index])
    else: right.add(points[index])
    index += 1
  a = _sortGeometryPoints(left)
  b = _sortGeometryPoints(right)
  output: List<Vec2> = []
  var i = 0
  var j = 0
  while i < a.length or j < b.length:
    if j == b.length or (i < a.length and _pointOrdered(a[i], b[j])):
      output.add(a[i])
      i += 1
    else:
      output.add(b[j])
      j += 1
  return output

_appendHullPoint(hull: List<Vec2>, point: Vec2):
  while hull.length >= 2:
    if _orientationExact(hull[hull.length - 2], hull.last, point) > 0: break
    hull.removeLast()
  hull.add(point)

:: symbolic

# Mathematical expression tree. It is not the language parser: kinds are data,
# and simplification does not rewrite the source. sqrt(x*x) stays, and x/x
# stays, because neither identity holds for every value. An unsupported
# derivative or integral throws instead of inventing a formula.
value class Expr:
  kind: String required
  name: String required
  number: BigFraction required
  arguments: List<Expr> required

exprNumber(number: BigFraction) -> Expr:
  return Expr(kind: "number", name: "", number: bigFraction(number.numerator, number.denominator), arguments: _exprNone())

exprSymbol(name: String) -> Expr:
  if name.isEmpty: throw "symbolic symbol needs a name"
  return Expr(kind: "symbol", name: name, number: _exprZero(), arguments: _exprNone())

exprAdd(left: Expr, right: Expr) -> Expr = _exprNode("add", [left, right])

exprSubtract(left: Expr, right: Expr) -> Expr = _exprNode("subtract", [left, right])

exprMultiply(left: Expr, right: Expr) -> Expr = _exprNode("multiply", [left, right])

exprDivide(left: Expr, right: Expr) -> Expr = _exprNode("divide", [left, right])

exprPower(left: Expr, right: Expr) -> Expr = _exprNode("power", [left, right])

exprSqrt(value: Expr) -> Expr = _exprNode("sqrt", [value])

exprSin(value: Expr) -> Expr = _exprNode("sin", [value])

# Constant folding and the identities +0, -0, *1. Multiplication by zero
# collapses only when the other operand is defined for all real assignments.
# No cancellation of a symbol with itself and no removal of a square root.
simplifyExpr(expr: Expr) -> Expr:
  if expr.kind == "number" or expr.kind == "symbol": return expr
  arguments: List<Expr> = []
  for argument in expr.arguments:
    arguments.add(simplifyExpr(argument))
  if expr.kind == "add" or expr.kind == "subtract" or expr.kind == "multiply" or expr.kind == "divide" or expr.kind == "power":
    left = arguments[0]
    right = arguments[1]
    if expr.kind == "add":
      if _exprIsNumber(left, _exprZero()): return right
      if _exprIsNumber(right, _exprZero()): return left
      if left.kind == "number" and right.kind == "number": return exprNumber(left.number + right.number)
    if expr.kind == "subtract":
      if _exprIsNumber(right, _exprZero()): return left
      if left.kind == "number" and right.kind == "number": return exprNumber(left.number - right.number)
    if expr.kind == "multiply":
      if _exprIsNumber(left, _exprZero()) and _exprEverywhere(right): return exprNumber(_exprZero())
      if _exprIsNumber(right, _exprZero()) and _exprEverywhere(left): return exprNumber(_exprZero())
      if _exprIsNumber(left, _exprOne()): return right
      if _exprIsNumber(right, _exprOne()): return left
      if left.kind == "number" and right.kind == "number": return exprNumber(left.number * right.number)
    if expr.kind == "divide":
      if left.kind == "number" and right.kind == "number":
        if right.number.numerator == BigInt.zero: throw "division by zero"
        return exprNumber(left.number / right.number)
    if expr.kind == "power":
      if _exprIsNumber(right, _exprOne()): return left
      if left.kind == "number" and right.kind == "number" and right.number.denominator == BigInt.one:
        return exprNumber(_exprPowerNumber(left.number, right.number.numerator))
  return Expr(kind: expr.kind, name: expr.name, number: expr.number, arguments: arguments)

# A conservative proof of totality on finite real assignments. Unknown and
# potentially partial operations retain their domain by staying in the tree.
_exprEverywhere(node: Expr) -> bool:
  if node.kind == "number": return node.number.denominator != BigInt.zero
  if node.kind == "symbol": return true
  if node.kind == "sin":
    return node.arguments.length == 1 and _exprEverywhere(node.arguments[0])
  if node.kind == "sqrt":
    if node.arguments.length != 1: return false
    argument = node.arguments[0]
    return argument.kind == "number" and argument.number.denominator != BigInt.zero and argument.number.compareTo(_exprZero()) >= 0
  if node.arguments.length != 2: return false
  left = node.arguments[0]
  right = node.arguments[1]
  if node.kind == "add" or node.kind == "subtract" or node.kind == "multiply":
    return _exprEverywhere(left) and _exprEverywhere(right)
  if node.kind == "divide":
    return _exprEverywhere(left) and right.kind == "number" and right.number.denominator != BigInt.zero and right.number.numerator != BigInt.zero
  if node.kind == "power":
    return _exprEverywhere(left) and right.kind == "number" and right.number.denominator == BigInt.one and right.number.numerator >= BigInt.zero
  return false

# Formal derivative in [variable]. sqrt and unknown kinds throw.
deriveExpr(expr: Expr, variable: String) -> Expr:
  if expr.kind == "number": return exprNumber(_exprZero())
  if expr.kind == "symbol":
    if expr.name == variable: return exprNumber(_exprOne())
    return exprNumber(_exprZero())
  if expr.kind == "add": return simplifyExpr(exprAdd(deriveExpr(expr.arguments[0], variable), deriveExpr(expr.arguments[1], variable)))
  if expr.kind == "subtract": return simplifyExpr(exprSubtract(deriveExpr(expr.arguments[0], variable), deriveExpr(expr.arguments[1], variable)))
  if expr.kind == "multiply":
    left = expr.arguments[0]
    right = expr.arguments[1]
    return simplifyExpr(exprAdd(exprMultiply(deriveExpr(left, variable), right), exprMultiply(left, deriveExpr(right, variable))))
  if expr.kind == "power":
    exponent = expr.arguments[1]
    if exponent.kind != "number" or exponent.number.denominator != BigInt.one: throw "symbolic derivative is not supported"
    base = expr.arguments[0]
    if exponent.number.numerator == BigInt.zero:
      if not _exprEverywhere(base): throw "symbolic derivative is not supported"
      return exprNumber(_exprZero())
    power = exprNumber(bigFraction(exponent.number.numerator - BigInt.one, BigInt.one))
    factor = exprNumber(exponent.number)
    return simplifyExpr(exprMultiply(exprMultiply(factor, exprPower(base, power)), deriveExpr(base, variable)))
  throw "symbolic derivative is not supported"

# Antiderivative of a polynomial in one symbol, with the constant term omitted.
# Degree after expansion stays at most 16. Other expressions throw.
integratePolynomial(expr: Expr, variable: String) -> Expr:
  coefficients = _exprPolynomial(expr, variable)
  integrated: List<Expr> = []
  integrated.add(exprNumber(_exprZero()))
  var power = 0
  while power < coefficients.length:
    denominator = BigInt.from(power + 1)
    coefficient = bigFraction(coefficients[power].value.numerator, coefficients[power].value.denominator * denominator)
    if coefficient.numerator != BigInt.zero:
      var term = exprNumber(coefficient)
      if power + 1 > 0:
        term = exprMultiply(term, exprPower(exprSymbol(variable), exprNumber(bigFraction(BigInt.from(power + 1), BigInt.one))))
      integrated.add(term)
    power += 1
  var total = integrated[0]
  var index = 1
  while index < integrated.length:
    total = exprAdd(total, integrated[index])
    index += 1
  return simplifyExpr(total)

exprText(expr: Expr) -> String:
  if expr.kind == "number": return "{expr.number.numerator}/{expr.number.denominator}"
  if expr.kind == "symbol": return expr.name
  if expr.kind == "sqrt": return "(sqrt({exprText(expr.arguments[0])}))"
  if expr.kind == "sin": return "(sin({exprText(expr.arguments[0])}))"
  if expr.kind == "add": return "({exprText(expr.arguments[0])}+{exprText(expr.arguments[1])})"
  if expr.kind == "subtract": return "({exprText(expr.arguments[0])}-{exprText(expr.arguments[1])})"
  if expr.kind == "multiply": return "({exprText(expr.arguments[0])}*{exprText(expr.arguments[1])})"
  if expr.kind == "divide": return "({exprText(expr.arguments[0])}/{exprText(expr.arguments[1])})"
  if expr.kind == "power": return "({exprText(expr.arguments[0])}^{exprText(expr.arguments[1])})"
  throw "symbolic expression is not supported"

_exprNone() -> List<Expr>:
  made: List<Expr> = []
  return made

_exprZero() -> BigFraction = bigFraction(BigInt.zero, BigInt.one)

_exprOne() -> BigFraction = bigFraction(BigInt.one, BigInt.one)

_exprNode(kind: String, arguments: List<Expr>) -> Expr:
  return Expr(kind: kind, name: "", number: _exprZero(), arguments: arguments)

_exprIsNumber(expr: Expr, number: BigFraction) -> bool:
  return expr.kind == "number" and expr.number.numerator == number.numerator and expr.number.denominator == number.denominator

_exprPowerNumber(number: BigFraction, exponent: BigInt) -> BigFraction:
  if exponent < BigInt.zero:
    if number.numerator == BigInt.zero: throw "division by zero"
    inverted = bigFraction(number.denominator, number.numerator)
    return _exprPowerNumber(inverted, BigInt.zero - exponent)
  var total = _exprOne()
  var count = BigInt.zero
  while count < exponent:
    total = total * number
    count = count + BigInt.one
    if count > BigInt.from(16): throw "symbolic power exceeds the work limit"
  return total

class _FracCell:
  var value: BigFraction required

_exprPolynomial(expr: Expr, variable: String) -> List<_FracCell>:
  if expr.kind == "number": return _exprCoeff(_exprZero(), 0, expr.number)
  if expr.kind == "symbol":
    if expr.name != variable: throw "symbolic integral is not supported"
    return _exprCoeff(_exprZero(), 1, _exprOne())
  if expr.kind == "add": return _exprPolyAdd(_exprPolynomial(expr.arguments[0], variable), _exprPolynomial(expr.arguments[1], variable), false)
  if expr.kind == "subtract": return _exprPolyAdd(_exprPolynomial(expr.arguments[0], variable), _exprPolynomial(expr.arguments[1], variable), true)
  if expr.kind == "multiply": return _exprPolyMul(_exprPolynomial(expr.arguments[0], variable), _exprPolynomial(expr.arguments[1], variable))
  if expr.kind == "power":
    exponent = expr.arguments[1]
    if exponent.kind != "number" or exponent.number.denominator != BigInt.one or exponent.number.numerator < BigInt.zero or exponent.number.numerator > BigInt.from(16):
      throw "symbolic integral is not supported"
    base = _exprPolynomial(expr.arguments[0], variable)
    var total = _exprCoeff(_exprOne(), 0, _exprOne())
    var count = BigInt.zero
    while count < exponent.number.numerator:
      total = _exprPolyMul(total, base)
      count = count + BigInt.one
    return total
  throw "symbolic integral is not supported"

_exprCoeff(ignored: BigFraction, power: int, coefficient: BigFraction) -> List<_FracCell>:
  made: List<_FracCell> = []
  var index = 0
  while index <= power:
    made.add(_FracCell(value: _exprZero()))
    index += 1
  made[power].value = coefficient
  return made

_exprPolyAdd(left: List<_FracCell>, right: List<_FracCell>, subtract: bool) -> List<_FracCell>:
  var width = left.length
  if right.length > width: width = right.length
  if width > 17: throw "symbolic polynomial exceeds the work limit"
  made: List<_FracCell> = []
  var index = 0
  while index < width:
    var value = _exprZero()
    if index < left.length: value = value + left[index].value
    if index < right.length:
      if subtract: value = value - right[index].value
      else: value = value + right[index].value
    made.add(_FracCell(value: value))
    index += 1
  return made

_exprPolyMul(left: List<_FracCell>, right: List<_FracCell>) -> List<_FracCell>:
  width = left.length + right.length - 1
  if width > 17: throw "symbolic polynomial exceeds the work limit"
  made: List<_FracCell> = []
  var index = 0
  while index < width:
    made.add(_FracCell(value: _exprZero()))
    index += 1
  var i = 0
  while i < left.length:
    var j = 0
    while j < right.length:
      made[i + j].value = made[i + j].value + left[i].value * right[j].value
      j += 1
    i += 1
  return made

:: tensor

# Dense row-major tensor. The value count must equal the product of [shape].
# At most 4096 values. This is storage and arithmetic, not a symbolic tensor.
value class Tensor:
  shape: List<int> required
  values: List<double> required

tensor(shape: List<int>, values: List<double>) -> Tensor:
  if shape.isEmpty or shape.length > 4: throw "tensor rank must be from 1 through 4"
  var count = 1
  for extent in shape:
    if extent < 0: throw "tensor extent must be nonnegative"
    count = count * extent
    if count > 4096: throw "tensor exceeds the work limit"
  if values.length != count: throw "tensor values must match the shape"
  for value in values:
    if not _finite(value): throw "tensor values must be finite"
  copied: List<int> = []
  for extent in shape:
    copied.add(extent)
  stored: List<double> = []
  for value in values:
    stored.add(value)
  return Tensor(shape: copied, values: stored)

tensorAdd(left: Tensor, right: Tensor) -> Tensor:
  if left.shape.length != right.shape.length: throw "tensor add needs the same shape"
  var index = 0
  while index < left.shape.length:
    if left.shape[index] != right.shape[index]: throw "tensor add needs the same shape"
    index += 1
  made: List<double> = []
  index = 0
  while index < left.values.length:
    made.add(left.values[index] + right.values[index])
    index += 1
  return Tensor(shape: left.shape, values: made)

# Rank-2 product. The inner extents must agree.
tensorMatmul(left: Tensor, right: Tensor) -> Tensor:
  if left.shape.length != 2 or right.shape.length != 2: throw "tensor matmul needs rank 2"
  if left.shape[1] != right.shape[0]: throw "tensor matmul needs compatible shapes"
  rows = left.shape[0]
  inner = left.shape[1]
  columns = right.shape[1]
  made: List<double> = []
  var row = 0
  while row < rows:
    var column = 0
    while column < columns:
      var total = 0.0
      var k = 0
      while k < inner:
        total = total + left.values[row * inner + k] * right.values[k * columns + column]
        k += 1
      made.add(total)
      column += 1
    row += 1
  return tensor([rows, columns], made)

:: algebra

# Residue in a prime field. The modulus must be a proven prime no larger than
# 1000000, by trial division. The stored residue is in 0 through modulus-1.
value class FieldElement:
  residue: int required
  modulus: int required

fieldElement(value: int, modulus: int) -> FieldElement:
  _fieldPrime(modulus)
  var residue = value % modulus
  if residue < 0: residue = residue + modulus
  return FieldElement(residue: residue, modulus: modulus)

fieldAdd(left: FieldElement, right: FieldElement) -> FieldElement:
  _fieldSame(left, right)
  return fieldElement(left.residue + right.residue, left.modulus)

fieldMultiply(left: FieldElement, right: FieldElement) -> FieldElement:
  _fieldSame(left, right)
  return fieldElement(left.residue * right.residue, left.modulus)

# Modular inverse by the extended Euclidean algorithm. Zero has none.
fieldInverse(value: FieldElement) -> FieldElement:
  _fieldPrime(value.modulus)
  if value.residue == 0: throw "finite field element has no inverse"
  var oldRemainder = value.modulus
  var remainder = value.residue
  var oldCoefficient = 0
  var coefficient = 1
  while remainder != 0:
    quotient = oldRemainder ~/ remainder
    nextRemainder = oldRemainder - quotient * remainder
    nextCoefficient = oldCoefficient - quotient * coefficient
    oldRemainder = remainder
    remainder = nextRemainder
    oldCoefficient = coefficient
    coefficient = nextCoefficient
  if oldRemainder != 1: throw "finite field element has no inverse"
  return fieldElement(oldCoefficient, value.modulus)

_fieldSame(left: FieldElement, right: FieldElement):
  if left.modulus != right.modulus: throw "finite field moduli must agree"

_fieldPrime(modulus: int):
  if modulus < 2 or modulus > 1000000: throw "finite field modulus is outside 2 through 1000000"
  if modulus == 2: return
  if modulus % 2 == 0: throw "finite field needs a prime modulus"
  var divisor = 3
  while divisor * divisor <= modulus:
    if modulus % divisor == 0: throw "finite field needs a prime modulus"
    divisor += 2

:: topology

# Euler characteristic of a pure triangle complex: V - E + F.
# [vertexCount] includes isolated vertices. Each face is three distinct
# indices. An undirected edge is counted once. This is not homology.
# Example:
#   print eulerCharacteristic(3, [[0, 1, 2]])
eulerCharacteristic(vertexCount: int, faces: List<List<int>>) -> int:
  if vertexCount < 0 or vertexCount > 5000: throw "topology vertex count is outside 0 through 5000"
  if faces.length > 2000: throw "topology exceeds the work limit"
  edges: List<int> = []
  faceCodes: List<int> = []
  for face in faces:
    if face.length != 3: throw "topology face must be a triangle"
    if face[0] == face[1] or face[0] == face[2] or face[1] == face[2]: throw "topology face repeats a vertex"
    var slot = 0
    while slot < 3:
      if face[slot] < 0 or face[slot] >= vertexCount: throw "topology vertex out of range"
      slot += 1
    ordered = face.sorted()
    code = (ordered[0] * vertexCount + ordered[1]) * vertexCount + ordered[2]
    if faceCodes.contains(code): throw "topology repeats a face"
    faceCodes.add(code)
    _topologyEdge(edges, vertexCount, face[0], face[1])
    _topologyEdge(edges, vertexCount, face[1], face[2])
    _topologyEdge(edges, vertexCount, face[2], face[0])
  return vertexCount - edges.length + faces.length

_topologyEdge(edges: List<int>, vertexCount: int, left: int, right: int):
  var low = left
  var high = right
  if high < low:
    low = right
    high = left
  code = low * vertexCount + high
  for existing in edges:
    if existing == code: return
  edges.add(code)


:: timeseries

# Population convention: center at the whole-series mean and divide by n.
seriesAutocovariance(samples: List<double>, lag: int) -> double:
  if samples.length == 0 or lag < 0 or lag >= samples.length: throw "series lag must be inside a nonempty series"
  _seriesFiniteList(samples)
  center = mean(samples)
  var total = 0.0
  var correction = 0.0
  var index = lag
  while index < samples.length:
    productValue = (samples[index] - center) * (samples[index - lag] - center) / samples.length
    adjusted = productValue - correction
    next = total + adjusted
    correction = (next - total) - adjusted
    total = next
    index += 1
  if not _seriesFinite(total): throw "series covariance is not finite"
  return total

seriesAutocorrelation(samples: List<double>, lag: int) -> double:
  covarianceValue = seriesAutocovariance(samples, lag)
  varianceValue = seriesAutocovariance(samples, 0)
  if varianceValue == 0.0: throw "series correlation needs positive variance"
  return covarianceValue / varianceValue

seriesDifference(samples: List<double>, lag: int = 1) -> List<double>:
  if lag < 1 or lag > samples.length: throw "series difference lag must be inside the series"
  _seriesFiniteList(samples)
  output: List<double> = []
  var index = lag
  while index < samples.length:
    value = samples[index] - samples[index - lag]
    if not _seriesFinite(value): throw "series difference is not finite"
    output.add(value)
    index += 1
  return output

# Coefficients are ordered from lag 1 to lag p; this does not fit a model.
arForecast(history: List<double>, coefficients: List<double>, intercept: double, steps: int) -> List<double>:
  if coefficients.length > 128 or history.length < coefficients.length or steps < 0 or steps > 10000: throw "AR dimensions exceed the work limit"
  _seriesFiniteList(history)
  _seriesFiniteList(coefficients)
  if not _seriesFinite(intercept): throw "AR intercept must be finite"
  values = history.toList()
  output: List<double> = []
  var stepIndex = 0
  while stepIndex < steps:
    var predicted = intercept
    var lagIndex = 0
    while lagIndex < coefficients.length:
      predicted += coefficients[lagIndex] * values[values.length - 1 - lagIndex]
      lagIndex += 1
    if not _seriesFinite(predicted): throw "AR forecast is not finite"
    output.add(predicted)
    values.add(predicted)
    stepIndex += 1
  return output

# Row-stochastic transition: output[j] = sum_i probabilities[i] * rows[i][j].
markovStep(probabilities: List<double>, rows: List<List<double>>) -> List<double>:
  size = probabilities.length
  if size == 0 or size > 128 or rows.length != size: throw "Markov dimensions must match within 1 through 128"
  _seriesProbability(probabilities)
  for row in rows:
    if row.length != size: throw "Markov dimensions must match within 1 through 128"
    _seriesProbability(row)
  output: List<double> = []
  var column = 0
  while column < size:
    var total = 0.0
    var rowIndex = 0
    while rowIndex < size:
      total += probabilities[rowIndex] * rows[rowIndex][column]
      rowIndex += 1
    output.add(total)
    column += 1
  return output

class KalmanEstimate:
  meanValue: double required
  variance: double required
  gain: double required

# Scalar identity state/observation model; process noise is added before update.
# Joseph-form posterior variance avoids subtracting nearly equal variances.
kalmanScalar(priorMean: double, varianceValue: double, observation: double, processVariance: double, measurementVariance: double) -> KalmanEstimate:
  _seriesFiniteList([priorMean, varianceValue, observation, processVariance, measurementVariance])
  if varianceValue < 0.0 or processVariance < 0.0 or measurementVariance <= 0.0: throw "Kalman variances need nonnegative state/process and positive measurement"
  predicted = varianceValue + processVariance
  denominator = predicted + measurementVariance
  if not _seriesFinite(denominator): throw "Kalman update is not finite"
  gainValue = predicted / denominator
  complement = measurementVariance / denominator
  updated = complement * priorMean + gainValue * observation
  varianceOutput = complement * complement * predicted + gainValue * gainValue * measurementVariance
  if not _seriesFinite(updated) or not _seriesFinite(varianceOutput): throw "Kalman update is not finite"
  return KalmanEstimate(meanValue: updated, variance: varianceOutput, gain: gainValue)

_seriesFinite(value: double) -> bool = value == value and value != 1.0 / 0.0 and value != 0.0 - 1.0 / 0.0
_seriesFiniteList(values: List<double>):
  for value in values:
    if not _seriesFinite(value): throw "series values must be finite"
_seriesProbability(values: List<double>):
  _seriesFiniteList(values)
  var total = 0.0
  for value in values:
    if value < 0.0 or value > 1.0 + 1.0e-12: throw "Markov probabilities must be normalized and nonnegative"
    total += value
  if total < 1.0 - 1.0e-12 or total > 1.0 + 1.0e-12: throw "Markov probabilities must be normalized and nonnegative"

:: logic

class SatResult:
  satisfiable: bool required
  assignment: List<bool> required

# Signed literals use 1-based variable indices. Empty CNF is true; empty clause
# is false. First assignment is deterministic in ascending binary-mask order.
solveCnf(variableCount: int, clauses: List<List<int>>) -> SatResult:
  if variableCount < 0 or variableCount > 16 or clauses.length > 512: throw "SAT exceeds the work limit"
  var literalCount = 0
  for clause in clauses:
    for literal in clause:
      if literal == 0 or literal < 0 - variableCount or literal > variableCount: throw "SAT literal is outside the variable range"
      literalCount += 1
  assignmentCount = 1 << variableCount
  if (literalCount + clauses.length) * assignmentCount > 16000000: throw "SAT exceeds the work limit"
  var maskValue = 0
  while maskValue < assignmentCount:
    var accepted = true
    for clause in clauses:
      var satisfied = false
      for literal in clause:
        var indexValue = literal
        if indexValue < 0: indexValue = 0 - indexValue
        bitValue = (maskValue & (1 << (indexValue - 1))) != 0
        if (literal > 0 and bitValue) or (literal < 0 and not bitValue): satisfied = true
      if not satisfied: accepted = false
    if accepted:
      values: List<bool> = []
      var indexValue = 0
      while indexValue < variableCount:
        values.add((maskValue & (1 << indexValue)) != 0)
        indexValue += 1
      return SatResult(satisfiable: true, assignment: values)
    maskValue += 1
  return SatResult(satisfiable: false, assignment: [])

# An explicit finite relation matrix: reflexive, antisymmetric and transitive.
isPartialOrder(relation: List<List<bool>>) -> bool:
  size = relation.length
  if size > 128: throw "order exceeds the work limit"
  for row in relation:
    if row.length != size: throw "order relation must be square"
  var left = 0
  while left < size:
    if not relation[left][left]: return false
    var right = 0
    while right < size:
      if left != right and relation[left][right] and relation[right][left]: return false
      var middle = 0
      while middle < size:
        if relation[left][middle] and relation[middle][right] and not relation[left][right]: return false
        middle += 1
      right += 1
    left += 1
  return true

:: topology::homology

class Homology2:
  betti0: int required
  betti1: int required
  betti2: int required

# Homology over F2 of a 2-dimensional finite simplicial complex. Triangle
# boundaries are included automatically. No 3-simplices are filled implicitly.
simplicialHomology(vertexCount: int, edges: List<List<int>>, faces: List<List<int>>) -> Homology2:
  if vertexCount < 0 or vertexCount > 128 or edges.length > 256 or faces.length > 128: throw "homology exceeds the work limit"
  codes: List<int> = []
  for edge in edges:
    if edge.length != 2 or edge[0] == edge[1]: throw "homology edge needs two distinct vertices"
    _homologyVertex(vertexCount, edge[0])
    _homologyVertex(vertexCount, edge[1])
    _homologyEdge(codes, vertexCount, edge[0], edge[1])
  faceCodes: List<int> = []
  for face in faces:
    if face.length != 3 or face[0] == face[1] or face[0] == face[2] or face[1] == face[2]: throw "homology face needs three distinct vertices"
    for vertex in face:
      _homologyVertex(vertexCount, vertex)
    ordered = face.sorted()
    code = (ordered[0] * vertexCount + ordered[1]) * vertexCount + ordered[2]
    if faceCodes.contains(code): throw "homology repeats a face"
    faceCodes.add(code)
    _homologyEdge(codes, vertexCount, face[0], face[1])
    _homologyEdge(codes, vertexCount, face[1], face[2])
    _homologyEdge(codes, vertexCount, face[2], face[0])
  if codes.length > 256: throw "homology exceeds the work limit"
  parents: List<int> = []
  var vertexIndex = 0
  while vertexIndex < vertexCount:
    parents.add(vertexIndex)
    vertexIndex += 1
  var components = vertexCount
  for code in codes:
    left = _homologyRoot(parents, code ~/ vertexCount)
    right = _homologyRoot(parents, code % vertexCount)
    if left != right:
      parents[left] = right
      components -= 1
  boundary: List<List<int>> = []
  for code in codes:
    row: List<int> = []
    for face in faces:
      var entryValue = 0
      if code == _homologyCode(vertexCount, face[0], face[1]) or code == _homologyCode(vertexCount, face[1], face[2]) or code == _homologyCode(vertexCount, face[2], face[0]): entryValue = 1
      row.add(entryValue)
    boundary.add(row)
  var rankValue = 0
  var column = 0
  while column < faces.length and rankValue < boundary.length:
    var pivot = rankValue
    while pivot < boundary.length and boundary[pivot][column] == 0:
      pivot += 1
    if pivot < boundary.length:
      saved = boundary[rankValue]
      boundary[rankValue] = boundary[pivot]
      boundary[pivot] = saved
      var rowIndex = rankValue + 1
      while rowIndex < boundary.length:
        if boundary[rowIndex][column] == 1:
          var entry = column
          while entry < faces.length:
            boundary[rowIndex][entry] = boundary[rowIndex][entry] ^ boundary[rankValue][entry]
            entry += 1
        rowIndex += 1
      rankValue += 1
    column += 1
  return Homology2(betti0: components, betti1: codes.length - vertexCount + components - rankValue, betti2: faces.length - rankValue)

_homologyVertex(size: int, vertex: int):
  if vertex < 0 or vertex >= size: throw "homology vertex out of range"
_homologyCode(size: int, left: int, right: int) -> int:
  if left < right: return left * size + right
  return right * size + left
_homologyEdge(codes: List<int>, size: int, left: int, right: int):
  code = _homologyCode(size, left, right)
  if not codes.contains(code): codes.add(code)
_homologyRoot(parents: List<int>, start: int) -> int:
  var vertex = start
  while parents[vertex] != vertex:
    vertex = parents[vertex]
  return vertex
''';

/// Source of `quds:text`. Kept equal to `lib/sdk/text.quds`.
const textSdkSource = r'''# General-purpose text library for Quds.
# Provides UTF-16 ranges and spans, line/column mapping, Unicode inspection,
# literal slicing, splitting, composition, efficient building, and line tools.
# A column-0 :: name opens a section. use quds:text::builder imports that
# section and any subsection under it. use quds:text imports every public name.
# Example:
#   use quds:text::compose as text
#   print text.repeatText("ha", 3, separator: "-")

use dart:convert as _convert
use dart:typed_data show Uint8List

:: types

# How an offset that falls inside a multi-unit character should be handled.
# Example:
#   policy = TextBoundaryPolicy.reject
#   print policy.name
enum TextBoundaryPolicy:
  reject
  previous
  next

# A half-open UTF-16 code-unit range [start, end) inside a string.
# Both bounds are zero-based and satisfy 0 <= start <= end.
# Example:
#   range = TextRange(1, 4)
#   print range.length
value class TextRange:
  start: int required
  end: int required

  init(this.start, this.end):
    if start < 0:
      throw RangeError.value(start, "start", "TextRange.start must be non-negative")
    if end < start:
      throw RangeError.value(end, "end", "TextRange.end must be >= start")

  # Number of UTF-16 code units covered by this range.
  # Example:
  #   print TextRange(2, 5).length
  property length: int:
    get = end - start

  # True when start equals end.
  # Example:
  #   print TextRange(2, 2).isEmpty
  property isEmpty: bool:
    get = start == end

  # True when the range covers at least one UTF-16 code unit.
  # Example:
  #   print TextRange(2, 5).isNotEmpty
  property isNotEmpty: bool:
    get = start < end

  # True when [offset] lies within [start, end).
  # Example:
  #   print TextRange(1, 4).contains(2)
  contains(offset: int) -> bool = offset >= start and offset < end

  # True when this range shares at least one code unit with [other].
  # Example:
  #   print TextRange(0, 3).overlaps(TextRange(2, 5))
  overlaps(other: TextRange) -> bool = start < other.end and other.start < end


  toString() -> String = "TextRange({start}, {end})"

# A validated slice view over a [source] string using a UTF-16 [range].
# Retaining a TextSpan may retain the full [source]; call materialize() to
# detach a copy that only holds the slice.
# Example:
#   span = TextSpan("hello world", TextRange(0, 5))
#   print span.value
value class TextSpan:
  source: String required
  range: TextRange required

  init(this.source, this.range):
    validateTextRange(source, range)

  # Substring covered by this span.
  # Example:
  #   print TextSpan("hello", TextRange(1, 4)).value
  property value: String:
    get = source.substring(range.start, range.end)

  # Number of UTF-16 code units in this span.
  # Example:
  #   print TextSpan("hello", TextRange(1, 4)).length
  property length: int:
    get = range.length

  # True when this span covers zero UTF-16 code units.
  # Example:
  #   print TextSpan("hello", TextRange(2, 2)).isEmpty
  property isEmpty: bool:
    get = range.isEmpty

  # Derives a sub-span using UTF-16 offsets relative to this span.
  # Example:
  #   span = TextSpan("abcdef", TextRange(1, 5))
  #   print span.slice(1, 3).value
  slice(start: int, end: int) -> TextSpan:
    sub = TextRange(start, end)
    if sub.end > range.length:
      throw RangeError.range(sub.end, 0, range.length, "end")
    return TextSpan(source, TextRange(range.start + sub.start, range.start + sub.end))

  # Returns a span backed only by the sliced text, releasing the original source.
  # Example:
  #   detached = TextSpan("hello world", TextRange(6, 11)).materialize()
  #   print detached.value
  materialize() -> TextSpan:
    copied = value
    return TextSpan(copied, TextRange(0, copied.length))


  toString() -> String = "TextSpan({range.start}..{range.end}: {value})"

# A position in text with zero-based UTF-16 [offset], one-based [line], and
# one-based UTF-16 [column]. CRLF counts as a single line break.
# Example:
#   pos = textPositionAt("a\nb", 2)
#   print pos.line
value class TextPosition:
  offset: int required
  line: int required
  column: int required

  init(this.offset, this.line, this.column):
    if offset < 0:
      throw RangeError.value(offset, "offset", "TextPosition.offset must be non-negative")
    if line < 1:
      throw RangeError.value(line, "line", "TextPosition.line must be >= 1")
    if column < 1:
      throw RangeError.value(column, "column", "TextPosition.column must be >= 1")


  toString() -> String = "TextPosition(offset: {offset}, line: {line}, column: {column})"

# Validates that [range] lies within [text] and returns it unchanged.
# Throws RangeError if end exceeds text.length.
# Example:
#   r = validateTextRange("hello", TextRange(0, 5))
#   print r.length
validateTextRange(text: String, bounds: TextRange) -> TextRange:
  if bounds.end > text.length:
    throw RangeError.range(bounds.end, 0, text.length, "bounds.end")
  return bounds

# Returns the intersection of [first] and [second], or null when disjoint.
# Adjacent non-empty ranges such as [0, 2) and [2, 4) return null.
# Example:
#   hit = intersectTextRanges(TextRange(0, 4), TextRange(2, 6))
#   print hit
intersectTextRanges(first: TextRange, second: TextRange) -> TextRange?:
  s = if first.start > second.start: first.start else: second.start
  e = if first.end < second.end: first.end else: second.end
  if s > e:
    return null
  if s == e and first.isNotEmpty and second.isNotEmpty:
    return null
  return TextRange(s, e)

# Computes the 1-based line and UTF-16 column for a 0-based UTF-16 [offset].
# Treats CRLF, LF, and CR as single line breaks.
# Example:
#   pos = textPositionAt("a\r\nb", 3)
#   print pos.line
textPositionAt(text: String, offset: int) -> TextPosition:
  if offset < 0 or offset > text.length:
    throw RangeError.range(offset, 0, text.length, "offset")
  var line = 1
  var column = 1
  var i = 0
  while i < offset:
    unit = text.codeUnitAt(i)
    if unit == 13:
      if i + 1 < offset and text.codeUnitAt(i + 1) == 10:
        line = line + 1
        column = 1
        i = i + 2
      else if i + 1 == offset and i + 1 < text.length and text.codeUnitAt(i + 1) == 10:
        # Offset sits between CR and LF inside CRLF.
        column = column + 1
        i = i + 1
      else:
        line = line + 1
        column = 1
        i = i + 1
    else if unit == 10:
      line = line + 1
      column = 1
      i = i + 1
    else:
      column = column + 1
      i = i + 1
  return TextPosition(offset, line, column)

# Computes the 0-based UTF-16 offset for a 1-based [line] and UTF-16 [column].
# Throws RangeError if [line] or [column] is out of bounds for [text].
# Example:
#   print textOffsetAt("ab\ncd", 2, 2)
textOffsetAt(text: String, line: int, column: int) -> int:
  if line < 1:
    throw RangeError.value(line, "line", "line must be >= 1")
  if column < 1:
    throw RangeError.value(column, "column", "column must be >= 1")
  var currentLine = 1
  var i = 0
  n = text.length
  while currentLine < line:
    if i >= n:
      throw RangeError.value(line, "line", "line exceeds total lines in text")
    unit = text.codeUnitAt(i)
    if unit == 13:
      if i + 1 < n and text.codeUnitAt(i + 1) == 10:
        i = i + 2
      else:
        i = i + 1
      currentLine = currentLine + 1
    else if unit == 10:
      i = i + 1
      currentLine = currentLine + 1
    else:
      i = i + 1
  var lineEnd = i
  while lineEnd < n:
    unit = text.codeUnitAt(lineEnd)
    if unit == 10 or unit == 13:
      break
    lineEnd = lineEnd + 1
  lineLength = lineEnd - i
  if column - 1 > lineLength:
    throw RangeError.range(column, 1, lineLength + 1, "column")
  return i + (column - 1)


:: unicode

# The pinned Unicode data version used by normalization, case folding, and
# grapheme cluster segmentation.
# Example:
#   print unicodeVersion()
unicodeVersion() -> String = _uDataVersion()

# Unicode normalization forms defined by UAX #15.
# Example:
#   form = TextNormalizationForm.nfc
#   print form.name
enum TextNormalizationForm:
  nfc
  nfd
  nfkc
  nfkd

# Code-point view over a [source] string with explicit UTF-16 range mapping.
# When [strict] is true, unpaired UTF-16 surrogates throw ArgumentError.
# When [replaceMalformed] is true, unpaired surrogates map to U+FFFD (0xFFFD).
# Example:
#   cps = TextCodePoints("A😀")
#   print cps.count
class TextCodePoints:
  source: String required
  strict: bool = false
  replaceMalformed: bool = false
  private var _points: List<int> = []
  private var _ranges: List<TextRange> = []

  init(this.source, this.strict = false, this.replaceMalformed = false):
    pts: List<int> = []
    rngs: List<TextRange> = []
    var i = 0
    n = source.length
    while i < n:
      unit = source.codeUnitAt(i)
      if unit >= 0xD800 and unit <= 0xDBFF:
        if i + 1 < n:
          low = source.codeUnitAt(i + 1)
          if low >= 0xDC00 and low <= 0xDFFF:
            cp = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
            pts.add(cp)
            rngs.add(TextRange(i, i + 2))
            i = i + 2
            continue
        if strict:
          throw ArgumentError("Unpaired high surrogate at UTF-16 offset {i}")
        pts.add(if replaceMalformed: 0xFFFD else: unit)
        rngs.add(TextRange(i, i + 1))
        i = i + 1
      else if unit >= 0xDC00 and unit <= 0xDFFF:
        if strict:
          throw ArgumentError("Unpaired low surrogate at UTF-16 offset {i}")
        pts.add(if replaceMalformed: 0xFFFD else: unit)
        rngs.add(TextRange(i, i + 1))
        i = i + 1
      else:
        pts.add(unit)
        rngs.add(TextRange(i, i + 1))
        i = i + 1
    _points = pts
    _ranges = rngs

  # Number of code points in this view.
  # Example:
  #   print TextCodePoints("😀").count
  property count: int:
    get = _points.length

  # True when the source string is empty.
  # Example:
  #   print TextCodePoints("").isEmpty
  property isEmpty: bool:
    get = _points.isEmpty

  # True when there is at least one code point.
  # Example:
  #   print TextCodePoints("a").isNotEmpty
  property isNotEmpty: bool:
    get = _points.isNotEmpty

  # Code point at zero-based [index].
  # Example:
  #   print TextCodePoints("A").codePointAt(0)
  codePointAt(index: int) -> int:
    if index < 0 or index >= _points.length:
      throw RangeError.index(index, _points, "index")
    return _points[index]

  # UTF-16 range of the code point at zero-based [index] in [source].
  # Example:
  #   print TextCodePoints("😀").rangeAt(0).length
  rangeAt(index: int) -> TextRange:
    if index < 0 or index >= _ranges.length:
      throw RangeError.index(index, _ranges, "index")
    return _ranges[index]

  # UTF-16 start offset for code-point [index] (accepts count for source.length).
  # Example:
  #   print TextCodePoints("😀a").offsetFor(1)
  offsetFor(index: int) -> int:
    if index < 0 or index > _ranges.length:
      throw RangeError.range(index, 0, _ranges.length, "index")
    if index == _ranges.length:
      return source.length
    return _ranges[index].start

  # Returns a copy of all code points.
  # Example:
  #   print TextCodePoints("AB").toList()
  toList() -> List<int> = _points.toList()

  # Iterates over all code points lazily.
  # Example:
  #   for cp in TextCodePoints("AB").iter():
  #     print cp
  iter() sync* -> int:
    for cp in _points:
      yield cp

# Extended Grapheme Cluster (UAX #29) character view over [source].
# Keeps combining diacritics, Arabic tashkeel, regional indicator flag pairs,
# Hangul jamo sequences, and ZWJ emoji sequences intact.
# Example:
#   characters = TextCharacters("قُدس 👨‍👩‍👧‍👦")
#   print characters.characterAt(0)
class TextCharacters:
  source: String required
  private _ranges: List<TextRange>

  init(this.source):
    _ranges = _segmentGraphemes(source)

  # Number of grapheme clusters in [source].
  # Example:
  #   print TextCharacters("👨‍👩‍👧‍👦").count
  property count: int:
    get = _ranges.length

  # True when [source] is empty.
  # Example:
  #   print TextCharacters("").isEmpty
  property isEmpty: bool:
    get = _ranges.isEmpty

  # True when [source] has at least one grapheme cluster.
  # Example:
  #   print TextCharacters("a").isNotEmpty
  property isNotEmpty: bool:
    get = _ranges.isNotEmpty

  # Grapheme cluster string at zero-based character [index].
  # Example:
  #   print TextCharacters("قُدس").characterAt(0)
  characterAt(index: int) -> String:
    r = rangeAt(index)
    return source.substring(r.start, r.end)

  # UTF-16 range of the grapheme cluster at zero-based character [index].
  # Example:
  #   print TextCharacters("قُدس").rangeAt(0).length
  rangeAt(index: int) -> TextRange:
    if index < 0 or index >= _ranges.length:
      throw RangeError.index(index, _ranges, "index")
    return _ranges[index]

  # Slices [source] by grapheme cluster indices [start, end).
  # Example:
  #   print TextCharacters("قُدس").slice(0, 2)
  slice(start: int, end: int) -> String:
    if start < 0 or start > _ranges.length:
      throw RangeError.range(start, 0, _ranges.length, "start")
    if end < start or end > _ranges.length:
      throw RangeError.range(end, start, _ranges.length, "end")
    if start == end:
      return ""
    return source.substring(_ranges[start].start, _ranges[end - 1].end)

  # Resolves a UTF-16 [utf16Offset] against grapheme cluster boundaries using [policy].
  # Example:
  #   print TextCharacters("😀").boundaryOffset(1, policy: TextBoundaryPolicy.next)
  boundaryOffset(utf16Offset: int, policy: TextBoundaryPolicy = TextBoundaryPolicy.reject) -> int:
    if utf16Offset < 0 or utf16Offset > source.length:
      throw RangeError.range(utf16Offset, 0, source.length, "utf16Offset")
    if utf16Offset == 0 or utf16Offset == source.length:
      return utf16Offset
    for r in _ranges:
      if utf16Offset == r.start:
        return utf16Offset
      if utf16Offset > r.start and utf16Offset < r.end:
        if policy == TextBoundaryPolicy.previous:
          return r.start
        if policy == TextBoundaryPolicy.next:
          return r.end
        throw ArgumentError("UTF-16 offset {utf16Offset} falls inside a grapheme cluster [{r.start}, {r.end})")
    return utf16Offset

  # Returns all grapheme clusters as a list of strings.
  # Example:
  #   print TextCharacters("a😀").toList().length
  toList() -> List<String>:
    out: List<String> = []
    for r in _ranges:
      out.add(source.substring(r.start, r.end))
    return out

  # Reverses [source] by grapheme clusters without breaking combining marks or emoji.
  # Example:
  #   print TextCharacters("قُدس").reversed()
  reversed() -> String:
    buffer = StringBuffer()
    var i = _ranges.length - 1
    while i >= 0:
      r = _ranges[i]
      buffer.write(source.substring(r.start, r.end))
      i = i - 1
    return buffer.toString()

  # Iterates over all grapheme clusters lazily.
  # Example:
  #   for ch in TextCharacters("قُدس").iter():
  #     print ch
  iter() sync* -> String:
    for r in _ranges:
      yield source.substring(r.start, r.end)

# Reusable Unicode normalizer configured with a [TextNormalizationForm].
# Example:
#   normalizer = TextNormalizer(TextNormalizationForm.nfc)
#   print normalizer.isNormalized("hello")
class TextNormalizer:
  form: TextNormalizationForm required

  init(this.form):
    assert true

  # Normalizes [text] into [form].
  # Example:
  #   print TextNormalizer(TextNormalizationForm.nfc).normalize("e\u0301")
  normalize(text: String) -> String = normalizeUnicode(text, form: form)

  # True when [text] is already normalized in [form].
  # Example:
  #   print TextNormalizer(TextNormalizationForm.nfc).isNormalized("abc")
  isNormalized(text: String) -> bool = isNormalizedUnicode(text, form: form)

# Normalizes [text] according to UAX #15 using [form] (defaults to NFC).
# Example:
#   print normalizeUnicode("Cafe", form: TextNormalizationForm.nfc)
normalizeUnicode(text: String, form: TextNormalizationForm = TextNormalizationForm.nfc) -> String:
  if text.isEmpty:
    return text
  compat = form == TextNormalizationForm.nfkc or form == TextNormalizationForm.nfkd
  compose = form == TextNormalizationForm.nfc or form == TextNormalizationForm.nfkc
  tables = _unicodeTables()
  cps = _decomposeAll(text, compat, tables)
  _canonicalOrder(cps, tables)
  if compose:
    _canonicalCompose(cps, tables)
  return _fromCodePoints(cps)

# True when [text] is already normalized in [form] (defaults to NFC).
# Example:
#   print isNormalizedUnicode("hello", form: TextNormalizationForm.nfc)
isNormalizedUnicode(text: String, form: TextNormalizationForm = TextNormalizationForm.nfc) -> bool:
  return normalizeUnicode(text, form: form) == text

# Performs full Unicode case folding (e.g. "ß" -> "ss", "İ" -> "i" + U+0307).
# Deterministic across Dart VM and JavaScript.
# Example:
#   print caseFoldText("Straße")
caseFoldText(text: String) -> String:
  if text.isEmpty:
    return text
  tables = _unicodeTables()
  cf = tables.caseFold
  buffer = StringBuffer()
  var i = 0
  n = text.length
  while i < n:
    unit = text.codeUnitAt(i)
    if unit >= 65 and unit <= 90:
      buffer.writeCharCode(unit + 32)
      i = i + 1
    else if unit < 128:
      buffer.writeCharCode(unit)
      i = i + 1
    else:
      var cp = unit
      var step = 1
      if unit >= 0xD800 and unit <= 0xDBFF and i + 1 < n:
        low = text.codeUnitAt(i + 1)
        if low >= 0xDC00 and low <= 0xDFFF:
          cp = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
          step = 2
      mapped = cf[cp]
      if mapped != null:
        for outCp in mapped:
          buffer.writeCharCode(outCp)
      else:
        buffer.writeCharCode(cp)
      i = i + step
  return buffer.toString()

# Reverses [text] by UAX #29 grapheme clusters without splitting combining marks
# or composite emoji.
# Example:
#   print reverseCharacters("قُدس")
reverseCharacters(text: String) -> String = TextCharacters(text).reversed()


:: inspect

# True when [text] is empty or consists solely of Unicode White_Space code points
# (Unicode 15.0: U+0009..U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000..U+200A,
# U+2028, U+2029, U+202F, U+205F, U+3000).
# Example:
#   print isBlankText(" \t ")
isBlankText(text: String) -> bool:
  var i = 0
  n = text.length
  while i < n:
    unit = text.codeUnitAt(i)
    if not _isUnicodeWhitespaceUnit(unit):
      return false
    i = i + 1
  return true

# True when [text] is non-null and not blank according to isBlankText.
# Example:
#   print hasText("Quds")
hasText(text: String?) -> bool:
  if let value = text:
    return not isBlankText(value)
  return false

# Returns null when [text] is null or blank; otherwise returns [text] verbatim
# without trimming.
# Example:
#   print blankTextToNull("  hi  ")
blankTextToNull(text: String?) -> String?:
  if let value = text:
    if not isBlankText(value):
      return value
  return null

# True when every grapheme cluster in [text] belongs to [allowed].
# Example:
#   print containsOnlyCharacters("1010", ["0", "1"])
containsOnlyCharacters(text: String, allowed: Iterable<String>) -> bool:
  permitted: Set<String> = set:
  for item in allowed:
    permitted.add(item)
  if text.isEmpty:
    return true
  for ch in TextCharacters(text).iter():
    if not permitted.contains(ch):
      return false
  return true

# True when [text] contains a recognized line break (LF, CR, NEL, LS, or PS).
# Example:
#   print hasLineBreak("a\nb")
hasLineBreak(text: String) -> bool:
  var i = 0
  n = text.length
  while i < n:
    unit = text.codeUnitAt(i)
    if unit == 10 or unit == 13 or unit == 0x85 or unit == 0x2028 or unit == 0x2029:
      return true
    i = i + 1
  return false

# True when [text] is well-formed UTF-16 with no unpaired surrogates.
# Example:
#   print isWellFormedUnicode("قدس")
isWellFormedUnicode(text: String) -> bool:
  var i = 0
  n = text.length
  while i < n:
    unit = text.codeUnitAt(i)
    if unit >= 0xD800 and unit <= 0xDBFF:
      if i + 1 >= n:
        return false
      low = text.codeUnitAt(i + 1)
      if low < 0xDC00 or low > 0xDFFF:
        return false
      i = i + 2
    else if unit >= 0xDC00 and unit <= 0xDFFF:
      return false
    else:
      i = i + 1
  return true


:: slice

# Returns the substring of [text] covered by [bounds] in UTF-16 code units.
# Throws RangeError if [bounds] exceeds [text].
# Example:
#   print sliceText("hello world", TextRange(6, 11))
sliceText(text: String, bounds: TextRange) -> String:
  validateTextRange(text, bounds)
  return text.substring(bounds.start, bounds.end)

# Returns the substring of [text] from grapheme cluster index [start] (inclusive)
# to [end] (exclusive). Never splits combining marks or composite emoji.
# Example:
#   print sliceCharacters("قُدس", 0, 2)
sliceCharacters(text: String, start: int, end: int) -> String:
  return TextCharacters(text).slice(start, end)

# Substring before the first occurrence of [marker], or null if absent.
# Rejects an empty [marker] with ArgumentError.
# Example:
#   print beforeText("key=value", "=")
beforeText(text: String, marker: String) -> String?:
  if marker.isEmpty:
    throw ArgumentError.value(marker, "marker", "marker must not be empty")
  found = text.indexOf(marker)
  if found < 0:
    return null
  return text.substring(0, found)

# Substring after the first occurrence of [marker], or null if absent.
# Rejects an empty [marker] with ArgumentError.
# Example:
#   print afterText("key=value", "=")
afterText(text: String, marker: String) -> String?:
  if marker.isEmpty:
    throw ArgumentError.value(marker, "marker", "marker must not be empty")
  found = text.indexOf(marker)
  if found < 0:
    return null
  return text.substring(found + marker.length)

# Substring before the last occurrence of [marker], or null if absent.
# Rejects an empty [marker] with ArgumentError.
# Example:
#   print beforeLastText("a.b.c", ".")
beforeLastText(text: String, marker: String) -> String?:
  if marker.isEmpty:
    throw ArgumentError.value(marker, "marker", "marker must not be empty")
  found = text.lastIndexOf(marker)
  if found < 0:
    return null
  return text.substring(0, found)

# Substring after the last occurrence of [marker], or null if absent.
# Rejects an empty [marker] with ArgumentError.
# Example:
#   print afterLastText("a.b.c", ".")
afterLastText(text: String, marker: String) -> String?:
  if marker.isEmpty:
    throw ArgumentError.value(marker, "marker", "marker must not be empty")
  found = text.lastIndexOf(marker)
  if found < 0:
    return null
  return text.substring(found + marker.length)

# Substring strictly between the first [startMarker] and the first [endMarker]
# occurring after it, or null if either marker is absent.
# Rejects empty markers with ArgumentError.
# Example:
#   print betweenText("[quds]", "[", "]")
betweenText(text: String, startMarker: String, endMarker: String) -> String?:
  if startMarker.isEmpty:
    throw ArgumentError.value(startMarker, "startMarker", "startMarker must not be empty")
  if endMarker.isEmpty:
    throw ArgumentError.value(endMarker, "endMarker", "endMarker must not be empty")
  first = text.indexOf(startMarker)
  if first < 0:
    return null
  afterStart = first + startMarker.length
  second = text.indexOf(endMarker, afterStart)
  if second < 0:
    return null
  return text.substring(afterStart, second)

# Sliding windows of UTF-16 length [size] advancing by [step] code units.
# Returns an empty list when [text] is shorter than [size].
# Example:
#   print textWindows("abcd", 2)
textWindows(text: String, size: int, step: int = 1) -> List<String>:
  if size < 1:
    throw ArgumentError.value(size, "size", "size must be >= 1")
  if step < 1:
    throw ArgumentError.value(step, "step", "step must be >= 1")
  out: List<String> = []
  var i = 0
  while i + size <= text.length:
    out.add(text.substring(i, i + size))
    i = i + step
  return out


:: patterns

# Error raised when a regular expression pattern cannot be compiled.
# Example:
#   err = TextPatternError("[unclosed", "Unterminated character class")
#   print err.pattern
class TextPatternError:
  pattern: String required
  message: String required
  offset: int? = null

  init(this.pattern, this.message, this.offset = null):
    assert true

  toString() -> String:
    if let at = offset:
      return "TextPatternError at {at} for \"{pattern}\": {message}"
    return "TextPatternError for \"{pattern}\": {message}"

# Compiled literal or regular-expression pattern reusable across search, split,
# and replace operations. Regex matching delegates to Dart RegExp (ECMAScript
# syntax shared across Dart VM and JavaScript).
# Example:
#   p = TextPattern.literal("=")
#   print p.hasMatch("a=b")
class TextPattern:
  source: String required
  isRegex: bool required
  caseSensitive: bool required
  multiLine: bool required
  dotAll: bool required
  unicode: bool required
  private regexObj: RegExp?

  init _make(this.source, this.isRegex, this.caseSensitive, this.multiLine, this.dotAll, this.unicode, this.regexObj):
    assert true

  # Creates a literal text pattern. Case-sensitive by default without hidden normalization.
  # Example:
  #   p = TextPattern.literal("quds")
  #   print p.hasMatch("hello quds")
  static literal(value: String, caseSensitive: bool = true) -> TextPattern:
    if caseSensitive:
      return TextPattern._make(value, false, true, false, false, false, null)
    compiled = RegExp(RegExp.escape(value), caseSensitive: false)
    return TextPattern._make(value, false, false, false, false, false, compiled)

  # Compiles a regular-expression pattern using Dart RegExp.
  # Throws TextPatternError if [pattern] is syntactically invalid.
  # Example:
  #   p = TextPattern.regex("[0-9]+")
  #   print p.hasMatch("x42y")
  static regex(pattern: String, caseSensitive: bool = true, multiLine: bool = false, dotAll: bool = false, unicode: bool = false) -> TextPattern:
    try:
      compiled = RegExp(
        pattern,
        caseSensitive: caseSensitive,
        multiLine: multiLine,
        dotAll: dotAll,
        unicode: unicode,
      )
      return TextPattern._make(pattern, true, caseSensitive, multiLine, dotAll, unicode, compiled)
    catch err:
      throw TextPatternError(pattern, err.toString())

  # True when this pattern matches anywhere inside [text].
  # Example:
  #   print TextPattern.literal("ab").hasMatch("xxabyy")
  hasMatch(text: String) -> bool:
    if let r = regexObj:
      return r.hasMatch(text)
    return text.contains(source)

  # The compiled RegExp backing this pattern, or null for case-sensitive literals.
  # Example:
  #   print TextPattern.regex("[0-9]+").compiledRegExp() != null
  compiledRegExp() -> RegExp? = regexObj


:: search

# Reusable search options for pattern matching.
# Example:
#   opts = TextSearchOptions(start: 2, maxMatches: 5, allowOverlap: true)
#   print opts.allowOverlap
class TextSearchOptions:
  start: int = 0
  maxMatches: int? = null
  allowOverlap: bool = false

  init(this.start = 0, this.maxMatches = null, this.allowOverlap = false):
    if start < 0:
      throw RangeError.value(start, "start", "start must be non-negative")
    if let limit = maxMatches:
      if limit < 0:
        throw ArgumentError.value(limit, "maxMatches", "maxMatches must be non-negative")

# One pattern match in the original text with its UTF-16 [range], matched [value],
# numbered capture [groups] (1-based via group(i)), and [namedGroups].
# Note: Dart RegExpMatch exposes captured strings without per-group UTF-16 offsets.
# Example:
#   m = findText("id=42", TextPattern.regex("([a-z]+)=([0-9]+)"))
#   if let hit = m:
#     print hit.group(2)
class TextMatch:
  range: TextRange required
  value: String required
  groups: List<String?> required
  namedGroups: Map<String, String?> required

  init(this.range, this.value, this.groups, this.namedGroups):
    assert true

  # Number of numbered capture groups (excluding group 0, the full match).
  # Example:
  #   m = findText("a1", TextPattern.regex("([a-z])([0-9])"))
  property groupCount: int:
    get = groups.length

  # Returns the full matched text for index 0, or the [index]-th capture group
  # (1-based; null when an optional group did not participate in the match).
  # Example:
  #   m = findText("ab", TextPattern.regex("(a)(b)?"))
  group(index: int) -> String?:
    if index == 0:
      return value
    if index < 0 or index > groups.length:
      throw RangeError.range(index, 0, groups.length, "index")
    return groups[index - 1]

  # Returns the captured string for named group [name], or null if absent or
  # non-participating.
  # Example:
  #   m = findText("x=7", TextPattern.regex("(?<k>[a-z])=(?<v>[0-9])"))
  namedGroup(name: String) -> String? = namedGroups[name]

  toString() -> String = "TextMatch({range.start}..{range.end}: {value})"

# Finds the first match of [pattern] in [text] at or after [start], or null.
# Example:
#   found = findText("name=value", TextPattern.literal("="))
#   if let m = found:
#     print m.range.start
findText(text: String, pattern: TextPattern, start: int = 0) -> TextMatch?:
  if start < 0 or start > text.length:
    throw RangeError.range(start, 0, text.length, "start")
  for m in findAllText(text, pattern, start: start, maxMatches: 1):
    return m
  return null

# Finds the last non-overlapping match of [pattern] in [text] (ending at or before [end]),
# or null when absent.
# Example:
#   found = findLastText("a=b=c", TextPattern.literal("="))
findLastText(text: String, pattern: TextPattern, end: int? = null) -> TextMatch?:
  limit = end ?? text.length
  if limit < 0 or limit > text.length:
    throw RangeError.range(limit, 0, text.length, "end")
  subject = if limit == text.length: text else: text.substring(0, limit)
  if pattern.compiledRegExp() == null:
    needle = pattern.source
    emptyNamed: Map<String, String?> = map:
    emptyGroups: List<String?> = []
    if needle.isEmpty:
      return TextMatch(TextRange(subject.length, subject.length), "", emptyGroups, emptyNamed)
    pos = subject.lastIndexOf(needle)
    if pos < 0:
      return null
    return TextMatch(TextRange(pos, pos + needle.length), needle, emptyGroups, emptyNamed)
  var last: TextMatch? = null
  for m in findAllText(subject, pattern):
    last = m
  return last

# Lazily yields matches of [pattern] in [text] starting at [start].
# Non-overlapping by default; set [allowOverlap] to true to advance by one step
# after each match. Zero-length matches advance cleanly so iteration always terminates.
# Example:
#   for m in findAllText("ababa", TextPattern.literal("aba"), allowOverlap: true):
#     print m.range.start
findAllText(text: String, pattern: TextPattern, start: int = 0, maxMatches: int? = null, allowOverlap: bool = false) sync* -> TextMatch:
  if start < 0 or start > text.length:
    throw RangeError.range(start, 0, text.length, "start")
  if maxMatches != null and maxMatches < 0:
    throw ArgumentError.value(maxMatches, "maxMatches", "maxMatches must be non-negative")
  if maxMatches != 0:
    var emitted = 0
    if let re = pattern.compiledRegExp():
      if not allowOverlap:
        for raw in re.allMatches(text, start):
          if maxMatches != null and emitted >= maxMatches:
            break
          yield _toTextMatch(text, raw)
          emitted = emitted + 1
      else:
        var cursor = start
        n = text.length
        while cursor <= n:
          if maxMatches != null and emitted >= maxMatches:
            break
          var foundOne = false
          var matchStart = cursor
          for raw in re.allMatches(text, cursor):
            yield _toTextMatch(text, raw)
            matchStart = raw.start
            foundOne = true
            emitted = emitted + 1
            break
          if not foundOne:
            break
          cursor = _advanceMatchCursor(text, matchStart, pattern.unicode)
    else:
      needle = pattern.source
      n = text.length
      var cursor = start
      if needle.isEmpty:
        while cursor <= n:
          if maxMatches != null and emitted >= maxMatches:
            break
          emptyNamed: Map<String, String?> = map:
          emptyGroups: List<String?> = []
          yield TextMatch(TextRange(cursor, cursor), "", emptyGroups, emptyNamed)
          emitted = emitted + 1
          cursor = cursor + 1
      else:
        while cursor <= n - needle.length:
          if maxMatches != null and emitted >= maxMatches:
            break
          found = text.indexOf(needle, cursor)
          if found < 0:
            break
          emptyNamed: Map<String, String?> = map:
          emptyGroups: List<String?> = []
          yield TextMatch(TextRange(found, found + needle.length), needle, emptyGroups, emptyNamed)
          emitted = emitted + 1
          cursor = if allowOverlap: found + 1 else: found + needle.length

# Counts matches of [pattern] in [text] starting at [start].
# Example:
#   print countTextMatches("ababa", TextPattern.literal("aba"), allowOverlap: true)
countTextMatches(text: String, pattern: TextPattern, start: int = 0, allowOverlap: bool = false) -> int:
  var total = 0
  for m in findAllText(text, pattern, start: start, allowOverlap: allowOverlap):
    total = total + 1
  return total

# True when [pattern] matches at least once in [text] at or after [start].
# Example:
#   print containsTextPattern("quds 2026", TextPattern.regex("[0-9]{4}"))
containsTextPattern(text: String, pattern: TextPattern, start: int = 0) -> bool:
  return findText(text, pattern, start: start) != null


:: split

# Reusable options for text splitting operations.
# [maxSplits] limits how many separator splits occur (0 means no split).
# Example:
#   opts = TextSplitOptions(keepEmpty: false, maxSplits: 2)
#   print opts.keepEmpty
class TextSplitOptions:
  keepEmpty: bool = true
  maxSplits: int? = null
  keepSeparators: bool = false

  init(this.keepEmpty = true, this.maxSplits = null, this.keepSeparators = false):
    limit = maxSplits
    if limit != null and limit < 0:
      throw ArgumentError.value(limit, "maxSplits", "maxSplits must be non-negative")

# Result of splitting a string at a single occurrence of a separator.
# Example:
#   part = splitTextOnce("name=value", "=")
#   print part.before
value class TextPartition:
  before: String required
  separator: String required
  after: String required
  found: bool required

  init(this.before, this.separator, this.after, this.found):
    assert true


  toString() -> String = "TextPartition(before: {before}, separator: {separator}, after: {after}, found: {found})"

# Splits [text] on literal [separator].
# Keeps empty segments by default; [maxSplits] counts splits (0 means no split).
# Rejects an empty [separator] or negative [maxSplits].
# Example:
#   print splitText("a,,b", ",")
splitText(text: String, separator: String, keepEmpty: bool = true, maxSplits: int? = null, keepSeparators: bool = false) -> List<String>:
  if separator.isEmpty:
    throw ArgumentError.value(separator, "separator", "separator must not be empty")
  if maxSplits != null and maxSplits < 0:
    throw ArgumentError.value(maxSplits, "maxSplits", "maxSplits must be non-negative")
  out: List<String> = []
  if maxSplits == 0:
    if keepEmpty or text.isNotEmpty:
      out.add(text)
    return out
  var start = 0
  var splits = 0
  while true:
    if maxSplits != null and splits >= maxSplits:
      break
    found = text.indexOf(separator, start)
    if found < 0:
      break
    piece = text.substring(start, found)
    if keepEmpty or piece.isNotEmpty:
      out.add(piece)
    if keepSeparators:
      out.add(separator)
    start = found + separator.length
    splits = splits + 1
  tail = text.substring(start)
  if keepEmpty or tail.isNotEmpty:
    out.add(tail)
  return out

# Splits [text] on any literal separator in [separators].
# When multiple separators match at the same position, prefers the longest match
# and breaks ties by definition order in [separators].
# Example:
#   print splitTextAny("a--b-c", ["-", "--"])
splitTextAny(text: String, separators: List<String>, keepEmpty: bool = true, maxSplits: int? = null, keepSeparators: bool = false) -> List<String>:
  if separators.isEmpty:
    throw ArgumentError.value(separators, "separators", "separators must not be empty")
  for sep in separators:
    if sep.isEmpty:
      throw ArgumentError("separators must not contain an empty string")
  if maxSplits != null and maxSplits < 0:
    throw ArgumentError.value(maxSplits, "maxSplits", "maxSplits must be non-negative")
  out: List<String> = []
  if maxSplits == 0:
    if keepEmpty or text.isNotEmpty:
      out.add(text)
    return out
  var start = 0
  var cursor = 0
  var splits = 0
  n = text.length
  while cursor < n:
    if maxSplits != null and splits >= maxSplits:
      break
    var hasMatch = false
    var matched = ""
    for sep in separators:
      if cursor + sep.length <= n and text.startsWith(sep, cursor):
        if not hasMatch or sep.length > matched.length:
          matched = sep
          hasMatch = true
    if hasMatch:
      piece = text.substring(start, cursor)
      if keepEmpty or piece.isNotEmpty:
        out.add(piece)
      if keepSeparators:
        out.add(matched)
      cursor = cursor + matched.length
      start = cursor
      splits = splits + 1
    else:
      cursor = cursor + 1
  tail = text.substring(start)
  if keepEmpty or tail.isNotEmpty:
    out.add(tail)
  return out

# Splits [text] once at the first occurrence of [separator].
# Example:
#   part = splitTextOnce("name=a=b", "=")
#   print part.after
splitTextOnce(text: String, separator: String) -> TextPartition:
  if separator.isEmpty:
    throw ArgumentError.value(separator, "separator", "separator must not be empty")
  found = text.indexOf(separator)
  if found < 0:
    return TextPartition(text, "", "", false)
  return TextPartition(text.substring(0, found), separator, text.substring(found + separator.length), true)

# Splits [text] once at the last occurrence of [separator].
# Example:
#   part = splitTextLastOnce("a/b/c", "/")
#   print part.after
splitTextLastOnce(text: String, separator: String) -> TextPartition:
  if separator.isEmpty:
    throw ArgumentError.value(separator, "separator", "separator must not be empty")
  found = text.lastIndexOf(separator)
  if found < 0:
    return TextPartition(text, "", "", false)
  return TextPartition(text.substring(0, found), separator, text.substring(found + separator.length), true)

# Splits [text] on literal [separator] into [TextSpan] views referencing [text].
# Example:
#   spans = textSegments("a,b,c", ",")
#   print spans[1].range.start
textSegments(text: String, separator: String, keepEmpty: bool = true, maxSplits: int? = null) -> List<TextSpan>:
  if separator.isEmpty:
    throw ArgumentError.value(separator, "separator", "separator must not be empty")
  if maxSplits != null and maxSplits < 0:
    throw ArgumentError.value(maxSplits, "maxSplits", "maxSplits must be non-negative")
  out: List<TextSpan> = []
  if maxSplits == 0:
    if keepEmpty or text.isNotEmpty:
      out.add(TextSpan(text, TextRange(0, text.length)))
    return out
  var start = 0
  var splits = 0
  while true:
    if maxSplits != null and splits >= maxSplits:
      break
    found = text.indexOf(separator, start)
    if found < 0:
      break
    if keepEmpty or found > start:
      out.add(TextSpan(text, TextRange(start, found)))
    start = found + separator.length
    splits = splits + 1
  if keepEmpty or text.length > start:
    out.add(TextSpan(text, TextRange(start, text.length)))
  return out

# Splits [text] using [pattern] (literal or regex).
# Rejects an empty literal pattern and negative [maxSplits].
# Handles zero-length regex matches cleanly without infinite loops.
# Example:
#   print splitTextPattern("a12b3c", TextPattern.regex("[0-9]+"))
splitTextPattern(text: String, pattern: TextPattern, keepEmpty: bool = true, maxSplits: int? = null, keepSeparators: bool = false) -> List<String>:
  if not pattern.isRegex and pattern.source.isEmpty:
    throw ArgumentError("literal separator pattern must not be empty")
  if maxSplits != null and maxSplits < 0:
    throw ArgumentError.value(maxSplits, "maxSplits", "maxSplits must be non-negative")
  out: List<String> = []
  if maxSplits == 0:
    if keepEmpty or text.isNotEmpty:
      out.add(text)
    return out
  var start = 0
  var splits = 0
  for m in findAllText(text, pattern):
    if maxSplits != null and splits >= maxSplits:
      break
    if m.range.isEmpty and m.range.start == start and splits > 0:
      continue
    piece = text.substring(start, m.range.start)
    if keepEmpty or piece.isNotEmpty:
      out.add(piece)
    if keepSeparators:
      out.add(m.value)
    start = m.range.end
    splits = splits + 1
  tail = text.substring(start)
  if keepEmpty or tail.isNotEmpty:
    out.add(tail)
  return out


:: replace

# Replaces the first match of [pattern] in [text] with literal [replacement].
# Never interprets $1 or similar backreferences in [replacement].
# Example:
#   print replaceFirstText("a=b=c", TextPattern.literal("="), ":")
replaceFirstText(text: String, pattern: TextPattern, replacement: String) -> String:
  if let hit = findText(text, pattern):
    return text.substring(0, hit.range.start) + replacement + text.substring(hit.range.end)
  return text

# Replaces the last match of [pattern] in [text] with literal [replacement].
# Never interprets $1 or similar backreferences in [replacement].
# Example:
#   print replaceLastText("a=b=c", TextPattern.literal("="), ":")
replaceLastText(text: String, pattern: TextPattern, replacement: String) -> String:
  if let hit = findLastText(text, pattern):
    return text.substring(0, hit.range.start) + replacement + text.substring(hit.range.end)
  return text

# Replaces every non-overlapping match of [pattern] in [text] with literal
# [replacement] in a single pass. Does not re-scan [replacement].
# Example:
#   print replaceAllText("a1b22c", TextPattern.regex("[0-9]+"), "#")
replaceAllText(text: String, pattern: TextPattern, replacement: String) -> String:
  return replaceTextMatches(text, pattern, (m: TextMatch) -> replacement)

# Replaces matches of [pattern] in [text] by calling [transform] once per match
# from left to right.
# Example:
#   print replaceTextMatches("a1b2", TextPattern.regex("[0-9]"), (m: TextMatch) -> "[{m.value}]")
replaceTextMatches(text: String, pattern: TextPattern, transform: (TextMatch) -> String, maxReplacements: int? = null) -> String:
  if maxReplacements != null and maxReplacements < 0:
    throw ArgumentError.value(maxReplacements, "maxReplacements", "maxReplacements must be non-negative")
  if maxReplacements == 0:
    return text
  buffer = StringBuffer()
  var cursor = 0
  var replaced = 0
  for m in findAllText(text, pattern, maxMatches: maxReplacements):
    buffer.write(text.substring(cursor, m.range.start))
    buffer.write(transform(m))
    cursor = m.range.end
    replaced = replaced + 1
  if replaced == 0:
    return text
  buffer.write(text.substring(cursor))
  return buffer.toString()

# Removes every non-overlapping match of [pattern] from [text].
# Example:
#   print removeTextMatches("a1b2c", TextPattern.regex("[0-9]+"))
removeTextMatches(text: String, pattern: TextPattern) -> String:
  return replaceAllText(text, pattern, "")

# Removes [prefix] from the start of [text] if present; otherwise returns [text].
# Example:
#   print removeTextPrefix("pre_val", "pre_")
removeTextPrefix(text: String, prefix: String) -> String:
  if prefix.isEmpty or not text.startsWith(prefix):
    return text
  return text.substring(prefix.length)

# Removes [suffix] from the end of [text] if present; otherwise returns [text].
# Example:
#   print removeTextSuffix("val_suf", "_suf")
removeTextSuffix(text: String, suffix: String) -> String:
  if suffix.isEmpty or not text.endsWith(suffix):
    return text
  return text.substring(0, text.length - suffix.length)

# Removes both [prefix] and [suffix] when [text] starts with [prefix], ends with
# [suffix], and is at least prefix.length + suffix.length code units long.
# Example:
#   print removeTextSurrounding("[quds]", "[", "]")
removeTextSurrounding(text: String, prefix: String, suffix: String) -> String:
  if text.length >= prefix.length + suffix.length and text.startsWith(prefix) and text.endsWith(suffix):
    return text.substring(prefix.length, text.length - suffix.length)
  return text

# Collapses consecutive identical grapheme clusters in [text].
# When [target] is specified, only consecutive occurrences of [target] are collapsed.
# Example:
#   print collapseRepeatedCharacters("a   b  c", target: " ")
collapseRepeatedCharacters(text: String, target: String? = null) -> String:
  if text.isEmpty:
    return text
  buffer = StringBuffer()
  var hasPrev = false
  var prev = ""
  for ch in TextCharacters(text).iter():
    shouldSkip = hasPrev and ch == prev and (target == null or ch == target)
    if not shouldSkip:
      buffer.write(ch)
      prev = ch
      hasPrev = true
  return buffer.toString()


:: compose

# Joins [parts] in a single pass with [separator] between consecutive elements.
# Example:
#   print joinText(["a", "b", "c"], separator: ", ")
joinText(parts: Iterable<String>, separator: String = "") -> String:
  buffer = StringBuffer()
  var first = true
  for part in parts:
    if not first and separator.isNotEmpty:
      buffer.write(separator)
    buffer.write(part)
    first = false
  return buffer.toString()

# Joins non-blank elements of [parts] (according to isBlankText) with [separator].
# Example:
#   print joinNonBlankText(["a", "  ", "b"], separator: "-")
joinNonBlankText(parts: Iterable<String>, separator: String = "") -> String:
  buffer = StringBuffer()
  var first = true
  for part in parts:
    if isBlankText(part):
      continue
    if not first and separator.isNotEmpty:
      buffer.write(separator)
    buffer.write(part)
    first = false
  return buffer.toString()

# Repeats [text] [count] times with optional [separator] between copies.
# Throws RangeError if [count] is negative.
# Example:
#   print repeatText("some", 3, separator: "-")
repeatText(text: String, count: int, separator: String = "") -> String:
  if count < 0:
    throw RangeError.value(count, "count", "count must be non-negative")
  if count == 0:
    return ""
  if count == 1:
    return text
  buffer = StringBuffer()
  var i = 0
  while i < count:
    if i > 0 and separator.isNotEmpty:
      buffer.write(separator)
    buffer.write(text)
    i = i + 1
  return buffer.toString()

# Wraps [text] with [prefix] and [suffix].
# Example:
#   print surroundText("quds", "[", "]")
surroundText(text: String, prefix: String, suffix: String) -> String = prefix + text + suffix

# Ensures [text] starts with [prefix] without duplicating an existing prefix.
# Example:
#   print ensureTextPrefix("home", "/")
ensureTextPrefix(text: String, prefix: String) -> String:
  if prefix.isEmpty or text.startsWith(prefix):
    return text
  return prefix + text

# Ensures [text] ends with [suffix] without duplicating an existing suffix.
# Example:
#   print ensureTextSuffix("dir", "/")
ensureTextSuffix(text: String, suffix: String) -> String:
  if suffix.isEmpty or text.endsWith(suffix):
    return text
  return text + suffix

# Lazily yields elements of [parts] with [separator] inserted between adjacent
# items without consuming [parts] upfront.
# Example:
#   for piece in interleaveText(["a", "b"], ","):
#     print piece
interleaveText(parts: Iterable<String>, separator: String) sync* -> String:
  var first = true
  for part in parts:
    if not first:
      yield separator
    yield part
    first = false


:: format

# Logical text alignment independent of visual display direction.
# Example:
#   print alignText("hi", 6, alignment: TextAlignment.center)
enum TextAlignment:
  start
  end
  center

# Reusable options for wrapping text on grapheme cluster limits.
# Example:
#   opts = TextWrapOptions(maxCharacters: 20, breakLongWords: true)
#   print opts.maxCharacters
class TextWrapOptions:
  maxCharacters: int required
  breakLongWords: bool = true
  preserveBlankLines: bool = true

  init(this.maxCharacters, this.breakLongWords = true, this.preserveBlankLines = true):
    if maxCharacters < 1:
      throw ArgumentError.value(maxCharacters, "maxCharacters", "maxCharacters must be >= 1")

# Aligns [text] to [width] UAX #29 grapheme clusters using [fill].
# Never truncates text whose grapheme count is already >= [width].
# When padding is needed, rejects empty [fill] and slices repeated [fill] on
# grapheme cluster boundaries.
# Example:
#   print alignText("قُدس", 6, alignment: TextAlignment.end, fill: ".")
alignText(text: String, width: int, alignment: TextAlignment = TextAlignment.start, fill: String = " ") -> String:
  if width < 0:
    throw RangeError.value(width, "width", "width must be non-negative")
  count = TextCharacters(text).count
  if count >= width:
    return text
  needed = width - count
  if alignment == TextAlignment.start:
    return text + _repeatFillChars(fill, needed)
  if alignment == TextAlignment.end:
    return _repeatFillChars(fill, needed) + text
  leftPad = needed ~/ 2
  rightPad = needed - leftPad
  return _repeatFillChars(fill, leftPad) + text + _repeatFillChars(fill, rightPad)

# Truncates [text] to at most [maxCharacters] UAX #29 grapheme clusters,
# including [suffix] within the limit. If [maxCharacters] is 0, returns "".
# If [suffix] exceeds [maxCharacters], truncates [suffix] on grapheme boundaries.
# Example:
#   print truncateText("hello world", 8, suffix: "...")
truncateText(text: String, maxCharacters: int, suffix: String = "...") -> String:
  if maxCharacters < 0:
    throw RangeError.value(maxCharacters, "maxCharacters", "maxCharacters must be non-negative")
  if maxCharacters == 0:
    return ""
  chars = TextCharacters(text)
  if chars.count <= maxCharacters:
    return text
  sufChars = TextCharacters(suffix)
  if sufChars.count >= maxCharacters:
    return sufChars.slice(0, maxCharacters)
  return chars.slice(0, maxCharacters - sufChars.count) + suffix

# Wraps [text] into lines bounded by [options.maxCharacters] UAX #29 grapheme clusters.
# Splits paragraphs on line breaks and words on Unicode whitespace.
# Example:
#   print wrapText("one two three", TextWrapOptions(7))
wrapText(text: String, options: TextWrapOptions) -> List<String>:
  maxCharacters = options.maxCharacters
  breakLongWords = options.breakLongWords
  preserveBlankLines = options.preserveBlankLines
  if text.isEmpty:
    return []
  paragraphs = splitTextLines(text, keepTrailingEmpty: false)
  out: List<String> = []
  for para in paragraphs:
    if isBlankText(para):
      if preserveBlankLines:
        out.add("")
      continue
    words: List<String> = []
    var i = 0
    n = para.length
    while i < n:
      while i < n and _isUnicodeWhitespaceUnit(para.codeUnitAt(i)):
        i = i + 1
      if i >= n:
        break
      wordStart = i
      while i < n and not _isUnicodeWhitespaceUnit(para.codeUnitAt(i)):
        i = i + 1
      words.add(para.substring(wordStart, i))
    var current = ""
    var currentLen = 0
    for word in words:
      wChars = TextCharacters(word)
      wLen = wChars.count
      if currentLen == 0:
        if wLen <= maxCharacters or not breakLongWords:
          current = word
          currentLen = wLen
        else:
          var pos = 0
          while pos < wLen:
            end = if pos + maxCharacters < wLen: pos + maxCharacters else: wLen
            chunk = wChars.slice(pos, end)
            if end < wLen:
              out.add(chunk)
            else:
              current = chunk
              currentLen = end - pos
            pos = end
      else if currentLen + 1 + wLen <= maxCharacters:
        current = current + " " + word
        currentLen = currentLen + 1 + wLen
      else:
        out.add(current)
        current = ""
        currentLen = 0
        if wLen <= maxCharacters or not breakLongWords:
          current = word
          currentLen = wLen
        else:
          var pos = 0
          while pos < wLen:
            end = if pos + maxCharacters < wLen: pos + maxCharacters else: wLen
            chunk = wChars.slice(pos, end)
            if end < wLen:
              out.add(chunk)
            else:
              current = chunk
              currentLen = end - pos
            pos = end
    if currentLen > 0:
      out.add(current)
  return out

# Wraps [text] using [options] and joins the resulting lines with [ending].
# Example:
#   print wrapTextJoined("one two three", TextWrapOptions(7))
wrapTextJoined(text: String, options: TextWrapOptions, ending: TextLineEnding = TextLineEnding.lf) -> String:
  return joinTextLines(wrapText(text, options), ending: ending)


:: builder

# Mutable builder for constructing strings in linear time.
# Does not expose a fake constant-time grapheme count because appending a
# combining mark can merge with the preceding character.
# Example:
#   builder = TextBuilder()
#   builder.append("Hello")
#   builder.appendLine(" Quds")
#   print builder.build()
class TextBuilder:
  private _buffer: StringBuffer = StringBuffer()

  init():
    assert true

  # Current length in UTF-16 code units.
  # Example:
  #   b = TextBuilder()
  #   b.append("hi")
  #   print b.utf16Length
  property utf16Length: int:
    get = _buffer.length

  # True when nothing has been written since creation or clear().
  # Example:
  #   print TextBuilder().isEmpty
  property isEmpty: bool:
    get = _buffer.isEmpty

  # True when at least one code unit has been written.
  # Example:
  #   b = TextBuilder()
  #   b.append("a")
  #   print b.isNotEmpty
  property isNotEmpty: bool:
    get = _buffer.isNotEmpty

  # Appends [text] to the buffer.
  # Example:
  #   b = TextBuilder()
  #   b.append("Quds")
  append(text: String):
    _buffer.write(text)

  # Appends [text] followed by [lineEnding] (defaults to LF "\n").
  # Example:
  #   b = TextBuilder()
  #   b.appendLine("line 1")
  appendLine(text: String, lineEnding: String = "\n"):
    if text.isNotEmpty:
      _buffer.write(text)
    _buffer.write(lineEnding)

  # Appends an empty line break ("\n").
  # Example:
  #   b = TextBuilder()
  #   b.appendLine()
  appendLine():
    _buffer.write("\n")

  # Appends every item of [parts] in a single pass.
  # Example:
  #   b = TextBuilder()
  #   b.appendAll(["a", "b"])
  appendAll(parts: Iterable<String>):
    for part in parts:
      _buffer.write(part)

  # Appends every item of [parts] in a single pass separated by [separator].
  # Example:
  #   b = TextBuilder()
  #   b.appendJoined(["a", "b", "c"], separator: ", ")
  appendJoined(parts: Iterable<String>, separator: String = ""):
    var first = true
    for part in parts:
      if not first and separator.isNotEmpty:
        _buffer.write(separator)
      _buffer.write(part)
      first = false

  # Appends a single Unicode scalar value [codePoint] (0..0x10FFFF, non-surrogate).
  # Example:
  #   b = TextBuilder()
  #   b.appendCodePoint(0x1F600)
  appendCodePoint(codePoint: int):
    if codePoint < 0 or codePoint > 0x10FFFF or (codePoint >= 0xD800 and codePoint <= 0xDFFF):
      throw RangeError.value(codePoint, "codePoint", "Expected a valid Unicode scalar value")
    _buffer.writeCharCode(codePoint)

  # Returns the accumulated string. Further mutations do not affect the result.
  # Example:
  #   b = TextBuilder()
  #   b.append("ok")
  #   print b.build()
  build() -> String = _buffer.toString()

  # Clears all accumulated content.
  # Example:
  #   b = TextBuilder()
  #   b.append("tmp")
  #   b.clear()
  clear():
    _buffer.clear()


:: lines

# Explicit line ending representation. Library default is LF across all platforms.
# Example:
#   print normalizeLineEndings("a\r\nb", ending: TextLineEnding.lf)
enum TextLineEnding:
  lf
  crlf
  cr

# One line parsed from a source string, preserving its content, ending, and ranges.
# Example:
#   lines = TextLines("a\r\nb")
#   print lines.lineAt(0).ending.length
value class TextLine:
  lineNumber: int required
  content: String required
  ending: String required
  contentRange: TextRange required
  fullRange: TextRange required

  init(this.lineNumber, this.content, this.ending, this.contentRange, this.fullRange):
    assert true


  toString() -> String = "TextLine({lineNumber}: {content})"

# Parsed view of lines in [source], distinguishing line content from line endings.
# Example:
#   view = TextLines("first\r\nsecond")
#   print view.count
class TextLines:
  source: String required
  keepTrailingEmpty: bool = false
  private _lines: List<TextLine>

  init(this.source, this.keepTrailingEmpty = false):
    _lines = _parseTextLines(source, keepTrailingEmpty)

  # Number of lines in this view.
  # Example:
  #   print TextLines("a\nb").count
  property count: int:
    get = _lines.length

  # True when there are no lines.
  # Example:
  #   print TextLines("").isEmpty
  property isEmpty: bool:
    get = _lines.isEmpty

  # Returns the line at zero-based [index].
  # Example:
  #   print TextLines("a\nb").lineAt(1).content
  lineAt(index: int) -> TextLine:
    if index < 0 or index >= _lines.length:
      throw RangeError.index(index, _lines, "index")
    return _lines[index]

  # Returns a copy of all parsed [TextLine] entries.
  # Example:
  #   print TextLines("a\nb").toList().length
  toList() -> List<TextLine> = _lines.toList()

  # Returns the content of each line without its line ending.
  # Example:
  #   print TextLines("a\r\nb").contents()
  contents() -> List<String>:
    out: List<String> = []
    for entry in _lines:
      out.add(entry.content)
    return out

# Splits [text] into line contents without line endings.
# Recognizes CRLF as a single line break, plus LF and CR.
# [keepTrailingEmpty] explicitly controls whether a trailing line break adds an
# empty final line (defaults to false, independent of platform).
# Example:
#   print splitTextLines("a\r\nb\n")
splitTextLines(text: String, keepTrailingEmpty: bool = false) -> List<String>:
  return TextLines(text, keepTrailingEmpty: keepTrailingEmpty).contents()

# Joins [lines] using explicit [ending] (defaults to LF across all platforms).
# Example:
#   print joinTextLines(["a", "b"], ending: TextLineEnding.crlf)
joinTextLines(lines: Iterable<String>, ending: TextLineEnding = TextLineEnding.lf, trailingNewline: bool = false) -> String:
  sep = _lineEndingString(ending)
  buffer = StringBuffer()
  var any = false
  for entry in lines:
    if any:
      buffer.write(sep)
    buffer.write(entry)
    any = true
  if any and trailingNewline:
    buffer.write(sep)
  return buffer.toString()

# Converts all CRLF, CR, and LF line endings in [text] to [ending].
# Example:
#   print normalizeLineEndings("a\r\nb\rc", ending: TextLineEnding.lf)
normalizeLineEndings(text: String, ending: TextLineEnding = TextLineEnding.lf) -> String:
  sep = _lineEndingString(ending)
  buffer = StringBuffer()
  var i = 0
  n = text.length
  while i < n:
    unit = text.codeUnitAt(i)
    if unit == 13:
      buffer.write(sep)
      if i + 1 < n and text.codeUnitAt(i + 1) == 10:
        i = i + 2
      else:
        i = i + 1
    else if unit == 10:
      buffer.write(sep)
      i = i + 1
    else:
      buffer.writeCharCode(unit)
      i = i + 1
  return buffer.toString()

# Prepends [prefix] to each line of [text], preserving original line endings.
# When [skipBlankLines] is true, blank lines are left unchanged.
# Example:
#   print indentText("a\nb", "  ")
indentText(text: String, prefix: String, skipBlankLines: bool = false) -> String:
  if text.isEmpty:
    return text
  parsed = _parseTextLines(text, true)
  buffer = StringBuffer()
  for entry in parsed:
    if not (skipBlankLines and isBlankText(entry.content)):
      buffer.write(prefix)
    buffer.write(entry.content)
    buffer.write(entry.ending)
  return buffer.toString()

# Removes common leading indentation across non-blank lines while preserving
# original line endings. Never silently converts tabs to spaces: when
# [preserveTabs] is true, computes the exact shared character prefix of tabs
# and spaces; when false, only spaces (U+0020) participate in common indentation.
# Example:
#   print dedentText("  a\n  b")
dedentText(text: String, preserveTabs: bool = true) -> String:
  if text.isEmpty:
    return text
  parsed = _parseTextLines(text, true)
  var hasCommon = false
  var common = ""
  for entry in parsed:
    if isBlankText(entry.content):
      continue
    lead = _leadingIndent(entry.content, preserveTabs)
    if hasCommon:
      common = _sharedPrefix(common, lead)
    else:
      common = lead
      hasCommon = true
  if not hasCommon or common.isEmpty:
    return text
  buffer = StringBuffer()
  for entry in parsed:
    if isBlankText(entry.content):
      if entry.content.startsWith(common):
        buffer.write(entry.content.substring(common.length))
      else:
        buffer.write(entry.content)
    else:
      buffer.write(entry.content.substring(common.length))
    buffer.write(entry.ending)
  return buffer.toString()

# Removes leading and trailing blank lines while keeping interior blank lines
# and original line endings intact.
# Example:
#   print trimBlankLines("\n  \nhello\n\nworld\n  ")
trimBlankLines(text: String) -> String:
  if text.isEmpty:
    return ""
  parsed = _parseTextLines(text, true)
  var first = 0
  while first < parsed.length and isBlankText(parsed[first].content):
    first = first + 1
  if first >= parsed.length:
    return ""
  var last = parsed.length - 1
  while last >= first and isBlankText(parsed[last].content):
    last = last - 1
  buffer = StringBuffer()
  var i = first
  while i <= last:
    buffer.write(parsed[i].content)
    if i < last:
      buffer.write(parsed[i].ending)
    i = i + 1
  return buffer.toString()


:: reader

# Error raised when a required [TextReader] operation fails, reporting the exact
# UTF-16 [offset], [position], and [message].
# Example:
#   err = TextParseError("Expected digit", 0, TextPosition(0, 1, 1))
#   print err.message
class TextParseError:
  message: String required
  offset: int required
  position: TextPosition required

  init(this.message, this.offset, this.position):
    assert true

  toString() -> String = "TextParseError at line {position.line}, column {position.column} (offset {offset}): {message}"

# Sequential UTF-16 text reader with checkpoints, rollback-safe tryRead methods,
# grapheme-aware character reading, and explicit number/quoted-literal parsing.
# Example:
#   reader = TextReader("age=42")
#   assert reader.tryReadText("age=")
#   print reader.readInt()
class TextReader:
  source: String required
  private var _pos: int = 0

  init(this.source):
    assert true

  # Current zero-based UTF-16 read offset.
  # Example:
  #   print TextReader("abc").position
  property position: int:
    get = _pos

  # Unread suffix starting at [position]. Computed on demand.
  # Example:
  #   print TextReader("abc").remaining
  property remaining: String:
    get = source.substring(_pos)

  # True when the reader has reached the end of [source].
  # Example:
  #   print TextReader("").isAtEnd
  property isAtEnd: bool:
    get = _pos >= source.length

  # Saves the current read offset as a checkpoint.
  # Example:
  #   r = TextReader("abc")
  #   mark = r.savePosition()
  savePosition() -> int = _pos

  # Restores the read offset to a previously saved [checkpoint].
  # Example:
  #   r = TextReader("abc")
  #   mark = r.savePosition()
  #   r.restorePosition(mark)
  restorePosition(checkpoint: int):
    if checkpoint < 0 or checkpoint > source.length:
      throw RangeError.range(checkpoint, 0, source.length, "checkpoint")
    _pos = checkpoint

  # Peeks the next grapheme cluster without advancing, or null at end of input.
  # Example:
  #   print TextReader("قُدس").peekCharacter()
  peekCharacter() -> String?:
    if _pos >= source.length:
      return null
    end = _nextGraphemeEnd(source, _pos)
    return source.substring(_pos, end)

  # Reads and advances past the next grapheme cluster, or throws TextParseError at end.
  # Example:
  #   r = TextReader("قُدس")
  #   print r.readCharacter()
  readCharacter() -> String:
    if _pos >= source.length:
      throw TextParseError("Unexpected end of text", _pos, textPositionAt(source, _pos))
    end = _nextGraphemeEnd(source, _pos)
    ch = source.substring(_pos, end)
    _pos = end
    return ch

  # Reads characters up to the first occurrence of [marker] (or end of input).
  # Rejects empty [marker]. When [consumeMarker] is true and [marker] is found,
  # advances past [marker] while excluding it from the returned string.
  # Example:
  #   r = TextReader("key=val")
  #   print r.readUntil("=", consumeMarker: true)
  readUntil(marker: String, consumeMarker: bool = false) -> String:
    if marker.isEmpty:
      throw ArgumentError.value(marker, "marker", "marker must not be empty")
    found = source.indexOf(marker, _pos)
    if found < 0:
      rest = source.substring(_pos)
      _pos = source.length
      return rest
    taken = source.substring(_pos, found)
    _pos = if consumeMarker: found + marker.length else: found
    return taken

  # Advances while [predicate] returns true for each grapheme cluster and returns
  # the matched slice.
  # Example:
  #   r = TextReader("abc123")
  #   print r.readWhile((c: String) -> c != "1")
  readWhile(accept: (String) -> bool) -> String:
    start = _pos
    while _pos < source.length:
      end = _nextGraphemeEnd(source, _pos)
      ch = source.substring(_pos, end)
      if not accept(ch):
        break
      _pos = end
    return source.substring(start, _pos)

  # Skips consecutive Unicode White_Space code units and returns how many were skipped.
  # Example:
  #   r = TextReader("  \thi")
  #   print r.skipWhitespace()
  skipWhitespace() -> int:
    start = _pos
    while _pos < source.length and _isUnicodeWhitespaceUnit(source.codeUnitAt(_pos)):
      _pos = _pos + 1
    return _pos - start

  # Consumes exact literal [expected] or throws TextParseError without advancing.
  # Example:
  #   r = TextReader("quds")
  #   r.expectText("quds")
  expectText(expected: String):
    if not tryReadText(expected):
      throw TextParseError("Expected \"{expected}\"", _pos, textPositionAt(source, _pos))

  # Consumes exact literal [expected] if present at [position] and returns true;
  # otherwise leaves [position] unchanged and returns false.
  # Example:
  #   r = TextReader("quds")
  #   print r.tryReadText("qu")
  tryReadText(expected: String) -> bool:
    if _pos + expected.length <= source.length and source.startsWith(expected, _pos):
      _pos = _pos + expected.length
      return true
    return false

  # Reads a quoted string delimited by [quote] with [escape] sequences
  # (\n, \r, \t, \\, \", \', or escaped delimiter). Rolls back on error.
  # Example:
  #   r = TextReader("\"hi\\n\"")
  #   print r.readQuoted()
  readQuoted(quote: String = "\"", escape: String = "\\") -> String:
    if quote.length != 1:
      throw ArgumentError.value(quote, "quote", "quote must be a single UTF-16 code unit")
    if escape.length != 1:
      throw ArgumentError.value(escape, "escape", "escape must be a single UTF-16 code unit")
    saved = _pos
    qUnit = quote.codeUnitAt(0)
    eUnit = escape.codeUnitAt(0)
    if _pos >= source.length or source.codeUnitAt(_pos) != qUnit:
      throw TextParseError("Expected opening quote {quote}", _pos, textPositionAt(source, _pos))
    _pos = _pos + 1
    buffer = StringBuffer()
    while _pos < source.length:
      unit = source.codeUnitAt(_pos)
      if unit == qUnit:
        _pos = _pos + 1
        return buffer.toString()
      if unit == eUnit:
        if _pos + 1 >= source.length:
          errAt = _pos
          _pos = saved
          throw TextParseError("Unterminated escape sequence", errAt, textPositionAt(source, errAt))
        esc = source.codeUnitAt(_pos + 1)
        if esc == 110:
          buffer.write("\n")
        else if esc == 114:
          buffer.write("\r")
        else if esc == 116:
          buffer.write("\t")
        else if esc == eUnit or esc == qUnit or esc == 34 or esc == 39:
          buffer.writeCharCode(esc)
        else:
          errAt = _pos
          _pos = saved
          throw TextParseError("Unsupported escape sequence", errAt, textPositionAt(source, errAt))
        _pos = _pos + 2
      else:
        buffer.writeCharCode(unit)
        _pos = _pos + 1
    errAt = saved
    _pos = saved
    throw TextParseError("Unterminated quoted string", errAt, textPositionAt(source, errAt))

  # Attempts to parse a signed integer in [radix] (2..36). On failure, restores
  # [position] and returns null.
  # Example:
  #   r = TextReader("-42abc")
  #   print r.tryReadInt()
  tryReadInt(radix: int = 10) -> int?:
    if radix < 2 or radix > 36:
      throw RangeError.range(radix, 2, 36, "radix")
    saved = _pos
    var cursor = _pos
    n = source.length
    if cursor < n and (source.codeUnitAt(cursor) == 43 or source.codeUnitAt(cursor) == 45):
      cursor = cursor + 1
    digitStart = cursor
    while cursor < n and _digitValue(source.codeUnitAt(cursor)) >= 0 and _digitValue(source.codeUnitAt(cursor)) < radix:
      cursor = cursor + 1
    if cursor == digitStart:
      _pos = saved
      return null
    parsed = int.tryParse(source.substring(saved, cursor), radix: radix)
    if parsed == null:
      _pos = saved
      return null
    _pos = cursor
    return parsed

  # Reads a signed integer in [radix] (2..36) or throws TextParseError without advancing.
  # Example:
  #   print TextReader("123").readInt()
  readInt(radix: int = 10) -> int:
    if let value = tryReadInt(radix: radix):
      return value
    throw TextParseError("Expected integer (radix {radix})", _pos, textPositionAt(source, _pos))

  # Attempts to parse a standard decimal or scientific floating-point number.
  # On failure, restores [position] and returns null.
  # Example:
  #   print TextReader("3.14e-2").tryReadDouble()
  tryReadDouble() -> double?:
    saved = _pos
    var cursor = _pos
    n = source.length
    if cursor < n and (source.codeUnitAt(cursor) == 43 or source.codeUnitAt(cursor) == 45):
      cursor = cursor + 1
    intStart = cursor
    while cursor < n and source.codeUnitAt(cursor) >= 48 and source.codeUnitAt(cursor) <= 57:
      cursor = cursor + 1
    hasInt = cursor > intStart
    var hasFrac = false
    if cursor < n and source.codeUnitAt(cursor) == 46:
      var dotCursor = cursor + 1
      fracStart = dotCursor
      while dotCursor < n and source.codeUnitAt(dotCursor) >= 48 and source.codeUnitAt(dotCursor) <= 57:
        dotCursor = dotCursor + 1
      if dotCursor > fracStart:
        hasFrac = true
        cursor = dotCursor
    if not hasInt and not hasFrac:
      _pos = saved
      return null
    if cursor < n and (source.codeUnitAt(cursor) == 101 or source.codeUnitAt(cursor) == 69):
      var expCursor = cursor + 1
      if expCursor < n and (source.codeUnitAt(expCursor) == 43 or source.codeUnitAt(expCursor) == 45):
        expCursor = expCursor + 1
      expStart = expCursor
      while expCursor < n and source.codeUnitAt(expCursor) >= 48 and source.codeUnitAt(expCursor) <= 57:
        expCursor = expCursor + 1
      if expCursor > expStart:
        cursor = expCursor
    parsed = double.tryParse(source.substring(saved, cursor))
    if parsed == null:
      _pos = saved
      return null
    _pos = cursor
    return parsed

  # Reads a standard decimal/scientific floating-point number or throws TextParseError.
  # Example:
  #   print TextReader("-2.5").readDouble()
  readDouble() -> double:
    if let value = tryReadDouble():
      return value
    throw TextParseError("Expected floating-point number", _pos, textPositionAt(source, _pos))


:: compare

# Reusable options for text comparison.
# Example:
#   opts = TextComparisonOptions(ignoreCase: true)
#   print opts.ignoreCase
class TextComparisonOptions:
  ignoreCase: bool = false
  normalization: TextNormalizationForm? = null

  init(this.ignoreCase = false, this.normalization = null):
    assert true

# Deterministic, locale-independent text comparison returning -1, 0, or 1.
# Applies explicit [normalization] (if non-null) and full Unicode [ignoreCase]
# folding before comparing.
# Example:
#   print compareText("Straße", "STRASSE", ignoreCase: true)
compareText(left: String, right: String, ignoreCase: bool = false, normalization: TextNormalizationForm? = null) -> int:
  a = _prepareCompare(left, ignoreCase, normalization)
  b = _prepareCompare(right, ignoreCase, normalization)
  cmp = a.compareTo(b)
  if cmp < 0:
    return -1
  if cmp > 0:
    return 1
  return 0

# True when [left] and [right] are equal under the explicit comparison options.
# Example:
#   print equalsText("Straße", "STRASSE", ignoreCase: true)
equalsText(left: String, right: String, ignoreCase: bool = false, normalization: TextNormalizationForm? = null) -> bool:
  return compareText(left, right, ignoreCase: ignoreCase, normalization: normalization) == 0

# Natural comparison splitting ASCII digit runs from non-digit text.
# Digit runs compare numerically without integer overflow; numerically equal
# runs with different leading zeros (e.g. "1" vs "01") break ties by shorter
# digit run first for a strict, anti-symmetric, transitive total order.
# Example:
#   print compareTextNaturally("file2", "file10") < 0
compareTextNaturally(left: String, right: String, ignoreCase: bool = false) -> int:
  a = if ignoreCase: caseFoldText(left) else: left
  b = if ignoreCase: caseFoldText(right) else: right
  var ia = 0
  var ib = 0
  na = a.length
  nb = b.length
  while ia < na and ib < nb:
    da = _isAsciiDigit(a.codeUnitAt(ia))
    db = _isAsciiDigit(b.codeUnitAt(ib))
    if da and db:
      var ea = ia
      while ea < na and _isAsciiDigit(a.codeUnitAt(ea)):
        ea = ea + 1
      var eb = ib
      while eb < nb and _isAsciiDigit(b.codeUnitAt(eb)):
        eb = eb + 1
      cmpNum = _compareDigitRuns(a.substring(ia, ea), b.substring(ib, eb))
      if cmpNum != 0:
        return cmpNum
      ia = ea
      ib = eb
    else:
      ua = a.codeUnitAt(ia)
      ub = b.codeUnitAt(ib)
      if ua != ub:
        if ua < ub:
          return -1
        return 1
      ia = ia + 1
      ib = ib + 1
  if ia < na:
    return 1
  if ib < nb:
    return -1
  return 0

# Longest common prefix of [left] and [right] on UAX #29 grapheme boundaries.
# Example:
#   print commonTextPrefix("قُدس", "قُدم")
commonTextPrefix(left: String, right: String) -> String:
  ca = TextCharacters(left)
  cb = TextCharacters(right)
  limit = if ca.count < cb.count: ca.count else: cb.count
  var matched = 0
  while matched < limit and ca.characterAt(matched) == cb.characterAt(matched):
    matched = matched + 1
  return ca.slice(0, matched)

# Longest common suffix of [left] and [right] on UAX #29 grapheme boundaries.
# Example:
#   print commonTextSuffix("hello.quds", "app.quds")
commonTextSuffix(left: String, right: String) -> String:
  ca = TextCharacters(left)
  cb = TextCharacters(right)
  limit = if ca.count < cb.count: ca.count else: cb.count
  var matched = 0
  while matched < limit and ca.characterAt(ca.count - 1 - matched) == cb.characterAt(cb.count - 1 - matched):
    matched = matched + 1
  return ca.slice(ca.count - matched, ca.count)

# Levenshtein edit distance between [left] and [right] measured in UAX #29
# grapheme clusters. Enforces a work guard (lenA * lenB <= 2,000,000) to avoid
# runaway quadratic computation.
# Example:
#   print editDistance("kitten", "sitting")
editDistance(left: String, right: String) -> int:
  a = TextCharacters(left).toList()
  b = TextCharacters(right).toList()
  m = a.length
  n = b.length
  if m == 0:
    return n
  if n == 0:
    return m
  if m * n > 2000000:
    throw ArgumentError("editDistance input exceeds the 2,000,000 cell work limit")
  var prev: List<int> = []
  var j = 0
  while j <= n:
    prev.add(j)
    j = j + 1
  var curr: List<int> = []
  j = 0
  while j <= n:
    curr.add(0)
    j = j + 1
  var i = 1
  while i <= m:
    curr[0] = i
    ai = a[i - 1]
    j = 1
    while j <= n:
      cost = if ai == b[j - 1]: 0 else: 1
      delCost = prev[j] + 1
      insCost = curr[j - 1] + 1
      subCost = prev[j - 1] + cost
      var best = if delCost < insCost: delCost else: insCost
      if subCost < best:
        best = subCost
      curr[j] = best
      j = j + 1
    tmp = prev
    prev = curr
    curr = tmp
    i = i + 1
  return prev[n]

# Levenshtein edit distance in grapheme clusters when <= [maxDistance], or null
# when the true distance exceeds [maxDistance].
# Example:
#   print boundedEditDistance("kitten", "sitting", 2)
boundedEditDistance(left: String, right: String, maxDistance: int) -> int?:
  if maxDistance < 0:
    throw RangeError.value(maxDistance, "maxDistance", "maxDistance must be non-negative")
  a = TextCharacters(left).toList()
  b = TextCharacters(right).toList()
  m = a.length
  n = b.length
  diff = if m > n: m - n else: n - m
  if diff > maxDistance:
    return null
  if m == 0:
    return n
  if n == 0:
    return m
  if m * n > 2000000:
    throw ArgumentError("boundedEditDistance input exceeds the 2,000,000 cell work limit")
  var prev: List<int> = []
  var j = 0
  while j <= n:
    prev.add(j)
    j = j + 1
  var curr: List<int> = []
  j = 0
  while j <= n:
    curr.add(0)
    j = j + 1
  var i = 1
  while i <= m:
    curr[0] = i
    var rowMin = i
    ai = a[i - 1]
    j = 1
    while j <= n:
      cost = if ai == b[j - 1]: 0 else: 1
      delCost = prev[j] + 1
      insCost = curr[j - 1] + 1
      subCost = prev[j - 1] + cost
      var best = if delCost < insCost: delCost else: insCost
      if subCost < best:
        best = subCost
      curr[j] = best
      if best < rowMin:
        rowMin = best
      j = j + 1
    if rowMin > maxDistance:
      return null
    tmp = prev
    prev = curr
    curr = tmp
    i = i + 1
  dist = prev[n]
  if dist > maxDistance:
    return null
  return dist

# Normalized edit similarity: 1 - editDistance(left, right) / max(lenA, lenB)
# in grapheme clusters. Two empty strings return 1.0.
# Example:
#   print textSimilarity("quds", "quds")
textSimilarity(left: String, right: String) -> double:
  ca = TextCharacters(left).count
  cb = TextCharacters(right).count
  denom = if ca > cb: ca else: cb
  if denom == 0:
    return 1.0
  dist = editDistance(left, right)
  return 1.0 - (dist.toDouble() / denom.toDouble())


:: escape

# Escapes backslash, single/double quotes, LF, CR, TAB, and ASCII control
# characters (< 0x20 or 0x7F as \xHH). Not a JSON, HTML, or URL encoder.
# Example:
#   print escapeTextLiteral("a\nb\"c")
escapeTextLiteral(text: String) -> String:
  buffer = StringBuffer()
  var i = 0
  n = text.length
  while i < n:
    u = text.codeUnitAt(i)
    if u == 92:
      buffer.write("\\\\")
    else if u == 34:
      buffer.write("\\\"")
    else if u == 39:
      buffer.write("\\'")
    else if u == 10:
      buffer.write("\\n")
    else if u == 13:
      buffer.write("\\r")
    else if u == 9:
      buffer.write("\\t")
    else if u < 32 or u == 127:
      buffer.write("\\x")
      buffer.write(_hexByte(u))
    else:
      buffer.writeCharCode(u)
    i = i + 1
  return buffer.toString()

# Decodes escape sequences produced by [escapeTextLiteral] (\\, \", \', \n, \r,
# \t, \xHH, and \u{H...}). Throws ArgumentError on malformed escapes.
# Example:
#   print unescapeTextLiteral("a\\nb")
unescapeTextLiteral(text: String) -> String:
  buffer = StringBuffer()
  var i = 0
  n = text.length
  while i < n:
    u = text.codeUnitAt(i)
    if u != 92:
      buffer.writeCharCode(u)
      i = i + 1
      continue
    if i + 1 >= n:
      throw ArgumentError("Unterminated escape sequence at offset {i}")
    esc = text.codeUnitAt(i + 1)
    if esc == 92:
      buffer.write("\\")
      i = i + 2
    else if esc == 34:
      buffer.write("\"")
      i = i + 2
    else if esc == 39:
      buffer.write("'")
      i = i + 2
    else if esc == 110:
      buffer.write("\n")
      i = i + 2
    else if esc == 114:
      buffer.write("\r")
      i = i + 2
    else if esc == 116:
      buffer.write("\t")
      i = i + 2
    else if esc == 120:
      if i + 3 >= n:
        throw ArgumentError("Incomplete \\x escape at offset {i}")
      hi = _digitValue(text.codeUnitAt(i + 2))
      lo = _digitValue(text.codeUnitAt(i + 3))
      if hi < 0 or hi > 15 or lo < 0 or lo > 15:
        throw ArgumentError("Invalid \\x hex digits at offset {i}")
      buffer.writeCharCode(hi * 16 + lo)
      i = i + 4
    else if esc == 117 and i + 2 < n and text.codeUnitAt(i + 2) == 123:
      close = text.indexOf("\}", i + 3)
      if close < 0 or close == i + 3:
        throw ArgumentError("Malformed \\u escape at offset {i}")
      hex = text.substring(i + 3, close)
      if let cp = int.tryParse(hex, radix: 16):
        if cp < 0 or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF):
          throw ArgumentError("Invalid Unicode scalar in \\u escape at offset {i}")
        buffer.writeCharCode(cp)
      else:
        throw ArgumentError("Invalid Unicode scalar in \\u escape at offset {i}")
      i = close + 1
    else:
      throw ArgumentError("Unsupported escape sequence at offset {i}")
  return buffer.toString()

# Escapes [text] and surrounds it with [quote] (either "\"" or "'").
# Example:
#   print quoteTextLiteral("a\nb")
quoteTextLiteral(text: String, quote: String = "\"") -> String:
  if quote != "\"" and quote != "'":
    throw ArgumentError.value(quote, "quote", "quote must be '\"' or \"'\"")
  return quote + escapeTextLiteral(text) + quote

# Removes surrounding [quote] delimiters and unescapes the interior.
# Throws ArgumentError if [text] is not wrapped in [quote] or has invalid escapes.
# Example:
#   print unquoteTextLiteral("\"a\\nb\"")
unquoteTextLiteral(text: String, quote: String = "\"") -> String:
  if quote != "\"" and quote != "'":
    throw ArgumentError.value(quote, "quote", "quote must be '\"' or \"'\"")
  if text.length < 2 or not text.startsWith(quote) or not text.endsWith(quote):
    throw ArgumentError("Input is not wrapped in matching quote delimiters")
  return unescapeTextLiteral(text.substring(1, text.length - 1))

# Escapes all regex metacharacters in [text] so it matches literally in RegExp.
# Example:
#   print escapeRegexLiteral("a+b[0]?")
escapeRegexLiteral(text: String) -> String = RegExp.escape(text)


:: encoding

# Explicit text encodings supported by [encodeText] and [decodeText].
# Example:
#   enc = TextEncoding.utf8
#   print enc.name
enum TextEncoding:
  utf8
  utf16Le
  utf16Be
  ascii
  latin1

# Byte-order mark detected at the start of a byte sequence.
# Example:
#   print detectTextBom([0xEF, 0xBB, 0xBF])
enum TextBom:
  none
  utf8
  utf16Le
  utf16Be

# Error raised when encoding or decoding text fails, recording the [encoding],
# failing [offset], [unit] ("byte" or "codeUnit"), and [message].
# Example:
#   err = TextEncodingError(TextEncoding.ascii, 0, "codeUnit", "Non-ASCII")
#   print err.offset
class TextEncodingError:
  encoding: TextEncoding required
  offset: int required
  unit: String required
  message: String required

  init(this.encoding, this.offset, this.unit, this.message):
    assert true

  toString() -> String = "TextEncodingError({encoding.name} at {unit} {offset}): {message}"

# Detects a leading UTF-8 or UTF-16 BOM in [bytes]. Does not guess arbitrary
# encodings from plain content.
# Example:
#   print detectTextBom([0xFF, 0xFE, 0x41, 0x00])
detectTextBom(bytes: List<int>) -> TextBom:
  var idx = 0
  for b in bytes:
    if b < 0 or b > 255:
      throw TextEncodingError(TextEncoding.utf8, idx, "byte", "Byte value {b} is outside 0..255")
    idx = idx + 1
  if bytes.length >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
    return TextBom.utf8
  if bytes.length >= 2 and bytes[0] == 0xFF and bytes[1] == 0xFE:
    return TextBom.utf16Le
  if bytes.length >= 2 and bytes[0] == 0xFE and bytes[1] == 0xFF:
    return TextBom.utf16Be
  return TextBom.none

# Encodes [text] into bytes (each in 0..255) using [encoding] (strict UTF-8 by
# default). Set [allowMalformed] to replace invalid surrogates or out-of-range
# characters explicitly instead of throwing [TextEncodingError].
# Example:
#   bytes = encodeText("قدس")
#   print bytes.length
encodeText(text: String, encoding: TextEncoding = TextEncoding.utf8, includeBom: bool = false, allowMalformed: bool = false) -> List<int>:
  if encoding == TextEncoding.utf8:
    checked = _prepareUtfText(text, encoding, allowMalformed)
    encoded = _convert.utf8.encode(checked)
    out: List<int> = []
    if includeBom:
      out.add(0xEF)
      out.add(0xBB)
      out.add(0xBF)
    for b in encoded:
      out.add(b)
    return out
  if encoding == TextEncoding.utf16Le or encoding == TextEncoding.utf16Be:
    checked = _prepareUtfText(text, encoding, allowMalformed)
    out: List<int> = []
    if includeBom:
      if encoding == TextEncoding.utf16Le:
        out.add(0xFF)
        out.add(0xFE)
      else:
        out.add(0xFE)
        out.add(0xFF)
    var i = 0
    n = checked.length
    while i < n:
      u = checked.codeUnitAt(i)
      lo = u & 0xFF
      hi = (u >> 8) & 0xFF
      if encoding == TextEncoding.utf16Le:
        out.add(lo)
        out.add(hi)
      else:
        out.add(hi)
        out.add(lo)
      i = i + 1
    return out
  if encoding == TextEncoding.ascii:
    out: List<int> = []
    var i = 0
    n = text.length
    while i < n:
      u = text.codeUnitAt(i)
      if u > 0x7F:
        if not allowMalformed:
          throw TextEncodingError(encoding, i, "codeUnit", "Code unit {u} exceeds ASCII range 0..127")
        out.add(0x3F)
      else:
        out.add(u)
      i = i + 1
    return out
  out: List<int> = []
  var i = 0
  n = text.length
  while i < n:
    u = text.codeUnitAt(i)
    if u > 0xFF:
      if not allowMalformed:
        throw TextEncodingError(encoding, i, "codeUnit", "Code unit {u} exceeds Latin-1 range 0..255")
      out.add(0x3F)
    else:
      out.add(u)
    i = i + 1
  return out

# Decodes [bytes] (each validated to be in 0..255) using [encoding] (strict
# UTF-8 by default). Set [stripBom] to explicitly strip a matching leading BOM,
# and [allowMalformed] to substitute U+FFFD on invalid sequences.
# Example:
#   print decodeText(encodeText("قدس"))
decodeText(bytes: List<int>, encoding: TextEncoding = TextEncoding.utf8, stripBom: bool = false, allowMalformed: bool = false) -> String:
  var idx = 0
  for b in bytes:
    if b < 0 or b > 255:
      throw TextEncodingError(encoding, idx, "byte", "Byte value {b} is outside 0..255")
    idx = idx + 1
  var start = 0
  if stripBom:
    bom = detectTextBom(bytes)
    if encoding == TextEncoding.utf8 and bom == TextBom.utf8:
      start = 3
    else if encoding == TextEncoding.utf16Le and bom == TextBom.utf16Le:
      start = 2
    else if encoding == TextEncoding.utf16Be and bom == TextBom.utf16Be:
      start = 2
  slice = if start == 0: bytes else: bytes.sublist(start)
  if encoding == TextEncoding.utf8:
    try:
      if not stripBom and detectTextBom(slice) == TextBom.utf8:
        return String.fromCharCode(0xFEFF) + _convert.utf8.decode(slice.sublist(3), allowMalformed: allowMalformed)
      return _convert.utf8.decode(slice, allowMalformed: allowMalformed)
    catch err:
      throw TextEncodingError(encoding, start, "byte", err.toString())
  if encoding == TextEncoding.utf16Le or encoding == TextEncoding.utf16Be:
    buffer = StringBuffer()
    var i = 0
    n = slice.length
    while i + 1 < n:
      u = if encoding == TextEncoding.utf16Le: slice[i] | (slice[i + 1] << 8) else: (slice[i] << 8) | slice[i + 1]
      if u >= 0xD800 and u <= 0xDBFF:
        if i + 3 < n:
          u2 = if encoding == TextEncoding.utf16Le: slice[i + 2] | (slice[i + 3] << 8) else: (slice[i + 2] << 8) | slice[i + 3]
          if u2 >= 0xDC00 and u2 <= 0xDFFF:
            buffer.writeCharCode(u)
            buffer.writeCharCode(u2)
            i = i + 4
            continue
        if not allowMalformed:
          throw TextEncodingError(encoding, start + i, "byte", "Unpaired UTF-16 high surrogate")
        buffer.writeCharCode(0xFFFD)
        i = i + 2
      else if u >= 0xDC00 and u <= 0xDFFF:
        if not allowMalformed:
          throw TextEncodingError(encoding, start + i, "byte", "Unpaired UTF-16 low surrogate")
        buffer.writeCharCode(0xFFFD)
        i = i + 2
      else:
        buffer.writeCharCode(u)
        i = i + 2
    if i < n:
      if not allowMalformed:
        throw TextEncodingError(encoding, start + i, "byte", "Truncated odd trailing byte in UTF-16 input")
      buffer.writeCharCode(0xFFFD)
    return buffer.toString()
  if encoding == TextEncoding.ascii:
    buffer = StringBuffer()
    var i = 0
    n = slice.length
    while i < n:
      b = slice[i]
      if b > 0x7F:
        if not allowMalformed:
          throw TextEncodingError(encoding, start + i, "byte", "Byte {b} exceeds ASCII range 0..127")
        buffer.writeCharCode(0xFFFD)
      else:
        buffer.writeCharCode(b)
      i = i + 1
    return buffer.toString()
  buffer = StringBuffer()
  for b in slice:
    buffer.writeCharCode(b)
  return buffer.toString()


:: extensions

# String convenience methods migrated from quds:ext with their original contracts
# preserved. For Unicode-aware or strict alternatives (such as Unicode whitespace,
# grapheme reversal, or nullable markers), see the top-level functions in quds:text.
extend String Text:
  # True when the text is empty or only ASCII spaces (" ").
  # For full Unicode whitespace checking, use isBlankText.
  # Example:
  #   print "  ".blank()
  blank() -> bool:
    if length == 0:
      return true
    for ch in this.chars:
      if ch != " ":
        return false
    return true

  # The first character in upper case, and the rest unchanged.
  # Example:
  #   print "ab".capitalized()
  capitalized() -> String:
    if length == 0:
      return this
    return this[0].toUpperCase() + this.substring(1)

  # The code-unit characters from last to first.
  # For grapheme-cluster-safe reversal, use reverseCharacters.
  # Example:
  #   print "ab".reversed()
  reversed() -> String:
    var out = ""
    for ch in this.chars:
      out = ch + out
    return out

  # How many times [part] occurs (including overlaps; 0 for empty [part]).
  # Example:
  #   print "ababa".count("ab")
  count(part: String) -> int:
    if part.length == 0:
      return 0
    return countTextMatches(this, TextPattern.literal(part), allowOverlap: true)

  # This text without [prefix] when it starts with that prefix.
  # Example:
  #   print "prefix-value".removePrefix("prefix-")
  removePrefix(prefix: String) -> String = removeTextPrefix(this, prefix)

  # This text without [suffix] when it ends with that suffix.
  # Example:
  #   print "value-suffix".removeSuffix("-suffix")
  removeSuffix(suffix: String) -> String = removeTextSuffix(this, suffix)

  # The text before the first [marker], or this text when [marker] is absent.
  # For nullable absence signaling, use beforeText.
  # Example:
  #   print "a-b".before("-")
  before(marker: String) -> String:
    found = this.indexOf(marker)
    if found < 0:
      return this
    return this.substring(0, found)

  # The text after the first [marker], or "" when [marker] is absent.
  # For nullable absence signaling, use afterText.
  # Example:
  #   print "a-b".after("-")
  after(marker: String) -> String:
    found = this.indexOf(marker)
    if found < 0:
      return ""
    return this.substring(found + marker.length)

  # This text repeated [times] times (returns "" when [times] <= 0).
  # Example:
  #   print "ab".repeated(3)
  repeated(times: int) -> String:
    if times <= 0:
      return ""
    return repeatText(this, times)

  # The words separated by ASCII spaces, dropping empty parts.
  # Example:
  #   print "a b".words().length
  words() -> List<String>:
    parts = this.split(" ")
    kept: List<String> = []
    for part in parts:
      if part.length > 0:
        kept.add(part)
    return kept

  # At most [limit] UTF-16 code units without a suffix (returns "" when <= 0).
  # For grapheme-aware truncation with an ellipsis, use truncateText.
  # Example:
  #   print "abcdef".truncate(3)
  truncate(limit: int) -> String:
    if limit <= 0:
      return ""
    if length <= limit:
      return this
    return this.substring(0, limit)

  # This text inside double quotes without escaping its contents.
  # For escaping + quoting, use quoteTextLiteral.
  # Example:
  #   print "ab".quoted()
  quoted() -> String = '"' + this + '"'

# Additional opt-in String extensions forwarding directly to quds:text functions
# with distinct names that never collide with core String or Text methods.
extend String TextStringExtensions:
  # Creates a UAX #29 grapheme cluster view over this string.
  # Example:
  #   print "قُدس".asTextCharacters().count
  asTextCharacters() -> TextCharacters = TextCharacters(this)

  # Creates a Unicode code-point view over this string.
  # Example:
  #   print "A😀".asTextCodePoints().count
  asTextCodePoints(strict: bool = false, replaceMalformed: bool = false) -> TextCodePoints:
    return TextCodePoints(this, strict: strict, replaceMalformed: replaceMalformed)

  # Normalizes this string according to UAX #15 [form] (defaults to NFC).
  # Example:
  #   print "Cafe".normalizedUnicode()
  normalizedUnicode(form: TextNormalizationForm = TextNormalizationForm.nfc) -> String:
    return normalizeUnicode(this, form: form)

  # Finds the first match of [pattern] in this string starting at [start].
  # Example:
  #   print "a=b".findTextMatch(TextPattern.literal("=")) != null
  findTextMatch(pattern: TextPattern, start: int = 0) -> TextMatch?:
    return findText(this, pattern, start: start)

  # Repeats this string [count] times separated by [separator].
  # Example:
  #   print "some".repeatedWithSeparator(3, "-")
  repeatedWithSeparator(count: int, separator: String) -> String:
    return repeatText(this, count, separator: separator)


:: support

_prepareCompare(text: String, ignoreCase: bool, normalization: TextNormalizationForm?) -> String:
  var current = text
  if let form = normalization:
    current = normalizeUnicode(current, form: form)
  if ignoreCase:
    current = caseFoldText(current)
  return current

_isAsciiDigit(unit: int) -> bool = unit >= 48 and unit <= 57

_compareDigitRuns(a: String, b: String) -> int:
  var za = 0
  while za < a.length and a.codeUnitAt(za) == 48:
    za = za + 1
  var zb = 0
  while zb < b.length and b.codeUnitAt(zb) == 48:
    zb = zb + 1
  sa = a.substring(za)
  sb = b.substring(zb)
  if sa.length != sb.length:
    if sa.length < sb.length:
      return -1
    return 1
  cmp = sa.compareTo(sb)
  if cmp != 0:
    if cmp < 0:
      return -1
    return 1
  if a.length != b.length:
    if a.length < b.length:
      return -1
    return 1
  return 0

_hexByte(value: int) -> String:
  hex = "0123456789abcdef"
  hi = (value >> 4) & 0xF
  lo = value & 0xF
  return hex[hi] + hex[lo]

_prepareUtfText(text: String, encoding: TextEncoding, allowMalformed: bool) -> String:
  if isWellFormedUnicode(text):
    return text
  if not allowMalformed:
    var i = 0
    n = text.length
    while i < n:
      u = text.codeUnitAt(i)
      if u >= 0xD800 and u <= 0xDBFF:
        if i + 1 < n:
          lo = text.codeUnitAt(i + 1)
          if lo >= 0xDC00 and lo <= 0xDFFF:
            i = i + 2
            continue
        throw TextEncodingError(encoding, i, "codeUnit", "Unpaired high surrogate")
      if u >= 0xDC00 and u <= 0xDFFF:
        throw TextEncodingError(encoding, i, "codeUnit", "Unpaired low surrogate")
      i = i + 1
  buffer = StringBuffer()
  var i = 0
  n = text.length
  while i < n:
    u = text.codeUnitAt(i)
    if u >= 0xD800 and u <= 0xDBFF:
      if i + 1 < n:
        lo = text.codeUnitAt(i + 1)
        if lo >= 0xDC00 and lo <= 0xDFFF:
          buffer.writeCharCode(u)
          buffer.writeCharCode(lo)
          i = i + 2
          continue
      buffer.writeCharCode(0xFFFD)
      i = i + 1
    else if u >= 0xDC00 and u <= 0xDFFF:
      buffer.writeCharCode(0xFFFD)
      i = i + 1
    else:
      buffer.writeCharCode(u)
      i = i + 1
  return buffer.toString()

_repeatFillChars(fill: String, count: int) -> String:
  if count <= 0:
    return ""
  fillChars = TextCharacters(fill)
  if fillChars.count == 0:
    throw ArgumentError.value(fill, "fill", "fill must not be empty when padding is required")
  buffer = StringBuffer()
  full = count ~/ fillChars.count
  rem = count % fillChars.count
  var i = 0
  while i < full:
    buffer.write(fill)
    i = i + 1
  if rem > 0:
    buffer.write(fillChars.slice(0, rem))
  return buffer.toString()

_toTextMatch(text: String, raw: RegExpMatch) -> TextMatch:
  val = text.substring(raw.start, raw.end)
  groups: List<String?> = []
  var g = 1
  while g <= raw.groupCount:
    groups.add(raw.group(g))
    g = g + 1
  named: Map<String, String?> = map:
  for gName in raw.groupNames:
    named[gName] = raw.namedGroup(gName)
  return TextMatch(TextRange(raw.start, raw.end), val, groups, named)

_advanceMatchCursor(text: String, pos: int, unicodeMode: bool) -> int:
  if pos >= text.length:
    return text.length + 1
  if unicodeMode and pos + 1 < text.length:
    hi = text.codeUnitAt(pos)
    lo = text.codeUnitAt(pos + 1)
    if hi >= 0xD800 and hi <= 0xDBFF and lo >= 0xDC00 and lo <= 0xDFFF:
      return pos + 2
  return pos + 1

_digitValue(unit: int) -> int:
  if unit >= 48 and unit <= 57:
    return unit - 48
  if unit >= 65 and unit <= 90:
    return unit - 55
  if unit >= 97 and unit <= 122:
    return unit - 87
  return -1

_nextGraphemeEnd(source: String, start: int) -> int:
  n = source.length
  if start >= n:
    return n
  tables = _unicodeTables()
  unit0 = source.codeUnitAt(start)
  var cp0 = unit0
  var cursor = start + 1
  if unit0 >= 0xD800 and unit0 <= 0xDBFF and start + 1 < n:
    low0 = source.codeUnitAt(start + 1)
    if low0 >= 0xDC00 and low0 <= 0xDFFF:
      cp0 = 0x10000 + ((unit0 - 0xD800) << 10) + (low0 - 0xDC00)
      cursor = start + 2
  var prev = _graphemeClass(cp0, tables)
  var riCount = if prev == 6: 1 else: 0
  var extPictState = if prev == 14: 1 else: 0
  while cursor < n:
    u = source.codeUnitAt(cursor)
    var cp = u
    var step = 1
    if u >= 0xD800 and u <= 0xDBFF and cursor + 1 < n:
      lo = source.codeUnitAt(cursor + 1)
      if lo >= 0xDC00 and lo <= 0xDFFF:
        cp = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00)
        step = 2
    curr = _graphemeClass(cp, tables)
    var shouldBreak = true
    if prev == 1 and curr == 2:
      shouldBreak = false
    else if prev == 1 or prev == 2 or prev == 3 or curr == 1 or curr == 2 or curr == 3:
      shouldBreak = true
    else if prev == 9 and (curr == 9 or curr == 10 or curr == 12 or curr == 13):
      shouldBreak = false
    else if (prev == 12 or prev == 10) and (curr == 10 or curr == 11):
      shouldBreak = false
    else if (prev == 13 or prev == 11) and curr == 11:
      shouldBreak = false
    else if curr == 4 or curr == 5:
      shouldBreak = false
    else if curr == 8:
      shouldBreak = false
    else if prev == 7:
      shouldBreak = false
    else if extPictState == 2 and curr == 14:
      shouldBreak = false
    else if prev == 6 and curr == 6 and (riCount % 2) == 1:
      shouldBreak = false
    if shouldBreak:
      break
    cursor = cursor + step
    if curr == 6:
      riCount = riCount + 1
    else:
      riCount = 0
    if curr == 14:
      extPictState = 1
    else if extPictState == 1 and curr == 4:
      extPictState = 1
    else if extPictState == 1 and curr == 5:
      extPictState = 2
    else:
      extPictState = 0
    prev = curr
  return cursor

_isUnicodeWhitespaceUnit(unit: int) -> bool:
  if unit == 0x20:
    return true
  if unit >= 0x09 and unit <= 0x0D:
    return true
  if unit == 0x85 or unit == 0xA0 or unit == 0x1680:
    return true
  if unit >= 0x2000 and unit <= 0x200A:
    return true
  if unit == 0x2028 or unit == 0x2029 or unit == 0x202F or unit == 0x205F or unit == 0x3000:
    return true
  return false

_lineEndingString(ending: TextLineEnding) -> String:
  if ending == TextLineEnding.crlf:
    return "\r\n"
  if ending == TextLineEnding.cr:
    return "\r"
  return "\n"

_parseTextLines(text: String, keepTrailingEmpty: bool) -> List<TextLine>:
  out: List<TextLine> = []
  n = text.length
  if n == 0:
    return out
  var start = 0
  var i = 0
  var lineNumber = 1
  var endedWithBreak = false
  while i < n:
    unit = text.codeUnitAt(i)
    if unit == 13:
      var endBreak = i + 1
      if i + 1 < n and text.codeUnitAt(i + 1) == 10:
        endBreak = i + 2
      out.add(TextLine(
        lineNumber,
        text.substring(start, i),
        text.substring(i, endBreak),
        TextRange(start, i),
        TextRange(start, endBreak),
      ))
      lineNumber = lineNumber + 1
      start = endBreak
      i = endBreak
      endedWithBreak = true
    else if unit == 10:
      endBreak = i + 1
      out.add(TextLine(
        lineNumber,
        text.substring(start, i),
        "\n",
        TextRange(start, i),
        TextRange(start, endBreak),
      ))
      lineNumber = lineNumber + 1
      start = endBreak
      i = endBreak
      endedWithBreak = true
    else:
      i = i + 1
      endedWithBreak = false
  if start < n or (endedWithBreak and keepTrailingEmpty):
    out.add(TextLine(
      lineNumber,
      text.substring(start, n),
      "",
      TextRange(start, n),
      TextRange(start, n),
    ))
  return out

_leadingIndent(line: String, includeTabs: bool) -> String:
  var i = 0
  while i < line.length:
    unit = line.codeUnitAt(i)
    if unit == 32 or (includeTabs and unit == 9):
      i = i + 1
    else:
      break
  return line.substring(0, i)

_sharedPrefix(a: String, b: String) -> String:
  limit = if a.length < b.length: a.length else: b.length
  var i = 0
  while i < limit and a.codeUnitAt(i) == b.codeUnitAt(i):
    i = i + 1
  return a.substring(0, i)

class _UnicodeTables:
  static var cached: _UnicodeTables? = null
  ccc: Map<int, int> required
  canon: Map<int, List<int>> required
  compat: Map<int, List<int>> required
  comp: Map<int, int> required
  caseFold: Map<int, List<int>> required
  extendSet: Set<int> required
  spacing: Set<int> required

  init(this.ccc, this.canon, this.compat, this.comp, this.caseFold, this.extendSet, this.spacing):
    assert true

_unicodeTables() -> _UnicodeTables:
  if let existing = _UnicodeTables.cached:
    return existing
  ccc: Map<int, int> = map:
  for entry in _uCccRaw().split(";"):
    if entry.isEmpty:
      continue
    parts = entry.split(",")
    start = int.parse(parts[0], radix: 36)
    span = int.parse(parts[1], radix: 36)
    cls = int.parse(parts[2], radix: 36)
    var cp = start
    while cp <= start + span:
      ccc[cp] = cls
      cp = cp + 1
  canon = _decodeDecompMap(_uCanonRaw())
  compat = _decodeDecompMap(_uCompatRaw())
  comp: Map<int, int> = map:
  for entry in _uCompRaw().split(";"):
    if entry.isEmpty:
      continue
    parts = entry.split(",")
    a = int.parse(parts[0], radix: 36)
    b = int.parse(parts[1], radix: 36)
    c = int.parse(parts[2], radix: 36)
    comp[a * 1114112 + b] = c
  caseFold = _decodeDecompMap(_uCaseFoldRaw())
  extendSet = _decodeRangeSet(_uExtendRaw())
  spacing = _decodeRangeSet(_uSpacingRaw())
  built = _UnicodeTables(ccc, canon, compat, comp, caseFold, extendSet, spacing)
  _UnicodeTables.cached = built
  return built

_decodeDecompMap(raw: String) -> Map<int, List<int>>:
  out: Map<int, List<int>> = map:
  for entry in raw.split(";"):
    if entry.isEmpty:
      continue
    colon = entry.indexOf(":")
    key = int.parse(entry.substring(0, colon), radix: 36)
    vals: List<int> = []
    for piece in entry.substring(colon + 1).split(","):
      vals.add(int.parse(piece, radix: 36))
    out[key] = vals
  return out

_decodeRangeSet(raw: String) -> Set<int>:
  out: Set<int> = set:
  for entry in raw.split(";"):
    if entry.isEmpty:
      continue
    parts = entry.split(",")
    start = int.parse(parts[0], radix: 36)
    span = int.parse(parts[1], radix: 36)
    var cp = start
    while cp <= start + span:
      out.add(cp)
      cp = cp + 1
  return out

_decomposeCodePoint(cp: int, compat: bool, tables: _UnicodeTables, out: List<int>):
  if cp >= 0xAC00 and cp <= 0xD7A3:
    sIndex = cp - 0xAC00
    l = 0x1100 + (sIndex ~/ 588)
    v = 0x1161 + ((sIndex % 588) ~/ 28)
    t = sIndex % 28
    out.add(l)
    out.add(v)
    if t != 0:
      out.add(0x11A7 + t)
    return
  mapped = tables.canon[cp]
  if mapped != null:
    for item in mapped:
      _decomposeCodePoint(item, compat, tables, out)
    return
  if compat:
    compatMapped = tables.compat[cp]
    if compatMapped != null:
      for item in compatMapped:
        _decomposeCodePoint(item, compat, tables, out)
      return
  out.add(cp)

_decomposeAll(text: String, compat: bool, tables: _UnicodeTables) -> List<int>:
  out: List<int> = []
  var i = 0
  n = text.length
  while i < n:
    unit = text.codeUnitAt(i)
    if unit >= 0xD800 and unit <= 0xDBFF and i + 1 < n:
      low = text.codeUnitAt(i + 1)
      if low >= 0xDC00 and low <= 0xDFFF:
        cp = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
        _decomposeCodePoint(cp, compat, tables, out)
        i = i + 2
        continue
    _decomposeCodePoint(unit, compat, tables, out)
    i = i + 1
  return out

_canonicalOrder(cps: List<int>, tables: _UnicodeTables):
  ccc = tables.ccc
  n = cps.length
  var i = 1
  while i < n:
    c = ccc[cps[i]] ?? 0
    if c > 0:
      var j = i
      while j > 0:
        prevC = ccc[cps[j - 1]] ?? 0
        if prevC == 0 or prevC <= c:
          break
        tmp = cps[j]
        cps[j] = cps[j - 1]
        cps[j - 1] = tmp
        j = j - 1
    i = i + 1

_composePair(first: int, second: int, tables: _UnicodeTables) -> int?:
  if first >= 0x1100 and first <= 0x1112 and second >= 0x1161 and second <= 0x1175:
    return 0xAC00 + ((first - 0x1100) * 21 + (second - 0x1161)) * 28
  if first >= 0xAC00 and first <= 0xD7A3 and ((first - 0xAC00) % 28) == 0 and second >= 0x11A8 and second <= 0x11C2:
    return first + (second - 0x11A7)
  return tables.comp[first * 1114112 + second]

_canonicalCompose(cps: List<int>, tables: _UnicodeTables):
  if cps.length < 2:
    return
  ccc = tables.ccc
  var starterIdx = -1
  var lastCcc = -1
  var writeIdx = 0
  var i = 0
  n = cps.length
  while i < n:
    ch = cps[i]
    c = ccc[ch] ?? 0
    var absorbed = false
    if starterIdx >= 0 and (lastCcc == 0 or lastCcc < c):
      combined = _composePair(cps[starterIdx], ch, tables)
      if combined != null:
        cps[starterIdx] = combined
        absorbed = true
    if not absorbed:
      if c == 0:
        starterIdx = writeIdx
        lastCcc = 0
      else:
        lastCcc = c
      cps[writeIdx] = ch
      writeIdx = writeIdx + 1
    i = i + 1
  while cps.length > writeIdx:
    cps.removeLast()

_fromCodePoints(cps: List<int>) -> String:
  buffer = StringBuffer()
  for cp in cps:
    buffer.writeCharCode(cp)
  return buffer.toString()

_isControl(cp: int) -> bool:
  if cp <= 0x09 or cp == 0x0B or cp == 0x0C or (cp >= 0x0E and cp <= 0x1F):
    return true
  if cp >= 0x7F and cp <= 0x9F:
    return true
  if cp == 0xAD or cp == 0x61C or cp == 0x180E or cp == 0x200B or cp == 0x2028 or cp == 0x2029:
    return true
  if (cp >= 0x2060 and cp <= 0x206F) or cp == 0xFEFF or (cp >= 0xFFF0 and cp <= 0xFFFB):
    return true
  if (cp >= 0x1BCA0 and cp <= 0x1BCA3) or (cp >= 0x1D173 and cp <= 0x1D17A):
    return true
  return false

_isPrepend(cp: int) -> bool:
  if (cp >= 0x0600 and cp <= 0x0605) or cp == 0x06DD or cp == 0x070F or cp == 0x0890 or cp == 0x0891 or cp == 0x08E2:
    return true
  if cp == 0x110BD or cp == 0x110CD or cp == 0x111C2 or cp == 0x111C3 or cp == 0x1193F or cp == 0x11941 or cp == 0x11A3A or (cp >= 0x11A84 and cp <= 0x11A89) or cp == 0x11D46 or cp == 0x11F02:
    return true
  return false

_isHangulL(cp: int) -> bool:
  return (cp >= 0x1100 and cp <= 0x115F) or (cp >= 0xA960 and cp <= 0xA97C)

_isHangulV(cp: int) -> bool:
  return (cp >= 0x1160 and cp <= 0x11A7) or (cp >= 0xD7B0 and cp <= 0xD7C6)

_isHangulT(cp: int) -> bool:
  return (cp >= 0x11A8 and cp <= 0x11FF) or (cp >= 0xD7CB and cp <= 0xD7FB)

_isHangulLV(cp: int) -> bool:
  return cp >= 0xAC00 and cp <= 0xD7A3 and ((cp - 0xAC00) % 28) == 0

_isHangulLVT(cp: int) -> bool:
  return cp >= 0xAC00 and cp <= 0xD7A3 and ((cp - 0xAC00) % 28) != 0

_isRegionalIndicator(cp: int) -> bool:
  return cp >= 0x1F1E6 and cp <= 0x1F1FF

_isExtendedPictographic(cp: int) -> bool:
  if cp >= 0x1F000 and cp <= 0x1FAFF:
    return true
  if cp >= 0x1FC00 and cp <= 0x1FFFD:
    return true
  if cp >= 0x2600 and cp <= 0x27BF:
    return true
  if cp == 0x00A9 or cp == 0x00AE or cp == 0x203C or cp == 0x2049 or cp == 0x2122 or cp == 0x2139:
    return true
  if (cp >= 0x2194 and cp <= 0x2199) or cp == 0x21A9 or cp == 0x21AA:
    return true
  if cp == 0x231A or cp == 0x231B or cp == 0x2328 or cp == 0x23CF or (cp >= 0x23E9 and cp <= 0x23F3) or (cp >= 0x23F8 and cp <= 0x23FA):
    return true
  if cp == 0x24C2 or cp == 0x25AA or cp == 0x25AB or cp == 0x25B6 or cp == 0x25C0 or (cp >= 0x25FB and cp <= 0x25FE):
    return true
  if cp == 0x2934 or cp == 0x2935 or (cp >= 0x2B05 and cp <= 0x2B07) or cp == 0x2B1B or cp == 0x2B1C or cp == 0x2B50 or cp == 0x2B55:
    return true
  if cp == 0x3030 or cp == 0x303D or cp == 0x3297 or cp == 0x3299:
    return true
  return false

# Grapheme break class tags:
# 0=Other, 1=CR, 2=LF, 3=Control, 4=Extend, 5=ZWJ, 6=RI, 7=Prepend,
# 8=SpacingMark, 9=L, 10=V, 11=T, 12=LV, 13=LVT, 14=ExtPict
_graphemeClass(cp: int, tables: _UnicodeTables) -> int:
  if cp == 13:
    return 1
  if cp == 10:
    return 2
  if cp == 0x200D:
    return 5
  if _isRegionalIndicator(cp):
    return 6
  if _isPrepend(cp):
    return 7
  if _isControl(cp):
    return 3
  if tables.extendSet.contains(cp):
    return 4
  if tables.spacing.contains(cp):
    return 8
  if _isHangulL(cp):
    return 9
  if _isHangulV(cp):
    return 10
  if _isHangulT(cp):
    return 11
  if _isHangulLV(cp):
    return 12
  if _isHangulLVT(cp):
    return 13
  if _isExtendedPictographic(cp):
    return 14
  return 0

_segmentGraphemes(source: String) -> List<TextRange>:
  out: List<TextRange> = []
  n = source.length
  if n == 0:
    return out
  tables = _unicodeTables()
  starts: List<int> = []
  ends: List<int> = []
  classes: List<int> = []
  var i = 0
  while i < n:
    unit = source.codeUnitAt(i)
    var cp = unit
    var step = 1
    if unit >= 0xD800 and unit <= 0xDBFF and i + 1 < n:
      low = source.codeUnitAt(i + 1)
      if low >= 0xDC00 and low <= 0xDFFF:
        cp = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
        step = 2
    starts.add(i)
    ends.add(i + step)
    classes.add(_graphemeClass(cp, tables))
    i = i + step

  var clusterStart = starts[0]
  var riCount = if classes[0] == 6: 1 else: 0
  var extPictState = if classes[0] == 14: 1 else: 0
  # extPictState: 0=none, 1=saw ExtPict (followed by 0+ Extend), 2=saw ExtPict Extend* ZWJ
  var k = 1
  m = classes.length
  while k < m:
    prev = classes[k - 1]
    curr = classes[k]
    var shouldBreak = true
    # GB3: CR x LF
    if prev == 1 and curr == 2:
      shouldBreak = false
    # GB4 / GB5: Control | CR | LF breaks
    else if prev == 1 or prev == 2 or prev == 3 or curr == 1 or curr == 2 or curr == 3:
      shouldBreak = true
    # GB6: L x (L | V | LV | LVT)
    else if prev == 9 and (curr == 9 or curr == 10 or curr == 12 or curr == 13):
      shouldBreak = false
    # GB7: (LV | V) x (V | T)
    else if (prev == 12 or prev == 10) and (curr == 10 or curr == 11):
      shouldBreak = false
    # GB8: (LVT | T) x T
    else if (prev == 13 or prev == 11) and curr == 11:
      shouldBreak = false
    # GB9: x (Extend | ZWJ)
    else if curr == 4 or curr == 5:
      shouldBreak = false
    # GB9a: x SpacingMark
    else if curr == 8:
      shouldBreak = false
    # GB9b: Prepend x
    else if prev == 7:
      shouldBreak = false
    # GB11: ExtPict Extend* ZWJ x ExtPict
    else if extPictState == 2 and curr == 14:
      shouldBreak = false
    # GB12 / GB13: RI x RI when odd number of preceding RIs
    else if prev == 6 and curr == 6 and (riCount % 2) == 1:
      shouldBreak = false

    if shouldBreak:
      out.add(TextRange(clusterStart, ends[k - 1]))
      clusterStart = starts[k]
      riCount = if curr == 6: 1 else: 0
      extPictState = if curr == 14: 1 else: 0
    else:
      if curr == 6:
        riCount = riCount + 1
      else:
        riCount = 0
      if curr == 14:
        extPictState = 1
      else if extPictState == 1 and curr == 4:
        extPictState = 1
      else if extPictState == 1 and curr == 5:
        extPictState = 2
      else:
        extPictState = 0
    k = k + 1
  out.add(TextRange(clusterStart, ends[m - 1]))
  return out

# BEGIN GENERATED UNICODE DATA
# Pinned Unicode data version: 15.0.0 (generated by tool/generate_text_unicode.py).
_uDataVersion() -> String = "15.0.0"

_uCccRaw() -> String:
  b = StringBuffer()
  b.write("lc,k,6e;lx,0,6g;ly,3,64;m2,0,6g;m3,0,60;m4,4,64;m9,1,5m;mb,3,64;mf,1,5m;mh,a,64;ms,4,1;mx,3,64;n1,7,6e;n9,0,6o;na,0,6e;n")
  b.write("b,2,64;ne,2,6e;nh,1,64;nk,2,6e;nn,3,64;nr,0,6e;ns,0,6g;nt,1,64;nv,0,6e;nw,0,6h;nx,1,6i;nz,0,6h;o0,1,6i;o2,0,6h;o3,c,6e;w")
  b.write("3,4,6e;13l,0,64;13m,3,6e;13q,0,64;13r,2,6e;13u,0,66;13v,0,64;13w,5,6e;142,5,64;148,1,6e;14a,0,64;14b,1,6e;14d,0,66;14e,0")
  b.write(",6c;14f,0,6e;14g,0,a;14h,0,b;14i,0,c;14j,0,d;14k,0,e;14l,0,f;14m,0,g;14n,0,h;14o,0,i;14p,1,j;14r,0,k;14s,0,l;14t,0,m;14v")
  b.write(",0,n;14x,0,o;14y,0,p;150,0,6e;151,0,64;153,0,i;174,7,6e;17c,0,u;17d,0,v;17e,0,w;18r,0,r;18s,0,s;18t,0,t;18u,0,u;18v,0,v;")
  b.write("18w,0,w;18x,0,x;18y,0,y;18z,1,6e;191,1,64;193,4,6e;198,0,64;199,1,6e;19b,0,64;19s,0,z;1cm,6,6e;1cv,3,6e;1cz,0,64;1d0,0,6")
  b.write("e;1d3,1,6e;1d6,0,64;1d7,1,6e;1d9,0,64;1e9,0,10;1f4,0,6e;1f5,0,64;1f6,1,6e;1f8,0,64;1f9,1,6e;1fb,2,64;1fe,0,6e;1ff,1,64;1")
  b.write("fh,0,6e;1fi,0,64;1fj,2,6e;1fm,0,64;1fn,0,6e;1fo,0,64;1fp,0,6e;1fq,0,64;1fr,0,6e;1fs,0,64;1ft,1,6e;1kb,6,6e;1ki,0,64;1kj,")
  b.write("0,6e;1kt,0,64;1li,3,6e;1ln,8,6e;1lx,2,6e;1m1,4,6e;1nd,2,64;1p4,0,6e;1p5,2,64;1p8,3,6e;1qi,4,6e;1qn,4,64;1qs,d,6e;1r7,0,6")
  b.write("4;1r8,1,6e;1ra,0,64;1rb,1,6e;1rd,0,64;1re,2,6e;1rh,2,64;1rk,0,r;1rl,0,s;1rm,0,t;1rn,2,6e;1rq,0,64;1rr,1,6e;1rt,1,64;1rv,")
  b.write("4,6e;1to,0,7;1u5,0,9;1u9,0,6e;1ua,0,64;1ub,1,6e;1x8,0,7;1xp,0,9;1z2,0,6e;20s,0,7;219,0,9;24c,0,7;24t,0,9;27w,0,7;28d,0,9")
  b.write(";2bx,0,9;2f0,0,7;2fh,0,9;2fp,0,2c;2fq,0,2j;2ik,0,7;2j1,0,9;2m3,1,9;2ml,0,9;2q2,0,9;2t4,1,2v;2t6,0,9;2tk,3,2z;2wo,1,3a;2w")
  b.write("q,0,9;2x4,3,3e;2zc,1,64;305,0,64;307,0,64;309,0,60;31t,0,3l;31u,0,3m;31w,0,3o;322,3,3m;328,0,3m;32a,1,6e;32c,0,9;32e,1,6")
  b.write("e;346,0,64;37b,0,7;37d,1,9;39p,0,64;3tp,2,6e;4k4,1,9;4l0,0,9;4pe,0,9;4pp,0,6e;4vd,0,6c;4zd,0,66;4ze,0,6e;4zf,0,64;55j,0,")
  b.write("6e;55k,0,64;57k,0,9;585,7,6e;58f,0,64;59s,4,6e;59x,5,64;5a3,1,6e;5a5,0,64;5a7,1,64;5a9,1,6e;5ab,1,64;5ad,4,6e;5ai,0,64;5")
  b.write("aj,3,6e;5dg,0,7;5dw,0,9;5ez,0,6e;5f0,0,64;5f1,6,6e;5gq,1,9;5ie,0,7;5iq,1,9;5kn,0,7;5ow,2,6e;5p0,0,1;5p1,4,64;5p6,1,6e;5p")
  b.write("8,3,64;5pc,0,6e;5pe,6,1;5pp,0,64;5pw,0,6e;5q0,1,6e;5vk,1,6e;5vm,0,64;5vn,6,6e;5vu,0,64;5vv,1,6e;5vx,0,6i;5vy,0,5y;5vz,0,")
  b.write("64;5w0,0,5m;5w1,10,6e;5x2,0,6g;5x3,1,6c;5x5,0,64;5x6,0,62;5x7,0,6e;5x8,0,6h;5x9,0,64;5xa,0,6e;5xb,0,64;6hc,1,6e;6he,1,1;")
  b.write("6hg,3,6e;6hk,2,1;6hn,1,6e;6ht,0,6e;6hx,1,1;6hz,0,6e;6i0,0,64;6i1,0,6e;6i2,1,1;6i4,3,64;6i8,0,6e;8vj,2,6e;8zj,0,9;928,v,6")
  b.write("e;9ii,0,62;9ij,0,6c;9ik,0,6g;9il,0,66;9im,1,68;9ll,1,8;wvj,0,6e;wvo,9,6e;wwu,1,6e;wz4,1,6e;x6u,0,9;x7w,0,9;xc4,0,9;xcw,h")
  b.write(",6e;xez,2,64;xg3,0,9;xir,0,7;xj4,0,9;xps,0,6e;xpu,1,6e;xpw,0,64;xpz,1,6e;xq6,1,6e;xq9,0,6e;xrq,0,9;xyl,0,9;1dlq,0,q;1e74")
  b.write(",6,6e;1e7b,6,64;1e7i,1,6e;1eyl,0,64;1f4w,0,64;1f92,4,6e;1gjx,0,64;1gjz,0,6e;1gl4,0,6e;1gl5,0,1;1gl6,0,64;1glb,0,9;1gpx,0")
  b.write(",6e;1gpy,0,64;1h5w,3,6e;1hgr,1,6e;1hj1,2,64;1hl2,1,64;1hl4,2,6e;1hl7,0,64;1hl8,0,6e;1hl9,3,64;1hmq,0,6e;1hmr,0,64;1hms,0")
  b.write(",6e;1hmt,0,64;1hs6,0,9;1htc,0,9;1htr,0,9;1hvd,0,9;1hve,0,7;1hxc,2,6e;1hyr,1,9;1i0j,0,7;1i2o,0,9;1i2y,0,7;1i5x,0,9;1i5y,0")
  b.write(",7;1iax,0,7;1iay,0,9;1id7,1,7;1idp,0,9;1iee,6,6e;1ieo,4,6e;1iki,0,9;1ikm,0,7;1ila,0,6e;1io2,0,9;1io3,0,7;1iv3,0,9;1iv4,0")
  b.write(",7;1iyn,0,9;1j1y,0,9;1j1z,0,7;1j57,0,9;1jcp,0,9;1jcq,0,7;1jjx,1,9;1jk3,0,7;1jog,0,9;1jqs,0,9;1jrb,0,9;1jtl,0,9;1k5b,0,9;")
  b.write("1kci,0,7;1kck,1,9;1kev,0,9;1kqp,1,9;1zow,4,1;1zqo,6,6e;20og,1,6;2ftq,0,1;2jxh,1,60;2jxj,2,1;2jxp,0,6a;2jxq,4,60;2jy3,7,6")
  b.write("4;2jyd,4,6e;2jyi,1,64;2jze,3,6e;2k3m,2,6e;2mtc,6,6e;2mtk,g,6e;2mu3,6,6e;2mub,1,6e;2mue,4,6e;2mxb,0,6e;2n1s,6,6e;2nce,0,6")
  b.write("e;2ne4,3,6e;2nsc,1,6g;2nse,0,64;2nsf,0,6e;2ok0,6,64;2on8,5,6e;2one,0,7")
  return b.toString()

_uCanonRaw() -> String:
  b = StringBuffer()
  b.write("5c:1t,lc;5d:1t,ld;5e:1t,le;5f:1t,lf;5g:1t,lk;5h:1t,lm;5j:1v,mf;5k:1x,lc;5l:1x,ld;5m:1x,le;5n:1x,lk;5o:21,lc;5p:21,ld;5q:")
  b.write("21,le;5r:21,lk;5t:26,lf;5u:27,lc;5v:27,ld;5w:27,le;5x:27,lf;5y:27,lk;61:2d,lc;62:2d,ld;63:2d,le;64:2d,lk;65:2h,ld;68:2p,")
  b.write("lc;69:2p,ld;6a:2p,le;6b:2p,lf;6c:2p,lk;6d:2p,lm;6f:2r,mf;6g:2t,lc;6h:2t,ld;6i:2t,le;6j:2t,lk;6k:2x,lc;6l:2x,ld;6m:2x,le;")
  b.write("6n:2x,lk;6p:32,lf;6q:33,lc;6r:33,ld;6s:33,le;6t:33,lf;6u:33,lk;6x:39,lc;6y:39,ld;6z:39,le;70:39,lk;71:3d,ld;73:3d,lk;74:")
  b.write("1t,lg;75:2p,lg;76:1t,li;77:2p,li;78:1t,mg;79:2p,mg;7a:1v,ld;7b:2r,ld;7c:1v,le;7d:2r,le;7e:1v,lj;7f:2r,lj;7g:1v,lo;7h:2r,")
  b.write("lo;7i:1w,lo;7j:2s,lo;7m:1x,lg;7n:2t,lg;7o:1x,li;7p:2t,li;7q:1x,lj;7r:2t,lj;7s:1x,mg;7t:2t,mg;7u:1x,lo;7v:2t,lo;7w:1z,le;")
  b.write("7x:2v,le;7y:1z,li;7z:2v,li;80:1z,lj;81:2v,lj;82:1z,mf;83:2v,mf;84:20,le;85:2w,le;88:21,lf;89:2x,lf;8a:21,lg;8b:2x,lg;8c:")
  b.write("21,li;8d:2x,li;8e:21,mg;8f:2x,mg;8g:21,lj;8k:22,le;8l:2y,le;8m:23,mf;8n:2z,mf;8p:24,ld;8q:30,ld;8r:24,mf;8s:30,mf;8t:24,")
  b.write("lo;8u:30,lo;8z:26,ld;90:32,ld;91:26,mf;92:32,mf;93:26,lo;94:32,lo;98:27,lg;99:33,lg;9a:27,li;9b:33,li;9c:27,ln;9d:33,ln;")
  b.write("9g:2a,ld;9h:36,ld;9i:2a,mf;9j:36,mf;9k:2a,lo;9l:36,lo;9m:2b,ld;9n:37,ld;9o:2b,le;9p:37,le;9q:2b,mf;9r:37,mf;9s:2b,lo;9t:")
  b.write("37,lo;9u:2c,mf;9v:38,mf;9w:2c,lo;9x:38,lo;a0:2d,lf;a1:39,lf;a2:2d,lg;a3:39,lg;a4:2d,li;a5:39,li;a6:2d,lm;a7:39,lm;a8:2d,")
  b.write("ln;a9:39,ln;aa:2d,mg;ab:39,mg;ac:2f,le;ad:3b,le;ae:2h,le;af:3d,le;ag:2h,lk;ah:2i,ld;ai:3e,ld;aj:2i,lj;ak:3e,lj;al:2i,lo;")
  b.write("am:3e,lo;bk:27,m3;bl:33,m3;bz:2d,m3;c0:39,m3;ct:1t,lo;cu:2p,lo;cv:21,lo;cw:2x,lo;cx:27,lo;cy:33,lo;cz:2d,lo;d0:39,lo;d1:")
  b.write("64,lg;d2:70,lg;d3:64,ld;d4:70,ld;d5:64,lo;d6:70,lo;d7:64,lc;d8:70,lc;da:5g,lg;db:6c,lg;dc:fa,lg;dd:fb,lg;de:5i,lg;df:6e,")
  b.write("lg;di:1z,lo;dj:2v,lo;dk:23,lo;dl:2z,lo;dm:27,mg;dn:33,mg;do:dm,lg;dp:dn,lg;dq:c7,lo;dr:ia,lo;ds:2y,lo;dw:1z,ld;dx:2v,ld;")
  b.write("e0:26,lc;e1:32,lc;e2:5h,ld;e3:6d,ld;e4:5i,ld;e5:6e,ld;e6:60,ld;e7:6w,ld;e8:1t,lr;e9:2p,lr;ea:1t,lt;eb:2p,lt;ec:1x,lr;ed:")
  b.write("2t,lr;ee:1x,lt;ef:2t,lt;eg:21,lr;eh:2x,lr;ei:21,lt;ej:2x,lt;ek:27,lr;el:33,lr;em:27,lt;en:33,lt;eo:2a,lr;ep:36,lr;eq:2a,")
  b.write("lt;er:36,lt;es:2d,lr;et:39,lr;eu:2d,lt;ev:39,lt;ew:2b,me;ex:37,me;ey:2c,me;ez:38,me;f2:20,lo;f3:2w,lo;fa:1t,lj;fb:2p,lj;")
  b.write("fc:1x,mf;fd:2t,mf;fe:5y,lg;ff:6u,lg;fg:5x,lg;fh:6t,lg;fi:27,lj;fj:33,lj;fk:fi,lg;fl:fj,lg;fm:2h,lg;fn:3d,lg;n4:lc;n5:ld;")
  b.write("n7:lv;n8:lk,ld;ok:jd;ou:1n;p1:4o,ld;p2:pd,ld;p3:53;p4:ph,ld;p5:pj,ld;p6:pl,ld;p8:pr,ld;pa:px,ld;pb:q1,ld;pc:qy,ld;q2:pl,")
  b.write("lk;q3:px,lk;q4:q9,ld;q5:qd,ld;q6:qf,ld;q7:qh,ld;q8:qz,ld;qy:qh,lk;qz:qt,lk;r0:qn,ld;r1:qt,ld;r2:qx,ld;r7:r6,ld;r8:r6,lk;")
  b.write("sg:t1,lc;sh:t1,lk;sj:sz,ld;sn:sm,lk;ss:t6,ld;st:t4,lc;su:tf,li;t5:t4,li;u1:u0,li;uo:tx,lc;up:tx,lk;ur:tv,ld;uv:uu,lk;v0:")
  b.write("u2,ld;v1:u0,lc;v2:ub,li;vq:vo,lr;vr:vp,lr;xt:t2,li;xu:ty,li;y8:sw,li;y9:ts,li;ya:sw,lk;yb:ts,lk;ye:t1,li;yf:tx,li;yi:yg,")
  b.write("lk;yj:yh,lk;yk:t2,lk;yl:ty,lk;ym:t3,lk;yn:tz,lk;yq:t4,lg;yr:u0,lg;ys:t4,lk;yt:u0,lk;yu:ta,lk;yv:u6,lk;yy:yw,lk;yz:yx,lk;")
  b.write("z0:tp,lk;z1:ul,lk;z2:tf,lg;z3:ub,lg;z4:tf,lk;z5:ub,lk;z6:tf,ln;z7:ub,ln;z8:tj,lk;z9:uf,lk;zc:tn,lk;zd:uj,lk;17m:17r,18z;")
  b.write("17n:17r,190;17o:18o,190;17p:17r,191;17q:18q,190;1c0:1cl,190;1c2:1c1,190;1cj:1ci,190;1t5:1t4,1to;1td:1tc,1to;1tg:1tf,1to;")
  b.write("1ug:1sl,1to;1uh:1sm,1to;1ui:1sn,1to;1uj:1ss,1to;1uk:1sx,1to;1ul:1sy,1to;1um:1t7,1to;1un:1tb,1to;1xn:1xj,1xa;1xo:1xj,1xz;")
  b.write("1y4:1wh,1x8;1y5:1wi,1x8;1y7:1wv,1x8;20j:20i,20s;20m:20o,20s;21l:1zq,20s;21m:1zr,20s;21n:1zw,20s;21q:20b,20s;288:287,28m;")
  b.write("28b:287,27y;28c:287,28n;28s:275,27w;28t:276,27w;2ac:2aa,2c7;2bu:2bq,2bi;2bv:2br,2bi;2bw:2bq,2c7;2fc:2fa,2fq;2io:2in,2j9;")
  b.write("2iv:2iu,2j9;2iw:2iu,2ja;2iy:2iu,2iq;2iz:2iy,2j9;2mi:2me,2m6;2mj:2mf,2m6;2mk:2me,2mv;2qi:2qh,2q2;2qk:2qh,2q7;2ql:2qk,2q2;")
  b.write("2qm:2qh,2qn;30j:30i,33r;30t:30s,33r;30y:30x,33r;313:312,33r;318:317,33r;31l:30g,33p;31v:31t,31u;31x:31t,31w;31y:33m,328;")
  b.write("320:33n,328;329:31t,328;32r:32q,33r;331:330,33r;336:335,33r;33b:33a,33r;33g:33f,33r;33t:32o,33p;36u:36t,372;5c6:5c5,5dh;")
  b.write("5c8:5c7,5dh;5ca:5c9,5dh;5cc:5cb,5dh;5ce:5cd,5dh;5ci:5ch,5dh;5dn:5dm,5dh;5dp:5do,5dh;5ds:5dq,5dh;5dt:5dr,5dh;5dv:5du,5dh;")
  b.write("5xc:1t,md;5xd:2p,md;5xe:1u,lj;5xf:2q,lj;5xg:1u,mb;5xh:2q,mb;5xi:1u,mp;5xj:2q,mp;5xk:5j,ld;5xl:6f,ld;5xm:1w,lj;5xn:2s,lj;")
  b.write("5xo:1w,mb;5xp:2s,mb;5xq:1w,mp;5xr:2s,mp;5xs:1w,mf;5xt:2s,mf;5xu:1w,ml;5xv:2s,ml;5xw:7m,lc;5xx:7n,lc;5xy:7m,ld;5xz:7n,ld;")
  b.write("5y0:1x,ml;5y1:2t,ml;5y2:1x,mo;5y3:2t,mo;5y4:fc,li;5y5:fd,li;5y6:1y,lj;5y7:2u,lj;5y8:1z,lg;5y9:2v,lg;5ya:20,lj;5yb:2w,lj;")
  b.write("5yc:20,mb;5yd:2w,mb;5ye:20,lk;5yf:2w,lk;5yg:20,mf;5yh:2w,mf;5yi:20,mm;5yj:2w,mm;5yk:21,mo;5yl:2x,mo;5ym:5r,ld;5yn:6n,ld;")
  b.write("5yo:23,ld;5yp:2z,ld;5yq:23,mb;5yr:2z,mb;5ys:23,mp;5yt:2z,mp;5yu:24,mb;5yv:30,mb;5yw:5yu,lg;5yx:5yv,lg;5yy:24,mp;5yz:30,m")
  b.write("p;5z0:24,ml;5z1:30,ml;5z2:25,ld;5z3:31,ld;5z4:25,lj;5z5:31,lj;5z6:25,mb;5z7:31,mb;5z8:26,lj;5z9:32,lj;5za:26,mb;5zb:32,m")
  b.write("b;5zc:26,mp;5zd:32,mp;5ze:26,ml;5zf:32,ml;5zg:5x,ld;5zh:6t,ld;5zi:5x,lk;5zj:6t,lk;5zk:98,lc;5zl:99,lc;5zm:98,ld;5zn:99,l")
  b.write("d;5zo:28,ld;5zp:34,ld;5zq:28,lj;5zr:34,lj;5zs:2a,lj;5zt:36,lj;5zu:2a,mb;5zv:36,mb;5zw:5zu,lg;5zx:5zv,lg;5zy:2a,mp;5zz:36")
  b.write(",mp;600:2b,lj;601:37,lj;602:2b,mb;603:37,mb;604:9m,lj;605:9n,lj;606:9s,lj;607:9t,lj;608:602,lj;609:603,lj;60a:2c,lj;60b:")
  b.write("38,lj;60c:2c,mb;60d:38,mb;60e:2c,mp;60f:38,mp;60g:2c,ml;60h:38,ml;60i:2d,mc;60j:39,mc;60k:2d,mo;60l:39,mo;60m:2d,ml;60n:")
  b.write("39,ml;60o:a0,ld;60p:a1,ld;60q:a2,lk;60r:a3,lk;60s:2e,lf;60t:3a,lf;60u:2e,mb;60v:3a,mb;60w:2f,lc;60x:3b,lc;60y:2f,ld;60z:")
  b.write("3b,ld;610:2f,lk;611:3b,lk;612:2f,lj;613:3b,lj;614:2f,mb;615:3b,mb;616:2g,lj;617:3c,lj;618:2g,lk;619:3c,lk;61a:2h,lj;61b:")
  b.write("3d,lj;61c:2i,le;61d:3e,le;61e:2i,mb;61f:3e,mb;61g:2i,mp;61h:3e,mp;61i:2w,mp;61j:38,lk;61k:3b,lm;61l:3d,lm;61n:an,lj;61s:")
  b.write("1t,mb;61t:2p,mb;61u:1t,ll;61v:2p,ll;61w:5e,ld;61x:6a,ld;61y:5e,lc;61z:6a,lc;620:5e,ll;621:6a,ll;622:5e,lf;623:6a,lf;624:")
  b.write("61s,le;625:61t,le;626:76,ld;627:77,ld;628:76,lc;629:77,lc;62a:76,ll;62b:77,ll;62c:76,lf;62d:77,lf;62e:61s,li;62f:61t,li;")
  b.write("62g:1x,mb;62h:2t,mb;62i:1x,ll;62j:2t,ll;62k:1x,lf;62l:2t,lf;62m:5m,ld;62n:6i,ld;62o:5m,lc;62p:6i,lc;62q:5m,ll;62r:6i,ll;")
  b.write("62s:5m,lf;62t:6i,lf;62u:62g,le;62v:62h,le;62w:21,ll;62x:2x,ll;62y:21,mb;62z:2x,mb;630:27,mb;631:33,mb;632:27,ll;633:33,l")
  b.write("l;634:5w,ld;635:6s,ld;636:5w,lc;637:6s,lc;638:5w,ll;639:6s,ll;63a:5w,lf;63b:6s,lf;63c:630,le;63d:631,le;63e:bk,ld;63f:bl")
  b.write(",ld;63g:bk,lc;63h:bl,lc;63i:bk,ll;63j:bl,ll;63k:bk,lf;63l:bl,lf;63m:bk,mb;63n:bl,mb;63o:2d,mb;63p:39,mb;63q:2d,ll;63r:39")
  b.write(",ll;63s:bz,ld;63t:c0,ld;63u:bz,lc;63v:c0,lc;63w:bz,ll;63x:c0,ll;63y:bz,lf;63z:c0,lf;640:bz,mb;641:c0,mb;642:2h,lc;643:3d")
  b.write(",lc;644:2h,mb;645:3d,mb;646:2h,ll;647:3d,ll;648:2h,lf;649:3d,lf;64g:q9,lv;64h:q9,lw;64i:64g,lc;64j:64h,lc;64k:64g,ld;64l")
  b.write(":64h,ld;64m:64g,n6;64n:64h,n6;64o:pd,lv;64p:pd,lw;64q:64o,lc;64r:64p,lc;64s:64o,ld;64t:64p,ld;64u:64o,n6;64v:64p,n6;64w:")
  b.write("qd,lv;64x:qd,lw;64y:64w,lc;64z:64x,lc;650:64w,ld;651:64x,ld;654:ph,lv;655:ph,lw;656:654,lc;657:655,lc;658:654,ld;659:655")
  b.write(",ld;65c:qf,lv;65d:qf,lw;65e:65c,lc;65f:65d,lc;65g:65c,ld;65h:65d,ld;65i:65c,n6;65j:65d,n6;65k:pj,lv;65l:pj,lw;65m:65k,lc")
  b.write(";65n:65l,lc;65o:65k,ld;65p:65l,ld;65q:65k,n6;65r:65l,n6;65s:qh,lv;65t:qh,lw;65u:65s,lc;65v:65t,lc;65w:65s,ld;65x:65t,ld;")
  b.write("65y:65s,n6;65z:65t,n6;660:pl,lv;661:pl,lw;662:660,lc;663:661,lc;664:660,ld;665:661,ld;666:660,n6;667:661,n6;668:qn,lv;66")
  b.write("9:qn,lw;66a:668,lc;66b:669,lc;66c:668,ld;66d:669,ld;66g:pr,lv;66h:pr,lw;66i:66g,lc;66j:66h,lc;66k:66g,ld;66l:66h,ld;66o:")
  b.write("qt,lv;66p:qt,lw;66q:66o,lc;66r:66p,lc;66s:66o,ld;66t:66p,ld;66u:66o,n6;66v:66p,n6;66x:px,lw;66z:66x,lc;671:66x,ld;673:66")
  b.write("x,n6;674:qx,lv;675:qx,lw;676:674,lc;677:675,lc;678:674,ld;679:675,ld;67a:674,n6;67b:675,n6;67c:q1,lv;67d:q1,lw;67e:67c,l")
  b.write("c;67f:67d,lc;67g:67c,ld;67h:67d,ld;67i:67c,n6;67j:67d,n6;67k:q9,lc;67l:q4;67m:qd,lc;67n:q5;67o:qf,lc;67p:q6;67q:qh,lc;67")
  b.write("r:q7;67s:qn,lc;67t:r0;67u:qt,lc;67v:r1;67w:qx,lc;67x:r2;680:64g,n9;681:64h,n9;682:64i,n9;683:64j,n9;684:64k,n9;685:64l,n")
  b.write("9;686:64m,n9;687:64n,n9;688:64o,n9;689:64p,n9;68a:64q,n9;68b:64r,n9;68c:64s,n9;68d:64t,n9;68e:64u,n9;68f:64v,n9;68g:65c,")
  b.write("n9;68h:65d,n9;68i:65e,n9;68j:65f,n9;68k:65g,n9;68l:65h,n9;68m:65i,n9;68n:65j,n9;68o:65k,n9;68p:65l,n9;68q:65m,n9;68r:65n")
  b.write(",n9;68s:65o,n9;68t:65p,n9;68u:65q,n9;68v:65r,n9;68w:674,n9;68x:675,n9;68y:676,n9;68z:677,n9;690:678,n9;691:679,n9;692:67")
  b.write("a,n9;693:67b,n9;694:67c,n9;695:67d,n9;696:67e,n9;697:67f,n9;698:67g,n9;699:67h,n9;69a:67i,n9;69b:67j,n9;69c:q9,li;69d:q9")
  b.write(",lg;69e:67k,n9;69f:q9,n9;69g:q4,n9;69i:q9,n6;69j:69i,n9;69k:pd,li;69l:pd,lg;69m:pd,lc;69n:p2;69o:pd,n9;69q:qh;69t:4o,n6;")
  b.write("69u:67o,n9;69v:qf,n9;69w:q6,n9;69y:qf,n6;69z:69y,n9;6a0:ph,lc;6a1:p4;6a2:pj,lc;6a3:p5;6a4:pj,n9;6a5:69r,lc;6a6:69r,ld;6a")
  b.write("7:69r,n6;6a8:qh,li;6a9:qh,lg;6aa:qy,lc;6ab:pc;6ae:qh,n6;6af:qy,n6;6ag:pl,li;6ah:pl,lg;6ai:pl,lc;6aj:p6;6al:6bi,lc;6am:6b")
  b.write("i,ld;6an:6bi,n6;6ao:qt,li;6ap:qt,lg;6aq:qz,lc;6ar:q8;6as:qp,lv;6at:qp,lw;6au:qt,n6;6av:qz,n6;6aw:px,li;6ax:px,lg;6ay:px,")
  b.write("lc;6az:pa;6b0:pt,lw;6b1:4o,lc;6b2:p1;6b3:2o;6b6:67w,n9;6b7:qx,n9;6b8:r2,n9;6ba:qx,n6;6bb:6ba,n9;6bc:pr,lc;6bd:p8;6be:q1,")
  b.write("lc;6bf:pb;6bg:q1,n9;6bh:50;6bk:6bm;6bl:6bn;6jq:q1;6ju:23;6jv:5h;6my:6mo,mw;6mz:6mq,mw;6ni:6ms,mw;6od:6og,mw;6oe:6ok,mw;6")
  b.write("of:6oi,mw;6pw:6pv,mw;6q1:6q0,mw;6q4:6q3,mw;6qs:6qr,mw;6qu:6qt,mw;6rl:6rg,mw;6ro:6rn,mw;6rr:6rp,mw;6rt:6rs,mw;6sg:1p,mw;6")
  b.write("si:6sh,mw;6st:6rx,mw;6su:1o,mw;6sv:1q,mw;6sw:6sk,mw;6sx:6sl,mw;6t0:6sy,mw;6t1:6sz,mw;6t4:6t2,mw;6t5:6t3,mw;6tc:6t6,mw;6t")
  b.write("d:6t7,mw;6tg:6te,mw;6th:6tf,mw;6tk:6ti,mw;6tl:6tj,mw;6uk:6ua,mw;6ul:6ug,mw;6um:6uh,mw;6un:6uj,mw;6w0:6t8,mw;6w1:6t9,mw;6")
  b.write("w2:6tt,mw;6w3:6tu,mw;6wa:6uq,mw;6wb:6ur,mw;6wc:6us,mw;6wd:6ut,mw;6y1:9hk;6y2:9hl;8gs:8gt,mw;9jg:9jf,9ll;9ji:9jh,9ll;9jk:")
  b.write("9jj,9ll;9jm:9jl,9ll;9jo:9jn,9ll;9jq:9jp,9ll;9js:9jr,9ll;9ju:9jt,9ll;9jw:9jv,9ll;9jy:9jx,9ll;9k0:9jz,9ll;9k2:9k1,9ll;9k5:")
  b.write("9k4,9ll;9k7:9k6,9ll;9k9:9k8,9ll;9kg:9kf,9ll;9kh:9kf,9lm;9kj:9ki,9ll;9kk:9ki,9lm;9km:9kl,9ll;9kn:9kl,9lm;9kp:9ko,9ll;9kq:")
  b.write("9ko,9lm;9ks:9kr,9ll;9kt:9kr,9lm;9lg:9ja,9ll;9lq:9lp,9ll;9m4:9m3,9ll;9m6:9m5,9ll;9m8:9m7,9ll;9ma:9m9,9ll;9mc:9mb,9ll;9me:")
  b.write("9md,9ll;9mg:9mf,9ll;9mi:9mh,9ll;9mk:9mj,9ll;9mm:9ml,9ll;9mo:9mn,9ll;9mq:9mp,9ll;9mt:9ms,9ll;9mv:9mu,9ll;9mx:9mw,9ll;9n4:")
  b.write("9n3,9ll;9n5:9n3,9lm;9n7:9n6,9ll;9n8:9n6,9lm;9na:9n9,9ll;9nb:9n9,9lm;9nd:9nc,9ll;9ne:9nc,9lm;9ng:9nf,9ll;9nh:9nf,9lm;9o4:")
  b.write("9ly,9ll;9o7:9nz,9ll;9o8:9o0,9ll;9o9:9o1,9ll;9oa:9o2,9ll;9oe:9od,9ll;1d6o:rpk;1d6p:kc4;1d6q:s7e;1d6r:rt4;1d6s:lw1;1d6t:fg")
  b.write("2;1d6u:gkl;1d6v:vj0;1d6w:vj0;1d6x:hn5;1d6y:ssx;1d6z:gw7;1d70:hmw;1d71:jcm;1d72:ne1;1d73:p6t;1d74:qin;1d75:qt6;1d76:r20;1")
  b.write("d77:sjz;1d78:kxu;1d79:ljv;1d7a:mah;1d7b:mvy;1d7c:q4d;1d7d:sq2;1d7e:uep;1d7f:fia;1d7g:ghh;1d7h:l50;1d7i:mjf;1d7j:qi5;1d7k")
  b.write(":v8e;1d7l:ifk;1d7m:m3v;1d7n:qfh;1d7o:r50;1d7p:jih;1d7q:pnc;1d7r:qvz;1d7s:iq2;1d7t:kd3;1d7u:lm2;1d7v:mpo;1d7w:slq;1d7x:fp")
  b.write("i;1d7y:g53;1d7z:gda;1d80:jwk;1d81:l3n;1d82:mj4;1d83:nhj;1d84:pa9;1d85:qh2;1d86:qjg;1d87:s1b;1d88:tv6;1d89:upb;1d8a:v7e;1")
  b.write("d8b:nt8;1d8c:nzz;1d8d:otc;1d8e:q15;1d8f:t1g;1d8g:vb3;1d8h:rfa;1d8i:hjz;1d8j:iro;1d8k:okg;1d8l:pdq;1d8m:mle;1d8n:nuy;1d8o")
  b.write(":rsy;1d8p:ttj;1d8q:hjs;1d8r:i8y;1d8s:kyb;1d8t:lp6;1d8u:lxr;1d8v:oq7;1d8w:oxj;1d8x:tor;1d8y:gcy;1d8z:pe3;1d90:g64;1d91:g5")
  b.write("o;1d92:o4c;1d93:ou6;1d94:q29;1d95:tpx;1d96:rk0;1d97:jin;1d98:kxu;1d99:rge;1d9a:fg9;1d9b:i5j;1d9c:iz6;1d9d:mtj;1d9e:n74;1")
  b.write("d9f:gev;1d9g:nwb;1d9h:fr3;1d9i:iw9;1d9j:ff1;1d9k:lho;1d9l:k1k;1d9m:opu;1d9n:gjn;1d9o:hge;1d9p:ni9;1d9q:q4p;1d9r:re2;1d9s")
  b.write(":la2;1d9t:sds;1d9u:lfs;1d9v:jjy;1d9w:put;1d9x:jog;1d9y:n6t;1d9z:fji;1da0:g2x;1da1:g5l;1da2:kn5;1da3:oo7;1da4:prj;1da5:rf")
  b.write("6;1da6:ssv;1da7:gdx;1da8:gn6;1da9:ho3;1daa:ir0;1dab:k3p;1dac:m4e;1dad:nxm;1dae:tkd;1daf:ui2;1dag:vbr;1dah:vda;1dai:gbf;1")
  b.write("daj:kau;1dak:l87;1dal:sbm;1dam:ino;1dan:j9s;1dao:jcw;1dap:jve;1daq:lyb;1dar:mdl;1das:n0p;1dat:o22;1dau:ovo;1dav:pdb;1daw")
  b.write(":s9y;1dax:q9a;1day:sgz;1daz:t3e;1db0:g7r;1db1:gbn;1db2:gql;1db3:ma0;1db4:r0i;1db5:re2;1db6:iq1;1db7:iyd;1db8:jnf;1db9:l9")
  b.write("q;1dba:oji;1dbb:mt1;1dbc:fl0;1dbd:h6h;1dbe:i5j;1dbf:iii;1dbg:izg;1dbh:muq;1dbi:mzt;1dbj:p7e;1dbk:pc6;1dbl:svo;1dbm:tti;1")
  b.write("dbn:tvs;1dbo:u1k;1dbp:fpn;1dbq:o1a;1dbr:ss4;1dbs:trs;1dbt:j4x;1dbu:fie;1dbv:fyy;1dbw:i5q;1dbx:i7z;1dby:k2h;1dbz:kxu;1dc0")
  b.write(":mha;1dc1:ncy;1dc2:q9o;1dc3:sjg;1dc4:vil;1dc5:k94;1dc6:tny;1dc7:gax;1dc8:kfv;1dc9:kj7;1dca:lkx;1dcb:luk;1dcc:mx5;1dcd:n6")
  b.write("h;1dce:nsb;1dcf:opc;1dcg:u3i;1dch:g31;1dci:je6;1dcj:tq0;1dck:fu3;1dcl:ie1;1dcm:lpm;1dcn:sa2;1dco:ivf;1dcp:j7o;1dcq:kk7;1")
  b.write("dcr:mtj;1dcs:tqe;1dct:g89;1dcu:glr;1dcv:i91;1dcw:k5v;1dcx:kem;1dcy:ko8;1dcz:lid;1dd0:mx2;1dd1:naa;1dd2:p6h;1dd3:r0v;1dd4")
  b.write(":r1d;1dd5:sss;1dd6:tsy;1dd7:gfz;1dd8:lve;1dd9:gm5;1dda:mhc;1ddb:n14;1ddc:qgq;1ddd:tr7;1dde:uvr;1ddf:vbz;1ddg:kgn;1ddh:lo")
  b.write("r;1ddi:pns;1ddj:o97;1ddk:obk;1ddl:olu;1ddm:mo0;1ddn:m8p;1ddo:riw;1ddp:fk0;1ddq:px2;1ddr:g8q;1dds:g7b;1ddt:ip2;1ddu:jir;1")
  b.write("ddv:onq;1ddw:i2t;1ddx:ljy;1ddy:kac;1ddz:saj;1de0:qx8;1de1:tot;1de2:r63;1de3:iqb;1de4:g1s;1de5:gxs;1de8:hga;1dea:k8k;1ded")
  b.write(":g66;1dee:mqy;1def:ngq;1deg:ny4;1deh:nz2;1dei:nz9;1dej:o0f;1dek:tw6;1del:on2;1dem:p8d;1deo:qhe;1deq:rg8;1det:shk;1deu:sn")
  b.write("1;1dey:u7j;1dez:u7w;1df0:u94;1df1:v5g;1df2:sm6;1df3:trr;1df4:fqm;1df5:fzb;1df6:g25;1df7:gcp;1df8:gdg;1df9:ggh;1dfa:gwt;1")
  b.write("dfb:gzq;1dfc:h2g;1dfd:hfk;1dfe:hig;1dff:i90;1dfg:i9a;1dfh:j2s;1dfi:j8o;1dfj:j9q;1dfk:jci;1dfl:k0f;1dfm:k4i;1dfn:k9d;1dfo")
  b.write(":kn9;1dfp:lmf;1dfq:lqy;1dfr:lya;1dfs:mem;1dft:mjv;1dfu:mxu;1dfv:ntd;1dfw:ny6;1dfx:nyh;1dfy:nyg;1dfz:nyo;1dg0:nyu;1dg1:nz")
  b.write("1;1dg2:o0d;1dg3:o0e;1dg4:o5c;1dg5:o75;1dg6:og0;1dg7:ovo;1dg8:ow9;1dg9:oxt;1dga:p6a;1dgb:pad;1dgc:pnx;1dgd:prt;1dge:prt;1")
  b.write("dgf:q53;1dgg:r2o;1dgh:r6e;1dgi:rgh;1dgj:ri1;1dgk:rtf;1dgl:ruw;1dgm:sdy;1dgn:shk;1dgo:tsz;1dgp:u0v;1dgq:u2j;1dgr:j1x;1dgs")
  b.write(":36cu;1dgt:pp4;1dgw:ffq;1dgx:g51;1dgy:g2w;1dgz:fpc;1dh0:g1x;1dh1:g3k;1dh2:gcn;1dh3:ge2;1dh4:gwt;1dh5:gut;1dh6:gwp;1dh7:g")
  b.write("yq;1dh8:hga;1dh9:hir;1dha:hms;1dhb:hn8;1dhc:huq;1dhd:i08;1dhe:iqa;1dhf:iqh;1dhg:iuh;1dhh:iwd;1dhi:j4o;1dhj:j7y;1dhk:j60;")
  b.write("1dhl:j9q;1dhm:j8g;1dhn:jci;1dho:jec;1dhp:jpg;1dhq:jrw;1dhr:jte;1dhs:k0m;1dht:k8k;1dhu:kd3;1dhv:kd7;1dhw:keu;1dhx:l89;1dh")
  b.write("y:la2;1dhz:lkx;1di0:lwb;1di1:lvv;1di2:lya;1di3:m5a;1di4:mem;1di5:nmv;1di6:mk5;1di7:mnj;1di8:mqy;1di9:n01;1dia:n46;1dib:n")
  b.write("5n;1dic:nbx;1did:nbz;1die:ngq;1dif:nh7;1dig:nhw;1dih:nka;1dii:nk0;1dij:nv0;1dik:o8h;1dil:og0;1dim:ol7;1din:orf;1dio:ovo;")
  b.write("1dip:p4u;1diq:pad;1dir:pxu;1dis:q27;1dit:qrd;1diu:r41;1div:r5y;1diw:r6e;1dix:ren;1diy:rg8;1diz:rez;1dj0:rgh;1dj1:rge;1dj")
  b.write("2:rfx;1dj3:ri1;1dj4:rka;1dj5:ruw;1dj6:sag;1dj7:sj6;1dj8:srd;1dj9:sxi;1dja:tq4;1djb:tsz;1djc:tw6;1djd:tzv;1dje:u0v;1djf:u")
  b.write("17;1djg:u2j;1djh:umq;1dji:vj0;1djj:313e;1djk:3138;1djl:33dh;1djm:brx;1djn:cns;1djo:cop;1djp:39e1;1djq:3bgw;1djr:3i6r;1dj")
  b.write("s:vgj;1djt:vim;1dlp:15l,14k;1dlr:16a,14n;1dm2:161,14x;1dm3:161,14y;1dm4:1dmx,14x;1dm5:1dmx,14y;1dm6:15c,14n;1dm7:15c,14o")
  b.write(";1dm8:15c,14s;1dm9:15d,14s;1dma:15e,14s;1dmb:15f,14s;1dmc:15g,14s;1dmd:15h,14s;1dme:15i,14s;1dmg:15k,14s;1dmh:15l,14s;1d")
  b.write("mi:15m,14s;1dmj:15n,14s;1dmk:15o,14s;1dmm:15q,14s;1dmo:15s,14s;1dmp:15t,14s;1dmr:15v,14s;1dms:15w,14s;1dmu:15y,14s;1dmv:")
  b.write("15z,14s;1dmw:160,14s;1dmx:161,14s;1dmy:162,14s;1dmz:15h,14p;1dn0:15d,14v;1dn1:15n,14v;1dn2:15w,14v;1hui:1huh,1hve;1huk:1")
  b.write("huj,1hve;1huz:1hut,1hve;1hym:1hyp,1hyf;1hyn:1hyq,1hyf;1idn:1idj,1ida;1ido:1idj,1idz;1inv:1int,1inu;1inw:1int,1ink;1iny:1")
  b.write("int,1inx;1iuy:1iuw,1iun;1iuz:1iux,1iun;1jjs:1jjp,1jjk;2jxa:2jx3,2jxh;2jxb:2jx4,2jxh;2jxc:2jxb,2jxq;2jxd:2jxb,2jxr;2jxe:2")
  b.write("jxb,2jxs;2jxf:2jxb,2jxt;2jxg:2jxb,2jxu;2jzv:2jzt,2jxh;2jzw:2jzu,2jxh;2jzx:2jzv,2jxq;2jzy:2jzw,2jxq;2jzz:2jzv,2jxr;2k00:2")
  b.write("jzw,2jxr;464g:fgd;464h:fg8;464i:fgh;464j:2tcy;464k:fog;464l:fqm;464m:fqz;464n:fsy;464o:fwa;464p:fx5;464q:fzb;464r:fyn;46")
  b.write("4s:ae6;464t:2ud6;464u:g25;464v:g2c;464w:g2s;464x:g3b;464y:2u58;464z:aex;4650:g2v;4651:g3x;4652:2u6j;4653:g47;4654:g4k;46")
  b.write("55:fkc;4656:g4s;4657:g51;4658:3ly7;4659:g6t;465a:g77;465b:afz;465c:g8r;465d:g92;465e:gaa;465f:gaf;465g:ahh;465h:gcn;465i")
  b.write(":gcp;465j:gdg;465k:ge2;465l:ged;465m:gee;465n:gev;465o:gg9;465p:ggh;465q:ggq;465r:ghf;465s:ghp;465t:ghr;465u:ghr;465v:gh")
  b.write("r;465w:2v58;465x:m7k;465y:gju;465z:gkf;4660:2vdv;4661:gkr;4662:gkx;4663:gli;4664:gpq;4665:gmw;4666:gnc;4667:go8;4668:gpu")
  b.write(";4669:gs6;466a:gsw;466b:gur;466c:gv7;466d:gw4;466e:gw4;466f:gwp;466g:gx7;466h:gxf;466i:gxu;466j:h7a;466k:gzq;466l:h7b;46")
  b.write("6m:h1t;466n:h2s;466o:g7b;466p:hke;466q:hce;466r:hdg;466s:he5;466t:haj;466u:hf6;466v:hf5;466w:hik;466x:2x9g;466y:hki;466z")
  b.write(":hkn;4670:hl2;4671:hlm;4672:hlu;4673:hnm;4674:2xm0;4675:2xnu;4676:hrg;4677:hsr;4678:ht3;4679:hqw;467a:huu;467b:aum;467c:")
  b.write("av0;467d:hzc;467e:i0u;467f:i0u;467g:2y88;467h:i4j;467i:i54;467j:i5j;467k:i5v;467l:2yhk;467m:i67;467n:i6e;467o:itv;467p:i")
  b.write("76;467q:ayp;467r:i8w;467s:i9a;467t:ibk;467u:ia5;467v:2z1g;467w:if7;467x:2z1i;467y:ige;467z:igb;4680:igs;4681:ijl;4682:ij")
  b.write("m;4683:b3j;4684:ikd;4685:ilk;4686:im5;4687:ind;4688:b4y;4689:2zr7;468a:b5o;468b:ipc;468c:ipf;468d:ipi;468e:iq2;468f:3pg2")
  b.write(";468g:iri;468h:3035;468i:3035;468j:poh;468k:isi;468l:isi;468m:b7r;468n:335k;468o:3cgq;468p:iua;468q:iuj;468r:b8j;468s:iv")
  b.write("u;468t:ix9;468u:ixj;468v:iyh;468w:j29;468x:bay;468y:ba4;468z:j2s;4690:30t0;4691:j47;4692:j7s;4693:j7w;4694:j7y;4695:j7w;")
  b.write("4696:j96;4697:j9q;4698:jaq;4699:jac;469a:jan;469b:jby;469c:jci;469d:jcm;469e:jdc;469f:jdn;469g:jfh;469h:jht;469i:jis;469")
  b.write("j:jm8;469k:31n0;469l:jlp;469m:jjw;469n:jmw;469o:jnn;469p:jqc;469q:31td;469r:js2;469s:jph;469t:jop;469u:bhq;469v:ju1;469w")
  b.write(":jum;469x:jvh;469y:juf;469z:bjg;46a0:k0f;46a1:k18;46a2:32mi;46a3:k4j;46a4:kc8;46a5:k7d;46a6:bo9;46a7:k9d;46a8:bns;46a9:b")
  b.write("ms;46aa:g42;46ab:g45;46ac:kcg;46ad:k9o;46ae:pf1;46af:deh;46ag:kd3;46ah:kd7;46ai:kdd;46aj:kf2;46ak:ker;46al:33cz;46am:bpl")
  b.write(";46an:kje;46ao:kg5;46ap:klu;46aq:kn9;46ar:33hp;46as:kni;46at:kkf;46au:kr8;46av:brx;46aw:ksi;46ax:kv7;46ay:kx6;46az:l2g;4")
  b.write("6b0:33xf;46b1:l3v;46b2:bvc;46b3:l5t;46b4:34br;46b5:l78;46b6:bwu;46b7:l82;46b8:l9b;46b9:la2;46ba:la3;46bb:34p9;46bc:2yvf;")
  b.write("46bd:34sa;46be:le6;46bf:354s;46bg:lhb;46bh:lhp;46bi:lev;46bj:ljq;46bk:lku;46bl:lmf;46bm:lkx;46bn:lm1;46bo:lmg;46bp:lmt;4")
  b.write("6bq:357i;46br:lkk;46bs:lrj;46bt:lta;46bu:c37;46bv:lvv;46bw:lvr;46bx:35jl;46by:lq1;46bz:m0e;46c0:35ni;46c1:35ou;46c2:m2u;")
  b.write("46c3:m61;46c4:m5a;46c5:m57;46c6:c5y;46c7:m6i;46c8:m7x;46c9:m7r;46ca:m99;46cb:2u5h;46cc:mdh;46cd:368z;46ce:mfw;46cf:36i3;")
  b.write("46cg:mjs;46ch:mk5;46ci:mkw;46cj:36yw;46ck:mm8;46cl:mmt;46cm:3779;46cn:37dg;46co:mt6;46cp:mtn;46cq:cdo;46cr:mud;46cs:ce0;")
  b.write("46ct:ce0;46cu:myv;46cv:mzg;46cw:n01;46cx:n0l;46cy:n2i;46cz:cgr;46d0:n50;46d1:386u;46d2:n5q;46d3:389e;46d4:n74;46d5:2zrz;")
  b.write("46d6:nbk;46d7:38v5;46d8:38vs;46d9:38zo;46da:cn0;46db:cnc;46dc:nhw;46dd:394j;46de:394i;46df:395l;46dg:396b;46dh:nj2;46di:")
  b.write("nj3;46dj:nj3;46dk:nka;46dl:cop;46dm:nm3;46dn:cp2;46do:cra;46dp:39r1;46dq:nri;46dr:nt8;46ds:nv0;46dt:ctf;46du:3a5i;46dv:n")
  b.write("yu;46dw:3a8q;46dx:3a9x;46dy:o0f;46dz:o2z;46e0:cvj;46e1:o5c;46e2:o5m;46e3:o5r;46e4:3at8;46e5:3b1j;46e6:3b1j;46e7:oa6;46e8")
  b.write(":d1e;46e9:3b8r;46ea:og6;46eb:og9;46ec:d2f;46ed:3beo;46ee:onm;46ef:d5s;46eg:oo8;46eh:oo3;46ei:oow;46ej:3c06;46ek:orn;46el")
  b.write(":d8h;46em:ouf;46en:ow2;46eo:oxx;46ep:d9w;46eq:3ciw;46er:3cjr;46es:dax;46et:3cnt;46eu:p6i;46ev:3cqm;46ew:p79;46ex:pa2;46e")
  b.write("y:pad;46ez:3d22;46f0:3d43;46f1:pcw;46f2:3d7s;46f3:pdc;46f4:33a7;46f5:ded;46f6:pf6;46f7:phf;46f8:dfv;46f9:pj2;46fa:hx1;46")
  b.write("fb:3dlz;46fc:3dmd;46fd:33bn;46fe:33bw;46ff:poh;46fg:pok;46fh:sda;46fi:dij;46fj:psh;46fk:psb;46fl:pst;46fm:gc3;46fn:ptd;4")
  b.write("6fo:ptf;46fp:ptp;46fq:puu;46fr:3ebg;46fs:put;46ft:pwd;46fu:pyb;46fv:q0d;46fw:pwj;46fx:q0t;46fy:q1z;46fz:q53;46g0:pxv;46g")
  b.write("1:q16;46g2:q18;46g3:q1o;46g4:3eie;46g5:3eqz;46g6:3emt;46g7:dnv;46g8:q9d;46g9:q9f;46ga:qae;46gb:3g0a;46gc:qck;46gd:3f3g;4")
  b.write("6ge:dp9;46gf:dpd;46gg:3f75;46gh:3ff6;46gi:dpn;46gj:qj4;46gk:qjg;46gl:qjr;46gm:qjt;46gn:qll;46go:qko;46gp:qoe;46gq:qn6;46")
  b.write("gr:qrd;46gs:qp4;46gt:qqz;46gu:qrq;46gv:dsn;46gw:qu9;46gx:qv5;46gy:dtl;46gz:qxs;46h0:qxv;46h1:3giv;46h2:r13;46h3:r1a;46h4")
  b.write(":dv9;46h5:r22;46h6:aez;46h7:3gz2;46h8:3h46;46h9:dz2;46ha:dzb;46hb:rds;46hc:rfx;46hd:rka;46he:rpx;46hf:3hrc;46hg:rsb;46hh")
  b.write(":rsx;46hi:rvf;46hj:rxz;46hk:3i9b;46hl:2upw;46hm:s0b;46hn:rzw;46ho:s1c;46hp:2uvy;46hq:s7o;46hr:sag;46hs:3jki;46ht:3jl9;46")
  b.write("hu:sk4;46hv:smp;46hw:snl;46hx:3ju6;46hy:snv;46hz:svs;46i0:t07;46i1:t08;46i2:sxo;46i3:t89;46i4:t91;46i5:3ksa;46i6:tjf;46i")
  b.write("7:ej9;46i8:tkn;46i9:3l2v;46ia:eli;46ib:ts3;46ic:iia;46id:tur;46ie:3ltx;46if:3lzu;46ig:epa;46ih:epi;46ii:u00;46ij:3mdm;46")
  b.write("ik:er6;46il:3mhi;46im:u17;46in:u17;46io:u21;46ip:3mpi;46iq:u76;46ir:eur;46is:u95;46it:ucn;46iu:ude;46iv:uf2;46iw:ez2;46i")
  b.write("x:3nsg;46iy:umq;46iz:uv4;46j0:v0d;46j1:f66;46j2:f71;46j3:v3b;46j4:3owe;46j5:f7c;46j6:3oxx;46j7:3p5a;46j8:3p8x;46j9:vcr;4")
  b.write("6ja:f9y;46jb:veh;46jc:vem;46jd:vet;46je:vf3;46jf:vfa;46jg:vgb;46jh:3pxc")
  return b.toString()

_uCompatRaw() -> String:
  b = StringBuffer()
  b.write("4g:w;4o:w,lk;4q:2p;4v:w,lg;4y:1e;4z:1f;50:w,ld;51:qk;54:w,mf;55:1d;56:33;58:1d,6dg,1g;59:1d,6dg,1e;5a:1f,6dg,1g;8i:21,22")
  b.write(";8j:2x,2y;8v:24,53;8w:30,53;95:jg,32;an:37;ck:1w,al;cl:1w,am;cm:2s,am;cn:24,22;co:24,2y;cp:30,2y;cq:26,22;cr:26,2y;cs:32")
  b.write(",2y;dt:1w,2i;du:1w,3e;dv:2s,3e;j4:2w;j5:h2;j6:2y;j7:36;j8:hl;j9:hn;ja:ht;jb:3b;jc:3d;k8:w,li;k9:w,lj;ka:w,lm;kb:w,mg;kc:")
  b.write("w,lf;kd:w,ln;kg:gz;kh:30;ki:37;kj:3c;kk:id;oq:w,n9;p0:w,ld;r4:qa;r5:qg;r6:px;r9:qu;ra:qo;s0:qi;s1:qp;s2:qq;s4:pk;s5:qd;s")
  b.write("9:pv;13b:12d,136;19x:17r,19w;19y:18o,19w;19z:1c7,19w;1a0:18q,19w;2sz:2tp,2sy;2wj:2x9,2wi;2xo:2wb,2vt;2xp:2wb,2w1;2z0:2yz")
  b.write(";31z:33m,329;321:33n,329;3cs:3bw;5rg:1t;5rh:5i;5ri:1u;5rk:1w;5rl:1x;5rm:b2;5rn:1z;5ro:20;5rp:21;5rq:22;5rr:23;5rs:24;5rt")
  b.write(":25;5ru:26;5rw:27;5rx:f6;5ry:28;5rz:2a;5s0:2c;5s1:2d;5s2:2f;5s3:2p;5s4:gg;5s5:gh;5s6:5qa;5s7:2q;5s8:2s;5s9:2t;5sa:gp;5sb")
  b.write(":gr;5sc:gs;5sd:2v;5sf:2z;5sg:31;5sh:97;5si:33;5sj:gk;5sk:5qu;5sl:5qv;5sm:34;5sn:38;5so:39;5sp:5r1;5sq:hb;5sr:3a;5ss:5r9;")
  b.write("5st:qa;5su:qb;5sv:qc;5sw:qu;5sx:qv;5sy:2x;5sz:36;5t0:39;5t1:3a;5t2:qa;5t3:qb;5t4:qp;5t5:qu;5t6:qv;5tk:u5;5uj:gi;5uk:2r;5")
  b.write("ul:gl;5um:6o;5un:gs;5uo:2u;5up:gv;5uq:gx;5ur:h1;5us:h4;5ut:h5;5uu:h6;5uv:5tn;5uw:il;5ux:h9;5uy:5tx;5uz:in;5v0:hd;5v1:hc;")
  b.write("5v2:he;5v3:hf;5v4:hg;5v5:hh;5v6:hk;5v7:hu;5v8:hv;5v9:bv;5va:i1;5vb:i2;5vc:5r0;5vd:i3;5ve:i4;5vf:3e;5vg:i8;5vh:i9;5vi:ia;")
  b.write("5vj:qg;61m:2p,ji;69p:w,lv;69r:w,lv;69s:w,n6;6bi:w,lw;6bm:w;6bn:w;6bo:w;6bp:w;6bq:w;6br:w;6bs:w;6bt:w;6bu:w;6c1:6c0;6c7:w")
  b.write(",mr;6ck:1a;6cl:1a,1a;6cm:1a,1a,1a;6cv:w;6cz:6cy,6cy;6d0:6cy,6cy,6cy;6d2:6d1,6d1;6d3:6d1,6d1,6d1;6d8:x,x;6da:w,lh;6dj:1r,")
  b.write("1r;6dk:1r,x;6dl:x,1r;6dz:6cy,6cy,6cy,6cy;6e7:w;6eo:1c;6ep:2x;6es:1g;6et:1h;6eu:1i;6ev:1j;6ew:1k;6ex:1l;6ey:17;6ez:6qa;6f")
  b.write("0:1p;6f1:14;6f2:15;6f3:32;6f4:1c;6f5:1d;6f6:1e;6f7:1f;6f8:1g;6f9:1h;6fa:1i;6fb:1j;6fc:1k;6fd:1l;6fe:17;6ff:6qa;6fg:1p;6f")
  b.write("h:14;6fi:15;6fk:2p;6fl:2t;6fm:33;6fn:3c;6fo:gp;6fp:2w;6fq:2z;6fr:30;6fs:31;6ft:32;6fu:34;6fv:37;6fw:38;6g8:2a,37;6io:2p,")
  b.write("1b,2r;6ip:2p,1b,37;6iq:1v;6ir:4w,1v;6it:2r,1b,33;6iu:2r,1b,39;6iv:b4;6ix:4w,1y;6iy:2v;6iz:20;6j0:20;6j1:20;6j2:2w;6j3:87")
  b.write(";6j4:21;6j5:21;6j6:24;6j7:30;6j9:26;6ja:26,33;6jd:28;6je:29;6jf:2a;6jg:2a;6jh:2a;6jk:2b,25;6jl:2c,1x,24;6jm:2c,25;6jo:2i")
  b.write(";6js:2i;6jw:1u;6jx:1v;6jz:2t;6k0:1x;6k1:1y;6k3:25;6k4:33;6k5:15c;6k6:15d;6k7:15e;6k8:15f;6k9:2x;6kb:1y,1t,2g;6kc:qo;6kd:")
  b.write("qb;6ke:pf;6kf:ps;6kg:6q9;6kl:1w;6km:2s;6kn:2t;6ko:2x;6kp:2y;6kw:1d,6dg,1j;6kx:1d,6dg,1l;6ky:1d,6dg,1d,1c;6kz:1d,6dg,1f;6")
  b.write("l0:1e,6dg,1f;6l1:1d,6dg,1h;6l2:1e,6dg,1h;6l3:1f,6dg,1h;6l4:1g,6dg,1h;6l5:1d,6dg,1i;6l6:1h,6dg,1i;6l7:1d,6dg,1k;6l8:1f,6d")
  b.write("g,1k;6l9:1h,6dg,1k;6la:1j,6dg,1k;6lb:1d,6dg;6lc:21;6ld:21,21;6le:21,21,21;6lf:21,2e;6lg:2e;6lh:2e,21;6li:2e,21,21;6lj:2e")
  b.write(",21,21,21;6lk:21,2g;6ll:2g;6lm:2g,21;6ln:2g,21,21;6lo:24;6lp:1v;6lq:1w;6lr:25;6ls:2x;6lt:2x,2x;6lu:2x,2x,2x;6lv:2x,3a;6l")
  b.write("w:3a;6lx:3a,2x;6ly:3a,2x,2x;6lz:3a,2x,2x,2x;6m0:2x,3c;6m1:3c;6m2:3c,2x;6m3:3c,2x,2x;6m4:30;6m5:2r;6m6:2s;6m7:31;6mh:1c,6")
  b.write("dg,1f;6r0:6qz,6qz;6r1:6qz,6qz,6qz;6r3:6r2,6r2;6r4:6r2,6r2,6r2;76o:1d;76p:1e;76q:1f;76r:1g;76s:1h;76t:1i;76u:1j;76v:1k;76")
  b.write("w:1l;76x:1d,1c;76y:1d,1d;76z:1d,1e;770:1d,1f;771:1d,1g;772:1d,1h;773:1d,1i;774:1d,1j;775:1d,1k;776:1d,1l;777:1e,1c;778:1")
  b.write("4,1d,15;779:14,1e,15;77a:14,1f,15;77b:14,1g,15;77c:14,1h,15;77d:14,1i,15;77e:14,1j,15;77f:14,1k,15;77g:14,1l,15;77h:14,1")
  b.write("d,1c,15;77i:14,1d,1d,15;77j:14,1d,1e,15;77k:14,1d,1f,15;77l:14,1d,1g,15;77m:14,1d,1h,15;77n:14,1d,1i,15;77o:14,1d,1j,15;")
  b.write("77p:14,1d,1k,15;77q:14,1d,1l,15;77r:14,1e,1c,15;77s:1d,1a;77t:1e,1a;77u:1f,1a;77v:1g,1a;77w:1h,1a;77x:1i,1a;77y:1j,1a;77")
  b.write("z:1k,1a;780:1l,1a;781:1d,1c,1a;782:1d,1d,1a;783:1d,1e,1a;784:1d,1f,1a;785:1d,1g,1a;786:1d,1h,1a;787:1d,1i,1a;788:1d,1j,1")
  b.write("a;789:1d,1k,1a;78a:1d,1l,1a;78b:1e,1c,1a;78c:14,2p,15;78d:14,2q,15;78e:14,2r,15;78f:14,2s,15;78g:14,2t,15;78h:14,2u,15;7")
  b.write("8i:14,2v,15;78j:14,2w,15;78k:14,2x,15;78l:14,2y,15;78m:14,2z,15;78n:14,30,15;78o:14,31,15;78p:14,32,15;78q:14,33,15;78r:")
  b.write("14,34,15;78s:14,35,15;78t:14,36,15;78u:14,37,15;78v:14,38,15;78w:14,39,15;78x:14,3a,15;78y:14,3b,15;78z:14,3c,15;790:14,")
  b.write("3d,15;791:14,3e,15;792:1t;793:1u;794:1v;795:1w;796:1x;797:1y;798:1z;799:20;79a:21;79b:22;79c:23;79d:24;79e:25;79f:26;79g")
  b.write(":27;79h:28;79i:29;79j:2a;79k:2b;79l:2c;79m:2d;79n:2e;79o:2f;79p:2g;79q:2h;79r:2i;79s:2p;79t:2q;79u:2r;79v:2s;79w:2t;79x:")
  b.write("2u;79y:2v;79z:2w;7a0:2x;7a1:2y;7a2:2z;7a3:30;7a4:31;7a5:32;7a6:33;7a7:34;7a8:35;7a9:36;7aa:37;7ab:38;7ac:39;7ad:3a;7ae:3")
  b.write("b;7af:3c;7ag:3d;7ah:3e;7ai:1c;8b0:6qz,6qz,6qz,6qz;8dw:1m,1m,1p;8dx:1p,1p;8dy:1p,1p,1p;8sc:2y;8sd:2e;8z3:8yp;97j:lal;99v:")
  b.write("vj3;9a8:feo;9a9:ffs;9aa:fg6;9ab:fgf;9ac:fh5;9ad:fid;9ae:fik;9af:fj4;9ag:fju;9ah:g1r;9ai:g2t;9aj:g2z;9ak:g3m;9al:g46;9am:")
  b.write("g4r;9an:g68;9ao:g6t;9ap:g74;9aq:gbf;9ar:ge1;9as:get;9at:gey;9au:gfs;9av:gg1;9aw:ggs;9ax:gh5;9ay:ghu;9az:gja;9b0:gjs;9b1:")
  b.write("gkj;9b2:h5j;9b3:h7j;9b4:hkb;9b5:hky;9b6:hl6;9b7:hlh;9b8:hlz;9b9:ho3;9ba:i1c;9bb:i2o;9bc:i60;9bd:i6n;9be:i76;9bf:i7s;9bg:")
  b.write("i9a;9bh:i9d;9bi:ijf;9bj:ijp;9bk:ik1;9bl:ike;9bm:inm;9bn:inu;9bo:inz;9bp:ir8;9bq:iri;9br:irv;9bs:is3;9bt:its;9bu:iu9;9bv:")
  b.write("iur;9bw:iwz;9bx:jd4;9by:jee;9bz:jez;9c0:jzj;9c1:jzo;9c2:k1z;9c3:k2f;9c4:k2s;9c5:k3d;9c6:k4g;9c7:k4l;9c8:kc0;9c9:kco;9ca:")
  b.write("kdk;9cb:l5s;9cc:l7m;9cd:l89;9ce:l9v;9cf:laj;9cg:las;9ch:laz;9ci:lcf;9cj:lck;9ck:ldg;9cl:m7f;9cm:mju;9cn:mk6;9co:mkb;9cp:")
  b.write("mkf;9cq:mkn;9cr:ml5;9cs:ml7;9ct:mng;9cu:mtg;9cv:mtl;9cw:n30;9cx:n3a;9cy:n4o;9cz:n4v;9d0:n54;9d1:n5c;9d2:n7v;9d3:n82;9d4:")
  b.write("nee;9d5:nel;9d6:nfy;9d7:ngf;9d8:nhq;9d9:nob;9da:noi;9db:noz;9dc:ny2;9dd:o1k;9de:o1q;9df:o6s;9dg:o97;9dh:oah;9di:okz;9dj:")
  b.write("ooo;9dk:p4m;9dl:p5d;9dm:p6y;9dn:p8d;9do:pa9;9dp:pak;9dq:paq;9dr:pbn;9ds:pdr;9dt:pe1;9du:pnn;9dv:pnu;9dw:po3;9dx:poc;9dy:")
  b.write("pos;9dz:pp7;9e0:ppb;9e1:pri;9e2:prm;9e3:prs;9e4:qj1;9e5:qjv;9e6:qww;9e7:qx8;9e8:qxv;9e9:r5q;9ea:r63;9eb:r82;9ec:r9c;9ed:")
  b.write("rp3;9ee:rpi;9ef:rpx;9eg:rqw;9eh:rrx;9ei:rxg;9ej:rxs;9ek:rzn;9el:s6j;9em:s7e;9en:sd7;9eo:sds;9ep:sdx;9eq:sk1;9er:sp5;9es:")
  b.write("ssm;9et:sss;9eu:ssx;9ev:tiv;9ew:tj4;9ex:tng;9ey:trq;9ez:trt;9f0:tt4;9f1:tw1;9f2:twe;9f3:twi;9f4:twp;9f5:tzf;9f6:u0d;9f7:")
  b.write("u0j;9f8:u0x;9f9:u5k;9fa:u6z;9fb:u73;9fc:uc6;9fd:uc9;9fe:ucs;9ff:ujs;9fg:ul4;9fh:ulb;9fi:un9;9fj:unj;9fk:unm;9fl:unw;9fm:")
  b.write("uoq;9fn:uzp;9fo:vat;9fp:vb3;9fq:vc5;9fr:vcr;9fs:vcz;9ft:vd9;9fu:vdd;9fv:veh;9fw:vel;9fx:vf2;9fy:vf7;9fz:vfk;9g0:vgb;9g1:")
  b.write("vgq;9g2:vgy;9g3:vil;9g4:vj0;9g5:vj4;9hc:w;9iu:9hu;9iw:gg1;9ix:gg4;9iy:gg5;9ln:w,9ll;9lo:w,9lm;9lr:9l4,9l6;9of:9mb,9mw;9p")
  b.write("t:3cw;9pu:3cx;9pv:3hm;9pw:3cy;9px:3ho;9py:3hp;9pz:3cz;9q0:3d0;9q1:3d1;9q2:3hs;9q3:3ht;9q4:3hu;9q5:3hv;9q6:3hw;9q7:3hx;9q")
  b.write("8:3dm;9q9:3d2;9qa:3d3;9qb:3d4;9qc:3dt;9qd:3d5;9qe:3d6;9qf:3d7;9qg:3d8;9qh:3d9;9qi:3da;9qj:3db;9qk:3dc;9ql:3dd;9qm:3de;9q")
  b.write("n:3fl;9qo:3fm;9qp:3fn;9qq:3fo;9qr:3fp;9qs:3fq;9qt:3fr;9qu:3fs;9qv:3ft;9qw:3fu;9qx:3fv;9qy:3fw;9qz:3fx;9r0:3fy;9r1:3fz;9r")
  b.write("2:3g0;9r3:3g1;9r4:3g2;9r5:3g3;9r6:3g4;9r7:3g5;9r8:3fk;9r9:3dg;9ra:3dh;9rb:3if;9rc:3ig;9rd:3ik;9re:3im;9rf:3ir;9rg:3iv;9r")
  b.write("h:3ix;9ri:3do;9rj:3j1;9rk:3j3;9rl:3dp;9rm:3dq;9rn:3ds;9ro:3du;9rp:3dv;9rq:3dz;9rr:3e1;9rs:3e3;9rt:3e4;9ru:3e5;9rv:3e6;9r")
  b.write("w:3e7;9rx:3ea;9ry:3ee;9rz:3eo;9s0:3ev;9s1:3f0;9s2:3jl;9s3:3jm;9s4:3fb;9s5:3fc;9s6:3fd;9s7:3gk;9s8:3gl;9s9:3go;9sa:3gx;9s")
  b.write("b:3gy;9sc:3h0;9sd:3ha;9se:3hd;9si:feo;9sj:fik;9sk:fex;9sl:h5n;9sm:fey;9sn:ffx;9so:fez;9sp:n5e;9sq:fh5;9sr:ffd;9ss:fep;9s")
  b.write("t:hm1;9su:h80;9sv:fju;9vk:14,3cw,15;9vl:14,3cy,15;9vm:14,3cz,15;9vn:14,3d1,15;9vo:14,3d2,15;9vp:14,3d3,15;9vq:14,3d5,15;")
  b.write("9vr:14,3d7,15;9vs:14,3d8,15;9vt:14,3da,15;9vu:14,3db,15;9vv:14,3dc,15;9vw:14,3dd,15;9vx:14,3de,15;9vy:14,3cw,3fl,15;9vz:")
  b.write("14,3cy,3fl,15;9w0:14,3cz,3fl,15;9w1:14,3d1,3fl,15;9w2:14,3d2,3fl,15;9w3:14,3d3,3fl,15;9w4:14,3d5,3fl,15;9w5:14,3d7,3fl,1")
  b.write("5;9w6:14,3d8,3fl,15;9w7:14,3da,3fl,15;9w8:14,3db,3fl,15;9w9:14,3dc,3fl,15;9wa:14,3dd,3fl,15;9wb:14,3de,3fl,15;9wc:14,3d8")
  b.write(",3fy,15;9wd:14,3d7,3ft,3d8,3fp,3hn,15;9we:14,3d7,3ft,3de,3fy,15;9wg:14,feo,15;9wh:14,fik,15;9wi:14,fex,15;9wj:14,h5n,15;")
  b.write("9wk:14,fis,15;9wl:14,g31,15;9wm:14,fer,15;9wn:14,g2z,15;9wo:14,fh9,15;9wp:14,gg1,15;9wq:14,kco,15;9wr:14,m7f,15;9ws:14,l")
  b.write("dg,15;9wt:14,kdk,15;9wu:14,ssx,15;9wv:14,h7j,15;9ww:14,k4l,15;9wx:14,kkq,15;9wy:14,kcp,15;9wz:14,ny6,15;9x0:14,glp,15;9x")
  b.write("1:14,mm1,15;9x2:14,rs1,15;9x3:14,nz1,15;9x4:14,gc4,15;9x5:14,fkz,15;9x6:14,gos,15;9x7:14,i1y,15;9x8:14,nhf,15;9x9:14,flt")
  b.write(",15;9xa:14,rt3,15;9xb:14,ggk,15;9xc:14,nzh,15;9xd:14,fm9,15;9xe:14,pnu,15;9xf:14,po3,15;9xg:gun;9xh:inw;9xi:k1z;9xj:oen;")
  b.write("9xs:28,2c,1x;9xt:1e,1d;9xu:1e,1e;9xv:1e,1f;9xw:1e,1g;9xx:1e,1h;9xy:1e,1i;9xz:1e,1j;9y0:1e,1k;9y1:1e,1l;9y2:1f,1c;9y3:1f,")
  b.write("1d;9y4:1f,1e;9y5:1f,1f;9y6:1f,1g;9y7:1f,1h;9y8:3cw;9y9:3cy;9ya:3cz;9yb:3d1;9yc:3d2;9yd:3d3;9ye:3d5;9yf:3d7;9yg:3d8;9yh:3")
  b.write("da;9yi:3db;9yj:3dc;9yk:3dd;9yl:3de;9ym:3cw,3fl;9yn:3cy,3fl;9yo:3cz,3fl;9yp:3d1,3fl;9yq:3d2,3fl;9yr:3d3,3fl;9ys:3d5,3fl;9")
  b.write("yt:3d7,3fl;9yu:3d8,3fl;9yv:3da,3fl;9yw:3db,3fl;9yx:3dc,3fl;9yy:3dd,3fl;9yz:3de,3fl;9z0:3da,3fl,3hz,3cw,3ft;9z1:3d8,3fy,3")
  b.write("d7,3g4;9z2:3d7,3fy;9z4:feo;9z5:fik;9z6:fex;9z7:h5n;9z8:fis;9z9:g31;9za:fer;9zb:g2z;9zc:fh9;9zd:gg1;9ze:kco;9zf:m7f;9zg:l")
  b.write("dg;9zh:kdk;9zi:ssx;9zj:h7j;9zk:k4l;9zl:kkq;9zm:kcp;9zn:ny6;9zo:glp;9zp:mm1;9zq:rs1;9zr:nz1;9zs:gc4;9zt:o2g;9zu:n5j;9zv:h")
  b.write("o3;9zw:six;9zx:g16;9zy:ghc;9zz:lig;a00:u11;a01:fm9;a02:g49;a03:l7n;a04:fey;a05:ffx;a06:fez;a07:ijq;a08:gkz;a09:gfv;a0a:i")
  b.write("3b;a0b:i1y;a0c:nhf;a0d:flt;a0e:rt3;a0f:ggk;a0g:hlo;a0h:1f,1i;a0i:1f,1j;a0j:1f,1k;a0k:1f,1l;a0l:1g,1c;a0m:1g,1d;a0n:1g,1e")
  b.write(";a0o:1g,1f;a0p:1g,1g;a0q:1g,1h;a0r:1g,1i;a0s:1g,1j;a0t:1g,1k;a0u:1g,1l;a0v:1h,1c;a0w:1d,kco;a0x:1e,kco;a0y:1f,kco;a0z:1g")
  b.write(",kco;a10:1h,kco;a11:1i,kco;a12:1j,kco;a13:1k,kco;a14:1l,kco;a15:1d,1c,kco;a16:1d,1d,kco;a17:1d,1e,kco;a18:20,2v;a19:2t,3")
  b.write("6,2v;a1a:2t,2e;a1b:24,2c,1w;a1c:9lu;a1d:9lw;a1e:9ly;a1f:9m0;a1g:9m2;a1h:9m3;a1i:9m5;a1j:9m7;a1k:9m9;a1l:9mb;a1m:9md;a1n:")
  b.write("9mf;a1o:9mh;a1p:9mj;a1q:9ml;a1r:9mn;a1s:9mp;a1t:9ms;a1u:9mu;a1v:9mw;a1w:9my;a1x:9mz;a1y:9n0;a1z:9n1;a20:9n2;a21:9n3;a22:")
  b.write("9n6;a23:9n9;a24:9nc;a25:9nf;a26:9ni;a27:9nj;a28:9nk;a29:9nl;a2a:9nm;a2b:9no;a2c:9nq;a2d:9ns;a2e:9nt;a2f:9nu;a2g:9nv;a2h:")
  b.write("9nw;a2i:9nx;a2j:9nz;a2k:9o0;a2l:9o1;a2m:9o2;a2n:fl0,gp8;a2o:9lu,9n5,9oc,9mw;a2p:9lu,9nv,9n9,9lt;a2q:9lu,9o3,9ne,9lu;a2r:")
  b.write("9lu,9oc,9nv;a2s:9lw,9mz,9o3,9m8;a2t:9lw,9o3,9mp;a2u:9ly,9m1,9o3;a2v:9m0,9mh,9m7,9oc,9mx;a2w:9m0,9oc,9m3,9oc;a2x:9m2,9o3,")
  b.write("9mh;a2y:9m2,9oc,9nk;a2z:9m3,9lw,9nu;a30:9m3,9nt,9mr,9mw;a31:9m3,9nx,9nu,9oc;a32:9m4,9nx,9o3;a33:9m4,9o3,9ni;a34:9m6,9m4;")
  b.write("a35:9m6,9mz,9oc;a36:9m5,9np,9nu,9oc;a37:9m6,9nv,9mo,9oc;a38:9m5,9nx;a39:9m5,9nx,9m8,9nt,9nk;a3a:9m5,9nx,9nl,9oc,9mw,9nv;")
  b.write("a3b:9m5,9nx,9nz,9mr,9mw;a3c:9m8,9nt,9nk;a3d:9m8,9nt,9nk,9mw,9o3;a3e:9m7,9nv,9mk,9lw,9nx;a3f:9m7,9nx,9oc,9n1;a3g:9m9,9oc,")
  b.write("9mh;a3h:9mb,9nv,9my;a3i:9mb,9oc,9nh;a3j:9md,9lw,9m7,9nv;a3k:9md,9o3,9mp,9oc,9nk;a3l:9mf,9nu,9o3,9m8;a3m:9mj,9o3,9mp;a3n:")
  b.write("9mj,9o3,9mw;a3o:9mo,9oc,9mh;a3p:9mv,9mf;a3q:9mx,9nv;a3r:9mw,9o3;a3s:9my,9n2;a3t:9n2,9mr,9mw;a3u:9n3,9lw,9ms;a3v:9n5,9oc,")
  b.write("9mj,9o3,9mw;a3w:9n5,9oc,9ms;a3x:9n4,9oc,9nw,9nv;a3y:9n8,9lu,9mh,9mw,9nv;a3z:9n8,9m7,9nv;a40:9n8,9mb;a41:9n7,9nv;a42:9n9,")
  b.write("9lt,9nt,9mr,9mx;a43:9n9,9lv,9oc,9mw;a44:9na,9mr,9mf,9lz,9nv;a45:9n9,9nt,9o3;a46:9nc,9m7,9mn,9oc,9nv;a47:9ne,9ml;a48:9ne,")
  b.write("9mz,9n6;a49:9nc,9nv,9ms;a4a:9ne,9o3,9mh;a4b:9ne,9oc,9mg;a4c:9nd,9oc,9mn;a4d:9nh,9lw,9o3,9mw;a4e:9ng,9nv,9mw;a4f:9nf,9o3;")
  b.write("a4g:9nh,9o3,9mx;a4h:9nf,9oc,9nv;a4i:9nf,9oc,9o3;a4j:9ni,9lw,9m7,9nx;a4k:9ni,9lw,9nv;a4l:9ni,9mr,9n3;a4m:9ni,9nv,9m7;a4n:")
  b.write("9ni,9o3,9mf,9nr,9o3;a4o:9nj,9m7,9nx,9o3;a4p:9nj,9nu;a4q:9nj,9nu,9n4,9oc,9nv;a4r:9nl,9m4;a4s:9nl,9m4,9mw,9o3;a4t:9nl,9oc,")
  b.write("9mw,9nv;a4u:9no,9oc,9mx;a4v:9no,9oc,9nv;a4w:9nq,9lu,9o3;a4x:9nu,9mr,9mw,9nv;a4y:9nu,9nt;a4z:9nv,9n8,9oc;a50:9nv,9oc,9na,")
  b.write("9nv;a51:9nw,9nk;a52:9nw,9o3,9mw,9ma,9o3;a53:9nz,9mr,9mw;a54:1c,m9l;a55:1d,m9l;a56:1e,m9l;a57:1f,m9l;a58:1g,m9l;a59:1h,m9")
  b.write("l;a5a:1i,m9l;a5b:1j,m9l;a5c:1k,m9l;a5d:1l,m9l;a5e:1d,1c,m9l;a5f:1d,1d,m9l;a5g:1d,1e,m9l;a5h:1d,1f,m9l;a5i:1d,1g,m9l;a5j:")
  b.write("1d,1h,m9l;a5k:1d,1i,m9l;a5l:1d,1j,m9l;a5m:1d,1k,m9l;a5n:1d,1l,m9l;a5o:1e,1c,m9l;a5p:1e,1d,m9l;a5q:1e,1e,m9l;a5r:1e,1f,m9")
  b.write("l;a5s:1e,1g,m9l;a5t:2w,28,2p;a5u:2s,2p;a5v:1t,2d;a5w:2q,2p,36;a5x:33,2e;a5y:34,2r;a5z:2s,31;a60:2s,31,4y;a61:2s,31,4z;a6")
  b.write("2:21,2d;a63:inn,jdc;a64:k6l,gp8;a65:hlz,l7n;a66:k5q,lh7;a67:kkq,irz,fmi,ny6;a68:34,1t;a69:32,1t;a6a:qk,1t;a6b:31,1t;a6c:")
  b.write("2z,1t;a6d:23,1u;a6e:25,1u;a6f:1z,1u;a6g:2r,2p,30;a6h:2z,2r,2p,30;a6i:34,1y;a6j:32,1y;a6k:qk,1y;a6l:qk,2v;a6m:31,2v;a6n:2")
  b.write("z,2v;a6o:20,3e;a6p:2z,20,3e;a6q:25,20,3e;a6r:1z,20,3e;a6s:2c,20,3e;a6t:qk,6j7;a6u:31,6j7;a6v:2s,6j7;a6w:2z,6j7;a6x:2u,31")
  b.write(";a6y:32,31;a6z:qk,31;a70:31,31;a71:2r,31;a72:2z,31;a73:31,31,4y;a74:2r,31,4y;a75:31,4y;a76:2z,31,4y;a77:31,31,4z;a78:2r,")
  b.write("31,4z;a79:31,4z;a7a:2z,31,4z;a7b:31,6qd,37;a7c:31,6qd,37,4y;a7d:28,2p;a7e:2z,28,2p;a7f:25,28,2p;a7g:1z,28,2p;a7h:36,2p,2")
  b.write("s;a7i:36,2p,2s,6qd,37;a7j:36,2p,2s,6qd,37,4y;a7k:34,37;a7l:32,37;a7m:qk,37;a7n:31,37;a7o:34,2e;a7p:32,2e;a7q:qk,2e;a7r:3")
  b.write("1,2e;a7s:2z,2e;a7t:25,2e;a7u:34,2f;a7v:32,2f;a7w:qk,2f;a7x:31,2f;a7y:2z,2f;a7z:25,2f;a80:2z,q1;a81:25,q1;a82:2p,1a,31,1a")
  b.write(";a83:1u,35;a84:2r,2r;a85:2r,2s;a86:1v,6qd,2z,2v;a87:1v,33,1a;a88:2s,1u;a89:1z,3d;a8a:2w,2p;a8b:20,28;a8c:2x,32;a8d:23,23")
  b.write(";a8e:23,25;a8f:2z,38;a8g:30,31;a8h:30,32;a8i:30,33,2v;a8j:30,3c;a8k:31,2q;a8l:31,2x,30;a8m:31,33,30;a8n:28,20;a8o:34,1a,")
  b.write("31,1a;a8p:28,28,25;a8q:28,2a;a8r:37,36;a8s:2b,3a;a8t:2f,2q;a8u:2e,6qd,31;a8v:1t,6qd,31;a8w:1d,k4l;a8x:1e,k4l;a8y:1f,k4l;")
  b.write("a8z:1g,k4l;a90:1h,k4l;a91:1i,k4l;a92:1j,k4l;a93:1k,k4l;a94:1l,k4l;a95:1d,1c,k4l;a96:1d,1d,k4l;a97:1d,1e,k4l;a98:1d,1f,k4")
  b.write("l;a99:1d,1g,k4l;a9a:1d,1h,k4l;a9b:1d,1i,k4l;a9c:1d,1j,k4l;a9d:1d,1k,k4l;a9e:1d,1l,k4l;a9f:1e,1c,k4l;a9g:1e,1d,k4l;a9h:1e")
  b.write(",1e,k4l;a9i:1e,1f,k4l;a9j:1e,1g,k4l;a9k:1e,1h,k4l;a9l:1e,1i,k4l;a9m:1e,1j,k4l;a9n:1e,1k,k4l;a9o:1e,1l,k4l;a9p:1f,1c,k4l;")
  b.write("a9q:1f,1d,k4l;a9r:2v,2p,30;wws:ui;wwt:uk;x2o:x2n;x6a:1v;x6b:1y;x6c:29;x6g:86;x6h:9f;xuk:x0n;xul:xtj;xum:h7;xun:xua;xux:i")
  b.write("5;1dkw:2u,2u;1dkx:2u,2x;1dky:2u,30;1dkz:2u,2u,2x;1dl0:2u,2u,30;1dl1:an,38;1dl2:37,38;1dlf:12s,12u;1dlg:12s,12d;1dlh:12s,")
  b.write("12j;1dli:132,12u;1dlj:12s,12l;1dls:15u;1dlt:15c;1dlu:15f;1dlv:15g;1dlw:15n;1dlx:15o;1dly:15p;1dlz:160;1dm0:162;1dm1:17;1")
  b.write("dn3:15c,15o;1dn4:19t;1dn5:19t;1dn6:1a3;1dn7:1a3;1dn8:1a3;1dn9:1a3;1dna:1a6;1dnb:1a6;1dnc:1a6;1dnd:1a6;1dne:1a8;1dnf:1a8;")
  b.write("1dng:1a8;1dnh:1a8;1dni:1a2;1dnj:1a2;1dnk:1a2;1dnl:1a2;1dnm:1a7;1dnn:1a7;1dno:1a7;1dnp:1a7;1dnq:1a1;1dnr:1a1;1dns:1a1;1dn")
  b.write("t:1a1;1dnu:1b8;1dnv:1b8;1dnw:1b8;1dnx:1b8;1dny:1ba;1dnz:1ba;1do0:1ba;1do1:1ba;1do2:1ac;1do3:1ac;1do4:1ac;1do5:1ac;1do6:1")
  b.write("ab;1do7:1ab;1do8:1ab;1do9:1ab;1doa:1ae;1dob:1ae;1doc:1ae;1dod:1ae;1doe:1af;1dof:1af;1dog:1af;1doh:1af;1doi:1al;1doj:1al;")
  b.write("1dok:1ak;1dol:1ak;1dom:1am;1don:1am;1doo:1ag;1dop:1ag;1doq:1aw;1dor:1aw;1dos:1ap;1dot:1ap;1dou:1bd;1dov:1bd;1dow:1bd;1do")
  b.write("x:1bd;1doy:1bj;1doz:1bj;1dp0:1bj;1dp1:1bj;1dp2:1bn;1dp3:1bn;1dp4:1bn;1dp5:1bn;1dp6:1bl;1dp7:1bl;1dp8:1bl;1dp9:1bl;1dpa:1")
  b.write("bu;1dpb:1bu;1dpc:1bv;1dpd:1bv;1dpe:1bv;1dpf:1bv;1dpg:1c0;1dph:1c0;1dpi:1c1;1dpj:1c1;1dpk:1c1;1dpl:1c1;1dpm:1by;1dpn:1by;")
  b.write("1dpo:1by;1dpp:1by;1dpq:1ci;1dpr:1ci;1dps:1cj;1dpt:1cj;1dqr:1bh;1dqs:1bh;1dqt:1bh;1dqu:1bh;1dqv:1c7;1dqw:1c7;1dqx:1c6;1dq")
  b.write("y:1c6;1dqz:1c8;1dr0:1c8;1dr1:19z;1dr2:1cb;1dr3:1cb;1dr4:1c5;1dr5:1c5;1dr6:1c9;1dr7:1c9;1dr8:1cg;1dr9:1cg;1dra:1cg;1drb:1")
  b.write("cg;1drc:18p;1drd:18p;1dre:17q,17r;1drf:17q,17r;1drg:17q,1cl;1drh:17q,1cl;1dri:17q,18o;1drj:17q,18o;1drk:17q,1c7;1drl:17q")
  b.write(",1c7;1drm:17q,1c6;1drn:17q,1c6;1dro:17q,1c8;1drp:17q,1c8;1drq:17q,1cg;1drr:17q,1cg;1drs:17q,1cg;1drt:17q,18p;1dru:17q,18")
  b.write("p;1drv:17q,18p;1drw:1cc;1drx:1cc;1dry:1cc;1drz:1cc;1ds0:17q,17w;1ds1:17q,17x;1ds2:17q,18l;1ds3:17q,18p;1ds4:17q,18q;1ds5")
  b.write(":17s,17w;1ds6:17s,17x;1ds7:17s,17y;1ds8:17s,18l;1ds9:17s,18p;1dsa:17s,18q;1dsb:17u,17w;1dsc:17u,17x;1dsd:17u,17y;1dse:17")
  b.write("u,18l;1dsf:17u,18p;1dsg:17u,18q;1dsh:17v,17w;1dsi:17v,18l;1dsj:17v,18p;1dsk:17v,18q;1dsl:17w,17x;1dsm:17w,18l;1dsn:17x,1")
  b.write("7w;1dso:17x,18l;1dsp:17y,17w;1dsq:17y,17x;1dsr:17y,18l;1dss:183,17w;1dst:183,17x;1dsu:183,17y;1dsv:183,18l;1dsw:185,17x;")
  b.write("1dsx:185,18l;1dsy:186,17w;1dsz:186,17x;1dt0:186,17y;1dt1:186,18l;1dt2:187,17x;1dt3:187,18l;1dt4:188,18l;1dt5:189,17w;1dt")
  b.write("6:189,18l;1dt7:18a,17w;1dt8:18a,18l;1dt9:18h,17w;1dta:18h,17x;1dtb:18h,17y;1dtc:18h,18l;1dtd:18h,18p;1dte:18h,18q;1dtf:1")
  b.write("8i,17x;1dtg:18i,18l;1dth:18i,18p;1dti:18i,18q;1dtj:18j,17r;1dtk:18j,17w;1dtl:18j,17x;1dtm:18j,17y;1dtn:18j,18k;1dto:18j,")
  b.write("18l;1dtp:18j,18p;1dtq:18j,18q;1dtr:18k,17w;1dts:18k,17x;1dtt:18k,17y;1dtu:18k,18l;1dtv:18k,18p;1dtw:18k,18q;1dtx:18l,17w")
  b.write(";1dty:18l,17x;1dtz:18l,17y;1du0:18l,18l;1du1:18l,18p;1du2:18l,18q;1du3:18m,17w;1du4:18m,17x;1du5:18m,17y;1du6:18m,18l;1d")
  b.write("u7:18m,18p;1du8:18m,18q;1du9:18n,17w;1dua:18n,18l;1dub:18n,18p;1duc:18n,18q;1dud:18q,17w;1due:18q,17x;1duf:18q,17y;1dug:")
  b.write("18q,18l;1duh:18q,18p;1dui:18q,18q;1duj:180,19s;1duk:181,19s;1dul:18p,19s;1dum:w,18s,18x;1dun:w,18t,18x;1duo:w,18u,18x;1d")
  b.write("up:w,18v,18x;1duq:w,18w,18x;1dur:w,18x,19s;1dus:17q,181;1dut:17q,182;1duu:17q,18l;1duv:17q,18m;1duw:17q,18p;1dux:17q,18q")
  b.write(";1duy:17s,181;1duz:17s,182;1dv0:17s,18l;1dv1:17s,18m;1dv2:17s,18p;1dv3:17s,18q;1dv4:17u,181;1dv5:17u,182;1dv6:17u,18l;1d")
  b.write("v7:17u,18m;1dv8:17u,18p;1dv9:17u,18q;1dva:17v,181;1dvb:17v,182;1dvc:17v,18l;1dvd:17v,18m;1dve:17v,18p;1dvf:17v,18q;1dvg:")
  b.write("18h,18p;1dvh:18h,18q;1dvi:18i,18p;1dvj:18i,18q;1dvk:18j,17r;1dvl:18j,18k;1dvm:18j,18l;1dvn:18j,18p;1dvo:18j,18q;1dvp:18k")
  b.write(",18l;1dvq:18k,18p;1dvr:18k,18q;1dvs:18l,17r;1dvt:18l,18l;1dvu:18m,181;1dvv:18m,182;1dvw:18m,18l;1dvx:18m,18m;1dvy:18m,18")
  b.write("p;1dvz:18m,18q;1dw0:18p,19s;1dw1:18q,181;1dw2:18q,182;1dw3:18q,18l;1dw4:18q,18m;1dw5:18q,18p;1dw6:18q,18q;1dw7:17q,17w;1")
  b.write("dw8:17q,17x;1dw9:17q,17y;1dwa:17q,18l;1dwb:17q,18n;1dwc:17s,17w;1dwd:17s,17x;1dwe:17s,17y;1dwf:17s,18l;1dwg:17s,18n;1dwh")
  b.write(":17u,17w;1dwi:17u,17x;1dwj:17u,17y;1dwk:17u,18l;1dwl:17u,18n;1dwm:17v,18l;1dwn:17w,17x;1dwo:17w,18l;1dwp:17x,17w;1dwq:17")
  b.write("x,18l;1dwr:17y,17w;1dws:17y,18l;1dwt:183,17w;1dwu:183,17x;1dwv:183,17y;1dww:183,18l;1dwx:185,17x;1dwy:185,17y;1dwz:185,1")
  b.write("8l;1dx0:186,17w;1dx1:186,17x;1dx2:186,17y;1dx3:186,18l;1dx4:187,17x;1dx5:188,18l;1dx6:189,17w;1dx7:189,18l;1dx8:18a,17w;")
  b.write("1dx9:18a,18l;1dxa:18h,17w;1dxb:18h,17x;1dxc:18h,17y;1dxd:18h,18l;1dxe:18i,17x;1dxf:18i,18l;1dxg:18j,17w;1dxh:18j,17x;1dx")
  b.write("i:18j,17y;1dxj:18j,18k;1dxk:18j,18l;1dxl:18k,17w;1dxm:18k,17x;1dxn:18k,17y;1dxo:18k,18l;1dxp:18k,18n;1dxq:18l,17w;1dxr:1")
  b.write("8l,17x;1dxs:18l,17y;1dxt:18l,18l;1dxu:18m,17w;1dxv:18m,17x;1dxw:18m,17y;1dxx:18m,18l;1dxy:18m,18n;1dxz:18n,17w;1dy0:18n,")
  b.write("18l;1dy1:18n,19s;1dy2:18q,17w;1dy3:18q,17x;1dy4:18q,17y;1dy5:18q,18l;1dy6:18q,18n;1dy7:17q,18l;1dy8:17q,18n;1dy9:17s,18l")
  b.write(";1dya:17s,18n;1dyb:17u,18l;1dyc:17u,18n;1dyd:17v,18l;1dye:17v,18n;1dyf:183,18l;1dyg:183,18n;1dyh:184,18l;1dyi:184,18n;1d")
  b.write("yj:18j,18k;1dyk:18j,18l;1dyl:18k,18l;1dym:18m,18l;1dyn:18m,18n;1dyo:18q,18l;1dyp:18q,18n;1dyq:18g,18u,18x;1dyr:18g,18v,1")
  b.write("8x;1dys:18g,18w,18x;1dyt:187,18p;1dyu:187,18q;1dyv:189,18p;1dyw:189,18q;1dyx:18a,18p;1dyy:18a,18q;1dyz:183,18p;1dz0:183,")
  b.write("18q;1dz1:184,18p;1dz2:184,18q;1dz3:17x,18p;1dz4:17x,18q;1dz5:17w,18p;1dz6:17w,18q;1dz7:17y,18p;1dz8:17y,18q;1dz9:185,18p")
  b.write(";1dza:185,18q;1dzb:186,18p;1dzc:186,18q;1dzd:184,17w;1dze:184,17x;1dzf:184,17y;1dzg:184,18l;1dzh:184,181;1dzi:183,181;1d")
  b.write("zj:185,181;1dzk:186,181;1dzl:187,18p;1dzm:187,18q;1dzn:189,18p;1dzo:189,18q;1dzp:18a,18p;1dzq:18a,18q;1dzr:183,18p;1dzs:")
  b.write("183,18q;1dzt:184,18p;1dzu:184,18q;1dzv:17x,18p;1dzw:17x,18q;1dzx:17w,18p;1dzy:17w,18q;1dzz:17y,18p;1e00:17y,18q;1e01:185")
  b.write(",18p;1e02:185,18q;1e03:186,18p;1e04:186,18q;1e05:184,17w;1e06:184,17x;1e07:184,17y;1e08:184,18l;1e09:184,181;1e0a:183,18")
  b.write("1;1e0b:185,181;1e0c:186,181;1e0d:184,17w;1e0e:184,17x;1e0f:184,17y;1e0g:184,18l;1e0h:183,18n;1e0i:184,18n;1e0j:187,18l;1")
  b.write("e0k:183,17w;1e0l:183,17x;1e0m:183,17y;1e0n:184,17w;1e0o:184,17x;1e0p:184,17y;1e0q:187,18l;1e0r:188,18l;1e0s:17r,18r;1e0t")
  b.write(":17r,18r;1e1c:17u,17w,18l;1e1d:17u,17x,17w;1e1e:17u,17x,17w;1e1f:17u,17x,18l;1e1g:17u,17y,18l;1e1h:17u,18l,17w;1e1i:17u,")
  b.write("18l,17x;1e1j:17u,18l,17y;1e1k:17w,18l,17x;1e1l:17w,18l,17x;1e1m:17x,18l,18q;1e1n:17x,18l,18p;1e1o:183,17x,17w;1e1p:183,1")
  b.write("7w,17x;1e1q:183,17w,18p;1e1r:183,18l,17x;1e1s:183,18l,17x;1e1t:183,18l,17w;1e1u:183,18l,18l;1e1v:183,18l,18l;1e1w:185,17")
  b.write("x,17x;1e1x:185,17x,17x;1e1y:185,18l,18l;1e1z:184,17x,18l;1e20:184,17x,18l;1e21:184,17w,18q;1e22:184,18l,17y;1e23:184,18l")
  b.write(",17y;1e24:184,18l,18l;1e25:184,18l,18l;1e26:186,17x,18p;1e27:186,17y,18l;1e28:186,17y,18l;1e29:187,18l,17x;1e2a:187,18l,")
  b.write("17x;1e2b:187,18l,18l;1e2c:187,18l,18q;1e2d:189,17w,18l;1e2e:189,18l,18l;1e2f:189,18l,18l;1e2g:189,18l,18p;1e2h:18a,18l,1")
  b.write("8l;1e2i:18a,18l,18q;1e2j:18a,18l,18p;1e2k:18h,17y,18l;1e2l:18h,17y,18l;1e2m:18i,18l,17x;1e2n:18i,18l,18l;1e2o:18k,17x,18")
  b.write("l;1e2p:18k,17x,18q;1e2q:18k,17x,18p;1e2r:18k,17w,17w;1e2s:18k,17w,17w;1e2t:18k,17y,18l;1e2u:18k,17y,18l;1e2v:18k,18l,17x")
  b.write(";1e2w:18k,18l,17x;1e2x:18l,17x,17w;1e2y:18l,17x,18l;1e2z:18l,17x,18q;1e30:18l,17w,17x;1e31:18l,17w,18l;1e32:18l,17y,17w;")
  b.write("1e33:18l,17y,18l;1e36:18l,17w,17y;1e37:18n,18l,17w;1e38:18n,18l,18l;1e39:18m,17x,18l;1e3a:18m,17x,18p;1e3b:18m,17w,18l;1")
  b.write("e3c:18m,17w,18l;1e3d:18m,17w,18p;1e3e:18m,18l,18q;1e3f:18m,18l,18p;1e3g:18q,18l,18l;1e3h:18q,18l,18l;1e3i:17s,17y,18q;1e")
  b.write("3j:17u,17w,18q;1e3k:17u,17w,18p;1e3l:17u,17y,18q;1e3m:17u,17y,18p;1e3n:17u,18l,18q;1e3o:17u,18l,18p;1e3p:17w,18l,18q;1e3")
  b.write("q:17w,17x,18p;1e3r:17w,18l,18p;1e3s:183,17y,18p;1e3t:185,17x,18q;1e3u:184,17x,18q;1e3v:186,17x,18q;1e3w:18k,17w,18q;1e3x")
  b.write(":18k,18l,18q;1e3y:18q,17x,18q;1e3z:18q,17w,18q;1e40:18q,18l,18q;1e41:18l,18l,18q;1e42:18i,18l,18q;1e43:18m,17x,18q;1e44:")
  b.write("18i,18l,17x;1e45:18k,17x,18l;1e46:189,18l,18q;1e47:18j,18l,18q;1e48:18m,17w,17x;1e49:18l,17y,18q;1e4a:18k,17w,18l;1e4b:1")
  b.write("8j,18l,18l;1e4c:18k,17w,18l;1e4d:18m,17w,17x;1e4e:17w,17x,18q;1e4f:17x,17w,18q;1e4g:18l,17w,18q;1e4h:18h,18l,18q;1e4i:17")
  b.write("s,17x,18q;1e4j:18j,18l,18l;1e4k:189,17w,18l;1e4l:185,18l,18l;1e4m:183,17y,18q;1e4n:18m,17w,18q;1e5s:185,18k,1ci;1e5t:18i")
  b.write(",18k,1ci;1e5u:17r,18k,18k,18n;1e5v:17r,18j,17s,181;1e5w:18l,17x,18l,17z;1e5x:185,18k,189,18l;1e5y:181,183,18o,18k;1e5z:1")
  b.write("89,18k,18q,18n;1e60:18o,183,18k,18l;1e61:185,18k,18p;1e62:185,18k,18p,w,17r,18k,18k,18n,w,189,18k,18q,18n,w,18o,183,18k,")
  b.write("18l;1e63:17w,18k,w,17w,18k,17r,18k,18n;1e64:181,1cc,17r,18k;1e6o:18;1e6p:9hd;1e6q:9he;1e6r:1m;1e6s:1n;1e6t:x;1e6u:1r;1e6")
  b.write("v:9hy;1e6w:9hz;1e6x:6cm;1e7k:6cl;1e7l:6c4;1e7m:6c3;1e7n:2n;1e7o:2n;1e7p:14;1e7q:15;1e7r:3f;1e7s:3h;1e7t:9hw;1e7u:9hx;1e7")
  b.write("v:9hs;1e7w:9ht;1e7x:9hm;1e7y:9hn;1e7z:9hk;1e80:9hl;1e81:9ho;1e82:9hp;1e83:9hq;1e84:9hr;1e87:2j;1e88:2l;1e89:6da;1e8a:6da")
  b.write(";1e8b:6da;1e8c:6da;1e8d:2n;1e8e:2n;1e8f:2n;1e8g:18;1e8h:9hd;1e8i:1a;1e8k:1n;1e8l:1m;1e8m:1r;1e8n:x;1e8o:6c4;1e8p:14;1e8q")
  b.write(":15;1e8r:3f;1e8s:3h;1e8t:9hw;1e8u:9hx;1e8v:z;1e8w:12;1e8x:16;1e8y:17;1e8z:19;1e90:1o;1e91:1q;1e92:1p;1e94:2k;1e95:10;1e9")
  b.write("6:11;1e97:1s;1e9c:w,18r;1e9d:18g,18r;1e9e:w,18s;1e9g:w,18t;1e9i:w,18u;1e9j:18g,18u;1e9k:w,18v;1e9l:18g,18v;1e9m:w,18w;1e")
  b.write("9n:18g,18w;1e9o:w,18x;1e9p:18g,18x;1e9q:w,18y;1e9r:18g,18y;1e9s:17l;1e9t:17m;1e9u:17m;1e9v:17n;1e9w:17n;1e9x:17o;1e9y:17")
  b.write("o;1e9z:17p;1ea0:17p;1ea1:17q;1ea2:17q;1ea3:17q;1ea4:17q;1ea5:17r;1ea6:17r;1ea7:17s;1ea8:17s;1ea9:17s;1eaa:17s;1eab:17t;1")
  b.write("eac:17t;1ead:17u;1eae:17u;1eaf:17u;1eag:17u;1eah:17v;1eai:17v;1eaj:17v;1eak:17v;1eal:17w;1eam:17w;1ean:17w;1eao:17w;1eap")
  b.write(":17x;1eaq:17x;1ear:17x;1eas:17x;1eat:17y;1eau:17y;1eav:17y;1eaw:17y;1eax:17z;1eay:17z;1eaz:180;1eb0:180;1eb1:181;1eb2:18")
  b.write("1;1eb3:182;1eb4:182;1eb5:183;1eb6:183;1eb7:183;1eb8:183;1eb9:184;1eba:184;1ebb:184;1ebc:184;1ebd:185;1ebe:185;1ebf:185;1")
  b.write("ebg:185;1ebh:186;1ebi:186;1ebj:186;1ebk:186;1ebl:187;1ebm:187;1ebn:187;1ebo:187;1ebp:188;1ebq:188;1ebr:188;1ebs:188;1ebt")
  b.write(":189;1ebu:189;1ebv:189;1ebw:189;1ebx:18a;1eby:18a;1ebz:18a;1ec0:18a;1ec1:18h;1ec2:18h;1ec3:18h;1ec4:18h;1ec5:18i;1ec6:18")
  b.write("i;1ec7:18i;1ec8:18i;1ec9:18j;1eca:18j;1ecb:18j;1ecc:18j;1ecd:18k;1ece:18k;1ecf:18k;1ecg:18k;1ech:18l;1eci:18l;1ecj:18l;1")
  b.write("eck:18l;1ecl:18m;1ecm:18m;1ecn:18m;1eco:18m;1ecp:18n;1ecq:18n;1ecr:18n;1ecs:18n;1ect:18o;1ecu:18o;1ecv:18p;1ecw:18p;1ecx")
  b.write(":18q;1ecy:18q;1ecz:18q;1ed0:18q;1ed1:18k,17m;1ed2:18k,17m;1ed3:18k,17n;1ed4:18k,17n;1ed5:18k,17p;1ed6:18k,17p;1ed7:18k,1")
  b.write("7r;1ed8:18k,17r;1edd:x;1ede:y;1edf:z;1edg:10;1edh:11;1edi:12;1edj:13;1edk:14;1edl:15;1edm:16;1edn:17;1edo:18;1edp:19;1ed")
  b.write("q:1a;1edr:1b;1eds:1c;1edt:1d;1edu:1e;1edv:1f;1edw:1g;1edx:1h;1edy:1i;1edz:1j;1ee0:1k;1ee1:1l;1ee2:1m;1ee3:1n;1ee4:1o;1ee")
  b.write("5:1p;1ee6:1q;1ee7:1r;1ee8:1s;1ee9:1t;1eea:1u;1eeb:1v;1eec:1w;1eed:1x;1eee:1y;1eef:1z;1eeg:20;1eeh:21;1eei:22;1eej:23;1ee")
  b.write("k:24;1eel:25;1eem:26;1een:27;1eeo:28;1eep:29;1eeq:2a;1eer:2b;1ees:2c;1eet:2d;1eeu:2e;1eev:2f;1eew:2g;1eex:2h;1eey:2i;1ee")
  b.write("z:2j;1ef0:2k;1ef1:2l;1ef2:2m;1ef3:2n;1ef4:2o;1ef5:2p;1ef6:2q;1ef7:2r;1ef8:2s;1ef9:2t;1efa:2u;1efb:2v;1efc:2w;1efd:2x;1ef")
  b.write("e:2y;1eff:2z;1efg:30;1efh:31;1efi:32;1efj:33;1efk:34;1efl:35;1efm:36;1efn:37;1efo:38;1efp:39;1efq:3a;1efr:3b;1efs:3c;1ef")
  b.write("t:3d;1efu:3e;1efv:3f;1efw:3g;1efx:3h;1efy:3i;1efz:879;1eg0:87a;1eg1:9he;1eg2:9ho;1eg3:9hp;1eg4:9hd;1eg5:9ob;1eg6:9o2;1eg")
  b.write("7:9lt;1eg8:9lv;1eg9:9lx;1ega:9lz;1egb:9m1;1egc:9nn;1egd:9np;1ege:9nr;1egf:9mr;1egg:9oc;1egh:9lu;1egi:9lw;1egj:9ly;1egk:9")
  b.write("m0;1egl:9m2;1egm:9m3;1egn:9m5;1ego:9m7;1egp:9m9;1egq:9mb;1egr:9md;1egs:9mf;1egt:9mh;1egu:9mj;1egv:9ml;1egw:9mn;1egx:9mp;")
  b.write("1egy:9ms;1egz:9mu;1eh0:9mw;1eh1:9my;1eh2:9mz;1eh3:9n0;1eh4:9n1;1eh5:9n2;1eh6:9n3;1eh7:9n6;1eh8:9n9;1eh9:9nc;1eha:9nf;1eh")
  b.write("b:9ni;1ehc:9nj;1ehd:9nk;1ehe:9nl;1ehf:9nm;1ehg:9no;1ehh:9nq;1ehi:9ns;1ehj:9nt;1ehk:9nu;1ehl:9nv;1ehm:9nw;1ehn:9nx;1eho:9")
  b.write("nz;1ehp:9o3;1ehq:9ll;1ehr:9lm;1ehs:9r8;1eht:9pt;1ehu:9pu;1ehv:9pv;1ehw:9pw;1ehx:9px;1ehy:9py;1ehz:9pz;1ei0:9q0;1ei1:9q1;")
  b.write("1ei2:9q2;1ei3:9q3;1ei4:9q4;1ei5:9q5;1ei6:9q6;1ei7:9q7;1ei8:9q8;1ei9:9q9;1eia:9qa;1eib:9qb;1eic:9qc;1eid:9qd;1eie:9qe;1ei")
  b.write("f:9qf;1eig:9qg;1eih:9qh;1eii:9qi;1eij:9qj;1eik:9qk;1eil:9ql;1eim:9qm;1eiq:9qn;1eir:9qo;1eis:9qp;1eit:9qq;1eiu:9qr;1eiv:9")
  b.write("qs;1eiy:9qt;1eiz:9qu;1ej0:9qv;1ej1:9qw;1ej2:9qx;1ej3:9qy;1ej6:9qz;1ej7:9r0;1ej8:9r1;1ej9:9r2;1eja:9r3;1ejb:9r4;1eje:9r5;")
  b.write("1ejf:9r6;1ejg:9r7;1ejk:4i;1ejl:4j;1ejm:4s;1ejn:4v;1ejo:4m;1ejp:4l;1ejq:6g9;1ejs:7b6;1ejt:6mo;1eju:6mp;1ejv:6mq;1ejw:6mr;")
  b.write("1ejx:7fk;1ejy:7gr;1g1t:k0;1g1u:k1;1g1v:6e;1g1w:ih;1g1x:gj;1g1z:ir;1g20:xuu;1g21:it;1g22:is;1g23:gm;1g24:gn;1g25:5u9;1g26")
  b.write(":go;1g27:gu;1g28:ix;1g29:h0;1g2a:gy;1g2b:gw;1g2c:ij;1g2d:87;1g2e:ik;1g2f:h3;1g2g:hw;1g2h:iy;1g2i:iz;1g2j:h8;1g2k:2mmc;1g")
  b.write("2l:x3i;1g2m:ha;1g2n:2mmd;1g2o:i6;1g2p:2mme;1g2q:6w;1g2r:hi;1g2s:hj;1g2t:35;1g2u:hm;1g2v:2mmg;1g2w:hp;1g2x:hq;1g2y:hs;1g2")
  b.write("z:iw;1g30:iu;1g31:xuv;1g32:iv;1g33:i0;1g34:8s1;1g36:i7;1g37:ip;1g38:iq;1g39:ig;1g3a:cg;1g3b:ch;1g3c:ci;1g3d:2mmi;1g3e:2m")
  b.write("n2;2kg0:1t;2kg1:1u;2kg2:1v;2kg3:1w;2kg4:1x;2kg5:1y;2kg6:1z;2kg7:20;2kg8:21;2kg9:22;2kga:23;2kgb:24;2kgc:25;2kgd:26;2kge:")
  b.write("27;2kgf:28;2kgg:29;2kgh:2a;2kgi:2b;2kgj:2c;2kgk:2d;2kgl:2e;2kgm:2f;2kgn:2g;2kgo:2h;2kgp:2i;2kgq:2p;2kgr:2q;2kgs:2r;2kgt:")
  b.write("2s;2kgu:2t;2kgv:2u;2kgw:2v;2kgx:2w;2kgy:2x;2kgz:2y;2kh0:2z;2kh1:30;2kh2:31;2kh3:32;2kh4:33;2kh5:34;2kh6:35;2kh7:36;2kh8:")
  b.write("37;2kh9:38;2kha:39;2khb:3a;2khc:3b;2khd:3c;2khe:3d;2khf:3e;2khg:1t;2khh:1u;2khi:1v;2khj:1w;2khk:1x;2khl:1y;2khm:1z;2khn:")
  b.write("20;2kho:21;2khp:22;2khq:23;2khr:24;2khs:25;2kht:26;2khu:27;2khv:28;2khw:29;2khx:2a;2khy:2b;2khz:2c;2ki0:2d;2ki1:2e;2ki2:")
  b.write("2f;2ki3:2g;2ki4:2h;2ki5:2i;2ki6:2p;2ki7:2q;2ki8:2r;2ki9:2s;2kia:2t;2kib:2u;2kic:2v;2kie:2x;2kif:2y;2kig:2z;2kih:30;2kii:")
  b.write("31;2kij:32;2kik:33;2kil:34;2kim:35;2kin:36;2kio:37;2kip:38;2kiq:39;2kir:3a;2kis:3b;2kit:3c;2kiu:3d;2kiv:3e;2kiw:1t;2kix:")
  b.write("1u;2kiy:1v;2kiz:1w;2kj0:1x;2kj1:1y;2kj2:1z;2kj3:20;2kj4:21;2kj5:22;2kj6:23;2kj7:24;2kj8:25;2kj9:26;2kja:27;2kjb:28;2kjc:")
  b.write("29;2kjd:2a;2kje:2b;2kjf:2c;2kjg:2d;2kjh:2e;2kji:2f;2kjj:2g;2kjk:2h;2kjl:2i;2kjm:2p;2kjn:2q;2kjo:2r;2kjp:2s;2kjq:2t;2kjr:")
  b.write("2u;2kjs:2v;2kjt:2w;2kju:2x;2kjv:2y;2kjw:2z;2kjx:30;2kjy:31;2kjz:32;2kk0:33;2kk1:34;2kk2:35;2kk3:36;2kk4:37;2kk5:38;2kk6:")
  b.write("39;2kk7:3a;2kk8:3b;2kk9:3c;2kka:3d;2kkb:3e;2kkc:1t;2kke:1v;2kkf:1w;2kki:1z;2kkl:22;2kkm:23;2kkp:26;2kkq:27;2kkr:28;2kks:")
  b.write("29;2kku:2b;2kkv:2c;2kkw:2d;2kkx:2e;2kky:2f;2kkz:2g;2kl0:2h;2kl1:2i;2kl2:2p;2kl3:2q;2kl4:2r;2kl5:2s;2kl7:2u;2kl9:2w;2kla:")
  b.write("2x;2klb:2y;2klc:2z;2kld:30;2kle:31;2klf:32;2klh:34;2kli:35;2klj:36;2klk:37;2kll:38;2klm:39;2kln:3a;2klo:3b;2klp:3c;2klq:")
  b.write("3d;2klr:3e;2kls:1t;2klt:1u;2klu:1v;2klv:1w;2klw:1x;2klx:1y;2kly:1z;2klz:20;2km0:21;2km1:22;2km2:23;2km3:24;2km4:25;2km5:")
  b.write("26;2km6:27;2km7:28;2km8:29;2km9:2a;2kma:2b;2kmb:2c;2kmc:2d;2kmd:2e;2kme:2f;2kmf:2g;2kmg:2h;2kmh:2i;2kmi:2p;2kmj:2q;2kmk:")
  b.write("2r;2kml:2s;2kmm:2t;2kmn:2u;2kmo:2v;2kmp:2w;2kmq:2x;2kmr:2y;2kms:2z;2kmt:30;2kmu:31;2kmv:32;2kmw:33;2kmx:34;2kmy:35;2kmz:")
  b.write("36;2kn0:37;2kn1:38;2kn2:39;2kn3:3a;2kn4:3b;2kn5:3c;2kn6:3d;2kn7:3e;2kn8:1t;2kn9:1u;2knb:1w;2knc:1x;2knd:1y;2kne:1z;2knh:")
  b.write("22;2kni:23;2knj:24;2knk:25;2knl:26;2knm:27;2knn:28;2kno:29;2knq:2b;2knr:2c;2kns:2d;2knt:2e;2knu:2f;2knv:2g;2knw:2h;2kny:")
  b.write("2p;2knz:2q;2ko0:2r;2ko1:2s;2ko2:2t;2ko3:2u;2ko4:2v;2ko5:2w;2ko6:2x;2ko7:2y;2ko8:2z;2ko9:30;2koa:31;2kob:32;2koc:33;2kod:")
  b.write("34;2koe:35;2kof:36;2kog:37;2koh:38;2koi:39;2koj:3a;2kok:3b;2kol:3c;2kom:3d;2kon:3e;2koo:1t;2kop:1u;2kor:1w;2kos:1x;2kot:")
  b.write("1y;2kou:1z;2kow:21;2kox:22;2koy:23;2koz:24;2kp0:25;2kp2:27;2kp6:2b;2kp7:2c;2kp8:2d;2kp9:2e;2kpa:2f;2kpb:2g;2kpc:2h;2kpe:")
  b.write("2p;2kpf:2q;2kpg:2r;2kph:2s;2kpi:2t;2kpj:2u;2kpk:2v;2kpl:2w;2kpm:2x;2kpn:2y;2kpo:2z;2kpp:30;2kpq:31;2kpr:32;2kps:33;2kpt:")
  b.write("34;2kpu:35;2kpv:36;2kpw:37;2kpx:38;2kpy:39;2kpz:3a;2kq0:3b;2kq1:3c;2kq2:3d;2kq3:3e;2kq4:1t;2kq5:1u;2kq6:1v;2kq7:1w;2kq8:")
  b.write("1x;2kq9:1y;2kqa:1z;2kqb:20;2kqc:21;2kqd:22;2kqe:23;2kqf:24;2kqg:25;2kqh:26;2kqi:27;2kqj:28;2kqk:29;2kql:2a;2kqm:2b;2kqn:")
  b.write("2c;2kqo:2d;2kqp:2e;2kqq:2f;2kqr:2g;2kqs:2h;2kqt:2i;2kqu:2p;2kqv:2q;2kqw:2r;2kqx:2s;2kqy:2t;2kqz:2u;2kr0:2v;2kr1:2w;2kr2:")
  b.write("2x;2kr3:2y;2kr4:2z;2kr5:30;2kr6:31;2kr7:32;2kr8:33;2kr9:34;2kra:35;2krb:36;2krc:37;2krd:38;2kre:39;2krf:3a;2krg:3b;2krh:")
  b.write("3c;2kri:3d;2krj:3e;2krk:1t;2krl:1u;2krm:1v;2krn:1w;2kro:1x;2krp:1y;2krq:1z;2krr:20;2krs:21;2krt:22;2kru:23;2krv:24;2krw:")
  b.write("25;2krx:26;2kry:27;2krz:28;2ks0:29;2ks1:2a;2ks2:2b;2ks3:2c;2ks4:2d;2ks5:2e;2ks6:2f;2ks7:2g;2ks8:2h;2ks9:2i;2ksa:2p;2ksb:")
  b.write("2q;2ksc:2r;2ksd:2s;2kse:2t;2ksf:2u;2ksg:2v;2ksh:2w;2ksi:2x;2ksj:2y;2ksk:2z;2ksl:30;2ksm:31;2ksn:32;2kso:33;2ksp:34;2ksq:")
  b.write("35;2ksr:36;2kss:37;2kst:38;2ksu:39;2ksv:3a;2ksw:3b;2ksx:3c;2ksy:3d;2ksz:3e;2kt0:1t;2kt1:1u;2kt2:1v;2kt3:1w;2kt4:1x;2kt5:")
  b.write("1y;2kt6:1z;2kt7:20;2kt8:21;2kt9:22;2kta:23;2ktb:24;2ktc:25;2ktd:26;2kte:27;2ktf:28;2ktg:29;2kth:2a;2kti:2b;2ktj:2c;2ktk:")
  b.write("2d;2ktl:2e;2ktm:2f;2ktn:2g;2kto:2h;2ktp:2i;2ktq:2p;2ktr:2q;2kts:2r;2ktt:2s;2ktu:2t;2ktv:2u;2ktw:2v;2ktx:2w;2kty:2x;2ktz:")
  b.write("2y;2ku0:2z;2ku1:30;2ku2:31;2ku3:32;2ku4:33;2ku5:34;2ku6:35;2ku7:36;2ku8:37;2ku9:38;2kua:39;2kub:3a;2kuc:3b;2kud:3c;2kue:")
  b.write("3d;2kuf:3e;2kug:1t;2kuh:1u;2kui:1v;2kuj:1w;2kuk:1x;2kul:1y;2kum:1z;2kun:20;2kuo:21;2kup:22;2kuq:23;2kur:24;2kus:25;2kut:")
  b.write("26;2kuu:27;2kuv:28;2kuw:29;2kux:2a;2kuy:2b;2kuz:2c;2kv0:2d;2kv1:2e;2kv2:2f;2kv3:2g;2kv4:2h;2kv5:2i;2kv6:2p;2kv7:2q;2kv8:")
  b.write("2r;2kv9:2s;2kva:2t;2kvb:2u;2kvc:2v;2kvd:2w;2kve:2x;2kvf:2y;2kvg:2z;2kvh:30;2kvi:31;2kvj:32;2kvk:33;2kvl:34;2kvm:35;2kvn:")
  b.write("36;2kvo:37;2kvp:38;2kvq:39;2kvr:3a;2kvs:3b;2kvt:3c;2kvu:3d;2kvv:3e;2kvw:1t;2kvx:1u;2kvy:1v;2kvz:1w;2kw0:1x;2kw1:1y;2kw2:")
  b.write("1z;2kw3:20;2kw4:21;2kw5:22;2kw6:23;2kw7:24;2kw8:25;2kw9:26;2kwa:27;2kwb:28;2kwc:29;2kwd:2a;2kwe:2b;2kwf:2c;2kwg:2d;2kwh:")
  b.write("2e;2kwi:2f;2kwj:2g;2kwk:2h;2kwl:2i;2kwm:2p;2kwn:2q;2kwo:2r;2kwp:2s;2kwq:2t;2kwr:2u;2kws:2v;2kwt:2w;2kwu:2x;2kwv:2y;2kww:")
  b.write("2z;2kwx:30;2kwy:31;2kwz:32;2kx0:33;2kx1:34;2kx2:35;2kx3:36;2kx4:37;2kx5:38;2kx6:39;2kx7:3a;2kx8:3b;2kx9:3c;2kxa:3d;2kxb:")
  b.write("3e;2kxc:1t;2kxd:1u;2kxe:1v;2kxf:1w;2kxg:1x;2kxh:1y;2kxi:1z;2kxj:20;2kxk:21;2kxl:22;2kxm:23;2kxn:24;2kxo:25;2kxp:26;2kxq:")
  b.write("27;2kxr:28;2kxs:29;2kxt:2a;2kxu:2b;2kxv:2c;2kxw:2d;2kxx:2e;2kxy:2f;2kxz:2g;2ky0:2h;2ky1:2i;2ky2:2p;2ky3:2q;2ky4:2r;2ky5:")
  b.write("2s;2ky6:2t;2ky7:2u;2ky8:2v;2ky9:2w;2kya:2x;2kyb:2y;2kyc:2z;2kyd:30;2kye:31;2kyf:32;2kyg:33;2kyh:34;2kyi:35;2kyj:36;2kyk:")
  b.write("37;2kyl:38;2kym:39;2kyn:3a;2kyo:3b;2kyp:3c;2kyq:3d;2kyr:3e;2kys:8h;2kyt:fr;2kyw:pd;2kyx:pe;2kyy:pf;2kyz:pg;2kz0:ph;2kz1:")
  b.write("pi;2kz2:pj;2kz3:pk;2kz4:pl;2kz5:pm;2kz6:pn;2kz7:po;2kz8:pp;2kz9:pq;2kza:pr;2kzb:ps;2kzc:pt;2kzd:s4;2kze:pv;2kzf:pw;2kzg:")
  b.write("px;2kzh:py;2kzi:pz;2kzj:q0;2kzk:q1;2kzl:6pz;2kzm:q9;2kzn:qa;2kzo:qb;2kzp:qc;2kzq:qd;2kzr:qe;2kzs:qf;2kzt:qg;2kzu:qh;2kzv")
  b.write(":qi;2kzw:qj;2kzx:qk;2kzy:ql;2kzz:qm;2l00:qn;2l01:qo;2l02:qp;2l03:qq;2l04:qr;2l05:qs;2l06:qt;2l07:qu;2l08:qv;2l09:qw;2l0a")
  b.write(":qx;2l0b:6pu;2l0c:s5;2l0d:r5;2l0e:s0;2l0f:r9;2l0g:s1;2l0h:ra;2l0i:pd;2l0j:pe;2l0k:pf;2l0l:pg;2l0m:ph;2l0n:pi;2l0o:pj;2l0")
  b.write("p:pk;2l0q:pl;2l0r:pm;2l0s:pn;2l0t:po;2l0u:pp;2l0v:pq;2l0w:pr;2l0x:ps;2l0y:pt;2l0z:s4;2l10:pv;2l11:pw;2l12:px;2l13:py;2l1")
  b.write("4:pz;2l15:q0;2l16:q1;2l17:6pz;2l18:q9;2l19:qa;2l1a:qb;2l1b:qc;2l1c:qd;2l1d:qe;2l1e:qf;2l1f:qg;2l1g:qh;2l1h:qi;2l1i:qj;2l")
  b.write("1j:qk;2l1k:ql;2l1l:qm;2l1m:qn;2l1n:qo;2l1o:qp;2l1p:qq;2l1q:qr;2l1r:qs;2l1s:qt;2l1t:qu;2l1u:qv;2l1v:qw;2l1w:qx;2l1x:6pu;2")
  b.write("l1y:s5;2l1z:r5;2l20:s0;2l21:r9;2l22:s1;2l23:ra;2l24:pd;2l25:pe;2l26:pf;2l27:pg;2l28:ph;2l29:pi;2l2a:pj;2l2b:pk;2l2c:pl;2")
  b.write("l2d:pm;2l2e:pn;2l2f:po;2l2g:pp;2l2h:pq;2l2i:pr;2l2j:ps;2l2k:pt;2l2l:s4;2l2m:pv;2l2n:pw;2l2o:px;2l2p:py;2l2q:pz;2l2r:q0;2")
  b.write("l2s:q1;2l2t:6pz;2l2u:q9;2l2v:qa;2l2w:qb;2l2x:qc;2l2y:qd;2l2z:qe;2l30:qf;2l31:qg;2l32:qh;2l33:qi;2l34:qj;2l35:qk;2l36:ql;")
  b.write("2l37:qm;2l38:qn;2l39:qo;2l3a:qp;2l3b:qq;2l3c:qr;2l3d:qs;2l3e:qt;2l3f:qu;2l3g:qv;2l3h:qw;2l3i:qx;2l3j:6pu;2l3k:s5;2l3l:r5")
  b.write(";2l3m:s0;2l3n:r9;2l3o:s1;2l3p:ra;2l3q:pd;2l3r:pe;2l3s:pf;2l3t:pg;2l3u:ph;2l3v:pi;2l3w:pj;2l3x:pk;2l3y:pl;2l3z:pm;2l40:pn")
  b.write(";2l41:po;2l42:pp;2l43:pq;2l44:pr;2l45:ps;2l46:pt;2l47:s4;2l48:pv;2l49:pw;2l4a:px;2l4b:py;2l4c:pz;2l4d:q0;2l4e:q1;2l4f:6p")
  b.write("z;2l4g:q9;2l4h:qa;2l4i:qb;2l4j:qc;2l4k:qd;2l4l:qe;2l4m:qf;2l4n:qg;2l4o:qh;2l4p:qi;2l4q:qj;2l4r:qk;2l4s:ql;2l4t:qm;2l4u:q")
  b.write("n;2l4v:qo;2l4w:qp;2l4x:qq;2l4y:qr;2l4z:qs;2l50:qt;2l51:qu;2l52:qv;2l53:qw;2l54:qx;2l55:6pu;2l56:s5;2l57:r5;2l58:s0;2l59:")
  b.write("r9;2l5a:s1;2l5b:ra;2l5c:pd;2l5d:pe;2l5e:pf;2l5f:pg;2l5g:ph;2l5h:pi;2l5i:pj;2l5j:pk;2l5k:pl;2l5l:pm;2l5m:pn;2l5n:po;2l5o:")
  b.write("pp;2l5p:pq;2l5q:pr;2l5r:ps;2l5s:pt;2l5t:s4;2l5u:pv;2l5v:pw;2l5w:px;2l5x:py;2l5y:pz;2l5z:q0;2l60:q1;2l61:6pz;2l62:q9;2l63")
  b.write(":qa;2l64:qb;2l65:qc;2l66:qd;2l67:qe;2l68:qf;2l69:qg;2l6a:qh;2l6b:qi;2l6c:qj;2l6d:qk;2l6e:ql;2l6f:qm;2l6g:qn;2l6h:qo;2l6i")
  b.write(":qp;2l6j:qq;2l6k:qr;2l6l:qs;2l6m:qt;2l6n:qu;2l6o:qv;2l6p:qw;2l6q:qx;2l6r:6pu;2l6s:s5;2l6t:r5;2l6u:s0;2l6v:r9;2l6w:s1;2l6")
  b.write("x:ra;2l6y:rg;2l6z:rh;2l72:1c;2l73:1d;2l74:1e;2l75:1f;2l76:1g;2l77:1h;2l78:1i;2l79:1j;2l7a:1k;2l7b:1l;2l7c:1c;2l7d:1d;2l7")
  b.write("e:1e;2l7f:1f;2l7g:1g;2l7h:1h;2l7i:1i;2l7j:1j;2l7k:1k;2l7l:1l;2l7m:1c;2l7n:1d;2l7o:1e;2l7p:1f;2l7q:1g;2l7r:1h;2l7s:1i;2l7")
  b.write("t:1j;2l7u:1k;2l7v:1l;2l7w:1c;2l7x:1d;2l7y:1e;2l7z:1f;2l80:1g;2l81:1h;2l82:1i;2l83:1j;2l84:1k;2l85:1l;2l86:1c;2l87:1d;2l8")
  b.write("8:1e;2l89:1f;2l8a:1g;2l8b:1h;2l8c:1i;2l8d:1j;2l8e:1k;2l8f:1l;2muo:ts;2mup:tt;2muq:tu;2mur:tv;2mus:tw;2mut:tx;2muu:ty;2mu")
  b.write("v:tz;2muw:u0;2mux:u2;2muy:u3;2muz:u4;2mv0:u6;2mv1:u7;2mv2:u8;2mv3:u9;2mv4:ua;2mv5:ub;2mv6:uc;2mv7:ud;2mv8:ue;2mv9:uf;2mv")
  b.write("a:ug;2mvb:uj;2mvc:ul;2mvd:um;2mve:ww9;2mvf:yh;2mvg:uu;2mvh:uw;2mvi:yx;2mvj:xb;2mvk:y7;2mvl:ts;2mvm:tt;2mvn:tu;2mvo:tv;2m")
  b.write("vp:tw;2mvq:tx;2mvr:ty;2mvs:tz;2mvt:u0;2mvu:u2;2mvv:u3;2mvw:u6;2mvx:u7;2mvy:u9;2mvz:ub;2mw0:uc;2mw1:ud;2mw2:ue;2mw3:uf;2m")
  b.write("w4:ug;2mw5:ui;2mw6:uj;2mw7:wh;2mw8:uu;2mw9:ut;2mwa:v3;2mwb:x7;2mwc:wup;2mwd:xd;2pkw:17r;2pkx:17s;2pky:17w;2pkz:17z;2pl1:")
  b.write("18o;2pl2:182;2pl3:17x;2pl4:187;2pl5:18q;2pl6:18j;2pl7:18k;2pl8:18l;2pl9:18m;2pla:183;2plb:189;2plc:18h;2pld:185;2ple:18i")
  b.write(";2plf:181;2plg:184;2plh:17u;2pli:17v;2plj:17y;2plk:180;2pll:186;2plm:188;2pln:18a;2plo:19q;2plp:1bu;2plq:1b5;2plr:19r;2p")
  b.write("lt:17s;2plu:17w;2plw:18n;2plz:17x;2pm1:18q;2pm2:18j;2pm3:18k;2pm4:18l;2pm5:18m;2pm6:183;2pm7:189;2pm8:18h;2pm9:185;2pma:")
  b.write("18i;2pmc:184;2pmd:17u;2pme:17v;2pmf:17y;2pmh:186;2pmj:18a;2pmq:17w;2pmv:17x;2pmx:18q;2pmz:18k;2pn1:18m;2pn2:183;2pn3:189")
  b.write(";2pn5:185;2pn6:18i;2pn8:184;2pnb:17y;2pnd:186;2pnf:18a;2pnh:1bu;2pnj:19r;2pnl:17s;2pnm:17w;2pno:18n;2pnr:17x;2pns:187;2p")
  b.write("nt:18q;2pnu:18j;2pnw:18l;2pnx:18m;2pny:183;2pnz:189;2po0:18h;2po1:185;2po2:18i;2po4:184;2po5:17u;2po6:17v;2po7:17y;2po9:")
  b.write("186;2poa:188;2pob:18a;2poc:19q;2poe:1b5;2pog:17r;2poh:17s;2poi:17w;2poj:17z;2pok:18n;2pol:18o;2pom:182;2pon:17x;2poo:187")
  b.write(";2pop:18q;2por:18k;2pos:18l;2pot:18m;2pou:183;2pov:189;2pow:18h;2pox:185;2poy:18i;2poz:181;2pp0:184;2pp1:17u;2pp2:17v;2p")
  b.write("p3:17y;2pp4:180;2pp5:186;2pp6:188;2pp7:18a;2ppd:17s;2ppe:17w;2ppf:17z;2pph:18o;2ppi:182;2ppj:17x;2ppk:187;2ppl:18q;2ppn:")
  b.write("18k;2ppo:18l;2ppp:18m;2ppq:183;2ppr:189;2pps:18h;2ppt:185;2ppu:18i;2ppv:181;2ppw:184;2ppx:17u;2ppy:17v;2ppz:17y;2pq0:180")
  b.write(";2pq1:186;2pq2:188;2pq3:18a;2q68:1c,1a;2q69:1c,18;2q6a:1d,18;2q6b:1e,18;2q6c:1f,18;2q6d:1g,18;2q6e:1h,18;2q6f:1i,18;2q6g")
  b.write(":1j,18;2q6h:1k,18;2q6i:1l,18;2q6o:14,1t,15;2q6p:14,1u,15;2q6q:14,1v,15;2q6r:14,1w,15;2q6s:14,1x,15;2q6t:14,1y,15;2q6u:14")
  b.write(",1z,15;2q6v:14,20,15;2q6w:14,21,15;2q6x:14,22,15;2q6y:14,23,15;2q6z:14,24,15;2q70:14,25,15;2q71:14,26,15;2q72:14,27,15;2")
  b.write("q73:14,28,15;2q74:14,29,15;2q75:14,2a,15;2q76:14,2b,15;2q77:14,2c,15;2q78:14,2d,15;2q79:14,2e,15;2q7a:14,2f,15;2q7b:14,2")
  b.write("g,15;2q7c:14,2h,15;2q7d:14,2i,15;2q7e:9hw,2b,9hx;2q7f:1v;2q7g:2a;2q7h:1v,1w;2q7i:2f,2i;2q7k:1t;2q7l:1u;2q7m:1v;2q7n:1w;2")
  b.write("q7o:1x;2q7p:1y;2q7q:1z;2q7r:20;2q7s:21;2q7t:22;2q7u:23;2q7v:24;2q7w:25;2q7x:26;2q7y:27;2q7z:28;2q80:29;2q81:2a;2q82:2b;2")
  b.write("q83:2c;2q84:2d;2q85:2e;2q86:2f;2q87:2g;2q88:2h;2q89:2i;2q8a:20,2e;2q8b:25,2e;2q8c:2b,1w;2q8d:2b,2b;2q8e:28,28,2e;2q8f:2f")
  b.write(",1v;2q96:25,1v;2q97:25,1w;2q98:25,2a;2qa8:1w,22;2qdc:9kr,9jf;2qdd:9mb,9mb;2qde:9md;2qds:jez;2qdt:i1j;2qdu:gjw;2qdv:9mv;2")
  b.write("qdw:fik;2qdx:hlm;2qdy:r8j;2qdz:hm1;2qe0:fj8;2qe1:k68;2qe2:mch;2qe3:k2h;2qe4:g99;2qe5:ivg;2qe6:g3x;2qe7:k34;2qe8:g7x;2qe9")
  b.write(":oqq;2qea:n4v;2qeb:rs9;2qec:hkg;2qed:gmx;2qee:lxw;2qef:jh1;2qeg:jmd;2qeh:feo;2qei:fex;2qej:si2;2qek:ijq;2qel:ffx;2qem:gk")
  b.write("z;2qen:jk7;2qeo:rxs;2qep:jf7;2qeq:o01;2qer:o6y;2qes:glk;2qet:lts;2qeu:kcp;2qev:kco;2qew:n5f;2qex:gaa;2qey:gxi;2qez:sp9;2")
  b.write("qf4:9hw,kdo,9hx;2qf5:9hw,fex,9hx;2qf6:9hw,fik,9hx;2qf7:9hw,i2x,9hx;2qf8:9hw,m9l,9hx;2qf9:9hw,jf7,9hx;2qfa:9hw,nh3,9hx;2q")
  b.write("fb:9hw,gd9,9hx;2qfc:9hw,k0n,9hx;2qfk:ivr;2qfl:gkv;2sc0:1c;2sc1:1d;2sc2:1e;2sc3:1f;2sc4:1g;2sc5:1h;2sc6:1i;2sc7:1j;2sc8:1")
  b.write("k;2sc9:1l")
  return b.toString()

_uCompRaw() -> String:
  b = StringBuffer()
  b.write("1t,lc,5c;1t,ld,5d;1t,le,5e;1t,lf,5f;1t,lk,5g;1t,lm,5h;1v,mf,5j;1x,lc,5k;1x,ld,5l;1x,le,5m;1x,lk,5n;21,lc,5o;21,ld,5p;21,")
  b.write("le,5q;21,lk,5r;26,lf,5t;27,lc,5u;27,ld,5v;27,le,5w;27,lf,5x;27,lk,5y;2d,lc,61;2d,ld,62;2d,le,63;2d,lk,64;2h,ld,65;2p,lc,")
  b.write("68;2p,ld,69;2p,le,6a;2p,lf,6b;2p,lk,6c;2p,lm,6d;2r,mf,6f;2t,lc,6g;2t,ld,6h;2t,le,6i;2t,lk,6j;2x,lc,6k;2x,ld,6l;2x,le,6m;")
  b.write("2x,lk,6n;32,lf,6p;33,lc,6q;33,ld,6r;33,le,6s;33,lf,6t;33,lk,6u;39,lc,6x;39,ld,6y;39,le,6z;39,lk,70;3d,ld,71;3d,lk,73;1t,")
  b.write("lg,74;2p,lg,75;1t,li,76;2p,li,77;1t,mg,78;2p,mg,79;1v,ld,7a;2r,ld,7b;1v,le,7c;2r,le,7d;1v,lj,7e;2r,lj,7f;1v,lo,7g;2r,lo,")
  b.write("7h;1w,lo,7i;2s,lo,7j;1x,lg,7m;2t,lg,7n;1x,li,7o;2t,li,7p;1x,lj,7q;2t,lj,7r;1x,mg,7s;2t,mg,7t;1x,lo,7u;2t,lo,7v;1z,le,7w;")
  b.write("2v,le,7x;1z,li,7y;2v,li,7z;1z,lj,80;2v,lj,81;1z,mf,82;2v,mf,83;20,le,84;2w,le,85;21,lf,88;2x,lf,89;21,lg,8a;2x,lg,8b;21,")
  b.write("li,8c;2x,li,8d;21,mg,8e;2x,mg,8f;21,lj,8g;22,le,8k;2y,le,8l;23,mf,8m;2z,mf,8n;24,ld,8p;30,ld,8q;24,mf,8r;30,mf,8s;24,lo,")
  b.write("8t;30,lo,8u;26,ld,8z;32,ld,90;26,mf,91;32,mf,92;26,lo,93;32,lo,94;27,lg,98;33,lg,99;27,li,9a;33,li,9b;27,ln,9c;33,ln,9d;")
  b.write("2a,ld,9g;36,ld,9h;2a,mf,9i;36,mf,9j;2a,lo,9k;36,lo,9l;2b,ld,9m;37,ld,9n;2b,le,9o;37,le,9p;2b,mf,9q;37,mf,9r;2b,lo,9s;37,")
  b.write("lo,9t;2c,mf,9u;38,mf,9v;2c,lo,9w;38,lo,9x;2d,lf,a0;39,lf,a1;2d,lg,a2;39,lg,a3;2d,li,a4;39,li,a5;2d,lm,a6;39,lm,a7;2d,ln,")
  b.write("a8;39,ln,a9;2d,mg,aa;39,mg,ab;2f,le,ac;3b,le,ad;2h,le,ae;3d,le,af;2h,lk,ag;2i,ld,ah;3e,ld,ai;2i,lj,aj;3e,lj,ak;2i,lo,al;")
  b.write("3e,lo,am;27,m3,bk;33,m3,bl;2d,m3,bz;39,m3,c0;1t,lo,ct;2p,lo,cu;21,lo,cv;2x,lo,cw;27,lo,cx;33,lo,cy;2d,lo,cz;39,lo,d0;64,")
  b.write("lg,d1;70,lg,d2;64,ld,d3;70,ld,d4;64,lo,d5;70,lo,d6;64,lc,d7;70,lc,d8;5g,lg,da;6c,lg,db;fa,lg,dc;fb,lg,dd;5i,lg,de;6e,lg,")
  b.write("df;1z,lo,di;2v,lo,dj;23,lo,dk;2z,lo,dl;27,mg,dm;33,mg,dn;dm,lg,do;dn,lg,dp;c7,lo,dq;ia,lo,dr;2y,lo,ds;1z,ld,dw;2v,ld,dx;")
  b.write("26,lc,e0;32,lc,e1;5h,ld,e2;6d,ld,e3;5i,ld,e4;6e,ld,e5;60,ld,e6;6w,ld,e7;1t,lr,e8;2p,lr,e9;1t,lt,ea;2p,lt,eb;1x,lr,ec;2t,")
  b.write("lr,ed;1x,lt,ee;2t,lt,ef;21,lr,eg;2x,lr,eh;21,lt,ei;2x,lt,ej;27,lr,ek;33,lr,el;27,lt,em;33,lt,en;2a,lr,eo;36,lr,ep;2a,lt,")
  b.write("eq;36,lt,er;2d,lr,es;39,lr,et;2d,lt,eu;39,lt,ev;2b,me,ew;37,me,ex;2c,me,ey;38,me,ez;20,lo,f2;2w,lo,f3;1t,lj,fa;2p,lj,fb;")
  b.write("1x,mf,fc;2t,mf,fd;5y,lg,fe;6u,lg,ff;5x,lg,fg;6t,lg,fh;27,lj,fi;33,lj,fj;fi,lg,fk;fj,lg,fl;2h,lg,fm;3d,lg,fn;4o,ld,p1;pd,")
  b.write("ld,p2;ph,ld,p4;pj,ld,p5;pl,ld,p6;pr,ld,p8;px,ld,pa;q1,ld,pb;qy,ld,pc;pl,lk,q2;px,lk,q3;q9,ld,q4;qd,ld,q5;qf,ld,q6;qh,ld,")
  b.write("q7;qz,ld,q8;qh,lk,qy;qt,lk,qz;qn,ld,r0;qt,ld,r1;qx,ld,r2;r6,ld,r7;r6,lk,r8;t1,lc,sg;t1,lk,sh;sz,ld,sj;sm,lk,sn;t6,ld,ss;")
  b.write("t4,lc,st;tf,li,su;t4,li,t5;u0,li,u1;tx,lc,uo;tx,lk,up;tv,ld,ur;uu,lk,uv;u2,ld,v0;u0,lc,v1;ub,li,v2;vo,lr,vq;vp,lr,vr;t2,")
  b.write("li,xt;ty,li,xu;sw,li,y8;ts,li,y9;sw,lk,ya;ts,lk,yb;t1,li,ye;tx,li,yf;yg,lk,yi;yh,lk,yj;t2,lk,yk;ty,lk,yl;t3,lk,ym;tz,lk,")
  b.write("yn;t4,lg,yq;u0,lg,yr;t4,lk,ys;u0,lk,yt;ta,lk,yu;u6,lk,yv;yw,lk,yy;yx,lk,yz;tp,lk,z0;ul,lk,z1;tf,lg,z2;ub,lg,z3;tf,lk,z4;")
  b.write("ub,lk,z5;tf,ln,z6;ub,ln,z7;tj,lk,z8;uf,lk,z9;tn,lk,zc;uj,lk,zd;17r,18z,17m;17r,190,17n;18o,190,17o;17r,191,17p;18q,190,1")
  b.write("7q;1cl,190,1c0;1c1,190,1c2;1ci,190,1cj;1t4,1to,1t5;1tc,1to,1td;1tf,1to,1tg;1xj,1xa,1xn;1xj,1xz,1xo;287,28m,288;287,27y,2")
  b.write("8b;287,28n,28c;2aa,2c7,2ac;2bq,2bi,2bu;2br,2bi,2bv;2bq,2c7,2bw;2fa,2fq,2fc;2in,2j9,2io;2iu,2j9,2iv;2iu,2ja,2iw;2iu,2iq,2")
  b.write("iy;2iy,2j9,2iz;2me,2m6,2mi;2mf,2m6,2mj;2me,2mv,2mk;2qh,2q2,2qi;2qh,2q7,2qk;2qk,2q2,2ql;2qh,2qn,2qm;36t,372,36u;5c5,5dh,5")
  b.write("c6;5c7,5dh,5c8;5c9,5dh,5ca;5cb,5dh,5cc;5cd,5dh,5ce;5ch,5dh,5ci;5dm,5dh,5dn;5do,5dh,5dp;5dq,5dh,5ds;5dr,5dh,5dt;5du,5dh,5")
  b.write("dv;1t,md,5xc;2p,md,5xd;1u,lj,5xe;2q,lj,5xf;1u,mb,5xg;2q,mb,5xh;1u,mp,5xi;2q,mp,5xj;5j,ld,5xk;6f,ld,5xl;1w,lj,5xm;2s,lj,5")
  b.write("xn;1w,mb,5xo;2s,mb,5xp;1w,mp,5xq;2s,mp,5xr;1w,mf,5xs;2s,mf,5xt;1w,ml,5xu;2s,ml,5xv;7m,lc,5xw;7n,lc,5xx;7m,ld,5xy;7n,ld,5")
  b.write("xz;1x,ml,5y0;2t,ml,5y1;1x,mo,5y2;2t,mo,5y3;fc,li,5y4;fd,li,5y5;1y,lj,5y6;2u,lj,5y7;1z,lg,5y8;2v,lg,5y9;20,lj,5ya;2w,lj,5")
  b.write("yb;20,mb,5yc;2w,mb,5yd;20,lk,5ye;2w,lk,5yf;20,mf,5yg;2w,mf,5yh;20,mm,5yi;2w,mm,5yj;21,mo,5yk;2x,mo,5yl;5r,ld,5ym;6n,ld,5")
  b.write("yn;23,ld,5yo;2z,ld,5yp;23,mb,5yq;2z,mb,5yr;23,mp,5ys;2z,mp,5yt;24,mb,5yu;30,mb,5yv;5yu,lg,5yw;5yv,lg,5yx;24,mp,5yy;30,mp")
  b.write(",5yz;24,ml,5z0;30,ml,5z1;25,ld,5z2;31,ld,5z3;25,lj,5z4;31,lj,5z5;25,mb,5z6;31,mb,5z7;26,lj,5z8;32,lj,5z9;26,mb,5za;32,mb")
  b.write(",5zb;26,mp,5zc;32,mp,5zd;26,ml,5ze;32,ml,5zf;5x,ld,5zg;6t,ld,5zh;5x,lk,5zi;6t,lk,5zj;98,lc,5zk;99,lc,5zl;98,ld,5zm;99,ld")
  b.write(",5zn;28,ld,5zo;34,ld,5zp;28,lj,5zq;34,lj,5zr;2a,lj,5zs;36,lj,5zt;2a,mb,5zu;36,mb,5zv;5zu,lg,5zw;5zv,lg,5zx;2a,mp,5zy;36,")
  b.write("mp,5zz;2b,lj,600;37,lj,601;2b,mb,602;37,mb,603;9m,lj,604;9n,lj,605;9s,lj,606;9t,lj,607;602,lj,608;603,lj,609;2c,lj,60a;3")
  b.write("8,lj,60b;2c,mb,60c;38,mb,60d;2c,mp,60e;38,mp,60f;2c,ml,60g;38,ml,60h;2d,mc,60i;39,mc,60j;2d,mo,60k;39,mo,60l;2d,ml,60m;3")
  b.write("9,ml,60n;a0,ld,60o;a1,ld,60p;a2,lk,60q;a3,lk,60r;2e,lf,60s;3a,lf,60t;2e,mb,60u;3a,mb,60v;2f,lc,60w;3b,lc,60x;2f,ld,60y;3")
  b.write("b,ld,60z;2f,lk,610;3b,lk,611;2f,lj,612;3b,lj,613;2f,mb,614;3b,mb,615;2g,lj,616;3c,lj,617;2g,lk,618;3c,lk,619;2h,lj,61a;3")
  b.write("d,lj,61b;2i,le,61c;3e,le,61d;2i,mb,61e;3e,mb,61f;2i,mp,61g;3e,mp,61h;2w,mp,61i;38,lk,61j;3b,lm,61k;3d,lm,61l;an,lj,61n;1")
  b.write("t,mb,61s;2p,mb,61t;1t,ll,61u;2p,ll,61v;5e,ld,61w;6a,ld,61x;5e,lc,61y;6a,lc,61z;5e,ll,620;6a,ll,621;5e,lf,622;6a,lf,623;6")
  b.write("1s,le,624;61t,le,625;76,ld,626;77,ld,627;76,lc,628;77,lc,629;76,ll,62a;77,ll,62b;76,lf,62c;77,lf,62d;61s,li,62e;61t,li,6")
  b.write("2f;1x,mb,62g;2t,mb,62h;1x,ll,62i;2t,ll,62j;1x,lf,62k;2t,lf,62l;5m,ld,62m;6i,ld,62n;5m,lc,62o;6i,lc,62p;5m,ll,62q;6i,ll,6")
  b.write("2r;5m,lf,62s;6i,lf,62t;62g,le,62u;62h,le,62v;21,ll,62w;2x,ll,62x;21,mb,62y;2x,mb,62z;27,mb,630;33,mb,631;27,ll,632;33,ll")
  b.write(",633;5w,ld,634;6s,ld,635;5w,lc,636;6s,lc,637;5w,ll,638;6s,ll,639;5w,lf,63a;6s,lf,63b;630,le,63c;631,le,63d;bk,ld,63e;bl,")
  b.write("ld,63f;bk,lc,63g;bl,lc,63h;bk,ll,63i;bl,ll,63j;bk,lf,63k;bl,lf,63l;bk,mb,63m;bl,mb,63n;2d,mb,63o;39,mb,63p;2d,ll,63q;39,")
  b.write("ll,63r;bz,ld,63s;c0,ld,63t;bz,lc,63u;c0,lc,63v;bz,ll,63w;c0,ll,63x;bz,lf,63y;c0,lf,63z;bz,mb,640;c0,mb,641;2h,lc,642;3d,")
  b.write("lc,643;2h,mb,644;3d,mb,645;2h,ll,646;3d,ll,647;2h,lf,648;3d,lf,649;q9,lv,64g;q9,lw,64h;64g,lc,64i;64h,lc,64j;64g,ld,64k;")
  b.write("64h,ld,64l;64g,n6,64m;64h,n6,64n;pd,lv,64o;pd,lw,64p;64o,lc,64q;64p,lc,64r;64o,ld,64s;64p,ld,64t;64o,n6,64u;64p,n6,64v;q")
  b.write("d,lv,64w;qd,lw,64x;64w,lc,64y;64x,lc,64z;64w,ld,650;64x,ld,651;ph,lv,654;ph,lw,655;654,lc,656;655,lc,657;654,ld,658;655,")
  b.write("ld,659;qf,lv,65c;qf,lw,65d;65c,lc,65e;65d,lc,65f;65c,ld,65g;65d,ld,65h;65c,n6,65i;65d,n6,65j;pj,lv,65k;pj,lw,65l;65k,lc,")
  b.write("65m;65l,lc,65n;65k,ld,65o;65l,ld,65p;65k,n6,65q;65l,n6,65r;qh,lv,65s;qh,lw,65t;65s,lc,65u;65t,lc,65v;65s,ld,65w;65t,ld,6")
  b.write("5x;65s,n6,65y;65t,n6,65z;pl,lv,660;pl,lw,661;660,lc,662;661,lc,663;660,ld,664;661,ld,665;660,n6,666;661,n6,667;qn,lv,668")
  b.write(";qn,lw,669;668,lc,66a;669,lc,66b;668,ld,66c;669,ld,66d;pr,lv,66g;pr,lw,66h;66g,lc,66i;66h,lc,66j;66g,ld,66k;66h,ld,66l;q")
  b.write("t,lv,66o;qt,lw,66p;66o,lc,66q;66p,lc,66r;66o,ld,66s;66p,ld,66t;66o,n6,66u;66p,n6,66v;px,lw,66x;66x,lc,66z;66x,ld,671;66x")
  b.write(",n6,673;qx,lv,674;qx,lw,675;674,lc,676;675,lc,677;674,ld,678;675,ld,679;674,n6,67a;675,n6,67b;q1,lv,67c;q1,lw,67d;67c,lc")
  b.write(",67e;67d,lc,67f;67c,ld,67g;67d,ld,67h;67c,n6,67i;67d,n6,67j;q9,lc,67k;qd,lc,67m;qf,lc,67o;qh,lc,67q;qn,lc,67s;qt,lc,67u;")
  b.write("qx,lc,67w;64g,n9,680;64h,n9,681;64i,n9,682;64j,n9,683;64k,n9,684;64l,n9,685;64m,n9,686;64n,n9,687;64o,n9,688;64p,n9,689;")
  b.write("64q,n9,68a;64r,n9,68b;64s,n9,68c;64t,n9,68d;64u,n9,68e;64v,n9,68f;65c,n9,68g;65d,n9,68h;65e,n9,68i;65f,n9,68j;65g,n9,68k")
  b.write(";65h,n9,68l;65i,n9,68m;65j,n9,68n;65k,n9,68o;65l,n9,68p;65m,n9,68q;65n,n9,68r;65o,n9,68s;65p,n9,68t;65q,n9,68u;65r,n9,68")
  b.write("v;674,n9,68w;675,n9,68x;676,n9,68y;677,n9,68z;678,n9,690;679,n9,691;67a,n9,692;67b,n9,693;67c,n9,694;67d,n9,695;67e,n9,6")
  b.write("96;67f,n9,697;67g,n9,698;67h,n9,699;67i,n9,69a;67j,n9,69b;q9,li,69c;q9,lg,69d;67k,n9,69e;q9,n9,69f;q4,n9,69g;q9,n6,69i;6")
  b.write("9i,n9,69j;pd,li,69k;pd,lg,69l;pd,lc,69m;pd,n9,69o;4o,n6,69t;67o,n9,69u;qf,n9,69v;q6,n9,69w;qf,n6,69y;69y,n9,69z;ph,lc,6a")
  b.write("0;pj,lc,6a2;pj,n9,6a4;69r,lc,6a5;69r,ld,6a6;69r,n6,6a7;qh,li,6a8;qh,lg,6a9;qy,lc,6aa;qh,n6,6ae;qy,n6,6af;pl,li,6ag;pl,lg")
  b.write(",6ah;pl,lc,6ai;6bi,lc,6al;6bi,ld,6am;6bi,n6,6an;qt,li,6ao;qt,lg,6ap;qz,lc,6aq;qp,lv,6as;qp,lw,6at;qt,n6,6au;qz,n6,6av;px")
  b.write(",li,6aw;px,lg,6ax;px,lc,6ay;pt,lw,6b0;4o,lc,6b1;67w,n9,6b6;qx,n9,6b7;r2,n9,6b8;qx,n6,6ba;6ba,n9,6bb;pr,lc,6bc;q1,lc,6be;")
  b.write("q1,n9,6bg;6mo,mw,6my;6mq,mw,6mz;6ms,mw,6ni;6og,mw,6od;6ok,mw,6oe;6oi,mw,6of;6pv,mw,6pw;6q0,mw,6q1;6q3,mw,6q4;6qr,mw,6qs;")
  b.write("6qt,mw,6qu;6rg,mw,6rl;6rn,mw,6ro;6rp,mw,6rr;6rs,mw,6rt;1p,mw,6sg;6sh,mw,6si;6rx,mw,6st;1o,mw,6su;1q,mw,6sv;6sk,mw,6sw;6s")
  b.write("l,mw,6sx;6sy,mw,6t0;6sz,mw,6t1;6t2,mw,6t4;6t3,mw,6t5;6t6,mw,6tc;6t7,mw,6td;6te,mw,6tg;6tf,mw,6th;6ti,mw,6tk;6tj,mw,6tl;6")
  b.write("ua,mw,6uk;6ug,mw,6ul;6uh,mw,6um;6uj,mw,6un;6t8,mw,6w0;6t9,mw,6w1;6tt,mw,6w2;6tu,mw,6w3;6uq,mw,6wa;6ur,mw,6wb;6us,mw,6wc;")
  b.write("6ut,mw,6wd;9jf,9ll,9jg;9jh,9ll,9ji;9jj,9ll,9jk;9jl,9ll,9jm;9jn,9ll,9jo;9jp,9ll,9jq;9jr,9ll,9js;9jt,9ll,9ju;9jv,9ll,9jw;9")
  b.write("jx,9ll,9jy;9jz,9ll,9k0;9k1,9ll,9k2;9k4,9ll,9k5;9k6,9ll,9k7;9k8,9ll,9k9;9kf,9ll,9kg;9kf,9lm,9kh;9ki,9ll,9kj;9ki,9lm,9kk;9")
  b.write("kl,9ll,9km;9kl,9lm,9kn;9ko,9ll,9kp;9ko,9lm,9kq;9kr,9ll,9ks;9kr,9lm,9kt;9ja,9ll,9lg;9lp,9ll,9lq;9m3,9ll,9m4;9m5,9ll,9m6;9")
  b.write("m7,9ll,9m8;9m9,9ll,9ma;9mb,9ll,9mc;9md,9ll,9me;9mf,9ll,9mg;9mh,9ll,9mi;9mj,9ll,9mk;9ml,9ll,9mm;9mn,9ll,9mo;9mp,9ll,9mq;9")
  b.write("ms,9ll,9mt;9mu,9ll,9mv;9mw,9ll,9mx;9n3,9ll,9n4;9n3,9lm,9n5;9n6,9ll,9n7;9n6,9lm,9n8;9n9,9ll,9na;9n9,9lm,9nb;9nc,9ll,9nd;9")
  b.write("nc,9lm,9ne;9nf,9ll,9ng;9nf,9lm,9nh;9ly,9ll,9o4;9nz,9ll,9o7;9o0,9ll,9o8;9o1,9ll,9o9;9o2,9ll,9oa;9od,9ll,9oe;1huh,1hve,1hu")
  b.write("i;1huj,1hve,1huk;1hut,1hve,1huz;1hyp,1hyf,1hym;1hyq,1hyf,1hyn;1idj,1ida,1idn;1idj,1idz,1ido;1int,1inu,1inv;1int,1ink,1in")
  b.write("w;1int,1inx,1iny;1iuw,1iun,1iuy;1iux,1iun,1iuz;1jjp,1jjk,1jjs")
  return b.toString()

_uCaseFoldRaw() -> String:
  b = StringBuffer()
  b.write("51:qk;5c:68;5d:69;5e:6a;5f:6b;5g:6c;5h:6d;5i:6e;5j:6f;5k:6g;5l:6h;5m:6i;5n:6j;5o:6k;5p:6l;5q:6m;5r:6n;5s:6o;5t:6p;5u:6q;")
  b.write("5v:6r;5w:6s;5x:6t;5y:6u;60:6w;61:6x;62:6y;63:6z;64:70;65:71;66:72;67:37,37;74:75;76:77;78:79;7a:7b;7c:7d;7e:7f;7g:7h;7i:")
  b.write("7j;7k:7l;7m:7n;7o:7p;7q:7r;7s:7t;7u:7v;7w:7x;7y:7z;80:81;82:83;84:85;86:87;88:89;8a:8b;8c:8d;8e:8f;8g:2x,lj;8i:8j;8k:8l;")
  b.write("8m:8n;8p:8q;8r:8s;8t:8u;8v:8w;8x:8y;8z:90;91:92;93:94;95:jg,32;96:97;98:99;9a:9b;9c:9d;9e:9f;9g:9h;9i:9j;9k:9l;9m:9n;9o:")
  b.write("9p;9q:9r;9s:9t;9u:9v;9w:9x;9y:9z;a0:a1;a2:a3;a4:a5;a6:a7;a8:a9;aa:ab;ac:ad;ae:af;ag:73;ah:ai;aj:ak;al:am;an:37;ap:gj;aq:")
  b.write("ar;as:at;au:gk;av:aw;ax:gm;ay:gn;az:b0;b2:d9;b3:gp;b4:gr;b5:b6;b7:gw;b8:gz;ba:h5;bb:h4;bc:bd;bg:hb;bh:he;bj:hh;bk:bl;bm:")
  b.write("bn;bo:bp;bq:hs;br:bs;bt:hv;bw:bx;by:i0;bz:c0;c1:i2;c2:i3;c3:c4;c5:c6;c7:ia;c8:c9;cc:cd;ck:cm;cl:cm;cn:cp;co:cp;cq:cs;cr:")
  b.write("cs;ct:cu;cv:cw;cx:cy;cz:d0;d1:d2;d3:d4;d5:d6;d7:d8;da:db;dc:dd;de:df;dg:dh;di:dj;dk:dl;dm:dn;do:dp;dq:dr;ds:2y,lo;dt:dv;")
  b.write("du:dv;dw:dx;dy:b9;dz:cf;e0:e1;e2:e3;e4:e5;e6:e7;e8:e9;ea:eb;ec:ed;ee:ef;eg:eh;ei:ej;ek:el;em:en;eo:ep;eq:er;es:et;eu:ev;")
  b.write("ew:ex;ey:ez;f0:f1;f2:f3;f4:bi;f6:f7;f8:f9;fa:fb;fc:fd;fe:ff;fg:fh;fi:fj;fk:fl;fm:fn;fu:8rp;fv:fw;fx:be;fy:8rq;g1:g2;g3:a")
  b.write("o;g4:i1;g5:i4;g6:g7;g8:g9;ga:gb;gc:gd;ge:gf;n9:qh;og:oh;oi:oj;om:on;ov:s3;p2:q4;p4:q5;p5:q6;p6:q7;p8:r0;pa:r1;pb:r2;pc:q")
  b.write("h,lk,ld;pd:q9;pe:qa;pf:qb;pg:qc;ph:qd;pi:qe;pj:qf;pk:qg;pl:qh;pm:qi;pn:qj;po:qk;pp:ql;pq:qm;pr:qn;ps:qo;pt:qp;pv:qr;pw:q")
  b.write("s;px:qt;py:qu;pz:qv;q0:qw;q1:qx;q2:qy;q3:qz;q8:qt,lk,ld;qq:qr;r3:rb;r4:qa;r5:qg;r9:qu;ra:qo;rc:rd;re:rf;rg:rh;ri:rj;rk:r")
  b.write("l;rm:rn;ro:rp;rq:rr;rs:rt;ru:rv;rw:rx;ry:rz;s0:qi;s1:qp;s4:qg;s5:qd;s7:s8;s9:s2;sa:sb;sd:or;se:os;sf:ot;sg:uo;sh:up;si:u")
  b.write("q;sj:ur;sk:us;sl:ut;sm:uu;sn:uv;so:uw;sp:ux;sq:uy;sr:uz;ss:v0;st:v1;su:v2;sv:v3;sw:ts;sx:tt;sy:tu;sz:tv;t0:tw;t1:tx;t2:t")
  b.write("y;t3:tz;t4:u0;t5:u1;t6:u2;t7:u3;t8:u4;t9:u5;ta:u6;tb:u7;tc:u8;td:u9;te:ua;tf:ub;tg:uc;th:ud;ti:ue;tj:uf;tk:ug;tl:uh;tm:u")
  b.write("i;tn:uj;to:uk;tp:ul;tq:um;tr:un;v4:v5;v6:v7;v8:v9;va:vb;vc:vd;ve:vf;vg:vh;vi:vj;vk:vl;vm:vn;vo:vp;vq:vr;vs:vt;vu:vv;vw:v")
  b.write("x;vy:vz;w0:w1;wa:wb;wc:wd;we:wf;wg:wh;wi:wj;wk:wl;wm:wn;wo:wp;wq:wr;ws:wt;wu:wv;ww:wx;wy:wz;x0:x1;x2:x3;x4:x5;x6:x7;x8:x")
  b.write("9;xa:xb;xc:xd;xe:xf;xg:xh;xi:xj;xk:xl;xm:xn;xo:xp;xq:xr;xs:y7;xt:xu;xv:xw;xx:xy;xz:y0;y1:y2;y3:y4;y5:y6;y8:y9;ya:yb;yc:y")
  b.write("d;ye:yf;yg:yh;yi:yj;yk:yl;ym:yn;yo:yp;yq:yr;ys:yt;yu:yv;yw:yx;yy:yz;z0:z1;z2:z3;z4:z5;z6:z7;z8:z9;za:zb;zc:zd;ze:zf;zg:z")
  b.write("h;zi:zj;zk:zl;zm:zn;zo:zp;zq:zr;zs:zt;zu:zv;zw:zx;zy:zz;100:101;102:103;104:105;106:107;108:109;10a:10b;10c:10d;10e:10f;")
  b.write("10g:10h;10i:10j;10k:10l;10m:10n;10o:10p;10q:10r;10s:10t;10u:10v;10x:129;10y:12a;10z:12b;110:12c;111:12d;112:12e;113:12f;")
  b.write("114:12g;115:12h;116:12i;117:12j;118:12k;119:12l;11a:12m;11b:12n;11c:12o;11d:12p;11e:12q;11f:12r;11g:12s;11h:12t;11i:12u;")
  b.write("11j:12v;11k:12w;11l:12x;11m:12y;11n:12z;11o:130;11p:131;11q:132;11r:133;11s:134;11t:135;11u:136;11v:137;11w:138;11x:139;")
  b.write("11y:13a;13b:12d,136;3a8:8w0;3a9:8w1;3aa:8w2;3ab:8w3;3ac:8w4;3ad:8w5;3ae:8w6;3af:8w7;3ag:8w8;3ah:8w9;3ai:8wa;3aj:8wb;3ak:")
  b.write("8wc;3al:8wd;3am:8we;3an:8wf;3ao:8wg;3ap:8wh;3aq:8wi;3ar:8wj;3as:8wk;3at:8wl;3au:8wm;3av:8wn;3aw:8wo;3ax:8wp;3ay:8wq;3az:")
  b.write("8wr;3b0:8ws;3b1:8wt;3b2:8wu;3b3:8wv;3b4:8ww;3b5:8wx;3b6:8wy;3b7:8wz;3b8:8x0;3b9:8x1;3bb:8x3;3bh:8x9;3y0:3xs;3y1:3xt;3y2:")
  b.write("3xu;3y3:3xv;3y4:3xw;3y5:3xx;5mo:tu;5mp:tw;5mq:u6;5mr:u9;5ms:ua;5mt:ua;5mu:ui;5mv:v7;5mw:wuj;5n4:3bk;5n5:3bl;5n6:3bm;5n7:")
  b.write("3bn;5n8:3bo;5n9:3bp;5na:3bq;5nb:3br;5nc:3bs;5nd:3bt;5ne:3bu;5nf:3bv;5ng:3bw;5nh:3bx;5ni:3by;5nj:3bz;5nk:3c0;5nl:3c1;5nm:")
  b.write("3c2;5nn:3c3;5no:3c4;5np:3c5;5nq:3c6;5nr:3c7;5ns:3c8;5nt:3c9;5nu:3ca;5nv:3cb;5nw:3cc;5nx:3cd;5ny:3ce;5nz:3cf;5o0:3cg;5o1:")
  b.write("3ch;5o2:3ci;5o3:3cj;5o4:3ck;5o5:3cl;5o6:3cm;5o7:3cn;5o8:3co;5o9:3cp;5oa:3cq;5od:3ct;5oe:3cu;5of:3cv;5xc:5xd;5xe:5xf;5xg:")
  b.write("5xh;5xi:5xj;5xk:5xl;5xm:5xn;5xo:5xp;5xq:5xr;5xs:5xt;5xu:5xv;5xw:5xx;5xy:5xz;5y0:5y1;5y2:5y3;5y4:5y5;5y6:5y7;5y8:5y9;5ya:")
  b.write("5yb;5yc:5yd;5ye:5yf;5yg:5yh;5yi:5yj;5yk:5yl;5ym:5yn;5yo:5yp;5yq:5yr;5ys:5yt;5yu:5yv;5yw:5yx;5yy:5yz;5z0:5z1;5z2:5z3;5z4:")
  b.write("5z5;5z6:5z7;5z8:5z9;5za:5zb;5zc:5zd;5ze:5zf;5zg:5zh;5zi:5zj;5zk:5zl;5zm:5zn;5zo:5zp;5zq:5zr;5zs:5zt;5zu:5zv;5zw:5zx;5zy:")
  b.write("5zz;600:601;602:603;604:605;606:607;608:609;60a:60b;60c:60d;60e:60f;60g:60h;60i:60j;60k:60l;60m:60n;60o:60p;60q:60r;60s:")
  b.write("60t;60u:60v;60w:60x;60y:60z;610:611;612:613;614:615;616:617;618:619;61a:61b;61c:61d;61e:61f;61g:61h;61i:2w,mp;61j:38,lk;")
  b.write("61k:3b,lm;61l:3d,lm;61m:2p,ji;61n:601;61q:37,37;61s:61t;61u:61v;61w:61x;61y:61z;620:621;622:623;624:625;626:627;628:629;")
  b.write("62a:62b;62c:62d;62e:62f;62g:62h;62i:62j;62k:62l;62m:62n;62o:62p;62q:62r;62s:62t;62u:62v;62w:62x;62y:62z;630:631;632:633;")
  b.write("634:635;636:637;638:639;63a:63b;63c:63d;63e:63f;63g:63h;63i:63j;63k:63l;63m:63n;63o:63p;63q:63r;63s:63t;63u:63v;63w:63x;")
  b.write("63y:63z;640:641;642:643;644:645;646:647;648:649;64a:64b;64c:64d;64e:64f;64o:64g;64p:64h;64q:64i;64r:64j;64s:64k;64t:64l;")
  b.write("64u:64m;64v:64n;654:64w;655:64x;656:64y;657:64z;658:650;659:651;65k:65c;65l:65d;65m:65e;65n:65f;65o:65g;65p:65h;65q:65i;")
  b.write("65r:65j;660:65s;661:65t;662:65u;663:65v;664:65w;665:65x;666:65y;667:65z;66g:668;66h:669;66i:66a;66j:66b;66k:66c;66l:66d;")
  b.write("66o:qt,lv;66q:qt,lv,lc;66s:qt,lv,ld;66u:qt,lv,n6;66x:66p;66z:66r;671:66t;673:66v;67c:674;67d:675;67e:676;67f:677;67g:678")
  b.write(";67h:679;67i:67a;67j:67b;680:64g,qh;681:64h,qh;682:64i,qh;683:64j,qh;684:64k,qh;685:64l,qh;686:64m,qh;687:64n,qh;688:64g")
  b.write(",qh;689:64h,qh;68a:64i,qh;68b:64j,qh;68c:64k,qh;68d:64l,qh;68e:64m,qh;68f:64n,qh;68g:65c,qh;68h:65d,qh;68i:65e,qh;68j:65")
  b.write("f,qh;68k:65g,qh;68l:65h,qh;68m:65i,qh;68n:65j,qh;68o:65c,qh;68p:65d,qh;68q:65e,qh;68r:65f,qh;68s:65g,qh;68t:65h,qh;68u:6")
  b.write("5i,qh;68v:65j,qh;68w:674,qh;68x:675,qh;68y:676,qh;68z:677,qh;690:678,qh;691:679,qh;692:67a,qh;693:67b,qh;694:674,qh;695:")
  b.write("675,qh;696:676,qh;697:677,qh;698:678,qh;699:679,qh;69a:67a,qh;69b:67b,qh;69e:67k,qh;69f:q9,qh;69g:q4,qh;69i:q9,n6;69j:q9")
  b.write(",n6,qh;69k:69c;69l:69d;69m:67k;69n:67l;69o:q9,qh;69q:qh;69u:67o,qh;69v:qf,qh;69w:q6,qh;69y:qf,n6;69z:qf,n6,qh;6a0:67m;6a")
  b.write("1:67n;6a2:67o;6a3:67p;6a4:qf,qh;6aa:qh,lk,lc;6ab:qh,lk,ld;6ae:qh,n6;6af:qh,lk,n6;6ag:6a8;6ah:6a9;6ai:67q;6aj:67r;6aq:qt,")
  b.write("lk,lc;6ar:qt,lk,ld;6as:qp,lv;6au:qt,n6;6av:qt,lk,n6;6aw:6ao;6ax:6ap;6ay:67u;6az:67v;6b0:6at;6b6:67w,qh;6b7:qx,qh;6b8:r2,")
  b.write("qh;6ba:qx,n6;6bb:qx,n6,qh;6bc:67s;6bd:67t;6be:67w;6bf:67x;6bg:qx,qh;6jq:qx;6ju:2z;6jv:6d;6k2:6ku;6lc:6ls;6ld:6lt;6le:6lu")
  b.write(";6lf:6lv;6lg:6lw;6lh:6lx;6li:6ly;6lj:6lz;6lk:6m0;6ll:6m1;6lm:6m2;6ln:6m3;6lo:6m4;6lp:6m5;6lq:6m6;6lr:6m7;6mb:6mc;792:79s")
  b.write(";793:79t;794:79u;795:79v;796:79w;797:79x;798:79y;799:79z;79a:7a0;79b:7a1;79c:7a2;79d:7a3;79e:7a4;79f:7a5;79g:7a6;79h:7a7")
  b.write(";79i:7a8;79j:7a9;79k:7aa;79l:7ab;79m:7ac;79n:7ad;79o:7ae;79p:7af;79q:7ag;79r:7ah;8ow:8q8;8ox:8q9;8oy:8qa;8oz:8qb;8p0:8qc")
  b.write(";8p1:8qd;8p2:8qe;8p3:8qf;8p4:8qg;8p5:8qh;8p6:8qi;8p7:8qj;8p8:8qk;8p9:8ql;8pa:8qm;8pb:8qn;8pc:8qo;8pd:8qp;8pe:8qq;8pf:8qr")
  b.write(";8pg:8qs;8ph:8qt;8pi:8qu;8pj:8qv;8pk:8qw;8pl:8qx;8pm:8qy;8pn:8qz;8po:8r0;8pp:8r1;8pq:8r2;8pr:8r3;8ps:8r4;8pt:8r5;8pu:8r6")
  b.write(";8pv:8r7;8pw:8r8;8px:8r9;8py:8ra;8pz:8rb;8q0:8rc;8q1:8rd;8q2:8re;8q3:8rf;8q4:8rg;8q5:8rh;8q6:8ri;8q7:8rj;8rk:8rl;8rm:h7;")
  b.write("8rn:5tp;8ro:hp;8rr:8rs;8rt:8ru;8rv:8rw;8rx:gh;8ry:hd;8rz:gg;8s0:gi;8s2:8s3;8s5:8s6;8se:fz;8sf:g0;8sg:8sh;8si:8sj;8sk:8sl")
  b.write(";8sm:8sn;8so:8sp;8sq:8sr;8ss:8st;8su:8sv;8sw:8sx;8sy:8sz;8t0:8t1;8t2:8t3;8t4:8t5;8t6:8t7;8t8:8t9;8ta:8tb;8tc:8td;8te:8tf")
  b.write(";8tg:8th;8ti:8tj;8tk:8tl;8tm:8tn;8to:8tp;8tq:8tr;8ts:8tt;8tu:8tv;8tw:8tx;8ty:8tz;8u0:8u1;8u2:8u3;8u4:8u5;8u6:8u7;8u8:8u9")
  b.write(";8ua:8ub;8uc:8ud;8ue:8uf;8ug:8uh;8ui:8uj;8uk:8ul;8um:8un;8uo:8up;8uq:8ur;8us:8ut;8uu:8uv;8uw:8ux;8uy:8uz;8v0:8v1;8v2:8v3")
  b.write(";8v4:8v5;8v6:8v7;8vf:8vg;8vh:8vi;8vm:8vn;wu8:wu9;wua:wub;wuc:wud;wue:wuf;wug:wuh;wui:wuj;wuk:wul;wum:wun;wuo:wup;wuq:wur")
  b.write(";wus:wut;wuu:wuv;wuw:wux;wuy:wuz;wv0:wv1;wv2:wv3;wv4:wv5;wv6:wv7;wv8:wv9;wva:wvb;wvc:wvd;wve:wvf;wvg:wvh;ww0:ww1;ww2:ww3")
  b.write(";ww4:ww5;ww6:ww7;ww8:ww9;wwa:wwb;wwc:wwd;wwe:wwf;wwg:wwh;wwi:wwj;wwk:wwl;wwm:wwn;wwo:wwp;wwq:wwr;x0i:x0j;x0k:x0l;x0m:x0n")
  b.write(";x0o:x0p;x0q:x0r;x0s:x0t;x0u:x0v;x0y:x0z;x10:x11;x12:x13;x14:x15;x16:x17;x18:x19;x1a:x1b;x1c:x1d;x1e:x1f;x1g:x1h;x1i:x1j")
  b.write(";x1k:x1l;x1m:x1n;x1o:x1p;x1q:x1r;x1s:x1t;x1u:x1v;x1w:x1x;x1y:x1z;x20:x21;x22:x23;x24:x25;x26:x27;x28:x29;x2a:x2b;x2c:x2d")
  b.write(";x2e:x2f;x2g:x2h;x2i:x2j;x2k:x2l;x2m:x2n;x2x:x2y;x2z:x30;x31:5tl;x32:x33;x34:x35;x36:x37;x38:x39;x3a:x3b;x3f:x3g;x3h:h1;")
  b.write("x3k:x3l;x3m:x3n;x3q:x3r;x3s:x3t;x3u:x3v;x3w:x3x;x3y:x3z;x40:x41;x42:x43;x44:x45;x46:x47;x48:x49;x4a:h2;x4b:gs;x4c:gx;x4d")
  b.write(":h8;x4e:h6;x4g:im;x4h:hz;x4i:il;x4j:xub;x4k:x4l;x4m:x4n;x4o:x4p;x4q:x4r;x4s:x4t;x4u:x4v;x4w:x4x;x4y:x4z;x50:x3o;x51:hu;x")
  b.write("52:5u6;x53:x54;x55:x56;x5c:x5d;x5i:x5j;x5k:x5l;x6d:x6e;xv4:3vk;xv5:3vl;xv6:3vm;xv7:3vn;xv8:3vo;xv9:3vp;xva:3vq;xvb:3vr;x")
  b.write("vc:3vs;xvd:3vt;xve:3vu;xvf:3vv;xvg:3vw;xvh:3vx;xvi:3vy;xvj:3vz;xvk:3w0;xvl:3w1;xvm:3w2;xvn:3w3;xvo:3w4;xvp:3w5;xvq:3w6;x")
  b.write("vr:3w7;xvs:3w8;xvt:3w9;xvu:3wa;xvv:3wb;xvw:3wc;xvx:3wd;xvy:3we;xvz:3wf;xw0:3wg;xw1:3wh;xw2:3wi;xw3:3wj;xw4:3wk;xw5:3wl;x")
  b.write("w6:3wm;xw7:3wn;xw8:3wo;xw9:3wp;xwa:3wq;xwb:3wr;xwc:3ws;xwd:3wt;xwe:3wu;xwf:3wv;xwg:3ww;xwh:3wx;xwi:3wy;xwj:3wz;xwk:3x0;x")
  b.write("wl:3x1;xwm:3x2;xwn:3x3;xwo:3x4;xwp:3x5;xwq:3x6;xwr:3x7;xws:3x8;xwt:3x9;xwu:3xa;xwv:3xb;xww:3xc;xwx:3xd;xwy:3xe;xwz:3xf;x")
  b.write("x0:3xg;xx1:3xh;xx2:3xi;xx3:3xj;xx4:3xk;xx5:3xl;xx6:3xm;xx7:3xn;xx8:3xo;xx9:3xp;xxa:3xq;xxb:3xr;1dkw:2u,2u;1dkx:2u,2x;1dk")
  b.write("y:2u,30;1dkz:2u,2u,2x;1dl0:2u,2u,30;1dl1:37,38;1dl2:37,38;1dlf:12s,12u;1dlg:12s,12d;1dlh:12s,12j;1dli:132,12u;1dlj:12s,1")
  b.write("2l;1ee9:1ef5;1eea:1ef6;1eeb:1ef7;1eec:1ef8;1eed:1ef9;1eee:1efa;1eef:1efb;1eeg:1efc;1eeh:1efd;1eei:1efe;1eej:1eff;1eek:1e")
  b.write("fg;1eel:1efh;1eem:1efi;1een:1efj;1eeo:1efk;1eep:1efl;1eeq:1efm;1eer:1efn;1ees:1efo;1eet:1efp;1eeu:1efq;1eev:1efr;1eew:1e")
  b.write("fs;1eex:1eft;1eey:1efu;1fcw:1fe0;1fcx:1fe1;1fcy:1fe2;1fcz:1fe3;1fd0:1fe4;1fd1:1fe5;1fd2:1fe6;1fd3:1fe7;1fd4:1fe8;1fd5:1f")
  b.write("e9;1fd6:1fea;1fd7:1feb;1fd8:1fec;1fd9:1fed;1fda:1fee;1fdb:1fef;1fdc:1feg;1fdd:1feh;1fde:1fei;1fdf:1fej;1fdg:1fek;1fdh:1f")
  b.write("el;1fdi:1fem;1fdj:1fen;1fdk:1feo;1fdl:1fep;1fdm:1feq;1fdn:1fer;1fdo:1fes;1fdp:1fet;1fdq:1feu;1fdr:1fev;1fds:1few;1fdt:1f")
  b.write("ex;1fdu:1fey;1fdv:1fez;1fdw:1ff0;1fdx:1ff1;1fdy:1ff2;1fdz:1ff3;1fhs:1fiw;1fht:1fix;1fhu:1fiy;1fhv:1fiz;1fhw:1fj0;1fhx:1f")
  b.write("j1;1fhy:1fj2;1fhz:1fj3;1fi0:1fj4;1fi1:1fj5;1fi2:1fj6;1fi3:1fj7;1fi4:1fj8;1fi5:1fj9;1fi6:1fja;1fi7:1fjb;1fi8:1fjc;1fi9:1f")
  b.write("jd;1fia:1fje;1fib:1fjf;1fic:1fjg;1fid:1fjh;1fie:1fji;1fif:1fjj;1fig:1fjk;1fih:1fjl;1fii:1fjm;1fij:1fjn;1fik:1fjo;1fil:1f")
  b.write("jp;1fim:1fjq;1fin:1fjr;1fio:1fjs;1fip:1fjt;1fiq:1fju;1fir:1fjv;1fn4:1fo7;1fn5:1fo8;1fn6:1fo9;1fn7:1foa;1fn8:1fob;1fn9:1f")
  b.write("oc;1fna:1fod;1fnb:1foe;1fnc:1fof;1fnd:1fog;1fne:1foh;1fng:1foj;1fnh:1fok;1fni:1fol;1fnj:1fom;1fnk:1fon;1fnl:1foo;1fnm:1f")
  b.write("op;1fnn:1foq;1fno:1for;1fnp:1fos;1fnq:1fot;1fnr:1fou;1fns:1fov;1fnt:1fow;1fnu:1fox;1fnw:1foz;1fnx:1fp0;1fny:1fp1;1fnz:1f")
  b.write("p2;1fo0:1fp3;1fo1:1fp4;1fo2:1fp5;1fo4:1fp7;1fo5:1fp8;1h1c:1h34;1h1d:1h35;1h1e:1h36;1h1f:1h37;1h1g:1h38;1h1h:1h39;1h1i:1h")
  b.write("3a;1h1j:1h3b;1h1k:1h3c;1h1l:1h3d;1h1m:1h3e;1h1n:1h3f;1h1o:1h3g;1h1p:1h3h;1h1q:1h3i;1h1r:1h3j;1h1s:1h3k;1h1t:1h3l;1h1u:1h")
  b.write("3m;1h1v:1h3n;1h1w:1h3o;1h1x:1h3p;1h1y:1h3q;1h1z:1h3r;1h20:1h3s;1h21:1h3t;1h22:1h3u;1h23:1h3v;1h24:1h3w;1h25:1h3x;1h26:1h")
  b.write("3y;1h27:1h3z;1h28:1h40;1h29:1h41;1h2a:1h42;1h2b:1h43;1h2c:1h44;1h2d:1h45;1h2e:1h46;1h2f:1h47;1h2g:1h48;1h2h:1h49;1h2i:1h")
  b.write("4a;1h2j:1h4b;1h2k:1h4c;1h2l:1h4d;1h2m:1h4e;1h2n:1h4f;1h2o:1h4g;1h2p:1h4h;1h2q:1h4i;1jfk:1jgg;1jfl:1jgh;1jfm:1jgi;1jfn:1j")
  b.write("gj;1jfo:1jgk;1jfp:1jgl;1jfq:1jgm;1jfr:1jgn;1jfs:1jgo;1jft:1jgp;1jfu:1jgq;1jfv:1jgr;1jfw:1jgs;1jfx:1jgt;1jfy:1jgu;1jfz:1j")
  b.write("gv;1jg0:1jgw;1jg1:1jgx;1jg2:1jgy;1jg3:1jgz;1jg4:1jh0;1jg5:1jh1;1jg6:1jh2;1jg7:1jh3;1jg8:1jh4;1jg9:1jh5;1jga:1jh6;1jgb:1j")
  b.write("h7;1jgc:1jh8;1jgd:1jh9;1jge:1jha;1jgf:1jhb;20cg:20dc;20ch:20dd;20ci:20de;20cj:20df;20ck:20dg;20cl:20dh;20cm:20di;20cn:20")
  b.write("dj;20co:20dk;20cp:20dl;20cq:20dm;20cr:20dn;20cs:20do;20ct:20dp;20cu:20dq;20cv:20dr;20cw:20ds;20cx:20dt;20cy:20du;20cz:20")
  b.write("dv;20d0:20dw;20d1:20dx;20d2:20dy;20d3:20dz;20d4:20e0;20d5:20e1;20d6:20e2;20d7:20e3;20d8:20e4;20d9:20e5;20da:20e6;20db:20")
  b.write("e7;2olc:2oma;2old:2omb;2ole:2omc;2olf:2omd;2olg:2ome;2olh:2omf;2oli:2omg;2olj:2omh;2olk:2omi;2oll:2omj;2olm:2omk;2oln:2o")
  b.write("ml;2olo:2omm;2olp:2omn;2olq:2omo;2olr:2omp;2ols:2omq;2olt:2omr;2olu:2oms;2olv:2omt;2olw:2omu;2olx:2omv;2oly:2omw;2olz:2o")
  b.write("mx;2om0:2omy;2om1:2omz;2om2:2on0;2om3:2on1;2om4:2on2;2om5:2on3;2om6:2on4;2om7:2on5;2om8:2on6;2om9:2on7")
  return b.toString()

_uExtendRaw() -> String:
  b = StringBuffer()
  b.write("lc,33;w3,6;13l,18;14v,0;14x,1;150,1;153,0;174,a;18r,k;19s,0;1cm,6;1cv,5;1d3,1;1d6,3;1e9,0;1f4,q;1ie,a;1kb,8;1kt,0;1li,3;")
  b.write("1ln,8;1lx,2;1m1,4;1nd,2;1p4,7;1qi,n;1r7,v;1tm,0;1to,0;1tt,7;1u5,0;1u9,6;1uq,1;1vl,0;1x8,0;1xd,3;1xp,0;1ya,1;1z2,0;1z5,1;")
  b.write("20s,0;20x,1;213,1;217,2;21d,0;228,1;22d,0;22p,1;24c,0;24h,4;24n,1;24t,0;25e,1;262,5;269,0;27w,0;27z,0;281,3;28d,0;28l,1;")
  b.write("28y,1;29u,0;2bk,0;2bx,0;2dc,0;2dg,0;2f0,0;2f2,2;2fa,2;2fe,3;2fp,1;2g2,1;2gx,0;2ik,0;2in,0;2iu,0;2j0,1;2jm,1;2kg,1;2m3,1;")
  b.write("2m9,3;2ml,0;2n6,1;2o1,0;2q2,0;2qa,2;2qe,0;2sx,0;2t0,6;2tj,7;2wh,0;2wk,8;2x4,6;2zc,1;305,0;307,0;309,0;31t,d;328,4;32e,1;")
  b.write("32l,a;32x,z;346,0;371,3;376,5;37d,1;37h,1;388,1;38e,2;38x,3;39e,0;39h,1;39p,0;3a5,0;3tp,2;4k2,2;4ky,1;4lu,1;4mq,1;4ok,1;")
  b.write("4on,6;4p2,0;4p5,a;4pp,0;4qz,2;4r3,0;4ud,1;4vd,0;4yo,2;4yv,1;4z6,0;4zd,2;55j,1;55n,0;57a,0;57c,6;57k,0;57m,0;57p,7;583,9;")
  b.write("58f,0;59s,u;5c0,3;5dg,0;5di,4;5do,0;5du,0;5ez,8;5fk,1;5gi,3;5go,1;5gr,2;5ie,0;5ig,1;5il,0;5in,2;5kc,7;5km,1;5ow,2;5p0,c;")
  b.write("5pe,6;5pp,0;5pw,0;5q0,1;5vk,1r;6bw,0;6hc,w;8vj,2;8zj,0;928,v;9ii,3;9ll,1;wvj,3;wvo,9;wwu,1;wz4,1;x6q,0;x6u,0;x6z,0;x7p,1")
  b.write(";x7w,0;xc4,1;xcw,h;xdr,0;xeu,7;xfr,a;xhc,2;xir,0;xiu,3;xj0,1;xk5,0;xm1,5;xm9,1;xmd,1;xmr,0;xn0,0;xoc,0;xps,0;xpu,2;xpz,1")
  b.write(";xq6,1;xq9,0;xrg,1;xrq,0;xyd,0;xyg,0;xyl,0;1dlq,0;1e68,f;1e74,f;1ehq,1;1eyl,0;1f4w,0;1f92,4;1gjl,2;1gjp,1;1gjw,3;1gl4,2;")
  b.write("1glb,0;1gpx,1;1h5w,3;1hgr,1;1hj1,2;1hl2,a;1hmq,3;1hq9,0;1hrs,e;1htc,0;1htf,1;1htr,2;1hv7,3;1hvd,1;1hvm,0;1hxc,2;1hyf,4;1")
  b.write("hyl,7;1i0j,0;1i0w,1;1i2e,8;1i2x,3;1i33,0;1i5r,2;1i5w,0;1i5y,1;1i66,0;1i69,0;1ian,0;1iar,7;1ibk,1;1id7,1;1idc,0;1iee,6;1i")
  b.write("eo,4;1ik8,7;1iki,2;1ikm,0;1ila,0;1inn,5;1inu,0;1inz,1;1io2,1;1iuq,3;1iv0,1;1iv3,1;1ivw,1;1iyb,7;1iyl,0;1iyn,1;1j1n,0;1j1")
  b.write("p,0;1j1s,5;1j1z,0;1j4t,2;1j4y,3;1j53,4;1jcf,8;1jcp,1;1jjv,1;1jjy,0;1jk3,0;1jo4,3;1joa,1;1jog,0;1jpd,9;1jqr,5;1jqz,3;1jrb")
  b.write(",0;1jrl,5;1jrt,2;1jt6,c;1jtk,1;1k4w,6;1k54,5;1k5b,0;1k7m,l;1k8a,6;1k8i,1;1k8l,1;1kc1,5;1kca,0;1kcc,1;1kcf,6;1kcn,0;1keo,")
  b.write("1;1ket,0;1kev,0;1koj,1;1kow,1;1kqe,4;1kqo,0;1kqq,0;1ow0,0;1ow7,e;1zow,4;1zqo,6;20jz,0;20lr,3;20o4,0;2ftp,1;2jgg,19;2jhs,")
  b.write("m;2jxj,2;2jy3,7;2jyd,6;2jze,3;2k3m,2;2lmo,1i;2lob,1d;2lpx,0;2lqc,0;2lqz,4;2lr5,e;2mtc,6;2mtk,g;2mu3,6;2mub,1;2mue,4;2mxb")
  b.write(",0;2n1s,6;2nce,0;2ne4,3;2nsc,3;2ok0,6;2on8,6;2qrf,4;jnz4,2n;jo5c,6n")
  return b.toString()

_uSpacingRaw() -> String:
  b = StringBuffer()
  b.write("1s3,0;1tn,0;1tq,2;1u1,3;1u6,1;1vm,1;1xa,2;1xj,1;1xn,1;1xz,0;1z7,0;20u,2;22r,0;24e,2;24p,0;24r,1;26a,1;27y,0;280,0;287,1;")
  b.write("28b,1;28n,0;2bi,1;2bl,1;2bq,2;2bu,2;2c7,0;2dd,2;2f5,3;2gy,1;2im,0;2io,4;2iv,1;2iy,1;2j9,1;2k3,0;2ki,1;2m6,2;2me,2;2mi,2;")
  b.write("2mv,0;2o2,1;2q7,2;2qg,7;2r6,1;30e,1;327,0;36z,1;375,0;37c,0;37f,1;386,1;38i,2;38n,6;39f,1;39j,5;39r,0;3a2,2;4k5,0;4l0,0;")
  b.write("4om,0;4ou,7;4p3,1;4yr,3;4yx,2;4z4,1;4z7,5;55l,1;579,0;57b,0;57l,0;57n,1;57x,5;5c4,0;5dh,0;5dn,0;5dp,4;5dv,1;5fm,0;5gh,0;")
  b.write("5gm,1;5gq,0;5if,0;5ii,2;5im,0;5iq,1;5k4,7;5kk,1;5pd,0;5pz,0;9im,1;x7n,1;x7r,0;xa8,1;xbo,f;xg2,1;xhf,0;xis,1;xiy,1;xj2,2;")
  b.write("xm7,1;xmb,1;xn1,0;xob,0;xod,0;xrf,0;xri,1;xrp,0;xyb,1;xye,1;xyh,1;xyk,0;1hq8,0;1hqa,0;1htu,0;1hv4,2;1hvb,1;1hyk,0;1hz9,1")
  b.write(";1i0y,0;1i2b,2;1i2n,1;1i32,0;1i5o,2;1i5u,1;1i5x,0;1iao,2;1ibm,1;1ida,1;1idd,3;1idj,1;1idn,2;1idz,0;1iea,1;1ik5,2;1ikg,1;")
  b.write("1ikl,0;1ink,2;1int,0;1inv,3;1io1,0;1iun,2;1iuw,3;1iv2,0;1iy8,2;1iyj,1;1iym,0;1j1o,0;1j1q,1;1j1y,0;1j4w,1;1j52,0;1jcc,2;1")
  b.write("jco,0;1jjk,5;1jjr,1;1jjx,0;1jk0,0;1jk2,0;1jo1,2;1joc,3;1jok,0;1jqx,0;1jrr,1;1jtj,0;1k4v,0;1k5a,0;1k89,0;1k8h,0;1k8k,0;1k")
  b.write("ei,4;1ker,1;1keu,0;1kol,1;1koz,0;1kqc,1;1kqm,1;1kqp,0;20k1,1i;20og,1;2jxh,1;2jxp,5")
  return b.toString()

# END GENERATED UNICODE DATA
''';

/// Source of `quds:collection`. Kept equal to `lib/sdk/collection.quds`.
const collectionSdkSource = r'''# General-purpose collections and data structures library for Quds.
#
# A column-0 :: name opens a section. use quds:collection::query imports that
# section and any subsection under it. use quds:collection imports every public name.
# Example:
#   use quds:collection::transform as col
#   print col.chunkList([1, 2, 3, 4, 5], 2)

:: types

# An item paired with its zero-based index in a sequence.
# Example:
#   entry = IndexedValue<String>(index: 0, value: "a")
#   print entry.index
class IndexedValue<T>:
  index: int required
  value: T required

  # Human-readable representation of this indexed entry.
  # Example:
  #   print IndexedValue<int>(index: 1, value: 42).toString()
  toString() -> String = "IndexedValue({index}: {value})"

# A typed two-element pair returned by zip, unzip, and map helpers.
# Example:
#   pair = CollectionPair<String, int>(first: "a", second: 1)
#   print pair.first
class CollectionPair<A, B>:
  first: A required
  second: B required

  # Human-readable representation of this pair.
  # Example:
  #   print CollectionPair<int, String>(first: 1, second: "x").toString()
  toString() -> String = "CollectionPair({first}, {second})"

# The result of splitting items into matching and non-matching lists.
# Example:
#   parts = partitionList([1, 2, 3, 4], (n: int) -> n % 2 == 0)
#   print parts.matching
class PartitionResult<T>:
  matching: List<T> required
  nonMatching: List<T> required

  # Human-readable representation of this partition result.
  # Example:
  #   print PartitionResult<int>(matching: [2], nonMatching: [1]).toString()
  toString() -> String = "PartitionResult(matching: {matching.length}, nonMatching: {nonMatching.length})"

# The minimum and maximum elements computed in a single pass.
# Example:
#   bounds = minMaxBy([3, 1, 4], (a: int, b: int) -> a.compareTo(b))
#   if bounds != null: print bounds.minimum
class MinMaxResult<T>:
  minimum: T required
  maximum: T required

  # Human-readable representation of this min/max result.
  # Example:
  #   print MinMaxResult<int>(minimum: 1, maximum: 5).toString()
  toString() -> String = "MinMaxResult(min: {minimum}, max: {maximum})"

# Policy controlling how mergeMaps resolves duplicate keys.
# Example:
#   policy = MapConflictPolicy.keepLast
enum MapConflictPolicy:
  keepFirst
  keepLast
  fail

# Structural difference between two sets.
# Example:
#   d = SetDiff<int>(added: set: 3, removed: set: 1, common: set: 2)
#   print d.added
class SetDiff<T>:
  added: Set<T> required
  removed: Set<T> required
  common: Set<T> required

  # True when both sets contain the exact same elements.
  # Example:
  #   print diff.isEmpty
  property isEmpty: bool:
    get = added.isEmpty and removed.isEmpty

# Structural difference between two maps.
# Example:
#   print diff.changed
class MapDiff<K, V>:
  added: Map<K, V> required
  removed: Map<K, V> required
  changed: Map<K, CollectionPair<V, V>> required
  unchanged: Map<K, V> required

  # True when both maps have identical keys and equal values.
  # Example:
  #   print diff.isEmpty
  property isEmpty: bool:
    get = added.isEmpty and removed.isEmpty and changed.isEmpty

# Operation kind for a single entry in a sequence diff.
# Example:
#   kind = ListDiffOp.insert
enum ListDiffOp:
  keep
  insert
  delete

# A contiguous diff step comparing two lists.
# Example:
#   step = ListDiffStep<String>(op: ListDiffOp.keep, value: "a")
class ListDiffStep<T>:
  op: ListDiffOp required
  value: T required

  # Human-readable representation of this diff step.
  # Example:
  #   print step.toString()
  toString() -> String = "ListDiffStep({op.name}: {value})"

# Error thrown when a collection operation violates an explicit contract
# (for example, duplicate keys with MapConflictPolicy.fail or invalid bounds).
# Example:
#   throw CollectionError("mergeMaps", "Duplicate key")
class CollectionError:
  operation: String required
  message: String required

  # Human-readable description of this error.
  # Example:
  #   print CollectionError("chunkList", "size must be positive").toString()
  toString() -> String = "CollectionError({operation}): {message}"


:: query

# Returns the first element of [items], or null when [items] is empty.
# Example:
#   print firstOrNull([10, 20])
firstOrNull<T>(items: Iterable<T>) -> T?:
  for item in items:
    return item
  return null

# Returns the last element of [items], or null when [items] is empty.
# Example:
#   print lastOrNull([10, 20])
lastOrNull<T>(items: Iterable<T>) -> T?:
  var found = false
  var latest: T? = null
  for item in items:
    found = true
    latest = item
  if not found:
    return null
  return latest

# Returns the single element of [items], or null when [items] is empty or has
# more than one element.
# Example:
#   print singleOrNull([42])
singleOrNull<T>(items: Iterable<T>) -> T?:
  var count = 0
  var only: T? = null
  for item in items:
    count = count + 1
    if count > 1:
      return null
    only = item
  if count != 1:
    return null
  return only

# Returns the first element in [items] that satisfies [test], or null if none.
# Example:
#   print firstWhereOrNull([1, 2, 3], (n: int) -> n > 1)
firstWhereOrNull<T>(items: Iterable<T>, test: (T) -> bool) -> T?:
  for item in items:
    if test(item):
      return item
  return null

# Returns the last element in [items] that satisfies [test], or null if none.
# Example:
#   print lastWhereOrNull([1, 2, 3, 4], (n: int) -> n % 2 == 0)
lastWhereOrNull<T>(items: Iterable<T>, test: (T) -> bool) -> T?:
  var matched = false
  var latest: T? = null
  for item in items:
    if test(item):
      matched = true
      latest = item
  if not matched:
    return null
  return latest

# Returns the element at zero-based [index] in [items], or null when [index]
# is negative or out of bounds.
# Example:
#   print elementAtOrNull(["a", "b"], 1)
elementAtOrNull<T>(items: List<T>, index: int) -> T?:
  if index < 0 or index >= items.length:
    return null
  return items[index]

# Returns the first index at or after [start] where [test] holds, or -1.
# Throws RangeError if [start] is negative or greater than items.length.
# Example:
#   print indexWhereFrom([1, 2, 3, 2], (n: int) -> n == 2, start: 2)
indexWhereFrom<T>(items: List<T>, test: (T) -> bool, start: int = 0) -> int:
  if start < 0 or start > items.length:
    throw RangeError.range(start, 0, items.length, "start")
  var i = start
  while i < items.length:
    if test(items[i]):
      return i
    i = i + 1
  return -1

# Returns the last index at or before [start] where [test] holds, or -1.
# When [start] is null, searches from the last element.
# Example:
#   print lastIndexWhereFrom([1, 2, 3, 2], (n: int) -> n == 2, start: 2)
lastIndexWhereFrom<T>(items: List<T>, test: (T) -> bool, start: int? = null) -> int:
  if items.isEmpty:
    if start != null and (start < 0 or start > 0):
      throw RangeError.range(start, 0, 0, "start")
    return -1
  var i = items.length - 1
  if start != null:
    i = start
  if i < 0 or i >= items.length:
    throw RangeError.range(i, 0, items.length - 1, "start")
  while i >= 0:
    if test(items[i]):
      return i
    i = i - 1
  return -1

# Counts how many elements in [items] satisfy [test].
# Example:
#   print countWhere([1, 2, 3, 4], (n: int) -> n % 2 == 0)
countWhere<T>(items: Iterable<T>, test: (T) -> bool) -> int:
  var total = 0
  for item in items:
    if test(item):
      total = total + 1
  return total

# True when no element in [items] satisfies [test] (vacuously true when empty).
# Example:
#   print noneMatch([1, 3, 5], (n: int) -> n % 2 == 0)
noneMatch<T>(items: Iterable<T>, test: (T) -> bool) -> bool:
  for item in items:
    if test(item):
      return false
  return true

# True when every element in [items] equals the first (true for 0 or 1 items).
# Example:
#   print allEqual([7, 7, 7])
allEqual<T>(items: Iterable<T>) -> bool:
  var hasFirst = false
  var expected: T? = null
  for item in items:
    if not hasFirst:
      hasFirst = true
      expected = item
    else if item != expected:
      return false
  return true

# True when [items] is non-decreasing according to [compare].
# When [strict] is true, adjacent elements must strictly increase.
# Example:
#   print isListSorted([1, 2, 2, 5], (a: int, b: int) -> a.compareTo(b))
isListSorted<T>(items: List<T>, compare: (T, T) -> int, strict: bool = false) -> bool:
  var i = 1
  while i < items.length:
    cmp = compare(items[i - 1], items[i])
    if strict:
      if cmp >= 0:
        return false
    else:
      if cmp > 0:
        return false
    i = i + 1
  return true

# Returns the minimum element of [items] according to [compare], or null when
# [items] is empty. Ties keep the earliest element.
# Example:
#   print minBy(["pear", "fig", "apple"], (a: String, b: String) -> a.length.compareTo(b.length))
minBy<T>(items: Iterable<T>, compare: (T, T) -> int) -> T?:
  var found = false
  var best: T? = null
  for item in items:
    if not found:
      found = true
      best = item
    else:
      current = best as T
      if compare(item, current) < 0:
        best = item
  if not found:
    return null
  return best

# Returns the maximum element of [items] according to [compare], or null when
# [items] is empty. Ties keep the earliest element.
# Example:
#   print maxBy(["pear", "fig", "apple"], (a: String, b: String) -> a.length.compareTo(b.length))
maxBy<T>(items: Iterable<T>, compare: (T, T) -> int) -> T?:
  var found = false
  var best: T? = null
  for item in items:
    if not found:
      found = true
      best = item
    else:
      current = best as T
      if compare(item, current) > 0:
        best = item
  if not found:
    return null
  return best

# Computes both minimum and maximum elements of [items] in one pass, or null
# when [items] is empty. Ties keep the earliest element.
# Example:
#   print minMaxBy([3, 1, 4, 1], (a: int, b: int) -> a.compareTo(b))
minMaxBy<T>(items: Iterable<T>, compare: (T, T) -> int) -> MinMaxResult<T>?:
  var found = false
  var lo: T? = null
  var hi: T? = null
  for item in items:
    if not found:
      found = true
      lo = item
      hi = item
    else:
      if compare(item, lo as T) < 0:
        lo = item
      if compare(item, hi as T) > 0:
        hi = item
  if not found:
    return null
  return MinMaxResult<T>(minimum: lo as T, maximum: hi as T)


:: transform

# Pairs each element of [items] with its zero-based index.
# Example:
#   print indexedValues(["a", "b"])
indexedValues<T>(items: Iterable<T>) -> List<IndexedValue<T>>:
  out: List<IndexedValue<T>> = []
  var idx = 0
  for item in items:
    out.add(IndexedValue<T>(index: idx, value: item))
    idx = idx + 1
  return out

# Splits [items] into contiguous chunks of length [size]. The final chunk may
# be shorter. Throws CollectionError if [size] is less than 1.
# Example:
#   print chunkList([1, 2, 3, 4, 5], 2)
chunkList<T>(items: List<T>, size: int) -> List<List<T>>:
  if size < 1:
    throw CollectionError("chunkList", "Chunk size must be at least 1, got {size}")
  out: List<List<T>> = []
  var i = 0
  while i < items.length:
    var end = i + size
    if end > items.length:
      end = items.length
    row: List<T> = []
    var j = i
    while j < end:
      row.add(items[j])
      j = j + 1
    out.add(row)
    i = end
  return out

# Returns sliding windows of length [size] advancing by [step]. When [partial]
# is true, trailing shorter windows are included. Throws CollectionError if
# [size] < 1 or [step] < 1.
# Example:
#   print windowList([1, 2, 3, 4], 2)
windowList<T>(items: List<T>, size: int, step: int = 1, partial: bool = false) -> List<List<T>>:
  if size < 1:
    throw CollectionError("windowList", "Window size must be at least 1, got {size}")
  if step < 1:
    throw CollectionError("windowList", "Window step must be at least 1, got {step}")
  out: List<List<T>> = []
  var i = 0
  while i < items.length:
    var end = i + size
    if end > items.length:
      if not partial:
        break
      end = items.length
    row: List<T> = []
    var j = i
    while j < end:
      row.add(items[j])
      j = j + 1
    out.add(row)
    i = i + step
  return out

# Splits [items] into elements matching [test] and elements not matching [test],
# preserving original relative order in both lists.
# Example:
#   parts = partitionList([1, 2, 3, 4], (n: int) -> n % 2 == 0)
partitionList<T>(items: Iterable<T>, test: (T) -> bool) -> PartitionResult<T>:
  yes: List<T> = []
  no: List<T> = []
  for item in items:
    if test(item):
      yes.add(item)
    else:
      no.add(item)
  return PartitionResult<T>(matching: yes, nonMatching: no)

# Groups [items] into lists keyed by [keyOf], preserving insertion order of
# keys and element order within each group.
# Example:
#   groups = groupBy(["ant", "ape", "bat"], (s: String) -> s[0])
groupBy<T, K>(items: Iterable<T>, keyOf: (T) -> K) -> Map<K, List<T>>:
  out: Map<K, List<T>> = map:
  for item in items:
    key = keyOf(item)
    existing = out[key]
    if existing == null:
      bucket: List<T> = [item]
      out[key] = bucket
    else:
      existing.add(item)
  return out

# Groups [items] by [keyOf] and folds each group starting from [initial] using
# [combine].
# Example:
#   sums = groupFold([1, 2, 3, 4], (n: int) -> n % 2, 0, (acc: int, n: int) -> acc + n)
groupFold<T, K, R>(items: Iterable<T>, keyOf: (T) -> K, initial: R, combine: (R, T) -> R) -> Map<K, R>:
  out: Map<K, R> = map:
  for item in items:
    key = keyOf(item)
    if out.containsKey(key):
      prev = out[key] as R
      out[key] = combine(prev, item)
    else:
      out[key] = combine(initial, item)
  return out

# Builds a map keyed by [keyOf]. When duplicate keys appear, [onConflict]
# controls whether the first value wins, the last value wins (default), or
# CollectionError is thrown.
# Example:
#   byId = associateBy(["a", "bb"], (s: String) -> s.length)
associateBy<T, K>(items: Iterable<T>, keyOf: (T) -> K, onConflict: MapConflictPolicy = MapConflictPolicy.keepLast) -> Map<K, T>:
  out: Map<K, T> = map:
  for item in items:
    key = keyOf(item)
    if out.containsKey(key):
      if onConflict == MapConflictPolicy.keepFirst:
        continue
      if onConflict == MapConflictPolicy.fail:
        throw CollectionError("associateBy", "Duplicate key: {key}")
    out[key] = item
  return out

# Combines [left] and [right] element-by-element into pairs up to the length
# of the shorter list.
# Example:
#   print zipLists([1, 2], ["a", "b", "c"])
zipLists<A, B>(left: List<A>, right: List<B>) -> List<CollectionPair<A, B>>:
  var limit = left.length
  if right.length < limit:
    limit = right.length
  out: List<CollectionPair<A, B>> = []
  var i = 0
  while i < limit:
    out.add(CollectionPair<A, B>(first: left[i], second: right[i]))
    i = i + 1
  return out

# Separates a sequence of pairs into a pair of parallel lists.
# Example:
#   unpacked = unzipPairs([CollectionPair<int, String>(first: 1, second: "a")])
unzipPairs<A, B>(pairs: Iterable<CollectionPair<A, B>>) -> CollectionPair<List<A>, List<B>>:
  firsts: List<A> = []
  seconds: List<B> = []
  for pair in pairs:
    firsts.add(pair.first)
    seconds.add(pair.second)
  return CollectionPair<List<A>, List<B>>(first: firsts, second: seconds)

# Flattens one level of nested iterables into a single list.
# Example:
#   print flattenOnce([[1, 2], [3]])
flattenOnce<T>(nested: Iterable<Iterable<T>>) -> List<T>:
  out: List<T> = []
  for inner in nested:
    for item in inner:
      out.add(item)
  return out

# Returns elements of [items] keeping only the first occurrence for each key
# returned by [keyOf].
# Example:
#   print distinctBy(["a", "bb", "c"], (s: String) -> s.length)
distinctBy<T, K>(items: Iterable<T>, keyOf: (T) -> K) -> List<T>:
  seen: Set<K> = set:
  out: List<T> = []
  for item in items:
    key = keyOf(item)
    if not seen.contains(key):
      seen.add(key)
      out.add(item)
  return out

# Alternates elements from [left] and [right], appending any remaining tail
# from the longer list.
# Example:
#   print interleave([1, 3], [2, 4, 6])
interleave<T>(left: List<T>, right: List<T>) -> List<T>:
  out: List<T> = []
  var i = 0
  while i < left.length or i < right.length:
    if i < left.length:
      out.add(left[i])
    if i < right.length:
      out.add(right[i])
    i = i + 1
  return out

# Inserts [separator] between consecutive elements of [items].
# Example:
#   print intersperse(["a", "b", "c"], "-")
intersperse<T>(items: Iterable<T>, separator: T) -> List<T>:
  out: List<T> = []
  var first = true
  for item in items:
    if not first:
      out.add(separator)
    first = false
    out.add(item)
  return out

# Computes prefix-fold intermediate states starting from [initial]. Always
# begins with [initial], so an empty input returns [initial].
# Example:
#   print scanLeft([1, 2, 3], 0, (acc: int, n: int) -> acc + n)
scanLeft<T, R>(items: Iterable<T>, initial: R, combine: (R, T) -> R) -> List<R>:
  out: List<R> = [initial]
  var acc = initial
  for item in items:
    acc = combine(acc, item)
    out.add(acc)
  return out


:: maps

# Returns a new map whose keys are transformed by [transform]. Duplicate
# target keys follow [onConflict] (default keepLast).
# Example:
#   print mapKeys(map: "a": 1, (k: String) -> k.toUpperCase())
mapKeys<K, V, K2>(source: Map<K, V>, transform: (K) -> K2, onConflict: MapConflictPolicy = MapConflictPolicy.keepLast) -> Map<K2, V>:
  out: Map<K2, V> = map:
  for entry in source.entries:
    nextKey = transform(entry.key)
    if out.containsKey(nextKey):
      if onConflict == MapConflictPolicy.keepFirst:
        continue
      if onConflict == MapConflictPolicy.fail:
        throw CollectionError("mapKeys", "Duplicate mapped key: {nextKey}")
    out[nextKey] = entry.value
  return out

# Returns a new map with the same keys and values transformed by [transform].
# Example:
#   print mapValues(map: "a": 2, (v: int) -> v * 10)
mapValues<K, V, V2>(source: Map<K, V>, transform: (V) -> V2) -> Map<K, V2>:
  out: Map<K, V2> = map:
  for entry in source.entries:
    out[entry.key] = transform(entry.value)
  return out

# Returns a new map containing only entries satisfying [test].
# Example:
#   print filterMap(scores, (k: String, v: int) -> v >= 50)
filterMap<K, V>(source: Map<K, V>, test: (K, V) -> bool) -> Map<K, V>:
  out: Map<K, V> = map:
  for entry in source.entries:
    if test(entry.key, entry.value):
      out[entry.key] = entry.value
  return out

# Returns a new map containing only entries whose key satisfies [test].
# Example:
#   print filterKeys(scores, (k: String) -> k.startsWith("a"))
filterKeys<K, V>(source: Map<K, V>, test: (K) -> bool) -> Map<K, V>:
  out: Map<K, V> = map:
  for entry in source.entries:
    if test(entry.key):
      out[entry.key] = entry.value
  return out

# Returns a new map containing only entries whose value satisfies [test].
# Example:
#   print filterValues(scores, (v: int) -> v > 0)
filterValues<K, V>(source: Map<K, V>, test: (V) -> bool) -> Map<K, V>:
  out: Map<K, V> = map:
  for entry in source.entries:
    if test(entry.value):
      out[entry.key] = entry.value
  return out

# Merges [first] and [second] into a new map, resolving duplicate keys using
# [onConflict] (default keepLast).
# Example:
#   merged = mergeMaps(a, b, onConflict: MapConflictPolicy.keepFirst)
mergeMaps<K, V>(first: Map<K, V>, second: Map<K, V>, onConflict: MapConflictPolicy = MapConflictPolicy.keepLast) -> Map<K, V>:
  out: Map<K, V> = map:
  for entry in first.entries:
    out[entry.key] = entry.value
  for entry in second.entries:
    if out.containsKey(entry.key):
      if onConflict == MapConflictPolicy.keepFirst:
        continue
      if onConflict == MapConflictPolicy.fail:
        throw CollectionError("mergeMaps", "Duplicate key: {entry.key}")
    out[entry.key] = entry.value
  return out

# Merges [first] and [second] into a new map, resolving duplicate keys with
# [combine](firstValue, secondValue).
# Example:
#   merged = mergeMapsWith(a, b, (x: int, y: int) -> x + y)
mergeMapsWith<K, V>(first: Map<K, V>, second: Map<K, V>, combine: (V, V) -> V) -> Map<K, V>:
  out: Map<K, V> = map:
  for entry in first.entries:
    out[entry.key] = entry.value
  for entry in second.entries:
    if out.containsKey(entry.key):
      prev = out[entry.key] as V
      out[entry.key] = combine(prev, entry.value)
    else:
      out[entry.key] = entry.value
  return out

# Swaps keys and values of [source]. Duplicate values follow [onConflict]
# (default keepLast).
# Example:
#   inv = invertMap(codes, onConflict: MapConflictPolicy.fail)
invertMap<K, V>(source: Map<K, V>, onConflict: MapConflictPolicy = MapConflictPolicy.keepLast) -> Map<V, K>:
  out: Map<V, K> = map:
  for entry in source.entries:
    if out.containsKey(entry.value):
      if onConflict == MapConflictPolicy.keepFirst:
        continue
      if onConflict == MapConflictPolicy.fail:
        throw CollectionError("invertMap", "Duplicate value: {entry.value}")
    out[entry.value] = entry.key
  return out

# Swaps keys and values of [source], grouping all original keys sharing a value.
# Example:
#   grouped = invertMapMulti(roles)
invertMapMulti<K, V>(source: Map<K, V>) -> Map<V, List<K>>:
  out: Map<V, List<K>> = map:
  for entry in source.entries:
    bucket = out[entry.value]
    if bucket == null:
      fresh: List<K> = [entry.key]
      out[entry.value] = fresh
    else:
      bucket.add(entry.key)
  return out

# Returns a new map containing only keys present in both [source] and [keys].
# Example:
#   print pickKeys(user, ["id", "name"])
pickKeys<K, V>(source: Map<K, V>, keys: Iterable<K>) -> Map<K, V>:
  out: Map<K, V> = map:
  for key in keys:
    if source.containsKey(key):
      out[key] = source[key] as V
  return out

# Returns a new map containing entries from [source] whose key is not in [keys].
# Example:
#   print omitKeys(user, ["password"])
omitKeys<K, V>(source: Map<K, V>, keys: Iterable<K>) -> Map<K, V>:
  excluded: Set<K> = set:
  for key in keys:
    excluded.add(key)
  out: Map<K, V> = map:
  for entry in source.entries:
    if not excluded.contains(entry.key):
      out[entry.key] = entry.value
  return out

# Returns the value for [key] in [target], inserting and returning [create]()
# if [key] is absent. Handles nullable V accurately via containsKey.
# Example:
#   count = getOrPut(counts, "a", () -> 0)
getOrPut<K, V>(target: Map<K, V>, key: K, create: () -> V) -> V:
  if target.containsKey(key):
    return target[key] as V
  made = create()
  target[key] = made
  return made

# Builds a map from [pairs], resolving duplicate keys with [onConflict].
# Example:
#   m = mapFromPairs([CollectionPair<String, int>(first: "a", second: 1)])
mapFromPairs<K, V>(pairs: Iterable<CollectionPair<K, V>>, onConflict: MapConflictPolicy = MapConflictPolicy.keepLast) -> Map<K, V>:
  out: Map<K, V> = map:
  for pair in pairs:
    if out.containsKey(pair.first):
      if onConflict == MapConflictPolicy.keepFirst:
        continue
      if onConflict == MapConflictPolicy.fail:
        throw CollectionError("mapFromPairs", "Duplicate key: {pair.first}")
    out[pair.first] = pair.second
  return out


:: sets

# Returns elements present in either [first] or [second], but not both.
# Example:
#   print symmetricDifference(a, b)
symmetricDifference<T>(first: Set<T>, second: Set<T>) -> Set<T>:
  out: Set<T> = set:
  for item in first:
    if not second.contains(item):
      out.add(item)
  for item in second:
    if not first.contains(item):
      out.add(item)
  return out

# True when every element of [subset] is contained in [superset].
# Example:
#   print isSubsetOf(small, big)
isSubsetOf<T>(subset: Set<T>, superset: Set<T>) -> bool:
  if subset.length > superset.length:
    return false
  for item in subset:
    if not superset.contains(item):
      return false
  return true

# True when [superset] contains every element of [subset].
# Example:
#   print isSupersetOf(big, small)
isSupersetOf<T>(superset: Set<T>, subset: Set<T>) -> bool = isSubsetOf<T>(subset, superset)

# True when [first] and [second] share no elements.
# Example:
#   print isDisjoint(a, b)
isDisjoint<T>(first: Set<T>, second: Set<T>) -> bool:
  if first.length <= second.length:
    for item in first:
      if second.contains(item):
        return false
  else:
    for item in second:
      if first.contains(item):
        return false
  return true

# Counts occurrences of each distinct element in [items].
# Example:
#   print frequencies(["a", "b", "a"])
frequencies<T>(items: Iterable<T>) -> Map<T, int>:
  counts: Map<T, int> = map:
  for item in items:
    prev = counts[item] ?? 0
    counts[item] = prev + 1
  return counts

# Computes the Cartesian product of [left] and [right] in row-major order.
# Example:
#   print cartesianProduct([1, 2], ["a", "b"])
cartesianProduct<A, B>(left: List<A>, right: List<B>) -> List<CollectionPair<A, B>>:
  out: List<CollectionPair<A, B>> = []
  for a in left:
    for b in right:
      out.add(CollectionPair<A, B>(first: a, second: b))
  return out

# A mutable multiset (counted bag) tracking non-negative multiplicities for
# distinct elements with O(1) average add/remove/count.
# Example:
#   ms = Multiset<String>()
#   ms.add("a", count: 2)
#   print ms.countOf("a")
class Multiset<T>:
  private var counts: Map<T, int> = Map<T, int>()
  private var totalCount: int = 0

  # Creates a multiset populated from [items].
  # Example:
  #   ms = Multiset.from(["a", "b", "a"])
  static from<E>(items: Iterable<E>) -> Multiset<E>:
    out = Multiset<E>()
    for item in items:
      out.add(item)
    return out

  # Total number of occurrences across all elements.
  # Example:
  #   print ms.length
  property length: int:
    get = totalCount

  # Number of distinct elements with count > 0.
  # Example:
  #   print ms.distinctCount
  property distinctCount: int:
    get = counts.length

  # True when the multiset holds no elements.
  # Example:
  #   print ms.isEmpty
  property isEmpty: bool:
    get = totalCount == 0

  # True when the multiset holds at least one element.
  # Example:
  #   print ms.isNotEmpty
  property isNotEmpty: bool:
    get = totalCount > 0

  # Distinct elements currently stored with positive count.
  # Example:
  #   print ms.distinctElements
  property distinctElements: List<T>:
    get = counts.keys.toList()

  # Returns the multiplicity of [value], or 0 when absent.
  # Example:
  #   print ms.countOf("a")
  countOf(value: T) -> int = counts[value] ?? 0

  # True when [value] has count > 0.
  # Example:
  #   print ms.contains("a")
  contains(value: T) -> bool = counts.containsKey(value)

  # Adds [count] occurrences of [value]. Throws CollectionError if [count] < 0.
  # Example:
  #   ms.add("x", count: 3)
  add(value: T, count: int = 1):
    if count < 0:
      throw CollectionError("Multiset.add", "Count must be non-negative, got {count}")
    if count == 0:
      return
    prev = counts[value] ?? 0
    counts[value] = prev + count
    totalCount = totalCount + count

  # Removes up to [count] occurrences of [value] and returns how many were
  # actually removed. Throws CollectionError if [count] < 0.
  # Example:
  #   removed = ms.remove("x", count: 2)
  remove(value: T, count: int = 1) -> int:
    if count < 0:
      throw CollectionError("Multiset.remove", "Count must be non-negative, got {count}")
    if count == 0:
      return 0
    prev = counts[value] ?? 0
    if prev == 0:
      return 0
    var taken = prev
    if count < taken:
      taken = count
    remaining = prev - taken
    if remaining == 0:
      counts.remove(value)
    else:
      counts[value] = remaining
    totalCount = totalCount - taken
    return taken

  # Removes all occurrences of [value] and returns the previous count.
  # Example:
  #   removed = ms.removeAll("x")
  removeAll(value: T) -> int:
    prev = counts[value] ?? 0
    if prev == 0:
      return 0
    counts.remove(value)
    totalCount = totalCount - prev
    return prev

  # Removes all elements from this multiset.
  # Example:
  #   ms.clear()
  clear():
    counts.clear()
    totalCount = 0

  # Returns a snapshot map from each distinct element to its positive count.
  # Example:
  #   print ms.toCountMap()
  toCountMap() -> Map<T, int>:
    out: Map<T, int> = map:
    for entry in counts.entries:
      out[entry.key] = entry.value
    return out

  # Returns up to [limit] most frequent elements as (element, count) pairs,
  # ordered by descending count (ties preserve insertion order).
  # Example:
  #   print ms.mostCommon(2)
  mostCommon(limit: int? = null) -> List<CollectionPair<T, int>>:
    if limit != null and limit < 0:
      throw CollectionError("Multiset.mostCommon", "Limit must be non-negative, got {limit}")
    pairs: List<CollectionPair<T, int>> = []
    for entry in counts.entries:
      pairs.add(CollectionPair<T, int>(first: entry.key, second: entry.value))
    # Stable insertion sort by descending count.
    var i = 1
    while i < pairs.length:
      current = pairs[i]
      var j = i - 1
      while j >= 0 and pairs[j].second < current.second:
        pairs[j + 1] = pairs[j]
        j = j - 1
      pairs[j + 1] = current
      i = i + 1
    if limit != null and limit < pairs.length:
      out: List<CollectionPair<T, int>> = []
      var k = 0
      while k < limit:
        out.add(pairs[k])
        k = k + 1
      return out
    return pairs

  # Returns a new multiset containing the sum of counts from this and [other].
  # Example:
  #   combined = a.sum(b)
  sum(other: Multiset<T>) -> Multiset<T>:
    out = Multiset<T>()
    for entry in counts.entries:
      out.add(entry.key, count: entry.value)
    for entry in other.toCountMap().entries:
      out.add(entry.key, count: entry.value)
    return out

  # Returns a new multiset whose counts are the minimum of counts in this and [other].
  # Example:
  #   shared = a.intersect(b)
  intersect(other: Multiset<T>) -> Multiset<T>:
    out = Multiset<T>()
    for entry in counts.entries:
      otherCount = other.countOf(entry.key)
      if otherCount > 0:
        var keep = otherCount
        if entry.value < keep:
          keep = entry.value
        out.add(entry.key, count: keep)
    return out


:: sort

# Internal stable merge sort returning a new list.
_mergeSort<T>(items: List<T>, compare: (T, T) -> int) -> List<T>:
  n = items.length
  if n <= 1:
    out: List<T> = []
    for item in items:
      out.add(item)
    return out
  mid = n ~/ 2
  leftSlice: List<T> = []
  var i = 0
  while i < mid:
    leftSlice.add(items[i])
    i = i + 1
  rightSlice: List<T> = []
  while i < n:
    rightSlice.add(items[i])
    i = i + 1
  left = _mergeSort<T>(leftSlice, compare)
  right = _mergeSort<T>(rightSlice, compare)
  merged: List<T> = []
  var li = 0
  var ri = 0
  while li < left.length and ri < right.length:
    if compare(left[li], right[ri]) <= 0:
      merged.add(left[li])
      li = li + 1
    else:
      merged.add(right[ri])
      ri = ri + 1
  while li < left.length:
    merged.add(left[li])
    li = li + 1
  while ri < right.length:
    merged.add(right[ri])
    ri = ri + 1
  return merged

# Returns a new list containing the elements of [items] stably sorted using
# [compare]. Does not mutate [items].
# Example:
#   print sortedWith([3, 1, 2], (a: int, b: int) -> a.compareTo(b))
sortedWith<T>(items: Iterable<T>, compare: (T, T) -> int) -> List<T>:
  copy: List<T> = []
  for item in items:
    copy.add(item)
  return _mergeSort<T>(copy, compare)

# Returns a new list stably sorted by a key computed once per element via
# [keyOf] and compared with [compareKeys]. Set [descending] to true to reverse
# the ordering while preserving stability for equal keys.
# Example:
#   print sortedByKey(["pear", "fig", "kiwi"], (s: String) -> s.length, (a: int, b: int) -> a.compareTo(b))
sortedByKey<T, K>(items: Iterable<T>, keyOf: (T) -> K, compareKeys: (K, K) -> int, descending: bool = false) -> List<T>:
  decorated: List<CollectionPair<T, K>> = []
  for item in items:
    decorated.add(CollectionPair<T, K>(first: item, second: keyOf(item)))
  var sorted: List<CollectionPair<T, K>> = []
  if descending:
    sorted = _mergeSort<CollectionPair<T, K>>(decorated, (a: CollectionPair<T, K>, b: CollectionPair<T, K>) -> compareKeys(b.second, a.second))
  else:
    sorted = _mergeSort<CollectionPair<T, K>>(decorated, (a: CollectionPair<T, K>, b: CollectionPair<T, K>) -> compareKeys(a.second, b.second))
  out: List<T> = []
  for pair in sorted:
    out.add(pair.first)
  return out

# Returns the first index in sorted [items] where compare(items[i], target) >= 0,
# or items.length when all elements are strictly less than [target].
# Example:
#   print lowerBound([1, 2, 2, 4], 2, (a: int, b: int) -> a.compareTo(b))
lowerBound<T>(items: List<T>, target: T, compare: (T, T) -> int) -> int:
  var lo = 0
  var hi = items.length
  while lo < hi:
    mid = lo + ((hi - lo) ~/ 2)
    if compare(items[mid], target) < 0:
      lo = mid + 1
    else:
      hi = mid
  return lo

# Returns the first index in sorted [items] where compare(items[i], target) > 0,
# or items.length when no element is strictly greater than [target].
# Example:
#   print upperBound([1, 2, 2, 4], 2, (a: int, b: int) -> a.compareTo(b))
upperBound<T>(items: List<T>, target: T, compare: (T, T) -> int) -> int:
  var lo = 0
  var hi = items.length
  while lo < hi:
    mid = lo + ((hi - lo) ~/ 2)
    if compare(items[mid], target) <= 0:
      lo = mid + 1
    else:
      hi = mid
  return lo

# Searches sorted [items] for [target] using [compare]. Returns a matching
# index, or -1 when [target] is not present.
# Example:
#   print binarySearch([1, 3, 5, 7], 5, (a: int, b: int) -> a.compareTo(b))
binarySearch<T>(items: List<T>, target: T, compare: (T, T) -> int) -> int:
  idx = lowerBound<T>(items, target, compare)
  if idx < items.length and compare(items[idx], target) == 0:
    return idx
  return -1

# Returns up to [k] largest elements of [items] in descending order according
# to [compare]. Equal elements keep their earlier appearance. Throws
# CollectionError when [k] is negative.
# Example:
#   print topK([5, 1, 9, 3, 7], 3, (a: int, b: int) -> a.compareTo(b))
topK<T>(items: Iterable<T>, k: int, compare: (T, T) -> int) -> List<T>:
  if k < 0:
    throw CollectionError("topK", "k must be non-negative, got {k}")
  if k == 0:
    empty: List<T> = []
    return empty
  sorted = sortedWith<T>(items, (a: T, b: T) -> compare(b, a))
  if k >= sorted.length:
    return sorted
  out: List<T> = []
  var i = 0
  while i < k:
    out.add(sorted[i])
    i = i + 1
  return out

# Returns up to [k] smallest elements of [items] in ascending order according
# to [compare]. Equal elements keep their earlier appearance. Throws
# CollectionError when [k] is negative.
# Example:
#   print bottomK([5, 1, 9, 3, 7], 3, (a: int, b: int) -> a.compareTo(b))
bottomK<T>(items: Iterable<T>, k: int, compare: (T, T) -> int) -> List<T>:
  if k < 0:
    throw CollectionError("bottomK", "k must be non-negative, got {k}")
  if k == 0:
    empty: List<T> = []
    return empty
  sorted = sortedWith<T>(items, compare)
  if k >= sorted.length:
    return sorted
  out: List<T> = []
  var i = 0
  while i < k:
    out.add(sorted[i])
    i = i + 1
  return out

# Returns a new list with the half-open slice [start, end) reversed.
# Throws RangeError when bounds are outside 0..items.length or start > end.
# Example:
#   print reverseRange([1, 2, 3, 4, 5], 1, 4)
reverseRange<T>(items: List<T>, start: int, end: int) -> List<T>:
  if start < 0 or start > items.length:
    throw RangeError.range(start, 0, items.length, "start")
  if end < start or end > items.length:
    throw RangeError.range(end, start, items.length, "end")
  out: List<T> = []
  var i = 0
  while i < items.length:
    out.add(items[i])
    i = i + 1
  var lo = start
  var hi = end - 1
  while lo < hi:
    tmp = out[lo]
    out[lo] = out[hi]
    out[hi] = tmp
    lo = lo + 1
    hi = hi - 1
  return out

# Returns a new list rotated right by [shift] positions (negative rotates left).
# Example:
#   print rotateList([1, 2, 3, 4], 1)
rotateList<T>(items: List<T>, shift: int) -> List<T>:
  n = items.length
  if n == 0:
    empty: List<T> = []
    return empty
  var k = shift % n
  if k < 0:
    k = k + n
  out: List<T> = []
  var i = 0
  while i < n:
    src = (i - k + n) % n
    out.add(items[src])
    i = i + 1
  return out

# Returns a deterministically shuffled copy of [items] using a portable 31-bit
# Park-Miller LCG seeded with [seed] (identical results on Dart VM and JS).
# Example:
#   print shuffleSeeded([1, 2, 3, 4], 42)
shuffleSeeded<T>(items: Iterable<T>, seed: int) -> List<T>:
  out: List<T> = []
  for item in items:
    out.add(item)
  if out.length <= 1:
    return out
  modulus = 2147483647
  var rng = seed % modulus
  if rng <= 0:
    rng = rng + modulus - 1
  if rng <= 0:
    rng = 1
  var i = out.length - 1
  while i > 0:
    # Schrage's method for 16807 * rng mod (2^31 - 1), overflow-safe on 32-bit/JS.
    q = 127773
    r = 2836
    hi = rng ~/ q
    lo = rng - hi * q
    rng = 16807 * lo - r * hi
    if rng <= 0:
      rng = rng + modulus
    j = rng % (i + 1)
    tmp = out[i]
    out[i] = out[j]
    out[j] = tmp
    i = i - 1
  return out


:: equality

# Internal 30-bit Jenkins-style hash combiner (safe on both VM and JS).
_combineHash(hash: int, value: int) -> int:
  var h = (hash + (value & 0x3fffffff)) & 0x3fffffff
  h = (h + ((h << 10) & 0x3fffffff)) & 0x3fffffff
  return h ^ (h >> 6)

# Internal 30-bit hash finalizer.
_finishHash(hash: int) -> int:
  var h = (hash + ((hash << 3) & 0x3fffffff)) & 0x3fffffff
  h = h ^ (h >> 11)
  return (h + ((h << 15) & 0x3fffffff)) & 0x3fffffff

# Element-wise structural equality for two lists, optionally using [itemEquals].
# Example:
#   print listEquals([1, 2], [1, 2])
listEquals<T>(first: List<T>, second: List<T>, itemEquals: ((T, T) -> bool)? = null) -> bool:
  if first.length != second.length:
    return false
  var i = 0
  while i < first.length:
    if itemEquals != null:
      if not itemEquals(first[i], second[i]):
        return false
    else:
      if first[i] != second[i]:
        return false
    i = i + 1
  return true

# Structural equality for two sets (same length and identical membership).
# Example:
#   print setEquals(a, b)
setEquals<T>(first: Set<T>, second: Set<T>) -> bool:
  if first.length != second.length:
    return false
  for item in first:
    if not second.contains(item):
      return false
  return true

# Structural equality for two maps (same keys and equal values, optionally
# compared with [valueEquals]). Distinguishes absent keys from null values.
# Example:
#   print mapEquals(a, b)
mapEquals<K, V>(first: Map<K, V>, second: Map<K, V>, valueEquals: ((V, V) -> bool)? = null) -> bool:
  if first.length != second.length:
    return false
  for entry in first.entries:
    if not second.containsKey(entry.key):
      return false
    otherVal = second[entry.key] as V
    if valueEquals != null:
      if not valueEquals(entry.value, otherVal):
        return false
    else:
      if entry.value != otherVal:
        return false
  return true

# Order-sensitive structural hash code for a sequence, optionally using [hashOf].
# Example:
#   print listHash([1, 2, 3])
listHash<T>(items: Iterable<T>, hashOf: ((T) -> int)? = null) -> int:
  var h = 0
  for item in items:
    var itemHash = item.hashCode
    if hashOf != null:
      itemHash = hashOf(item)
    h = _combineHash(h, itemHash)
  return _finishHash(h)

# Order-independent structural hash code for sets or multisets.
# Example:
#   print unorderedHash([1, 2]) == unorderedHash([2, 1])
unorderedHash<T>(items: Iterable<T>, hashOf: ((T) -> int)? = null) -> int:
  var sum = 0
  var count = 0
  for item in items:
    var itemHash = item.hashCode
    if hashOf != null:
      itemHash = hashOf(item)
    mixed = _finishHash(_combineHash(0, itemHash))
    sum = (sum + mixed) & 0x3fffffff
    count = count + 1
  return _finishHash(_combineHash(sum, count))

# Order-independent structural hash code for a map.
# Example:
#   print mapHash(m1) == mapHash(m2)
mapHash<K, V>(source: Map<K, V>, keyHash: ((K) -> int)? = null, valueHash: ((V) -> int)? = null) -> int:
  var sum = 0
  var count = 0
  for entry in source.entries:
    var kh = entry.key.hashCode
    if keyHash != null:
      kh = keyHash(entry.key)
    var vh = entry.value.hashCode
    if valueHash != null:
      vh = valueHash(entry.value)
    pairHash = _finishHash(_combineHash(_combineHash(0, kh), vh))
    sum = (sum + pairHash) & 0x3fffffff
    count = count + 1
  return _finishHash(_combineHash(sum, count))

# Bundles an explicit typed equality test and consistent hash function for [T].
# Example:
#   eq = Equality.defaultOf<String>()
#   print eq.isEqual("a", "a")
class Equality<T>:
  private equalsFn: (T, T) -> bool required
  private hashFn: (T) -> int required

  # Creates an Equality using standard `==` and `hashCode`.
  # Example:
  #   eq = Equality.defaultOf<int>()
  static defaultOf<E>() -> Equality<E>:
    return Equality<E>(
      equalsFn: (a: E, b: E) -> a == b,
      hashFn: (v: E) -> v.hashCode,
    )

  # Creates an Equality with custom [itemEquals] and [itemHash] functions.
  # Example:
  #   ci = Equality.custom<String>((a: String, b: String) -> a.toLowerCase() == b.toLowerCase(), (s: String) -> s.toLowerCase().hashCode)
  static custom<E>(itemEquals: (E, E) -> bool, itemHash: (E) -> int) -> Equality<E>:
    return Equality<E>(equalsFn: itemEquals, hashFn: itemHash)

  # Returns true when [first] and [second] are equal under this contract.
  # Example:
  #   print eq.isEqual(a, b)
  isEqual(first: T, second: T) -> bool = equalsFn(first, second)

  # Returns the hash code of [value] under this contract.
  # Example:
  #   print eq.hashOf(a)
  hashOf(value: T) -> int = hashFn(value)

  # Compares two lists element-by-element using this equality.
  # Example:
  #   print eq.listsEqual(a, b)
  listsEqual(first: List<T>, second: List<T>) -> bool = listEquals<T>(first, second, itemEquals: equalsFn)

  # Computes a list hash consistent with [listsEqual].
  # Example:
  #   print eq.hashList(a)
  hashList(items: Iterable<T>) -> int = listHash<T>(items, hashOf: hashFn)


:: diff

# Computes the structural difference between [before] and [after] sets.
# Example:
#   d = diffSets(oldSet, newSet)
diffSets<T>(before: Set<T>, after: Set<T>) -> SetDiff<T>:
  added: Set<T> = set:
  removed: Set<T> = set:
  common: Set<T> = set:
  for item in before:
    if after.contains(item):
      common.add(item)
    else:
      removed.add(item)
  for item in after:
    if not before.contains(item):
      added.add(item)
  return SetDiff<T>(added: added, removed: removed, common: common)

# Computes the structural difference between [before] and [after] maps.
# Optionally compares values with [valueEquals].
# Example:
#   d = diffMaps(oldMap, newMap)
diffMaps<K, V>(before: Map<K, V>, after: Map<K, V>, valueEquals: ((V, V) -> bool)? = null) -> MapDiff<K, V>:
  added: Map<K, V> = map:
  removed: Map<K, V> = map:
  changed: Map<K, CollectionPair<V, V>> = map:
  unchanged: Map<K, V> = map:
  for entry in before.entries:
    if not after.containsKey(entry.key):
      removed[entry.key] = entry.value
    else:
      nextVal = after[entry.key] as V
      var matched = false
      if valueEquals != null:
        matched = valueEquals(entry.value, nextVal)
      else:
        matched = entry.value == nextVal
      if matched:
        unchanged[entry.key] = entry.value
      else:
        changed[entry.key] = CollectionPair<V, V>(first: entry.value, second: nextVal)
  for entry in after.entries:
    if not before.containsKey(entry.key):
      added[entry.key] = entry.value
  return MapDiff<K, V>(added: added, removed: removed, changed: changed, unchanged: unchanged)

# Computes a longest common subsequence of [first] and [second] in O(n * m)
# time and space. Optionally compares elements with [itemEquals].
# Example:
#   print longestCommonSubsequence(["a", "b", "c"], ["a", "x", "c"])
longestCommonSubsequence<T>(first: List<T>, second: List<T>, itemEquals: ((T, T) -> bool)? = null) -> List<T>:
  n = first.length
  m = second.length
  if n == 0 or m == 0:
    empty: List<T> = []
    return empty
  cols = m + 1
  dp: List<int> = []
  var total = (n + 1) * cols
  while total > 0:
    dp.add(0)
    total = total - 1
  var i = n - 1
  while i >= 0:
    var j = m - 1
    while j >= 0:
      var matched = false
      if itemEquals != null:
        matched = itemEquals(first[i], second[j])
      else:
        matched = first[i] == second[j]
      if matched:
        dp[i * cols + j] = 1 + dp[(i + 1) * cols + (j + 1)]
      else:
        down = dp[(i + 1) * cols + j]
        right = dp[i * cols + (j + 1)]
        if down >= right:
          dp[i * cols + j] = down
        else:
          dp[i * cols + j] = right
      j = j - 1
    i = i - 1
  out: List<T> = []
  var r = 0
  var c = 0
  while r < n and c < m:
    var matched = false
    if itemEquals != null:
      matched = itemEquals(first[r], second[c])
    else:
      matched = first[r] == second[c]
    if matched:
      out.add(first[r])
      r = r + 1
      c = c + 1
    else if dp[(r + 1) * cols + c] >= dp[r * cols + (c + 1)]:
      r = r + 1
    else:
      c = c + 1
  return out

# Computes a minimal LCS-based sequence edit script transforming [before] into
# [after] as keep/delete/insert steps.
# Example:
#   steps = diffLists(["a", "b", "c"], ["a", "x", "c"])
diffLists<T>(before: List<T>, after: List<T>, itemEquals: ((T, T) -> bool)? = null) -> List<ListDiffStep<T>>:
  n = before.length
  m = after.length
  cols = m + 1
  dp: List<int> = []
  var total = (n + 1) * cols
  while total > 0:
    dp.add(0)
    total = total - 1
  var i = n - 1
  while i >= 0:
    var j = m - 1
    while j >= 0:
      var matched = false
      if itemEquals != null:
        matched = itemEquals(before[i], after[j])
      else:
        matched = before[i] == after[j]
      if matched:
        dp[i * cols + j] = 1 + dp[(i + 1) * cols + (j + 1)]
      else:
        down = dp[(i + 1) * cols + j]
        right = dp[i * cols + (j + 1)]
        if down >= right:
          dp[i * cols + j] = down
        else:
          dp[i * cols + j] = right
      j = j - 1
    i = i - 1
  steps: List<ListDiffStep<T>> = []
  var r = 0
  var c = 0
  while r < n and c < m:
    var matched = false
    if itemEquals != null:
      matched = itemEquals(before[r], after[c])
    else:
      matched = before[r] == after[c]
    if matched:
      steps.add(ListDiffStep<T>(op: ListDiffOp.keep, value: before[r]))
      r = r + 1
      c = c + 1
    else if dp[(r + 1) * cols + c] >= dp[r * cols + (c + 1)]:
      steps.add(ListDiffStep<T>(op: ListDiffOp.delete, value: before[r]))
      r = r + 1
    else:
      steps.add(ListDiffStep<T>(op: ListDiffOp.insert, value: after[c]))
      c = c + 1
  while r < n:
    steps.add(ListDiffStep<T>(op: ListDiffOp.delete, value: before[r]))
    r = r + 1
  while c < m:
    steps.add(ListDiffStep<T>(op: ListDiffOp.insert, value: after[c]))
    c = c + 1
  return steps

# Applies [steps] produced by [diffLists] to [before], returning the target
# list. Throws CollectionError if [steps] does not align with [before].
# Example:
#   rebuilt = applyListDiff(oldList, diffLists(oldList, newList))
applyListDiff<T>(before: List<T>, steps: List<ListDiffStep<T>>, itemEquals: ((T, T) -> bool)? = null) -> List<T>:
  out: List<T> = []
  var idx = 0
  for step in steps:
    if step.op == ListDiffOp.insert:
      out.add(step.value)
    else:
      if idx >= before.length:
        throw CollectionError("applyListDiff", "Diff step exceeds source length at index {idx}")
      var matched = false
      if itemEquals != null:
        matched = itemEquals(before[idx], step.value)
      else:
        matched = before[idx] == step.value
      if not matched:
        throw CollectionError("applyListDiff", "Diff mismatch at index {idx}")
      if step.op == ListDiffOp.keep:
        out.add(before[idx])
      idx = idx + 1
  if idx != before.length:
    throw CollectionError("applyListDiff", "Diff did not consume all elements of source ({idx} of {before.length})")
  return out
''';

const embeddedSdk = <String, String>{
  'core': coreSdkSource,
  'ext': extSdkSource,
  'math': mathSdkSource,
  'text': textSdkSource,
  'collection': collectionSdkSource,
};

List<String>? _sdkLibraryNames;
String? _sdkLibraryStamp;

/// SDK library names, from memory. The `lib/sdk` directory is read again only
/// when that directory itself changes.
List<String> sdkLibraryNames() {
  String? stamp;
  Directory? directory;
  for (final root in _packageRoots()) {
    final candidate = Directory(
        '$root${Platform.pathSeparator}lib${Platform.pathSeparator}sdk');
    if (!candidate.existsSync()) continue;
    directory = candidate;
    final stat = candidate.statSync();
    stamp = '${candidate.path}:${stat.modified.microsecondsSinceEpoch}';
    break;
  }
  final key = stamp ?? 'embedded';
  final cached = _sdkLibraryNames;
  if (cached != null && _sdkLibraryStamp == key) return cached;
  final names = <String>{...embeddedSdk.keys};
  if (directory != null) {
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final base = entity.path.split(Platform.pathSeparator).last;
      if (!base.endsWith('.quds')) continue;
      final stem = base.substring(0, base.length - 5);
      if (sdkLibraryName('quds:$stem') == null) continue;
      names.add(stem);
    }
  }
  final sorted = names.toList()..sort();
  _sdkLibraryNames = sorted;
  _sdkLibraryStamp = key;
  return sorted;
}

/// A `quds:` import. [section] is null for the whole library.
class SdkImport {
  const SdkImport(this.library, this.section);
  final String library;

  /// `graph`, or `graph::weighted`. Null imports every public name.
  final String? section;
}

final _sdkIdentifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// `quds:math` and `quds:math::graph::weighted`. Null when the URI is not a
/// library name followed by optional `::` sections.
SdkImport? sdkImport(String uri) {
  if (!uri.startsWith('quds:')) return null;
  final body = uri.substring('quds:'.length);
  if (body.isEmpty) return null;
  final parts = body.split('::');
  for (final part in parts) {
    if (!_sdkIdentifier.hasMatch(part)) return null;
  }
  if (parts.length == 1) return SdkImport(parts.first, null);
  return SdkImport(parts.first, parts.sublist(1).join('::'));
}

/// `quds:core` -> `core`. `quds:math::graph` -> `math`.
String? sdkLibraryName(String uri) => sdkImport(uri)?.library;

final _sdkSectionCache = <String, (int, int, List<String>)>{};

/// Section paths declared by column-0 `::` headers in [library].
///
/// The scan reads the source text only. It does not parse or type-check.
List<String> sdkSectionNames(String library) {
  if (sdkLibraryName('quds:$library') == null) return const [];
  final source = readSdk(library);
  if (source == null) return const [];
  final cached = _sdkSectionCache[library];
  if (cached != null &&
      cached.$1 == source.length &&
      cached.$2 == source.hashCode) {
    return cached.$3;
  }
  final names = sectionHeadersIn(source);
  _sdkSectionCache[library] = (source.length, source.hashCode, names);
  return names;
}

/// Generated Dart file written beside the caller's output.
String sdkDartFileName(String name) => 'quds_$name.dart';

/// Absolute path of `lib/sdk/<name>.quds` inside this compiler package.
String? sdkPath(String name) {
  if (sdkLibraryName('quds:$name') == null) return null;
  for (final root in _packageRoots()) {
    final file = File(
        '$root${Platform.pathSeparator}lib${Platform.pathSeparator}sdk${Platform.pathSeparator}$name.quds');
    if (file.existsSync()) return file.path;
  }
  return null;
}

/// The on-disk library when this package is available, otherwise the embedded copy.
String? readSdk(String name) {
  if (sdkLibraryName('quds:$name') == null) return null;
  final path = sdkPath(name);
  if (path != null) return File(path).readAsStringSync();
  return embeddedSdk[name];
}

/// Bytes mixed into the incremental cache so an SDK edit rebuilds outputs.
String sdkDigestMaterial() {
  final names = embeddedSdk.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final name in names) {
    buffer.writeln(name);
    buffer.write(readSdk(name) ?? '');
    buffer.writeCharCode(0);
  }
  return buffer.toString();
}

List<String> _packageRoots() {
  final roots = <String>[];
  final seen = <String>{};
  void walk(String start) {
    var directory = Directory(start);
    for (var level = 0; level < 20; level++) {
      if (!seen.add(directory.path)) return;
      final spec =
          File('${directory.path}${Platform.pathSeparator}pubspec.yaml');
      if (spec.existsSync()) {
        final match = RegExp(
          '''^[ \\t]*name:[ \\t]*["']?([^"'\\s#]+)''',
          multiLine: true,
        ).firstMatch(spec.readAsStringSync());
        if (match?.group(1) == 'quds_lang') roots.add(directory.path);
      }
      final parent = directory.parent;
      if (parent.path == directory.path) return;
      directory = parent;
    }
  }

  walk(File(Platform.resolvedExecutable).parent.path);
  try {
    final script = Platform.script.toFilePath();
    if (script.isNotEmpty) walk(File(script).parent.path);
  } catch (_) {}
  walk(Directory.current.path);
  return roots;
}
