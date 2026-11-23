import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

void main() {
  test(
      'formatRichDiagnostic renders rustc-style snippet, carets, and help while preserving line 1',
      () {
    const source = '''
class Handle:
  read() -> int = 1
  @consumes
  close() -> void:
    return

main():
  h = Handle()
  h.close()
  print h.read()
''';
    CompilerException? caught;
    try {
      compile(source, file: 'demo.quds');
    } on CompilerException catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    final rich = formatRichDiagnostic(caught!, source: source);
    final lines = rich.split('\n');
    expect(lines.first, caught.toString());
    expect(rich, contains('10 |   print h.read()'));
    expect(rich, contains('^'));
    expect(rich, contains('= help:'));
    expect(rich, contains('@consumes'));
  });

  test('CLI prints rustc-style source snippet and help hint on compile errors',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-diag-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final bad = File('${sandbox.path}/bad.quds')..writeAsStringSync('''
main():
  x = 1
  if true:
    x = 2
''');
    final result = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'build', bad.path],
      workingDirectory: sandbox.path,
    );
    expect(result.exitCode, 65);
    expect(result.stderr, contains('${bad.path}:4:5: E202:'));
    expect(result.stderr, contains('4 |     x = 2'));
    expect(result.stderr, contains('^'));
    expect(result.stderr, contains('= help:'));
    expect(result.stderr, contains('quds fix --apply'));
  }, timeout: const Timeout.factor(2));

  test(
      'fixQudsSource fixes E203 shadow, E202 var, and W002 unused imports while preserving when test: imports',
      () {
    final sandbox = Directory.systemTemp.createTempSync('quds-fix-unit-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    File('${sandbox.path}/used.quds')
      ..writeAsStringSync('doubleIt(n: int) -> int = n * 2\n');
    File('${sandbox.path}/unused.quds')
      ..writeAsStringSync('neverCalled() -> int = 99\n');
    File('${sandbox.path}/test_only.quds')
      ..writeAsStringSync('testHelper() -> int = 7\n');

    final appPath = '${sandbox.path}/app.quds';
    const broken = '''
use used
use unused
use test_only

compute(flag: bool) -> int:
  total = 10
  if flag:
    total = 20
  val = 1
  if flag:
    val: int = 5
    return total + doubleIt(val)
  return total

when test:
  test "keeps test_only import":
    expect(testHelper(), equals(7))
''';
    File(appPath).writeAsStringSync(broken);

    final fixed = fixQudsSource(broken, file: appPath);
    expect(fixed.changed, isTrue);
    expect(
        fixed.fixes.map((f) => f.code), containsAll(['E202', 'E203', 'W002']));
    expect(fixed.source, contains('use used'));
    expect(fixed.source, contains('use test_only'));
    expect(fixed.source, isNot(contains('use unused')));
    expect(fixed.source, contains('var total = 10'));
    expect(fixed.source, contains('shadow val: int = 5'));

    // Resulting source compiles cleanly in both normal and test modes
    expect(() => compile(fixed.source, file: appPath), returnsNormally);
    expect(() => compile(fixed.source, file: appPath, testing: true),
        returnsNormally);
  });

  test(
      'quds fix CLI supports --help, --dry-run preview, --apply write, and idempotent re-run',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-fix-cli-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    File('${sandbox.path}/helper.quds')
      ..writeAsStringSync('addOne(n: int) -> int = n + 1\n');
    File('${sandbox.path}/extra.quds')
      ..writeAsStringSync('unusedFn() -> int = 0\n');
    final entry = File('${sandbox.path}/main.quds')..writeAsStringSync('''
use helper
use extra

main():
  count = 1
  count = addOne(count)
  if true:
    count: int = 9
    print "{count}"
  print "{count}"
''');
    final original = entry.readAsStringSync();

    // 1. quds fix --help
    final help = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'fix', '--help'],
      workingDirectory: sandbox.path,
    );
    expect(help.exitCode, 0);
    expect(help.stdout, contains('quds fix [--dry-run|-n|--apply]'));

    // 2. Default (dry-run) reports proposed fixes and does NOT modify the file
    final dry = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'fix', '--dry-run', sandbox.path],
      workingDirectory: sandbox.path,
    );
    expect(dry.exitCode, 0, reason: '${dry.stdout}\n${dry.stderr}');
    expect(dry.stdout, contains('[E202]'));
    expect(dry.stdout, contains('[E203]'));
    expect(dry.stdout, contains('[W002]'));
    expect(dry.stdout, contains('Run with --apply to write changes.'));
    expect(entry.readAsStringSync(), original);

    // 3. --apply writes fixes in place
    final applied = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'fix', '--apply', sandbox.path],
      workingDirectory: sandbox.path,
    );
    expect(applied.exitCode, 0, reason: '${applied.stdout}\n${applied.stderr}');
    expect(applied.stdout, contains('Applied 3 fixes in 1 file.'));
    final updated = entry.readAsStringSync();
    expect(updated, isNot(contains('use extra')));
    expect(updated, contains('var count = 1'));
    expect(updated, contains('shadow count: int = 9'));

    // 4. Re-running quds fix is idempotent
    final second = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'fix', sandbox.path],
      workingDirectory: sandbox.path,
    );
    expect(second.exitCode, 0, reason: '${second.stdout}\n${second.stderr}');
    expect(second.stdout, contains('Nothing to fix!'));

    // 5. Fixed program executes and passes strict quds analyze --fatal-infos
    final run = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'run', entry.path],
      workingDirectory: sandbox.path,
    );
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, '9\n2\n');

    final analyze = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'analyze', '--fatal-infos', entry.path],
      workingDirectory: sandbox.path,
    );
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
  }, timeout: const Timeout.factor(4));
}
