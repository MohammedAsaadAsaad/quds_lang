import 'dart:convert';

import 'ast.dart';
import 'compiler.dart';
import 'semantics.dart';
import 'source.dart';
import 'walk.dart';

/// LSP completion items for [source] at the zero-based [line] and [character].
///
/// A successful analysis of this buffer is reused. While the current line is
/// incomplete, names declared on earlier lines still come from that analysis,
/// so typing does not compile the file again. A complex receiver that the
/// saved analysis does not contain is compiled once, with the unfinished token
/// removed.
List<Map<String, Object?>> completeAt({
  required String source,
  required int line,
  required int character,
  Compilation? stable,
  required Compilation? Function(String source) compileSource,
}) {
  final cursor = _stringIndexAt(source, line, character);
  if (!_inCode(source, cursor)) return const [];
  final word = _word(source, cursor);
  final prefix = word.read(source);
  if (prefix.isNotEmpty && _digit(prefix.codeUnitAt(0))) return const [];
  final dot = _dotBefore(source, word.start);
  final range = _range(source, word.start, word.end);
  final items = <String, Map<String, Object?>>{};
  void add(Map<String, Object?> item) {
    final label = item['label'];
    final detail = item['detail'];
    items.putIfAbsent('$label|$detail', () => item);
  }

  Compilation? resolved = stable;
  Compilation? compile(String next) {
    if (next == source && resolved != null) return resolved;
    return compileSource(next);
  }

  if (dot != null) {
    final name = _receiverName(source, dot);
    final literal = name == null ? _literalType(source, dot) : null;
    if (literal != null) {
      _builtinMembers(literal, false, range, add);
      return items.values.toList();
    }
    final compilation = name != null && !_chained(source, dot)
        ? (resolved ?? _recover(source, word, dot, compile))
        : _recover(source, word, dot, compile);
    if (compilation == null) return const [];
    final scope = _scopeAt(compilation, source, cursor);
    _members(
      compilation,
      source,
      dot,
      word,
      scope,
      range,
      add,
    );
    return items.values.toList();
  }

  resolved ??= _recover(source, word, null, compile);
  final scope = resolved == null
      ? _Here(const {}, null)
      : _scopeAt(resolved, source, cursor);
  final argument = _argument(source, word.start);
  if (argument != null && resolved != null) {
    _namedArguments(resolved, source, scope, argument, range, add);
  }
  for (final entry in scope.names.entries) {
    if (entry.key == '_') continue;
    for (final item in _symbolItems(resolved, entry.value, range)) {
      add(item);
    }
  }
  if (scope.owner != null) {
    add(_plain('this', 14, scope.owner!.name, range, sort: '1'));
    if (scope.owner!.superclass != null) {
      add(_plain('super', 14, scope.owner!.superclass!, range, sort: '1'));
    }
  }
  for (final type in _builtinTypes) {
    if (scope.names.containsKey(type)) continue;
    add(_plain(type, 7, 'type', range, sort: '1'));
  }
  final atStatement = _statementStart(source, word.start);
  for (final keyword in _keywords) {
    if (atStatement && _snippets.containsKey(keyword)) continue;
    add(_plain(keyword, 14, 'keyword', range, sort: '3', commit: false));
  }
  if (atStatement) {
    final indent = _indent(source, word.start);
    for (final entry in _snippets.entries) {
      final body = entry.value.replaceAll('\n', '\n$indent');
      add({
        'label': entry.key,
        'kind': 15,
        'detail': 'snippet',
        'filterText': entry.key,
        'sortText': '0${entry.key}',
        'insertTextFormat': 2,
        'textEdit': {...range, 'newText': body},
      });
    }
  }
  return items.values.toList();
}

const _keywords = [
  'and',
  'as',
  'async',
  'await',
  'break',
  'catch',
  'class',
  'const',
  'continue',
  'do',
  'else',
  'enum',
  'false',
  'for',
  'if',
  'in',
  'is',
  'late',
  'match',
  'not',
  'null',
  'or',
  'private',
  'protected',
  'readonly',
  'required',
  'return',
  'shadow',
  'switch',
  'throw',
  'true',
  'try',
  'use',
  'var',
  'while',
  'with',
  'yield',
];

const _snippets = {
  'if': 'if \${1:condition}:\n  \$0',
  'for': 'for \${1:name} in \${2:items}:\n  \$0',
  'while': 'while \${1:condition}:\n  \$0',
  'else': 'else:\n  \$0',
  'match': 'match \${1:value}:\n  \${2:pattern}:\n    \$0',
  'var': 'var \${1:name} = \$0',
  'const': 'const \${1:name} = \$0',
};

const _builtinTypes = [
  'int',
  'double',
  'num',
  'String',
  'bool',
  'List',
  'Map',
  'Set',
  'Iterable',
  'Object',
  'Null',
  'Never',
  'void',
  'Future',
  'Stream',
];

class _Word {
  const _Word(this.start, this.end);
  final int start, end;
  String read(String source) => source.substring(start, end);
}

_Word _word(String source, int cursor) {
  var start = cursor;
  var end = cursor;
  while (start > 0 && _ident(source.codeUnitAt(start - 1))) {
    start--;
  }
  while (end < source.length && _ident(source.codeUnitAt(end))) {
    end++;
  }
  return _Word(start, end);
}

bool _ident(int unit) =>
    unit == 95 ||
    unit == 36 ||
    (unit >= 65 && unit <= 90) ||
    (unit >= 97 && unit <= 122) ||
    (unit >= 48 && unit <= 57);

bool _digit(int unit) => unit >= 48 && unit <= 57;

