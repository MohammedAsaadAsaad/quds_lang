# Editor, console and installer follow-up

Base: 9a2ca13. Requested scope: reliable `$.` completion while editing, console
output without a newline, string repetition, update-before-install, and a raw
`quds flutter clean` pass-through. The final gate and exact results are recorded at the top of `VALIDATION.md`.

## Console and repetition

```quds
use dart:io
main():
  stdout.write("some" * 5)
  stdout.write(" next")
  print " finished"
```

The typed top-level Dart getter reader now recognizes stdout/stdin/stderr instead
of exposing an erroneous name `get`. Actual Quds console output is tested byte for
byte (with native line terminators normalized on Windows).

The existing approved repetition syntax supports both `"some" * 5` and
`5 * "some"`; both forms have actual execution, constant, evaluation-order
and awaited-operand coverage. Native console writes use existing Dart interop:
`use dart:io`, then `stdout.write("text")` or `stdout.writeln("text")`.
This is native IO; browser consoles do not expose the same stream API.

## Completion while editing

Reproduced: `print "{$.` inside a loop returned no completions while the string or
interpolation was unfinished. Syntax-only recovery now closes a temporary parse
view or uses the prefix to the cursor; it never edits the user's document or
invokes semantic compilation/import resolution. Live LSP tests cover the partial
buffer. The grammar marks interpolation contents as embedded Quds code with token
type `other`, allowing code suggestions with normal string suggestions disabled.
Raw strings and doubled literal braces retain string handling and do not request
loop completions. No interactive VS Code GUI run is claimed by the headless tests.

## Update and Flutter commands

`quds install` updates the compiler checkout from origin/main with a
fast-forward only, then runs the updated installer. It preserves tracked local
changes and divergence, and offers --no-update for local installations. This flag
skips repository network access; dependency resolution may still require cached
packages or network access.
No reset, clean, forced branch change or automatic stash. A fresh Dart process
runs the updated installer with --no-update so newly added installer files are
included. Activation failures now produce a failing exit status even when editor
files were copied. The unsupported global-activate --offline flag was replaced
with offline dependency preparation followed by standard path activation. An archive without Git
metadata cannot be updated in place and must report that explicitly.

`quds flutter <arguments>` forwards arguments, working directory and exit status
to the selected Flutter executable. `quds flutter clean` uses Flutter's own clean
behavior. No Flutter engine run is claimed by fake-backend command tests.

## Evidence and handoff

- `test/loop_context_test.dart`: unfinished interpolation, auto-closed quote,
  bare `$.` at EOF, and live LSP completion; no semantic compilation callback.
- `test/string_repeat.quds`: primary Quds repetition/constant/async conformance.
- `test/console_repeat_vm.quds`: actual IO writes without inserted newlines.
- `test/string_repeat_web.quds` and its golden: deterministic output, strict
  Dart analysis, actual VM and compiled JavaScript execution, left-to-right
  exactly-once effects and awaited operands. Reverse repetition now captures
  operands outside the helper's synchronous body.
- `test/toolchain_update_test.dart`: real temporary Git origins/checkouts,
  update/idempotence, local changes, divergence, detached HEAD, fetch failure and
  non-Git archives. No production checkout is updated by these tests.
- `test/toolchain_activation_test.dart`: a real isolated local package is activated
  and its generated command executes; invalid package activation fails.
- `test/project_cli_test.dart`: Flutter clean arguments, cwd, output, exit status.

Generated ABI v16 invalidates older generated output. The portable CI matrix now
selects the new drivers; local success does not prove remote jobs passed. The
original 115 readiness statuses stay unchanged. Other union work remains in the
previous handoff; this does not expand its certified subset.
