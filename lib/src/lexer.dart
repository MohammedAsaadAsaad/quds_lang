import 'source.dart';
export 'source.dart';

enum TokenKind {
  identifier,
  number,
  string,
  colon,
  comma,
  leftParen,
  rightParen,
  leftBracket,
  rightBracket,
  equals,
  plus,
  minus,
  star,
  slash,
  percent,
  plusEquals,
  minusEquals,
  starEquals,
  slashEquals,
  equalEqual,
  bangEqual,
  less,
  lessEqual,
  greater,
  greaterEqual,
  arrow,
  dot,
  dotDot,
  dotDotLess,
  spread,
  spreadQuestion,
  question,
  questionQuestion,
  questionQuestionEquals,
  questionDot,
  bang,
  pipe,
  pipeGreater,
  amp,
  caret,
  tilde,
  tildeSlash,
  shiftLeft,
  shiftRight,
  unsignedShiftRight,
  at,
  toQuestion,
  withQuestion,
  newline,
  indent,
  dedent,
  eof,
}

class Token {
  const Token(this.kind, this.lexeme, this.span, {this.documentation});
  final TokenKind kind;
  final String lexeme;
  final SourceSpan span;

  /// `#` or `///` lines immediately above this token.
  final String? documentation;
  @override
  String toString() => '${kind.name}($lexeme)@$span';
}

class LexerException extends CompilerException {
  const LexerException(String code, String message, SourceSpan span)
      : super(code, message, span);
}

class Lexer {
  static RegExp get identifierStart => _Scanner.identifierStart;
  static RegExp get identifierPart => _Scanner.identifierPart;
  const Lexer();
  List<Token> tokenize(String source, {String file = '<input>'}) =>
      _Scanner(source, file).scan();
}

class _Scanner {
  _Scanner(this.source, this.file) : _byteOffsets = _utf8Offsets(source);
  final String source;
  final String file;
  final List<int> _byteOffsets;
  final tokens = <Token>[];
  final indents = <int>[0];
  final brackets = <Token>[];
  final _pendingDocs = <String>[];
  var _docLine = 0;

  /// Parentheses hide newlines. Square brackets keep them so a collection
  /// `if` or `for` can use an indented suite.
  bool get _insideParen =>
      brackets.any((token) => token.kind == TokenKind.leftParen);
  int i = 0, line = 1, column = 1;
  bool lineStart = true, hasCode = false;
  static final identifierStart = RegExp(r'^[\p{L}\p{Nl}_]$', unicode: true);
  static final identifierPart =
      RegExp(r'^[\p{L}\p{Nl}\p{N}\p{M}_]$', unicode: true);
  bool get end => i >= source.length;
  String get ch => end ? '' : source[i];
  String get rune {
    if (end) return '';
    final first = source.codeUnitAt(i);
    if (first >= 0xd800 && first <= 0xdbff && i + 1 < source.length) {
      final second = source.codeUnitAt(i + 1);
      if (second >= 0xdc00 && second <= 0xdfff)
        return source.substring(i, i + 2);
    }
    return source[i];
  }

  bool at(String value) => source.startsWith(value, i);
  SourceSpan span(int start, int startLine, int startColumn) =>
      SourceSpan(startLine, startColumn, _byteOffsets[i] - _byteOffsets[start],
          file: file, offset: _byteOffsets[start]);
  SourceSpan get here =>
      SourceSpan(line, column, 0, file: file, offset: _byteOffsets[i]);
  Never fail(String code, String message, [SourceSpan? location]) =>
      throw LexerException(code, message, location ?? here);
  void advance() {
    if (ch == '\r') {
      i++;
      if (ch == '\n') i++;
      line++;
      column = 1;
    } else if (ch == '\n') {
      i++;
      line++;
      column = 1;
    } else {
      i++;
      column++;
    }
  }

  void emit(TokenKind kind, int start, int sl, int sc) {
    tokens.add(Token(kind, source.substring(start, i), span(start, sl, sc),
        documentation: _claimDocs(sl)));
    hasCode = true;
  }

