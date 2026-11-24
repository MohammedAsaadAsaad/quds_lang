import 'dart:io';
import 'dart:convert';
import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/complete.dart';
import 'package:quds_lang/src/navigate.dart';
import 'package:test/test.dart';

void main() {
  test('loop contexts execute in Quds', () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/loop_context.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(20));
  });
  for (final source in <String>[
    'main():\n  print \$.index\n',
    'main():\n  repeat \$.index:\n    print 0\n',
    'main():\n  while true:\n    print \$.item\n    break\n',
    'main():\n  repeat 1:\n    print \$.last\n',
    'main():\n  for item in [1]:\n    \$.index = 2\n',
    'main():\n  for item in [1]:\n    \$.item = 2\n',
    'main():\n  print \$\n',
    'main():\n  for item in [1]:\n    print outside()\noutside() -> int = \$.index\n',
    'main():\n  repeat 0:\n    print 0\n  else:\n    print \$.index\n',
  ]) {
    test('invalid loop context is diagnosed in Quds: $source', () {
      expect(
          () => compile(source, file: 'invalid_context.quds'),
          throwsA(isA<CompilerException>().having((error) => error.span.file,
              'Quds source', 'invalid_context.quds')));
    });
  }
  for (final sample in <(String, Set<String>)>[
    ('main():\n  for item in [1]:\n    print "{{\$.|}}"\n', {}),
    ('main():\n  for item in [1]:\n    print r"{\$.|}"\n', {}),
    (
      'main():\n  for item in [1]:\n    print "{\$.|"',
      {'index', 'iteration', 'item', 'isFirst'}
    ),
    (
      'main():\n  for item in [1]:\n    print "{\$.|',
      {'index', 'iteration', 'item', 'isFirst'}
    ),
    ('main():\n  repeat 3:\n    \$.|', {'index', 'iteration', 'isFirst'}),
    (
      'main():\n  for عنصر in [1]:\n    print \$.|\n',
      {'index', 'iteration', 'item', 'isFirst'}
    ),
    (
      'main():\n  repeat:\n    print 0\n  while \$.|\n',
      {'index', 'iteration', 'isFirst'}
    ),
    (
      'main():\n  for item in [1]:\n    print \$.|\n',
      {'index', 'iteration', 'item', 'isFirst'}
    ),
    (
      'main():\n  while true:\n    print \$.|\n    break\n',
      {'index', 'iteration', 'isFirst'}
    ),
    (
      'main():\n  for item in [1]:\n    repeat \$.|:\n      print 0\n',
      {'index', 'iteration', 'item', 'isFirst'}
    ),
    (
      'main():\n  for item in [1]:\n    while true:\n      print \$.|\n      break\n',
      {'index', 'iteration', 'isFirst'}
    ),
    (
      'main():\n  values = [\$.| for item in [1]]\n  print values\n',
      {'index', 'iteration', 'item', 'isFirst'}
    ),
    ('main():\n  print \$.|\n', {}),
    ('main():\n  for item in [1]:\n    print "\$.|"\n', {}),
    ('main():\n  for item in [1]:\n    print \$.iter|\n', {'iteration'}),
    ('main():\n  retry 5:\n    \$.|', {'index', 'iteration', 'isFirst'}),
    ('main():\n  retry 5: \$.|', {'index', 'iteration', 'isFirst'}),
    (
      'main():\n  retry 5, when e is StateError and \$.|:\n    print 0\n',
      {'index', 'iteration', 'isFirst'}
    ),
    (
      'main():\n  for item in [1]:\n    retry \$.|:\n      print 0\n',
      {'index', 'iteration', 'item', 'isFirst'}
    ),
    ('main():\n  retry \$.|:\n    print 0\n', {}),
  ]) {
    test('context completion is syntax-only: ${sample.$1}', () {
      final cursor = sample.$1.indexOf('|');
      final source = sample.$1.replaceFirst('|', '');
      final before = source.substring(0, cursor);
      final items = completeAt(
          source: source,
          line: '\n'.allMatches(before).length,
          character: before.length - before.lastIndexOf('\n') - 1,
          compileSource: (_) =>
              throw StateError('Completion must not compile'));
      expect(items.map((entry) => entry['label']).toSet(), sample.$2);
      for (final item in items) {
        expect((item['documentation'] as Map)['value'], contains('```quds'));
        expect((item['textEdit'] as Map)['newText'], item['label']);
      }
    });
  }
  test(
      'live LSP serves loop suggestions before incomplete-string diagnostics finish',
      () {
    final session = LspSession()..background = true;
    addTearDown(session.dispose);
    const uri = 'file:///loop-popup.quds';
    const text = 'main():\n  for item in [1]:\n    print "{\$.';
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {
          'uri': uri,
          'languageId': 'quds',
          'version': 1,
          'text': text
        }
      }
    });
    final answer = session.handle({
      'id': 1,
      'method': 'textDocument/completion',
      'params': {
        'textDocument': {'uri': uri},
        'position': {'line': 2, 'character': 14}
      }
    });
    final result = answer.response!['result'] as Map;
    expect((result['items'] as List).map((item) => item['label']).toSet(),
        {'index', 'iteration', 'item', 'isFirst'});
  });
  test('loop context hover explains purpose and static type in English', () {
    const source = 'main():\n  for item in [10]:\n    print \$.index\n';
    final result = compile(source);
    final hover = hoverAt(result, source, 3, 14);
    expect(hover, contains('Zero-based'));
    expect(hover, contains('int'));
    expect(hover, contains('```quds'));

    const retrySource = 'main():\n  retry 5:\n    print \$.iteration\n';
    final retryResult = compile(retrySource);
    final retryHover = hoverAt(retryResult, retrySource, 3, 15);
    expect(retryHover, contains('One-based'));
    expect(retryHover, contains('int'));
    expect(retryHover, contains('```quds'));
  });
  test('v15 invalidates a checksum-valid v14 generated pair consumer',
      () async {
    final root = Directory.systemTemp.createTempSync('quds-loop-abi-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
        "name: loop_upgrade\nenvironment:\n  sdk: '>=3.3.0 <4.0.0'\n");
    final input = File('${root.path}/main.quds')
      ..writeAsStringSync(
          'values() async* -> (String, int):\n  yield ("a", 10)\n'
          'main() async:\n  await for key, item in values():\n    print item\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'build', input.path]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final cacheFile = Directory('${root.path}/.dart_tool/quds/cache')
        .listSync()
        .whereType<File>()
        .single;
    final cache =
        jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
    const old =
        "// Generated by Quds MVP-0. Do not edit.\nvoid main() { print('legacy'); }\n";
    File('${root.path}/.dart_tool/quds/out/main.dart').writeAsStringSync(old);
    cache['abi'] = 'provider-defaults-v14';
    cache['output'] = sha256Hex(utf8.encode(old));
    cacheFile.writeAsStringSync(jsonEncode(cache));
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'run', input.path]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, '10\n');
    expect(jsonDecode(cacheFile.readAsStringSync())['abi'],
        'provider-defaults-v16');
  });
  test('context golden analyzes and executes on VM and JavaScript', () async {
    final input = File('test/loop_context_web.quds').absolute;
    final result = compile(input.readAsStringSync(), file: input.path);
    expect(
        result.dart, compile(input.readAsStringSync(), file: input.path).dart);
    expect(result.dart,
        File('test/goldens/loop_context.dart.txt').readAsStringSync());
    final root = Directory.systemTemp.createTempSync('quds-loop-context-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    const expected =
        '0:1:10:true\n1:2:20:false\ninner0\nwhile0\nwhile2\nfor1\nfor2\nrepeat0\nrepeat1\npost0\npost1\n[10, 21]\n[10, 32]\n[a:10:0, b:20:1]\n{0: 5, 1: 7}\nstream0:10\nstream1:20\n10\n21\nlet0:3\npattern0\n20\n[10, 22]\n';
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
  }, timeout: const Timeout(Duration(minutes: 2)));
}
