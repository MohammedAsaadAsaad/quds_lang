import 'lexer.dart';

/// Formats Quds [source] with [indent] spaces per level, normalized token
/// spacing, and a maximum [width]. Comments, documentation, and string
/// contents stay intact. A long line breaks after the last comma that still
/// fits. A condition whose body is one statement can share its header line
/// when [singleLineIf] is set and the result fits. Trailing whitespace outside
/// a string is removed, and a newline ends the file.
String formatQuds(String source,
    {int indent = 2, int width = 80, bool singleLineIf = true}) {
  final step = indent < 1 ? 2 : indent;
  final limit = width < 20 ? 20 : width;
  final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();

  final insideMultilineString = <bool>[];
  final hasBlockComment = <bool>[];
  final indents = <int>[];
  var openQuote = '';
  var blockCommentDepth = 0;
  for (final line in lines) {
    if (openQuote.isNotEmpty) {
      insideMultilineString.add(true);
      hasBlockComment.add(false);
      openQuote = _advanceQuotes(line, openQuote);
      continue;
    }
    insideMultilineString.add(false);
    final scan = _scanLineBlockComments(line, blockCommentDepth);
    hasBlockComment.add(blockCommentDepth > 0 || scan.sawComment);
    blockCommentDepth = scan.depth;
    if (line.trim().isNotEmpty) {
      final leading = line.length - line.trimLeft().length;
      if (!indents.contains(leading)) indents.add(leading);
    }
    openQuote = _advanceQuotes(line, '');
  }
  indents.sort();

  final tokenized = _tokenize(normalized);
  final tokensByLine = tokenized?.byLine;
  final genericAngles = tokenized?.genericAngles ?? const <Token>{};
  final multilineTokenLines = <int>{};
  if (tokensByLine != null) {
    for (final entry in tokensByLine.entries) {
      for (final token in entry.value) {
        if (token.lexeme.contains('\n')) {
          final spanLines = token.lexeme.split('\n').length;
          for (var offset = 0; offset < spanLines; offset++) {
            multilineTokenLines.add(entry.key + offset);
          }
        }
      }
    }
  }

  final rewritten = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (insideMultilineString[i]) {
      rewritten.add(lines[i]);
      continue;
    }
    final rawLine = lines[i].trimRight();
    if (rawLine.trim().isEmpty) {
      rewritten.add('');
      continue;
    }
    final spaces = rawLine.length - rawLine.trimLeft().length;
    final depth = indents.indexOf(spaces);
    final prefix = ' ' * step * (depth < 0 ? 0 : depth);
    final lineNumber = i + 1;
    final lineTokens = tokensByLine?[lineNumber];
    final formattedContent = (lineTokens != null &&
            lineTokens.isNotEmpty &&
            !hasBlockComment[i] &&
            !multilineTokenLines.contains(lineNumber))
        ? _formatLineTokens(rawLine, lineTokens, genericAngles,
            isTopLevel: depth <= 0)
        : rawLine.trimLeft();
    final body = '$prefix$formattedContent';
    rewritten.addAll(_wrapLine(body, limit));
  }
  final collapsed =
      singleLineIf ? _collapseIfs(rewritten, step, limit) : rewritten;
  return '${collapsed.join('\n')}\n';
}

class _TokenizedSource {
  const _TokenizedSource(this.byLine, this.genericAngles);
  final Map<int, List<Token>> byLine;
  final Set<Token> genericAngles;
}

_TokenizedSource? _tokenize(String source) {
  try {
    final tokens = const Lexer().tokenize(source);
    final grouped = <int, List<Token>>{};
    for (final token in tokens) {
      if (token.kind == TokenKind.newline ||
          token.kind == TokenKind.indent ||
          token.kind == TokenKind.dedent ||
          token.kind == TokenKind.eof) {
        continue;
      }
      grouped.putIfAbsent(token.span.line, () => <Token>[]).add(token);
    }
    return _TokenizedSource(grouped, _findGenericAngles(tokens));
  } on CompilerException {
    return null;
  }
}

const _spaceBeforeParenKeywords = {
  'if',
  'elif',
  'else',
  'while',
  'for',
  'in',
  'is',
  'as',
  'to',
  'with',
  'and',
  'or',
  'not',
  'return',
  'yield',
  'print',
  'throw',
  'await',
  'assert',
  'match',
  'case',
  'when',
  'where',
  'repeat',
  'until',
  'unless',
  'then',
  'do',
  'defer',
};

