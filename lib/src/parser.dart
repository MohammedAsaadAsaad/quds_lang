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
      'not',
      'while',
      'break',
      'continue',
      'label',
      'match',
      'switch',
      'class',
      'sealed',
      'use',
      'await',
      'async',
      'type',
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
          var k = j + 1;
          if (tokens[k].kind == TokenKind.identifier &&
              (tokens[k].lexeme == 'async' || tokens[k].lexeme == 'sync')) {
            k++;
            if (k < tokens.length && tokens[k].kind == TokenKind.star) k++;
          }
          final next = tokens[k].kind;
          if (next != TokenKind.colon &&
              next != TokenKind.arrow &&
              next != TokenKind.equals) {
            return false;
          }
          return _parameterList(index + 2, j);
        }
      }
    }
    return false;
  }

  /// A function parameter list is empty or `name: Type` entries.
  /// `send(1):` is a call with a named-argument block, not a local function.
  bool _parameterList(int start, int end) {
    var i = start;
    if (i == end) return true;
    while (i < end) {
      if (tokens[i].lexeme == 'var') i++;
      if (i >= end || tokens[i].kind != TokenKind.identifier) return false;
      i++;
      if (i >= end || tokens[i].kind != TokenKind.colon) return false;
      i++;
      if (!_skipType(i, end, (next) => i = next)) return false;
      if (i < end && tokens[i].lexeme == 'required') i++;
      if (i < end && tokens[i].kind == TokenKind.equals) {
        i++;
        var depth = 0;
        while (i < end) {
          final kind = tokens[i].kind;
          if (kind == TokenKind.leftParen || kind == TokenKind.leftBracket) {
            depth++;
          }
          if (kind == TokenKind.rightParen || kind == TokenKind.rightBracket) {
            depth--;
          }
          if (depth == 0 && kind == TokenKind.comma) break;
          i++;
        }
      }
      if (i < end && tokens[i].kind == TokenKind.comma) {
        i++;
        continue;
      }
      return i == end;
    }
    return true;
  }

  bool _skipType(int start, int end, void Function(int) move) {
    if (start >= end) return false;
    final token = tokens[start];
    if (token.kind == TokenKind.leftParen) {
      var depth = 0;
      var i = start;
      while (i < end) {
        if (tokens[i].kind == TokenKind.leftParen) depth++;
        if (tokens[i].kind == TokenKind.rightParen) {
          depth--;
          if (depth == 0) {
            move(i + 1);
            return true;
          }
        }
        i++;
      }
      return false;
    }
    if (token.kind != TokenKind.identifier) return false;
    var i = start + 1;
    if (i < end && tokens[i].kind == TokenKind.less) {
      var depth = 0;
      while (i < end) {
        if (tokens[i].kind == TokenKind.less) depth++;
        if (tokens[i].kind == TokenKind.greater) {
          depth--;
          if (depth == 0) {
            i++;
            break;
          }
        }
        i++;
      }
    }
    if (i < end && tokens[i].kind == TokenKind.question) i++;
    move(i);
    return true;
  }

  List<String> takeAnnotations() {
    final notes = <String>[];
    while (at(TokenKind.at)) {
      take();
      notes.add(name().lexeme);
      if (at(TokenKind.newline) && peek().kind == TokenKind.at) endLine();
    }
    if (notes.isNotEmpty && at(TokenKind.newline)) endLine();
    return notes;
  }

  Statement statement({bool topLevel = false, bool member = false}) {
    final span = current.span;
    final notes = takeAnnotations();
    if (topLevel && word('use')) return useImport(span);
    if (word('sealed') ||
        word('class') ||
        (word('value') && peek().lexeme == 'class')) {
      return typeDeclaration(span, notes);
    }
    if (word('enum')) return enumDeclaration(span, notes);
    if (functionAhead()) return function(notes);
    if (notes.isNotEmpty) {
      fail('Annotation is not attached to a declaration', span);
    }
    if (word('if')) return ifStatement();
    if ((word('test') || word('group')) && peek().kind == TokenKind.string) {
      return testDeclaration(span);
    }
    if (word('await') && peek().lexeme == 'for') {
      take();
      return forStatement(span, awaiting: true);
    }
    if (word('for')) return forStatement(span);
    if (word('try')) return tryStatement(span);
    if (word('throw')) {
      take();
      final value = expression(bare: true);
      endLine();
      return ThrowStatement(value, extent(span));
    }
    if (word('rethrow')) {
      take();
      endLine();
      return RethrowStatement(extent(span));
    }
    if (word('yield')) {
      take();
      final star = match(TokenKind.star);
      final value = expression(bare: true);
      endLine();
      return YieldStatement(value, star, extent(span));
    }
    if (word('repeat')) return repeatStatement(span);
    if (word('result')) {
      take();
      final value = expression(bare: true);
      endLine();
      return ResultStatement(value, extent(span));
    }
    if (word('while')) {
      take();
      final condition = expression();
      return WhileStatement(condition, block(), extent(span));
    }
    if (word('break') || word('continue')) {
      final keyword = take().lexeme;
      String? label;
      if (at(TokenKind.identifier)) label = name().lexeme;
      endLine();
      return keyword == 'break'
          ? BreakStatement(label, extent(span))
          : ContinueStatement(label, extent(span));
    }
    if (word('label')) {
      take();
      final label = name().lexeme;
      endLine();
      return LabelStatement(label, statement(), extent(span));
    }
    if (word('match') || word('switch')) return matchStatement(span);
    if (at(TokenKind.leftParen) && destructureAhead()) {
      return destructure(span);
    }
    if (word('return')) {
      take();
      final value = at(TokenKind.newline) ? null : expression(bare: true);
      if (value is! DoExpression &&
          value is! WithExpression &&
          value is! MatchExpression &&
          !(value is IfExpression && !at(TokenKind.newline))) {
        endLine();
      }
      return ReturnStatement(value, extent(span));
    }
    var mode = BindingMode.inferred;
    if (word('late')) {
      take();
      if (word('var')) {
        take();
        mode = BindingMode.lateMutable;
      } else {
        mode = BindingMode.lateFinal;
      }
    }
    if (word('var') || word('const') || word('shadow')) {
      final keyword = take().lexeme;
      if (keyword == 'shadow' && word('var')) {
        take();
        mode = BindingMode.shadowMutable;
      } else {
        mode = switch (keyword) {
          'var' => BindingMode.mutable,
          'const' => BindingMode.constant,
          _ => BindingMode.shadow,
        };
      }
    }
    final bindingAhead = at(TokenKind.identifier) &&
        (assignments.contains(peek().kind) ||
            peek().kind == TokenKind.colon &&
                peek(2).kind == TokenKind.identifier);
    if (bindingAhead || mode != BindingMode.inferred) {
      final bindingName = name();
      String? type;
      if (match(TokenKind.colon)) type = typeName();
      if (!assignments.contains(current.kind)) {
        if (mode == BindingMode.lateFinal || mode == BindingMode.lateMutable) {
          endLine();
          return Binding(bindingName.lexeme, mode, type, '=',
              Literal(null, bindingName.span), extent(span),
              open: true);
        }
        fail('Expected binding initializer or assignment');
      }
      final operator = take().lexeme;
      var value = expression(bare: true);
      value = finishBlockValue(value);
      return Binding(
          bindingName.lexeme, mode, type, operator, value, extent(span));
    }
    var value = expression(bare: true);
    value = finishBlockValue(value);
    return ExpressionStatement(value, extent(span));
  }

  Expression finishBlockValue(Expression value) {
    if (at(TokenKind.colon) &&
        value is Identifier &&
        (value.name == 'map' || value.name == 'set')) {
      return collectionLiteral(value.name, value.span);
    }
    if (at(TokenKind.colon)) return namedBlock(value);
    if (value is DoExpression ||
        value is WithExpression ||
        value is MatchExpression) {
      return value;
    }
    if (value is IfExpression && !at(TokenKind.newline)) return value;
    endLine();
    return value;
  }

  Expression collectionLiteral(String kind, SourceSpan span) {
    expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'collection literal');
    if (kind == 'set') {
      final elements = <Expression>[];
      while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
        elements.add(readElement(terminated: true));
      }
      expect(TokenKind.dedent, 'end of set');
      return SetExpression(elements, extent(span));
    }
    return mapEntries(span);
  }

  MapExpression mapEntries(SourceSpan span) {
    final keys = <Expression>[];
    final values = <Expression>[];
    while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
      if (word('if') ||
          word('for') ||
          at(TokenKind.spread) ||
          at(TokenKind.spreadQuestion)) {
        keys.add(readMapControl());
        values.add(Literal(null, current.span));
        continue;
      }
      keys.add(expression());
      expect(TokenKind.colon, ':');
      values.add(expression(bare: true));
      endLine();
    }
    expect(TokenKind.dedent, 'end of map');
    return MapExpression(keys, values, extent(span));
  }

  Expression readMapControl() {
    if (word('if')) {
      final token = take();
      final condition = expression();
      final thenMap = mapBody();
      MapExpression? elseMap;
      if (word('else')) {
        take();
        elseMap = word('if') ? null : mapBody();
        if (elseMap == null) {
          final nested = readMapControl();
          elseMap = MapExpression(
              [nested], [Literal(null, token.span)], extent(token.span));
        }
      }
      return MapComprehension(
          condition, null, null, thenMap, elseMap, extent(token.span));
    }
    if (word('for')) {
      final token = take();
      final binding = name();
      expect(TokenKind.identifier, 'in');
      if (tokens[index - 1].lexeme != 'in') {
        fail('Expected in', tokens[index - 1].span);
      }
      final iterable = expression();
      return MapComprehension(
          null, binding.lexeme, iterable, mapBody(), null, extent(token.span));
    }
    final token = take();
    var operand = expression(bare: true);
    operand = finishCollection(operand, terminated: true);
    return SpreadElement(
        operand, token.kind == TokenKind.spreadQuestion, extent(token.span));
  }

  Expression finishCollection(Expression value, {required bool terminated}) {
    if (value is Identifier &&
        (value.name == 'map' || value.name == 'set') &&
        at(TokenKind.colon)) {
      return collectionLiteral(value.name, value.span);
    }
    if (terminated && at(TokenKind.colon)) return namedBlock(value);
    if (terminated) endLine();
    return value;
  }

  MapExpression mapBody() {
    expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'indented block');
    return mapEntries(current.span);
  }

  static const assignments = {
    TokenKind.equals,
    TokenKind.plusEquals,
    TokenKind.minusEquals,
    TokenKind.starEquals,
    TokenKind.slashEquals
  };
  String typeName() {
    var result = typeAtom();
    while (at(TokenKind.pipe)) {
      take();
      result = '$result | ${typeAtom()}';
    }
    final parts = result.split(' | ').map((part) => part.trim()).toSet();
    if (parts.length == 2 &&
        parts.contains('int') &&
        parts.contains('double')) {
      return 'num';
    }
    if (parts.length == 2 && parts.contains('Null')) {
      final other = parts.firstWhere((part) => part != 'Null');
      return other.endsWith('?') ? other : '$other?';
    }
    return result;
  }

  String typeAtom() {
    if (word('readonly')) {
      take();
      return 'readonly ${typeAtom()}';
    }
    var result = name().lexeme;
    if (match(TokenKind.less)) {
      result += '<${typeName()}';
      while (match(TokenKind.comma)) {
        result += ', ${typeName()}';
      }
      expect(TokenKind.greater, '>');
      result += '>';
    }
    if (match(TokenKind.question)) result += '?';
    return result;
  }

  Statement testDeclaration(SourceSpan span) {
    final kind = take().lexeme;
    final parsed = string(take());
    if (parsed is! Literal || parsed.value is! String) {
      fail('Test title must be a string literal', span);
    }
    final async = word('async');
    if (async) take();
    return TestDeclaration(
        kind, parsed.value as String, async, block(), extent(span));
  }

  Statement forStatement(SourceSpan span, {bool awaiting = false}) {
    take();
    if (at(TokenKind.identifier) && peek().lexeme == 'in') {
      final variable = name();
      take();
      final iterable = expression();
      return ForStatement(variable.lexeme, iterable, block(), extent(span),
          awaiting: awaiting);
    }
    if (awaiting) fail('await for expects one name');
    final initSpan = current.span;
    var mode = BindingMode.inferred;
    if (word('var')) {
      take();
      mode = BindingMode.mutable;
    }
    final bindingName = name();
    String? type;
    if (match(TokenKind.colon)) type = typeName();
    if (!match(TokenKind.equals)) fail('Expected =');
    final value = expression();
    final init =
        Binding(bindingName.lexeme, mode, type, '=', value, extent(initSpan));
    if (!word('while')) fail('Expected while');
    take();
    final condition = expression();
    Expression? step;
    if (word('step')) {
      take();
      step = stepExpression();
    }
    return CForStatement(init, condition, step, block(), extent(span));
  }

  Expression stepExpression() {
    if (at(TokenKind.identifier) && assignments.contains(peek().kind)) {
      final name = this.name();
      final operator = take().lexeme;
      return AssignExpression(
          name.lexeme, operator, expression(), extent(name.span));
    }
    return expression();
  }

  Statement repeatStatement(SourceSpan span) {
    take();
    final body = block();
    if (!word('while')) fail('Expected while');
    take();
    final condition = expression();
    endLine();
    return RepeatStatement(body, condition, extent(span));
  }

  ImportDeclaration useImport(SourceSpan span) {
    take();
    final buffer = StringBuffer();
    while (!at(TokenKind.newline) && !at(TokenKind.eof)) {
      if (word('as')) break;
      buffer.write(take().lexeme);
    }
    String? prefix;
    if (word('as')) {
      take();
      prefix = name().lexeme;
    }
    endLine();
    if (buffer.isEmpty) fail('Expected import uri', span);
    return ImportDeclaration(buffer.toString(), prefix, extent(span));
  }

  ClassDeclaration typeDeclaration(SourceSpan span, List<String> notes) {
    var kind = 'class';
    if (word('sealed')) {
      take();
      kind = word('type') ? 'sealedType' : 'sealed';
    } else if (word('value')) {
      take();
      kind = 'value';
    }
    if (kind == 'sealedType') {
      if (!word('type')) fail('Expected type');
    } else if (!word('class')) {
      fail('Expected class');
    }
    take();
    final typeNameToken = name();
    expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'indented block');
    final fields = <FieldDeclaration>[];
    final methods = <FunctionDeclaration>[];
    final cases = <ClassCase>[];
    while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
      if (kind == 'sealedType' && !functionAhead()) {
        final caseToken = name();
        if (at(TokenKind.leftParen)) {
          take();
          final caseFields = <FieldDeclaration>[];
          if (!at(TokenKind.rightParen)) {
            do {
              final fieldName = name();
              expect(TokenKind.colon, ':');
              final fieldType = typeName();
              caseFields.add(FieldDeclaration(fieldName.lexeme, fieldType,
                  false, true, null, fieldName.span));
            } while (match(TokenKind.comma) && !at(TokenKind.rightParen));
          }
          expect(TokenKind.rightParen, ')');
          endLine();
          cases.add(
              ClassCase(caseToken.lexeme, caseFields, extent(caseToken.span)));
        } else {
          endLine();
          cases.add(ClassCase(caseToken.lexeme, const [], caseToken.span));
        }
        continue;
      }
      if (functionAhead()) {
        methods.add(function(const []));
        continue;
      }
      final fieldName = name();
      expect(TokenKind.colon, ':');
      final fieldType = typeName();
      final mutable = false;
      var requiredField = false;
      Expression? initializer;
      if (word('required')) {
        take();
        requiredField = true;
      }
      if (match(TokenKind.equals)) initializer = expression(bare: true);
      endLine();
      fields.add(FieldDeclaration(fieldName.lexeme, fieldType, mutable,
          requiredField || initializer == null, initializer, fieldName.span));
    }
    expect(TokenKind.dedent, 'end of block');
    return ClassDeclaration(typeNameToken.lexeme, kind, fields, methods, cases,
        notes, extent(span));
  }

  bool destructureAhead() {
    var depth = 0;
    for (var j = index; j < tokens.length; j++) {
      final kind = tokens[j].kind;
      if (kind == TokenKind.leftParen || kind == TokenKind.leftBracket) {
        depth++;
      }
      if (kind == TokenKind.rightParen || kind == TokenKind.rightBracket) {
        depth--;
      }
      if (depth == 0 && kind == TokenKind.equals) return true;
      if (depth == 0 && kind == TokenKind.newline) return false;
    }
    return false;
  }

  DestructureStatement destructure(SourceSpan span) {
    final pattern = patternLiteral();
    expect(TokenKind.equals, '=');
    final value = expression(bare: true);
    endLine();
    return DestructureStatement(pattern, value, extent(span));
  }

  MatchStatement matchStatement(SourceSpan span) {
    take();
    final value = expression();
    expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'indented block');
    final arms = <MatchArm>[];
    while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
      final armSpan = current.span;
      final pattern = patternLiteral();
      Expression? guard;
      if (word('when')) {
        take();
        guard = expression();
      }
      final body = block();
      arms.add(MatchArm(pattern, body, extent(armSpan), guard: guard));
    }
    expect(TokenKind.dedent, 'end of block');
    return MatchStatement(value, arms, extent(span));
  }

  Pattern patternLiteral() {
    final span = current.span;
    const typeWords = {'int', 'double', 'num', 'bool', 'String', 'Null'};
    if (at(TokenKind.identifier) && typeWords.contains(current.lexeme)) {
      final type = take().lexeme;
      final name = at(TokenKind.identifier) && current.lexeme != 'when'
          ? this.name().lexeme
          : null;
      return TypedPattern(type, name, span);
    }
    if (at(TokenKind.identifier) && current.lexeme == '_') {
      take();
      return WildcardPattern(span);
    }
    if (at(TokenKind.number) ||
        at(TokenKind.string) ||
        word('true') ||
        word('false') ||
        word('null')) {
      return LiteralPattern(prefix(), span);
    }
    if (at(TokenKind.leftParen)) {
      take();
      final fields = <Pattern>[];
      if (!at(TokenKind.rightParen)) {
        do {
          fields.add(patternLiteral());
        } while (match(TokenKind.comma) && !at(TokenKind.rightParen));
      }
      expect(TokenKind.rightParen, ')');
      return ConstructorPattern(
          '', fields, List.filled(fields.length, null), extent(span));
    }
    if (at(TokenKind.leftBracket)) {
      take();
      final elements = <Pattern>[];
      if (!at(TokenKind.rightBracket)) {
        do {
          elements.add(patternLiteral());
        } while (match(TokenKind.comma) && !at(TokenKind.rightBracket));
      }
      expect(TokenKind.rightBracket, ']');
      return ListPattern(elements, extent(span));
    }
    final typeOrName = name();
    if (at(TokenKind.leftParen)) {
      take();
      final fields = <Pattern>[];
      final names = <String?>[];
      if (!at(TokenKind.rightParen)) {
        do {
          if (at(TokenKind.identifier) && peek().kind == TokenKind.colon) {
            names.add(name().lexeme);
            take();
            final token = current;
            if (at(TokenKind.identifier) &&
                token.lexeme != '_' &&
                peek().kind != TokenKind.leftParen &&
                peek().kind != TokenKind.leftBracket) {
              final bound = name();
              fields.add(BindingPattern(bound.lexeme, bound.span));
            } else {
              fields.add(patternLiteral());
            }
          } else if (at(TokenKind.identifier) &&
              current.lexeme != '_' &&
              peek().kind != TokenKind.leftParen &&
              peek().kind != TokenKind.leftBracket) {
            final token = name();
            names.add(null);
            fields.add(BindingPattern(token.lexeme, token.span));
          } else {
            names.add(null);
            fields.add(patternLiteral());
          }
        } while (match(TokenKind.comma) && !at(TokenKind.rightParen));
      }
      expect(TokenKind.rightParen, ')');
      return ConstructorPattern(typeOrName.lexeme, fields, names, extent(span));
    }
    return BindingPattern(typeOrName.lexeme, typeOrName.span);
  }

  FunctionDeclaration function(List<String> notes) {
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
        if (word('required')) take();
        Expression? defaultValue;
        if (match(TokenKind.equals)) defaultValue = expression();
        parameters.add(Parameter(
            parameter.lexeme, type, mutable, extent(parameter.span),
            defaultValue: defaultValue));
      } while (match(TokenKind.comma) && !at(TokenKind.rightParen));
    }
    expect(TokenKind.rightParen, ')');
    var isAsync = false;
    var generator = '';
    if (word('async') || word('sync')) {
      final marker = take().lexeme;
      if (match(TokenKind.star)) {
        generator = marker;
        isAsync = marker == 'async';
      } else if (marker == 'async') {
        isAsync = true;
      } else {
        fail('sync requires *');
      }
    }
    String? returnType;
    if (match(TokenKind.arrow)) returnType = typeName();
    if (match(TokenKind.equals)) {
      if (generator.isNotEmpty) fail('A generator body is a suite');
      final value = expression(bare: true);
      if (value is! MatchExpression &&
          value is! DoExpression &&
          value is! WithExpression &&
          !(value is IfExpression && !at(TokenKind.newline))) {
        endLine();
      }
      return FunctionDeclaration(
          token.lexeme, parameters, returnType, null, value, extent(token.span),
          isAsync: isAsync, annotations: notes, generator: generator);
    }
    return FunctionDeclaration(
        token.lexeme, parameters, returnType, block(), null, extent(token.span),
        isAsync: isAsync, annotations: notes, generator: generator);
  }

  ClassDeclaration enumDeclaration(SourceSpan span, List<String> notes) {
    take();
    final typeNameToken = name();
    expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'indented block');
    final cases = <ClassCase>[];
    while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
      final value = name();
      endLine();
      cases.add(ClassCase(value.lexeme, const [], value.span));
    }
    expect(TokenKind.dedent, 'end of enum');
    if (cases.isEmpty) fail('An enum needs a value', span);
    return ClassDeclaration(typeNameToken.lexeme, 'enum', const [], const [],
        cases, notes, extent(span));
  }

  Statement tryStatement(SourceSpan span) {
    take();
    if (!at(TokenKind.colon)) {
      final operand = expression();
      if (!word('else')) fail('try expression requires else');
      take();
      final fallback = expression(bare: true);
      endLine();
      return ExpressionStatement(
          TryExpression(operand, fallback, extent(span)), extent(span));
    }
    final body = block();
    final catches = <CatchClause>[];
    while (word('catch')) {
      final token = take();
      final caught = name();
      String? type;
      String? trace;
      expect(TokenKind.colon, ':');
      if (at(TokenKind.identifier) && peek().kind == TokenKind.colon) {
        type = typeName();
        if (match(TokenKind.comma)) trace = name().lexeme;
        catches.add(CatchClause(
            caught.lexeme, type, trace, block(), extent(token.span)));
      } else {
        if (match(TokenKind.comma)) trace = name().lexeme;
        catches.add(CatchClause(caught.lexeme, type, trace,
            block(colonTaken: true), extent(token.span)));
      }
    }
    final finallyBody = <Statement>[];
    if (word('finally')) {
      take();
      finallyBody.addAll(block());
    }
    if (catches.isEmpty && finallyBody.isEmpty) {
      fail('try needs catch or finally', span);
    }
    return TryStatement(body, catches, finallyBody, extent(span));
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

  List<Statement> block({bool colonTaken = false}) {
    if (!colonTaken) expect(TokenKind.colon, ':');
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
    expect(TokenKind.indent, 'indented block');
    if (_namedArgumentRows()) {
      final arguments = <Argument>[];
      while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
        final argument = name();
        expect(TokenKind.colon, ':');
        final Expression value;
        if (at(TokenKind.newline)) {
          value = indentedBlock();
        } else {
          value = expression(bare: true);
          endLine();
        }
        arguments.add(Argument(argument.lexeme, value, argument.span));
      }
      expect(TokenKind.dedent, 'end of named argument block');
      if (callee is CallExpression) {
        return CallExpression(callee.callee,
            [...callee.arguments, ...arguments], extent(callee.span));
      }
      return CallExpression(callee, arguments, extent(callee.span));
    }
    final list = collectionRows(callee.span);
    final argument = Argument(null, list, list.span);
    if (callee is CallExpression) {
      return CallExpression(
          callee.callee, [...callee.arguments, argument], extent(callee.span));
    }
    return CallExpression(callee, [argument], extent(callee.span));
  }

  /// A value written as an indented block after a named argument's colon.
  Expression indentedBlock() {
    endLine();
    expect(TokenKind.indent, 'indented block');
    if (_namedArgumentRows()) {
      fail('A nested label block needs its callee before the colon');
    }
    return collectionRows(current.span);
  }

  bool _namedArgumentRows() {
    var i = index;
    var depth = 1;
    var named = true;
    var rows = 0;
    var atRow = true;
    const blocked = {'if', 'for', 'else', 'repeat'};
    while (i < tokens.length && depth > 0) {
      final token = tokens[i];
      if (token.kind == TokenKind.indent) {
        depth++;
        atRow = false;
        i++;
        continue;
      }
      if (token.kind == TokenKind.dedent) {
        depth--;
        atRow = depth == 1;
        i++;
        continue;
      }
      if (depth != 1) {
        i++;
        continue;
      }
      if (token.kind == TokenKind.newline) {
        atRow = true;
        i++;
        continue;
      }
      if (atRow) {
        rows++;
        final next = i + 1 < tokens.length ? tokens[i + 1] : null;
        final label = token.kind == TokenKind.identifier &&
            !blocked.contains(token.lexeme) &&
            next != null &&
            next.kind == TokenKind.colon;
        if (!label) named = false;
        atRow = false;
      }
      i++;
    }
    if (rows == 0) fail('A colon block needs a row');
    return named;
  }

  ListExpression collectionRows(SourceSpan span) {
    final elements = <Expression>[];
    while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
      elements.add(readElement(terminated: true));
    }
    expect(TokenKind.dedent, 'end of block');
    return ListExpression(elements, extent(span));
  }

  Expression readElement({required bool terminated}) {
    if (word('if')) return collectionIf();
    if (word('for')) return collectionFor();
    if (at(TokenKind.spread) || at(TokenKind.spreadQuestion)) {
      final token = take();
      final operand = expression(bare: terminated);
      if (terminated) endLine();
      return SpreadElement(
          operand, token.kind == TokenKind.spreadQuestion, extent(token.span));
    }
    final aware = match(TokenKind.question);
    var value = expression(bare: terminated);
    value = finishCollection(value, terminated: terminated);
    return aware ? NullAwareElement(value, value.span) : value;
  }

  CollectionIf collectionIf() {
    final token = take();
    final condition = expression();
    final thenElements = elementBlock();
    final elseElements = <Expression>[];
    if (word('else')) {
      take();
      if (word('if')) {
        elseElements.add(collectionIf());
      } else {
        elseElements.addAll(elementBlock());
      }
    }
    return CollectionIf(
        condition, thenElements, elseElements, extent(token.span));
  }

  CollectionFor collectionFor() {
    final token = take();
    final binding = name();
    expect(TokenKind.identifier, 'in');
    if (tokens[index - 1].lexeme != 'in') {
      fail('Expected in', tokens[index - 1].span);
    }
    final iterable = expression();
    return CollectionFor(
        binding.lexeme, iterable, elementBlock(), extent(token.span));
  }

  Expression ifExpression(Token token) {
    final condition = expression();
    final thenValue = suiteExpression();
    if (!word('else')) fail('if expression requires else');
    take();
    final elseValue = word('if') ? ifExpression(take()) : suiteExpression();
    return IfExpression(condition, thenValue, elseValue, extent(token.span));
  }

  Expression matchExpression(Token token) {
    final value = expression();
    expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'indented block');
    final arms = <MatchExprArm>[];
    while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
      final armSpan = current.span;
      final pattern = patternLiteral();
      Expression? guard;
      if (word('when')) {
        take();
        guard = expression();
      }
      final result = suiteExpression();
      if (at(TokenKind.newline)) endLine();
      arms.add(MatchExprArm(pattern, result, extent(armSpan), guard: guard));
    }
    expect(TokenKind.dedent, 'end of match');
    return MatchExpression(value, arms, extent(token.span));
  }

  /// A colon followed by one expression, either on this line or indented.
  Expression suiteExpression() {
    expect(TokenKind.colon, ':');
    if (!at(TokenKind.newline)) return expression(bare: true);
    endLine();
    expect(TokenKind.indent, 'indented block');
    final value = expression(bare: true);
    endLine();
    expect(TokenKind.dedent, 'end of block');
    return value;
  }

  List<Expression> elementBlock() {
    expect(TokenKind.colon, ':');
    if (!at(TokenKind.newline)) return [readElement(terminated: false)];
    endLine();
    expect(TokenKind.indent, 'indented block');
    return collectionRows(current.span).elements;
  }

  bool arrowAfterGroup() {
    var depth = 1;
    for (var j = index; j < tokens.length; j++) {
      if (tokens[j].kind == TokenKind.leftParen) depth++;
      if (tokens[j].kind == TokenKind.rightParen) {
        depth--;
        if (depth == 0) {
          return j + 1 < tokens.length && tokens[j + 1].kind == TokenKind.arrow;
        }
      }
    }
    return false;
  }

  Expression finishLambda(List<Parameter> parameters, SourceSpan span) {
    expect(TokenKind.arrow, '->');
    if (at(TokenKind.colon)) {
      return Lambda(parameters, null, block(), extent(span));
    }
    return Lambda(parameters, expression(bare: true), null, extent(span));
  }

  Expression pipeline(Expression left, Expression right) {
    if (right is Identifier) {
      return CallExpression(
          right, [Argument(null, left, left.span)], extent(left.span));
    }
    if (right is CallExpression) {
      final arguments = [...right.arguments];
      final hole = arguments.indexWhere((argument) =>
          argument.value is Identifier &&
          (argument.value as Identifier).name == '_');
      if (hole < 0) {
        fail('Pipeline target needs a bare function or one _ hole', right.span);
      }
      arguments[hole] = Argument(arguments[hole].name, left, left.span);
      return CallExpression(right.callee, arguments, extent(left.span));
    }
    fail('Pipeline target must be a function', right.span);
  }

  int precedence(Token token) {
    if (token.kind == TokenKind.pipeGreater) return -1;
    if (token.kind == TokenKind.questionQuestion) return 0;
    if (token.kind == TokenKind.dotDot || token.kind == TokenKind.dotDotLess) {
      return 5;
    }
    if (token.kind == TokenKind.tildeSlash) return 7;
    return switch (token.lexeme) {
      'or' => 1,
      'and' => 2,
      '==' || '!=' => 3,
      '<' || '<=' || '>' || '>=' => 4,
      '+' || '-' => 6,
      '*' || '/' || '%' => 7,
      _ => -2,
    };
  }

  Expression expression({int minimum = -1, bool bare = false}) {
    var left = prefix();
    while (true) {
      if (at(TokenKind.leftParen)) {
        left = call(left);
        continue;
      }
      if (at(TokenKind.leftBracket)) {
        take();
        final index = expression();
        expect(TokenKind.rightBracket, ']');
        left = IndexExpression(left, index, extent(left.span));
        continue;
      }
      if (at(TokenKind.dot) || at(TokenKind.questionDot)) {
        final nullAware = take().kind == TokenKind.questionDot;
        final member = name();
        left = MemberAccess(left, member.lexeme, nullAware, extent(left.span));
        continue;
      }
      if (at(TokenKind.bang)) {
        take();
        left = UnaryExpression('!', left, extent(left.span));
        continue;
      }
      if (at(TokenKind.question)) {
        take();
        left = PropagateExpression(left, extent(left.span));
        continue;
      }
      if (at(TokenKind.arrow) && left is Identifier) {
        final parameter = Parameter(left.name, '<infer>', false, left.span);
        left = finishLambda([parameter], left.span);
        continue;
      }
      if ((word('to') || at(TokenKind.toQuestion)) && 4 >= minimum) {
        final safe = at(TokenKind.toQuestion);
        take();
        final type = typeName();
        left = ConversionExpression(left, type, safe, extent(left.span));
        continue;
      }
      final power = precedence(current);
      if (power < minimum) break;
      final operator = take();
      final right = expression(minimum: power + 1);
      if (operator.kind == TokenKind.dotDot ||
          operator.kind == TokenKind.dotDotLess) {
        left = RangeExpression(
            left, right, operator.kind == TokenKind.dotDot, extent(left.span));
      } else if (operator.kind == TokenKind.pipeGreater) {
        left = pipeline(left, right);
      } else {
        left =
            BinaryExpression(left, operator.lexeme, right, extent(left.span));
      }
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
      final lexeme = token.lexeme.replaceAll('_', '');
      final Object? value;
      if (lexeme.startsWith('0x') || lexeme.startsWith('0X')) {
        value = int.tryParse(lexeme.substring(2), radix: 16);
      } else if (lexeme.contains('.') ||
          lexeme.contains('e') ||
          lexeme.contains('E')) {
        value = double.tryParse(lexeme);
      } else {
        value = int.tryParse(lexeme);
      }
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
          token.lexeme, expression(minimum: 8), extent(token.span));
    }
    if (token.lexeme == 'await') {
      return AwaitExpression(expression(minimum: 8), extent(token.span));
    }
    if (token.lexeme == 'if') return ifExpression(token);
    if (token.lexeme == 'match' || token.lexeme == 'switch') {
      return matchExpression(token);
    }
    if (token.lexeme == 'try') {
      final operand = expression();
      if (!word('else')) fail('try expression requires else');
      take();
      final fallback = expression();
      return TryExpression(operand, fallback, extent(token.span));
    }
    if (token.lexeme == 'do') {
      return DoExpression(block(), extent(token.span));
    }
    if (token.lexeme == 'capture' && at(TokenKind.leftParen)) {
      take();
      final names = <String>[];
      if (!at(TokenKind.rightParen)) {
        do {
          names.add(name().lexeme);
        } while (match(TokenKind.comma) && !at(TokenKind.rightParen));
      }
      expect(TokenKind.rightParen, ')');
      expect(TokenKind.arrow, '->');
      final body = at(TokenKind.colon) ? null : expression(bare: true);
      if (body == null) {
        fail('capture body must be an expression', token.span);
      }
      return CaptureExpression(names, body, extent(token.span));
    }
    if (token.lexeme == 'with' || token.kind == TokenKind.withQuestion) {
      final receiver = expression();
      expect(TokenKind.colon, ':');
      endLine();
      expect(TokenKind.indent, 'indented block');
      final fields = <String>[];
      final values = <Expression>[];
      while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
        fields.add(name().lexeme);
        if (!match(TokenKind.colon) && !match(TokenKind.equals)) {
          fail('Expected : or =');
        }
        values.add(expression(bare: true));
        endLine();
      }
      expect(TokenKind.dedent, 'end of block');
      return WithExpression(receiver, fields, values,
          token.kind == TokenKind.withQuestion, extent(token.span));
    }
    if (token.kind == TokenKind.dot) {
      final member = word('new') ? (take().lexeme) : name().lexeme;
      List<Argument>? arguments;
      if (at(TokenKind.leftParen)) {
        arguments = call(Identifier(member, token.span)).arguments;
      }
      return DotShorthand(member, arguments, extent(token.span));
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
        'readonly',
        'capture',
        'return',
        'var',
        'const',
        'shadow',
        'if',
        'else',
        'for',
        'while',
        'class',
        'sealed',
        'use',
        'async',
        'break',
        'continue',
        'label',
        'match',
        'switch',
        'type',
      };
      if (unsupported.contains(token.lexeme))
        fail('Unsupported syntax: ${token.lexeme}', token.span);
      return Identifier(token.lexeme, token.span);
    }
    if (token.kind == TokenKind.leftParen) {
      if (arrowAfterGroup()) {
        final parameters = <Parameter>[];
        if (!at(TokenKind.rightParen)) {
          do {
            final mutable = word('var');
            if (mutable) take();
            final parameter = name();
            var type = '<infer>';
            if (match(TokenKind.colon)) type = typeName();
            parameters.add(
                Parameter(parameter.lexeme, type, mutable, parameter.span));
          } while (match(TokenKind.comma) && !at(TokenKind.rightParen));
        }
        expect(TokenKind.rightParen, ')');
        return finishLambda(parameters, token.span);
      }
      if (at(TokenKind.rightParen)) {
        take();
        return RecordExpression(const [], extent(token.span));
      }
      final value = expression();
      if (at(TokenKind.comma)) {
        final fields = <Expression>[value];
        while (match(TokenKind.comma) && !at(TokenKind.rightParen)) {
          fields.add(expression());
        }
        expect(TokenKind.rightParen, ')');
        return RecordExpression(fields, extent(token.span));
      }
      expect(TokenKind.rightParen, ')');
      return value;
    }
    if (token.kind == TokenKind.leftBracket) {
      final values = <Expression>[];
      while (true) {
        while (at(TokenKind.newline) ||
            at(TokenKind.indent) ||
            at(TokenKind.dedent)) {
          take();
        }
        if (at(TokenKind.rightBracket) || at(TokenKind.eof)) break;
        values.add(readElement(terminated: false));
        while (at(TokenKind.newline) ||
            at(TokenKind.indent) ||
            at(TokenKind.dedent)) {
          take();
        }
        if (!match(TokenKind.comma)) break;
      }
      while (at(TokenKind.newline) ||
          at(TokenKind.indent) ||
          at(TokenKind.dedent)) {
        take();
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
