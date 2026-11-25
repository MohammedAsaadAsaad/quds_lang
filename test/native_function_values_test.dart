import 'dart:io';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test('required native function values execute in Quds', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/native_function_values.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect('${result.stdout}'.split('\n').where((l) => l.startsWith('ok ')),
        hasLength(13));
  });
  for (final expression in ['native.identity']) {
    test('unrepresented native signature stays rejected: $expression', () {
      expect(
          () => compile(
              'use fixtures/function_values/api.dart as native\nmain():\n  saved = $expression\n',
              file: 'test/native_reject_values.quds'),
          throwsA(
              isA<CompilerException>().having((e) => e.code, 'code', 'E910')));
    });
  }
  final invalidCalls = <String, String>{
    'saved: (num) -> int = native.identity': 'E300',
    'saved: (int) -> String = native.identity': 'E300',
    'saved: (String) -> String = native.bounded': 'E300',
    'saved: (String) -> String = native.Box<num>(1).select': 'E300',
    'saved: (value: int required) -> int = native.identity': 'E300',
    'saved: () -> void = native.unused': 'E302',
    'receiver: native.Counter? = null\n  saved: (int) -> int = receiver?.identity':
        'E300',
    'view: readonly native.Counter = native.Counter(1)\n  saved: (int) -> int = view.identity':
        'E307',
    'saved = native.Counter(1).callback<int>': 'E910',
    'saved = native.bounded<String>': 'E300',
    'saved = native.identity<int, String>': 'E300',
    'saved = native.increment<int>': 'E300',
    'saved = native.Box<num>(1).select<String>': 'E300',
    'saved = native.identity<int>\n  saved("wrong")': 'E300',
    'saved: (String) -> int = native.identity<int>': 'E300',
    'saved = native.named\n  saved()': 'E500',
    'saved = native.named\n  saved(1)': 'E300',
    'saved = native.named\n  saved(other: 1)': 'E500',
    'saved = native.named\n  saved(value: "bad")': 'E300',
    'saved = native.named\n  saved(value: 1, value: 2)': 'E201',
    'saved = native.optional\n  saved(1, 2)': 'E300',
    'saved: ([value: int]) -> int = native.increment': 'E300',
    'saved: () -> int = native.named': 'E300',
    'saved: (value: int = 0) -> int = native.named': 'E300',
    'saved: (other: int required) -> int = native.named': 'E300',
    'saved: (value: num required) -> int = native.named': 'E300',
    'saved: (value: int required, value: int = 0) -> int = native.named':
        'E503',
    'saved: ([value: int], int) -> int = native.optional': 'E503',
    'saved: ([value: int], extra: int = 0) -> int = native.optional': 'E300',
  };
  for (final entry in invalidCalls.entries) {
    test('function metadata rejects ${entry.key}', () {
      expect(
          () => compile(
              'use fixtures/function_values/api.dart as native\nmain():\n  ${entry.key}\n',
              file: 'test/native_reject_values.quds'),
          throwsA(isA<CompilerException>()
              .having((e) => e.code, 'code', entry.value)
              .having((e) => e.span.file, 'source',
                  'test/native_reject_values.quds')));
    });
  }
  test('native function values preserve type and readonly boundaries', () {
    expect(
        () => compile('''use fixtures/function_values/api.dart as native
main():
  view: readonly native.Counter = native.Counter(1)
  saved = view.add
''', file: 'test/native_reject_values.quds'),
        throwsA(
            isA<CompilerException>().having((e) => e.code, 'code', 'E307')));
    expect(
        () => compile('''use fixtures/function_values/api.dart as native
main():
  saved: (String) -> int = native.increment
''', file: 'test/native_reject_values.quds'),
        throwsA(
            isA<CompilerException>().having((e) => e.code, 'code', 'E300')));
  });
  test('native function values analyze and agree on VM and JavaScript',
      () async {
    final input = File('test/native_function_values_web.quds').absolute;
    final compilation = compile(input.readAsStringSync(), file: input.path);
    String normalizeNativePrefixes(String source) {
      final ids = <String, String>{};
      return source
          .replaceAll(Directory.current.absolute.uri.toString(), '<repo>/')
          .replaceAllMapped(RegExp(r'_qNative[0-9a-f]{12}'), (m) {
        final key = m.group(0)!;
        return ids.putIfAbsent(key, () => '_qNative<${ids.length}>');
      });
    }

    final normalized = normalizeNativePrefixes(compilation.dart);
    expect(
        normalized,
        normalizeNativePrefixes(
            File('test/goldens/native_function_values.dart.txt')
                .readAsStringSync()
                .replaceAll('\r\n', '\n')));
    expect(compilation.dart,
        compile(input.readAsStringSync(), file: input.path).dart);
    final root = Directory.systemTemp.createTempSync('quds-native-values-web-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/program.dart')
      ..writeAsStringSync(compilation.dart.replaceAll(
          "import 'fixtures/function_values/api.dart'",
          "import '${File('test/fixtures/function_values/api.dart').absolute.uri}'"));
    writeSdkBundles(root.path, compilation);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stderr}');
    expect('${vm.stdout}'.replaceAll('\r\n', '\n'),
        '2\n12\n4\n1\n5\n1:7:3:9\n8\n4\n1:7:3:9\n1:2:3:9\nCABD\n13\ngeneric\n14\n15\n16\n17\nnull\n18\n8\n19\n20\n21\nnull\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', output.path, '-o', '${root.path}/program.js']);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final js = await Process.run('node', [
      '-e',
      'globalThis.self = globalThis; require(process.argv[1]);',
      '${root.path}/program.js'
    ]);
    expect(js.exitCode, 0, reason: '${js.stderr}');
    expect('${js.stdout}'.replaceAll('\r\n', '\n'),
        '${vm.stdout}'.replaceAll('\r\n', '\n'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