const _nonValueKeywords = {
  'if',
  'elif',
  'else',
  'while',
  'for',
  'in',
  'is',
  'as',
  'to',
  'with',
  'and',
  'or',
  'not',
  'return',
  'yield',
  'print',
  'throw',
  'await',
  'assert',
  'case',
  'then',
  'do',
  'defer',
  'var',
  'val',
  'const',
};

const _directiveClauses = {'as', 'show', 'hide', 'deferred', 'when'};

const _genericDisallowedKeywords = {
  'and',
  'or',
  'not',
  'in',
  'is',
  'as',
  'to',
  'if',
  'elif',
  'else',
  'then',
  'for',
  'while',
  'return',
  'yield',
  'print',
  'throw',
  'await',
  'match',
  'case',
  'repeat',
};

const _binaryOperatorKinds = {
  TokenKind.equals,
  TokenKind.plus,
  TokenKind.minus,
  TokenKind.star,
  TokenKind.slash,
  TokenKind.percent,
  TokenKind.tildeSlash,
  TokenKind.plusEquals,
  TokenKind.minusEquals,
  TokenKind.starEquals,
  TokenKind.slashEquals,
  TokenKind.equalEqual,
  TokenKind.bangEqual,
  TokenKind.less,
  TokenKind.lessEqual,
  TokenKind.greater,
  TokenKind.greaterEqual,
  TokenKind.arrow,
  TokenKind.questionQuestion,
  TokenKind.questionQuestionEquals,
  TokenKind.pipe,
  TokenKind.pipeGreater,
  TokenKind.amp,
  TokenKind.caret,
  TokenKind.shiftLeft,
  TokenKind.shiftRight,
  TokenKind.unsignedShiftRight,
};

String _formatLineTokens(
  String rawLine,
  List<Token> tokens,
  Set<Token> genericAngles, {
  required bool isTopLevel,
}) {
  final last = tokens.last;
  final trailingStart = (last.span.column - 1) + last.lexeme.length;
  final trailingComment = trailingStart <= rawLine.length
      ? rawLine.substring(trailingStart).trim()
      : '';

  final formatted =
      _renderTokens(tokens, genericAngles, isTopLevel: isTopLevel);
  if (trailingComment.isEmpty) return formatted;
  return '$formatted $trailingComment';
}

bool _isDirectiveLine(List<Token> tokens, bool isTopLevel) {
  if (!isTopLevel || tokens.length < 2) return false;
  if (tokens[0].kind != TokenKind.identifier) return false;
  final head = tokens[0].lexeme;
  if (head != 'use' && head != 'export' && head != 'part') return false;
  final next = tokens[1].kind;
  return next == TokenKind.identifier ||
      next == TokenKind.string ||
      next == TokenKind.caret ||
      next == TokenKind.dot;
}

String _renderTokens(
  List<Token> tokens,
  Set<Token> genericAngles, {
  bool isTopLevel = false,
}) {
  // Section headers: `::`, `:: types`, `:: interval::outward`
  if (tokens.length >= 2 &&
      tokens[0].kind == TokenKind.colon &&
      tokens[1].kind == TokenKind.colon) {
    if (tokens.length == 2) return '::';
    final rest = StringBuffer();
    for (var i = 2; i < tokens.length; i++) {
      rest.write(tokens[i].lexeme);
    }
    return ':: $rest';
  }

  // Directive lines: `use ...`, `export ...`, `part ...`, `part of ...`
  if (_isDirectiveLine(tokens, isTopLevel)) {
    return _renderDirective(tokens, genericAngles);
  }

  final operatorIndexes = _findOperatorNameIndexes(tokens);
  final brackets = <TokenKind>[];
  final out = StringBuffer();

  for (var i = 0; i < tokens.length; i++) {
    final curr = tokens[i];
    final prev = i > 0 ? tokens[i - 1] : null;
    final prevPrev = i > 1 ? tokens[i - 2] : null;

    if (prev != null &&
        _needsSpace(
          tokens: tokens,
          index: i,
          prev: prev,
          prevPrev: prevPrev,
          curr: curr,
          brackets: brackets,
          genericAngles: genericAngles,
          operatorIndexes: operatorIndexes,
        )) {
      out.write(' ');
    }
    out.write(curr.lexeme);

    if (curr.kind == TokenKind.leftParen ||
        curr.kind == TokenKind.leftBracket) {
      brackets.add(curr.kind);
    } else if ((curr.kind == TokenKind.rightParen ||
            curr.kind == TokenKind.rightBracket) &&
        brackets.isNotEmpty) {
      brackets.removeLast();
    }
  }
  return out.toString();
}

