/// General-purpose sandboxed Quds Formula, Rule & Micro-Plugin Engine
/// (`QudsFormulaEngine`).
///
/// Designed for embedding Quds inside ANY Dart or Flutter application
/// (ERP/accounting formulas, tax & pricing calculators, workflow rules,
/// game balancing scripts, or user-authored micro-plugins) with:
/// - Strict sandbox execution policy by default (configurable per host)
/// - Compiled AST caching for fast repeated evaluations & batch row processing
/// - Typed context variable injection without mutating host state
/// - Pre-execution static validation (`validate`)
///
/// 100% pure Dart (zero `dart:io` or Flutter dependencies).
library;

import 'dart:async';

import '../ast.dart';
import '../lexer.dart';
import '../parser.dart';
import 'evaluator.dart';
import 'exceptions.dart';
import 'host_bridge.dart';
import 'policy.dart';
import 'session.dart';
import 'values.dart';

/// Result of statically validating a formula or rule before execution.
class QudsFormulaValidationResult {
  const QudsFormulaValidationResult({
    required this.valid,
    this.errors = const [],
  });

  final bool valid;
  final List<String> errors;
}

/// Reusable, AST-cached, sandboxed Quds Formula & Rule Engine.
class QudsFormulaEngine {
  QudsFormulaEngine({
    QudsExecutionPolicy? policy,
    List<QudsHostModule> hostModules = const [],
    Map<String, QudsHostCallback> hostFunctions = const {},
    this.maxCacheEntries = 256,
  })  : policy = policy ??
            QudsExecutionPolicy.strictSandbox(
              maxSteps: 50000,
              timeout: const Duration(seconds: 2),
              allowMutation: true,
              allowClasses: true,
              allowedLibraries: const {'quds:math', 'quds:core', 'dart:math'},
            ),
        _hostModules = List.unmodifiable(hostModules),
        _hostFunctions = Map.unmodifiable(hostFunctions);

  /// Security & resource policy governing all formula evaluations.
  final QudsExecutionPolicy policy;
  final List<QudsHostModule> _hostModules;
  final Map<String, QudsHostCallback> _hostFunctions;
  final int maxCacheEntries;

  final Map<String, Program> _astCache = {};

  /// Number of currently cached parsed AST programs.
  int get cacheSize => _astCache.length;

  /// Clears the parsed AST cache.
  void clearCache() => _astCache.clear();

  /// Validates syntax and basic policy compliance of [source] without executing it.
  QudsFormulaValidationResult validate(String source) {
    final errors = <String>[];
    try {
      final program = _compileCached(source);
      for (final stmt in program.statements) {
        if (stmt is ImportDeclaration) {
          if (!policy.allowImports) {
            errors.add('Imports are disabled by policy `${policy.name}`.');
          } else if (!policy.isLibraryAllowed(stmt.uri)) {
            errors.add(
                'Library `${stmt.uri}` is not allowed by policy `${policy.name}`.');
          }
        }
      }
    } catch (err) {
      errors.add(err.toString());
    }
    return QudsFormulaValidationResult(
      valid: errors.isEmpty,
      errors: List.unmodifiable(errors),
    );
  }

  /// Evaluates a single Quds formula [expression] (or multi-line rule whose
  /// final expression is the return value) against [context] variables.
  ///
  /// Example:
  /// ```dart
  /// final engine = QudsFormulaEngine();
  /// final tax = await engine.evaluate<double>(
  ///   'amount * rate - discount',
  ///   context: {'amount': 250.0, 'rate': 0.15, 'discount': 5.0},
  /// );
  /// ```
  Future<T> evaluate<T>(
    String expression, {
    Map<String, Object?> context = const {},
    String file = '<formula>',
  }) async {
    final program = _compileCached(expression, file: file);
    final session = _createIsolatedSession(context);
    try {
      final evaluator = _createEvaluator(session);
      final raw = await evaluator.executeProgram(program,
          env: session.globalEnvironment);
      if (raw is T) return raw;
      if (T == double && raw is num) return raw.toDouble() as T;
      if (T == int && raw is num) return raw.toInt() as T;
      throw QudsRuntimeException(
        'Formula returned `${qudsTypeName(raw)}` (`$raw`), expected `$T`.',
        program.statements.isNotEmpty
            ? program.statements.last.span
            : const SourceSpan(1, 1, 1),
      );
    } finally {
      await session.dispose();
    }
  }

