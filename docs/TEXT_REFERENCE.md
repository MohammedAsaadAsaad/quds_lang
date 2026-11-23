# `quds:text` API Reference

General-purpose text library for Quds, implemented in `lib/sdk/text.quds` and embedded in `lib/src/sdk.dart`.

## Imports and Sections

Import the whole library or individual sections:

```quds
use quds:text
use quds:text as text
use quds:text::types show TextRange, TextSpan
use quds:text::builder show TextBuilder
use quds:text::split as split
use quds:text::extensions
```

All 17 public sections:

| Section | Purpose |
| --- | --- |
| `:: types` | `TextBoundaryPolicy`, `TextRange`, `TextSpan`, `TextPosition`, `validateTextRange`, `intersectTextRanges`, `textPositionAt`, `textOffsetAt` |
| `:: unicode` | `unicodeVersion`, `TextNormalizationForm`, `TextCodePoints`, `TextCharacters`, `TextNormalizer`, `normalizeUnicode`, `isNormalizedUnicode`, `caseFoldText`, `reverseCharacters` |
| `:: inspect` | `isBlankText`, `hasText`, `blankTextToNull`, `containsOnlyCharacters`, `hasLineBreak`, `isWellFormedUnicode` |
| `:: slice` | `sliceText`, `sliceCharacters`, `beforeText`, `afterText`, `beforeLastText`, `afterLastText`, `betweenText`, `textWindows` |
| `:: patterns` | `TextPatternError`, `TextPattern` (`literal`, `regex`, `hasMatch`, `compiledRegExp`) |
| `:: search` | `TextSearchOptions`, `TextMatch`, `findText`, `findLastText`, `findAllText`, `countTextMatches`, `containsTextPattern` |
| `:: split` | `TextSplitOptions`, `TextPartition`, `splitText`, `splitTextAny`, `splitTextPattern`, `splitTextOnce`, `splitTextLastOnce`, `textSegments` |
| `:: replace` | `replaceFirstText`, `replaceLastText`, `replaceAllText`, `replaceTextMatches`, `removeTextMatches`, `removeTextPrefix`, `removeTextSuffix`, `removeTextSurrounding`, `collapseRepeatedCharacters` |
| `:: compose` | `joinText`, `joinNonBlankText`, `repeatText`, `surroundText`, `ensureTextPrefix`, `ensureTextSuffix`, `interleaveText` |
| `:: format` | `TextAlignment`, `TextWrapOptions`, `alignText`, `truncateText`, `wrapText`, `wrapTextJoined` |
| `:: builder` | `TextBuilder` (`append`, `appendLine`, `appendAll`, `appendJoined`, `appendCodePoint`, `utf16Length`, `isEmpty`, `isNotEmpty`, `build`, `clear`) |
| `:: lines` | `TextLineEnding`, `TextLine`, `TextLines`, `splitTextLines`, `joinTextLines`, `normalizeLineEndings`, `indentText`, `dedentText`, `trimBlankLines` |
| `:: reader` | `TextParseError`, `TextReader` (`position`, `remaining`, `isAtEnd`, `savePosition`, `restorePosition`, `peekCharacter`, `readCharacter`, `readUntil`, `readWhile`, `skipWhitespace`, `expectText`, `tryReadText`, `readQuoted`, `tryReadInt`, `readInt`, `tryReadDouble`, `readDouble`) |
| `:: compare` | `TextComparisonOptions`, `compareText`, `equalsText`, `compareTextNaturally`, `commonTextPrefix`, `commonTextSuffix`, `editDistance`, `boundedEditDistance`, `textSimilarity` |
| `:: escape` | `escapeTextLiteral`, `unescapeTextLiteral`, `quoteTextLiteral`, `unquoteTextLiteral`, `escapeRegexLiteral` |
| `:: encoding` | `TextEncoding`, `TextBom`, `TextEncodingError`, `detectTextBom`, `encodeText`, `decodeText` |
| `:: extensions` | `extend String Text` (migrated from `quds:ext`) and `extend String TextStringExtensions` |

