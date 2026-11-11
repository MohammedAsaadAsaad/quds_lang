import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
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
}