bool _space(int unit) => unit == 32 || unit == 9;

/// Index of `.` before the word, when this is member completion.
int? _dotBefore(String source, int wordStart) {
  var index = wordStart;
  while (index > 0 && _space(source.codeUnitAt(index - 1))) {
    index--;
  }
  if (index == 0 || source.codeUnitAt(index - 1) != 46) return null;
  if (index > 1 && source.codeUnitAt(index - 2) == 46) return null;
  var previous = index - 1;
  while (previous > 0 && _space(source.codeUnitAt(previous - 1))) {
    previous--;
  }
  if (previous > 0 && _digit(source.codeUnitAt(previous - 1))) return null;
  return index - 1;
}

bool _chained(String source, int dot) {
  final name = _receiverName(source, dot);
  if (name == null) return true;
  final start = dot - name.length;
  if (start > 0 && source.codeUnitAt(start - 1) == 46) return true;
  return false;
}

String? _literalType(String source, int dot) {
  var index = dot;
  if (index > 0 && source.codeUnitAt(index - 1) == 63) index--;
  while (index > 0 && _space(source.codeUnitAt(index - 1))) {
    index--;
  }
  if (index == 0) return null;
  final unit = source.codeUnitAt(index - 1);
  if (unit == 34 || unit == 39) return 'String';
  return null;
}

String? _receiverName(String source, int dot) {
  var index = dot;
  if (index > 0 && source.codeUnitAt(index - 1) == 63) index--;
  while (index > 0 && _space(source.codeUnitAt(index - 1))) {
    index--;
  }
  final end = index;
  while (index > 0 && _ident(source.codeUnitAt(index - 1))) {
    index--;
  }
  if (index == end) return null;
  final text = source.substring(index, end);
  if (text == 'this' || text == 'super') return text;
  if (_digit(text.codeUnitAt(0))) return null;
  return text;
}

Compilation? _recover(
  String source,
  _Word word,
  int? dot,
  Compilation? Function(String source) compile,
) {
  final attempts = <String>[];
  if (dot != null) {
    var from = dot;
    if (from > 0 && source.codeUnitAt(from - 1) == 63) from--;
    attempts.add(source.substring(0, from) + source.substring(word.end));
  }
  if (word.start != word.end) {
    attempts.add(
        source.substring(0, word.start) + '0' + source.substring(word.end));
  }
  attempts.add(_replaceLine(source, word.start));
  final seen = <String>{};
  for (final attempt in attempts) {
    if (!seen.add(attempt)) continue;
    final compiled = compile(attempt);
    if (compiled != null) return compiled;
  }
  return null;
}

String _replaceLine(String source, int index) {
  var start = index;
  while (start > 0 && source.codeUnitAt(start - 1) != 10) {
    start--;
  }
  var end = index;
  while (end < source.length && source.codeUnitAt(end) != 10) {
    end++;
  }
  final line = source.substring(start, index < end ? end : index);
  final indent = RegExp(r'^ *').matchAsPrefix(line)?.group(0) ?? '';
  return '${source.substring(0, start)}${indent}print 0${source.substring(end)}';
}

class _Here {
  const _Here(this.names, this.owner);
  final Map<String, Symbol> names;
  final ClassDeclaration? owner;
}

_Here _scopeAt(Compilation compilation, String source, int cursor) {
  final bytes = _bytes(source, cursor);
  final scope = _blocks(
    compilation,
    source,
    bytes,
    compilation.program.statements,
    Map<String, Symbol>.of(compilation.semantics.moduleSymbols),
    1 << 30,
    null,
  );
  final lambda = _lambda(compilation, bytes);
  if (lambda == null) return scope;
  final names = Map<String, Symbol>.of(scope.names);
  for (final parameter in lambda.parameters) {
    final symbol = compilation.semantics.declarations[parameter] ??
        Symbol(parameter.name, parameter.name, parameter.type);
    if (parameter.name != '_') names[parameter.name] = symbol;
  }
  return _Here(names, scope.owner);
}

Lambda? _lambda(Compilation compilation, int bytes) {
  Lambda? found;
  var best = 1 << 30;
  walkAst(compilation.program, (node) {
    if (node is! Lambda) return;
    if (bytes < node.span.offset ||
        bytes >= node.span.offset + node.span.length) {
      return;
    }
    if (node.span.length < best) {
      best = node.span.length;
      found = node;
    }
  });
  return found;
}

_Here _blocks(
  Compilation compilation,
  String source,
  int bytes,
  List<Statement> body,
  Map<String, Symbol> outer,
  int regionEnd,
  ClassDeclaration? owner,
) {
  final here = Map<String, Symbol>.of(outer);
  for (var i = 0; i < body.length; i++) {
    final statement = body[i];
    final next = i + 1 < body.length ? body[i + 1].span.offset : regionEnd;
    if (bytes < statement.span.offset) break;
    if (bytes < next) {
      final nested =
          _enter(compilation, source, bytes, statement, here, next, owner);
      if (nested != null) return nested;
      if (bytes >= statement.span.offset + statement.span.length) {
        _addBinding(compilation, statement, here);
      }
      return _Here(here, owner);
    }
    _addBinding(compilation, statement, here);
  }
  return _Here(here, owner);
}

void _addBinding(
    Compilation compilation, Statement statement, Map<String, Symbol> here) {
  if (statement is! Binding && statement is! FunctionDeclaration) return;
  final symbol = compilation.semantics.declarations[statement];
  if (symbol == null || symbol.name == '_') return;
  here[symbol.name] = symbol;
}

