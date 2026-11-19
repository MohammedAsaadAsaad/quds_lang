import 'dart:io';
import 'dart:convert';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test(
      'Quds declarations preserve required named and optional positional forms',
      () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/parameter_forms.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(15));
  });

  test('run rebuilds a v4 provider lacking parameter-form bridges', () async {
    final root = Directory.systemTemp.createTempSync('quds-parameter-upgrade-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
        "name: parameter_upgrade\nenvironment:\n  sdk: '>=3.3.0 <4.0.0'\n");
    final provider = File('${root.path}/provider.quds')
      ..writeAsStringSync(
          'named(value: int required) -> int = value\noptional([value: int = 7]) -> int = value\n');
    final input = File('${root.path}/main.quds')
      ..writeAsStringSync(
          'use provider as api\nmain():\n  saved = api.named\n  print saved(value: 8)\n  optional = api.optional\n  print optional()\n  print optional == api.optional\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'build', input.path]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final output = File('${root.path}/.dart_tool/quds/out/provider.dart');
    final legacy = output
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.contains(r' $QudsDefault'))
        .join('\n');
    output.writeAsStringSync(legacy);
    final cache = Directory('${root.path}/.dart_tool/quds/cache');
    for (final file in cache.listSync().whereType<File>()) {
      final saved = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      saved['abi'] = 'provider-defaults-v4';
      final paths = (saved['paths'] as List).cast<String>();
      if (paths.length == 1 && paths.single == provider.path)
        saved['output'] = sha256Hex(utf8.encode(legacy));
      file.writeAsStringSync(jsonEncode(saved));
    }
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'run', input.path]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, '8\n7\ntrue\n');
    expect(output.readAsStringSync(), contains(r' $QudsDefault'));
    for (final file in cache.listSync().whereType<File>()) {
      expect((jsonDecode(file.readAsStringSync()) as Map)['abi'],
          'provider-defaults-v5');
    }
  });

  test('imported computed constructor defaults report the provider boundary',
      () {
    final root =
        Directory.systemTemp.createTempSync('quds-constructor-boundary-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/provider.quds').writeAsStringSync(
        '_seed() -> int = 7\nclass Owner:\n  value: int\n  init([this.value: int = _seed()]):\n    require true\n');
    final file = '${root.path}/main.quds';
    expect(
        () => compile('use provider as api\nmain():\n  owner = api.Owner()\n',
            file: file),
        throwsA(isA<CompilerException>()
            .having((error) => error.code, 'boundary', 'E910')
            .having((error) => error.span.file, 'consumer', file)));
  });

  final negative = <String, String>{
    'required positional': 'main():\n  api.named(1)\n',
    'required omitted': 'main():\n  api.named()\n',
    'unknown label': 'main():\n  api.named(other: 1)\n',
    'duplicate label': 'main():\n  api.named(value: 1, value: 2)\n',
    'required function value': 'main():\n  saved = api.named\n  saved(1)\n',
    'required callback shape': 'main():\n  saved: (int) -> int = api.named\n',
    'required constructor': 'main():\n  owner = api.Constructed(1)\n',
    'required generic constructor':
        'main():\n  owner = api.GenericConstructed<int>(1)\n',
    'nonnullable implicit null':
        'bad([value: int]) -> int = value\nmain():\n  print 1\n',
    'required default':
        'bad(value: int required = 1) -> int = value\nmain():\n  print 1\n',
    'required bracket':
        'bad([value: int required]) -> int = value\nmain():\n  print 1\n',
    'variadic default':
        'bad(...values: int = 1) -> int = values.length\nmain():\n  print 1\n',
    'variadic bracket':
        'bad([...values: int]) -> int = values.length\nmain():\n  print 1\n',
    'imported positional gap': 'main():\n  print api.optional(other: 2)\n',
    'stored positional gap':
        'main():\n  saved = api.optional\n  print saved(other: 2)\n',
    'mixed value groups':
        'mixed([value: int = 1], amount: int required) -> int = value + amount\nmain():\n  saved = mixed\n',
    'override kind':
        'class Parent:\n  read(value: int required) -> int = value\nclass Child extends Parent:\n  read(value: int) -> int = value\nmain():\n  print 1\n',
  };
  for (final entry in negative.entries) {
    test('parameter forms reject ${entry.key} at Quds coordinates', () {
      final file = File('test/parameter_bad.quds').absolute.path;
      expect(
          () => compile(
              'use fixtures.parameter_forms.provider as api\n${entry.value}',
              file: file),
          throwsA(isA<CompilerException>()
              .having((error) => error.span.file, 'source', file)));
    });
  }

  test('parameter forms generate deterministic Dart and execute on VM and JS',
      () async {
    final input = File('test/parameter_forms_web.quds').absolute;
    final compiled = compile(input.readAsStringSync(), file: input.path);
    expect(compiled.dart,
        compile(input.readAsStringSync(), file: input.path).dart);
    expect(compiled.dart,
        File('test/goldens/parameter_forms.dart.txt').readAsStringSync());
    final root = Directory.systemTemp.createTempSync('quds-parameter-forms-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(compiled.dart);
    writeSdkBundles(root.path, compiled);
    final provider =
        File('test/fixtures/parameter_forms/provider.quds').absolute;
    final implementation =
        compile(provider.readAsStringSync(), file: provider.path);
    final emitted = File('${root.path}/fixtures/parameter_forms/provider.dart');
    emitted.parent.createSync(recursive: true);
    emitted.writeAsStringSync(
        relocateGeneratedLibraries(implementation, '../../').dart);
    writeSdkBundles(root.path, implementation);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}${vm.stderr}');
    expect(vm.stdout,
        '8\ntrue\n14\n10\n11\ntrue\nnull\n3\nQuds\n11\n6\ntrue\nsafe\n3\ntrue\n70\n20\ntrue\n70\n9\n8\nleft:4\n');
    final js = '${root.path}/main.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final node = await Process.run('node',
        ['-e', 'globalThis.self = globalThis; require(process.argv[1]);', js]);
    expect(node.exitCode, 0, reason: '${node.stderr}');
    expect(node.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
