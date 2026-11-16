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

const extSdkSource = '''extend String Text:
  # True when the text is empty or only spaces.
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
  # The characters from last to first.
  # Example:
  #   print "ab".reversed()
  reversed() -> String:
    var out = ""
    for ch in this.chars:
      out = ch + out
    return out
  # How many times [part] occurs.
  # Example:
  #   print "ababa".count("ab")
  count(part: String) -> int:
    if part.length == 0:
      return 0
    var total = 0
    var index = 0
    while index <= length - part.length:
      if this.substring(index, index + part.length) == part:
        total = total + 1
      index = index + 1
    return total
  # This text without [prefix] when it starts with that prefix.
  # Example:
  #   print "prefix-value".removePrefix("prefix-")
  removePrefix(prefix: String) -> String:
    if this.startsWith(prefix):
      return this.substring(prefix.length)
    return this
  # This text without [suffix] when it ends with that suffix.
  # Example:
  #   print "value-suffix".removeSuffix("-suffix")
  removeSuffix(suffix: String) -> String:
    if this.endsWith(suffix):
      return this.substring(0, length - suffix.length)
    return this
  # The text before the first [marker].
  # Example:
  #   print "a-b".before("-")
  before(marker: String) -> String:
    found = this.indexOf(marker)
    if found < 0:
      return this
    return this.substring(0, found)
  # The text after the first [marker].
  # Example:
  #   print "a-b".after("-")
  after(marker: String) -> String:
    found = this.indexOf(marker)
    if found < 0:
      return ""
    return this.substring(found + marker.length)
  # This text repeated [times] times.
  # Example:
  #   print "ab".repeated(3)
  repeated(times: int) -> String:
    var out = ""
    var left = times
    while left > 0:
      out = out + this
      left = left - 1
    return out
  # The words separated by spaces.
  # Example:
  #   print "a b".words().length
  words() -> List<String>:
    parts = this.split(" ")
    kept: List<String> = []
    for part in parts:
      if part.length > 0:
        kept.add(part)
    return kept
  # At most [limit] characters.
  # Example:
  #   print "abcdef".truncate(3)
  truncate(limit: int) -> String:
    if limit <= 0:
      return ""
    if length <= limit:
      return this
    return this.substring(0, limit)
  # This text inside double quotes.
  # Example:
  #   print "ab".quoted()
  quoted() -> String = '"' + this + '"'

extend List<T> Lists:
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
# graph::flow, graph::matching, exact, exact::decimal, autodiff,
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
  about(other: double) -> bool = approximately(this, other, 1.0e-9)

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
  return normalCdf(math.log(x), center, sigma)

# Lognormal quantile.
# Example:
#   print lognormalQuantile(0.5, 0.0, 1.0)
lognormalQuantile(p: double, center: double, sigma: double) -> double:
  return math.exp(normalQuantile(p, center, sigma))

# One lognormal draw.
# Example:
#   print lognormalSample(Random(1), 0.0, 1.0) > 0.0
lognormalSample(random: Random, center: double, sigma: double) -> double:
  return math.exp(normalSample(random, center, sigma))

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
      tolerance)
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
  for face in faces:
    if face.length != 3: throw "topology face must be a triangle"
    if face[0] == face[1] or face[0] == face[2] or face[1] == face[2]: throw "topology face repeats a vertex"
    var slot = 0
    while slot < 3:
      if face[slot] < 0 or face[slot] >= vertexCount: throw "topology vertex out of range"
      slot += 1
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
''';

const embeddedSdk = <String, String>{
  'core': coreSdkSource,
  'ext': extSdkSource,
  'math': mathSdkSource,
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
