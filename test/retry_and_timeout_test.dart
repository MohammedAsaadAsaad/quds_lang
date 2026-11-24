import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

void main() {
  test('quds test passes primary Batch D suite (retry and timeout)', () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', 'test/retry_and_timeout.quds'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('ok sync retry succeeds'));
    expect(result.stdout, contains('ok async retry with delay'));
    expect(result.stdout, contains('ok timeout succeeds before deadline'));
    expect(result.stdout, contains('ok retry and timeout remain usable'));
  }, timeout: const Timeout.factor(4));

  test('retry and timeout static errors reject invalid types and sync misuse',
      () {
    expect(
      () => compile('''
main():
  retry "three": print("hi")
''', file: 'bad_retry_attempts.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E300')),
    );

    expect(
      () => compile('''
main() async:
  retry 3, delay: 100: print("hi")
''', file: 'bad_retry_delay.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E300')),
    );

    expect(
      () => compile('''
main():
  retry 3, delay: 10ms: print("hi")
''', file: 'bad_retry_sync_delay.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E803')),
    );

    expect(
      () => compile('''
main():
  timeout 10ms: print("hi")
''', file: 'bad_timeout_sync.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E803')),
    );

    expect(
      () => compile('''
main() async:
  timeout 50: print("hi")
''', file: 'bad_timeout_duration.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E300')),
    );
  });

  test('strict quds analyze --fatal-infos and VM / JS parity pass for Batch D',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-bd-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final entry = File('${sandbox.path}/app.quds')..writeAsStringSync('''
class _State:
  static var tries: int = 0

step() async -> String:
  _State.tries += 1
  await Future.delayed(1ms)
  if _State.tries < 2:
    throw StateError("not yet")
  return "ready-{_State.tries}"

slow() async -> String:
  await Future.delayed(100ms)
  return "late"

main() async:
  a = retry 3, delay: 2ms: await step()
  b = timeout 15ms: await slow() else: "timed-out"
  print "{a}|{b}"
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
    expect(run.stdout, 'ready-2|timed-out\n');

    final jsOut = '${sandbox.path}/app.js';
    final jsBuild = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'compile', 'js', '-o', jsOut, entry.path],
      workingDirectory: sandbox.path,
    );
    expect(jsBuild.exitCode, 0, reason: '${jsBuild.stdout}\n${jsBuild.stderr}');
    final nodeRun = await Process.run(
      'node',
      [
        '-e',
        'globalThis.self = globalThis; require(process.argv[1]);',
        jsOut,
      ],
    );
    expect(nodeRun.exitCode, 0, reason: '${nodeRun.stdout}\n${nodeRun.stderr}');
    expect(nodeRun.stdout, 'ready-2|timed-out\n');
  }, timeout: const Timeout.factor(4));
}
