/// Data models for the pure-Dart embedded Quds Code Editor Engine.
///
/// Zero `dart:io` or Flutter dependencies — binds cleanly to Flutter
/// `TextEditingController`, Web editors, or desktop IDE widgets.
library;

/// Semantic & lexical token categories for syntax highlighting.
enum QudsTokenCategory {
  keyword,
  controlKeyword,
  declarationKeyword,
  literalKeyword,
  typeName,
  functionName,
  methodName,
  variable,
  parameter,
  property,
  number,
  duration,
  string,
  interpolation,
  comment,
  docComment,
  operator,
  punctuation,
  annotation,
  sectionHeader,
  builtin,
  error,
}

/// A highlighted span in UTF-16 code-unit offsets matching Dart [String] indices.
class QudsHighlightSpan {
  const QudsHighlightSpan({
    required this.startOffset,
    required this.endOffset,
    required this.line,
    required this.column,
    required this.category,
    required this.text,
  });

  final int startOffset;
  final int endOffset;
  final int line;
  final int column;
  final QudsTokenCategory category;
  final String text;

  int get length => endOffset - startOffset;

  Map<String, Object?> toJson() => {
        'start': startOffset,
        'end': endOffset,
        'line': line,
        'column': column,
        'category': category.name,
      };
}

/// Ready-to-use ARGB color palette for dark and light Quds code editors.
class QudsEditorThemePalette {
  const QudsEditorThemePalette({
    required this.background,
    required this.foreground,
    required this.gutterBackground,
    required this.gutterForeground,
    required this.activeLineBackground,
    required this.breakpointColor,
    required this.pausedLineBackground,
    required this.colors,
  });

  factory QudsEditorThemePalette.dark() => const QudsEditorThemePalette(
        background: 0xFF0F172A,
        foreground: 0xFFE2E8F0,
        gutterBackground: 0xFF0B1120,
        gutterForeground: 0xFF64748B,
        activeLineBackground: 0xFF1E293B,
        breakpointColor: 0xFFEF4444,
        pausedLineBackground: 0x44F59E0B,
        colors: {
          QudsTokenCategory.keyword: 0xFF38BDF8,
          QudsTokenCategory.controlKeyword: 0xFFC084FC,
          QudsTokenCategory.declarationKeyword: 0xFF60A5FA,
          QudsTokenCategory.literalKeyword: 0xFFF472B6,
          QudsTokenCategory.typeName: 0xFF2DD4BF,
          QudsTokenCategory.functionName: 0xFFFBBF24,
          QudsTokenCategory.methodName: 0xFFFCD34D,
          QudsTokenCategory.variable: 0xFFE2E8F0,
          QudsTokenCategory.parameter: 0xFFBAE6FD,
          QudsTokenCategory.property: 0xFF93C5FD,
          QudsTokenCategory.number: 0xFFFB923C,
          QudsTokenCategory.duration: 0xFFFB923C,
          QudsTokenCategory.string: 0xFF4ADE80,
          QudsTokenCategory.interpolation: 0xFFFDE047,
          QudsTokenCategory.comment: 0xFF64748B,
          QudsTokenCategory.docComment: 0xFF94A3B8,
          QudsTokenCategory.operator: 0xFF94A3B8,
          QudsTokenCategory.punctuation: 0xFF94A3B8,
          QudsTokenCategory.annotation: 0xFFE879F9,
          QudsTokenCategory.sectionHeader: 0xFF34D399,
          QudsTokenCategory.builtin: 0xFF38BDF8,
          QudsTokenCategory.error: 0xFFF87171,
        },
      );

  factory QudsEditorThemePalette.light() => const QudsEditorThemePalette(
        background: 0xFFFFFFFF,
        foreground: 0xFF0F172A,
        gutterBackground: 0xFFF8FAFC,
        gutterForeground: 0xFF94A3B8,
        activeLineBackground: 0xFFF1F5F9,
        breakpointColor: 0xFFDC2626,
        pausedLineBackground: 0x33F59E0B,
        colors: {
          QudsTokenCategory.keyword: 0xFF0284C7,
          QudsTokenCategory.controlKeyword: 0xFF7C3AED,
          QudsTokenCategory.declarationKeyword: 0xFF2563EB,
          QudsTokenCategory.literalKeyword: 0xFFDB2777,
          QudsTokenCategory.typeName: 0xFF0D9488,
          QudsTokenCategory.functionName: 0xFFB45309,
          QudsTokenCategory.methodName: 0xFFD97706,
          QudsTokenCategory.variable: 0xFF0F172A,
          QudsTokenCategory.parameter: 0xFF0369A1,
          QudsTokenCategory.property: 0xFF1D4ED8,
          QudsTokenCategory.number: 0xFFC2410C,
          QudsTokenCategory.duration: 0xFFC2410C,
          QudsTokenCategory.string: 0xFF15803D,
          QudsTokenCategory.interpolation: 0xFFA16207,
          QudsTokenCategory.comment: 0xFF64748B,
          QudsTokenCategory.docComment: 0xFF475569,
          QudsTokenCategory.operator: 0xFF475569,
          QudsTokenCategory.punctuation: 0xFF475569,
          QudsTokenCategory.annotation: 0xFFA21CAF,
          QudsTokenCategory.sectionHeader: 0xFF059669,
          QudsTokenCategory.builtin: 0xFF0284C7,
          QudsTokenCategory.error: 0xFFDC2626,
        },
      );

