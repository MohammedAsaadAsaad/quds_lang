/// Execution policy, resource guards, capability-based permissions, and
/// dynamic host interceptors for the embedded Quds interpreter.
///
/// Supports everything from a locked-down pure-math sandbox (`strictSandbox`)
/// to a full MATLAB-like notebook (`scientific`) to a capability-governed
/// host/system bridge (`systemBridge`). Zero `dart:io` imports.
library;

import 'dart:async';

import '../ast.dart';
import '../source.dart';
import 'exceptions.dart';
import 'module_loader.dart';

/// A named capability granted to a [QudsSession] with optional scope rules.
class QudsCapability {
  const QudsCapability(this.name, {this.scope = const {}, this.description});

  /// Grants scoped read access to specific host paths (enforced by the host bridge).
  factory QudsCapability.fileRead({List<String> allowedRoots = const []}) =>
      QudsCapability(
        'fs.read',
        scope: {'allowedRoots': allowedRoots},
        description: 'Read files within allowed roots.',
      );

  /// Grants scoped write access to specific host paths.
  factory QudsCapability.fileWrite({List<String> allowedRoots = const []}) =>
      QudsCapability(
        'fs.write',
        scope: {'allowedRoots': allowedRoots},
        description: 'Write files within allowed roots.',
      );

  /// Grants scoped outbound HTTP access to allowed hostnames.
  factory QudsCapability.networkHttp({List<String> allowedHosts = const []}) =>
      QudsCapability(
        'net.http',
        scope: {'allowedHosts': allowedHosts},
        description: 'Perform HTTP requests to allowed hosts.',
      );

  /// Grants read access to selected host environment keys.
  factory QudsCapability.systemEnv({List<String> allowedVars = const []}) =>
      QudsCapability(
        'sys.env',
        scope: {'allowedVars': allowedVars},
        description: 'Read selected environment values.',
      );

  /// Defines a domain-specific capability (e.g. `sensors.read`, `app.state.write`).
  factory QudsCapability.custom(
    String name, {
    Map<String, Object?> scope = const {},
    String? description,
  }) =>
      QudsCapability(name, scope: scope, description: description);

  final String name;
  final Map<String, Object?> scope;
  final String? description;
}

/// Permission request passed to [QudsExecutionPolicy.onPermissionCheck].
class QudsPermissionRequest {
  const QudsPermissionRequest({
    required this.capability,
    required this.functionName,
    required this.positionalArguments,
    required this.namedArguments,
    required this.span,
    this.grantedScope,
  });

  final String capability;
  final String functionName;
  final List<Object?> positionalArguments;
  final Map<String, Object?> namedArguments;
  final SourceSpan span;
  final Map<String, Object?>? grantedScope;
}

/// Decision returned by [QudsExecutionPolicy.onPermissionCheck].
class QudsPermissionDecision {
  const QudsPermissionDecision._(this.allowed, this.reason);

  const QudsPermissionDecision.allow() : this._(true, null);
  const QudsPermissionDecision.deny([String? reason]) : this._(false, reason);

  final bool allowed;
  final String? reason;
}

/// Decision returned by dynamic call or statement interceptors.
class QudsInterceptDecision {
  const QudsInterceptDecision._(this.allowed, this.reason);

  const QudsInterceptDecision.allow() : this._(true, null);
  const QudsInterceptDecision.deny([String? reason]) : this._(false, reason);

  final bool allowed;
  final String? reason;
}

/// Context provided to [QudsExecutionPolicy.onCallIntercept].
class QudsCallInterceptEvent {
  const QudsCallInterceptEvent({
    required this.functionName,
    required this.positionalArguments,
    required this.namedArguments,
    required this.span,
    this.requiredCapability,
  });

  final String functionName;
  final List<Object?> positionalArguments;
  final Map<String, Object?> namedArguments;
  final SourceSpan span;
  final String? requiredCapability;
}

/// Context provided to [QudsExecutionPolicy.onStatementIntercept].
class QudsStatementInterceptEvent {
  const QudsStatementInterceptEvent({
    required this.statement,
    required this.span,
  });

  final Statement statement;
  final SourceSpan span;
}

typedef QudsPermissionCallback = FutureOr<QudsPermissionDecision> Function(
    QudsPermissionRequest request);

typedef QudsCallInterceptor = FutureOr<QudsInterceptDecision> Function(
    QudsCallInterceptEvent event);

typedef QudsStatementInterceptor = FutureOr<QudsInterceptDecision> Function(
    QudsStatementInterceptEvent event);

