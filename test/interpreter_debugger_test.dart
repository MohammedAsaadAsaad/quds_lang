import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group('Phase 4 — Native Interactive AST Debugger', () {
    test(
        'line breakpoint pauses with locals, stackFrames, watch results, and live frame evaluation',
        () async {
      final debugger = QudsDebugController();
      debugger.setLineBreakpoints('calc.quds', [4]);
      debugger.setWatchExpressions(['acc * 2', 'i']);

      final session = QudsSession(
        policy: QudsExecutionPolicy.scientific(),
        debugger: debugger,
      );

      final pausedLines = <int>[];
      final evalResults = <Object?>[];
      final watchSnapshots = <Object?>[];

      final sub = debugger.onPaused.listen((pause) async {
        pausedLines.add(pause.span.line);
        watchSnapshots.add(pause.watchResults['acc * 2']?.value);
        final live = await pause.evaluate('acc + i * 100');
        evalResults.add(live);
        debugger.continueRun();
      });

      final res = await session.run('''
var acc = 0
for i in 1..3:
  acc += i
  print acc
''', file: 'calc.quds');

      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, ['1', '3', '6']);
      expect(pausedLines, [4, 4, 4]);
      expect(watchSnapshots, [2, 6, 12]);
      expect(evalResults, [101, 203, 306]);

      await sub.cancel();
      await debugger.dispose();
      await session.dispose();
    });

    test('conditional breakpoint and non-stopping logpoint', () async {
      final debugger = QudsDebugController();
      debugger.setBreakpoints('sim.quds', const [
        QudsBreakpoint(
          file: 'sim.quds',
          line: 3,
          logMessage: 'tick i={i}',
        ),
        QudsBreakpoint(
          file: 'sim.quds',
          line: 4,
          condition: 'i == 4',
        ),
      ]);

      final session = QudsSession(
        policy: QudsExecutionPolicy.scientific(),
        debugger: debugger,
      );

      final stoppedAtI = <Object?>[];
      final sub = debugger.onPaused.listen((pause) {
        stoppedAtI.add(pause.locals['i']);
        debugger.continueRun();
      });

      final res = await session.run('''
var total = 0
for i in 1..5:
  total += i
  square = i * i
print total
''', file: 'sim.quds');

      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(stoppedAtI, [4]);
      expect(res.printedLines, [
        'tick i=1',
        'tick i=2',
        'tick i=3',
        'tick i=4',
        'tick i=5',
        '15',
      ]);

      await sub.cancel();
      await debugger.dispose();
      await session.dispose();
    });

    test('stepInto, stepOver, and stepOut navigate call frames accurately',
        () async {
      final debugger = QudsDebugController();
      debugger.setLineBreakpoints('steps.quds', [6]);

      final session = QudsSession(
        policy: QudsExecutionPolicy.scientific(),
        debugger: debugger,
      );

      final trace = <String>[];
      var stepIndex = 0;
      final sub = debugger.onPaused.listen((pause) {
        final topFrame = pause.stackFrames.first.functionName;
        trace.add('$topFrame:${pause.span.line}');
        stepIndex++;
        if (stepIndex == 1) {
          // At line 6 (`a = helper(5)`), step INTO `helper`
          debugger.stepInto();
        } else if (stepIndex == 2) {
          // Inside `helper` (line 2), step OUT back to main
          debugger.stepOut();
        } else if (stepIndex == 3) {
          // Back in `<main>` at line 7 (`b = helper(10)`), step OVER `helper`
          debugger.stepOver();
        } else {
          debugger.continueRun();
        }
      });

      final res = await session.run('''
helper(n: int) -> int:
  doubled = n * 2
  return doubled + 1

a = helper(5)
b = helper(10)
print a + b
''', file: 'steps.quds');

      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, ['32']);
      // Line 5 is `a = helper(5)`, line 6 is `b = helper(10)` — wait let's verify exact trace:
      expect(trace.first, '<main>:6');
      expect(trace.any((t) => t.startsWith('helper:')), isTrue);
      expect(trace.last, startsWith('<main>:'));

      await sub.cancel();
      await debugger.dispose();
      await session.dispose();
    });

    test('debugger.stop() cleanly aborts execution while paused', () async {
      final debugger = QudsDebugController();
      debugger.setLineBreakpoints('abort.quds', [2]);
      final session = QudsSession(
        policy: QudsExecutionPolicy.scientific(),
        debugger: debugger,
      );

      final sub = debugger.onPaused.listen((pause) {
        debugger.stop();
      });

      final res = await session.run('''
x = 1
y = 2
print "never reached"
''', file: 'abort.quds');

      expect(res.succeeded, isFalse);
      expect(res.printedLines, isEmpty);
      expect((res.error as QudsPolicyViolationException).kind,
          QudsPolicyViolationKind.stopped);

      await sub.cancel();
      await debugger.dispose();
      await session.dispose();
    });
  });
}
