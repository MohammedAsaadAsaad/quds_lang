---
name: quds
description: Work with Quds (.quds) programs. Use when a file ends in .quds or the user mentions Quds, quds build, or quds run.
---

Quds is an indentation-based language that compiles to Dart. The command is `quds`.

- `quds build <file.quds>` writes Dart under `.dart_tool/quds/out/`.
- `quds run <file.quds>` compiles and runs. A Flutter package launches with `flutter run`.
- `quds test <file.quds>` runs the file's tests.
- `quds format <file.quds>` rewrites the file.
- `quds lsp` is the language server.
- `quds help` lists every command.

A block starts with `:` and continues by indentation. `name = value` introduces an immutable binding. `var name = value` is mutable. `const` is compile-time.
