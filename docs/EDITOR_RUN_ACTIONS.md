# Missing Run / Debug / Profile actions in Quds files

The editor actions are CodeLens commands located above `main()`. They do not
appear above every widget `build()` method. Editor settings must allow CodeLens
(`editor.codeLens: true`).

## Defects corrected

Previously the language server obtained these actions from a successfully typed
compilation. In a live editor the first request could arrive before the background
analyzer populated its cache, or package/type errors could prevent compilation.
The editor then received an empty list. Its provider also lacked a refresh event
for completed analysis. This incorrectly made launch controls depend on semantic
analysis readiness rather than the presence of a syntactic entry point.

Actions now use the current buffer's lexer/parser in recovery mode without
resolving imports or type checking. They appear immediately for the Academy
entry point, including when dependencies are unresolved or unrelated statements
are invalid. Full diagnostics continue independently; this does not hide errors
or guarantee that an invalid program can execute. Lexically unreadable buffers
can still prevent the syntax pass from finding an entry point.

The VS Code provider is refreshed with analysis updates and discards CodeLens
responses for obsolete document versions.

## Compiler selection and stale diagnostics

An app can be built by a current checkout while the editor uses an older global
`quds lsp`. Another mismatch came from starting a stale compiled server while
rebuilding its replacement in the background. Both can yield parser errors for
syntax supported by the actual build compiler.

The extension now prefers the active document's compiler context. In an external
project it can resolve `quds_lang` through `.dart_tool/package_config.json`,
including relative file URIs and paths with spaces/Unicode. The same discovery
is used for launching tools. Fresh compiled executables remain fast; when the
executable is stale, the server starts from current Dart sources and rebuilds
in the background. An explicit `quds.serverCommand` setting still overrides
selection; update or remove a setting that points at an old compiler.

The screenshot's exact installed compiler version cannot be established from
an image. The current Academy source has been parsed with the current repository
lexer/parser and produces **no E100 errors**. This is a parser validation, not
a claim that every project has resolved its Flutter dependencies.

## Update an existing installation

From the latest compiler checkout:

```sh
git pull
dart pub get
dart pub global activate --source path .
quds install
```

In the Flutter app, run `flutter pub get` if its package resolution is missing or
outdated. Then run **Developer: Reload Window** in VS Code so the installed
extension code is reloaded. **Quds: Restart Language Server** alone restarts the
server but does not reload old extension JavaScript. Inspect **Output → Quds**
for the selected server command, and check any explicit `quds.serverCommand`.
Scroll to `main()` near the beginning of the Academy source to see its actions.

An immediate explicit source selection is possible in VS Code settings:

```json
{
  "quds.serverCommand": ["dart", "run", "/absolute/path/to/quds_lang/bin/quds.dart", "lsp"]
}
```

Replace the path with the current checkout. Reinstall the updated extension to
receive the new compiler discovery and CodeLens behavior as well.

## Tests

`test/editor_actions_test.dart` checks actual Academy parsing, immediate live
CodeLens availability, missing imports/type errors, unrelated syntax errors,
entry removal and unopened files. Its Node fixture additionally checks project
compiler selection, encoded paths, stale/fresh binaries, invalid package configs
and late responses after buffer edits. Existing editor suites and full compiler
results are recorded in `docs/VALIDATION.md`.
