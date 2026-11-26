/// Core Quds language compiler library.
///
/// Exposes the Quds lexer, parser, typed AST, static semantic analyzer,
/// Dart code generator, formatter, quick-fix engine, source maps, and LSP/DAP
/// editor protocol helpers.
library quds;

export 'src/ast.dart';
export 'src/constants.dart'
    show
        ConstValue,
        ConstBool,
        ConstInt,
        ConstDouble,
        ConstString,
        ConstNull,
        ConstList;
export 'src/compiler.dart';
export 'src/hash.dart' show sha256Hex;
export 'src/navigate.dart'
    show breakpointAt, breakpointOnLine, definitionAt, renameAt;
export 'src/format.dart' show formatQuds;
export 'src/diagnostics_format.dart' show diagnosticHelp, formatRichDiagnostic;
export 'src/fix.dart' show AppliedFix, FixResult, fixQudsSource;
export 'src/protocol.dart'
    show encodeFrame, respondDebug, respondLsp, LspExchange, LspSession;
export 'src/debug.dart'
    show DebugAction, DebugBinary, DebugTranslator, desktopLaunchEnvironment;
export 'src/sourcemap.dart'
    show
        encodeSourceMap,
        mapStack,
        preferQudsSnippet,
        sourceMapFor,
        QudsLocal,
        SourcePositions;
export 'src/emitter.dart';
export 'src/lexer.dart';
export 'src/parser.dart';
export 'src/semantics.dart';
