import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group('Phase 2 — Embedded quds:* SDK Execution in Interpreter', () {
    test('quds:core Stack and Queue work natively in interpreter', () async {
      final session = QudsSession();
      final res = await session.run('''
use quds:core

s = Stack<int>()
s.push(10)
s.push(20)
print "{s.size()},{s.top()},{s.pop()},{s.pop()}"

q = Queue<String>()
q.add("a")
q.add("b")
print "{q.take()},{q.take()}"
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, ['2,20,20,10', 'a,b']);
    });

    test(
        'quds:json encode, decode, pretty, merge, and equality work in interpreter',
        () async {
      final session = QudsSession();
      final res = await session.run('''
use quds:json

base = map:
  "host": "localhost"
  "port": 8080
patch = map:
  "port": 9090
  "tls": true

merged = jsonMerge(base, patch)
encoded = jsonPretty(merged)
print jsonEquals(merged, jsonMerge(base, patch))
print encoded.contains("9090")
print merged["port"]
print merged["tls"]
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, ['true', 'true', '9090', 'true']);
    });

    test(
        'quds:math::stats, quds:math::geometry, quds:math::number, and quds:math::graph run natively',
        () async {
      final session = QudsSession();
      final res = await session.run('''
use quds:math

# Scalar & stats
xs = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
avg = mean(xs)
d = cohenD([10.0, 12.0, 14.0], [4.0, 6.0, 8.0])

# Geometry (Vec2, polygonCentroid, triangulatePolygon)
poly = [Vec2(0.0, 0.0), Vec2(6.0, 0.0), Vec2(6.0, 4.0), Vec2(0.0, 4.0)]
center = polygonCentroid(poly)
tris = triangulatePolygon(poly)

# Number theory / combinatorics
combos = combinationsOf(4, 2)

# Graph theory (bridges on adjacency list: 0-1-2-0 triangle + bridge 2-3)
bridges = graphBridges([[1, 2], [0, 2], [0, 1, 3], [2]])

print "avg={avg},d={d.toStringAsFixed(2)}"
print "center=({center.x},{center.y}),tris={tris.length}"
print "combos={combos.length},bridges={bridges.length}"
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, [
        'avg=5.0,d=3.00',
        'center=(3.0,2.0),tris=2',
        'combos=6,bridges=1',
      ]);
    });

    test(
        'section-scoped import `use quds:math::geometry` exposes section symbols and hides unrelated sections',
        () async {
      final session = QudsSession();
      final res = await session.run('''
use quds:math::vector show Vec2
use quds:math::geometry show polygonCentroid, pointToSegmentDistance

dist = pointToSegmentDistance(Vec2(3.0, 4.0), Vec2(0.0, 0.0), Vec2(6.0, 0.0))
c = polygonCentroid([Vec2(0.0, 0.0), Vec2(3.0, 0.0), Vec2(0.0, 3.0)])
print "{dist},{c.x},{c.y}"
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, ['4.0,1.0,1.0']);
    });

    test('quds:async waitAll and withTimeout work natively in interpreter',
        () async {
      final session = QudsSession();
      final res = await session.run('''
use quds:async

fast(v: int) async -> int = v * 10
vals = await waitAll([fast(1), fast(2), fast(3)])
ok = await withTimeout(1s, () -> fast(7))
print vals
print ok
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, ['[10, 20, 30]', '70']);
    });

    test(
        'quds:math native Dart intrinsics match exact linalg results and errors across runs',
        () async {
      final session = QudsSession(allowTopLevelRebind: true);
      final r1 = await session.run('''
use quds:math
a = [[2.0, 1.0], [5.0, 3.0]]
b = [[1.0, 0.0], [2.0, 4.0]]
print a * b
print(~a)
print determinant(a).toStringAsFixed(1)
print solveLinear(a, [4.0, 11.0])
inv = inverse(a)
print((a * inv)[0][0].toStringAsFixed(1))
print((a * inv)[1][1].toStringAsFixed(1))
print dot([1.0, 2.0, 3.0], [4.0, 5.0, 6.0])
print trace(a)
print norm1(a)
print normInf(a)
t1 = tensor([2, 2], [1.0, 2.0, 3.0, 4.0])
t2 = tensor([2, 2], [2.0, 0.0, 1.0, 2.0])
print((t1 * t2).values)
s = sparseMatrix(2, [0, 1], [1, 0], [3.0, 5.0])
print s * [2.0, 4.0]
var caught = ""
try:
  matmul([], [])
catch e:
  caught = "{e}"
print caught
''');
      expect(r1.succeeded, isTrue, reason: '${r1.error}');
      expect(r1.printedLines, [
        '[[4.0, 4.0], [11.0, 12.0]]',
        '[[2.0, 5.0], [1.0, 3.0]]',
        '1.0',
        '[1.0, 2.0]',
        '1.0',
        '1.0',
        '32.0',
        '5.0',
        '7.0',
        '8.0',
        '[4.0, 4.0, 10.0, 8.0]',
        '[12.0, 10.0]',
        'matmul needs non-empty matrices',
      ]);

      // Cross-run persistence: Matrices operators remain active in follow-up cells.
      final r2 = await session.run('print((a * b)[1][1])');
      expect(r2.succeeded, isTrue, reason: '${r2.error}');
      expect(r2.printedLines, ['12.0']);
      await session.dispose();
    });
  });
}
