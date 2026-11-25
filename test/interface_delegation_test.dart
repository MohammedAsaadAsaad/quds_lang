import 'dart:io';

import 'package:quds/quds.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

void main() {
  test('quds test passes primary Batch C suite (implements Interface by field)',
      () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', 'test/interface_delegation.quds'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(
        result.stdout, contains('ok implements Interface by field delegates'));
    expect(
        result.stdout, contains('ok multiple interfaces, generic interfaces'));
  }, timeout: const Timeout.factor(3));

  test(
      'implements by rejects missing delegate field (E700) and incompatible field type (E300)',
      () {
    expect(
      () => compile('''
interface Greeter:
  greet() -> String = ""

class Bad implements Greeter by missing:
  x: int = 1
''', file: 'bad_delegate_missing.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E700')),
    );

    expect(
      () => compile('''
interface Greeter:
  greet() -> String = ""

class Bad implements Greeter by inner:
  inner: int
''', file: 'bad_delegate_type.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E300')),
    );
  });

  test('strict quds analyze --fatal-infos and VM / JS parity pass for Batch C',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-bc-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final entry = File('${sandbox.path}/app.quds')..writeAsStringSync('''
interface Printer:
  prefix: String
  format(msg: String) -> String = msg

class BasePrinter implements Printer:
  prefix: String = ">"
  format(msg: String) -> String = "{prefix}{msg}"

class ShoutPrinter implements Printer by inner:
  private inner: Printer
  format(msg: String) -> String = "{inner.format(msg)}!"

main():
  p: Printer = ShoutPrinter(inner: BasePrinter(prefix: "#"))
  print "{p.prefix}:{p.format("quds")}"
''');

    final analyze = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'analyze', '--fatal-infos', entry.path],
      workingDirectory: sandbox.path,
    );
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');

    final run = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'run', entry.path],
      workingDirectory: sandbox.path,
    );
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, '#:#quds!\n');

    final jsOut = '${sandbox.path}/app.js';
    final jsBuild = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'compile', 'js', '-o', jsOut, entry.path],
      workingDirectory: sandbox.path,
    );
    expect(jsBuild.exitCode, 0, reason: '${jsBuild.stdout}\n${jsBuild.stderr}');
    final nodeRun = await Process.run('node', [jsOut]);
    expect(nodeRun.exitCode, 0, reason: '${nodeRun.stdout}\n${nodeRun.stderr}');
    expect(nodeRun.stdout, '#:#quds!\n');
  }, timeout: const Timeout.factor(4));
}
