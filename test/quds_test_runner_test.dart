import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUp(() =>
      directory = Directory.systemTemp.createTempSync('quds-test-runner-'));
  tearDown(() => directory.deleteSync(recursive: true));

  Future<ProcessResult> run(String source) {
    final file = File('${directory.path}/suite.quds')
      ..writeAsStringSync(source);
    return Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', file.path]);
  }

  test('Quds tests run even when the source defines main', () async {
    final result = await run('''
main():
  print "main must not run"
test "deliberate mismatch":
  expect(1, 2)
test "continues after a failure":
  expect(3, 3)
''');
    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('FAIL deliberate mismatch:'));
    expect(result.stdout, contains('ok continues after a failure'));
    expect(result.stdout, isNot(contains('main must not run')));
  });

  test('an empty discovery result cannot report success', () async {
    for (final source in [
      'helper() -> int = 1\n',
      'main():\n  print "not a test"\n',
      'group "empty":\n  print "not a test"\n',
    ]) {
      final result = await run(source);
      expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stderr, contains('No tests found'));
      expect(result.stdout, isEmpty);
    }
  });

  test('256 failed Quds tests still produce a failing process status',
      () async {
    final result = await run(
        List.generate(256, (i) => 'test "failure $i":\n  expect(1, 2)\n')
            .join());
    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    expect(RegExp(r'^FAIL ', multiLine: true).allMatches('${result.stdout}'),
        hasLength(256));
  });

  test('legacy asynchronous Quds tests finish in sequence', () async {
    final result = await run('''
_pause() async -> void:
  print "pause"
testFirst() async -> void:
  await _pause()
  print "first"
testSecond():
  print "second"
''');
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, 'pause\nfirst\nsecond\n');
  });

  test('the generated entry bridge does not collide with a user declaration',
      () async {
    final result = await run('''
qudsTestEntrypoint() -> int = 7
qudsTestEntrypoint1() -> int = 8
test "entry collision":
  expect(qudsTestEntrypoint(), 7)
  expect(qudsTestEntrypoint1(), 8)
''');
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, 'ok entry collision\n');
  });
}