  /// Executes a multi-line Quds business rule script and returns the full
  /// [QudsRunResult] (value, stdout, outputs, workspace, and error if any).
  Future<QudsRunResult> evaluateRule(
    String ruleScript, {
    Map<String, Object?> context = const {},
    String file = '<rule>',
  }) async {
    final session = _createIsolatedSession(context);
    try {
      return await session.run(ruleScript, file: file);
    } finally {
      await session.dispose();
    }
  }

  /// Evaluates [expression] over a batch of [rows] reusing the cached AST.
  Future<List<T>> evaluateBatch<T>(
    String expression,
    List<Map<String, Object?>> rows, {
    String file = '<formula_batch>',
  }) async {
    final program = _compileCached(expression, file: file);
    final results = <T>[];
    for (final row in rows) {
      final session = _createIsolatedSession(row);
      try {
        final evaluator = _createEvaluator(session);
        final raw = await evaluator.executeProgram(program,
            env: session.globalEnvironment);
        if (raw is T) {
          results.add(raw);
        } else if (T == double && raw is num) {
          results.add(raw.toDouble() as T);
        } else if (T == int && raw is num) {
          results.add(raw.toInt() as T);
        } else {
          throw QudsRuntimeException(
            'Batch formula returned `${qudsTypeName(raw)}`, expected `$T`.',
            const SourceSpan(1, 1, 1),
          );
        }
      } finally {
        await session.dispose();
      }
    }
    return results;
  }

  Program _compileCached(String source, {String file = '<formula>'}) {
    final existing = _astCache[source];
    if (existing != null) return existing;
    final tokens = Lexer().tokenize(source, file: file);
    final program = Parser(tokens).parse();
    if (_astCache.length >= maxCacheEntries && _astCache.isNotEmpty) {
      _astCache.remove(_astCache.keys.first);
    }
    _astCache[source] = program;
    return program;
  }

  QudsSession _createIsolatedSession(Map<String, Object?> context) {
    final session = QudsSession(
      policy: policy,
      hostModules: _hostModules,
    );
    for (final entry in _hostFunctions.entries) {
      session.registerFunction(entry.key, entry.value);
    }
    for (final entry in context.entries) {
      session.setVariable(entry.key, entry.value, mutable: false);
    }
    return session;
  }

  QudsEvaluator _createEvaluator(QudsSession session) => QudsEvaluator(
        globalEnv: session.globalEnvironment,
        onPrint: (_, __) {},
        onOutput: (_, __) {},
        onImport: (decl, env) => session.resolveImportInto(decl, env),
        onBeforeCall:
            policy.onCallIntercept != null || policy.onPermissionCheck != null
                ? (name, pos, named, span, cap) async {
                    await policy.authorizeCall(
                      functionName: name,
                      positional: pos,
                      named: named,
                      span: span,
                      requiredCapability: cap,
                    );
                  }
                : null,
        maxSteps: policy.maxSteps,
        timeout: policy.timeout,
        maxCallDepth: policy.maxCallDepth,
        maxCollectionLength: policy.maxCollectionLength,
        maxStringLength: policy.maxStringLength,
        maxLoopIterations: policy.maxLoopIterations,
        allowMutation: policy.allowMutation,
        allowAsync: policy.allowAsync,
        allowClasses: policy.allowClasses,
        allowExceptions: policy.allowExceptions,
        interactiveInputs: session.interactiveInputs,
      );
}
