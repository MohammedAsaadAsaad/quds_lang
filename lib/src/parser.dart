import 'dart:convert';
import 'ast.dart';
import 'libraries.dart';
import 'lexer.dart';

class Parser {
  Parser(this.tokens);
  final List<Token> tokens;
  final errors = <CompilerException>[];
  final _pending = <Statement>[];

  /// True when [finishBlockValue] left a trailing `if` on the same line.
  var _suffixIf = false;

  /// Labels whose statements are still being parsed.
  final _openLabels = <String>[];
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
      throw CompilerException('E100', message, span ?? current.span);
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

  Program parse({bool partial = false}) {
    final span = current.span;
    final statements = <Statement>[];
    while (_pending.isNotEmpty || !at(TokenKind.eof)) {
      try {
        statements.add(statement(topLevel: true));
      } on CompilerException catch (error) {
        _record(error);
      }
    }
    if (!partial) _finish();
    return Program(statements, extent(span));
  }

  /// A parse error ends the current line. Later lines are still parsed, and
  /// every recorded error is reported. The line skip is the recovery point
  /// this version defines; missing tokens are not invented.
  void _record(CompilerException error) {
    errors.add(error);
    if (at(TokenKind.dedent) || at(TokenKind.eof)) return;
    while (!at(TokenKind.eof) && !at(TokenKind.dedent)) {
      final newline = at(TokenKind.newline);
      take();
      if (newline) return;
    }
  }

  void _finish() {
    if (errors.isEmpty) return;
    if (errors.length == 1) throw errors.single;
    throw CompilerException(errors.first.code,
        errors.map((error) => '$error').join('\n'), errors.first.span);
  }

