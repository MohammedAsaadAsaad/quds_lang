import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group('Phase 2 — OOP, Patterns, Result, Conversions, Exceptions & Async', () {
    test('class, value class, enum, operator overloading, properties, and with',
        () async {
      final session = QudsSession();
      final res = await session.run('''
enum Color:
  red
  green
  blue

value class Point:
  x: double required
  y: double required
  operator +(other: Point) -> Point = Point(x + other.x, y + other.y)
  lengthSq() -> double = x * x + y * y

p1 = Point(3.0, 4.0)
p2 = Point(1.0, 2.0)
p3 = p1 + p2
p4 = with p1:
  y = 10.0

print p1 == Point(3.0, 4.0)
print p3.x
print p3.y
print p1.lengthSq()
print p4.y
print Color.green
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, [
        'true',
        '4.0',
        '6.0',
        '25.0',
        '10.0',
        'Color.green',
      ]);
    });

    test(
        'pattern matching, Result Ok/Error/? propagation, and to/to? conversions',
        () async {
      final session = QudsSession();
      final res = await session.run('''
parsePositive(raw: String) -> Result<int, String>:
  n = raw to? int
  if n == null:
    return Error("not-int")
  if n <= 0:
    return Error("non-positive")
  return Ok(n)

addTwo(a: String, b: String) -> Result<int, String>:
  x = parsePositive(a)?
  y = parsePositive(b)?
  return Ok(x + y)

describe(r: Result<int, String>) -> String:
  return match r:
    Ok(v) when v > 10: "big:{v}"
    Ok(v): "ok:{v}"
    Error(e): "err:{e}"

print describe(addTwo("7", "8"))
print describe(addTwo("2", "3"))
print describe(addTwo("7", "abc"))
print describe(addTwo("-1", "5"))
print(("42" to int) + 1)
print(("nope" to? int) ?? -99)
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, [
        'big:15',
        'ok:5',
        'err:not-int',
        'err:non-positive',
        '43',
        '-99',
      ]);
    });

    test('try/catch/finally, defer LIFO order, and try fallback expression',
        () async {
      final session = QudsSession();
      final res = await session.run('''
var log: List<String> = []

runDefer():
  defer log.add("first")
  defer log.add("second")
  log.add("body")

runDefer()

try:
  throw ArgumentError("boom")
catch e: ArgumentError:
  log.add("caught")
finally:
  log.add("done")

safe = try ("xyz" to int) else -1
print log.join(",")
print safe
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, [
        'body,second,first,caught,done',
        '-1',
      ]);
    });

    test('async/await and await all', () async {
      final session = QudsSession();
      session.registerFunction('delayedDouble', (pos, named, ctx) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return (pos[0] as num) * 2;
      });
      final res = await session.run('''
compute(x: int) async -> int:
  a = await delayedDouble(x)
  b = await delayedDouble(x + 1)
  return (a to int) + (b to int)

ans = await compute(5)
pair = await all:
  delayedDouble(3)
  delayedDouble(4)
print ans
print "{pair.\$1},{pair.\$2}"
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, ['22', '6,8']);
    });
  });
}
