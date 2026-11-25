import 'dart:io';

import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test('extension and intersection identity execute in Quds', () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/extension_identity.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(6));
  });

  test('readonly extension methods reject writes to the receiver', () {
    expect(
        () => compile(
            'class Box:\n  var value: int = 0\n'
            'extend Box:\n  readonly mutate() -> int:\n'
            '    this.value = 3\n    return 1\nmain():\n  print 1\n',
            file: 'readonly_extension.quds'),
        throwsA(isA<CompilerException>().having(
            (error) => error.span.file, 'source', 'readonly_extension.quds')));
  });

  test('extension identity analyzes and runs on VM and JavaScript', () async {
    final source = File('test/extension_identity_web.quds').absolute;
    final result = compile(source.readAsStringSync(), file: source.path);
    expect(result.dart, contains(r'WeakReference<$QudsValueSlot>'));
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
    const expected = 'true\n1\ntrue\nfalse\ntrue\ntrue\ntrue\n'
        'true\nfalse\n1\nfalse\n1\ntrue\n2\ntrue\n1\n'
        '1\n1\ntrue\nfalse\ntrue\nfalse\n4\n3\n9\nfalse\nfalse\n3\n3\ntrue\n5\n11\nfalse\ntrue\ntrue\n3\n4\n';
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
