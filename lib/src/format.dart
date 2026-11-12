/// Two-space indents and a width of 80. Comments, documentation, and string
/// contents stay. A long line breaks after the last comma that still fits.
/// Trailing whitespace outside a string is removed, and a newline ends the file.
String formatQuds(String source) {
  final lines = source.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  final inside = <bool>[];
  final indents = <int>[];
  var open = '';
  for (final line in lines) {
    if (open.isNotEmpty) {
      inside.add(true);
      open = _advanceQuotes(line, open);
      continue;
    }
    inside.add(false);
    if (line.trim().isNotEmpty) {
      final width = line.length - line.trimLeft().length;
      if (!indents.contains(width)) indents.add(width);
    }
    open = _advanceQuotes(line, '');
  }
  indents.sort();
  final rewritten = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (inside[i]) {
      rewritten.add(lines[i]);
      continue;
    }
    final line = lines[i].trimRight();
    if (line.trim().isEmpty) {
      rewritten.add('');
      continue;
    }
    final width = line.length - line.trimLeft().length;
    final depth = indents.indexOf(width);
    final body = '${'  ' * (depth < 0 ? 0 : depth)}${line.trimLeft()}';
    rewritten.addAll(_wrapLine(body));
  }
  return '${rewritten.join('\n')}\n';
}

List<String> _wrapLine(String line, {bool pending = false}) {
  if (line.length <= 80) return [line];
  final content = line.trimLeft();
  if (content.startsWith('#') || content.startsWith('///')) return [line];
  final indent = line.length - content.length;
  final split = _wrapAt(content, 80 - indent, pending: pending);
  if (split == null) return [line];
  return [
    '${' ' * indent}${split.left}',
    ..._wrapLine('${' ' * indent}${split.right}', pending: split.pending),
  ];
}

/// A comma splits only inside `()` or `[]`, and the next line keeps the same
/// indent so the lexer does not open a block.
_Split? _wrapAt(String text, int budget, {required bool pending}) {
  if (budget <= 0) return null;
  var quote = '';
  var depth = pending ? 1 : 0;
  var last = -1;
  var lastDepth = 0;
  for (var i = 0; i < text.length && i < budget; i++) {
    if (quote.isNotEmpty) {
      if (text.startsWith(quote, i)) {
        i += quote.length - 1;
        quote = '';
      } else if (quote.length == 1 && text[i] == '\\') {
        i++;
      }
      continue;
    }
    if (text.startsWith('"""', i) || text.startsWith("'''", i)) {
      quote = text.substring(i, i + 3);
      i += 2;
      continue;
    }
    final char = text[i];
    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }
    if (char == '#') break;
    if (char == '(' || char == '[') {
      depth++;
    } else if ((char == ')' || char == ']') && depth > 0) {
      depth--;
    } else if (char == ',' && depth > 0) {
      last = i;
      lastDepth = depth;
    }
  }
  if (last < 0 || last + 1 >= text.length) return null;
  final rest = text.substring(last + 1).trimLeft();
  if (rest.isEmpty) return null;
  return _Split(text.substring(0, last + 1), rest, lastDepth > 0);
}

class _Split {
  const _Split(this.left, this.right, this.pending);
  final String left;
  final String right;
  final bool pending;
}

String _advanceQuotes(String line, String open) {
  var current = open;
  var i = 0;
  while (i < line.length) {
    if (current.isNotEmpty) {
      if (line.startsWith(current, i)) {
        current = '';
        i += 3;
        continue;
      }
      i++;
      continue;
    }
    if (line.startsWith('"""', i) || line.startsWith("'''", i)) {
      current = line.substring(i, i + 3);
      i += 3;
      continue;
    }
    final quote = line[i];
    if (quote == '"' || quote == "'") {
      i++;
      while (i < line.length && line[i] != quote) {
        if (line[i] == '\\' && i + 1 < line.length) {
          i += 2;
          continue;
        }
        i++;
      }
      if (i < line.length) i++;
      continue;
    }
    i++;
  }
  return current;
}
