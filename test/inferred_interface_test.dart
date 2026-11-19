import 'dart:convert';
import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('inferred interface defaults execute in Quds', () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/inferred_interface.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(1));
  });

  test('inferred interface defaults analyze and run on VM and JavaScript',
      () async {
    final source = File('test/inferred_interface_web.quds').absolute;
    final result = compile(source.readAsStringSync(), file: source.path);
    expect(result.dart,
        compile(source.readAsStringSync(), file: source.path).dart);
    expect(result.dart, isNot(contains('_seed')));
    expect(result.dart, isNot(contains('<infer>')));
    expect(
        result.dart,
        File('test/goldens/inferred_interface.dart.txt')
            .readAsStringSync()
            .replaceAll('\r\n', '\n'));
    final root =
        Directory.systemTemp.createTempSync('quds-inferred-interface-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final provider =
        File('test/fixtures/inferred_interface/provider.quds').absolute;
    final compiled = compile(provider.readAsStringSync(), file: provider.path);
    expect(compiled.dart, contains(r'$QudsInterfaceDefaults'));
    expect(compiled.dart, contains('_q0()'));
    expect(result.dart, isNot(contains('_q0()')));
    final target =
        File('${root.path}/fixtures/inferred_interface/provider.dart');
    target.parent.createSync(recursive: true);
    target
        .writeAsStringSync(relocateGeneratedLibraries(compiled, '../../').dart);
    writeSdkBundles(root.path, compiled);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path, target.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    const expected = '70\ntrue\n70\n20\n';
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

  test('v11 rebuilds a valid v10 provider without the inferred resolver',
      () async {
    final root = Directory.systemTemp.createTempSync('quds-interface-cache-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
        "name: interface_cache\nenvironment:\n  sdk: '>=3.3.0 <4.0.0'\n");
    final input = File('${root.path}/main.quds')..writeAsStringSync('''
use provider as api
main():
  face: api.Contract = api.Box()
  print face.read()
''');
    final provider = File('${root.path}/provider.quds')
      ..writeAsStringSync(File('test/fixtures/inferred_interface/provider.quds')
          .readAsStringSync());
    final build = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'build', input.path]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final output = File('${root.path}/.dart_tool/quds/out/provider.dart');
    final current = output.readAsStringSync();
    final legacy = current
        .split('\n')
        .where((line) => !line.contains(r'$QudsInterfaceDefaults'))
        .join('\n');
    expect(legacy, isNot(current));
    output.writeAsStringSync(legacy);
    var updated = false;
    final cache = Directory('${root.path}/.dart_tool/quds/cache');
    for (final file in cache.listSync().whereType<File>()) {
      final saved = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      saved['abi'] = 'provider-defaults-v10';
      final paths = (saved['paths'] as List).cast<String>();
      if (paths.length == 1 && paths.single == provider.path) {
        saved['output'] = sha256Hex(utf8.encode(legacy));
        updated = true;
      }
      file.writeAsStringSync(jsonEncode(saved));
    }
    expect(updated, isTrue);
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'run', input.path]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, '70\n');
    expect(output.readAsStringSync(), contains(r'$QudsInterfaceDefaults'));
    for (final file in cache.listSync().whereType<File>()) {
      expect((jsonDecode(file.readAsStringSync()) as Map)['abi'],
          'provider-defaults-v12');
    }
  });
}
