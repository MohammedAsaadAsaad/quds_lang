/// Resilient Quds syntax & semantic highlighter producing UTF-16 offset spans.
///
/// Handles incomplete/in-progress code gracefully without crashing, highlights
/// comments, doc comments, `:: section` headers, string interpolations `{...}`,
/// annotations, types, functions, properties, keywords, durations, and errors.
/// Zero `dart:io` imports.
library;

import 'models.dart';

const _controlKeywords = <String>{
  'if',
  'else',
  'guard',
  'for',
  'in',
  'while',
  'repeat',
  'step',
  'break',
  'continue',
  'label',
  'return',
  'do',
  'result',
  'match',
  'when',
  'try',
  'catch',
  'finally',
  'throw',
  'rethrow',
  'defer',
  'using',
  'await',
  'all',
  'isolate',
  'retry',
  'timeout',
  'where',
  'and',
  'or',
  'not',
  'is',
  'as',
  'to',
  'with',
  'yield',
  'require',
  'check',
  'assert',
  'raise',
  'lock',
  'watch',
  'batch',
  'once',
  'test',
  'capture',
};

const _declarationKeywords = <String>{
  'var',
  'const',
  'shadow',
  'late',
  'state',
  'computed',
  'class',
  'value',
  'sealed',
  'enum',
  'abstract',
  'base',
  'interface',
  'final',
  'mixin',
  'singleton',
  'extends',
  'implements',
  'extend',
  'on',
  'type',
  'use',
  'export',
  'part',
  'show',
  'hide',
  'deferred',
  'async',
  'sync',
  'operator',
  'factory',
  'get',
  'set',
  'by',
  'lazy',
  'private',
  'protected',
  'internal',
  'static',
  'required',
  'readonly',
  'event',
  'annotation',
  'config',
  'secret',
};

const _literalKeywords = <String>{
  'true',
  'false',
  'null',
  'missing',
  'this',
  'super',
};

const _builtinTypes = <String>{
  'int',
  'double',
  'num',
  'bool',
  'String',
  'void',
  'dynamic',
  'Object',
  'Never',
  'List',
  'Map',
  'Set',
  'Iterable',
  'Future',
  'Stream',
  'Duration',
  'DateTime',
  'BigInt',
  'RegExp',
  'Result',
  'Optional',
  'Array',
  'Dict',
  'HashSet',
  'Range',
  'Function',
};

const _builtinFunctions = <String>{
  'print',
  'range',
  'min',
  'max',
  'Ok',
  'Error',
  'present',
  'identical',
  'nameof',
};

