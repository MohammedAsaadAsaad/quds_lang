import 'source_index.dart';
import 'parser.dart';
import 'loop_context_docs.dart';
import 'keyword_docs_data.dart';
import 'lexer.dart';
import 'type_syntax.dart';
import 'dart:convert';
import 'dart:io';

import 'ast.dart';
import 'compiler.dart';
import 'dart_api.dart';
import 'libraries.dart';
import 'sdk.dart';
import 'semantics.dart';
import 'walk.dart';

Node? _loopCompletionOwner(String source, String prefix, int offset) {
  for (var candidate in [source, prefix]) {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final program =
            Parser(Lexer().tokenize(candidate)).parse(partial: true);
        Node? owner;
        walkAst(program, (node) {
          if (!_loopContextContains(node, offset)) return;
          if (owner == null || node.span.length < owner!.span.length)
            owner = node;
        });
        if (owner != null) return owner;
        break;
      } on CompilerException catch (error) {
        if (error.code != 'E004') break;
        final start = _stringIndexForByte(candidate, error.span.offset);
        if (start >= candidate.length) break;
        final quote = candidate[start];
        if (quote != '"' && quote != "'") break;
        final delimiter =
            candidate.startsWith(quote * 3, start) ? quote * 3 : quote;
        candidate +=
            '${error.message.contains('interpolation') ? '}' : ''}$delimiter\n';
      }
    }
  }
  return null;
}

