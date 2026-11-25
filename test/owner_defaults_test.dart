import 'dart:io';

import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test('value, mixin, and protected defaults execute in Quds', () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/owner_defaults.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(1));
  });

  test('owner defaults analyze and run on VM and JavaScript', () async {
    final source = File('test/owner_defaults_web.quds').absolute;
    final result = compile(source.readAsStringSync(), file: source.path);
    expect(result.dart, isNot(contains('_seed')));
    expect(
        result.dart,
        File('test/goldens/owner_defaults.dart.txt')
            .readAsStringSync()
            .replaceAll('\r\n', '\n'));
    final provider =
        File('test/fixtures/owner_defaults/provider.quds').absolute;
    final compiled = compile(provider.readAsStringSync(), file: provider.path);
    expect(compiled.dart, contains(r'$QudsMethodDefault'));
    expect(compiled.dart, contains('_q0()'));
    expect(compiled.dart, contains('/// protected'));
    expect(result.dart, isNot(contains('_q0()')));
    final root = Directory.systemTemp.createTempSync('quds-owner-defaults-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final target = File('${root.path}/fixtures/owner_defaults/provider.dart');
    target.parent.createSync(recursive: true);
    target
        .writeAsStringSync(relocateGeneratedLibraries(compiled, '../../').dart);
    writeSdkBundles(root.path, compiled);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path, target.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    const expected = 'true\n12\ntrue\n4\n4\ntrue\n';
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}${vm.stderr}');
    expect(vm.stdout, expected);
    final js = '${root.path}/main.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final node = await Process.run('node',
        ['-e', 'globalThis.self = globalThis; require(process.argv[1]);', js]);
    expect(node.exitCode, 0, reason: '${node.stderr}');
    expect(node.stdout, expected);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a protected method value stays inside a subtype', () {
    expect(
        () => compile('''
use fixtures.owner_defaults.provider as api
main():
  base = api.Base()
  saved = base.read
''', file: 'test/owner_defaults_reject.quds'),
        throwsA(isA<CompilerException>()
            .having((error) => error.code, 'code', 'E207')
            .having((error) => error.span.file, 'file',
                'test/owner_defaults_reject.quds')
            .having((error) => error.span.line, 'line', 4)));
  });
}