## Text Units & Guarantees

- **UTF-16 code units:** `TextRange` (`[start, end)` half-open), `TextSpan`, `TextPosition` (0-based `offset`, 1-based `line` and UTF-16 `column`, CRLF counts as one break), `TextReader.position`, and `TextMatch.range`.
- **Unicode code points:** `TextCodePoints` with explicit `strict` / `replaceMalformed` policies for unpaired UTF-16 surrogates.
- **Grapheme clusters (UAX #29):** `TextCharacters`, `sliceCharacters`, `reverseCharacters`, `containsOnlyCharacters`, `collapseRepeatedCharacters`, `alignText`, `truncateText`, `wrapText`, `commonTextPrefix`, `commonTextSuffix`, `editDistance`, `boundedEditDistance`, and `textSimilarity`.
- **Pinned Unicode version:** Unicode **15.0.0** (generated deterministically via `tool/generate_text_unicode.py` from Python's `unicodedata`), supporting full UAX #15 normalization (`NFC`, `NFD`, `NFKC`, `NFKD`), canonical combining order, Hangul algorithmic syllables, full Unicode case folding, and UAX #29 extended grapheme clusters across both Dart VM and JavaScript.
- **Bytes:** `:: encoding` validates every byte is within `0..255`, defaults to strict UTF-8, never strips a BOM unless `stripBom: true` is passed, and reports `TextEncodingError` with exact offset and unit (`"byte"` or `"codeUnit"`).
- **Work limits:** `editDistance` and `boundedEditDistance` enforce a `2,000,000`-cell quadratic guard and use O(min(m, n)) rolling-row memory.

## Migration from `quds:ext`

`extend String Text` (`blank`, `capitalized`, `reversed`, `count`, `removePrefix`, `removeSuffix`, `before`, `after`, `repeated`, `words`, `truncate`, `quoted`) has been moved from `quds:ext` to `quds:text::extensions` without a re-export or compatibility alias in `quds:ext`. `quds:ext` retains extensions for `List`, `Map`, `Set`, `int`, and `double`.

## Test Suites

- `test/text_core.quds` — `types`, `inspect`, `slice`, literal `split`, `compose`, `builder`, `lines`, and migrated `Text` baseline
- `test/text_imports.quds` — section imports, prefixes, `show`, and `quds:ext` coexistence
- `test/text_unicode.quds` — `TextCodePoints`, `TextCharacters`, `TextNormalizer`, `sliceCharacters`, `boundaryOffset`, malformed surrogates
- `test/text_unicode_reference.quds` — 980 independent Unicode 15.0.0 reference checks (NFC, NFD, NFKC, NFKD, idempotence, full case folding)
- `test/text_patterns_search.quds` — `TextPattern`, `TextPatternError`, `TextMatch`, groups/named groups, overlap, zero-length matches, `splitTextPattern`
- `test/text_replace_reader.quds` — literal replacements, left-to-right callbacks, grapheme collapsing, `TextReader` checkpoints and rollback
- `test/text_format_compare.quds` — alignment, truncation, wrapping, natural ordering, grapheme prefix/suffix, edit distance, similarity
- `test/text_escape_encoding.quds` — literal escape/quote round-trips, regex escaping, UTF-8/UTF-16 LE/UTF-16 BE/ASCII/Latin-1, BOMs, malformed input
- `test/text_extensions.quds` & `test/text_reject_ext_string.quds` — `Text` + `TextStringExtensions` and negative verification that `quds:ext` alone no longer exposes `Text`
- `test/text_web.quds` & `test/text_sdk_test.dart` — Quds runner, strict `dart analyze --fatal-infos`, Dart VM + Node.js JS parity, golden check (`test/goldens/text_slice.dart.txt`), and LSP completion/definition checks
