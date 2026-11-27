/// Runtime value representations and events for the embedded Quds interpreter.
///
/// Pure Dart (zero `dart:io` imports) so values can be inspected directly in
/// Flutter Desktop, Mobile, Web, and Dart CLI applications.
library;

import 'dart:async';

import '../ast.dart';
import '../source.dart';
import 'environment.dart';
import 'exceptions.dart';

/// Context passed into native / host functions invoked from Quds code.
class QudsCallContext {
  const QudsCallContext({
    required this.span,
    required this.functionName,
    required this.emitOutput,
    required this.emitPrint,
    required this.invokeCallable,
    this.interactiveInputs = const {},
  });

  final SourceSpan span;
  final String functionName;
  final void Function(Object output) emitOutput;
  final void Function(String line) emitPrint;
  final Future<Object?> Function(
    Object? callee,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span,
  ) invokeCallable;
  final Map<String, Object?> interactiveInputs;
}

/// Signature for a native or host-provided function callable from Quds.
typedef QudsHostCallback = FutureOr<Object?> Function(
  List<Object?> positional,
  Map<String, Object?> named,
  QudsCallContext context,
);

/// Sentinel representing Quds `missing` (QUDS-083).
final class QudsMissing {
  const QudsMissing._();
  static const instance = QudsMissing._();

  @override
  String toString() => 'missing';
}

/// Quds `Optional<T>` value distinguishing omitted arguments from `null`.
final class QudsOptional {
  const QudsOptional.present(this.value) : isPresent = true;
  const QudsOptional.missing()
      : value = null,
        isPresent = false;

  final Object? value;
  final bool isPresent;
  bool get isMissing => !isPresent;

  Object? get valueOrNull => isPresent ? value : null;

  Object? orElse(Object? fallback) => isPresent ? value : fallback;

  @override
  bool operator ==(Object other) =>
      other is QudsOptional &&
      other.isPresent == isPresent &&
      qudsEquals(other.value, value);

  @override
  int get hashCode => Object.hash(isPresent, value);

  @override
  String toString() =>
      isPresent ? 'present(${qudsFormatValue(value)})' : 'missing';
}

/// First-class Quds `Future` wrapper that avoids Dart's automatic flattening
/// of `Future<Future<T>>` when an async evaluator returns an unawaited call.
final class QudsFuture {
  const QudsFuture(this.future);
  final Future<Object?> future;

  @override
  String toString() => '<Future>';
}

/// Quds `Result<T, E>` (`Ok(v)` / `Error(e)`).
final class QudsResult {
  const QudsResult.ok(this.value)
      : error = null,
        isOk = true;
  const QudsResult.error(this.error)
      : value = null,
        isOk = false;

  final Object? value;
  final Object? error;
  final bool isOk;
  bool get isError => !isOk;

  Object? get valueOrNull => isOk ? value : null;
  Object? get errorOrNull => isError ? error : null;

  Object? unwrap() {
    if (isOk) return value;
    throw StateError('Called unwrap() on Error($error)');
  }

  Object? unwrapOr(Object? fallback) => isOk ? value : fallback;

  @override
  bool operator ==(Object other) =>
      other is QudsResult &&
      other.isOk == isOk &&
      (isOk ? qudsEquals(other.value, value) : qudsEquals(other.error, error));

  @override
  int get hashCode => Object.hash(isOk, isOk ? value : error);

  @override
  String toString() => isOk
      ? 'Ok(${qudsFormatValue(value)})'
      : 'Error(${qudsFormatValue(error)})';
}

/// Quds loop context exposed as `$` inside `for`, `while`, and `repeat` loops.
class QudsLoopContext {
  QudsLoopContext({
    required this.index,
    this.count,
    required this.first,
    required this.last,
    this.item,
    this.hasItem = false,
    this.prev,
    this.next,
  });

  final int index;
  final int? count;
  final bool first;
  final bool last;
  final Object? item;
  final bool hasItem;
  final Object? prev;
  final Object? next;

  int get iteration => index + 1;
  int get number => index + 1;
  bool get isFirst => first;
  bool get isLast => last;
  bool get isEven => index.isEven;
  bool get isOdd => index.isOdd;

  Object? getMember(String name, SourceSpan span) => switch (name) {
        'index' => index,
        'iteration' || 'number' => iteration,
        'item' => hasItem
            ? item
            : throw QudsRuntimeException(
                'Loop context `\$.item` is only available inside `for ... in` loops.',
                span,
              ),
        'count' => count,
        'first' || 'isFirst' => first,
        'last' || 'isLast' => last,
        'even' || 'isEven' => isEven,
        'odd' || 'isOdd' => isOdd,
        'prev' => prev,
        'next' => next,
        _ => throw QudsRuntimeException(
            'Loop context `\$` has no member `$name`.', span),
      };

