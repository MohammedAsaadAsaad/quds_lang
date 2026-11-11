import 'dart:convert';

import 'emitter.dart';
import 'source.dart';

/// Source Map Revision 3, one mapping per generated line.
String encodeSourceMap(
    String generatedFile, String sourceFile, List<(int, SourceSpan)> mappings) {
  final byLine = <int, SourceSpan>{};
  for (final (line, span) in mappings) {
    byLine.putIfAbsent(line, () => span);
  }
  final lines = <String>[];
  var previousGenerated = 0;
  var previousSourceLine = 0;
  var previousSourceColumn = 0;
  final lastLine = byLine.keys.fold<int>(0, (a, b) => a > b ? a : b);
  for (var line = 1; line <= lastLine; line++) {
    final span = byLine[line];
    if (span == null) {
      lines.add('');
      continue;
    }
    final buffer = StringBuffer();
    buffer.write(_vlq(0 - previousGenerated));
    previousGenerated = 0;
    buffer.write(_vlq(0));
    buffer.write(_vlq(span.line - 1 - previousSourceLine));
    previousSourceLine = span.line - 1;
    buffer.write(_vlq(span.column - 1 - previousSourceColumn));
    previousSourceColumn = span.column - 1;
    lines.add(buffer.toString());
  }
  return jsonEncode({
    'version': 3,
    'file': generatedFile,
    'sources': [sourceFile],
    'names': <String>[],
    'mappings': lines.join(';'),
  });
}

String _vlq(int value) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  var number = value < 0 ? ((-value) << 1) | 1 : value << 1;
  final out = StringBuffer();
  do {
    var digit = number & 31;
    number >>= 5;
    if (number > 0) digit |= 32;
    out.write(alphabet[digit]);
  } while (number > 0);
  return out.toString();
}

String? sourceMapFor(
    DartEmitter emitter, String generatedFile, String sourceFile) {
  if (emitter.mappings.isEmpty) return null;
  return encodeSourceMap(generatedFile, sourceFile, emitter.mappings);
}
