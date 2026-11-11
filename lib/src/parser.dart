import 'dart:convert';
import 'ast.dart';
import 'lexer.dart';

class Parser {
  Parser(this.tokens);
  final List<Token> tokens;
  int index = 0;
  Token get current => tokens[index];
  Token peek([int n = 1]) => tokens[(index + n).clamp(0, tokens.length - 1)];
  bool at(TokenKind kind) => current.kind == kind;
  bool word(String value) =>
      at(TokenKind.identifier) && current.lexeme == value;
  Token take() => tokens[index++];
  bool match(TokenKind kind) {
    if (!at(kind)) return false;
    take();
    return true;
  }

  Never fail(String message, [SourceSpan? span]) =>
      throw CompilerException('Q100', message, span ?? current.span);
  Token expect(TokenKind kind, String description) {
    if (!at(kind)) fail('Expected $description, found ${current.kind.name}');
    return take();
  }

  Token name() {
    final token = expect(TokenKind.identifier, 'identifier');
    const reserved = {
      'if',
      'else',
      'for',
      'in',
      'return',
      'var',
      'const',
      'shadow',
      'true',
      'false',
      'null',
      'and',
      'or',
      'not'
    };
    if (reserved.contains(token.lexeme))
      fail('Reserved word cannot be a name', token.span);
    return token;
  }

  SourceSpan extent(SourceSpan start) {
    final last = tokens[index == 0 ? 0 : index - 1].span;
    return SourceSpan(
        start.line, start.column, last.offset + last.length - start.offset,
        file: start.file, offset: start.offset);
  }

  Program parse() {
    final span = current.span;
    final statements = <Statement>[];
    while (!at(TokenKind.eof)) {
      statements.add(statement(topLevel: true));
    }
    return Program(statements, extent(span));
  }

  bool functionAhead() {
    if (!at(TokenKind.identifier) || peek().kind != TokenKind.leftParen)
      return false;
    var depth = 0;
    for (var j = index + 1; j < tokens.length; j++) {
      if (tokens[j].kind == TokenKind.leftParen) depth++;
      if (tokens[j].kind == TokenKind.rightParen) {
        depth--;
        if (depth == 0) {
          final next = tokens[j + 1].kind;
          return next == TokenKind.colon ||
              next == TokenKind.arrow ||
              next == TokenKind.equals;
        }
      }
    }
    return false;
  }

  Statement statement({bool topLevel = false}) {
    final span = current.span;
    if (topLevel && functionAhead()) return function();
    if (word('if')) return ifStatement();
    if (word('for')) {
      take();
      final variable = name();
      if (!word('in')) fail('Expected in');
      take();
      final iterable = expression();
      return ForStatement(variable.lexeme, iterable, block(), extent(span));
    }
    if (word('return')) {
      take();
      final value = at(TokenKind.newline) ? null : expression(bare: true);
      endLine();
      return ReturnStatement(value, extent(span));
    }
    var mode = BindingMode.inferred;
    if (word('var') || word('const') || word('shadow')) {
      mode = switch (take().lexeme) {
        'var' => BindingMode.mutable,
        'const' => BindingMode.constant,
        _ => BindingMode.shadow,
      };
    }
    final bindingAhead = at(TokenKind.identifier) &&
        (assignments.contains(peek().kind) ||
            peek().kind == TokenKind.colon &&
                peek(2).kind == TokenKind.identifier);
    if (bindingAhead || mode != BindingMode.inferred) {
      final bindingName = name();
      String? type;
      if (match(TokenKind.colon)) type = typeName();
      if (!assignments.contains(current.kind))
        fail('Expected binding initializer or assignment');
      final operator = take().lexeme;
      var value = expression(bare: true);
      if (at(TokenKind.colon)) {
        value = namedBlock(value);
      } else {
        endLine();
      }
      return Binding(
          bindingName.lexeme, mode, type, operator, value, extent(span));
    }
    var value = expression(bare: true);
    if (at(TokenKind.colon)) {
      value = namedBlock(value);
    } else {
      endLine();
    }
    return ExpressionStatement(value, extent(span));
  }

  static const assignments = {
    TokenKind.equals,
    TokenKind.plusEquals,
    TokenKind.minusEquals,
    TokenKind.starEquals,
    TokenKind.slashEquals
  };
  String typeName() {
    var result = name().lexeme;
    if (match(TokenKind.less)) {
      result += '<${typeName()}';
      while (match(TokenKind.comma)) {
        result += ', ${typeName()}';
      }
      expect(TokenKind.greater, '>');
      result += '>';
    }
    return result;
  }

