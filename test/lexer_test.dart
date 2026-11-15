import 'dart:convert';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('UTF-8 span indexing preserves supplementary Unicode and CRLF', () {
    const source = '𐐀 = "😀"\r\nπ = 3.14\n';
    final tokens = const Lexer().tokenize(source);
    final identifiers =
        tokens.where((t) => t.kind == TokenKind.identifier).toList();
    expect(identifiers.first.lexeme, '𐐀');
    expect(identifiers.first.span.length, 4);
    expect(identifiers.last.span.offset, 15);
    expect(identifiers.last.span.line, 2);
    expect(tokens.firstWhere((t) => t.kind == TokenKind.equals).span.column, 4);
    final bytes = utf8.encode(source);
    for (final token in tokens) {
      expect(
          utf8.decode(bytes.sublist(
              token.span.offset, token.span.offset + token.span.length)),
          token.lexeme);
    }
  });
  final lexer = Lexer();

  test('emits indentation and dedentation for nested blocks', () {
    final tokens = lexer.tokenize('main():\n  print "Hello"\nprint "Done"\n');
    final kinds = tokens.map((t) => t.kind).toList();
    expect(kinds.where((k) => k == TokenKind.indent).length, 1);
    expect(kinds.where((k) => k == TokenKind.dedent).length, 1);
    expect(kinds.last, TokenKind.eof);
  });

  test('ignores blank lines and comment-only lines for indentation', () {
    final tokens = lexer.tokenize('main():\n\n  # comment\n  x = 10\n');
    expect(tokens.where((t) => t.kind == TokenKind.indent).length, 1);
  });

  test('rejects indentation not matching a prior level', () {
    expect(
      () => lexer.tokenize('main():\n    x = 1\n  y = 2\n'),
      throwsA(isA<LexerException>()),
    );
  });

  test('rejects tab indentation', () {
    expect(
      () => lexer.tokenize('main():\n\tx = 1\n'),
      throwsA(isA<LexerException>()),
    );
  });
  test('golden tokens include source coordinates and comments disappear', () {
    final tokens = lexer.tokenize('x = 12.5 # ignored\n', file: 'sample.quds');
    expect(
        tokens.map((t) =>
            '${t.kind.name}:${t.lexeme}:${t.span.line}:${t.span.column}:${t.span.offset}:${t.span.length}'),
        [
          'identifier:x:1:1:0:1',
          'equals:=:1:3:2:1',
          'number:12.5:1:5:4:4',
          'newline::1:19:18:0',
          'eof::2:1:19:0',
        ]);
    expect(tokens.every((t) => t.span.file == 'sample.quds'), isTrue);
  });
  test('brackets suppress continuation indentation and newlines', () {
    final tokens = lexer.tokenize('f(\n  [1,\n   2]\n)\n');
    expect(tokens.where((t) => t.kind == TokenKind.newline), hasLength(1));
    expect(tokens.where((t) => t.kind == TokenKind.indent), isEmpty);
  });
  test('Unicode identifiers have UTF-8 byte offsets', () {
    final tokens = lexer.tokenize('قدس = 1\n');
    expect(tokens.first.lexeme, 'قدس');
    expect(tokens.first.span.length, 6);
    expect(tokens[1].span.offset, 7);
    expect(tokens[1].span.column, 5);
  });
  test('line endings preserve original byte offsets', () {
    final tokens = lexer.tokenize('x = 1\r\ny = 2\rz = 3');
    final y = tokens.firstWhere((t) => t.lexeme == 'y');
    final z = tokens.firstWhere((t) => t.lexeme == 'z');
    expect([y.span.line, y.span.column, y.span.offset], [2, 1, 7]);
    expect([z.span.line, z.span.column, z.span.offset], [3, 1, 13]);
  });
  test('nested comments and documentation comments', () {
    final tokens =
        lexer.tokenize('/* a /* b */ c */\n/// docs\nx = 1 /* trailing */\n');
    expect(
        tokens
            .where((t) => t.kind == TokenKind.identifier)
            .map((t) => t.lexeme),
        ['x']);
    expect(tokens.where((t) => t.kind == TokenKind.newline), hasLength(1));
  });
  test('multiple dedents occur at end of file without final newline', () {
    final tokens = lexer.tokenize('main():\n  if true:\n    print 1');
    expect(tokens.reversed.take(4).map((t) => t.kind), [
      TokenKind.eof,
      TokenKind.dedent,
      TokenKind.dedent,
      TokenKind.newline,
    ]);
  });
  test('leading block comments preserve the line indentation', () {
    final tokens = lexer.tokenize('main():\n  /* note */ print 1\n  print 2\n');
    expect(tokens.where((t) => t.kind == TokenKind.indent), hasLength(1));
    expect(tokens.where((t) => t.kind == TokenKind.dedent), hasLength(1));
  });
  test('operators use longest match', () {
    final tokens =
        lexer.tokenize('a += 1\nb != 2\nc <= 3\nf() -> int:\n  return 1\n');
    expect(
        tokens.map((t) => t.kind),
        containsAll([
          TokenKind.plusEquals,
          TokenKind.bangEqual,
          TokenKind.lessEqual,
          TokenKind.arrow,
        ]));
  });
  for (final source in [
    '(]',
    '(1',
    '"unterminated',
    '/* open',
    'x++',
    '"bad\\q"'
  ]) {
    test('rejects invalid lexeme: $source', () {
      expect(() => lexer.tokenize(source), throwsA(isA<LexerException>()));
    });
  }
}
