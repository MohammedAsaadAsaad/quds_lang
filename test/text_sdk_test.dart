import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/sdk.dart';
import 'package:test/test.dart';

void main() {
  test('embedded quds:text and quds:ext match lib/sdk/*.quds', () {
    expect(embeddedSdk['text'], File('lib/sdk/text.quds').readAsStringSync());
    expect(embeddedSdk['ext'], File('lib/sdk/ext.quds').readAsStringSync());
    expect(embeddedSdk['ext'], isNot(contains('extend String Text')));
  });

  const suites = [
    'text_core.quds',
    'text_imports.quds',
    'text_unicode.quds',
    'text_unicode_reference.quds',
    'text_patterns_search.quds',
    'text_replace_reader.quds',
    'text_format_compare.quds',
    'text_escape_encoding.quds',
    'text_extensions.quds',
  ];

  for (final name in suites) {
    test('Quds primary suite $name', () async {
      final path = 'test/$name';
      final source = File(path).readAsStringSync();
      final program = Parser(Lexer().tokenize(source, file: path)).parse();
      final titles = <String>[];
      void collect(List<Statement> statements) {
        for (final declaration in statements.whereType<TestDeclaration>()) {
          titles.add(declaration.title);
          collect(declaration.body);
        }
      }

      collect(program.statements);
      expect(titles, isNotEmpty);
      final result = await Process.run(
          Platform.resolvedExecutable, ['run', 'bin/quds.dart', 'test', path]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final lines = '${result.stdout}'.split('\n');
      for (final title in titles) {
        expect(lines, contains('ok $title'), reason: '${result.stdout}');
      }
      expect(lines.where((line) => line.startsWith('FAIL ')), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  test('quds:ext alone no longer exposes migrated String Text extension', () {
    final reject = File('test/text_reject_ext_string.quds');
    expect(
      () => compile(reject.readAsStringSync(), file: reject.path),
      throwsA(isA<CompilerException>()),
    );
    expect(
      () => compile('use quds:text hide Text\nmain():\n  print " ".blank()\n'),
      throwsA(isA<CompilerException>()),
    );
    final shown =
        compile('use quds:text show Text\nmain():\n  print " ".blank()\n');
    expect(shown.dart, contains('blank'));
  });

  test('quds:text generated Dart matches deterministic golden', () {
    final input = File('test/text_slice_golden.quds');
    final compiled = compile(input.readAsStringSync(), file: input.path);
    final golden = File('test/goldens/text_slice.dart.txt').readAsStringSync();
    expect(compiled.dart, golden);
  });

  test(
      'quds:text executes identically on Dart VM and JavaScript with clean dart analyze',
      () async {
    final directory = Directory.systemTemp.createTempSync('quds-text-sdk-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('test/text_web.quds');
    final compiled = compile(input.readAsStringSync(), file: input.path);
    writeSdkBundles(directory.path, compiled);
    final emitted = File('${directory.path}/program.dart')
      ..writeAsStringSync(compiled.dart);
    final analyze = await Process.run(Platform.resolvedExecutable,
        ['analyze', '--fatal-infos', emitted.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm =
        await Process.run(Platform.resolvedExecutable, ['run', emitted.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, 'TEXT SDK VM WEB OK\n');
    final js = '${directory.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', emitted.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final web = await Process.run('node', [js]);
    expect(web.exitCode, 0, reason: '${web.stdout}\n${web.stderr}');
    expect(web.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
      'editor completion and definition reflect quds:text sections and migrated Text',
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
      'file:///tmp/text_enum_complete.quds',
      'use quds:text::lines show TextLineEnding\nmain():\n  e = TextLineEnding.\n',
      2,
      '  e = TextLineEnding.'.length,
    );
    expect(enumLabels, containsAll(['lf', 'crlf', 'cr', 'values']));

    final textExtLabels = completeLabels(
      'file:///tmp/text_ext_complete.quds',
      'use quds:text::extensions\nmain():\n  s = "hi"\n  x = s.\n',
      3,
      '  x = s.'.length,
    );
    expect(
      textExtLabels,
      containsAll([
        'blank',
        'capitalized',
        'asTextCharacters',
        'normalizedUnicode',
        'repeatedWithSeparator'
      ]),
    );

    final oldExtLabels = completeLabels(
      'file:///tmp/ext_only_complete.quds',
      'use quds:ext\nmain():\n  s = "hi"\n  x = s.\n',
      3,
      '  x = s.'.length,
    );
    expect(oldExtLabels, isNot(contains('blank')));

    final session = LspSession();
    const defUri = 'file:///tmp/text_def.quds';
    const defSource =
        'use quds:text::extensions\nmain():\n  print "hi".blank()\n';
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {'uri': defUri, 'version': 1, 'text': defSource},
      },
    });
    final def = session.handle({
      'id': 2,
      'method': 'textDocument/definition',
      'params': {
        'textDocument': {'uri': defUri},
        'position': {'line': 2, 'character': '  print "hi".bl'.length},
      },
    }).response!['result'] as Map;
    session.dispose();
    expect(def['uri'], 'quds-sdk://library/text.quds');
  });
}
