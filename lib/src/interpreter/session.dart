/// Stateful scientific session (`QudsSession`) integrating execution policies,
/// capability-gated host modules, native AST debugging, `quds:viz` interactive
/// geometry/plotting, and persistent MATLAB-like workspace state.
///
/// 100% pure Dart (zero `dart:io` imports).
library;

import 'dart:async';
import 'dart:math' as math;

import '../ast.dart';
import '../lexer.dart';
import '../parser.dart';
import 'assets_module.dart';
import 'bytecode_vm.dart';
import 'universal_vm.dart';
import 'dart_stdlib_bridge.dart';
import 'data_module.dart';
import 'debugger.dart';
import 'environment.dart';
import 'evaluator.dart';
import 'exceptions.dart';
import 'host_bridge.dart';
import 'module_loader.dart';
import 'outputs.dart';
import 'pen_module.dart';
import 'policy.dart';
import 'profiler.dart';
import 'values.dart';
import 'viz_module.dart';
import 'workspace.dart';

/// Result returned by executing a Quds script or notebook cell in [QudsSession].
class QudsRunResult {
  const QudsRunResult({
    required this.succeeded,
    this.value,
    this.printedLines = const [],
    this.outputs = const [],
    this.stepsExecuted = 0,
    this.elapsed = Duration.zero,
    this.error,
    this.usedBytecodeVm = false,
  });

  /// Whether execution completed without uncaught parse, runtime, or policy error.
  final bool succeeded;

  /// Value of the last expression statement (if any).
  final Object? value;

  /// All lines emitted via `print(...)` during this run.
  final List<String> printedLines;

  /// Structured rich outputs emitted during this run (plots, geometry, tables, etc.).
  final List<Object> outputs;

  /// Total AST or bytecode steps executed during this run.
  final int stepsExecuted;

  /// Wall-clock duration of this run.
  final Duration elapsed;

  /// The caught error when [succeeded] is false (`CompilerException`,
  /// `QudsRuntimeException`, or `QudsPolicyViolationException`).
  final Object? error;

  /// Whether this run was accelerated by the stack-based [QudsBytecodeVm].
  final bool usedBytecodeVm;

  /// Joined stdout lines.
  String get stdout => printedLines.join('\n');

  /// Convenience getter for the last emitted [QudsGeometrySceneOutput], if any.
  QudsGeometrySceneOutput? get lastGeometryScene {
    for (var i = outputs.length - 1; i >= 0; i--) {
      final out = outputs[i];
      if (out is QudsGeometrySceneOutput) return out;
    }
    return null;
  }

  /// Convenience getter for the last emitted [QudsPlot2DOutput], if any.
  QudsPlot2DOutput? get lastPlot {
    for (var i = outputs.length - 1; i >= 0; i--) {
      final out = outputs[i];
      if (out is QudsPlot2DOutput) return out;
    }
    return null;
  }

  /// Convenience getter for the last emitted [QudsSurface3DOutput], if any.
  QudsSurface3DOutput? get lastSurface3D {
    for (var i = outputs.length - 1; i >= 0; i--) {
      final out = outputs[i];
      if (out is QudsSurface3DOutput) return out;
    }
    return null;
  }

  /// Convenience getter for the last emitted [QudsVectorFieldOutput], if any.
  QudsVectorFieldOutput? get lastVectorField {
    for (var i = outputs.length - 1; i >= 0; i--) {
      final out = outputs[i];
      if (out is QudsVectorFieldOutput) return out;
    }
    return null;
  }

  /// Convenience getter for the last emitted [QudsGraphOutput], if any.
  QudsGraphOutput? get lastGraph {
    for (var i = outputs.length - 1; i >= 0; i--) {
      final out = outputs[i];
      if (out is QudsGraphOutput) return out;
    }
    return null;
  }

  /// Convenience getter for the last emitted [QudsFormOutput], if any.
  QudsFormOutput? get lastForm {
    for (var i = outputs.length - 1; i >= 0; i--) {
      final out = outputs[i];
      if (out is QudsFormOutput) return out;
    }
    return null;
  }

  /// Active animation specification attached to any output in this run, if any.
  QudsAnimationSpec? get animationSpec {
    for (var i = outputs.length - 1; i >= 0; i--) {
      final out = outputs[i];
      if (out is QudsGeometrySceneOutput && out.animation != null) {
        return out.animation;
      }
      if (out is QudsPlot2DOutput && out.animation != null) {
        return out.animation;
      }
      if (out is QudsSurface3DOutput && out.animation != null) {
        return out.animation;
      }
      if (out is QudsVectorFieldOutput && out.animation != null) {
        return out.animation;
      }
      if (out is QudsGraphOutput && out.animation != null) {
        return out.animation;
      }
    }
    return null;
  }
}

