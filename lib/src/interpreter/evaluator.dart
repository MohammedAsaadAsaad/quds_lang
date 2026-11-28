/// Cooperative AST evaluator for the embedded Quds interpreter.
///
/// Pure Dart (zero `dart:io` imports). Preserves left-to-right, exactly-once
/// evaluation, original `.quds` [SourceSpan] diagnostics, and yields
/// cooperatively so host UIs (Flutter Desktop/Mobile/Web) stay responsive.
library;

import 'dart:async';
import 'dart:core' hide Pattern;
import 'dart:core' as core show Pattern;
import 'dart:math' as math;

import '../ast.dart';
import '../source.dart';
import 'dart_stdlib_bridge.dart';
import 'environment.dart';
import 'exceptions.dart';
import 'profiler.dart';
import 'values.dart';

/// Hook invoked before executing a statement (used by debugger & policy).
typedef StatementHook = Future<void> Function(
  Statement statement,
  QudsEnvironment env,
);

/// Hook invoked before calling a function/method (used by policy & audit).
typedef CallHook = Future<void> Function(
  String name,
  List<Object?> positional,
  Map<String, Object?> named,
  SourceSpan span,
  String? requiredCapability,
);

/// Hook invoked to resolve `use ...` imports.
typedef ImportHook = Future<void> Function(
  ImportDeclaration declaration,
  QudsEnvironment targetEnv,
);

/// Core AST evaluator for Quds programs and expressions.
class QudsEvaluator {
  QudsEvaluator({
    required this.globalEnv,
    required this.onPrint,
    required this.onOutput,
    this.onStepProgress,
    this.onBeforeStatement,
    this.onBeforeCall,
    this.checkCapabilitySync,
    this.trackFrameLocals = true,
    this.onImport,
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
    this.interactiveInputs = const {},
    this.profiler,
  });

  final QudsEnvironment globalEnv;
  final void Function(String text, SourceSpan span) onPrint;
  final void Function(Object output, SourceSpan span) onOutput;
  final void Function(int steps, SourceSpan span)? onStepProgress;
  final StatementHook? onBeforeStatement;
  final CallHook? onBeforeCall;
  final void Function(String name, String capability, SourceSpan span)?
      checkCapabilitySync;
  final bool trackFrameLocals;
  final ImportHook? onImport;
  final QudsProfiler? profiler;

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
  final Map<String, Object?> interactiveInputs;

  int _steps = 0;
  int _callDepth = 0;
  bool _stopped = false;
  Stopwatch? _stopwatch;
  final List<QudsStackFrame> _callStack = [];
  final List<Object?> _thrownStack = [];
  final Map<String, Map<String, QudsUserFunction>> _extensions = {};
  final Map<String, Map<String, List<(String, QudsUserFunction)>>>
      _extensionOperators = {};
  final List<QudsUserFunction> _customConversions = [];
  final Set<int> _executedOnceSites = {};
  final List<List<Object?>> _yieldStack = [];
  final List<_QudsComputedEntry> _computedCells = [];
  final List<_QudsWatchEntry> _watchers = [];
  int _batchDepth = 0;
  bool _watchersDirty = false;
  final Set<QudsInstance> _initializingInstances = {};

  /// Total AST steps executed in the current run.
  int get stepsExecuted => _steps;

  /// Current immutable snapshot of the call stack.
  List<QudsStackFrame> get stackFrames => List.unmodifiable(_callStack);

  /// Requests immediate cooperative cancellation of the active execution.
  void stop() {
    _stopped = true;
  }

  /// Registers extension methods & operator overloads (from `extend Target:` or `augment Target:`).
  void registerExtension(ExtensionDeclaration ext, QudsEnvironment env) {
    final targetKey = _baseTypeName(ext.target);
    final bucket = _extensions.putIfAbsent(targetKey, () => {});
    final opBucket = _extensionOperators.putIfAbsent(targetKey, () => {});
    for (final method in ext.methods) {
      final fn = QudsUserFunction(
        name: method.name,
        parameters: method.parameters,
        body: method.body,
        expressionBody: method.expressionBody,
        isAsync: method.isAsync,
        generator: method.generator,
        returnType: method.returnType ?? '',
        closure: env,
        span: method.span,
      );
      if (method.conversionKind.isNotEmpty) {
        _customConversions.add(fn);
      } else if (method.isOperator) {
        opBucket.putIfAbsent(method.name, () => []).add((ext.target, fn));
      } else {
        bucket[method.name] = fn;
      }
    }
  }

  /// Executes a parsed Quds [Program] inside [env] (defaults to [globalEnv]).
  /// Returns the value of the final expression statement (if any).
  Future<Object?> executeProgram(
    Program program, {
    QudsEnvironment? env,
    bool resetBudget = true,
  }) async {
    final targetEnv = env ?? globalEnv;
    if (resetBudget) {
      _steps = 0;
      _stopped = false;
      _stopwatch = Stopwatch()..start();
    }
    try {
      return await executeBlock(
        program.statements,
        targetEnv,
        returnLastExpression: true,
        hoistDeclarations: true,
      );
    } on ReturnSignal catch (ret) {
      return ret.value;
    } on QudsThrownValue catch (thrown) {
      throw QudsRuntimeException(
        'Uncaught exception: ${qudsFormatValue(thrown.value)}',
        thrown.span,
        code: 'R200',
        stackFrames: thrown.stackFrames,
        cause: thrown.value,
      );
    } finally {
      if (resetBudget) {
        _stopwatch?.stop();
      }
    }
  }

  /// Evaluates a single expression inside [env] (e.g. debugger watch / REPL).
  Future<Object?> evaluateExpression(
    Expression expr,
    QudsEnvironment env, {
    bool resetBudget = false,
  }) async {
    if (resetBudget) {
      _steps = 0;
      _stopped = false;
      _stopwatch = Stopwatch()..start();
    }
    try {
      final res = _evalExprFast(expr, env);
      return res is Future<Object?> ? await res : res;
    } finally {
      if (resetBudget) {
        _stopwatch?.stop();
      }
    }
  }

  /// Executes a list of statements inside [env].
  Future<Object?> executeBlock(
    List<Statement> statements,
    QudsEnvironment env, {
    bool returnLastExpression = false,
    bool hoistDeclarations = false,
  }) async {
    if (onBeforeStatement == null &&
        onBeforeCall == null &&
        !statements.any((s) => s is DeferStatement)) {
      final res = _execBlockFast(
        statements,
        env,
        returnLastExpression: returnLastExpression,
        hoistDeclarations: hoistDeclarations,
      );
      return res is Future<Object?> ? await res : res;
    }

    if (hoistDeclarations) {
      _hoistFunctions(statements, env);
    }

    final deferred = <Expression>[];
    Object? lastValue;

    try {
      for (var i = 0; i < statements.length; i++) {
        final stmt = statements[i];
        final tickFut = _tick(stmt.span);
        if (tickFut != null) await tickFut;
        if (onBeforeStatement != null &&
            stmt is! FunctionDeclaration &&
            stmt is! SectionDeclaration) {
          await onBeforeStatement!(stmt, env);
        }

        if (stmt is DeferStatement) {
          deferred.add(stmt.expression);
          continue;
        }

        final val =
            await _execStatement(stmt, env, alreadyHoisted: hoistDeclarations);
        if (returnLastExpression && stmt is ExpressionStatement) {
          lastValue = val;
        }
      }
      return lastValue;
    } finally {
      for (final expr in deferred.reversed) {
        await _evalExpr(expr, env);
      }
    }
  }

