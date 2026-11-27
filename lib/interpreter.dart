/// Embedded pure-Dart Quds language interpreter.
///
/// Designed for embedding Quds inside scientific applications, interactive
/// notebooks, Flutter Desktop/Mobile/Web apps, and policy-governed scripting
/// hosts — with zero `dart:io` dependencies.
library quds.interpreter;

export 'src/source.dart' show CompilerException, SourceSpan;
export 'src/interpreter/environment.dart' show QudsEnvironment, QudsSlot;
export 'src/interpreter/evaluator.dart'
    show CallHook, ImportHook, QudsEvaluator, StatementHook;
export 'src/interpreter/exceptions.dart'
    show
        QudsConversionError,
        QudsPolicyViolationException,
        QudsPolicyViolationKind,
        QudsRuntimeException,
        QudsStackFrame;
export 'src/interpreter/module_loader.dart'
    show
        QudsImportAllow,
        QudsImportDeny,
        QudsImportProvideSource,
        QudsImportProvideSymbols,
        QudsImportResolution,
        QudsImportResolver,
        QudsModuleLoader;
export 'src/interpreter/session.dart' show QudsRunResult, QudsSession;
export 'src/interpreter/values.dart'
    show
        QudsCallContext,
        QudsCallable,
        QudsClass,
        QudsErrorEvent,
        QudsHostCallback,
        QudsInstance,
        QudsLoopContext,
        QudsMissing,
        QudsNamespace,
        QudsNativeFunction,
        QudsOptional,
        QudsOutputEvent,
        QudsOverloadSet,
        QudsPrintEvent,
        QudsRange,
        QudsRecord,
        QudsResult,
        QudsRuntimeEvent,
        QudsStepProgressEvent,
        QudsUserFunction,
        QudsWorkspaceEntry,
        qudsEquals,
        qudsFormatValue,
        qudsSummarizeValue,
        qudsTypeName;