/// Declarative execution policy controlling resource limits, language features,
/// allowed libraries, host capabilities, and dynamic runtime interceptors.
class QudsExecutionPolicy {
  const QudsExecutionPolicy({
    this.name = 'custom',
    this.maxSteps,
    this.timeout,
    this.maxCallDepth = 256,
    this.maxCollectionLength,
    this.maxStringLength,
    this.maxLoopIterations,
    this.maxOutputCount,
    this.maxPrimitives,
    this.yieldEveryNSteps = 2000,
    this.allowMutation = true,
    this.allowAsync = true,
    this.allowClasses = true,
    this.allowExceptions = true,
    this.allowImports = true,
    this.allowedLibraries,
    this.deniedLibraries = const {},
    this.capabilities = const [],
    this.importResolver,
    this.onPermissionCheck,
    this.onCallIntercept,
    this.onStatementIntercept,
  });

  /// General-purpose default policy with safe runaway guards and no hardcoded
  /// domain restrictions. Host applications can customize any limit, library
  /// allow/deny list, capability, or dynamic interceptor via the constructor
  /// or [copyWith].
  factory QudsExecutionPolicy.standard({
    String name = 'standard',
    int? maxSteps = 500000,
    Duration? timeout = const Duration(seconds: 15),
    int maxCallDepth = 256,
    int? maxCollectionLength = 250000,
    int? maxStringLength = 2500000,
    int? maxLoopIterations,
    int? maxOutputCount = 256,
    int? maxPrimitives = 50000,
    bool allowMutation = true,
    bool allowAsync = true,
    bool allowClasses = true,
    bool allowExceptions = true,
    bool allowImports = true,
    Set<String>? allowedLibraries,
    Set<String> deniedLibraries = const {},
    List<QudsCapability> capabilities = const [],
    QudsImportResolver? importResolver,
    QudsPermissionCallback? onPermissionCheck,
    QudsCallInterceptor? onCallIntercept,
    QudsStatementInterceptor? onStatementIntercept,
  }) =>
      QudsExecutionPolicy(
        name: name,
        maxSteps: maxSteps,
        timeout: timeout,
        maxCallDepth: maxCallDepth,
        maxCollectionLength: maxCollectionLength,
        maxStringLength: maxStringLength,
        maxLoopIterations: maxLoopIterations,
        maxOutputCount: maxOutputCount,
        maxPrimitives: maxPrimitives,
        allowMutation: allowMutation,
        allowAsync: allowAsync,
        allowClasses: allowClasses,
        allowExceptions: allowExceptions,
        allowImports: allowImports,
        allowedLibraries: allowedLibraries,
        deniedLibraries: deniedLibraries,
        capabilities: capabilities,
        importResolver: importResolver,
        onPermissionCheck: onPermissionCheck,
        onCallIntercept: onCallIntercept,
        onStatementIntercept: onStatementIntercept,
      );

  /// Example preset: locked-down sandbox for untrusted formulas or strict calculators.
  /// Any field can be customized or replaced using [QudsExecutionPolicy] / [copyWith].
  factory QudsExecutionPolicy.strictSandbox({
    int maxSteps = 50000,
    Duration timeout = const Duration(seconds: 2),
    int maxCallDepth = 64,
    int maxCollectionLength = 10000,
    int maxStringLength = 100000,
    int maxLoopIterations = 20000,
    int maxOutputCount = 32,
    int maxPrimitives = 2000,
    bool allowMutation = true,
    bool allowClasses = true,
    Set<String> allowedLibraries = const {
      'quds:math',
      'quds:core',
      'quds:collection',
      'quds:text',
      'quds:json',
      'dart:math',
    },
    QudsImportResolver? importResolver,
    QudsCallInterceptor? onCallIntercept,
    QudsStatementInterceptor? onStatementIntercept,
  }) =>
      QudsExecutionPolicy(
        name: 'strictSandbox',
        maxSteps: maxSteps,
        timeout: timeout,
        maxCallDepth: maxCallDepth,
        maxCollectionLength: maxCollectionLength,
        maxStringLength: maxStringLength,
        maxLoopIterations: maxLoopIterations,
        maxOutputCount: maxOutputCount,
        maxPrimitives: maxPrimitives,
        allowMutation: allowMutation,
        allowAsync: false,
        allowClasses: allowClasses,
        allowExceptions: true,
        allowImports: true,
        allowedLibraries: allowedLibraries,
        importResolver: importResolver,
        onCallIntercept: onCallIntercept,
        onStatementIntercept: onStatementIntercept,
      );