  bool functionAhead() {
    if (!at(TokenKind.identifier)) return false;
    var open = index + 1;
    if (open < tokens.length && tokens[open].kind == TokenKind.less) {
      final after = _skipAngles(open);
      if (after < 0) return false;
      open = after;
    }
    if (open >= tokens.length || tokens[open].kind != TokenKind.leftParen) {
      return false;
    }
    var depth = 0;
    for (var j = open; j < tokens.length; j++) {
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
          return _parameterList(open + 1, j);
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
      if (i < end && tokens[i].kind == TokenKind.spread) i++;
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
            var next = i + 1;
            if (next < end && tokens[next].kind == TokenKind.arrow) {
              next++;
              if (!_skipType(next, end, (moved) => next = moved)) return false;
            }
            if (next < end && tokens[next].kind == TokenKind.question) next++;
            move(next);
            return true;
          }
        }
        i++;
      }
      return false;
    }
    if (token.kind == TokenKind.identifier && token.lexeme == 'readonly') {
      return _skipType(start + 1, end, move);
    }
    if (token.kind != TokenKind.identifier) return false;
    var i = start + 1;
    if (i < end && tokens[i].kind == TokenKind.less) {
      var depth = 0;
      while (i < end) {
        if (tokens[i].kind == TokenKind.less) depth++;
        final close = _angleCloseWidth(tokens[i].kind);
        if (close > 0) {
          depth -= close;
          if (depth == 0) {
            i++;
            break;
          }
          if (depth < 0) return false;
        }
        i++;
      }
    }
    if (i < end && tokens[i].kind == TokenKind.question) i++;
    while (i < end &&
        (tokens[i].kind == TokenKind.amp || tokens[i].kind == TokenKind.pipe)) {
      i++;
      if (!_skipType(i, end, (next) => i = next)) return false;
    }
    move(i);
    return true;
  }

  /// Index just after a `<...>` group, or `-1` when the brackets do not close.
  int _skipAngles(int start) {
    var depth = 0;
    for (var i = start; i < tokens.length; i++) {
      if (tokens[i].kind == TokenKind.less) depth++;
      final close = _angleCloseWidth(tokens[i].kind);
      if (close > 0) {
        depth -= close;
        if (depth == 0) return i + 1;
        if (depth < 0) return -1;
      }
    }
    return -1;
  }

  List<Metadata> takeAnnotations() {
    final notes = <Metadata>[];
    while (at(TokenKind.at)) {
      final span = current.span;
      take();
      final annotation = name();
      final arguments = <Argument>[];
      if (match(TokenKind.leftParen)) {
        if (!at(TokenKind.rightParen)) {
          do {
            String? label;
            final argumentSpan = current.span;
            if (at(TokenKind.identifier) && peek().kind == TokenKind.colon) {
              label = name().lexeme;
              take();
            }
            arguments.add(Argument(label, expression(), argumentSpan));
          } while (match(TokenKind.comma) && !at(TokenKind.rightParen));
        }
        expect(TokenKind.rightParen, ')');
      }
      notes.add(Metadata(annotation.lexeme, arguments, extent(span)));
      if (at(TokenKind.newline) && peek().kind == TokenKind.at) endLine();
    }
    if (notes.isNotEmpty && at(TokenKind.newline)) endLine();
    return notes;
  }

  Statement statement({bool topLevel = false, bool member = false}) {
    _suffixIf = false;
    if (_pending.isNotEmpty) return _pending.removeAt(0);
    final span = current.span;
    if (topLevel && at(TokenKind.colon) && peek().kind == TokenKind.colon) {
      return sectionHeader(span);
    }
    final notes = takeAnnotations();
    if (topLevel && word('use')) return useImport(span);
    if (topLevel && word('export')) return exportDirective(span);
    if (topLevel && word('part')) return partDirective(span);
    if (word('annotation')) return annotationDeclaration(span);
    if (topLevel && word('config')) return configDeclaration(span);
    if (word('extend')) return extensionDeclaration(span, notes);
    if (word('type') && peek().kind == TokenKind.identifier) {
      return typeForm(span);
    }
    if (word('enum')) return enumDeclaration(span, notes);
    if (word('sealed') && peek().lexeme == 'type') {
      return typeDeclaration(span, notes);
    }
    final modifiers = <String>[];
    const modifierWords = {
      'abstract',
      'base',
      'interface',
      'final',
      'sealed',
      'mixin',
      'value',
      'singleton',
    };
    while (modifierWords.contains(current.lexeme)) {
      final next = peek().lexeme;
      if (next != 'class' && !modifierWords.contains(next)) break;
      modifiers.add(take().lexeme);
    }
    if (word('mixin')) {
      return mixinDeclaration(span, notes, modifiers: modifiers);
    }
    if (word('interface') && peek().kind == TokenKind.identifier) {
      take();
      return typeDeclaration(span, notes, forced: 'interface');
    }
    if (word('class') || modifiers.isNotEmpty) {
      return typeDeclaration(span, notes, modifiers: modifiers);
    }
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
    if (word('watch')) {
      take();
      final value = expression();
      return WatchStatement(value, block(), extent(span));
    }
    if (word('batch') && peek().kind == TokenKind.colon) {
      take();
      return BatchStatement(block(), extent(span));
    }
    if (word('for')) return forStatement(span);
    if (word('try')) return tryStatement(span);
    if (word('require') || word('check') || word('assert')) {
      final kind = take().lexeme;
      final condition = expression(bare: true);
      Expression? message;
      if (match(TokenKind.comma)) message = expression(bare: true);
      return finishLine(RequireStatement(condition, extent(span),
          message: message, kind: kind, source: _snippet(condition.span)));
    }
    if (word('task') && peek().lexeme == 'group') {
      return taskGroup(span);
    }
    if (word('spawn')) {
      throw CompilerException(
          'E107', 'spawn is only valid inside task group', span);
    }
    if (word('throw')) {
      take();
      final value = expression(bare: true);
      return finishLine(ThrowStatement(value, extent(span)));
    }
    if (word('raise') && peek().kind == TokenKind.identifier) {
      take();
      final eventName = name();
      final arguments = at(TokenKind.leftParen)
          ? call(Identifier(eventName.lexeme, eventName.span)).arguments
          : const <Argument>[];
      return finishLine(
          RaiseStatement(eventName.lexeme, arguments, extent(span)));
    }
    if (word('rethrow')) {
      take();
      return finishLine(RethrowStatement(extent(span)));
    }
    if (word('yield')) {
      take();
      final star = match(TokenKind.star);
      final value = expression(bare: true);
      return finishLine(YieldStatement(value, star, extent(span)));
    }
    if (word('repeat')) return repeatStatement(span);
    if (word('once') && peek().kind == TokenKind.colon) {
      take();
      return OnceStatement(suite(), extent(span));
    }
    if (word('result')) {
      take();
      final value = expression(bare: true);
      return finishLine(ResultStatement(value, extent(span)));
    }
    if (word('while')) return whileStatement(span);
    if (word('when') && !assignments.contains(peek().kind)) {
      take();
      final condition = expression();
      return WhenStatement(condition, block(), extent(span));
    }
    if (word('using')) return usingStatement(span);
    if (word('defer') && !assignments.contains(peek().kind)) {
      take();
      final value = expression(bare: true);
      return finishLine(DeferStatement(value, extent(span)));
    }
    if (word('break') || word('continue')) {
      final keyword = take().lexeme;
      String? label;
      Expression? value;
      final labeled = at(TokenKind.identifier) &&
          !word('if') &&
          _openLabels.contains(current.lexeme) &&
          !_continuesBreakValue();
      if (labeled) {
        label = name().lexeme;
      } else if (keyword == 'break' && startsExpression()) {
        value = expression(bare: true);
      } else if (at(TokenKind.identifier) && !word('if')) {
        label = name().lexeme;
      }
      return finishLine(keyword == 'break'
          ? BreakStatement(label, extent(span), value: value)
          : ContinueStatement(label, extent(span)));
    }
    if (word('label')) {
      take();
      final label = name().lexeme;
      endLine();
      _openLabels.add(label);
      final child = statement();
      _openLabels.removeLast();
      return LabelStatement(label, child, extent(span));
    }
    if (word('match') || word('switch')) return matchStatement(span);
    if ((at(TokenKind.leftParen) || at(TokenKind.leftBracket)) &&
        destructureAhead()) {
      return finishLine(destructure(span));
    }
    if (commaAssignAhead()) return finishLine(parallelAssign(span));
    if (word('return')) {
      take();
      if (word('if')) return finishLine(ReturnStatement(null, extent(span)));
      final value = at(TokenKind.newline) ? null : expression(bare: true);
      final returned = ReturnStatement(value, extent(span));
      if (value is DoExpression ||
          value is WithExpression ||
          value is MatchExpression ||
          value is AwaitAllExpression ||
          value is AwaitIsolateExpression ||
          value is LoopExpression ||
          value is WhereExpression && value.block ||
          (value is IfExpression && !at(TokenKind.newline))) {
        return returned;
      }
      return finishLine(returned);
    }
    var mode = BindingMode.inferred;
    if (word('state')) {
      take();
      mode = BindingMode.state;
    } else if (word('computed')) {
      take();
      mode = BindingMode.computed;
    }
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
                (peek(2).kind == TokenKind.identifier ||
                    peek(2).kind == TokenKind.leftParen));
    if (bindingAhead || mode != BindingMode.inferred) {
      final bindings = _bindingLine(span, mode);
      _pending.addAll(bindings.skip(1));
      if (_suffixIf && word('if')) {
        if (bindings.length != 1) {
          fail('A trailing condition follows one statement');
        }
        return finishLine(bindings.first);
      }
      return bindings.first;
    }
    if (at(TokenKind.identifier) &&
        peek().kind == TokenKind.dot &&
        peek(2).kind == TokenKind.identifier &&
        assignments.contains(peek(3).kind)) {
      final object = name();
      take();
      final member = name();
      final operator = take().lexeme;
      final value = expression(bare: true);
      return finishLine(MemberAssignment(Identifier(object.lexeme, object.span),
          member.lexeme, operator, value, extent(span)));
    }
    if (word('this') &&
        peek().kind == TokenKind.dot &&
        peek(2).kind == TokenKind.identifier &&
        assignments.contains(peek(3).kind)) {
      final token = take();
      take();
      final member = name();
      final operator = take().lexeme;
      final value = expression(bare: true);
      return finishLine(MemberAssignment(ThisExpression(token.span),
          member.lexeme, operator, value, extent(span)));
    }
    var value = expression(bare: true);
    if (value is MemberAccess && assignments.contains(current.kind)) {
      if (value.nullAware) fail('Cannot assign through ?.');
      final operator = take().lexeme;
      final written = expression(bare: true);
      return finishLine(MemberAssignment(
          value.object, value.name, operator, written, extent(span)));
    }
    value = finishBlockValue(value);
    final written = ExpressionStatement(value, extent(span));
    if (_suffixIf && word('if')) return finishLine(written);
    return written;
  }

  /// `var whole = 0.0, fraction = 0.0` is two bindings. The keyword applies to
  /// every name. A block value ends the line, and a trailing comma is an error.
  List<Binding> _bindingLine(SourceSpan span, BindingMode mode) {
    final bindings = <Binding>[];
    while (true) {
      final start = bindings.isEmpty ? span : current.span;
      final bindingName = name();
      String? type;
      if (match(TokenKind.colon)) type = typeName();
      if (!assignments.contains(current.kind)) {
        if (mode == BindingMode.lateFinal || mode == BindingMode.lateMutable) {
          bindings.add(Binding(bindingName.lexeme, mode, type, '=',
              Literal(null, bindingName.span), extent(start),
              open: true));
          if (match(TokenKind.comma)) continue;
          endLine();
          return bindings;
        }
        fail('Expected binding initializer or assignment');
      }
      final operator = take().lexeme;
      var value = expression(bare: true);
      if (!_ownsLine(value) && match(TokenKind.comma)) {
        bindings.add(Binding(
            bindingName.lexeme, mode, type, operator, value, extent(start)));
        continue;
      }
      value = finishBlockValue(value);
      bindings.add(Binding(
          bindingName.lexeme, mode, type, operator, value, extent(start)));
      return bindings;
    }
  }

  bool _ownsLine(Expression value) {
    if (value is DoExpression ||
        value is WithExpression ||
        value is MatchExpression ||
        value is AwaitAllExpression ||
        value is AwaitIsolateExpression ||
        value is LoopExpression ||
        value is WhereExpression && value.block ||
        value is MapExpression ||
        value is SetExpression ||
        value is Lambda && value.body != null) {
      return true;
    }
    if (value is CallExpression) {
      return value.arguments.any((argument) => _ownsLine(argument.value));
    }
    return false;
  }

  Expression finishBlockValue(Expression value) {
    if (at(TokenKind.colon) &&
        value is Identifier &&
        (value.name == 'map' || value.name == 'set')) {
      return collectionLiteral(value.name, value.span);
    }
    if (at(TokenKind.colon) && value is MemberAccess && value.name == 'add') {
      final body = suite();
      final handler = Lambda(const [], null, body, extent(value.span));
      return CallExpression(
          value, [Argument(null, handler, handler.span)], extent(value.span));
    }
    if (at(TokenKind.colon)) return namedBlock(value);
    if (value is DoExpression ||
        value is WithExpression ||
        value is MatchExpression ||
        value is AwaitAllExpression ||
        value is AwaitIsolateExpression ||
        _ownsLine(value)) {
      return value;
    }
    if (value is IfExpression && !at(TokenKind.newline)) return value;
    if (word('if')) {
      _suffixIf = true;
      return value;
    }
    _suffixIf = false;
    endLine();
    return value;
  }

  Expression collectionLiteral(String kind, SourceSpan span) {
    expect(TokenKind.colon, ':');
    endLine();
    if (!at(TokenKind.indent)) {
      return kind == 'set'
          ? SetExpression(const [], extent(span))
          : MapExpression(const [], const [], extent(span));
    }
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
    TokenKind.slashEquals,
    TokenKind.questionQuestionEquals
  };
  String typeName() {
    var result = intersection();
    while (at(TokenKind.pipe)) {
      take();
      result = '$result | ${intersection()}';
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

  String intersection() {
    var result = typeAtom();
    while (at(TokenKind.amp)) {
      take();
      result = '$result & ${typeAtom()}';
    }
    return result;
  }

  bool _typeArgumentsAhead() {
    if (!at(TokenKind.less)) return false;
    final after = _skipAngles(index);
    if (after < 0 || after >= tokens.length) return false;
    return tokens[after].kind == TokenKind.leftParen;
  }

  AnnotationDeclaration annotationDeclaration(SourceSpan span) {
    take();
    final annotation = name();
    final parameters =
        at(TokenKind.leftParen) ? parameterList() : const <Parameter>[];
    if (match(TokenKind.colon)) {
      if (at(TokenKind.newline)) {
        endLine();
        if (at(TokenKind.indent)) block(colonTaken: true);
      }
    } else {
      endLine();
    }
    return AnnotationDeclaration(annotation.lexeme, parameters, extent(span));
  }

  ConfigDeclaration configDeclaration(SourceSpan span) {
    take();
    final secret = word('secret');
    if (secret) take();
    final parts = <String>[name().lexeme];
    while (match(TokenKind.dot)) {
      parts.add(name().lexeme);
    }
    expect(TokenKind.colon, ':');
    final type = typeName();
    Expression? value;
    if (match(TokenKind.equals)) value = expression(bare: true);
    endLine();
    return ConfigDeclaration(
        parts.join('.'), type, value, secret, extent(span));
  }

  TaskGroupStatement taskGroup(SourceSpan span) {
    take();
    take();
    expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'task group');
    final children = <Node>[];
    while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
      if (word('task') && peek().lexeme == 'group') {
        children.add(taskGroup(current.span));
        continue;
      }
      if (!word('spawn')) fail('task group contains spawn');
      take();
      children.add(expression(bare: true));
      endLine();
    }
    expect(TokenKind.dedent, 'end of task group');
    return TaskGroupStatement(children, extent(span));
  }

  List<TypeParameter> typeParameterList() {
    if (!match(TokenKind.less)) return const [];
    final parameters = <TypeParameter>[];
    do {
      final span = current.span;
      var variance = '';
      if (word('in') || word('out')) variance = take().lexeme;
      final parameter = name();
      String? bound;
      if (match(TokenKind.colon)) bound = typeName();
      parameters.add(TypeParameter(parameter.lexeme, extent(span),
          variance: variance, bound: bound));
    } while (match(TokenKind.comma) && !atTypeClose());
    expectTypeClose();
    return parameters;
  }

  /// `where T is Numeric` sets the bound. `Numeric` means `num`.
  void _whereClause(List<TypeParameter> parameters) {
    if (!word('where')) return;
    take();
    do {
      final parameter = name();
      if (!word('is')) fail('Expected is');
      take();
      final boundName = name().lexeme;
      final bound = boundName == 'Numeric' ? 'num' : boundName;
      final index =
          parameters.indexWhere((item) => item.name == parameter.lexeme);
      if (index < 0) {
        fail('Unknown type parameter ${parameter.lexeme}', parameter.span);
      }
      final current = parameters[index];
      parameters[index] = TypeParameter(current.name, current.span,
          variance: current.variance, bound: bound);
    } while (match(TokenKind.comma));
  }

  /// Tokens of [span], separated by spaces. Indentation is not part of the text.
  String _snippet(SourceSpan span) {
    final parts = <String>[];
    for (final token in tokens) {
      if (token.kind == TokenKind.newline ||
          token.kind == TokenKind.indent ||
          token.kind == TokenKind.dedent ||
          token.kind == TokenKind.eof) {
        continue;
      }
      final start = token.span.offset;
      if (start + token.span.length <= span.offset) continue;
      if (start >= span.offset + span.length) break;
      if (token.lexeme.isEmpty) continue;
      parts.add(token.lexeme);
    }
    return parts.join(' ');
  }

  /// `>>` and `>>>` are one token. In a type argument they close two or three
  /// argument lists, one `>` at a time.
  int _angleCloseWidth(TokenKind kind) => switch (kind) {
        TokenKind.greater => 1,
        TokenKind.shiftRight => 2,
        TokenKind.unsignedShiftRight => 3,
        _ => 0,
      };

  bool atTypeClose() => _angleCloseWidth(current.kind) > 0;

  bool takeTypeClose() {
    if (match(TokenKind.greater)) return true;
    if (at(TokenKind.shiftRight)) {
      _leaveTypeClose(TokenKind.greater, '>');
      return true;
    }
    if (at(TokenKind.unsignedShiftRight)) {
      _leaveTypeClose(TokenKind.shiftRight, '>>');
      return true;
    }
    return false;
  }

  void _leaveTypeClose(TokenKind kind, String lexeme) {
    final token = current;
    tokens[index] = Token(
        kind,
        lexeme,
        SourceSpan(token.span.line, token.span.column + 1, lexeme.length,
            file: token.span.file, offset: token.span.offset + 1));
  }

  void expectTypeClose() {
    if (!takeTypeClose()) {
      fail('Expected >, found ${current.kind.name}');
    }
  }

  String typeAtom() {
    if (word('readonly')) {
      take();
      return 'readonly ${typeAtom()}';
    }
    if (at(TokenKind.leftParen)) return groupedType();
    var result = name().lexeme;
    while (match(TokenKind.dot)) {
      result += '.${name().lexeme}';
    }
    if (match(TokenKind.less)) {
      result += '<${typeName()}';
      while (match(TokenKind.comma)) {
        result += ', ${typeName()}';
      }
      expectTypeClose();
      result += '>';
    }
    if (match(TokenKind.question)) result += '?';
    return result;
  }

  String groupedType() {
    expect(TokenKind.leftParen, '(');
    final parameters = <String>[];
    if (!at(TokenKind.rightParen)) {
      do {
        if (at(TokenKind.identifier) && peek().kind == TokenKind.colon) {
          final parameter = name();
          take();
          parameters.add('${parameter.lexeme}: ${typeName()}');
        } else {
          parameters.add(typeName());
        }
      } while (match(TokenKind.comma) && !at(TokenKind.rightParen));
    }
    expect(TokenKind.rightParen, ')');
    if (match(TokenKind.arrow)) {
      return '(${parameters.join(', ')}) -> ${typeName()}';
    }
    if (parameters.length == 1 && !parameters.single.contains(':')) {
      final inner = parameters.single;
      if (!match(TokenKind.question)) return inner;
      return inner.startsWith('(') ? '($inner)?' : '$inner?';
    }
    final record = '(${parameters.join(', ')})';
    if (match(TokenKind.question)) return '$record?';
    return record;
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

  Statement forStatement(SourceSpan span,
      {bool awaiting = false,
      bool keywordTaken = false,
      bool asValue = false}) {
    if (!keywordTaken) take();
    if (at(TokenKind.identifier) &&
        (peek().lexeme == 'in' || peek().kind == TokenKind.comma)) {
      final first = name();
      String? index;
      var item = first.lexeme;
      if (match(TokenKind.comma)) {
        index = first.lexeme;
        item = name().lexeme;
      }
      if (!word('in')) fail('Expected in');
      take();
      final iterable = expression();
      Expression? step;
      if (word('step')) {
        take();
        step = expression();
      }
      return ForStatement(item, iterable, block(), extent(span),
          awaiting: awaiting,
          index: index,
          step: step,
          elseBody: asValue ? const [] : _statementElse());
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
    return CForStatement(init, condition, step, block(), extent(span),
        elseBody: asValue ? const [] : _statementElse());
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

  Statement repeatStatement(SourceSpan span,
      {bool keywordTaken = false, bool asValue = false}) {
    if (!keywordTaken) take();
    if (at(TokenKind.colon)) {
      final body = block();
      if (!word('while')) fail('Expected while');
      take();
      final condition = expression();
      endLine();
      return RepeatStatement(body, condition, extent(span),
          elseBody: asValue ? const [] : _statementElse());
    }
    final count = expression();
    return RepeatStatement(suite(), null, extent(span),
        count: count, elseBody: asValue ? const [] : _statementElse());
  }

  /// `:: graph`, `:: graph::weighted`, or a bare `::` back to the library root.
  Statement sectionHeader(SourceSpan span) {
    take();
    take();
    if (at(TokenKind.newline) || at(TokenKind.eof)) {
      if (at(TokenKind.newline)) endLine();
      return SectionDeclaration('', extent(span));
    }
    final parts = <String>[name().lexeme];
    while (at(TokenKind.colon) && peek().kind == TokenKind.colon) {
      take();
      take();
      parts.add(name().lexeme);
    }
    endLine();
    return SectionDeclaration(parts.join('::'), extent(span));
  }

  ImportDeclaration useImport(SourceSpan span) {
    take();
    final buffer = StringBuffer();
    while (!at(TokenKind.newline) && !at(TokenKind.eof)) {
      if (buffer.isNotEmpty &&
          (word('as') || word('when') || word('show') || word('hide'))) {
        break;
      }
      if (buffer.isEmpty && (word('as') || word('when'))) break;
      buffer.write(take().lexeme);
    }
    String? prefix;
    if (word('as')) {
      take();
      prefix = name().lexeme;
    }
    final filters = _combinators();
    Expression? condition;
    if (word('when')) {
      take();
      condition = expression();
    }
    endLine();
    if (buffer.isEmpty) fail('Expected import uri', span);
    return ImportDeclaration(
        normalizeImportUri(_stripUri(buffer.toString())), prefix, extent(span),
        condition: condition, show: filters.$1, hide: filters.$2);
  }

  ImportDeclaration exportDirective(SourceSpan span) {
    take();
    final uri = normalizeImportUri(_stripUri(readUri()));
    final filters = _combinators();
    endLine();
    return ImportDeclaration(uri, null, extent(span),
        export: true, show: filters.$1, hide: filters.$2);
  }

  (List<String>, List<String>) _combinators() {
    if (!word('show') && !word('hide')) return (const [], const []);
    final hiding = word('hide');
    take();
    final names = <String>[name().lexeme];
    while (match(TokenKind.comma)) {
      names.add(name().lexeme);
    }
    return hiding ? (const <String>[], names) : (names, const <String>[]);
  }

  String _stripUri(String uri) {
    if (uri.length >= 2 &&
        ((uri.startsWith('"') && uri.endsWith('"')) ||
            (uri.startsWith("'") && uri.endsWith("'")))) {
      return uri.substring(1, uri.length - 1);
    }
    return uri;
  }

  PartDirective partDirective(SourceSpan span) {
    take();
    final of = word('of');
    if (of) take();
    final uri = readUri();
    endLine();
    return PartDirective(uri, of, extent(span));
  }

  String readUri() {
    if (at(TokenKind.string)) {
      final token = take().lexeme;
      return token.length >= 2 ? token.substring(1, token.length - 1) : token;
    }
    final buffer = StringBuffer();
    while (!at(TokenKind.newline) && !at(TokenKind.eof)) {
      if (buffer.isNotEmpty &&
          (word('as') || word('when') || word('show') || word('hide'))) {
        break;
      }
      if (buffer.isEmpty && (word('as') || word('when'))) break;
      buffer.write(take().lexeme);
    }
    if (buffer.isEmpty) fail('Expected a uri');
    return buffer.toString();
  }

  UsingStatement usingStatement(SourceSpan span) {
    take();
    final async = word('async');
    if (async) take();
    final resource = name();
    expect(TokenKind.equals, '=');
    final value = expression();
    return UsingStatement(resource.lexeme, value, block(), extent(span),
        async: async);
  }

  void _checkModifiers(List<String> modifiers, SourceSpan span) {
    if (modifiers.toSet().length != modifiers.length) {
      throw CompilerException('E720', 'Class modifiers are repeated', span);
    }
    const extras = {'abstract', 'value', 'singleton'};
    const core = {'base', 'interface', 'final', 'sealed', 'mixin'};
    if (modifiers
        .any((item) => !extras.contains(item) && !core.contains(item))) {
      throw CompilerException(
          'E720', 'Class modifiers are not a combination Dart accepts', span);
    }
    final chosen = modifiers.where(core.contains).toSet();
    final legal = chosen.length <= 1 ||
        chosen.length == 2 &&
            chosen.contains('base') &&
            chosen.contains('mixin');
    if (!legal || chosen.contains('sealed') && modifiers.contains('abstract')) {
      throw CompilerException(
          'E720', 'Class modifiers are not a combination Dart accepts', span);
    }
  }

  ClassDeclaration typeDeclaration(SourceSpan span, List<Metadata> notes,
      {String? forced, List<String> modifiers = const []}) {
    final documentation = current.documentation;
    _checkModifiers(modifiers, span);
    var kind = forced ?? 'class';
    if (forced == 'interface') {
      kind = 'interface';
    } else if (modifiers.isEmpty && word('sealed')) {
      take();
      kind = word('type') ? 'sealedType' : 'sealed';
    } else if (modifiers.isEmpty && word('value')) {
      take();
      kind = 'value';
    } else if (forced != 'interface') {
      if (modifiers.contains('mixin')) kind = 'mixinClass';
      if (modifiers.contains('value')) kind = 'value';
      if (modifiers.contains('sealed') && kind != 'value') kind = 'sealed';
    }
    if (kind == 'sealedType') {
      if (!word('type')) fail('Expected type');
      take();
    } else if (kind != 'interface') {
      if (!word('class')) fail('Expected class');
      take();
    }
    final typeNameToken = name();
    final typeParameters = typeParameterList();
    String? superclass;
    final mixins = <String>[];
    final interfaces = <String>[];
    if (word('extends')) {
      take();
      superclass = typeName();
    }
    if (word('with')) {
      take();
      do {
        mixins.add(typeName());
      } while (match(TokenKind.comma));
    }
    if (word('implements')) {
      take();
      do {
        interfaces.add(typeName());
      } while (match(TokenKind.comma));
    }
    expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'indented block');
    final fields = <FieldDeclaration>[];
    final methods = <FunctionDeclaration>[];
    final cases = <ClassCase>[];
    final constructors = <ConstructorDeclaration>[];
    final properties = <PropertyDeclaration>[];
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
      var visibility = '';
      if (word('private') || word('protected')) {
        visibility = take().lexeme;
      }
      if (word('property')) {
        properties.add(propertyDeclaration(visibility));
        continue;
      }
      if (word('operator')) {
        methods.add(operatorDeclaration());
        continue;
      }
      if (word('init') ||
          (word('factory') && peek().lexeme == 'init') ||
          (word('const') && peek().lexeme == 'init')) {
        constructors.add(constructorDeclaration());
        continue;
      }
      var isStatic = false;
      if (word('static')) {
        take();
        isStatic = true;
        if (word('const') && peek().lexeme != 'init') {
          fields.add(staticConstant());
          continue;
        }
        if (!functionAhead()) {
          fields.add(staticField());
          continue;
        }
      }
      var readonlyMethod = false;
      if (word('readonly') &&
          peek().kind == TokenKind.identifier &&
          peek(2).kind == TokenKind.leftParen) {
        take();
        readonlyMethod = true;
      }
      if (functionAhead()) {
        methods.add(function(const [],
            visibility: visibility,
            readonlyMethod: readonlyMethod,
            isStatic: isStatic));
        continue;
      }
      if (word('event')) {
        if (isStatic) fail('static applies to a field, function, or const');
        take();
        final fieldName = name();
        expect(TokenKind.colon, ':');
        final payload = typeName();
        endLine();
        fields.add(FieldDeclaration(fieldName.lexeme, 'Event<$payload>', false,
            false, null, fieldName.span,
            visibility: visibility, isEvent: true));
        continue;
      }
      if (isStatic) fail('static applies to a field, function, or const');
      if (readonlyMethod) fail('readonly applies to a method');
      final mutable = word('var');
      if (mutable) take();
      final fieldName = name();
      expect(TokenKind.colon, ':');
      final fieldType = typeName();
      if (word('by') && peek().lexeme == 'lazy') {
        if (mutable) fail('by lazy is not var');
        take();
        take();
        fields.add(FieldDeclaration(
            fieldName.lexeme, fieldType, false, false, null, fieldName.span,
            visibility: visibility, lazyBody: suite()));
        continue;
      }
      var requiredField = false;
      Expression? initializer;
      if (word('required')) {
        take();
        requiredField = true;
      }
      if (match(TokenKind.equals)) initializer = expression(bare: true);
      endLine();
      fields.add(FieldDeclaration(fieldName.lexeme, fieldType, mutable,
          requiredField || initializer == null, initializer, fieldName.span,
          visibility: visibility));
    }
    expect(TokenKind.dedent, 'end of block');
    return ClassDeclaration(
        typeNameToken.lexeme, kind, fields, methods, cases, notes, extent(span),
        superclass: superclass,
        mixins: mixins,
        interfaces: interfaces,
        modifiers: modifiers,
        constructors: constructors,
        properties: properties,
        typeParameters: typeParameters,
        documentation: documentation);
  }

  PropertyDeclaration propertyDeclaration(String visibility) {
    final token = take();
    final propertyName = name();
    expect(TokenKind.colon, ':');
    final type = typeName();
    Expression? getter;
    List<Statement>? getterBody;
    String? setter;
    List<Statement>? setterBody;
    if (match(TokenKind.colon)) {
      endLine();
      expect(TokenKind.indent, 'indented block');
      while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
        if (word('get')) {
          take();
          if (match(TokenKind.equals)) {
            getter = expression(bare: true);
            endLine();
          } else {
            getterBody = block();
          }
        } else if (word('set')) {
          take();
          expect(TokenKind.leftParen, '(');
          setter = at(TokenKind.identifier) ? name().lexeme : 'value';
          expect(TokenKind.rightParen, ')');
          setterBody = block();
        } else {
          fail('A property suite contains get or set');
        }
      }
      expect(TokenKind.dedent, 'end of property');
    } else {
      endLine();
    }
    return PropertyDeclaration(propertyName.lexeme, type, getter, getterBody,
        setter, setterBody, extent(token.span),
        visibility: visibility);
  }

  FunctionDeclaration operatorDeclaration() {
    final token = take();
    if (at(TokenKind.newline) || at(TokenKind.eof)) fail('Expected operator');
    final op = take();
    return function(const [],
        operatorName: op.lexeme, operatorSpan: extent(token.span));
  }

  ConstructorDeclaration constructorDeclaration() {
    final span = current.span;
    var factory = false;
    var constant = false;
    if (word('factory')) {
      take();
      factory = true;
    }
    if (word('const')) {
      take();
      constant = true;
    }
    if (!word('init')) fail('Expected init');
    take();
    String? ctorName;
    if (at(TokenKind.identifier) && peek().kind == TokenKind.leftParen) {
      ctorName = name().lexeme;
    }
    if (at(TokenKind.equals)) {
      take();
      final value = expression(bare: true);
      endLine();
      return ConstructorDeclaration(
          ctorName, const [], null, value, extent(span),
          factory: factory, constant: constant);
    }
    final parameters = parameterList();
    if (constant && !at(TokenKind.colon) && !at(TokenKind.equals)) {
      endLine();
      return ConstructorDeclaration(
          ctorName, parameters, null, null, extent(span),
          factory: factory, constant: true);
    }
    if (match(TokenKind.arrow)) typeName();
    if (match(TokenKind.equals)) {
      final value = expression(bare: true);
      endLine();
      return ConstructorDeclaration(
          ctorName, parameters, null, value, extent(span),
          factory: factory, constant: constant);
    }
    return ConstructorDeclaration(
        ctorName, parameters, block(), null, extent(span),
        factory: factory, constant: constant);
  }

  Statement typeForm(SourceSpan span) {
    final documentation = current.documentation;
    take();
    final typeNameToken = name();
    if (word('wraps')) {
      take();
      final target = typeName();
      final methods = <FunctionDeclaration>[];
      final requirements = <Expression>[];
      if (at(TokenKind.colon)) {
        take();
        endLine();
        expect(TokenKind.indent, 'indented block');
        while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
          if (word('require')) {
            take();
            requirements.add(expression(bare: true));
            endLine();
            continue;
          }
          if (!functionAhead())
            fail('An extension type member must be a function');
          methods.add(function(const []));
        }
        expect(TokenKind.dedent, 'end of extension type');
      } else {
        endLine();
      }
      return ClassDeclaration(
          typeNameToken.lexeme,
          'extensionType',
          [
            FieldDeclaration(
                'value', target, false, true, null, extent(typeNameToken.span))
          ],
          methods,
          const [],
          const [],
          extent(span),
          requirements: requirements);
    }
    expect(TokenKind.equals, '=');
    final target = typeName();
    endLine();
    return AliasDeclaration(typeNameToken.lexeme, target, extent(span),
        documentation: documentation);
  }

  ClassDeclaration mixinDeclaration(SourceSpan span, List<Metadata> notes,
      {List<String> modifiers = const []}) {
    _checkModifiers([...modifiers, 'mixin'], span);
    take();
    final typeNameToken = name();
    String? onType;
    if (word('on')) {
      take();
      onType = typeName();
    }
    final body = typeMembers(const []);
    return ClassDeclaration(typeNameToken.lexeme, 'mixin', body.$1, body.$2,
        const [], notes, extent(span),
        onType: onType, modifiers: [...modifiers, 'mixin']);
  }

  ExtensionDeclaration extensionDeclaration(
      SourceSpan span, List<Metadata> notes) {
    take();
    final target = typeName();
    final typeParameters = extensionParameters(target, span);
    String? extensionName;
    if (at(TokenKind.identifier) && peek().kind == TokenKind.colon) {
      extensionName = name().lexeme;
    }
    final methods = <FunctionDeclaration>[];
    final properties = <PropertyDeclaration>[];
    expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'indented block');
    while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
      if (word('property')) {
        properties.add(propertyDeclaration(''));
        continue;
      }
      if (!functionAhead()) fail('An extension member must be a function');
      methods.add(function(notes));
    }
    expect(TokenKind.dedent, 'end of extension');
    return ExtensionDeclaration(extensionName, target, methods, extent(span),
        typeParameters: typeParameters, properties: properties);
  }

  List<TypeParameter> extensionParameters(String target, SourceSpan span) {
    const known = {
      'int',
      'double',
      'num',
      'bool',
      'String',
      'Null',
      'Object',
      'dynamic',
      'void',
      'Never',
      'List',
      'Map',
      'Set',
      'Future',
      'Stream',
      'Iterable',
      'Result',
      'Optional',
      'Range'
    };
    final names = <String>[];
    void walk(String type) {
      final open = type.indexOf('<');
      if (open < 0) return;
      final close = type.lastIndexOf('>');
      if (close < open) return;
      final inner = type.substring(open + 1, close);
      var depth = 0;
      final buffer = StringBuffer();
      final parts = <String>[];
      for (final rune in inner.codeUnits) {
        final char = String.fromCharCode(rune);
        if (char == '<') depth++;
        if (char == '>') depth--;
        if (char == ',' && depth == 0) {
          parts.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
      parts.add(buffer.toString());
      for (final part in parts) {
        final trimmed = part.trim();
        walk(trimmed);
        if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(trimmed) &&
            !known.contains(trimmed) &&
            !names.contains(trimmed)) {
          names.add(trimmed);
        }
      }
    }

    walk(target);
    return [for (final name in names) TypeParameter(name, span)];
  }

  (List<FieldDeclaration>, List<FunctionDeclaration>) typeMembers(
      List<Metadata> notes) {
    expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'indented block');
    final fields = <FieldDeclaration>[];
    final methods = <FunctionDeclaration>[];
    while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
      if (functionAhead()) {
        methods.add(function(notes));
        continue;
      }
      final fieldName = name();
      expect(TokenKind.colon, ':');
      final fieldType = typeName();
      var requiredField = false;
      Expression? initializer;
      if (word('required')) {
        take();
        requiredField = true;
      }
      if (match(TokenKind.equals)) initializer = expression(bare: true);
      endLine();
      fields.add(FieldDeclaration(fieldName.lexeme, fieldType, false,
          requiredField || initializer == null, initializer, fieldName.span));
    }
    expect(TokenKind.dedent, 'end of block');
    return (fields, methods);
  }

  Statement whileStatement(SourceSpan span,
      {bool keywordTaken = false, bool asValue = false}) {
    if (!keywordTaken) take();
    if (word('let') &&
        peek().kind == TokenKind.identifier &&
        peek(2).kind == TokenKind.equals) {
      take();
      final bound = name();
      expect(TokenKind.equals, '=');
      final value = expression();
      return WhileStatement(value, block(), extent(span),
          letName: bound.lexeme,
          elseBody: asValue ? const [] : _statementElse());
    }
    final condition = expression(typeTest: false);
    if (word('is')) {
      take();
      final pattern = patternLiteral();
      return WhileStatement(condition, block(), extent(span),
          pattern: pattern, elseBody: asValue ? const [] : _statementElse());
    }
    return WhileStatement(condition, block(), extent(span),
        elseBody: asValue ? const [] : _statementElse());
  }

  /// `else:` after a loop statement. `else if` stays an if-statement form.
  List<Statement> _statementElse() {
    if (!word('else')) return const [];
    take();
    if (word('if')) fail('A loop else is a block');
    return suite();
  }

  /// `else:` after a loop expression. One expression, indented or on the line.
  Expression? _valueElse() {
    if (!word('else')) return null;
    take();
    final value = suiteExpression();
    if (at(TokenKind.newline)) endLine();
    return value;
  }

  Expression _loopValue(Token token) {
    final Statement loop;
    if (token.lexeme == 'for') {
      loop = forStatement(token.span, keywordTaken: true, asValue: true);
    } else if (token.lexeme == 'while') {
      loop = whileStatement(token.span, keywordTaken: true, asValue: true);
    } else {
      loop = repeatStatement(token.span, keywordTaken: true, asValue: true);
    }
    return LoopExpression(loop, _valueElse(), extent(token.span));
  }

  /// An active label followed by more expression syntax is a value, not a label.
  bool _continuesBreakValue() {
    final next = peek();
    return next.kind != TokenKind.newline &&
        next.kind != TokenKind.dedent &&
        next.kind != TokenKind.eof &&
        next.kind != TokenKind.comma &&
        next.lexeme != 'if' &&
        next.lexeme != 'else';
  }

  /// A trailing `if` guards [node]. The condition, including `let` and `is`,
  /// is parsed before the newline.
  Statement finishLine(Statement node) {
    _suffixIf = false;
    if (!word('if')) {
      endLine();
      return node;
    }
    take();
    if (word('let') &&
        peek().kind == TokenKind.identifier &&
        peek(2).kind == TokenKind.equals) {
      take();
      final bound = name();
      expect(TokenKind.equals, '=');
      final value = expression(bare: true);
      final alternate = _guardElse();
      endLine();
      return GuardedStatement(node, value, extent(node.span),
          letName: bound.lexeme, alternate: alternate);
    }
    final condition = expression(typeTest: false);
    if (word('is')) {
      take();
      final pattern = patternLiteral();
      final alternate = _guardElse();
      endLine();
      return GuardedStatement(node, condition, extent(node.span),
          pattern: pattern, alternate: alternate);
    }
    final alternate = _guardElse();
    endLine();
    return GuardedStatement(node, condition, extent(node.span),
        alternate: alternate);
  }

  /// The expression after a same-line `else` on a trailing condition.
  Expression? _guardElse() {
    if (!word('else')) return null;
    take();
    return expression(bare: true);
  }

  bool commaAssignAhead() {
    if (word('var') ||
        word('const') ||
        word('late') ||
        word('state') ||
        word('computed')) {
      return false;
    }
    if (!at(TokenKind.identifier) && !word('shadow')) return false;
    var depth = 0;
    var comma = false;
    for (var j = index; j < tokens.length; j++) {
      final kind = tokens[j].kind;
      if (kind == TokenKind.leftParen ||
          kind == TokenKind.leftBracket ||
          kind == TokenKind.less) {
        depth++;
      }
      if (kind == TokenKind.rightParen ||
          kind == TokenKind.rightBracket ||
          kind == TokenKind.greater) {
        depth--;
      }
      if (depth == 0 && kind == TokenKind.comma) comma = true;
      if (depth == 0 && kind == TokenKind.equals) return comma;
      if (depth == 0 && kind == TokenKind.newline) return false;
      if (depth < 0) return false;
    }
    return false;
  }

  ParallelAssignment parallelAssign(SourceSpan span) {
    final targets = <Pattern>[];
    while (true) {
      if (word('shadow')) {
        take();
        final bound = name();
        targets.add(BindingPattern(bound.lexeme, bound.span, shadow: true));
      } else if (at(TokenKind.identifier) && current.lexeme == '_') {
        targets.add(WildcardPattern(take().span));
      } else {
        final bound = name();
        targets.add(BindingPattern(bound.lexeme, bound.span));
      }
      if (!match(TokenKind.comma) || at(TokenKind.equals)) break;
    }
    expect(TokenKind.equals, '=');
    final values = <Expression>[expression(bare: true)];
    while (match(TokenKind.comma) && !at(TokenKind.newline)) {
      values.add(expression(bare: true));
    }
    return ParallelAssignment(targets, values, extent(span));
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
    var left = patternAnd();
    while (at(TokenKind.pipe)) {
      final span = left.span;
      take();
      left = OrPattern(left, patternAnd(), extent(span));
    }
    return left;
  }

  Pattern patternAnd() {
    var left = patternPostfix();
    while (word('and')) {
      final span = left.span;
      take();
      left = AndPattern(left, patternPostfix(), extent(span));
    }
    return left;
  }

  Pattern patternPostfix() {
    var pattern = patternPrimary();
    while (true) {
      if (word('as')) {
        final span = pattern.span;
        take();
        pattern = CastPattern(pattern, typeName(), extent(span));
        continue;
      }
      if (at(TokenKind.question)) {
        final span = pattern.span;
        take();
        pattern = NullCheckPattern(pattern, extent(span));
        continue;
      }
      if (at(TokenKind.bang)) {
        final span = pattern.span;
        take();
        pattern = NullAssertPattern(pattern, extent(span));
        continue;
      }
      return pattern;
    }
  }

  bool relationalAhead() =>
      at(TokenKind.less) ||
      at(TokenKind.lessEqual) ||
      at(TokenKind.greater) ||
      at(TokenKind.greaterEqual) ||
      at(TokenKind.equalEqual) ||
      at(TokenKind.bangEqual);

  Pattern patternPrimary() {
    final span = current.span;
    if (relationalAhead()) {
      final operator = take().lexeme;
      return RelationalPattern(operator, expression(minimum: 3), extent(span));
    }
    const typeWords = {'int', 'double', 'num', 'bool', 'String', 'Null'};
    if (at(TokenKind.identifier) && typeWords.contains(current.lexeme)) {
      final type = take().lexeme;
      final shadowed = word('shadow');
      if (shadowed) take();
      final name = at(TokenKind.identifier) && current.lexeme != 'when'
          ? this.name().lexeme
          : null;
      return TypedPattern(type, name, span, shadow: shadowed);
    }
    if (word('shadow')) {
      take();
      final bound = name();
      return BindingPattern(bound.lexeme, bound.span, shadow: true);
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
    if (word('map') && peek().kind == TokenKind.colon) {
      take();
      take();
      endLine();
      expect(TokenKind.indent, 'map pattern');
      final keys = <Expression>[];
      final values = <Pattern>[];
      while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
        keys.add(expression());
        expect(TokenKind.colon, ':');
        values.add(patternLiteral());
        endLine();
      }
      expect(TokenKind.dedent, 'end of map pattern');
      return MapPattern(keys, values, extent(span));
    }
    if (at(TokenKind.leftParen)) {
      take();
      final fields = <Pattern>[];
      var comma = false;
      if (!at(TokenKind.rightParen)) {
        while (true) {
          fields.add(patternLiteral());
          if (!match(TokenKind.comma)) break;
          comma = true;
          if (at(TokenKind.rightParen)) break;
        }
      }
      expect(TokenKind.rightParen, ')');
      if (fields.length == 1 && !comma) return fields.single;
      return ConstructorPattern(
          '', fields, List.filled(fields.length, null), extent(span));
    }
    if (at(TokenKind.leftBracket)) {
      take();
      final elements = <Pattern>[];
      if (!at(TokenKind.rightBracket)) {
        while (true) {
          if (at(TokenKind.spread)) {
            final rest = take();
            final shadowed = word('shadow');
            if (shadowed) take();
            String? bound;
            if (at(TokenKind.identifier) &&
                current.lexeme != '_' &&
                current.lexeme != 'when') {
              bound = name().lexeme;
            }
            elements.add(RestPattern(bound, rest.span, shadow: shadowed));
          } else {
            elements.add(patternLiteral());
          }
          if (!match(TokenKind.comma) || at(TokenKind.rightBracket)) break;
        }
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

  FieldDeclaration staticField() {
    final mutable = word('var');
    if (mutable) take();
    final fieldName = name();
    var type = '<infer>';
    if (match(TokenKind.colon)) type = typeName();
    if (word('by') && peek().lexeme == 'lazy') {
      if (mutable) fail('by lazy is not var');
      take();
      take();
      return FieldDeclaration(
          fieldName.lexeme, type, false, false, null, fieldName.span,
          isStatic: true, lazyBody: suite());
    }
    expect(TokenKind.equals, '=');
    final value = expression(bare: true);
    endLine();
    return FieldDeclaration(
        fieldName.lexeme, type, mutable, false, value, fieldName.span,
        isStatic: true);
  }

  FieldDeclaration staticConstant() {
    take();
    final fieldName = name();
    var type = '<infer>';
    if (match(TokenKind.colon)) type = typeName();
    expect(TokenKind.equals, '=');
    final value = expression(bare: true);
    endLine();
    return FieldDeclaration(
        fieldName.lexeme, type, false, false, value, fieldName.span,
        isStatic: true, isConst: true);
  }

  FunctionDeclaration function(List<Metadata> notes,
      {String visibility = '',
      bool readonlyMethod = false,
      String? operatorName,
      SourceSpan? operatorSpan,
      bool isStatic = false}) {
    final documentation = operatorName == null ? current.documentation : null;
    final token = operatorName == null ? name() : null;
    final nameText = operatorName ?? token!.lexeme;
    final span = operatorSpan ?? token!.span;
    final typeParameters = operatorName == null
        ? List<TypeParameter>.of(typeParameterList())
        : <TypeParameter>[];
    final parameters = parameterList();
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
    _whereClause(typeParameters);
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
          nameText, parameters, returnType, null, value, extent(span),
          isAsync: isAsync,
          annotations: notes,
          generator: generator,
          visibility: visibility,
          isOperator: operatorName != null,
          readonlyMethod: readonlyMethod,
          isStatic: isStatic,
          typeParameters: typeParameters,
          documentation: documentation);
    }
    return FunctionDeclaration(
        nameText, parameters, returnType, block(), null, extent(span),
        isAsync: isAsync,
        annotations: notes,
        generator: generator,
        visibility: visibility,
        isOperator: operatorName != null,
        readonlyMethod: readonlyMethod,
        isStatic: isStatic,
        typeParameters: typeParameters,
        documentation: documentation);
  }

  List<Parameter> parameterList() {
    expect(TokenKind.leftParen, '(');
    final parameters = <Parameter>[];
    if (!at(TokenKind.rightParen)) {
      do {
        parameters.add(parameter());
      } while (match(TokenKind.comma) && !at(TokenKind.rightParen));
    }
    expect(TokenKind.rightParen, ')');
    final variadicAt = parameters.indexWhere((item) => item.variadic);
    if (variadicAt >= 0 && variadicAt != parameters.length - 1) {
      throw CompilerException('E503', 'A variadic parameter must be last',
          parameters[variadicAt].span);
    }
    return parameters;
  }

  Parameter parameter() {
    final span = current.span;
    if (word('this') || word('super')) {
      final kind = take().lexeme;
      expect(TokenKind.dot, '.');
      final field = name();
      var type = '<field>';
      if (match(TokenKind.colon)) type = typeName();
      if (word('required')) take();
      Expression? defaultValue;
      if (match(TokenKind.equals)) defaultValue = expression();
      return Parameter(field.lexeme, type, false, extent(span),
          defaultValue: defaultValue, initializing: kind);
    }
    final variadic = at(TokenKind.spread);
    if (variadic) take();
    final mutable = word('var');
    if (mutable) take();
    final parameterName = name();
    expect(TokenKind.colon, ':');
    final type = typeName();
    if (word('required')) take();
    Expression? defaultValue;
    if (match(TokenKind.equals)) defaultValue = expression();
    return Parameter(
        parameterName.lexeme, type, mutable, extent(parameterName.span),
        defaultValue: defaultValue, variadic: variadic);
  }

  ClassDeclaration enumDeclaration(SourceSpan span, List<Metadata> notes) {
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
      if (match(TokenKind.comma)) {
        trace = name().lexeme;
      } else if (at(TokenKind.colon) && peek().kind == TokenKind.identifier) {
        take();
        type = typeName();
        if (match(TokenKind.comma)) trace = name().lexeme;
      }
      catches.add(
          CatchClause(caught.lexeme, type, trace, block(), extent(token.span)));
    }
    final elseBody = <Statement>[];
    if (word('else')) {
      if (catches.isEmpty) fail('try else needs catch');
      take();
      elseBody.addAll(block());
    }
    final finallyBody = <Statement>[];
    if (word('finally')) {
      take();
      finallyBody.addAll(block());
    }
    if (catches.isEmpty && finallyBody.isEmpty) {
      fail('try needs catch or finally', span);
    }
    return TryStatement(body, catches, finallyBody, extent(span),
        elseBody: elseBody);
  }

  Statement ifStatement() {
    final token = take();
    if (word('let')) {
      take();
      final bound = name();
      expect(TokenKind.equals, '=');
      final value = expression();
      final body = suite();
      final otherwise = <Statement>[];
      if (word('else')) {
        take();
        if (word('if')) {
          otherwise.add(ifStatement());
        } else {
          otherwise.addAll(suite());
        }
      }
      return IfLetStatement(
          bound.lexeme, value, body, otherwise, extent(token.span));
    }
    final condition = expression(typeTest: false);
    if (word('is')) {
      take();
      final pattern = patternLiteral();
      return IfCaseStatement(condition, pattern, suite(), extent(token.span));
    }
    final body = suite();
    final otherwise = <Statement>[];
    if (word('else')) {
      take();
      if (word('if')) {
        otherwise.add(ifStatement());
      } else {
        otherwise.addAll(suite());
      }
    }
    return IfStatement(condition, body, otherwise, extent(token.span));
  }

  /// A colon and either one statement on that line, or an indented block.
  List<Statement> suite() {
    expect(TokenKind.colon, ':');
    if (at(TokenKind.newline) || at(TokenKind.dedent) || at(TokenKind.eof)) {
      return block(colonTaken: true);
    }
    final line = <Statement>[statement()];
    line.addAll(_pending);
    _pending.clear();
    return line;
  }

  List<Statement> block({bool colonTaken = false}) {
    if (!colonTaken) expect(TokenKind.colon, ':');
    endLine();
    expect(TokenKind.indent, 'indented block');
    final body = <Statement>[];
    while (
        _pending.isNotEmpty || (!at(TokenKind.dedent) && !at(TokenKind.eof))) {
      try {
        body.add(statement());
      } on CompilerException catch (error) {
        _record(error);
      }
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
    if (!aware && word('for')) {
      return trailingComprehension(value, terminated: terminated);
    }
    value = finishCollection(value, terminated: terminated);
    return aware ? NullAwareElement(value, value.span) : value;
  }

  /// `value for name in iterable if condition` builds one element per item.
  Expression trailingComprehension(Expression element,
      {required bool terminated}) {
    take();
    final names = loopNames();
    expect(TokenKind.identifier, 'in');
    if (tokens[index - 1].lexeme != 'in') {
      fail('Expected in', tokens[index - 1].span);
    }
    final iterable = expression();
    Expression? filter;
    if (word('if')) {
      take();
      filter = expression(bare: terminated);
    }
    if (terminated) endLine();
    return CollectionFor(names.$1, iterable, [element], extent(element.span),
        filter: filter, index: names.$2);
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
    final names = loopNames();
    expect(TokenKind.identifier, 'in');
    if (tokens[index - 1].lexeme != 'in') {
      fail('Expected in', tokens[index - 1].span);
    }
    final iterable = expression();
    return CollectionFor(names.$1, iterable, elementBlock(), extent(token.span),
        index: names.$2);
  }

  /// `name` or `index, name` before `in`.
  (String, String?) loopNames() {
    final first = name();
    if (!match(TokenKind.comma)) return (first.lexeme, null);
    return (name().lexeme, first.lexeme);
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

  int precedence(Token token, {bool range = true}) {
    if (token.kind == TokenKind.pipeGreater) return -1;
    if (token.kind == TokenKind.questionQuestion) return 0;
    if (token.kind == TokenKind.dotDot || token.kind == TokenKind.dotDotLess) {
      return range ? 5 : -2;
    }
    if (token.kind == TokenKind.tildeSlash) return 11;
    return switch (token.lexeme) {
      'or' => 1,
      'and' => 2,
      '==' || '!=' => 3,
      '<' || '<=' || '>' || '>=' => 4,
      '|' => 6,
      '^' => 7,
      '&' => 8,
      '<<' || '>>' || '>>>' => 9,
      '+' || '-' => 10,
      '*' || '/' || '%' => 11,
      _ => -2,
    };
  }

  Expression expression(
      {int minimum = -1,
      bool bare = false,
      bool typeTest = true,
      bool range = true}) {
    var left = prefix();
    while (true) {
      if ((left is Identifier || left is MemberAccess) &&
          _typeArgumentsAhead()) {
        final arguments = <String>[];
        take();
        do {
          arguments.add(typeName());
        } while (match(TokenKind.comma) && !atTypeClose());
        expectTypeClose();
        left = TypeApplication(left, arguments, extent(left.span));
        continue;
      }
      if (at(TokenKind.leftParen)) {
        left = call(left);
        continue;
      }
      if (at(TokenKind.leftBracket)) {
        take();
        left = finishIndex(left);
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
      if (typeTest && (word('is') || word('as')) && 4 >= minimum) {
        var operator = take().lexeme;
        if (operator == 'is' && match(TokenKind.bang)) operator = 'is!';
        final type = typeName();
        left = TypeTestExpression(left, operator, type, extent(left.span));
        continue;
      }
      if ((word('in') || (word('not') && peek().lexeme == 'in')) &&
          4 >= minimum) {
        final negative = word('not');
        if (negative) take();
        take();
        final right = expression(minimum: 5, range: range);
        left = BinaryExpression(
            left, negative ? 'not in' : 'in', right, extent(left.span));
        continue;
      }
      final power = precedence(current, range: range);
      if (power < minimum) break;
      final operator = take();
      final right = expression(minimum: power + 1, range: range);
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
      if (left is BinaryExpression && _comparison(left.operator)) {
        final operands = <Expression>[left.left, left.right];
        final operators = <String>[left.operator];
        while (_comparison(current.lexeme) &&
            precedence(current, range: range) >= minimum) {
          operators.add(take().lexeme);
          operands.add(expression(minimum: 5, range: range));
        }
        if (operators.length > 1) {
          left =
              ChainComparison(operands, operators, extent(operands.first.span));
        }
      }
    }
    if (bare && left is Identifier && startsExpression()) {
      final argument = expression(bare: true);
      left = CallExpression(
          left, [Argument(null, argument, argument.span)], extent(left.span));
    }
    if (bare && left is MemberAccess && startsExpression()) {
      final arguments = <Argument>[];
      do {
        arguments.add(_juxtaposedArgument());
      } while (match(TokenKind.comma));
      left = CallExpression(left, arguments, extent(left.span));
    }
    if (minimum < 0 && word('where')) left = _where(left);
    return left;
  }

  /// `expr where name = value, other = value` or an indented `where:` block.
  Expression _where(Expression value) {
    final span = value.span;
    take();
    final bindings = <Binding>[];
    if (at(TokenKind.colon)) {
      take();
      endLine();
      expect(TokenKind.indent, 'indented block');
      while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
        bindings.add(_whereBinding());
        endLine();
      }
      expect(TokenKind.dedent, 'end of block');
      return WhereExpression(value, bindings, extent(span), block: true);
    }
    bindings.add(_whereBinding());
    while (match(TokenKind.comma)) {
      bindings.add(_whereBinding());
    }
    return WhereExpression(value, bindings, extent(span));
  }

  Binding _whereBinding() {
    final start = current.span;
    final bindingName = name();
    expect(TokenKind.equals, '=');
    final init = expression();
    return Binding(bindingName.lexeme, BindingMode.inferred, null, '=', init,
        extent(start));
  }

  /// `items[1]`, `text[1..]`, `text[..<n]`, and `items[1..3]`.
  ///
  /// A bound stops before `..`, so the range is the slice rather than a value
  /// used as an index. Comparisons inside the brackets stay part of a bound.
  Expression finishIndex(Expression object) {
    final span = object.span;
    if (at(TokenKind.dotDot) || at(TokenKind.dotDotLess)) {
      final inclusive = take().kind == TokenKind.dotDot;
      final end = at(TokenKind.rightBracket) ? null : expression(range: false);
      expect(TokenKind.rightBracket, ']');
      return SliceExpression(object, null, end, inclusive, extent(span));
    }
    final start = expression(range: false);
    if (at(TokenKind.dotDot) || at(TokenKind.dotDotLess)) {
      final inclusive = take().kind == TokenKind.dotDot;
      final end = at(TokenKind.rightBracket) ? null : expression(range: false);
      expect(TokenKind.rightBracket, ']');
      return SliceExpression(object, start, end, inclusive, extent(span));
    }
    expect(TokenKind.rightBracket, ']');
    return IndexExpression(object, start, extent(span));
  }

  bool _comparison(String operator) =>
      operator == '<' ||
      operator == '<=' ||
      operator == '>' ||
      operator == '>=';

  /// `log.info "Loaded", data: map:` is a call. `map:` and `set:` stay collections.
  Argument _juxtaposedArgument() {
    String? label;
    final span = current.span;
    if (at(TokenKind.identifier) &&
        peek().kind == TokenKind.colon &&
        current.lexeme != 'map' &&
        current.lexeme != 'set') {
      label = name().lexeme;
      take();
    }
    final value = expression(bare: true);
    if (value is Identifier &&
        (value.name == 'map' || value.name == 'set') &&
        at(TokenKind.colon)) {
      return Argument(label, collectionLiteral(value.name, value.span), span);
    }
    return Argument(label, value, span);
  }

  /// `if` without a `:` on this line is a trailing condition, not an argument.
  bool _ifExpressionAhead() {
    var depth = 0;
    for (var j = index + 1; j < tokens.length; j++) {
      final kind = tokens[j].kind;
      if (kind == TokenKind.leftParen || kind == TokenKind.leftBracket) {
        depth++;
      }
      if (kind == TokenKind.rightParen || kind == TokenKind.rightBracket) {
        depth--;
      }
      if (depth == 0 && kind == TokenKind.colon) return true;
      if (depth == 0 &&
          (kind == TokenKind.newline || kind == TokenKind.equals)) {
        return false;
      }
      if (depth < 0) return false;
    }
    return false;
  }

  bool startsExpression() =>
      at(TokenKind.number) ||
      at(TokenKind.string) ||
      at(TokenKind.leftBracket) ||
      at(TokenKind.leftParen) ||
      at(TokenKind.identifier) &&
          !{'else', 'in', 'and', 'or', 'for', 'where'}
              .contains(current.lexeme) &&
          !(word('if') && !_ifExpressionAhead());
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
        throw CompilerException(
            'E006',
            'Numeric literal is outside the supported native Dart range',
            token.span);
      }
      return Literal(value, token.span);
    }
    if (token.kind == TokenKind.string) return string(token);
    if (token.kind == TokenKind.minus ||
        token.kind == TokenKind.plus ||
        token.kind == TokenKind.tilde ||
        token.lexeme == 'not') {
      return UnaryExpression(
          token.lexeme, expression(minimum: 12), extent(token.span));
    }
    if (token.lexeme == 'await') {
      if (word('all') && peek().kind == TokenKind.colon) {
        take();
        take();
        endLine();
        expect(TokenKind.indent, 'await all');
        final arms = <Expression>[];
        while (!at(TokenKind.dedent) && !at(TokenKind.eof)) {
          arms.add(expression(bare: true));
          endLine();
        }
        expect(TokenKind.dedent, 'end of await all');
        return AwaitAllExpression(arms, extent(token.span));
      }
      if (word('isolate') && peek().kind == TokenKind.colon) {
        take();
        take();
        endLine();
        expect(TokenKind.indent, 'await isolate');
        final call = expression(bare: true);
        endLine();
        expect(TokenKind.dedent, 'end of await isolate');
        return AwaitIsolateExpression(call, extent(token.span));
      }
      return AwaitExpression(expression(minimum: 12), extent(token.span));
    }
    if (token.lexeme == 'symbol') {
      if (!at(TokenKind.string)) fail('symbol expects a string', token.span);
      final parsed = string(take());
      if (parsed is! Literal || parsed.value is! String) {
        fail('symbol expects a string', token.span);
      }
      return SymbolExpression(parsed.value as String, extent(token.span));
    }
    if (token.lexeme == 'if') return ifExpression(token);
    if (token.lexeme == 'for' ||
        token.lexeme == 'while' ||
        token.lexeme == 'repeat') {
      return _loopValue(token);
    }
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
      if (token.lexeme == 'this') return ThisExpression(token.span);
      if (token.lexeme == 'nameof') {
        final first = name();
        final parts = [first.lexeme];
        Expression target = Identifier(first.lexeme, first.span);
        while (match(TokenKind.dot)) {
          final member = name();
          parts.add(member.lexeme);
          target =
              MemberAccess(target, member.lexeme, false, extent(first.span));
        }
        return NameofExpression(target, parts.join('.'), extent(token.span));
      }
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
        if (at(TokenKind.spread) || at(TokenKind.spreadQuestion)) {
          final token = take();
          final operand = expression();
          arguments.add(Argument(
              null,
              SpreadElement(operand, token.kind == TokenKind.spreadQuestion,
                  extent(token.span)),
              span));
        } else {
          if (at(TokenKind.identifier) && peek().kind == TokenKind.colon) {
            label = name().lexeme;
            take();
          }
          arguments.add(Argument(label, expression(), span));
        }
      } while (match(TokenKind.comma) && !at(TokenKind.rightParen));
    }
    expect(TokenKind.rightParen, ')');
    return CallExpression(callee, arguments, extent(callee.span));
  }

  /// Spaces removed from a triple-quoted block, using the closing line as the margin.
  Set<int>? _closingDedent(String content, SourceSpan span) {
    final lastNl = content.lastIndexOf('\n');
    if (lastNl < 0) return null;
    var suffix = content.substring(lastNl + 1);
    if (suffix.endsWith('\r')) suffix = suffix.substring(0, suffix.length - 1);
    if (suffix.codeUnits.any((unit) => unit != 0x20)) return null;
    final margin = suffix.length;
    final skips = <int>{};
    var index = 0;
    if (content.startsWith('\r\n')) {
      skips.add(0);
      skips.add(1);
      index = 2;
    } else if (content.startsWith('\n')) {
      skips.add(0);
      index = 1;
    }
    while (index < lastNl) {
      final start = index;
      while (index < lastNl && content[index] != '\n') {
        index++;
      }
      var end = index;
      if (end > start && content[end - 1] == '\r') end--;
      final line = content.substring(start, end);
      var spaces = 0;
      while (spaces < line.length && line.codeUnitAt(spaces) == 0x20) {
        spaces++;
      }
      final whitespace =
          line.codeUnits.every((unit) => unit == 0x20 || unit == 0x09);
      if (whitespace && spaces < margin) {
        for (var cursor = start; cursor < end; cursor++) {
          skips.add(cursor);
        }
      } else if (spaces < margin) {
        fail('A line is less indented than the closing quotes', span);
      } else {
        for (var cursor = 0; cursor < margin; cursor++) {
          skips.add(start + cursor);
        }
      }
      if (index < lastNl && content[index] == '\n') index++;
    }
    for (var cursor = lastNl; cursor < content.length; cursor++) {
      skips.add(cursor);
    }
    return skips;
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

    final skips = width == 3 ? _closingDedent(content, token.span) : null;
    for (var i = 0; i < content.length; i++) {
      if (skips != null && skips.contains(i)) continue;
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
        final hole = content.substring(start, i);
        final shown = _shownText(hole);
        final prefix = text.substring(0, width + start);
        final lines =
            prefix.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
        final line = token.span.line + lines.length - 1;
        final column = lines.length == 1
            ? token.span.column + prefix.length
            : lines.last.length + 1;
        final offset = token.span.offset + utf8.encode(prefix).length;
        final nestedTokens = Lexer()
            .tokenize(shown ?? hole, file: token.span.file)
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
        parts.add(
            shown == null ? value : ShownExpression(value, shown, value.span));
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

  /// `{age=}` keeps the expression text. `{a == b}` stays a comparison.
  String? _shownText(String hole) {
    final trimmed = hole.trimRight();
    if (trimmed.length < 2 || !trimmed.endsWith('=')) return null;
    final before = trimmed[trimmed.length - 2];
    if (before == '=' || before == '<' || before == '>' || before == '!') {
      return null;
    }
    return trimmed.substring(0, trimmed.length - 1).trim();
  }
}