String _renderDirective(List<Token> tokens, Set<Token> genericAngles) {
  final out = StringBuffer(tokens[0].lexeme);
  var i = 1;
  if (tokens[0].lexeme == 'part' &&
      i < tokens.length &&
      tokens[i].kind == TokenKind.identifier &&
      tokens[i].lexeme == 'of') {
    out.write(' of');
    i++;
  }
  if (i >= tokens.length) return out.toString();
  out.write(' ');
  // Keep the module path tightly joined until a clause keyword (`as`, `show`,
  // `hide`, `deferred`, `when`).
  while (i < tokens.length) {
    final tok = tokens[i];
    if (tok.kind == TokenKind.identifier &&
        _directiveClauses.contains(tok.lexeme)) {
      break;
    }
    out.write(tok.lexeme);
    i++;
  }
  if (i < tokens.length) {
    out.write(' ');
    out.write(_renderTokens(tokens.sublist(i), genericAngles));
  }
  return out.toString();
}

Set<int> _findOperatorNameIndexes(List<Token> tokens) {
  final result = <int>{};
  for (var i = 0; i + 1 < tokens.length; i++) {
    if (tokens[i].kind == TokenKind.identifier &&
        tokens[i].lexeme == 'operator') {
      final next = tokens[i + 1];
      if (next.kind == TokenKind.leftBracket &&
          i + 2 < tokens.length &&
          tokens[i + 2].kind == TokenKind.rightBracket) {
        result.add(i + 1);
        result.add(i + 2);
        if (i + 3 < tokens.length && tokens[i + 3].kind == TokenKind.equals) {
          result.add(i + 3);
        }
      } else if (_binaryOperatorKinds.contains(next.kind) ||
          next.kind == TokenKind.tilde) {
        result.add(i + 1);
      }
    }
  }
  return result;
}

Set<Token> _findGenericAngles(List<Token> tokens) {
  final result = Set<Token>.identity();
  var lineHead = 0;

  for (var i = 0; i < tokens.length; i++) {
    final kind = tokens[i].kind;
    if (kind == TokenKind.newline ||
        kind == TokenKind.indent ||
        kind == TokenKind.dedent) {
      lineHead = i + 1;
      continue;
    }
    if (kind != TokenKind.less || i == 0) continue;
    final prev = tokens[i - 1];
    if (prev.kind != TokenKind.identifier ||
        _nonValueKeywords.contains(prev.lexeme)) {
      continue;
    }
    final isExtendLine = lineHead < tokens.length &&
        tokens[lineHead].kind == TokenKind.identifier &&
        tokens[lineHead].lexeme == 'extend';
    final openStack = <int>[i];
    final candidate = <Token>[tokens[i]];
    var valid = true;
    var end = -1;
    for (var j = i + 1; j < tokens.length && openStack.isNotEmpty; j++) {
      final tok = tokens[j];
      if (tok.kind == TokenKind.less) {
        openStack.add(j);
        candidate.add(tok);
      } else if (tok.kind == TokenKind.greater) {
        openStack.removeLast();
        candidate.add(tok);
        if (openStack.isEmpty) end = j;
      } else if (tok.kind == TokenKind.shiftRight && openStack.length >= 2) {
        openStack.removeLast();
        openStack.removeLast();
        candidate.add(tok);
        if (openStack.isEmpty) end = j;
      } else if (tok.kind == TokenKind.unsignedShiftRight &&
          openStack.length >= 3) {
        openStack.removeLast();
        openStack.removeLast();
        openStack.removeLast();
        candidate.add(tok);
        if (openStack.isEmpty) end = j;
      } else if (tok.kind == TokenKind.identifier &&
          !_genericDisallowedKeywords.contains(tok.lexeme)) {
        continue;
      } else if (tok.kind == TokenKind.comma ||
          tok.kind == TokenKind.question ||
          tok.kind == TokenKind.colon ||
          tok.kind == TokenKind.dot ||
          tok.kind == TokenKind.pipe ||
          tok.kind == TokenKind.leftParen ||
          tok.kind == TokenKind.rightParen ||
          tok.kind == TokenKind.arrow) {
        continue;
      } else {
        valid = false;
        break;
      }
    }
    if (!valid || end < 0) continue;
    if (end + 1 < tokens.length) {
      final after = tokens[end + 1];
      final allowedAfter = after.kind == TokenKind.newline ||
          after.kind == TokenKind.eof ||
          after.kind == TokenKind.dedent ||
          after.kind == TokenKind.leftParen ||
          after.kind == TokenKind.leftBracket ||
          after.kind == TokenKind.rightParen ||
          after.kind == TokenKind.rightBracket ||
          after.kind == TokenKind.comma ||
          after.kind == TokenKind.colon ||
          after.kind == TokenKind.question ||
          after.kind == TokenKind.dot ||
          after.kind == TokenKind.questionDot ||
          after.kind == TokenKind.equals ||
          after.kind == TokenKind.equalEqual ||
          after.kind == TokenKind.bangEqual ||
          after.kind == TokenKind.arrow ||
          after.kind == TokenKind.pipe ||
          after.kind == TokenKind.greater ||
          after.kind == TokenKind.shiftRight ||
          after.kind == TokenKind.unsignedShiftRight ||
          (after.kind == TokenKind.identifier &&
              (isExtendLine ||
                  const {
                    'is',
                    'as',
                    'in',
                    'and',
                    'or',
                    'then',
                    'else',
                    'where',
                    'when',
                    'implements',
                    'extends',
                    'with',
                    'on',
                    'from',
                  }.contains(after.lexeme)));
      if (!allowedAfter) continue;
    }
    result.addAll(candidate);
  }
  return result;
}

