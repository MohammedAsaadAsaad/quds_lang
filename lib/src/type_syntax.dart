/// Structural operations on the compiler's existing textual type encoding.
/// These inspect balanced type delimiters; they do not parse Quds expressions.
List<String> splitTypeList(String text) {
  if (text.trim().isEmpty) return const [];
  final parts = <String>[];
  var start = 0;
  var parens = 0;
  var angles = 0;
  for (var i = 0; i < text.length; i++) {
    switch (text[i]) {
      case '(':
        parens++;
      case ')':
        parens--;
      case '<':
        angles++;
      case '>':
        if (i == 0 || text[i - 1] != '-') angles--;
      case ',':
        if (parens == 0 && angles == 0) {
          parts.add(text.substring(start, i).trim());
          start = i + 1;
        }
    }
  }
  parts.add(text.substring(start).trim());
  return parts;
}

int _closeParen(String type) {
  if (!type.startsWith('(')) return -1;
  var depth = 0;
  for (var i = 0; i < type.length; i++) {
    if (type[i] == '(') depth++;
    if (type[i] == ')' && --depth == 0) return i;
  }
  return -1;
}

/// Only a top-level arrow defines a function. A record can contain functions.
(String, String)? functionTypeParts(String type) {
  final close = _closeParen(type);
  if (close < 0) return null;
  final tail = type.substring(close + 1).trimLeft();
  if (!tail.startsWith('->')) return null;
  final result = tail.substring(2).trim();
  if (result.isEmpty || splitTypeList(result).length != 1) return null;
  return (type.substring(1, close), result);
}

bool isNullableType(String type) =>
    type.endsWith('?') && functionTypeParts(type) == null;

String nonNullableType(String type) {
  if (!isNullableType(type)) return type;
  final inner = type.substring(0, type.length - 1);
  if (_closeParen(inner) == inner.length - 1) {
    final grouped = inner.substring(1, inner.length - 1);
    if (functionTypeParts(grouped) != null) return grouped;
  }
  return inner;
}

String nullableType(String type) {
  if (type == 'Null' || type == 'dynamic' || isNullableType(type)) return type;
  return functionTypeParts(type) != null ? '($type)?' : '$type?';
}

String functionParameterType(String parameter) {
  final label = RegExp(r'^[^\s():,<>]+\s*:').firstMatch(parameter);
  return label == null
      ? parameter.trim()
      : parameter.substring(label.end).trim();
}
