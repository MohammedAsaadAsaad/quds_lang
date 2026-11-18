import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/complete.dart';
import 'package:quds_lang/src/keyword_docs_data.dart';
import 'package:test/test.dart';

Map<String, Object?>? help(String source, String target, {int offset = 0}) {
  final index = source.indexOf(target) + offset;
  final prefix = source.substring(0, index);
  return keywordHoverAt(source, '\n'.allMatches(prefix).length,
      prefix.length - prefix.lastIndexOf('\n') - 1);
}

void main() {
  test('bundled documentation matches the Markdown and covers parser words',
      () async {
    final result =
        await Process.run('python3', ['tool/sync_keyword_docs.py', '--check']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    final parser = File('lib/src/parser.dart').readAsStringSync();
    final words = RegExp(r"word\('([^']+)'\)")
        .allMatches(parser)
        .map((m) => m[1]!)
        .toSet();
    expect(keywordDocumentation.keys, containsAll(words));
    for (final entry in keywordDocumentation.entries) {
      expect(entry.value, startsWith('### ${entry.key}\n\n'));
      expect(entry.value, contains('```quds\n'));
    }
  });

  test('every guide example follows the actual parser grammar', () {
    final failures = <String>[];
    for (final entry in keywordDocumentation.entries) {
      final example = RegExp(r'```quds\n(.*?)\n```', dotAll: true)
          .firstMatch(entry.value)!
          .group(1)!;
      try {
        Parser(const Lexer().tokenize('$example\n')).parse();
      } catch (error) {
        failures.add('${entry.key}: $error');
      }
    }
    expect(failures, isEmpty);
  });

  test('keyword and snippet completion use the exact guide Markdown', () {
    final entries = completeAt(
        source: '', line: 0, character: 0, compileSource: (_) => null);
    for (final key in keywordDocumentation.keys) {
      final entry = entries.singleWhere((e) => e['label'] == key);
      expect(entry['documentation'], {
        'kind': 'markdown',
        'value': keywordDocumentation[key],
      });
    }
  });

  test('contextual keywords and compound forms expose English examples', () {
    final cases = <String, String>{
      'var count = 0': 'var',
      'sum<T>(items: List<T>) -> T where T is Numeric:': 'where',
      'augment int:': 'augment',
      '  implicit cast(value: int) -> Box:': 'implicit',
      '  explicit cast(value: int) -> Box:': 'cast',
      'value class Point:': 'value',
      'class A:\n  property answer: int:\n    get = 42': 'get',
      '  property answer: int:\n    set(value):': 'set',
      'x = map:\n  "a": 1': 'map',
      'x = set:\n  1': 'set',
      'x = source to? int': 'to?',
      'x = source to int': 'to',
      'x = with? item:': 'with?',
      'await all:': 'all',
      'await isolate:': 'isolate',
      'task group:': 'group',
      'group "math":': 'group',
      'part of "main.quds"': 'of',
      'use quds:math show Fraction': 'show',
      'class A:\n  value: int by lazy:': 'lazy',
      'read = capture(count) -> count': 'capture',
      'point: Point = .new(1, 2)': 'new',
      'tick():\n  once:': 'once',
      'interface Source<out T>:': 'out',
      'numbers() sync* -> int:': 'sync',
      'for var i = 0 while i < 3 step i += 1:': 'step',
    };
    for (final entry in cases.entries) {
      final result = help(entry.key, entry.value);
      expect(result, isNotNull, reason: entry.key);
      expect(
          result!['contents'],
          {
            'kind': 'markdown',
            'value': keywordDocumentation[entry.value],
          },
          reason: entry.key);
    }
  });

  test('ordinary identifiers, members, comments and strings keep symbol hover',
      () {
    for (final source in [
      'value = 1',
      'get = 1',
      'map = 1',
      'set = 1',
      'once = 1',
      'get(value: int) -> int = value',
      'print value',
      'print map',
      'object.var',
      'object?.get',
      'object.new()',
      'object .new()',
      'f(map: int) -> int = map',
      'f(set: int) -> int = set',
      '# var count = 0',
      '// var count = 0',
      '/* var count = 0 */',
      'text = "var count = 0"',
      "text = r'''var count = 0'''",
    ]) {
      final target = RegExp(r'\b(?:value|get|map|set|once|var|new)\b')
          .firstMatch(source)!
          .group(0)!;
      expect(help(source, target), isNull, reason: source);
    }
  });

  test('keyword help resumes after closed triple and raw triple strings', () {
    for (final literal in [
      '\"\"\"abc\"\"\"',
      "r'''abc'''",
      '\"\"\"line\ntext\"\"\"'
    ]) {
      final source = 'text = $literal\nvar count = 0';
      expect(help(source, 'var'), isNotNull, reason: literal);
    }
  });

  test('hover range uses UTF16 and includes the safe conversion suffix', () {
    const source = 'print "😀"; value to? int';
    final result = help(source, 'to?', offset: 2)!;
    final start = source.indexOf('to?');
    expect(result['range'], {
      'start': {'line': 0, 'character': start},
      'end': {'line': 0, 'character': start + 3},
    });
  });

  test('LSP returns keyword help in an invalid buffer with no symbol analysis',
      () {
    final session = LspSession();
    const uri = 'file:///tmp/keyword_help.quds';
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {'uri': uri, 'version': 1, 'text': 'var broken = (\n'}
      }
    });
    final response = session.handle({
      'id': 1,
      'method': 'textDocument/hover',
      'params': {
        'textDocument': {'uri': uri},
        'position': {'line': 0, 'character': 1}
      }
    });
    expect((response.response!['result'] as Map)['contents'], {
      'kind': 'markdown',
      'value': keywordDocumentation['var'],
    });
    session.dispose();
  });

  test('LSP preserves contextual identifier symbol documentation', () {
    final session = LspSession();
    const uri = 'file:///tmp/keyword_symbol.quds';
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {
          'uri': uri,
          'version': 1,
          'text': 'main():\n  get = 1\n  print get\n'
        }
      }
    });
    final response = session.handle({
      'id': 1,
      'method': 'textDocument/hover',
      'params': {
        'textDocument': {'uri': uri},
        'position': {'line': 2, 'character': 9}
      }
    });
    final contents = (response.response!['result'] as Map)['contents'] as Map;
    expect(contents['value'], contains('get: int'));
    expect(contents['value'], isNot(contains('Declares a property getter')));
    session.dispose();
  });

  test('large incomplete source can show help without compiling', () {
    final source =
        '${List.filled(15000, '# padding').join('\n')}\nvar broken = (';
    final result = keywordHoverAt(source, 15000, 1);
    expect((result!['contents'] as Map)['value'], keywordDocumentation['var']);
  });

  test('VS Code completion preserves Markdown without trusting it', () async {
    final result =
        await Process.run('node', ['test/editor/vscode_keyword_docs.cjs']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });
}