  /// Synchronous step/budget check. Returns `true` ONLY when a cooperative
  /// microtask yield is required (`yieldEveryNSteps`).
  bool _tickNeedsYield(SourceSpan span) {
    if (_stopped) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.stopped,
        'Execution stopped by host controller.',
        span,
        stackFrames: stackFrames,
      );
    }
    _steps++;
    if (maxSteps != null && _steps > maxSteps!) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.stepLimit,
        'Execution exceeded maximum step limit ($maxSteps steps).',
        span,
        stackFrames: stackFrames,
      );
    }
    if (timeout != null &&
        (_steps & 63) == 0 &&
        _stopwatch != null &&
        _stopwatch!.elapsed > timeout!) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.timeout,
        'Execution timed out after ${timeout!.inMilliseconds}ms.',
        span,
        stackFrames: stackFrames,
      );
    }
    return yieldEveryNSteps > 0 && _steps % yieldEveryNSteps == 0;
  }

  Future<void>? _tick(SourceSpan span) {
    if (_tickNeedsYield(span)) {
      onStepProgress?.call(_steps, span);
      return Future<void>.delayed(Duration.zero);
    }
    return null;
  }

  void _checkCollectionSize(int size, SourceSpan span) {
    if (maxCollectionLength != null && size > maxCollectionLength!) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.collectionLimit,
        'Collection size ($size) exceeded maximum limit ($maxCollectionLength).',
        span,
        stackFrames: stackFrames,
      );
    }
  }

  void _checkStringLength(int length, SourceSpan span) {
    if (maxStringLength != null && length > maxStringLength!) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.stringLimit,
        'String length ($length) exceeded maximum limit ($maxStringLength).',
        span,
        stackFrames: stackFrames,
      );
    }
  }

  void _hoistFunctions(List<Statement> statements, QudsEnvironment env) {
    final seenInBlock = <String, List<FunctionDeclaration>>{};
    final allowCrossRunReplace = env.isGlobal && env.allowTopLevelRebind;
    for (final stmt in statements) {
      if (stmt is FunctionDeclaration) {
        final prior = seenInBlock.putIfAbsent(stmt.name, () => []);
        for (final prev in prior) {
          if (QudsEnvironment.sameParameterShape(
              prev.parameters, stmt.parameters)) {
            throw QudsRuntimeException(
              'Duplicate function or unsupported overload: `${stmt.name}` '
              '(already defined on line ${prev.span.line}).',
              stmt.span,
              code: 'E201',
              stackFrames: stackFrames,
            );
          }
        }
        prior.add(stmt);
        _registerFunctionDeclaration(
          stmt,
          env,
          allowReplace: allowCrossRunReplace,
        );
      }
    }
  }

  void _registerFunctionDeclaration(
    FunctionDeclaration decl,
    QudsEnvironment env, {
    bool allowReplace = false,
  }) {
    if (decl.isAsync && !allowAsync) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.featureDisabled,
        'Async function `${decl.name}` is disabled by the active execution policy.',
        decl.span,
        stackFrames: stackFrames,
      );
    }
    final fn = QudsUserFunction(
      name: decl.name,
      parameters: decl.parameters,
      body: decl.body,
      expressionBody: decl.expressionBody,
      isAsync: decl.isAsync,
      generator: decl.generator,
      returnType: decl.returnType ?? '',
      closure: env,
      span: decl.span,
    );
    env.defineFunction(fn, allowReplace: allowReplace);
  }

  // -------------------------------------------------------------------------
  // Statements
  // -------------------------------------------------------------------------

  Future<Object?> _execStatement(
    Statement stmt,
    QudsEnvironment env, {
    bool alreadyHoisted = false,
    String? activeLabel,
  }) async {
    switch (stmt) {
      case ExpressionStatement(:final expression):
        return _evalExpr(expression, env);

      case Binding():
        await _execBinding(stmt, env);
        return null;

      case FunctionDeclaration():
        if (!alreadyHoisted) {
          _registerFunctionDeclaration(stmt, env);
        }
        return null;

      case ReturnStatement(:final value):
        final result = value == null ? null : await _evalExpr(value, env);
        throw ReturnSignal(result);

      case ResultStatement(:final value):
        final result = await _evalExpr(value, env);
        throw ResultSignal(result);

      case IfStatement(:final condition, :final thenBody, :final elseBody):
        final cond =
            _expectBool(await _evalExpr(condition, env), condition.span);
        if (cond) {
          await executeBlock(thenBody, env.child(), hoistDeclarations: true);
        } else if (elseBody.isNotEmpty) {
          await executeBlock(elseBody, env.child(), hoistDeclarations: true);
        }
        return null;

      case IfLetStatement(
          :final name,
          :final value,
          :final thenBody,
          :final elseBody
        ):
        final v = await _evalExpr(value, env);
        if (v != null) {
          final child = env.child()..define(name, v);
          await executeBlock(thenBody, child, hoistDeclarations: true);
        } else if (elseBody.isNotEmpty) {
          await executeBlock(elseBody, env.child(), hoistDeclarations: true);
        }
        return null;

      case WhenStatement(:final condition, :final body):
        if (_expectBool(await _evalExpr(condition, env), condition.span)) {
          await executeBlock(body, env.child(), hoistDeclarations: true);
        }
        return null;

      case GuardStatement(:final condition, :final elseBody):
        if (!_expectBool(await _evalExpr(condition, env), condition.span)) {
          await executeBlock(elseBody, env.child(), hoistDeclarations: true);
        }
        return null;

      case GuardedStatement(
          :final statement,
          :final condition,
          :final letName,
          :final alternate
        ):
        if (letName != null) {
          final v = await _evalExpr(condition, env);
          if (v != null) {
            final child = env.child()..define(letName, v);
            return _execStatement(statement, child);
          } else if (alternate != null && statement is Binding) {
            final altVal = await _evalExpr(alternate, env);
            env.bind(statement.name, statement.mode, altVal, statement.span,
                declaredType: statement.type, allowMutation: allowMutation);
          }
          return null;
        }
        if (_expectBool(await _evalExpr(condition, env), condition.span)) {
          return _execStatement(statement, env);
        } else if (alternate != null && statement is Binding) {
          final altVal = await _evalExpr(alternate, env);
          env.bind(statement.name, statement.mode, altVal, statement.span,
              declaredType: statement.type, allowMutation: allowMutation);
        }
        return null;

      case LabelStatement(:final name, :final statement):
        return _execStatement(statement, env, activeLabel: name);

      case WhileStatement():
        await _execWhile(stmt, env, label: activeLabel);
        return null;

      case ForStatement():
        await _execFor(stmt, env, label: activeLabel);
        return null;

      case CForStatement():
        await _execCFor(stmt, env, label: activeLabel);
        return null;

      case RepeatStatement():
        await _execRepeat(stmt, env, label: activeLabel);
        return null;

      case BreakStatement(:final label, :final value):
        final val = value == null ? null : await _evalExpr(value, env);
        throw BreakSignal(label: label, value: val, hasValue: value != null);

      case ContinueStatement(:final label):
        throw ContinueSignal(label: label);

      case IndexAssignment(:final target, :final operator, :final value):
        await _execIndexAssignment(target, operator, value, env, stmt.span);
        return null;

      case MemberAssignment(
          :final object,
          :final name,
          :final operator,
          :final value
        ):
        await _execMemberAssignment(
            object, name, operator, value, env, stmt.span);
        return null;

      case ParallelAssignment(:final targets, :final values):
        await _execParallelAssignment(targets, values, env, stmt.span);
        return null;

      case RequireStatement(
          :final condition,
          :final message,
          :final kind,
          :final source
        ):
        final ok = _expectBool(await _evalExpr(condition, env), condition.span);
        if (!ok) {
          final msg = message != null
              ? qudsFormatValue(await _evalExpr(message, env))
              : '$kind failed${source != null ? ': $source' : ''}';
          throw QudsThrownValue(
              kind == 'require' ? ArgumentError(msg) : StateError(msg),
              stmt.span,
              stackFrames);
        }
        return null;

      case ImportDeclaration():
        if (!allowImports) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.featureDisabled,
            'Imports (`use ${stmt.uri}`) are disabled by the active execution policy.',
            stmt.span,
            stackFrames: stackFrames,
          );
        }
        if (onImport != null) {
          await onImport!(stmt, env);
        } else {
          throw QudsRuntimeException(
            'Import `${stmt.uri}` is not available in bare evaluator mode (use QudsSession).',
            stmt.span,
            code: 'E900',
            stackFrames: stackFrames,
          );
        }
        return null;

      case SectionDeclaration():
      case AliasDeclaration():
      case PartDirective():
      case AnnotationDeclaration():
        return null;

      case ExtensionDeclaration():
        registerExtension(stmt, env);
        return null;

      case TryStatement():
        await _execTry(stmt, env);
        return null;

      case ThrowStatement(:final value):
        if (!allowExceptions) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.featureDisabled,
            'Throwing exceptions is disabled by the active execution policy.',
            stmt.span,
            stackFrames: stackFrames,
          );
        }
        final v = await _evalExpr(value, env);
        throw QudsThrownValue(v, stmt.span, stackFrames);

      case RethrowStatement():
        if (_thrownStack.isEmpty) {
          throw QudsRuntimeException(
              '`rethrow` is only valid inside a `catch` block.', stmt.span);
        }
        throw QudsThrownValue(_thrownStack.last, stmt.span, stackFrames);

      case ClassDeclaration():
        if (!allowClasses) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.featureDisabled,
            'Class declarations (`${stmt.name}`) are disabled by the active execution policy.',
            stmt.span,
            stackFrames: stackFrames,
          );
        }
        await _execClassDeclaration(stmt, env);
        return null;

      case MatchStatement(:final value, :final arms):
        final scrutinee = await _evalExpr(value, env);
        for (final arm in arms) {
          final armEnv = env.child();
          if (await _matchPattern(arm.pattern, scrutinee, armEnv, stmt.span)) {
            if (arm.guard != null &&
                !_expectBool(
                    await _evalExpr(arm.guard!, armEnv), arm.guard!.span)) {
              continue;
            }
            await executeBlock(arm.body, armEnv, hoistDeclarations: true);
            break;
          }
        }
        return null;

      case IfCaseStatement(
          :final scrutinee,
          :final pattern,
          :final guard,
          :final body,
          :final elseBody
        ):
        final v = await _evalExpr(scrutinee, env);
        final child = env.child();
        final matched = await _matchPattern(pattern, v, child, stmt.span) &&
            (guard == null ||
                _expectBool(await _evalExpr(guard, child), guard.span));
        if (matched) {
          await executeBlock(body, child, hoistDeclarations: true);
        } else if (elseBody.isNotEmpty) {
          await executeBlock(elseBody, env.child(), hoistDeclarations: true);
        }
        return null;

      case DestructureStatement(
          :final pattern,
          :final value,
          :final elseBody,
          :final mutable
        ):
        final v = await _evalExpr(value, env);
        final matched = await _matchPattern(pattern, v, env, stmt.span,
            mutableBindings: mutable);
        if (!matched) {
          if (elseBody != null && elseBody.isNotEmpty) {
            await executeBlock(elseBody, env.child(), hoistDeclarations: true);
          } else {
            throw QudsRuntimeException(
              'Destructuring pattern did not match value `${qudsFormatValue(v)}`.',
              stmt.span,
            );
          }
        }
        return null;

      case UsingStatement(:final name, :final value, :final body):
        final resource = await _evalExpr(value, env);
        final child = env.child()..define(name, resource);
        try {
          await executeBlock(body, child, hoistDeclarations: true);
        } finally {
          await _tryCloseResource(resource, stmt.span);
        }
        return null;

      case DeferStatement():
        return null;

      case TestDeclaration(:final body):
        await executeBlock(body, env.child(), hoistDeclarations: true);
        return null;

      case ConfigDeclaration(:final name, :final value):
        final v = value == null ? null : await _evalExpr(value, env);
        final parts = name.split('.');
        if (parts.length == 1) {
          env.define(name, v);
        } else {
          final rootName = parts.first;
          QudsNamespace current;
          final existing = env.resolveSlot(rootName)?.value;
          if (existing is QudsNamespace) {
            current = existing;
          } else {
            current = QudsNamespace(rootName, {});
            env.define(rootName, current);
          }
          for (var i = 1; i < parts.length - 1; i++) {
            final seg = parts[i];
            final next = current.members[seg];
            if (next is QudsNamespace) {
              current = next;
            } else {
              final child = QudsNamespace(seg, {});
              current.members[seg] = child;
              current = child;
            }
          }
          current.members[parts.last] = v;
        }
        return null;

      case LockStatement(:final body):
        await executeBlock(body, env.child(), hoistDeclarations: true);
        return null;

      case OnceStatement(:final body):
        if (_executedOnceSites.add(identityHashCode(stmt))) {
          await executeBlock(body, env.child(), hoistDeclarations: true);
        }
        return null;

      case YieldStatement(:final value, :final star):
        if (_yieldStack.isEmpty) {
          throw QudsRuntimeException(
            '`yield` is only valid inside a `sync*` or `async*` generator.',
            stmt.span,
          );
        }
        final v = await _evalExpr(value, env);
        if (star && v is Iterable) {
          _yieldStack.last.addAll(v);
        } else {
          _yieldStack.last.add(v);
        }
        return null;

      case TaskGroupStatement(:final children):
        for (final child in children) {
          if (child is Statement) {
            await _execStatement(child, env);
          } else if (child is Expression) {
            final res = await _evalExpr(child, env);
            if (res is QudsFuture) {
              await res.future;
            }
          }
        }
        return null;

      case WatchStatement(:final value, :final body):
        final initial = await _evalExpr(value, env);
        _watchers.add(_QudsWatchEntry(value, body, env, initial));
        return null;

      case BatchStatement(:final body):
        _batchDepth++;
        try {
          await executeBlock(body, env, hoistDeclarations: true);
        } finally {
          _batchDepth--;
          if (_batchDepth == 0 && _watchersDirty) {
            _watchersDirty = false;
            await _flushReactive();
          }
        }
        return null;

      case RaiseStatement(:final name, :final arguments):
        Object? channel;
        final thisVal = env.resolveSlot('this')?.value;
        if (thisVal is QudsInstance && thisVal.fields.containsKey(name)) {
          channel = thisVal.fields[name];
        } else {
          channel = env.resolveSlot(name)?.value;
        }
        if (channel is! QudsEventChannel) {
          throw QudsRuntimeException('Undefined event `$name`.', stmt.span);
        }
        final pos = <Object?>[];
        final named = <String, Object?>{};
        for (final arg in arguments) {
          final v = await _evalExpr(arg.value, env);
          if (arg.name != null) {
            named[arg.name!] = v;
          } else {
            pos.add(v);
          }
        }
        for (final listener in List<QudsCallable>.from(channel.listeners)) {
          await invokeCallable(listener, pos, named, stmt.span);
        }
        return null;
    }
  }

  Future<void> _notifyStateChanged() async {
    if (_computedCells.isEmpty && _watchers.isEmpty) return;
    if (_batchDepth > 0) {
      _watchersDirty = true;
      return;
    }
    await _flushReactive();
  }

  Future<void> _flushReactive() async {
    for (final cell in _computedCells) {
      final updated = await _evalExpr(cell.expr, cell.env);
      final slot = cell.env.localSlots[cell.name];
      if (slot != null) {
        slot.value = updated;
      }
    }
    for (final w in List<_QudsWatchEntry>.from(_watchers)) {
      final next = await _evalExpr(w.expr, w.env);
      if (!qudsEquals(next, w.lastValue)) {
        w.lastValue = next;
        await executeBlock(w.body, w.env.child(), hoistDeclarations: true);
      }
    }
  }

  Future<Object?> _evalDotShorthand(
    DotShorthand shorthand,
    String? declaredType,
    QudsEnvironment env,
    SourceSpan span,
  ) async {
    if (declaredType != null && declaredType.isNotEmpty) {
      final baseName = _baseTypeName(declaredType);
      final target = env.resolveSlot(baseName)?.value;
      if (target is QudsClass) {
        if (shorthand.arguments == null) {
          if (target.enumCases.containsKey(shorthand.name)) {
            return target.enumCases[shorthand.name];
          }
          if (target.staticFields.containsKey(shorthand.name)) {
            return target.staticFields[shorthand.name];
          }
        } else {
          final pos = <Object?>[];
          final named = <String, Object?>{};
          for (final arg in shorthand.arguments!) {
            final v = await _evalExpr(arg.value, env);
            if (arg.name != null) {
              named[arg.name!] = v;
            } else {
              pos.add(v);
            }
          }
          final ctor = shorthand.name == 'new'
              ? null
              : target.constructors[shorthand.name];
          return _instantiateClass(target, pos, named, span, ctor: ctor);
        }
      }
    }
    throw QudsRuntimeException(
      'Expression `DotShorthand` requires an explicit target type context.',
      span,
    );
  }

  Future<void> _execBinding(Binding stmt, QudsEnvironment env) async {
    if (stmt.operator == '=') {
      final Object? val;
      if (stmt.open) {
        val = null;
      } else if (stmt.value is DotShorthand) {
        val = await _evalDotShorthand(
            stmt.value as DotShorthand, stmt.type, env, stmt.span);
      } else {
        val = await _evalExpr(stmt.value, env);
      }
      env.bind(
        stmt.name,
        stmt.mode,
        val,
        stmt.span,
        declaredType: stmt.type,
        open: stmt.open,
        allowMutation: allowMutation,
      );
      if (stmt.mode == BindingMode.computed) {
        _computedCells.add(_QudsComputedEntry(stmt.name, stmt.value, env));
      } else if (_computedCells.isNotEmpty || _watchers.isNotEmpty) {
        await _notifyStateChanged();
      }
      return;
    }

    // Compound assignment (`+=`, `-=`, `*=`, `/=`, `~/=`, `%=`, `??=`, ...)
    final current = env.get(stmt.name, stmt.span);
    if (stmt.operator == '??=') {
      if (current == null) {
        final rhs = await _evalExpr(stmt.value, env);
        env.assignExisting(stmt.name, rhs, stmt.span,
            allowMutation: allowMutation);
        await _notifyStateChanged();
      }
      return;
    }
    final rhs = await _evalExpr(stmt.value, env);
    final baseOp = stmt.operator.substring(0, stmt.operator.length - 1);
    final updated = await _applyBinaryOp(current, baseOp, rhs, stmt.span);
    env.assignExisting(stmt.name, updated, stmt.span,
        allowMutation: allowMutation);
    await _notifyStateChanged();
  }

  Future<Object?> _execWhile(
    WhileStatement stmt,
    QudsEnvironment env, {
    String? label,
  }) async {
    var index = 0;
    var broke = false;
    Object? breakValue;

    while (true) {
      await _tick(stmt.span);
      if (maxLoopIterations != null && index >= maxLoopIterations!) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.loopLimit,
          'Loop exceeded maximum iteration limit ($maxLoopIterations).',
          stmt.span,
          stackFrames: stackFrames,
        );
      }
      final iterEnv = env.child();
      if (stmt.letName != null) {
        final v = await _evalExpr(stmt.condition, env);
        if (v == null) break;
        iterEnv.define(stmt.letName!, v);
      } else if (stmt.pattern != null) {
        final v = await _evalExpr(stmt.condition, env);
        if (!await _matchPattern(stmt.pattern!, v, iterEnv, stmt.span)) break;
      } else {
        final ok = _expectBool(
            await _evalExpr(stmt.condition, env), stmt.condition.span);
        if (!ok) break;
      }

      iterEnv.define(
        r'$',
        QudsLoopContext(index: index, first: index == 0, last: false),
      );
      try {
        await executeBlock(stmt.body, iterEnv, hoistDeclarations: true);
      } on ContinueSignal catch (sig) {
        if (sig.label != null && sig.label != label) rethrow;
      } on BreakSignal catch (sig) {
        if (sig.label != null && sig.label != label) rethrow;
        broke = true;
        breakValue = sig.value;
        break;
      }
      index++;
    }

    if (!broke && stmt.elseBody.isNotEmpty) {
      await executeBlock(stmt.elseBody, env.child(), hoistDeclarations: true);
    }
    return broke ? breakValue : null;
  }

  Future<Object?> _execFor(
    ForStatement stmt,
    QudsEnvironment env, {
    String? label,
  }) async {
    final iterableVal = await _evalExpr(stmt.iterable, env);
    Iterable<Object?> items;
    if (iterableVal is QudsRange) {
      if (stmt.step != null) {
        final stepVal =
            _expectInt(await _evalExpr(stmt.step!, env), stmt.step!.span);
        if (stepVal == 0) {
          throw QudsRuntimeException(
              'For-loop step cannot be 0.', stmt.step!.span);
        }
        items = iterableVal.withStep(stepVal);
      } else {
        items = iterableVal;
      }
    } else if (iterableVal is Iterable) {
      items = iterableVal;
    } else if (iterableVal is String) {
      items = iterableVal.split('');
    } else {
      throw QudsRuntimeException(
        'Cannot iterate over value of type `${qudsTypeName(iterableVal)}`.',
        stmt.iterable.span,
      );
    }

    final material = items.toList();
    _checkCollectionSize(material.length, stmt.iterable.span);

    var broke = false;
    Object? breakValue;
    for (var i = 0; i < material.length; i++) {
      await _tick(stmt.span);
      if (maxLoopIterations != null && i >= maxLoopIterations!) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.loopLimit,
          'Loop exceeded maximum iteration limit ($maxLoopIterations).',
          stmt.span,
          stackFrames: stackFrames,
        );
      }
      final item = material[i];
      final iterEnv = env.child();
      if (stmt.index != null) {
        if (item is QudsRecord && item.positional.length >= 2) {
          iterEnv.define(stmt.index!, item.positional[0]);
          iterEnv.define(stmt.name, item.positional[1]);
        } else if (item is MapEntry) {
          iterEnv.define(stmt.index!, item.key);
          iterEnv.define(stmt.name, item.value);
        } else {
          iterEnv.define(stmt.index!, i);
          iterEnv.define(stmt.name, item);
        }
      } else {
        iterEnv.define(stmt.name, item);
      }
      iterEnv.define(
        r'$',
        QudsLoopContext(
          index: i,
          count: material.length,
          first: i == 0,
          last: i == material.length - 1,
          item: item,
          hasItem: true,
          prev: i > 0 ? material[i - 1] : null,
          next: i + 1 < material.length ? material[i + 1] : null,
        ),
      );
      try {
        await executeBlock(stmt.body, iterEnv, hoistDeclarations: true);
      } on ContinueSignal catch (sig) {
        if (sig.label != null && sig.label != label) rethrow;
      } on BreakSignal catch (sig) {
        if (sig.label != null && sig.label != label) rethrow;
        broke = true;
        breakValue = sig.value;
        break;
      }
    }

    if (!broke && stmt.elseBody.isNotEmpty) {
      await executeBlock(stmt.elseBody, env.child(), hoistDeclarations: true);
    }
    return broke ? breakValue : null;
  }

  Future<Object?> _execCFor(
    CForStatement stmt,
    QudsEnvironment env, {
    String? label,
  }) async {
    final loopEnv = env.child();
    await _execStatement(stmt.init, loopEnv);
    var index = 0;
    var broke = false;
    Object? breakValue;

    while (true) {
      await _tick(stmt.span);
      if (maxLoopIterations != null && index >= maxLoopIterations!) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.loopLimit,
          'Loop exceeded maximum iteration limit ($maxLoopIterations).',
          stmt.span,
          stackFrames: stackFrames,
        );
      }
      if (!_expectBool(
          await _evalExpr(stmt.condition, loopEnv), stmt.condition.span)) {
        break;
      }
      final iterEnv = loopEnv.child()
        ..define(
          r'$',
          QudsLoopContext(index: index, first: index == 0, last: false),
        );
      try {
        await executeBlock(stmt.body, iterEnv, hoistDeclarations: true);
      } on ContinueSignal catch (sig) {
        if (sig.label != null && sig.label != label) rethrow;
      } on BreakSignal catch (sig) {
        if (sig.label != null && sig.label != label) rethrow;
        broke = true;
        breakValue = sig.value;
        break;
      }
      if (stmt.step != null) {
        await _evalExpr(stmt.step!, loopEnv);
      }
      index++;
    }

    if (!broke && stmt.elseBody.isNotEmpty) {
      await executeBlock(stmt.elseBody, env.child(), hoistDeclarations: true);
    }
    return broke ? breakValue : null;
  }

  Future<Object?> _execRepeat(
    RepeatStatement stmt,
    QudsEnvironment env, {
    String? label,
  }) async {
    var broke = false;
    Object? breakValue;

    if (stmt.count != null) {
      final total =
          _expectInt(await _evalExpr(stmt.count!, env), stmt.count!.span);
      for (var i = 0; i < total; i++) {
        await _tick(stmt.span);
        if (maxLoopIterations != null && i >= maxLoopIterations!) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.loopLimit,
            'Loop exceeded maximum iteration limit ($maxLoopIterations).',
            stmt.span,
            stackFrames: stackFrames,
          );
        }
        final iterEnv = env.child()
          ..define(
            r'$',
            QudsLoopContext(
              index: i,
              count: total,
              first: i == 0,
              last: i == total - 1,
            ),
          );
        try {
          await executeBlock(stmt.body, iterEnv, hoistDeclarations: true);
        } on ContinueSignal catch (sig) {
          if (sig.label != null && sig.label != label) rethrow;
        } on BreakSignal catch (sig) {
          if (sig.label != null && sig.label != label) rethrow;
          broke = true;
          breakValue = sig.value;
          break;
        }
      }
    } else {
      var index = 0;
      while (true) {
        await _tick(stmt.span);
        if (maxLoopIterations != null && index >= maxLoopIterations!) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.loopLimit,
            'Loop exceeded maximum iteration limit ($maxLoopIterations).',
            stmt.span,
            stackFrames: stackFrames,
          );
        }
        final iterEnv = env.child()
          ..define(
            r'$',
            QudsLoopContext(index: index, first: index == 0, last: false),
          );
        try {
          await executeBlock(stmt.body, iterEnv, hoistDeclarations: true);
        } on ContinueSignal catch (sig) {
          if (sig.label != null && sig.label != label) rethrow;
        } on BreakSignal catch (sig) {
          if (sig.label != null && sig.label != label) rethrow;
          broke = true;
          breakValue = sig.value;
          break;
        }
        if (stmt.condition != null &&
            !_expectBool(
                await _evalExpr(stmt.condition!, env), stmt.condition!.span)) {
          break;
        }
        index++;
      }
    }

    if (!broke && stmt.elseBody.isNotEmpty) {
      await executeBlock(stmt.elseBody, env.child(), hoistDeclarations: true);
    }
    return broke ? breakValue : null;
  }

  Future<void> _execIndexAssignment(
    IndexExpression target,
    String operator,
    Expression valueExpr,
    QudsEnvironment env,
    SourceSpan span,
  ) async {
    if (!allowMutation) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.featureDisabled,
        'Index mutation is disabled by the active execution policy.',
        span,
        stackFrames: stackFrames,
      );
    }
    final container = await _evalExpr(target.object, env);
    final index = await _evalExpr(target.index, env);
    Object? newValue;
    if (operator == '=') {
      newValue = await _evalExpr(valueExpr, env);
    } else if (operator == '??=') {
      final existing = await _evalIndexRead(container, index, span);
      if (existing != null) return;
      newValue = await _evalExpr(valueExpr, env);
    } else {
      final existing = await _evalIndexRead(container, index, span);
      final rhs = await _evalExpr(valueExpr, env);
      final baseOp = operator.substring(0, operator.length - 1);
      newValue = await _applyBinaryOp(existing, baseOp, rhs, span);
    }

    if (container is List) {
      final idx = _expectInt(index, target.index.span);
      final resolved = idx < 0 ? container.length + idx : idx;
      if (resolved < 0 || resolved >= container.length) {
        throw QudsRuntimeException(
            'List index $idx out of range (length ${container.length}).', span);
      }
      container[resolved] = newValue;
      return;
    }
    if (container is Map) {
      container[index] = newValue;
      _checkCollectionSize(container.length, span);
      return;
    }
    if (container is QudsInstance || _extensionOperators.isNotEmpty) {
      final overload =
          _resolveOperatorOverload(container, '[]=', [index, newValue]);
      if (overload != null) {
        final (fn, isExt) = overload;
        if (isExt) {
          await _invokeExtension(
              fn, container, [index, newValue], const {}, span);
        } else {
          await invokeCallable(fn.bind(container as QudsInstance),
              [index, newValue], const {}, span);
        }
        return;
      }
    }
    throw QudsRuntimeException(
        'Cannot index-assign value of type `${qudsTypeName(container)}`.',
        span);
  }

  Future<void> _execMemberAssignment(
    Expression objectExpr,
    String name,
    String operator,
    Expression valueExpr,
    QudsEnvironment env,
    SourceSpan span,
  ) async {
    if (!allowMutation) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.featureDisabled,
        'Member mutation (`.$name`) is disabled by the active execution policy.',
        span,
        stackFrames: stackFrames,
      );
    }
    final receiver = await _evalExpr(objectExpr, env);
    Object? newValue;
    if (operator == '=') {
      newValue = await _evalExpr(valueExpr, env);
    } else {
      final current = await _evalMemberRead(receiver, name, false, span);
      if (operator == '??=' && current != null) return;
      final rhs = await _evalExpr(valueExpr, env);
      if (operator == '??=') {
        newValue = rhs;
      } else {
        final baseOp = operator.substring(0, operator.length - 1);
        newValue = await _applyBinaryOp(current, baseOp, rhs, span);
      }
    }

    if (receiver is QudsInstance) {
      final prop = receiver.qudsClass.lookupProperty(name);
      if (prop != null && prop.setter != null && prop.setterBody != null) {
        final setterEnv =
            receiver.qudsClass.definingEnv.child(isFunctionBoundary: true)
              ..define('this', receiver)
              ..define(prop.setter!, newValue);
        _exposeInstanceFields(receiver, setterEnv);
        await executeBlock(prop.setterBody!, setterEnv);
        _syncInstanceFieldsBack(receiver, setterEnv);
        await _notifyStateChanged();
        return;
      }
      final fieldDecl = _findFieldDecl(receiver.qudsClass, name);
      if (fieldDecl != null &&
          !fieldDecl.mutable &&
          !_initializingInstances.contains(receiver)) {
        throw QudsRuntimeException(
            'Cannot assign to immutable field `${receiver.qudsClass.name}.$name`.',
            span,
            code: 'E202');
      }
      receiver.fields[name] = newValue;
      // Keep exposed field slot in sync so `_syncInstanceFieldsBack` does not clobber `this.field = ...`.
      if (identical(env.resolveSlot('this')?.value, receiver)) {
        final fieldSlot = env.resolveSlot(name);
        if (fieldSlot != null) {
          fieldSlot.value = newValue;
        }
      }
      await _notifyStateChanged();
      return;
    }
    if (receiver is QudsClass) {
      receiver.staticFields[name] = newValue;
      await _notifyStateChanged();
      return;
    }
    throw QudsRuntimeException(
        'Cannot assign member `$name` on `${qudsTypeName(receiver)}`.', span);
  }

  Future<void> _execParallelAssignment(
    List<Pattern> targets,
    List<Expression> values,
    QudsEnvironment env,
    SourceSpan span,
  ) async {
    // Evaluate ALL right-hand expressions left-to-right first!
    final evaluated = <Object?>[];
    for (final expr in values) {
      evaluated.add(await _evalExpr(expr, env));
    }
    List<Object?> items;
    if (evaluated.length == 1 && targets.length > 1) {
      final single = evaluated.first;
      if (single is QudsRecord) {
        items = single.positional;
      } else if (single is List) {
        items = single;
      } else {
        throw QudsRuntimeException(
            'Cannot unpack `${qudsTypeName(single)}` into ${targets.length} targets.',
            span);
      }
    } else {
      items = evaluated;
    }
    if (items.length < targets.length) {
      throw QudsRuntimeException(
          'Expected ${targets.length} values in parallel assignment, got ${items.length}.',
          span);
    }
    for (var i = 0; i < targets.length; i++) {
      final pat = targets[i];
      if (pat is BindingPattern) {
        final mode = pat.shadow ? BindingMode.shadow : BindingMode.inferred;
        env.bind(pat.name, mode, items[i], pat.span,
            allowMutation: allowMutation);
      } else {
        final ok = await _matchPattern(pat, items[i], env, span);
        if (!ok) {
          throw QudsRuntimeException(
              'Parallel assignment pattern did not match.', pat.span);
        }
      }
    }
  }

  Future<void> _execTry(TryStatement stmt, QudsEnvironment env) async {
    var threw = false;
    try {
      await executeBlock(stmt.body, env.child(), hoistDeclarations: true);
    } on QudsPolicyViolationException {
      rethrow; // Policy violations can NEVER be swallowed by user `catch`!
    } on ReturnSignal {
      rethrow;
    } on BreakSignal {
      rethrow;
    } on ContinueSignal {
      rethrow;
    } on ResultSignal {
      rethrow;
    } on PropagateErrorSignal {
      rethrow;
    } catch (err) {
      threw = true;
      final thrownObj = err is QudsThrownValue ? err.value : err;
      var handled = false;
      for (final clause in stmt.catches) {
        if (clause.type != null && !_matchesType(thrownObj, clause.type!)) {
          continue;
        }
        handled = true;
        final catchEnv = env.child()..define(clause.name, thrownObj);
        if (clause.trace != null) {
          final traceText = stackFrames.reversed.map((f) => '$f').join('\n');
          catchEnv.define(clause.trace!, traceText);
        }
        _thrownStack.add(thrownObj);
        try {
          await executeBlock(clause.body, catchEnv, hoistDeclarations: true);
        } finally {
          _thrownStack.removeLast();
        }
        break;
      }
      if (!handled) rethrow;
    } finally {
      if (stmt.finallyBody.isNotEmpty) {
        await executeBlock(stmt.finallyBody, env.child(),
            hoistDeclarations: true);
      }
    }
    if (!threw && stmt.elseBody.isNotEmpty) {
      await executeBlock(stmt.elseBody, env.child(), hoistDeclarations: true);
    }
  }

  Future<void> _execClassDeclaration(
      ClassDeclaration decl, QudsEnvironment env) async {
    if (decl.kind == 'augment') {
      final existing = env.resolveSlot(decl.name)?.value;
      if (existing is QudsClass) {
        for (final field in decl.fields) {
          if (field.isStatic) {
            existing.staticFields[field.name] = field.initializer == null
                ? null
                : await _evalExpr(field.initializer!, env);
          }
        }
        for (final prop in decl.properties) {
          existing.properties[prop.name] = prop;
        }
        for (final ctor in decl.constructors) {
          existing.constructors[ctor.name ?? ''] = ctor;
        }
        for (final m in decl.methods) {
          final fn = QudsUserFunction(
            name: m.name,
            parameters: m.parameters,
            body: m.body,
            expressionBody: m.expressionBody,
            isAsync: m.isAsync,
            generator: m.generator,
            returnType: m.returnType ?? '',
            closure: env,
            span: m.span,
            definingClass: existing,
          );
          if (m.conversionKind.isNotEmpty) {
            existing.conversions.add(fn);
            _customConversions.add(fn);
          } else if (m.isStatic) {
            existing.staticMethods[m.name] = fn;
          } else if (m.isOperator) {
            existing.operators.putIfAbsent(m.name, () => []).add(fn);
            existing.methods[m.name] ??= fn;
          } else {
            existing.methods[m.name] = fn;
          }
        }
        return;
      }

      // Augmenting a built-in or external type (e.g., `augment String:`, `augment int:`)
      final targetKey = _baseTypeName(decl.name);
      final bucket = _extensions.putIfAbsent(targetKey, () => {});
      final opBucket = _extensionOperators.putIfAbsent(targetKey, () => {});
      for (final m in decl.methods) {
        final fn = QudsUserFunction(
          name: m.name,
          parameters: m.parameters,
          body: m.body,
          expressionBody: m.expressionBody,
          isAsync: m.isAsync,
          generator: m.generator,
          returnType: m.returnType ?? '',
          closure: env,
          span: m.span,
        );
        if (m.conversionKind.isNotEmpty) {
          _customConversions.add(fn);
        } else if (m.isOperator) {
          opBucket.putIfAbsent(m.name, () => []).add((decl.name, fn));
        } else {
          bucket[m.name] = fn;
        }
      }
      return;
    }

    QudsClass? superclass;
    if (decl.superclass != null) {
      final supVal = env.resolveSlot(_baseTypeName(decl.superclass!))?.value;
      if (supVal is QudsClass) superclass = supVal;
    }

    final mixins = <QudsClass>[];
    for (final mixinName in decl.mixins) {
      final mVal = env.resolveSlot(_baseTypeName(mixinName))?.value;
      if (mVal is QudsClass) mixins.add(mVal);
    }

    final methods = <String, QudsUserFunction>{};
    final operators = <String, List<QudsUserFunction>>{};
    final staticMethods = <String, QudsUserFunction>{};
    final staticFields = <String, Object?>{};
    final constructors = <String, ConstructorDeclaration>{};
    final properties = <String, PropertyDeclaration>{};
    final enumCases = <String, QudsInstance>{};
    final conversions = <QudsUserFunction>[];

    final klass = QudsClass(
      name: decl.name,
      kind: decl.kind,
      declaration: decl,
      definingEnv: env,
      superclass: superclass,
      mixins: mixins,
      methods: methods,
      operators: operators,
      staticMethods: staticMethods,
      staticFields: staticFields,
      constructors: constructors,
      properties: properties,
      enumCases: enumCases,
      conversions: conversions,
    );
    env.define(decl.name, klass);

    for (final field in decl.fields) {
      if (field.isStatic) {
        staticFields[field.name] = field.initializer == null
            ? null
            : await _evalExpr(field.initializer!, env);
      }
    }

    for (final prop in decl.properties) {
      properties[prop.name] = prop;
    }

    for (final ctor in decl.constructors) {
      constructors[ctor.name ?? ''] = ctor;
    }

    for (final m in decl.methods) {
      final fn = QudsUserFunction(
        name: m.name,
        parameters: m.parameters,
        body: m.body,
        expressionBody: m.expressionBody,
        isAsync: m.isAsync,
        generator: m.generator,
        returnType: m.returnType ?? '',
        closure: env,
        span: m.span,
        definingClass: klass,
      );
      if (m.conversionKind.isNotEmpty) {
        conversions.add(fn);
        _customConversions.add(fn);
      } else if (m.isStatic) {
        staticMethods[m.name] = fn;
      } else if (m.isOperator) {
        operators.putIfAbsent(m.name, () => []).add(fn);
        methods[m.name] ??= fn;
      } else {
        methods[m.name] = fn;
      }
    }

    if (decl.kind == 'enum') {
      for (var i = 0; i < decl.cases.length; i++) {
        final c = decl.cases[i];
        final fields = <String, Object?>{'name': c.name, 'index': i};
        final instance =
            QudsInstance(klass, fields, enumCaseName: c.name, enumIndex: i);
        enumCases[c.name] = instance;
      }
      staticFields['values'] = enumCases.values.toList();
    } else if (decl.cases.isNotEmpty) {
      // Sealed class cases -> register each case as a subclass of `klass`!
      for (final c in decl.cases) {
        final caseDecl = ClassDeclaration(
          c.name,
          'value',
          c.fields,
          const [],
          const [],
          const [],
          c.span,
          superclass: decl.name,
        );
        final caseClass = QudsClass(
          name: c.name,
          kind: 'value',
          declaration: caseDecl,
          definingEnv: env,
          superclass: klass,
        );
        env.define(c.name, caseClass);
        staticFields[c.name] = caseClass;
      }
    }
  }

  // -------------------------------------------------------------------------
  // Expressions
  // -------------------------------------------------------------------------

  Future<Object?> _evalExpr(Expression expr, QudsEnvironment env) async {
    switch (expr) {
      case Literal(:final value):
        return value;

      case DurationLiteral(:final microseconds):
        return Duration(microseconds: microseconds);

      case Identifier(:final name):
        if (name == 'missing') return QudsMissing.instance;
        return env.get(name, expr.span);

      case ThisExpression():
        return env.get('this', expr.span);

      case InterpolatedString(:final parts):
        final buffer = StringBuffer();
        for (final part in parts) {
          final v = await _evalExpr(part, env);
          final formatted = formatValueForOutput(v, expr.span);
          buffer
              .write(formatted is Future<String> ? await formatted : formatted);
          _checkStringLength(buffer.length, expr.span);
        }
        return buffer.toString();

      case ShownExpression(:final value, :final text):
        final v = await _evalExpr(value, env);
        return '$text = ${qudsFormatValue(v)}';

      case UnaryExpression(:final operator, :final operand):
        final v = await _evalExpr(operand, env);
        return _applyUnaryOp(operator, v, expr.span);

      case BinaryExpression(:final left, :final operator, :final right):
        return _evalBinary(left, operator, right, env, expr.span);

      case ChainComparison(:final operands, :final operators):
        var lhs = await _evalExpr(operands.first, env);
        for (var i = 0; i < operators.length; i++) {
          final rhs = await _evalExpr(operands[i + 1], env);
          final ok = await _applyBinaryOp(lhs, operators[i], rhs, expr.span);
          if (ok != true) return false;
          lhs = rhs;
        }
        return true;

      case TypeTestExpression(:final operand, :final operator, :final type):
        final v = await _evalExpr(operand, env);
        final matched = _matchesType(v, type);
        if (operator == 'is') return matched;
        if (operator == 'is!') return !matched;
        if (operator == 'as') {
          if (!matched) {
            throw QudsRuntimeException(
              'Type cast failed: `${qudsTypeName(v)}` is not `$type`.',
              expr.span,
              code: 'R300',
            );
          }
          return v;
        }
        throw QudsRuntimeException(
            'Unknown type operator `$operator`.', expr.span);

      case ConversionExpression(:final operand, :final type, :final safe):
        final v = await _evalExpr(operand, env);
        return _applyConversion(v, type, safe, expr.span);

      case ListExpression(:final elements, :final nullAware):
        final out = <Object?>[];
        for (var i = 0; i < elements.length; i++) {
          await _collectElement(
            elements[i],
            out,
            env,
            isNullAware: i < nullAware.length && nullAware[i],
          );
          _checkCollectionSize(out.length, expr.span);
        }
        return out;

      case SetExpression(:final elements, :final nullAware):
        final out = <Object?>{};
        final tmp = <Object?>[];
        for (var i = 0; i < elements.length; i++) {
          tmp.clear();
          await _collectElement(
            elements[i],
            tmp,
            env,
            isNullAware: i < nullAware.length && nullAware[i],
          );
          out.addAll(tmp);
          _checkCollectionSize(out.length, expr.span);
        }
        return out;

      case MapExpression(:final keys, :final values):
        final out = <Object?, Object?>{};
        for (var i = 0; i < keys.length; i++) {
          final k = await _evalExpr(keys[i], env);
          final v = await _evalExpr(values[i], env);
          out[k] = v;
          _checkCollectionSize(out.length, expr.span);
        }
        return out;

      case MapComprehension(
          :final condition,
          :final name,
          :final iterable,
          :final thenMap,
          :final elseMap
        ):
        final out = <Object?, Object?>{};
        if (iterable != null && name != null) {
          final seq = await _evalExpr(iterable, env);
          if (seq is! Iterable) {
            throw QudsRuntimeException(
                'Expected iterable in map comprehension.', expr.span);
          }
          for (final item in seq) {
            final child = env.child()..define(name, item);
            if (condition != null &&
                !_expectBool(
                    await _evalExpr(condition, child), condition.span)) {
              continue;
            }
            final sub = await _evalExpr(thenMap, child);
            if (sub is Map) out.addAll(sub);
            _checkCollectionSize(out.length, expr.span);
          }
        } else if (condition != null) {
          if (_expectBool(await _evalExpr(condition, env), condition.span)) {
            final sub = await _evalExpr(thenMap, env);
            if (sub is Map) out.addAll(sub);
          } else if (elseMap != null) {
            final sub = await _evalExpr(elseMap, env);
            if (sub is Map) out.addAll(sub);
          }
        }
        return out;

      case RecordExpression(:final fields, :final names):
        final pos = <Object?>[];
        final named = <String, Object?>{};
        for (var i = 0; i < fields.length; i++) {
          final v = await _evalExpr(fields[i], env);
          final fieldName = i < names.length ? names[i] : null;
          if (fieldName != null) {
            named[fieldName] = v;
          } else {
            pos.add(v);
          }
        }
        return QudsRecord(pos, named);

      case RangeExpression(:final start, :final end, :final inclusive):
        final s = _expectInt(await _evalExpr(start, env), start.span);
        final e = _expectInt(await _evalExpr(end, env), end.span);
        return QudsRange(s, e, inclusive: inclusive);

      case IndexExpression(:final object, :final index):
        final container = await _evalExpr(object, env);
        final idx = await _evalExpr(index, env);
        return _evalIndexRead(container, idx, expr.span);

      case SliceExpression(
          :final object,
          :final start,
          :final end,
          :final inclusive
        ):
        final container = await _evalExpr(object, env);
        final s = start == null
            ? null
            : _expectInt(await _evalExpr(start, env), start.span);
        final e = end == null
            ? null
            : _expectInt(await _evalExpr(end, env), end.span);
        return _evalSlice(container, s, e, inclusive, expr.span);

      case MemberAccess(:final object, :final name, :final nullAware):
        final receiver = await _evalExpr(object, env);
        return _evalMemberRead(receiver, name, nullAware, expr.span);

      case CallExpression(:final callee, :final arguments):
        return _evalCall(callee, arguments, env, expr.span);

      case TypeApplication(:final callee):
        // Type arguments are erased at runtime in the dynamic evaluator.
        return _evalExpr(callee, env);

      case Lambda(:final parameters, :final expressionBody, :final body):
        return QudsUserFunction(
          name: '<lambda>',
          parameters: parameters,
          body: body,
          expressionBody: expressionBody,
          closure: env,
          span: expr.span,
        );

      case CaptureExpression(:final names, :final body):
        final snapEnv = env.captureSnapshot(names, expr.span);
        return QudsUserFunction(
          name: '<capture>',
          parameters: const [],
          expressionBody: body,
          closure: snapEnv,
          span: expr.span,
        );

      case IfExpression(:final condition, :final thenValue, :final elseValue):
        final cond =
            _expectBool(await _evalExpr(condition, env), condition.span);
        return cond
            ? await _evalExpr(thenValue, env)
            : await _evalExpr(elseValue, env);

      case WhereExpression(:final value, :final bindings):
        final localEnv = env.child();
        for (final b in bindings) {
          await _execBinding(b, localEnv);
        }
        return _evalExpr(value, localEnv);

      case DoExpression(:final body):
        try {
          await executeBlock(body, env.child(), hoistDeclarations: true);
          return null;
        } on ResultSignal catch (res) {
          return res.value;
        }

      case LoopExpression(:final loop, :final fallback):
        final res = await switch (loop) {
          ForStatement() => _execFor(loop, env),
          WhileStatement() => _execWhile(loop, env),
          CForStatement() => _execCFor(loop, env),
          RepeatStatement() => _execRepeat(loop, env),
          LabelStatement(:final name, :final statement) => switch (statement) {
              ForStatement() => _execFor(statement, env, label: name),
              WhileStatement() => _execWhile(statement, env, label: name),
              CForStatement() => _execCFor(statement, env, label: name),
              RepeatStatement() => _execRepeat(statement, env, label: name),
              _ => Future<Object?>.value(null),
            },
          _ => Future<Object?>.value(null),
        };
        if (res != null) return res;
        return fallback == null ? null : await _evalExpr(fallback, env);

      case AssignExpression(:final name, :final operator, :final value):
        if (operator == '=') {
          final v = await _evalExpr(value, env);
          env.assignExisting(name, v, expr.span, allowMutation: allowMutation);
          return v;
        }
        final current = env.get(name, expr.span);
        if (operator == '??=') {
          if (current != null) return current;
          final rhs = await _evalExpr(value, env);
          env.assignExisting(name, rhs, expr.span,
              allowMutation: allowMutation);
          return rhs;
        }
        final rhs = await _evalExpr(value, env);
        final baseOp = operator.substring(0, operator.length - 1);
        final updated = await _applyBinaryOp(current, baseOp, rhs, expr.span);
        env.assignExisting(name, updated, expr.span,
            allowMutation: allowMutation);
        return updated;

      case MatchExpression(:final value, :final arms):
        final scrutinee = await _evalExpr(value, env);
        for (final arm in arms) {
          final armEnv = env.child();
          if (await _matchPattern(arm.pattern, scrutinee, armEnv, expr.span)) {
            if (arm.guard != null &&
                !_expectBool(
                    await _evalExpr(arm.guard!, armEnv), arm.guard!.span)) {
              continue;
            }
            return _evalExpr(arm.result, armEnv);
          }
        }
        throw QudsRuntimeException(
          'Non-exhaustive match for value `${qudsFormatValue(scrutinee)}`.',
          expr.span,
        );

      case TryExpression(:final operand, :final fallback):
        try {
          return await _evalExpr(operand, env);
        } on QudsPolicyViolationException {
          rethrow;
        } catch (_) {
          return _evalExpr(fallback, env);
        }

      case PropagateExpression(:final operand):
        final val = await _evalExpr(operand, env);
        if (val is QudsResult) {
          if (val.isOk) return val.value;
          throw PropagateErrorSignal(val);
        }
        throw QudsRuntimeException(
          'Operator `?` requires a `Result` value, got `${qudsTypeName(val)}`.',
          expr.span,
        );

      case AwaitExpression(:final operand):
        if (!allowAsync) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.featureDisabled,
            '`await` is disabled by the active execution policy.',
            expr.span,
            stackFrames: stackFrames,
          );
        }
        final v = await _evalExpr(operand, env);
        if (v is QudsFuture) return await v.future;
        return v is Future ? await v : v;

      case AwaitAllExpression(:final arms):
        if (!allowAsync) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.featureDisabled,
            '`await all` is disabled by the active execution policy.',
            expr.span,
            stackFrames: stackFrames,
          );
        }
        final futures = <Future<Object?>>[];
        for (final arm in arms) {
          final v = await _evalExpr(arm, env);
          if (v is QudsFuture) {
            futures.add(v.future);
          } else {
            futures.add(v is Future ? v : Future.value(v));
          }
        }
        final results = await Future.wait(futures);
        return QudsRecord(results, const {});

      case AwaitIsolateExpression(:final call):
        if (!allowAsync) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.featureDisabled,
            '`await isolate` is disabled by the active execution policy.',
            expr.span,
            stackFrames: stackFrames,
          );
        }
        final v = await _evalExpr(call, env);
        if (v is QudsFuture) return await v.future;
        return v is Future ? await v : v;

      case WithExpression(
          :final receiver,
          :final fields,
          :final values,
          :final nullAware
        ):
        final target = await _evalExpr(receiver, env);
        if (nullAware && target == null) return null;
        if (target is! QudsInstance) {
          throw QudsRuntimeException(
              '`with` requires a class instance, got `${qudsTypeName(target)}`.',
              expr.span);
        }
        final updatedFields = Map<String, Object?>.from(target.fields);
        for (var i = 0; i < fields.length; i++) {
          updatedFields[fields[i]] = await _evalExpr(values[i], env);
        }
        return QudsInstance(target.qudsClass, updatedFields);

      case NameofExpression(:final text):
        return text;

      case SymbolExpression(:final text):
        return Symbol(text);

      case TimeoutExpression(
          :final duration,
          :final bodyExpr,
          :final bodyStmts,
          :final fallbackExpr,
          :final fallbackStmts
        ):
        final dVal = await _evalExpr(duration, env);
        if (dVal is! Duration) {
          throw QudsRuntimeException(
              '`timeout` expects a Duration.', duration.span);
        }
        try {
          Future<Object?> run() async {
            if (bodyExpr != null) return _evalExpr(bodyExpr, env);
            if (bodyStmts != null) {
              return executeBlock(bodyStmts, env.child(),
                  returnLastExpression: true);
            }
            return null;
          }

          return await run().timeout(dVal);
        } on TimeoutException {
          if (fallbackExpr != null) return _evalExpr(fallbackExpr, env);
          if (fallbackStmts != null) {
            return executeBlock(fallbackStmts, env.child(),
                returnLastExpression: true);
          }
          rethrow;
        }

      case RetryExpression(
          :final attempts,
          :final delay,
          :final bodyExpr,
          :final bodyStmts,
          :final whenErrorName,
          :final whenCondition
        ):
        final maxAttempts =
            _expectInt(await _evalExpr(attempts, env), attempts.span);
        final delayDur = delay == null ? null : await _evalExpr(delay, env);
        Object? lastErr;
        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            if (bodyExpr != null) return await _evalExpr(bodyExpr, env);
            if (bodyStmts != null) {
              return await executeBlock(bodyStmts, env.child(),
                  returnLastExpression: true);
            }
            return null;
          } on QudsPolicyViolationException {
            rethrow;
          } catch (err) {
            lastErr = err is QudsThrownValue ? err.value : err;
            if (whenCondition != null && whenErrorName != null) {
              final condEnv = env.child()..define(whenErrorName, lastErr);
              if (!_expectBool(await _evalExpr(whenCondition, condEnv),
                  whenCondition.span)) {
                rethrow;
              }
            }
            if (attempt == maxAttempts) rethrow;
            if (delayDur is Duration && delayDur > Duration.zero) {
              await Future<void>.delayed(delayDur);
            }
          }
        }
        throw QudsThrownValue(lastErr, expr.span, stackFrames);

      case SpreadElement():
      case NullAwareElement():
      case CollectionIf():
      case CollectionFor():
      case DotShorthand():
        throw QudsRuntimeException(
          'Expression `${expr.runtimeType}` cannot be evaluated standalone.',
          expr.span,
        );
    }
  }

  Future<void> _collectElement(
    Expression element,
    List<Object?> out,
    QudsEnvironment env, {
    bool isNullAware = false,
  }) async {
    if (element is SpreadElement) {
      final seq = await _evalExpr(element.operand, env);
      if (seq == null) {
        if (element.nullAware) return;
        throw QudsRuntimeException('Cannot spread `null`.', element.span);
      }
      if (seq is Iterable) {
        out.addAll(seq);
        return;
      }
      throw QudsRuntimeException(
          'Spread target must be Iterable, got `${qudsTypeName(seq)}`.',
          element.span);
    }
    if (element is NullAwareElement) {
      final v = await _evalExpr(element.value, env);
      if (v != null) out.add(v);
      return;
    }
    if (element is CollectionIf) {
      final condVal = await _evalExpr(element.condition, env);
      if (element.pattern != null) {
        final child = env.child();
        final ok = await _matchPattern(
                element.pattern!, condVal, child, element.span) &&
            (element.guard == null ||
                _expectBool(await _evalExpr(element.guard!, child),
                    element.guard!.span));
        if (ok) {
          for (final e in element.thenElements) {
            await _collectElement(e, out, child);
          }
        } else {
          for (final e in element.elseElements) {
            await _collectElement(e, out, env);
          }
        }
        return;
      }
      if (_expectBool(condVal, element.condition.span)) {
        for (final e in element.thenElements) {
          await _collectElement(e, out, env);
        }
      } else {
        for (final e in element.elseElements) {
          await _collectElement(e, out, env);
        }
      }
      return;
    }
    if (element is CollectionFor) {
      final seq = await _evalExpr(element.iterable, env);
      if (seq is! Iterable) {
        throw QudsRuntimeException(
            'Expected Iterable in collection-for.', element.iterable.span);
      }
      var i = 0;
      for (final item in seq) {
        await _tick(element.span);
        final child = env.child();
        if (element.index != null) {
          child.define(element.index!, i);
        }
        child.define(element.name, item);
        if (element.filter != null &&
            !_expectBool(await _evalExpr(element.filter!, child),
                element.filter!.span)) {
          i++;
          continue;
        }
        for (final b in element.body) {
          await _collectElement(b, out, child);
        }
        i++;
      }
      return;
    }
    final v = await _evalExpr(element, env);
    if (isNullAware && v == null) return;
    out.add(v);
  }

  // -------------------------------------------------------------------------
  // Operators
  // -------------------------------------------------------------------------

  List<String> _operatorReceiverKeys(Object? value) {
    if (value is QudsInstance) {
      final keys = <String>[];
      QudsClass? cursor = value.qudsClass;
      while (cursor != null) {
        keys.add(cursor.name);
        for (final m in cursor.mixins.reversed) {
          keys.add(m.name);
        }
        cursor = cursor.superclass;
      }
      keys.add('Object');
      return keys;
    }
    if (value is String) return const ['String', 'Object'];
    if (value is int) return const ['int', 'num', 'Object'];
    if (value is double) return const ['double', 'num', 'Object'];
    if (value is bool) return const ['bool', 'Object'];
    if (value is List) return const ['List', 'Iterable', 'Object'];
    if (value is Map) return const ['Map', 'Object'];
    if (value is Set) return const ['Set', 'Iterable', 'Object'];
    if (value is BigInt) return const ['BigInt', 'Object'];
    if (value is Duration) return const ['Duration', 'Object'];
    if (value is math.Point) return const ['Point', 'Object'];
    return const ['Object'];
  }

  int _operatorArgSpecificity(Object? arg, String rawType) {
    final trimmed = rawType.trim();
    if (trimmed.isEmpty || trimmed == 'dynamic') return 10;
    if (!_matchesExtensionTarget(arg, trimmed)) return -1;
    final nonNull = trimmed.endsWith('?')
        ? trimmed.substring(0, trimmed.length - 1).trim()
        : trimmed;
    final base = _baseTypeName(nonNull);
    if (base == 'Object' || base == 'dynamic') return 10;
    if (arg == null) return 20;
    if (arg is QudsInstance) {
      return arg.qudsClass.name == base ? 100 : 60;
    }
    if ((arg is int && base == 'int') ||
        (arg is double && base == 'double') ||
        (arg is String && base == 'String') ||
        (arg is bool && base == 'bool') ||
        (arg is List && base == 'List') ||
        (arg is Map && base == 'Map') ||
        (arg is Set && base == 'Set') ||
        (arg is BigInt && base == 'BigInt') ||
        (arg is Duration && base == 'Duration') ||
        (arg is math.Point && base == 'Point')) {
      return nonNull.contains('<') ? 110 : 100;
    }
    return 50;
  }

  bool _matchesExtensionTarget(Object? value, String targetType) {
    final trimmed = targetType.trim();
    final nonNull = trimmed.endsWith('?')
        ? trimmed.substring(0, trimmed.length - 1).trim()
        : trimmed;
    final bare =
        nonNull.startsWith('readonly ') ? nonNull.substring(9).trim() : nonNull;
    if (bare.startsWith('List<') && bare.endsWith('>')) {
      if (value is! List) return false;
      final elemType = bare.substring(5, bare.length - 1).trim();
      if (value.isEmpty) return true;
      return value.every((item) => _matchesExtensionTarget(item, elemType));
    }
    if (bare.startsWith('Point<') && bare.endsWith('>')) {
      if (value is! math.Point) return false;
      final coordType = bare.substring(6, bare.length - 1).trim();
      return _matchesType(value.x, coordType) &&
          _matchesType(value.y, coordType);
    }
    if (bare == 'Point') {
      return value is math.Point || _matchesType(value, bare);
    }
    return _matchesType(value, bare);
  }

  (QudsUserFunction, bool)? _resolveOperatorOverload(
    Object? receiver,
    String op,
    List<Object?> args,
  ) {
    QudsUserFunction? bestFn;
    var bestIsExt = false;
    var bestScore = -1;

    void consider(QudsUserFunction fn, bool isExt, int receiverBonus) {
      if (fn.parameters.length != args.length) return;
      var score = receiverBonus;
      for (var i = 0; i < args.length; i++) {
        final s = _operatorArgSpecificity(args[i], fn.parameters[i].type);
        if (s < 0) return;
        score += s;
      }
      if (score > bestScore) {
        bestScore = score;
        bestFn = fn;
        bestIsExt = isExt;
      }
    }

    if (receiver is QudsInstance) {
      for (final fn in receiver.qudsClass.lookupOperators(op)) {
        consider(fn, false, 1000);
      }
    }

    if (_extensionOperators.isNotEmpty) {
      final keys = _operatorReceiverKeys(receiver);
      for (var i = 0; i < keys.length; i++) {
        final ops = _extensionOperators[keys[i]]?[op];
        if (ops == null) continue;
        final bonus = (keys.length - i) * 10;
        for (final (targetType, fn) in ops) {
          if (!_matchesExtensionTarget(receiver, targetType)) continue;
          final genericBonus = targetType.contains('<') ? 5 : 0;
          consider(fn, true, bonus + genericBonus);
        }
      }
    }

    if (bestFn == null) return null;
    return (bestFn!, bestIsExt);
  }

  FutureOr<Object?> _applyUnaryList(
      String op, List<Object?> items, SourceSpan span) {
    final result = <Object?>[];
    for (var i = 0; i < items.length; i++) {
      final mapped = _applyUnaryOp(op, items[i], span);
      if (mapped is Future<Object?>) {
        return _finishUnaryListAsync(op, items, i, result, mapped, span);
      }
      result.add(mapped);
    }
    return result;
  }

  Future<List<Object?>> _finishUnaryListAsync(
    String op,
    List<Object?> items,
    int index,
    List<Object?> result,
    Future<Object?> pending,
    SourceSpan span,
  ) async {
    result.add(await pending);
    for (var i = index + 1; i < items.length; i++) {
      result.add(await _applyUnaryOp(op, items[i], span));
    }
    return result;
  }

  FutureOr<Object?> _applyUnaryOp(String op, Object? v, SourceSpan span) {
    if ((op == '-' || op == '+' || op == '~') &&
        (v is QudsInstance || _extensionOperators.isNotEmpty)) {
      final overload = _resolveOperatorOverload(v, op, const []);
      if (overload != null) {
        final (fn, isExt) = overload;
        if (isExt) {
          return _invokeExtension(fn, v, const [], const {}, span);
        }
        return _invokeUserFunctionFast(
            fn.bind(v as QudsInstance), const [], const {}, span);
      }
    }
    if (v is List && (op == '-' || op == '+' || op == '~')) {
      return _applyUnaryList(op, v, span);
    }
    switch (op) {
      case '-':
        if (v is num) return -v;
        if (v is BigInt) return -v;
        if (v is Duration) return -v;
        if (v is math.Point) {
          final x = -v.x;
          final y = -v.y;
          if (x is int && y is int) return math.Point<int>(x, y);
          if (x is double && y is double) return math.Point<double>(x, y);
          return math.Point<num>(x, y);
        }
        throw QudsRuntimeException('Cannot negate `${qudsTypeName(v)}`.', span);
      case '+':
        if (v is num || v is BigInt || v is Duration || v is math.Point) {
          return v;
        }
        throw QudsRuntimeException('Unary `+` requires a number.', span);
      case 'not':
        return !_expectBool(v, span);
      case '!':
        if (v == null) {
          throw QudsRuntimeException(
              'Null assertion (`!`) failed on null value.', span,
              code: 'R301');
        }
        return v;
      case '~':
        if (v is int) return ~v;
        if (v is BigInt) return ~v;
        throw QudsRuntimeException('Bitwise `~` requires an int.', span);
      default:
        throw QudsRuntimeException('Unknown unary operator `$op`.', span);
    }
  }

  Future<Object?> _evalBinary(
    Expression leftExpr,
    String op,
    Expression rightExpr,
    QudsEnvironment env,
    SourceSpan span,
  ) async {
    // Short-circuiting operators evaluate left-to-right!
    if (op == 'and' || op == '&&') {
      final l = _expectBool(await _evalExpr(leftExpr, env), leftExpr.span);
      if (!l) return false;
      return _expectBool(await _evalExpr(rightExpr, env), rightExpr.span);
    }
    if (op == 'or' || op == '||') {
      final l = _expectBool(await _evalExpr(leftExpr, env), leftExpr.span);
      if (l) return true;
      return _expectBool(await _evalExpr(rightExpr, env), rightExpr.span);
    }
    if (op == '??') {
      final l = await _evalExpr(leftExpr, env);
      return l ?? await _evalExpr(rightExpr, env);
    }

    final left = await _evalExpr(leftExpr, env);
    final right = await _evalExpr(rightExpr, env);
    return _applyBinaryOp(left, op, right, span);
  }

  bool get hasExtensionOperators => _extensionOperators.isNotEmpty;

  /// Formats [value] for string output, invoking user-defined `toString()` on
  /// [QudsInstance] when present to match compiled Dart VM behavior.
  FutureOr<String> formatValueForOutput(Object? value, SourceSpan span) {
    if (value is String) return value;
    if (value is QudsInstance) {
      final toStr = value.qudsClass.lookupMethod('toString');
      if (toStr != null && toStr.parameters.isEmpty) {
        final res = _invokeUserFunctionFast(
            toStr.bind(value), const [], const {}, span);
        if (res is Future<Object?>) {
          return res.then(qudsFormatValue);
        }
        return qudsFormatValue(res);
      }
    }
    return qudsFormatValue(value);
  }

  Future<Object?> _applyBinaryOp(
    Object? left,
    String op,
    Object? right,
    SourceSpan span,
  ) async {
    // Operator overloading on user-defined classes, augments, and extensions
    if (left is QudsInstance || _extensionOperators.isNotEmpty) {
      final overload = _resolveOperatorOverload(left, op, [right]);
      if (overload != null) {
        final (fn, isExt) = overload;
        if (isExt) {
          return _invokeExtension(fn, left, [right], const {}, span);
        }
        return invokeCallable(
            fn.bind(left as QudsInstance), [right], const {}, span);
      }
    }

    switch (op) {
      case '==':
        return qudsEquals(left, right);
      case '!=':
        return !qudsEquals(left, right);
      case '+':
        if (left is num && right is num) return left + right;
        if (left is BigInt && right is BigInt) return left + right;
        if (left is String) {
          final rhs =
              right is String ? right : formatValueForOutput(right, span);
          final out = left + (rhs is Future<String> ? await rhs : rhs);
          _checkStringLength(out.length, span);
          return out;
        }
        if (left is List && right is List) {
          final out = [...left, ...right];
          _checkCollectionSize(out.length, span);
          return out;
        }
        if (left is Duration && right is Duration) return left + right;
        throw QudsRuntimeException(
            'Operator `+` not defined for `${qudsTypeName(left)}` and `${qudsTypeName(right)}`.',
            span);
      case '-':
        if (left is num && right is num) return left - right;
        if (left is BigInt && right is BigInt) return left - right;
        if (left is Duration && right is Duration) return left - right;
        throw QudsRuntimeException(
            'Operator `-` not defined for `${qudsTypeName(left)}` and `${qudsTypeName(right)}`.',
            span);
      case '*':
        if (left is num && right is num) return left * right;
        if (left is BigInt && right is BigInt) return left * right;
        if (left is String && right is int) {
          _checkStringLength(left.length * math.max(0, right), span);
          return left * right;
        }
        if (left is Duration && right is num) return left * right;
        throw QudsRuntimeException(
            'Operator `*` not defined for `${qudsTypeName(left)}` and `${qudsTypeName(right)}`.',
            span);
      case '/':
        if (left is num && right is num) return left / right;
        if (left is BigInt && right is BigInt) return left / right;
        throw QudsRuntimeException(
            'Operator `/` not defined for `${qudsTypeName(left)}` and `${qudsTypeName(right)}`.',
            span);
      case '~/':
        if (left is num && right is num) {
          if (right == 0) {
            throw QudsRuntimeException('Integer division by zero.', span);
          }
          return left ~/ right;
        }
        if (left is BigInt && right is BigInt) return left ~/ right;
        throw QudsRuntimeException(
            'Operator `~/` requires numeric operands.', span);
      case '%':
        if (left is num && right is num) {
          if (right == 0) {
            throw QudsRuntimeException('Remainder by zero.', span);
          }
          return left % right;
        }
        if (left is BigInt && right is BigInt) return left % right;
        throw QudsRuntimeException(
            'Operator `%` requires numeric operands.', span);
      case '**':
        if (left is num && right is num) return math.pow(left, right);
        throw QudsRuntimeException(
            'Operator `**` requires numeric operands.', span);
      case '<':
        return _compare(left, right, span) < 0;
      case '<=':
        return _compare(left, right, span) <= 0;
      case '>':
        return _compare(left, right, span) > 0;
      case '>=':
        return _compare(left, right, span) >= 0;
      case '&':
        if (left is int && right is int) return left & right;
        if (left is BigInt && right is BigInt) return left & right;
        throw QudsRuntimeException('Bitwise `&` requires integers.', span);
      case '|':
        if (left is int && right is int) return left | right;
        if (left is BigInt && right is BigInt) return left | right;
        throw QudsRuntimeException('Bitwise `|` requires integers.', span);
      case '^':
        if (left is int && right is int) return left ^ right;
        if (left is BigInt && right is BigInt) return left ^ right;
        throw QudsRuntimeException('Bitwise `^` requires integers.', span);
      case '<<':
        if (left is int && right is int) return left << right;
        if (left is BigInt && right is int) return left << right;
        throw QudsRuntimeException('Bitwise `<<` requires integers.', span);
      case '>>':
        if (left is int && right is int) return left >> right;
        if (left is BigInt && right is int) return left >> right;
        throw QudsRuntimeException('Bitwise `>>` requires integers.', span);
      case '>>>':
        if (left is int && right is int) return left >>> right;
        throw QudsRuntimeException('Bitwise `>>>` requires integers.', span);
      case 'in':
        return _contains(right, left, span);
      case 'not in':
        return !_contains(right, left, span);
      default:
        throw QudsRuntimeException('Unknown binary operator `$op`.', span);
    }
  }

  int _compare(Object? a, Object? b, SourceSpan span) {
    if (a is num && b is num) return a.compareTo(b);
    if (a is BigInt && b is BigInt) return a.compareTo(b);
    if (a is String && b is String) return a.compareTo(b);
    if (a is Duration && b is Duration) return a.compareTo(b);
    if (a is DateTime && b is DateTime) return a.compareTo(b);
    throw QudsRuntimeException(
        'Cannot compare `${qudsTypeName(a)}` and `${qudsTypeName(b)}`.', span);
  }

  bool _contains(Object? container, Object? item, SourceSpan span) {
    if (container is QudsRange) return container.containsValue(item);
    if (container is List) return container.any((e) => qudsEquals(e, item));
    if (container is Set) return container.any((e) => qudsEquals(e, item));
    if (container is Map) return container.containsKey(item);
    if (container is String && item is String) return container.contains(item);
    throw QudsRuntimeException(
        'Operator `in` is not supported on `${qudsTypeName(container)}`.',
        span);
  }

  // -------------------------------------------------------------------------
  // Calls, Functions, Constructors, and Methods
  // -------------------------------------------------------------------------

  Future<Object?> _evalCall(
    Expression calleeExpr,
    List<Argument> arguments,
    QudsEnvironment env,
    SourceSpan span,
  ) async {
    // Handle null-aware method calls `obj?.method(...)`.
    if (calleeExpr is MemberAccess && calleeExpr.nullAware) {
      final recv = await _evalExpr(calleeExpr.object, env);
      if (recv == null) return null;
      final member =
          await _evalMemberRead(recv, calleeExpr.name, false, calleeExpr.span);
      final (pos, named) = await _evalArguments(arguments, env);
      return invokeCallable(member, pos, named, span);
    }

    // Handle named constructors `ClassName.ctorName(...)`.
    if (calleeExpr is MemberAccess) {
      final recv = await _evalExpr(calleeExpr.object, env);
      if (recv is QudsClass) {
        final namedCtor = recv.constructors[calleeExpr.name];
        if (namedCtor != null) {
          final (pos, named) = await _evalArguments(arguments, env);
          return _instantiateClass(recv, pos, named, span, ctor: namedCtor);
        }
        final staticMethod = recv.staticMethods[calleeExpr.name];
        if (staticMethod != null) {
          final (pos, named) = await _evalArguments(arguments, env);
          return invokeCallable(staticMethod, pos, named, span);
        }
      }
      final member =
          await _evalMemberRead(recv, calleeExpr.name, false, calleeExpr.span);
      final (pos, named) = await _evalArguments(arguments, env);
      return invokeCallable(member, pos, named, span);
    }

    final callee = await _evalExpr(calleeExpr, env);
    final (pos, named) = await _evalArguments(arguments, env);
    return invokeCallable(callee, pos, named, span);
  }

  Future<(List<Object?>, Map<String, Object?>)> _evalArguments(
    List<Argument> arguments,
    QudsEnvironment env,
  ) async {
    final pos = <Object?>[];
    final named = <String, Object?>{};
    for (final arg in arguments) {
      if (arg.name != null) {
        named[arg.name!] = await _evalExpr(arg.value, env);
      } else if (arg.value is SpreadElement) {
        final spread = arg.value as SpreadElement;
        final seq = await _evalExpr(spread.operand, env);
        if (seq is Iterable) {
          pos.addAll(seq);
        } else if (seq == null && spread.nullAware) {
          continue;
        } else {
          throw QudsRuntimeException(
              'Spread argument must be Iterable.', spread.span);
        }
      } else {
        pos.add(await _evalExpr(arg.value, env));
      }
    }
    return (pos, named);
  }

  /// Invokes any Quds callable (user function, overload set, native function,
  /// or class constructor).
  Future<Object?> invokeCallable(
    Object? callee,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span,
  ) async {
    if (_callDepth >= maxCallDepth) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.callDepth,
        'Maximum call depth ($maxCallDepth) exceeded.',
        span,
        stackFrames: stackFrames,
      );
    }

    if (callee is QudsNativeFunction) {
      if (onBeforeCall != null) {
        await onBeforeCall!(
          callee.name,
          positional,
          named,
          span,
          callee.requiredCapability,
        );
      } else if (callee.requiredCapability != null) {
        checkCapabilitySync?.call(
          callee.name,
          callee.requiredCapability!,
          span,
        );
      }
      final ctx = QudsCallContext(
        span: span,
        functionName: callee.name,
        emitOutput: (out) => onOutput(out, span),
        emitPrint: (line) => onPrint(line, span),
        invokeCallable: invokeCallable,
        interactiveInputs: interactiveInputs,
      );
      _callDepth++;
      try {
        final result = callee.callback(positional, named, ctx);
        return result is Future ? await result : result;
      } on QudsRuntimeException {
        rethrow;
      } on QudsThrownValue {
        rethrow;
      } catch (err) {
        throw QudsThrownValue(err, span, stackFrames);
      } finally {
        _callDepth--;
      }
    }

    if (callee is QudsOverloadSet) {
      final selected = _selectOverload(callee, positional, named, span);
      if (selected.isAsync) {
        return QudsFuture(
            _invokeUserFunction(selected, positional, named, span));
      }
      return _invokeUserFunction(selected, positional, named, span);
    }

    if (callee is QudsUserFunction) {
      if (callee.isAsync) {
        return QudsFuture(_invokeUserFunction(callee, positional, named, span));
      }
      return _invokeUserFunction(callee, positional, named, span);
    }

    if (callee is QudsClass) {
      return _instantiateClass(callee, positional, named, span);
    }

    throw QudsRuntimeException(
      'Value of type `${qudsTypeName(callee)}` is not callable.',
      span,
      code: 'E500',
      stackFrames: stackFrames,
    );
  }

  QudsUserFunction _selectOverload(
    QudsOverloadSet set,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span,
  ) {
    final candidates = <QudsUserFunction>[];
    for (final fn in set.overloads) {
      if (_canBindParameters(fn.parameters, positional, named)) {
        candidates.add(fn);
      }
    }
    if (candidates.isEmpty) {
      throw QudsRuntimeException(
        'No overload of `${set.name}` matches ${positional.length} positional and ${named.length} named arguments.',
        span,
        code: 'E500',
      );
    }
    if (candidates.length == 1) return candidates.first;
    // Pick best type match
    QudsUserFunction? best;
    var bestScore = -1;
    for (final fn in candidates) {
      var score = 0;
      for (var i = 0; i < fn.parameters.length && i < positional.length; i++) {
        final p = fn.parameters[i];
        if (p.type == '<infer>' || p.type == 'Object?' || p.type == 'dynamic') {
          score += 1;
        } else if (_matchesType(positional[i], p.type)) {
          score += 10;
        } else {
          score = -100;
          break;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = fn;
      }
    }
    return best ?? candidates.first;
  }

  bool _canBindParameters(
    List<Parameter> params,
    List<Object?> positional,
    Map<String, Object?> named,
  ) {
    final paramNames = {for (final p in params) p.name};
    for (final key in named.keys) {
      if (!paramNames.contains(key)) return false;
    }
    final hasVariadic = params.any((p) => p.variadic);
    if (!hasVariadic && positional.length > params.length) return false;
    for (var i = 0; i < params.length; i++) {
      final p = params[i];
      if (p.variadic) continue;
      final supplied = i < positional.length || named.containsKey(p.name);
      if (!supplied &&
          p.defaultValue == null &&
          !p.type.startsWith('Optional')) {
        return false;
      }
    }
    return true;
  }

  Future<Object?> _invokeUserFunction(
    QudsUserFunction fn,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span,
  ) async {
    if (onBeforeCall != null) {
      await onBeforeCall!(fn.name, positional, named, span, null);
    }

    final callEnv = fn.closure.child(isFunctionBoundary: true);
    if (fn.receiver != null) {
      callEnv.define('this', fn.receiver);
      if (fn.receiver!.qudsClass.superclass != null) {
        callEnv.define(
          'super',
          QudsSuperProxy(fn.receiver!, fn.receiver!.qudsClass.superclass!),
        );
      }
      _exposeInstanceFields(fn.receiver!, callEnv);
    }

    await _bindParameters(fn.parameters, positional, named, callEnv, span);

    final frameName = fn.definingClass != null
        ? '${fn.definingClass!.name}.${fn.name}'
        : fn.name;
    final frame = QudsStackFrame(
      functionName: frameName,
      span: span,
      locals: trackFrameLocals ? callEnv.snapshotLocals() : const {},
    );

    final callNode = profiler?.enterCall(frameName, positional, named, span);
    Object? returnVal;
    final isGen = fn.generator.isNotEmpty;
    final List<Object?>? genBuffer = isGen ? <Object?>[] : null;
    if (genBuffer != null) {
      _yieldStack.add(genBuffer);
    }
    _callDepth++;
    _callStack.add(frame);
    try {
      if (fn.expressionBody != null) {
        returnVal = await _evalExpr(fn.expressionBody!, callEnv);
        return isGen ? genBuffer : returnVal;
      }
      if (fn.body != null) {
        await executeBlock(fn.body!, callEnv, hoistDeclarations: true);
      }
      if (isGen) {
        returnVal = genBuffer;
        return genBuffer;
      }
      return null;
    } on ReturnSignal catch (ret) {
      returnVal = isGen ? genBuffer : ret.value;
      return returnVal;
    } on PropagateErrorSignal catch (prop) {
      returnVal = prop.errorResult;
      return returnVal;
    } finally {
      if (genBuffer != null) {
        _yieldStack.removeLast();
      }
      profiler?.exitCall(callNode, returnVal);
      _callStack.removeLast();
      _callDepth--;
      // Sync back any field assignments made directly to bare field names.
      if (fn.receiver != null) {
        _syncInstanceFieldsBack(fn.receiver!, callEnv);
      }
    }
  }

  Future<void> _bindParameters(
    List<Parameter> params,
    List<Object?> positional,
    Map<String, Object?> named,
    QudsEnvironment callEnv,
    SourceSpan span,
  ) async {
    var posIdx = 0;
    final usedNamed = <String>{};

    for (final param in params) {
      if (param.variadic) {
        final rest = posIdx < positional.length
            ? positional.sublist(posIdx)
            : <Object?>[];
        posIdx = positional.length;
        callEnv.define(param.name, rest, mutable: param.mutable);
        continue;
      }

      if (named.containsKey(param.name)) {
        usedNamed.add(param.name);
        final val = named[param.name];
        callEnv.define(
          param.name,
          param.type.startsWith('Optional') &&
                  val is! QudsOptional &&
                  val is! QudsMissing
              ? QudsOptional.present(val)
              : val,
          mutable: param.mutable,
          declaredType: param.type,
        );
      } else if (!param.isNamed && posIdx < positional.length) {
        final val = positional[posIdx++];
        callEnv.define(
          param.name,
          param.type.startsWith('Optional') &&
                  val is! QudsOptional &&
                  val is! QudsMissing
              ? QudsOptional.present(val)
              : val,
          mutable: param.mutable,
          declaredType: param.type,
        );
      } else if (param.kind == ParameterKind.optionalNamed &&
          posIdx < positional.length) {
        // QUDS-081 unified call syntax: optional-named parameters can also be passed positionally.
        final val = positional[posIdx++];
        callEnv.define(param.name, val,
            mutable: param.mutable, declaredType: param.type);
      } else if (param.defaultValue != null) {
        // QUDS-086: computed default arguments evaluated in callEnv so they can refer to earlier parameters!
        final defVal = await _evalExpr(param.defaultValue!, callEnv);
        callEnv.define(param.name, defVal,
            mutable: param.mutable, declaredType: param.type);
      } else if (param.type.startsWith('Optional')) {
        callEnv.define(param.name, const QudsOptional.missing(),
            mutable: param.mutable, declaredType: param.type);
      } else {
        throw QudsRuntimeException(
          'Missing required argument `${param.name}`.',
          span,
          code: 'E500',
        );
      }
    }

    if (posIdx < positional.length) {
      throw QudsRuntimeException(
        'Too many positional arguments: expected at most $posIdx, got ${positional.length}.',
        span,
        code: 'E500',
      );
    }
    for (final key in named.keys) {
      if (!usedNamed.contains(key)) {
        throw QudsRuntimeException(
          'Unknown named argument `$key`.',
          span,
          code: 'E500',
        );
      }
    }
  }

  Future<QudsInstance> _instantiateClass(
    QudsClass klass,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span, {
    ConstructorDeclaration? ctor,
  }) async {
    final effectiveCtor = ctor ?? klass.constructors[''];

    // Factory constructor runs its body and returns an instance directly.
    if (effectiveCtor != null && effectiveCtor.factory) {
      final ctorEnv = klass.definingEnv.child(isFunctionBoundary: true);
      await _bindParameters(
          effectiveCtor.parameters, positional, named, ctorEnv, span);
      Object? result;
      if (effectiveCtor.expressionBody != null) {
        result = await _evalExpr(effectiveCtor.expressionBody!, ctorEnv);
      } else if (effectiveCtor.body != null) {
        try {
          await executeBlock(effectiveCtor.body!, ctorEnv,
              hoistDeclarations: true);
        } on ReturnSignal catch (ret) {
          result = ret.value;
        }
      }
      if (result is QudsInstance) return result;
      throw QudsRuntimeException(
          'Factory constructor `${klass.name}` must return an instance.', span);
    }

    final fields = <String, Object?>{};
    final allFields = _collectAllInstanceFields(klass);

    // Initialize default field initializers and event channels first.
    for (final f in allFields) {
      if (f.isEvent) {
        fields[f.name] = QudsEventChannel(f.name);
      } else if (f.initializer != null) {
        fields[f.name] = await _evalExpr(f.initializer!, klass.definingEnv);
      } else if (!f.requiredField && f.lazyBody == null) {
        fields[f.name] = null;
      }
    }

    final instance = QudsInstance(klass, fields);

    if (effectiveCtor != null) {
      final ctorEnv = klass.definingEnv.child(isFunctionBoundary: true)
        ..define('this', instance);
      await _bindParameters(
          effectiveCtor.parameters, positional, named, ctorEnv, span);
      for (final p in effectiveCtor.parameters) {
        if (p.initializing == 'this' || p.initializing == 'super') {
          instance.fields[p.name] = ctorEnv.get(p.name, p.span);
        }
      }
      _exposeInstanceFields(instance, ctorEnv, allowImmutableWrite: true);
      if (effectiveCtor.body != null) {
        _initializingInstances.add(instance);
        try {
          await executeBlock(effectiveCtor.body!, ctorEnv,
              hoistDeclarations: true);
        } finally {
          _initializingInstances.remove(instance);
        }
      }
      _syncInstanceFieldsBack(instance, ctorEnv);
    } else {
      // Default field-based constructor (positional or named).
      final ctorFields = allFields
          .where((f) =>
              !f.isStatic && !f.isEvent && f.lazyBody == null && !f.isConst)
          .toList();
      var posIdx = 0;
      for (final f in ctorFields) {
        if (named.containsKey(f.name)) {
          instance.fields[f.name] = named[f.name];
        } else if (posIdx < positional.length &&
            (f.requiredField || f.initializer == null || named.isEmpty)) {
          instance.fields[f.name] = positional[posIdx++];
        } else if (f.requiredField && !instance.fields.containsKey(f.name)) {
          throw QudsRuntimeException(
            'Missing required field `${f.name}` for `${klass.name}`.',
            span,
            code: 'E500',
          );
        }
      }
    }

    // Check class `require` invariants.
    if (klass.declaration.requirements.isNotEmpty) {
      final reqEnv = klass.definingEnv.child()..define('this', instance);
      _exposeInstanceFields(instance, reqEnv);
      for (final req in klass.declaration.requirements) {
        if (!_expectBool(await _evalExpr(req, reqEnv), req.span)) {
          throw QudsThrownValue(
            ArgumentError('Invariant failed for `${klass.name}`.'),
            req.span,
            stackFrames,
          );
        }
      }
    }

    return instance;
  }

  List<FieldDeclaration> _collectAllInstanceFields(QudsClass klass) {
    final result = <FieldDeclaration>[];
    if (klass.superclass != null) {
      result.addAll(_collectAllInstanceFields(klass.superclass!));
    }
    for (final m in klass.mixins) {
      result.addAll(_collectAllInstanceFields(m));
    }
    for (final f in klass.declaration.fields) {
      if (!f.isStatic) result.add(f);
    }
    return result;
  }

  FieldDeclaration? _findFieldDecl(QudsClass klass, String name) {
    for (final f in klass.declaration.fields) {
      if (!f.isStatic && f.name == name) return f;
    }
    for (final m in klass.mixins.reversed) {
      final hit = _findFieldDecl(m, name);
      if (hit != null) return hit;
    }
    return klass.superclass == null
        ? null
        : _findFieldDecl(klass.superclass!, name);
  }

  void _exposeInstanceFields(
    QudsInstance instance,
    QudsEnvironment env, {
    bool allowImmutableWrite = false,
  }) {
    for (final entry in instance.fields.entries) {
      if (!env.containsLocal(entry.key)) {
        final decl = _findFieldDecl(instance.qudsClass, entry.key);
        env.define(
          entry.key,
          entry.value,
          mutable: allowImmutableWrite || (decl?.mutable ?? true),
        );
      }
    }
    // Also expose instance methods (including mixins & superclasses) so bare `method()` calls work!
    QudsClass? cursor = instance.qudsClass;
    while (cursor != null) {
      for (final m in cursor.methods.entries) {
        if (!env.containsLocal(m.key)) {
          env.define(m.key, m.value.bind(instance));
        }
      }
      for (final mix in cursor.mixins.reversed) {
        for (final m in mix.methods.entries) {
          if (!env.containsLocal(m.key)) {
            env.define(m.key, m.value.bind(instance));
          }
        }
      }
      cursor = cursor.superclass;
    }
  }

  void _syncInstanceFieldsBack(QudsInstance instance, QudsEnvironment env) {
    for (final key in instance.fields.keys.toList()) {
      final slot = env.localSlots[key];
      if (slot != null) {
        instance.fields[key] = slot.value;
      }
    }
  }

  // -------------------------------------------------------------------------
  // Index, Slice & Member Access
  // -------------------------------------------------------------------------

  Future<Object?> _evalIndexRead(
    Object? container,
    Object? index,
    SourceSpan span,
  ) async {
    if (_extensionOperators.isNotEmpty) {
      final overload = _resolveOperatorOverload(container, '[]', [index]);
      if (overload != null) {
        final (fn, isExt) = overload;
        if (isExt) {
          return _invokeExtension(fn, container, [index], const {}, span);
        }
        return invokeCallable(
            fn.bind(container as QudsInstance), [index], const {}, span);
      }
    }
    if (container is List) {
      final idx = _expectInt(index, span);
      final resolved = idx < 0 ? container.length + idx : idx;
      if (resolved < 0 || resolved >= container.length) {
        throw QudsRuntimeException(
            'List index $idx out of range (length ${container.length}).', span);
      }
      return container[resolved];
    }
    if (container is Map) {
      return container[index];
    }
    if (container is String) {
      final idx = _expectInt(index, span);
      final resolved = idx < 0 ? container.length + idx : idx;
      if (resolved < 0 || resolved >= container.length) {
        throw QudsRuntimeException(
            'String index $idx out of range (length ${container.length}).',
            span);
      }
      return container[resolved];
    }
    if (container is QudsInstance) {
      final overload = _resolveOperatorOverload(container, '[]', [index]);
      if (overload != null) {
        final (fn, isExt) = overload;
        if (isExt) {
          return _invokeExtension(fn, container, [index], const {}, span);
        }
        return invokeCallable(fn.bind(container), [index], const {}, span);
      }
    }
    throw QudsRuntimeException(
        'Cannot index value of type `${qudsTypeName(container)}`.', span);
  }

  Object? _evalSlice(
    Object? container,
    int? start,
    int? end,
    bool inclusive,
    SourceSpan span,
  ) {
    int clamp(int val, int len) {
      var v = val < 0 ? len + val : val;
      if (v < 0) v = 0;
      if (v > len) v = len;
      return v;
    }

    if (container is List) {
      final len = container.length;
      final s = start == null ? 0 : clamp(start, len);
      final rawEnd =
          end == null ? len : (end < 0 ? len + end : end) + (inclusive ? 1 : 0);
      final e = rawEnd.clamp(s, len);
      return container.sublist(s, e);
    }
    if (container is String) {
      final len = container.length;
      final s = start == null ? 0 : clamp(start, len);
      final rawEnd =
          end == null ? len : (end < 0 ? len + end : end) + (inclusive ? 1 : 0);
      final e = rawEnd.clamp(s, len);
      return container.substring(s, e);
    }
    throw QudsRuntimeException(
        'Cannot slice value of type `${qudsTypeName(container)}`.', span);
  }

  Future<Object?> _evalMemberRead(
    Object? receiver,
    String name,
    bool nullAware,
    SourceSpan span,
  ) async {
    if (receiver == null) {
      if (nullAware) return null;
      throw QudsRuntimeException('Cannot access `.$name` on `null`.', span,
          code: 'R301');
    }

    if (receiver is QudsNamespace) {
      return receiver.getMember(name, span);
    }

    if (receiver is QudsCallableNamespace) {
      return receiver.getMember(name, span);
    }

    if (receiver is QudsLoopContext) {
      return receiver.getMember(name, span);
    }

    if (receiver is QudsRecord) {
      return receiver.getField(name, span);
    }

    if (receiver is QudsSuperProxy) {
      final prop = receiver.superclass.lookupProperty(name);
      if (prop != null) {
        final propEnv = receiver.superclass.definingEnv
            .child(isFunctionBoundary: true)
          ..define('this', receiver.instance);
        _exposeInstanceFields(receiver.instance, propEnv);
        if (prop.getter != null) return _evalExpr(prop.getter!, propEnv);
        if (prop.getterBody != null) {
          try {
            return await executeBlock(prop.getterBody!, propEnv,
                returnLastExpression: true);
          } on ReturnSignal catch (ret) {
            return ret.value;
          }
        }
      }
      final method = receiver.superclass.lookupMethod(name);
      if (method != null) return method.bind(receiver.instance);
      if (receiver.instance.fields.containsKey(name)) {
        return receiver.instance.fields[name];
      }
      throw QudsRuntimeException(
          'Superclass `${receiver.superclass.name}` has no member `$name`.',
          span);
    }

    if (receiver is QudsEventChannel) {
      if (name == 'listen' || name == 'add') {
        return QudsNativeFunction(
          name,
          (pos, named, ctx) {
            if (pos.isNotEmpty && pos[0] is QudsCallable) {
              receiver.listeners.add(pos[0] as QudsCallable);
            }
            return null;
          },
          isSync: true,
        );
      }
      if (name == 'clear') {
        return QudsNativeFunction(
          'clear',
          (pos, named, ctx) {
            receiver.listeners.clear();
            return null;
          },
          isSync: true,
        );
      }
      throw QudsRuntimeException(
          'Event `${receiver.name}` has no member `$name`.', span);
    }

    if (receiver is QudsClass) {
      if (name == 'instance' && receiver.isSingleton) {
        return receiver.singletonInstance ??=
            await _instantiateClass(receiver, const [], const {}, span);
      }
      if (receiver.enumCases.containsKey(name)) return receiver.enumCases[name];
      if (receiver.staticFields.containsKey(name)) {
        return receiver.staticFields[name];
      }
      if (receiver.staticMethods.containsKey(name)) {
        return receiver.staticMethods[name];
      }
      throw QudsRuntimeException(
          'Class `${receiver.name}` has no static member `$name`.', span);
    }

    if (receiver is QudsInstance) {
      if (receiver.fields.containsKey(name)) return receiver.fields[name];

      // Lazy field evaluation on first access (uncomputed lazy fields are absent from `fields`)
      final fieldDecl = _findFieldDecl(receiver.qudsClass, name);
      if (fieldDecl != null && fieldDecl.lazyBody != null) {
        if (!receiver.isLazyComputed(name)) {
          final lazyEnv = receiver.qudsClass.definingEnv
              .child(isFunctionBoundary: true)
            ..define('this', receiver);
          _exposeInstanceFields(receiver, lazyEnv);
          Object? val;
          try {
            val = await executeBlock(fieldDecl.lazyBody!, lazyEnv,
                returnLastExpression: true);
          } on ReturnSignal catch (ret) {
            val = ret.value;
          } on ResultSignal catch (res) {
            val = res.value;
          }
          receiver.fields[name] = val;
          receiver.markLazyComputed(name);
        }
        return receiver.fields[name];
      }

      final prop = receiver.qudsClass.lookupProperty(name);
      if (prop != null) {
        final propEnv = receiver.qudsClass.definingEnv
            .child(isFunctionBoundary: true)
          ..define('this', receiver);
        _exposeInstanceFields(receiver, propEnv);
        if (prop.getter != null) return _evalExpr(prop.getter!, propEnv);
        if (prop.getterBody != null) {
          try {
            return await executeBlock(prop.getterBody!, propEnv,
                returnLastExpression: true);
          } on ReturnSignal catch (ret) {
            return ret.value;
          }
        }
      }

      final method = receiver.qudsClass.lookupMethod(name);
      if (method != null) return method.bind(receiver);

      if (name == 'copyWith' && receiver.qudsClass.isValueClass) {
        return QudsNativeFunction(
          'copyWith',
          (pos, named, ctx) =>
              QudsInstance(receiver.qudsClass, {...receiver.fields, ...named}),
          isSync: true,
        );
      }
    }

    // Check user-defined extensions (`extend Type:` / `augment Type:`).
    final extMethod = _lookupExtension(receiver, name);
    if (extMethod != null) {
      return QudsNativeFunction(
        name,
        (pos, named, ctx) =>
            _invokeExtension(extMethod, receiver, pos, named, span),
      );
    }

    // Core built-in members on standard Dart / Quds values.
    final builtin = _lookupBuiltinMember(receiver, name, span);
    if (builtin != _noMember) return builtin;

    throw QudsRuntimeException(
      'Type `${qudsTypeName(receiver)}` has no member `$name`.',
      span,
    );
  }

  Future<Object?> _invokeExtension(
    QudsUserFunction fn,
    Object? receiver,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span,
  ) async {
    final callEnv = fn.closure.child(isFunctionBoundary: true)
      ..define('this', receiver);
    if (receiver is QudsInstance) {
      _exposeInstanceFields(receiver, callEnv);
    }
    await _bindParameters(fn.parameters, positional, named, callEnv, span);
    try {
      if (fn.expressionBody != null) {
        return await _evalExpr(fn.expressionBody!, callEnv);
      }
      if (fn.body != null) {
        await executeBlock(fn.body!, callEnv, hoistDeclarations: true);
      }
      return null;
    } on ReturnSignal catch (ret) {
      return ret.value;
    } finally {
      if (receiver is QudsInstance) {
        _syncInstanceFieldsBack(receiver, callEnv);
      }
    }
  }

  QudsUserFunction? _lookupExtension(Object receiver, String name) {
    final keys = <String>[];
    if (receiver is QudsInstance) {
      keys.add(receiver.qudsClass.name);
    } else if (receiver is List) {
      keys.addAll(['List', 'Iterable']);
    } else if (receiver is Map) {
      keys.add('Map');
    } else if (receiver is Set) {
      keys.addAll(['Set', 'Iterable']);
    } else if (receiver is String) {
      keys.add('String');
    } else if (receiver is int) {
      keys.addAll(['int', 'num']);
    } else if (receiver is double) {
      keys.addAll(['double', 'num']);
    } else if (receiver is Iterable) {
      keys.add('Iterable');
    }
    for (final k in keys) {
      final hit = _extensions[k]?[name];
      if (hit != null) return hit;
    }
    return null;
  }

  static const _noMember = Object();

  Object? _lookupBuiltinMember(Object receiver, String name, SourceSpan span) {
    if (name == 'toString') {
      return QudsNativeFunction(
          'toString', (p, n, ctx) => qudsFormatValue(receiver));
    }
    if (name == 'hashCode') return receiver.hashCode;
    if (name == 'runtimeType') return qudsTypeName(receiver);

    // Result<T, E>
    if (receiver is QudsResult) {
      return switch (name) {
        'isOk' => receiver.isOk,
        'isError' => receiver.isError,
        'value' => receiver.value,
        'error' => receiver.error,
        'valueOrNull' => receiver.valueOrNull,
        'errorOrNull' => receiver.errorOrNull,
        'unwrap' =>
          QudsNativeFunction('unwrap', (p, n, c) => receiver.unwrap()),
        'unwrapOr' => QudsNativeFunction('unwrapOr',
            (p, n, c) => receiver.unwrapOr(p.isNotEmpty ? p[0] : null)),
        _ => _noMember,
      };
    }

    // Optional<T>
    if (receiver is QudsOptional) {
      return switch (name) {
        'isPresent' => receiver.isPresent,
        'isMissing' => receiver.isMissing,
        'value' => receiver.value,
        'valueOrNull' => receiver.valueOrNull,
        'orElse' => QudsNativeFunction(
            'orElse', (p, n, c) => receiver.orElse(p.isNotEmpty ? p[0] : null)),
        _ => _noMember,
      };
    }

    // String
    if (receiver is String) {
      return switch (name) {
        'length' => receiver.length,
        'isEmpty' => receiver.isEmpty,
        'isNotEmpty' => receiver.isNotEmpty,
        'codeUnits' => receiver.codeUnits.toList(),
        'runes' => receiver.runes.toList(),
        'toLowerCase' => QudsNativeFunction(
            'toLowerCase', (p, n, c) => receiver.toLowerCase()),
        'toUpperCase' => QudsNativeFunction(
            'toUpperCase', (p, n, c) => receiver.toUpperCase()),
        'trim' => QudsNativeFunction('trim', (p, n, c) => receiver.trim()),
        'trimLeft' =>
          QudsNativeFunction('trimLeft', (p, n, c) => receiver.trimLeft()),
        'trimRight' =>
          QudsNativeFunction('trimRight', (p, n, c) => receiver.trimRight()),
        'split' => QudsNativeFunction('split', (p, n, c) {
            final sep = p[0];
            if (sep is core.Pattern) return receiver.split(sep);
            return receiver.split('$sep');
          }),
        'contains' => QudsNativeFunction('contains', (p, n, c) {
            final pat = p[0];
            return receiver.contains(pat is core.Pattern ? pat : '$pat');
          }),
        'startsWith' => QudsNativeFunction('startsWith', (p, n, c) {
            final pat = p[0];
            return receiver.startsWith(pat is core.Pattern ? pat : '$pat');
          }),
        'endsWith' => QudsNativeFunction(
            'endsWith', (p, n, c) => receiver.endsWith('${p[0]}')),
        'indexOf' => QudsNativeFunction('indexOf', (p, n, c) {
            final pat = p[0];
            final start = p.length > 1 ? (p[1] as int) : 0;
            return receiver.indexOf(pat is core.Pattern ? pat : '$pat', start);
          }),
        'lastIndexOf' => QudsNativeFunction('lastIndexOf', (p, n, c) {
            final pat = p[0];
            return receiver.lastIndexOf(pat is core.Pattern ? pat : '$pat');
          }),
        'substring' => QudsNativeFunction('substring', (p, n, c) {
            final s = p[0] as int;
            final e = p.length > 1 ? p[1] as int? : null;
            return receiver.substring(s, e);
          }),
        'replaceAll' => QudsNativeFunction('replaceAll', (p, n, c) {
            final from = p[0];
            return receiver.replaceAll(
                from is core.Pattern ? from : '$from', '${p[1]}');
          }),
        'replaceFirst' => QudsNativeFunction('replaceFirst', (p, n, c) {
            final from = p[0];
            return receiver.replaceFirst(
                from is core.Pattern ? from : '$from', '${p[1]}');
          }),
        'padLeft' => QudsNativeFunction(
            'padLeft',
            (p, n, c) =>
                receiver.padLeft(p[0] as int, p.length > 1 ? '${p[1]}' : ' ')),
        'padRight' => QudsNativeFunction(
            'padRight',
            (p, n, c) =>
                receiver.padRight(p[0] as int, p.length > 1 ? '${p[1]}' : ' ')),
        'codeUnitAt' => QudsNativeFunction(
            'codeUnitAt', (p, n, c) => receiver.codeUnitAt(p[0] as int)),
        'compareTo' => QudsNativeFunction(
            'compareTo', (p, n, c) => receiver.compareTo('${p[0]}')),
        _ => _noMember,
      };
    }

    // num / int / double
    if (receiver is num) {
      return switch (name) {
        'isNaN' => receiver.isNaN,
        'isInfinite' => receiver.isInfinite,
        'isFinite' => receiver.isFinite,
        'isNegative' => receiver.isNegative,
        'sign' => receiver.sign,
        'isEven' => receiver is int ? receiver.isEven : _noMember,
        'isOdd' => receiver is int ? receiver.isOdd : _noMember,
        'bitLength' => receiver is int ? receiver.bitLength : _noMember,
        'abs' => QudsNativeFunction('abs', (p, n, c) => receiver.abs()),
        'floor' => QudsNativeFunction('floor', (p, n, c) => receiver.floor()),
        'floorToDouble' => QudsNativeFunction(
            'floorToDouble', (p, n, c) => receiver.floorToDouble()),
        'ceil' => QudsNativeFunction('ceil', (p, n, c) => receiver.ceil()),
        'ceilToDouble' => QudsNativeFunction(
            'ceilToDouble', (p, n, c) => receiver.ceilToDouble()),
        'round' => QudsNativeFunction('round', (p, n, c) => receiver.round()),
        'roundToDouble' => QudsNativeFunction(
            'roundToDouble', (p, n, c) => receiver.roundToDouble()),
        'truncate' =>
          QudsNativeFunction('truncate', (p, n, c) => receiver.truncate()),
        'truncateToDouble' => QudsNativeFunction(
            'truncateToDouble', (p, n, c) => receiver.truncateToDouble()),
        'remainder' => QudsNativeFunction(
            'remainder', (p, n, c) => receiver.remainder(p[0] as num)),
        'toDouble' =>
          QudsNativeFunction('toDouble', (p, n, c) => receiver.toDouble()),
        'toInt' => QudsNativeFunction('toInt', (p, n, c) => receiver.toInt()),
        'clamp' => QudsNativeFunction(
            'clamp', (p, n, c) => receiver.clamp(p[0] as num, p[1] as num)),
        'compareTo' => QudsNativeFunction(
            'compareTo', (p, n, c) => receiver.compareTo(p[0] as num)),
        'toStringAsFixed' => QudsNativeFunction('toStringAsFixed',
            (p, n, c) => receiver.toStringAsFixed(p[0] as int)),
        'toStringAsPrecision' => QudsNativeFunction('toStringAsPrecision',
            (p, n, c) => receiver.toStringAsPrecision(p[0] as int)),
        'toRadixString' => receiver is int
            ? QudsNativeFunction('toRadixString',
                (p, n, c) => receiver.toRadixString(p[0] as int))
            : _noMember,
        'gcd' => receiver is int
            ? QudsNativeFunction('gcd', (p, n, c) => receiver.gcd(p[0] as int))
            : _noMember,
        _ => _noMember,
      };
    }

    // BigInt
    if (receiver is BigInt) {
      return switch (name) {
        'isEven' => receiver.isEven,
        'isOdd' => receiver.isOdd,
        'isNegative' => receiver.isNegative,
        'sign' => receiver.sign,
        'bitLength' => receiver.bitLength,
        'abs' => QudsNativeFunction('abs', (p, n, c) => receiver.abs()),
        'toInt' => QudsNativeFunction('toInt', (p, n, c) => receiver.toInt()),
        'toDouble' =>
          QudsNativeFunction('toDouble', (p, n, c) => receiver.toDouble()),
        'pow' =>
          QudsNativeFunction('pow', (p, n, c) => receiver.pow(p[0] as int)),
        'gcd' =>
          QudsNativeFunction('gcd', (p, n, c) => receiver.gcd(p[0] as BigInt)),
        'modPow' => QudsNativeFunction('modPow',
            (p, n, c) => receiver.modPow(p[0] as BigInt, p[1] as BigInt)),
        'modInverse' => QudsNativeFunction(
            'modInverse', (p, n, c) => receiver.modInverse(p[0] as BigInt)),
        'compareTo' => QudsNativeFunction(
            'compareTo', (p, n, c) => receiver.compareTo(p[0] as BigInt)),
        'toRadixString' => QudsNativeFunction(
            'toRadixString', (p, n, c) => receiver.toRadixString(p[0] as int)),
        _ => _noMember,
      };
    }

    // List
    if (receiver is List) {
      final listMember = switch (name) {
        'length' => receiver.length,
        'isEmpty' => receiver.isEmpty,
        'isNotEmpty' => receiver.isNotEmpty,
        'first' => receiver.first,
        'last' => receiver.last,
        'firstOrNull' => receiver.isEmpty ? null : receiver.first,
        'lastOrNull' => receiver.isEmpty ? null : receiver.last,
        'reversed' => receiver.reversed.toList(),
        'add' => QudsNativeFunction('add', (p, n, c) {
            _requireMutation('List.add', span);
            receiver.add(p[0]);
            _checkCollectionSize(receiver.length, span);
            return null;
          }),
        'addAll' => QudsNativeFunction('addAll', (p, n, c) {
            _requireMutation('List.addAll', span);
            receiver.addAll(p[0] as Iterable);
            _checkCollectionSize(receiver.length, span);
            return null;
          }),
        'insert' => QudsNativeFunction('insert', (p, n, c) {
            _requireMutation('List.insert', span);
            receiver.insert(p[0] as int, p[1]);
            _checkCollectionSize(receiver.length, span);
            return null;
          }),
        'remove' => QudsNativeFunction('remove', (p, n, c) {
            _requireMutation('List.remove', span);
            return receiver.remove(p[0]);
          }),
        'removeAt' => QudsNativeFunction('removeAt', (p, n, c) {
            _requireMutation('List.removeAt', span);
            return receiver.removeAt(p[0] as int);
          }),
        'removeLast' => QudsNativeFunction('removeLast', (p, n, c) {
            _requireMutation('List.removeLast', span);
            return receiver.removeLast();
          }),
        'clear' => QudsNativeFunction('clear', (p, n, c) {
            _requireMutation('List.clear', span);
            receiver.clear();
            return null;
          }),
        'sublist' => QudsNativeFunction('sublist', (p, n, c) {
            final s = p[0] as int;
            final e = p.length > 1 ? p[1] as int? : null;
            return receiver.sublist(s, e);
          }),
        'indexOf' => QudsNativeFunction('indexOf', (p, n, c) {
            final start = p.length > 1 ? p[1] as int : 0;
            for (var i = start; i < receiver.length; i++) {
              if (qudsEquals(receiver[i], p[0])) return i;
            }
            return -1;
          }),
        'sort' => QudsNativeFunction('sort', (p, n, c) async {
            _requireMutation('List.sort', span);
            if (p.isEmpty) {
              receiver.sort((a, b) => _compare(a, b, span));
              return null;
            }
            // Custom comparator (async-safe merge sort)
            final cmp = p[0];
            final sorted = await _mergeSort(receiver.toList(), cmp, span);
            receiver
              ..clear()
              ..addAll(sorted);
            return null;
          }),
        'fillRange' => QudsNativeFunction('fillRange', (p, n, c) {
            _requireMutation('List.fillRange', span);
            receiver.fillRange(
                p[0] as int, p[1] as int, p.length > 2 ? p[2] : null);
            return null;
          }),
        'asMap' => QudsNativeFunction(
            'asMap', (p, n, c) => Map<int, Object?>.from(receiver.asMap())),
        _ => _noMember,
      };
      if (listMember != _noMember) return listMember;
    }

    // Set
    if (receiver is Set) {
      final setMember = switch (name) {
        'length' => receiver.length,
        'isEmpty' => receiver.isEmpty,
        'isNotEmpty' => receiver.isNotEmpty,
        'first' => receiver.first,
        'last' => receiver.last,
        'add' => QudsNativeFunction('add', (p, n, c) {
            _requireMutation('Set.add', span);
            final added = receiver.add(p[0]);
            _checkCollectionSize(receiver.length, span);
            return added;
          }),
        'addAll' => QudsNativeFunction('addAll', (p, n, c) {
            _requireMutation('Set.addAll', span);
            receiver.addAll(p[0] as Iterable);
            _checkCollectionSize(receiver.length, span);
            return null;
          }),
        'remove' => QudsNativeFunction('remove', (p, n, c) {
            _requireMutation('Set.remove', span);
            return receiver.remove(p[0]);
          }),
        'clear' => QudsNativeFunction('clear', (p, n, c) {
            _requireMutation('Set.clear', span);
            receiver.clear();
            return null;
          }),
        'union' => QudsNativeFunction(
            'union', (p, n, c) => receiver.union((p[0] as Iterable).toSet())),
        'intersection' => QudsNativeFunction('intersection',
            (p, n, c) => receiver.intersection((p[0] as Iterable).toSet())),
        'difference' => QudsNativeFunction('difference',
            (p, n, c) => receiver.difference((p[0] as Iterable).toSet())),
        _ => _noMember,
      };
      if (setMember != _noMember) return setMember;
    }

    // Iterable common methods (List, Set, QudsRange, etc.)
    if (receiver is Iterable) {
      return switch (name) {
        'length' => receiver.length,
        'isEmpty' => receiver.isEmpty,
        'isNotEmpty' => receiver.isNotEmpty,
        'first' => receiver.first,
        'last' => receiver.last,
        'toList' =>
          QudsNativeFunction('toList', (p, n, c) => receiver.toList()),
        'toSet' => QudsNativeFunction('toSet', (p, n, c) => receiver.toSet()),
        'contains' => QudsNativeFunction(
            'contains', (p, n, c) => receiver.any((e) => qudsEquals(e, p[0]))),
        'join' => QudsNativeFunction('join', (p, n, c) {
            final sep = p.isNotEmpty ? '${p[0]}' : '';
            final out = receiver.map(qudsFormatValue).join(sep);
            _checkStringLength(out.length, span);
            return out;
          }),
        'take' => QudsNativeFunction(
            'take', (p, n, c) => receiver.take(p[0] as int).toList()),
        'skip' => QudsNativeFunction(
            'skip', (p, n, c) => receiver.skip(p[0] as int).toList()),
        'map' => QudsNativeFunction('map', (p, n, c) async {
            final out = <Object?>[];
            for (final item in receiver) {
              out.add(await invokeCallable(p[0], [item], const {}, span));
            }
            return out;
          }),
        'where' => QudsNativeFunction('where', (p, n, c) async {
            final out = <Object?>[];
            for (final item in receiver) {
              final keep = await invokeCallable(p[0], [item], const {}, span);
              if (_expectBool(keep, span)) out.add(item);
            }
            return out;
          }),
        'any' => QudsNativeFunction('any', (p, n, c) async {
            for (final item in receiver) {
              if (_expectBool(
                  await invokeCallable(p[0], [item], const {}, span), span)) {
                return true;
              }
            }
            return false;
          }),
        'every' => QudsNativeFunction('every', (p, n, c) async {
            for (final item in receiver) {
              if (!_expectBool(
                  await invokeCallable(p[0], [item], const {}, span), span)) {
                return false;
              }
            }
            return true;
          }),
        'fold' => QudsNativeFunction('fold', (p, n, c) async {
            var acc = p[0];
            for (final item in receiver) {
              acc = await invokeCallable(p[1], [acc, item], const {}, span);
            }
            return acc;
          }),
        'reduce' => QudsNativeFunction('reduce', (p, n, c) async {
            final it = receiver.iterator;
            if (!it.moveNext()) {
              throw QudsRuntimeException(
                  'Cannot reduce an empty collection.', span);
            }
            var acc = it.current;
            while (it.moveNext()) {
              acc =
                  await invokeCallable(p[0], [acc, it.current], const {}, span);
            }
            return acc;
          }),
        'forEach' => QudsNativeFunction('forEach', (p, n, c) async {
            for (final item in receiver) {
              await invokeCallable(p[0], [item], const {}, span);
            }
            return null;
          }),
        'expand' => QudsNativeFunction('expand', (p, n, c) async {
            final out = <Object?>[];
            for (final item in receiver) {
              final sub = await invokeCallable(p[0], [item], const {}, span);
              if (sub is Iterable) out.addAll(sub);
            }
            return out;
          }),
        _ => _noMember,
      };
    }

    // Map
    if (receiver is Map) {
      return switch (name) {
        'length' => receiver.length,
        'isEmpty' => receiver.isEmpty,
        'isNotEmpty' => receiver.isNotEmpty,
        'keys' => receiver.keys.toList(),
        'values' => receiver.values.toList(),
        'entries' => receiver.entries.toList(),
        'containsKey' => QudsNativeFunction(
            'containsKey', (p, n, c) => receiver.containsKey(p[0])),
        'containsValue' => QudsNativeFunction('containsValue',
            (p, n, c) => receiver.values.any((v) => qudsEquals(v, p[0]))),
        'remove' => QudsNativeFunction('remove', (p, n, c) {
            _requireMutation('Map.remove', span);
            return receiver.remove(p[0]);
          }),
        'clear' => QudsNativeFunction('clear', (p, n, c) {
            _requireMutation('Map.clear', span);
            receiver.clear();
            return null;
          }),
        'addAll' => QudsNativeFunction('addAll', (p, n, c) {
            _requireMutation('Map.addAll', span);
            receiver.addAll(p[0] as Map);
            _checkCollectionSize(receiver.length, span);
            return null;
          }),
        'putIfAbsent' => QudsNativeFunction('putIfAbsent', (p, n, c) async {
            _requireMutation('Map.putIfAbsent', span);
            if (receiver.containsKey(p[0])) return receiver[p[0]];
            final v = await invokeCallable(p[1], const [], const {}, span);
            receiver[p[0]] = v;
            return v;
          }),
        _ => _noMember,
      };
    }

    // MapEntry
    if (receiver is MapEntry) {
      return switch (name) {
        'key' => receiver.key,
        'value' => receiver.value,
        _ => _noMember,
      };
    }

    // Duration
    if (receiver is Duration) {
      return switch (name) {
        'inMicroseconds' => receiver.inMicroseconds,
        'inMilliseconds' => receiver.inMilliseconds,
        'inSeconds' => receiver.inSeconds,
        'inMinutes' => receiver.inMinutes,
        'inHours' => receiver.inHours,
        'inDays' => receiver.inDays,
        'isNegative' => receiver.isNegative,
        'abs' => QudsNativeFunction('abs', (p, n, c) => receiver.abs()),
        _ => _noMember,
      };
    }

    // DateTime
    if (receiver is DateTime) {
      return switch (name) {
        'year' => receiver.year,
        'month' => receiver.month,
        'day' => receiver.day,
        'hour' => receiver.hour,
        'minute' => receiver.minute,
        'second' => receiver.second,
        'millisecond' => receiver.millisecond,
        'microsecond' => receiver.microsecond,
        'weekday' => receiver.weekday,
        'isUtc' => receiver.isUtc,
        'millisecondsSinceEpoch' => receiver.millisecondsSinceEpoch,
        'microsecondsSinceEpoch' => receiver.microsecondsSinceEpoch,
        'toIso8601String' => QudsNativeFunction(
            'toIso8601String', (p, n, c) => receiver.toIso8601String()),
        'toUtc' => QudsNativeFunction('toUtc', (p, n, c) => receiver.toUtc()),
        'toLocal' =>
          QudsNativeFunction('toLocal', (p, n, c) => receiver.toLocal()),
        'add' => QudsNativeFunction(
            'add', (p, n, c) => receiver.add(p[0] as Duration)),
        'subtract' => QudsNativeFunction(
            'subtract', (p, n, c) => receiver.subtract(p[0] as Duration)),
        'difference' => QudsNativeFunction(
            'difference', (p, n, c) => receiver.difference(p[0] as DateTime)),
        'isBefore' => QudsNativeFunction(
            'isBefore', (p, n, c) => receiver.isBefore(p[0] as DateTime)),
        'isAfter' => QudsNativeFunction(
            'isAfter', (p, n, c) => receiver.isAfter(p[0] as DateTime)),
        _ => _noMember,
      };
    }

    // RegExp
    if (receiver is RegExp) {
      return switch (name) {
        'pattern' => receiver.pattern,
        'hasMatch' => QudsNativeFunction(
            'hasMatch', (p, n, c) => receiver.hasMatch('${p[0]}')),
        'firstMatch' => QudsNativeFunction(
            'firstMatch', (p, n, c) => receiver.firstMatch('${p[0]}')),
        'allMatches' => QudsNativeFunction(
            'allMatches', (p, n, c) => receiver.allMatches('${p[0]}').toList()),
        'stringMatch' => QudsNativeFunction(
            'stringMatch', (p, n, c) => receiver.stringMatch('${p[0]}')),
        _ => _noMember,
      };
    }

    if (receiver is RegExpMatch) {
      return switch (name) {
        'start' => receiver.start,
        'end' => receiver.end,
        'groupCount' => receiver.groupCount,
        'group' =>
          QudsNativeFunction('group', (p, n, c) => receiver.group(p[0] as int)),
        _ => _noMember,
      };
    }

    // StringBuffer
    if (receiver is StringBuffer) {
      return switch (name) {
        'length' => receiver.length,
        'isEmpty' => receiver.isEmpty,
        'isNotEmpty' => receiver.isNotEmpty,
        'write' => QudsNativeFunction('write', (p, n, c) {
            receiver.write(qudsFormatValue(p[0]));
            _checkStringLength(receiver.length, span);
            return null;
          }),
        'writeln' => QudsNativeFunction('writeln', (p, n, c) {
            receiver.writeln(p.isEmpty ? '' : qudsFormatValue(p[0]));
            _checkStringLength(receiver.length, span);
            return null;
          }),
        'clear' => QudsNativeFunction('clear', (p, n, c) {
            receiver.clear();
            return null;
          }),
        _ => _noMember,
      };
    }

    // Completer
    if (receiver is Completer) {
      return switch (name) {
        'future' => QudsFuture(receiver.future),
        'isCompleted' => receiver.isCompleted,
        'complete' => QudsNativeFunction('complete', (p, n, c) {
            if (!receiver.isCompleted) {
              final val = p.isEmpty ? null : p[0];
              receiver.complete(val is QudsFuture ? val.future : val);
            }
            return null;
          }),
        'completeError' => QudsNativeFunction('completeError', (p, n, c) {
            if (!receiver.isCompleted) {
              receiver.completeError(p[0]!);
            }
            return null;
          }),
        _ => _noMember,
      };
    }

    // Timer
    if (receiver is Timer) {
      return switch (name) {
        'isActive' => receiver.isActive,
        'tick' => receiver.tick,
        'cancel' => QudsNativeFunction('cancel', (p, n, c) {
            receiver.cancel();
            return null;
          }),
        _ => _noMember,
      };
    }

    // QudsFuture / Future
    if (receiver is QudsFuture || receiver is Future) {
      final fut = receiver is QudsFuture ? receiver.future : receiver as Future;
      return switch (name) {
        'then' => QudsNativeFunction('then', (p, n, c) {
            return QudsFuture(fut.then(
              (v) => invokeCallable(p[0], [v], const {}, span),
              onError: n['onError'] != null
                  ? (Object e) =>
                      invokeCallable(n['onError'], [e], const {}, span)
                  : null,
            ));
          }),
        'catchError' => QudsNativeFunction('catchError', (p, n, c) {
            return QudsFuture(fut.catchError(
                (Object e) => invokeCallable(p[0], [e], const {}, span)));
          }),
        'whenComplete' => QudsNativeFunction('whenComplete', (p, n, c) {
            return QudsFuture(fut.whenComplete(
                () => invokeCallable(p[0], const [], const {}, span)));
          }),
        _ => _noMember,
      };
    }

    final stdlibMember =
        lookupStdlibInstanceMember(receiver, name, span, invokeCallable);
    if (stdlibMember != null) return stdlibMember;

    return _noMember;
  }

  Future<List<Object?>> _mergeSort(
      List<Object?> list, Object? cmp, SourceSpan span) async {
    if (list.length <= 1) return list;
    final mid = list.length ~/ 2;
    final left = await _mergeSort(list.sublist(0, mid), cmp, span);
    final right = await _mergeSort(list.sublist(mid), cmp, span);
    final merged = <Object?>[];
    var i = 0;
    var j = 0;
    while (i < left.length && j < right.length) {
      final res =
          await invokeCallable(cmp, [left[i], right[j]], const {}, span);
      if ((res as num) <= 0) {
        merged.add(left[i++]);
      } else {
        merged.add(right[j++]);
      }
    }
    while (i < left.length) {
      merged.add(left[i++]);
    }
    while (j < right.length) {
      merged.add(right[j++]);
    }
    return merged;
  }

  void _requireMutation(String operation, SourceSpan span) {
    if (!allowMutation) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.featureDisabled,
        'Mutation (`$operation`) is disabled by the active execution policy.',
        span,
        stackFrames: stackFrames,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Pattern Matching & Conversions
  // -------------------------------------------------------------------------

  Future<bool> _matchPattern(
    Pattern pattern,
    Object? value,
    QudsEnvironment env,
    SourceSpan span, {
    bool mutableBindings = false,
  }) async {
    switch (pattern) {
      case WildcardPattern():
        return true;

      case BindingPattern(:final name):
        env.define(name, value, mutable: mutableBindings);
        return true;

      case LiteralPattern(:final literal):
        final expected = await _evalExpr(literal, env);
        return qudsEquals(value, expected);

      case TypedPattern(:final type, :final name):
        if (!_matchesType(value, type)) return false;
        if (name != null) env.define(name, value, mutable: mutableBindings);
        return true;

      case NullCheckPattern(:final inner):
        if (value == null) return false;
        return _matchPattern(inner, value, env, span,
            mutableBindings: mutableBindings);

      case NullAssertPattern(:final inner):
        if (value == null) {
          throw QudsRuntimeException(
              'Null assertion in pattern failed.', pattern.span);
        }
        return _matchPattern(inner, value, env, span,
            mutableBindings: mutableBindings);

      case CastPattern(:final inner, :final type):
        if (!_matchesType(value, type)) {
          throw QudsRuntimeException(
              'Pattern cast failed: `${qudsTypeName(value)}` is not `$type`.',
              pattern.span);
        }
        return _matchPattern(inner, value, env, span,
            mutableBindings: mutableBindings);

      case OrPattern(:final left, :final right):
        final tryLeft = env.child();
        if (await _matchPattern(left, value, tryLeft, span,
            mutableBindings: mutableBindings)) {
          for (final entry in tryLeft.localSlots.entries) {
            env.define(entry.key, entry.value.value, mutable: mutableBindings);
          }
          return true;
        }
        return _matchPattern(right, value, env, span,
            mutableBindings: mutableBindings);

      case AndPattern(:final left, :final right):
        return await _matchPattern(left, value, env, span,
                mutableBindings: mutableBindings) &&
            await _matchPattern(right, value, env, span,
                mutableBindings: mutableBindings);

      case RelationalPattern(:final operator, value: final rhsExpr):
        final rhs = await _evalExpr(rhsExpr, env);
        final ok = await _applyBinaryOp(value, operator, rhs, pattern.span);
        return ok == true;

      case ListPattern(:final elements):
        if (value is! List) return false;
        final restIdx = elements.indexWhere((e) => e is RestPattern);
        if (restIdx < 0) {
          if (value.length != elements.length) return false;
          for (var i = 0; i < elements.length; i++) {
            if (!await _matchPattern(elements[i], value[i], env, span,
                mutableBindings: mutableBindings)) {
              return false;
            }
          }
          return true;
        }
        final tailCount = elements.length - restIdx - 1;
        if (value.length < restIdx + tailCount) return false;
        for (var i = 0; i < restIdx; i++) {
          if (!await _matchPattern(elements[i], value[i], env, span,
              mutableBindings: mutableBindings)) {
            return false;
          }
        }
        final restPat = elements[restIdx] as RestPattern;
        if (restPat.name != null) {
          env.define(
            restPat.name!,
            value.sublist(restIdx, value.length - tailCount),
            mutable: mutableBindings,
          );
        }
        for (var i = 0; i < tailCount; i++) {
          if (!await _matchPattern(
            elements[restIdx + 1 + i],
            value[value.length - tailCount + i],
            env,
            span,
            mutableBindings: mutableBindings,
          )) {
            return false;
          }
        }
        return true;

      case MapPattern(:final keys, :final values):
        if (value is! Map) return false;
        for (var i = 0; i < keys.length; i++) {
          final k = await _evalExpr(keys[i], env);
          if (!value.containsKey(k)) return false;
          if (!await _matchPattern(values[i], value[k], env, span,
              mutableBindings: mutableBindings)) {
            return false;
          }
        }
        return true;

      case ConstructorPattern(:final typeName, :final fields, :final names):
        // Built-in Ok(v) / Error(e) / present(v)
        if (typeName == 'Ok' && value is QudsResult && value.isOk) {
          if (fields.isEmpty) return true;
          return _matchPattern(fields.first, value.value, env, span,
              mutableBindings: mutableBindings);
        }
        if (typeName == 'Error' && value is QudsResult && value.isError) {
          if (fields.isEmpty) return true;
          return _matchPattern(fields.first, value.error, env, span,
              mutableBindings: mutableBindings);
        }
        if (typeName == 'present' && value is QudsOptional && value.isPresent) {
          if (fields.isEmpty) return true;
          return _matchPattern(fields.first, value.value, env, span,
              mutableBindings: mutableBindings);
        }
        if (value is QudsInstance) {
          if (!value.qudsClass.isSubtypeOf(typeName)) return false;
          final classFields = _collectAllInstanceFields(value.qudsClass);
          for (var i = 0; i < fields.length; i++) {
            final fieldName = (i < names.length ? names[i] : null) ??
                (i < classFields.length ? classFields[i].name : null);
            if (fieldName == null || !value.fields.containsKey(fieldName)) {
              return false;
            }
            if (!await _matchPattern(
              fields[i],
              value.fields[fieldName],
              env,
              span,
              mutableBindings: mutableBindings,
            )) {
              return false;
            }
          }
          return true;
        }
        // Record destructuring `(a, b)`
        if (typeName.isEmpty && value is QudsRecord) {
          if (fields.length > value.positional.length + value.named.length) {
            return false;
          }
          var pIdx = 0;
          for (var i = 0; i < fields.length; i++) {
            final fieldName = i < names.length ? names[i] : null;
            final fv = fieldName != null
                ? value.named[fieldName]
                : (pIdx < value.positional.length
                    ? value.positional[pIdx++]
                    : null);
            if (!await _matchPattern(fields[i], fv, env, span,
                mutableBindings: mutableBindings)) {
              return false;
            }
          }
          return true;
        }
        return false;

      case RestPattern():
        return true;
    }
  }

  FutureOr<Object?> _applyConversion(
      Object? value, String targetType, bool safe, SourceSpan span) {
    final nullable = targetType.endsWith('?');
    final base = _baseTypeName(targetType);

    if (value == null) {
      if (nullable) return null;
      if (safe) return null;
      throw QudsThrownValue(
          QudsConversionError('Cannot convert `null` to `$targetType`.'),
          span,
          stackFrames);
    }

    if (_customConversions.isNotEmpty) {
      for (final conv in _customConversions) {
        if (conv.parameters.length == 1 &&
            _baseTypeName(conv.returnType) == base &&
            _matchesType(value, conv.parameters.first.type)) {
          return _invokeCustomConversion(conv, value, safe, span);
        }
      }
    }

    try {
      switch (base) {
        case 'int':
          if (value is int) return value;
          if (value is double) return value.toInt();
          if (value is BigInt) return value.toInt();
          if (value is String) {
            final parsed = int.tryParse(value.trim());
            if (parsed != null) return parsed;
            if (safe) return null;
            throw QudsConversionError('Cannot convert "$value" to int.');
          }
          if (value is bool) return value ? 1 : 0;
          break;
        case 'double':
          if (value is double) return value;
          if (value is int) return value.toDouble();
          if (value is BigInt) return value.toDouble();
          if (value is String) {
            final parsed = double.tryParse(value.trim());
            if (parsed != null) return parsed;
            if (safe) return null;
            throw QudsConversionError('Cannot convert "$value" to double.');
          }
          break;
        case 'num':
          if (value is num) return value;
          if (value is String) {
            final parsed = num.tryParse(value.trim());
            if (parsed != null) return parsed;
            if (safe) return null;
            throw QudsConversionError('Cannot convert "$value" to num.');
          }
          break;
        case 'String':
          return qudsFormatValue(value);
        case 'bool':
          if (value is bool) return value;
          if (value is String) {
            final lower = value.trim().toLowerCase();
            if (lower == 'true') return true;
            if (lower == 'false') return false;
          }
          if (value is int) return value != 0;
          break;
        case 'BigInt':
          if (value is BigInt) return value;
          if (value is int) return BigInt.from(value);
          if (value is String) {
            final parsed = BigInt.tryParse(value.trim());
            if (parsed != null) return parsed;
          }
          break;
        case 'List':
          if (value is List) return value.toList();
          if (value is Iterable) return value.toList();
          break;
        case 'Set':
          if (value is Set) return value.toSet();
          if (value is Iterable) return value.toSet();
          break;
      }
      if (safe) return null;
      throw QudsConversionError(
          'Cannot convert `${qudsTypeName(value)}` to `$targetType`.');
    } on QudsConversionError catch (e) {
      if (safe) return null;
      throw QudsThrownValue(e, span, stackFrames);
    }
  }

  Future<Object?> _invokeCustomConversion(
    QudsUserFunction conv,
    Object? value,
    bool safe,
    SourceSpan span,
  ) async {
    try {
      return await invokeCallable(conv, [value], const {}, span);
    } on QudsPolicyViolationException {
      rethrow;
    } catch (_) {
      if (safe) return null;
      rethrow;
    }
  }

  bool _matchesType(Object? value, String type) {
    final trimmed = type.trim();
    if (trimmed == 'dynamic' || trimmed == 'Object?' || trimmed == 'Object') {
      return trimmed != 'Object' || value != null;
    }
    if (value == null) return trimmed.endsWith('?') || trimmed == 'Null';
    final base = _baseTypeName(trimmed);
    switch (base) {
      case 'int':
        return value is int;
      case 'double':
        return value is double;
      case 'num':
        return value is num;
      case 'bool':
        return value is bool;
      case 'String':
        return value is String;
      case 'BigInt':
        return value is BigInt;
      case 'List' || 'Array':
        return value is List;
      case 'Map' || 'Dict':
        return value is Map;
      case 'Set' || 'HashSet':
        return value is Set;
      case 'Iterable':
        return value is Iterable;
      case 'Duration':
        return value is Duration;
      case 'DateTime':
        return value is DateTime;
      case 'RegExp':
        return value is RegExp;
      case 'Future':
        return value is Future || value is QudsFuture;
      case 'Function':
        return value is QudsCallable;
      case 'Result':
        return value is QudsResult;
      case 'Ok':
        return value is QudsResult && value.isOk;
      case 'Error':
        return value is QudsResult && value.isError;
      case 'Optional':
        return value is QudsOptional || value is QudsMissing;
      case 'Exception':
        return value is Exception || value is Error;
      case 'ArgumentError':
        return value is ArgumentError;
      case 'StateError':
        return value is StateError;
      case 'RangeError':
        return value is RangeError;
      case 'FormatException':
        return value is FormatException;
      case 'ConversionError':
        return value is QudsConversionError;
      default:
        if (value is QudsInstance) return value.qudsClass.isSubtypeOf(base);
        return value.runtimeType.toString() == base;
    }
  }

  Future<void> _tryCloseResource(Object? resource, SourceSpan span) async {
    if (resource is QudsInstance) {
      final close = resource.qudsClass.lookupMethod('close') ??
          resource.qudsClass.lookupMethod('dispose');
      if (close != null) {
        await invokeCallable(close.bind(resource), const [], const {}, span);
      }
    }
  }

  bool _expectBool(Object? v, SourceSpan span) {
    if (v is bool) return v;
    throw QudsRuntimeException(
        'Expected `bool`, got `${qudsTypeName(v)}` (${qudsFormatValue(v)}).',
        span,
        code: 'E300');
  }

  int _expectInt(Object? v, SourceSpan span) {
    if (v is int) return v;
    throw QudsRuntimeException(
        'Expected `int`, got `${qudsTypeName(v)}` (${qudsFormatValue(v)}).',
        span,
        code: 'E300');
  }

  String _baseTypeName(String type) {
    var cleaned = type.trim();
    if (cleaned.startsWith('readonly ')) {
      cleaned = cleaned.substring('readonly '.length).trim();
    }
    if (cleaned.endsWith('?')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    final lt = cleaned.indexOf('<');
    return lt < 0 ? cleaned : cleaned.substring(0, lt).trim();
  }

  // -------------------------------------------------------------------------
  // Sound FutureOr<Object?> synchronous fast-path (zero Future allocations
  // when synchronous; exact-once async continuation on first Future or yield)
  // -------------------------------------------------------------------------

  FutureOr<Object?> _execBlockFast(
    List<Statement> statements,
    QudsEnvironment env, {
    bool returnLastExpression = false,
    bool hoistDeclarations = false,
  }) {
    for (final s in statements) {
      if (s is DeferStatement) {
        return executeBlock(
          statements,
          env,
          returnLastExpression: returnLastExpression,
          hoistDeclarations: hoistDeclarations,
        );
      }
    }
    if (hoistDeclarations) {
      _hoistFunctions(statements, env);
    }
    Object? lastValue;
    for (var i = 0; i < statements.length; i++) {
      final stmt = statements[i];
      if (_tickNeedsYield(stmt.span)) {
        onStepProgress?.call(_steps, stmt.span);
        return _execBlockAsyncTail(
          statements,
          i,
          env,
          returnLastExpression: returnLastExpression,
          hoistDeclarations: hoistDeclarations,
          lastValue: lastValue,
          yieldFirst: true,
        );
      }
      final res =
          _execStatementFast(stmt, env, alreadyHoisted: hoistDeclarations);
      if (res is Future<Object?>) {
        return _execBlockAsyncAfterStmt(
          res,
          stmt,
          statements,
          i,
          env,
          returnLastExpression: returnLastExpression,
          hoistDeclarations: hoistDeclarations,
          lastValue: lastValue,
        );
      }
      if (returnLastExpression && stmt is ExpressionStatement) {
        lastValue = res;
      }
    }
    return lastValue;
  }

  Future<Object?> _execBlockAsyncAfterStmt(
    Future<Object?> pending,
    Statement stmt,
    List<Statement> statements,
    int index,
    QudsEnvironment env, {
    required bool returnLastExpression,
    required bool hoistDeclarations,
    required Object? lastValue,
  }) async {
    final val = await pending;
    var nextLast = lastValue;
    if (returnLastExpression && stmt is ExpressionStatement) {
      nextLast = val;
    }
    return _execBlockAsyncTail(
      statements,
      index + 1,
      env,
      returnLastExpression: returnLastExpression,
      hoistDeclarations: hoistDeclarations,
      lastValue: nextLast,
      yieldFirst: false,
    );
  }

  Future<Object?> _execBlockAsyncTail(
    List<Statement> statements,
    int startIndex,
    QudsEnvironment env, {
    required bool returnLastExpression,
    required bool hoistDeclarations,
    required Object? lastValue,
    required bool yieldFirst,
  }) async {
    if (yieldFirst) {
      await Future<void>.delayed(Duration.zero);
    }
    var currentLast = lastValue;
    for (var i = startIndex; i < statements.length; i++) {
      final stmt = statements[i];
      if (i > startIndex || !yieldFirst) {
        final tickFut = _tick(stmt.span);
        if (tickFut != null) await tickFut;
      }
      final res =
          _execStatementFast(stmt, env, alreadyHoisted: hoistDeclarations);
      final val = res is Future<Object?> ? await res : res;
      if (returnLastExpression && stmt is ExpressionStatement) {
        currentLast = val;
      }
    }
    return currentLast;
  }

  FutureOr<Object?> _execStatementFast(
    Statement stmt,
    QudsEnvironment env, {
    bool alreadyHoisted = false,
  }) {
    switch (stmt) {
      case FunctionDeclaration():
        if (!alreadyHoisted) _registerFunctionDeclaration(stmt, env);
        return null;
      case SectionDeclaration():
      case AliasDeclaration():
      case PartDirective():
      case AnnotationDeclaration():
        return null;
      case ExpressionStatement(:final expression):
        return _evalExprFast(expression, env);
      case Binding():
        if (stmt.value is DotShorthand ||
            stmt.mode == BindingMode.computed ||
            _computedCells.isNotEmpty ||
            _watchers.isNotEmpty) {
          return _execBinding(stmt, env);
        }
        if (stmt.operator == '=') {
          if (stmt.open) {
            env.bind(
              stmt.name,
              stmt.mode,
              null,
              stmt.span,
              declaredType: stmt.type,
              open: true,
              allowMutation: allowMutation,
            );
            return null;
          }
          final val = _evalExprFast(stmt.value, env);
          if (val is Future<Object?>) {
            return val.then((v) {
              env.bind(
                stmt.name,
                stmt.mode,
                v,
                stmt.span,
                declaredType: stmt.type,
                open: false,
                allowMutation: allowMutation,
              );
              return null;
            });
          }
          env.bind(
            stmt.name,
            stmt.mode,
            val,
            stmt.span,
            declaredType: stmt.type,
            open: false,
            allowMutation: allowMutation,
          );
          return null;
        }
        if (stmt.operator == '??=') return _execBinding(stmt, env);
        final current = env.get(stmt.name, stmt.span);
        final rhs = _evalExprFast(stmt.value, env);
        final baseOp = stmt.operator.substring(0, stmt.operator.length - 1);
        if (rhs is Future<Object?>) {
          return rhs.then((r) async {
            final updated = await _applyBinaryOp(current, baseOp, r, stmt.span);
            env.assignExisting(stmt.name, updated, stmt.span,
                allowMutation: allowMutation);
            return null;
          });
        }
        final updated = _applyBinaryFast(current, baseOp, rhs, stmt.span);
        if (updated is Future<Object?>) {
          return updated.then((u) {
            env.assignExisting(stmt.name, u, stmt.span,
                allowMutation: allowMutation);
            return null;
          });
        }
        env.assignExisting(stmt.name, updated, stmt.span,
            allowMutation: allowMutation);
        return null;
      case ReturnStatement(:final value):
        if (value == null) throw const ReturnSignal(null);
        final res = _evalExprFast(value, env);
        if (res is Future<Object?>) {
          return res.then((v) => throw ReturnSignal(v));
        }
        throw ReturnSignal(res);
      case BreakStatement(:final label, :final value):
        if (value == null) {
          throw BreakSignal(label: label, value: null, hasValue: false);
        }
        final res = _evalExprFast(value, env);
        if (res is Future<Object?>) {
          return res.then(
              (v) => throw BreakSignal(label: label, value: v, hasValue: true));
        }
        throw BreakSignal(label: label, value: res, hasValue: true);
      case ContinueStatement(:final label):
        throw ContinueSignal(label: label);
      case ThrowStatement(:final value):
        if (!allowExceptions) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.featureDisabled,
            'Throwing exceptions is disabled by the active execution policy.',
            stmt.span,
            stackFrames: stackFrames,
          );
        }
        final res = _evalExprFast(value, env);
        if (res is Future<Object?>) {
          return res
              .then((v) => throw QudsThrownValue(v, stmt.span, stackFrames));
        }
        throw QudsThrownValue(res, stmt.span, stackFrames);
      case IfStatement(:final condition, :final thenBody, :final elseBody):
        final cond = _evalExprFast(condition, env);
        if (cond is Future<Object?>) {
          return cond.then((c) {
            if (_expectBool(c, condition.span)) {
              return _execBlockFast(thenBody, env.child(),
                  hoistDeclarations: true);
            } else if (elseBody.isNotEmpty) {
              return _execBlockFast(elseBody, env.child(),
                  hoistDeclarations: true);
            }
            return null;
          });
        }
        if (_expectBool(cond, condition.span)) {
          return _execBlockFast(thenBody, env.child(), hoistDeclarations: true);
        } else if (elseBody.isNotEmpty) {
          return _execBlockFast(elseBody, env.child(), hoistDeclarations: true);
        }
        return null;
      case WhenStatement(:final condition, :final body):
        final cond = _evalExprFast(condition, env);
        if (cond is Future<Object?>) {
          return cond.then((c) => _expectBool(c, condition.span)
              ? _execBlockFast(body, env.child(), hoistDeclarations: true)
              : null);
        }
        if (_expectBool(cond, condition.span)) {
          return _execBlockFast(body, env.child(), hoistDeclarations: true);
        }
        return null;
      case GuardStatement(:final condition, :final elseBody):
        final cond = _evalExprFast(condition, env);
        if (cond is Future<Object?>) {
          return cond.then((c) => !_expectBool(c, condition.span)
              ? _execBlockFast(elseBody, env.child(), hoistDeclarations: true)
              : null);
        }
        if (!_expectBool(cond, condition.span)) {
          return _execBlockFast(elseBody, env.child(), hoistDeclarations: true);
        }
        return null;
      case WhileStatement():
        return _execWhileFast(stmt, env);
      case ForStatement():
        return _execForFast(stmt, env);
      case IndexAssignment(:final target, :final operator, :final value):
        if (operator != '=') {
          return _execIndexAssignment(target, operator, value, env, stmt.span);
        }
        final container = _evalExprFast(target.object, env);
        if (container is Future<Object?>) {
          return container.then((c) async {
            final idx = await _evalExprFast(target.index, env);
            final rhs = await _evalExprFast(value, env);
            _assignIndexSync(c, idx, rhs, stmt.span);
            return null;
          });
        }
        final idx = _evalExprFast(target.index, env);
        if (idx is Future<Object?>) {
          return idx.then((i) async {
            final rhs = await _evalExprFast(value, env);
            _assignIndexSync(container, i, rhs, stmt.span);
            return null;
          });
        }
        final rhs = _evalExprFast(value, env);
        if (rhs is Future<Object?>) {
          return rhs.then((v) {
            _assignIndexSync(container, idx, v, stmt.span);
            return null;
          });
        }
        if (container is List || container is Map) {
          _assignIndexSync(container, idx, rhs, stmt.span);
          return null;
        }
        return _execStatement(stmt, env, alreadyHoisted: alreadyHoisted);
      default:
        return _execStatement(stmt, env, alreadyHoisted: alreadyHoisted);
    }
  }

  void _assignIndexSync(
      Object? container, Object? idx, Object? rhs, SourceSpan span) {
    if (container is List && idx is int) {
      if (idx < 0 || idx >= container.length) {
        throw QudsRuntimeException(
          'Index $idx out of bounds for List of length ${container.length}.',
          span,
          code: 'R302',
        );
      }
      container[idx] = rhs;
      return;
    }
    if (container is Map) {
      container[idx] = rhs;
      return;
    }
    throw QudsRuntimeException(
      'Cannot index-assign on `${qudsTypeName(container)}`.',
      span,
    );
  }

  FutureOr<Object?> _execWhileFast(WhileStatement stmt, QudsEnvironment env) {
    var index = 0;
    while (true) {
      if (_tickNeedsYield(stmt.span)) {
        onStepProgress?.call(_steps, stmt.span);
        return _execWhileAsyncTail(stmt, env, index, yieldFirst: true);
      }
      if (maxLoopIterations != null && index >= maxLoopIterations!) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.loopLimit,
          'Loop exceeded maximum iteration limit ($maxLoopIterations).',
          stmt.span,
          stackFrames: stackFrames,
        );
      }
      final cond = _evalExprFast(stmt.condition, env);
      if (cond is Future<Object?>) {
        return _execWhileAsyncAfterCond(stmt, env, index, cond);
      }
      if (!_expectBool(cond, stmt.condition.span)) break;

      final iterEnv = env.child()
        ..define(
          r'$',
          QudsLoopContext(
              index: index, count: -1, first: index == 0, last: false),
        );
      try {
        final bodyRes =
            _execBlockFast(stmt.body, iterEnv, hoistDeclarations: true);
        if (bodyRes is Future<Object?>) {
          return _execWhileAsyncAfterBody(stmt, env, index, bodyRes);
        }
      } on ContinueSignal catch (sig) {
        if (sig.label != null) rethrow;
      } on BreakSignal catch (sig) {
        if (sig.label != null) rethrow;
        return sig.value;
      }
      index++;
    }
    if (stmt.elseBody.isNotEmpty) {
      return _execBlockFast(stmt.elseBody, env.child(),
          hoistDeclarations: true);
    }
    return null;
  }

  Future<Object?> _execWhileAsyncAfterCond(
    WhileStatement stmt,
    QudsEnvironment env,
    int index,
    Future<Object?> condFuture,
  ) async {
    final c = await condFuture;
    if (!_expectBool(c, stmt.condition.span)) {
      if (stmt.elseBody.isNotEmpty) {
        await executeBlock(stmt.elseBody, env.child(), hoistDeclarations: true);
      }
      return null;
    }
    final iterEnv = env.child()
      ..define(
        r'$',
        QudsLoopContext(
            index: index, count: -1, first: index == 0, last: false),
      );
    try {
      await executeBlock(stmt.body, iterEnv, hoistDeclarations: true);
    } on ContinueSignal catch (sig) {
      if (sig.label != null) rethrow;
    } on BreakSignal catch (sig) {
      if (sig.label != null) rethrow;
      return sig.value;
    }
    return _execWhileAsyncTail(stmt, env, index + 1, yieldFirst: false);
  }

  Future<Object?> _execWhileAsyncAfterBody(
    WhileStatement stmt,
    QudsEnvironment env,
    int index,
    Future<Object?> bodyFuture,
  ) async {
    try {
      await bodyFuture;
    } on ContinueSignal catch (sig) {
      if (sig.label != null) rethrow;
    } on BreakSignal catch (sig) {
      if (sig.label != null) rethrow;
      return sig.value;
    }
    return _execWhileAsyncTail(stmt, env, index + 1, yieldFirst: false);
  }

  Future<Object?> _execWhileAsyncTail(
    WhileStatement stmt,
    QudsEnvironment env,
    int startIndex, {
    required bool yieldFirst,
  }) async {
    if (yieldFirst) {
      await Future<void>.delayed(Duration.zero);
    }
    var index = startIndex;
    while (true) {
      if (index > startIndex || !yieldFirst) {
        final t = _tick(stmt.span);
        if (t != null) await t;
      }
      if (maxLoopIterations != null && index >= maxLoopIterations!) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.loopLimit,
          'Loop exceeded maximum iteration limit ($maxLoopIterations).',
          stmt.span,
          stackFrames: stackFrames,
        );
      }
      final cond = await _evalExprFast(stmt.condition, env);
      if (!_expectBool(cond, stmt.condition.span)) break;
      final iterEnv = env.child()
        ..define(
          r'$',
          QudsLoopContext(
              index: index, count: -1, first: index == 0, last: false),
        );
      try {
        final r = _execBlockFast(stmt.body, iterEnv, hoistDeclarations: true);
        if (r is Future<Object?>) await r;
      } on ContinueSignal catch (sig) {
        if (sig.label != null) rethrow;
      } on BreakSignal catch (sig) {
        if (sig.label != null) rethrow;
        return sig.value;
      }
      index++;
    }
    if (stmt.elseBody.isNotEmpty) {
      final r =
          _execBlockFast(stmt.elseBody, env.child(), hoistDeclarations: true);
      if (r is Future<Object?>) await r;
    }
    return null;
  }

  FutureOr<Object?> _execForFast(ForStatement stmt, QudsEnvironment env) {
    final iterVal = _evalExprFast(stmt.iterable, env);
    if (iterVal is Future<Object?>) {
      return iterVal.then((v) async {
        final stepVal =
            stmt.step != null ? await _evalExprFast(stmt.step!, env) : null;
        final material = _materializeForIterable(v, stepVal, stmt);
        return _execForAsyncTail(stmt, env, material, 0, yieldFirst: false);
      });
    }
    Object? stepVal;
    if (stmt.step != null) {
      final sv = _evalExprFast(stmt.step!, env);
      if (sv is Future<Object?>) {
        return sv.then((s) {
          final material = _materializeForIterable(iterVal, s, stmt);
          return _execForAsyncTail(stmt, env, material, 0, yieldFirst: false);
        });
      }
      stepVal = sv;
    }
    final material = _materializeForIterable(iterVal, stepVal, stmt);
    for (var i = 0; i < material.length; i++) {
      if (_tickNeedsYield(stmt.span)) {
        onStepProgress?.call(_steps, stmt.span);
        return _execForAsyncTail(stmt, env, material, i, yieldFirst: true);
      }
      if (maxLoopIterations != null && i >= maxLoopIterations!) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.loopLimit,
          'Loop exceeded maximum iteration limit ($maxLoopIterations).',
          stmt.span,
          stackFrames: stackFrames,
        );
      }
      final iterEnv = _buildForIterEnv(stmt, env, material, i);
      try {
        final r = _execBlockFast(stmt.body, iterEnv, hoistDeclarations: true);
        if (r is Future<Object?>) {
          return _execForAsyncAfterBody(stmt, env, material, i, r);
        }
      } on ContinueSignal catch (sig) {
        if (sig.label != null) rethrow;
      } on BreakSignal catch (sig) {
        if (sig.label != null) rethrow;
        return sig.value;
      }
    }
    if (stmt.elseBody.isNotEmpty) {
      return _execBlockFast(stmt.elseBody, env.child(),
          hoistDeclarations: true);
    }
    return null;
  }

  List<Object?> _materializeForIterable(
      Object? iterableVal, Object? stepVal, ForStatement stmt) {
    List<Object?> material;
    if (iterableVal is QudsRange) {
      if (stmt.step != null) {
        final stepInt = _expectInt(stepVal, stmt.step!.span);
        if (stepInt == 0) {
          throw QudsRuntimeException(
              'For-loop step cannot be 0.', stmt.step!.span);
        }
        material = iterableVal.withStep(stepInt).toList();
      } else {
        material = iterableVal.toList();
      }
    } else if (iterableVal is List) {
      material = List<Object?>.from(iterableVal);
    } else if (iterableVal is Iterable) {
      material = iterableVal.toList();
    } else if (iterableVal is String) {
      material = iterableVal.split('');
    } else {
      throw QudsRuntimeException(
        'Cannot iterate over value of type `${qudsTypeName(iterableVal)}`.',
        stmt.iterable.span,
      );
    }
    _checkCollectionSize(material.length, stmt.iterable.span);
    return material;
  }

  QudsEnvironment _buildForIterEnv(
    ForStatement stmt,
    QudsEnvironment env,
    List<Object?> material,
    int i,
  ) {
    final item = material[i];
    final iterEnv = env.child();
    if (stmt.index != null) {
      if (item is QudsRecord && item.positional.length >= 2) {
        iterEnv.define(stmt.index!, item.positional[0]);
        iterEnv.define(stmt.name, item.positional[1]);
      } else if (item is MapEntry) {
        iterEnv.define(stmt.index!, item.key);
        iterEnv.define(stmt.name, item.value);
      } else {
        iterEnv.define(stmt.index!, i);
        iterEnv.define(stmt.name, item);
      }
    } else {
      iterEnv.define(stmt.name, item);
    }
    iterEnv.define(
      r'$',
      QudsLoopContext(
        index: i,
        count: material.length,
        first: i == 0,
        last: i == material.length - 1,
        item: item,
        hasItem: true,
        prev: i > 0 ? material[i - 1] : null,
        next: i + 1 < material.length ? material[i + 1] : null,
      ),
    );
    return iterEnv;
  }

  Future<Object?> _execForAsyncAfterBody(
    ForStatement stmt,
    QudsEnvironment env,
    List<Object?> material,
    int index,
    Future<Object?> bodyFuture,
  ) async {
    try {
      await bodyFuture;
    } on ContinueSignal catch (sig) {
      if (sig.label != null) rethrow;
    } on BreakSignal catch (sig) {
      if (sig.label != null) rethrow;
      return sig.value;
    }
    return _execForAsyncTail(stmt, env, material, index + 1, yieldFirst: false);
  }

  Future<Object?> _execForAsyncTail(
    ForStatement stmt,
    QudsEnvironment env,
    List<Object?> material,
    int startIndex, {
    required bool yieldFirst,
  }) async {
    if (yieldFirst) {
      await Future<void>.delayed(Duration.zero);
    }
    for (var i = startIndex; i < material.length; i++) {
      if (i > startIndex || !yieldFirst) {
        final t = _tick(stmt.span);
        if (t != null) await t;
      }
      if (maxLoopIterations != null && i >= maxLoopIterations!) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.loopLimit,
          'Loop exceeded maximum iteration limit ($maxLoopIterations).',
          stmt.span,
          stackFrames: stackFrames,
        );
      }
      final iterEnv = _buildForIterEnv(stmt, env, material, i);
      try {
        final r = _execBlockFast(stmt.body, iterEnv, hoistDeclarations: true);
        if (r is Future<Object?>) await r;
      } on ContinueSignal catch (sig) {
        if (sig.label != null) rethrow;
      } on BreakSignal catch (sig) {
        if (sig.label != null) rethrow;
        return sig.value;
      }
    }
    if (stmt.elseBody.isNotEmpty) {
      final r =
          _execBlockFast(stmt.elseBody, env.child(), hoistDeclarations: true);
      if (r is Future<Object?>) await r;
    }
    return null;
  }

  FutureOr<Object?> _evalExprFast(Expression expr, QudsEnvironment env) {
    switch (expr) {
      case Literal(:final value):
        return value;
      case DurationLiteral(:final microseconds):
        return Duration(microseconds: microseconds);
      case Identifier(:final name):
        if (name == 'missing') return QudsMissing.instance;
        return env.get(name, expr.span);
      case ThisExpression():
        return env.get('this', expr.span);
      case UnaryExpression(:final operator, :final operand):
        final v = _evalExprFast(operand, env);
        if (v is Future<Object?>) {
          return v.then((val) => _applyUnaryOp(operator, val, expr.span));
        }
        return _applyUnaryOp(operator, v, expr.span);
      case BinaryExpression(:final left, :final operator, :final right):
        if (operator == '&&' || operator == 'and') {
          final l = _evalExprFast(left, env);
          if (l is Future<Object?>) {
            return l.then((lv) async => _expectBool(lv, left.span)
                ? _expectBool(await _evalExprFast(right, env), right.span)
                : false);
          }
          if (!_expectBool(l, left.span)) return false;
          final r = _evalExprFast(right, env);
          if (r is Future<Object?>) {
            return r.then((rv) => _expectBool(rv, right.span));
          }
          return _expectBool(r, right.span);
        }
        if (operator == '||' || operator == 'or') {
          final l = _evalExprFast(left, env);
          if (l is Future<Object?>) {
            return l.then((lv) async => _expectBool(lv, left.span)
                ? true
                : _expectBool(await _evalExprFast(right, env), right.span));
          }
          if (_expectBool(l, left.span)) return true;
          final r = _evalExprFast(right, env);
          if (r is Future<Object?>) {
            return r.then((rv) => _expectBool(rv, right.span));
          }
          return _expectBool(r, right.span);
        }
        if (operator == '??') {
          final l = _evalExprFast(left, env);
          if (l is Future<Object?>) {
            return l.then((lv) => (lv != null && lv is! QudsMissing)
                ? lv
                : _evalExprFast(right, env));
          }
          if (l != null && l is! QudsMissing) return l;
          return _evalExprFast(right, env);
        }
        final l = _evalExprFast(left, env);
        if (l is Future<Object?>) {
          return l.then((lv) async {
            final rv = await _evalExprFast(right, env);
            return _applyBinaryFast(lv, operator, rv, expr.span);
          });
        }
        final r = _evalExprFast(right, env);
        if (r is Future<Object?>) {
          return r.then((rv) => _applyBinaryFast(l, operator, rv, expr.span));
        }
        return _applyBinaryFast(l, operator, r, expr.span);
      case IfExpression(:final condition, :final thenValue, :final elseValue):
        final cond = _evalExprFast(condition, env);
        if (cond is Future<Object?>) {
          return cond.then((c) => _expectBool(c, condition.span)
              ? _evalExprFast(thenValue, env)
              : _evalExprFast(elseValue, env));
        }
        return _expectBool(cond, condition.span)
            ? _evalExprFast(thenValue, env)
            : _evalExprFast(elseValue, env);
      case RangeExpression(:final start, :final end, :final inclusive):
        final s = _evalExprFast(start, env);
        if (s is Future<Object?>) {
          return s.then((sv) async {
            final ev = await _evalExprFast(end, env);
            return QudsRange(
                _expectInt(sv, start.span), _expectInt(ev, end.span),
                inclusive: inclusive);
          });
        }
        final e = _evalExprFast(end, env);
        if (e is Future<Object?>) {
          return e.then((ev) => QudsRange(
              _expectInt(s, start.span), _expectInt(ev, end.span),
              inclusive: inclusive));
        }
        return QudsRange(_expectInt(s, start.span), _expectInt(e, end.span),
            inclusive: inclusive);
      case IndexExpression(:final object, :final index):
        final container = _evalExprFast(object, env);
        if (container is Future<Object?>) {
          return container.then((c) async {
            final i = await _evalExprFast(index, env);
            return _evalIndexReadFast(c, i, expr.span);
          });
        }
        final idx = _evalExprFast(index, env);
        if (idx is Future<Object?>) {
          return idx.then((i) => _evalIndexReadFast(container, i, expr.span));
        }
        return _evalIndexReadFast(container, idx, expr.span);
      case MemberAccess(:final object, :final name, :final nullAware):
        final recv = _evalExprFast(object, env);
        if (recv is Future<Object?>) {
          return recv
              .then((r) => _evalMemberReadFast(r, name, nullAware, expr.span));
        }
        return _evalMemberReadFast(recv, name, nullAware, expr.span);
      case ListExpression(:final elements, :final nullAware):
        if (nullAware.any((e) => e)) return _evalExpr(expr, env);
        final out = <Object?>[];
        for (var i = 0; i < elements.length; i++) {
          final el = elements[i];
          if (el is SpreadElement ||
              el is NullAwareElement ||
              el is CollectionIf ||
              el is CollectionFor) {
            return _evalListTailAsync(out, elements, i, env, expr.span);
          }
          final v = _evalExprFast(el, env);
          if (v is Future<Object?>) {
            return v.then((val) {
              out.add(val);
              _checkCollectionSize(out.length, expr.span);
              return _evalListTailAsync(out, elements, i + 1, env, expr.span);
            });
          }
          out.add(v);
        }
        _checkCollectionSize(out.length, expr.span);
        return out;
      case InterpolatedString(:final parts):
        final buf = StringBuffer();
        for (var i = 0; i < parts.length; i++) {
          final v = _evalExprFast(parts[i], env);
          if (v is Future<Object?>) {
            return v.then((val) async {
              final f = formatValueForOutput(val, expr.span);
              buf.write(f is Future<String> ? await f : f);
              _checkStringLength(buf.length, expr.span);
              for (var j = i + 1; j < parts.length; j++) {
                final fj = formatValueForOutput(
                    await _evalExprFast(parts[j], env), expr.span);
                buf.write(fj is Future<String> ? await fj : fj);
                _checkStringLength(buf.length, expr.span);
              }
              return buf.toString();
            });
          }
          final f = formatValueForOutput(v, expr.span);
          if (f is Future<String>) {
            return f.then((str) async {
              buf.write(str);
              _checkStringLength(buf.length, expr.span);
              for (var j = i + 1; j < parts.length; j++) {
                final fj = formatValueForOutput(
                    await _evalExprFast(parts[j], env), expr.span);
                buf.write(fj is Future<String> ? await fj : fj);
                _checkStringLength(buf.length, expr.span);
              }
              return buf.toString();
            });
          }
          buf.write(f);
          _checkStringLength(buf.length, expr.span);
        }
        return buf.toString();
      case TypeApplication(:final callee):
        return _evalExprFast(callee, env);
      case TypeTestExpression(:final operand, :final operator, :final type):
        final v = _evalExprFast(operand, env);
        if (v is Future<Object?>) {
          return v.then(
              (val) => _applyTypeTestSync(val, operator, type, expr.span));
        }
        return _applyTypeTestSync(v, operator, type, expr.span);
      case ConversionExpression(:final operand, :final type, :final safe):
        final v = _evalExprFast(operand, env);
        if (v is Future<Object?>) {
          return v.then((val) => _applyConversion(val, type, safe, expr.span));
        }
        return _applyConversion(v, type, safe, expr.span);
      case CallExpression(:final callee, :final arguments):
        return _evalCallFast(callee, arguments, env, expr.span);
      default:
        return _evalExpr(expr, env);
    }
  }

  Future<List<Object?>> _evalListTailAsync(
    List<Object?> out,
    List<Expression> elements,
    int startIndex,
    QudsEnvironment env,
    SourceSpan span,
  ) async {
    for (var i = startIndex; i < elements.length; i++) {
      await _collectElement(elements[i], out, env);
      _checkCollectionSize(out.length, span);
    }
    return out;
  }

  Object? _applyTypeTestSync(
      Object? v, String operator, String type, SourceSpan span) {
    final matched = _matchesType(v, type);
    if (operator == 'is') return matched;
    if (operator == 'is!') return !matched;
    if (operator == 'as') {
      if (!matched) {
        throw QudsRuntimeException(
          'Type cast failed: `${qudsTypeName(v)}` is not `$type`.',
          span,
          code: 'R300',
        );
      }
      return v;
    }
    throw QudsRuntimeException('Unknown type operator `$operator`.', span);
  }

  FutureOr<Object?> _evalIndexReadFast(
      Object? container, Object? idx, SourceSpan span) {
    if (_extensionOperators.isNotEmpty) {
      final overload = _resolveOperatorOverload(container, '[]', [idx]);
      if (overload != null) {
        final (fn, isExt) = overload;
        if (isExt) {
          return _invokeExtension(fn, container, [idx], const {}, span);
        }
        return _invokeUserFunctionFast(
            fn.bind(container as QudsInstance), [idx], const {}, span);
      }
    }
    if (container is List && idx is int) {
      final realIdx = idx < 0 ? container.length + idx : idx;
      if (realIdx < 0 || realIdx >= container.length) {
        throw QudsRuntimeException(
          'Index $idx out of bounds for List of length ${container.length}.',
          span,
          code: 'R302',
        );
      }
      return container[realIdx];
    }
    if (container is Map) return container[idx];
    if (container is String && idx is int) {
      final realIdx = idx < 0 ? container.length + idx : idx;
      if (realIdx < 0 || realIdx >= container.length) {
        throw QudsRuntimeException(
          'Index $idx out of bounds for String of length ${container.length}.',
          span,
          code: 'R302',
        );
      }
      return container[realIdx];
    }
    return _evalIndexRead(container, idx, span);
  }

  FutureOr<Object?> _applyBinaryFast(
    Object? left,
    String op,
    Object? right,
    SourceSpan span,
  ) {
    if (left is QudsInstance || _extensionOperators.isNotEmpty) {
      final overload = _resolveOperatorOverload(left, op, [right]);
      if (overload != null) {
        final (fn, isExt) = overload;
        if (isExt) {
          return _invokeExtension(fn, left, [right], const {}, span);
        }
        return _invokeUserFunctionFast(
            fn.bind(left as QudsInstance), [right], const {}, span);
      }
    }
    switch (op) {
      case '==':
        return qudsEquals(left, right);
      case '!=':
        return !qudsEquals(left, right);
      case '+':
        if (left is num && right is num) return left + right;
        if (left is BigInt && right is BigInt) return left + right;
        if (left is String) {
          if (right is String) {
            final out = left + right;
            _checkStringLength(out.length, span);
            return out;
          }
          final rhs = formatValueForOutput(right, span);
          if (rhs is Future<String>) {
            return rhs.then((s) {
              final out = left + s;
              _checkStringLength(out.length, span);
              return out;
            });
          }
          final out = left + rhs;
          _checkStringLength(out.length, span);
          return out;
        }
        return _applyBinaryOp(left, op, right, span);
      case '-':
        if (left is num && right is num) return left - right;
        if (left is BigInt && right is BigInt) return left - right;
        return _applyBinaryOp(left, op, right, span);
      case '*':
        if (left is num && right is num) return left * right;
        if (left is BigInt && right is BigInt) return left * right;
        return _applyBinaryOp(left, op, right, span);
      case '/':
        if (left is num && right is num) return left / right;
        if (left is BigInt && right is BigInt) return left / right;
        return _applyBinaryOp(left, op, right, span);
      case '~/':
        if (left is num && right is num) {
          if (right == 0) {
            throw QudsRuntimeException('Integer division by zero.', span);
          }
          return left ~/ right;
        }
        if (left is BigInt && right is BigInt) {
          if (right == BigInt.zero) {
            throw QudsRuntimeException('Integer division by zero.', span);
          }
          return left ~/ right;
        }
        return _applyBinaryOp(left, op, right, span);
      case '%':
        if (left is num && right is num) {
          if (right == 0) {
            throw QudsRuntimeException('Remainder by zero.', span);
          }
          return left % right;
        }
        if (left is BigInt && right is BigInt) {
          if (right == BigInt.zero) {
            throw QudsRuntimeException('Remainder by zero.', span);
          }
          return left % right;
        }
        return _applyBinaryOp(left, op, right, span);
      case '**':
        if (left is num && right is num) return math.pow(left, right);
        return _applyBinaryOp(left, op, right, span);
      case '<':
        if (left is num && right is num) return left < right;
        if (left is BigInt && right is BigInt) return left < right;
        return _compare(left, right, span) < 0;
      case '<=':
        if (left is num && right is num) return left <= right;
        if (left is BigInt && right is BigInt) return left <= right;
        return _compare(left, right, span) <= 0;
      case '>':
        if (left is num && right is num) return left > right;
        if (left is BigInt && right is BigInt) return left > right;
        return _compare(left, right, span) > 0;
      case '>=':
        if (left is num && right is num) return left >= right;
        if (left is BigInt && right is BigInt) return left >= right;
        return _compare(left, right, span) >= 0;
      case '&':
        if (left is int && right is int) return left & right;
        if (left is BigInt && right is BigInt) return left & right;
        return _applyBinaryOp(left, op, right, span);
      case '|':
        if (left is int && right is int) return left | right;
        if (left is BigInt && right is BigInt) return left | right;
        return _applyBinaryOp(left, op, right, span);
      case '^':
        if (left is int && right is int) return left ^ right;
        if (left is BigInt && right is BigInt) return left ^ right;
        return _applyBinaryOp(left, op, right, span);
      case '<<':
        if (left is int && right is int) return left << right;
        if (left is BigInt && right is int) return left << right;
        return _applyBinaryOp(left, op, right, span);
      case '>>':
        if (left is int && right is int) return left >> right;
        if (left is BigInt && right is int) return left >> right;
        return _applyBinaryOp(left, op, right, span);
      default:
        return _applyBinaryOp(left, op, right, span);
    }
  }

  FutureOr<Object?> _evalMemberReadFast(
    Object? receiver,
    String name,
    bool nullAware,
    SourceSpan span,
  ) {
    if (receiver == null) {
      if (nullAware) return null;
      throw QudsRuntimeException('Cannot access `.$name` on `null`.', span,
          code: 'R301');
    }
    if (receiver is QudsInstance) {
      if (receiver.fields.containsKey(name)) return receiver.fields[name];
      final prop = receiver.qudsClass.lookupProperty(name);
      if (prop == null && _findFieldDecl(receiver.qudsClass, name) == null) {
        final method = receiver.qudsClass.lookupMethod(name);
        if (method != null) return method.bind(receiver);
      }
      return _evalMemberRead(receiver, name, nullAware, span);
    }
    if (receiver is QudsNamespace) return receiver.getMember(name, span);
    if (receiver is QudsCallableNamespace) {
      return receiver.getMember(name, span);
    }
    if (receiver is QudsLoopContext) return receiver.getMember(name, span);
    if (receiver is List) {
      return switch (name) {
        'length' => receiver.length,
        'isEmpty' => receiver.isEmpty,
        'isNotEmpty' => receiver.isNotEmpty,
        'first' => receiver.first,
        'last' => receiver.last,
        _ => _evalMemberRead(receiver, name, nullAware, span),
      };
    }
    if (receiver is String) {
      return switch (name) {
        'length' => receiver.length,
        'isEmpty' => receiver.isEmpty,
        'isNotEmpty' => receiver.isNotEmpty,
        _ => _evalMemberRead(receiver, name, nullAware, span),
      };
    }
    if (receiver is Map) {
      return switch (name) {
        'length' => receiver.length,
        'isEmpty' => receiver.isEmpty,
        'isNotEmpty' => receiver.isNotEmpty,
        _ => _evalMemberRead(receiver, name, nullAware, span),
      };
    }
    if (receiver is num) {
      return switch (name) {
        'abs' => receiver.abs(),
        'isNaN' => receiver.isNaN,
        'isFinite' => receiver.isFinite,
        'isInfinite' => receiver.isInfinite,
        'isNegative' => receiver.isNegative,
        'sign' => receiver.sign,
        'floor' => receiver.floor(),
        'ceil' => receiver.ceil(),
        'round' => receiver.round(),
        'truncate' => receiver.truncate(),
        'toDouble' => receiver.toDouble(),
        'toInt' => receiver.toInt(),
        _ => _evalMemberRead(receiver, name, nullAware, span),
      };
    }
    if (receiver is BigInt) {
      return switch (name) {
        'sign' => receiver.sign,
        'isNegative' => receiver.isNegative,
        'isEven' => receiver.isEven,
        'isOdd' => receiver.isOdd,
        'bitLength' => receiver.bitLength,
        'toDouble' => receiver.toDouble(),
        'toInt' => receiver.toInt(),
        _ => _evalMemberRead(receiver, name, nullAware, span),
      };
    }
    return _evalMemberRead(receiver, name, nullAware, span);
  }

  FutureOr<Object?> _evalCallFast(
    Expression calleeExpr,
    List<Argument> arguments,
    QudsEnvironment env,
    SourceSpan span,
  ) {
    if (onBeforeCall != null) {
      return _evalCall(calleeExpr, arguments, env, span);
    }

    if (calleeExpr is MemberAccess) {
      final recv = _evalExprFast(calleeExpr.object, env);
      if (recv is Future<Object?>) {
        return recv.then((r) =>
            _evalMemberCallWithRecvFast(r, calleeExpr, arguments, env, span));
      }
      return _evalMemberCallWithRecvFast(
          recv, calleeExpr, arguments, env, span);
    }

    final callee = _evalExprFast(calleeExpr, env);
    if (callee is Future<Object?>) {
      return callee
          .then((c) => _evalArgsAndInvokeFast(c, arguments, env, span));
    }
    return _evalArgsAndInvokeFast(callee, arguments, env, span);
  }

  FutureOr<Object?> _evalMemberCallWithRecvFast(
    Object? recv,
    MemberAccess calleeExpr,
    List<Argument> arguments,
    QudsEnvironment env,
    SourceSpan span,
  ) {
    if (recv == null && calleeExpr.nullAware) return null;

    if (recv is QudsClass) {
      final namedCtor = recv.constructors[calleeExpr.name];
      if (namedCtor != null) {
        return _evalArgsThen(
          arguments,
          env,
          (pos, named) =>
              _instantiateClass(recv, pos, named, span, ctor: namedCtor),
        );
      }
      final staticMethod = recv.staticMethods[calleeExpr.name];
      if (staticMethod != null) {
        return _evalArgsAndInvokeFast(staticMethod, arguments, env, span);
      }
    }

    if (recv is QudsNamespace || recv is QudsCallableNamespace) {
      final member = recv is QudsNamespace
          ? recv.getMember(calleeExpr.name, calleeExpr.span)
          : (recv as QudsCallableNamespace)
              .getMember(calleeExpr.name, calleeExpr.span);
      return _evalArgsAndInvokeFast(member, arguments, env, span);
    }

    if (arguments.every((a) => a.name == null && a.value is! SpreadElement)) {
      if (recv is num) {
        if (arguments.isEmpty) {
          switch (calleeExpr.name) {
            case 'abs':
              return recv.abs();
            case 'truncateToDouble':
              return recv.truncateToDouble();
            case 'floorToDouble':
              return recv.floorToDouble();
            case 'ceilToDouble':
              return recv.ceilToDouble();
            case 'roundToDouble':
              return recv.roundToDouble();
            case 'truncate':
              return recv.truncate();
            case 'floor':
              return recv.floor();
            case 'ceil':
              return recv.ceil();
            case 'round':
              return recv.round();
            case 'toDouble':
              return recv.toDouble();
            case 'toInt':
              return recv.toInt();
          }
        }
        if (calleeExpr.name == 'toStringAsFixed' && arguments.length == 1) {
          return _evalArgsThen(
            arguments,
            env,
            (pos, _) => recv
                .toStringAsFixed(_expectInt(pos[0], arguments[0].value.span)),
          );
        }
      }

      if (recv is BigInt) {
        if (arguments.isEmpty) {
          switch (calleeExpr.name) {
            case 'abs':
              return recv.abs();
            case 'toDouble':
              return recv.toDouble();
            case 'toInt':
              return recv.toInt();
          }
        }
        if (calleeExpr.name == 'gcd' && arguments.length == 1) {
          return _evalArgsThen(
              arguments, env, (pos, _) => recv.gcd(pos[0] as BigInt));
        }
        if (calleeExpr.name == 'pow' && arguments.length == 1) {
          return _evalArgsThen(
            arguments,
            env,
            (pos, _) => recv.pow(_expectInt(pos[0], arguments[0].value.span)),
          );
        }
      }

      if (recv is List) {
        if (calleeExpr.name == 'add' && arguments.length == 1) {
          return _evalArgsThen(arguments, env, (pos, _) {
            recv.add(pos[0]);
            _checkCollectionSize(recv.length, span);
            return null;
          });
        }
        if (calleeExpr.name == 'removeAt' && arguments.length == 1) {
          return _evalArgsThen(
            arguments,
            env,
            (pos, _) =>
                recv.removeAt(_expectInt(pos[0], arguments[0].value.span)),
          );
        }
        if (calleeExpr.name == 'contains' && arguments.length == 1) {
          return _evalArgsThen(
            arguments,
            env,
            (pos, _) => recv.any((e) => qudsEquals(e, pos[0])),
          );
        }
      }

      if (recv is String && arguments.length == 1) {
        switch (calleeExpr.name) {
          case 'split':
            return _evalArgsThen(
                arguments, env, (pos, _) => recv.split('${pos[0]}'));
          case 'startsWith':
            return _evalArgsThen(
                arguments, env, (pos, _) => recv.startsWith('${pos[0]}'));
          case 'endsWith':
            return _evalArgsThen(
                arguments, env, (pos, _) => recv.endsWith('${pos[0]}'));
          case 'contains':
            return _evalArgsThen(
                arguments, env, (pos, _) => recv.contains('${pos[0]}'));
          case 'indexOf':
            return _evalArgsThen(
                arguments, env, (pos, _) => recv.indexOf('${pos[0]}'));
        }
      }
    }

    final member =
        _evalMemberReadFast(recv, calleeExpr.name, false, calleeExpr.span);
    if (member is Future<Object?>) {
      return member
          .then((m) => _evalArgsAndInvokeFast(m, arguments, env, span));
    }
    return _evalArgsAndInvokeFast(member, arguments, env, span);
  }

  FutureOr<Object?> _evalArgsThen(
    List<Argument> arguments,
    QudsEnvironment env,
    FutureOr<Object?> Function(List<Object?> pos, Map<String, Object?> named)
        action,
  ) {
    final pos = <Object?>[];
    final named = <String, Object?>{};
    for (var i = 0; i < arguments.length; i++) {
      final arg = arguments[i];
      if (arg.value is SpreadElement) {
        return _evalArgsTailAsync(pos, named, arguments, i, env, action);
      }
      final v = _evalExprFast(arg.value, env);
      if (v is Future<Object?>) {
        return v.then((val) {
          if (arg.name != null) {
            named[arg.name!] = val;
          } else {
            pos.add(val);
          }
          return _evalArgsTailAsync(pos, named, arguments, i + 1, env, action);
        });
      }
      if (arg.name != null) {
        named[arg.name!] = v;
      } else {
        pos.add(v);
      }
    }
    return action(pos, named);
  }

  Future<Object?> _evalArgsTailAsync(
    List<Object?> pos,
    Map<String, Object?> named,
    List<Argument> arguments,
    int startIndex,
    QudsEnvironment env,
    FutureOr<Object?> Function(List<Object?> pos, Map<String, Object?> named)
        action,
  ) async {
    for (var i = startIndex; i < arguments.length; i++) {
      final arg = arguments[i];
      if (arg.name != null) {
        named[arg.name!] = await _evalExprFast(arg.value, env);
      } else if (arg.value is SpreadElement) {
        final spread = arg.value as SpreadElement;
        final seq = await _evalExprFast(spread.operand, env);
        if (seq is Iterable) {
          pos.addAll(seq);
        } else if (seq == null && spread.nullAware) {
          continue;
        } else {
          throw QudsRuntimeException(
              'Spread argument must be Iterable.', spread.span);
        }
      } else {
        pos.add(await _evalExprFast(arg.value, env));
      }
    }
    final res = action(pos, named);
    return res is Future<Object?> ? await res : res;
  }

  FutureOr<Object?> _evalArgsAndInvokeFast(
    Object? callee,
    List<Argument> arguments,
    QudsEnvironment env,
    SourceSpan span,
  ) =>
      _evalArgsThen(
        arguments,
        env,
        (pos, named) => _invokeCallableFast(callee, pos, named, span),
      );

  FutureOr<Object?> _invokeCallableFast(
    Object? callee,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span,
  ) {
    if (_callDepth >= maxCallDepth) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.callDepth,
        'Maximum call depth ($maxCallDepth) exceeded.',
        span,
        stackFrames: stackFrames,
      );
    }
    if (callee is QudsNativeFunction && callee.isSync) {
      if (callee.requiredCapability != null) {
        checkCapabilitySync?.call(
            callee.name, callee.requiredCapability!, span);
      }
      final ctx = QudsCallContext(
        span: span,
        functionName: callee.name,
        emitOutput: (out) => onOutput(out, span),
        emitPrint: (line) => onPrint(line, span),
        invokeCallable: invokeCallable,
        interactiveInputs: interactiveInputs,
      );
      _callDepth++;
      try {
        final result = callee.callback(positional, named, ctx);
        return result is Future ? result : result;
      } on QudsRuntimeException {
        rethrow;
      } on QudsThrownValue {
        rethrow;
      } catch (err) {
        throw QudsThrownValue(err, span, stackFrames);
      } finally {
        _callDepth--;
      }
    }
    if (callee is QudsUserFunction &&
        !callee.isAsync &&
        callee.generator.isEmpty) {
      return _invokeUserFunctionFast(callee, positional, named, span);
    }
    if (callee is QudsOverloadSet) {
      final selected = _selectOverload(callee, positional, named, span);
      if (!selected.isAsync && selected.generator.isEmpty) {
        return _invokeUserFunctionFast(selected, positional, named, span);
      }
    }
    if (callee is QudsClass &&
        callee.constructors[''] == null &&
        callee.declaration.requirements.isEmpty) {
      return _instantiateClassFast(callee, positional, named, span);
    }
    return invokeCallable(callee, positional, named, span);
  }

  FutureOr<Object?> _invokeUserFunctionFast(
    QudsUserFunction fn,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span,
  ) {
    final callEnv = fn.closure.child(isFunctionBoundary: true);
    if (fn.receiver != null) {
      callEnv.define('this', fn.receiver);
      if (fn.receiver!.qudsClass.superclass != null) {
        callEnv.define(
          'super',
          QudsSuperProxy(fn.receiver!, fn.receiver!.qudsClass.superclass!),
        );
      }
      _exposeInstanceFields(fn.receiver!, callEnv);
    }

    // Bind parameters; fall back seamlessly to async helper only if a default value is async.
    var posIdx = 0;
    final usedNamed = <String>{};
    for (var i = 0; i < fn.parameters.length; i++) {
      final param = fn.parameters[i];
      if (param.variadic) {
        final rest = posIdx < positional.length
            ? positional.sublist(posIdx)
            : <Object?>[];
        posIdx = positional.length;
        callEnv.define(param.name, rest, mutable: param.mutable);
        continue;
      }
      if (named.containsKey(param.name)) {
        usedNamed.add(param.name);
        final val = named[param.name];
        callEnv.define(
          param.name,
          param.type.startsWith('Optional') &&
                  val is! QudsOptional &&
                  val is! QudsMissing
              ? QudsOptional.present(val)
              : val,
          mutable: param.mutable,
          declaredType: param.type,
        );
      } else if (!param.isNamed && posIdx < positional.length) {
        final val = positional[posIdx++];
        callEnv.define(
          param.name,
          param.type.startsWith('Optional') &&
                  val is! QudsOptional &&
                  val is! QudsMissing
              ? QudsOptional.present(val)
              : val,
          mutable: param.mutable,
          declaredType: param.type,
        );
      } else if (param.kind == ParameterKind.optionalNamed &&
          posIdx < positional.length) {
        callEnv.define(param.name, positional[posIdx++],
            mutable: param.mutable, declaredType: param.type);
      } else if (param.defaultValue != null) {
        final defVal = _evalExprFast(param.defaultValue!, callEnv);
        if (defVal is Future<Object?>) {
          return _invokeUserFunction(fn, positional, named, span);
        }
        callEnv.define(param.name, defVal,
            mutable: param.mutable, declaredType: param.type);
      } else if (param.type.startsWith('Optional')) {
        callEnv.define(param.name, const QudsOptional.missing(),
            mutable: param.mutable, declaredType: param.type);
      } else {
        throw QudsRuntimeException(
          'Missing required argument `${param.name}`.',
          span,
          code: 'E500',
        );
      }
    }
    if (posIdx < positional.length) {
      throw QudsRuntimeException(
        'Too many positional arguments: expected at most $posIdx, got ${positional.length}.',
        span,
        code: 'E500',
      );
    }
    for (final key in named.keys) {
      if (!usedNamed.contains(key)) {
        throw QudsRuntimeException(
          'Unknown named argument `$key`.',
          span,
          code: 'E500',
        );
      }
    }

    _callDepth++;
    try {
      FutureOr<Object?> res;
      if (fn.expressionBody != null) {
        res = _evalExprFast(fn.expressionBody!, callEnv);
      } else if (fn.body != null) {
        res = _execBlockFast(fn.body!, callEnv, hoistDeclarations: true);
      } else {
        res = null;
      }
      if (res is Future<Object?>) {
        return _finishUserFnAsync(res, fn, callEnv);
      }
      _callDepth--;
      if (fn.receiver != null) {
        _syncInstanceFieldsBack(fn.receiver!, callEnv);
      }
      return fn.expressionBody != null ? res : null;
    } on ReturnSignal catch (ret) {
      _callDepth--;
      if (fn.receiver != null) {
        _syncInstanceFieldsBack(fn.receiver!, callEnv);
      }
      return ret.value;
    } on PropagateErrorSignal catch (prop) {
      _callDepth--;
      if (fn.receiver != null) {
        _syncInstanceFieldsBack(fn.receiver!, callEnv);
      }
      return prop.errorResult;
    } catch (_) {
      _callDepth--;
      if (fn.receiver != null) {
        _syncInstanceFieldsBack(fn.receiver!, callEnv);
      }
      rethrow;
    }
  }

  Future<Object?> _finishUserFnAsync(
    Future<Object?> pending,
    QudsUserFunction fn,
    QudsEnvironment callEnv,
  ) async {
    try {
      final res = await pending;
      return fn.expressionBody != null ? res : null;
    } on ReturnSignal catch (ret) {
      return ret.value;
    } on PropagateErrorSignal catch (prop) {
      return prop.errorResult;
    } finally {
      _callDepth--;
      if (fn.receiver != null) {
        _syncInstanceFieldsBack(fn.receiver!, callEnv);
      }
    }
  }

  FutureOr<QudsInstance> _instantiateClassFast(
    QudsClass klass,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span,
  ) {
    final allFields = _collectAllInstanceFields(klass);
    final fields = <String, Object?>{};
    for (final f in allFields) {
      if (f.isEvent) {
        fields[f.name] = QudsEventChannel(f.name);
      } else if (f.initializer != null) {
        final v = _evalExprFast(f.initializer!, klass.definingEnv);
        if (v is Future<Object?>) {
          return _instantiateClass(klass, positional, named, span);
        }
        fields[f.name] = v;
      } else if (!f.requiredField && f.lazyBody == null) {
        fields[f.name] = null;
      }
    }
    final instance = QudsInstance(klass, fields);
    var posIdx = 0;
    for (final f in allFields) {
      if (f.isStatic || f.isEvent || f.lazyBody != null || f.isConst) continue;
      if (named.containsKey(f.name)) {
        instance.fields[f.name] = named[f.name];
      } else if (posIdx < positional.length &&
          (f.requiredField || f.initializer == null || named.isEmpty)) {
        instance.fields[f.name] = positional[posIdx++];
      } else if (f.requiredField && !instance.fields.containsKey(f.name)) {
        throw QudsRuntimeException(
          'Missing required field `${f.name}` for `${klass.name}`.',
          span,
          code: 'E500',
        );
      }
    }
    return instance;
  }

  // -------------------------------------------------------------------------
  // Universal Register VM Runtime Bridge
  // -------------------------------------------------------------------------

  /// Starts budget accounting for a Universal Register VM execution.
  void vmBeginRun({bool resetBudget = true}) {
    if (resetBudget) {
      _steps = 0;
      _stopped = false;
      _stopwatch = Stopwatch()..start();
    }
  }

  /// Stops budget stopwatch at the end of a Universal Register VM execution.
  void vmEndRun({bool resetBudget = true}) {
    if (resetBudget) {
      _stopwatch?.stop();
    }
  }

  /// Advances step counter and yields cooperatively when required.
  Future<void>? vmTick(SourceSpan span) => _tick(span);

  /// Enforces collection size policy.
  void vmCheckCollectionSize(int size, SourceSpan span) =>
      _checkCollectionSize(size, span);

  /// Enforces string length policy.
  void vmCheckStringLength(int length, SourceSpan span) =>
      _checkStringLength(length, span);

  /// Whether any reactive `computed` cells or `watch` blocks are registered.
  bool get vmHasReactiveState =>
      _computedCells.isNotEmpty || _watchers.isNotEmpty;

  /// Flushes reactive `computed` cells and `watch` listeners.
  Future<void> vmNotifyStateChanged() => _notifyStateChanged();

  /// Hoists a list of function declarations into [env].
  void vmHoistFunctions(List<Statement> statements, QudsEnvironment env) =>
      _hoistFunctions(statements, env);

  /// Executes a single AST statement in [env].
  Future<Object?> vmExecStatement(
    Statement stmt,
    QudsEnvironment env, {
    bool alreadyHoisted = true,
  }) =>
      _execStatement(stmt, env, alreadyHoisted: alreadyHoisted);

  /// Evaluates a single AST expression in [env].
  FutureOr<Object?> vmEvalExpr(Expression expr, QudsEnvironment env) =>
      _evalExprFast(expr, env);

  /// Reads a member on any Quds or Dart runtime value.
  FutureOr<Object?> vmEvalMemberRead(
    Object? receiver,
    String name,
    bool nullAware,
    SourceSpan span,
  ) =>
      _evalMemberReadFast(receiver, name, nullAware, span);

  /// Assigns a member on any Quds runtime object/class with full semantics.
  Future<void> vmExecMemberAssign(
    Object? receiver,
    String name,
    String operator,
    Object? rhsValue,
    QudsEnvironment env,
    SourceSpan span,
  ) async {
    if (!allowMutation) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.featureDisabled,
        'Member mutation (`.$name`) is disabled by the active execution policy.',
        span,
        stackFrames: stackFrames,
      );
    }
    Object? newValue;
    if (operator == '=') {
      newValue = rhsValue;
    } else {
      final current = await _evalMemberRead(receiver, name, false, span);
      if (operator == '??=' && current != null) return;
      if (operator == '??=') {
        newValue = rhsValue;
      } else {
        final baseOp = operator.substring(0, operator.length - 1);
        newValue = await _applyBinaryOp(current, baseOp, rhsValue, span);
      }
    }
    if (receiver is QudsInstance) {
      final prop = receiver.qudsClass.lookupProperty(name);
      if (prop != null && prop.setter != null && prop.setterBody != null) {
        final setterEnv =
            receiver.qudsClass.definingEnv.child(isFunctionBoundary: true)
              ..define('this', receiver)
              ..define(prop.setter!, newValue);
        _exposeInstanceFields(receiver, setterEnv);
        await executeBlock(prop.setterBody!, setterEnv);
        _syncInstanceFieldsBack(receiver, setterEnv);
        await _notifyStateChanged();
        return;
      }
      final fieldDecl = _findFieldDecl(receiver.qudsClass, name);
      if (fieldDecl != null &&
          !fieldDecl.mutable &&
          !_initializingInstances.contains(receiver)) {
        throw QudsRuntimeException(
          'Cannot assign to immutable field `${receiver.qudsClass.name}.$name`.',
          span,
          code: 'E202',
        );
      }
      receiver.fields[name] = newValue;
      if (identical(env.resolveSlot('this')?.value, receiver)) {
        final fieldSlot = env.resolveSlot(name);
        if (fieldSlot != null) {
          fieldSlot.value = newValue;
        }
      }
      await _notifyStateChanged();
      return;
    }
    if (receiver is QudsClass) {
      receiver.staticFields[name] = newValue;
      await _notifyStateChanged();
      return;
    }
    throw QudsRuntimeException(
      'Cannot assign member `$name` on `${qudsTypeName(receiver)}`.',
      span,
    );
  }

  /// Reads an index on List/Map/String/QudsInstance.
  FutureOr<Object?> vmEvalIndexRead(
    Object? container,
    Object? index,
    SourceSpan span,
  ) =>
      _evalIndexReadFast(container, index, span);

  /// Assigns an index on List/Map/QudsInstance with policy & operator checks.
  Future<void> vmExecIndexAssign(
    Object? container,
    Object? index,
    String operator,
    Object? rhsValue,
    SourceSpan span,
  ) async {
    if (!allowMutation) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.featureDisabled,
        'Index mutation is disabled by the active execution policy.',
        span,
        stackFrames: stackFrames,
      );
    }
    Object? newValue;
    if (operator == '=') {
      newValue = rhsValue;
    } else {
      final current = await _evalIndexRead(container, index, span);
      if (operator == '??=' && current != null) return;
      if (operator == '??=') {
        newValue = rhsValue;
      } else {
        final baseOp = operator.substring(0, operator.length - 1);
        newValue = await _applyBinaryOp(current, baseOp, rhsValue, span);
      }
    }
    if (container is List) {
      final idx = _expectInt(index, span);
      final resolved = idx < 0 ? container.length + idx : idx;
      if (resolved < 0 || resolved >= container.length) {
        throw QudsRuntimeException(
          'List index $idx out of range (length ${container.length}).',
          span,
          code: 'R302',
        );
      }
      container[resolved] = newValue;
      return;
    }
    if (container is Map) {
      container[index] = newValue;
      _checkCollectionSize(container.length, span);
      return;
    }
    if (container is QudsInstance || _extensionOperators.isNotEmpty) {
      final overload =
          _resolveOperatorOverload(container, '[]=', [index, newValue]);
      if (overload != null) {
        final (fn, isExt) = overload;
        if (isExt) {
          await _invokeExtension(
              fn, container, [index, newValue], const {}, span);
        } else {
          await invokeCallable(fn.bind(container as QudsInstance),
              [index, newValue], const {}, span);
        }
        return;
      }
    }
    throw QudsRuntimeException(
      'Cannot index-assign on `${qudsTypeName(container)}`.',
      span,
    );
  }

  /// Applies a binary operator (with operator overloading on QudsInstance).
  FutureOr<Object?> vmApplyBinary(
    Object? left,
    String op,
    Object? right,
    SourceSpan span,
  ) =>
      _applyBinaryFast(left, op, right, span);

  /// Applies a unary operator.
  FutureOr<Object?> vmApplyUnary(String op, Object? value, SourceSpan span) =>
      _applyUnaryOp(op, value, span);

  /// Validates boolean condition value.
  bool vmExpectBool(Object? value, SourceSpan span) => _expectBool(value, span);

  /// Invokes a callable using the fast synchronous path when possible.
  FutureOr<Object?> vmInvokeCallable(
    Object? callee,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span,
  ) =>
      _invokeCallableFast(callee, positional, named, span);

  /// Invokes a named constructor or method on a receiver cleanly.
  FutureOr<Object?> vmInvokeMemberCall(
    Object? receiver,
    String name,
    bool nullAware,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span,
  ) {
    if (receiver == null && nullAware) return null;
    if (named.isEmpty) {
      if (receiver is num) {
        if (positional.isEmpty) {
          switch (name) {
            case 'abs':
              return receiver.abs();
            case 'truncateToDouble':
              return receiver.truncateToDouble();
            case 'floorToDouble':
              return receiver.floorToDouble();
            case 'ceilToDouble':
              return receiver.ceilToDouble();
            case 'roundToDouble':
              return receiver.roundToDouble();
            case 'truncate':
              return receiver.truncate();
            case 'floor':
              return receiver.floor();
            case 'ceil':
              return receiver.ceil();
            case 'round':
              return receiver.round();
            case 'toDouble':
              return receiver.toDouble();
            case 'toInt':
              return receiver.toInt();
          }
        }
        if (name == 'toStringAsFixed' && positional.length == 1) {
          return receiver.toStringAsFixed(_expectInt(positional[0], span));
        }
      }
      if (receiver is BigInt) {
        if (positional.isEmpty) {
          switch (name) {
            case 'abs':
              return receiver.abs();
            case 'toDouble':
              return receiver.toDouble();
            case 'toInt':
              return receiver.toInt();
          }
        }
        if (name == 'gcd' && positional.length == 1) {
          return receiver.gcd(positional[0] as BigInt);
        }
        if (name == 'pow' && positional.length == 1) {
          return receiver.pow(_expectInt(positional[0], span));
        }
      }
    }
    if (receiver is QudsClass) {
      final namedCtor = receiver.constructors[name];
      if (namedCtor != null) {
        return _instantiateClass(receiver, positional, named, span,
            ctor: namedCtor);
      }
      final staticMethod = receiver.staticMethods[name];
      if (staticMethod != null) {
        return _invokeCallableFast(staticMethod, positional, named, span);
      }
    }
    final member = _evalMemberReadFast(receiver, name, nullAware, span);
    if (member is Future<Object?>) {
      return member
          .then((m) => _invokeCallableFast(m, positional, named, span));
    }
    return _invokeCallableFast(member, positional, named, span);
  }

  /// Registers an extension/augment declaration.
  void vmRegisterExtension(ExtensionDeclaration ext, QudsEnvironment env) =>
      registerExtension(ext, env);
}

class _QudsComputedEntry {
  _QudsComputedEntry(this.name, this.expr, this.env);

  final String name;
  final Expression expr;
  final QudsEnvironment env;
}

class _QudsWatchEntry {
  _QudsWatchEntry(this.expr, this.body, this.env, this.lastValue);

  final Expression expr;
  final List<Statement> body;
  final QudsEnvironment env;
  Object? lastValue;
}
