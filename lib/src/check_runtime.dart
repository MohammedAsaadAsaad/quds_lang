import 'package:matcher/matcher.dart' as match;
// AsyncMatcher is the protocol package:test uses for throwsA, completion,
// prints, and stream matchers. It is not re-exported by matcher.dart.
// ignore: implementation_imports
import 'package:matcher/src/expect/async_matcher.dart';

/// Checks [actual] the way Dart's `expect` does, without the test-package zone.
///
/// A non-matcher [matcher] is compared with [match.equals]. Failure throws
/// [StateError] whose message is Dart's Expected / Actual / Which text.
/// An asynchronous matcher returns a future when [wait] is true.
Object? qExpect(Object? actual, Object? matcher,
    {String? reason, Object? skip, bool wait = false}) {
  if (skip != null && skip is! bool && skip is! String) {
    throw ArgumentError.value(skip, 'skip', 'must be a bool or a String');
  }
  final wrapped = match.wrapMatcher(matcher);
  if (skip != null && skip != false) {
    String message;
    if (skip is String) {
      message = 'Skip expect: $skip';
    } else if (reason != null) {
      message = 'Skip expect ($reason).';
    } else {
      final description = match.StringDescription()..addDescriptionOf(wrapped);
      message = 'Skip expect ($description).';
    }
    print(message);
    return null;
  }
  if (wrapped is AsyncMatcher) {
    final result = wrapped.matchAsync(actual);
    if (result is String) {
      throw StateError(_failure(wrapped, actual, result, reason));
    }
    if (result is Future) {
      final pending = result.then((value) {
        if (value == null) return null;
        throw StateError(_failure(wrapped, actual, '$value', reason));
      });
      if (!wait) {
        pending.ignore();
        throw StateError('await expectLater for an asynchronous matcher');
      }
      return pending;
    }
    return null;
  }
  final state = <Object?, Object?>{};
  String? thrown;
  var matched = false;
  try {
    matched = wrapped.matches(actual, state);
  } catch (error, trace) {
    thrown = '$error at $trace';
  }
  if (matched) return null;
  var which = '';
  if (thrown == null) {
    final mismatch = match.StringDescription();
    try {
      wrapped.describeMismatch(actual, mismatch, state, false);
      which = mismatch.toString();
    } catch (error, trace) {
      thrown = '$error at $trace';
    }
  }
  throw StateError(_failure(wrapped, actual, which, reason ?? thrown));
}

/// Waits for an asynchronous matcher. Synchronous failure still throws at once.
Future<void> qExpectLater(Object? actual, Object? matcher,
    {String? reason, Object? skip}) async {
  final result =
      qExpect(actual, matcher, reason: reason, skip: skip, wait: true);
  if (result is Future) await result;
}

/// Stops the current test with [message], as Dart's `fail` does.
Never qFail(String message) => throw StateError(message);

String _failure(
    Object? expected, Object? actual, String which, String? reason) {
  final buffer = StringBuffer();
  buffer.writeln(_indent(_show(expected), 'Expected: '));
  buffer.writeln(_indent(_show(actual), '  Actual: '));
  if (which.isNotEmpty) buffer.writeln(_indent(which, '   Which: '));
  if (reason != null) buffer.writeln(reason);
  return buffer.toString();
}

String _show(Object? value) =>
    (match.StringDescription()..addDescriptionOf(value)).toString();

String _indent(String text, String first) {
  final prefix = ' ' * first.length;
  final lines = text.split('\n');
  if (lines.length == 1) return '$first$text';
  final buffer = StringBuffer('$first${lines.first}\n');
  for (final line in lines.skip(1).take(lines.length - 2)) {
    buffer.writeln('$prefix$line');
  }
  buffer.write('$prefix${lines.last}');
  return buffer.toString();
}
