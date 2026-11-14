import 'dart:io';

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

const embeddedSdk = <String, String>{
  'core': coreSdkSource,
  'ext': extSdkSource,
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

/// `quds:core` -> `core`. Null when the name is not a single identifier.
String? sdkLibraryName(String uri) {
  if (!uri.startsWith('quds:')) return null;
  final name = uri.substring('quds:'.length);
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) return null;
  return name;
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
