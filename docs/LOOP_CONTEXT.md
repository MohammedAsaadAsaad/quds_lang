# Loop context: `$`

User-approved addition, 2026-11-20. This extends specification 1.2 without
replacing the existing loop syntax. The implementation uses existing AST member access with a reserved `$` receiver;
final validation results are recorded at the top of `VALIDATION.md`.

Inside a loop or `retry` body, `$.index` is the zero-based entry index, `$.iteration` is the
one-based entry number, and `$.isFirst` is true on the first entry. `$.item` is
the same typed value as the for-in binding (including await-for and collection
for). While/C-style for/repeat/retry have no implicit item. Context properties cannot
be assigned. `$` is reserved for this contextual receiver, not a normal binding.

The nearest enclosing body supplies the context. A new loop's or `retry`'s header is evaluated
in its outer context: `repeat $.index:` and `retry $.iteration:` read the enclosing loop context
(`attempts`, `delay:`, and `backoff:` evaluate once before retrying). Conditions,
initializers and C-style steps also use the enclosing context. A trailing repeat
condition uses the completed entry of that repeat, allowing `while $.iteration < 3`,
and a `retry` `when` condition uses the current attempt context, allowing `when e is StateError and $.iteration < 3`.
A loop's else block uses its enclosing context. A callback declared inside a body
captures that iteration's index and item. An unrelated called function does not
inherit the caller's context.

Counts advance on body entry, including iterations that continue; they do not
advance merely because a condition is tested. A collection filter sees the input
position, before filtering. For pair bindings the context index is always an ordinal, not the first field;
`$.item` follows the original source binding. No extra enumeration, prefetching,
length query or replay is introduced. Streams remain single-pass.

Examples:
```quds
for item in [10, 20]:
  print "{$.iteration}: {$.item}"
  repeat $.index:
    print $.index
```

Editor completion after `$.` and hover documentation are English. Unsupported
members and use outside an enclosing loop produce source-level Quds diagnostics.
`length`/`isLast` are deliberately absent: arbitrary iterators and streams need
not have a known length, and lookahead would change evaluation behavior.

## Implementation and handoff

- All four statement loop forms, loop expressions, while-let/pattern, await-for,
  generators, pair bindings, list/set/map comprehensions and nested loops use
  statically resolved context symbols. No runtime context object or global counter.
- Statement counters are emitted only when needed. Each entered body binds a final
  snapshot for escaping callbacks. Collection contexts use lazy `.indexed` record
  patterns, so awaited operands stay in their original async context.
- Postcondition repeats bind a final snapshot in a switch expression. This keeps
  awaited tests and escaping callback captures correct, including after continue.
- Fixes an existing await-for record-pair lowering defect exposed by the new suite.
  Generated ABI v15 invalidates checksum-valid v14 consumers; the cache regression
  executes the rebuilt program. No approved syntax was replaced.
- Completion uses parser/lexer information only, with zero semantic-compilation or
  import-resolution callbacks. TextMate and semantic highlighting mark contextual
  properties, semantic tokens mark them readonly, and English hover shows type,
  purpose and example.

Evidence: `test/loop_context.quds` has twenty executable Quds cases. The Dart driver
adds negative source diagnostics, completion checks (including Unicode and partial
properties), hover, deterministic golden/strict generated analysis, actual VM/JS
execution and cache migration. The portable CI matrix selects this driver; local
success does not certify a remote Windows/macOS run.

An ordinary library callback such as map/forEach does not create its own context;
a callback defined inside a loop captures that enclosing loop.

This does not add retry semantics to try/catch, a first-class `$` value, lookahead,
length/last-item properties or arbitrary context members. Other language completion
work remains in `LANGUAGE_READINESS_AR.md`.
