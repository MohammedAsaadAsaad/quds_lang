import 'dart:io';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

List<dynamic> lenses(LspSession session, String uri) => session.handle({
      'id': 1,
      'method': 'textDocument/codeLens',
      'params': {
        'textDocument': {'uri': uri}
      }
    }).response!['result'] as List;

void main() {
  test(
      'Academy parses without E100 and exposes actions before background analysis',
      () {
    final file =
        File('examples/flutter_app/quds_academy/lib/main.quds').absolute;
    final source = file.readAsStringSync();
    final parser = Parser(Lexer().tokenize(source, file: file.path));
    parser.parse(partial: true);
    expect(parser.errors, isEmpty);
    final session = LspSession()..background = true;
    addTearDown(session.dispose);
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {
          'uri': file.uri.toString(),
          'version': 1,
          'text': source
        }
      }
    });
    final result = lenses(session, file.uri.toString());
    expect(result.map((l) => l['command']['command']),
        ['quds.run', 'quds.debug', 'quds.profile']);
    for (final lens in result) {
      expect(lens['command']['arguments'], [file.uri.toString()]);
      final line = lens['range']['start']['line'] as int;
      expect(source.split('\n')[line], startsWith('main()'));
    }
  });

  test(
      'actions survive missing packages, type failures and unrelated syntax errors',
      () {
    final session = LspSession();
    addTearDown(session.dispose);
    final file = File('/tmp/quds-actions-missing/main.quds');
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {
          'uri': file.uri.toString(),
          'version': 1,
          'text':
              '# تعلّم قدس\nuse package:missing/api.dart\nmain():\n  print unknown\n\nbroken =\n'
        }
      }
    });
    expect(lenses(session, file.uri.toString()).length, 3);
    session.handle({
      'method': 'textDocument/didChange',
      'params': {
        'textDocument': {'uri': file.uri.toString(), 'version': 2},
        'contentChanges': [
          {'text': 'helper():\n  print "no entry"\n'}
        ]
      }
    });
    expect(lenses(session, file.uri.toString()), isEmpty);
  });

  test('unopened saved entry exposes actions without resolving imports', () {
    final root = Directory.systemTemp.createTempSync('quds-actions-');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = File('${root.path}/main.quds')
      ..writeAsStringSync('use missing.module\nmain():\n  print unknown\n');
    final session = LspSession();
    addTearDown(session.dispose);
    expect(lenses(session, file.uri.toString()).length, 3);
  });

  test('VS Code chooses project compiler and avoids stale executables',
      () async {
    final result =
        await Process.run('node', ['test/editor/vscode_actions.cjs']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('VSCODE ACTIONS OK'));
  });
}
