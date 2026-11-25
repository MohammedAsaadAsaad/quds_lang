import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:quds/src/protocol.dart' as protocol;

void send(dynamic session, String uri, int version, String text) =>
    session.handle({
      'method':
          version == 1 ? 'textDocument/didOpen' : 'textDocument/didChange',
      'params': version == 1
          ? {
              'textDocument': {'uri': uri, 'version': version, 'text': text}
            }
          : {
              'textDocument': {'uri': uri, 'version': version},
              'contentChanges': [
                {'text': text}
              ]
            }
    });
Future<Map<String, Object?>> measure(String name, int size,
    {bool math = false}) async {
  final session = protocol.LspSession()..background = true;
  final uri = File('/tmp/quds_diagnostics_$name.quds').uri.toString();
  final ready = <int, Completer<void>>{};
  final watch = Stopwatch()..start();
  double? firstColor, firstError;
  var target = 1;
  session.emit = (message) {
    final params = message['params'] as Map;
    if (params['version'] != target) return;
    if (message['method'] == 'quds/semanticTokensReady')
      firstColor ??= watch.elapsedMicroseconds / 1000;
    if (message['method'] == 'textDocument/publishDiagnostics') {
      if ((params['diagnostics'] as List).isNotEmpty)
        firstError ??= watch.elapsedMicroseconds / 1000;
      if (params['qudsAnalysisComplete'] != false) {
        firstColor ??= watch.elapsedMicroseconds / 1000;
        ready.putIfAbsent(target, Completer<void>.new).complete();
      }
    }
  };
  final base =
      '${math ? 'use quds:math\n' : ''}main():\n${List.generate(size, (i) => '  value$i = $i\n  print value$i\n').join()}';
  try {
    send(session, uri, 1, base);
    await ready
        .putIfAbsent(1, Completer<void>.new)
        .future
        .timeout(const Duration(seconds: 60));
    final initial = {
      'first_colors_ms': firstColor,
      'complete_ms': watch.elapsedMicroseconds / 1000
    };
    target = 2;
    firstColor = null;
    firstError = null;
    watch.reset();
    send(session, uri, 2, '${base}  print unknownValue\n');
    await ready
        .putIfAbsent(2, Completer<void>.new)
        .future
        .timeout(const Duration(seconds: 60));
    return {
      'name': name,
      'bindings': size,
      'math_import': math,
      'initial': initial,
      'semantic_error_edit': {
        'first_colors_ms': firstColor,
        'first_error_ms': firstError,
        'complete_ms': watch.elapsedMicroseconds / 1000
      }
    };
  } finally {
    session.dispose();
  }
}

Future<Map<String, Object?>> continuous() async {
  final session = protocol.LspSession()..background = true;
  final uri = File('/tmp/quds_diagnostics_typing.quds').uri.toString();
  final initial = Completer<void>(), finalCheck = Completer<void>();
  var typing = false, count = 0;
  final watch = Stopwatch();
  double? first;
  session.emit = (message) {
    if (message['method'] != 'textDocument/publishDiagnostics') return;
    final params = message['params'] as Map;
    if (params['qudsAnalysisComplete'] == false) return;
    if (params['version'] == 1 && !initial.isCompleted) initial.complete();
    if (typing && (params['version'] as int) > 1) {
      count++;
      first ??= watch.elapsedMicroseconds / 1000;
    }
    if (params['version'] == 22 && !finalCheck.isCompleted)
      finalCheck.complete();
  };
  try {
    send(session, uri, 1, 'main():\n  print 1\n');
    await initial.future.timeout(const Duration(seconds: 20));
    typing = true;
    watch.start();
    for (var version = 2; version <= 22; version++) {
      send(session, uri, version, 'main():\n  print $version\n');
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    typing = false;
    await finalCheck.future.timeout(const Duration(seconds: 20));
    return {
      'updates': 21,
      'interval_ms': 60,
      'checks_while_typing': count,
      'first_check_while_typing_ms': first,
      'last_check_ms': watch.elapsedMicroseconds / 1000
    };
  } finally {
    session.dispose();
  }
}

Future<void> main() async {
  final samples = <Map<String, Object?>>[];
  for (final (name, count, math) in [
    ('small', 20, false),
    ('large', 5000, false),
    ('math', 1000, true)
  ]) {
    samples.add(await measure(name, count, math: math));
  }
  print(const JsonEncoder.withIndent('  ').convert({
    'schema': 1,
    'samples': samples,
    'continuous_typing': await continuous(),
    'scope':
        'Live LspSession and background isolates; includes debounce and worker startup on each document, excludes VS Code rendering and pipe transport. Single samples, not latency guarantees.'
  }));
}
