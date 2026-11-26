import 'source_index.dart';
import 'loop_context_docs.dart';
import 'dart:convert';
import 'dart:io';

import 'ast.dart';
import 'compiler.dart';
import 'dart_api.dart';
import 'doc_markup.dart';
import 'libraries.dart';
import 'sdk.dart';
import 'semantics.dart';
import 'source.dart';
import 'walk.dart';

/// The library named by a `use`, `export`, or `part` URI under the cursor.
///
/// [line] and [column] are one-based. A `quds:` library carries its source in
/// [LibraryPlace.text] so the editor can show it without a writable file.
LibraryPlace? libraryAt(String source, int line, int column, {String? from}) {
  final rows = source.split('\n');
  if (line < 1 || line > rows.length) return null;
  final row = rows[line - 1];
  final index = column - 1;
  if (index < 0 || index > row.length) return null;
  final header = RegExp(r'^[ \t]*(use|export|part)\b[ \t]*').matchAsPrefix(row);
  if (header == null) return null;
  var start = header.end;
  if (header.group(1) == 'part') {
    final of = RegExp(r'of\b[ \t]*').matchAsPrefix(row, start);
    if (of != null) start = of.end;
  }
  if (start >= row.length) return null;
  var uriStart = start;
  var uriEnd = start;
  final quote = row[start];
  if (quote == '"' || quote == "'") {
    uriStart = start + 1;
    uriEnd = row.indexOf(quote, uriStart);
    if (uriEnd < 0) return null;
  } else {
    while (uriEnd < row.length && row[uriEnd] != ' ' && row[uriEnd] != '\t') {
      uriEnd++;
    }
  }
  if (index < start || index > uriEnd) return null;
  final uri = row.substring(uriStart, uriEnd);
  if (uri.isEmpty) return null;
  final literalPart =
      header.group(1) == 'part' && (quote == '"' || quote == "'");
  return _libraryPlace(literalPart ? uri : normalizeImportUri(uri), from);
}

LibraryPlace? _libraryPlace(String uri, String? from) {
  final sdk = sdkLibraryName(uri);
  if (sdk != null) {
    final text = readSdk(sdk);
    if (text == null) return null;
    return LibraryPlace(sdkPath(sdk) ?? 'quds:$sdk', text: text);
  }
  if (uri.startsWith('dart:')) {
    final file = dartLibraryFile(uri);
    if (file == null) return null;
    return LibraryPlace(file.path);
  }
  if (from == null || from == '<input>') return null;
  final quds = resolveLibraryPath(from, uri);
  if (quds != null && File(quds).existsSync()) return LibraryPlace(quds);
  final dartUri = dartLibraryUri(from, uri);
  if (dartUri == null) return null;
  final dart = packageDartFile(from, dartUri);
  if (dart == null) return null;
  return LibraryPlace(dart.path);
}

/// A library opened from an import URI.
class LibraryPlace {
  const LibraryPlace(this.file, {this.text});

  /// Absolute path, or a `quds:` URI when the library is only embedded.
  final String file;

  /// Source of a `quds:` library. Dart and package files are read from [file].
  final String? text;
}