/// Persistent interactive workspace for interpreting Quds code, similar to
/// a MATLAB / Jupyter scientific session.
class QudsSession {
  QudsSession({
    QudsExecutionPolicy? policy,
    this.debugger,
    this.profiler,
    QudsWorkspace? projectWorkspace,
    this.allowTopLevelRebind = false,
    List<QudsHostModule> hostModules = const [],
    int? maxSteps,
    Duration? timeout,
    int? maxCallDepth,
    int? maxCollectionLength,
    int? maxStringLength,
    int? maxLoopIterations,
    int? yieldEveryNSteps,
    bool? allowMutation,
    bool? allowAsync,
    bool? allowClasses,
    bool? allowExceptions,
    bool? allowImports,
    Set<String>? allowedLibraries,
    Set<String>? deniedLibraries,
    QudsImportResolver? importResolver,
    Map<String, Map<String, Object?>> virtualModules = const {},
    ImportHook? onImport,
    StatementHook? onBeforeStatement,
    CallHook? onBeforeCall,
  })  : _onImport = onImport,
        _onBeforeStatement = onBeforeStatement,
        _onBeforeCall = onBeforeCall,
        policy = (policy ?? const QudsExecutionPolicy()).copyWith(
          maxSteps: maxSteps,
          timeout: timeout,
          maxCallDepth: maxCallDepth,
          maxCollectionLength: maxCollectionLength,
          maxStringLength: maxStringLength,
          maxLoopIterations: maxLoopIterations,
          yieldEveryNSteps: yieldEveryNSteps,
          allowMutation: allowMutation,
          allowAsync: allowAsync,
          allowClasses: allowClasses,
          allowExceptions: allowExceptions,
          allowImports: allowImports,
          allowedLibraries: allowedLibraries,
          deniedLibraries: deniedLibraries,
          importResolver: importResolver,
        ) {
    _globalEnv = QudsEnvironment(
      isGlobal: true,
      allowTopLevelRebind: allowTopLevelRebind,
    );
    _installCoreBuiltins(_globalEnv);
    _initModuleLoader(virtualModules: virtualModules);
    if (projectWorkspace != null) {
      attachWorkspace(projectWorkspace);
    }
    for (final mod in hostModules) {
      registerHostModule(mod);
    }
  }

  /// Active execution policy governing resource budgets, libraries, and capabilities.
  final QudsExecutionPolicy policy;

  /// Optional native AST debugger attached to this session.
  final QudsDebugController? debugger;

  /// Optional execution profiler & recursive call-tree tracer.
  final QudsProfiler? profiler;

  /// Whether top-level immutable bindings may be rebound across separate runs.
  final bool allowTopLevelRebind;

  final ImportHook? _onImport;
  final StatementHook? _onBeforeStatement;
  final CallHook? _onBeforeCall;

  late QudsEnvironment _globalEnv;
  late QudsModuleLoader _moduleLoader;
  QudsWorkspace? _projectWorkspace;
  final StreamController<QudsRuntimeEvent> _events =
      StreamController<QudsRuntimeEvent>.broadcast();
  final Set<String> _builtinNames = {};
  final Map<String, QudsHostModule> _hostModules = {};
  final Map<String, Object?> _interactiveInputs = {};
  final Map<String, Object?> _simulationState = {};
  String? _lastInteractiveSource;
  String _lastInteractiveFile = '<session>';
  String? _cachedProgramSource;
  String? _cachedProgramFile;
  Program? _cachedProgram;
  QudsUniversalChunk? _cachedUniversalChunk;
  QudsEvaluator? _activeEvaluator;
  List<String>? _activePrinted;
  List<Object>? _activeOutputs;

  /// Attached multi-file [QudsWorkspace] project, if any.
  QudsWorkspace? get projectWorkspace => _projectWorkspace;

  /// Attaches (or detaches when `null`) a multi-file [QudsWorkspace] to this
  /// session with automatic transitive cache invalidation on file edits.
  void attachWorkspace(QudsWorkspace? workspace) {
    _projectWorkspace?.removeChangeListener(_onWorkspaceFileChanged);
    _projectWorkspace = workspace;
    _moduleLoader.workspace = workspace;
    _moduleLoader.clearWorkspaceCache();
    workspace?.addChangeListener(_onWorkspaceFileChanged);
  }

  void _onWorkspaceFileChanged(String path) {
    _moduleLoader.invalidateWorkspaceFile(path);
    if (_cachedProgramFile == path) {
      _cachedProgram = null;
      _cachedProgramSource = null;
      _cachedUniversalChunk = null;
    }
  }

  /// Live broadcast stream of print lines, rich outputs, debug pauses, errors, and progress.
  Stream<QudsRuntimeEvent> get events => _events.stream;

  /// Underlying global environment (also read by the embedded editor engine).
  QudsEnvironment get globalEnvironment => _globalEnv;

  /// All registered host modules (including built-in `quds:viz`).
  List<QudsHostModule> get hostModules =>
      List.unmodifiable(_hostModules.values);

  /// Current values of interactive controls (draggable points, sliders, toggles).
  Map<String, Object?> get interactiveInputs =>
      Map.unmodifiable(_interactiveInputs);

  /// Snapshot of user-defined variables in the current workspace (excluding builtins).
  Map<String, QudsWorkspaceEntry> get workspace {
    final result = <String, QudsWorkspaceEntry>{};
    for (final entry in _globalEnv.localSlots.entries) {
      if (_builtinNames.contains(entry.key) ||
          entry.key.startsWith('__quds_')) {
        continue;
      }
      final val = entry.value.value;
      result[entry.key] = QudsWorkspaceEntry(
        name: entry.key,
        value: val,
        typeName: qudsTypeName(val),
        mutable: entry.value.mutable,
        summary: qudsSummarizeValue(val),
      );
    }
    return Map.unmodifiable(result);
  }

  /// Injects or updates a variable in the workspace from the host app.
  void setVariable(String name, Object? value, {bool mutable = true}) {
    _globalEnv.define(name, value, mutable: mutable);
  }

  /// Reads a variable from the workspace (returns null if absent).
  Object? getVariable(String name) => _globalEnv.resolveSlot(name)?.value;

  /// Registers a host function callable directly by name from Quds code.
  void registerFunction(
    String name,
    QudsHostCallback callback, {
    String? requiredCapability,
    String? signature,
    String? documentation,
  }) {
    _globalEnv.define(
      name,
      QudsNativeFunction(
        name,
        callback,
        requiredCapability: requiredCapability,
        signature: signature,
        documentation: documentation,
      ),
    );
    _builtinNames.add(name);
  }