  FunctionDeclaration function() {
    final token = name();
    expect(TokenKind.leftParen, '(');
    final parameters = <Parameter>[];
    if (!at(TokenKind.rightParen)) {
      do {
        final mutable = word('var');
        if (mutable) take();
        final parameter = name();
        expect(TokenKind.colon, ':');
        final type = typeName();
        parameters.add(
            Parameter(parameter.lexeme, type, mutable, extent(parameter.span)));
      } while (match(TokenKind.comma) && !at(TokenKind.rightParen));
    }
    expect(TokenKind.rightParen, ')');
    String? returnType;
    if (match(TokenKind.arrow)) returnType = typeName();
    if (match(TokenKind.equals)) {
      final value = expression(bare: true);
      endLine();
      return FunctionDeclaration(token.lexeme, parameters, returnType, null,
          value, extent(token.span));
    }
    return FunctionDeclaration(token.lexeme, parameters, returnType, block(),
        null, extent(token.span));
  }

  IfStatement ifStatement() {
    final token = take();
    final condition = expression();
    final body = block();
    final otherwise = <Statement>[];
    if (word('else')) {
      take();
      if (word('if')) {
        otherwise.add(ifStatement());
      } else {
        otherwise.addAll(block());
      }
    }
    return IfStatement(condition, body, otherwise, extent(token.span));
  }