/// Tokenizes [source] into ordered, non-overlapping [QudsHighlightSpan]s
/// suitable for direct rendering in Flutter or Web code editors.
List<QudsHighlightSpan> highlightQudsSource(String source) {
  final spans = <QudsHighlightSpan>[];
  final n = source.length;
  var i = 0;
  var line = 1;
  var col = 1;
  var lineStart = true;
  QudsTokenCategory? prevCategory;
  String? prevLexeme;

  void add(int start, int end, int startLine, int startCol,
      QudsTokenCategory category) {
    if (end <= start) return;
    final text = source.substring(start, end);
    spans.add(QudsHighlightSpan(
      startOffset: start,
      endOffset: end,
      line: startLine,
      column: startCol,
      category: category,
      text: text,
    ));
    prevCategory = category;
    prevLexeme = text;
  }

  bool isIdentStart(int c) =>
      (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      c == 95 ||
      c >= 0x80; // Unicode identifiers

  bool isIdentPart(int c) => isIdentStart(c) || (c >= 48 && c <= 57);

  bool isDigit(int c) => c >= 48 && c <= 57;

  while (i < n) {
    final start = i;
    final startLine = line;
    final startCol = col;
    final ch = source.codeUnitAt(i);

    // Newline
    if (ch == 10) {
      i++;
      line++;
      col = 1;
      lineStart = true;
      continue;
    }
    if (ch == 13) {
      i++;
      continue;
    }

    // Whitespace
    if (ch == 32 || ch == 9) {
      i++;
      col++;
      continue;
    }

    // Column-0 `:: section` header
    if (lineStart && ch == 58 && i + 1 < n && source.codeUnitAt(i + 1) == 58) {
      while (
          i < n && source.codeUnitAt(i) != 10 && source.codeUnitAt(i) != 13) {
        if (source.codeUnitAt(i) == 35) break; // stop before trailing # comment
        i++;
        col++;
      }
      add(start, i, startLine, startCol, QudsTokenCategory.sectionHeader);
      lineStart = false;
      continue;
    }

    lineStart = false;

    // `#` line comment or `///` doc comment
    if (ch == 35 ||
        (ch == 47 &&
            i + 2 < n &&
            source.codeUnitAt(i + 1) == 47 &&
            source.codeUnitAt(i + 2) == 47)) {
      final isDoc = ch == 47;
      while (
          i < n && source.codeUnitAt(i) != 10 && source.codeUnitAt(i) != 13) {
        i++;
        col++;
      }
      add(
        start,
        i,
        startLine,
        startCol,
        isDoc ? QudsTokenCategory.docComment : QudsTokenCategory.comment,
      );
      continue;
    }

    // Block comment `/* ... */`
    if (ch == 47 && i + 1 < n && source.codeUnitAt(i + 1) == 42) {
      i += 2;
      col += 2;
      var depth = 1;
      while (i < n && depth > 0) {
        if (source.codeUnitAt(i) == 10) {
          line++;
          col = 1;
          i++;
          continue;
        }
        if (source.codeUnitAt(i) == 47 &&
            i + 1 < n &&
            source.codeUnitAt(i + 1) == 42) {
          depth++;
          i += 2;
          col += 2;
          continue;
        }
        if (source.codeUnitAt(i) == 42 &&
            i + 1 < n &&
            source.codeUnitAt(i + 1) == 47) {
          depth--;
          i += 2;
          col += 2;
          continue;
        }
        i++;
        col++;
      }
      add(
        start,
        i,
        startLine,
        startCol,
        depth == 0 ? QudsTokenCategory.comment : QudsTokenCategory.error,
      );
      continue;
    }

    // Annotation `@Name`
    if (ch == 64) {
      i++;
      col++;
      while (i < n && isIdentPart(source.codeUnitAt(i))) {
        i++;
        col++;
      }
      add(start, i, startLine, startCol, QudsTokenCategory.annotation);
      continue;
    }

    // Loop context `$`
    if (ch == 36) {
      i++;
      col++;
      add(start, i, startLine, startCol, QudsTokenCategory.builtin);
      continue;
    }

    // String literals (single/double/triple + raw `r"..."`) with `{...}` interpolation spans
    final isRawPrefix = (ch == 114) &&
        i + 1 < n &&
        (source.codeUnitAt(i + 1) == 34 || source.codeUnitAt(i + 1) == 39);
    if (ch == 34 || ch == 39 || isRawPrefix) {
      final isRaw = isRawPrefix;
      if (isRaw) {
        i++;
        col++;
      }
      final quote = source.codeUnitAt(i);
      final isTriple = i + 2 < n &&
          source.codeUnitAt(i + 1) == quote &&
          source.codeUnitAt(i + 2) == quote;
      final openLen = isTriple ? 3 : 1;
      i += openLen;
      col += openLen;

      var segStart = start;
      var segLine = startLine;
      var segCol = startCol;
      var closed = false;

      while (i < n) {
        final c = source.codeUnitAt(i);
        if (c == 10) {
          if (!isTriple) break;
          i++;
          line++;
          col = 1;
          continue;
        }
        if (!isRaw && c == 92 && i + 1 < n) {
          i += 2;
          col += 2;
          continue;
        }
        if (isTriple) {
          if (c == quote &&
              i + 2 < n &&
              source.codeUnitAt(i + 1) == quote &&
              source.codeUnitAt(i + 2) == quote) {
            i += 3;
            col += 3;
            closed = true;
            break;
          }
        } else if (c == quote) {
          i++;
          col++;
          closed = true;
          break;
        }

        // String interpolation `{expr}` inside non-raw strings
        if (!isRaw && c == 123) {
          if (i > segStart) {
            add(segStart, i, segLine, segCol, QudsTokenCategory.string);
          }
          final interpStart = i;
          final interpLine = line;
          final interpCol = col;
          var braceDepth = 1;
          i++;
          col++;
          while (i < n && braceDepth > 0) {
            final ic = source.codeUnitAt(i);
            if (ic == 10 && !isTriple) break;
            if (ic == 10) {
              line++;
              col = 1;
              i++;
              continue;
            }
            if (ic == 123) braceDepth++;
            if (ic == 125) braceDepth--;
            i++;
            col++;
          }
          add(
            interpStart,
            i,
            interpLine,
            interpCol,
            braceDepth == 0
                ? QudsTokenCategory.interpolation
                : QudsTokenCategory.error,
          );
          segStart = i;
          segLine = line;
          segCol = col;
          continue;
        }

        i++;
        col++;
      }

      if (i > segStart) {
        add(
          segStart,
          i,
          segLine,
          segCol,
          closed ? QudsTokenCategory.string : QudsTokenCategory.error,
        );
      }
      continue;
    }

    // Numbers & Duration literals (`500ms`, `2s`, `1.5m`, `0xFF`, `1_000`)
    if (isDigit(ch)) {
      if (ch == 48 &&
          i + 1 < n &&
          (source.codeUnitAt(i + 1) == 120 || source.codeUnitAt(i + 1) == 88)) {
        i += 2;
        col += 2;
        while (i < n && RegExp(r'[0-9a-fA-F_]').hasMatch(source[i])) {
          i++;
          col++;
        }
        add(start, i, startLine, startCol, QudsTokenCategory.number);
        continue;
      }
      while (i < n &&
          (isDigit(source.codeUnitAt(i)) || source.codeUnitAt(i) == 95)) {
        i++;
        col++;
      }
      if (i + 1 < n &&
          source.codeUnitAt(i) == 46 &&
          isDigit(source.codeUnitAt(i + 1))) {
        i++;
        col++;
        while (i < n &&
            (isDigit(source.codeUnitAt(i)) || source.codeUnitAt(i) == 95)) {
          i++;
          col++;
        }
      }
      if (i < n &&
          (source.codeUnitAt(i) == 101 || source.codeUnitAt(i) == 69)) {
        i++;
        col++;
        if (i < n &&
            (source.codeUnitAt(i) == 43 || source.codeUnitAt(i) == 45)) {
          i++;
          col++;
        }
        while (i < n && isDigit(source.codeUnitAt(i))) {
          i++;
          col++;
        }
      }
      // Optional duration suffix (`us`, `ms`, `s`, `m`, `h`, `d`)
      final suffixStart = i;
      while (i < n &&
          ((source.codeUnitAt(i) >= 97 && source.codeUnitAt(i) <= 122) ||
              (source.codeUnitAt(i) >= 65 && source.codeUnitAt(i) <= 90))) {
        i++;
        col++;
      }
      if (i > suffixStart) {
        final suffix = source.substring(suffixStart, i);
        final isDuration =
            const {'us', 'ms', 's', 'm', 'h', 'd'}.contains(suffix);
        add(
          start,
          i,
          startLine,
          startCol,
          isDuration ? QudsTokenCategory.duration : QudsTokenCategory.error,
        );
      } else {
        add(start, i, startLine, startCol, QudsTokenCategory.number);
      }
      continue;
    }

    // Identifiers, keywords, types, functions, members
    if (isIdentStart(ch)) {
      while (i < n && isIdentPart(source.codeUnitAt(i))) {
        i++;
        col++;
      }
      // Handle `to?` and `with?`
      if (i < n && source.codeUnitAt(i) == 63) {
        final word = source.substring(start, i);
        if (word == 'to' || word == 'with') {
          i++;
          col++;
          add(start, i, startLine, startCol, QudsTokenCategory.controlKeyword);
          continue;
        }
      }
      final word = source.substring(start, i);

      // Peek next non-space char to detect calls `foo(`
      var peekIdx = i;
      while (peekIdx < n && source.codeUnitAt(peekIdx) == 32) {
        peekIdx++;
      }
      final nextChar = peekIdx < n ? source.codeUnitAt(peekIdx) : -1;
      final followedByParen = nextChar == 40; // '('

      QudsTokenCategory category;
      if (_controlKeywords.contains(word)) {
        category = QudsTokenCategory.controlKeyword;
      } else if (_declarationKeywords.contains(word)) {
        category = QudsTokenCategory.declarationKeyword;
      } else if (_literalKeywords.contains(word)) {
        category = QudsTokenCategory.literalKeyword;
      } else if (prevLexeme == '.' || prevLexeme == '?.') {
        category = followedByParen
            ? QudsTokenCategory.methodName
            : QudsTokenCategory.property;
      } else if (_builtinTypes.contains(word) ||
          (word.isNotEmpty &&
              word.codeUnitAt(0) >= 65 &&
              word.codeUnitAt(0) <= 90 &&
              !_builtinFunctions.contains(word))) {
        category = QudsTokenCategory.typeName;
      } else if (_builtinFunctions.contains(word)) {
        category = QudsTokenCategory.builtin;
      } else if (followedByParen) {
        category = QudsTokenCategory.functionName;
      } else if (prevCategory == QudsTokenCategory.declarationKeyword &&
          (prevLexeme == 'class' ||
              prevLexeme == 'enum' ||
              prevLexeme == 'interface' ||
              prevLexeme == 'type')) {
        category = QudsTokenCategory.typeName;
      } else {
        category = QudsTokenCategory.variable;
      }

      add(start, i, startLine, startCol, category);
      continue;
    }

    // Multi-character operators & punctuation
    final rest = source.substring(i, i + 3 < n ? i + 3 : n);
    String? matchedOp;
    for (final op in const [
      '>>>',
      '??=',
      '..<',
      '...?',
      '...',
      '->',
      '|>',
      '==',
      '!=',
      '<=',
      '>=',
      '+=',
      '-=',
      '*=',
      '/=',
      '~/',
      '??',
      '?.',
      '..',
      '<<',
      '>>',
      '**',
    ]) {
      if (source.startsWith(op, i)) {
        matchedOp = op;
        break;
      }
    }
    if (matchedOp != null) {
      i += matchedOp.length;
      col += matchedOp.length;
      add(start, i, startLine, startCol, QudsTokenCategory.operator);
      continue;
    }

    // Single-character punctuation / operators
    final single = rest[0];
    i++;
    col++;
    if (const {'(', ')', '[', ']', '{', '}', ':', ',', '.'}.contains(single)) {
      add(start, i, startLine, startCol, QudsTokenCategory.punctuation);
    } else if (const {
      '+',
      '-',
      '*',
      '/',
      '%',
      '=',
      '<',
      '>',
      '!',
      '?',
      '&',
      '|',
      '^',
      '~',
    }.contains(single)) {
      add(start, i, startLine, startCol, QudsTokenCategory.operator);
    } else {
      add(start, i, startLine, startCol, QudsTokenCategory.error);
    }
  }

  return spans;
}
