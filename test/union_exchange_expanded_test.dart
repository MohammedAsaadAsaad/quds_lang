import 'dart:io';

import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test('expanded imported union boundaries execute in Quds', () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/union_exchange_expanded.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(3));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('expanded union boundaries analyze and run identically on VM and JS',
      () async {
    final dir = Directory.systemTemp.createTempSync('quds-union-exp-');
    addTearDown(() => dir.deleteSync(recursive: true));

    final providerFile =
        File('test/fixtures/union_exchange/expanded.quds').absolute;
    final providerCompiled =
        compile(providerFile.readAsStringSync(), file: providerFile.path);
    final providerOut =
        File('${dir.path}/fixtures/union_exchange/expanded.dart')
          ..parent.createSync(recursive: true);
    providerOut.writeAsStringSync(
        relocateGeneratedLibraries(providerCompiled, '../../').dart);
    writeSdkBundles(dir.path, providerCompiled);

    const consumerSrc = '''
use fixtures.union_exchange.expanded as api

main() async:
  held: int | String = 4
  print api.describeAlias(api.echoAlias(held))
  saved = api.echoAlias
  print api.describeAlias(saved("hi"))
  print await api.asyncTag(9)
  out: int | String = await api.asyncEcho("done")
  print api.describeAlias(out)
  savedAsync = api.asyncEcho
  out2: int | String = await savedAsync(7)
  print api.describeAlias(out2)
  var count = 0
  nextVal() -> int:
    count += 1
    return 10 + count
  part = api.combine(_, nextVal())
  print "{count}:{part(1)}:{part("k")}"
  partAsync = api.asyncEcho(_)
  out3: int | String = await partAsync("pa")
  print api.describeAlias(out3)
''';
    final consumerPath = File('test/union_exchange_expanded_tmp.quds').absolute;
    final consumerCompiled = compile(consumerSrc, file: consumerPath.path);
    final consumerOut = File('${dir.path}/main.dart')
      ..writeAsStringSync(consumerCompiled.dart);
    writeSdkBundles(dir.path, consumerCompiled);

    final analyze = await Process.run(Platform.resolvedExecutable,
        ['analyze', consumerOut.path, providerOut.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');

    const expected =
        'ai:4\nas:hi\nai:9\nas:done\nai:7\n1:ai:1:ai:11:as:k:ai:11\nas:pa\n';
    final vm =
        await Process.run(Platform.resolvedExecutable, [consumerOut.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect('${vm.stdout}'.replaceAll('\r\n', '\n'), expected);

    final jsPath = '${dir.path}/main.js';
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', consumerOut.path, '-o', jsPath]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final js = await Process.run('node', [
      '-e',
      'globalThis.self = globalThis; require(process.argv[1]);',
      jsPath
    ]);
    expect(js.exitCode, 0, reason: '${js.stdout}\n${js.stderr}');
    expect('${js.stdout}'.replaceAll('\r\n', '\n'), expected);

    // Verify the async bridge also rejects invalid foreign payloads with ArgumentError.
    final providerCode = providerOut.readAsStringSync();
    final bridge =
        RegExp(r'Future<Object\?> (\$QudsUnionCall\w+)\(List<Object\?>')
            .firstMatch(providerCode)!
            .group(1)!;
    final invalid = File('${dir.path}/invalid_async.dart')
      ..writeAsStringSync('''
import 'fixtures/union_exchange/expanded.dart' as p;
Future<void> main() async {
  try {
    await p.$bridge(<Object?>[false], <bool>[true]);
  } on ArgumentError {
    print('async-checked');
    return;
  }
  throw StateError('Invalid payload entered async union bridge');
}
''');
    final rejected =
        await Process.run(Platform.resolvedExecutable, [invalid.path]);
    expect(rejected.exitCode, 0,
        reason: '${rejected.stdout}\n${rejected.stderr}');
    expect('${rejected.stdout}'.replaceAll('\r\n', '\n'), 'async-checked\n');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
