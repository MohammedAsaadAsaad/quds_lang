import 'dart:io';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

const prelude = '''
maybe(value: int) -> int? = value
absent() -> ((int) -> int?)? = null
type Callback = (int) -> int?
type MaybeCallback = ((int) -> int?)?
''';

void main() {
  test('function nullability conformance runs in Quds', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/function_nullability.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect('${result.stdout}'.split('\n').where((s) => s.startsWith('ok ')),
        hasLength(16));
  }, timeout: const Timeout(Duration(minutes: 3)));

  final rejects = <String, (String, String)>{
    'null is not a callback even with a nullable return': (
      'callback: (int) -> int? = null',
      'E300'
    ),
    'alias does not accept null': ('callback: Callback = null', 'E300'),
    'nullable identifier cannot be invoked': (
      'callback: ((int) -> int?)? = null\n  print callback(1)',
      'E308'
    ),
    'nullable alias cannot be invoked': (
      'callback: MaybeCallback = null\n  print callback(1)',
      'E308'
    ),
    'returned nullable callback cannot be invoked': (
      'print absent()(1)',
      'E308'
    ),
    'missing map key cannot be invoked': (
      'callbacks: Map<String, (int) -> int?> = map:\n'
          '  print callbacks["absent"](1)',
      'E308'
    ),
    'fallback preserves nullable result': (
      'callback = absent() ?? maybe\n  value: int = callback(1)',
      'E300'
    ),
    'assertion preserves nullable result': (
      'callback: ((int) -> int?)? = maybe\n  value: int = callback!(1)',
      'E300'
    ),
    'promotion preserves nullable result': (
      'callback: ((int) -> int?)? = maybe\n'
          '  if callback != null:\n    value: int = callback(1)',
      'E300'
    ),
    'nullable return is not a nonnullable return': (
      'callback: (int) -> int = maybe',
      'E300'
    ),
    'nullable callback does not satisfy a required callback parameter': (
      'consume(callback: (int) -> int?) = callback(1)\n'
          '  print consume(absent())',
      'E500'
    ),
    'mutable callback collections remain invariant': (
      'original: List<(int) -> int?> = [maybe]\n'
          '  widened: List<((int) -> int?)?> = original',
      'E300'
    ),
    'callbacks cannot be widened unsafely in argument position': (
      'narrow(value: int) -> int = value\n'
          '  callback: (num) -> int = narrow',
      'E300'
    ),
    'nullable result does not satisfy Object': (
      'value: Object = maybe(1)',
      'E300'
    ),
    'record containing a function is not callable': (
      'pair = (maybe, "name")\n  print pair(1)',
      'E300'
    ),
  };
  for (final entry in rejects.entries) {
    test(entry.key, () {
      expect(() => compile('${prelude}main():\n  ${entry.value.$1}\n'),
          throwsA(predicate((e) => '$e'.contains(entry.value.$2))));
    });
  }

  test('test declarations cannot inherit previous callback promotions', () {
    expect(() => compile('''
${prelude}test "first":
  var callback: MaybeCallback = null
  callback ??= maybe
  expect(callback(1), 1)
test "second":
  callback: MaybeCallback = null
  print callback(1)
'''), throwsA(predicate((e) => '$e'.contains('E308'))));
  });

  test('unsafe callback reports its original Quds span', () {
    try {
      compile(
          'main():\n  callback: ((int) -> int?)? = null\n'
          '  print callback(1)\n',
          file: 'callback.quds');
      fail('Expected a diagnostic');
    } on CompilerException catch (error) {
      expect(error.code, 'E308');
      expect(error.span.file, 'callback.quds');
      expect(error.span.line, 3);
      expect(error.span.column, 9);
    }
  });

  test(
      'function and record Dart output is deterministic and executable on VM and JS',
      () async {
    final directory = Directory.systemTemp.createTempSync('quds-functions-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('test/function_nullability_web.quds');
    final source = input.readAsStringSync();
    final compilation = compile(source, file: input.path);
    final generated = compilation.dart;
    writeSdkBundles(directory.path, compilation);
    expect(generated, compile(source, file: input.path).dart);
    expect(generated,
        File('test/goldens/function_nullability.dart.txt').readAsStringSync());
    final output = File('${directory.path}/program.dart')
      ..writeAsStringSync(generated);
    final analyze = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', output.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, contains('FUNCTION NULLABILITY OK'));
    final js = '${directory.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final run = await Process.run('node', [js]);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, contains('FUNCTION NULLABILITY OK'));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
