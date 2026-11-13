import 'dart:convert';

import 'ast.dart';
import 'compiler.dart';
import 'semantics.dart';
import 'source.dart';
import 'walk.dart';

/// The declaration span of the name under [line] and [column].
///
/// The span belongs to the `.quds` file that declares the name. [sourceOf]
/// supplies that file's text so the span can shrink to the name itself.
/// A missing source keeps the whole declaration span.
SourceSpan? definitionAt(Compilation compilation, int line, int column,
    {String? Function(String file)? sourceOf}) {
  final node = _definitionNode(compilation, line, column);
  if (node == null) return null;
  final name = _declaredName(node);
  final text = name == null ? null : sourceOf?.call(node.span.file);
  if (name == null || text == null) return node.span;
  return _nameSpan(text, node.span, name) ?? node.span;
}

/// Replaces the name under [line] and [column], and every other use of that
/// symbol, with [next]. Declaration names are replaced inside their spans.
/// Uses are replaced only on the identifier span.
String renameAt(
    Compilation compilation, String source, int line, int column, String next) {
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(next)) {
    throw ArgumentError('A new name must be an identifier');
  }
  final hit = _identifierAt(compilation, line, column);
  if (hit == null) return source;
  final symbol = compilation.semantics.references[hit];
  if (symbol == null) return source;
  final spans = <SourceSpan>[];
  walkAst(compilation.program, (node) {
    if (node is Identifier &&
        identical(compilation.semantics.references[node], symbol)) {
      spans.add(node.span);
    }
  });
  for (final entry in compilation.semantics.declarations.entries) {
    if (!identical(entry.value, symbol)) continue;
    final name = _declaredName(entry.key);
    if (name == null) continue;
    final local = _nameSpan(source, entry.key.span, name);
    if (local != null) spans.add(local);
  }
  spans.sort((a, b) => b.offset.compareTo(a.offset));
  final seen = <int>{};
  var result = source;
  for (final span in spans) {
    if (!seen.add(span.offset)) continue;
    final start = _stringIndex(result, span.offset);
    final end = _stringIndex(result, span.offset + span.length);
    result = result.replaceRange(start, end, next);
  }
  return result;
}

/// The smallest statement that starts on [line].
SourceSpan? breakpointOnLine(Compilation compilation, int line) {
  Statement? hit;
  var best = 1 << 30;
  walkAst(compilation.program, (node) {
    if (node is! Statement || node.span.line != line) return;
    if (node.span.length < best) {
      best = node.span.length;
      hit = node;
    }
  });
  return hit?.span;
}

/// The type or signature under [line] and [column], both one-based.
///
/// A name is shown with its type. A function shows its parameters and result.
/// Any other expression shows the type alone.
String? hoverAt(Compilation compilation, String source, int line, int column) {
  final offset = _byteOffsetAt(source, line, column);
  Node? hit;
  var best = 1 << 30;
  walkAst(compilation.program, (node) {
    final span = node.span;
    if (offset < span.offset || offset >= span.offset + span.length) return;
    if (span.length <= best) {
      best = span.length;
      hit = node;
    }
  });
  final node = hit;
  if (node == null) return null;
  return _hoverText(compilation, source, node, offset);
}

/// Legend shared with the editor. A property is not a function.
const semanticTokenTypes = [
  'function',
  'method',
  'property',
  'variable',
  'parameter',
  'class',
];

/// `declaration` then `readonly`. A writable binding omits `readonly`.
const semanticTokenModifiers = ['declaration', 'readonly'];

