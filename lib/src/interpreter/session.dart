/// Stateful scientific session (`QudsSession`) and run results for the
/// embedded Quds interpreter (zero `dart:io` imports).
library;

import 'dart:async';
import 'dart:math' as math;

import '../ast.dart';
import '../lexer.dart';
import '../parser.dart';
import 'dart_stdlib_bridge.dart';
import 'environment.dart';
import 'evaluator.dart';
import 'exceptions.dart';
import 'module_loader.dart';
import 'values.dart';

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
  });

  /// Whether execution completed without uncaught parse, runtime, or policy error.
  final bool succeeded;

  /// Value of the last expression statement (if any).
  final Object? value;

  /// All lines emitted via `print(...)` during this run.
  final List<String> printedLines;

  /// Structured rich outputs emitted during this run (plots, geometry, tables, etc.).
  final List<Object> outputs;

  /// Total AST steps executed during this run.
  final int stepsExecuted;

  /// Wall-clock duration of this run.
  final Duration elapsed;

  /// The caught error when [succeeded] is false (`CompilerException`,
  /// `QudsRuntimeException`, or `QudsPolicyViolationException`).
  final Object? error;

  String get stdout => printedLines.join('\n');
}

/// Persistent interactive workspace for interpreting Quds code, similar to
/// a MATLAB / Jupyter scientific session.
class QudsSession {
  QudsSession({
    this.allowTopLevelRebind = false,
    this.maxSteps,
    this.timeout,
    this.maxCallDepth = 256,
    this.maxCollectionLength,
    this.maxStringLength,
    this.maxLoopIterations,
    this.yieldEveryNSteps = 2000,
    this.allowMutation = true,
    this.allowAsync = true,
    this.allowClasses = true,
    this.allowExceptions = true,
    this.allowImports = true,
    this.allowedLibraries,
    this.deniedLibraries = const {},
    this.importResolver,
    Map<String, Map<String, Object?>> virtualModules = const {},
    ImportHook? onImport,
    StatementHook? onBeforeStatement,
    CallHook? onBeforeCall,
  })  : _onImport = onImport,
        _onBeforeStatement = onBeforeStatement,
        _onBeforeCall = onBeforeCall {
    _globalEnv = QudsEnvironment(
      isGlobal: true,
      allowTopLevelRebind: allowTopLevelRebind,
    );
    _installCoreBuiltins(_globalEnv);
    _moduleLoader = QudsModuleLoader(
      createBaseEnvironment: () {
        final env = QudsEnvironment(isGlobal: true);
        _installCoreBuiltins(env, recordAsBuiltins: false);
        return env;
      },
      createModuleEvaluator: (modEnv, impHook) => QudsEvaluator(
        globalEnv: modEnv,
        onPrint: (text, span) => _events.add(QudsPrintEvent(text, span: span)),
        onOutput: (out, span) => _events.add(QudsOutputEvent(out, span: span)),
        onImport: impHook,
        maxCallDepth: maxCallDepth,
        maxCollectionLength: maxCollectionLength,
        maxStringLength: maxStringLength,
        yieldEveryNSteps: yieldEveryNSteps,
        allowMutation: true,
        allowAsync: allowAsync,
        allowClasses: true,
        allowExceptions: true,
        allowImports: true,
      ),
      virtualModules: virtualModules,
      allowedLibraries: allowedLibraries,
      deniedLibraries: deniedLibraries,
      importResolver: importResolver,
    );
  }

  final bool allowTopLevelRebind;
  final int? maxSteps;
  final Duration? timeout;
  final int maxCallDepth;
  final int? maxCollectionLength;
  final int? maxStringLength;
  final int? maxLoopIterations;
  final int yieldEveryNSteps;
  final bool allowMutation;
  final bool allowAsync;
  final bool allowClasses;
  final bool allowExceptions;
  final bool allowImports;
  final Set<String>? allowedLibraries;
  final Set<String> deniedLibraries;
  final QudsImportResolver? importResolver;
  final ImportHook? _onImport;
  final StatementHook? _onBeforeStatement;
  final CallHook? _onBeforeCall;