  /// Example preset: MATLAB-like scientific notebook configuration (illustrative
  /// starter preset, not a hardcoded mode — build any custom policy via
  /// `QudsExecutionPolicy(...)`, `QudsExecutionPolicy.standard(...)`, or `copyWith`).
  factory QudsExecutionPolicy.scientific({
    int maxSteps = 500000,
    Duration timeout = const Duration(seconds: 15),
    int maxCallDepth = 128,
    int maxCollectionLength = 200000,
    int maxStringLength = 2000000,
    int? maxLoopIterations,
    int maxOutputCount = 128,
    int maxPrimitives = 20000,
    Set<String> allowedLibraries = const {
      'quds:math',
      'quds:core',
      'quds:collection',
      'quds:text',
      'quds:json',
      'quds:async',
      'quds:ext',
      'quds:viz',
      'quds:data',
      'dart:math',
      'dart:convert',
    },
    List<QudsCapability> capabilities = const [],
    QudsImportResolver? importResolver,
    QudsPermissionCallback? onPermissionCheck,
    QudsCallInterceptor? onCallIntercept,
    QudsStatementInterceptor? onStatementIntercept,
  }) =>
      QudsExecutionPolicy(
        name: 'scientific',
        maxSteps: maxSteps,
        timeout: timeout,
        maxCallDepth: maxCallDepth,
        maxCollectionLength: maxCollectionLength,
        maxStringLength: maxStringLength,
        maxLoopIterations: maxLoopIterations,
        maxOutputCount: maxOutputCount,
        maxPrimitives: maxPrimitives,
        allowMutation: true,
        allowAsync: true,
        allowClasses: true,
        allowExceptions: true,
        allowImports: true,
        allowedLibraries: allowedLibraries,
        capabilities: capabilities,
        importResolver: importResolver,
        onPermissionCheck: onPermissionCheck,
        onCallIntercept: onCallIntercept,
        onStatementIntercept: onStatementIntercept,
      );

  /// Host/system-connected policy granting explicit [capabilities] under optional
  /// runtime approval ([onPermissionCheck]) and call/statement auditing.
  factory QudsExecutionPolicy.systemBridge({
    required List<QudsCapability> capabilities,
    int? maxSteps = 2000000,
    Duration? timeout = const Duration(seconds: 30),
    int maxCallDepth = 256,
    int? maxCollectionLength = 500000,
    int? maxStringLength = 5000000,
    int? maxOutputCount = 256,
    int? maxPrimitives = 50000,
    Set<String>? allowedLibraries,
    Set<String> deniedLibraries = const {},
    QudsImportResolver? importResolver,
    QudsPermissionCallback? onPermissionCheck,
    QudsCallInterceptor? onCallIntercept,
    QudsStatementInterceptor? onStatementIntercept,
  }) =>
      QudsExecutionPolicy(
        name: 'systemBridge',
        maxSteps: maxSteps,
        timeout: timeout,
        maxCallDepth: maxCallDepth,
        maxCollectionLength: maxCollectionLength,
        maxStringLength: maxStringLength,
        maxOutputCount: maxOutputCount,
        maxPrimitives: maxPrimitives,
        allowMutation: true,
        allowAsync: true,
        allowClasses: true,
        allowExceptions: true,
        allowImports: true,
        allowedLibraries: allowedLibraries,
        deniedLibraries: deniedLibraries,
        capabilities: capabilities,
        importResolver: importResolver,
        onPermissionCheck: onPermissionCheck,
        onCallIntercept: onCallIntercept,
        onStatementIntercept: onStatementIntercept,
      );

  final String name;
  final int? maxSteps;
  final Duration? timeout;
  final int maxCallDepth;
  final int? maxCollectionLength;
  final int? maxStringLength;
  final int? maxLoopIterations;
  final int? maxOutputCount;
  final int? maxPrimitives;
  final int yieldEveryNSteps;
  final bool allowMutation;
  final bool allowAsync;
  final bool allowClasses;
  final bool allowExceptions;
  final bool allowImports;
  final Set<String>? allowedLibraries;
  final Set<String> deniedLibraries;
  final List<QudsCapability> capabilities;
  final QudsImportResolver? importResolver;
  final QudsPermissionCallback? onPermissionCheck;
  final QudsCallInterceptor? onCallIntercept;
  final QudsStatementInterceptor? onStatementIntercept;

  /// Looks up a granted [QudsCapability] by exact name or wildcard prefix (`fs.*`).
  QudsCapability? findCapability(String capabilityName) {
    for (final cap in capabilities) {
      if (cap.name == capabilityName || cap.name == '*') return cap;
      if (cap.name.endsWith('.*')) {
        final prefix = cap.name.substring(0, cap.name.length - 1);
        if (capabilityName.startsWith(prefix)) return cap;
      }
    }
    return null;
  }

