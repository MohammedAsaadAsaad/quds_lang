/// Runtime exceptions, policy violations, and internal control-flow signals
/// for the embedded Quds interpreter (zero `dart:io` imports).
library;

import '../source.dart';

/// One frame in an interpreted Quds call stack.
class QudsStackFrame {
  const QudsStackFrame({
    required this.functionName,
    required this.span,
    this.locals = const {},
  });

  final String functionName;
  final SourceSpan span;
  final Map<String, Object?> locals;

  Map<String, Object?> toJson() => {
        'functionName': functionName,
        'file': span.file,
        'line': span.line,
        'column': span.column,
      };

  @override
  String toString() =>
      '$functionName (${span.file}:${span.line}:${span.column})';
}

/// Runtime error raised while interpreting Quds code, always anchored to
/// original `.quds` source coordinates.
class QudsRuntimeException implements Exception {
  const QudsRuntimeException(
    this.message,
    this.span, {
    this.code = 'R100',
    this.stackFrames = const [],
    this.cause,
  });

  final String code;
  final String message;
  final SourceSpan span;
  final List<QudsStackFrame> stackFrames;
  final Object? cause;

  @override
  String toString() {
    final buffer = StringBuffer(
        '${span.file}:${span.line}:${span.column}: $code: $message');
    for (final frame in stackFrames.reversed) {
      buffer.write('\n  at $frame');
    }
    return buffer.toString();
  }
}

/// Specific policy boundary violated during interpreted execution.
enum QudsPolicyViolationKind {
  stepLimit,
  timeout,
  callDepth,
  collectionLimit,
  stringLimit,
  loopLimit,
  outputLimit,
  primitiveLimit,
  libraryDenied,
  featureDisabled,
  permissionDenied,
  interceptDenied,
  stopped,
}

/// Thrown when interpreted Quds code exceeds a configured resource guard,
/// tries to use a disabled feature/library, or is denied by a host interceptor.
class QudsPolicyViolationException extends QudsRuntimeException {
  const QudsPolicyViolationException(
    this.kind,
    super.message,
    super.span, {
    super.stackFrames = const [],
    this.capability,
    this.detail,
  }) : super(code: 'P100');

  final QudsPolicyViolationKind kind;
  final String? capability;
  final Object? detail;
}

/// Thrown when a `to Type` conversion fails in interpreted Quds code.
class QudsConversionError implements Exception {
  const QudsConversionError(this.message);
  final String message;

  @override
  String toString() => 'ConversionError: $message';
}

// ---------------------------------------------------------------------------
// Internal control-flow signals (caught inside the evaluator, never exposed).
// ---------------------------------------------------------------------------

class ReturnSignal {
  const ReturnSignal(this.value);
  final Object? value;
}

class BreakSignal {
  const BreakSignal({this.label, this.value, this.hasValue = false});
  final String? label;
  final Object? value;
  final bool hasValue;
}

class ContinueSignal {
  const ContinueSignal({this.label});
  final String? label;
}

class ResultSignal {
  const ResultSignal(this.value);
  final Object? value;
}

class PropagateErrorSignal {
  const PropagateErrorSignal(this.errorResult);
  final Object? errorResult;
}

class QudsThrownValue implements Exception {
  const QudsThrownValue(this.value, this.span, this.stackFrames);
  final Object? value;
  final SourceSpan span;
  final List<QudsStackFrame> stackFrames;

  @override
  String toString() => '$value';
}
