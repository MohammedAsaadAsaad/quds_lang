import 'dart:async';
import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void send(LspSession session, String uri, int version, String source) =>
    session.handle({
      'method':
          version == 1 ? 'textDocument/didOpen' : 'textDocument/didChange',
      'params': version == 1
          ? {
              'textDocument': {'uri': uri, 'version': version, 'text': source}
            }
          : {
              'textDocument': {'uri': uri, 'version': version},
              'contentChanges': [
                {'text': source}
              ]
            }
    });
List<int> colors(LspSession session, String uri) => ((session.handle({
      'id': 1,
      'method': 'textDocument/semanticTokens/full',
      'params': {
        'textDocument': {'uri': uri}
      }
    }).response!['result'] as Map)['data'] as List)
        .cast<int>();
List<(int, int, int)> positions(List<int> data) {
  var line = 0, column = 0;
  return [
    for (var i = 0; i < data.length; i += 5)
      (
        line += data[i],
        column = data[i] == 0 ? column + data[i + 1] : data[i + 1],
        data[i + 2]
      )
  ];
}

void main() {
  test(
      'syntax colors arrive before semantic checking and errors before recovery completes',
      () async {
    final session = LspSession()..background = true;
    addTearDown(session.dispose);
    final uri = File('/tmp/quds_staged_diagnostics.quds').uri.toString();
    final completed = Completer<void>();
    final stages = <String>[];
    session.emit = (message) {
      final params = message['params'] as Map;
      if (params['uri'] != uri) return;
      if (message['method'] == 'quds/semanticTokensReady') {
        stages.add('syntax');
        expect(colors(session, uri), isNotEmpty);
      } else if (message['method'] == 'textDocument/publishDiagnostics') {
        final diagnostics = params['diagnostics'] as List;
        expect(diagnostics, isNotEmpty);
        expect((diagnostics.first as Map)['code'], 'E200');
        if (params['qudsAnalysisComplete'] == false) {
          stages.add('error');
        } else {
          stages.add('complete');
          if (!completed.isCompleted) completed.complete();
        }
      }
    };
    send(session, uri, 1, 'main():\n  values = [1]\n  print unknownValue\n');
    await completed.future.timeout(const Duration(seconds: 20));
    expect(stages.first, 'syntax');
    expect(stages.indexOf('error'), lessThan(stages.indexOf('complete')));
  });
  test('unchanged colors project immediately through Unicode multiline edits',
      () async {
    final session = LspSession()..background = true;
    addTearDown(session.dispose);
    final uri = File('/tmp/quds_project_colors.quds').uri.toString();
    final ready = Completer<void>();
    session.emit = (message) {
      if (message['method'] == 'textDocument/publishDiagnostics' &&
          (message['params'] as Map)['qudsAnalysisComplete'] != false &&
          !ready.isCompleted) ready.complete();
    };
    const text = 'main():\n  var count = 1\n  print count\n';
    send(session, uri, 1, text);
    await ready.future.timeout(const Duration(seconds: 20));
    expect(positions(colors(session, uri)), contains((2, 8, 5)));
    const moved = '# تعليق 😀\n$text';
    send(session, uri, 2, moved);
    expect(positions(colors(session, uri)), contains((3, 8, 5)));
    expect(positions(colors(session, uri)), contains((2, 6, 5)));
    send(session, uri, 3, moved.replaceFirst('print count', 'print count.'));
    final preserved = positions(colors(session, uri));
    expect(preserved, contains((2, 6, 5)));
    expect(preserved.where((t) => t.$1 == 3), isEmpty);
  });
  test(
      'continuous typing does not indefinitely postpone diagnostics in either document',
      () async {
    final session = LspSession()..background = true;
    addTearDown(session.dispose);
    final a = File('/tmp/quds_diagnostic_stream_a.quds').uri.toString();
    final b = File('/tmp/quds_diagnostic_stream_b.quds').uri.toString();
    final initial = <String>{};
    var typing = false;
    var duringTyping = 0;
    var secondCheckedDuringTyping = false;
    session.emit = (message) {
      if (message['method'] != 'textDocument/publishDiagnostics') return;
      final params = message['params'] as Map;
      if (params['qudsAnalysisComplete'] == false) return;
      if (params['version'] == 1) initial.add(params['uri'] as String);
      if (typing && (params['version'] as int) > 1) {
        duringTyping++;
        if (params['uri'] == b) secondCheckedDuringTyping = true;
      }
    };
    send(session, a, 1, 'main():\n  print 1\n');
    send(session, b, 1, 'main():\n  print 2\n');
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (initial.length < 2 && DateTime.now().isBefore(deadline))
      await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(initial, hasLength(2));
    typing = true;
    send(session, b, 2, 'main():\n  print 3\n');
    for (var version = 2; version <= 22; version++) {
      send(session, a, version, 'main():\n  print $version\n');
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    typing = false;
    expect(duringTyping, greaterThan(0));
    expect(secondCheckedDuringTyping, isTrue);
  });
  test('VS Code bounds change debounce and handles staged refreshes', () async {
    final result =
        await Process.run('node', ['test/editor/vscode_diagnostics.cjs']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('VSCODE DIAGNOSTICS OK'));
  });
}
