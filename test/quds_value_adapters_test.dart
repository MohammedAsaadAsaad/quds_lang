import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('Quds value adapters execute', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/quds.dart',
      'test',
      'test/quds_value_adapters.quds',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(
        '${result.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(5));
  });

  test('deferred imports and guarded results keep their diagnostics', () {
    expect(
        () => compile('''
use dart:core as core
main():
  core.loadLibrary()
''', file: 'deferred_bad.quds'),
        throwsA(isA<CompilerException>()
            .having((error) => error.code, 'code', 'E300')
            .having(
                (error) => error.span.file, 'source', 'deferred_bad.quds')));
    expect(
        () => compile('''
use dart:core deferred
main():
  print 1
''', file: 'deferred_prefix.quds'),
        throwsA(isA<CompilerException>().having(
            (error) => error.span.file, 'source', 'deferred_prefix.quds')));
    expect(
        () => compile('''
class Fresh:
  readonly read() -> List<int> = [1]
main():
  view: readonly Fresh = Fresh()
  saved = view.read
  saved()[0] = 2
''', file: 'readonly_value.quds'),
        throwsA(isA<CompilerException>()
            .having((error) => error.code, 'code', 'E307')
            .having(
                (error) => error.span.file, 'source', 'readonly_value.quds')));
  });

  test('adapter programs analyze and execute on the VM and JavaScript',
      () async {
    final input = File('test/quds_value_adapters_web.quds').absolute;
    final source = input.readAsStringSync();
    final result = compile(source, file: input.path);
    expect(result.dart, compile(source, file: input.path).dart);
    expect(result.dart, contains('identical('));
    expect(result.dart, contains('pick\$1'));
    expect(result.dart, contains('Utility.echo'));
    final root = Directory.systemTemp.createTempSync('quds-value-adapters-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/program.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final helper =
        File('test/fixtures/quds_value_adapters/helpers.quds').absolute;
    final compiledHelper =
        compile(helper.readAsStringSync(), file: helper.path);
    expect(compiledHelper.dart, contains('pick\$1'));
    expect(compiledHelper.dart, contains('pick\$2'));
    final helperOutput =
        File('${root.path}/fixtures/quds_value_adapters/helpers.dart');
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
    expect(vm.stdout, 'Quds\nempty\n4\n2\nnull\nAda\n6\n3\ninteger\ntext\n');
    final js = '${root.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final node = await Process.run('node', [
      '-e',
      'globalThis.self = globalThis; require(process.argv[1]);',
      js,
    ]);
    expect(node.exitCode, 0, reason: '${node.stderr}');
    expect(node.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
