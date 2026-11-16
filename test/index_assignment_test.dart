import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('indexed mutation conformance runs in Quds', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/index_assignment.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect('${result.stdout}'.split('\n').where((s) => s.startsWith('ok ')),
        hasLength(10));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('readonly methods cannot mutate indexed fields through aliases', () {
    for (final target in ['values', 'this.values', 'alias']) {
      final setup = target == 'alias' ? '    alias = values\n' : '';
      expect(
          () => compile('class Box:\n  values: List<int> required\n'
              '  readonly alter():\n$setup    $target[0] = 1\n'
              'main():\n  print 1\n'),
          throwsA(predicate((e) => '$e'.contains('E307'))));
    }
  });

  test('indexed writes report the original Quds value span', () {
    try {
      compile('main():\n  items = [1]\n  items[0] = "bad"\n',
          file: 'indexed.quds');
      fail('Expected a type diagnostic');
    } on CompilerException catch (error) {
      expect(error.code, 'E300');
      expect(error.span.file, 'indexed.quds');
      expect(error.span.line, 3);
      expect(error.span.column, 14);
    }
  });

  test('indexed Quds kernels compile and execute in JavaScript', () async {
    final directory = Directory.systemTemp.createTempSync('quds-index-web-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('test/index_assignment_web.quds');
    final compiled = compile(input.readAsStringSync(), file: input.path);
    final emitted = File('${directory.path}/index.dart')
      ..writeAsStringSync(compiled.dart);
    final output = '${directory.path}/index.js';
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', emitted.path, '-o', output]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final result = await Process.run('node', [output]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('INDEX WEB OK'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  final rejects = <String, String>{
    'items = [1]\n  items[0] = "bad"': 'E300',
    'items = [1]\n  items[0] /= 2': 'E300',
    'items = [1]\n  items[0.5] = 2': 'E300',
    'items: readonly List<int> = [1]\n  items[0] = 2': 'E307',
    'items: readonly List<List<int>> = [[1]]\n  items[0][0] += 2': 'E307',
    'items: readonly Map<String, int> = map:\n    "x": 1\n  items["x"] = 2':
        'E307',
    'items: List<int>? = null\n  items[0] = 2': 'E308',
    'items = "abc"\n  items[0] = "x"': 'E300',
    'items: Map<String, int> = map:\n  items[1] = 2': 'E300',
    'items: Map<String, int> = map:\n  items["x"] += 2': 'E308',
    'items: Map<String, int> = map:\n  value: int = items["missing"]': 'E300',
    'items: List<int> = [1]\n  items[0] ??= 2': 'E300',
  };
  for (final entry in rejects.entries) {
    test('rejects unsafe indexed access: ${entry.key}', () {
      expect(() => compile('main():\n  ${entry.key}\n'),
          throwsA(predicate((e) => '$e'.contains(entry.value))));
    });
  }
}
