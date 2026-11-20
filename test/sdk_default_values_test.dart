import 'dart:convert';
import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('SDK section defaults execute in Quds', () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/sdk_default_values.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(1));
  });

  test('SDK section defaults analyze and run on VM and JavaScript', () async {
    final source = File('test/sdk_default_values_web.quds').absolute;
    final result = compile(source.readAsStringSync(), file: source.path);
    expect(result.dart,
        compile(source.readAsStringSync(), file: source.path).dart);
    expect(result.dart, contains(r'$QudsDefaultabd0fdc129fa6f8c3e1f'));
    expect(result.dart, isNot(contains(r'_$qudsDefaultOmitted')));
    expect(
        result.dart,
        File('test/goldens/sdk_default_values.dart.txt')
            .readAsStringSync()
            .replaceAll('\r\n', '\n'));
    final root = Directory.systemTemp.createTempSync('quds-sdk-defaults-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    const expected = 'true\ntrue\ntrue\n';
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

  test('v12 rebuilds a valid v11 program that inlined an SDK default',
      () async {
    final root = Directory.systemTemp.createTempSync('quds-sdk-cache-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
        "name: sdk_cache\nenvironment:\n  sdk: '>=3.3.0 <4.0.0'\n");
    final input = File('${root.path}/main.quds')..writeAsStringSync('''
use quds:math::distribution as stats
main():
  saved = stats.normalPdf
  print saved == stats.normalPdf
  print saved(0.0) > 0.0
''');
    final build = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'build', input.path]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final output = File('${root.path}/.dart_tool/quds/out/main.dart');
    final current = output.readAsStringSync();
    expect(current, contains(r'$QudsDefault'));
    final legacy = current.replaceAll(
        RegExp(r'stats\.\$QudsDefault[0-9a-f]+'), 'stats.normalPdf');
    expect(legacy, isNot(current));
    output.writeAsStringSync(legacy);
    final cache = Directory('${root.path}/.dart_tool/quds/cache');
    var updated = false;
    for (final file in cache.listSync().whereType<File>()) {
      final saved = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      saved['abi'] = 'provider-defaults-v11';
      final paths = (saved['paths'] as List).cast<String>();
      if (paths.length == 1 && paths.single == input.path) {
        saved['output'] = sha256Hex(utf8.encode(legacy));
        updated = true;
      }
      file.writeAsStringSync(jsonEncode(saved));
    }
    expect(updated, isTrue);
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'run', input.path]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, 'true\ntrue\n');
    expect(output.readAsStringSync(), contains(r'$QudsDefault'));
    for (final file in cache.listSync().whereType<File>()) {
      expect((jsonDecode(file.readAsStringSync()) as Map)['abi'],
          'provider-defaults-v16');
    }
  });
}
