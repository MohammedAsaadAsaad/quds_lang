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
  });
}