/// Encoded `textDocument/semanticTokens/full` data for [source].
List<int> semanticTokenData(Compilation compilation, String source) {
  final tokens = <_Token>[];
  final methods = <FunctionDeclaration>{};
  walkAst(compilation.program, (node) {
    if (node is ClassDeclaration) methods.addAll(node.methods);
  });
  final parameters = <Symbol>{
    for (final entry in compilation.semantics.declarations.entries)
      if (entry.key is Parameter) entry.value,
  };
  walkAst(compilation.program, (node) {
    switch (node) {
      case FunctionDeclaration():
        final token = _nameToken(
          source,
          node.span,
          node.name,
          methods.contains(node) ? _method : _function,
          _bits(declaration: true),
        );
        if (token != null) tokens.add(token);
      case PropertyDeclaration():
        final writes = node.setter != null || node.setterBody != null;
        final token = _nameToken(
          source,
          node.span,
          node.name,
          _property,
          _bits(declaration: true, readonly: !writes),
        );
        if (token != null) tokens.add(token);
      case FieldDeclaration():
        final token = _nameToken(
          source,
          node.span,
          node.name,
          _property,
          _bits(declaration: true, readonly: !node.mutable),
        );
        if (token != null) tokens.add(token);
      case ClassDeclaration():
        final token = _nameToken(
          source,
          node.span,
          node.name,
          _classType,
          _bits(declaration: true),
        );
        if (token != null) tokens.add(token);
      case Parameter():
        final token = _nameToken(
          source,
          node.span,
          node.name,
          _parameter,
          _bits(declaration: true, readonly: !node.mutable),
        );
        if (token != null) tokens.add(token);
      case Binding():
        final symbol = compilation.semantics.declarations[node] ??
            compilation.semantics.references[node];
        final token = _nameToken(
          source,
          node.span,
          node.name,
          _variable,
          _bits(
            declaration: compilation.semantics.declarations.containsKey(node),
            readonly: symbol?.mutable != true,
          ),
        );
        if (token != null) tokens.add(token);
      case ForStatement():
        final symbol = compilation.semantics.declarations[node];
        final token = _nameToken(
          source,
          node.span,
          node.name,
          _variable,
          _bits(declaration: true, readonly: symbol?.mutable != true),
        );
        if (token != null) tokens.add(token);
      case Identifier():
        final kind = _identifierKind(compilation, node, methods, parameters);
        if (kind == null) break;
        final index = _stringIndex(source, node.span.offset);
        final token =
            _tokenAt(source, index, node.name.length, kind.$1, kind.$2);
        if (token != null) tokens.add(token);
      case MemberAccess():
        final kind = _memberKind(compilation.semantics, node);
        final token = _memberNameToken(source, node, kind.$1, kind.$2);
        if (token != null) tokens.add(token);
      default:
        break;
    }
  });
  tokens.sort((a, b) {
    final byLine = a.line.compareTo(b.line);
    if (byLine != 0) return byLine;
    return a.column.compareTo(b.column);
  });
  final data = <int>[];
  var line = 0;
  var column = 0;
  var previous = -1;
  for (final token in tokens) {
    final start = token.line * 100000 + token.column;
    if (start == previous || token.length <= 0) continue;
    previous = start;
    final deltaLine = token.line - line;
    final deltaColumn = deltaLine == 0 ? token.column - column : token.column;
    data
      ..add(deltaLine)
      ..add(deltaColumn)
      ..add(token.length)
      ..add(token.type)
      ..add(token.modifiers);
    line = token.line;
    column = token.column;
  }
  return data;
}

const _function = 0;
const _method = 1;
const _property = 2;
const _variable = 3;
const _parameter = 4;
const _classType = 5;

int _bits({bool declaration = false, bool readonly = false}) =>
    (declaration ? 1 : 0) | (readonly ? 2 : 0);

/// Name spans of every `main` function, so an editor can offer actions there.
List<SourceSpan> mainSpans(Compilation compilation, String source) {
  final spans = <SourceSpan>[];
  walkAst(compilation.program, (node) {
    if (node is! FunctionDeclaration || node.name != 'main') return;
    final name = _nameSpan(source, node.span, node.name);
    if (name != null) spans.add(name);
  });
  return spans;
}

/// The statement span that contains [line] and [column].
SourceSpan? breakpointAt(Compilation compilation, int line, int column) {
  Statement? hit;
  var best = 1 << 30;
  walkAst(compilation.program, (node) {
    if (node is! Statement) return;
    if (!_covers(node.span, line, column)) return;
    if (node.span.length < best) {
      best = node.span.length;
      hit = node;
    }
  });
  return hit?.span;
}

Node? _definitionNode(Compilation compilation, int line, int column) {
  final node = _smallestNode(compilation, line, column);
  if (node == null) return null;
  return _declaredNode(compilation, node, line, column);
}