_Here? _enter(
  Compilation compilation,
  String source,
  int bytes,
  Statement statement,
  Map<String, Symbol> outer,
  int regionEnd,
  ClassDeclaration? owner,
) {
  switch (statement) {
    case FunctionDeclaration():
      return _function(
          compilation, source, bytes, statement, outer, regionEnd, owner);
    case ClassDeclaration():
      return _class(compilation, source, bytes, statement, outer, regionEnd);
    case ForStatement():
      if (!_past(bytes, statement.iterable.span)) return null;
      final names = Map<String, Symbol>.of(outer);
      final symbol = compilation.semantics.declarations[statement];
      if (symbol != null && statement.name != '_') names[symbol.name] = symbol;
      return _blocks(
          compilation, source, bytes, statement.body, names, regionEnd, owner);
    case IfStatement():
      return _branch(compilation, source, bytes, statement.thenBody,
              statement.elseBody, outer, regionEnd, owner) ??
          _branch(compilation, source, bytes, statement.elseBody, const [],
              outer, regionEnd, owner);
    case WhileStatement():
      if (!_past(bytes, statement.condition.span)) return null;
      return _blocks(
          compilation, source, bytes, statement.body, outer, regionEnd, owner);
    case IfLetStatement():
      if (statement.thenBody.isEmpty ||
          bytes < statement.thenBody.first.span.offset) {
        return null;
      }
      if (statement.elseBody.isNotEmpty &&
          bytes >= statement.elseBody.first.span.offset) {
        return _blocks(compilation, source, bytes, statement.elseBody, outer,
            regionEnd, owner);
      }
      final names = Map<String, Symbol>.of(outer);
      final symbol = compilation.semantics.declarations[statement];
      if (symbol != null && statement.name != '_') names[symbol.name] = symbol;
      return _blocks(compilation, source, bytes, statement.thenBody, names,
          regionEnd, owner);
    case UsingStatement():
      if (statement.body.isEmpty || bytes < statement.body.first.span.offset) {
        return null;
      }
      final names = Map<String, Symbol>.of(outer);
      final symbol = compilation.semantics.declarations[statement];
      if (symbol != null && statement.name != '_') names[symbol.name] = symbol;
      return _blocks(
          compilation, source, bytes, statement.body, names, regionEnd, owner);
    case TryStatement():
      final tried = _insideList(
          compilation, source, bytes, statement.body, outer, regionEnd, owner);
      if (tried != null) return tried;
      for (final clause in statement.catches) {
        if (bytes < clause.span.offset) continue;
        if (clause.body.isEmpty || bytes < clause.body.first.span.offset) {
          continue;
        }
        final names = Map<String, Symbol>.of(outer);
        final caught = compilation.semantics.declarations[clause];
        if (caught != null && clause.name != '_') names[clause.name] = caught;
        final trace = compilation.semantics.traces[clause];
        if (trace != null && clause.trace != null) names[clause.trace!] = trace;
        return _blocks(
            compilation, source, bytes, clause.body, names, regionEnd, owner);
      }
      return _insideList(compilation, source, bytes, statement.finallyBody,
          outer, regionEnd, owner);
    case CForStatement():
      if (!_past(bytes, statement.init.span)) return null;
      final names = Map<String, Symbol>.of(outer);
      _addBinding(compilation, statement.init, names);
      if (statement.body.isEmpty || bytes < statement.body.first.span.offset) {
        return _Here(names, owner);
      }
      return _blocks(
          compilation, source, bytes, statement.body, names, regionEnd, owner);
    default:
      return null;
  }
}

bool _past(int bytes, SourceSpan span) => bytes >= span.offset + span.length;

_Here? _branch(
  Compilation compilation,
  String source,
  int bytes,
  List<Statement> body,
  List<Statement> later,
  Map<String, Symbol> outer,
  int regionEnd,
  ClassDeclaration? owner,
) {
  if (body.isEmpty || bytes < body.first.span.offset) return null;
  if (later.isNotEmpty && bytes >= later.first.span.offset) return null;
  return _blocks(compilation, source, bytes, body, outer, regionEnd, owner);
}

_Here? _insideList(
  Compilation compilation,
  String source,
  int bytes,
  List<Statement> body,
  Map<String, Symbol> outer,
  int regionEnd,
  ClassDeclaration? owner,
) {
  if (body.isEmpty ||
      bytes < body.first.span.offset ||
      bytes >= body.last.span.offset + body.last.span.length &&
          bytes >= regionEnd) {
    return null;
  }
  if (bytes < body.first.span.offset) return null;
  if (bytes >= body.last.span.offset + body.last.span.length) return null;
  return _blocks(compilation, source, bytes, body, outer, regionEnd, owner);
}

_Here? _function(
  Compilation compilation,
  String source,
  int bytes,
  FunctionDeclaration function,
  Map<String, Symbol> outer,
  int regionEnd,
  ClassDeclaration? owner,
) {
  if (!_inBody(source, bytes, function.span, function.body)) return null;
  final names = Map<String, Symbol>.of(outer);
  final self = compilation.semantics.declarations[function];
  if (self != null) names[function.name] = self;
  if (owner != null) _instanceMembers(compilation, owner, names);
  for (final parameter in function.parameters) {
    final symbol = compilation.semantics.declarations[parameter] ??
        Symbol(parameter.name, parameter.name, parameter.type,
            mutable: parameter.mutable);
    if (parameter.name != '_') names[parameter.name] = symbol;
  }
  final body = function.body;
  if (body == null) return _Here(names, owner);
  return _blocks(compilation, source, bytes, body, names, regionEnd, owner);
}

