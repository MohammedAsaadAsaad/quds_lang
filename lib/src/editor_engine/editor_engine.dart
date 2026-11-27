/// Pure-Dart embedded Quds Code Editor Engine (`QudsEditorEngine`).
///
/// Provides syntax & semantic highlighting, official Quds formatting, live
/// syntax + policy-aware diagnostics with quick fixes, context-aware
/// autocomplete (including live `QudsSession` workspace, `quds:*` SDKs,
/// `::sections`, `quds:viz`, and custom `QudsHostModule`s), hover docs,
/// signature help, document outline, folding, and indentation-aware editing.
///
/// Zero `dart:io` or Flutter dependencies — works on Flutter Desktop/Mobile/Web
/// and Dart VM/CLI without affecting `quds lsp` or desktop editor extensions.
library;

import '../ast.dart';
import '../format.dart';
import '../interpreter/host_bridge.dart';
import '../interpreter/policy.dart';
import '../interpreter/session.dart';
import '../interpreter/values.dart';
import '../interpreter/viz_module.dart';
import '../keyword_docs_data.dart';
import '../lexer.dart';
import '../library_uri.dart';
import '../loop_context_docs.dart';
import '../parser.dart';
import '../sdk_sources.dart';
import 'highlighter.dart';
import 'models.dart';
import 'sdk_catalog.dart';

/// Embedded language & code-editing engine designed to pair with [QudsSession].
class QudsEditorEngine {
  QudsEditorEngine({
    this.session,
    QudsExecutionPolicy? policy,
    List<QudsHostModule> hostModules = const [],
  })  : _explicitPolicy = policy,
        _explicitHostModules = List<QudsHostModule>.from(hostModules);

  /// Optional live session for workspace autocomplete, active policy, and host modules.
  final QudsSession? session;
  final QudsExecutionPolicy? _explicitPolicy;
  final List<QudsHostModule> _explicitHostModules;

  QudsExecutionPolicy? get _effectivePolicy =>
      _explicitPolicy ?? session?.policy;

  List<QudsHostModule> get _effectiveHostModules {
    final byUri = <String, QudsHostModule>{};
    final builtInViz = buildQudsVizModule();
    byUri[builtInViz.uri] = builtInViz;
    if (session != null) {
      for (final m in session!.hostModules) {
        byUri[m.uri] = m;
      }
    }
    for (final m in _explicitHostModules) {
      byUri[m.uri] = m;
    }
    return byUri.values.toList();
  }

  /// Produces ordered UTF-16 syntax & semantic highlight spans for [source].
  List<QudsHighlightSpan> highlight(String source) =>
      highlightQudsSource(source);

  /// Formats [source] using the official Quds formatter (`formatQuds`).
  String format(
    String source, {
    int indent = 2,
    int width = 80,
    bool singleLineIf = true,
  }) =>
      formatQuds(
        source,
        indent: indent,
        width: width,
        singleLineIf: singleLineIf,
      );

  /// Analyzes [source] for syntax errors, policy violations, semantic warnings,
  /// document outline symbols, highlights, and foldable block ranges.
  QudsEditorAnalysis analyze(String source, {String file = '<editor>'}) {
    final highlights = highlight(source);
    final diagnostics = <QudsEditorDiagnostic>[];
    final symbols = <QudsDocumentSymbol>[];
    final foldRanges = _computeFoldRanges(source);
    final lineStarts = _computeLineStarts(source);

    Program? program;
    var validSyntax = true;

    try {
      final tokens = const Lexer().tokenize(source, file: file);
      final parser = Parser(tokens);
      program = parser.parse(partial: true);
      if (parser.errors.isNotEmpty) {
        validSyntax = false;
        for (final err in parser.errors) {
          diagnostics.add(_fromCompilerException(err, source, lineStarts));
        }
      }
    } on CompilerException catch (err) {
      validSyntax = false;
      diagnostics.add(_fromCompilerException(err, source, lineStarts));
    }

    if (program != null) {
      _extractSymbols(program.statements, symbols);
      _runPolicyAndStaticChecks(
        program.statements,
        source,
        lineStarts,
        diagnostics,
      );
    }

    return QudsEditorAnalysis(
      highlights: highlights,
      diagnostics: diagnostics,
      symbols: symbols,
      foldRanges: foldRanges,
      validSyntax: validSyntax &&
          !diagnostics.any((d) => d.severity == QudsDiagnosticSeverity.error),
    );
  }

  /// Context-aware autocomplete at a 0-based UTF-16 [offset] in [source].
  List<QudsCompletionItem> completeAt(String source, int offset) {
    final clamped = offset.clamp(0, source.length);
    final before = source.substring(0, clamped);
    final lineStart = before.lastIndexOf('\n') + 1;
    final currentLine = before.substring(lineStart);

    // 1. `use <uri>` import & `::section` completion
    final useMatch = RegExp(r'^\s*(?:use|export)\s+([A-Za-z0-9_:/.-]*)$')
        .firstMatch(currentLine);
    if (useMatch != null) {
      return _completeImport(useMatch.group(1)!);
    }

    // 2. Member completion after `.` or `?.`
    final memberMatch =
        RegExp(r'([A-Za-z_\$][A-Za-z0-9_]*)\??\.([A-Za-z0-9_]*)$')
            .firstMatch(currentLine);
    if (memberMatch != null) {
      final receiver = memberMatch.group(1)!;
      final prefix = memberMatch.group(2)!;
      return _completeMember(source, receiver, prefix);
    }

    // 3. General identifier / keyword / workspace / imported symbol completion
    final wordMatch =
        RegExp(r'([A-Za-z_][A-Za-z0-9_]*)$').firstMatch(currentLine);
    final prefix = wordMatch?.group(1) ?? '';
    return _completeGeneral(source, prefix);
  }

  /// Convenience wrapper accepting 1-based [line] and [column].
  List<QudsCompletionItem> completeAtLineColumn(
    String source,
    int line,
    int column,
  ) =>
      completeAt(source, _offsetForLineColumn(source, line, column));

