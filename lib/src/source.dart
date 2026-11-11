/// Original source coordinates. Offsets and lengths count UTF-8 bytes;
/// lines and columns are one-based (columns count UTF-16 code units).
class SourceSpan {
  const SourceSpan(this.line, this.column, this.length,
      {this.file = '<input>', this.offset = 0});
  final int line;
  final int column;
  final int length;
  final String file;
  final int offset;
  @override
  String toString() => '$file:$line:$column';
}

class CompilerException implements Exception {
  const CompilerException(this.code, this.message, this.span);
  final String code;
  final String message;
  final SourceSpan span;
  @override
  String toString() => '$span: $code: $message';
}
