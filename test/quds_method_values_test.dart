import 'dart:io';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

String declarations() =>
    File('test/quds_method_values.quds')
        .readAsStringSync()
        .split('test "')
        .first +
    '''
class Limited:
  keep<U>(value: U, count: int = 1) -> U = value
  first<U>(...values: U) -> U = values[0]
class Fresh:
  readonly read() -> List<int> = [1]
class DerivedUtility extends Utility:
  tag: int = 0
''';

void main() {
  test('Quds method values execute the primary Quds suite', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/quds_method_values.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect('${result.stdout}'.split('\n').where((l) => l.startsWith('ok ')),
        hasLength(5));
  });
  final invalid = <String, String>{
    'view: readonly ListBox<int> = ListBox<int>(values: [1])\n  saved: () -> List<int> = view.read':
        'E300',
    'saved = Box<num>(stored: 1).echo': 'E302',
    'saved = Box<num>(stored: 1).keep<String>': 'E300',
    'saved: (String) -> String = Box<num>(stored: 1).keep': 'E300',
    'saved = Box<num>(stored: 1).echo<int, String>': 'E300',
    'saved: (String) -> int = Box<num>(stored: 1).echo<int>': 'E300',
    'saved = Box.echo<int>': 'E300',
    'saved = Utility().echo<int>': 'E300',
    'absent: Box<num>? = null\n  saved = absent.echo<int>': 'E308',
    'view: readonly Counter = Counter()\n  saved = view.change<int>': 'E307',
    'view: readonly Counter = Counter()\n  saved: (int) -> int = view.change':
        'E307',
    'saved = helpers.Vault(stored: 1).secret<int>': 'E206',
    'saved = helpers.Vault(stored: 1).guarded<int>': 'E207',
    'view: readonly ListBox<int> = ListBox<int>(values: [1])\n  saved = view.read\n  saved()[0] = 2':
        'E307',
    'saved = Box<num>(stored: 1).echo<int>\n  print saved("bad")': 'E300',
    'saved = helpers.Vault.echo<int>': 'E300',
  };
  for (final entry in invalid.entries) {
    test('rejects method value: ${entry.key}', () {
      expect(
          () => compile('${declarations()}\nmain():\n  ${entry.key}\n',
              file: 'test/quds_method_values_bad.quds'),
          throwsA(isA<CompilerException>()
              .having((e) => e.code, 'code', entry.value)
              .having((e) => e.span.file, 'source',
                  'test/quds_method_values_bad.quds')));
    });
  }
  test('a named default before a required method parameter is one value',
      () async {
    final source = '''
class Awkward:
  keep<U>(value: U? = null, other: int) -> int = other
main():
  box = Awkward()
  saved = box.keep<int>
  print saved(4)
  print saved(4, value: null)
  print saved == box.keep<int>
''';
    final compiled = compile(source, file: 'awkward_method_value.quds');
    final root = Directory.systemTemp.createTempSync('quds-awkward-method-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(compiled.dart);
    writeSdkBundles(root.path, compiled);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}${vm.stderr}');
    expect(vm.stdout, '4\n4\ntrue\n');
  });
  test('readonly this cannot leak a mutating generic method value', () {
    expect(
        () => compile('''class Escaper:
  change<U>(value: U) -> U = value
  readonly steal() -> (int) -> int = this.change<int>
main():
  print "unused"
''', file: 'readonly_method_value.quds'),
        throwsA(isA<CompilerException>()
            .having((e) => e.code, 'code', 'E307')
            .having(
                (e) => e.span.file, 'source', 'readonly_method_value.quds')));
  });
  test('method value Dart golden analyzes and executes on VM and JavaScript',
      () async {
    final input = File('test/quds_method_values_web.quds').absolute;
    final result = compile(input.readAsStringSync(), file: input.path);
    expect(
        result.dart, compile(input.readAsStringSync(), file: input.path).dart);
    expect(
        result.dart,
        File('test/goldens/quds_method_values.dart.txt')
            .readAsStringSync()
            .replaceAll('\r\n', '\n'));
    final root = Directory.systemTemp.createTempSync('quds-method-values-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/program.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final helper =
        File('test/fixtures/quds_method_values/helpers.quds').absolute;
    final compiledHelper =
        compile(helper.readAsStringSync(), file: helper.path);
    final helperOutput =
        File('${root.path}/fixtures/quds_method_values/helpers.dart');
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
    expect('${vm.stdout}'.replaceAll('\r\n', '\n'),
        '3\n4\n2\n5\nshadow\n6\n7\n8\n9\n10\nnull\n11\n1\n2\n3\n4\n12\n13\n14\n');
    final js = '${root.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final node = await Process.run('node',
        ['-e', 'globalThis.self = globalThis; require(process.argv[1]);', js]);
    expect(node.exitCode, 0, reason: '${node.stderr}');
    expect('${node.stdout}'.replaceAll('\r\n', '\n'),
        '${vm.stdout}'.replaceAll('\r\n', '\n'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