Node? _smallestNode(Compilation compilation, int line, int column) {
  Node? hit;
  var best = 1 << 30;
  walkAst(compilation.program, (node) {
    if (!_covers(node.span, line, column)) return;
    if (node.span.length <= best) {
      best = node.span.length;
      hit = node;
    }
  });
  return hit;
}

Node? _declaredNode(Compilation compilation, Node node, int line, int column) {
  if (node is MemberAccess) {
    if (!_onMemberName(node, line, column)) {
      return _declaredNode(compilation, node.object, line, column);
    }
    final linked =
        _nodeForSymbol(compilation, compilation.semantics.references[node]);
    if (linked != null) return linked;
    return switch (_findMember(compilation.semantics, node)) {
      _PropertyFound(:final declaration) => declaration,
      _FieldFound(:final declaration) => declaration,
      _MethodFound(:final declaration) => declaration,
      _ => null,
    };
  }
  if (node is Identifier) {
    return _nodeForSymbol(compilation, compilation.semantics.references[node]);
  }
  if (node is CallExpression) {
    return _declaredNode(compilation, node.callee, line, column);
  }
  if (_declaredName(node) != null) return node;
  return null;
}

Node? _nodeForSymbol(Compilation compilation, Symbol? symbol) {
  if (symbol == null) return null;
  for (final entry in compilation.semantics.declarations.entries) {
    if (identical(entry.value, symbol)) return entry.key;
  }
  final function = symbol.function;
  if (function != null) return function;
  if (symbol.overloads.length == 1) return symbol.overloads.single;
  return symbol.classDeclaration;
}

bool _onMemberName(MemberAccess node, int line, int column) {
  if (node.span.line != line) return false;
  final start = node.span.column + node.span.length - node.name.length;
  return column >= start && column < start + node.name.length;
}

Identifier? _identifierAt(Compilation compilation, int line, int column) {
  Identifier? hit;
  var best = 1 << 30;
  walkAst(compilation.program, (node) {
    if (node is! Identifier) return;
    if (!_covers(node.span, line, column)) return;
    if (node.span.length < best) {
      best = node.span.length;
      hit = node;
    }
  });
  return hit;
}

bool _covers(SourceSpan span, int line, int column) {
  if (span.line != line) return false;
  return column >= span.column && column < span.column + span.length;
}

String? _declaredName(Node node) => switch (node) {
      Binding(:final name) => name,
      FunctionDeclaration(:final name) => name,
      Parameter(:final name) => name,
      ForStatement(:final name) => name,
      ClassDeclaration(:final name) => name,
      FieldDeclaration(:final name) => name,
      PropertyDeclaration(:final name) => name,
      _ => null,
    };

SourceSpan? _nameSpan(String source, SourceSpan span, String name) {
  final start = _stringIndex(source, span.offset);
  final end = _stringIndex(source, span.offset + span.length);
  if (start < 0 || end > source.length || start > end) return null;
  final match = RegExp('\\b${RegExp.escape(name)}\\b')
      .firstMatch(source.substring(start, end));
  if (match == null) return null;
  return SourceSpan(span.line, span.column + match.start, name.length,
      file: span.file, offset: span.offset + match.start);
}

String? _hoverText(
    Compilation compilation, String source, Node node, int offset) {
  final model = compilation.semantics;
  if (node is Identifier) return _identifierHover(model, node);
  if (node is MemberAccess) return _memberHover(model, node);
  if (node is Expression) return model.types[node];
  if (!_onName(source, node, offset)) return null;
  return switch (node) {
    FunctionDeclaration() => _signature(node, model),
    Parameter() => _valueHover(
        node.name,
        node.variadic ? 'List<${node.type}>' : node.type,
        mutable: node.mutable,
      ),
    Binding() => _bindingHover(model, node),
    ForStatement() => _valueHover(
        node.name,
        model.declarations[node]?.type,
        mutable: model.declarations[node]?.mutable ?? false,
      ),
    FieldDeclaration() => _valueHover(
        node.name,
        node.type == '<infer>' ? model.declarations[node]?.type : node.type,
        mutable: node.mutable,
      ),
    PropertyDeclaration() => _propertyHover(node),
    ClassDeclaration() => 'class ${node.name}',
    _ => null,
  };
}

