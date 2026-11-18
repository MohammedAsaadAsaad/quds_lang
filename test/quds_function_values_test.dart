import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

const declarations = '''identity<T>(value: T) -> T = value
bounded<T: num>(value: T) -> T = value
choose(value: int) -> String = "integer"
choose(value: String) -> String = "text"
ambiguous(value: int) -> int = value
ambiguous(value: num) -> int = 1
shape<T>(value: T) -> T = value
shape<T>(value: List<T>) -> T = value[0]
withDefault<T>(value: T? = null) -> T? = value
variadic<T>(...items: T) -> int = items.length
awkward<T>(value: T? = null, other: int) -> int = other
unused<T>():
  print "unused"
ordinary(value: int) -> int = value
''';

void main() {
  test('Quds function values execute the primary Quds declarations', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/quds_function_values.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect('${result.stdout}'.split('\n').where((l) => l.startsWith('ok ')),
        hasLength(5));
  });
  final invalid = <String, String>{
    'saved = choose': 'E311',
    'saved: (bool) -> String = choose': 'E311',
    'saved: (int) -> int = ambiguous': 'E311',
    'saved = identity': 'E302',
    'saved = bounded<String>': 'E300',
    'saved: (String) -> String = bounded': 'E300',
    'saved = identity<int, String>': 'E300',
    'saved: (String) -> int = identity<int>': 'E300',
    'saved = shape<int>': 'E311',
    'saved = awkward<int>': 'E910',
    'saved = ordinary<int>': 'E300',
    'saved: () -> void = unused': 'E302',
    'saved: (int) -> int = identity\n  print saved("wrong")': 'E300',
  };
  for (final entry in invalid.entries) {
    test('rejects Quds function value: ${entry.key}', () {
      expect(
          () => compile('$declarations\nmain():\n  ${entry.key}\n',
              file: 'quds_values_bad.quds'),
          throwsA(isA<CompilerException>()
              .having((e) => e.code, 'code', entry.value)
              .having((e) => e.span.file, 'source', 'quds_values_bad.quds')));
    });
  }
  test('selected Quds values produce deterministic Dart and execute on VM/JS',
      () async {
    final input = File('test/quds_function_values_web.quds').absolute;
    final result = compile(input.readAsStringSync(), file: input.path);
    expect(
        result.dart, compile(input.readAsStringSync(), file: input.path).dart);
    expect(result.dart,
        File('test/goldens/quds_function_values.dart.txt').readAsStringSync());
    final root = Directory.systemTemp.createTempSync('quds-own-values-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/program.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final helper =
        File('test/fixtures/quds_function_values/helpers.quds').absolute;
    final compiledHelper =
        compile(helper.readAsStringSync(), file: helper.path);
    final helperOutput =
        File('${root.path}/fixtures/quds_function_values/helpers.dart');
    helperOutput.parent.createSync(recursive: true);
    helperOutput.writeAsStringSync(
        relocateGeneratedLibraries(compiledHelper, '../../').dart);
    writeSdkBundles(root.path, compiledHelper);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stderr}');
    expect(vm.stdout,
        '3\nQuds\n4\n9\ninteger\ntext\n5\nsecond\n6\n7\n8\n10\ninteger\n11\n');
    final js = '${root.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final node = await Process.run('node',
        ['-e', 'globalThis.self = globalThis; require(process.argv[1]);', js]);
    expect(node.exitCode, 0, reason: '${node.stderr}');
    expect(node.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