bool _inBody(
    String source, int bytes, SourceSpan header, List<Statement>? body) {
  if (body != null && body.isNotEmpty && bytes >= body.first.span.offset) {
    return true;
  }
  if (bytes < header.offset + header.length &&
      (body == null || body.isEmpty || bytes < body.first.span.offset)) {
    final cursorLine = _lineOfByte(source, bytes);
    final headerLine = _lineOfByte(source, header.offset);
    if (cursorLine == headerLine) return false;
  }
  if (bytes < header.offset) return false;
  final cursor = _stringIndexForByte(source, bytes);
  final cursorIndent = _lineIndent(source, cursor);
  if (cursorIndent < 0) return bytes >= header.offset;
  final headerIndent =
      _lineIndent(source, _stringIndexForByte(source, header.offset));
  return cursorIndent > headerIndent;
}

_Here? _class(
  Compilation compilation,
  String source,
  int bytes,
  ClassDeclaration type,
  Map<String, Symbol> outer,
  int regionEnd,
) {
  final members = <Node>[
    ...type.constructors,
    ...type.fields,
    ...type.methods,
    ...type.properties,
  ]..sort((a, b) => a.span.offset.compareTo(b.span.offset));
  for (var i = 0; i < members.length; i++) {
    final member = members[i];
    final next =
        i + 1 < members.length ? members[i + 1].span.offset : regionEnd;
    if (bytes < member.span.offset || bytes >= next) continue;
    switch (member) {
      case FunctionDeclaration():
        return _function(compilation, source, bytes, member, outer, next, type);
      case ConstructorDeclaration():
        return _constructor(
            compilation, source, bytes, type, member, outer, next);
      case PropertyDeclaration():
        return _property(compilation, source, bytes, type, member, outer, next);
      default:
        return null;
    }
  }
  return null;
}

_Here? _constructor(
  Compilation compilation,
  String source,
  int bytes,
  ClassDeclaration type,
  ConstructorDeclaration constructor,
  Map<String, Symbol> outer,
  int regionEnd,
) {
  final body = constructor.body;
  if (body == null || !_inBody(source, bytes, constructor.span, body)) {
    return null;
  }
  final names = Map<String, Symbol>.of(outer);
  _instanceMembers(compilation, type, names);
  for (final parameter in constructor.parameters) {
    final symbol = compilation.semantics.declarations[parameter] ??
        Symbol(parameter.name, parameter.name, parameter.type);
    if (parameter.name != '_') names[parameter.name] = symbol;
  }
  return _blocks(compilation, source, bytes, body, names, regionEnd, type);
}

_Here? _property(
  Compilation compilation,
  String source,
  int bytes,
  ClassDeclaration type,
  PropertyDeclaration property,
  Map<String, Symbol> outer,
  int regionEnd,
) {
  final names = Map<String, Symbol>.of(outer);
  _instanceMembers(compilation, type, names);
  final getter = property.getterBody;
  if (getter != null &&
      getter.isNotEmpty &&
      bytes >= getter.first.span.offset &&
      bytes < getter.last.span.offset + getter.last.span.length) {
    return _blocks(compilation, source, bytes, getter, names, regionEnd, type);
  }
  final setter = property.setterBody;
  if (setter != null &&
      setter.isNotEmpty &&
      bytes >= setter.first.span.offset) {
    final parameter = property.setter ?? 'value';
    names[parameter] =
        Symbol(parameter, parameter, property.type, mutable: true);
    return _blocks(compilation, source, bytes, setter, names, regionEnd, type);
  }
  return null;
}

void _instanceMembers(
    Compilation compilation, ClassDeclaration type, Map<String, Symbol> names) {
  for (final current in _lineage(compilation, type)) {
    for (final field in current.fields) {
      if (field.isStatic || !_name(field.name)) continue;
      names[field.name] = compilation.semantics.declarations[field] ??
          Symbol(field.name, field.name, field.type,
              mutable: field.mutable, field: true);
    }
    for (final property in current.properties) {
      if (!_name(property.name)) continue;
      names[property.name] =
          Symbol(property.name, property.name, property.type, field: true);
    }
    for (final method in current.methods) {
      if (method.isStatic || method.isOperator || !_name(method.name)) continue;
      final symbol = compilation.semantics.declarations[method];
      if (symbol != null) names[method.name] = symbol;
    }
  }
}

List<ClassDeclaration> _lineage(
    Compilation compilation, ClassDeclaration type) {
  final found = <ClassDeclaration>[];
  final seen = <ClassDeclaration>{};
  void walk(ClassDeclaration? current) {
    if (current == null || !seen.add(current)) return;
    final parent = current.superclass == null
        ? null
        : compilation.semantics.classes[_head(current.superclass!)];
    if (parent != null) walk(parent);
    for (final mixin in current.mixins) {
      final declaration = compilation.semantics.classes[_head(mixin)];
      if (declaration != null) walk(declaration);
    }
    found.add(current);
  }

  walk(type);
  return found;
}

void _members(
  Compilation compilation,
  String source,
  int dot,
  _Word word,
  _Here scope,
  Map<String, Object> range,
  void Function(Map<String, Object?>) add,
) {
  final name = _receiverName(source, dot);
  if (name == 'this' && scope.owner != null) {
    _typeMembers(
        compilation, scope.owner!.name, scope.owner, false, range, add);
    return;
  }
  if (name == 'super' && scope.owner?.superclass != null) {
    _typeMembers(
        compilation, scope.owner!.superclass!, null, false, range, add);
    return;
  }
  final symbol = name == null ? null : scope.names[name];
  if (symbol != null && symbol.namespace != null) {
    for (final entry in symbol.namespace!.entries) {
      for (final item in _symbolItems(compilation, entry.value, range)) {
        add(item);
      }
    }
    return;
  }
  final onType = symbol != null &&
      symbol.classDeclaration != null &&
      symbol.classCase == null;
  final type = onType
      ? symbol.classDeclaration!.name
      : symbol?.type ?? _expressionType(compilation, source, dot);
  if (type == null || type == 'prefix') return;
  _typeMembers(compilation, type, symbol?.classDeclaration, onType, range, add);
}

