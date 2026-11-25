import 'dart:io';

import 'package:quds/quds.dart';
import 'package:quds/src/sdk.dart';
import 'package:test/test.dart';

void main() {
  test('embedded quds:collection and quds:ext match lib/sdk/*.quds', () {
    expect(
      collectionSdkSource,
      File('lib/sdk/collection.quds').readAsStringSync(),
    );
    expect(embeddedSdk['collection'], collectionSdkSource);
    expect(extSdkSource, File('lib/sdk/ext.quds').readAsStringSync());
    expect(embeddedSdk['ext'], extSdkSource);
  });

  for (final suite in const [
    'test/collection_core.quds',
    'test/collection_imports.quds',
    'test/collection_sort_equality_diff.quds',
    'test/collection_structures.quds',
    'test/collection_specialized.quds',
    'test/collection_extensions.quds',
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

  test('quds:ext alone no longer exposes migrated Lists/Maps/Sets extensions',
      () {
    final reject =
        File('test/collection_reject_ext_collections.quds').readAsStringSync();
    expect(
      () =>
          compile(reject, file: 'test/collection_reject_ext_collections.quds'),
      throwsA(isA<CompilerException>()),
    );
    expect(
      () => compile(
          'use quds:ext\nmain():\n  m = map:\n    "a": 1\n  print m.missing("b")\n'),
      throwsA(isA<CompilerException>()),
    );
    expect(
      () => compile(
          'use quds:ext\nmain():\n  s = set:\n    1\n  print s.without(1)\n'),
      throwsA(isA<CompilerException>()),
    );
    expect(
      () => compile(
          'use quds:collection hide Lists\nmain():\n  xs = [1, 2]\n  print xs.second()\n'),
      throwsA(isA<CompilerException>()),
    );
    expect(
      () {
        compile(
            'use quds:collection show Lists\nmain():\n  xs = [1, 2]\n  print xs.second()\n');
      },
      returnsNormally,
    );
  });

  test('quds:collection generated Dart matches deterministic golden', () {
    final input = File('test/collection_slice_golden.quds');
    final compiled = compile(input.readAsStringSync(), file: input.path);
    final golden =
        File('test/goldens/collection_slice.dart.txt').readAsStringSync();
    expect(compiled.dart, golden);
  });

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

  test(
      'editor completion and definition reflect quds:collection sections and migrated Lists',
      () {
    Set<String> completeLabels(String uri, String source, int line, int col) {
      final session = LspSession();
      session.handle({
        'method': 'textDocument/didOpen',
        'params': {
          'textDocument': {'uri': uri, 'version': 1, 'text': source},
        },
      });
      final result = session.handle({
        'id': 1,
        'method': 'textDocument/completion',
        'params': {
          'textDocument': {'uri': uri},
          'position': {'line': line, 'character': col},
        },
      }).response!['result'] as Map;
      session.dispose();
      return (result['items'] as List)
          .cast<Map>()
          .map((item) => item['label'] as String)
          .toSet();
    }

    final enumLabels = completeLabels(
      'file:///collection_enum_complete.quds',
      'use quds:collection::types show MapConflictPolicy\nmain():\n  p = MapConflictPolicy.\n',
      2,
      24,
    );
    expect(enumLabels, containsAll(['keepFirst', 'keepLast', 'fail']));

    final extLabels = completeLabels(
      'file:///collection_ext_complete.quds',
      'use quds:collection::extensions\nmain():\n  xs = [1, 2]\n  y = xs.\n',
      3,
      9,
    );
    expect(extLabels, containsAll(['second', 'third', 'chunked', 'rotated']));

    final oldExtLabels = completeLabels(
      'file:///collection_old_ext_complete.quds',
      'use quds:ext\nmain():\n  xs = [1, 2]\n  y = xs.\n',
      3,
      9,
    );
    expect(oldExtLabels, isNot(contains('second')));
    expect(oldExtLabels, isNot(contains('chunk')));

    final session = LspSession();
    const defUri = 'file:///collection_def.quds';
    const defSource =
        'use quds:collection::extensions\nmain():\n  xs = [1, 2]\n  print xs.second()\n';
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {'uri': defUri, 'version': 1, 'text': defSource},
      },
    });
    final defResponse = session.handle({
      'id': 2,
      'method': 'textDocument/definition',
      'params': {
        'textDocument': {'uri': defUri},
        'position': {'line': 3, 'character': 13},
      },
    }).response!['result'] as Map;
    session.dispose();
    expect(defResponse['uri'], 'quds-sdk://library/collection.quds');
  });
}