  final int background;
  final int foreground;
  final int gutterBackground;
  final int gutterForeground;
  final int activeLineBackground;
  final int breakpointColor;
  final int pausedLineBackground;
  final Map<QudsTokenCategory, int> colors;

  int colorFor(QudsTokenCategory category) => colors[category] ?? foreground;
}

/// Diagnostic severity for editor error squiggles and problem panels.
enum QudsDiagnosticSeverity { error, warning, info, hint }

/// A single text replacement range (UTF-16 offsets).
class QudsTextEdit {
  const QudsTextEdit({
    required this.startOffset,
    required this.endOffset,
    required this.replacement,
  });

  final int startOffset;
  final int endOffset;
  final String replacement;
}

/// An actionable quick-fix attached to an editor diagnostic.
class QudsQuickFix {
  const QudsQuickFix({required this.title, required this.edits});

  final String title;
  final List<QudsTextEdit> edits;
}

/// A live diagnostic reported by [QudsEditorEngine.analyze].
class QudsEditorDiagnostic {
  const QudsEditorDiagnostic({
    required this.code,
    required this.message,
    required this.severity,
    required this.line,
    required this.column,
    required this.startOffset,
    required this.endOffset,
    this.help,
    this.quickFixes = const [],
  });

  final String code;
  final String message;
  final QudsDiagnosticSeverity severity;
  final int line;
  final int column;
  final int startOffset;
  final int endOffset;
  final String? help;
  final List<QudsQuickFix> quickFixes;

  Map<String, Object?> toJson() => {
        'code': code,
        'message': message,
        'severity': severity.name,
        'line': line,
        'column': column,
        'startOffset': startOffset,
        'endOffset': endOffset,
        if (help != null) 'help': help,
      };
}

/// Autocomplete suggestion category.
enum QudsCompletionKind {
  keyword,
  function,
  method,
  variable,
  field,
  classType,
  module,
  section,
  snippet,
  constant,
  property,
}

/// One autocomplete suggestion returned by [QudsEditorEngine.completeAt].
class QudsCompletionItem {
  const QudsCompletionItem({
    required this.label,
    required this.insertText,
    required this.kind,
    this.detail,
    this.documentation,
    this.sortPriority = 50,
    this.isSnippet = false,
  });

  final String label;
  final String insertText;
  final QudsCompletionKind kind;
  final String? detail;
  final String? documentation;
  final int sortPriority;
  final bool isSnippet;

  Map<String, Object?> toJson() => {
        'label': label,
        'insertText': insertText,
        'kind': kind.name,
        if (detail != null) 'detail': detail,
        if (documentation != null) 'documentation': documentation,
      };
}

/// Hover card content for the token under the pointer/cursor.
class QudsHoverInfo {
  const QudsHoverInfo({
    required this.title,
    required this.documentation,
    required this.startOffset,
    required this.endOffset,
    this.signature,
  });

  final String title;
  final String? signature;
  final String documentation;
  final int startOffset;
  final int endOffset;
}

/// Active function call signature help (parameter hints).
class QudsSignatureHelp {
  const QudsSignatureHelp({
    required this.functionName,
    required this.label,
    required this.parameters,
    required this.activeParameter,
    this.documentation,
  });

  final String functionName;
  final String label;
  final List<String> parameters;
  final int activeParameter;
  final String? documentation;
}

/// Outline symbol entry (function, class, field, variable, section).
class QudsDocumentSymbol {
  const QudsDocumentSymbol({
    required this.name,
    required this.kind,
    required this.line,
    required this.column,
    this.detail,
    this.children = const [],
  });

  final String name;
  final String kind;
  final int line;
  final int column;
  final String? detail;
  final List<QudsDocumentSymbol> children;
}

/// Foldable line range (1-based inclusive).
class QudsFoldRange {
  const QudsFoldRange({
    required this.startLine,
    required this.endLine,
    this.kind = 'block',
  });

  final int startLine;
  final int endLine;
  final String kind;
}

/// Complete analysis snapshot produced by [QudsEditorEngine.analyze].
class QudsEditorAnalysis {
  const QudsEditorAnalysis({
    required this.highlights,
    required this.diagnostics,
    required this.symbols,
    required this.foldRanges,
    required this.validSyntax,
  });

  final List<QudsHighlightSpan> highlights;
  final List<QudsEditorDiagnostic> diagnostics;
  final List<QudsDocumentSymbol> symbols;
  final List<QudsFoldRange> foldRanges;
  final bool validSyntax;

  bool get hasErrors =>
      diagnostics.any((d) => d.severity == QudsDiagnosticSeverity.error);
}

/// Result of a smart editing operation (`handleNewline`, `handleTab`, etc.).
class QudsEditResult {
  const QudsEditResult({
    required this.text,
    required this.selectionStart,
    int? selectionEnd,
  }) : selectionEnd = selectionEnd ?? selectionStart;

  final String text;
  final int selectionStart;
  final int selectionEnd;
}
