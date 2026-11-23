import 'dart:io';

import 'source.dart';

/// Returns an actionable hint for [error] when one is known.
String? diagnosticHelp(CompilerException error) {
  final msg = error.message;
  return switch (error.code) {
    'E110' =>
      'Add `()` to invoke a zero-argument function (or run `quds fix --apply`).',
    'E202' =>
      'Declare the binding with `var` if it should be reassigned (or run `quds fix --apply`).',
    'E203' =>
      'Prefix the inner binding with `shadow` to intentionally shadow the outer name (or run `quds fix --apply`).',
    'E206' =>
      'Names marked `private` (or starting with `_`) are only accessible inside their declaring library.',
    'E207' =>
      'Names marked `protected` are only accessible inside their declaring library and subtypes.',
    'E208' =>
      'Files under `lib/src/` and `lib/internal/` are private to their package; import a public entrypoint instead.',
    'E209' =>
      '`internal` declarations and class members are only accessible within their declaring package.',
    'E307' =>
      'Remove `readonly` from the reference or invoke a `readonly` method instead.',
    'E308' =>
      'Unwrap the nullable value with `if let name = expr:`, `let name = expr else:`, or provide a fallback with `??`.',
    'E315' =>
      'Values consumed by a `@consumes` method cannot be used afterwards unless reassigned on a `var` binding.',
    'E316' =>
      'End the guard destructuring `else:` branch with `return`, `throw`, `rethrow`, `break`, or `continue`.',
    'E803' => 'Mark the enclosing function `async`.',
    'E902' =>
      '`when` conditions must be compile-time constant booleans such as `when test:`, `when not test:`, or `when platform == "vm":`.',
    'E300' when msg.contains('dispose()') || msg.contains('close()') =>
      'Implement `Disposable` / `AsyncDisposable`, or add a zero-argument `dispose()` or `close()` method.',
    'E300' when msg.contains('incompatible') =>
      'Use `to Type` or `to? Type` for an explicit conversion if converting between types.',
    _ => null,
  };
}

/// Formats [error] with a `rustc`-style source snippet, caret underline, and
/// optional `help:` suggestion while keeping the first line identical to
/// `error.toString()` (`path:line:column: CODE: message`).
String formatRichDiagnostic(CompilerException error,
    {String? source, String? help}) {
  final buffer = StringBuffer()..writeln(error.toString());
  final text = source ?? _readSourceIfAvailable(error.span.file);
  if (text != null && error.span.line >= 1) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final index = error.span.line - 1;
    if (index >= 0 && index < lines.length) {
      final lineText = lines[index];
      final lineNum = error.span.line.toString();
      final gutterWidth = lineNum.length < 2 ? 2 : lineNum.length;
      final pad = ' ' * gutterWidth;
      final numbered = lineNum.padLeft(gutterWidth);
      final startCol = error.span.column < 1 ? 1 : error.span.column;
      final zeroCol =
          startCol - 1 > lineText.length ? lineText.length : startCol - 1;
      final remaining = lineText.length - zeroCol;
      final rawLen = error.span.length < 1 ? 1 : error.span.length;
      final caretLen =
          remaining <= 0 ? 1 : (rawLen > remaining ? remaining : rawLen);
      final indentBuffer = StringBuffer();
      for (var i = 0; i < zeroCol; i++) {
        indentBuffer.write(lineText[i] == '\t' ? '\t' : ' ');
      }
      buffer.writeln('$pad |');
      buffer.writeln('$numbered | $lineText');
      buffer.writeln('$pad | ${indentBuffer.toString()}${'^' * caretLen}');
    }
  }
  final suggestion = help ?? diagnosticHelp(error);
  if (suggestion != null && suggestion.isNotEmpty) {
    final lineNum = error.span.line >= 1 ? error.span.line.toString() : '';
    final gutterWidth = lineNum.length < 2 ? 2 : lineNum.length;
    final pad = ' ' * gutterWidth;
    buffer.writeln('$pad = help: $suggestion');
  }
  return buffer.toString().trimRight();
}

String? _readSourceIfAvailable(String path) {
  if (path.isEmpty || path.startsWith('<')) return null;
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  } on FileSystemException {
    return null;
  }
}
