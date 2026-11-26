/// Structural operations on the compiler's existing textual type encoding.
/// These inspect balanced type delimiters; they do not parse Quds expressions.
List<String> splitTypeList(String text) {
  if (text.trim().isEmpty) return const [];
  final parts = <String>[];
  var start = 0;
  var parens = 0;
  var angles = 0;
  var brackets = 0;
  var braces = 0;
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
      case '[':
        brackets++;
      case ']':
        brackets--;
      case '{':
        braces++;
      case '}':
        braces--;
      case ',':
        if (parens == 0 && angles == 0 && brackets == 0 && braces == 0) {
          parts.add(text.substring(start, i).trim());
          start = i + 1;
        }
    }
  }
  parts.add(text.substring(start).trim());
  return parts;
}

/// Splits a record type like `(int, {String name, List<int> items})` into
/// `(fieldNameOrNull, fieldType)` entries in declaration order.
List<(String?, String)> splitRecordTypeFields(String type) {
  if (!type.startsWith('(') || !type.endsWith(')')) return const [];
  final inner = type.substring(1, type.length - 1).trim();
  if (inner.isEmpty) return const [];
  final result = <(String?, String)>[];
  for (final raw in splitTypeList(inner)) {
    final part = raw.trim();
    if (part.isEmpty) continue;
    if (part.startsWith('{') && part.endsWith('}')) {
      for (final entry in splitTypeList(part.substring(1, part.length - 1))) {
        final t = entry.trim();
        if (t.isEmpty) continue;
        final colon = t.indexOf(':');
        if (colon > 0 && !t.substring(0, colon).contains(' ')) {
          result.add(
              (t.substring(0, colon).trim(), t.substring(colon + 1).trim()));
        } else {
          final space = t.lastIndexOf(' ');
          if (space > 0) {
            result.add(
                (t.substring(space + 1).trim(), t.substring(0, space).trim()));
          } else {
            result.add((null, t));
          }
        }
      }
    } else {
      result.add((null, part));
    }
  }
  return result;
}

/// Splits [text] on a top-level operator (such as `' | '` or `' & '`) outside
/// nested `()`, `<>`, `[]`, and `{}` delimiters.
List<String> splitTopLevelTypeOp(String text, String op) {
  final parts = <String>[];
  var start = 0;
  var parens = 0;
  var angles = 0;
  var brackets = 0;
  var braces = 0;
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
      case '[':
        brackets++;
      case ']':
        brackets--;
      case '{':
        braces++;
      case '}':
        braces--;
      default:
        if (parens == 0 &&
            angles == 0 &&
            brackets == 0 &&
            braces == 0 &&
            text.startsWith(op, i)) {
          parts.add(text.substring(start, i).trim());
          i += op.length - 1;
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

String functionParameterType(String parameter) =>
    functionParameters(parameter).single.type;

/// Remove only the outer qualifier, preserving nested readonly type arguments.
String stripReadonlyType(String type) =>
    type.startsWith('readonly ') ? type.substring(9) : type;

/// Parameter metadata in a structural function type. Defaults describe omission;
/// their values belong to the callable declaration, never to this type.
class FunctionParameterShape {
  const FunctionParameterShape(this.type,
      {this.name,
      this.named = false,
      this.optional = false,
      this.variadic = false});
  final String type;
  final String? name;
  final bool named;
  final bool optional;

  /// `...name: Type` collects the remaining positional arguments.
  final bool variadic;
}

List<FunctionParameterShape> functionParameters(String text) {
  final result = <FunctionParameterShape>[];
  for (final part in splitTypeList(text)) {
    if (part.startsWith('...')) {
      final parsed = functionParameters(part.substring(3).trim()).single;
      result.add(FunctionParameterShape(parsed.type,
          name: parsed.name, variadic: true));
      continue;
    }
    if (part.startsWith('[') && part.endsWith(']')) {
      result.addAll(functionParameters(part.substring(1, part.length - 1)).map(
          (p) => FunctionParameterShape(p.type,
              name: p.name, optional: true, variadic: p.variadic)));
      continue;
    }
    final label = RegExp(r'^([^\s():,<>]+)\s*:').firstMatch(part);
    var type = label == null ? part : part.substring(label.end).trim();
    final optional = type.endsWith(' = missing');
    final named = optional || type.endsWith(' required');
    if (optional) type = type.substring(0, type.length - 10).trim();
    if (type.endsWith(' required')) {
      type = type.substring(0, type.length - 9).trim();
    }
    result.add(FunctionParameterShape(type,
        name: label?.group(1), named: named, optional: optional));
  }
  return result;
}

String nativeFunctionParameters(List<(String, String)> parameters,
    Set<String> named, Set<String> optional) {
  return parameters.map((p) {
    if (p.$2.startsWith('...')) return '...${p.$1}: ${p.$2.substring(3)}';
    if (named.contains(p.$1)) {
      return '${p.$1}: ${p.$2}${optional.contains(p.$1) ? ' = missing' : ' required'}';
    }
    return optional.contains(p.$1) ? '[${p.$1}: ${p.$2}]' : p.$2;
  }).join(', ');
}

/// Function arguments are contravariant. The source must accept every call
/// admitted by the destination (including omission and required named labels).
bool functionParametersCompatible(String source, String destination,
    bool Function(String, String) compatible) {
  var from = functionParameters(source), to = functionParameters(destination);
  if (from.any((p) => p.variadic) || to.any((p) => p.variadic)) {
    if (from.isEmpty ||
        to.isEmpty ||
        !from.last.variadic ||
        !to.last.variadic ||
        !compatible(to.last.type, from.last.type)) {
      return false;
    }
    from = from.sublist(0, from.length - 1);
    to = to.sublist(0, to.length - 1);
  }
  final a = from.where((p) => !p.named).toList();
  final b = to.where((p) => !p.named).toList();
  if (a.where((p) => !p.optional).length > b.where((p) => !p.optional).length ||
      a.length < b.length) {
    return false;
  }
  for (var i = 0; i < b.length; i++) {
    if (!compatible(b[i].type, a[i].type)) return false;
  }
  final an = {for (final p in from.where((p) => p.named)) p.name: p};
  final bn = {for (final p in to.where((p) => p.named)) p.name: p};
  for (final p in an.values) {
    if (!p.optional && (bn[p.name] == null || bn[p.name]!.optional)) {
      return false;
    }
  }
  for (final p in bn.values) {
    final other = an[p.name];
    if (other == null || !compatible(p.type, other.type)) return false;
  }
  return true;
}