bool _isValueEnding(Token token, Set<Token> genericAngles) {
  switch (token.kind) {
    case TokenKind.identifier:
      return !_nonValueKeywords.contains(token.lexeme);
    case TokenKind.dollar:
    case TokenKind.number:
    case TokenKind.string:
    case TokenKind.rightParen:
    case TokenKind.rightBracket:
    case TokenKind.bang:
    case TokenKind.question:
      return true;
    case TokenKind.greater:
    case TokenKind.shiftRight:
    case TokenKind.unsignedShiftRight:
      return genericAngles.contains(token);
    default:
      return false;
  }
}

bool _isUnarySign(Token? prevPrev, Token prev, Set<Token> genericAngles) {
  if (prev.kind != TokenKind.minus && prev.kind != TokenKind.plus) return false;
  if (prevPrev == null) return true;
  return !_isValueEnding(prevPrev, genericAngles);
}

bool _needsSpace({
  required List<Token> tokens,
  required int index,
  required Token prev,
  required Token? prevPrev,
  required Token curr,
  required List<TokenKind> brackets,
  required Set<Token> genericAngles,
  required Set<int> operatorIndexes,
}) {
  // Operator declaration names: `operator +(`, `operator -()`, `operator []=(`
  if (operatorIndexes.contains(index)) {
    if (prev.kind == TokenKind.identifier && prev.lexeme == 'operator') {
      return true;
    }
    return false;
  }
  if (operatorIndexes.contains(index - 1)) {
    if (curr.kind == TokenKind.leftParen) return false;
    return true;
  }

  // Never space immediately after opening delimiters or tight prefixes.
  if (prev.kind == TokenKind.leftParen ||
      prev.kind == TokenKind.leftBracket ||
      prev.kind == TokenKind.at ||
      prev.kind == TokenKind.tilde ||
      prev.kind == TokenKind.spread ||
      prev.kind == TokenKind.spreadQuestion ||
      prev.kind == TokenKind.dot ||
      prev.kind == TokenKind.questionDot ||
      prev.kind == TokenKind.dotDot ||
      prev.kind == TokenKind.dotDotLess) {
    return false;
  }

  // Prefix null-aware collection element: `[?a, ?b]`
  if (prev.kind == TokenKind.question) {
    final isPrefixNullAware = prevPrev == null ||
        prevPrev.kind == TokenKind.leftBracket ||
        prevPrev.kind == TokenKind.comma;
    if (isPrefixNullAware) return false;
  }

  // Unary +/- attaches directly to its operand (`-1`, `(-x)`, `a + -b`).
  if (_isUnarySign(prevPrev, prev, genericAngles)) {
    return false;
  }

  // Never space before closing delimiters, comma, range operators, or postfix ? / !.
  if (curr.kind == TokenKind.rightParen ||
      curr.kind == TokenKind.rightBracket ||
      curr.kind == TokenKind.comma ||
      curr.kind == TokenKind.dotDot ||
      curr.kind == TokenKind.dotDotLess) {
    return false;
  }

  // `?`: postfix nullable / propagation (`String?`, `x?`) vs prefix null-aware (`[?x, ?y]`).
  if (curr.kind == TokenKind.question) {
    final isPrefixNullAware = prev.kind == TokenKind.comma;
    return isPrefixNullAware;
  }

  // `!`: postfix null-assert (`x!`) or `is!` (`is! int`) -> never space before `!`.
  if (curr.kind == TokenKind.bang) {
    return false;
  }

  // `.` and `?.`: attach tightly after values (`a.b`, `$.iteration`),
  // but keep space before leading-dot shorthand (`= .lf`, `return .crlf`).
  if (curr.kind == TokenKind.dot || curr.kind == TokenKind.questionDot) {
    return !_isValueEnding(prev, genericAngles);
  }

  // Generic `<` / `>` / `>>` / `>>>`.
  if (genericAngles.contains(curr)) {
    return false;
  }
  if (prev.kind == TokenKind.less && genericAngles.contains(prev)) {
    return false;
  }

  // Colon `:` rules.
  if (curr.kind == TokenKind.colon) {
    return false;
  }
  if (prev.kind == TokenKind.colon) {
    // Inside `[...]`, `:` is a slice separator (`a[0:3]`, `a[:3]`, `a[1:]`).
    if (brackets.isNotEmpty && brackets.last == TokenKind.leftBracket) {
      return false;
    }
    return true;
  }

  // `(`: no space after callable/type/operator, space after control/statement keywords & operators.
  if (curr.kind == TokenKind.leftParen) {
    if (prev.kind == TokenKind.identifier &&
        !_spaceBeforeParenKeywords.contains(prev.lexeme)) {
      return false;
    }
    if (prev.kind == TokenKind.rightParen ||
        prev.kind == TokenKind.rightBracket ||
        prev.kind == TokenKind.bang ||
        prev.kind == TokenKind.question ||
        genericAngles.contains(prev)) {
      return false;
    }
    return true;
  }

  // `[`: no space when indexing (`items[0]`, `a[0:2]`), space after keywords/operators.
  if (curr.kind == TokenKind.leftBracket) {
    if (_isValueEnding(prev, genericAngles)) {
      return false;
    }
    return true;
  }

  // Default: single space between all other adjacent tokens (operators, keywords,
  // identifiers, literals, after comma, after `is!`, after `>` generic before `=`, etc.).
  return true;
}

