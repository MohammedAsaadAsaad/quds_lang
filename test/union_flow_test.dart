import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('union flow regressions execute in Quds', () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/union_flow.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(4));
  });
  for (final source in [
    'read(value: int | String, other: int | bool) -> int:\n'
        '  if value is int:\n    if other is int:\n      return 0\n'
        '  return value.length\nmain():\n  print read(3, false)\n',
    'class Notice:\n  event changed: () -> void\n'
        '  read(value: int | String) -> int:\n'
        '    if value is int:\n      raise changed\n'
        '    return value.length\nmain():\n  print Notice().read(3)\n',
  ]) {
    test(
        'conditional execution cannot justify an unsafe union promotion: $source',
        () {
      expect(
          () => compile(source, file: 'unsafe_union.quds'),
          throwsA(isA<CompilerException>().having(
              (error) => error.span.file, 'Quds source', 'unsafe_union.quds')));
    });
  }
  test('union flow golden analyzes and executes on VM and JavaScript',
      () async {
    final input = File('test/union_flow_web.quds').absolute;
    final result = compile(input.readAsStringSync(), file: input.path);
    expect(
        result.dart, compile(input.readAsStringSync(), file: input.path).dart);
    expect(result.dart,
        File('test/goldens/union_flow.dart.txt').readAsStringSync());
    final root = Directory.systemTemp.createTempSync('quds-union-flow-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    const expected =
        'fallback\nnested\nsq\nq\nnumber\nend\nq\ntrue\nnumber\nq\n';
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}${vm.stderr}');
    expect(vm.stdout, expected);
    final js = '${root.path}/main.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final run = await Process.run('node',
        ['-e', 'globalThis.self = globalThis; require(process.argv[1]);', js]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, expected);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('if, match, and try expressions box branches into expected union types',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-union-expr-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final entry = File('${sandbox.path}/app.quds')..writeAsStringSync('''
describe(v: String | int) -> String:
  if v is String:
    return "s:{v}"
  return "i:{v}"

failNow() -> String:
  throw StateError("boom")

main():
  a = 5
  b: String | int = if a > 3: "sd" else: 4
  c: String | int = if a < 3: "sd" else: 4
  d: String | int = match a:
    5: "five"
    _: 0
  e: String | int = try failNow() else 99
  o: Object = if a > 3: "ok" else: 1
  print "{describe(b)}|{describe(c)}|{describe(d)}|{describe(e)}|{o}"
''');

    final qudsBin = '${Directory.current.path}/bin/quds.dart';
    final analyze = await Process.run(
      Platform.resolvedExecutable,
      [qudsBin, 'analyze', '--fatal-infos', entry.path],
      workingDirectory: sandbox.path,
    );
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');

    final run = await Process.run(
      Platform.resolvedExecutable,
      [qudsBin, 'run', entry.path],
      workingDirectory: sandbox.path,
    );
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, 's:sd|i:4|s:five|i:99|ok\n');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
