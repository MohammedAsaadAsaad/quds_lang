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

/// One original position for each generated line that has a mapping.
class SourcePositions {
  SourcePositions(this.byGeneratedLine);

  /// Generated line, one-based, to source path, source line, and column.
  final Map<int, (String, int, int)> byGeneratedLine;

  static SourcePositions parse(String sourceMap) {
    final data = jsonDecode(sourceMap) as Map<String, Object?>;
    final sources = (data['sources'] as List).cast<String>();
    final sections = (data['mappings'] as String).split(';');
    final byLine = <int, (String, int, int)>{};
    var sourceIndex = 0;
    var sourceLine = 0;
    var sourceColumn = 0;
    for (var i = 0; i < sections.length; i++) {
      for (final segment in sections[i].split(',')) {
        if (segment.isEmpty) continue;
        final cursor = [0];
        final values = <int>[];
        while (cursor[0] < segment.length) {
          values.add(_readVlq(segment, cursor));
        }
        if (values.length < 4) continue;
        sourceIndex += values[1];
        sourceLine += values[2];
        sourceColumn += values[3];
        byLine[i + 1] = (
          sources[sourceIndex],
          sourceLine + 1,
          sourceColumn + 1,
        );
      }
    }
    return SourcePositions(byLine);
  }

  (String, int, int)? original(int generatedLine) =>
      byGeneratedLine[generatedLine];

  /// The first generated line that came from [sourceLine] in [source].
  int? generated(String source, int sourceLine) {
    int? found;
    for (final entry in byGeneratedLine.entries) {
      final position = entry.value;
      if (position.$2 != sourceLine || !_pathsMatch(position.$1, source)) {
        continue;
      }
      if (found == null || entry.key < found) found = entry.key;
    }
    return found;
  }
}

bool _pathsMatch(String left, String right) =>
    left == right || left.endsWith('/$right') || right.endsWith('/$left');

/// Rewrites each frame in [stack] that hits [sourceMap].
///
/// A frame whose path ends with the map's `file` and whose generated line has
/// a mapping is reported as `source:line:column`, one-based. A frame that
/// does not hit stays unchanged. Async and isolate frames use the same rule.
/// A web stack is this function applied to the Dart-to-JavaScript map, then
/// to the Quds map.
String mapStack(String stack, String sourceMap) {
  final data = jsonDecode(sourceMap) as Map<String, Object?>;
  final file = data['file'] as String;
  final positions = SourcePositions.parse(sourceMap);
  return stack.replaceAllMapped(_frame, (match) {
    final path = match.group(1)!;
    if (!_sameFile(path, file)) return match.group(0)!;
    final hit = positions.original(int.parse(match.group(2)!));
    if (hit == null) return match.group(0)!;
    return '${hit.$1}:${hit.$2}:${hit.$3}';
  });
}

final _frame = RegExp(r'([\w./:+\-]+\.(?:dart|js)):(\d+):(\d+)');

bool _sameFile(String path, String file) =>
    path == file || path.endsWith('/$file');

int _readVlq(String data, List<int> cursor) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  var value = 0;
  var shift = 0;
  while (cursor[0] < data.length) {
    final digit = alphabet.indexOf(data[cursor[0]]);
    cursor[0]++;
    if (digit < 0) break;
    value |= (digit & 31) << shift;
    shift += 5;
    if (digit & 32 == 0) break;
  }
  final negative = value & 1 == 1;
  final magnitude = value >> 1;
  return negative ? -magnitude : magnitude;
}