String? _identifierHover(SemanticModel model, Identifier node) {
  final symbol = model.references[node];
  final function = symbol?.function;
  if (function != null) return _signature(function, model);
  if (symbol?.classDeclaration != null) return 'class ${node.name}';
  final type = model.types[node] ?? symbol?.type;
  return _valueHover(node.name, type, mutable: symbol?.mutable ?? false);
}

String? _memberHover(SemanticModel model, MemberAccess node) {
  final found = _findMember(model, node);
  if (found is _PropertyFound) return _propertyHover(found.declaration);
  if (found is _FieldFound) {
    return _valueHover(
      found.declaration.name,
      model.types[node] ?? found.declaration.type,
      mutable: found.declaration.mutable,
    );
  }
  if (found is _MethodFound) return _signature(found.declaration, model);
  final type = model.types[node];
  if (type == null) return null;
  if (type.startsWith('(') && type.contains('->')) return '${node.name}: $type';
  return 'get ${node.name}: $type';
}

String _propertyHover(PropertyDeclaration node) {
  final reads = node.getter != null || node.getterBody != null;
  final writes = node.setter != null || node.setterBody != null;
  final kind = reads && writes
      ? 'property'
      : reads
          ? 'get'
          : 'set';
  return '$kind ${node.name}: ${node.type}';
}

String _signature(FunctionDeclaration function, SemanticModel model) {
  final parameters = function.parameters.map((parameter) {
    final stored =
        parameter.variadic ? 'List<${parameter.type}>' : parameter.type;
    final prefix = parameter.mutable ? 'var ' : '';
    return '$prefix${parameter.name}: $stored';
  }).join(', ');
  final returns =
      model.declarations[function]?.type ?? function.returnType ?? 'void';
  return '${function.name}($parameters) -> $returns';
}

String? _bindingHover(SemanticModel model, Binding node) {
  final symbol = model.declarations[node] ?? model.references[node];
  final declared = symbol?.type;
  final type = declared != null && declared != '<infer>'
      ? declared
      : (node.type ?? model.types[node.value]);
  return _valueHover(node.name, type, mutable: symbol?.mutable ?? false);
}

String? _valueHover(String name, String? type, {required bool mutable}) {
  if (type == null || type == '<infer>') return null;
  return '${mutable ? 'var ' : ''}$name: $type';
}

(int, int)? _identifierKind(
  Compilation compilation,
  Identifier node,
  Set<FunctionDeclaration> methods,
  Set<Symbol> parameters,
) {
  final symbol = compilation.semantics.references[node];
  if (symbol == null) return null;
  final function = symbol.function;
  if (function != null) {
    return (methods.contains(function) ? _method : _function, 0);
  }
  if (symbol.classDeclaration != null) return (_classType, 0);
  if (symbol.field) {
    return (_property, _bits(readonly: !symbol.mutable));
  }
  if (parameters.contains(symbol)) {
    return (_parameter, _bits(readonly: !symbol.mutable));
  }
  if (symbol.type.startsWith('(') && symbol.type.contains('->')) {
    return (_function, 0);
  }
  return (_variable, _bits(readonly: !symbol.mutable));
}

(int, int) _memberKind(SemanticModel model, MemberAccess node) {
  final found = _findMember(model, node);
  switch (found) {
    case _PropertyFound(:final declaration):
      return (
        _property,
        _bits(
          readonly:
              declaration.setter == null && declaration.setterBody == null,
        ),
      );
    case _FieldFound(:final declaration):
      return (_property, _bits(readonly: !declaration.mutable));
    case _MethodFound():
      return (_method, 0);
    case null:
      final type = model.types[node];
      if (type != null && type.startsWith('(') && type.contains('->')) {
        return (_function, 0);
      }
      return (_property, _bits(readonly: true));
  }
}

