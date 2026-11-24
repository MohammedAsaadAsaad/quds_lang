# Changelog

## 0.1.0

- First public alpha release of the Quds VS Code extension.
- Syntax highlighting, bracket/indentation configuration, format-on-save, and diagnostics for `.quds` files.
- Language server integration (`quds lsp`): completion (including loop context `$.`), hover with keyword reference & Dart-to-Quds preview, go-to-definition, signature help, and rename.
- Integrated debugging (`quds debug`) with `.quds` breakpoints, Flutter hot reload/restart commands, and live `$` / `$.index` / `$.iteration` / `$.item` evaluation in Hover, Watch, and Debug Console.