  void _noteDoc(String text) {
    if (_pendingDocs.isNotEmpty && line != _docLine + 1) _pendingDocs.clear();
    _pendingDocs.add(text);
    _docLine = line;
  }

  String? _claimDocs(int tokenLine) {
    if (_pendingDocs.isEmpty || tokenLine != _docLine + 1) {
      if (tokenLine > _docLine + 1) _pendingDocs.clear();
      return null;
    }
    final text = _pendingDocs.join('\n');
    _pendingDocs.clear();
    return text;
  }

  void blockComment() {
    final location = here;
    advance();
    advance();
    var depth = 1;
    while (!end && depth > 0) {
      if (at('/*')) {
        depth++;
        advance();
        advance();
      } else if (at('*/')) {
        depth--;
        advance();
        advance();
      } else {
        advance();
      }
    }
    if (depth != 0) fail('E004', 'Unterminated block comment', location);
  }

  List<Token> scan() {
    while (!end) {
      if (lineStart) {
        var spaces = 0;
        while (ch == ' ') {
          spaces++;
          advance();
        }
        if (ch == '\t') fail('E002', 'Tabs are not permitted for indentation');
        while (at('/*')) {
          blockComment();
          while (ch == ' ') {
            advance();
          }
          if (ch == '\t')
            fail('E002', 'Tabs are not permitted for indentation');
        }
        if (end) break;
        if (ch != '\n' &&
            ch != '\r' &&
            ch != '#' &&
            !at('///') &&
            !_insideParen) {
          if (spaces > indents.last) {
            indents.add(spaces);
            tokens.add(Token(TokenKind.indent, '', here));
          } else {
            while (spaces < indents.last) {
              indents.removeLast();
              tokens.add(Token(TokenKind.dedent, '', here));
            }
            if (spaces != indents.last)
              fail('E001', 'Indentation does not match any outer block');
          }
        }
        lineStart = false;
      }
      if (ch == ' ' || ch == '\t') {
        advance();
        continue;
      }
      if (ch == '#' || at('///') || at('//')) {
        final hash = ch == '#';
        final triple = at('///');
        final fullLine = !hasCode;
        if (hash) {
          advance();
        } else if (triple) {
          advance();
          advance();
          advance();
        } else {
          advance();
          advance();
        }
        final start = i;
        while (!end && ch != '\n' && ch != '\r') {
          advance();
        }
        if (fullLine && (hash || triple)) {
          var text = source.substring(start, i);
          if (text.startsWith(' ')) text = text.substring(1);
          _noteDoc(text);
        }
        continue;
      }
      if (at('/*')) {
        blockComment();
        continue;
      }
      if (ch == '\n' || ch == '\r') {
        if (!hasCode && _pendingDocs.isNotEmpty && line != _docLine) {
          _pendingDocs.clear();
        }
        if (hasCode && !_insideParen) {
          tokens.add(Token(TokenKind.newline, '', here));
          hasCode = false;
        }
        advance();
        lineStart = true;
        continue;
      }
      final start = i, sl = line, sc = column;
      if (ch == 'r' &&
          i + 1 < source.length &&
          (source[i + 1] == '"' || source[i + 1] == "'")) {
        advance();
        scanString(raw: true);
        emit(TokenKind.string, start, sl, sc);
        continue;
      }
      if (ch == '"' || ch == "'") {
        scanString();
        emit(TokenKind.string, start, sl, sc);
        continue;
      }
      if (identifierStart.hasMatch(rune)) {
        final width = rune.length;
        for (var n = 0; n < width; n++) {
          advance();
        }
        while (!end && identifierPart.hasMatch(rune)) {
          final width = rune.length;
          for (var n = 0; n < width; n++) {
            advance();
          }
        }
        final word = source.substring(start, i);
        if ((word == 'to' || word == 'with') &&
            ch == '?' &&
            (i + 1 >= source.length ||
                (source[i + 1] != '?' && source[i + 1] != '.'))) {
          advance();
          emit(word == 'to' ? TokenKind.toQuestion : TokenKind.withQuestion,
              start, sl, sc);
          continue;
        }
        emit(TokenKind.identifier, start, sl, sc);
        continue;
      }
      if (RegExp(r'[0-9]').hasMatch(ch)) {
        if (ch == '0' &&
            i + 1 < source.length &&
            (source[i + 1] == 'x' || source[i + 1] == 'X')) {
          advance();
          advance();
          if (end || !RegExp(r'[0-9a-fA-F]').hasMatch(ch)) {
            fail('E006', 'Invalid hex literal');
          }
          while (!end && (RegExp(r'[0-9a-fA-F]').hasMatch(ch) || ch == '_')) {
            advance();
          }
          emit(TokenKind.number, start, sl, sc);
          continue;
        }
        while (!end && (RegExp(r'[0-9]').hasMatch(ch) || ch == '_')) {
          advance();
        }
        if (ch == '.' &&
            i + 1 < source.length &&
            RegExp(r'[0-9]').hasMatch(source[i + 1])) {
          advance();
          while (!end && (RegExp(r'[0-9]').hasMatch(ch) || ch == '_')) {
            advance();
          }
        }
        if (ch == 'e' || ch == 'E') {
          final next = i + 1 < source.length ? source[i + 1] : '';
          final sign = next == '+' || next == '-';
          final digitAt = sign ? i + 2 : i + 1;
          if (digitAt < source.length &&
              RegExp(r'[0-9]').hasMatch(source[digitAt])) {
            advance();
            if (sign) advance();
            while (!end && (RegExp(r'[0-9]').hasMatch(ch) || ch == '_')) {
              advance();
            }
          }
        }
        emit(TokenKind.number, start, sl, sc);
        continue;
      }
      final four = i + 3 < source.length ? source.substring(i, i + 4) : '';
      if (four == '...?') {
        advance();
        advance();
        advance();
        advance();
        emit(TokenKind.spreadQuestion, start, sl, sc);
        continue;
      }
      final triple = i + 2 < source.length ? source.substring(i, i + 3) : '';
      if (triple == '...') {
        advance();
        advance();
        advance();
        emit(TokenKind.spread, start, sl, sc);
        continue;
      }
      if (triple == '..<') {
        advance();
        advance();
        advance();
        emit(TokenKind.dotDotLess, start, sl, sc);
        continue;
      }
      if (triple == '>>>') {
        advance();
        advance();
        advance();
        emit(TokenKind.unsignedShiftRight, start, sl, sc);
        continue;
      }
      if (triple == '??=') {
        advance();
        advance();
        advance();
        emit(TokenKind.questionQuestionEquals, start, sl, sc);
        continue;
      }
      const pairs = {
        '->': TokenKind.arrow,
        '+=': TokenKind.plusEquals,
        '-=': TokenKind.minusEquals,
        '*=': TokenKind.starEquals,
        '/=': TokenKind.slashEquals,
        '==': TokenKind.equalEqual,
        '!=': TokenKind.bangEqual,
        '<=': TokenKind.lessEqual,
        '>=': TokenKind.greaterEqual,
        '..': TokenKind.dotDot,
        '??': TokenKind.questionQuestion,
        '?.': TokenKind.questionDot,
        '|>': TokenKind.pipeGreater,
        '~/': TokenKind.tildeSlash,
        '<<': TokenKind.shiftLeft,
        '>>': TokenKind.shiftRight,
      };
      final pair = i + 1 < source.length ? source.substring(i, i + 2) : '';
      if (pairs.containsKey(pair)) {
        advance();
        advance();
        emit(pairs[pair]!, start, sl, sc);
        continue;
      }
      const singles = {
        ':': TokenKind.colon,
        ',': TokenKind.comma,
        '(': TokenKind.leftParen,
        ')': TokenKind.rightParen,
        '[': TokenKind.leftBracket,
        ']': TokenKind.rightBracket,
        '=': TokenKind.equals,
        '+': TokenKind.plus,
        '-': TokenKind.minus,
        '*': TokenKind.star,
        '/': TokenKind.slash,
        '%': TokenKind.percent,
        '<': TokenKind.less,
        '>': TokenKind.greater,
        '.': TokenKind.dot,
        '?': TokenKind.question,
        '!': TokenKind.bang,
        '|': TokenKind.pipe,
        '&': TokenKind.amp,
        '^': TokenKind.caret,
        '~': TokenKind.tilde,
        '@': TokenKind.at,
      };
      if (ch == ';') fail('E102', 'A semicolon is not allowed');
      final kind = singles[ch];
      if (kind == null) fail('E003', 'Unexpected character: $ch');
      if ((ch == '+' || ch == '-') && at('$ch$ch')) {
        fail('E003',
            'Increment/decrement are not supported; use compound assignment');
      }
      advance();
      emit(kind, start, sl, sc);
      if (kind == TokenKind.leftParen || kind == TokenKind.leftBracket) {
        brackets.add(tokens.last);
      } else if (kind == TokenKind.rightParen ||
          kind == TokenKind.rightBracket) {
        final expected = kind == TokenKind.rightParen
            ? TokenKind.leftParen
            : TokenKind.leftBracket;
        if (brackets.isEmpty || brackets.last.kind != expected)
          fail('E100', 'Mismatched closing bracket', tokens.last.span);
        brackets.removeLast();
      }
    }
    if (brackets.isNotEmpty)
      fail('E100', 'Unclosed bracket', brackets.last.span);
    if (hasCode) tokens.add(Token(TokenKind.newline, '', here));
    while (indents.length > 1) {
      indents.removeLast();
      tokens.add(Token(TokenKind.dedent, '', here));
    }
    tokens.add(Token(TokenKind.eof, '', here));
    return tokens;
  }

