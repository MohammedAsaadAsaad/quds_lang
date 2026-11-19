import 'dart:io';
import 'dart:convert';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('Quds value adapters execute', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/quds.dart',
      'test',
      'test/quds_value_adapters.quds',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(
        '${result.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(27));
  });

  test('run rebuilds provider output from a previous generated ABI', () async {
    final root = Directory.systemTemp.createTempSync('quds-provider-upgrade-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
        "name: provider_upgrade\nenvironment:\n  sdk: '>=3.3.0 <4.0.0'\n");
    final provider = File('${root.path}/provider.quds')
      ..writeAsStringSync(File('test/fixtures/quds_value_adapters/helpers.quds')
          .readAsStringSync());
    final input = File('${root.path}/main.quds')
      ..writeAsStringSync(
          'use provider as api\nmain():\n  saved = api.report\n  print saved()\n  owner = api.DefaultBox<int>(stored: 8)\n  print owner.read()\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'build', input.path]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final output = File('${root.path}/.dart_tool/quds/out/provider.dart');
    final legacy = output
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.contains(r' $QudsMethodDefault'))
        .join('\n');
    output.writeAsStringSync(legacy);
    final cache = Directory('${root.path}/.dart_tool/quds/cache');
    for (final file in cache.listSync().whereType<File>()) {
      final saved = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      saved['abi'] = 'provider-defaults-v1';
      final paths = (saved['paths'] as List).cast<String>();
      if (paths.length == 1 && paths.single == provider.path) {
        // Keep its output checksum valid: only the ABI marker should reject it.
        saved['output'] = sha256Hex(utf8.encode(legacy));
      }
      file.writeAsStringSync(jsonEncode(saved));
    }
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'run', input.path]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.replaceAll('\r', ''), '7:9\n11\n');
    expect(output.readAsStringSync(), contains(r' $QudsMethodDefault'));
    for (final file in cache.listSync().whereType<File>()) {
      expect((jsonDecode(file.readAsStringSync()) as Map)['abi'],
          'provider-defaults-v3');
    }
  });

  test('provider bridges retain source visibility and type diagnostics', () {
    final sourceFile = File('test/provider_bad.quds').absolute.path;
    for (final body in [
      'saved = helpers._hiddenNumber',
      'owner = helpers.DefaultBox<int>(stored: 8)\n  saved = owner.next',
      'owner = helpers.DefaultBox<int>(stored: 8)\n  print owner.count',
      'saved = helpers.report\n  print saved(first: "wrong")',
    ]) {
      expect(
          () => compile(
              'use fixtures.quds_value_adapters.helpers as helpers\nmain():\n  $body\n',
              file: sourceFile),
          throwsA(isA<CompilerException>()
              .having((error) => error.span.file, 'Quds source', sourceFile)));
    }
  });

  test('default value slots are named-only', () {
    expect(
        () => compile('''
choose(value: int = 1) -> int = value
main():
  saved = choose
  print saved(2)
''', file: 'default_named.quds'),
        throwsA(isA<CompilerException>()
            .having((error) => error.code, 'code', 'E300')));
  });

  test('default bridges preserve readonly access restrictions', () {
    expect(
        () => compile('''
class Owner:
  change(value: int = 1) -> int = value
main():
  view: readonly Owner = Owner()
  saved = view.change
''', file: 'readonly_default.quds'),
        throwsA(isA<CompilerException>()
            .having((error) => error.code, 'code', 'E307')));
  });

  test('deferred imports and guarded results keep their diagnostics', () {
    expect(
        () => compile('''
use dart:core as core
main():
  core.loadLibrary()
''', file: 'deferred_bad.quds'),
        throwsA(isA<CompilerException>()
            .having((error) => error.code, 'code', 'E300')
            .having(
                (error) => error.span.file, 'source', 'deferred_bad.quds')));
    expect(
        () => compile('''
use dart:core deferred
main():
  print 1
''', file: 'deferred_prefix.quds'),
        throwsA(isA<CompilerException>().having(
            (error) => error.span.file, 'source', 'deferred_prefix.quds')));
    expect(
        () => compile('''
class Fresh:
  readonly read() -> List<int> = [1]
main():
  view: readonly Fresh = Fresh()
  saved = view.read
  saved()[0] = 2
''', file: 'readonly_value.quds'),
        throwsA(isA<CompilerException>()
            .having((error) => error.code, 'code', 'E307')
            .having(
                (error) => error.span.file, 'source', 'readonly_value.quds')));
  });

  test('adapter programs analyze and execute on the VM and JavaScript',
      () async {
    final input = File('test/quds_value_adapters_web.quds').absolute;
    final source = input.readAsStringSync();
    final result = compile(source, file: input.path);
    expect(result.dart, compile(source, file: input.path).dart);
    expect(
        result.dart.replaceAll('\r', ''),
        File('test/goldens/quds_value_adapters.dart.txt')
            .readAsStringSync()
            .replaceAll('\r', ''));
    expect(result.dart, contains('identical('));
    expect(result.dart, contains('pick\$1'));
    expect(result.dart, contains('Utility.echo'));
    final root = Directory.systemTemp.createTempSync('quds-value-adapters-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/program.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final helper =
        File('test/fixtures/quds_value_adapters/helpers.quds').absolute;
    final compiledHelper =
        compile(helper.readAsStringSync(), file: helper.path);
    expect(compiledHelper.dart, contains('pick\$1'));
    expect(compiledHelper.dart, contains('pick\$2'));
    final helperOutput =
        File('${root.path}/fixtures/quds_value_adapters/helpers.dart');
    helperOutput.parent.createSync(recursive: true);
    helperOutput.writeAsStringSync(
        relocateGeneratedLibraries(compiledHelper, '../../').dart);
    writeSdkBundles(root.path, compiledHelper);
    final facade =
        File('test/fixtures/quds_value_adapters/facade.quds').absolute;
    final compiledFacade =
        compile(facade.readAsStringSync(), file: facade.path);
    File('${root.path}/fixtures/quds_value_adapters/facade.dart')
        .writeAsStringSync(
            relocateGeneratedLibraries(compiledFacade, '../../').dart);
    writeSdkBundles(root.path, compiledFacade);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stderr}');
    expect(vm.stdout,
        'Quds\nempty\n4\n2\nnull\nAda\n6\n3\ninteger\ntext\n33\n44\ndefault\nnull\ntrue\ntrue\n1\ntrue\nQuds\n4\n10\ntrue\n10\n4\ntrue\nstatic\ntrue\n4\n10\n20\n7:9\n12:12\ntrue\ntrue\ntrue\n5\n8\ndefault\nnull\ntrue\n9\n10\n7:9\n12:12\n7:4\ntrue\n11\nvalue\n12\n12\n8\n7\ntrue\ntrue\n12\ntrue\nnull\n12\n12\n11\n');
    final js = '${root.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final node = await Process.run('node', [
      '-e',
      'globalThis.self = globalThis; require(process.argv[1]);',
      js,
    ]);
    expect(node.exitCode, 0, reason: '${node.stderr}');
    expect(node.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