  /// Registers a structured [QudsHostModule] importable via `use <mod.uri>`.
  void registerHostModule(QudsHostModule module) {
    _hostModules[module.uri] = module;
    _moduleLoader.registerVirtualModule(module.uri, module.exports);
  }

  /// Registers raw virtual module symbols importable via `use <uri>`.
  void registerVirtualModule(String uri, Map<String, Object?> symbols) {
    _moduleLoader.registerVirtualModule(uri, symbols);
  }

  /// Clears all user-defined variables and functions, restoring core builtins
  /// and registered host modules.
  void clear() {
    _globalEnv.clearAll();
    _builtinNames.clear();
    _interactiveInputs.clear();
    _simulationState.clear();
    _lastInteractiveSource = null;
    _moduleLoader.clearSessionCache();
    _installCoreBuiltins(_globalEnv);
    _installBuiltInVizModule();
    for (final mod in _hostModules.values) {
      _moduleLoader.registerVirtualModule(mod.uri, mod.exports);
    }
  }

  /// Requests immediate cooperative stop of any currently running execution.
  void stop() {
    debugger?.stop();
    _activeEvaluator?.stop();
  }

  /// Releases the event stream controller and detaches any workspace listener.
  Future<void> dispose() async {
    stop();
    _projectWorkspace?.removeChangeListener(_onWorkspaceFileChanged);
    await _events.close();
  }

  void _initModuleLoader({
    Map<String, Map<String, Object?>> virtualModules = const {},
  }) {
    _moduleLoader = QudsModuleLoader(
      createBaseEnvironment: () {
        final env = QudsEnvironment(isGlobal: true);
        _installCoreBuiltins(env, recordAsBuiltins: false);
        return env;
      },
      createModuleEvaluator: (modEnv, impHook, {required bool isSdk}) {
        final debugActive =
            !isSdk && debugger != null && debugger!.hasActiveHooks;
        final profilerActive = !isSdk && profiler != null && profiler!.enabled;
        late QudsEvaluator modEval;
        modEval = QudsEvaluator(
          globalEnv: modEnv,
          onPrint: (text, span) {
            if (!isSdk) _activePrinted?.add(text);
            _events.add(QudsPrintEvent(text, span: span));
          },
          onOutput: (out, span) {
            if (!isSdk) {
              if (policy.maxOutputCount != null &&
                  _activeOutputs != null &&
                  _activeOutputs!.length >= policy.maxOutputCount!) {
                throw QudsPolicyViolationException(
                  QudsPolicyViolationKind.outputLimit,
                  'Exceeded maximum output limit (${policy.maxOutputCount}).',
                  span,
                );
              }
              _activeOutputs?.add(out);
            }
            _events.add(QudsOutputEvent(out, span: span));
          },
          onBeforeStatement: (!isSdk && (debugActive || profilerActive))
              ? (stmt, env) async {
                  if (profilerActive) {
                    profiler!.recordStatement(stmt.span);
                  }
                  if (debugActive) {
                    await debugger!.beforeStatement(
                      statement: stmt,
                      env: env,
                      globalEnv: modEnv,
                      evaluator: modEval,
                      emitPrint: (text, span) {
                        _activePrinted?.add(text);
                        _events.add(QudsPrintEvent(text, span: span));
                      },
                      emitEvent: _events.add,
                    );
                  }
                }
              : null,
          onImport: impHook,
          maxSteps: isSdk ? null : policy.maxSteps,
          timeout: isSdk ? null : policy.timeout,
          maxCallDepth: policy.maxCallDepth,
          maxCollectionLength: policy.maxCollectionLength,
          maxStringLength: policy.maxStringLength,
          maxLoopIterations: isSdk ? null : policy.maxLoopIterations,
          yieldEveryNSteps: policy.yieldEveryNSteps,
          allowMutation: isSdk ? true : policy.allowMutation,
          allowAsync: policy.allowAsync,
          allowClasses: isSdk ? true : policy.allowClasses,
          allowExceptions: isSdk ? true : policy.allowExceptions,
          allowImports: true,
          interactiveInputs: Map<String, Object?>.from(_interactiveInputs),
          profiler: profilerActive ? profiler : null,
        );
        return modEval;
      },
      virtualModules: virtualModules,
      allowedLibraries: policy.allowedLibraries,
      deniedLibraries: policy.deniedLibraries,
      importResolver: policy.importResolver,
      workspace: _projectWorkspace,
    );
    _installBuiltInVizModule();
  }

  void _installBuiltInVizModule() {
    final sharedInteractive = <String, QudsInteractiveInput>{};
    final viz = buildQudsVizModule(
      maxPrimitives: policy.maxPrimitives,
      maxOutputs: policy.maxOutputCount,
      persistentState: _simulationState,
      sharedInteractiveRegistry: sharedInteractive,
    );
    _hostModules[viz.uri] = viz;
    _moduleLoader.registerVirtualModule(viz.uri, viz.exports);
    final pen = buildQudsPenModule(
      maxPrimitives: policy.maxPrimitives,
      maxOutputs: policy.maxOutputCount,
      sharedInteractiveRegistry: sharedInteractive,
    );
    _hostModules[pen.uri] = pen;
    _moduleLoader.registerVirtualModule(pen.uri, pen.exports);
    final dataMod = buildQudsDataModule();
    _hostModules[dataMod.uri] = dataMod;
    _moduleLoader.registerVirtualModule(dataMod.uri, dataMod.exports);
    final assetsMod = buildQudsAssetsModule(
      getWorkspace: () => _projectWorkspace,
      allowMutation: () => policy.allowMutation,
    );
    _hostModules[assetsMod.uri] = assetsMod;
    _moduleLoader.registerVirtualModule(assetsMod.uri, assetsMod.exports);
  }

