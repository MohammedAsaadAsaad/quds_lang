import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/sdk.dart';
import 'package:test/test.dart';

void main() {
  test('embedded quds:text matches lib/sdk/text.quds', () {
    final disk = File('lib/sdk/text.quds').readAsStringSync();
    expect(embeddedSdk['text'], disk);
  });

  const suites = [
    'text_core.quds',
    'text_imports.quds',
    'text_unicode.quds',
    'text_unicode_reference.quds',
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

  test('editor completion suggests quds:text enums and section members', () {
    const uri = 'file:///tmp/text_enum_complete.quds';
    const source = '''use quds:text::lines show TextLineEnding
main():
  e = TextLineEnding.
''';
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
        'position': {'line': 2, 'character': '  e = TextLineEnding.'.length},
      },
    }).response!['result'] as Map;
    final labels = (result['items'] as List)
        .cast<Map>()
        .map((item) => item['label'] as String)
        .toSet();
    expect(labels, containsAll(['lf', 'crlf', 'cr', 'values']));
  });
}
