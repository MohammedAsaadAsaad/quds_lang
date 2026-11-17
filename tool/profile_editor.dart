import 'dart:convert';
import 'dart:io';
import 'package:quds_lang/quds_lang.dart';

const workload =
    'use quds:math\nmain():\n  values = [1.0, 2.0, 3.0]\n  print mean(values)\n';
Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    final watch = Stopwatch()..start();
    final c = compile(workload, emitDart: args.single == 'full');
    print(jsonEncode({
      'milliseconds': watch.elapsedMicroseconds / 1000,
      'dart_bytes': c.dart.length,
      'bundles': c.bundles.length,
      'symbols': c.semantics.moduleSymbols.length
    }));
    return;
  }
  final phases = <String, Object?>{};
  for (final mode in ['full', 'analysis']) {
    final result = await Process.run(
        Platform.resolvedExecutable, ['run', 'tool/profile_editor.dart', mode]);
    if (result.exitCode != 0)
      throw StateError('${result.stdout}\n${result.stderr}');
    phases[mode] = jsonDecode('${result.stdout}');
  }
  final session = LspSession()..background = true;
  final uri = File('/tmp/quds-editor-profile.quds').uri.toString();
  var analyzed = false;
  session.emit = (_) {
    analyzed = true;
  };
  final ready = Stopwatch()..start();
  session.handle({
    'method': 'textDocument/didOpen',
    'params': {
      'textDocument': {'uri': uri, 'version': 1, 'text': workload}
    }
  });
  while (!analyzed && ready.elapsed < const Duration(seconds: 30))
    await Future<void>.delayed(const Duration(milliseconds: 5));
  if (!analyzed) throw StateError('Analysis timed out');
  phases['background_ready_ms'] = ready.elapsedMicroseconds / 1000;
  final samples = <double>[];
  var count = 0;
  for (var i = 0; i < 105; i++) {
    final watch = Stopwatch()..start();
    final result = session.handle({
      'id': i,
      'method': 'textDocument/completion',
      'params': {
        'textDocument': {'uri': uri},
        'position': {'line': 3, 'character': 8}
      }
    });
    // Include response serialization, not just internal lookup.
    jsonEncode(result.response);
    count = ((result.response!['result'] as Map)['items'] as List).length;
    if (i >= 5) samples.add(watch.elapsedMicroseconds / 1000);
  }
  samples.sort();
  phases['cached_completion'] = {
    'samples': samples.length,
    'items': count,
    'p50_ms': samples[49],
    'p95_ms': samples[94],
    'max_ms': samples.last,
    'includes_json_encoding': true
  };
  session.dispose();
  print(const JsonEncoder.withIndent('  ').convert({
    'dart': Platform.version,
    'workload': 'quds:math, analyzed live buffer',
    'phases': phases,
    'scope':
        'Language server and response encoding; excludes VS Code rendering and OS pipe transport.'
  }));
}