  @override
  String toString() =>
      'LoopContext(index: $index, first: $first, last: $last${count != null ? ', count: $count' : ''})';
}

/// Quds range value (`start..end` inclusive or `start..<end` exclusive).
class QudsRange extends Iterable<int> {
  const QudsRange(this.start, this.end, {this.inclusive = true, this.step = 1});

  final int start;
  final int end;
  final bool inclusive;
  final int step;

  QudsRange withStep(int newStep) =>
      QudsRange(start, end, inclusive: inclusive, step: newStep);

  @override
  Iterator<int> get iterator => _QudsRangeIterator(start, end, inclusive, step);

  @override
  int get length {
    if (step == 0) return 0;
    if (step > 0) {
      final last = inclusive ? end : end - 1;
      if (last < start) return 0;
      return ((last - start) ~/ step) + 1;
    } else {
      final last = inclusive ? end : end + 1;
      if (last > start) return 0;
      return ((start - last) ~/ (-step)) + 1;
    }
  }

  bool containsValue(Object? value) {
    if (value is! num) return false;
    if (step > 0) {
      return value >= start && (inclusive ? value <= end : value < end);
    }
    return value <= start && (inclusive ? value >= end : value > end);
  }

  @override
  String toString() => inclusive ? '$start..$end' : '$start..<$end';
}

class _QudsRangeIterator implements Iterator<int> {
  _QudsRangeIterator(this.start, this.end, this.inclusive, this.step);
  final int start;
  final int end;
  final bool inclusive;
  final int step;
  int? _current;

  @override
  int get current => _current!;

  @override
  bool moveNext() {
    if (step == 0) return false;
    final next = _current == null ? start : _current! + step;
    final ok = step > 0
        ? (inclusive ? next <= end : next < end)
        : (inclusive ? next >= end : next > end);
    if (!ok) return false;
    _current = next;
    return true;
  }
}

/// Quds structural record `(a, b, name: c)`.
class QudsRecord {
  const QudsRecord(this.positional, this.named);

  final List<Object?> positional;
  final Map<String, Object?> named;

  Object? getField(String name, SourceSpan span) {
    if (named.containsKey(name)) return named[name];
    if (name.startsWith(r'$')) {
      final idx = int.tryParse(name.substring(1));
      if (idx != null && idx >= 1 && idx <= positional.length) {
        return positional[idx - 1];
      }
    }
    throw QudsRuntimeException('Record has no field `$name`.', span);
  }

