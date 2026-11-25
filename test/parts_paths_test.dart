import 'dart:io';

import 'package:quds/quds.dart';
import 'package:quds/src/complete.dart';
import 'package:quds/src/navigate.dart';
import 'package:test/test.dart';

void main() {
  test('part paths normalize like use and export and retain source spans', () {
    for (final directive in ['part', 'part of']) {
      for (final entry in {
        'details': 'details.quds',
        'src.details': 'src/details.quds',
        '^.main': '../main.quds',
        'details.quds': 'details.quds',
        'src/details.quds': 'src/details.quds',
        'src.show': 'src/show.quds',
        '"literal.name.quds"': 'literal.name.quds',
      }.entries) {
        final source = '$directive ${entry.key}\n';
        final node = Parser(const Lexer().tokenize(source))
            .parse()
            .statements
            .single as PartDirective;
        expect(node.uri, entry.value, reason: source);
        expect(node.of, directive == 'part of');
        expect(node.span.offset, 0);
      }
    }
  });

  test('both part directives require a path', () {
    for (final source in ['part\n', 'part of\n']) {
      expect(() => Parser(const Lexer().tokenize(source)).parse(),
          throwsA(isA<CompilerException>()));
    }
  });

  test('unquoted part module paths are preserved by formatting', () {
    const source = 'part src.details\npart of ^.main\n';
    expect(formatQuds(source), source);
  });

  test(
      'part completion offers of and local modules without schemes or sections',
      () {
    final root = Directory.systemTemp.createTempSync('quds-part-complete-');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory('${root.path}/src').createSync();
    File('${root.path}/main.quds').writeAsStringSync('part src.details\n');
    File('${root.path}/helper.quds')
        .writeAsStringSync(':: utilities\nvalue = 1\n');
    File('${root.path}/src/details.quds').writeAsStringSync('part of ^.main\n');
    File('${root.path}/note.txt').writeAsStringSync('skip');
    List<Map<String, Object?>> at(String text, [String name = 'main.quds']) =>
        completeAt(
            source: text,
            line: 0,
            character: text.length,
            file: '${root.path}/$name',
            compileSource: (_) =>
                throw StateError('URI completion must not compile'));
    for (final directive in ['part ', 'part of ']) {
      final items = at(directive);
      expect(items.map((i) => i['label']), containsAll(['helper', 'src']));
      expect(items.map((i) => i['label']), isNot(contains('main')));
      expect(items.map((i) => i['label']), isNot(contains('helper::')));
      expect(items.map((i) => i['label']), isNot(contains('quds:')));
      expect(items.map((i) => i['label']), isNot(contains('dart:')));
      expect(items.map((i) => i['label']), isNot(contains('note.txt')));
      final folder = items.singleWhere((i) => i['label'] == 'src');
      expect((folder['textEdit'] as Map)['newText'], 'src.');
      final nested = at('${directive}src.d');
      expect(nested.map((i) => i['label']), ['details']);
      final edit = nested.single['textEdit'] as Map;
      expect(edit['newText'], 'details');
      expect((edit['range'] as Map)['start'],
          {'line': 0, 'character': directive.length + 4});
      expect(at('${directive}helper::'), isEmpty);
      expect(at('${directive}quds:'), isEmpty);
    }
    final of = at('part o').singleWhere((i) => i['label'] == 'of');
    expect((of['textEdit'] as Map)['newText'], 'of ');
    expect(of['documentation'], isNotNull);
    expect(at('part of').single['label'], 'of');
    expect(at('part of ^.m', 'src/details.quds').single['label'], 'main');
    expect(at('part office').where((i) => i['label'] == 'of'), isEmpty);
    expect(at('# part src.'), isEmpty);
    expect(at('text = "part src.'), isEmpty);
    expect(at('  part src.').single['label'], 'details');
  });

  test('LSP returns local path edits for an incomplete part directive', () {
    final session = LspSession();
    final file = File('test/fixtures/parts_bare/owner.quds').absolute;
    final uri = file.uri.toString();
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {'uri': uri, 'version': 1, 'text': 'part nested.d'}
      }
    });
    final response = session.handle({
      'id': 1,
      'method': 'textDocument/completion',
      'params': {
        'textDocument': {'uri': uri},
        'position': {'line': 0, 'character': 13}
      }
    });
    final items = (response.response!['result'] as Map)['items'] as List;
    final edit = (items.single as Map)['textEdit'] as Map;
    expect(edit['newText'], 'details');
    expect((edit['range'] as Map)['start'], {'line': 0, 'character': 12});
    session.dispose();
  });

  test('navigation resolves bare and literal part paths consistently', () {
    final owner = File('test/fixtures/parts_bare/owner.quds').absolute.path;
    final child =
        File('test/fixtures/parts_bare/nested/details.quds').absolute.path;
    expect(libraryAt('part nested.details', 1, 8, from: owner)!.file, child);
    expect(libraryAt('part of ^.owner', 1, 12, from: child)!.file, owner);
    final root = Directory.systemTemp.createTempSync('quds-literal-part-');
    addTearDown(() => root.deleteSync(recursive: true));
    final literal = File('${root.path}/literal.name.quds')
      ..writeAsStringSync('');
    expect(
        libraryAt('part "literal.name.quds"', 1, 10,
                from: '${root.path}/main.quds')!
            .file,
        literal.path);
  });

  test('bare part ownership is checked', () {
    final root = Directory.systemTemp.createTempSync('quds-part-owner-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/details.quds')
        .writeAsStringSync('part of wrong\nvalue = 1\n');
    expect(
        () => compile('part details\nmain():\n  print 1\n',
            file: '${root.path}/main.quds'),
        throwsA(predicate((e) => '$e'.contains('E903'))));
  });

  test('Quds primary conformance for bare nested parts', () async {
    final cli = File('bin/quds.dart').absolute.path;
    final result = await Process.run(
        Platform.resolvedExecutable, [cli, 'test', 'test/parts_paths.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout,
        contains('ok unquoted nested parts share library privacy'));
  });

  test('fresh CLI run builds bare parts and emits valid Dart', () async {
    final root = Directory.systemTemp.createTempSync('quds-part-run-');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory('${root.path}/nested').createSync();
    File('${root.path}/quds.yaml').writeAsStringSync('language: "1.2"\n');
    for (final name in ['owner.quds', 'nested/details.quds']) {
      File('${root.path}/$name').writeAsStringSync(
          File('test/fixtures/parts_bare/$name').readAsStringSync());
    }
    final result = await Process.run(Platform.resolvedExecutable, [
      File('bin/quds.dart').absolute.path,
      'run',
      '${root.path}/owner.quds'
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, '7\n');
    final out = '${root.path}/.dart_tool/quds/out';
    expect(File('$out/owner.dart').readAsStringSync(),
        contains("part 'nested/details.dart';"));
    expect(File('$out/nested/details.dart').readAsStringSync(),
        contains("part of '../owner.dart';"));
    final analysis = await Process.run(Platform.resolvedExecutable,
        ['analyze', '$out/owner.dart', '$out/nested/details.dart']);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
