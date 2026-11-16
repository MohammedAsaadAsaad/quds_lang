import 'dart:convert';
import 'dart:io';
import 'package:quds_lang/quds_lang.dart';

// Diagnostic emitter-only benchmark; no timing assertion belongs in CI.
void main() {
  print(jsonEncode({
    'dart': Platform.version,
    'os': Platform.operatingSystem,
    'processors': Platform.numberOfProcessors,
    'warmup': 1,
    'repeat': 5,
    'phase': 'emission only; lexing/parsing/analysis excluded'
  }));
  for (final size in [250, 1000, 4000]) {
    final source =
        List.generate(size, (i) => 'f$i(value: int) -> int = value + $i')
            .join('\n');
    final program = Parser(Lexer().tokenize(source)).parse();
    final model = Analyzer().analyze(program);
    DartEmitter(model).emit(program);
    final times = <int>[];
    String output = '';
    String mapping = '';
    for (var i = 0; i < 5; i++) {
      final emitter = DartEmitter(model);
      final watch = Stopwatch()..start();
      output = emitter.emit(program);
      watch.stop();
      times.add(watch.elapsedMicroseconds);
      mapping = emitter.mappings
          .map((m) => '${m.$1}:${m.$2.line}:${m.$2.column}')
          .join('\n');
    }
    final sorted = [...times]..sort();
    print(jsonEncode({
      'functions': size,
      'samples_us': times,
      'median_us': sorted[2],
      'min_us': sorted.first,
      'max_us': sorted.last,
      'dart_bytes': utf8.encode(output).length,
      'dart_sha256': sha256Hex(utf8.encode(output)),
      'mapping_sha256': sha256Hex(utf8.encode(mapping))
    }));
  }
}