  /// Checks whether [libraryUri] is permitted by this policy's allow/deny rules.
  bool isLibraryAllowed(String libraryUri) {
    final base = libraryUri.contains('::')
        ? libraryUri.substring(0, libraryUri.indexOf('::'))
        : libraryUri;
    if (deniedLibraries.contains(libraryUri) ||
        deniedLibraries.contains(base)) {
      return false;
    }
    if (allowedLibraries == null) return true;
    return allowedLibraries!.contains('*') ||
        allowedLibraries!.contains(libraryUri) ||
        allowedLibraries!.contains(base);
  }

  /// Verifies both capability grant and optional dynamic permission callback.
  Future<void> authorizeCall({
    required String functionName,
    required List<Object?> positional,
    required Map<String, Object?> named,
    required SourceSpan span,
    String? requiredCapability,
  }) async {
    if (requiredCapability != null) {
      final granted = findCapability(requiredCapability);
      if (granted == null) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.permissionDenied,
          'Function `$functionName` requires capability `$requiredCapability`, which is not granted by policy `$name`.',
          span,
          capability: requiredCapability,
        );
      }
      if (onPermissionCheck != null) {
        final decision = await onPermissionCheck!(
          QudsPermissionRequest(
            capability: requiredCapability,
            functionName: functionName,
            positionalArguments: positional,
            namedArguments: named,
            span: span,
            grantedScope: granted.scope,
          ),
        );
        if (!decision.allowed) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.permissionDenied,
            decision.reason ??
                'Permission denied for `$functionName` (capability `$requiredCapability`).',
            span,
            capability: requiredCapability,
          );
        }
      }
    }

    if (onCallIntercept != null) {
      final decision = await onCallIntercept!(
        QudsCallInterceptEvent(
          functionName: functionName,
          positionalArguments: positional,
          namedArguments: named,
          span: span,
          requiredCapability: requiredCapability,
        ),
      );
      if (!decision.allowed) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.interceptDenied,
          decision.reason ??
              'Call to `$functionName` was blocked by host policy.',
          span,
          capability: requiredCapability,
        );
      }
    }
  }

  /// Evaluates [onStatementIntercept] if configured.
  Future<void> authorizeStatement(Statement statement) async {
    if (onStatementIntercept == null) return;
    final decision = await onStatementIntercept!(
      QudsStatementInterceptEvent(statement: statement, span: statement.span),
    );
    if (!decision.allowed) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.interceptDenied,
        decision.reason ?? 'Statement execution blocked by host policy.',
        statement.span,
      );
    }
  }

  /// Creates a customized copy of this policy.
  QudsExecutionPolicy copyWith({
    String? name,
    int? maxSteps,
    Duration? timeout,
    int? maxCallDepth,
    int? maxCollectionLength,
    int? maxStringLength,
    int? maxLoopIterations,
    int? maxOutputCount,
    int? maxPrimitives,
    int? yieldEveryNSteps,
    bool? allowMutation,
    bool? allowAsync,
    bool? allowClasses,
    bool? allowExceptions,
    bool? allowImports,
    Set<String>? allowedLibraries,
    Set<String>? deniedLibraries,
    List<QudsCapability>? capabilities,
    QudsImportResolver? importResolver,
    QudsPermissionCallback? onPermissionCheck,
    QudsCallInterceptor? onCallIntercept,
    QudsStatementInterceptor? onStatementIntercept,
  }) =>
      QudsExecutionPolicy(
        name: name ?? this.name,
        maxSteps: maxSteps ?? this.maxSteps,
        timeout: timeout ?? this.timeout,
        maxCallDepth: maxCallDepth ?? this.maxCallDepth,
        maxCollectionLength: maxCollectionLength ?? this.maxCollectionLength,
        maxStringLength: maxStringLength ?? this.maxStringLength,
        maxLoopIterations: maxLoopIterations ?? this.maxLoopIterations,
        maxOutputCount: maxOutputCount ?? this.maxOutputCount,
        maxPrimitives: maxPrimitives ?? this.maxPrimitives,
        yieldEveryNSteps: yieldEveryNSteps ?? this.yieldEveryNSteps,
        allowMutation: allowMutation ?? this.allowMutation,
        allowAsync: allowAsync ?? this.allowAsync,
        allowClasses: allowClasses ?? this.allowClasses,
        allowExceptions: allowExceptions ?? this.allowExceptions,
        allowImports: allowImports ?? this.allowImports,
        allowedLibraries: allowedLibraries ?? this.allowedLibraries,
        deniedLibraries: deniedLibraries ?? this.deniedLibraries,
        capabilities: capabilities ?? this.capabilities,
        importResolver: importResolver ?? this.importResolver,
        onPermissionCheck: onPermissionCheck ?? this.onPermissionCheck,
        onCallIntercept: onCallIntercept ?? this.onCallIntercept,
        onStatementIntercept: onStatementIntercept ?? this.onStatementIntercept,
      );
}