  Future<void> _handleImport(
      ImportDeclaration decl, QudsEnvironment env) async {
    if (_onImport != null) {
      await _onImport(decl, env);
      return;
    }
    await _moduleLoader.resolveImport(decl, env, fromFile: decl.span.file);
  }

  /// Executes a specific file inside the attached [projectWorkspace] (resolving
  /// all relative, parent `^.`, barrel `export`, and `package:` imports cleanly).
  Future<QudsRunResult> runFile(
    String filePath, {
    Map<String, Object?>? interactiveInputs,
    bool resetGlobalScope = true,
    bool resetWorkspaceModules = false,
    bool resetVizQuota = true,
    bool preferBytecode = true,
  }) async {
    final ws = _projectWorkspace;
    if (ws == null) {
      throw StateError(
          'No QudsWorkspace is attached to this session. Call attachWorkspace() first.');
    }
    final norm = QudsWorkspace.normalizePath(filePath);
    final source = ws.readFile(norm);
    if (source == null) {
      return QudsRunResult(
        succeeded: false,
        error: QudsRuntimeException(
          'Workspace file `$norm` not found.',
          SourceSpan(1, 1, 1, file: norm),
          code: 'E900',
        ),
      );
    }
    if (resetGlobalScope) {
      _resetUserGlobals(allowTopLevelRebind: true);
    }
    if (resetWorkspaceModules) {
      _moduleLoader.clearWorkspaceCache();
    }
    return _moduleLoader.runWithEntryFile(
      norm,
      () => run(
        source,
        file: norm,
        interactiveInputs: interactiveInputs,
        resetVizQuota: resetVizQuota,
        preferBytecode: preferBytecode,
      ),
    );
  }

  /// Executes the entry-point file (`projectWorkspace.entryPoint`) of the
  /// attached multi-file [QudsWorkspace].
  Future<QudsRunResult> runProject({
    Map<String, Object?>? interactiveInputs,
    bool resetGlobalScope = true,
    bool resetWorkspaceModules = false,
    bool resetVizQuota = true,
    bool preferBytecode = true,
  }) {
    final ws = _projectWorkspace;
    if (ws == null) {
      throw StateError(
          'No QudsWorkspace is attached to this session. Call attachWorkspace() first.');
    }
    return runFile(
      ws.entryPoint,
      interactiveInputs: interactiveInputs,
      resetGlobalScope: resetGlobalScope,
      resetWorkspaceModules: resetWorkspaceModules,
      resetVizQuota: resetVizQuota,
      preferBytecode: preferBytecode,
    );
  }

  void _resetUserGlobals({bool allowTopLevelRebind = false}) {
    final prevSlots = Map<String, QudsSlot>.from(_globalEnv.localSlots);
    _globalEnv = QudsEnvironment(
      isGlobal: true,
      allowTopLevelRebind: allowTopLevelRebind,
    );
    for (final entry in prevSlots.entries) {
      if (_builtinNames.contains(entry.key)) {
        _globalEnv.define(
          entry.key,
          entry.value.value,
          mutable: entry.value.mutable,
          isConst: entry.value.isConst,
          declaredType: entry.value.declaredType,
        );
      }
    }
  }