  @override
  bool operator ==(Object other) {
    if (other is! QudsRecord) return false;
    if (positional.length != other.positional.length ||
        named.length != other.named.length) {
      return false;
    }
    for (var i = 0; i < positional.length; i++) {
      if (!qudsEquals(positional[i], other.positional[i])) return false;
    }
    for (final entry in named.entries) {
      if (!other.named.containsKey(entry.key)) return false;
      if (!qudsEquals(entry.value, other.named[entry.key])) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(positional),
        Object.hashAllUnordered(
          named.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  @override
  String toString() {
    final parts = <String>[
      for (final v in positional) qudsFormatValue(v),
      for (final e in named.entries) '${e.key}: ${qudsFormatValue(e.value)}',
    ];
    return '(${parts.join(', ')})';
  }
}

/// Base class for all callable Quds runtime entities.
sealed class QudsCallable {
  const QudsCallable();
  String get name;
}

/// A Quds user-defined function or lambda closure.
class QudsUserFunction extends QudsCallable {
  QudsUserFunction({
    required this.name,
    required this.parameters,
    required this.closure,
    required this.span,
    this.body,
    this.expressionBody,
    this.isAsync = false,
    this.returnType = '',
    this.receiver,
    this.definingClass,
  });

  @override
  final String name;
  final List<Parameter> parameters;
  final QudsEnvironment closure;
  final SourceSpan span;
  final List<Statement>? body;
  final Expression? expressionBody;
  final bool isAsync;
  final String returnType;
  final QudsInstance? receiver;
  final QudsClass? definingClass;

  QudsUserFunction bind(QudsInstance instance) => QudsUserFunction(
        name: name,
        parameters: parameters,
        closure: closure,
        span: span,
        body: body,
        expressionBody: expressionBody,
        isAsync: isAsync,
        returnType: returnType,
        receiver: instance,
        definingClass: definingClass,
      );

  @override
  String toString() => '<fn $name>';
}

/// Holds overloaded Quds functions sharing the same name (QUDS-085).
class QudsOverloadSet extends QudsCallable {
  QudsOverloadSet(this.name, List<QudsUserFunction> overloads)
      : overloads = List<QudsUserFunction>.from(overloads);

  @override
  final String name;
  final List<QudsUserFunction> overloads;

  @override
  String toString() => '<fn $name (${overloads.length} overloads)>';
}

/// A Dart / host function callable from Quds.
class QudsNativeFunction extends QudsCallable {
  const QudsNativeFunction(
    this.name,
    this.callback, {
    this.requiredCapability,
    this.signature,
    this.documentation,
    this.isSync = false,
  });

  @override
  final String name;
  final QudsHostCallback callback;
  final String? requiredCapability;
  final String? signature;
  final String? documentation;
  final bool isSync;

  @override
  String toString() => '<native fn $name>';
}

/// A namespace exposing symbols from an imported module or host object.
class QudsNamespace {
  QudsNamespace(
    this.name,
    Map<String, Object?> members, {
    this.onGetMember,
  }) : members = Map<String, Object?>.from(members);

  final String name;
  final Map<String, Object?> members;
  final Object? Function(String memberName)? onGetMember;

  bool hasMember(String member) =>
      members.containsKey(member) || onGetMember?.call(member) != null;

  Object? getMember(String member, SourceSpan span) {
    if (members.containsKey(member)) return members[member];
    final dynamicMember = onGetMember?.call(member);
    if (dynamicMember != null) return dynamicMember;
    throw QudsRuntimeException(
      'Module `$name` has no exported member `$member`.',
      span,
    );
  }

  @override
  String toString() => '<module $name>';
}

/// Runtime representation of a Quds class, value class, sealed class, or enum.
class QudsClass extends QudsCallable {
  QudsClass({
    required this.name,
    required this.kind,
    required this.declaration,
    required this.definingEnv,
    this.superclass,
    this.methods = const {},
    this.staticMethods = const {},
    this.staticFields = const {},
    this.constructors = const {},
    this.properties = const {},
    this.enumCases = const {},
  });

  @override
  final String name;
  final String kind;
  final ClassDeclaration declaration;
  final QudsEnvironment definingEnv;
  final QudsClass? superclass;
  final Map<String, QudsUserFunction> methods;
  final Map<String, QudsUserFunction> staticMethods;
  final Map<String, Object?> staticFields;
  final Map<String, ConstructorDeclaration> constructors;
  final Map<String, PropertyDeclaration> properties;
  final Map<String, QudsInstance> enumCases;

  bool get isValueClass => kind == 'value';
  bool get isEnum => kind == 'enum';

  bool isSubtypeOf(String typeName) {
    if (name == typeName) return true;
    final base = _stripTypeArgs(typeName);
    if (name == base) return true;
    for (final iface in declaration.interfaces) {
      if (_stripTypeArgs(iface) == base) return true;
    }
    return superclass?.isSubtypeOf(base) ?? false;
  }

  QudsUserFunction? lookupMethod(String methodName) =>
      methods[methodName] ?? superclass?.lookupMethod(methodName);

  PropertyDeclaration? lookupProperty(String propName) =>
      properties[propName] ?? superclass?.lookupProperty(propName);

  @override
  String toString() => '<class $name>';
}

/// Runtime instance of a Quds class, value class, sealed case, or enum entry.
class QudsInstance {
  QudsInstance(this.qudsClass, Map<String, Object?> fields,
      {this.enumCaseName, this.enumIndex})
      : fields = Map<String, Object?>.from(fields);

  final QudsClass qudsClass;
  final Map<String, Object?> fields;
  final String? enumCaseName;
  final int? enumIndex;
  final Map<String, bool> _lazyComputed = {};

  bool isLazyComputed(String name) => _lazyComputed[name] ?? false;
  void markLazyComputed(String name) => _lazyComputed[name] = true;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QudsInstance) return false;
    if (qudsClass.isEnum) {
      return other.qudsClass.name == qudsClass.name &&
          other.enumCaseName == enumCaseName;
    }
    if (qudsClass.isValueClass && other.qudsClass.name == qudsClass.name) {
      if (fields.length != other.fields.length) return false;
      for (final entry in fields.entries) {
        if (!other.fields.containsKey(entry.key)) return false;
        if (!qudsEquals(entry.value, other.fields[entry.key])) return false;
      }
      return true;
    }
    return false;
  }

  @override
  int get hashCode {
    if (qudsClass.isEnum) return Object.hash(qudsClass.name, enumCaseName);
    if (qudsClass.isValueClass) {
      return Object.hash(
        qudsClass.name,
        Object.hashAllUnordered(
          fields.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
    }
    return identityHashCode(this);
  }

  @override
  String toString() {
    if (qudsClass.isEnum && enumCaseName != null) {
      return '${qudsClass.name}.$enumCaseName';
    }
    final rendered = fields.entries
        .where((e) => !e.key.startsWith('_'))
        .map((e) => '${e.key}: ${qudsFormatValue(e.value)}')
        .join(', ');
    return '${qudsClass.name}($rendered)';
  }
}

/// Snapshot of a single variable inside `QudsSession.workspace`.
class QudsWorkspaceEntry {
  const QudsWorkspaceEntry({
    required this.name,
    required this.value,
    required this.typeName,
    required this.mutable,
    required this.summary,
  });

  final String name;
  final Object? value;
  final String typeName;
  final bool mutable;
  final String summary;

  Map<String, Object?> toJson() => {
        'name': name,
        'typeName': typeName,
        'mutable': mutable,
        'summary': summary,
      };
}

/// Structured events emitted live by `QudsSession` during execution.
abstract class QudsRuntimeEvent {
  const QudsRuntimeEvent();
}

class QudsPrintEvent extends QudsRuntimeEvent {
  const QudsPrintEvent(this.text, {this.span});
  final String text;
  final SourceSpan? span;
}

class QudsOutputEvent extends QudsRuntimeEvent {
  const QudsOutputEvent(this.output, {this.span});
  final Object output;
  final SourceSpan? span;
}

class QudsErrorEvent extends QudsRuntimeEvent {
  const QudsErrorEvent(this.error);
  final Object error;
}

class QudsStepProgressEvent extends QudsRuntimeEvent {
  const QudsStepProgressEvent(this.stepsExecuted, this.span);
  final int stepsExecuted;
  final SourceSpan span;
}

/// Structural / Quds-compatible equality helper.
bool qudsEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a is num && b is num) return a == b;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!qudsEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!qudsEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is Set && b is Set) {
    if (a.length != b.length) return false;
    for (final item in a) {
      if (!b.any((other) => qudsEquals(item, other))) return false;
    }
    return true;
  }
  return a == b;
}

