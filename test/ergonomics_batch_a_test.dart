import 'dart:io';

import 'package:quds/quds.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

void main() {
  test(
      'quds test passes primary Batch A suite (guard, :name shorthand, Duration literals)',
      () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', 'test/ergonomics_batch_a.quds'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('ok guard cond else:'));
    expect(result.stdout, contains('ok :name shorthand named arguments'));
    expect(result.stdout, contains('ok Duration literals support'));
  }, timeout: const Timeout.factor(3));

  test('guard rejects non-exiting else (E316) and non-bool condition (E300)',
      () {
    expect(
      () => compile('''
f(x: int) -> int:
  guard x > 0 else:
    print "bad"
  return x
''', file: 'guard_fallthrough.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E316')),
    );

    expect(
      () => compile('''
f(x: int) -> int:
  guard x else: return 0
  return x
''', file: 'guard_non_bool.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E300')),
    );
  });

  test('formatQuds preserves :name shorthand spacing and Duration literals',
      () {
    const input = '''
f(name: String, age: int) -> String:
  d = 1.5s
  return make(:name, :age, delay: 250ms)
''';
    final formatted = formatQuds(input);
    expect(formatted, contains('make(:name, :age, delay: 250ms)'));
    expect(formatted, contains('d = 1.5s'));
  });

  test('strict quds analyze --fatal-infos and VM / JS parity pass for Batch A',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-ba-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final entry = File('${sandbox.path}/app.quds')..writeAsStringSync('''
const limit = 2s

class Job:
  name: String
  timeout: Duration

_check(job: Job?) -> String:
  guard job != null else: return "empty"
  guard job.timeout <= limit else: return "slow"
  return "{job.name}:{job.timeout.inMilliseconds}"

main():
  name = "sync"
  timeout = 1.5s
  j = Job(:name, :timeout)
  print "{_check(j)}|{_check(null)}"
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
    expect(run.stdout, 'sync:1500|empty\n');

    final jsOut = '${sandbox.path}/app.js';
    final jsBuild = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'compile', 'js', '-o', jsOut, entry.path],
      workingDirectory: sandbox.path,
    );
    expect(jsBuild.exitCode, 0, reason: '${jsBuild.stdout}\n${jsBuild.stderr}');
    final nodeRun = await Process.run('node', [jsOut]);
    expect(nodeRun.exitCode, 0, reason: '${nodeRun.stdout}\n${nodeRun.stderr}');
    expect(nodeRun.stdout, 'sync:1500|empty\n');
  }, timeout: const Timeout.factor(4));
}
