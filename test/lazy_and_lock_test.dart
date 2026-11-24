import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

void main() {
  test('quds test passes primary Batch B suite (lazy and lock + Mutex)',
      () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', 'test/lazy_and_lock.quds'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('ok lazy evaluates once on first read'));
    expect(
        result.stdout, contains('ok lock mutex serializes concurrent async'));
  }, timeout: const Timeout.factor(3));

  test('lazy and lock enforce static safety rules (E100, E202, E803, E300)',
      () {
    // Uninitialized lazy local is rejected
    expect(
      () => compile('''
f() -> int:
  lazy x: int
  return 0
''', file: 'lazy_open.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E100')),
    );

    // Reassigning a lazy local is rejected (E202)
    expect(
      () => compile('''
f() -> int:
  lazy x = 1
  x = 2
  return x
''', file: 'lazy_reassign.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E202')),
    );

    // lock outside async is rejected (E803)
    expect(
      () => compile('''
use quds:core
f() -> void:
  m = Mutex()
  lock m:
    print "sync"
''', file: 'lock_sync.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E803')),
    );

    // lock on non-lock object is rejected (E300)
    expect(
      () => compile('''
f() async -> void:
  lock 42:
    print "bad"
''', file: 'lock_bad_target.quds'),
      throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E300')),
    );
  });

  test('strict quds analyze --fatal-infos and VM / JS parity pass for Batch B',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-bb-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final entry = File('${sandbox.path}/app.quds')..writeAsStringSync('''
use quds:core

class Box:
  base: int
  lazy computed = base * 10

_step(m: Mutex, box: Box) async -> int:
  lock m
  return await Future<int>.value(box.computed)

main() async:
  m = Mutex()
  b = Box(base: 4)
  v = await _step(m, b)
  print "{v}:{m.isLocked()}"
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
    expect(run.stdout, '40:false\n');

    final jsOut = '${sandbox.path}/app.js';
    final jsBuild = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'compile', 'js', '-o', jsOut, entry.path],
      workingDirectory: sandbox.path,
    );
    expect(jsBuild.exitCode, 0, reason: '${jsBuild.stdout}\n${jsBuild.stderr}');
    final nodeRun = await Process.run(
      'node',
      ['-e', 'globalThis.self = globalThis; require(process.argv[1]);', jsOut],
    );
    expect(nodeRun.exitCode, 0, reason: '${nodeRun.stdout}\n${nodeRun.stderr}');
    expect(nodeRun.stdout, '40:false\n');
  }, timeout: const Timeout.factor(4));
}
