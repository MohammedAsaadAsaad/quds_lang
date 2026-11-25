import 'dart:convert';
import 'dart:io';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test('inferred provider results execute in Quds', () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/inferred_provider.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(13));
  });

  for (final body in [
    'value: String = api.inferred()\n  print value',
    'print api.plain("wrong")',
    'print api.bounded<String>("wrong")',
    'print api._privateSeed()',
    'saved = api.identity\n  print 1',
    'saved = api.classify\n  print 1',
  ]) {
    test('inferred import rejects $body at consumer coordinates', () {
      final file = File('test/inferred_provider_bad.quds').absolute.path;
      expect(
          () => compile(
              'use fixtures.inferred_provider.provider as api\nmain():\n  $body\n',
              file: file),
          throwsA(isA<CompilerException>()
              .having((error) => error.span.file, 'source', file)));
    });
  }
  for (final name in ['self', 'left']) {
    test('inferred import rejects $name recursion at its declaration', () {
      final file = File('test/inferred_provider_bad.quds').absolute.path;
      final provider =
          File('test/fixtures/inferred_provider/cycles.quds').absolute.path;
      expect(
          () => compile(
              'use fixtures.inferred_provider.cycles as api\nmain():\n  print api.$name()\n',
              file: file),
          throwsA(isA<CompilerException>()
              .having((error) => error.code, 'code', 'E300')
              .having((error) => error.message, 'message',
                  contains('return annotation'))
              .having((error) => error.span.file, 'source', provider)));
    });
  }

  test('an inferred override cannot weaken its declared result contract', () {
    final file = File('test/inferred_provider_bad.quds').absolute.path;
    const source = 'use fixtures.inferred_provider.provider as api\n'
        'class Wrong extends api.TypedBase:\n'
        '  readonly read(value: int = 3) = "bad"\n'
        'main():\n  print 1\n';
    expect(
        () => compile(source, file: file),
        throwsA(isA<CompilerException>()
            .having((error) => error.code, 'code', 'E300')
            .having((error) => error.span.file, 'source', file)));
  });

  test('ordinary multiline bodies still require an explicit result annotation',
      () {
    expect(
        () => compile('number():\n  return 7\nmain():\n  print number()\n',
            file: 'block_return.quds'),
        throwsA(isA<CompilerException>().having(
            (error) => error.span.file, 'source', 'block_return.quds')));
  });

  test('inferred provider golden analyzes and runs on VM and JavaScript',
      () async {
    final source = File('test/inferred_provider_web.quds').absolute;
    final result = compile(source.readAsStringSync(), file: source.path);
    expect(result.dart,
        compile(source.readAsStringSync(), file: source.path).dart);
    expect(result.dart,
        File('test/goldens/inferred_provider.dart.txt').readAsStringSync());
    expect(result.dart, isNot(contains('_privateSeed')));
    expect(result.dart, isNot(contains('<infer>')));
    final root = Directory.systemTemp.createTempSync('quds-inferred-provider-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final files = <String>[output.path];
    for (final name in ['provider', 'facade']) {
      final input = File('test/fixtures/inferred_provider/$name.quds').absolute;
      final compiled = compile(input.readAsStringSync(), file: input.path);
      final target = File('${root.path}/fixtures/inferred_provider/$name.dart');
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(
          relocateGeneratedLibraries(compiled, '../../').dart);
      writeSdkBundles(root.path, compiled);
      files.add(target.path);
    }
    final analysis =
        await Process.run(Platform.resolvedExecutable, ['analyze', ...files]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    const expected =
        'true\n7\n7\n7\n7\n4\ntrue\ntrue\n5\n9\ntrue\n15\n7\n3\n3\nq\n4\n7\n9\ni4\nsq\n7\n9\n10\n5\n10\n7\n8\n8\nq\nnull\n3\n4\nq\n10\n10\ntrue\n17\n4\n14\n24\n';
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

  test('v10 rebuilds an otherwise valid v9 provider without inferred bridges',
      () async {
    final root = Directory.systemTemp.createTempSync('quds-inferred-cache-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
        "name: inferred_cache\nenvironment:\n  sdk: '>=3.3.0 <4.0.0'\n");
    final input = File('${root.path}/main.quds')
      ..writeAsStringSync(
          'use provider as api\nmain():\n  saved = api.inferred\n  print saved()\n');
    final provider = File('${root.path}/provider.quds')
      ..writeAsStringSync(
          '_seed() = 7\ninferred(value: int = _seed()) = value\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'build', input.path]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final output = File('${root.path}/.dart_tool/quds/out/provider.dart');
    final current = output.readAsStringSync();
    final legacy = current
        .split('\n')
        .where((line) => !line.contains(r'$QudsDefault'))
        .join('\n');
    expect(legacy, isNot(current));
    output.writeAsStringSync(legacy);
    var updated = false;
    final cache = Directory('${root.path}/.dart_tool/quds/cache');
    for (final file in cache.listSync().whereType<File>()) {
      final saved = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      saved['abi'] = 'provider-defaults-v9';
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
    expect(run.stdout, '7\n');
    for (final file in cache.listSync().whereType<File>()) {
      expect((jsonDecode(file.readAsStringSync()) as Map)['abi'],
          'provider-defaults-v16');
    }
  });
}
