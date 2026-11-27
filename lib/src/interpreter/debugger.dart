/// Native AST-level interactive debugger for the embedded Quds interpreter.
///
/// Supports line breakpoints, conditional breakpoints (`condition`), hit-count
/// breakpoints, non-stopping logpoints (`logMessage`), `pause`, `continueRun`,
/// `stepOver`, `stepInto`, `stepOut`, `stop`, live watch expressions, and
/// live frame expression evaluation (`evaluate`). Zero `dart:io` imports.
library;

import 'dart:async';

import '../ast.dart';
import '../lexer.dart';
import '../parser.dart';
import 'environment.dart';
import 'evaluator.dart';
import 'exceptions.dart';
import 'values.dart';

/// Reason execution paused inside the debugger.
enum QudsPauseReason {
  entry,
  breakpoint,
  step,
  pause,
  exception,
}

/// Action chosen by the debugger host to resume from a pause.
enum _DebugStepMode {
  running,
  pauseNext,
  stepInto,
  stepOver,
  stepOut,
}

/// Declarative breakpoint attached to a specific `.quds` file and 1-based line.
class QudsBreakpoint {
  const QudsBreakpoint({
    required this.line,
    this.file = '<session>',
    this.condition,
    this.hitCount,
    this.logMessage,
    this.enabled = true,
  });

  /// 1-based source line in [file].
  final int line;

  /// Source file identifier matching the `file:` passed to `QudsSession.run`.
  final String file;

  /// Optional Quds boolean expression (e.g. `i == 5 and err < 0.01`).
  final String? condition;

  /// Optional 1-based hit count threshold (pause on or after the Nth hit).
  final int? hitCount;

  /// If non-null, emits a log line instead of pausing (logpoint).
  final String? logMessage;

  /// Whether this breakpoint is active.
  final bool enabled;
}

/// Evaluation result of a single debugger watch expression.
class QudsWatchResult {
  const QudsWatchResult({
    required this.expression,
    this.value,
    this.summary = '',
    this.typeName = '',
    this.error,
  });

  final String expression;
  final Object? value;
  final String summary;
  final String typeName;
  final String? error;

  bool get succeeded => error == null;
}

/// Callback invoked by [QudsDebugPauseEvent.evaluate] to run a live expression
/// inside a paused stack frame.
typedef QudsFrameEvaluator = Future<Object?> Function(
  String expression,
  int frameIndex,
);

/// Snapshot delivered to the host UI whenever execution pauses in the debugger.
class QudsDebugPauseEvent {
  const QudsDebugPauseEvent({
    required this.reason,
    required this.span,
    required this.stackFrames,
    required this.locals,
    required this.globals,
    required this.watchResults,
    required QudsFrameEvaluator evaluateInFrame,
    this.breakpoint,
    this.exception,
  }) : _evaluateInFrame = evaluateInFrame;

  final QudsPauseReason reason;
  final SourceSpan span;
  final List<QudsStackFrame> stackFrames;
  final Map<String, Object?> locals;
  final Map<String, Object?> globals;
  final Map<String, QudsWatchResult> watchResults;
  final QudsBreakpoint? breakpoint;
  final Object? exception;
  final QudsFrameEvaluator _evaluateInFrame;

  /// Evaluates any Quds expression inside the paused frame (`0` = innermost).
  Future<Object?> evaluate(String qudsExpression, {int frameIndex = 0}) =>
      _evaluateInFrame(qudsExpression, frameIndex);
}

/// Runtime event emitted on `QudsSession.events` when the debugger pauses.
class QudsDebugPausedRuntimeEvent extends QudsRuntimeEvent {
  const QudsDebugPausedRuntimeEvent(this.pause);
  final QudsDebugPauseEvent pause;
}

/// Runtime event emitted on `QudsSession.events` when the debugger resumes.
class QudsDebugResumedRuntimeEvent extends QudsRuntimeEvent {
  const QudsDebugResumedRuntimeEvent();
}

/// Interactive debugger controller attachable to any [QudsSession].
class QudsDebugController {
  QudsDebugController({this.stopOnEntry = false});

  bool stopOnEntry;

  final Map<String, Map<int, QudsBreakpoint>> _breakpoints = {};
  final Map<String, int> _hitCounts = {};
  final List<String> _watchExpressions = [];

  final StreamController<QudsDebugPauseEvent> _pausedController =
      StreamController<QudsDebugPauseEvent>.broadcast();
  final StreamController<void> _resumedController =
      StreamController<void>.broadcast();

  _DebugStepMode _mode = _DebugStepMode.running;
  int _stepOriginDepth = 0;
  int? _lastPausedLine;
  String? _lastPausedFile;
  Completer<void>? _resumeCompleter;
  bool _stopRequested = false;
  QudsDebugPauseEvent? _currentPause;

