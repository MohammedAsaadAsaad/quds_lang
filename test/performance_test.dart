import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('benchmark stages imported nominal types and separates measured phases',
      () async {
    final directory = Directory.systemTemp.createTempSync('quds-perf-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/value.quds').writeAsStringSync('''
class Value:
  number: int required
make() -> Value = Value(number: 7)
''');
    final source = File('${directory.path}/main.quds')..writeAsStringSync('''
use "value.quds"
test "imported nominal result":
  value = make()
  expect(value.number, 7)
main():
  value = make()
  print value.number
''');
    Future<ProcessResult> cli(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/quds.dart', ...args]);
    final suite = await cli(['test', source.path]);
    expect(suite.exitCode, 0, reason: '${suite.stdout}\n${suite.stderr}');
    expect(suite.stdout, contains('ok imported nominal result'));
    source.writeAsStringSync(
        'use "value.quds"\nmain():\n  value = make()\n  other = make()\n  print value.number + other.number - 7\n');
    final analyze = await cli(['analyze', source.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final measured = await cli([
      'benchmark',
      source.path,
      '--measure',
      '--warmup',
      '0',
      '--repeat',
      '2'
    ]);
    expect(measured.exitCode, 0,
        reason: '${measured.stdout}\n${measured.stderr}');
    final line = '${measured.stdout}'
        .split('\n')
        .singleWhere((l) => l.startsWith('metrics '));
    final data = jsonDecode(line.substring(8)) as Map<String, dynamic>;
    expect(data['schema'], 1);
    expect(data['output'], '7\n');
    expect(data['warmup'], 0);
    expect(data['repeat'], 2);
    expect(data['dart'], contains('Dart SDK version'));
    expect(data['initial_quds_compile_us'], isNonNegative);
    expect(data['module_staging_us'], isNonNegative);
    expect(data['dart_aot_compile_us'], isNonNegative);
    for (final key in [
      'warm_quds_compile',
      'aot_process_execution_including_startup'
    ]) {
      expect(data[key]['samples_us'], hasLength(2));
      expect(data[key]['median_us'], isNonNegative);
    }
    expect(
        directory
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
        isEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));
  test('benchmark rejects an empty repeat count', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/quds.dart',
      'benchmark',
      'missing.quds',
      '--measure',
      '--repeat',
      '0'
    ]);
    expect(result.exitCode, 64);
    expect(result.stderr, contains('Usage: quds benchmark'));
  });
}
