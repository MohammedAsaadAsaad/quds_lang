import 'dart:io';

import 'package:quds/interpreter.dart';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

/// Compiles [source] to Dart and runs it on the Dart VM, returning trimmed stdout.
String _runCompiledOnDartVm(String source) {
  final dir = Directory.systemTemp.createTempSync('quds_parity_');
  try {
    final qudsFile = File('${dir.path}/main.quds')..writeAsStringSync(source);
    final compiled = compile(source, file: qudsFile.path);
    writeSdkBundles(dir.path, compiled);
    final dartFile = File('${dir.path}/main.dart')
      ..writeAsStringSync(compiled.dart);
    final res = Process.runSync(Platform.resolvedExecutable, [dartFile.path]);
    if (res.exitCode != 0) {
      fail(
          'Compiled Dart failed (${res.exitCode}):\n${res.stderr}\n--- Dart ---\n${compiled.dart}');
    }
    return (res.stdout as String).trimRight().replaceAll('\r\n', '\n');
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  group('Phase 1 — Core Quds Interpreter & Session', () {
    test(
        'zero dart:io imports in package:quds/interpreter.dart transitive graph',
        () {
      final visited = <String>{};
      final queue = <String>['lib/interpreter.dart'];
      final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
          multiLine: true);

      while (queue.isNotEmpty) {
        final path = queue.removeLast();
        if (!visited.add(path)) continue;
        final content = File(path).readAsStringSync();
        for (final m in importRe.allMatches(content)) {
          final uri = m.group(1)!;
          expect(uri, isNot('dart:io'),
              reason:
                  '$path must not import dart:io for Web/Flutter portability');
          if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
          final resolved = File(path).parent.uri.resolve(uri).toFilePath();
          final rel = resolved.replaceFirst('${Directory.current.path}/', '');
          queue.add(rel);
        }
      }
      expect(visited.length, greaterThanOrEqualTo(6));
    });

    test('arithmetic, chain comparisons (once-eval), and string interpolation',
        () async {
      final session = QudsSession();
      final result = await session.run('''
var calls = 0
probe(v: int) -> int:
  calls += 1
  return v

ok = 1 < probe(5) <= 10
msg = "ok={ok}, calls={calls}, sum={2 + 3 * 4}"
print msg
''');
      expect(result.succeeded, isTrue, reason: '${result.error}');
      expect(result.printedLines, ['ok=true, calls=1, sum=14']);
      expect(session.getVariable('ok'), isTrue);
      expect(session.getVariable('calls'), 1);
    });

    test('QUDS-090 binding immutability and explicit shadow', () async {
      final session = QudsSession();
      final failReassign = await session.run('''
x = 10
x = 20
''');
      expect(failReassign.succeeded, isFalse);
      expect(failReassign.error, isA<QudsRuntimeException>());
      expect((failReassign.error as QudsRuntimeException).code, 'E202');

      final session2 = QudsSession();
      final failShadow = await session2.run('''
x = 10
if true:
  var x = 20
''');
      expect(failShadow.succeeded, isFalse);
      expect((failShadow.error as QudsRuntimeException).code, 'E203');

      final session3 = QudsSession();
      final okShadow = await session3.run('''
var total = 10
if true:
  shadow x = 5
  total += x
print total
''');
      expect(okShadow.succeeded, isTrue, reason: '${okShadow.error}');
      expect(okShadow.printedLines, ['15']);
    });

    test('for loop with \$ context, step, labels, and LoopExpression',
        () async {
      final session = QudsSession();
      final res = await session.run('''
var tags: List<String> = []
for v in [10, 20, 30]:
  tags.add("{\$.index}:{\$.first}:{\$.last}:{v}")

var evens: List<int> = []
for i in 0..8 step 2:
  evens.add(i)

found = for n in 1..20:
  if n * n > 50:
    break n
else:
  -1

print tags.join("|")
print evens
print found
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, [
        '0:true:false:10|1:false:false:20|2:false:true:30',
        '[0, 2, 4, 6, 8]',
        '8',
      ]);
    });

    test(
        'functions: defaults (QUDS-086), named args, variadics (QUDS-087), overloads (QUDS-085), capture (QUDS-091)',
        () async {
      final session = QudsSession();
      final res = await session.run('''
scale(x: int, factor: int = x * 2) -> int = x + factor

sumAll(...nums: int) -> int:
  var s = 0
  for n in nums:
    s += n
  return s

describe(v: int) -> String = "int:{v}"
describe(v: String) -> String = "str:{v}"

var fns: List<Function> = []
for i in 1..3:
  fns.add(capture(i) -> i * 10)

print scale(5)
print scale(factor: 3, x: 5)
print sumAll(1, 2, 3, 4)
print describe(7)
print describe("hi")
f0 = fns[0]
f1 = fns[1]
f2 = fns[2]
print([f0(), f1(), f2()])
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, [
        '15',
        '8',
        '10',
        'int:7',
        'str:hi',
        '[10, 20, 30]',
      ]);
    });

    test('collections, slices, comprehensions, parallel swap, where, do/result',
        () async {
      final session = QudsSession();
      final res = await session.run('''
nums = [1, 2, 3, 4, 5]
squares = [x * x for x in nums if x % 2 == 1]
sliced = nums[1..3]
var a = 1
var b = 9
a, b = b, a
area = w * h where:
  w = 6
  h = 7
calc = do:
  t = 4
  result t * t + 1
print squares
print sliced
print "{a},{b},{area},{calc}"
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, [
        '[1, 9, 25]',
        '[2, 3, 4]',
        '9,1,42,17',
      ]);
    });

    test(
        'persistent QudsSession workspace, host variable injection, custom host functions, and event stream',
        () async {
      final session = QudsSession();
      final observed = <String>[];
      final sub = session.events.listen((e) {
        if (e is QudsPrintEvent) observed.add(e.text);
      });

      session.setVariable('baseRate', 0.15, mutable: false);
      session.registerFunction(
          'doubleIt', (pos, named, ctx) => (pos[0] as num) * 2);

      final r1 = await session.run('var balance = 1000.0');
      expect(r1.succeeded, isTrue);

      final r2 = await session.run('''
balance += balance * baseRate
doubled = doubleIt(balance)
print doubled
''');
      expect(r2.succeeded, isTrue, reason: '${r2.error}');
      expect(r2.printedLines, ['2300.0']);
      expect(session.workspace.containsKey('balance'), isTrue);
      expect(session.workspace['balance']!.typeName, 'double');
      expect(session.workspace['doubled']!.value, 2300.0);

      await Future<void>.delayed(Duration.zero);
      expect(observed, ['2300.0']);

      session.clear();
      expect(session.workspace, isEmpty);
      await sub.cancel();
      await session.dispose();
    });

    test('compiler parity: interpreted stdout matches compiled Dart VM stdout',
        () async {
      const parityProgram = '''
fib(n: int) -> int:
  if n <= 1:
    return n
  return fib(n - 1) + fib(n - 2)

main():
  var acc = 0
  for i in 1..6:
    acc += fib(i)
  items = [x * 3 for x in [1, 2, 3, 4] if x > 1]
  print "acc={acc}"
  print items
''';
      final vmOut = _runCompiledOnDartVm(parityProgram);

      final session = QudsSession();
      final runRes = await session.run('$parityProgram\nmain()\n');
      expect(runRes.succeeded, isTrue, reason: '${runRes.error}');
      expect(runRes.stdout, vmOut);
    });
  });
}
