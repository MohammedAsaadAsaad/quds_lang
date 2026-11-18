import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('required native function values execute in Quds', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/native_function_values.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect('${result.stdout}'.split('\n').where((l) => l.startsWith('ok ')),
        hasLength(4));
  });
  for (final expression in [
    'native.optional',
    'native.named',
    'native.identity'
  ]) {
    test('unrepresented native signature stays rejected: $expression', () {
      expect(
          () => compile(
              'use fixtures/function_values/api.dart as native\nmain():\n  saved = $expression\n',
              file: 'test/native_reject_values.quds'),
          throwsA(
              isA<CompilerException>().having((e) => e.code, 'code', 'E910')));
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
    expect(vm.stdout, '2\n12\n4\n1\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', output.path, '-o', '${root.path}/program.js']);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final js = await Process.run('node', [
      '-e',
      'globalThis.self = globalThis; require(process.argv[1]);',
      '${root.path}/program.js'
    ]);
    expect(js.exitCode, 0, reason: '${js.stderr}');
    expect(js.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
