import 'ast.dart';
import 'compiler.dart';
import 'lexer.dart';
import 'parser.dart';
import 'walk.dart';

class AppliedFix {
  const AppliedFix({
    required this.line,
    required this.code,
    required this.description,
  });

  final int line;
  final String code;
  final String description;
}

class FixResult {
  const FixResult(this.source, this.fixes);

  final String source;
  final List<AppliedFix> fixes;

  bool get changed => fixes.isNotEmpty;
}

/// Applies safe, deterministic AST/diagnostic-backed fixes to Quds [source]:
/// - `E203`: inserts `shadow ` before an inner binding that shadows an outer name
/// - `E202`: changes a same-file immutable binding to `var ` when reassigned
/// - `E110`: inserts `()` on a zero-argument call written without parentheses
/// - `W002`: removes unused single-line `use` imports (verified against both
///   normal and `when test:` compilations)
FixResult fixQudsSource(
  String source, {
  String file = '<input>',
  String? packageConfigFrom,
}) {
  var current = source;
  final fixes = <AppliedFix>[];

  // Pass 1: iterative diagnostic-backed fixes (up to 16 safe steps).
  for (var step = 0; step < 16; step++) {
    try {
      compile(current,
          file: file, emitDart: false, packageConfigFrom: packageConfigFrom);
      break;
    } on CompilerException catch (error) {
      final patched = _applyDiagnosticFix(current, error);
      if (patched == null || patched.$1 == current) break;
      current = patched.$1;
      fixes.add(patched.$2);
    }
  }

  // Pass 2: remove unused single-line `use` imports when the file compiles cleanly.
  Compilation? compiled;
  try {
    compiled = compile(current,
        file: file, emitDart: false, packageConfigFrom: packageConfigFrom);
  } on CompilerException {
    return FixResult(current, fixes);
  }

  final hasWhenTest = current.contains('when test');
  final imports = <ImportDeclaration>[
    for (final stmt in compiled.program.statements)
      if (stmt is ImportDeclaration && !stmt.export) stmt,
  ];
  if (imports.isNotEmpty) {
    // Check in reverse line order so removing a line does not shift earlier lines.
    imports.sort((a, b) => b.span.line.compareTo(a.span.line));
    for (final imp in imports) {
      final candidate = _removeLine(current, imp.span.line);
      if (candidate == null) continue;
      if (_compilesCleanly(candidate, file, packageConfigFrom,
          testing: false)) {
        if (!hasWhenTest ||
            _compilesCleanly(candidate, file, packageConfigFrom,
                testing: true)) {
          current = candidate;
          fixes.add(AppliedFix(
            line: imp.span.line,
            code: 'W002',
            description: "Removed unused import '${imp.uri}'",
          ));
        }
      }
    }
  }

  // Sort applied fixes by line number for clean reporting.
  fixes.sort((a, b) => a.line.compareTo(b.line));
  return FixResult(current, fixes);
}

bool _compilesCleanly(String source, String file, String? packageConfigFrom,
    {required bool testing}) {
  try {
    compile(
      source,
      file: file,
      emitDart: false,
      testing: testing,
      packageConfigFrom: packageConfigFrom,
    );
    return true;
  } on CompilerException {
    return false;
  }
}

(String, AppliedFix)? _applyDiagnosticFix(
    String source, CompilerException error) {
  switch (error.code) {
    case 'E203':
      final offset =
          _lineColToOffset(source, error.span.line, error.span.column);
      if (offset == null || offset < 0 || offset > source.length) return null;
      final rest = source.substring(offset);
      if (rest.startsWith('shadow ')) return null;
      final updated =
          '${source.substring(0, offset)}shadow ${source.substring(offset)}';
      return (
        updated,
        AppliedFix(
          line: error.span.line,
          code: 'E203',
          description: "Inserted 'shadow' before inner binding",
        ),
      );

    case 'E202':
      final match = RegExp(r'Cannot assign immutable binding (\w+)')
          .firstMatch(error.message);
      if (match == null) return null;
      final targetName = match.group(1)!;
      final binding =
          _findPrecedingBinding(source, targetName, error.span.line);
      if (binding == null) return null;
      if (binding.mode == BindingMode.inferred) {
        final offset =
            _lineColToOffset(source, binding.span.line, binding.span.column);
        if (offset == null) return null;
        final rest = source.substring(offset);
        if (rest.startsWith('var ') || rest.startsWith('const ')) return null;
        final updated =
            '${source.substring(0, offset)}var ${source.substring(offset)}';
        return (
          updated,
          AppliedFix(
            line: binding.span.line,
            code: 'E202',
            description: "Changed immutable binding '$targetName' to 'var'",
          ),
        );
      }
      if (binding.mode == BindingMode.shadow) {
        final offset =
            _lineColToOffset(source, binding.span.line, binding.span.column);
        if (offset == null) return null;
        final rest = source.substring(offset);
        if (!rest.startsWith('shadow ')) return null;
        final insertAt = offset + 'shadow '.length;
        final updated =
            '${source.substring(0, insertAt)}var ${source.substring(insertAt)}';
        return (
          updated,
          AppliedFix(
            line: binding.span.line,
            code: 'E202',
            description:
                "Changed 'shadow $targetName' to 'shadow var $targetName'",
          ),
        );
      }
      return null;

    case 'E110':
      final offset =
          _lineColToOffset(source, error.span.line, error.span.column);
      if (offset == null) return null;
      final end = offset + (error.span.length < 1 ? 1 : error.span.length);
      if (end > source.length) return null;
      if (end < source.length && source[end] == '(') return null;
      final updated = '${source.substring(0, end)}()${source.substring(end)}';
      return (
        updated,
        AppliedFix(
          line: error.span.line,
          code: 'E110',
          description: "Added '()' to zero-argument call",
        ),
      );

    default:
      return null;
  }
}

Binding? _findPrecedingBinding(String source, String name, int beforeLine) {
  try {
    final tokens = const Lexer().tokenize(source);
    final program = Parser(tokens).parse();
    Binding? best;
    walkAst(program, (node) {
      if (node is Binding &&
          node.name == name &&
          node.span.line < beforeLine &&
          (node.mode == BindingMode.inferred ||
              node.mode == BindingMode.shadow)) {
        if (best == null || node.span.line > best!.span.line) {
          best = node;
        }
      }
    });
    return best;
  } on CompilerException {
    return null;
  }
}

int? _lineColToOffset(String source, int line, int column) {
  if (line < 1 || column < 1) return null;
  var currentLine = 1;
  var i = 0;
  while (i < source.length && currentLine < line) {
    if (source.codeUnitAt(i) == 0x0A) currentLine++;
    i++;
  }
  if (currentLine != line) return null;
  final offset = i + (column - 1);
  return offset <= source.length ? offset : null;
}

String? _removeLine(String source, int lineNumber) {
  if (lineNumber < 1) return null;
  final hasCrlf = source.contains('\r\n');
  final eol = hasCrlf ? '\r\n' : '\n';
  final normalized = source.replaceAll('\r\n', '\n');
  final trailingNewline = normalized.endsWith('\n');
  final lines = normalized.split('\n');
  if (trailingNewline) lines.removeLast();
  final index = lineNumber - 1;
  if (index < 0 || index >= lines.length) return null;
  // Only remove single-line `use ...` directives safely.
  if (!lines[index].trimLeft().startsWith('use ')) return null;
  lines.removeAt(index);
  final rebuilt = lines.join(eol);
  return trailingNewline ? '$rebuilt$eol' : rebuilt;
}
