/// Minimal indentation-aware lexer bootstrap for Quds.
///
/// This intentionally implements only a small lexical subset. It is not a
/// parser or a full implementation of the Quds language specification.
enum TokenKind {
  identifier,
  number,
  string,
  colon,
  comma,
  leftParen,
  rightParen,
  equals,
  plus,
  minus,
  star,
  slash,
  newline,
  indent,
  dedent,
  eof,
}

class SourceSpan {
  const SourceSpan(this.line, this.column, this.length);

  final int line;
  final int column;
  final int length;

  @override
  String toString() => '$line:$column+$length';
}

class Token {
  const Token(this.kind, this.lexeme, this.span);

  final TokenKind kind;
  final String lexeme;
  final SourceSpan span;

  @override
  String toString() => '${kind.name}($lexeme)@${span.toString()}';
}

class LexerException implements Exception {
  const LexerException(this.message, this.span);

  final String message;
  final SourceSpan span;

  @override
  String toString() => 'LexerException at $span: $message';
}

class Lexer {
  const Lexer();

  List<Token> tokenize(String source) {
    final result = <Token>[];
    final indents = <int>[0];
    final lines = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final lineNumber = lineIndex + 1;
      final line = lines[lineIndex];
      var offset = 0;
      while (offset < line.length && line[offset] == ' ') {
        offset++;
      }
      if (offset < line.length && line[offset] == '\t') {
        throw LexerException('Tabs are not permitted for indentation',
            SourceSpan(lineNumber, offset + 1, 1));
      }
      final rest = line.substring(offset).trim();
      if (rest.isEmpty || rest.startsWith('#')) continue;

      if (offset > indents.last) {
        indents.add(offset);
        result.add(Token(TokenKind.indent, '', SourceSpan(lineNumber, 1, offset)));
      } else if (offset < indents.last) {
        while (indents.length > 1 && offset < indents.last) {
          indents.removeLast();
          result.add(Token(TokenKind.dedent, '', SourceSpan(lineNumber, 1, 0)));
        }
        if (offset != indents.last) {
          throw LexerException('Indentation does not match any outer block',
              SourceSpan(lineNumber, 1, offset));
        }
      }

      while (offset < line.length) {
        final ch = line[offset];
        if (ch == ' ' || ch == '\t') {
          offset++;
          continue;
        }
        if (ch == '#') break;
        final column = offset + 1;
        if (_isIdentifierStart(ch)) {
          final start = offset++;
          while (offset < line.length && _isIdentifierPart(line[offset])) {
            offset++;
          }
          result.add(Token(TokenKind.identifier, line.substring(start, offset),
              SourceSpan(lineNumber, column, offset - start)));
          continue;
        }
        if (_isDigit(ch)) {
          final start = offset++;
          while (offset < line.length && _isDigit(line[offset])) {
            offset++;
          }
          if (offset + 1 < line.length &&
              line[offset] == '.' &&
              _isDigit(line[offset + 1])) {
            offset++;
            while (offset < line.length && _isDigit(line[offset])) {
              offset++;
            }
          }
          result.add(Token(TokenKind.number, line.substring(start, offset),
              SourceSpan(lineNumber, column, offset - start)));
          continue;
        }
        if (ch == '"' || ch == "'") {
          final quote = ch;
          final start = offset++;
          var terminated = false;
          while (offset < line.length) {
            if (line[offset] == '\\') {
              offset += 2;
              continue;
            }
            if (line[offset] == quote) {
              offset++;
              terminated = true;
              break;
            }
            offset++;
          }
          if (!terminated) {
            throw LexerException('Unterminated string',
                SourceSpan(lineNumber, column, line.length - start));
          }
          result.add(Token(TokenKind.string, line.substring(start, offset),
              SourceSpan(lineNumber, column, offset - start)));
          continue;
        }
        final kind = switch (ch) {
          ':' => TokenKind.colon,
          ',' => TokenKind.comma,
          '(' => TokenKind.leftParen,
          ')' => TokenKind.rightParen,
          '=' => TokenKind.equals,
          '+' => TokenKind.plus,
          '-' => TokenKind.minus,
          '*' => TokenKind.star,
          '/' => TokenKind.slash,
          _ => null,
        };
        if (kind == null) {
          throw LexerException('Unexpected character: $ch',
              SourceSpan(lineNumber, column, 1));
        }
        result.add(Token(kind, ch, SourceSpan(lineNumber, column, 1)));
        offset++;
      }
      result.add(Token(TokenKind.newline, '', SourceSpan(lineNumber, line.length + 1, 0)));
    }
    while (indents.length > 1) {
      indents.removeLast();
      result.add(Token(TokenKind.dedent, '', SourceSpan(lines.length, 1, 0)));
    }
    result.add(Token(TokenKind.eof, '', SourceSpan(lines.length, 1, 0)));
    return result;
  }

  bool _isDigit(String ch) => RegExp(r'^[0-9]$').hasMatch(ch);
  bool _isIdentifierStart(String ch) => RegExp(r'^[a-zA-Z_]$').hasMatch(ch);
  bool _isIdentifierPart(String ch) => RegExp(r'^[a-zA-Z0-9_]$').hasMatch(ch);
}