  late QudsEnvironment _globalEnv;
  late QudsModuleLoader _moduleLoader;
  final StreamController<QudsRuntimeEvent> _events =
      StreamController<QudsRuntimeEvent>.broadcast();
  final Set<String> _builtinNames = {};
  QudsEvaluator? _activeEvaluator;

  /// Live broadcast stream of print lines, rich outputs, errors, and progress.
  Stream<QudsRuntimeEvent> get events => _events.stream;

  /// Underlying global environment (for advanced integrations & editor autocomplete).
  QudsEnvironment get globalEnvironment => _globalEnv;

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

  /// Registers a virtual host module importable via `use <uri>`.
  void registerVirtualModule(String uri, Map<String, Object?> symbols) {
    _moduleLoader.registerVirtualModule(uri, symbols);
  }

  /// Clears all user-defined variables and functions, restoring core builtins.
  void clear() {
    _globalEnv.clearAll();
    _builtinNames.clear();
    _moduleLoader.clearSessionCache();
    _installCoreBuiltins(_globalEnv);
  }

  /// Requests immediate stop of any currently running execution.
  void stop() {
    _activeEvaluator?.stop();
  }

  /// Releases the event stream controller.
  Future<void> dispose() async {
    stop();
    await _events.close();
  }

  Future<void> _handleImport(
      ImportDeclaration decl, QudsEnvironment env) async {
    if (_onImport != null) {
      await _onImport(decl, env);
      return;
    }
    await _moduleLoader.resolveImport(decl, env);
  }

  /// Parses and executes Quds [source] inside this session's persistent workspace.
  Future<QudsRunResult> run(
    String source, {
    String file = '<session>',
    Map<String, Object?> interactiveInputs = const {},
  }) async {
    final stopwatch = Stopwatch()..start();
    final printed = <String>[];
    final outputs = <Object>[];

    Program program;
    try {
      final tokens = Lexer().tokenize(source, file: file);
      program = Parser(tokens).parse();
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

    final evaluator = QudsEvaluator(
      globalEnv: _globalEnv,
      onPrint: (text, span) {
        printed.add(text);
        _events.add(QudsPrintEvent(text, span: span));
      },
      onOutput: (out, span) {
        outputs.add(out);
        _events.add(QudsOutputEvent(out, span: span));
      },
      onStepProgress: (steps, span) {
        _events.add(QudsStepProgressEvent(steps, span));
      },
      onBeforeStatement: _onBeforeStatement,
      onBeforeCall: _onBeforeCall,
      onImport: _handleImport,
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
      interactiveInputs: interactiveInputs,
    );

    _activeEvaluator = evaluator;
    try {
      final value = await evaluator.executeProgram(program);
      stopwatch.stop();
      return QudsRunResult(
        succeeded: true,
        value: value,
        printedLines: List.unmodifiable(printed),
        outputs: List.unmodifiable(outputs),
        stepsExecuted: evaluator.stepsExecuted,
        elapsed: stopwatch.elapsed,
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
      );
    } finally {
      if (identical(_activeEvaluator, evaluator)) {
        _activeEvaluator = null;
      }
    }
  }

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
      onBeforeCall: _onBeforeCall,
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
          final text = pos.isEmpty ? '' : pos.map(qudsFormatValue).join(' ');
          ctx.emitPrint(text);
          return null;
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

    // Common error constructors
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

    // Dart core type constructors/namespaces
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
          if (maxCollectionLength != null && len > maxCollectionLength!) {
            throw QudsPolicyViolationException(
              QudsPolicyViolationKind.collectionLimit,
              'List.filled size ($len) exceeded maximum limit ($maxCollectionLength).',
              c.span,
            );
          }
          return List<Object?>.filled(len, p[1],
              growable: (n['growable'] as bool?) ?? false);
        }),
        'generate': QudsNativeFunction('List.generate', (p, n, c) async {
          final len = p[0] as int;
          if (maxCollectionLength != null && len > maxCollectionLength!) {
            throw QudsPolicyViolationException(
              QudsPolicyViolationKind.collectionLimit,
              'List.generate size ($len) exceeded maximum limit ($maxCollectionLength).',
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