/// The declaration span of the name under [line] and [column].
///
/// The span belongs to the `.quds` file that declares the name. [sourceOf]
/// supplies that file's text so the span can shrink to the name itself.
/// A missing source keeps the whole declaration span.
SourceSpan? definitionAt(Compilation compilation, int line, int column,
    {String? Function(String file)? sourceOf}) {
  final currentText = sourceOf?.call(compilation.program.span.file);
  if (currentText != null) {
    final hit = _smallestNode(compilation, line, column);
    if (hit != null) {
      final typeSymbol =
          _typeSymbolAt(compilation, currentText, hit, line, column);
      if (typeSymbol != null) {
        final declared = _nodeForSymbol(compilation, typeSymbol);
        if (declared != null) {
          final name = _declaredName(declared);
          final text = name == null ? null : sourceOf?.call(declared.span.file);
          if (name == null || text == null) return declared.span;
          return _nameSpan(text, declared.span, name) ?? declared.span;
        }
        return _originSpan(typeSymbol);
      }
    }
  }
  final node = _definitionNode(compilation, line, column);
  if (node == null) {
    return _originSpan(_symbolAt(compilation, line, column));
  }
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
  return _hoverText(compilation, source, node, offset, line, column);
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
List<int> semanticTokenData(Compilation compilation, String source,
    {bool declarationsOnly = false}) {
  final tokens = <_Token>[];
  final positions = SourceIndex(source);
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
          index: positions,
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
          index: positions,
        );
        if (token != null) tokens.add(token);
      case FieldDeclaration():
        final token = _nameToken(
          source,
          node.span,
          node.name,
          _property,
          _bits(declaration: true, readonly: !node.mutable),
          index: positions,
        );
        if (token != null) tokens.add(token);
      case ClassDeclaration():
        final token = _nameToken(
          source,
          node.span,
          node.name,
          _classType,
          _bits(declaration: true),
          index: positions,
        );
        if (token != null) tokens.add(token);
      case Parameter():
        final token = _nameToken(
          source,
          node.span,
          node.name,
          _parameter,
          _bits(declaration: true, readonly: !node.mutable),
          index: positions,
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
            readonly: !(symbol?.mutable ??
                const {
                  BindingMode.mutable,
                  BindingMode.shadowMutable,
                  BindingMode.lateMutable,
                  BindingMode.state
                }.contains(node.mode)),
          ),
          index: positions,
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
          index: positions,
        );
        if (token != null) tokens.add(token);
        final index = node.index;
        if (index != null) {
          final indexToken = _nameToken(
            source,
            node.span,
            index,
            _variable,
            _bits(declaration: true, readonly: true),
            index: positions,
          );
          if (indexToken != null) tokens.add(indexToken);
        }
      case Identifier():
        if (declarationsOnly) break;
        final kind = _identifierKind(compilation, node, methods, parameters);
        if (kind == null) break;
        final start = positions.stringIndex(node.span.offset);
        final token = _tokenAt(
            source, start, node.name.length, kind.$1, kind.$2,
            index: positions);
        if (token != null) tokens.add(token);
      case MemberAccess():
        if (declarationsOnly) break;
        final kind = _memberKind(compilation.semantics, node);
        final token =
            _memberNameToken(source, node, kind.$1, kind.$2, index: positions);
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
    final member = _findMember(compilation.semantics, node);
    if (member is _ConstructorFound) return member.declaration;
    final linked =
        _nodeForSymbol(compilation, compilation.semantics.references[node]);
    if (linked != null) return linked;
    return switch (member) {
      _PropertyFound(:final declaration) => declaration,
      _FieldFound(:final declaration) => declaration,
      _MethodFound(:final declaration) => declaration,
      _ => null,
    };
  }
  if (node is Identifier) {
    return _nodeForSymbol(compilation, compilation.semantics.references[node]);
  }
  if (node is TypeApplication) {
    return _declaredNode(compilation, node.callee, line, column);
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
  for (final entry in compilation.semantics.loopIndexes.entries) {
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
      ConstructorDeclaration(:final name) => name,
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

String? _hoverText(Compilation compilation, String source, Node node,
    int offset, int line, int column) {
  final model = compilation.semantics;
  if (node is Identifier) return _identifierHover(model, node);
  if (node is MemberAccess) return _memberHover(model, node);
  final typeSymbol = _typeSymbolAt(compilation, source, node, line, column);
  if (typeSymbol != null) {
    return _libraryHover(model, typeSymbol) ?? 'class ${typeSymbol.name}';
  }
  if (node is Expression) return model.types[node];
  if (!_onName(source, node, offset)) return null;
  return switch (node) {
    FunctionDeclaration() =>
      _documented(_signature(node, model), node.documentation),
    Parameter() => _valueHover(
        node.name,
        node.variadic ? 'List<${node.type}>' : node.type,
        mutable: node.mutable,
      ),
    Binding() => _bindingHover(model, node),
    ForStatement() => _forHover(model, source, node, offset),
    FieldDeclaration() => _valueHover(
        node.name,
        node.type == '<infer>' ? model.declarations[node]?.type : node.type,
        mutable: node.mutable,
      ),
    PropertyDeclaration() => _propertyHover(node),
    ClassDeclaration() => _documented('class ${node.name}', node.documentation),
    _ => null,
  };
}

String? _libraryHover(SemanticModel model, Symbol? symbol) {
  if (symbol == null) return null;
  final function = symbol.function;
  final rawSignature = symbol.signature ??
      (function == null ? null : _signature(function, model)) ??
      (symbol.classDeclaration == null
          ? null
          : 'class ${symbol.classDeclaration!.name}');
  final signature =
      rawSignature == null ? null : model.displayType(rawSignature);
  final documentation = _written(symbol.documentation) ??
      _written(function?.documentation) ??
      _written(symbol.classDeclaration?.documentation);
  if (signature == null && documentation == null) return null;
  if (documentation == null) return signature;
  if (signature == null) return _markdownHover('', documentation, 'quds');
  if (symbol.external) {
    return nativeDocumentationHover(signature, documentation);
  }
  return _markdownHover(signature, documentation, 'quds');
}

String? _written(String? text) {
  final trimmed = text?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String _documented(String signature, String? documentation) {
  final text = _written(documentation);
  if (text == null) return signature;
  return _markdownHover(signature, text, 'quds');
}

/// Signature, prose, and an `Example:` block, as editor markdown.
String _markdownHover(String signature, String documentation, String fence) {
  final prose = <String>[];
  final example = <String>[];
  var inExample = false;
  for (final raw in documentation.split('\n')) {
    final line = raw.trimRight();
    final trimmed = line.trim();
    if (!inExample && (trimmed == 'Example:' || trimmed == 'Example')) {
      inExample = true;
      continue;
    }
    if (inExample) {
      example.add(line.startsWith('  ') ? line.substring(2) : line);
    } else if (trimmed.isNotEmpty) {
      prose.add(trimmed);
    }
  }
  final buffer = StringBuffer();
  if (signature.isNotEmpty) {
    buffer.writeln('```$fence');
    buffer.writeln(signature);
    buffer.writeln('```');
  }
  if (prose.isNotEmpty) {
    if (buffer.isNotEmpty) buffer.writeln();
    buffer.writeln(prose.join('\n'));
  }
  if (example.isNotEmpty) {
    if (buffer.isNotEmpty) buffer.writeln();
    buffer.writeln('```quds');
    buffer.writeln(example.join('\n').trimRight());
    buffer.writeln('```');
  }
  return buffer.toString().trimRight();
}

SourceSpan? _originSpan(Symbol? symbol) {
  final file = symbol?.originFile;
  if (symbol == null || file == null || file.isEmpty || symbol.originLine < 1) {
    return null;
  }
  return SourceSpan(
    symbol.originLine,
    symbol.originColumn < 1 ? 1 : symbol.originColumn,
    symbol.name.length,
    file: file,
    offset: symbol.originOffset,
  );
}

Symbol? _symbolAt(Compilation compilation, int line, int column) {
  final node = _smallestNode(compilation, line, column);
  if (node == null) return null;
  return _symbolOf(compilation, node, line, column);
}

Symbol? _symbolOf(Compilation compilation, Node node, int line, int column) {
  if (node is MemberAccess) {
    if (!_onMemberName(node, line, column)) {
      return _symbolOf(compilation, node.object, line, column);
    }
    return compilation.semantics.references[node];
  }
  if (node is Identifier) return compilation.semantics.references[node];
  if (node is TypeApplication) {
    return _symbolOf(compilation, node.callee, line, column);
  }
  if (node is CallExpression) {
    return _symbolOf(compilation, node.callee, line, column);
  }
  return null;
}

String? _identifierHover(SemanticModel model, Identifier node) {
  final symbol = model.references[node];
  final library = _libraryHover(model, symbol);
  if (library != null) return library;
  final function = symbol?.function;
  if (function != null) return _signature(function, model);
  if (symbol?.classDeclaration != null) return 'class ${node.name}';
  final type = model.types[node] ?? symbol?.type;
  return _valueHover(node.name, type, mutable: symbol?.mutable ?? false);
}

String? _memberHover(SemanticModel model, MemberAccess node) {
  if (model.loopContextMembers.containsKey(node)) {
    return '`${r'$.'}${node.name}: ${model.displayType(model.types[node]!)}`\n\n${loopContextDocs[node.name]}';
  }
  final found = _findMember(model, node);
  if (found is _ConstructorFound) {
    return _constructorHover(found.owner, found.declaration);
  }
  final library = _libraryHover(model, model.references[node]);
  if (library != null) return library;
  if (found is _PropertyFound) return _propertyHover(found.declaration);
  if (found is _FieldFound) {
    return _valueHover(
      found.declaration.name,
      model.types[node] ?? found.declaration.type,
      mutable: found.declaration.mutable,
    );
  }
  if (found is _MethodFound) {
    return _documented(
        _signature(found.declaration, model), found.declaration.documentation);
  }
  final type = model.types[node];
  if (type == null) return null;
  if (type.startsWith('(') && type.contains('->')) return '${node.name}: $type';
  return 'get ${node.name}: $type';
}

String _constructorHover(
    ClassDeclaration owner, ConstructorDeclaration constructor) {
  final parameters = constructor.parameters.map((parameter) {
    final fieldType = parameter.initializing.isEmpty
        ? parameter.type
        : owner.fields
                .where((field) => field.name == parameter.name)
                .firstOrNull
                ?.type ??
            parameter.type;
    final stored = parameter.variadic ? 'List<$fieldType>' : fieldType;
    final prefix = parameter.mutable ? 'var ' : '';
    return '$prefix${parameter.name}: $stored';
  }).join(', ');
  final kind = constructor.factory
      ? 'factory '
      : constructor.constant
          ? 'const '
          : '';
  return '$kind${owner.name}.${constructor.name}($parameters) -> ${owner.name}';
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
  if (symbol.classDeclaration != null || symbol.nativeTop?.isType == true) {
    return (_classType, 0);
  }
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
  if (model.loopContextMembers.containsKey(node)) {
    return (_property, _bits(readonly: true));
  }
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
    case _ConstructorFound():
      return (_method, 0);
    case null:
      final ref = model.references[node];
      if (ref != null && (ref.callable || ref.nativeMember?.getter == false)) {
        return (_method, 0);
      }
      final type = model.types[node];
      if (type != null && type.startsWith('(') && type.contains('->')) {
        return (_function, 0);
      }
      return (_property, _bits(readonly: true));
  }
}

_Found? _findMember(SemanticModel model, MemberAccess node) {
  final direct = model.references[node.object]?.classDeclaration;
  if (direct != null) {
    for (final constructor in direct.constructors) {
      if (constructor.name == node.name) {
        return _ConstructorFound(direct, constructor);
      }
    }
  }
  var typeName = _classHead(model.types[node.object] ?? direct?.name ?? '');
  final seen = <String>{};
  while (typeName.isNotEmpty && seen.add(typeName)) {
    final declaration = model.classes[typeName];
    if (declaration == null) break;
    for (final constructor in declaration.constructors) {
      if (constructor.name == node.name) {
        return _ConstructorFound(declaration, constructor);
      }
    }
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
    String source, SourceSpan span, String name, int type, int modifiers,
    {SourceIndex? index}) {
  final start =
      index?.stringIndex(span.offset) ?? _stringIndex(source, span.offset);
  final end = index?.stringIndex(span.offset + span.length) ??
      _stringIndex(source, span.offset + span.length);
  if (start < 0 || end > source.length || start > end) return null;
  final match = RegExp('\\b${RegExp.escape(name)}\\b')
      .firstMatch(source.substring(start, end));
  if (match == null) return null;
  return _tokenAt(source, start + match.start, name.length, type, modifiers,
      index: index);
}

_Token? _memberNameToken(
    String source, MemberAccess node, int type, int modifiers,
    {SourceIndex? index}) {
  final start = index?.stringIndex(node.span.offset) ??
      _stringIndex(source, node.span.offset);
  final end = index?.stringIndex(node.span.offset + node.span.length) ??
      _stringIndex(source, node.span.offset + node.span.length);
  if (start < 0 || end > source.length || start > end) return null;
  final text = source.substring(start, end);
  final dot = node.nullAware ? '?.${node.name}' : '.${node.name}';
  final at = text.lastIndexOf(dot);
  if (at < 0) return null;
  return _tokenAt(source, start + at + dot.length - node.name.length,
      node.name.length, type, modifiers,
      index: index);
}

_Token? _tokenAt(
    String source, int stringIndex, int length, int type, int modifiers,
    {SourceIndex? index}) {
  if (stringIndex < 0 || length <= 0 || stringIndex > source.length) {
    return null;
  }
  if (index != null) {
    final position = index.position(stringIndex);
    return _Token(position.$1, position.$2, length, type, modifiers);
  }
  var line = 0;
  var column = 0;
  var cursor = 0;
  while (cursor < stringIndex) {
    final unit = source.codeUnitAt(cursor);
    if (unit == 13) {
      cursor++;
      if (cursor < source.length && source.codeUnitAt(cursor) == 10) cursor++;
      line++;
      column = 0;
    } else if (unit == 10) {
      cursor++;
      line++;
      column = 0;
    } else {
      cursor++;
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

class _ConstructorFound extends _Found {
  _ConstructorFound(this.owner, this.declaration);
  final ClassDeclaration owner;
  final ConstructorDeclaration declaration;
}

Symbol? _typeSymbolAt(
    Compilation compilation, String source, Node node, int line, int column) {
  final isTypeCarrier = node is Binding ||
      node is Parameter ||
      node is FieldDeclaration ||
      node is PropertyDeclaration ||
      node is FunctionDeclaration ||
      node is ClassDeclaration ||
      node is AliasDeclaration ||
      node is ExtensionDeclaration ||
      node is TypeTestExpression ||
      node is ConversionExpression ||
      node is TypeApplication;
  if (!isTypeCarrier) return null;
  final offset = _byteOffsetAt(source, line, column);
  if (_onName(source, node, offset)) return null;
  final word = _wordAt(source, line, column);
  if (word == null) return null;
  final model = compilation.semantics;
  final symbol = model.moduleSymbols[word];
  if (symbol != null &&
      (symbol.nativeTop?.isType == true || symbol.classDeclaration != null)) {
    return symbol;
  }
  final declared = model.classes[word];
  if (declared != null) return model.declarations[declared];
  return null;
}

String? _wordAt(String source, int line, int column) {
  final index = _indexAt(source, line, column);
  if (index < 0 || index > source.length) return null;
  var end = index < source.length && _word(source.codeUnitAt(index))
      ? index
      : index - 1;
  if (end < 0 || !_word(source.codeUnitAt(end))) return null;
  var start = end;
  while (start > 0 && _word(source.codeUnitAt(start - 1))) {
    start--;
  }
  while (end + 1 < source.length && _word(source.codeUnitAt(end + 1))) {
    end++;
  }
  return source.substring(start, end + 1);
}

bool _onName(String source, Node node, int offset) {
  final names = <String>[
    if (node is ForStatement && node.index != null) node.index!,
    if (_declaredName(node) != null) _declaredName(node)!,
  ];
  for (final name in names) {
    if (_nameCovers(source, node.span, name, offset)) return true;
  }
  return false;
}

bool _nameCovers(String source, SourceSpan span, String name, int offset) {
  final local = _nameSpan(source, span, name);
  if (local == null) return false;
  final bytes = utf8.encode(name).length;
  return offset >= local.offset && offset < local.offset + bytes;
}

String? _forHover(
    SemanticModel model, String source, ForStatement node, int offset) {
  final index = node.index;
  if (index != null && _nameCovers(source, node.span, index, offset)) {
    final symbol = model.loopIndexes[node];
    return _valueHover(index, symbol?.type ?? 'int', mutable: false);
  }
  final symbol = model.declarations[node];
  return _valueHover(node.name, symbol?.type,
      mutable: symbol?.mutable ?? false);
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

/// Where a Dart SDK name sits, including when the Quds file does not compile.
class DartPlace {
  const DartPlace({
    required this.text,
    required this.file,
    required this.line,
    required this.column,
    required this.offset,
    required this.length,
  });

  final String text;
  final String file;
  final int line;
  final int column;
  final int offset;
  final int length;
}

/// The Dart declaration under [line] and [column] in a buffer that may not compile.
DartPlace? dartPlaceAt(String source, int line, int column) {
  final index = _indexAt(source, line, column);
  if (index < 0 || index > source.length) return null;
  var end = index < source.length && _word(source.codeUnitAt(index))
      ? index
      : index - 1;
  if (end < 0 || !_word(source.codeUnitAt(end))) return null;
  var start = end;
  while (start > 0 && _word(source.codeUnitAt(start - 1))) {
    start--;
  }
  while (end + 1 < source.length && _word(source.codeUnitAt(end + 1))) {
    end++;
  }
  final name = source.substring(start, end + 1);
  var cursor = start - 1;
  while (cursor >= 0 && _gap(source.codeUnitAt(cursor))) {
    cursor--;
  }
  if (cursor < 0 || source.codeUnitAt(cursor) != 46) {
    return _unprefixedDartTop(source, name);
  }
  cursor--;
  while (cursor >= 0 && _gap(source.codeUnitAt(cursor))) {
    cursor--;
  }
  if (cursor >= 0 && source.codeUnitAt(cursor) == 62) {
    var depth = 0;
    var scan = cursor;
    while (scan >= 0) {
      final unit = source.codeUnitAt(scan);
      if (unit == 62) {
        depth++;
      } else if (unit == 60) {
        depth--;
        if (depth == 0) break;
      }
      scan--;
    }
    if (scan > 0 && _word(source.codeUnitAt(scan - 1))) {
      cursor = scan - 1;
    }
  }
  if (cursor >= 0 && source.codeUnitAt(cursor) == 41) {
    var depth = 0;
    while (cursor >= 0) {
      final unit = source.codeUnitAt(cursor);
      if (unit == 41) {
        depth++;
      } else if (unit == 40) {
        depth--;
        if (depth == 0) break;
      }
      cursor--;
    }
    cursor--;
    while (cursor >= 0 && _gap(source.codeUnitAt(cursor))) {
      cursor--;
    }
    final called = _wordBefore(source, cursor);
    if (called == null) return null;
    var owner = called;
    cursor = called.start - 1;
    while (cursor >= 0 && _gap(source.codeUnitAt(cursor))) {
      cursor--;
    }
    if (cursor >= 0 && source.codeUnitAt(cursor) == 46) {
      cursor--;
      while (cursor >= 0 && _gap(source.codeUnitAt(cursor))) {
        cursor--;
      }
      final previous = _wordBefore(source, cursor);
      if (previous != null) {
        final imported = _dartPrefix(source, previous.text);
        if (imported != null && _visible(imported, called.text)) {
          owner = called;
        } else if (previous.text.isNotEmpty) {
          final prefix = _prefixBefore(source, previous.start - 1);
          final library = prefix == null ? null : _dartPrefix(source, prefix);
          if (library != null && _visible(library, previous.text)) {
            final shape = readDartLibrary(library.uri)?.types[previous.text];
            final member = shape?.members[name];
            if (member == null || member.file.isEmpty) return null;
            return _place(describeDartMember(member), member.file, member.line,
                member.column, member.offset, name.length);
          }
        }
      }
    }
    final prefix = _prefixBefore(source, owner.start - 1);
    final library = prefix == null ? null : _dartPrefix(source, prefix);
    if (library == null || !_visible(library, owner.text)) return null;
    final member =
        readDartLibrary(library.uri)?.types[owner.text]?.members[name];
    if (member == null || member.file.isEmpty) return null;
    return _place(describeDartMember(member), member.file, member.line,
        member.column, member.offset, name.length);
  }
  final prefix = _wordBefore(source, cursor);
  if (prefix == null) return null;
  final library = _dartPrefix(source, prefix.text);
  if (library != null && _visible(library, name)) {
    final top = readDartLibrary(library.uri)?.names[name];
    if (top != null && top.file.isNotEmpty) {
      return _place(describeDartTop(top), top.file, top.line, top.column,
          top.offset, name.length);
    }
  }
  final outer = _prefixBefore(source, prefix.start - 1);
  if (outer != null) {
    final outerLibrary = _dartPrefix(source, outer);
    if (outerLibrary != null && _visible(outerLibrary, prefix.text)) {
      final shape = readDartLibrary(outerLibrary.uri)?.types[prefix.text];
      final member = shape?.statics[name] ?? shape?.constructors[name];
      if (member != null && member.file.isNotEmpty) {
        return _place(describeDartMember(member), member.file, member.line,
            member.column, member.offset, name.length);
      }
    }
    return null;
  }
  return _unprefixedDartMember(source, prefix.text, name);
}

DartPlace? _unprefixedDartTop(String source, String name) {
  for (final library in _unprefixedDartImports(source)) {
    if (!_visible(library, name)) continue;
    final top = readDartLibrary(library.uri)?.names[name];
    if (top != null && top.file.isNotEmpty) {
      return _place(describeDartTop(top), top.file, top.line, top.column,
          top.offset, name.length);
    }
  }
  if (name == 'print' || name == 'Error') return null;
  final top = readDartLibrary('dart:core')?.names[name];
  if (top == null || !top.isType || top.file.isEmpty) return null;
  return _place(describeDartTop(top), top.file, top.line, top.column,
      top.offset, name.length);
}

DartPlace? _unprefixedDartMember(String source, String owner, String name) {
  for (final library in _unprefixedDartImports(source)) {
    if (!_visible(library, owner)) continue;
    final shape = readDartLibrary(library.uri)?.types[owner];
    final member = shape?.statics[name] ?? shape?.constructors[name];
    if (member != null && member.file.isNotEmpty) {
      return _place(describeDartMember(member), member.file, member.line,
          member.column, member.offset, name.length);
    }
  }
  final shape = readDartLibrary('dart:core')?.types[owner];
  final member = shape?.statics[name] ?? shape?.constructors[name];
  if (member == null || member.file.isEmpty) return null;
  return _place(describeDartMember(member), member.file, member.line,
      member.column, member.offset, name.length);
}

List<({String uri, List<String>? show, List<String>? hide})>
    _unprefixedDartImports(String source) {
  final results = <({String uri, List<String>? show, List<String>? hide})>[];
  final pattern =
      RegExp(r'^\s*use\s+(dart:[A-Za-z0-9_]+)([^\n]*)', multiLine: true);
  for (final match in pattern.allMatches(source)) {
    final tail = match.group(2)!;
    if (RegExp(r'\bas\b').hasMatch(tail)) continue;
    List<String>? names(String keyword) {
      final found = RegExp('$keyword\\s+([A-Za-z0-9_,\\s]+)').firstMatch(tail);
      if (found == null) return null;
      return found
          .group(1)!
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    results.add((
      uri: match.group(1)!,
      show: names('show'),
      hide: names('hide'),
    ));
  }
  return results;
}

DartPlace _place(
    String text, String file, int line, int column, int offset, int length) {
  return DartPlace(
    text: text,
    file: file,
    line: line,
    column: column,
    offset: offset,
    length: length,
  );
}

bool _word(int unit) =>
    unit == 95 ||
    (unit >= 65 && unit <= 90) ||
    (unit >= 97 && unit <= 122) ||
    (unit >= 48 && unit <= 57);

bool _gap(int unit) => unit == 32 || unit == 9;

({int start, String text})? _wordBefore(String source, int end) {
  if (end < 0 || end >= source.length || !_word(source.codeUnitAt(end))) {
    return null;
  }
  var start = end;
  while (start > 0 && _word(source.codeUnitAt(start - 1))) {
    start--;
  }
  return (start: start, text: source.substring(start, end + 1));
}

String? _prefixBefore(String source, int end) {
  while (end >= 0 && _gap(source.codeUnitAt(end))) {
    end--;
  }
  if (end < 0 || source.codeUnitAt(end) != 46) return null;
  end--;
  while (end >= 0 && _gap(source.codeUnitAt(end))) {
    end--;
  }
  return _wordBefore(source, end)?.text;
}

({String uri, List<String>? show, List<String>? hide})? _dartPrefix(
    String source, String prefix) {
  final pattern = RegExp(
      'use\\s+(dart:[A-Za-z0-9_]+)\\s+as\\s+${RegExp.escape(prefix)}\\b');
  final match = pattern.firstMatch(source);
  if (match == null) return null;
  final lineEnd = source.indexOf('\n', match.end);
  final tail =
      source.substring(match.end, lineEnd < 0 ? source.length : lineEnd);
  List<String>? names(String keyword) {
    final found = RegExp('$keyword\\s+([A-Za-z0-9_,\\s]+)').firstMatch(tail);
    if (found == null) return null;
    return found
        .group(1)!
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  return (uri: match.group(1)!, show: names('show'), hide: names('hide'));
}

bool _visible(({String uri, List<String>? show, List<String>? hide}) library,
    String name) {
  if (library.show != null && !library.show!.contains(name)) return false;
  if (library.hide != null && library.hide!.contains(name)) return false;
  return true;
}

int _indexAt(String source, int line, int column) {
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
  return index;
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
