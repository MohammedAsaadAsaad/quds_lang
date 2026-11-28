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

    test(
        'quds:math expanded intrinsics (number, stats, polynomial, FFT/signal) match exact contracts',
        () async {
      final session = QudsSession();
      final res = await session.run('''
use quds:math

# Number theory
print "{gcd(48, 18)},{lcm(12, 18)},{modPow(2, 10, 1000)}"
print "{isPrime(97)},{isPrime(100)},{primesUpTo(30).length}"

# Stats
xs = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
print "{mean(xs)},{median(xs)},{minimum(xs)},{maximum(xs)}"
print "{populationVariance(xs).toStringAsFixed(2)},{populationStddev(xs).toStringAsFixed(2)}"
print "{variance(xs).toStringAsFixed(3)},{stddev(xs).toStringAsFixed(3)}"
print "{percentile(xs, 50.0)},{kahanSum([1.0e16, 1.0, 1.0, -1.0e16])}"
print "{covariance([1.0, 2.0, 3.0], [2.0, 4.0, 6.0])},{correlation([1.0, 2.0, 3.0], [2.0, 4.0, 6.0]).toStringAsFixed(2)}"
sm = softmax([0.0, 0.0])
print "{sm[0].toStringAsFixed(2)},{polyEval([1.0, 2.0, 3.0], 2.0)}"

# Signal / FFT
sig = [1.0, 2.0, 3.0, 4.0]
spec = fftReal(sig)
back = ifft(spec)
print "{spec[0].real.toStringAsFixed(1)},{back[2].real.toStringAsFixed(1)}"
c1 = convolve([1.0, 2.0, 3.0], [4.0, 5.0])
c2 = fftConvolve([1.0, 2.0, 3.0], [4.0, 5.0])
print "{c1[1].toStringAsFixed(1)},{c2[1].toStringAsFixed(1)}"

# Error contract check
var err = ""
try:
  fftReal([1.0, 2.0, 3.0])
catch e:
  err = "{e}"
print err
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, [
        '6,36,24',
        'true,false,10',
        '5.0,4.5,2.0,9.0',
        '4.00,2.00',
        '4.571,2.138',
        '4.5,2.0',
        '2.0,1.00',
        '0.50,17.0',
        '10.0,3.0',
        '13.0,13.0',
        'fft needs a positive power of two',
      ]);
      await session.dispose();
    });

    test(
        'quds:json native intrinsics match parse/encode/path/merge/equals & JsonError contracts',
        () async {
      final session = QudsSession();
      final res = await session.run(r'''
use quds:json

raw = "\{\"user\":\{\"name\":\"Quds\",\"scores\":[10,20,30]\},\"active\":true\}"
objRes = parseJsonObject(raw)
obj = objRes.unwrap()
print jsonPath(obj, "user.name")
print jsonPath(obj, "user.scores.2")
print jsonPath(obj, "user.missing")

userPatch = map:
  "role": "admin"
patch = map:
  "user": userPatch
  "v": 2
merged = jsonMerge(obj, patch)
uName = jsonPath(merged, "user.name")
uRole = jsonPath(merged, "user.role")
ver = merged["v"]
print "{uName},{uRole},{ver}"
encoded = encodeJson(merged)
reparsed = parseJsonObject(encoded).unwrap()
print jsonEquals(merged, reparsed)
print jsonEquals(1, 1.0)

bad = parseJson("\{not-json")
print bad.isError
wrongRoot = parseJsonList("\{\"a\":1\}")
print wrongRoot.isError
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, [
        'Quds',
        '30',
        'null',
        'Quds,admin,2',
        'true',
        'true',
        'true',
        'true',
      ]);
      await session.dispose();
    });

    test(
        'quds:collection native intrinsics match transform/map/set & CollectionError contracts',
        () async {
      final session = QudsSession();
      final res = await session.run(r'''
use quds:collection

print chunkList([1, 2, 3, 4, 5], 2)
print windowList([1, 2, 3, 4, 5], 3, step: 2, partial: true)
print flattenOnce([[1, 2], [3], [4, 5]])
print interleave([1, 3], [2, 4, 6])
print intersperse(["a", "b", "c"], "-")
freqs = frequencies(["a", "b", "a", "c", "a"])
fa = freqs["a"]
fb = freqs["b"]
print "{fa},{fb}"

s1 = [1, 2, 3].toSet()
s2 = [2, 3, 4].toSet()
sd = symmetricDifference(s1, s2).length
sub = isSubsetOf([1, 2].toSet(), s1)
disj = isDisjoint([1].toSet(), [4].toSet())
print "{sd},{sub},{disj}"

m = map:
  "a": 1
  "b": 2
  "c": 3
picked = pickKeys(m, ["a", "c"]).length
omitted = omitKeys(m, ["b"]).length
print "{picked},{omitted}"

var errMsg = ""
try:
  chunkList([1, 2], 0)
catch e:
  errMsg = "{e}"
print errMsg
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, [
        '[[1, 2], [3, 4], [5]]',
        '[[1, 2, 3], [3, 4, 5], [5]]',
        '[1, 2, 3, 4, 5]',
        '[1, 2, 3, 4, 6]',
        '[a, -, b, -, c]',
        '3,1',
        '2,true,true',
        '2,2',
        'CollectionError(chunkList): Chunk size must be at least 1, got 0',
      ]);
      await session.dispose();
    });

    test(
        'quds:text native intrinsics accelerate ASCII and preserve UAX #29 Arabic/Unicode fallback',
        () async {
      final session = QudsSession();
      final res = await session.run(r'''
use quds:text

b1 = isBlankText(" \t\n")
b2 = isBlankText(" Quds ")
print "{b1},{b2}"
print splitText("a,,b,c", ",", keepEmpty: false)
print splitText("a,b,c,d", ",", maxSplits: 2)
print splitTextLines("a\r\nb\nc\n")
print joinText(["x", "y", "z"], separator: "-")
print repeatText("ha", 3, separator: "-")
print escapeTextLiteral("a\nb\"c")

# Fast ASCII path
d1 = editDistance("kitten", "sitting")
d2 = boundedEditDistance("kitten", "sitting", 2)
d3 = boundedEditDistance("kitten", "sitting", 3)
print "{d1},{d2},{d3}"
pref = commonTextPrefix("quds_lang", "quds_studio")
suff = commonTextSuffix("hello.quds", "app.quds")
print "{pref},{suff}"
print textSimilarity("quds", "quds").toStringAsFixed(1)

# Exact UAX #29 Unicode fallback (Arabic combining tashkeel + CRLF)
arPref = commonTextPrefix("قُدس", "قُدم")
arDist = editDistance("قُدس", "قُدم")
print "{arPref},{arDist}"
print editDistance("a\r\nb", "a\nb")
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, [
        'true,false',
        '[a, b, c]',
        '[a, b, c,d]',
        '[a, b, c]',
        'x-y-z',
        'ha-ha-ha',
        r'a\nb\"c',
        '3,null,3',
        'quds_,.quds',
        '1.0',
        'قُد,1',
        '1',
      ]);
      await session.dispose();
    });

    test(
        'Tier-1 Register VM lets local variables named e and pi shadow math constants',
        () async {
      final session = QudsSession();
      final res = await session.run('''
calc():
  var e = 0.0
  var pi = 10.0
  var i = 0
  while i < 5:
    e = e + pi
    i = i + 1
  return e
ans = calc()
ans
''', preferBytecode: true);
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.usedBytecodeVm, isTrue);
      expect(res.value, 50.0);
      await session.dispose();
    });
  });
}
