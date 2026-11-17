import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/source_index.dart';
import 'package:test/test.dart';

Map request(
        LspSession session, String uri, String method, int line, int column) =>
    session.handle({
      'id': 1,
      'method': method,
      'params': {
        'textDocument': {'uri': uri},
        'position': {'line': line, 'character': column}
      }
    }).response!['result'] as Map;

void main() {
  test('source coordinate index handles Arabic emoji CRLF and UTF-8 boundaries',
      () {
    const source = 'abc\r\nعدد = "😀"\nlast\rnext';
    final index = SourceIndex(source);
    for (var i = 0; i <= source.length; i++) {
      expect(index.byteOffset(i), utf8.encode(source.substring(0, i)).length);
      expect(index.stringIndex(index.byteOffset(i)), i);
    }
    expect(index.position(source.indexOf('عدد')), (1, 0));
    expect(index.position(source.indexOf('last')), (2, 0));
    expect(index.position(source.indexOf('next')), (3, 0));
  });
  test('growing incomplete buffers retain new locals and truthful diagnostics',
      () async {
    final session = LspSession()..background = true;
    addTearDown(session.dispose);
    final uri = File('/tmp/quds_editor_growth.quds').uri.toString();
    final notifications = <int, Map>{};
    session.emit = (message) {
      final params = message['params'] as Map;
      notifications[params['version'] as int] = params;
    };
    Future<Map> ready(int version) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!notifications.containsKey(version) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(notifications, contains(version));
      return notifications[version]!;
    }

    var text =
        'main():\n${List.generate(2000, (i) => '  value$i = $i\n').join()}';
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {'uri': uri, 'version': 1, 'text': text}
      }
    });
    await ready(1);
    for (var version = 2; version <= 4; version++) {
      final edited =
          '${text}  values$version = [$version]\n  print values$version.\n';
      session.handle({
        'method': 'textDocument/didChange',
        'params': {
          'textDocument': {'uri': uri, 'version': version},
          'contentChanges': [
            {'text': edited}
          ]
        }
      });
      final diagnostics = await ready(version);
      expect(diagnostics['diagnostics'], isNotEmpty);
      final lines = edited.split('\n');
      final at = lines.length - 2;
      final result = request(
          session, uri, 'textDocument/completion', at, lines[at].length);
      final labels =
          (result['items'] as List).cast<Map>().map((i) => i['label']);
      expect(labels, containsAll(['length', 'add', 'map']));
      // Keep the previous statement valid as the next line is typed.
      text =
          edited.replaceFirst('values$version.\n', 'values$version.length\n');
    }
  });
  test('large live semantic token requests reuse background data', () async {
    final session = LspSession()..background = true;
    addTearDown(session.dispose);
    final ready = Completer<void>();
    session.emit = (_) {
      if (!ready.isCompleted) ready.complete();
    };
    final uri = File('/tmp/quds_editor_large.quds').uri.toString();
    final text =
        'main():\n${List.generate(5000, (i) => '  value$i = $i\n  print value$i\n').join()}';
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {'uri': uri, 'version': 1, 'text': text}
      }
    });
    await ready.future.timeout(const Duration(seconds: 30));
    final first =
        request(session, uri, 'textDocument/semanticTokens/full', 0, 0)['data']
            as List;
    expect(first.length, 15001 * 5);
    for (var i = 0; i < 10; i++) {
      final data = request(
          session, uri, 'textDocument/semanticTokens/full', 0, 0)['data'];
      expect(identical(data, first), isTrue,
          reason:
              'Tokens must not rescan a large document on the input isolate');
    }
    final result = request(session, uri, 'textDocument/completion', 10000, 8);
    expect((result['items'] as List).cast<Map>().map((i) => i['label']),
        contains('value4999'));
  });
  test('an analysis exception does not strand later documents in the queue',
      () async {
    final session = LspSession()..background = true;
    addTearDown(session.dispose);
    final events = <String>{};
    session.emit = (message) {
      events.add((message['params'] as Map)['uri'] as String);
    };
    for (final (name, text) in [
      ('deep', 'main():\n  print ${'not ' * 12000}true\n'),
      ('healthy', 'main():\n  values = [1]\n  print values.length\n')
    ]) {
      final uri = File('/tmp/editor_$name.quds').uri.toString();
      session.handle({
        'method': 'textDocument/didOpen',
        'params': {
          'textDocument': {'uri': uri, 'version': 1, 'text': text}
        }
      });
    }
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (events.length < 2 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(events, hasLength(2));
    final uri = File('/tmp/editor_healthy.quds').uri.toString();
    expect(request(session, uri, 'textDocument/completion', 2, 15)['items'],
        isNotEmpty);
  });
  test(
      'actual LSP handles large tokens completion and repeated incomplete edits',
      () async {
    final result = await Process.run(
        'node', ['test/editor/lsp_growth.cjs', Platform.resolvedExecutable]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final data = jsonDecode('${result.stdout}') as Map;
    expect(data['bindings'], 5000);
    expect(data['pipeline_p95_ms'], lessThan(3000));
  }, timeout: const Timeout(Duration(seconds: 80)));
  test('VS Code cancels releases stale requests and refreshes semantic tokens',
      () async {
    final result =
        await Process.run('node', ['test/editor/vscode_requests.cjs']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('VSCODE REQUESTS OK'));
  });
}
