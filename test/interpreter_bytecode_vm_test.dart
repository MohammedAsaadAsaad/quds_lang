import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group(
      'Package 5 — Stack Bytecode Compiler & Virtual Machine (QudsBytecodeVm)',
      () {
    test(
        'compiles & runs recursive Fibonacci, loops, math intrinsics, lists, and matches AST output identically',
        () async {
      const program = '''
use dart:math as m

fib(n: int) -> int:
  if n <= 2:
    return 1
  return fib(n - 1) + fib(n - 2)

var acc = 0.0
var vals = []
for i in 1..20:
  acc += m.sqrt(i * 1.0)
  vals.add(i * i)

f12 = fib(12)
print "fib12={f12} sum={acc.toStringAsFixed(3)} len={vals.length} last={vals[19]}"
f12
''';

      // Verify disassembly works cleanly
      final bc = QudsBytecodeCompiler.tryCompileSource(program);
      expect(bc, isNotNull);
      expect(bc!.disassemble(), contains('CALL_FN'));

      // Compare AST execution vs Bytecode VM execution via QudsSession
      final astSession = QudsSession(policy: QudsExecutionPolicy.standard());
      final vmSession = QudsSession(policy: QudsExecutionPolicy.standard());

      final astRes = await astSession.run(program, preferBytecode: false);
      final vmRes = await vmSession.run(program, preferBytecode: true);

      expect(astRes.succeeded, isTrue, reason: '${astRes.error}');
      expect(vmRes.succeeded, isTrue, reason: '${vmRes.error}');
      expect(astRes.usedBytecodeVm, isFalse);
      expect(vmRes.usedBytecodeVm, isTrue);
      expect(vmRes.stdout, astRes.stdout);
      expect(vmRes.value, astRes.value);
      expect(vmRes.value, 144);
      expect(vmSession.workspace['f12']?.value, 144);

      await astSession.dispose();
      await vmSession.dispose();
    });

    test(
        'enforces maxSteps and maxCallDepth in Bytecode VM and transparently falls back to AST for viz scripts',
        () async {
      final limited = QudsSession(
        policy: QudsExecutionPolicy.standard(maxSteps: 500),
      );
      final res = await limited.run(
        '''
var i = 0
while true:
  i += 1
''',
        preferBytecode: true,
      );
      expect(res.succeeded, isFalse);
      expect(res.error, isA<QudsPolicyViolationException>());

      // Script using quds:viz transparently falls back to full AST evaluator!
      final vizSession = QudsSession(policy: QudsExecutionPolicy.standard());
      final vizRes = await vizSession.run(
        '''
use quds:viz as viz
viz.plot([0.0, 1.0, 2.0], [0.0, 1.0, 4.0], title: "Fallback OK")
''',
        preferBytecode: true,
      );
      expect(vizRes.succeeded, isTrue, reason: '${vizRes.error}');
      expect(vizRes.usedBytecodeVm, isFalse);
      expect(vizRes.lastPlot, isNotNull);

      await limited.dispose();
      await vizSession.dispose();
    });

    test(
        'Bytecode VM accelerates compute-heavy gradient descent & recursion significantly',
        () async {
      const bench = '''
fib(n: int) -> int:
  if n <= 2:
    return 1
  return fib(n - 1) + fib(n - 2)

var total = 0
for i in 1..2000:
  total += (i * 3) % 17

res = fib(18) + total
print "res={res}"
res
''';
      final astSession = QudsSession(policy: QudsExecutionPolicy.standard());
      final vmSession = QudsSession(policy: QudsExecutionPolicy.standard());

      final astRes = await astSession.run(bench, preferBytecode: false);
      final vmRes = await vmSession.run(bench, preferBytecode: true);

      expect(astRes.succeeded, isTrue);
      expect(vmRes.succeeded, isTrue);
      expect(vmRes.usedBytecodeVm, isTrue);
      expect(vmRes.value, astRes.value);
      expect(vmRes.stdout, astRes.stdout);

      await astSession.dispose();
      await vmSession.dispose();
    });

    test(
        'register VM optimizations (monotonic inference, typed lists, CSE, loop inversion, FMA) match AST identically',
        () async {
      const suite = '''
use dart:math as m

fib(n: int):
  if n <= 1:
    return n
  return fib(n - 1) + fib(n - 2)

mandel_small():
  w = 24
  h = 24
  max_iter = 40
  var total = 0
  var py = 0
  while py < h:
    cy = -1.25 + (py * 2.5) / h
    var px = 0
    while px < w:
      cx = -2.0 + (px * 3.0) / w
      var zx = 0.0
      var zy = 0.0
      var it = 0
      while it < max_iter and (zx * zx + zy * zy) <= 4.0:
        nx = zx * zx - zy * zy + cx
        zy = 2.0 * zx * zy + cy
        zx = nx
        it = it + 1
      total = total + it
      px = px + 1
    py = py + 1
  return total

sieve_small():
  limit = 1000
  var flags = []
  var k = 0
  while k <= limit:
    flags.add(1)
    k = k + 1
  flags[0] = 0
  flags[1] = 0
  var p = 2
  while p * p <= limit:
    if flags[p] == 1:
      var mult = p * p
      while mult <= limit:
        flags[mult] = 0
        mult = mult + p
    p = p + 1
  var cnt = 0
  var i = 2
  while i <= limit:
    cnt = cnt + flags[i]
    i = i + 1
  return cnt

nbody_small():
  n = 12
  var xs = []
  var ys = []
  var vxs = []
  var vys = []
  var i = 0
  while i < n:
    ang = i * 0.61803398875
    r = 1.0 + (i % 5) * 0.25
    xs.add(r * m.cos(ang))
    ys.add(r * m.sin(ang))
    vxs.add(-0.3 * m.sin(ang))
    vys.add(0.3 * m.cos(ang))
    i = i + 1
  var step = 0
  while step < 5:
    i = 0
    while i < n:
      xi = xs[i]
      yi = ys[i]
      var ax = 0.0
      var ay = 0.0
      var j = 0
      while j < n:
        if i != j:
          dx = xs[j] - xi
          dy = ys[j] - yi
          dist2 = dx * dx + dy * dy + 0.05
          inv_d = 1.0 / m.sqrt(dist2)
          f = inv_d * inv_d * inv_d
          ax = ax + dx * f
          ay = ay + dy * f
        j = j + 1
      vxs[i] = vxs[i] + ax * 0.01
      vys[i] = vys[i] + ay * 0.01
      i = i + 1
    i = 0
    while i < n:
      xs[i] = xs[i] + vxs[i] * 0.01
      ys[i] = ys[i] + vys[i] * 0.01
      i = i + 1
    step = step + 1
  var cs = 0.0
  i = 0
  while i < n:
    cs = cs + xs[i] * xs[i] + ys[i] * ys[i]
    i = i + 1
  return cs

f14 = fib(14)
ms = mandel_small()
ss = sieve_small()
nb = nbody_small()
print "f14={f14} ms={ms} ss={ss} nb={nb.toStringAsFixed(6)}"
f14 + ms + ss
''';

      final bc = QudsBytecodeCompiler.tryCompileSource(suite);
      expect(bc, isNotNull);
      final dis = bc!.disassemble();
      // Verify key register-VM specializations actually activated:
      expect(dis, contains('CALL_FN_SELF_I1_SUB'));
      expect(dis, contains('RET_SELF_I'));
      expect(dis, contains('NEW_INT_LIST'));
      expect(dis, contains('NEW_FLOAT_LIST'));
      expect(dis, contains('I_INC_JLE'));
      expect(dis, contains('I_INC_JLT'));
      expect(dis, contains('I_ADD_LIST_GET'));
      expect(dis, contains('F_MUL_ADD'));

      final astSession = QudsSession(policy: QudsExecutionPolicy.standard());
      final vmSession = QudsSession(policy: QudsExecutionPolicy.standard());

      final astRes = await astSession.run(suite, preferBytecode: false);
      final vmRes = await vmSession.run(suite, preferBytecode: true);

      expect(astRes.succeeded, isTrue, reason: '${astRes.error}');
      expect(vmRes.succeeded, isTrue, reason: '${vmRes.error}');
      expect(vmRes.usedBytecodeVm, isTrue);
      expect(vmRes.stdout, astRes.stdout);
      expect(vmRes.value, astRes.value);
      expect(vmSession.workspace['f14']?.value, 377);
      expect(vmSession.workspace['ss']?.value, 168);

      await astSession.dispose();
      await vmSession.dispose();
    });

    test(
        'loop-inversion handles 0-iteration, break, continue, and self-recursion callDepth policy',
        () async {
      const edgeCases = '''
var zero_iters = 0
var i = 5
var n = 5
while i < n:
  zero_iters = zero_iters + 1
  i = i + 1

var zero_le = 0
var k = 6
while k <= n:
  zero_le = zero_le + 1
  k = k + 1

var brk_sum = 0
var b = 0
var lim = 10
while b < lim:
  if b == 4:
    break
  brk_sum = brk_sum + b
  b = b + 1

var cont_sum = 0
var c = 0
while c < lim:
  c = c + 1
  if c % 2 == 0:
    continue
  cont_sum = cont_sum + c

print "{zero_iters},{zero_le},{brk_sum},{cont_sum},{i},{k},{b}"
brk_sum + cont_sum
''';
      final astSession = QudsSession(policy: QudsExecutionPolicy.standard());
      final vmSession = QudsSession(policy: QudsExecutionPolicy.standard());
      final astRes = await astSession.run(edgeCases, preferBytecode: false);
      final vmRes = await vmSession.run(edgeCases, preferBytecode: true);

      expect(astRes.succeeded, isTrue, reason: '${astRes.error}');
      expect(vmRes.succeeded, isTrue, reason: '${vmRes.error}');
      expect(vmRes.usedBytecodeVm, isTrue);
      expect(vmRes.stdout, astRes.stdout);
      expect(vmRes.value, astRes.value);
      expect(vmRes.stdout, '0,0,6,25,5,6,4');

      // Verify maxCallDepth policy on self-recursive pure-int fast path!
      final depthLimited = QudsSession(
        policy: QudsExecutionPolicy.standard(maxCallDepth: 8),
      );
      final depthRes = await depthLimited.run(
        '''
fib(n: int):
  if n <= 1:
    return n
  return fib(n - 1) + fib(n - 2)
fib(20)
''',
        preferBytecode: true,
      );
      expect(depthRes.succeeded, isFalse);
      expect(depthRes.error, isA<QudsPolicyViolationException>());

      await astSession.dispose();
      await vmSession.dispose();
      await depthLimited.dispose();
    });
  });
}