String? _expressionType(Compilation compilation, String source, int dot) {
  final end = _bytes(source, dot);
  Expression? best;
  var size = 1 << 30;
  walkAst(compilation.program, (node) {
    if (node is! Expression) return;
    final stop = node.span.offset + node.span.length;
    if (stop > end) return;
    final gap = source.substring(
        _stringIndexForByte(source, stop), _stringIndexForByte(source, end));
    if (!RegExp(r'^[)\s]*$').hasMatch(gap)) return;
    if (end - stop > size) return;
    if (end - stop < size ||
        node.span.length < (best?.span.length ?? 1 << 30)) {
      size = end - stop;
      best = node;
    }
  });
  final node = best;
  if (node == null) return null;
  if (node is Identifier) {
    final symbol = compilation.semantics.references[node];
    if (symbol != null) return symbol.type;
  }
  return compilation.semantics.types[node];
}

void _typeMembers(
  Compilation compilation,
  String type,
  ClassDeclaration? known,
  bool onType,
  Map<String, Object> range,
  void Function(Map<String, Object?>) add,
) {
  var bare = type.startsWith('readonly ') ? type.substring(9) : type;
  if (bare.endsWith('?')) bare = bare.substring(0, bare.length - 1);
  final declaration = known ?? compilation.semantics.classes[_head(bare)];
  if (declaration != null) {
    for (final current in _lineage(compilation, declaration)) {
      for (final field in current.fields) {
        if (field.isStatic != onType || !_name(field.name)) continue;
        final shown =
            compilation.semantics.declarations[field]?.type ?? field.type;
        add(_plain(field.name, 5, field.mutable ? 'var $shown' : shown, range,
            sort: '0'));
      }
      for (final property in current.properties) {
        if (onType || !_name(property.name)) continue;
        final reads = property.getter != null || property.getterBody != null;
        final writes = property.setter != null || property.setterBody != null;
        final kind = reads && writes
            ? 'property'
            : reads
                ? 'get'
                : 'set';
        add(_plain(property.name, 10, '$kind ${property.type}', range,
            sort: '0'));
      }
      for (final method in current.methods) {
        if (method.isStatic != onType ||
            method.isOperator ||
            !_name(method.name)) {
          continue;
        }
        add(_plain(method.name, 2, _signature(compilation, method), range,
            sort: '1'));
      }
      if (onType) {
        for (final item in current.cases) {
          add(_plain(item.name, 4, 'case ${current.name}', range, sort: '0'));
        }
      }
    }
  }
  for (final extension in compilation.semantics.extensions) {
    if (extension.target != bare && extension.target != _head(bare)) continue;
    for (final method in extension.methods) {
      if (!_name(method.name)) continue;
      add(_plain(method.name, 2, _signature(compilation, method), range,
          sort: '1'));
    }
  }
  _builtinMembers(bare, onType, range, add);
}

void _builtinMembers(
  String type,
  bool onType,
  Map<String, Object> range,
  void Function(Map<String, Object?>) add,
) {
  if (onType) return;
  final family = _family(type);
  if (family == null) return;
  final vars = family.$2;
  final families = family.$1 == 'List' || family.$1 == 'Set'
      ? [family.$1, 'Iterable']
      : [family.$1];
  for (final name in families) {
    for (final entry in _getters[name]!.entries) {
      add(_plain(entry.key, 10, _subst(entry.value, vars), range, sort: '0'));
    }
    for (final entry in _methods[name]!.entries) {
      final parameters = [
        for (final parameter in entry.value.$1)
          '${parameter.$1}: ${_subst(parameter.$2, vars)}'
      ].join(', ');
      add(_plain(entry.key, 2,
          '($parameters) -> ${_subst(entry.value.$2, vars)}', range,
          sort: '1'));
    }
  }
}

(String, Map<String, String>)? _family(String type) {
  if (type == 'String') return ('String', const {});
  if (type.startsWith('List<') && type.endsWith('>')) {
    return ('List', {'T': type.substring(5, type.length - 1)});
  }
  if (type.startsWith('Set<') && type.endsWith('>')) {
    return ('Set', {'T': type.substring(4, type.length - 1)});
  }
  if (type.startsWith('Iterable<') && type.endsWith('>')) {
    return ('Iterable', {'T': type.substring(9, type.length - 1)});
  }
  if (type.startsWith('Map<') && type.endsWith('>')) {
    final parts = _split(type.substring(4, type.length - 1));
    if (parts.length != 2) return null;
    return ('Map', {'K': parts[0], 'V': parts[1]});
  }
  return null;
}

const _getters = {
  'List': {
    'length': 'int',
    'isEmpty': 'bool',
    'isNotEmpty': 'bool',
    'first': 'T',
    'last': 'T',
    'reversed': 'Iterable<T>',
  },
  'Set': {
    'length': 'int',
    'isEmpty': 'bool',
    'isNotEmpty': 'bool',
    'first': 'T',
    'last': 'T',
  },
  'Iterable': {
    'isEmpty': 'bool',
    'isNotEmpty': 'bool',
    'first': 'T',
    'last': 'T',
  },
  'Map': {
    'length': 'int',
    'isEmpty': 'bool',
    'isNotEmpty': 'bool',
    'keys': 'Iterable<K>',
    'values': 'Iterable<V>',
  },
  'String': {
    'length': 'int',
    'isEmpty': 'bool',
    'isNotEmpty': 'bool',
  },
};

