import 'dart:convert';
import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('Quds constructor and async packet regressions execute', () async {
    final run = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/quds.dart',
      'test',
      'test/constructor_packet_regressions.quds'
    ]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(11));
  });
  final invalid = <String, (String, String)>{
    'self reference': (
      'class Owner:\n  value: int\n  init(this.value: int = value):\n    require true\nmain():\n  print 1\n',
      'E503'
    ),
    'forward reference': (
      'class Owner:\n  first: int\n  second: int\n  init(this.first: int = second, this.second: int = 1):\n    require true\nmain():\n  print 1\n',
      'E503'
    ),
  };
  for (final entry in invalid.entries) {
    test('constructor rejects ${entry.key} at Quds coordinates', () {
      expect(
          () => compile(entry.value.$1, file: 'constructor_bad.quds'),
          throwsA(isA<CompilerException>()
              .having((error) => error.code, 'code', entry.value.$2)
              .having(
                  (error) => error.span.file, 'file', 'constructor_bad.quds')));
    });
  }
  for (final source in [
    'print api.Bounded<String>().value',
    'print api.Box(first: "bad").second',
    'print api.Box.named(first: "bad").second',
    'print api.Box.named(3).second',
    'print api.Box._hidden(1, 2).second',
  ]) {
    test('constructor imports reject $source', () {
      final file = File('test/constructor_packet_bad.quds').absolute.path;
      expect(
          () => compile(
              'use fixtures.constructor_packet_regressions.provider as api\nmain():\n  $source\n',
              file: file),
          throwsA(isA<CompilerException>()
              .having((error) => error.span.file, 'consumer source', file)));
    });
  }
  test('packet golden analyzes and executes on VM and JavaScript', () async {
    final input = File('test/constructor_packet_regressions_web.quds').absolute;
    final compiled = compile(input.readAsStringSync(), file: input.path);
    expect(compiled.dart,
        compile(input.readAsStringSync(), file: input.path).dart);
    expect(
        compiled.dart,
        File('test/goldens/constructor_packet_regressions.dart.txt')
            .readAsStringSync());
    expect(compiled.dart, isNot(contains('_seed')));
    final root =
        Directory.systemTemp.createTempSync('quds-constructor-packets-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(compiled.dart);
    writeSdkBundles(root.path, compiled);
    final provider =
        File('test/fixtures/constructor_packet_regressions/provider.quds')
            .absolute;
    final implementation =
        compile(provider.readAsStringSync(), file: provider.path);
    final target = File(
        '${root.path}/fixtures/constructor_packet_regressions/provider.dart');
    target.parent.createSync(recursive: true);
    target.writeAsStringSync(
        relocateGeneratedLibraries(implementation, '../../').dart);
    writeSdkBundles(root.path, implementation);
    final analysis = await Process.run(Platform.resolvedExecutable,
        ['analyze', '--no-fatal-warnings', output.path, target.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}${vm.stderr}');
    expect(vm.stdout,
        '7\n4\n7\n7\n7\n4\n3\n7\n2\n9\nr2\n9\n9\n10\n27:2\n8\n3\np:2\n');
    final js = '${root.path}/main.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final node = await Process.run('node',
        ['-e', 'globalThis.self = globalThis; require(process.argv[1]);', js]);
    expect(node.exitCode, 0, reason: '${node.stderr}');
    expect(node.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('current ABI rebuilds valid-checksum v7 constructor output', () async {
    final root = Directory.systemTemp.createTempSync('quds-constructor-cache-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
        "name: constructor_cache\nenvironment:\n  sdk: '>=3.3.0 <4.0.0'\n");
    final provider = File('${root.path}/provider.quds')
      ..writeAsStringSync(
          '_seed() -> int = 7\nclass Box:\n  first: int\n  second: int\n  init(this.first: int = _seed(), this.second: int = first):\n    require true\n');
    final input = File('${root.path}/main.quds')
      ..writeAsStringSync(
          'use provider as api\nmain():\n  print api.Box().second\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'build', input.path]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final output = File('${root.path}/.dart_tool/quds/out/provider.dart');
    final current = output.readAsStringSync();
    final legacy = current.replaceAll(r': $qCtorSlot0;', ': first;');
    expect(legacy, isNot(current),
        reason: 'The fixture must retain the old unbound parameter defect.');
    output.writeAsStringSync(legacy);
    var providerChecksumUpdated = false;
    final cache = Directory('${root.path}/.dart_tool/quds/cache');
    for (final file in cache.listSync().whereType<File>()) {
      final saved = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      saved['abi'] = 'provider-defaults-v7';
      final paths = (saved['paths'] as List).cast<String>();
      if (paths.length == 1 && paths.single == provider.path) {
        saved['output'] = sha256Hex(utf8.encode(legacy));
        providerChecksumUpdated = true;
      }
      file.writeAsStringSync(jsonEncode(saved));
    }
    expect(providerChecksumUpdated, isTrue);
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'run', input.path]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, '7\n');
    for (final file in cache.listSync().whereType<File>()) {
      expect((jsonDecode(file.readAsStringSync()) as Map)['abi'],
          'provider-defaults-v15');
    }
  });
}