class _BlockCommentScan {
  const _BlockCommentScan(this.depth, this.sawComment);
  final int depth;
  final bool sawComment;
}

_BlockCommentScan _scanLineBlockComments(String line, int startDepth) {
  var depth = startDepth;
  var saw = startDepth > 0;
  var quote = '';
  for (var i = 0; i < line.length; i++) {
    if (depth > 0) {
      if (line.startsWith('/*', i)) {
        depth++;
        i++;
      } else if (line.startsWith('*/', i)) {
        depth--;
        i++;
      }
      continue;
    }
    if (quote.isNotEmpty) {
      if (line.startsWith(quote, i)) {
        i += quote.length - 1;
        quote = '';
      } else if (quote.length == 1 && line[i] == '\\') {
        i++;
      }
      continue;
    }
    if (line.startsWith('"""', i) || line.startsWith("'''", i)) {
      quote = line.substring(i, i + 3);
      i += 2;
      continue;
    }
    if (line[i] == '"' || line[i] == "'") {
      quote = line[i];
      continue;
    }
    if (line[i] == '#' || line.startsWith('//', i)) break;
    if (line.startsWith('/*', i)) {
      depth++;
      saw = true;
      i++;
    }
  }
  return _BlockCommentScan(depth, saw);
}

List<String> _wrapLine(String line, int width, {bool pending = false}) {
  if (line.length <= width) return [line];
  final content = line.trimLeft();
  if (content.startsWith('#') || content.startsWith('///')) return [line];
  final indent = line.length - content.length;
  final split = _wrapAt(content, width - indent, pending: pending);
  if (split == null) return [line];
  return [
    '${' ' * indent}${split.left}',
    ..._wrapLine('${' ' * indent}${split.right}', width,
        pending: split.pending),
  ];
}