const _methods = {
  'List': {
    'add': ([('value', 'T')], 'void'),
    'addAll': ([('values', 'Iterable<T>')], 'void'),
    'insert': ([('index', 'int'), ('value', 'T')], 'void'),
    'removeAt': ([('index', 'int')], 'T'),
    'removeLast': (<(String, String)>[], 'T'),
    'remove': ([('value', 'Object')], 'bool'),
    'clear': (<(String, String)>[], 'void'),
    'sort': (<(String, String)>[], 'void'),
    'sublist': ([('start', 'int')], 'List<T>'),
    'indexOf': ([('value', 'Object')], 'int'),
  },
  'Set': {
    'add': ([('value', 'T')], 'bool'),
    'addAll': ([('values', 'Iterable<T>')], 'void'),
    'remove': ([('value', 'Object')], 'bool'),
    'clear': (<(String, String)>[], 'void'),
  },
  'Iterable': {
    'contains': ([('value', 'Object')], 'bool'),
    'elementAt': ([('index', 'int')], 'T'),
    'join': (<(String, String)>[], 'String'),
    'toList': (<(String, String)>[], 'List<T>'),
    'where': ([('test', '(T) -> bool')], 'Iterable<T>'),
    'any': ([('test', '(T) -> bool')], 'bool'),
    'every': ([('test', '(T) -> bool')], 'bool'),
    'forEach': ([('action', '(T) -> void')], 'void'),
  },
  'Map': {
    'containsKey': ([('key', 'Object')], 'bool'),
    'remove': ([('key', 'Object')], 'V?'),
    'clear': (<(String, String)>[], 'void'),
    'addAll': ([('other', 'Map<K, V>')], 'void'),
    'putIfAbsent': ([('key', 'K'), ('ifAbsent', '() -> V')], 'V'),
    'forEach': ([('action', '(K, V) -> void')], 'void'),
  },
  'String': {
    'contains': ([('other', 'String')], 'bool'),
    'startsWith': ([('other', 'String')], 'bool'),
    'endsWith': ([('other', 'String')], 'bool'),
    'substring': ([('start', 'int')], 'String'),
    'toUpperCase': (<(String, String)>[], 'String'),
    'toLowerCase': (<(String, String)>[], 'String'),
    'trim': (<(String, String)>[], 'String'),
    'split': ([('pattern', 'String')], 'List<String>'),
    'indexOf': ([('pattern', 'String')], 'int'),
    'replaceAll': ([('from', 'String'), ('to', 'String')], 'String'),
  },
};

class _Call {
  const _Call(this.paren, this.callee, this.member);
  final int paren;
  final String callee;
  final bool member;
}

_Call? _argument(String source, int wordStart) {
  var index = wordStart;
  while (index > 0 && _space(source.codeUnitAt(index - 1))) {
    index--;
  }
  if (index == 0) return null;
  final mark = source.codeUnitAt(index - 1);
  if (mark != 40 && mark != 44) return null;
  var depth = 0;
  var paren = -1;
  for (var cursor = index - 1; cursor >= 0; cursor--) {
    final unit = source.codeUnitAt(cursor);
    if (unit == 41 || unit == 93) depth++;
    if (unit == 40 || unit == 91) {
      if (depth == 0 && unit == 40) {
        paren = cursor;
        break;
      }
      if (depth == 0) return null;
      depth--;
    }
  }
  if (paren < 0) return null;
  var nameEnd = paren;
  while (nameEnd > 0 && _space(source.codeUnitAt(nameEnd - 1))) {
    nameEnd--;
  }
  var nameStart = nameEnd;
  while (nameStart > 0 && _ident(source.codeUnitAt(nameStart - 1))) {
    nameStart--;
  }
  if (nameStart == nameEnd) return null;
  final callee = source.substring(nameStart, nameEnd);
  if (_digit(callee.codeUnitAt(0))) return null;
  final member = nameStart > 0 && source.codeUnitAt(nameStart - 1) == 46;
  return _Call(paren, callee, member);
}

void _namedArguments(
  Compilation compilation,
  String source,
  _Here scope,
  _Call call,
  Map<String, Object> range,
  void Function(Map<String, Object?>) add,
) {
  final used = _namesBefore(source, call.paren, _wordStart(range, source));
  final Iterable<_Param> parameters;
  if (call.member) {
    final receiver =
        _receiverName(source, _calleeStart(source, call.paren) - 1);
    final symbol = receiver == null ? null : scope.names[receiver];
    if (symbol == null) return;
    parameters = _parametersOf(compilation, symbol, call.callee);
  } else {
    final symbol = scope.names[call.callee];
    if (symbol == null) return;
    if (symbol.classDeclaration != null && symbol.classCase == null) {
      parameters = _constructorParameters(symbol.classDeclaration!);
    } else {
      parameters = [
        for (final function in symbol.overloads)
          for (final parameter in function.parameters)
            _Param(parameter.name, parameter.type)
      ];
    }
  }
  final seen = <String>{};
  for (final parameter in parameters) {
    if (!_name(parameter.name) || !seen.add(parameter.name)) continue;
    if (used.contains(parameter.name)) continue;
    add(_plain(parameter.name, 5, parameter.type, range,
        insert: '${parameter.name}: ', sort: '0', commit: false));
  }
}