  /// Parses and executes Quds [source] inside this session's persistent workspace.
  Future<QudsRunResult> run(
    String source, {
    String file = '<session>',
    Map<String, Object?>? interactiveInputs,
    bool resetVizQuota = true,
    bool preferBytecode = true,
  }) async {
    if (interactiveInputs != null) {
      _interactiveInputs.addAll(interactiveInputs);
    }
    if (resetVizQuota) {
      _installBuiltInVizModule();
    }
    _lastInteractiveSource = source;
    _lastInteractiveFile = file;

    final stopwatch = Stopwatch()..start();
    final printed = <String>[];
    final outputs = <Object>[];

    Program program;
    if (_cachedProgram != null &&
        _cachedProgramSource == source &&
        _cachedProgramFile == file) {
      program = _cachedProgram!;
    } else {
      try {
        final tokens = Lexer().tokenize(source, file: file);
        program = Parser(tokens).parse();
        _cachedProgramSource = source;
        _cachedProgramFile = file;
        _cachedProgram = program;
        _cachedUniversalChunk = null;
      } catch (err) {
        stopwatch.stop();
        _events.add(QudsErrorEvent(err));
        return QudsRunResult(
          succeeded: false,
          printedLines: printed,
          outputs: outputs,
          elapsed: stopwatch.elapsed,
          error: err,
        );
      }
    }

    debugger?.resetForRun();
    profiler?.resetForRun();
    final debugActive = debugger != null && debugger!.hasActiveHooks;
    final profilerActive = profiler != null && profiler!.enabled;
    final needsStatementHook = policy.onStatementIntercept != null ||
        _onBeforeStatement != null ||
        debugActive ||
        profilerActive;
    final needsCallHook = policy.onCallIntercept != null ||
        _onBeforeCall != null ||
        policy.onPermissionCheck != null;

    final canUseTier1FastPath = preferBytecode &&
        !needsStatementHook &&
        !needsCallHook &&
        policy.maxLoopIterations == null &&
        policy.allowMutation;

    if (canUseTier1FastPath) {
      final hasPriorUserBindings =
          _globalEnv.localSlots.keys.any((k) => !_builtinNames.contains(k));
      final importsAllowed = program.statements
          .whereType<ImportDeclaration>()
          .every(
              (imp) => policy.allowImports && policy.isLibraryAllowed(imp.uri));
      if (importsAllowed &&
          (!hasPriorUserBindings || _globalEnv.allowTopLevelRebind)) {
        final compiled = QudsBytecodeCompiler.tryCompile(program, file: file);
        if (compiled != null) {
          final vmRes = QudsBytecodeVm.run(
            compiled,
            maxSteps: policy.maxSteps,
            maxCallDepth: policy.maxCallDepth,
            maxCollectionLength: policy.maxCollectionLength,
            timeout: policy.timeout,
            onPrint: (line) {
              printed.add(line);
              _events.add(QudsPrintEvent(line));
            },
          );
          for (final entry in vmRes.globals.entries) {
            _globalEnv.define(
              entry.key,
              entry.value,
              mutable: compiled.globalMutable[entry.key] ?? false,
            );
          }
          for (var i = 0; i < compiled.functionDecls.length; i++) {
            final decl = compiled.functionDecls[i];
            final userFn = QudsUserFunction(
              name: decl.name,
              parameters: decl.parameters,
              body: decl.body,
              expressionBody: decl.expressionBody,
              isAsync: decl.isAsync,
              generator: decl.generator,
              returnType: decl.returnType ?? '',
              closure: _globalEnv,
              span: decl.span,
            );
            _globalEnv.defineFunction(userFn,
                allowReplace: _globalEnv.allowTopLevelRebind);
          }
          stopwatch.stop();
          if (!vmRes.succeeded && vmRes.error != null) {
            _events.add(QudsErrorEvent(vmRes.error!));
          }
          return QudsRunResult(
            succeeded: vmRes.succeeded,
            value: vmRes.value,
            printedLines: List.unmodifiable(printed),
            outputs: const [],
            stepsExecuted: vmRes.stepsExecuted,
            elapsed: stopwatch.elapsed,
            error: vmRes.error,
            usedBytecodeVm: true,
          );
        }
      }
    }

    _activePrinted = printed;
    _activeOutputs = outputs;

    late QudsEvaluator evaluator;
    evaluator = QudsEvaluator(
      globalEnv: _globalEnv,
      onPrint: (text, span) {
        printed.add(text);
        _events.add(QudsPrintEvent(text, span: span));
      },
      onOutput: (out, span) {
        if (policy.maxOutputCount != null &&
            outputs.length >= policy.maxOutputCount!) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.outputLimit,
            'Exceeded maximum output limit (${policy.maxOutputCount}).',
            span,
          );
        }
        outputs.add(out);
        _events.add(QudsOutputEvent(out, span: span));
      },
      onStepProgress: (steps, span) {
        _events.add(QudsStepProgressEvent(steps, span));
      },
      onBeforeStatement: needsStatementHook
          ? (stmt, env) async {
              if (profilerActive) {
                profiler!.recordStatement(stmt.span);
              }
              await policy.authorizeStatement(stmt);
              if (_onBeforeStatement != null) {
                await _onBeforeStatement(stmt, env);
              }
              if (debugger != null) {
                await debugger!.beforeStatement(
                  statement: stmt,
                  env: env,
                  globalEnv: _globalEnv,
                  evaluator: evaluator,
                  emitPrint: (text, span) {
                    printed.add(text);
                    _events.add(QudsPrintEvent(text, span: span));
                  },
                  emitEvent: _events.add,
                );
              }
            }
          : null,
      onBeforeCall: needsCallHook
          ? (name, pos, named, span, cap) async {
              await policy.authorizeCall(
                functionName: name,
                positional: pos,
                named: named,
                span: span,
                requiredCapability: cap,
              );
              if (_onBeforeCall != null) {
                await _onBeforeCall(name, pos, named, span, cap);
              }
            }
          : null,
      checkCapabilitySync: (name, cap, span) {
        if (policy.findCapability(cap) == null) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.permissionDenied,
            'Function `$name` requires capability `$cap`, which is not granted by policy `${policy.name}`.',
            span,
            capability: cap,
          );
        }
      },
      trackFrameLocals: debugActive,
      onImport: _handleImport,
      maxSteps: policy.maxSteps,
      timeout: policy.timeout,
      maxCallDepth: policy.maxCallDepth,
      maxCollectionLength: policy.maxCollectionLength,
      maxStringLength: policy.maxStringLength,
      maxLoopIterations: policy.maxLoopIterations,
      yieldEveryNSteps: policy.yieldEveryNSteps,
      allowMutation: policy.allowMutation,
      allowAsync: policy.allowAsync,
      allowClasses: policy.allowClasses,
      allowExceptions: policy.allowExceptions,
      allowImports: policy.allowImports,
      interactiveInputs: Map<String, Object?>.from(_interactiveInputs),
      profiler: profilerActive ? profiler : null,
    );

    _activeEvaluator = evaluator;
    final useUniversalVm =
        preferBytecode && !needsStatementHook && !needsCallHook;
    try {
      final Object? value;
      if (useUniversalVm) {
        final chunk = _cachedUniversalChunk ??=
            QudsUniversalCompiler.compile(program, name: file);
        value = await QudsUniversalVm.execute(
          chunk,
          evaluator,
          _globalEnv,
          enableTier1Promotion:
              policy.maxLoopIterations == null && policy.allowMutation,
        );
      } else {
        value = await evaluator.executeProgram(program);
      }
      stopwatch.stop();
      return QudsRunResult(
        succeeded: true,
        value: value,
        printedLines: List.unmodifiable(printed),
        outputs: List.unmodifiable(outputs),
        stepsExecuted: evaluator.stepsExecuted,
        elapsed: stopwatch.elapsed,
        usedBytecodeVm: useUniversalVm,
      );
    } catch (err) {
      stopwatch.stop();
      _events.add(QudsErrorEvent(err));
      return QudsRunResult(
        succeeded: false,
        printedLines: List.unmodifiable(printed),
        outputs: List.unmodifiable(outputs),
        stepsExecuted: evaluator.stepsExecuted,
        elapsed: stopwatch.elapsed,
        error: err,
        usedBytecodeVm: useUniversalVm,
      );
    } finally {
      if (identical(_activeEvaluator, evaluator)) {
        _activeEvaluator = null;
      }
      if (identical(_activePrinted, printed)) {
        _activePrinted = null;
      }
      if (identical(_activeOutputs, outputs)) {
        _activeOutputs = null;
      }
    }
  }

  /// Updates one or more interactive parameters (for example, a dragged geometry
  /// handle `{'C': {'x': 4.5, 'y': 5.2}}` or slider `{'radius': 4.0}`) and
  /// re-executes the last interactive script cleanly to produce updated scenes.
  Future<QudsRunResult> updateInteractiveInputs(
    Map<String, Object?> patch, {
    String? source,
    String? file,
  }) async {
    final targetSource = source ?? _lastInteractiveSource;
    if (targetSource == null) {
      throw StateError(
          'No interactive script has been run in this session yet.');
    }
    _interactiveInputs.addAll(patch);
    // Re-run in a clean rebind-enabled pass so immutable bindings like `A = viz.point(...)`
    // recompute cleanly without QUDS-090 conflicts, and imported workspace modules
    // observe the latest interactive inputs.
    _resetUserGlobals(allowTopLevelRebind: true);
    _moduleLoader.clearWorkspaceCache();
    return run(
      targetSource,
      file: file ?? _lastInteractiveFile,
      resetVizQuota: true,
    );
  }

  /// Advances the animation clock by [dt] seconds and re-executes the active
  /// interactive script for frame-stepped 60fps physics/visual simulations.
  Future<QudsRunResult> stepFrame(
    double dt, {
    double? time,
    int? frame,
    String? source,
    String? file,
  }) {
    final prevT =
        (_interactiveInputs['__quds_anim_t'] as num?)?.toDouble() ?? 0.0;
    final prevFrame =
        (_interactiveInputs['__quds_anim_frame'] as num?)?.toInt() ?? 0;
    final nextT = time ?? (prevT + dt);
    final nextFrame = frame ?? (prevFrame + 1);
    return updateInteractiveInputs(
      {
        '__quds_anim_t': nextT,
        '__quds_anim_dt': dt,
        '__quds_anim_frame': nextFrame,
      },
      source: source,
      file: file,
    );
  }

  /// Jumps the animation clock directly to [time] seconds (for timeline scrubbing).
  Future<QudsRunResult> seekTime(
    double time, {
    double dt = 1.0 / 60.0,
    int? frame,
    String? source,
    String? file,
  }) {
    final clampedT = time < 0.0 ? 0.0 : time;
    final targetFrame = frame ?? (dt > 0 ? (clampedT / dt).round() : 0);
    return updateInteractiveInputs(
      {
        '__quds_anim_t': clampedT,
        '__quds_anim_dt': dt,
        '__quds_anim_frame': targetFrame,
      },
      source: source,
      file: file,
    );
  }

  /// Deterministically executes a time-based Quds script across [frames] steps
  /// separated by [dt] seconds, preserving persistent `viz.state(...)` across
  /// frames and returning every frame's [QudsRunResult].
  Future<List<QudsRunResult>> runTimeline(
    String source, {
    required int frames,
    double dt = 1.0 / 60.0,
    String file = '<timeline>',
    void Function(int frame, QudsRunResult result)? onFrame,
  }) async {
    resetAnimation();
    final results = <QudsRunResult>[];
    for (var i = 0; i < frames; i++) {
      final res = await updateInteractiveInputs(
        {
          '__quds_anim_t': i * dt,
          '__quds_anim_dt': dt,
          '__quds_anim_frame': i,
        },
        source: source,
        file: file,
      );
      results.add(res);
      onFrame?.call(i, res);
      if (!res.succeeded) break;
    }
    return results;
  }

  /// Resets the animation clock back to `t = 0.0`, `frame = 0` and clears
  /// persistent cross-frame simulation state (`viz.state(...)`).
  void resetAnimation() {
    _simulationState.clear();
    _interactiveInputs['__quds_anim_t'] = 0.0;
    _interactiveInputs['__quds_anim_dt'] = 1.0 / 60.0;
    _interactiveInputs['__quds_anim_frame'] = 0;
  }

  /// Resolves an [ImportDeclaration] into [env] using this session's module loader.
  Future<void> resolveImportInto(ImportDeclaration decl, QudsEnvironment env) =>
      _handleImport(decl, env);

  /// Evaluates a single Quds expression string inside this session's workspace.
  Future<Object?> evaluateExpression(String source,
      {String file = '<eval>'}) async {
    final tokens = Lexer().tokenize(source, file: file);
    final program = Parser(tokens).parse();
    if (program.statements.isEmpty) return null;
    final evaluator = QudsEvaluator(
      globalEnv: _globalEnv,
      onPrint: (text, span) => _events.add(QudsPrintEvent(text, span: span)),
      onOutput: (out, span) => _events.add(QudsOutputEvent(out, span: span)),
      onImport: _handleImport,
      onBeforeCall: (name, pos, named, span, cap) async {
        await policy.authorizeCall(
          functionName: name,
          positional: pos,
          named: named,
          span: span,
          requiredCapability: cap,
        );
        if (_onBeforeCall != null) {
          await _onBeforeCall(name, pos, named, span, cap);
        }
      },
      maxSteps: policy.maxSteps,
      timeout: policy.timeout,
      maxCallDepth: policy.maxCallDepth,
      maxCollectionLength: policy.maxCollectionLength,
      maxStringLength: policy.maxStringLength,
      maxLoopIterations: policy.maxLoopIterations,
      yieldEveryNSteps: policy.yieldEveryNSteps,
      allowMutation: policy.allowMutation,
      allowAsync: policy.allowAsync,
      allowClasses: policy.allowClasses,
      allowExceptions: policy.allowExceptions,
      allowImports: policy.allowImports,
      interactiveInputs: Map<String, Object?>.from(_interactiveInputs),
    );
    return evaluator.executeProgram(program);
  }

  void _installCoreBuiltins(QudsEnvironment env,
      {bool recordAsBuiltins = true}) {
    void add(String name, Object? value) {
      env.define(name, value);
      if (recordAsBuiltins) _builtinNames.add(name);
    }

    add(
      'print',
      QudsNativeFunction(
        'print',
        (pos, named, ctx) {
          if (pos.isEmpty) {
            ctx.emitPrint('');
            return null;
          }
          final eval = _activeEvaluator;
          if (eval == null || !pos.any((v) => v is QudsInstance)) {
            ctx.emitPrint(pos.map(qudsFormatValue).join(' '));
            return null;
          }
          return () async {
            final parts = <String>[];
            for (final item in pos) {
              final formatted = eval.formatValueForOutput(item, ctx.span);
              parts.add(
                  formatted is Future<String> ? await formatted : formatted);
            }
            ctx.emitPrint(parts.join(' '));
            return null;
          }();
        },
        signature: 'print(value: Object?) -> void',
        documentation: 'Prints a value to the session output stream.',
      ),
    );

    add(
      'range',
      QudsNativeFunction(
        'range',
        (pos, named, ctx) {
          if (pos.length == 1) {
            return QudsRange(0, pos[0] as int, inclusive: true);
          }
          if (pos.length == 2) {
            return QudsRange(pos[0] as int, pos[1] as int, inclusive: true);
          }
          if (pos.length == 3) {
            return QudsRange(pos[0] as int, pos[1] as int,
                inclusive: true, step: pos[2] as int);
          }
          throw QudsRuntimeException(
              'range expects 1, 2, or 3 arguments.', ctx.span,
              code: 'E500');
        },
        signature: 'range(start: int, end: int) -> Range<int>',
        documentation:
            'Integers from start through end, including both ends. range(end) is range(0, end).',
      ),
    );

    add(
      'min',
      QudsNativeFunction(
        'min',
        (pos, named, ctx) => math.min(pos[0] as num, pos[1] as num),
        signature: 'min(a: num, b: num) -> num',
        documentation: 'Returns the smaller of two numbers.',
      ),
    );

    add(
      'max',
      QudsNativeFunction(
        'max',
        (pos, named, ctx) => math.max(pos[0] as num, pos[1] as num),
        signature: 'max(a: num, b: num) -> num',
        documentation: 'Returns the larger of two numbers.',
      ),
    );

    add(
      'Ok',
      QudsNativeFunction(
        'Ok',
        (pos, named, ctx) => QudsResult.ok(pos.isEmpty ? null : pos[0]),
        signature: 'Ok(value: T) -> Result<T, Never>',
      ),
    );

    add(
      'Error',
      QudsNativeFunction(
        'Error',
        (pos, named, ctx) => QudsResult.error(pos.isEmpty ? null : pos[0]),
        signature: 'Error(error: E) -> Result<Never, E>',
      ),
    );

    add(
      'present',
      QudsNativeFunction(
        'present',
        (pos, named, ctx) => QudsOptional.present(pos.isEmpty ? null : pos[0]),
        signature: 'present(value: T) -> Optional<T>',
      ),
    );

    add('missing', QudsMissing.instance);

    add(
      'ConversionError',
      QudsNativeFunction(
        'ConversionError',
        (pos, named, ctx) =>
            QudsConversionError(pos.isEmpty ? '' : '${pos[0]}'),
      ),
    );

    add(
      'identical',
      QudsNativeFunction(
        'identical',
        (pos, named, ctx) => identical(pos[0], pos[1]),
      ),
    );

    add(
      'Exception',
      QudsNativeFunction(
          'Exception', (pos, n, c) => Exception(pos.isEmpty ? '' : pos[0])),
    );
    add(
      'ArgumentError',
      QudsNativeFunction('ArgumentError',
          (pos, n, c) => ArgumentError(pos.isEmpty ? '' : pos[0])),
    );
    add(
      'StateError',
      QudsNativeFunction('StateError',
          (pos, n, c) => StateError(pos.isEmpty ? '' : '${pos[0]}')),
    );
    add(
      'RangeError',
      QudsNativeFunction(
          'RangeError', (pos, n, c) => RangeError(pos.isEmpty ? '' : pos[0])),
    );
    add(
      'FormatException',
      QudsNativeFunction('FormatException',
          (pos, n, c) => FormatException(pos.isEmpty ? '' : '${pos[0]}')),
    );

    add(
      'StringBuffer',
      QudsNativeFunction('StringBuffer',
          (pos, n, c) => StringBuffer(pos.isEmpty ? '' : '${pos[0]}')),
    );
    add(
      'RegExp',
      QudsNativeFunction('RegExp', (pos, named, c) {
        return RegExp(
          '${pos[0]}',
          multiLine: (named['multiLine'] as bool?) ?? false,
          caseSensitive: (named['caseSensitive'] as bool?) ?? true,
          unicode: (named['unicode'] as bool?) ?? false,
          dotAll: (named['dotAll'] as bool?) ?? false,
        );
      }),
    );
    add('Future', resolveDartStdlib('dart:async')!['Future']);
    add('TimeoutException',
        resolveDartStdlib('dart:async')!['TimeoutException']);
    add(
      'Duration',
      QudsNativeFunction('Duration', (pos, named, c) {
        return Duration(
          days: (named['days'] as int?) ?? 0,
          hours: (named['hours'] as int?) ?? 0,
          minutes: (named['minutes'] as int?) ?? 0,
          seconds: (named['seconds'] as int?) ?? 0,
          milliseconds: (named['milliseconds'] as int?) ?? 0,
          microseconds: (named['microseconds'] as int?) ?? 0,
        );
      }),
    );
    add(
      'int',
      QudsNamespace('int', {
        'parse': QudsNativeFunction('int.parse',
            (p, n, c) => int.parse('${p[0]}', radix: n['radix'] as int?)),
        'tryParse': QudsNativeFunction('int.tryParse',
            (p, n, c) => int.tryParse('${p[0]}', radix: n['radix'] as int?)),
      }),
    );
    add(
      'double',
      QudsNamespace('double', {
        'infinity': double.infinity,
        'negativeInfinity': double.negativeInfinity,
        'nan': double.nan,
        'maxFinite': double.maxFinite,
        'minPositive': double.minPositive,
        'parse': QudsNativeFunction(
            'double.parse', (p, n, c) => double.parse('${p[0]}')),
        'tryParse': QudsNativeFunction(
            'double.tryParse', (p, n, c) => double.tryParse('${p[0]}')),
      }),
    );
    add(
      'BigInt',
      QudsNamespace('BigInt', {
        'zero': BigInt.zero,
        'one': BigInt.one,
        'two': BigInt.two,
        'from': QudsNativeFunction(
            'BigInt.from', (p, n, c) => BigInt.from(p[0] as num)),
        'parse': QudsNativeFunction('BigInt.parse',
            (p, n, c) => BigInt.parse('${p[0]}', radix: n['radix'] as int?)),
        'tryParse': QudsNativeFunction('BigInt.tryParse',
            (p, n, c) => BigInt.tryParse('${p[0]}', radix: n['radix'] as int?)),
      }),
    );
    add(
      'DateTime',
      QudsNamespace('DateTime', {
        'now': QudsNativeFunction('DateTime.now', (p, n, c) => DateTime.now()),
        'utc': QudsNativeFunction('DateTime.utc', (p, n, c) {
          return DateTime.utc(
            p[0] as int,
            p.length > 1 ? p[1] as int : 1,
            p.length > 2 ? p[2] as int : 1,
            p.length > 3 ? p[3] as int : 0,
            p.length > 4 ? p[4] as int : 0,
            p.length > 5 ? p[5] as int : 0,
            p.length > 6 ? p[6] as int : 0,
            p.length > 7 ? p[7] as int : 0,
          );
        }),
        'parse': QudsNativeFunction(
            'DateTime.parse', (p, n, c) => DateTime.parse('${p[0]}')),
        'tryParse': QudsNativeFunction(
            'DateTime.tryParse', (p, n, c) => DateTime.tryParse('${p[0]}')),
        'fromMillisecondsSinceEpoch': QudsNativeFunction(
          'DateTime.fromMillisecondsSinceEpoch',
          (p, n, c) => DateTime.fromMillisecondsSinceEpoch(
            p[0] as int,
            isUtc: (n['isUtc'] as bool?) ?? false,
          ),
        ),
      }),
    );
    add(
      'List',
      QudsNamespace('List', {
        'filled': QudsNativeFunction('List.filled', (p, n, c) {
          final len = p[0] as int;
          if (policy.maxCollectionLength != null &&
              len > policy.maxCollectionLength!) {
            throw QudsPolicyViolationException(
              QudsPolicyViolationKind.collectionLimit,
              'List.filled size ($len) exceeded maximum limit (${policy.maxCollectionLength}).',
              c.span,
            );
          }
          return List<Object?>.filled(len, p[1],
              growable: (n['growable'] as bool?) ?? false);
        }),
        'generate': QudsNativeFunction('List.generate', (p, n, c) async {
          final len = p[0] as int;
          if (policy.maxCollectionLength != null &&
              len > policy.maxCollectionLength!) {
            throw QudsPolicyViolationException(
              QudsPolicyViolationKind.collectionLimit,
              'List.generate size ($len) exceeded maximum limit (${policy.maxCollectionLength}).',
              c.span,
            );
          }
          final out = <Object?>[];
          for (var i = 0; i < len; i++) {
            out.add(await c.invokeCallable(p[1], [i], const {}, c.span));
          }
          return out;
        }),
        'from': QudsNativeFunction(
            'List.from', (p, n, c) => List<Object?>.from(p[0] as Iterable)),
        'of': QudsNativeFunction(
            'List.of', (p, n, c) => List<Object?>.from(p[0] as Iterable)),
        'unmodifiable': QudsNativeFunction('List.unmodifiable',
            (p, n, c) => List<Object?>.unmodifiable(p[0] as Iterable)),
      }),
    );
    add(
      'Map',
      QudsNamespace('Map', {
        'from': QudsNativeFunction(
            'Map.from', (p, n, c) => Map<Object?, Object?>.from(p[0] as Map)),
        'of': QudsNativeFunction(
            'Map.of', (p, n, c) => Map<Object?, Object?>.from(p[0] as Map)),
        'fromEntries': QudsNativeFunction('Map.fromEntries', (p, n, c) {
          final entries = (p[0] as Iterable).cast<MapEntry<Object?, Object?>>();
          return Map<Object?, Object?>.fromEntries(entries);
        }),
      }),
    );
    add(
      'Set',
      QudsNamespace('Set', {
        'from': QudsNativeFunction(
            'Set.from', (p, n, c) => Set<Object?>.from(p[0] as Iterable)),
        'of': QudsNativeFunction(
            'Set.of', (p, n, c) => Set<Object?>.from(p[0] as Iterable)),
      }),
    );
  }
}