/// Formats a runtime value for Quds `print` and interpolation.
String qudsFormatValue(Object? value) {
  if (value == null) return 'null';
  if (value is String) return value;
  if (value is bool || value is num || value is BigInt) return '$value';
  if (value is List) {
    return '[${value.map(qudsFormatValue).join(', ')}]';
  }
  if (value is Set) {
    return '{${value.map(qudsFormatValue).join(', ')}}';
  }
  if (value is Map) {
    final entries = value.entries
        .map((e) => '${qudsFormatValue(e.key)}: ${qudsFormatValue(e.value)}')
        .join(', ');
    return '{$entries}';
  }
  return '$value';
}

/// Concise preview string for workspace tables and debugger panels.
String qudsSummarizeValue(Object? value, {int maxLength = 80}) {
  final text = value is String ? '"$value"' : qudsFormatValue(value);
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3)}...';
}

/// Returns the user-facing Quds type name for a runtime value.
String qudsTypeName(Object? value) {
  if (value == null) return 'Null';
  if (value is int) return 'int';
  if (value is double) return 'double';
  if (value is bool) return 'bool';
  if (value is String) return 'String';
  if (value is BigInt) return 'BigInt';
  if (value is Duration) return 'Duration';
  if (value is DateTime) return 'DateTime';
  if (value is RegExp) return 'RegExp';
  if (value is QudsRange) return 'Range<int>';
  if (value is List) return 'List (${value.length})';
  if (value is Map) return 'Map (${value.length})';
  if (value is Set) return 'Set (${value.length})';
  if (value is QudsResult) return value.isOk ? 'Ok' : 'Error';
  if (value is QudsOptional) return 'Optional';
  if (value is QudsMissing) return 'Optional<Never>';
  if (value is QudsRecord) return 'Record';
  if (value is QudsInstance) return value.qudsClass.name;
  if (value is QudsClass) return 'Type<${value.name}>';
  if (value is QudsCallable) return 'Function';
  if (value is QudsNamespace) return 'Module<${value.name}>';
  return value.runtimeType.toString();
}

String _stripTypeArgs(String type) {
  var cleaned = type.trim();
  if (cleaned.startsWith('readonly ')) {
    cleaned = cleaned.substring('readonly '.length).trim();
  }
  if (cleaned.endsWith('?')) cleaned = cleaned.substring(0, cleaned.length - 1);
  final lt = cleaned.indexOf('<');
  return lt < 0 ? cleaned : cleaned.substring(0, lt).trim();
}