  /// Stream of pause snapshots (suitable for direct Flutter UI binding).
  Stream<QudsDebugPauseEvent> get onPaused => _pausedController.stream;

  /// Emits whenever execution resumes from a pause.
  Stream<void> get onResumed => _resumedController.stream;

  /// True while execution is currently suspended at a breakpoint or step.
  bool get isPaused =>
      _resumeCompleter != null && !_resumeCompleter!.isCompleted;

  /// True when at least one breakpoint, entry stop, or step mode is active.
  bool get hasActiveHooks {
    if (stopOnEntry || _mode != _DebugStepMode.running) return true;
    for (final map in _breakpoints.values) {
      if (map.isNotEmpty) return true;
    }
    return false;
  }

  /// The active pause snapshot when [isPaused] is true.
  QudsDebugPauseEvent? get currentPause => _currentPause;

  /// Configured watch expressions evaluated automatically on every pause.
  List<String> get watchExpressions => List.unmodifiable(_watchExpressions);

  /// Replaces the list of watch expressions.
  void setWatchExpressions(Iterable<String> expressions) {
    _watchExpressions
      ..clear()
      ..addAll(expressions);
  }

  /// Replaces all breakpoints for [file].
  void setBreakpoints(String file, List<QudsBreakpoint> breakpoints) {
    final map = <int, QudsBreakpoint>{};
    for (final bp in breakpoints) {
      map[bp.line] = bp;
    }
    _breakpoints[file] = map;
  }

  /// Convenience helper for setting unconditional line breakpoints in [file].
  void setLineBreakpoints(String file, Iterable<int> lines) {
    setBreakpoints(
      file,
      [for (final line in lines) QudsBreakpoint(file: file, line: line)],
    );
  }

  /// Clears breakpoints for [file], or all files when [file] is omitted.
  void clearBreakpoints([String? file]) {
    if (file == null) {
      _breakpoints.clear();
      _hitCounts.clear();
    } else {
      _breakpoints.remove(file);
    }
  }

  /// Resets per-run transient stepping state before a new `QudsSession.run`.
  void resetForRun() {
    _stopRequested = false;
    _lastPausedLine = null;
    _lastPausedFile = null;
    _currentPause = null;
    _mode = stopOnEntry ? _DebugStepMode.pauseNext : _DebugStepMode.running;
  }

  /// Requests pausing at the next executable statement.
  void pause() {
    _mode = _DebugStepMode.pauseNext;
  }

  /// Resumes normal execution until the next breakpoint or completion.
  void continueRun() {
    _mode = _DebugStepMode.running;
    _releasePause();
  }

  /// Executes the current statement and pauses at the next statement at the
  /// same or shallower call depth (steps over function calls).
  void stepOver() {
    _mode = _DebugStepMode.stepOver;
    _releasePause();
  }

  /// Pauses at the very next executable statement, stepping into function calls.
  void stepInto() {
    _mode = _DebugStepMode.stepInto;
    _releasePause();
  }

  /// Continues until returning to a shallower call depth.
  void stepOut() {
    _mode = _DebugStepMode.stepOut;
    _releasePause();
  }

  /// Immediately stops execution (even while paused at a breakpoint).
  void stop() {
    _stopRequested = true;
    _releasePause();
  }

  void _releasePause() {
    _currentPause = null;
    final completer = _resumeCompleter;
    _resumeCompleter = null;
    if (completer != null && !completer.isCompleted) {
      _resumedController.add(null);
      completer.complete();
    }
  }

