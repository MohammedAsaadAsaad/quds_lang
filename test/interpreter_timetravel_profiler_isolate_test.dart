import 'package:quds/interpreter.dart';
import 'package:quds/interpreter_isolate.dart';
import 'package:test/test.dart';

void main() {
  group(
      'Package 4 — Time-Travel Debugging, QudsProfiler (Call Tree + Hotspots), and QudsIsolateRunner',
      () {
    test(
        'Time-Travel debugger records history snapshots and steps backward/forward',
        () async {
      final debugger = QudsDebugController(recordHistory: true);
      final session = QudsSession(
        policy: QudsExecutionPolicy.standard(),
        debugger: debugger,
      );

      final res = await session.run('''
var total = 0
for i in 1..4:
  total += i * 10
print total
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, ['100']);
      expect(debugger.history.length, greaterThan(4));
      expect(debugger.canStepBack, isTrue);

      final lastIdx = debugger.historyIndex;
      final prev = debugger.stepBack();
      expect(prev, isNotNull);
      expect(debugger.historyIndex, lastIdx - 1);

      final start = debugger.jumpToHistory(0);
      expect(start, isNotNull);
      expect(start!.span.line, 1);
      expect(debugger.canStepBack, isFalse);
      expect(debugger.canStepForward, isTrue);

      final next = debugger.stepForward();
      expect(next, isNotNull);
      expect(debugger.historyIndex, 1);

      await debugger.dispose();
      await session.dispose();
    });

    test(
        'QudsProfiler captures recursive fib(5) Call Tree and per-line hotspots',
        () async {
      final profiler = QudsProfiler();
      final session = QudsSession(
        policy: QudsExecutionPolicy.standard(),
        profiler: profiler,
      );

      final res = await session.run('''
fib(n: int) -> int:
  if n <= 2:
    return 1
  return fib(n - 1) + fib(n - 2)

print fib(5)
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, ['5']);

      // fib(5) makes 9 total recursive calls: fib(5) -> fib(4), fib(3) -> ...
      expect(profiler.totalCalls, 9);
      expect(profiler.callTrees.length, 1);
      final root = profiler.callTrees.first;
      expect(root.name, 'fib');
      expect(root.argsSummary, '5');
      expect(root.returnSummary, '5');
      expect(root.children.length, 2);
      expect(root.children[0].argsSummary, '4');
      expect(root.children[1].argsSummary, '3');

      final spots = profiler.hotspots(top: 5);
      expect(spots, isNotEmpty);
      expect(spots.first.hits, greaterThanOrEqualTo(9));

      await session.dispose();
    });

    test(
        'QudsIsolateRunner executes off main isolate with streaming prints and supports instant cancel',
        () async {
      final streamedPrints = <String>[];
      final handle = QudsIsolateRunner.start('''
var s = 0
for i in 1..200:
  s += i
print "sum={s}"
s
''');
      final sub = handle.events.listen((e) {
        if (e.kind == 'print' && e.text != null) streamedPrints.add(e.text!);
      });
      final res = await handle.result;
      await sub.cancel();

      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.stdout, 'sum=20100');
      expect(streamedPrints, ['sum=20100']);
      expect(res.valueSummary, '20100');

      // Test instant hard cancellation of an infinite loop in a background isolate
      final longHandle = QudsIsolateRunner.start('''
var x = 0
while true:
  x += 1
''', maxSteps: 50000000, timeoutMs: 30000);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      longHandle.cancel();
      final cancelledRes = await longHandle.result;
      expect(cancelledRes.succeeded, isFalse);
      expect(cancelledRes.cancelled, isTrue);
    });
  });
}