int _calleeStart(String source, int paren) {
  var nameEnd = paren;
  while (nameEnd > 0 && _space(source.codeUnitAt(nameEnd - 1))) {
    nameEnd--;
  }
  var nameStart = nameEnd;
  while (nameStart > 0 && _ident(source.codeUnitAt(nameStart - 1))) {
    nameStart--;
  }
  return nameStart;
}

int _wordStart(Map<String, Object> range, String source) {
  final text = range['range'];
  if (text is! Map) return 0;
  final start = text['start'];
  if (start is! Map) return 0;
  final line = (start['line'] as num?)?.toInt() ?? 0;
  final character = (start['character'] as num?)?.toInt() ?? 0;
  return _stringIndexAt(source, line, character);
}

Set<String> _namesBefore(String source, int paren, int wordStart) {
  if (wordStart < paren || wordStart > source.length) return const {};
  final slice = source.substring(paren, wordStart);
  final names = <String>{};
  var depth = 0;
  var index = 0;
  while (index < slice.length) {
    final unit = slice.codeUnitAt(index);
    if (unit == 40 || unit == 91) depth++;
    if ((unit == 41 || unit == 93) && depth > 0) depth--;
    if (depth == 1) {
      final match =
          RegExp(r'([A-Za-z_$][A-Za-z0-9_$]*)\s*:').matchAsPrefix(slice, index);
      if (match != null) {
        names.add(match.group(1)!);
        index = match.end;
        continue;
      }
    }
    index++;
  }
  return names;
}

class _Param {
  const _Param(this.name, this.type);
  final String name, type;
}

List<_Param> _constructorParameters(ClassDeclaration type) {
  if (type.constructors.isNotEmpty) {
    return [
      for (final constructor in type.constructors)
        for (final parameter in constructor.parameters)
          if (parameter.initializing.isEmpty)
            _Param(parameter.name, parameter.type)
          else
            _Param(parameter.name, _fieldType(type, parameter.name))
    ];
  }
  return [
    for (final field in type.fields)
      if (!field.isStatic) _Param(field.name, field.type)
  ];
}

String _fieldType(ClassDeclaration type, String name) {
  for (final field in type.fields) {
    if (field.name == name) return field.type;
  }
  return 'Object';
}

Iterable<_Param> _parametersOf(
    Compilation compilation, Symbol symbol, String member) sync* {
  final type = symbol.classDeclaration?.name ?? symbol.type;
  final declaration =
      symbol.classDeclaration ?? compilation.semantics.classes[_head(type)];
  if (declaration == null) return;
  for (final current in _lineage(compilation, declaration)) {
    for (final method in current.methods) {
      if (method.name != member) continue;
      for (final parameter in method.parameters) {
        yield _Param(parameter.name, parameter.type);
      }
    }
  }
}

String _signature(Compilation compilation, FunctionDeclaration function) {
  final parameters = function.parameters
      .map((parameter) =>
          '${parameter.name}: ${parameter.variadic ? 'List<${parameter.type}>' : parameter.type}')
      .join(', ');
  final returned = compilation.semantics.declarations[function]?.type ??
      function.returnType ??
      'void';
  return '($parameters) -> $returned';
}

List<Map<String, Object?>> _symbolItems(
    Compilation? compilation, Symbol symbol, Map<String, Object> range) {
  if (symbol.namespace != null) {
    return [_plain(symbol.name, 9, 'prefix', range, sort: '1')];
  }
  if (symbol.classCase != null) {
    return [
      _plain(symbol.name, 4,
          'case ${symbol.classDeclaration?.name ?? symbol.type}', range,
          sort: '1')
    ];
  }
  if (symbol.classDeclaration != null && symbol.overloads.isEmpty) {
    return [_plain(symbol.name, 7, 'class ${symbol.name}', range, sort: '1')];
  }
  if (symbol.overloads.isNotEmpty && compilation != null) {
    final kind = symbol.field ? 2 : 3;
    return [
      for (final function in symbol.overloads)
        _plain(symbol.name, kind, _signature(compilation, function), range,
            sort: '1')
    ];
  }
  final type = symbol.readonly ? 'readonly ${symbol.type}' : symbol.type;
  final detail = symbol.mutable ? 'var $type' : type;
  final kind = symbol.constant
      ? 21
      : symbol.field
          ? 10
          : 6;
  return [_plain(symbol.name, kind, detail, range, sort: '0')];
}

Map<String, Object?> _plain(
  String label,
  int kind,
  String detail,
  Map<String, Object> range, {
  String? insert,
  String sort = '1',
  bool commit = true,
}) {
  final text = insert ?? label;
  return {
    'label': label,
    'kind': kind,
    'detail': detail,
    'filterText': label,
    'sortText': '$sort$label',
    'textEdit': {...range, 'newText': text},
    if (commit) 'commitCharacters': ['.', '('],
  };
}

Map<String, Object> _range(String source, int start, int end) => {
      'range': {
        'start': _position(source, start),
        'end': _position(source, end),
      }
    };

Map<String, int> _position(String source, int index) {
  var line = 0;
  var character = 0;
  for (var i = 0; i < index && i < source.length; i++) {
    if (source.codeUnitAt(i) == 10) {
      line++;
      character = 0;
    } else if (source.codeUnitAt(i) != 13) {
      character++;
    }
  }
  return {'line': line, 'character': character};
}

bool _statementStart(String source, int wordStart) {
  var index = wordStart;
  while (index > 0 && source.codeUnitAt(index - 1) != 10) {
    if (!_space(source.codeUnitAt(index - 1))) return false;
    index--;
  }
  return true;
}

