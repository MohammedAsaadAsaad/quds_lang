import 'dart:io';

import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late File runner;
  setUpAll(() {
    directory = Directory.systemTemp.createTempSync('quds-math-graph-');
    final compiled = compile('use quds:math\nmain():\n  print ln(e)\n');
    writeSdkBundles(directory.path, compiled);
    runner = File('${directory.path}/graphs.dart')
      ..writeAsStringSync(File('test/fixtures/math_graph_reference.dart.txt')
          .readAsStringSync());
  });
  tearDownAll(() => directory.deleteSync(recursive: true));

  void verifySummary(ProcessResult result) {
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final summary = RegExp(r'GRAPH CHECKS=(\d+) GRAPHS=1695 FAILURES=0')
        .firstMatch('${result.stdout}');
    expect(summary, isNotNull, reason: '${result.stdout}');
    expect(int.parse(summary!.group(1)!), greaterThan(100000));
    print('${result.stdout}'.trim());
  }

  test('graph algorithms match exhaustive independent oracles on VM', () async {
    verifySummary(
        await Process.run(Platform.resolvedExecutable, [runner.path]));
  });

  test('graph algorithms match exhaustive independent oracles on JavaScript',
      () async {
    final output = '${directory.path}/graphs.js';
    final compiled = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', runner.path, '-o', output]);
    expect(compiled.exitCode, 0,
        reason: '${compiled.stdout}\n${compiled.stderr}');
    ProcessResult result;
    try {
      result = await Process.run('node', [output]);
    } on ProcessException {
      markTestSkipped('JavaScript compiled; Node is unavailable for execution');
      return;
    }
    verifySummary(result);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('Quds graph conformance suite runs through the CLI', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/math_graph.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final titles = RegExp(r'^  test "([^"]+)":', multiLine: true)
        .allMatches(File('test/math_graph.quds').readAsStringSync())
        .map((match) => match.group(1)!)
        .toList();
    expect(titles, hasLength(13));
    final passed = '${result.stdout}'.split('\n').toSet();
    for (final title in titles) {
      expect(passed, contains('ok $title'));
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
