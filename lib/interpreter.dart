/// Embedded pure-Dart Quds language interpreter, policy engine, native AST
/// debugger, and rich scientific / interactive geometry output protocol.
///
/// Zero `dart:io` dependencies — runs natively inside Flutter Desktop, Mobile,
/// Web, and Dart VM/CLI applications.
library quds.interpreter;

export 'src/source.dart' show CompilerException, SourceSpan;
export 'src/interpreter/data_module.dart' show buildQudsDataModule;
export 'src/interpreter/debugger.dart'
    show
        QudsBreakpoint,
        QudsDebugController,
        QudsDebugHistoryEntry,
        QudsDebugPauseEvent,
        QudsDebugPausedRuntimeEvent,
        QudsDebugResumedRuntimeEvent,
        QudsFrameEvaluator,
        QudsPauseReason,
        QudsWatchResult;
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
export 'src/interpreter/formula_engine.dart'
    show QudsFormulaEngine, QudsFormulaValidationResult;
export 'src/interpreter/host_bridge.dart'
    show QudsHostModule, QudsHostModuleBuilder, QudsHostSymbolDoc;
export 'src/interpreter/module_loader.dart'
    show
        QudsImportAllow,
        QudsImportDeny,
        QudsImportProvideSource,
        QudsImportProvideSymbols,
        QudsImportResolution,
        QudsImportResolver,
        QudsModuleLoader;
export 'src/interpreter/notebook.dart'
    show
        QudsNotebook,
        QudsNotebookCell,
        QudsNotebookCellKind,
        QudsNotebookRunSummary;
export 'src/interpreter/outputs.dart'
    show
        QudsAnimationSpec,
        QudsFormOutput,
        QudsGeoAngle,
        QudsGeoArc,
        QudsGeoBounds,
        QudsGeoCircle,
        QudsGeoCurve,
        QudsGeoLabel,
        QudsGeoLine,
        QudsGeoPoint,
        QudsGeoPolygon,
        QudsGeoPrimitive,
        QudsGeoSegment,
        QudsGeoVector,
        QudsGeometrySceneOutput,
        QudsGraphEdge,
        QudsGraphNode,
        QudsGraphOutput,
        QudsInteractiveInput,
        QudsMatrixOutput,
        QudsOutput,
        QudsPlot2DOutput,
        QudsPlotSeries,
        QudsSurface3DOutput,
        QudsTableOutput,
        QudsTextOutput,
        QudsVectorFieldArrow,
        QudsVectorFieldOutput;
export 'src/interpreter/policy.dart'
    show
        QudsCallInterceptEvent,
        QudsCallInterceptor,
        QudsCapability,
        QudsExecutionPolicy,
        QudsInterceptDecision,
        QudsPermissionCallback,
        QudsPermissionDecision,
        QudsPermissionRequest,
        QudsStatementInterceptEvent,
        QudsStatementInterceptor;
export 'src/interpreter/profiler.dart'
    show QudsCallNode, QudsLineProfile, QudsProfiler;
export 'src/interpreter/session.dart' show QudsRunResult, QudsSession;
export 'src/interpreter/stream_bridge.dart'
    show QudsStreamBridge, QudsStreamSample;
export 'src/interpreter/values.dart'
    show
        QudsCallContext,
        QudsCallable,
        QudsClass,
        QudsErrorEvent,
        QudsFuture,
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
export 'src/interpreter/viz_module.dart' show buildQudsVizModule;