  /// Returns hover documentation for the symbol at UTF-16 [offset], if any.
  QudsHoverInfo? hoverAt(String source, int offset) {
    if (source.isEmpty) return null;
    final clamped = offset.clamp(0, source.length);
    final bounds = _wordRangeAt(source, clamped);
    if (bounds == null) return null;
    final word = source.substring(bounds.$1, bounds.$2);

    // Check `$.member`
    if (bounds.$1 >= 2 && source.substring(bounds.$1 - 2, bounds.$1) == r'$.') {
      final doc = loopContextDocs[word];
      if (doc != null) {
        return QudsHoverInfo(
          title: '\$.$word',
          signature: '\$.$word',
          documentation: doc,
          startOffset: bounds.$1,
          endOffset: bounds.$2,
        );
      }
    }

    // Check `prefix.member` (e.g. `viz.scene` or host module function)
    if (bounds.$1 >= 1 && source[bounds.$1 - 1] == '.') {
      final recvBounds = _wordRangeAt(source, bounds.$1 - 2);
      if (recvBounds != null) {
        final recv = source.substring(recvBounds.$1, recvBounds.$2);
        final memberItems = _completeMember(source, recv, '');
        for (final item in memberItems) {
          if (item.label == word) {
            return QudsHoverInfo(
              title: '$recv.$word',
              signature: item.detail,
              documentation: item.documentation ?? item.detail ?? word,
              startOffset: bounds.$1,
              endOffset: bounds.$2,
            );
          }
        }
      }
    }

    // Check live session workspace variable
    final ws = session?.workspace[word];
    if (ws != null) {
      return QudsHoverInfo(
        title: word,
        signature: '${ws.mutable ? 'var ' : ''}$word: ${ws.typeName}',
        documentation: 'Current workspace value: `${ws.summary}`',
        startOffset: bounds.$1,
        endOffset: bounds.$2,
      );
    }

    // Check file-local declarations
    final local = _findLocalSymbol(source, word);
    if (local != null) {
      return QudsHoverInfo(
        title: local.label,
        signature: local.detail,
        documentation: local.documentation ?? local.detail ?? local.label,
        startOffset: bounds.$1,
        endOffset: bounds.$2,
      );
    }

    // Check imported SDK / host module symbols
    final imported = _importedSymbolsForSource(source);
    for (final item in imported) {
      if (item.label == word) {
        return QudsHoverInfo(
          title: item.label,
          signature: item.detail,
          documentation: item.documentation ?? item.detail ?? item.label,
          startOffset: bounds.$1,
          endOffset: bounds.$2,
        );
      }
    }

    // Check official Quds keyword documentation
    final kwDoc = keywordDocumentation[word];
    if (kwDoc != null) {
      return QudsHoverInfo(
        title: word,
        signature: 'keyword $word',
        documentation: kwDoc,
        startOffset: bounds.$1,
        endOffset: bounds.$2,
      );
    }

    return null;
  }

  /// Returns active function call signature help at UTF-16 [offset], if inside `fn(...)`.
  QudsSignatureHelp? signatureHelpAt(String source, int offset) {
    final clamped = offset.clamp(0, source.length);
    var depth = 0;
    var commas = 0;
    var openParen = -1;
    for (var i = clamped - 1; i >= 0; i--) {
      final ch = source[i];
      if (ch == ')') {
        depth++;
      } else if (ch == '(') {
        if (depth == 0) {
          openParen = i;
          break;
        }
        depth--;
      } else if (ch == ',' && depth == 0) {
        commas++;
      } else if (ch == '\n' && depth == 0) {
        // Allow multiline calls, keep scanning up to a reasonable limit.
        if (clamped - i > 400) break;
      }
    }
    if (openParen <= 0) return null;

    final calleeRange = _wordRangeAt(source, openParen - 1);
    if (calleeRange == null) return null;
    final fnName = source.substring(calleeRange.$1, calleeRange.$2);

    // Search member call (`viz.point(`) or top-level call (`mean(`)
    QudsCompletionItem? match;
    if (calleeRange.$1 >= 1 && source[calleeRange.$1 - 1] == '.') {
      final recvRange = _wordRangeAt(source, calleeRange.$1 - 2);
      if (recvRange != null) {
        final recv = source.substring(recvRange.$1, recvRange.$2);
        for (final item in _completeMember(source, recv, '')) {
          if (item.label == fnName) {
            match = item;
            break;
          }
        }
      }
    }
    match ??= _findLocalSymbol(source, fnName);
    if (match == null) {
      for (final item in _importedSymbolsForSource(source)) {
        if (item.label == fnName) {
          match = item;
          break;
        }
      }
    }
    if (match == null) {
      for (final item in _coreBuiltinCompletions()) {
        if (item.label == fnName) {
          match = item;
          break;
        }
      }
    }
    if (match == null || match.detail == null) return null;

    final sig = match.detail!;
    final lp = sig.indexOf('(');
    final rp = sig.lastIndexOf(')');
    final params = (lp >= 0 && rp > lp)
        ? sig
            .substring(lp + 1, rp)
            .split(',')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList()
        : const <String>[];

    return QudsSignatureHelp(
      functionName: fnName,
      label: sig,
      parameters: params,
      activeParameter: params.isEmpty ? 0 : commas.clamp(0, params.length - 1),
      documentation: match.documentation,
    );
  }

  // -------------------------------------------------------------------------
  // Smart Indentation & Editing Helpers (Indentation-based Quds UX)
  // -------------------------------------------------------------------------

  /// Handles pressing Enter at [cursorOffset], preserving indentation,
  /// auto-indenting after `:` blocks, and auto-dedenting after `return`/`break`.
  QudsEditResult handleNewline(
    String text,
    int cursorOffset, {
    int indent = 2,
  }) {
    final pos = cursorOffset.clamp(0, text.length);
    final lineStart = pos == 0
        ? 0
        : (text[pos - 1] == '\n' ? pos : text.lastIndexOf('\n', pos - 1) + 1);
    final lineBeforeCursor = text.substring(lineStart, pos);
    final leadingSpaces =
        lineBeforeCursor.length - lineBeforeCursor.trimLeft().length;
    final trimmedRaw = lineBeforeCursor.trim();
    final trimmed = _stripLineComment(trimmedRaw).trim();

    // Check remaining text on the same line after the cursor.
    final nextNl = text.indexOf('\n', pos);
    final lineEnd = nextNl < 0 ? text.length : nextNl;
    final restOfLine = text.substring(pos, lineEnd);

    // Pressing Enter on a whitespace-only indented line exits one indent level
    // cleanly (and strips stray spaces from the blank line).
    if (trimmedRaw.isEmpty && restOfLine.trim().isEmpty && leadingSpaces > 0) {
      final nextIndent = (leadingSpaces - indent).clamp(0, leadingSpaces);
      final replacement = '\n${' ' * nextIndent}';
      final updated = text.replaceRange(lineStart, lineEnd, replacement);
      return QudsEditResult(
        text: updated,
        selectionStart: lineStart + replacement.length,
      );
    }

    var nextIndent = leadingSpaces;
    if (trimmed.endsWith(':')) {
      nextIndent += indent;
    } else if (trimmed == 'return' ||
        trimmed.startsWith('return ') ||
        trimmed == 'break' ||
        trimmed.startsWith('break ') ||
        trimmed == 'continue' ||
        trimmed.startsWith('continue ') ||
        trimmed == 'pass' ||
        trimmed.startsWith('throw ')) {
      nextIndent = (leadingSpaces - indent).clamp(0, leadingSpaces);
    }

    final insertion = '\n${' ' * nextIndent}';
    // If splitting mid-line, strip leading spaces from the moved remainder.
    final leadingRestSpaces = restOfLine.length - restOfLine.trimLeft().length;
    final updated =
        text.replaceRange(pos, pos + leadingRestSpaces, insertion);
    return QudsEditResult(
      text: updated,
      selectionStart: pos + insertion.length,
    );
  }

  /// Smart backspace: when the cursor is inside leading indentation whitespace,
  /// deletes back to the previous indent stop (VS Code style). Returns `null`
  /// when normal single-character backspace should occur.
  QudsEditResult? handleBackspace(
    String text,
    int cursorOffset, {
    int indent = 2,
  }) {
    final pos = cursorOffset.clamp(0, text.length);
    if (pos == 0) return null;
    final lineStart =
        text[pos - 1] == '\n' ? pos : text.lastIndexOf('\n', pos - 1) + 1;
    final before = text.substring(lineStart, pos);
    if (before.isEmpty || before.trim().isNotEmpty) return null;

    // Delete back to the previous indent stop (e.g. 4 -> 2, 3 -> 2, 2 -> 0).
    final remainder = before.length % indent;
    final removeCount = remainder == 0 ? indent : remainder;
    final deleteStart = (pos - removeCount).clamp(lineStart, pos);
    final updated = text.replaceRange(deleteStart, pos, '');
    return QudsEditResult(
      text: updated,
      selectionStart: deleteStart,
    );
  }

