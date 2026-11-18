# Quds for VS Code

Highlights `.quds` files, formats the open buffer, and shows compiler diagnostics. A `.quds` file uses the Quds mark in the explorer, the same way a Dart file uses the Dart mark. `#region Title` folds through `#end region`, and the title stays on the collapsed line. Enter on a blank line stays at that column. Enter after a line that ends with `:` indents to the start of the body. Hovering a name or expression shows its type. F12 and Ctrl+click open its declaration in the `.quds` file. Above `main`, Run, Debug, and Profile start the program, stop on a breakpoint in the `.quds` file, and benchmark it. F5 debugs the open file from `main`.

The extension starts the compiled `quds lsp` binary when one is already built for this package, and rebuilds that binary in the background when its sources are newer. Until the first binary exists it starts `dart run bin/quds.dart lsp`. Outside this package it starts `quds lsp`. It walks up from the file when no folder is open. On Linux and macOS it also checks `~/.pub-cache/bin/quds` when that directory is not on `PATH`. On Windows it checks `%LOCALAPPDATA%\Pub\Cache\bin` for `quds.bat`, and `PATH` is split on `;`. It looks for `dart` on `PATH` and in the usual Flutter install locations. Set `quds.serverCommand` to replace that, for example `["dart", "run", "/path/to/bin/quds.dart", "lsp"]`.

On Linux, `bash install.sh` from the repository root installs Dart if needed, activates the `quds` command, and installs this extension. After `quds` is on `PATH`, `quds install` does that editor step on Linux, macOS, and Windows, including the other VS Code-family editors it finds, Quds highlighting in Android Studio and other JetBrains IDEs, and a Claude Code skill when Claude Code is installed. You can also install the folder with **Developer: Install Extension from Location**. Then open a `.quds` file and run **Format Document**. **Quds: Restart Language Server** starts the server again.

Saving a `.quds` file formats it. Formatting uses the same rules as `quds format`: indents follow the editor tab size, the line width defaults to 80 and wraps after a comma, and a condition with one statement is written on its header line when it fits. Comments and string contents stay as written. `quds.format.lineWidth` and `quds.format.singleLineIf` change those two choices. A buffer that does not parse is left unchanged. The parse error stays a diagnostic in the Problems list, and saving does not open a format-failure message. Completion answers from the last analysis kept in memory, including after the current line is unfinished. A changed buffer is analyzed in a separate isolate, so the suggestion list does not wait for that analysis. The language server reads the editor buffer, including text that has not been saved. Hover uses that buffer. A mutable binding shows `var name: Type`, a getter/setter shows `property name: Type` (or `get`/`set` when only one side exists), and a function shows `name(parameters) -> Type`. Semantic tokens color those differently: a property or variable is not painted as a function. Another expression shows its type. The three actions above `main` save the file. Run and Profile use a terminal named Quds. Debug builds into `.dart_tool/quds/out/` and stops on breakpoints set in the `.quds` file. Clicking the gutter sets a breakpoint. A blank line stays unverified. Stepping comes from the Dart VM, and the variables pane shows the names written in the `.quds` file. **Quds: Show Generated Dart** opens the source and the generated file together. Hover reads the analysis already kept for that buffer, so moving the pointer does not compile the file again. A position with no type does not open a tooltip. Completion offers names in scope, members after `.`, named arguments, and snippets for `if`, `for`, and `while`. `use quds:` lists the SDK libraries from memory. Go to definition of an SDK declaration opens a read-only document. It reuses that same analysis while the current line is unfinished, and a word from elsewhere in the file is not offered as a suggestion.

## Completion and debugger update — 2026-11-17

Signature help is available at `(` and `,`. Completion specializes inherited Quds
and Dart generic members, includes generic SDK extensions and unused arguments
inside indentation call blocks, and supports Arabic identifiers. Private imported
members are filtered. Analysis stays in a background worker with one latest pending
request per document; cached live completion does not compile or cold-load Dart
library metadata on the request path.

Breakpoints account for generated imports/helpers and const lint comments.
Variables, nested expansion and Watch expressions use Quds names. A real VM/DAP
integration test expands a Quds list/object and evaluates an Arabic-named binding.
After updating the installed extension, use **Developer: Reload Window**. Detailed
measurement scope and current limits are in `docs/EDITOR_PERFORMANCE_DEBUG_AR.md`
in the repository; raw measurements are under `bench/results/editor_latency.json`.

## English keyword help

Hover over a recognized keyword to see its purpose, constraints and a Quds
example. The same Markdown appears in the completion details pane for keywords
and statement snippets. The source is
[docs/KEYWORD_REFERENCE.md](../../docs/KEYWORD_REFERENCE.md).

The server handles this help from its bundled catalog, including in incomplete
buffers, without compiling or loading SDK metadata. Contextual identifier names
retain symbol hover; comments, strings and member access are excluded. The
approved but currently unsupported `deferred` directive is explicitly labeled in
its documentation. Keyword help does not add language syntax.

Update the installed compiler and run `quds install`, then use **Developer:
Reload Window** so both the extension and server use the new files. With an
up-to-date extension already loaded, **Quds: Restart Language Server** reloads the
server alone. Other LSP clients can render the same Markdown; JetBrains receives
highlighting from the installer and is not claimed to have this LSP integration.
