import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('extension and intersection identity execute in Quds', () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/extension_identity.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(1));
  });

  test('extension identity analyzes and runs on VM and JavaScript', () async {
    final source = File('test/extension_identity_web.quds').absolute;
    final result = compile(source.readAsStringSync(), file: source.path);
    expect(result.dart,
        contains('HashMap<Object?, Map<String, Object?>>.identity()'));
    expect(result.dart, isNot(contains('Expando<Object?>')));
    expect(
        result.dart,
        File('test/goldens/extension_identity.dart.txt')
            .readAsStringSync()
            .replaceAll('\r\n', '\n'));
    final root =
        Directory.systemTemp.createTempSync('quds-extension-identity-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    const expected = 'true\n1\nfalse\ntrue\ntrue\ntrue\n'
        'true\nfalse\n1\nfalse\n1\ntrue\n2\ntrue\n1\n';
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
