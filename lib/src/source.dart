/// Original source coordinates. Offsets and lengths count UTF-8 bytes;
/// lines and columns are one-based (columns count UTF-16 code units).
class SourceSpan {
  /// Creates a source span at [line], [column], and UTF-8 byte [length].
  const SourceSpan(this.line, this.column, this.length,
      {this.file = '<input>', this.offset = 0});

  /// One-based line number in [file].
  final int line;

  /// One-based column offset in UTF-16 code units.
  final int column;

  /// UTF-8 byte length of the spanned token or node.
  final int length;

  /// Source file path or `<input>` for in-memory sources.
  final String file;

  /// Zero-based UTF-8 byte offset from the start of [file].
  final int offset;

  @override
  String toString() => '$file:$line:$column';
}

/// Diagnostic exception thrown by the Quds lexer, parser, or analyzer.
class CompilerException implements Exception {
  /// Creates a compiler diagnostic with registry [code], [message], and [span].
  const CompilerException(this.code, this.message, this.span);

  /// Registry diagnostic code (for example `E100`, `E300`, or `E910`).
  final String code;

  /// Human-readable diagnostic message.
  final String message;

  /// Original `.quds` source span where the error occurred.
  final SourceSpan span;

  @override
  String toString() => '$span: $code: $message';
}

/// Maps an analyzer message onto the design registry. Parser failures stay
/// `E100` unless a more specific code is thrown at the call site.
String registryCode(String message) {
  if (message.contains('Integer remainder') ||
      message.contains('compile-time constant')) {
    return 'E401';
  }
  if (message.contains('shadow')) return 'E203';
  if (message.startsWith('Duplicate') || message.contains('already defined')) {
    return 'E201';
  }
  if (message.contains('immutable')) return 'E202';
  if (message.startsWith('Undefined') || message.contains('is not defined')) {
    return 'E200';
  }
  if (message.startsWith('Unknown label') ||
      message.contains('label must be attached')) {
    return 'E800';
  }
  if (message.startsWith('Unknown import')) return 'E900';
  if (message.contains('Ambiguous overload') ||
      message.contains('Choose one overload')) {
    return 'E310';
  }
  if (message.contains('Default arguments may refer')) return 'E503';
  if (message.contains('Pipeline')) return 'E512';
  if (message.startsWith('Too many arguments') ||
      message.startsWith('Missing required') ||
      message.startsWith('Unknown argument') ||
      message.startsWith('Duplicate argument') ||
      message.startsWith('Positional arguments') ||
      message.startsWith('No overload') ||
      message.contains('expects one') ||
      message.contains('expects ') && message.contains('argument')) {
    return 'E500';
  }
  if (message.contains('Empty list') ||
      message.contains('Empty map') ||
      message.contains('Empty set') ||
      message.contains('require a type annotation') ||
      message.contains('Dot shorthand')) {
    return 'E302';
  }
  if (message.contains('inside async') || message.startsWith('await ')) {
    return 'E803';
  }
  if (message.contains('return is only valid')) return 'E107';
  if (message.contains('Module scope')) return 'E100';
  if (message.contains('Unsupported') ||
      message.contains('not implemented') ||
      message.contains('not supported')) {
    return 'E910';
  }
  if (message.contains('incompatible') ||
      message.contains('must be bool') ||
      message.contains('must be int') ||
      message.contains('must share') ||
      message.contains('Cannot initialize') ||
      message.contains('Cannot assign') ||
      message.contains('must be numeric') ||
      message.contains('not defined for') ||
      message.contains('does not match')) {
    return 'E300';
  }
  return 'E300';
}