  /// Auto-dedents block continuation clauses (`else:`, `elif ...:`, `catch ...:`,
  /// `finally:`) when the user types `:` at the end of an indented line.
  /// Returns `null` if no dedent adjustment is needed.
  QudsEditResult? handleTypedColon(
    String text,
    int cursorOffset, {
    int indent = 2,
  }) {
    final pos = cursorOffset.clamp(0, text.length);
    if (pos == 0 || text[pos - 1] != ':') return null;
    final lineStart = text.lastIndexOf('\n', pos - 1) + 1;
    final lineBefore = text.substring(lineStart, pos);
    final leadingSpaces = lineBefore.length - lineBefore.trimLeft().length;
    if (leadingSpaces < indent) return null;

    final trimmed = lineBefore.trim();
    final isContinuation = trimmed == 'else:' ||
        trimmed.startsWith('elif ') ||
        trimmed.startsWith('else if ') ||
        trimmed == 'catch:' ||
        trimmed.startsWith('catch ') ||
        trimmed == 'finally:';
    if (!isContinuation) return null;

    // Only dedent if the previous non-empty line is indented at least as deep.
    final prevText = lineStart > 0 ? text.substring(0, lineStart - 1) : '';
    final prevLines = prevText.split('\n');
    int? prevIndent;
    for (var i = prevLines.length - 1; i >= 0; i--) {
      if (prevLines[i].trim().isNotEmpty) {
        prevIndent = prevLines[i].length - prevLines[i].trimLeft().length;
        break;
      }
    }
    if (prevIndent == null || prevIndent < leadingSpaces) return null;

    final remove = indent.clamp(0, leadingSpaces);
    final updated = text.replaceRange(lineStart, lineStart + remove, '');
    return QudsEditResult(
      text: updated,
      selectionStart: pos - remove,
    );
  }

