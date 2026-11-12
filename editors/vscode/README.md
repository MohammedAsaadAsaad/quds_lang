# Quds for VS Code

Highlights `.quds` files, formats the open buffer, and shows compiler diagnostics.

The extension starts `dart run bin/quds.dart lsp` when the workspace is the `quds_lang` package. Otherwise it starts `quds lsp` from `PATH`. Set `quds.serverCommand` to replace that, for example `["dart", "run", "/path/to/bin/quds.dart", "lsp"]`.

On Linux, `bash install.sh` from the repository root installs Dart if needed, activates the `quds` command, and installs this extension. You can also install the folder with **Developer: Install Extension from Location**. Then open a `.quds` file and run **Format Document**. **Quds: Restart Language Server** starts the server again.

Formatting uses the same rules as `quds format`: two-space indents, an 80-column wrap after a comma, and comments and string contents left as written. A buffer that does not parse is not formatted. The language server reads the editor buffer, including text that has not been saved. Completion, hover, and a debugger that launches a program are not in this extension.
