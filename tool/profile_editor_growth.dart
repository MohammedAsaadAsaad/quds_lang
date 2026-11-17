import 'dart:convert';
import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/navigate.dart';
import 'package:quds_lang/src/complete.dart';

void main() {
  final results = <Map<String, Object>>[];
  for (final size in [100, 1000, 5000]) {
    final source =
        'main():\n${List.generate(size, (i) => '  value$i = $i\n  print value$i\n').join()}';
    final compileWatch = Stopwatch()..start();
    final c = compile(source, emitDart: false);
    compileWatch.stop();
    final watch = Stopwatch()..start();
    final tokens = semanticTokenData(c, source);
    watch.stop();
    final completions = Stopwatch()..start();
    final items = completeAt(
        source: source,
        line: size * 2,
        character: 8,
        stable: c,
        compileSource: (_) => throw StateError('Unexpected recompile'));
    completions.stop();
    results.add({
      'bindings': size,
      'source_utf16': source.length,
      'analysis_ms': compileWatch.elapsedMicroseconds / 1000,
      'semantic_tokens_ms': watch.elapsedMicroseconds / 1000,
      'completion_ms': completions.elapsedMicroseconds / 1000,
      'tokens': tokens.length ~/ 5,
      'items': items.length
    });
  }
  print(const JsonEncoder.withIndent('  ').convert(results));
}
