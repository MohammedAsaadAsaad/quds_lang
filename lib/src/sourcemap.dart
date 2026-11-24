import 'dart:convert';

import 'ast.dart';
import 'emitter.dart';
import 'semantics.dart';
import 'source.dart';
import 'walk.dart';

/// Source Map Revision 3, one mapping per generated line.
String encodeSourceMap(
    String generatedFile, String sourceFile, List<(int, SourceSpan)> mappings) {
  final byLine = <int, SourceSpan>{};
  for (final (line, span) in mappings) {
    byLine.putIfAbsent(line, () => span);
  }
  final lines = <String>[];
  final sources = <String>[sourceFile];
  var previousSourceIndex = 0;
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
    final file = span.file == '<input>' ? sourceFile : span.file;
    var sourceIndex = sources.indexOf(file);
    if (sourceIndex < 0) {
      sourceIndex = sources.length;
      sources.add(file);
    }
    buffer.write(_vlq(sourceIndex - previousSourceIndex));
    previousSourceIndex = sourceIndex;
    buffer.write(_vlq(span.line - 1 - previousSourceLine));
    previousSourceLine = span.line - 1;
    buffer.write(_vlq(span.column - 1 - previousSourceColumn));
    previousSourceColumn = span.column - 1;
    lines.add(buffer.toString());
  }
  return jsonEncode({
    'version': 3,
    'file': generatedFile,
    'sources': sources,
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
    DartEmitter emitter, String generatedFile, String sourceFile,
    {Program? program, String? source}) {
  if (emitter.mappings.isEmpty) return null;
  final encoded = encodeSourceMap(generatedFile, sourceFile, emitter.mappings);
  final names = _qudsNames(emitter.model);
  final locals = program == null || source == null
      ? const <Map<String, Object>>[]
      : _qudsLocals(emitter.model, program, source);
  if (names.isEmpty && locals.isEmpty) return encoded;
  final data = jsonDecode(encoded) as Map<String, Object?>;
  if (names.isNotEmpty) data['x_qudsNames'] = names;
  if (locals.isNotEmpty) data['x_qudsLocals'] = locals;
  return jsonEncode(data);
}

/// Generated Dart name to the name written in the `.quds` source.
Map<String, String> _qudsNames(SemanticModel model) {
  final names = <String, String>{};
  void take(Symbol symbol) {
    if (symbol.dartName.isEmpty || symbol.name.isEmpty) return;
    if (symbol.dartName == symbol.name) return;
    names.putIfAbsent(symbol.dartName, () => symbol.name);
  }

  for (final symbol in model.declarations.values) {
    take(symbol);
  }
  for (final symbol in model.loopIndexes.values) {
    take(symbol);
  }
  return names;
}

/// A local whose generated name differs from the name written in the source.
///
/// [line] and [end] are the lines where that binding is in scope.
class QudsLocal {
  const QudsLocal(this.dartName, this.name, this.line, this.end);
  final String dartName;
  final String name;
  final int line;
  final int end;
}

List<Map<String, Object>> _qudsLocals(
    SemanticModel model, Program program, String source) {
  final bytes = utf8.encode(source);
  int endLine(SourceSpan span) {
    final start = span.offset.clamp(0, bytes.length);
    final stop = (span.offset + span.length).clamp(0, bytes.length);
    var line = span.line;
    for (var i = start; i < stop; i++) {
      if (bytes[i] == 10) line++;
    }
    return line;
  }

  final locals = <Map<String, Object>>[];
  final seen = <String>{};
  void add(Symbol? symbol, SourceSpan span, int end) {
    if (symbol == null || symbol.dartName.isEmpty) return;
    if (symbol.dartName == symbol.name || !seen.add(symbol.dartName)) return;
    locals.add({
      'dart': symbol.dartName,
      'name': symbol.name,
      'line': span.line,
      'end': end < span.line ? span.line : end,
    });
  }

  late void Function(Statement node, int end) visitStatement;

  void visitStatements(List<Statement>? body, int end) {
    if (body == null) return;
    for (final node in body) {
      visitStatement(node, end);
    }
  }

  void patterns(Pattern pattern, int end) {
    walkAst(pattern, (node) {
      if (node is Pattern) add(model.declarations[node], node.span, end);
    });
  }

  void visitExpression(Expression? node, int end) {
    if (node == null) return;
    final lambdas = <Lambda>{};
    final blocks = <DoExpression>{};
    final loops = <CollectionFor>{};
    final valueLoops = <LoopExpression>{};
    final wheres = <WhereExpression>{};
    walkAst(node, (child) {
      if (child is CollectionFor && loops.add(child)) {
        final loopEnd = endLine(child.span);
        add(model.declarations[child], child.span, loopEnd);
        add(model.loopIndexes[child], child.span, loopEnd);
      }
      if (child is Lambda && lambdas.add(child)) {
        final lambdaEnd = endLine(child.span);
        for (final parameter in child.parameters) {
          add(model.declarations[parameter], parameter.span, lambdaEnd);
          visitExpression(parameter.defaultValue, lambdaEnd);
        }
        visitStatements(child.body, lambdaEnd);
        visitExpression(child.expressionBody, lambdaEnd);
      }
      if (child is DoExpression && blocks.add(child)) {
        visitStatements(child.body, endLine(child.span));
      }
      if (child is LoopExpression && valueLoops.add(child)) {
        visitStatement(child.loop, endLine(child.span));
        visitExpression(child.fallback, end);
      }
      if (child is WhereExpression && wheres.add(child)) {
        final whereEnd = endLine(child.span);
        for (final binding in child.bindings) {
          add(model.declarations[binding], binding.span, whereEnd);
          visitExpression(binding.value, whereEnd);
        }
        visitExpression(child.value, whereEnd);
      }
    });
  }

  void function(FunctionDeclaration node) {
    final functionEnd = endLine(node.span);
    for (final parameter in node.parameters) {
      add(model.declarations[parameter], parameter.span, functionEnd);
      visitExpression(parameter.defaultValue, functionEnd);
    }
    visitStatements(node.body, functionEnd);
    visitExpression(node.expressionBody, functionEnd);
  }

  void constructor(ConstructorDeclaration node) {
    final functionEnd = endLine(node.span);
    for (final parameter in node.parameters) {
      add(model.declarations[parameter], parameter.span, functionEnd);
      visitExpression(parameter.defaultValue, functionEnd);
    }
    visitStatements(node.body, functionEnd);
    visitExpression(node.expressionBody, functionEnd);
  }

  visitStatement = (Statement node, int end) {
    switch (node) {
      case Binding(:final value):
        add(model.declarations[node], node.span, end);
        visitExpression(value, end);
      case FunctionDeclaration():
        function(node);
      case IfStatement(:final condition, :final thenBody, :final elseBody):
        visitExpression(condition, end);
        visitStatements(thenBody, _bodyEnd(thenBody, node.span, endLine));
        visitStatements(elseBody, _bodyEnd(elseBody, node.span, endLine));
      case ForStatement(
          :final iterable,
          :final body,
          :final step,
          :final elseBody
        ):
        final loopEnd = endLine(node.span);
        visitExpression(iterable, end);
        visitExpression(step, end);
        add(model.declarations[node], node.span, loopEnd);
        add(model.loopIndexes[node], node.span, loopEnd);
        visitStatements(body, loopEnd);
        visitStatements(elseBody, loopEnd);
      case WhileStatement(
          :final condition,
          :final body,
          :final pattern,
          :final elseBody
        ):
        final loopEnd = endLine(node.span);
        visitExpression(condition, end);
        if (pattern != null) patterns(pattern, loopEnd);
        add(model.declarations[node], node.span, loopEnd);
        visitStatements(body, loopEnd);
        visitStatements(elseBody, loopEnd);
      case GuardedStatement(
          :final statement,
          :final condition,
          :final pattern,
          :final alternate
        ):
        visitExpression(condition, end);
        if (pattern != null) patterns(pattern, end);
        add(model.declarations[node], node.span, end);
        visitStatement(statement, end);
        visitExpression(alternate, end);
      case ParallelAssignment(:final targets, :final values):
        for (final target in targets) {
          patterns(target, end);
        }
        for (final value in values) {
          visitExpression(value, end);
        }
      case RepeatStatement(
          :final body,
          :final condition,
          :final count,
          :final elseBody
        ):
        final loopEnd = endLine(node.span);
        visitExpression(count, end);
        visitStatements(body, loopEnd);
        visitExpression(condition, end);
        visitStatements(elseBody, loopEnd);
      case CForStatement(
          :final init,
          :final condition,
          :final step,
          :final body
        ):
        final loopEnd = endLine(node.span);
        visitStatement(init, loopEnd);
        visitExpression(condition, loopEnd);
        visitExpression(step, loopEnd);
        visitStatements(body, loopEnd);
        visitStatements(node.elseBody, loopEnd);
      case IfLetStatement(:final value, :final thenBody, :final elseBody):
        final thenEnd = _bodyEnd(thenBody, node.span, endLine);
        add(model.declarations[node], node.span, thenEnd);
        visitExpression(value, end);
        visitStatements(thenBody, thenEnd);
        visitStatements(elseBody, _bodyEnd(elseBody, node.span, endLine));
      case IfCaseStatement(:final scrutinee, :final pattern, :final body):
        final armEnd = endLine(node.span);
        visitExpression(scrutinee, end);
        patterns(pattern, armEnd);
        visitStatements(body, armEnd);
      case UsingStatement(:final value, :final body):
        final usedEnd = endLine(node.span);
        visitExpression(value, end);
        add(model.declarations[node], node.span, usedEnd);
        visitStatements(body, usedEnd);
      case WatchStatement(:final value, :final body):
        visitExpression(value, end);
        visitStatements(body, endLine(node.span));
      case BatchStatement(:final body):
        visitStatements(body, endLine(node.span));
      case OnceStatement(:final body):
        visitStatements(body, endLine(node.span));
      case WhenStatement(:final condition, :final body):
        visitExpression(condition, end);
        visitStatements(body, endLine(node.span));
      case TestDeclaration(:final body):
        visitStatements(body, endLine(node.span));
      case MatchStatement(:final value, :final arms):
        visitExpression(value, end);
        for (final arm in arms) {
          final armEnd = endLine(arm.span);
          patterns(arm.pattern, armEnd);
          visitExpression(arm.guard, armEnd);
          visitStatements(arm.body, armEnd);
        }
      case TryStatement(
          :final body,
          :final catches,
          :final elseBody,
          :final finallyBody
        ):
        visitStatements(body, endLine(node.span));
        for (final clause in catches) {
          final catchEnd = endLine(clause.span);
          add(model.declarations[clause], clause.span, catchEnd);
          add(model.traces[clause], clause.span, catchEnd);
          visitStatements(clause.body, catchEnd);
        }
        visitStatements(elseBody, endLine(node.span));
        visitStatements(finallyBody, endLine(node.span));
      case DestructureStatement(:final pattern, :final value, :final elseBody):
        patterns(pattern, end);
        visitExpression(value, end);
        if (elseBody != null) visitStatements(elseBody, endLine(node.span));
      case GuardStatement(:final condition, :final elseBody):
        visitExpression(condition, end);
        visitStatements(elseBody, endLine(node.span));
      case LabelStatement():
        visitStatement(node.statement, end);
      case ClassDeclaration(
          :final fields,
          :final methods,
          :final constructors,
          :final properties,
        ):
        for (final field in fields) {
          visitExpression(field.initializer, endLine(node.span));
          visitStatements(field.lazyBody, endLine(field.span));
        }
        for (final method in methods) {
          function(method);
        }
        for (final ctor in constructors) {
          constructor(ctor);
        }
        for (final property in properties) {
          final propertyEnd = endLine(property.span);
          visitExpression(property.getter, propertyEnd);
          visitStatements(property.getterBody, propertyEnd);
          visitStatements(property.setterBody, propertyEnd);
        }
      case ExtensionDeclaration(:final methods, :final properties):
        for (final method in methods) {
          function(method);
        }
        for (final property in properties) {
          final propertyEnd = endLine(property.span);
          visitExpression(property.getter, propertyEnd);
          visitStatements(property.getterBody, propertyEnd);
          visitStatements(property.setterBody, propertyEnd);
        }
      case TaskGroupStatement(:final children):
        final groupEnd = endLine(node.span);
        for (final child in children) {
          if (child is Statement) visitStatement(child, groupEnd);
          if (child is Expression) visitExpression(child, groupEnd);
        }
      case ReturnStatement(:final value):
        visitExpression(value, end);
      case YieldStatement(:final value):
      case ThrowStatement(:final value):
      case ResultStatement(:final value):
        visitExpression(value, end);
      case ExpressionStatement():
        visitExpression(node.expression, end);
      case DeferStatement():
        visitExpression(node.expression, end);
      case RequireStatement(:final condition, :final message):
        visitExpression(condition, end);
        visitExpression(message, end);
      case RaiseStatement(:final arguments):
        for (final argument in arguments) {
          visitExpression(argument.value, end);
        }
      case IndexAssignment(:final target, :final value):
        visitExpression(target, end);
        visitExpression(value, end);
      case MemberAssignment(:final object, :final value):
        visitExpression(object, end);
        visitExpression(value, end);
      case ConfigDeclaration(:final value):
        visitExpression(value, end);
      case ImportDeclaration(:final condition):
        visitExpression(condition, end);
      case BreakStatement(:final value):
        visitExpression(value, end);
      case ContinueStatement():
      case RethrowStatement():
      case PartDirective():
      case SectionDeclaration():
      case AliasDeclaration():
      case AnnotationDeclaration():
        break;
    }
  };

  visitStatements(program.statements, endLine(program.span));
  return locals;
}

int _bodyEnd(List<Statement> body, SourceSpan span,
    int Function(SourceSpan span) endLine) {
  if (body.isEmpty) return endLine(span);
  return endLine(body.last.span);
}

/// One original position for each generated line that has a mapping.
class SourcePositions {
  SourcePositions(this.byGeneratedLine,
      {this.names = const {}, this.locals = const []});

  /// Generated line, one-based, to source path, source line, and column.
  final Map<int, (String, int, int)> byGeneratedLine;

  /// Generated local name to the name written in the source.
  final Map<String, String> names;

  /// Locals whose generated names differ from the source, with their scope.
  final List<QudsLocal> locals;

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
    final rawNames = data['x_qudsNames'];
    final names = rawNames is Map
        ? rawNames.map((key, value) => MapEntry('$key', '$value'))
        : const <String, String>{};
    final rawLocals = data['x_qudsLocals'];
    final locals = <QudsLocal>[];
    if (rawLocals is List) {
      for (final item in rawLocals) {
        if (item is! Map) continue;
        locals.add(QudsLocal(
          '${item['dart']}',
          '${item['name']}',
          (item['line'] as num?)?.toInt() ?? 1,
          (item['end'] as num?)?.toInt() ?? 1,
        ));
      }
    }
    return SourcePositions(byLine, names: names, locals: locals);
  }

  (String, int, int)? original(int generatedLine) =>
      byGeneratedLine[generatedLine];

  /// Rewrites frames whose path is [generatedPath] back to the Quds source.
  String rewriteStack(String text, String generatedPath) {
    final normalized = _normalizePath(generatedPath);
    final name = normalized.split('/').last;
    return text.replaceAllMapped(_frame, (match) {
      final path = match.group(1)!;
      if (!_pathsMatch(path, name) && !_pathsMatch(path, normalized)) {
        return match.group(0)!;
      }
      final hit = original(int.parse(match.group(2)!));
      if (hit == null) return match.group(0)!;
      return '${hit.$1}:${hit.$2}:${hit.$3}';
    });
  }

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

String _normalizePath(String value) {
  var normalized = value.replaceAll('\\', '/');
  if (RegExp(r'^/[A-Za-z]:/').hasMatch(normalized)) {
    normalized = normalized.substring(1);
  }
  if (normalized.startsWith('//')) {
    normalized = '//${normalized.substring(2).replaceAll(RegExp(r'/+'), '/')}';
  } else {
    normalized = normalized.replaceAll(RegExp(r'/+'), '/');
  }
  if (value.contains('\\') || RegExp(r'^[A-Za-z]:/').hasMatch(normalized)) {
    normalized = normalized.toLowerCase();
  }
  return normalized;
}

bool _pathsMatch(String left, String right) {
  final a = _normalizePath(left);
  final b = _normalizePath(right);
  return a == b || a.endsWith('/$b') || b.endsWith('/$a');
}

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

final _frame = RegExp(r'([\w./\\:+\-]+\.(?:dart|js)):(\d+):(\d+)');

bool _sameFile(String path, String file) => _pathsMatch(path, file);

/// Replaces a Dart compiler source listing that follows a `.quds` location
/// with the Quds line itself.
String preferQudsSnippet(String text, String source) {
  final lines = source.split('\n');
  final input = text.split('\n');
  final out = <String>[];
  final location = RegExp(r'\.quds:(\d+):\d+');
  final numbered = RegExp(r'^\s*\d+\s*\|');
  final gutter = RegExp(r'^\s*\|');
  for (var i = 0; i < input.length; i++) {
    out.add(input[i]);
    final match = location.firstMatch(input[i]);
    if (match == null) continue;
    var cursor = i + 1;
    var replaced = false;
    while (cursor < input.length &&
        (numbered.hasMatch(input[cursor]) || gutter.hasMatch(input[cursor]))) {
      replaced = true;
      cursor++;
    }
    if (!replaced) continue;
    final lineNo = int.parse(match.group(1)!);
    if (lineNo >= 1 && lineNo <= lines.length) out.add(lines[lineNo - 1]);
    i = cursor - 1;
  }
  return out.join('\n');
}

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