  /// Internal statement hook called by [QudsSession] before each statement.
  Future<void> beforeStatement({
    required Statement statement,
    required QudsEnvironment env,
    required QudsEnvironment globalEnv,
    required QudsEvaluator evaluator,
    required void Function(String line, SourceSpan span) emitPrint,
    required void Function(QudsRuntimeEvent event) emitEvent,
  }) async {
    if (_stopRequested) {
      evaluator.stop();
      return;
    }

    final span = statement.span;
    final depth = evaluator.stackFrames.length;
    QudsPauseReason? pauseReason;
    QudsBreakpoint? matchedBp;

    // 1. Check breakpoints on this file + line (avoid re-triggering on same line twice in a row unless looped).
    final bp = _breakpoints[span.file]?[span.line];
    if (bp != null && bp.enabled) {
      final hitKey = '${span.file}:${span.line}';
      final condOk = bp.condition == null
          ? true
          : await _evalCondition(bp.condition!, env, evaluator);
      if (condOk) {
        final count = (_hitCounts[hitKey] ?? 0) + 1;
        _hitCounts[hitKey] = count;
        final countOk = bp.hitCount == null || count >= bp.hitCount!;
        if (countOk) {
          if (bp.logMessage != null) {
            final rendered =
                await _renderLogMessage(bp.logMessage!, env, evaluator, span);
            emitPrint(rendered, span);
          } else {
            pauseReason = QudsPauseReason.breakpoint;
            matchedBp = bp;
          }
        }
      }
    }

    // 2. Check stepping / pause requests if not already paused by breakpoint.
    if (pauseReason == null) {
      switch (_mode) {
        case _DebugStepMode.running:
          break;
        case _DebugStepMode.pauseNext:
          pauseReason = stopOnEntry && _lastPausedLine == null
              ? QudsPauseReason.entry
              : QudsPauseReason.pause;
          break;
        case _DebugStepMode.stepInto:
          pauseReason = QudsPauseReason.step;
          break;
        case _DebugStepMode.stepOver:
          if (depth <= _stepOriginDepth &&
              !(span.file == _lastPausedFile && span.line == _lastPausedLine)) {
            pauseReason = QudsPauseReason.step;
          }
          break;
        case _DebugStepMode.stepOut:
          if (depth < _stepOriginDepth) {
            pauseReason = QudsPauseReason.step;
          }
          break;
      }
    }

    if (pauseReason == null) return;

    _stepOriginDepth = depth;
    _lastPausedFile = span.file;
    _lastPausedLine = span.line;

    final frames = <QudsStackFrame>[
      QudsStackFrame(
        functionName: '<main>',
        span: span,
        locals: globalEnv.snapshotLocals(),
      ),
      ...evaluator.stackFrames,
    ];
    final activeLocals = env.snapshotLocals();
    final globals = globalEnv.snapshotLocals();

    // Evaluate configured watch expressions safely inside the paused frame.
    final watchMap = <String, QudsWatchResult>{};
    for (final exprText in _watchExpressions) {
      watchMap[exprText] = await _evaluateWatch(exprText, env, evaluator);
    }

    final pauseEvent = QudsDebugPauseEvent(
      reason: pauseReason,
      span: span,
      stackFrames: List.unmodifiable(frames.reversed),
      locals: Map.unmodifiable(activeLocals),
      globals: Map.unmodifiable(globals),
      watchResults: Map.unmodifiable(watchMap),
      breakpoint: matchedBp,
      evaluateInFrame: (exprText, frameIndex) async {
        final targetEnv = frameIndex == 0 ? env : globalEnv;
        return _evalSnippet(exprText, targetEnv, evaluator);
      },
    );

    _currentPause = pauseEvent;
    _resumeCompleter = Completer<void>();
    _pausedController.add(pauseEvent);
    emitEvent(QudsDebugPausedRuntimeEvent(pauseEvent));

    await _resumeCompleter!.future;
    emitEvent(const QudsDebugResumedRuntimeEvent());

    if (_stopRequested) {
      evaluator.stop();
    }
  }

  Future<bool> _evalCondition(
    String exprSource,
    QudsEnvironment env,
    QudsEvaluator evaluator,
  ) async {
    try {
      final value = await _evalSnippet(exprSource, env, evaluator);
      return value == true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _renderLogMessage(
    String template,
    QudsEnvironment env,
    QudsEvaluator evaluator,
    SourceSpan span,
  ) async {
    try {
      final escaped = template.replaceAll('"', r'\"');
      final val = await _evalSnippet('"$escaped"', env, evaluator);
      return qudsFormatValue(val);
    } catch (_) {
      return template;
    }
  }

  Future<QudsWatchResult> _evaluateWatch(
    String exprSource,
    QudsEnvironment env,
    QudsEvaluator evaluator,
  ) async {
    try {
      final value = await _evalSnippet(exprSource, env, evaluator);
      return QudsWatchResult(
        expression: exprSource,
        value: value,
        summary: qudsSummarizeValue(value),
        typeName: qudsTypeName(value),
      );
    } catch (err) {
      return QudsWatchResult(
        expression: exprSource,
        error: '$err',
      );
    }
  }

  Future<Object?> _evalSnippet(
    String source,
    QudsEnvironment env,
    QudsEvaluator evaluator,
  ) async {
    final program =
        Parser(Lexer().tokenize(source, file: '<debug-eval>')).parse();
    if (program.statements.isEmpty) return null;
    final sub = QudsEvaluator(
      globalEnv: env,
      onPrint: (_, __) {},
      onOutput: (_, __) {},
      maxSteps: 10000,
      maxCallDepth: 32,
      allowMutation: evaluator.allowMutation,
      allowAsync: evaluator.allowAsync,
      allowClasses: evaluator.allowClasses,
      allowExceptions: evaluator.allowExceptions,
      allowImports: false,
    );
    final first = program.statements.first;
    if (program.statements.length == 1 && first is ExpressionStatement) {
      return sub.evaluateExpression(first.expression, env, resetBudget: true);
    }
    return sub.executeProgram(program, env: env.child(), resetBudget: true);
  }

  /// Releases controller streams.
  Future<void> dispose() async {
    stop();
    await _pausedController.close();
    await _resumedController.close();
  }
}
