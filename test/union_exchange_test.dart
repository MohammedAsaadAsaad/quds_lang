import 'dart:convert';
import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('library union exchange executes in Quds', () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/union_exchange.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(8));
  });
  for (final statement in [
    'api.accept(false)',
    'saved = api.accept\n  saved(false)',
    'value: int | String = false\n  print value',
    'value: bool = api.produce(true)\n  print value',
    'api.readObject(3)',
  ]) {
    test('invalid union exchange is rejected in Quds: $statement', () {
      final file = File('test/union_exchange_bad.quds').absolute.path;
      expect(
          () => compile(
              'use fixtures.union_exchange.provider as api\nmain():\n  $statement\n',
              file: file),
          throwsA(isA<CompilerException>()
              .having((error) => error.span.file, 'Quds source', file)));
    });
  }
  for (final statement in [
    'saved = api.alias',
    'saved = api.asynchronous',
    'api.alias(3)',
    'api.generic<int>(3, 4)',
    'api.asynchronous(3)',
    'api.accept(_)',
    'api.nested([3])',
  ]) {
    test('uncertified union boundaries produce Quds E910: $statement', () {
      final file = File('test/union_exchange_bad.quds').absolute.path;
      expect(
          () => compile(
              'use fixtures.union_exchange.unsupported as api\n'
              'main():\n  $statement\n',
              file: file),
          throwsA(isA<CompilerException>()
              .having((error) => error.code, 'code', 'E910')
              .having((error) => error.span.file, 'Quds source', file)));
    });
  }
  test('checked union ABI golden analyzes and runs on VM and JS', () async {
    final source = File('test/union_exchange_web.quds').absolute;
    final result = compile(source.readAsStringSync(), file: source.path);
    expect(result.dart,
        compile(source.readAsStringSync(), file: source.path).dart);
    expect(result.dart,
        File('test/goldens/union_exchange.dart.txt').readAsStringSync());
    expect(result.dart, isNot(contains('_seed')));
    final root = Directory.systemTemp.createTempSync('quds-union-exchange-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final files = [output.path];
    for (final name in ['provider', 'facade', 'second']) {
      final input = File('test/fixtures/union_exchange/$name.quds').absolute;
      final compiled = compile(input.readAsStringSync(), file: input.path);
      final target = File('${root.path}/fixtures/union_exchange/$name.dart');
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
        'n3\nn3\nsq\nn3\nn7\ntrue\nn3\nn4:sx\nBA\nn1:n2\nn5:n3\nsx:n3\nn5\n2\n12\nsset\nsq\ntrue\nn3\n12\nbool\n';
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}${vm.stderr}');
    expect(vm.stdout, expected);
    final js = '${root.path}/main.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final run = await Process.run('node',
        ['-e', 'globalThis.self = globalThis; require(process.argv[1]);', js]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, expected);
    // The reserved bridge must validate payloads even for foreign Dart callers.
    final provider = File(files[1]).readAsStringSync();
    final bridge = RegExp(r'String (\$QudsUnionCall\w+)\(List<Object\?>')
        .firstMatch(provider)!
        .group(1)!;
    final invalid = File('${root.path}/invalid.dart')..writeAsStringSync('''
import 'fixtures/union_exchange/provider.dart' as p;
void main() {
  try { p.$bridge(<Object?>[false], <bool>[true]); }
  on ArgumentError { print('checked'); return; }
  throw StateError('Invalid payload entered a typed function');
}
''');
    final rejected =
        await Process.run(Platform.resolvedExecutable, [invalid.path]);
    expect(rejected.exitCode, 0,
        reason: '${rejected.stdout}${rejected.stderr}');
    expect(rejected.stdout, 'checked\n');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('current ABI rebuilds a checksum-valid v13 union consumer', () async {
    final root = Directory.systemTemp.createTempSync('quds-union-abi-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
        "name: union_upgrade\nenvironment:\n  sdk: '>=3.3.0 <4.0.0'\n");
    final input = File('${root.path}/main.quds')
      ..writeAsStringSync('main():\n  print 7\n');
    Future<ProcessResult> build() => Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'build', input.path]);
    final first = await build();
    expect(first.exitCode, 0, reason: '${first.stdout}${first.stderr}');
    final caches = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'));
    final cache = caches.firstWhere(
        (file) => file.readAsStringSync().contains('provider-defaults-v15'));
    final data = jsonDecode(cache.readAsStringSync()) as Map<String, dynamic>;
    data['abi'] = 'provider-defaults-v13';
    const old =
        "// Generated by Quds MVP-0. Do not edit.\nvoid main() { print('legacy'); }\n";
    final output = File('${root.path}/.dart_tool/quds/out/main.dart');
    output.writeAsStringSync(old);
    data['output'] = sha256Hex(utf8.encode(old));
    cache.writeAsStringSync(jsonEncode(data));
    final second = await build();
    expect(second.exitCode, 0, reason: '${second.stdout}${second.stderr}');
    expect(
        jsonDecode(cache.readAsStringSync())['abi'], 'provider-defaults-v15');
    expect(output.readAsStringSync(), isNot(old));
  });
}
