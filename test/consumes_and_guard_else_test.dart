import 'dart:io';

import 'package:quds/quds.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

void main() {
  test('quds test passes primary @consumes and guard destructuring suite',
      () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', 'test/consumes_and_guard_else.quds'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('ok @consumes allows valid branch-exit'));
    expect(result.stdout, contains('ok guard destructuring supports Ok'));
  }, timeout: const Timeout.factor(3));

  test(
      '@consumes rejects use-after-consume across sequences, branches, loops, interfaces, and extensions (E315)',
      () {
    const header = '''
interface Closeable:
  @consumes
  close() -> void:
    return

class Handle implements Closeable:
  id: int
  read() -> int = id
  @consumes
  close() -> void:
    return

extend Handle:
  @consumes
  shutdown() -> void:
    return

_inspect(h: Handle) -> int = h.id
''';

    void expectE315(String body, {String? containsText}) {
      expect(
        () => compile('$header\n$body', file: 'consumes_neg.quds'),
        throwsA(
          isA<CompilerException>().having((e) => e.code, 'code', 'E315').having(
                (e) => e.message,
                'message',
                containsText == null ? anything : contains(containsText),
              ),
        ),
      );
    }

    // Direct use after consume
    expectE315('''
f() -> int:
  h = Handle(id: 1)
  h.close()
  return h.read()
''');

    // Double close
    expectE315('''
f() -> void:
  h = Handle(id: 1)
  h.close()
  h.close()
''');

    // Pass consumed value as argument
    expectE315('''
f() -> int:
  h = Handle(id: 1)
  h.close()
  return _inspect(h)
''');

    // Conditional consume without exit
    expectE315('''
f(flag: bool) -> int:
  h = Handle(id: 1)
  if flag:
    h.close()
  return h.read()
''');

    // Outer variable consumed inside loop that may iterate > 1 time
    expectE315('''
f() -> void:
  h = Handle(id: 1)
  for i in 0..3:
    h.close()
''', containsText: 'inside a loop');

    // Interface @consumes
    expectE315('''
f(c: Closeable) -> void:
  c.close()
  c.close()
''');

    // Extension @consumes
    expectE315('''
f() -> int:
  h = Handle(id: 2)
  h.shutdown()
  return h.read()
''');

    // @consumes rejects arguments
    expect(
      () => compile('''
class Bad:
  @consumes(1)
  close() -> void:
    return
''', file: 'bad_note.quds'),
      throwsA(isA<CompilerException>()),
    );
  });

  test('guard destructuring rejects non-exiting else branches (E316)', () {
    const header = '''
_get(ok: bool) -> Result<int, String>:
  if ok:
    return Ok(42)
  return Error("bad")
''';

    expect(
      () => compile('''
$header
f(ok: bool) -> int:
  Ok(v) = _get(ok) else:
    print "fell through"
  return v
''', file: 'guard_fallthrough.quds'),
      throwsA(
        isA<CompilerException>().having((e) => e.code, 'code', 'E316'),
      ),
    );

    expect(
      () => compile('''
$header
f(ok: bool, flag: bool) -> int:
  Ok(v) = _get(ok) else:
    if flag:
      return 0
  return v
''', file: 'guard_partial_exit.quds'),
      throwsA(
        isA<CompilerException>().having((e) => e.code, 'code', 'E316'),
      ),
    );
  });

  test('strict quds analyze --fatal-infos and VM / JS parity pass', () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-b4-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final entry = File('${sandbox.path}/app.quds')..writeAsStringSync('''
class Box:
  value: int
  @consumes
  take() -> int = value

_fetch(ok: bool) -> Result<Box, String>:
  if ok:
    return Ok(Box(value: 7))
  return Error("nope")

_run(ok: bool) -> int:
  Ok(box) = _fetch(ok) else:
    return -1
  return box.take()

main():
  print "{_run(true)}:{_run(false)}"
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
    expect(run.stdout, '7:-1\n');

    final jsOut = '${sandbox.path}/app.js';
    final jsBuild = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'compile', 'js', '-o', jsOut, entry.path],
      workingDirectory: sandbox.path,
    );
    expect(jsBuild.exitCode, 0, reason: '${jsBuild.stdout}\n${jsBuild.stderr}');
    final nodeRun = await Process.run('node', [jsOut]);
    expect(nodeRun.exitCode, 0, reason: '${nodeRun.stdout}\n${nodeRun.stderr}');
    expect(nodeRun.stdout, '7:-1\n');
  }, timeout: const Timeout.factor(4));
}