String _indent(String source, int index) {
  var start = index;
  while (start > 0 && source.codeUnitAt(start - 1) != 10) {
    start--;
  }
  var end = start;
  while (end < source.length && source.codeUnitAt(end) == 32) {
    end++;
  }
  return source.substring(start, end);
}

bool _name(String value) =>
    RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(value);

String _head(String type) {
  final index = type.indexOf('<');
  return index < 0 ? type : type.substring(0, index);
}

String _subst(String pattern, Map<String, String> vars) {
  if (vars.isEmpty) return pattern;
  return pattern.replaceAllMapped(RegExp(r'[A-Za-z_][A-Za-z0-9_]*'), (match) {
    return vars[match.group(0)!] ?? match.group(0)!;
  });
}

List<String> _split(String inner) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < inner.length; i++) {
    final unit = inner.codeUnitAt(i);
    if (unit == 60) depth++;
    if (unit == 62 && depth > 0) depth--;
    if (unit == 44 && depth == 0) {
      parts.add(inner.substring(start, i).trim());
      start = i + 1;
    }
  }
  parts.add(inner.substring(start).trim());
  return parts;
}

int _lineIndent(String source, int index) {
  var start = index;
  while (start > 0 && source.codeUnitAt(start - 1) != 10) {
    start--;
  }
  var end = start;
  while (end < source.length && source.codeUnitAt(end) == 32) {
    end++;
  }
  if (end >= source.length ||
      source.codeUnitAt(end) == 10 ||
      source.codeUnitAt(end) == 13) {
    return -1;
  }
  return end - start;
}

int _lineOfByte(String source, int bytes) => '\n'
    .allMatches(source.substring(0, _stringIndexForByte(source, bytes)))
    .length;

bool _inCode(String source, int index) {
  var cursor = 0;
  var raw = false;
  var quote = 0;
  var triple = false;
  var line = false;
  var block = false;
  final interpolations = <int>[];
  while (cursor < index && cursor < source.length) {
    final unit = source.codeUnitAt(cursor);
    if (line) {
      if (unit == 10) line = false;
      cursor++;
      continue;
    }
    if (block) {
      if (unit == 42 &&
          cursor + 1 < source.length &&
          source.codeUnitAt(cursor + 1) == 47) {
        block = false;
        cursor += 2;
        continue;
      }
      cursor++;
      continue;
    }
    if (quote != 0 && interpolations.isEmpty) {
      if (!raw && unit == 92) {
        cursor += cursor + 1 < source.length ? 2 : 1;
        continue;
      }
      if (!raw && unit == 123) {
        interpolations.add(1);
        cursor++;
        continue;
      }
      if (triple &&
          cursor + 2 < source.length &&
          source.codeUnitAt(cursor + 1) == quote &&
          source.codeUnitAt(cursor + 2) == quote) {
        quote = 0;
        cursor += 3;
        continue;
      }
      if (!triple && unit == quote) quote = 0;
      cursor++;
      continue;
    }
    if (interpolations.isNotEmpty) {
      if (unit == 123) interpolations.last++;
      if (unit == 125) {
        interpolations.last--;
        if (interpolations.last == 0) interpolations.removeLast();
      }
    }
    if (quote == 0 && unit == 35) {
      line = true;
      cursor++;
      continue;
    }
    if (quote == 0 &&
        unit == 47 &&
        cursor + 1 < source.length &&
        source.codeUnitAt(cursor + 1) == 47) {
      line = true;
      cursor += 2;
      continue;
    }
    if (quote == 0 &&
        unit == 47 &&
        cursor + 1 < source.length &&
        source.codeUnitAt(cursor + 1) == 42) {
      block = true;
      cursor += 2;
      continue;
    }
    if (quote == 0 && (unit == 34 || unit == 39)) {
      raw = cursor > 0 &&
          (source.codeUnitAt(cursor - 1) == 114 ||
              source.codeUnitAt(cursor - 1) == 82);
      triple = cursor + 2 < source.length &&
          source.codeUnitAt(cursor + 1) == unit &&
          source.codeUnitAt(cursor + 2) == unit;
      quote = unit;
      cursor += triple ? 3 : 1;
      continue;
    }
    cursor++;
  }
  return quote == 0 && !line && !block || interpolations.isNotEmpty;
}

int _stringIndexAt(String source, int line, int character) {
  var index = 0;
  var current = 0;
  while (index < source.length && current < line) {
    final unit = source.codeUnitAt(index);
    if (unit == 13) {
      index++;
      if (index < source.length && source.codeUnitAt(index) == 10) index++;
      current++;
    } else if (unit == 10) {
      index++;
      current++;
    } else {
      index++;
    }
  }
  var column = 0;
  while (index < source.length && column < character) {
    final unit = source.codeUnitAt(index);
    if (unit == 10 || unit == 13) break;
    index++;
    column++;
  }
  return index;
}

int _bytes(String source, int index) =>
    utf8.encode(source.substring(0, index)).length;

int _stringIndexForByte(String source, int byteOffset) {
  var bytes = 0;
  var index = 0;
  while (index < source.length && bytes < byteOffset) {
    final unit = source.codeUnitAt(index);
    if (unit < 0x80) {
      bytes += 1;
    } else if (unit < 0x800) {
      bytes += 2;
    } else if (unit >= 0xD800 && unit <= 0xDBFF) {
      bytes += 4;
      index++;
    } else {
      bytes += 3;
    }
    index++;
  }
  return index;
}
