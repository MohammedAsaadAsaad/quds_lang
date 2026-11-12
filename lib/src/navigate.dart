import 'ast.dart';
import 'compiler.dart';
import 'source.dart';
import 'walk.dart';

/// The declaration span of the symbol under [line] and [column].
SourceSpan? definitionAt(Compilation compilation, int line, int column) {
  final hit = _identifierAt(compilation, line, column);
  if (hit == null) return null;
  final symbol = compilation.semantics.references[hit];
  if (symbol == null) return null;
  for (final entry in compilation.semantics.declarations.entries) {
    if (identical(entry.value, symbol)) return entry.key.span;
  }
  return null;
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
