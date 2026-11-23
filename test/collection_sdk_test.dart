import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/sdk.dart';
import 'package:test/test.dart';

void main() {
  test('embedded quds:collection matches lib/sdk/collection.quds', () {
    expect(
      collectionSdkSource,
      File('lib/sdk/collection.quds').readAsStringSync(),
    );
    expect(embeddedSdk['collection'], collectionSdkSource);
  });

  for (final suite in const [
    'test/collection_core.quds',
    'test/collection_imports.quds',
  ]) {
    test('Quds primary suite ${suite.split('/').last}', () async {
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', suite],
      );
      expect(
        result.exitCode,
        0,
        reason: 'STDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}',
      );
      expect(result.stdout, contains('ok '));
    });
  }

  test(
      'quds:collection executes identically on Dart VM and JavaScript with clean dart analyze',
      () async {
    final directory =
        Directory.systemTemp.createTempSync('quds-collection-sdk-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('test/collection_web.quds');
    final compiled = compile(input.readAsStringSync(), file: input.path);
    writeSdkBundles(directory.path, compiled);
    final emitted = File('${directory.path}/program.dart')
      ..writeAsStringSync(compiled.dart);

    final analyze = await Process.run(
      Platform.resolvedExecutable,
      ['analyze', '--fatal-infos', emitted.path],
    );
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');

    final vm =
        await Process.run(Platform.resolvedExecutable, ['run', emitted.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, 'COLLECTION_WEB_OK\n');

    final js = '${directory.path}/program.js';
    final build = await Process.run(
      Platform.resolvedExecutable,
      ['compile', 'js', emitted.path, '-o', js],
    );
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');

    final web = await Process.run('node', [js]);
    expect(web.exitCode, 0, reason: '${web.stdout}\n${web.stderr}');
    expect(web.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