  static String _stripLineComment(String line) {
    var inSingle = false;
    var inDouble = false;
    var escaped = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == r'\' && (inSingle || inDouble)) {
        escaped = true;
        continue;
      }
      if (ch == "'" && !inDouble) {
        inSingle = !inSingle;
      } else if (ch == '"' && !inSingle) {
        inDouble = !inDouble;
      } else if (ch == '#' && !inSingle && !inDouble) {
        return line.substring(0, i);
      }
    }
    return line;
  }

  /// Indents or outdents the selected line(s) by [indent] spaces (VS Code style).
  QudsEditResult handleTab(
    String text,
    int selectionStart,
    int selectionEnd, {
    bool outdent = false,
    int indent = 2,
  }) {
    final s = selectionStart.clamp(0, text.length);
    final e = selectionEnd.clamp(s, text.length);
    final pad = ' ' * indent;

    if (s == e && !outdent) {
      final lineStart = s == 0 ? 0 : text.lastIndexOf('\n', s - 1) + 1;
      final before = text.substring(lineStart, s);
      final spacesToInsert = before.trim().isEmpty
          ? (indent - (before.length % indent))
          : indent;
      final insert = ' ' * spacesToInsert;
      final updated = text.replaceRange(s, e, insert);
      return QudsEditResult(
        text: updated,
        selectionStart: s + spacesToInsert,
      );
    }

    final blockStart = s == 0 ? 0 : text.lastIndexOf('\n', s - 1) + 1;
    final nextNl = text.indexOf('\n', e);
    final blockEnd = nextNl < 0 ? text.length : nextNl;
    final block = text.substring(blockStart, blockEnd);
    final lines = block.split('\n');
    var firstLineDelta = 0;
    var totalDelta = 0;

    final transformed = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!outdent) {
        transformed.add('$pad$line');
        if (i == 0) firstLineDelta = indent;
        totalDelta += indent;
      } else {
        var remove = 0;
        while (remove < indent && remove < line.length && line[remove] == ' ') {
          remove++;
        }
        transformed.add(line.substring(remove));
        if (i == 0) firstLineDelta = -remove;
        totalDelta -= remove;
      }
    }

    final replacement = transformed.join('\n');
    final updated = text.replaceRange(blockStart, blockEnd, replacement);
    return QudsEditResult(
      text: updated,
      selectionStart: (s + firstLineDelta).clamp(blockStart, updated.length),
      selectionEnd: (e + totalDelta).clamp(blockStart, updated.length),
    );
  }

  /// Toggles `# ` line comments across all lines intersecting `[selectionStart, selectionEnd]`.
  QudsEditResult toggleLineComment(
    String text,
    int selectionStart,
    int selectionEnd,
  ) {
    final s = selectionStart.clamp(0, text.length);
    final e = selectionEnd.clamp(s, text.length);
    final blockStart = s == 0 ? 0 : text.lastIndexOf('\n', s - 1) + 1;
    final nextNl = text.indexOf('\n', e);
    final blockEnd = nextNl < 0 ? text.length : nextNl;
    final lines = text.substring(blockStart, blockEnd).split('\n');

    final nonEmpty = lines.where((l) => l.trim().isNotEmpty).toList();
    final allCommented = nonEmpty.isNotEmpty &&
        nonEmpty.every((l) => l.trimLeft().startsWith('#'));

    final out = <String>[];
    for (final line in lines) {
      if (line.trim().isEmpty) {
        out.add(line);
        continue;
      }
      final lead = line.length - line.trimLeft().length;
      final prefix = line.substring(0, lead);
      final body = line.substring(lead);
      if (allCommented) {
        if (body.startsWith('# ')) {
          out.add('$prefix${body.substring(2)}');
        } else if (body.startsWith('#')) {
          out.add('$prefix${body.substring(1)}');
        } else {
          out.add(line);
        }
      } else {
        out.add('$prefix# $body');
      }
    }

    final replacement = out.join('\n');
    final updated = text.replaceRange(blockStart, blockEnd, replacement);
    final delta = replacement.length - (blockEnd - blockStart);
    return QudsEditResult(
      text: updated,
      selectionStart: s,
      selectionEnd: (e + delta).clamp(blockStart, updated.length),
    );
  }

  /// Applies a list of [QudsTextEdit]s (e.g. from a [QudsQuickFix]) safely.
  String applyEdits(String text, List<QudsTextEdit> edits) {
    final sorted = List<QudsTextEdit>.from(edits)
      ..sort((a, b) => b.startOffset.compareTo(a.startOffset));
    var out = text;
    for (final edit in sorted) {
      final start = edit.startOffset.clamp(0, out.length);
      final end = edit.endOffset.clamp(start, out.length);
      out = out.replaceRange(start, end, edit.replacement);
    }
    return out;
  }

  // -------------------------------------------------------------------------
  // Internals: Analysis, Diagnostics, Completion
  // -------------------------------------------------------------------------

  QudsEditorDiagnostic _fromCompilerException(
    CompilerException err,
    String source,
    List<int> lineStarts,
  ) {
    final start = _offsetFromLineStarts(
        lineStarts, err.span.line, err.span.column, source.length);
    final len = err.span.length > 0 ? err.span.length : 1;
    final end = (start + len).clamp(start, source.length);
    return QudsEditorDiagnostic(
      code: err.code,
      message: err.message,
      severity: QudsDiagnosticSeverity.error,
      line: err.span.line,
      column: err.span.column,
      startOffset: start,
      endOffset: end,
      help: _diagnosticHint(err.code, err.message),
    );
  }

  void _runPolicyAndStaticChecks(
    List<Statement> statements,
    String source,
    List<int> lineStarts,
    List<QudsEditorDiagnostic> diagnostics,
  ) {
    final policy = _effectivePolicy;
    final knownHostUris = {for (final m in _effectiveHostModules) m.uri};
    final topBindings = <String, Binding>{};

    void checkStatements(List<Statement> stmts, {required bool isTopLevel}) {
      for (final stmt in stmts) {
        if (stmt is ImportDeclaration) {
          final target = libraryTarget(stmt.uri);
          final section = librarySection(stmt.uri);
          final start = _offsetFromLineStarts(
              lineStarts, stmt.span.line, stmt.span.column, source.length);
          final end = (start + stmt.span.length).clamp(start, source.length);

          if (policy != null) {
            if (!policy.allowImports) {
              diagnostics.add(QudsEditorDiagnostic(
                code: 'P101',
                message: 'Imports are disabled by policy `${policy.name}`.',
                severity: QudsDiagnosticSeverity.error,
                line: stmt.span.line,
                column: stmt.span.column,
                startOffset: start,
                endOffset: end,
              ));
              continue;
            }
            if (!policy.isLibraryAllowed(stmt.uri)) {
              diagnostics.add(QudsEditorDiagnostic(
                code: 'P102',
                message:
                    'Library `${stmt.uri}` is not allowed by active policy `${policy.name}`.',
                severity: QudsDiagnosticSeverity.error,
                line: stmt.span.line,
                column: stmt.span.column,
                startOffset: start,
                endOffset: end,
                help: policy.allowedLibraries == null
                    ? null
                    : 'Allowed libraries: ${policy.allowedLibraries!.join(', ')}',
              ));
              continue;
            }
          }

          // Validate `quds:*` library & section existence
          if (target.startsWith('quds:')) {
            final libName = sdkLibraryName(target);
            if (libName == null ||
                (!embeddedSdk.containsKey(libName) &&
                    !knownHostUris.contains(target))) {
              diagnostics.add(QudsEditorDiagnostic(
                code: 'E900',
                message: 'Unknown Quds SDK library `$target`.',
                severity: QudsDiagnosticSeverity.error,
                line: stmt.span.line,
                column: stmt.span.column,
                startOffset: start,
                endOffset: end,
                help:
                    'Available SDK libraries: ${QudsSdkCatalog.libraryNames.map((n) => 'quds:$n').join(', ')}',
              ));
            } else if (section != null && embeddedSdk.containsKey(libName)) {
              final validSections = QudsSdkCatalog.sectionsOf(libName);
              final ok = validSections
                  .any((s) => s == section || s.startsWith('$section::'));
              if (!ok) {
                diagnostics.add(QudsEditorDiagnostic(
                  code: 'E900',
                  message: 'Library `$target` has no section `::$section`.',
                  severity: QudsDiagnosticSeverity.error,
                  line: stmt.span.line,
                  column: stmt.span.column,
                  startOffset: start,
                  endOffset: end,
                  help: validSections.isEmpty
                      ? null
                      : 'Available sections: ${validSections.take(10).join(', ')}',
                ));
              }
            }
          }
          continue;
        }

        if (stmt is FunctionDeclaration && stmt.isAsync) {
          if (policy != null && !policy.allowAsync) {
            final start = _offsetFromLineStarts(
                lineStarts, stmt.span.line, stmt.span.column, source.length);
            diagnostics.add(QudsEditorDiagnostic(
              code: 'P103',
              message:
                  'Async function `${stmt.name}` is disabled by policy `${policy.name}`.',
              severity: QudsDiagnosticSeverity.error,
              line: stmt.span.line,
              column: stmt.span.column,
              startOffset: start,
              endOffset: (start + stmt.name.length).clamp(start, source.length),
            ));
          }
        }

        if (stmt is ClassDeclaration &&
            policy != null &&
            !policy.allowClasses) {
          final start = _offsetFromLineStarts(
              lineStarts, stmt.span.line, stmt.span.column, source.length);
          diagnostics.add(QudsEditorDiagnostic(
            code: 'P104',
            message:
                'Class declaration `${stmt.name}` is disabled by policy `${policy.name}`.',
            severity: QudsDiagnosticSeverity.error,
            line: stmt.span.line,
            column: stmt.span.column,
            startOffset: start,
            endOffset: (start + stmt.name.length).clamp(start, source.length),
          ));
        }

        if (stmt is Binding) {
          final wantsMut = stmt.mode == BindingMode.mutable ||
              stmt.mode == BindingMode.shadowMutable ||
              stmt.mode == BindingMode.lateMutable;
          final start = _offsetFromLineStarts(
              lineStarts, stmt.span.line, stmt.span.column, source.length);
          if (wantsMut && policy != null && !policy.allowMutation) {
            diagnostics.add(QudsEditorDiagnostic(
              code: 'P105',
              message:
                  'Mutable binding `var ${stmt.name}` is disabled by policy `${policy.name}`.',
              severity: QudsDiagnosticSeverity.error,
              line: stmt.span.line,
              column: stmt.span.column,
              startOffset: start,
              endOffset:
                  (start + stmt.name.length + 4).clamp(start, source.length),
            ));
          }

          if (isTopLevel) {
            final prev = topBindings[stmt.name];
            if (prev != null &&
                stmt.mode == BindingMode.inferred &&
                prev.mode == BindingMode.inferred) {
              final prevStart = _offsetFromLineStarts(
                  lineStarts, prev.span.line, prev.span.column, source.length);
              diagnostics.add(QudsEditorDiagnostic(
                code: 'E202',
                message:
                    'Cannot reassign immutable binding `${stmt.name}` (defined on line ${prev.span.line}).',
                severity: QudsDiagnosticSeverity.error,
                line: stmt.span.line,
                column: stmt.span.column,
                startOffset: start,
                endOffset:
                    (start + stmt.name.length).clamp(start, source.length),
                help:
                    'Declare `${stmt.name}` with `var ${stmt.name} = ...` to allow reassignment.',
                quickFixes: [
                  QudsQuickFix(
                    title: 'Make `${stmt.name}` mutable (`var ${stmt.name}`)',
                    edits: [
                      QudsTextEdit(
                        startOffset: prevStart,
                        endOffset: prevStart,
                        replacement: 'var ',
                      ),
                    ],
                  ),
                ],
              ));
            } else {
              topBindings[stmt.name] = stmt;
            }
          }
        }

        // Recurse into nested bodies for policy checks
        if (stmt is IfStatement) {
          checkStatements(stmt.thenBody, isTopLevel: false);
          checkStatements(stmt.elseBody, isTopLevel: false);
        } else if (stmt is ForStatement) {
          checkStatements(stmt.body, isTopLevel: false);
        } else if (stmt is WhileStatement) {
          checkStatements(stmt.body, isTopLevel: false);
        } else if (stmt is FunctionDeclaration && stmt.body != null) {
          checkStatements(stmt.body!, isTopLevel: false);
        }
      }
    }

    checkStatements(statements, isTopLevel: true);
  }

  void _extractSymbols(
    List<Statement> statements,
    List<QudsDocumentSymbol> out,
  ) {
    for (final stmt in statements) {
      if (stmt is FunctionDeclaration) {
        final params = stmt.parameters
            .map((p) => p.type == '<infer>' ? p.name : '${p.name}: ${p.type}')
            .join(', ');
        final ret = stmt.returnType != null && stmt.returnType!.isNotEmpty
            ? ' -> ${stmt.returnType}'
            : '';
        out.add(QudsDocumentSymbol(
          name: stmt.name,
          kind: 'function',
          line: stmt.span.line,
          column: stmt.span.column,
          detail: '${stmt.name}($params)$ret',
        ));
      } else if (stmt is ClassDeclaration) {
        final children = <QudsDocumentSymbol>[
          for (final f in stmt.fields)
            QudsDocumentSymbol(
              name: f.name,
              kind: 'field',
              line: f.span.line,
              column: f.span.column,
              detail: '${f.name}: ${f.type}',
            ),
          for (final m in stmt.methods)
            QudsDocumentSymbol(
              name: m.name,
              kind: 'method',
              line: m.span.line,
              column: m.span.column,
              detail:
                  '${m.name}(${m.parameters.map((p) => p.name).join(', ')})',
            ),
        ];
        out.add(QudsDocumentSymbol(
          name: stmt.name,
          kind: stmt.kind,
          line: stmt.span.line,
          column: stmt.span.column,
          detail: '${stmt.kind} ${stmt.name}',
          children: children,
        ));
      } else if (stmt is Binding) {
        out.add(QudsDocumentSymbol(
          name: stmt.name,
          kind: stmt.mode == BindingMode.constant ? 'constant' : 'variable',
          line: stmt.span.line,
          column: stmt.span.column,
          detail: stmt.type != null ? '${stmt.name}: ${stmt.type}' : stmt.name,
        ));
      } else if (stmt is SectionDeclaration && stmt.path.isNotEmpty) {
        out.add(QudsDocumentSymbol(
          name: ':: ${stmt.path}',
          kind: 'section',
          line: stmt.span.line,
          column: stmt.span.column,
        ));
      }
    }
  }

  List<QudsCompletionItem> _completeImport(String typed) {
    final policy = _effectivePolicy;
    final items = <QudsCompletionItem>[];

    // Section completion (`quds:math::...`)
    if (typed.contains('::')) {
      final idx = typed.indexOf('::');
      final libUri = typed.substring(0, idx);
      final secPrefix = typed.substring(idx + 2).toLowerCase();
      final libName = sdkLibraryName(libUri);
      if (libName != null) {
        for (final sec in QudsSdkCatalog.sectionsOf(libName)) {
          if (sec.toLowerCase().startsWith(secPrefix)) {
            items.add(QudsCompletionItem(
              label: sec,
              insertText: sec,
              kind: QudsCompletionKind.section,
              detail: '$libUri::$sec',
              sortPriority: 10,
            ));
          }
        }
      }
      return items;
    }

    final lower = typed.toLowerCase();
    final candidates = <(String, String)>[
      (
        'quds:math',
        '20-domain mathematics SDK (stats, geometry, linalg, graph, calculus, ...)'
      ),
      (
        'quds:viz',
        'Interactive 2D geometry scenes, plots, tables, matrices, and LaTeX'
      ),
      ('quds:core', 'Core data structures (Stack, Queue, Result, typed views)'),
      (
        'quds:collection',
        'Collection helpers, sorting, grouping, and specialized structures'
      ),
      ('quds:text', 'Unicode text utilities, encoding, and string helpers'),
      (
        'quds:json',
        'Typed JSON validation, path queries, pretty printing, and deep merge'
      ),
      (
        'quds:async',
        'Timeouts, cancellation, concurrency, channels, debouncer, and throttler'
      ),
      ('quds:ext', 'Standard extension methods'),
      ('dart:math', 'Dart standard mathematics library'),
      ('dart:convert', 'Dart JSON/UTF-8/Base64 encoders and decoders'),
      for (final mod in _effectiveHostModules)
        if (!mod.uri.startsWith('quds:'))
          (mod.uri, mod.description ?? 'Host-provided module'),
    ];

    for (final (uri, desc) in candidates) {
      if (policy != null && !policy.isLibraryAllowed(uri)) continue;
      if (uri.toLowerCase().startsWith(lower)) {
        items.add(QudsCompletionItem(
          label: uri,
          insertText: uri,
          kind: QudsCompletionKind.module,
          detail: desc,
          documentation: desc,
          sortPriority: 10,
        ));
      }
    }
    return items;
  }

  List<QudsCompletionItem> _completeMember(
    String source,
    String receiver,
    String prefix,
  ) {
    final lower = prefix.toLowerCase();
    final items = <QudsCompletionItem>[];

    // 1. Loop context `$`
    if (receiver == r'$') {
      for (final entry in loopContextDocs.entries) {
        if (entry.key.toLowerCase().startsWith(lower)) {
          items.add(QudsCompletionItem(
            label: entry.key,
            insertText: entry.key,
            kind: QudsCompletionKind.property,
            detail: 'LoopContext.${entry.key}',
            documentation: entry.value,
            sortPriority: 5,
          ));
        }
      }
      for (final extra in const ['first', 'last', 'count', 'prev', 'next']) {
        if (extra.startsWith(lower) && !loopContextDocs.containsKey(extra)) {
          items.add(QudsCompletionItem(
            label: extra,
            insertText: extra,
            kind: QudsCompletionKind.property,
            detail: 'LoopContext.$extra',
            sortPriority: 8,
          ));
        }
      }
      return items;
    }

    // 2. Check prefixed imports (`use quds:viz as viz`, `use quds:math as m`, `use host:fs as fs`)
    final imports = _parseImportsFromSource(source);
    for (final imp in imports) {
      if (imp.prefix != receiver) continue;
      final target = libraryTarget(imp.uri);
      final section = librarySection(imp.uri);

      // Host module (including `quds:viz`)
      for (final mod in _effectiveHostModules) {
        if (mod.uri == target) {
          for (final doc in mod.docs) {
            if (doc.name.toLowerCase().startsWith(lower)) {
              items.add(QudsCompletionItem(
                label: doc.name,
                insertText: doc.kind == 'function' ? '${doc.name}(' : doc.name,
                kind: doc.kind == 'function'
                    ? QudsCompletionKind.function
                    : QudsCompletionKind.constant,
                detail: doc.signature ?? '${mod.uri}.${doc.name}',
                documentation: doc.documentation,
                sortPriority: 10,
              ));
            }
          }
          return items;
        }
      }

      // Embedded SDK library
      final libName = sdkLibraryName(target);
      if (libName != null) {
        for (final sym in QudsSdkCatalog.symbolsOf(libName, section: section)) {
          if (sym.name.toLowerCase().startsWith(lower)) {
            items.add(QudsCompletionItem(
              label: sym.name,
              insertText: sym.kind == 'function' ? '${sym.name}(' : sym.name,
              kind: _kindFromSdk(sym.kind),
              detail: sym.signature,
              documentation: sym.documentation,
              sortPriority: 15,
            ));
          }
        }
        return items;
      }
    }

    // 3. Detect `viz.scene(...)` variable -> interactive geometry scene builder methods!
    if (RegExp('\\b${RegExp.escape(receiver)}\\s*=\\s*[A-Za-z_][A-Za-z0-9_]*\\.scene\\s*\\(')
            .hasMatch(source) ||
        RegExp('\\b${RegExp.escape(receiver)}\\s*=\\s*scene\\s*\\(')
            .hasMatch(source)) {
      for (final (name, sig, doc) in _sceneBuilderMethods) {
        if (name.toLowerCase().startsWith(lower)) {
          items.add(QudsCompletionItem(
            label: name,
            insertText: '$name(',
            kind: QudsCompletionKind.method,
            detail: sig,
            documentation: doc,
            sortPriority: 8,
          ));
        }
      }
      return items;
    }

    // 4. Inspect live QudsSession workspace value if present
    final live = session?.getVariable(receiver);
    if (live is QudsNamespace) {
      for (final entry in live.members.entries) {
        if (entry.key.toLowerCase().startsWith(lower)) {
          final isFn = entry.value is QudsCallable;
          items.add(QudsCompletionItem(
            label: entry.key,
            insertText: isFn ? '${entry.key}(' : entry.key,
            kind:
                isFn ? QudsCompletionKind.method : QudsCompletionKind.property,
            detail: isFn ? '${entry.key}(...)' : qudsTypeName(entry.value),
            sortPriority: 10,
          ));
        }
      }
      return items;
    }
    if (live is QudsInstance) {
      for (final f in live.fields.keys) {
        if (f.toLowerCase().startsWith(lower)) {
          items.add(QudsCompletionItem(
            label: f,
            insertText: f,
            kind: QudsCompletionKind.field,
            detail:
                '${live.qudsClass.name}.$f: ${qudsTypeName(live.fields[f])}',
            sortPriority: 10,
          ));
        }
      }
      for (final m in live.qudsClass.methods.values) {
        if (m.name.toLowerCase().startsWith(lower)) {
          items.add(QudsCompletionItem(
            label: m.name,
            insertText: '${m.name}(',
            kind: QudsCompletionKind.method,
            detail: '${m.name}(${m.parameters.map((p) => p.name).join(', ')})',
            sortPriority: 12,
          ));
        }
      }
      return items;
    }

    // 5. Infer common type members from live workspace or source text
    final inferredType = _inferReceiverType(source, receiver, live);
    for (final (name, sig, kind) in _membersForCommonType(inferredType)) {
      if (name.toLowerCase().startsWith(lower)) {
        items.add(QudsCompletionItem(
          label: name,
          insertText: kind == QudsCompletionKind.method ? '$name(' : name,
          kind: kind,
          detail: sig,
          sortPriority: 20,
        ));
      }
    }
    return items;
  }

  List<QudsCompletionItem> _completeGeneral(String source, String prefix) {
    final lower = prefix.toLowerCase();
    final items = <QudsCompletionItem>[];
    final seen = <String>{};

    void add(QudsCompletionItem item) {
      if (!item.label.toLowerCase().startsWith(lower)) return;
      if (seen.add('${item.kind.name}:${item.label}')) {
        items.add(item);
      }
    }

    // 1. Local declarations in current editor buffer
    for (final local in _collectLocalSymbols(source)) {
      add(local);
    }

    // 2. Live session workspace variables
    if (session != null) {
      for (final ws in session!.workspace.values) {
        add(QudsCompletionItem(
          label: ws.name,
          insertText: ws.name,
          kind: QudsCompletionKind.variable,
          detail: '${ws.typeName} = ${ws.summary}',
          documentation:
              'Workspace variable (`${ws.typeName}`): `${ws.summary}`',
          sortPriority: 12,
        ));
      }
    }

    // 3. Imported symbols from `use ...` directives in this buffer
    for (final imp in _importedSymbolsForSource(source)) {
      add(imp);
    }

    // 4. Core builtins
    for (final b in _coreBuiltinCompletions()) {
      add(b);
    }

    // 5. Quds keywords with official documentation
    for (final entry in keywordDocumentation.entries) {
      add(QudsCompletionItem(
        label: entry.key,
        insertText: entry.key,
        kind: QudsCompletionKind.keyword,
        detail: 'keyword',
        documentation: entry.value,
        sortPriority: 40,
      ));
    }

    // 6. High-value Quds snippets
    for (final snip in _qudsSnippets) {
      add(snip);
    }

    items.sort((a, b) {
      final byPrio = a.sortPriority.compareTo(b.sortPriority);
      if (byPrio != 0) return byPrio;
      return a.label.compareTo(b.label);
    });
    return items;
  }

  List<ImportDeclaration> _parseImportsFromSource(String source) {
    try {
      final tokens = const Lexer().tokenize(source, file: '<complete>');
      final program = Parser(tokens).parse(partial: true);
      return program.statements.whereType<ImportDeclaration>().toList();
    } catch (_) {
      // Fallback regex scan for broken buffers so autocomplete still works while typing!
      final out = <ImportDeclaration>[];
      final re = RegExp(
          r'^\s*use\s+([A-Za-z0-9_:/.-]+)(?:\s+as\s+([A-Za-z_][A-Za-z0-9_]*))?',
          multiLine: true);
      for (final m in re.allMatches(source)) {
        out.add(ImportDeclaration(
            m.group(1)!, m.group(2), const SourceSpan(1, 1, 1)));
      }
      return out;
    }
  }

  List<QudsCompletionItem> _importedSymbolsForSource(String source) {
    final items = <QudsCompletionItem>[];
    final imports = _parseImportsFromSource(source);
    for (final imp in imports) {
      if (imp.prefix != null) {
        items.add(QudsCompletionItem(
          label: imp.prefix!,
          insertText: imp.prefix!,
          kind: QudsCompletionKind.module,
          detail: 'module ${imp.uri}',
          sortPriority: 15,
        ));
        continue;
      }
      final target = libraryTarget(imp.uri);
      final section = librarySection(imp.uri);

      for (final mod in _effectiveHostModules) {
        if (mod.uri == target) {
          for (final doc in mod.docs) {
            if (imp.show.isNotEmpty && !imp.show.contains(doc.name)) continue;
            if (imp.hide.contains(doc.name)) continue;
            items.add(QudsCompletionItem(
              label: doc.name,
              insertText: doc.kind == 'function' ? '${doc.name}(' : doc.name,
              kind: doc.kind == 'function'
                  ? QudsCompletionKind.function
                  : QudsCompletionKind.constant,
              detail: doc.signature ?? '${mod.uri}.${doc.name}',
              documentation: doc.documentation,
              sortPriority: 22,
            ));
          }
        }
      }

      final libName = sdkLibraryName(target);
      if (libName != null && embeddedSdk.containsKey(libName)) {
        for (final sym in QudsSdkCatalog.symbolsOf(libName, section: section)) {
          if (imp.show.isNotEmpty && !imp.show.contains(sym.name)) continue;
          if (imp.hide.contains(sym.name)) continue;
          items.add(QudsCompletionItem(
            label: sym.name,
            insertText: sym.kind == 'function' ? '${sym.name}(' : sym.name,
            kind: _kindFromSdk(sym.kind),
            detail: sym.signature,
            documentation: sym.documentation,
            sortPriority: 24,
          ));
        }
      }
    }
    return items;
  }

  List<QudsCompletionItem> _collectLocalSymbols(String source) {
    final items = <QudsCompletionItem>[];
    try {
      final tokens = const Lexer().tokenize(source, file: '<complete>');
      final program = Parser(tokens).parse(partial: true);
      for (final stmt in program.statements) {
        if (stmt is FunctionDeclaration) {
          final params = stmt.parameters
              .map((p) => p.type == '<infer>' ? p.name : '${p.name}: ${p.type}')
              .join(', ');
          final ret = stmt.returnType != null && stmt.returnType!.isNotEmpty
              ? ' -> ${stmt.returnType}'
              : '';
          items.add(QudsCompletionItem(
            label: stmt.name,
            insertText: '${stmt.name}(',
            kind: QudsCompletionKind.function,
            detail: '${stmt.name}($params)$ret',
            documentation: stmt.documentation,
            sortPriority: 8,
          ));
        } else if (stmt is ClassDeclaration) {
          items.add(QudsCompletionItem(
            label: stmt.name,
            insertText: stmt.name,
            kind: QudsCompletionKind.classType,
            detail: '${stmt.kind} ${stmt.name}',
            documentation: stmt.documentation,
            sortPriority: 9,
          ));
        } else if (stmt is Binding) {
          items.add(QudsCompletionItem(
            label: stmt.name,
            insertText: stmt.name,
            kind: stmt.mode == BindingMode.constant
                ? QudsCompletionKind.constant
                : QudsCompletionKind.variable,
            detail: stmt.type ?? 'local binding',
            sortPriority: 10,
          ));
        }
      }
    } catch (_) {
      // Fallback regex scan for variables/functions in broken code
      final bindRe = RegExp(
          r'^(?:var\s+|const\s+|shadow\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=]+)?=',
          multiLine: true);
      for (final m in bindRe.allMatches(source)) {
        final name = m.group(1)!;
        items.add(QudsCompletionItem(
          label: name,
          insertText: name,
          kind: QudsCompletionKind.variable,
          detail: 'local binding',
          sortPriority: 10,
        ));
      }
    }
    return items;
  }

  QudsCompletionItem? _findLocalSymbol(String source, String name) {
    for (final item in _collectLocalSymbols(source)) {
      if (item.label == name) return item;
    }
    return null;
  }

  String _inferReceiverType(String source, String receiver, Object? live) {
    if (live is List) return 'List';
    if (live is String) return 'String';
    if (live is Map) return 'Map';
    if (live is Set) return 'Set';
    if (live is num) return 'num';
    final esc = RegExp.escape(receiver);
    if (RegExp('\\b$esc\\s*(?::\\s*List[^=]*)?=\\s*\\[').hasMatch(source)) {
      return 'List';
    }
    if (RegExp('\\b$esc\\s*(?::\\s*String)?=\\s*["\']').hasMatch(source)) {
      return 'String';
    }
    if (RegExp('\\b$esc\\s*(?::\\s*Map[^=]*)?=\\s*map:').hasMatch(source)) {
      return 'Map';
    }
    if (RegExp('\\b$esc\\s*=\\s*Vec2\\(').hasMatch(source)) return 'Vec2';
    return 'Object';
  }

  List<(String, String, QudsCompletionKind)> _membersForCommonType(
      String type) {
    switch (type) {
      case 'List':
        return const [
          ('length', 'int', QudsCompletionKind.property),
          ('isEmpty', 'bool', QudsCompletionKind.property),
          ('isNotEmpty', 'bool', QudsCompletionKind.property),
          ('first', 'T', QudsCompletionKind.property),
          ('last', 'T', QudsCompletionKind.property),
          ('add', 'add(value: T) -> void', QudsCompletionKind.method),
          (
            'addAll',
            'addAll(items: Iterable<T>) -> void',
            QudsCompletionKind.method
          ),
          ('map', 'map(fn: (T) -> R) -> List<R>', QudsCompletionKind.method),
          (
            'where',
            'where(test: (T) -> bool) -> List<T>',
            QudsCompletionKind.method
          ),
          (
            'fold',
            'fold(init: R, combine: (R, T) -> R) -> R',
            QudsCompletionKind.method
          ),
          (
            'join',
            'join(separator: String = "") -> String',
            QudsCompletionKind.method
          ),
          ('sort', 'sort([compare]) -> void', QudsCompletionKind.method),
          (
            'contains',
            'contains(element: Object?) -> bool',
            QudsCompletionKind.method
          ),
          (
            'sublist',
            'sublist(start: int, [end: int]) -> List<T>',
            QudsCompletionKind.method
          ),
          ('toSet', 'toSet() -> Set<T>', QudsCompletionKind.method),
        ];
      case 'String':
        return const [
          ('length', 'int', QudsCompletionKind.property),
          ('isEmpty', 'bool', QudsCompletionKind.property),
          ('trim', 'trim() -> String', QudsCompletionKind.method),
          (
            'split',
            'split(pattern: String) -> List<String>',
            QudsCompletionKind.method
          ),
          (
            'contains',
            'contains(other: String) -> bool',
            QudsCompletionKind.method
          ),
          (
            'startsWith',
            'startsWith(prefix: String) -> bool',
            QudsCompletionKind.method
          ),
          (
            'endsWith',
            'endsWith(suffix: String) -> bool',
            QudsCompletionKind.method
          ),
          (
            'replaceAll',
            'replaceAll(from: String, to: String) -> String',
            QudsCompletionKind.method
          ),
          ('toLowerCase', 'toLowerCase() -> String', QudsCompletionKind.method),
          ('toUpperCase', 'toUpperCase() -> String', QudsCompletionKind.method),
          (
            'substring',
            'substring(start: int, [end: int]) -> String',
            QudsCompletionKind.method
          ),
        ];
      case 'Map':
        return const [
          ('length', 'int', QudsCompletionKind.property),
          ('isEmpty', 'bool', QudsCompletionKind.property),
          ('keys', 'List<K>', QudsCompletionKind.property),
          ('values', 'List<V>', QudsCompletionKind.property),
          ('entries', 'List<MapEntry<K, V>>', QudsCompletionKind.property),
          (
            'containsKey',
            'containsKey(key: Object?) -> bool',
            QudsCompletionKind.method
          ),
          ('remove', 'remove(key: Object?) -> V?', QudsCompletionKind.method),
        ];
      case 'num':
        return const [
          ('abs', 'abs() -> num', QudsCompletionKind.method),
          ('floor', 'floor() -> int', QudsCompletionKind.method),
          ('ceil', 'ceil() -> int', QudsCompletionKind.method),
          ('round', 'round() -> int', QudsCompletionKind.method),
          (
            'clamp',
            'clamp(low: num, high: num) -> num',
            QudsCompletionKind.method
          ),
          ('toDouble', 'toDouble() -> double', QudsCompletionKind.method),
          ('toInt', 'toInt() -> int', QudsCompletionKind.method),
          (
            'toStringAsFixed',
            'toStringAsFixed(digits: int) -> String',
            QudsCompletionKind.method
          ),
        ];
      case 'Vec2':
        return const [
          ('x', 'double', QudsCompletionKind.field),
          ('y', 'double', QudsCompletionKind.field),
        ];
      default:
        return const [
          ('toString', 'toString() -> String', QudsCompletionKind.method),
        ];
    }
  }

  List<QudsCompletionItem> _coreBuiltinCompletions() => const [
        QudsCompletionItem(
          label: 'print',
          insertText: 'print ',
          kind: QudsCompletionKind.function,
          detail: 'print(value: Object?) -> void',
          documentation: 'Prints a value to the output stream.',
          sortPriority: 28,
        ),
        QudsCompletionItem(
          label: 'range',
          insertText: 'range(',
          kind: QudsCompletionKind.function,
          detail: 'range(start: int, end: int) -> Range<int>',
          documentation: 'Inclusive integer range from start through end.',
          sortPriority: 28,
        ),
        QudsCompletionItem(
          label: 'min',
          insertText: 'min(',
          kind: QudsCompletionKind.function,
          detail: 'min(a: num, b: num) -> num',
          documentation: 'Returns the smaller of two numbers.',
          sortPriority: 28,
        ),
        QudsCompletionItem(
          label: 'max',
          insertText: 'max(',
          kind: QudsCompletionKind.function,
          detail: 'max(a: num, b: num) -> num',
          documentation: 'Returns the larger of two numbers.',
          sortPriority: 28,
        ),
        QudsCompletionItem(
          label: 'Ok',
          insertText: 'Ok(',
          kind: QudsCompletionKind.function,
          detail: 'Ok(value: T) -> Result<T, Never>',
          documentation: 'Wraps a successful Result value.',
          sortPriority: 29,
        ),
        QudsCompletionItem(
          label: 'Error',
          insertText: 'Error(',
          kind: QudsCompletionKind.function,
          detail: 'Error(error: E) -> Result<Never, E>',
          documentation: 'Wraps an error Result value.',
          sortPriority: 29,
        ),
      ];

  QudsCompletionKind _kindFromSdk(String kind) => switch (kind) {
        'function' => QudsCompletionKind.function,
        'class' => QudsCompletionKind.classType,
        'constant' => QudsCompletionKind.constant,
        _ => QudsCompletionKind.variable,
      };

  static const _sceneBuilderMethods = <(String, String, String)>[
    (
      'point',
      'point(id: String, x, y, draggable: bool = false, label: String?, color: String?)',
      'Adds a 2D point or draggable handle to the scene.'
    ),
    (
      'segment',
      'segment(id: String, a, b, color: String?, dashed: bool = false)',
      'Adds a finite line segment between two points.'
    ),
    (
      'line',
      'line(id: String, a, b, color: String?, dashed: bool = false)',
      'Adds an infinite line passing through two points.'
    ),
    (
      'circle',
      'circle(id: String, center, radius: double, stroke: String?, fill: String?)',
      'Adds a circle with center and radius.'
    ),
    (
      'arc',
      'arc(id: String, center, radius: double, startAngle: double, endAngle: double)',
      'Adds a circular arc in radians.'
    ),
    (
      'polygon',
      'polygon(id: String, points: List, stroke: String?, fill: String?)',
      'Adds a closed or open polygon.'
    ),
    (
      'mesh',
      'mesh(prefix: String, triangles: List, vertices: List?)',
      'Adds a triangulated mesh (accepts triangulatePolygon output directly).'
    ),
    (
      'vector',
      'vector(id: String, origin, tip, label: String?, color: String?)',
      'Adds a directed 2D vector arrow.'
    ),
    (
      'angle',
      'angle(id: String, a, vertex, b, showDegrees: bool = true)',
      'Measures and displays the angle ∠AVB.'
    ),
    (
      'curve',
      'curve(id: String, points: List, color: String?)',
      'Adds a sampled smooth polyline/parametric curve.'
    ),
    (
      'label',
      'label(id: String, point, text: String, color: String?)',
      'Adds a text label at world coordinates.'
    ),
    (
      'render',
      'render() -> QudsGeometrySceneOutput',
      'Emits the completed interactive geometry scene to the host UI.'
    ),
  ];

  static const _qudsSnippets = <QudsCompletionItem>[
    QudsCompletionItem(
      label: 'for-in',
      insertText: 'for item in items:\n  print item',
      kind: QudsCompletionKind.snippet,
      detail: 'For-in loop',
      isSnippet: true,
      sortPriority: 60,
    ),
    QudsCompletionItem(
      label: 'if-else',
      insertText: 'if condition:\n  \nelse:\n  ',
      kind: QudsCompletionKind.snippet,
      detail: 'If / else block',
      isSnippet: true,
      sortPriority: 60,
    ),
    QudsCompletionItem(
      label: 'viz-scene',
      insertText:
          'use quds:viz as viz\nscene = viz.scene(title: "Geometry", grid: true, interactive: true)\nscene.point("A", 0.0, 0.0, draggable: true)\nscene.render()',
      kind: QudsCompletionKind.snippet,
      detail: 'Interactive 2D geometry scene template',
      isSnippet: true,
      sortPriority: 61,
    ),
  ];

  List<QudsFoldRange> _computeFoldRanges(String source) {
    final lines = source.split('\n');
    final ranges = <QudsFoldRange>[];
    final stack = <(int line, int indent)>[];

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      if (raw.trim().isEmpty || raw.trimLeft().startsWith('#')) continue;
      final ind = raw.length - raw.trimLeft().length;
      while (stack.isNotEmpty && ind <= stack.last.$2) {
        final start = stack.removeLast();
        if (i > start.$1) {
          ranges.add(QudsFoldRange(startLine: start.$1, endLine: i));
        }
      }
      if (raw.trimRight().endsWith(':')) {
        stack.add((i + 1, ind));
      }
    }
    while (stack.isNotEmpty) {
      final start = stack.removeLast();
      if (lines.length > start.$1) {
        ranges.add(QudsFoldRange(startLine: start.$1, endLine: lines.length));
      }
    }
    return ranges;
  }

  List<int> _computeLineStarts(String source) {
    final starts = <int>[0];
    for (var i = 0; i < source.length; i++) {
      if (source.codeUnitAt(i) == 10) starts.add(i + 1);
    }
    return starts;
  }

  int _offsetFromLineStarts(
      List<int> starts, int line, int column, int maxLen) {
    final l = (line - 1).clamp(0, starts.length - 1);
    final c = (column - 1).clamp(0, maxLen);
    return (starts[l] + c).clamp(0, maxLen);
  }

  int _offsetForLineColumn(String source, int line, int column) =>
      _offsetFromLineStarts(
          _computeLineStarts(source), line, column, source.length);

  (int, int)? _wordRangeAt(String source, int offset) {
    if (offset < 0 || offset > source.length) return null;
    bool isWord(int c) =>
        (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        (c >= 48 && c <= 57) ||
        c == 95 ||
        c >= 0x80;
    var idx = offset;
    if (idx == source.length || !isWord(source.codeUnitAt(idx))) {
      if (idx > 0 && isWord(source.codeUnitAt(idx - 1))) {
        idx--;
      } else {
        return null;
      }
    }
    var start = idx;
    while (start > 0 && isWord(source.codeUnitAt(start - 1))) {
      start--;
    }
    var end = idx + 1;
    while (end < source.length && isWord(source.codeUnitAt(end))) {
      end++;
    }
    return (start, end);
  }

  String? _diagnosticHint(String code, String message) {
    if (message.contains('Expected :')) {
      return 'Quds blocks start with `:` followed by an indented block.';
    }
    if (message.contains('indentation') || message.contains('indent')) {
      return 'Use consistent 2-space indentation for blocks.';
    }
    if (code == 'E202') {
      return 'Bindings without `var` are immutable. Prefix with `var` to reassign.';
    }
    return null;
  }
}
