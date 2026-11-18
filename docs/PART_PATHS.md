# Unquoted part paths and completion

Per the owner's 2026-11-18 clarification, `part` and `part of` use unquoted
module paths, like `use` and `export`. This corrects the quoted-only `part`
grammar/example in the previous handoff; quoted literal paths remain accepted
for backward compatibility.

Given this project:

```text
quds.yaml
main.quds
src/details.quds
```

`main.quds`:

```quds
part src.details

class Secret:
  private value: int = 7

main():
  print read(Secret())
```

`src/details.quds`:

```quds
part of ^.main

read(item: Secret) -> int = item.value
```

The result is `7`. The two files share library privacy. No inheritance or import
is involved. `src.details` resolves to `src/details.quds`; `^.main` resolves to
`../main.quds`. Explicit `.quds` paths also work. Formatting preserves the bare
spelling. Generated Dart still uses Dart's quoted `part` and `part of` directives.

After `part ` or `part of ` the editor suggests local Quds files and directories.
Selecting a directory inserts its name followed by a dot and retriggers completion.
Selecting a file inserts its module name without quotation marks or `.quds`.
Typing `part o` suggests `of ` and then retriggers path completion. Parent traversal
uses `^.`. The current file, SDK/package schemes, non-Quds files and section
selectors are excluded from part suggestions. Completion runs before semantic
analysis, so an unfinished directive can still offer paths.

Quoted paths remain literal, including filenames that contain dots:
`part "literal.name.quds"` still names that exact file. Go to definition follows
the same interpretation as the parser. Existing ownership checks still reject a
mismatched owner with `E903`.

The English [keyword reference](KEYWORD_REFERENCE.md) and its generated tooltip
catalog have been updated. Regression coverage is in `parts_paths_test.dart` and
the executable Quds suite `parts_paths.quds`; final command results are recorded
in [VALIDATION.md](VALIDATION.md). The CLI execution fixture is a project marked
by `quds.yaml` and verifies generated Dart analysis as well as output.
