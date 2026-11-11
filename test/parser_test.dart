import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

Program parse(String source) => Parser(Lexer().tokenize(source)).parse();

void main() {
  test('Pratt precedence, associativity, grouping and source location', () {
    final program = parse('main():\n  x = 8 - 3 - 1 * (2 + 4)\n');
    final body = (program.statements.single as FunctionDeclaration).body!;
    final value = (body.single as Binding).value as BinaryExpression;
    expect(value.operator, '-');
    expect((value.left as BinaryExpression).operator, '-');
    expect((value.right as BinaryExpression).operator, '*');
    expect(value.span.line, 2);
    expect(value.span.column, 7);
  });
  test('typed function, return, nested blocks and else-if', () {
    final program = parse(
        'f(a: int) -> int:\n  if a > 0:\n    return a\n  else if a == 0:\n    return 1\n  else:\n    return -a\n');
    final function = program.statements.single as FunctionDeclaration;
    expect(function.returnType, 'int');
    final condition = function.body!.single as IfStatement;
    expect(condition.thenBody.single, isA<ReturnStatement>());
    expect(condition.elseBody.single, isA<IfStatement>());
  });
  test('positional, inline named and block named calls share AST', () {
    final program = parse(
        'main():\n  send(1):\n    b: 2\n  send(a: 3, b: 4)\n  print send(5, 6)\n');
    final body = (program.statements.single as FunctionDeclaration).body!;
    final call =
        (body.first as ExpressionStatement).expression as CallExpression;
    expect(call.arguments.map((a) => a.name), [null, 'b']);
    final print =
        (body.last as ExpressionStatement).expression as CallExpression;
    expect(print.arguments.single.value, isA<CallExpression>());
  });
  for (final source in [
    'main():\nprint 1\n',
    'main():\n  x = [1, 2\n',
    'main():\n  print(1 2)\n',
    'main():\n  if true\n    print 1\n',
    'main():\n  return 1 2\n',
    'main():\n  x = 999999999999999999999999999999999999\n',
  ]) {
    test('rejects malformed program: ${source.replaceAll('\n', r'\n')}', () {
      expect(() => parse(source), throwsA(isA<CompilerException>()));
    });
  }
  test('interpolation parses real expressions at original coordinates', () {
    final program = parse('main():\n  print "value {unknown + 1}"\n');
    final call = ((program.statements.single as FunctionDeclaration)
            .body!
            .single as ExpressionStatement)
        .expression as CallExpression;
    final string = call.arguments.single.value as InterpolatedString;
    final value = string.parts.last as BinaryExpression;
    expect(value.left.span.line, 2);
    expect(value.left.span.column, 17);
    expect(value.left.span.offset, 24);
  });
}
