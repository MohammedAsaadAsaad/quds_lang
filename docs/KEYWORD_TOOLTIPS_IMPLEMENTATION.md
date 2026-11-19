# English keyword tooltips: implementation and handoff

## Delivered behavior

[KEYWORD_REFERENCE.md](KEYWORD_REFERENCE.md) is the English reference, prepared
before the editor implementation. Its 111 entries cover all `word(...)` spellings
in the parser, class modifiers, and documented contextual forms such as `capture`,
`nameof`, `lazy`, `cast`, `to?` and `with?`. Each has prose and a Quds example.
Examples are grammar fragments, not 111 independent runnable programs.

Hover and keyword/snippet completion use the same Markdown. There is no new
language syntax or changed conversion resolution. Existing SDK/symbol hover is
preserved. In particular, ordinary identifiers named `value`, `get`, `map`, `set`
and `once` are not automatically treated as language keywords.

The `deferred` entry documents a prefixed import and `prefix.loadLibrary()`.
Do not infer that every import combinator is certified from the presence of a
help entry. Context recognition is conservative for
ambiguous/incomplete contextual syntax; normal symbol hover is the fallback.

## Data flow

1. Edit the English entries under the level-two keyword headings in
   `docs/KEYWORD_REFERENCE.md`.
2. Run `python3 tool/sync_keyword_docs.py`, then `dart format .`.
3. The generator embeds the exact Markdown in
   `lib/src/keyword_docs_data.dart`. No runtime documentation file, network call,
   SDK lookup or compilation is needed to read a keyword entry.
4. `complete.dart` attaches LSP Markdown documentation to keyword and snippet
   entries. `keywordHoverAt` checks lexical code position and contextual syntax,
   returning a UTF-16 range and the same documentation.
5. `protocol.dart` tries keyword help before symbol analysis. Existing symbol
   and Dart-location fallbacks remain intact.
6. The VS Code adapter preserves MarkupContent in CompletionItem.documentation
   using an untrusted MarkdownString. Hover already renders Markdown.

Keyword lookup scans the prefix for string/comment state, so it is linear in the
cursor offset, not a claim of constant-time parsing. A 15,000-line incomplete
buffer is covered without a compiler callback. The shared scanner also now checks
that the current character actually matches the quote when closing a triple
string; help and completion resume correctly after ordinary/raw triple strings.

## Validation coverage

`test/keyword_docs_test.dart` checks catalog synchronization, parser-word coverage,
all reference example grammars, including the deferred import example, identical
completion text, contextual/compound keyword hover, comment/string/member
exclusion, ordinary-symbol LSP fallback, UTF-16 positions, triple strings, invalid
buffers, and a large buffer. Its Node adapter regression checks Markdown and plain
text mapping without enabling trust.

Commands:

```sh
python3 tool/sync_keyword_docs.py --check
dart format .
dart analyze
dart test test/keyword_docs_test.dart --reporter expanded
dart test --reporter expanded
git diff --check
```

Final measured results are recorded in [VALIDATION.md](VALIDATION.md). These checks
exercise LSP and the VS Code adapter in an isolated harness; no manual interactive
VS Code session is claimed. Reinstall/update the extension and reload its window
to use the new completion rendering.
