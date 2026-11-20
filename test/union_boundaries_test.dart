import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('union calls and narrowing execute in Quds', () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/union_boundaries.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(1));
  });

  test('union boundaries analyze and run on VM and JavaScript', () async {
    final source = File('test/union_boundaries_web.quds').absolute;
    final result = compile(source.readAsStringSync(), file: source.path);
    expect(result.dart, contains('api.\$QudsUnionCall'));
    expect(result.dart, contains('as QudsUnion_int_or_String_String).value'));
    expect(
        result.dart,
        File('test/goldens/union_boundaries.dart.txt')
            .readAsStringSync()
            .replaceAll('\r\n', '\n'));
    final provider =
        File('test/fixtures/union_boundaries/provider.quds').absolute;
    final compiled = compile(provider.readAsStringSync(), file: provider.path);
    expect(compiled.dart, contains('QudsUnion_int_or_String_String'));
    final root = Directory.systemTemp.createTempSync('quds-union-boundaries-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final target = File('${root.path}/fixtures/union_boundaries/provider.dart');
    target.parent.createSync(recursive: true);
    target
        .writeAsStringSync(relocateGeneratedLibraries(compiled, '../../').dart);
    writeSdkBundles(root.path, compiled);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path, target.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    const expected = 'n1\nsa\nn2\nsb\n4\n';
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
}
