import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('acceptance output is deterministic and matches golden Dart', () {
    final source = File('examples/sum.quds').readAsStringSync();
    final output = compile(source, file: 'examples/sum.quds').dart;
    expect(output, File('test/goldens/sum.dart.txt').readAsStringSync());
    expect(compile(source).dart, output);
  });
  test('literal dollar, braces, escaped quotes and triple strings', () async {
    await execute(r'''main():
  print "\{literal\} $notDart \"quoted\""
  print """first
second"""
''', '{literal} \$notDart "quoted"\nfirst\nsecond\n');
  });
  test('quoted interpolation expressions use the same parser', () async {
    await execute('''echo(value: String) = value
main():
  print "nested {echo("hello")}"
''', 'nested hello\n');
  });
  test('acceptance generated Dart analyzes and executes', () async {
    await execute(
        File('examples/sum.quds').readAsStringSync(), 'Total: 60\n12\n');
  });
  test('named blocks preserve written evaluation order, exactly once',
      () async {
    await execute('''mark(value: int) -> int:
  print value
  return value
subtract(a: int, b: int) = a - b
main():
  answer = subtract:
    b: mark(2)
    a: mark(1)
  print answer
  print subtract(mark(3), b: mark(4))
''', '2\n1\n-1\n3\n4\n-1\n');
  });
  test('scopes, shadow, const, branches, lists and Unicode execute', () async {
    await execute('''main():
  const قاعدة = 2
  var total = 0
  for item in [1, 2, 3]:
    total += item
  if total == 6 and not false:
    shadow total = total + قاعدة
    print total
  else:
    print 0
  print total
''', '8\n6\n');
  });
  test('boolean operators short circuit and arithmetic is left associative',
      () async {
    await execute('''flag(value: bool) = value
mark() -> bool:
  print 999
  return true
main():
  print(flag(false) and mark())
  print(flag(true) or mark())
  print(10 - 3 - 2)
  print(1 + 2 * 3)
''', 'false\ntrue\n5\n7\n');
  });
  test('CLI build, diagnostics, usage, and overwrite protection', () async {
    final directory = Directory.systemTemp.createTempSync('quds-cli-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/app.quds')
      ..writeAsStringSync('main():\n  print 42\n');
    final output = File('${directory.path}/app.dart');
    Future<ProcessResult> cli(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/quds.dart', ...args]);
    final built = await cli(['build', source.path]);
    expect(built.exitCode, 0, reason: '${built.stderr}');
    final run = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(run.stdout, '42\n');
    expect((await cli(['build', source.path])).exitCode, 0);
    output.writeAsStringSync('user file');
    expect((await cli(['build', source.path])).exitCode, 73);
    expect(output.readAsStringSync(), 'user file');
    source.writeAsStringSync('main():\n  print unknown\n');
    final bad = await cli(['build', source.path]);
    expect(bad.exitCode, 65);
    expect(bad.stderr, contains('${source.path}:2:9: E200'));
    expect(output.readAsStringSync(), 'user file');
    expect((await cli([])).exitCode, 64);
    expect(
        (await cli(['build', '${directory.path}/missing.quds'])).exitCode, 74);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<void> execute(String source, String stdout) async {
  final directory = Directory.systemTemp.createTempSync('quds-execution-');
  try {
    final output = File('${directory.path}/app.dart')
      ..writeAsStringSync(compile(source).dart);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason:
            '${analysis.stdout}\n${analysis.stderr}\n${output.readAsStringSync()}');
    final run = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(run.stdout, stdout);
    expect(run.stderr, isEmpty);
  } finally {
    directory.deleteSync(recursive: true);
  }
}