bool _loopContextContains(Node node, int offset) {
  bool contains(Node child) =>
      offset >= child.span.offset &&
      offset < child.span.offset + child.span.length;
  final body = switch (node) {
    ForStatement() => node.body,
    WhileStatement() => node.body,
    CForStatement() => node.body,
    RepeatStatement() => node.body,
    _ => null,
  };
  if (body != null)
    return body.any(contains) ||
        node is RepeatStatement &&
            node.condition != null &&
            contains(node.condition!);
  if (node is CollectionFor) {
    return node.body.any(contains) ||
        node.filter != null && contains(node.filter!);
  }
  return node is MapComprehension &&
      node.name != null &&
      contains(node.thenMap);
}

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
  String? file,
  Compilation? stable,
  bool allowUncompiledDart = true,
  required Compilation? Function(String source) compileSource,
}) {
  final cursor = _stringIndexAt(source, line, character);
  if (!_inCode(source, cursor)) return const [];
  final imports = _importCompletion(source, cursor, file);
  if (imports != null) return imports;
  final word = _word(source, cursor);
  final prefix = word.read(source);
  if (prefix.isNotEmpty && _digit(prefix.codeUnitAt(0))) return const [];
  final dot = _dotBefore(source, word.start);
  final range = _range(source, word.start, word.end);
  if (dot != null && dot > 0 && source[dot - 1] == r'$') {
    // Syntax-only: no compiler, imports, Dart analyzer or filesystem work on
    // the loop-context completion path, even while the property is unfinished.
    try {
      final probe = source.substring(0, word.start) +
          'index' +
          source.substring(word.end);
      final offset = utf8.encode(source.substring(0, dot - 1)).length;
      final owner = _loopCompletionOwner(
          probe, source.substring(0, word.start) + 'index', offset);
      if (owner == null) return const [];
      final hasItem = owner is ForStatement ||
          owner is CollectionFor ||
          owner is MapComprehension;
      return [
        for (final entry in loopContextDocs.entries)
          if ((entry.key != 'item' || hasItem) && entry.key.startsWith(prefix))
            {
              'label': entry.key,
              'kind': 10,
              'detail': entry.key == 'item'
                  ? 'current loop item'
                  : entry.key == 'isFirst'
                      ? 'bool'
                      : 'int',
              'documentation': {'kind': 'markdown', 'value': entry.value},
              'textEdit': {'range': range, 'newText': entry.key},
            }
      ];
    } on CompilerException {
      return const [];
    }
  }
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
    final compilation = resolved ?? _recover(source, word, dot, compile);
    if (compilation == null) {
      if (allowUncompiledDart) _uncompiledDart(source, dot, range, add);
      if (items.isEmpty) _uncompiledCore(source, dot, range, add);
      return items.values.toList();
    }
    final scope = _scopeAt(compilation, source, _lineStart(source, cursor));
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
  final argument =
      _argument(source, word.start) ?? _argumentBlock(source, word.start);
  if (argument != null && resolved != null) {
    _namedArguments(resolved, source, scope, argument, range, add);
  }
  for (final entry in scope.names.entries) {
    if (entry.key == '_' ||
        entry.value.function?.conversionKind.isNotEmpty == true) continue;
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
  for (final keyword in keywordDocumentation.keys) {
    if (atStatement && _snippets.containsKey(keyword)) continue;
    add({
      ..._plain(keyword, 14, 'keyword', range, sort: '3', commit: false),
      'documentation': {
        'kind': 'markdown',
        'value': keywordDocumentation[keyword]!
      },
    });
  }
  if (atStatement) {
    final indent = _indent(source, word.start);
    for (final entry in _snippets.entries) {
      final body = entry.value.replaceAll('\n', '\n$indent');
      add({
        'label': entry.key,
        'kind': 15,
        'detail': 'snippet',
        'documentation': {
          'kind': 'markdown',
          'value': keywordDocumentation[entry.key]!
        },
        'filterText': entry.key,
        'sortText': '0${entry.key}',
        'insertTextFormat': 2,
        'textEdit': {...range, 'newText': body},
      });
    }
  }
  return items.values.toList();
}

/// Keyword help works on incomplete buffers without invoking semantic analysis.
/// Contextual words are recognized only in their grammatical surroundings.
Map<String, Object?>? keywordHoverAt(String source, int line, int character) {
  final cursor = _stringIndexAt(source, line, character);
  final word = _word(source, cursor);
  if (word.start == word.end || !_inCode(source, word.start)) return null;
  final dot = _dotBefore(source, word.start);
  if (dot != null) {
    final receiverPrefix =
        source.substring(_lineStart(source, dot), dot).trimRight();
    if (word.read(source) != 'new' ||
        receiverPrefix.isNotEmpty &&
            RegExp(r'[\w\p{L}\p{N}?)\]]$', unicode: true)
                .hasMatch(receiverPrefix)) return null;
  }
  var end = word.end;
  var key = source.substring(word.start, end);
  if ((key == 'to' || key == 'with') &&
      end < source.length &&
      source[end] == '?') {
    key += '?';
    end++;
  }
  final documentation = keywordDocumentation[key];
  if (documentation == null) return null;
  final before =
      source.substring(_lineStart(source, word.start), word.start).trim();
  final lineEnd = source.indexOf('\n', end);
  final after =
      source.substring(end, lineEnd < 0 ? source.length : lineEnd).trim();
  if (!_keywordContext(key, before, after)) return null;
  if ((key == 'get' || key == 'set' && after.startsWith('(')) &&
      !_insideProperty(source, word.start)) return null;
  return {
    'contents': {'kind': 'markdown', 'value': documentation},
    'range': _range(source, word.start, end)['range'],
  };
}

bool _insideProperty(String source, int start) {
  final currentLine = _lineStart(source, start);
  final indent = start - currentLine;
  var end = currentLine;
  while (end > 0) {
    final previous = _lineStart(source, end - 1);
    final line = source.substring(previous, end).trimRight();
    final text = line.trimLeft();
    if (text.isNotEmpty &&
        !text.startsWith('#') &&
        !text.startsWith('//') &&
        line.length - text.length < indent) {
      return RegExp(r'^(?:(?:private|protected)\s+)?property\s+')
          .hasMatch(text);
    }
    end = previous;
  }
  return false;
}

bool _keywordContext(String key, String before, String after) {
  // Reserved words have no identifier interpretation. All remaining words are
  // contextual: in particular value/get/map may be names of user symbols.
  const reserved = {
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
    'return',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'var',
    'while',
    'with',
    'with?',
    'yield',
  };
  if (reserved.contains(key)) return true;
  bool starts(String pattern) =>
      RegExp('^(?:$pattern)', unicode: true).hasMatch(after);
  bool follows(String pattern) => RegExp('(?:$pattern)\u0024').hasMatch(before);
  // An assignment, type annotation, call or bare reference to a contextual
  // identifier must not be mistaken for a keyword declaration.
  switch (key) {
    case 'to':
    case 'to?':
      return before.isNotEmpty &&
          starts(r'[\p{L}_$]') &&
          !follows(r'(?:^|\s)(?:var|const|return|print)|[=(:,]');
    case 'map':
    case 'set':
      return (after == ':' || starts(r':\s*(?:#|//|/\*)')) ||
          key == 'set' && before.isEmpty && starts(r'\(');
    case 'get':
      return before.isEmpty && starts(r'(?:=|:)');
    case 'cast':
      return follows(r'\b(?:implicit|explicit)') && starts(r'\(');
    case 'implicit':
    case 'explicit':
      return before.isEmpty && starts(r'cast\b');
    case 'value':
    case 'abstract':
    case 'base':
    case 'final':
    case 'singleton':
      return RegExp(
              r'^(?:(?:abstract|base|interface|final|sealed|mixin|value|singleton)\s+)*class\b')
          .hasMatch(after);
    case 'sealed':
      return starts(r'(?:class|type)\b');
    case 'interface':
    case 'mixin':
    case 'augment':
    case 'extend':
    case 'annotation':
    case 'type':
      return before.isEmpty && starts(r'[\p{L}_$]');
    case 'all':
    case 'isolate':
      return follows(r'\bawait') && starts(':');
    case 'of':
      return before == 'part' && after.isNotEmpty;
    case 'show':
    case 'hide':
    case 'deferred':
      return RegExp(r'^(?:use|export)\s+').hasMatch(before);
    case 'wraps':
      return RegExp(r'^type\s+').hasMatch(before) && starts(r'[\p{L}_$]');
    case 'extends':
    case 'implements':
    case 'on':
      return RegExp(r'\b(?:class|interface|mixin)\s+').hasMatch(before);
    case 'out':
      return follows(r'[<,]') && starts(r'[\p{L}_$]');
    case 'sync':
      return follows(r'\)') && starts(r'\*');
    case 'required':
      return before.contains(':') && (after.isEmpty || starts(r'[,)=]'));
    case 'by':
      return starts(r'lazy\s*:') && before.contains(':');
    case 'lazy':
      return follows(r'\bby') && starts(':');
    case 'capture':
      return starts(r'\([^)]*\)\s*->');
    case 'nameof':
      return after.isNotEmpty && !starts(r'(?:=|:|,|\))');
    case 'new':
      return follows(r'\.') && starts(r'\(');
    case 'group':
      return before == 'task' && starts(':') ||
          before.isEmpty && starts('["\u0027]');
    case 'test':
      return before.isEmpty && starts('["\u0027]');
    case 'task':
      return before.isEmpty && starts(r'group\s*:');
    case 'once':
    case 'batch':
      return before.isEmpty && starts(':');
    case 'let':
      return follows(r'\b(?:if|while)') && starts(r'[\p{L}_$]');
    case 'step':
      return before.startsWith('for ') && before.contains(' while ');
    case 'secret':
      return before == 'config' && starts(r'[\p{L}_$]');
    case 'where':
      return before.isNotEmpty &&
          !follows(r'[=(:,]') &&
          (starts(':') ||
              RegExp(r'^[\p{L}_$][^=]*=', unicode: true).hasMatch(after) ||
              RegExp(r'^[\p{L}_$]\w*\s+is\s+', unicode: true).hasMatch(after));
    case 'when':
      return after.isNotEmpty && !starts(r'[=:(]');
    case 'readonly':
      return starts(r'[\p{L}_$]');
    default:
      // Statement/declaration introductions (including member modifiers).
      return (before.isEmpty ||
              RegExp(r'^(?:(?:private|protected|static|const|factory|shadow)\s*)+$')
                  .hasMatch(before)) &&
          after.isNotEmpty &&
          !starts(r'[=:(,]');
  }
}

/// Signature information uses the same cached scope and native metadata as completion.
Map<String, Object?>? signatureHelpAt(
    {required String source,
    required int line,
    required int character,
    Compilation? stable,
    required Compilation? Function(String) compileSource}) {
  final cursor = _stringIndexAt(source, line, character);
  if (!_inCode(source, cursor)) return null;
  final compilation =
      stable ?? _recover(source, _word(source, cursor), null, compileSource);
  if (compilation == null) return null;
  final call = _argument(source, cursor);
  if (call == null) return null;
  final scope = _scopeAt(compilation, source, cursor);
  final signatures = <Map<String, Object?>>[];
  void add(Iterable<_Param> params) {
    final list = params.toList();
    signatures.add({
      'label':
          '${call.callee}(${list.map((p) => '${p.name}: ${compilation.semantics.displayType(p.type)}').join(', ')})',
      'parameters': [
        for (final p in list)
          {'label': '${p.name}: ${compilation.semantics.displayType(p.type)}'}
      ]
    });
  }

  if (call.member) {
    final receiver =
        _receiverName(source, _calleeStart(source, call.paren) - 1);
    final symbol = scope.names[receiver];
    if (symbol != null) add(_parametersOf(compilation, symbol, call.callee));
  } else {
    final symbol = scope.names[call.callee];
    if (symbol == null) return null;
    if (symbol.classDeclaration != null)
      add(_constructorParameters(symbol.classDeclaration!));
    else if (symbol.nativeTop != null)
      add([for (final p in symbol.nativeTop!.parameters) _Param(p.$1, p.$2)]);
    else
      for (final fn in symbol.overloads)
        add([for (final p in fn.parameters) _Param(p.name, p.type)]);
  }
  if (signatures.isEmpty) return null;
  var depth = 0, active = 0;
  var quote = 0;
  for (var i = call.paren + 1; i < cursor; i++) {
    final c = source.codeUnitAt(i);
    if (quote != 0) {
      if (c == 92) {
        i++;
        continue;
      }
      if (c == quote) quote = 0;
      continue;
    }
    if (c == 34 || c == 39) {
      quote = c;
      continue;
    }
    if (c == 40 || c == 91 || c == 123) depth++;
    if (c == 41 || c == 93 || c == 125) depth--;
    if (c == 44 && depth == 0) active++;
  }
  return {
    'signatures': signatures,
    'activeSignature': 0,
    'activeParameter': active
  };
}

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
    (unit >= 48 && unit <= 57) ||
    unit >= 0xd800 && unit <= 0xdfff ||
    unit > 127 && Lexer.identifierPart.hasMatch(String.fromCharCode(unit));

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
  if (previous > 0 && _digit(source.codeUnitAt(previous - 1))) {
    var start = previous;
    while (start > 0 && _ident(source.codeUnitAt(start - 1))) start--;
    // A decimal literal is unfinished at `12.`; a variable such as values12
    // still needs member completion as the file grows.
    if (start < previous && _digit(source.codeUnitAt(start))) return null;
  }
  return index - 1;
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
  if (index > 0 && source.codeUnitAt(index - 1) == 62) {
    final open = _skipBack(source, index - 1, 60, 62);
    if (open > 0 && _ident(source.codeUnitAt(open - 1))) {
      index = open;
    }
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
  final names = Map<String, Symbol>.of(scope.names);
  _collectionNames(compilation, bytes, names);
  final lambda = _lambda(compilation, bytes);
  if (lambda == null) return _Here(names, scope.owner);
  for (final parameter in lambda.parameters) {
    final symbol = compilation.semantics.declarations[parameter] ??
        Symbol(parameter.name, parameter.name, parameter.type);
    if (parameter.name != '_') names[parameter.name] = symbol;
  }
  return _Here(names, scope.owner);
}

void _collectionNames(
    Compilation compilation, int bytes, Map<String, Symbol> names) {
  bool inside(SourceSpan span) =>
      bytes >= span.offset && bytes < span.offset + span.length;
  walkAst(compilation.program, (node) {
    if (node is! CollectionFor) return;
    final inBody = node.body.any((element) => inside(element.span));
    final inFilter = node.filter != null && inside(node.filter!.span);
    if (!inBody && !inFilter) return;
    final symbol = compilation.semantics.declarations[node];
    if (symbol != null) names[symbol.name] = symbol;
    final index = compilation.semantics.loopIndexes[node];
    if (index != null) names[index.name] = index;
  });
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
      if (statement.elseBody.isNotEmpty &&
          bytes >= statement.elseBody.first.span.offset) {
        return _blocks(compilation, source, bytes, statement.elseBody, outer,
            regionEnd, owner);
      }
      if (!_past(bytes, statement.iterable.span)) return null;
      final names = Map<String, Symbol>.of(outer);
      final symbol = compilation.semantics.declarations[statement];
      if (symbol != null && statement.name != '_') names[symbol.name] = symbol;
      final index = compilation.semantics.loopIndexes[statement];
      if (index != null) names[index.name] = index;
      return _blocks(
          compilation, source, bytes, statement.body, names, regionEnd, owner);
    case IfStatement():
      return _branch(compilation, source, bytes, statement.thenBody,
              statement.elseBody, outer, regionEnd, owner) ??
          _branch(compilation, source, bytes, statement.elseBody, const [],
              outer, regionEnd, owner);
    case WhileStatement():
      if (statement.elseBody.isNotEmpty &&
          bytes >= statement.elseBody.first.span.offset) {
        return _blocks(compilation, source, bytes, statement.elseBody, outer,
            regionEnd, owner);
      }
      if (!_past(bytes, statement.condition.span)) return null;
      final names = Map<String, Symbol>.of(outer);
      final symbol = compilation.semantics.declarations[statement];
      if (symbol != null && statement.letName != null) {
        names[symbol.name] = symbol;
      }
      return _blocks(
          compilation, source, bytes, statement.body, names, regionEnd, owner);
    case GuardedStatement():
      final names = Map<String, Symbol>.of(outer);
      final symbol = compilation.semantics.declarations[statement];
      if (symbol != null && statement.letName != null) {
        names[symbol.name] = symbol;
      }
      return _enter(compilation, source, bytes, statement.statement, names,
              regionEnd, owner) ??
          _Here(names, owner);
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
      final otherwise = _insideList(compilation, source, bytes,
          statement.elseBody, outer, regionEnd, owner);
      if (otherwise != null) return otherwise;
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
    case OnceStatement():
      return _insideList(
          compilation, source, bytes, statement.body, outer, regionEnd, owner);
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
      case FieldDeclaration():
        final lazy = member.lazyBody;
        if (lazy == null) return null;
        final names = Map<String, Symbol>.of(outer);
        if (!member.isStatic) _instanceMembers(compilation, type, names);
        return _blocks(compilation, source, bytes, lazy, names, next, type);
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

Iterable<(ClassDeclaration, String)> _typedLineage(
    Compilation compilation, String type,
    [Set<ClassDeclaration> seen = const {}]) sync* {
  type =
      nonNullableType(stripReadonlyType(compilation.semantics.resolve(type)));
  final declaration = readonlyClassFor(compilation.semantics, type);
  if (declaration == null || seen.contains(declaration)) return;
  yield (declaration, type);
  final args = _typeArgs(declaration, type);
  final visited = {...seen, declaration};
  for (final mixin in declaration.mixins.reversed)
    yield* _typedLineage(compilation, _applyArgs(mixin, args), visited);
  if (declaration.superclass != null)
    yield* _typedLineage(
        compilation, _applyArgs(declaration.superclass!, args), visited);
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
  final chain = _chainType(compilation, source, dot, scope);
  if (chain != null) {
    _typeMembers(compilation, chain, null, false, range, add,
        accessOwner: scope.owner);
    return;
  }
  final symbol = name == null ? null : scope.names[name];
  if (symbol != null && symbol.namespace != null && symbol.type == 'prefix') {
    for (final entry in symbol.namespace!.entries) {
      for (final item in _symbolItems(compilation, entry.value, range)) {
        add(item);
      }
    }
    return;
  }
  final referenced = symbol ?? _bestSymbol(compilation, source, dot);
  if (referenced != null &&
      referenced.namespace != null &&
      referenced.type != 'prefix') {
    for (final entry in referenced.namespace!.entries) {
      for (final item in _symbolItems(compilation, entry.value, range)) {
        add(item);
      }
    }
    if (referenced.external && referenced.type == referenced.name) return;
  }
  final onType = symbol != null &&
      (symbol.nativeTop?.isType == true ||
          symbol.classDeclaration != null && symbol.classCase == null);
  final type = onType
      ? symbol.classDeclaration?.name ?? symbol.type
      : symbol?.type ?? _expressionType(compilation, source, dot);
  if (type == null || type == 'prefix') return;
  _typeMembers(compilation, type, symbol?.classDeclaration, onType, range, add,
      accessOwner: scope.owner);
}

/// Type of `a.b.c` before [dot], using the cached analysis only.
String? _chainType(
    Compilation compilation, String source, int dot, _Here scope) {
  final steps = _chain(source, dot);
  if (steps == null || steps.length < 2) return null;
  var type = _rootType(compilation, scope, steps.first.name);
  if (steps.first.call) type = _returnType(type);
  if (steps.first.index) type = _elementType(type);
  if (type == null) return null;
  for (final step in steps.skip(1)) {
    final current = type;
    if (current == null) return null;
    if (step.name.isNotEmpty) {
      type = _memberType(compilation, current, step.name);
    }
    if (step.call) type = _returnType(type);
    if (step.index) type = _elementType(type);
    if (type == null || type == '<infer>') return null;
  }
  return type;
}

String? _rootType(Compilation compilation, _Here scope, String name) {
  final symbol = scope.names[name];
  if (symbol != null && symbol.type.isNotEmpty && symbol.type != 'prefix') {
    return symbol.type;
  }
  final owner = scope.owner;
  if (owner == null) return null;
  return _memberType(compilation, owner.name, name);
}

String? _memberType(Compilation compilation, String type, String name) {
  var bare = type.startsWith('readonly ') ? type.substring(9) : type;
  if (bare.endsWith('?')) bare = bare.substring(0, bare.length - 1);
  if (bare.startsWith('Event<') && bare.endsWith('>') && name == 'add') {
    final payload = bare.substring(6, bare.length - 1);
    return '($payload) -> void';
  }
  final declaration = readonlyClassFor(compilation.semantics, bare);
  if (declaration != null) {
    for (final (current, instantiated) in _typedLineage(compilation, bare)) {
      final args = _typeArgs(current, instantiated);
      for (final field in current.fields) {
        if (field.name != name) continue;
        final shown =
            compilation.semantics.declarations[field]?.type ?? field.type;
        return _applyArgs(shown, args);
      }
      for (final property in current.properties) {
        if (property.name == name) return _applyArgs(property.type, args);
      }
      for (final method in current.methods) {
        if (method.name != name || method.isOperator) continue;
        final shown = compilation.semantics.declarations[method]?.type ??
            method.returnType ??
            'void';
        return _applyArgs(shown, args);
      }
    }
  }
  for (final extension in compilation.semantics.extensions) {
    final args = _extensionArgs(compilation, extension, bare);
    if (args == null) continue;
    for (final method in extension.methods) {
      if (method.name != name) continue;
      return _applyArgs(
          compilation.semantics.declarations[method]?.type ??
              method.returnType ??
              'void',
          args);
    }
    for (final property in extension.properties) {
      if (property.name == name) return _applyArgs(property.type, args);
    }
  }
  final family = _family(bare);
  if (family != null) {
    final groups = family.$1 == 'List' || family.$1 == 'Set'
        ? [family.$1, 'Iterable']
        : [family.$1];
    for (final group in groups) {
      final getter = _getters[group]?[name];
      if (getter != null) return _subst(getter, family.$2);
      final method = _methods[group]?[name];
      if (method != null) return _subst(method.$2, family.$2);
    }
  }
  final shape = compilation
      .semantics.dartShapes[_head(compilation.semantics.resolve(bare))];
  return shape == null
      ? null
      : instantiateDartShape(shape, compilation.semantics.resolve(bare))
          .members[name]
          ?.type;
}

Map<String, String> _typeArgs(ClassDeclaration type, String applied) {
  if (type.typeParameters.isEmpty || !applied.contains('<')) {
    return const {};
  }
  final close = applied.lastIndexOf('>');
  if (close < 0) return const {};
  final parts = _split(applied.substring(applied.indexOf('<') + 1, close));
  if (parts.length != type.typeParameters.length) return const {};
  return {
    for (var i = 0; i < parts.length; i++) type.typeParameters[i].name: parts[i]
  };
}

String _applyArgs(String type, Map<String, String> args) {
  if (args.isEmpty || type == '<infer>') return type;
  return type.replaceAllMapped(RegExp(r'[A-Za-z_][A-Za-z0-9_]*'), (match) {
    return args[match.group(0)!] ?? match.group(0)!;
  });
}

String? _elementType(String? type) {
  if (type == null) return null;
  var bare = type.endsWith('?') ? type.substring(0, type.length - 1) : type;
  if (bare == 'String') return 'String';
  final family = _family(bare);
  if (family == null) return null;
  if (family.$1 == 'Map') return family.$2['V'];
  return family.$2['T'];
}

String? _returnType(String? type) {
  if (type == null) return null;
  final arrow = type.lastIndexOf('->');
  if (arrow < 0) return type;
  return type.substring(arrow + 2).trim();
}

class _Step {
  const _Step(this.name, {this.call = false, this.index = false});
  final String name;
  final bool call;
  final bool index;
}

/// `a.b.c` or `a.b()` ending at [dot]. One name is not a chain.
List<_Step>? _chain(String source, int dot) {
  final steps = <_Step>[];
  var index = dot;
  while (true) {
    if (index > 0 && source.codeUnitAt(index - 1) == 63) index--;
    while (index > 0 && _space(source.codeUnitAt(index - 1))) index--;
    if (index == 0) return null;
    final unit = source.codeUnitAt(index - 1);
    if (_ident(unit)) {
      final end = index;
      while (index > 0 && _ident(source.codeUnitAt(index - 1))) index--;
      final text = source.substring(index, end);
      if (_digit(text.codeUnitAt(0))) return null;
      steps.add(_Step(text));
    } else if (unit == 41 || unit == 93) {
      final open = unit == 41 ? 40 : 91;
      final start = _skipBack(source, index - 1, open, unit);
      if (start < 0) return null;
      index = start;
      var called = '';
      var cursor = index;
      while (cursor > 0 && _space(source.codeUnitAt(cursor - 1))) cursor--;
      if (cursor > 0 && _ident(source.codeUnitAt(cursor - 1))) {
        final end = cursor;
        while (cursor > 0 && _ident(source.codeUnitAt(cursor - 1))) cursor--;
        called = source.substring(cursor, end);
        if (_digit(called.codeUnitAt(0))) return null;
        index = cursor;
      }
      steps.add(_Step(called, call: unit == 41, index: unit == 93));
    } else {
      return null;
    }
    while (index > 0 && _space(source.codeUnitAt(index - 1))) index--;
    if (index > 1 &&
        source.codeUnitAt(index - 1) == 46 &&
        source.codeUnitAt(index - 2) != 46) {
      index--;
      continue;
    }
    break;
  }
  if (steps.length < 2) return null;
  return steps.reversed.toList();
}

int _skipBack(String source, int close, int open, int shut) {
  var depth = 0;
  for (var i = close; i >= 0; i--) {
    final unit = source.codeUnitAt(i);
    if (unit == shut) depth++;
    if (unit == open) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

int _lineStart(String source, int index) {
  var start = index;
  while (start > 0 && source.codeUnitAt(start - 1) != 10) start--;
  return start;
}

Expression? _receiverExpression(
    Compilation compilation, String source, int dot) {
  final positions = SourceIndex(source);
  final end = positions.byteOffset(dot);
  // Only an expression ending in the contiguous suffix of ')' or whitespace
  // can be the receiver. Reject other AST nodes before any offset conversion.
  var suffix = dot;
  final closing = RegExp(r'^[)\s]$');
  while (suffix > 0 && closing.hasMatch(source.substring(suffix - 1, suffix)))
    suffix--;
  final earliest = positions.byteOffset(suffix);
  Expression? best;
  var size = 1 << 30;
  walkAst(compilation.program, (node) {
    if (node is! Expression) return;
    final stop = node.span.offset + node.span.length;
    if (stop > end || stop < earliest || end - stop > size) return;
    if (end - stop < size ||
        node.span.length < (best?.span.length ?? 1 << 30)) {
      size = end - stop;
      best = node;
    }
  });
  return best;
}

String? _expressionType(Compilation compilation, String source, int dot) {
  final node = _receiverExpression(compilation, source, dot);
  if (node == null) return null;
  if (node is Identifier) {
    final symbol = compilation.semantics.references[node];
    if (symbol != null) return symbol.type;
  }
  return compilation.semantics.types[node];
}

Symbol? _bestSymbol(Compilation compilation, String source, int dot) {
  final node = _receiverExpression(compilation, source, dot);
  return node == null ? null : compilation.semantics.references[node];
}

Map<String, String>? _extensionArgs(
    Compilation compilation, ExtensionDeclaration extension, String receiver) {
  final formals = extension.typeParameters.map((p) => p.name).toSet();
  final found = <String, String>{};
  bool match(String pattern, String actual) {
    pattern = compilation.semantics.resolve(pattern);
    actual = compilation.semantics.resolve(actual);
    if (formals.contains(pattern)) {
      final before = found[pattern];
      found[pattern] = actual;
      return before == null || before == actual;
    }
    if (pattern == actual || pattern == _head(actual)) return true;
    if (_head(pattern) != _head(actual) ||
        !pattern.endsWith('>') ||
        !actual.endsWith('>')) return false;
    final p = splitTypeList(
        pattern.substring(pattern.indexOf('<') + 1, pattern.length - 1));
    final a = splitTypeList(
        actual.substring(actual.indexOf('<') + 1, actual.length - 1));
    if (p.length != a.length) return false;
    for (var i = 0; i < p.length; i++) if (!match(p[i], a[i])) return false;
    return true;
  }

  if (!match(extension.target, receiver)) return null;
  for (final p in extension.typeParameters) {
    final bound = p.bound;
    final actual = found[p.name];
    if (bound == null ||
        bound == 'Object?' ||
        actual == null ||
        bound == actual) continue;
    if (bound == 'num' && const {'int', 'double', 'num'}.contains(actual))
      continue;
    if (bound == 'Object' && !isNullableType(actual)) continue;
    if (_typedLineage(compilation, actual).any((entry) => entry.$2 == bound))
      continue;
    return null;
  }
  return found;
}

bool _completionVisible(Compilation compilation, ClassDeclaration declaration,
    String visibility, ClassDeclaration? owner) {
  if (visibility != 'private' && visibility != 'protected') return true;
  final home = compilation.semantics.libraryOf[declaration] ?? '';
  final current = compilation.program.span.file;
  if (home.isEmpty || home == current || home == File(current).absolute.path)
    return true;
  return visibility == 'protected' &&
      owner != null &&
      _typedLineage(compilation, owner.name)
          .any((entry) => identical(entry.$1, declaration));
}

void _typeMembers(
    Compilation compilation,
    String type,
    ClassDeclaration? known,
    bool onType,
    Map<String, Object> range,
    void Function(Map<String, Object?>) add,
    {ClassDeclaration? accessOwner}) {
  var bare = stripReadonlyType(compilation.semantics.resolve(type));
  if (bare.endsWith('?')) bare = bare.substring(0, bare.length - 1);
  if (!onType && bare.startsWith('Event<') && bare.endsWith('>')) {
    final payload = bare.substring(6, bare.length - 1);
    add(_plain('add', 2, '($payload) -> void', range, sort: '1'));
    return;
  }
  final declaration = known ?? readonlyClassFor(compilation.semantics, bare);
  if (declaration != null) {
    final seen = <String>{};
    if (declaration.kind == 'enum') {
      if (onType) {
        for (final item in declaration.cases) {
          if (_name(item.name) && seen.add(item.name)) {
            add(_plain(item.name, 20, declaration.name, range, sort: '0'));
          }
        }
        if (seen.add('values')) {
          add(_plain('values', 5, 'List<${declaration.name}>', range,
              sort: '1'));
        }
      } else {
        if (seen.add('name')) {
          add(_plain('name', 10, 'String', range, sort: '0'));
        }
        if (seen.add('index')) {
          add(_plain('index', 10, 'int', range, sort: '0'));
        }
      }
    }
    for (final (current, instantiated) in _typedLineage(compilation, bare)) {
      final args = _typeArgs(current, instantiated);
      for (final field in current.fields) {
        if (!_completionVisible(
                compilation,
                current,
                field.name.startsWith('_') ? 'private' : field.visibility,
                accessOwner ?? known) ||
            field.isStatic != onType ||
            !_name(field.name) ||
            !seen.add(field.name)) continue;
        final shown = _applyArgs(
            compilation.semantics.declarations[field]?.type ?? field.type,
            args);
        add(_plain(
            field.name,
            5,
            compilation.semantics
                .displayType(field.mutable ? 'var $shown' : shown),
            range,
            sort: '0'));
      }
      for (final property in current.properties) {
        if (!_completionVisible(
                compilation,
                current,
                property.name.startsWith('_') ? 'private' : property.visibility,
                accessOwner ?? known) ||
            onType ||
            !_name(property.name) ||
            !seen.add(property.name)) continue;
        final reads = property.getter != null || property.getterBody != null;
        final writes = property.setter != null || property.setterBody != null;
        final kind = reads && writes
            ? 'property'
            : reads
                ? 'get'
                : 'set';
        add(_plain(property.name, 10,
            '$kind ${_applyArgs(property.type, args)}', range,
            sort: '0'));
      }
      for (final method in current.methods) {
        if (!_completionVisible(
                compilation,
                current,
                method.name.startsWith('_') ? 'private' : method.visibility,
                accessOwner ?? known) ||
            method.isStatic != onType ||
            method.isOperator ||
            !_name(method.name) ||
            !seen.add(method.name)) {
          continue;
        }
        add(_plain(
            method.name,
            2,
            _applyArgs(
                _signature(compilation, method),
                Map.of(args)
                  ..removeWhere((key, _) =>
                      method.typeParameters.any((p) => p.name == key))),
            range,
            sort: '1'));
      }
      if (onType) {
        if (identical(current, declaration)) {
          for (final constructor in current.constructors) {
            final ctorName = constructor.name;
            if (ctorName == null ||
                ctorName.isEmpty ||
                !_name(ctorName) ||
                !_completionVisible(
                    compilation,
                    current,
                    ctorName.startsWith('_') ? 'private' : '',
                    accessOwner ?? known) ||
                !seen.add(ctorName)) {
              continue;
            }
            final parameters = [
              for (final p in constructor.parameters)
                '${p.name}: ${_applyArgs(p.initializing.isEmpty ? p.type : _fieldType(current, p.name), args)}'
            ].join(', ');
            final kindPrefix = constructor.factory
                ? 'factory '
                : constructor.constant
                    ? 'const '
                    : '';
            add(_plain(
              ctorName,
              4,
              '$kindPrefix($parameters) -> ${compilation.semantics.displayType(instantiated)}',
              range,
              sort: '0',
            ));
          }
        }
        for (final item in current.cases) {
          add(_plain(item.name, 4, 'case ${current.name}', range, sort: '0'));
        }
      }
    }
  }
  if (!onType) {
    for (final extension in compilation.semantics.extensions) {
      final extensionArgs = _extensionArgs(compilation, extension, bare);
      if (extensionArgs == null) continue;
      for (final method in extension.methods) {
        if (!_name(method.name)) continue;
        add(_plain(method.name, 2,
            _applyArgs(_signature(compilation, method), extensionArgs), range,
            sort: '1'));
      }
      for (final property in extension.properties) {
        if (!_name(property.name)) continue;
        add(_plain(property.name, 10,
            'get ${_applyArgs(property.type, extensionArgs)}', range,
            sort: '0'));
      }
    }
  }
  final typed = compilation.semantics.classes.containsKey(_head(bare))
      ? null
      : compilation.semantics.dartShapes[_head(bare)]?.listElement;
  final builtinLabels = <String>{};
  _builtinMembers(typed == null ? bare : 'List<$typed>', onType, range, (item) {
    final label = item['label'];
    if (label is String) builtinLabels.add(label);
    add(item);
  });
  _sdkMembers(compilation, bare, onType, range, (item) {
    final label = item['label'];
    if (!onType && label is String && builtinLabels.contains(label)) return;
    add(item);
  });
}

void _sdkMembers(
  Compilation compilation,
  String type,
  bool onType,
  Map<String, Object> range,
  void Function(Map<String, Object?>) add,
) {
  final bare =
      nonNullableType(stripReadonlyType(compilation.semantics.resolve(type)));
  if (readonlyClassFor(compilation.semantics, bare) != null) return;
  final raw = compilation.semantics.dartShapes[_head(bare)];
  if (raw == null) return;
  final shape = instantiateDartShape(raw, bare);
  for (final member in (onType
          ? {
              ...shape.statics,
              for (final e in shape.constructors.entries)
                if (e.key.isNotEmpty) e.key: e.value
            }
          : shape.members)
      .values) {
    if (!_name(member.name)) continue;
    final isCtor = onType && shape.constructors.containsKey(member.name);
    if (member.getter) {
      add(_plain(member.name, 10,
          compilation.semantics.displayType(member.type), range,
          sort: '0'));
      continue;
    }
    final parameters = [
      for (final parameter in member.parameters)
        '${parameter.$1}: ${compilation.semantics.displayType(parameter.$2)}'
    ].join(', ');
    add(_plain(
        member.name,
        isCtor ? 4 : 2,
        '($parameters) -> ${compilation.semantics.displayType(member.type)}',
        range,
        sort: isCtor ? '0' : '1'));
  }
}

void _uncompiledDart(
  String source,
  int dot,
  Map<String, Object> range,
  void Function(Map<String, Object?>) add,
) {
  final name = _receiverName(source, dot);
  if (name == null) return;
  final imported = _dartImport(source, name);
  if (imported != null) {
    final surface = imported.$1;
    for (final top in imported.$2) {
      for (final item in _symbolItems(
          null, symbolForDart(top, surface.types[top.name]), range)) {
        add(item);
      }
    }
    return;
  }
  final start = _receiverStart(source, dot);
  if (start <= 0 || source[start - 1] != '.') return;
  final owner = _receiverName(source, start - 1);
  if (owner == null) return;
  final library = _dartImport(source, owner);
  if (library == null) return;
  final shape = library.$1.types[name];
  if (shape == null) return;
  _emitDartTypeMembers(shape, name, range, add);
}

void _uncompiledCore(
  String source,
  int dot,
  Map<String, Object> range,
  void Function(Map<String, Object?>) add,
) {
  final name = _receiverName(source, dot);
  if (name == null) return;
  final start = _receiverStart(source, dot);
  if (start > 0 && source[start - 1] == '.') return;
  final surface = readDartLibrary('dart:core');
  final shape = surface?.types[name];
  if (shape == null) return;
  _emitDartTypeMembers(shape, name, range, add);
}

void _emitDartTypeMembers(
  DartShape shape,
  String ownerName,
  Map<String, Object> range,
  void Function(Map<String, Object?>) add,
) {
  for (final member in [
    ...shape.constructors.entries
        .where((entry) => entry.key.isNotEmpty)
        .map((entry) => entry.value),
    ...shape.statics.values,
  ]) {
    if (!_name(member.name)) continue;
    final isCtor = shape.constructors.containsKey(member.name);
    if (member.getter) {
      add(_plain(member.name, 10, member.type, range, sort: '0'));
      continue;
    }
    final parameters = [
      for (final parameter in member.parameters)
        '${parameter.$1}: ${parameter.$2}'
    ].join(', ');
    add(_plain(
        member.name, isCtor ? 4 : 2, '($parameters) -> ${member.type}', range,
        sort: isCtor ? '0' : '1'));
  }
}

int _receiverStart(String source, int dot) {
  var index = dot;
  if (index > 0 && source.codeUnitAt(index - 1) == 63) index--;
  while (index > 0 && _space(source.codeUnitAt(index - 1))) {
    index--;
  }
  if (index > 0 && source.codeUnitAt(index - 1) == 62) {
    final open = _skipBack(source, index - 1, 60, 62);
    if (open > 0 && _ident(source.codeUnitAt(open - 1))) {
      index = open;
    }
  }
  final end = index;
  while (index > 0 && _ident(source.codeUnitAt(index - 1))) {
    index--;
  }
  return index == end ? -1 : index;
}

(DartSurface, List<DartTop>)? _dartImport(String source, String prefix) {
  final match = RegExp(
    '^\\s*use\\s+(dart:[A-Za-z0-9_]+)\\s+as\\s+$prefix\\b([^\\n]*)',
    multiLine: true,
  ).firstMatch(source);
  if (match == null) return null;
  final surface = readDartLibrary(match.group(1)!);
  if (surface == null) return null;
  final clause = match.group(2)!.split(RegExp(r'\bwhen\b')).first;
  final show = RegExp(r'\bshow\s+([A-Za-z0-9_,\s]+)').firstMatch(clause);
  final hide = RegExp(r'\bhide\s+([A-Za-z0-9_,\s]+)').firstMatch(clause);
  Iterable<DartTop> names = surface.names.values;
  if (show != null) {
    final wanted = show
        .group(1)!
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    names = names.where((item) => wanted.contains(item.name));
  } else if (hide != null) {
    final hidden = hide
        .group(1)!
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    names = names.where((item) => !hidden.contains(item.name));
  }
  return (surface, names.toList());
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
  if (type == 'int' || type == 'double' || type == 'num') {
    return (type, const {});
  }
  if (type.startsWith('List<') && type.endsWith('>')) {
    return ('List', {'T': type.substring(5, type.length - 1)});
  }
  if (type.startsWith('Set<') && type.endsWith('>')) {
    return ('Set', {'T': type.substring(4, type.length - 1)});
  }
  if (type.startsWith('Iterable<') && type.endsWith('>')) {
    return ('Iterable', {'T': type.substring(9, type.length - 1)});
  }
  if (type.startsWith('Range<') && type.endsWith('>')) {
    return ('Iterable', {'T': type.substring(6, type.length - 1)});
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
    'single': 'T',
    'reversed': 'Iterable<T>',
  },
  'Set': {
    'length': 'int',
    'isEmpty': 'bool',
    'isNotEmpty': 'bool',
    'first': 'T',
    'last': 'T',
    'single': 'T',
  },
  'Iterable': {
    'length': 'int',
    'isEmpty': 'bool',
    'isNotEmpty': 'bool',
    'first': 'T',
    'last': 'T',
    'single': 'T',
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
    'chars': 'List<String>',
    'lines': 'List<String>',
  },
  'int': {
    'isFinite': 'bool',
    'isInfinite': 'bool',
    'isNaN': 'bool',
    'isNegative': 'bool',
    'abs': 'int',
    'round': 'int',
    'floor': 'int',
    'ceil': 'int',
    'plain': 'String',
  },
  'double': {
    'isFinite': 'bool',
    'isInfinite': 'bool',
    'isNaN': 'bool',
    'isNegative': 'bool',
    'abs': 'double',
    'round': 'int',
    'floor': 'int',
    'ceil': 'int',
    'plain': 'String',
  },
  'num': {
    'isFinite': 'bool',
    'isInfinite': 'bool',
    'isNaN': 'bool',
    'isNegative': 'bool',
    'abs': 'num',
    'round': 'int',
    'floor': 'int',
    'ceil': 'int',
    'plain': 'String',
  },
};

const _methods = {
  'List': {
    'add': ([('value', 'T')], 'void'),
    'addAll': ([('values', 'Iterable<T>')], 'void'),
    'setAll': ([('index', 'int'), ('values', 'Iterable<T>')], 'void'),
    'insert': ([('index', 'int'), ('value', 'T')], 'void'),
    'removeAt': ([('index', 'int')], 'T'),
    'removeLast': (<(String, String)>[], 'T'),
    'remove': ([('value', 'Object?')], 'bool'),
    'clear': (<(String, String)>[], 'void'),
    'sort': (<(String, String)>[], 'void'),
    'sublist': ([('start', 'int')], 'List<T>'),
    'indexOf': ([('value', 'T')], 'int'),
  },
  'Set': {
    'add': ([('value', 'T')], 'bool'),
    'addAll': ([('values', 'Iterable<T>')], 'void'),
    'remove': ([('value', 'Object?')], 'bool'),
    'clear': (<(String, String)>[], 'void'),
  },
  'Iterable': {
    'contains': ([('value', 'Object?')], 'bool'),
    'elementAt': ([('index', 'int')], 'T'),
    'join': ([('separator', 'String')], 'String'),
    'toList': (<(String, String)>[], 'List<T>'),
    'toSet': (<(String, String)>[], 'Set<T>'),
    'map': ([('transform', '(T) -> R')], 'List<R>'),
    'fold': ([('initial', 'R'), ('combine', '(R, T) -> R')], 'R'),
    'reduce': ([('combine', '(T, T) -> T')], 'T'),
    'sum': (<(String, String)>[], 'T'),
    'min': (<(String, String)>[], 'T?'),
    'max': (<(String, String)>[], 'T?'),
    'count': ([('test', '(T) -> bool')], 'int'),
    'find': ([('test', '(T) -> bool')], 'T?'),
    'findLast': ([('test', '(T) -> bool')], 'T?'),
    'take': ([('count', 'int')], 'List<T>'),
    'zip': ([('other', 'Iterable<U>')], 'List<(T, U)>'),
    'drop': ([('count', 'int')], 'List<T>'),
    'takeLast': ([('count', 'int')], 'List<T>'),
    'dropLast': ([('count', 'int')], 'List<T>'),
    'skip': ([('count', 'int')], 'List<T>'),
    'sorted': ([('compare', '(T, T) -> int')], 'List<T>'),
    'unique': (<(String, String)>[], 'List<T>'),
    'flat': (<(String, String)>[], 'List<E>'),
    'group': ([('key', '(T) -> K')], 'Map<K, List<T>>'),
    'where': ([('test', '(T) -> bool')], 'Iterable<T>'),
    'any': ([('test', '(T) -> bool')], 'bool'),
    'every': ([('test', '(T) -> bool')], 'bool'),
    'forEach': ([('action', '(T) -> void')], 'void'),
  },
  'Map': {
    'containsKey': ([('key', 'Object?')], 'bool'),
    'remove': ([('key', 'Object?')], 'V?'),
    'clear': (<(String, String)>[], 'void'),
    'addAll': ([('other', 'Map<K, V>')], 'void'),
    'putIfAbsent': ([('key', 'K'), ('ifAbsent', '() -> V')], 'V'),
    'forEach': ([('action', '(K, V) -> void')], 'void'),
  },
  'String': {
    'contains': ([('other', 'String')], 'bool'),
    'startsWith': ([('other', 'String')], 'bool'),
    'endsWith': ([('other', 'String')], 'bool'),
    'substring': ([('start', 'int'), ('end', 'int')], 'String'),
    'toUpperCase': (<(String, String)>[], 'String'),
    'toLowerCase': (<(String, String)>[], 'String'),
    'trim': (<(String, String)>[], 'String'),
    'split': ([('pattern', 'String')], 'List<String>'),
    'indexOf': ([('pattern', 'String')], 'int'),
    'replaceAll': ([('from', 'String'), ('to', 'String')], 'String'),
    'take': ([('count', 'int')], 'String'),
    'drop': ([('count', 'int')], 'String'),
    'takeLast': ([('count', 'int')], 'String'),
    'dropLast': ([('count', 'int')], 'String'),
    'padStart': ([('width', 'int'), ('fill', 'String')], 'String'),
    'padEnd': ([('width', 'int'), ('fill', 'String')], 'String'),
  },
  'int': {
    'clamp': ([('lower', 'int'), ('upper', 'int')], 'int'),
    'pad': ([('width', 'int')], 'String'),
    'fixed': ([('digits', 'int')], 'String'),
  },
  'double': {
    'clamp': ([('lower', 'double'), ('upper', 'double')], 'double'),
    'fixed': ([('digits', 'int')], 'String'),
  },
  'num': {
    'clamp': ([('lower', 'num'), ('upper', 'num')], 'num'),
    'fixed': ([('digits', 'int')], 'String'),
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
  if (nameEnd > 0 && source.codeUnitAt(nameEnd - 1) == 62) {
    final start = _skipBack(source, nameEnd - 1, 60, 62);
    if (start < 0) return null;
    nameEnd = start;
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

_Call? _argumentBlock(String source, int cursor) {
  final start = _lineStart(source, cursor);
  final indent = source.substring(start, cursor).length -
      source.substring(start, cursor).trimLeft().length;
  var end = start;
  while (end > 0) {
    var from = end - 1;
    if (from > 0 && source.codeUnitAt(from) == 10) from--;
    from = _lineStart(source, from);
    final line = source.substring(from, end).trimRight();
    end = from;
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final leading = line.length - line.trimLeft().length;
    if (leading >= indent) continue;
    if (!line.endsWith(':') ||
        RegExp(r'^(class|interface|extend|mixin|enum|sealed|value|abstract|final|base)\b')
            .hasMatch(line.trimLeft())) return null;
    final colon = from + line.length - 1;
    final nameStart = _calleeStart(source, colon);
    var nameEnd = colon;
    while (nameEnd > nameStart && _space(source.codeUnitAt(nameEnd - 1)))
      nameEnd--;
    if (nameEnd > 0 && source.codeUnitAt(nameEnd - 1) == 62)
      nameEnd = _skipBack(source, nameEnd - 1, 60, 62);
    if (nameEnd <= nameStart) return null;
    return _Call(colon, source.substring(nameStart, nameEnd),
        nameStart > 0 && source.codeUnitAt(nameStart - 1) == 46);
  }
  return null;
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
    } else if (symbol.nativeTop != null) {
      parameters = [
        for (final p in symbol.nativeTop!.parameters) _Param(p.$1, p.$2)
      ];
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
    add(_plain(parameter.name, 5,
        compilation.semantics.displayType(parameter.type), range,
        insert: '${parameter.name}: ', sort: '0', commit: false));
  }
}

int _calleeStart(String source, int paren) {
  var nameEnd = paren;
  while (nameEnd > 0 && _space(source.codeUnitAt(nameEnd - 1))) {
    nameEnd--;
  }
  if (nameEnd > 0 && source.codeUnitAt(nameEnd - 1) == 62) {
    final start = _skipBack(source, nameEnd - 1, 60, 62);
    if (start >= 0) nameEnd = start;
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
  if (source.codeUnitAt(paren) == 58) {
    final lines = slice
        .split('\n')
        .skip(1)
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final indents =
        lines.map((line) => line.length - line.trimLeft().length).toList();
    if (indents.isEmpty) return names;
    final level = indents.reduce((a, b) => a < b ? a : b);
    for (var i = 0; i < lines.length; i++) {
      if (indents[i] != level) continue;
      final match = RegExp(r'^\s*([^\s:]+)\s*:').firstMatch(lines[i]);
      if (match != null) names.add(match[1]!);
    }
    return names;
  }
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
  final imported = symbol.namespace?[member];
  if (imported != null) {
    final parameters =
        imported.nativeTop?.parameters ?? imported.nativeMember?.parameters;
    if (parameters != null) {
      for (final p in parameters) yield _Param(p.$1, p.$2);
      return;
    }
    for (final function in imported.overloads)
      for (final p in function.parameters) yield _Param(p.name, p.type);
    if (imported.overloads.isNotEmpty) return;
  }
  final declaration = symbol.classDeclaration;
  if (declaration != null && symbol.classCase == null) {
    for (final constructor in declaration.constructors) {
      if (constructor.name != member) continue;
      for (final p in constructor.parameters) {
        yield _Param(
          p.name,
          p.initializing.isEmpty ? p.type : _fieldType(declaration, p.name),
        );
      }
      return;
    }
  }
  final type = compilation.semantics
      .resolve(symbol.classDeclaration?.name ?? symbol.type);
  final raw = compilation.semantics.dartShapes[_head(type)];
  if (raw != null && readonlyClassFor(compilation.semantics, type) == null) {
    final shape = instantiateDartShape(raw, type);
    final method = (symbol.nativeTop?.isType == true
            ? (shape.statics[member] ?? shape.constructors[member])
            : shape.members[member]) ??
        shape.members[member];
    if (method != null)
      for (final p in method.parameters) yield _Param(p.$1, p.$2);
    return;
  }
  for (final (current, applied) in _typedLineage(compilation, type)) {
    for (final method in current.methods) {
      if (method.name != member) continue;
      final args = Map.of(_typeArgs(current, applied))
        ..removeWhere(
            (key, _) => method.typeParameters.any((p) => p.name == key));
      for (final p in method.parameters)
        yield _Param(p.name, _applyArgs(p.type, args));
      return;
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
  return compilation.semantics.displayType('($parameters) -> $returned');
}

List<Map<String, Object?>> _symbolItems(
    Compilation? compilation, Symbol symbol, Map<String, Object> range) {
  if (symbol.namespace != null && symbol.type == 'prefix') {
    return [_plain(symbol.name, 9, 'prefix', range, sort: '1')];
  }
  if (symbol.nativeTop?.isType == true)
    return [
      _plain(
          symbol.name,
          7,
          compilation?.semantics
                  .displayType(symbol.signature ?? 'class ${symbol.name}') ??
              symbol.signature ??
              'class ${symbol.name}',
          range,
          sort: '0')
    ];
  if (symbol.external &&
      symbol.type == symbol.name &&
      symbol.classDeclaration == null &&
      symbol.classCase == null) {
    return [_plain(symbol.name, 7, 'class ${symbol.name}', range, sort: '0')];
  }
  if (symbol.signature != null &&
      symbol.function == null &&
      symbol.overloads.isEmpty &&
      symbol.classCase == null &&
      symbol.classDeclaration == null) {
    final kind = symbol.constant
        ? 21
        : (symbol.callable || symbol.parameterTypes.isNotEmpty)
            ? 3
            : 6;
    return [
      _plain(
          symbol.name,
          kind,
          compilation?.semantics.displayType(symbol.signature!) ??
              symbol.signature!,
          range,
          sort: '1')
    ];
  }
  if ((symbol.callable || symbol.parameterTypes.isNotEmpty) &&
      symbol.function == null &&
      symbol.overloads.isEmpty) {
    final parameters = symbol.parameterTypes.join(', ');
    return [
      _plain(symbol.name, 3, '($parameters) -> ${symbol.type}', range,
          sort: '1')
    ];
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
    RegExp(r'^[\p{L}\p{Nl}_$][\p{L}\p{Nl}\p{N}\p{M}_$]*$', unicode: true)
        .hasMatch(value);

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
      if (!raw &&
          (unit == 123 || unit == 125) &&
          cursor + 1 < source.length &&
          source.codeUnitAt(cursor + 1) == unit) {
        cursor += 2;
        continue;
      }
      if (!raw && unit == 123) {
        interpolations.add(1);
        cursor++;
        continue;
      }
      if (triple &&
          unit == quote &&
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

const _retrigger = {
  'command': 'editor.action.triggerSuggest',
  'title': 'Suggest',
};

/// Completion for a library directive URI, or null outside one.
List<Map<String, Object?>>? _importCompletion(
    String source, int cursor, String? file) {
  final lineStart = cursor == 0 ? 0 : source.lastIndexOf('\n', cursor - 1) + 1;
  final line = source.substring(lineStart, cursor);
  final trimmed = line.trimLeft();
  final keyword = trimmed.startsWith('export')
      ? 'export'
      : trimmed.startsWith('use')
          ? 'use'
          : trimmed.startsWith('part')
              ? 'part'
              : null;
  if (keyword == null) return null;
  if (trimmed.length > keyword.length &&
      _ident(trimmed.codeUnitAt(keyword.length))) {
    return null;
  }
  var index = lineStart + (line.length - trimmed.length) + keyword.length;
  while (index < cursor && _space(source.codeUnitAt(index))) {
    index++;
  }
  if (keyword == 'part') {
    if (trimmed == 'part') return null;
    final rest = source.substring(index, cursor);
    final of = RegExp(r'^of[ \t]+').firstMatch(rest);
    if (of != null) index += of.end;
    final uri = source.substring(index, cursor);
    final items = uri == 'of' && of == null
        ? <Map<String, Object?>>[]
        : _relativeCompletion(source, cursor, index, uri, file,
            partsOnly: true);
    if (of == null && 'of'.startsWith(uri)) {
      items.insert(0, {
        ..._importItem(source, index, cursor, 'of', 'of ', 'part of', 14,
            retrigger: true),
        'documentation': {
          'kind': 'markdown',
          'value': keywordDocumentation['of']!
        },
      });
    }
    return items;
  }
  final uri = source.substring(index, cursor);
  if (RegExp(r'\s+(?:as|show|hide|when)\b').hasMatch(uri)) return null;
  if (uri.isEmpty) {
    return [
      _importItem(source, cursor, cursor, 'dart:', 'dart:', 'scheme', 9,
          retrigger: true),
      _importItem(source, cursor, cursor, 'package:', 'package:', 'scheme', 9,
          retrigger: true),
      _importItem(source, cursor, cursor, 'quds:', 'quds:', 'scheme', 9,
          retrigger: true),
      ..._relativeEntries(source, cursor, cursor, '', const [], file),
    ];
  }
  if (uri.startsWith('dart:')) {
    final partial = uri.substring(5);
    if (partial.contains('/') ||
        partial.contains('.') ||
        partial.contains(':')) {
      return const [];
    }
    final start = cursor - partial.length;
    return [
      for (final name in dartLibraryNames())
        if (name.startsWith(partial))
          _importItem(source, start, cursor, name, name, 'dart:$name', 9),
    ];
  }
  if (uri.startsWith('package:')) {
    return _packageCompletion(source, cursor, uri.substring(8), file);
  }
  if (uri.startsWith('quds:')) {
    final partial = uri.substring(5);
    if (partial.contains('/') || partial.contains('.')) return const [];
    final marker = partial.indexOf('::');
    if (marker < 0) {
      if (partial.contains(':')) return const [];
      final start = cursor - partial.length;
      final items = <Map<String, Object?>>[];
      for (final name in sdkLibraryNames()) {
        if (!name.startsWith(partial)) continue;
        items.add(
            _importItem(source, start, cursor, name, name, 'quds:$name', 9));
        if (sdkSectionNames(name).isNotEmpty) {
          items.add(_importItem(
              source, start, cursor, '$name::', '$name::', 'quds:$name::', 9,
              retrigger: true));
        }
      }
      return items;
    }
    return _sectionItems(
        source,
        cursor,
        partial.substring(marker + 2),
        sdkSectionNames(partial.substring(0, marker)),
        'quds:${partial.substring(0, marker)}');
  }
  return _relativeCompletion(source, cursor, index, uri, file);
}

/// Completions after `library::`. Only the next path segment is offered.
List<Map<String, Object?>> _sectionItems(String source, int cursor, String rest,
    List<String> sections, String libraryLabel) {
  if (libraryLabel.startsWith('quds:') &&
      !sdkLibraryNames().contains(libraryLabel.substring(5))) {
    return const [];
  }
  if (RegExp(r'(?<!:):(?!:)').hasMatch(rest)) return const [];
  final splitAt = rest.lastIndexOf('::');
  final parent = splitAt < 0 ? '' : rest.substring(0, splitAt);
  final typed = splitAt < 0 ? rest : rest.substring(splitAt + 2);
  if (parent.isNotEmpty && !librarySectionPattern.hasMatch(parent)) {
    return const [];
  }
  final heads = <String>{};
  final deeper = <String>{};
  for (final section in sections) {
    final String tail;
    if (parent.isEmpty) {
      tail = section;
    } else if (section.startsWith('$parent::')) {
      tail = section.substring(parent.length + 2);
    } else {
      continue;
    }
    final head = tail.split('::').first;
    if (!head.startsWith(typed)) continue;
    heads.add(head);
    if (tail.contains('::')) deeper.add(head);
  }
  final start = cursor - typed.length;
  final prefix = parent.isEmpty ? '' : '$parent::';
  final items = <Map<String, Object?>>[];
  final labels = heads.toList()..sort();
  for (final head in labels) {
    final path = '$prefix$head';
    items.add(_importItem(
        source, start, cursor, head, head, '$libraryLabel::$path', 9));
    if (deeper.contains(head)) {
      items.add(_importItem(source, start, cursor, '$head::', '$head::',
          '$libraryLabel::$path::', 9,
          retrigger: true));
    }
  }
  return items;
}

String? _importedQudsFile(String? from, String libraryText) {
  if (from == null || from == '<input>' || libraryText.isEmpty) return null;
  final normalized = normalizeImportUri(libraryText);
  if (librarySection(normalized) != null) return null;
  final path = resolveLibraryPath(from, normalized);
  if (path == null || !File(path).existsSync()) return null;
  return path;
}

List<Map<String, Object?>> _packageCompletion(
    String source, int cursor, String rest, String? file) {
  final sectionMarker = rest.indexOf('::');
  if (sectionMarker >= 0) {
    final target = 'package:${rest.substring(0, sectionMarker)}';
    final path = _importedQudsFile(file, target);
    if (path == null ||
        (file != null && externalInternalPackageOwner(file, path) != null)) {
      return const [];
    }
    return _sectionItems(source, cursor, rest.substring(sectionMarker + 2),
        fileSectionNames(path), target);
  }
  final libraries = file == null || file == '<input>'
      ? const <PackageLibrary>[]
      : packageLibraries(file);
  final current =
      file == null || file == '<input>' ? null : packageRoot(file)?.name;
  final slash = rest.indexOf('/');
  if (slash < 0 && rest.contains('.')) {
    return _dottedPackage(source, cursor, rest, libraries, current, file);
  }
  if (slash < 0) {
    final start = cursor - rest.length;
    final items = <Map<String, Object?>>[];
    for (final library in libraries) {
      if (!library.name.startsWith(rest)) continue;
      items.add(_importItem(source, start, cursor, library.name, library.name,
          'package:${library.name}', 9));
      final entryQuds =
          File(_joinImport(library.libDirectory, '${library.name}.quds'));
      if (entryQuds.existsSync() &&
          fileSectionNames(entryQuds.path).isNotEmpty) {
        items.add(_importItem(source, start, cursor, '${library.name}::',
            '${library.name}::', 'package:${library.name}::', 9,
            retrigger: true));
      }
    }
    final lib = current == null || file == null
        ? null
        : Directory(
            '${packageRoot(file)!.directory}${Platform.pathSeparator}lib');
    items.addAll(_namedFiles(source, start, cursor, rest, lib, quds: true));
    return items;
  }
  final name = rest.substring(0, slash);
  final path = rest.substring(slash + 1);
  final library = _libraryNamed(libraries, name);
  final separator = path.lastIndexOf('/');
  final parent = separator < 0 ? '' : path.substring(0, separator);
  final partial = separator < 0 ? path : path.substring(separator + 1);
  final dot = partial.lastIndexOf('.');
  final directory = _packageDirectory(library, current, name, file, parent);
  final externalPackage = current != name;
  final inExternalInternal = externalPackage && _isInternalRelative(parent);
  if (dot >= 0 && partial.endsWith('.') == false) {
    final folder = partial.substring(0, dot);
    final nested = Directory(_joinImport(directory?.path ?? '', folder));
    if (directory != null && nested.existsSync()) {
      final at = cursor - (partial.length - dot);
      final nestedInternal = externalPackage &&
          _isInternalRelative(parent.isEmpty ? folder : '$parent/$folder');
      return _directoryEntries(source, at, cursor, partial.substring(dot + 1),
          nested, _packageFile(current, name),
          externalLibRoot: false, hideQuds: nestedInternal);
    }
  }
  if (partial.endsWith('.')) {
    final folder = partial.substring(0, partial.length - 1);
    final nested = folder.isEmpty
        ? directory
        : Directory(_joinImport(directory?.path ?? '', folder));
    final nestedInternal = externalPackage &&
        _isInternalRelative(folder.isEmpty
            ? parent
            : (parent.isEmpty ? folder : '$parent/$folder'));
    return _directoryEntries(
        source, cursor - 1, cursor, '', nested, _packageFile(current, name),
        externalLibRoot: externalPackage && parent.isEmpty && folder.isEmpty,
        hideQuds: nestedInternal);
  }
  final start = cursor - partial.length;
  return _directoryEntries(
      source, start, cursor, partial, directory, _packageFile(current, name),
      externalLibRoot: externalPackage && parent.isEmpty,
      hideQuds: inExternalInternal);
}

List<Map<String, Object?>> _dottedPackage(
  String source,
  int cursor,
  String rest,
  List<PackageLibrary> libraries,
  String? current,
  String? file,
) {
  final parts = rest.split('.');
  if (parts.isEmpty || parts.first.isEmpty) return const [];
  if (parts.take(parts.length - 1).any((part) => part.isEmpty)) {
    return const [];
  }
  final package = parts.first;
  final partial = parts.last;
  final folders = parts.sublist(1, parts.length - 1);
  final root = _packageDirectory(
      _libraryNamed(libraries, package), current, package, file, '');
  if (root == null || !root.existsSync()) return const [];
  var directory = root;
  for (final folder in folders) {
    directory = Directory(_joinImport(directory.path, folder));
    if (!directory.existsSync()) return const [];
  }
  final externalPackage = current != package;
  final inExternalInternal = externalPackage &&
      folders.isNotEmpty &&
      (folders.first == 'src' || folders.first == 'internal');
  final start = cursor - partial.length;
  final items = <Map<String, Object?>>[];
  final seenStems = <String>{};
  for (final entity in _children(directory)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.startsWith('.') || name.startsWith('_')) continue;
    if (entity is Directory) {
      if (externalPackage &&
          folders.isEmpty &&
          (name == 'src' || name == 'internal') &&
          _isQudsInternalDirectory(entity)) {
        continue;
      }
      if (!name.startsWith(partial)) continue;
      items.add(_importItem(
          source, start, cursor, name, '$name.', 'directory', 19,
          retrigger: true));
    } else if (entity is File &&
        (name.endsWith('.dart') || name.endsWith('.quds'))) {
      if (inExternalInternal && name.endsWith('.quds')) continue;
      final stem = name.substring(0, name.length - 5);
      if (stem.isEmpty || stem.startsWith('_') || !stem.startsWith(partial)) {
        continue;
      }
      if (!seenStems.add(stem)) continue;
      items.add(_importItem(source, start, cursor, stem, stem, name, 17));
      if (name.endsWith('.quds') && fileSectionNames(entity.path).isNotEmpty) {
        items.add(_importItem(
            source, start, cursor, '$stem::', '$stem::', name, 17,
            retrigger: true));
      }
    }
  }
  items.sort((a, b) => (a['label'] as String).compareTo(b['label'] as String));
  return items;
}

bool _isInternalRelative(String parent) {
  if (parent.isEmpty) return false;
  final first = parent.split('/').first;
  return first == 'src' || first == 'internal';
}

bool _isQudsInternalDirectory(Directory directory) {
  var hasQuds = false;
  var hasDart = false;
  void scan(Directory dir) {
    for (final entity in _children(dir)) {
      if (entity is File) {
        if (entity.path.endsWith('.quds')) hasQuds = true;
        if (entity.path.endsWith('.dart')) hasDart = true;
      } else if (entity is Directory) {
        scan(entity);
      }
      if (hasQuds) return;
    }
  }

  scan(directory);
  return hasQuds || !hasDart;
}

bool _packageFile(String? current, String name) => current != name;

PackageLibrary? _libraryNamed(List<PackageLibrary> libraries, String name) {
  for (final library in libraries) {
    if (library.name == name) return library;
  }
  return null;
}

Directory? _packageDirectory(PackageLibrary? library, String? current,
    String name, String? file, String parent) {
  String? root;
  if (library != null && (current == null || name != current)) {
    root = library.libDirectory;
  } else if (current != null && name == current && file != null) {
    root = '${packageRoot(file)!.directory}${Platform.pathSeparator}lib';
  }
  if (root == null) return null;
  if (parent.isEmpty) return Directory(root);
  return Directory(_joinImport(root, parent));
}

List<Map<String, Object?>> _relativeCompletion(
    String source, int cursor, int uriStart, String uri, String? file,
    {bool partsOnly = false}) {
  final marker = uri.indexOf('::');
  if (marker >= 0) {
    if (partsOnly) return const [];
    final library = uri.substring(0, marker);
    final path = _importedQudsFile(file, library);
    if (path == null) return const [];
    return _sectionItems(source, cursor, uri.substring(marker + 2),
        fileSectionNames(path), library);
  }
  var body = uri;
  var from = uriStart;
  if (body.startsWith('.')) {
    body = body.substring(1);
    from = uriStart;
  } else {
    from = cursor;
  }
  if (body.contains('/') || body.contains(':')) return const [];
  final parts = body.split('.');
  final partial = parts.removeLast();
  if (parts.any((part) => part.isEmpty)) return const [];
  if (!uri.startsWith('.')) from = cursor - partial.length;
  final directory = _relativeDirectory(file, parts);
  final items = _relativeEntries(source, from, cursor, partial, parts, file,
      directory: directory, partsOnly: partsOnly);
  if (!partsOnly &&
      parts.isEmpty &&
      !uri.startsWith('.') &&
      !uri.contains('^')) {
    if ('dart:'.startsWith(uri)) {
      items.insert(
          0,
          _importItem(source, from, cursor, 'dart:', 'dart:', 'scheme', 9,
              retrigger: true));
    }
    if ('package:'.startsWith(uri)) {
      items.insert(
          0,
          _importItem(source, from, cursor, 'package:', 'package:', 'scheme', 9,
              retrigger: true));
    }
  }
  return items;
}

Directory? _relativeDirectory(String? file, List<String> parts) {
  if (file == null || file == '<input>') return null;
  var directory = File(file).absolute.parent;
  for (final part in parts) {
    if (RegExp(r'^\^+$').hasMatch(part)) {
      for (var count = 0; count < part.length; count++) {
        directory = directory.parent;
      }
      continue;
    }
    if (part.contains('^')) return null;
    directory = Directory(_joinImport(directory.path, part));
  }
  return directory;
}

List<Map<String, Object?>> _relativeEntries(String source, int start, int end,
    String partial, List<String> parts, String? file,
    {Directory? directory, bool partsOnly = false}) {
  final dir = directory ?? _relativeDirectory(file, parts);
  if (dir == null || !dir.existsSync()) return const [];
  final items = <Map<String, Object?>>[];
  for (final entity in _children(dir)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.startsWith('.') || !name.startsWith(partial)) continue;
    if (entity is Directory) {
      items.add(_importItem(source, start, end, name, '$name.', 'directory', 19,
          retrigger: true,
          filter: _importFilter(source, start, end, partial, name)));
    } else if (entity is File && name.endsWith('.quds')) {
      if (partsOnly &&
          file != null &&
          entity.absolute.path == File(file).absolute.path) continue;
      final stem = name.substring(0, name.length - 5);
      if (stem.isEmpty || !stem.startsWith(partial)) continue;
      items.add(_importItem(source, start, end, stem, stem, name, 17,
          filter: _importFilter(source, start, end, partial, stem)));
      if (!partsOnly && fileSectionNames(entity.path).isNotEmpty) {
        items.add(_importItem(
            source, start, end, '$stem::', '$stem::', name, 17,
            retrigger: true,
            filter: _importFilter(source, start, end, partial, '$stem::')));
      }
    }
  }
  items.sort((a, b) => (a['label'] as String).compareTo(b['label'] as String));
  return items;
}

List<Map<String, Object?>> _namedFiles(
    String source, int start, int end, String partial, Directory? directory,
    {required bool quds}) {
  if (directory == null || !directory.existsSync()) return const [];
  final suffix = quds ? '.quds' : '.dart';
  final items = <Map<String, Object?>>[];
  for (final entity in _children(directory)) {
    if (entity is! File) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    if (!name.endsWith(suffix)) continue;
    final stem = name.substring(0, name.length - suffix.length);
    if (stem.isEmpty || !stem.startsWith(partial)) continue;
    items.add(_importItem(source, start, end, stem, stem, name, 17));
  }
  return items;
}

List<Map<String, Object?>> _directoryEntries(String source, int start, int end,
    String partial, Directory? directory, bool dartFiles,
    {bool externalLibRoot = false, bool hideQuds = false}) {
  if (directory == null || !directory.existsSync()) return const [];
  final children = _children(directory);
  final qudsStems = <String>{
    for (final entity in children)
      if (entity is File && entity.path.endsWith('.quds'))
        entity.path.split(Platform.pathSeparator).last.substring(
            0, entity.path.split(Platform.pathSeparator).last.length - 5),
  };
  final items = <Map<String, Object?>>[];
  for (final entity in children) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.startsWith('.')) continue;
    if (entity is Directory) {
      if (externalLibRoot &&
          (name == 'src' || name == 'internal') &&
          _isQudsInternalDirectory(entity)) {
        continue;
      }
      if (!name.startsWith(partial)) continue;
      final replacingDot = start < end && source.codeUnitAt(start) == 46;
      final text = replacingDot ? '/$name/' : '$name/';
      items.add(_importItem(source, start, end, name, text, 'directory', 19,
          retrigger: true, filter: replacingDot ? '.$name/' : name));
    } else if (entity is File) {
      final isQuds = name.endsWith('.quds');
      if (isQuds && hideQuds) continue;
      String? shown;
      if (isQuds) {
        shown = name.substring(0, name.length - 5);
      } else if (dartFiles && name.endsWith('.dart')) {
        final stem = name.substring(0, name.length - 5);
        if (qudsStems.contains(stem)) continue;
        shown = name;
      }
      if (shown == null || !shown.startsWith(partial)) continue;
      final replacingDot = start < end && source.codeUnitAt(start) == 46;
      final text = replacingDot ? '/$shown' : shown;
      items.add(_importItem(source, start, end, shown, text, name, 17,
          filter: replacingDot ? '.$shown' : shown));
      if (isQuds && fileSectionNames(entity.path).isNotEmpty) {
        final secText = replacingDot ? '/$shown::' : '$shown::';
        items.add(_importItem(source, start, end, '$shown::', secText, name, 17,
            retrigger: true, filter: replacingDot ? '.$shown::' : '$shown::'));
      }
    }
  }
  items.sort((a, b) => (a['label'] as String).compareTo(b['label'] as String));
  return items;
}

Map<String, Object?> _importItem(String source, int start, int end,
    String label, String text, String detail, int kind,
    {bool retrigger = false, String? filter}) {
  return {
    'label': label,
    'kind': kind,
    'detail': detail,
    'filterText': filter ?? label,
    'sortText': '0$label',
    'textEdit': {..._range(source, start, end), 'newText': text},
    if (retrigger) 'command': _retrigger,
  };
}

List<FileSystemEntity> _children(Directory directory) {
  try {
    return directory.listSync(followLinks: true);
  } on FileSystemException {
    return const [];
  }
}

String _importFilter(
    String source, int start, int end, String partial, String label) {
  final replaced = source.substring(start, end);
  if (replaced.isEmpty || label.startsWith(replaced)) return label;
  final keep = replaced.length - partial.length;
  final separator = keep > 0 ? replaced.substring(0, keep) : '';
  return '$separator$label';
}

String _joinImport(String root, String relative) {
  final separator = Platform.pathSeparator;
  final tail = relative.replaceAll('/', separator);
  if (root.endsWith(separator)) return '$root$tail';
  return '$root$separator$tail';
}

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