List<String> _collapseIfs(List<String> lines, int indent, int width) {
  var current = lines;
  var changed = true;
  while (changed) {
    changed = false;
    final next = <String>[];
    var open = '';
    var i = 0;
    while (i < current.length) {
      final line = current[i];
      if (open.isNotEmpty) {
        next.add(line);
        open = _advanceQuotes(line, open);
        i++;
        continue;
      }
      final body = i + 1 < current.length ? current[i + 1] : null;
      final after = i + 2 < current.length ? current[i + 2] : null;
      if (body != null &&
          open.isEmpty &&
          _advanceQuotes(line, '') == '' &&
          _canJoinIf(line, body, after, indent, width)) {
        next.add('${line.trimRight()} ${body.trimLeft()}');
        open = _advanceQuotes(body, '');
        changed = true;
        i += 2;
        continue;
      }
      next.add(line);
      open = _advanceQuotes(line, '');
      i++;
    }
    current = next;
  }
  return current;
}

bool _canJoinIf(
    String header, String body, String? after, int indent, int width) {
  final head = header.trimLeft();
  if (!head.endsWith(':')) return false;
  if (!head.startsWith('if ') &&
      !head.startsWith('else if ') &&
      head != 'else:') {
    return false;
  }
  final statement = body.trimLeft();
  if (statement.isEmpty || statement.startsWith('#')) return false;
  if (statement.endsWith(':')) return false;
  final headerIndent = header.length - head.length;
  final bodyIndent = body.length - statement.length;
  if (bodyIndent != headerIndent + indent) return false;
  if (_unclosed(body)) return false;
  if (after != null && after.trim().isNotEmpty) {
    final afterIndent = after.length - after.trimLeft().length;
    if (afterIndent > headerIndent) return false;
  }
  return '${header.trimRight()} $statement'.length <= width;
}

bool _unclosed(String text) {
  var quote = '';
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    if (quote.isNotEmpty) {
      if (text.startsWith(quote, i)) {
        i += quote.length - 1;
        quote = '';
      } else if (quote.length == 1 && text[i] == '\\') {
        i++;
      }
      continue;
    }
    if (text.startsWith('"""', i) || text.startsWith("'''", i)) {
      quote = text.substring(i, i + 3);
      i += 2;
      continue;
    }
    final char = text[i];
    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }
    if (char == '#') break;
    if (char == '(' || char == '[') {
      depth++;
    } else if ((char == ')' || char == ']') && depth > 0) {
      depth--;
    }
  }
  return depth > 0 || quote.isNotEmpty;
}

/// A comma splits only inside `()` or `[]`, and the next line keeps the same
/// indent so the lexer does not open a block.
_Split? _wrapAt(String text, int budget, {required bool pending}) {
  if (budget <= 0) return null;
  var quote = '';
  var depth = pending ? 1 : 0;
  var last = -1;
  var lastDepth = 0;
  for (var i = 0; i < text.length && i < budget; i++) {
    if (quote.isNotEmpty) {
      if (text.startsWith(quote, i)) {
        i += quote.length - 1;
        quote = '';
      } else if (quote.length == 1 && text[i] == '\\') {
        i++;
      }
      continue;
    }
    if (text.startsWith('"""', i) || text.startsWith("'''", i)) {
      quote = text.substring(i, i + 3);
      i += 2;
      continue;
    }
    final char = text[i];
    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }
    if (char == '#') break;
    if (char == '(' || char == '[') {
      depth++;
    } else if ((char == ')' || char == ']') && depth > 0) {
      depth--;
    } else if (char == ',' && depth > 0) {
      last = i;
      lastDepth = depth;
    }
  }
  if (last < 0 || last + 1 >= text.length) return null;
  final rest = text.substring(last + 1).trimLeft();
  if (rest.isEmpty) return null;
  return _Split(text.substring(0, last + 1), rest, lastDepth > 0);
}

class _Split {
  const _Split(this.left, this.right, this.pending);
  final String left;
  final String right;
  final bool pending;
}

String _advanceQuotes(String line, String open) {
  var current = open;
  var i = 0;
  while (i < line.length) {
    if (current.isNotEmpty) {
      if (line.startsWith(current, i)) {
        current = '';
        i += 3;
        continue;
      }
      i++;
      continue;
    }
    if (line.startsWith('"""', i) || line.startsWith("'''", i)) {
      current = line.substring(i, i + 3);
      i += 3;
      continue;
    }
    final quote = line[i];
    if (quote == '"' || quote == "'") {
      i++;
      while (i < line.length && line[i] != quote) {
        if (line[i] == '\\' && i + 1 < line.length) {
          i += 2;
          continue;
        }
        i++;
      }
      if (i < line.length) i++;
      continue;
    }
    i++;
  }
  return current;
}