  void scanString({bool raw = false}) {
    final location = here, quote = ch;
    final triple = at(quote * 3);
    final delimiter = quote * (triple ? 3 : 1);
    for (var n = 0; n < delimiter.length; n++) {
      advance();
    }
    while (!end) {
      if (at(delimiter)) {
        for (var n = 0; n < delimiter.length; n++) {
          advance();
        }
        return;
      }
      if (!raw && ch == '{') {
        advance();
        var depth = 1;
        while (!end && depth > 0) {
          if (ch == '\"' || ch == "'") {
            scanString();
          } else if (at('/*')) {
            blockComment();
          } else if (ch == '{') {
            depth++;
            advance();
          } else if (ch == '}') {
            depth--;
            advance();
          } else {
            advance();
          }
        }
        if (depth != 0) fail('E004', 'Unclosed interpolation', location);
      } else if (!raw && ch == '\\') {
        advance();
        if (end) break;
        if (!'nrt\\\'"{}\$'.contains(ch)) {
          fail('E005', 'Unsupported string escape');
        }
        advance();
      } else {
        if (!triple && (ch == '\n' || ch == '\r'))
          fail('E004', 'Unterminated string', location);
        advance();
      }
    }
    fail('E004', 'Unterminated string', location);
  }
}

// Index UTF-8 offsets once rather than re-encoding every token's source prefix.
// Columns still use the original UTF-16 indices, and CRLF bytes remain intact.
List<int> _utf8Offsets(String source) {
  final offsets = List<int>.filled(source.length + 1, 0);
  var index = 0;
  var bytes = 0;
  for (final rune in source.runes) {
    offsets[index] = bytes;
    if (rune > 0xffff) {
      offsets[index + 1] = bytes + 3;
      index += 2;
      bytes += 4;
    } else {
      index++;
      bytes += rune <= 0x7f
          ? 1
          : rune <= 0x7ff
              ? 2
              : 3;
    }
    offsets[index] = bytes;
  }
  return offsets;
}
