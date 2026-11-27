/// Embedded pure-Dart Quds Code Editor & Language Engine.
///
/// Provides syntax/semantic highlighting, official formatting (`formatQuds`),
/// live syntax + policy-aware diagnostics with quick fixes, context-aware
/// autocomplete (including live `QudsSession` workspace, `quds:*` SDKs,
/// `::sections`, `quds:viz`, and `QudsHostModule`s), hover documentation,
/// signature help, document outline, folding, and indentation-aware editing.
///
/// Contains zero `dart:io` or Flutter dependencies — works cleanly on Flutter
/// Desktop, Mobile, Web, and Dart CLI without affecting `quds lsp` or desktop
/// editor extensions.
library quds.editor_engine;

export 'src/editor_engine/editor_engine.dart' show QudsEditorEngine;
export 'src/editor_engine/highlighter.dart' show highlightQudsSource;
export 'src/editor_engine/models.dart'
    show
        QudsCompletionItem,
        QudsCompletionKind,
        QudsDiagnosticSeverity,
        QudsDocumentSymbol,
        QudsEditResult,
        QudsEditorAnalysis,
        QudsEditorDiagnostic,
        QudsEditorThemePalette,
        QudsFoldRange,
        QudsHighlightSpan,
        QudsHoverInfo,
        QudsQuickFix,
        QudsSignatureHelp,
        QudsTextEdit,
        QudsTokenCategory;
export 'src/editor_engine/sdk_catalog.dart' show QudsSdkCatalog, QudsSdkSymbol;