  List<Statement> block() {
    expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'indented block');
    final body = <Statement>[];
    while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
      body.add(statement());
    }
    expect(TokenKind.dedent, 'end of block');
    return body;
  }

  void endLine() => expect(TokenKind.newline, 'end of line');
  Expression namedBlock(Expression callee) {
    expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'named argument block');
    final arguments = <Argument>[];
    while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
      final argument = name();
      expect(TokenKind.colon, ':');
      final value = expression(bare: true);
      endLine();
      arguments.add(Argument(argument.lexeme, value, argument.span));
    }
    expect(TokenKind.dedent, 'end of named argument block');
    if (callee is CallExpression) {
      return CallExpression(callee.callee, [...callee.arguments, ...arguments],
          extent(callee.span));
    }
    return CallExpression(callee, arguments, extent(callee.span));
  }

  int precedence(Token token) => switch (token.lexeme) {
        'or' => 1,
        'and' => 2,
        '==' || '!=' => 3,
        '<' || '<=' || '>' || '>=' => 4,
        '+' || '-' => 5,
        '*' || '/' || '%' => 6,
        _ => 0,
      };
  Expression expression({int minimum = 1, bool bare = false}) {
    var left = prefix();
    while (true) {
      if (at(TokenKind.leftParen)) {
        left = call(left);
        continue;
      }
      final power = precedence(current);
      if (power < minimum) break;
      final operator = take();
      final right = expression(minimum: power + 1);
      left = BinaryExpression(left, operator.lexeme, right, extent(left.span));
    }
    if (bare && left is Identifier && startsExpression()) {
      final argument = expression(bare: true);
      left = CallExpression(
          left, [Argument(null, argument, argument.span)], extent(left.span));
    }
    return left;
  }

  bool startsExpression() =>
      at(TokenKind.number) ||
      at(TokenKind.string) ||
      at(TokenKind.leftBracket) ||
      at(TokenKind.leftParen) ||
      at(TokenKind.identifier) &&
          !{'else', 'in', 'and', 'or'}.contains(current.lexeme);
  Expression prefix() {
    final token = take();
    if (token.kind == TokenKind.number) {
      final value = token.lexeme.contains('.')
          ? double.tryParse(token.lexeme)
          : int.tryParse(token.lexeme);
      if (value == null || value is double && !value.isFinite) {
        fail('Numeric literal is outside the supported native Dart range',
            token.span);
      }
      return Literal(value, token.span);
    }
    if (token.kind == TokenKind.string) return string(token);
    if (token.kind == TokenKind.minus ||
        token.kind == TokenKind.plus ||
        token.lexeme == 'not') {
      return UnaryExpression(
          token.lexeme, expression(minimum: 7), extent(token.span));
    }
    if (token.kind == TokenKind.identifier) {
      if (token.lexeme == 'true' ||
          token.lexeme == 'false' ||
          token.lexeme == 'null') {
        return Literal(
            switch (token.lexeme) {
              'true' => true,
              'false' => false,
              _ => null
            },
            token.span);
      }
      const unsupported = {
        'class',
        'while',
        'match',
        'use',
        'async',
        'await',
        'missing',
        'readonly',
        'capture',
        'break',
        'continue',
        'return',
        'var',
        'const',
        'shadow',
        'if',
        'else',
        'for'
      };
      if (unsupported.contains(token.lexeme))
        fail('Unsupported syntax: ${token.lexeme}', token.span);
      return Identifier(token.lexeme, token.span);
    }
    if (token.kind == TokenKind.leftParen) {
      final value = expression();
      expect(TokenKind.rightParen, ')');
      return value;
    }
    if (token.kind == TokenKind.leftBracket) {
      final values = <Expression>[];
      if (!at(TokenKind.rightBracket)) {
        do {
          values.add(expression());
        } while (match(TokenKind.comma) && !at(TokenKind.rightBracket));
      }
      expect(TokenKind.rightBracket, ']');
      return ListExpression(values, extent(token.span));
    }
    fail('Expected expression', token.span);
  }

  CallExpression call(Expression callee) {
    take();
    final arguments = <Argument>[];
    if (!at(TokenKind.rightParen)) {
      do {
        String? label;
        final span = current.span;
        if (at(TokenKind.identifier) && peek().kind == TokenKind.colon) {
          label = name().lexeme;
          take();
        }
        arguments.add(Argument(label, expression(), span));
      } while (match(TokenKind.comma) && !at(TokenKind.rightParen));
    }
    expect(TokenKind.rightParen, ')');
    return CallExpression(callee, arguments, extent(callee.span));
  }

  Expression string(Token token) {
    final text = token.lexeme;
    final width = text.startsWith(text[0] * 3) ? 3 : 1;
    final content = text.substring(width, text.length - width);
    final parts = <Expression>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isNotEmpty) {
        parts.add(Literal(buffer.toString(), token.span));
        buffer.clear();
      }
    }

    for (var i = 0; i < content.length; i++) {
      final ch = content[i];
      if (ch == '\\') {
        i++;
        buffer.write(switch (content[i]) {
          'n' => '\n',
          'r' => '\r',
          't' => '\t',
          _ => content[i]
        });
      } else if (ch == '{') {
        flush();
        final start = i + 1;
        var depth = 1;
        while (++i < content.length && depth > 0) {
          if (content[i] == '\\') {
            i++;
            continue;
          }
          if (content[i] == '\"' || content[i] == "'") {
            final quote = content[i];
            final delimiter =
                content.startsWith(quote * 3, i) ? quote * 3 : quote;
            i += delimiter.length;
            while (i < content.length && !content.startsWith(delimiter, i)) {
              if (content[i] == '\\') i++;
              i++;
            }
            i += delimiter.length - 1;
            continue;
          }
          if (content[i] == '{') depth++;
          if (content[i] == '}') depth--;
          if (depth == 0) break;
        }
        if (depth != 0) fail('Unclosed interpolation', token.span);
        final prefix = text.substring(0, width + start);
        final lines =
            prefix.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
        final line = token.span.line + lines.length - 1;
        final column = lines.length == 1
            ? token.span.column + prefix.length
            : lines.last.length + 1;
        final offset = token.span.offset + utf8.encode(prefix).length;
        final nestedTokens = Lexer()
            .tokenize(content.substring(start, i), file: token.span.file)
            .map((t) => Token(
                t.kind,
                t.lexeme,
                SourceSpan(
                    line + t.span.line - 1,
                    t.span.line == 1
                        ? column + t.span.column - 1
                        : t.span.column,
                    t.span.length,
                    file: token.span.file,
                    offset: offset + t.span.offset)))
            .toList();
        final parser = Parser(nestedTokens);
        final value = parser.expression();
        parser.endLine();
        parser.expect(TokenKind.eof, 'end of interpolation');
        parts.add(value);
      } else if (ch == '}') {
        fail('Escape literal braces with a backslash', token.span);
      } else {
        buffer.write(ch);
      }
    }
    flush();
    if (parts.every((p) => p is Literal))
      return Literal(parts.map((p) => (p as Literal).value).join(), token.span);
    return InterpolatedString(parts, token.span);
  }
}