_Found? _findMember(SemanticModel model, MemberAccess node) {
  var typeName = _classHead(model.types[node.object] ?? '');
  final seen = <String>{};
  while (typeName.isNotEmpty && seen.add(typeName)) {
    final declaration = model.classes[typeName];
    if (declaration == null) break;
    for (final property in declaration.properties) {
      if (property.name == node.name) return _PropertyFound(property);
    }
    for (final field in declaration.fields) {
      if (field.name == node.name) return _FieldFound(field);
    }
    for (final method in declaration.methods) {
      if (method.name == node.name) return _MethodFound(method);
    }
    typeName = declaration.superclass ?? '';
  }
  return null;
}

String _classHead(String type) {
  var current = type;
  if (current.startsWith('readonly ')) current = current.substring(9);
  if (current.endsWith('?')) {
    current = current.substring(0, current.length - 1);
  }
  final open = current.indexOf('<');
  if (open > 0) current = current.substring(0, open);
  return current;
}

class _Token {
  const _Token(this.line, this.column, this.length, this.type, this.modifiers);
  final int line, column, length, type, modifiers;
}

_Token? _nameToken(
    String source, SourceSpan span, String name, int type, int modifiers) {
  final start = _stringIndex(source, span.offset);
  final end = _stringIndex(source, span.offset + span.length);
  if (start < 0 || end > source.length || start > end) return null;
  final match = RegExp('\\b${RegExp.escape(name)}\\b')
      .firstMatch(source.substring(start, end));
  if (match == null) return null;
  return _tokenAt(source, start + match.start, name.length, type, modifiers);
}

_Token? _memberNameToken(
    String source, MemberAccess node, int type, int modifiers) {
  final start = _stringIndex(source, node.span.offset);
  final end = _stringIndex(source, node.span.offset + node.span.length);
  if (start < 0 || end > source.length || start > end) return null;
  final text = source.substring(start, end);
  final dot = node.nullAware ? '?.${node.name}' : '.${node.name}';
  final at = text.lastIndexOf(dot);
  if (at < 0) return null;
  return _tokenAt(source, start + at + dot.length - node.name.length,
      node.name.length, type, modifiers);
}

_Token? _tokenAt(
    String source, int stringIndex, int length, int type, int modifiers) {
  if (stringIndex < 0 || length <= 0 || stringIndex > source.length) {
    return null;
  }
  var line = 0;
  var column = 0;
  var index = 0;
  while (index < stringIndex) {
    final unit = source.codeUnitAt(index);
    if (unit == 13) {
      index++;
      if (index < source.length && source.codeUnitAt(index) == 10) index++;
      line++;
      column = 0;
    } else if (unit == 10) {
      index++;
      line++;
      column = 0;
    } else {
      index++;
      column++;
    }
  }
  return _Token(line, column, length, type, modifiers);
}

sealed class _Found {}

class _PropertyFound extends _Found {
  _PropertyFound(this.declaration);
  final PropertyDeclaration declaration;
}

class _FieldFound extends _Found {
  _FieldFound(this.declaration);
  final FieldDeclaration declaration;
}

class _MethodFound extends _Found {
  _MethodFound(this.declaration);
  final FunctionDeclaration declaration;
}

bool _onName(String source, Node node, int offset) {
  final name = _declaredName(node);
  if (name == null) return false;
  final local = _nameSpan(source, node.span, name);
  if (local == null) return false;
  final bytes = utf8.encode(name).length;
  return offset >= local.offset && offset < local.offset + bytes;
}

/// One-based [line] and UTF-16 [column], matching [SourceSpan].
int _byteOffsetAt(String source, int line, int column) {
  var index = 0;
  var currentLine = 1;
  while (index < source.length && currentLine < line) {
    final unit = source.codeUnitAt(index);
    if (unit == 13) {
      index++;
      if (index < source.length && source.codeUnitAt(index) == 10) index++;
      currentLine++;
    } else if (unit == 10) {
      index++;
      currentLine++;
    } else {
      index++;
    }
  }
  var currentColumn = 1;
  while (index < source.length && currentColumn < column) {
    final unit = source.codeUnitAt(index);
    if (unit == 10 || unit == 13) break;
    index++;
    currentColumn++;
  }
  return utf8.encode(source.substring(0, index)).length;
}

int _stringIndex(String source, int byteOffset) {
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
