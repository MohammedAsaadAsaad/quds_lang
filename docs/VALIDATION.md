# Scoped `using`, `Disposable` / `AsyncDisposable`, and Dart `dispose()` / `close()` interop (Batch 1) — 2026-11-23

Base: `09f2ee7`.

| Check | Observed result |
| --- | --- |
| Core SDK interfaces | Added `Disposable` and `AsyncDisposable` to `lib/sdk/core.quds` and synced `lib/src/sdk.dart` via `python3 tool/sync_sdk.py core` |
| Block & scoped `using` | Added block-less `using x = expr` / `using async x = expr` in `lib/src/parser.dart` (`_wrapScopedUsing`), desugaring trailing statements in enclosing blocks into LIFO `UsingStatement`s |
| Static cleanup & definite return | Added `_resolveUsingCleanup` in `lib/src/semantics.dart` resolving `dispose()` then `close()` across Quds classes/interfaces/generic bounds and Dart/Flutter native classes (`StreamController`, etc.); fixed definite-return (`returns()`) and `_mentionsBreak()` for `UsingStatement` |
| Quds primary suite & driver | `/opt/flutter/bin/dart test test/using_disposable_test.dart`: **4 passed, 0 failed** (26s; `quds test test/using_disposable.quds`, negative checks, formatter + LSP completion, strict `quds analyze --fatal-infos`, VM + `quds compile js` + `node` parity) |
| Language regression | `/opt/flutter/bin/dart test test/language_test.dart --name "using\|defer\|QUDS-04"`: **1 passed, 0 failed** |
| Format, analysis & sync | `dart format` clean, `/opt/flutter/bin/dart analyze`: no issues found; `python3 tool/audit_language.py --check`, `python3 tool/sync_keyword_docs.py --check`, `git diff --check`: passed |

Targeted regression suites were run rather than the full repository suite.

# Dart CLI parity upgrade (`quds compile`, VM flags, directory `analyze`/`test`, templates) — 2026-11-23

Base: `a5a13bc`.

| Check | Observed result |
| --- | --- |
| Global & passthrough commands | Added `quds --version` / `-v` / `version`, per-command `-h` / `--help`, direct `quds <file.quds> [args]` execution, `quds dart <args>`, `quds devtools`, `quds info`, and `pub` shortcuts (`upgrade`, `outdated`, `deps`, `publish`) |
| `quds compile` | Added `quds compile <exe\|aot-snapshot\|jit-snapshot\|kernel\|js\|wasm> [options] [input.quds]` forwarding Dart compiler options (`-o/--output`, `-D/--define`, `-O0..-O4`, `--target-os`, `--target-arch`, etc.) with default outputs beside the `.quds` source |
| `quds run` | Added `-e` / `--eval=<code>` snippet execution and Dart VM flags (`--[no-]enable-asserts`, `-D`/`--define`, `--observe`, `--enable-vm-service`, `--pause-isolates-on-*`, `--verbosity`, `--disable-service-auth-codes`, `--write-service-info`) for non-Flutter projects |
| `quds analyze` & `quds test` | Added directory/multi-file/default targets (`.` for `analyze`, `test/` for `test`), `--fatal-infos` / `--[no-]fatal-warnings` on `analyze`, and `-n/--name`, `-N/--plain-name`, `--fail-fast`, `--[no-]enable-asserts`, `-r/--reporter` on `test` (backed by group/filter/fail-fast hooks in `lib/src/emitter.dart`) |
| `quds create`, `format`, `build`, `doc` | Added `-t/--template <console\|cli\|package\|flutter>`, `--force`, `--[no-]pub` to `create`; `-o/--output <write\|show\|none>` and `-l` to `format`; default entry detection to `build`; `-o/--output` and directory docs to `doc` |
| New CLI parity suite | `/opt/flutter/bin/dart test test/cli_dart_parity_test.dart`: **6 passed, 0 failed** (3m46s; real `compile exe` binary run, `compile js` + `node`, `compile kernel` + `dart`, `-e`/`-D`/`--enable-asserts`, directory `analyze`, filtered/`--fail-fast` `test`, `create -t package`/`cli`, `format -o/-l`, default `build`, `doc -o`) |
| Existing CLI/format/runner regressions | `test/quds_test_runner_test.dart` (**7/7**), `test/format_test.dart` (**5/5**), `test/project_cli_test.dart` (**7/7** across combined + targeted rerun), `test/compiler_test.dart --name "help, doctor\|CLI build\|quds create"` (**3/3**) |
| Format, analysis & sync | `dart format` clean, `/opt/flutter/bin/dart analyze`: no issues found; `python3 tool/audit_language.py --check`, `python3 tool/sync_keyword_docs.py --check`, `git diff --check`: passed |

Targeted regression suites were run rather than the full repository suite.

# External Quds packages, package-internal visibility (`E208`), and `quds build --package` — 2026-11-23

Base: `982cc74`.

| Check | Observed result |
| --- | --- |
| External Quds packages (`git:`, `path:`, transitive) | `resolveLibraryPath`, `packageDartFile`, `compile`, `Analyzer`, and CLI (`quds build`, `quds run`, `quds test`, `quds analyze`) resolve external `.quds` packages (including sections `package:name::section`, extensions, and transitive `app -> mid -> leaf` chains) via `.dart_tool/package_config.json`; consumer builds emit external modules under `.dart_tool/quds/out/_packages/<name>/` without writing to dependency/pub-cache directories |
| Package-internal visibility (`E208`) | `lib/src/` and `lib/internal/` `.quds` libraries are accessible within the owning package (`lib/`, `bin/`, `test/`) and re-exportable through its public facade, while direct/dotted/relative cross-package imports and exports (and transitive cross-package re-exports) fail at compile time with `E208` |
| Dual publishing (`quds build --package [dir]`) | Emits `lib/**/*.dart` beside `lib/**/*.quds` and shared SDK bundles under `lib/src/_quds_sdk/` when used, verifies plain Dart `import 'package:greeter/greeter.dart';` execution, and refuses (`exitCode == 73`) to overwrite non-generated `.dart` files |
| LSP completion & navigation | `completeAt` suggests external `.quds` packages, `package:name::` sections, and public `.quds` modules while hiding external Quds `src/` and `internal/` folders (preserving pure-Dart `package:widgets/src/` completion); `libraryAt` and `definitionAt` jump to external `.quds` sources |
| End-to-end suite (`test/external_packages_test.dart`) | `/opt/flutter/bin/dart test test/external_packages_test.dart`: **5 passed, 0 failed** (1m35s; real `git init` + `dart pub get` `git:` dependency, VM + `dart compile js` + `node` parity, transitive `app -> mid -> leaf`, 10+ `E208` cases, `quds build --package`, LSP) |
| Editor/parts/interop regressions | `/opt/flutter/bin/dart test test/editor_test.dart test/parts_paths_test.dart test/academy_interop_test.dart`: **32 passed, 0 failed** (36s) |
| Filtered compiler regressions | `/opt/flutter/bin/dart test test/compiler_test.dart --name "package|import|build|completion|library|export"` (**16 passed** + 1 stale `quds:c` expectation updated to include `quds:collection`), rerun `import completion reads files`: **1 passed, 0 failed** |
| Format, analysis & sync | `dart format` (6 touched Dart files clean), `/opt/flutter/bin/dart analyze`: no issues found; `python3 tool/audit_language.py --check`, `python3 tool/sync_keyword_docs.py --check`, `git diff --check`: passed |

Targeted regression suites were run rather than the full repository suite; no full-suite run or live `pub.dev` upload is claimed for this entry.

# General-purpose collections SDK (`quds:collection`, Batches 0–5) — 2026-11-23

Base: `4197acf` (Batches 0–4 pushed as `66fdadc`, `823ba76`, `ee8b432`, `7bfd419`; Batch 5 closes `:: extensions`, `quds:ext` `Lists`/`Maps`/`Sets` migration, golden, LSP, and docs).
Design/plan: [COLLECTION_SDK_PLAN_AR.md](COLLECTION_SDK_PLAN_AR.md). API reference: [COLLECTION_REFERENCE.md](COLLECTION_REFERENCE.md).

| Check | Observed result |
| --- | --- |
| Embedded SDK sync | `lib/sdk/collection.quds` (12 sections) and `lib/sdk/ext.quds` (`Lists`/`Maps`/`Sets` removed with no alias/re-export; `Ints`/`Doubles` retained; `lib/sdk/core.quds` kept intact) match `lib/src/sdk.dart` |
| Quds primary suites (`quds test`) | All 6 suites pass via `test/collection_sdk_test.dart`: `collection_core.quds`, `collection_imports.quds`, `collection_sort_equality_diff.quds`, `collection_structures.quds`, `collection_specialized.quds`, `collection_extensions.quds` |
| `quds:ext` migration check | `test/collection_reject_ext_collections.quds`, `Map.missing`/`Set.without` rejection on `quds:ext` alone, `hide Lists`, and `show Lists` confirm full migration while `quds:collection::extensions` coexists with `quds:ext` and `quds:core` |
| Generated output & VM/JS parity | Deterministic golden `test/goldens/collection_slice.dart.txt` matches; `test/collection_web.quds` passes strict `dart analyze --fatal-infos` on generated Dart and executes identically on Dart VM and `dart compile js` + `node` |
| Editor LSP checks | Completion (`MapConflictPolicy.`, `quds:collection::extensions` vs `quds:ext` alone) and go-to-definition (`quds-sdk://library/collection.quds`) pass inside `test/collection_sdk_test.dart` |
| `quds:collection` driver | `/opt/flutter/bin/dart test test/collection_sdk_test.dart --reporter expanded`: **11 passed, 0 failed** (1m06s) |
| `quds:text` driver | `/opt/flutter/bin/dart test test/text_sdk_test.dart`: **14 passed, 0 failed** (1m42s) |
| Editor suite | `/opt/flutter/bin/dart test test/editor_test.dart`: **15 passed, 0 failed** (2s) |
| Filtered compiler/SDK/LSP regressions | `/opt/flutter/bin/dart test test/compiler_test.dart --name "ext|sdk|lsp"`: **9 passed, 0 failed** (6s) |
| Language suite | `/opt/flutter/bin/dart test test/language_test.dart`: **57 passed, 0 failed** (1m58s) |
| Format & analysis | `dart format` (touched Dart files clean), `/opt/flutter/bin/dart analyze`: no issues found |
| Inventory/keyword/diff sync | `python3 tool/audit_language.py --check`, `python3 tool/sync_keyword_docs.py --check`, `git diff --check`: passed (`READINESS: 115 decisions indexed; no unearned completeness claims`) |

Targeted regression suites were run rather than the full repository suite; no full-suite run or interactive VS Code GUI session is claimed for this entry.

# General-purpose text SDK (`quds:text`, Batches 0–5) — 2026-11-23

Base: `7f238d1` (Batches 0–4 pushed as `78cb96c`, `6be6474`, `7e20446`, `13219eb`; Batch 5 closes extensions, `quds:ext` `Text` migration, golden, and docs).
Design/plan: [TEXT_SDK_PLAN_AR.md](TEXT_SDK_PLAN_AR.md). API reference: [TEXT_REFERENCE.md](TEXT_REFERENCE.md).

| Check | Observed result |
| --- | --- |
| Embedded SDK sync | `lib/sdk/text.quds` (17 sections) and `lib/sdk/ext.quds` (with `extend String Text` removed, no alias/re-export) match `lib/src/sdk.dart` |
| Quds primary suites (`quds test`) | All 9 suites pass via `test/text_sdk_test.dart`: `text_core.quds`, `text_imports.quds`, `text_unicode.quds`, `text_unicode_reference.quds` (980 checks against pinned Unicode 15.0.0 generated by `tool/generate_text_unicode.py`), `text_patterns_search.quds`, `text_replace_reader.quds`, `text_format_compare.quds`, `text_escape_encoding.quds`, `text_extensions.quds` |
| `quds:ext` migration check | `test/text_reject_ext_string.quds`, `show Text`, and `hide Text` confirm `use quds:ext` alone rejects migrated `Text` methods while `use quds:text::extensions` coexists with `use quds:ext` |
| Generated output & VM/JS parity | Deterministic golden `test/goldens/text_slice.dart.txt` matches; `test/text_web.quds` passes strict `dart analyze --fatal-infos` on generated Dart and executes identically on Dart VM and `dart compile js` + `node` |
| Editor LSP checks | Completion (`TextLineEnding.`, `quds:text::extensions` vs `quds:ext` alone) and go-to-definition (`quds-sdk://library/text.quds`) pass inside `test/text_sdk_test.dart` |
| `quds:text` driver | `/opt/flutter/bin/dart test test/text_sdk_test.dart --reporter expanded`: **14 passed, 0 failed** (1m44s) |
| Editor/static/actions regressions | `/opt/flutter/bin/dart test test/dart_core_static_editor_test.dart test/editor_test.dart test/editor_actions_test.dart`: **25 passed, 0 failed** (7s) |
| Filtered compiler/debug/SDK regressions | `/opt/flutter/bin/dart test test/compiler_test.dart --name "enum|ext|sdk|debug|hover"`: **17 passed, 0 failed** (42s) |
| Language suite | `/opt/flutter/bin/dart test test/language_test.dart`: **57 passed, 0 failed** (1m56s) |
| VS Code JS unit checks | `for f in test/editor/vscode_*.cjs; do node "$f"; done`: **7/7 passed** |
| Format & analysis | `dart format` (4 touched Dart files: 1 formatted), `/opt/flutter/bin/dart analyze`: no issues found |
| Inventory/keyword/diff sync | `python3 tool/audit_language.py --check`, `python3 tool/sync_keyword_docs.py --check`, `git diff --check`: passed (`READINESS: 115 decisions indexed; no unearned completeness claims`) |

Targeted regression suites were run rather than the full 11m repository suite; no full-suite run or interactive VS Code GUI session is claimed for this entry. Unicode data is pinned to Unicode 15.0.0 (normalization NFC/NFD/NFKC/NFKD, case folding, and UAX #29 extended grapheme clusters) and does not claim locale-specific collation or full Unicode word/sentence segmentation.

# Editor/console/installer follow-up — 2026-11-20

Base: `9a2ca13`. Generated ABI: `provider-defaults-v16`.
Contract/handoff: [EDITOR_CONSOLE_INSTALL_FOLLOWUP.md](EDITOR_CONSOLE_INSTALL_FOLLOWUP.md).

| Check | Observed result |
| --- | --- |
| Reproduced completion defect | Unterminated interpolation returned an empty loop completion list; bare EOF/closed interpolation worked |
| Editor fixes | Temporary syntax-recovery views, live LSP completion before diagnostics, embedded code token type; literal doubled braces/raw strings excluded |
| Console | Real Quds VM program uses stdout.write without inserted newlines; getter parsing restored stdout and preserves typed getters across setters |
| Repetition | Three primary Quds tests, deterministic golden/strict generated Dart analysis, actual VM/JS execution; awaited reverse operands remain in caller context |
| Git update | Real temporary origins/checkouts: fast-forward/idempotence, tracked edits, divergence, detached HEAD, fetch failure and archive cases |
| Activation | An isolated local package is activated and its command runs; invalid activation fails. Restricted editor-staging test reports activation failure while retaining copied editor files |
| Flutter clean | Fake-backend project test checks arguments, working directory, stdout/stderr and exit codes; no actual engine run claimed |
| Focused final gate | Loop/console/update/activation/editor drivers: **56 passed in 15s**; updated installer staging regression: **1 passed in 30s** |
| Final format | `dart format .`: 119 files, 0 changes |
| Final analysis | `dart analyze`: no issues found |
| Full suite | `dart test --reporter expanded`: **836 passed, 1 failed, 11m41s**; the sole failure was an accidentally changed Shell-installer exit-code expectation, not product code |
| Corrected Shell regression | Restored success expectation for `install.sh --skip-cli`; exact targeted test: **1 passed**. No product code changed after the full run; all **837 final cases** are verified across the full and targeted runs |
| Inventory/keyword sync | `audit_language.py --check`, `sync_keyword_docs.py --check`, `git diff --check`: passed; 24 partial, 91 needs_certification, 0 complete |

The full suite was not repeated after the one-line Shell expectation correction;
the matching targeted test was rerun successfully. VM/JS cache GC regressions in
the full run each observed `collected: 1000, buckets: 1, live: 42, canonical: true`.

The first full run was stopped before completion to include literal-interpolation
regressions. No incomplete full-run pass is claimed. Headless LSP/client tests and
grammar configuration do not constitute an interactive VS Code GUI session.

# Owner-approved loop context — 2026-11-20

Base: `2fd7ffe`. Generated ABI: `provider-defaults-v15`.
Contract/handoff: [LOOP_CONTEXT.md](LOOP_CONTEXT.md).

| Check | Observed result |
| --- | --- |
| Quds source coverage | 20 positive cases across statement/value loops, nullable/pattern while, ranges, labels, nested headers, postconditions, callbacks, generators, streams and list/set/map comprehensions |
| Focused gate | Final loop driver: **23 passed in 12s**. Loop/union/editor development gate: 53 passed before the final async-postcondition case; final full gate includes it |
| Baseline pair defect | The `2fd7ffe` backend on a pair-stream program emitted synchronous for-in over Stream; actual Dart execution rejected the generated file |
| Generated output | Deterministic golden, strict generated Dart analysis, actual VM and JavaScript execution |
| Completion | Parser/lexer only; tests forbid semantic compilation, cover Unicode, incomplete property names, nested headers and postconditions, and omit item in non-item loops |
| Hover/highlighting | English type/purpose/example; TextMate contextual receiver/property scopes and readonly semantic tokens |
| Completion measurement | During the full gate, 20 warm requests after 5 warmups: 1,000 helper lines median 12.009ms / p95 22.434ms; 5,000 lines median 43.472ms / p95 58.214ms. Zero semantic compilations; this is a local syntax-completion measurement, not an end-to-end editor SLA |
| Cache | Checksum-valid v14 output rebuilt to v15; real CLI await-for pair program prints 10 |
| Memory regression | VM and compiled JS each reported `collected: 1000, buckets: 1, live: 42, canonical: true` |
| Final format | `dart format .`: 115 files, 0 changes |
| Final analysis | `dart analyze`: no issues found |
| Full suite | `dart test --reporter expanded`: **818 passed, 0 failed, 11m33s** |
| Inventory/docs | `audit_language.py --check`, `sync_keyword_docs.py --check`, `git diff --check`: passed; 24 partial, 91 needs_certification, 0 complete |

The existing source syntax is preserved. `$` is an additive owner-approved
contextual receiver, not a new first-class runtime value. The portable CI matrix
selects the new driver; its configuration is not an observed remote run. No actual
Flutter engine run is claimed for this compiler addition.

# Checked union library exchange — 2026-11-20

Base: `20949f6`. Generated ABI: `provider-defaults-v14`.
Contract/handoff: [UNION_LIBRARY_BOUNDARIES.md](UNION_LIBRARY_BOUNDARIES.md).

| Check | Observed result |
| --- | --- |
| Baseline reproduction | `quds test test/union_exchange.quds` failed: separate nominal union families across modules, plus raw-arm returns from a union function |
| Quds execution | Eight new execution cases in `test/union_exchange.quds`; source-level invalid-arm checks and explicit E910 coverage |
| Focused regression | Union exchange/boundary/flow drivers: 21 passed; final exchange-only driver (including overload-candidate regression): 15 passed |
| Generated output | Deterministic golden, strict Dart analysis, actual VM and JavaScript runs; invalid foreign payload rejected with ArgumentError |
| Cache | Checksum-valid v13 legacy output rebuilt with ABI v14 |
| Memory regression | VM and compiled JS each observed `collected: 1000, buckets: 1, live: 42, canonical: true` |
| Portable CI | Three union drivers added to Linux/Windows/macOS matrix; remote runs not observed locally |
| Final format | `dart format .`: 113 files, 0 changes |
| Final analysis | `dart analyze`: no issues found |
| Full suite | `dart test --reporter expanded`: **795 passed, 0 failed, 11m30s** |
| Inventory and keyword sync | `audit_language.py --check`, `sync_keyword_docs.py --check`, `git diff --check`: passed; 24 partial, 91 needs_certification, 0 complete retained |

The cloud connection was restored during the final run; the original process
continued and its final log recorded all 795 passes.

The preliminary full run was stopped before completion to ensure the final run
includes a correction to speculative overload handling. No preliminary full-run
pass is claimed. These checks do not repeat an actual Flutter engine run or
certify the broader union combinations listed in the contract.

# Review of the next agent's work and cache/flow follow-up — 2026-11-20

Review base: `5f6dbc3`. Generated ABI: `provider-defaults-v13`.
Contract/review: [FUNCTION_VALUE_CACHE_AND_FLOW.md](FUNCTION_VALUE_CACHE_AND_FLOW.md).

| Check | Observed result |
| --- | --- |
| Baseline review | The five new commits were inspected; `dart analyze` clean. The inferred-interface/SDK/owner/identity/union drivers plus compiler driver: **84 passed in 3m34s** |
| Baseline union defect | A conditional nested case was treated as an unconditional exit; actual execution threw a sealed-union subtype cast error |
| Baseline memory workload on `5f6dbc3` | VM and JavaScript both retained all 1,000 cyclic receivers: `collected: 0, buckets: 1001`; the new GC tests failed as expected |
| Revised memory workload | VM-service GC and compiled JavaScript/Node GC each reported `collected: 1000, buckets: 1, live: 42, canonical: true` |
| Development regression set | Extension/GC/union-flow/value-adapter/method-value drivers: **39 passed in 28s**. Final nullable-reference identity coverage was added afterward and is included in the full gate |
| Entry-point preparation regression | Same fake-Flutter test failed on `5f6dbc3` with two main definitions; fixed source has one main and a real top-level _qMain. No engine execution claimed by this test |
| Program arguments | Actual CLI passes a `.quds` suffix as a payload argument after the entry point; mapped runtime errors and `-- --help` retain existing behavior |
| Quds coverage | Six reference-identity declarations and four union-flow declarations; negative union-promotion and readonly-extension cases |
| Output conformance | Deterministic goldens and actual VM/JavaScript execution; 37-line identity program and 10-line union-flow program |
| Cache epoch | A checksum-valid v12 consumer with legacy output is rebuilt to v13 and prints `true`, `1` |
| Final `dart format .` | 112 files, 0 changes |
| Final `dart analyze` | No issues found |
| Final `dart test` | **780 passed, 0 failed, 11m13s**; includes the final nullable-identity regression and all VM/JS GC checks |
| Inventory/docs | `python3 tool/audit_language.py --check`, `python3 tool/sync_keyword_docs.py --check`, `git diff --check`: passed |

The GC workload uses real compiled Quds objects, including receiver/closure cycles
and an independently retained live callable. Test thresholds allow collector timing
variation. The exact 1,000/1 measurements above were observed on both hosts; they
are not a platform-wide memory budget. Buckets contain only weak slots and
finalizer tokens do not retain receivers. Reified generic types, readonly contract
keys, lexical activations and implicit-this owners keep distinct operations apart.

A conditional pattern or event notification cannot justify remainder narrowing.
Throw does exit. The emitter tracks the promoted symbol rather than applying one
union case's assumption to other values. Wider/inter-library union certification,
polymorphic callbacks and foreign implementors remain explicit follow-up work.

The preceding agent recorded actual Linux Flutter engine/hot reload/debug/build
observations. Those records were read, but the engine SDK is absent in this
workspace; no fresh engine/device run is claimed. GitHub API still returns Forbidden,
so its pull-request state was not independently queried here. All 115 decisions
remain indexed, with 24 partial, 91 needs_certification and no newly complete rule.
Older sections below are historical.

---

# Program arguments for main — 2026-11-19

`main` may return `void` or `Future<void>` and take no arguments, or one `List<String>` argument. `main(args: List<String>)` and `main(...args: String)` both lower to Dart `main(List<String> ...)`. `quds run file.quds alpha -- beta` passes `alpha` then `beta`. `quds run file.quds -- --help` passes the text `--help` into `main`. Another parameter shape is rejected. A range error inside that `main` is still reported on the Quds line. `dart test test/compiler_test.dart --name "main receives one List"` passed. `dart analyze lib bin test` reports no issues. `dart test`: 772 passed, reporter 06:33, wall 394825 ms.

---

# Breakpoint retention after a saved Quds file — 2026-11-19

One Linux debug session of `examples/flutter_app/hello_world`. `setBreakpoints` was sent once, for `main.quds` line 18, before launch.

| Check | Observed result |
| --- | --- |
| First stop | `main.quds:18` |
| After continue | No further stop for 20 seconds. `build` runs on state changes, so an idle frame does not re-enter it |
| Save | A trailing comment was appended to `main.quds` and removed afterward |
| Next stop | `main.quds:18` again, with no second `setBreakpoints` request |
| Reload text | None. `FlutterDebugLive` hides a successful internal hot-reload response and only prints a rejection |

Android, iOS, Windows, and macOS were not attached. Nothing was published.

---

# Union remainder narrowing — 2026-11-19

Base: `3e1541c`. Generated ABI stays `provider-defaults-v12`.

| Check | Observed result |
| --- | --- |
| Before | The statement after `if value is int: return` still read the sealed wrapper, so `.value` was not a member |
| After | That statement casts `QudsUnion_int_or_String_String` and reads `.value`. Inside the promoting case the read stays uncast |
| Quds test | `quds test test/union_boundaries.quds` prints `ok union calls wrap and narrowing unwraps` |
| VM and JavaScript | Both print `n1`, `sa`, `n2`, `sb`, `4` |
| Limit | A union with more than two arms keeps the original sealed class. The fact does not leave the statement list |
| Analysis | `dart analyze lib bin test` reports no issues |
| Full suite | `dart test`: 771 passed, reporter 06:36, wall 397862 ms |

No rule was marked `complete`. Foreign Dart implementors stay at their existing sound rejection.

---

# Union call boundaries and the Flutter engine — 2026-11-19

Base: `2f3e8d0`. Generated ABI stays `provider-defaults-v12`.

| Check | Observed result |
| --- | --- |
| Union failure before the fix | A call passed a raw `int` to `QudsUnion_int_or_String`, and `is int` still read the wrapper |
| Quds test | `quds test test/union_boundaries.quds` prints `ok union calls wrap and narrowing unwraps` |
| Generated boundary | Local calls wrap `QudsUnion_int_or_String_int`. Imported calls wrap `api.QudsUnion_int_or_String_int`. Narrowed uses read `.value` |
| VM and JavaScript | Both print `n1`, `sa`, `n2`, `sb`, `4` |
| Re-emit | `quds test` emits twice. `wrapAs` is restored so the second emit still wraps |
| Flutter Linux debug | `flutter build linux --debug -t lib/quds_gen/main.dart` built `build/linux/x64/debug/bundle/hello_world` |
| Flutter Linux profile and release | Both bundles built |
| Flutter web | `flutter build web --debug` and `--release` built `build/web` |
| Live session | `quds run -d linux --debug` reached Impeller. Saving `main.quds` logged `Reloaded 1 of 757 libraries in 188ms` and `Quds: Flutter update completed`. `R` logged `Restarted application in 285ms` |
| Breakpoint | `quds debug` stopped with reason `breakpoint` at `main.quds:18`, frame `HomeState.build`, local `context` |
| Not certified | Breakpoint retention after a later hot reload. Android, iOS, Windows, and macOS. No pub.dev publish |
| Terminal | `stdin.echoMode` is read and restored only when the call succeeds. A closed descriptor no longer aborts `quds run` |
| Analysis | `dart analyze lib bin test`: no issues. `python3 tool/audit_language.py`: 115 decisions, no unearned complete |
| Suite | `dart test`: 771 passed, reporter 06:23, wall 384579 ms |

No rule was marked `complete`. A returning `is` does not narrow the following code to the remaining union arm. Foreign Dart implementors stay unfinished.

---

# SDK, owner, and reference-identity bridges — 2026-11-19

Base: `9619805`. Generated ABI: `provider-defaults-v12`.

| Check | Observed result |
| --- | --- |
| SDK failure before the fix | `quds test test/sdk_default_values.quds` exited 254 at Quds lines 4 and 5. The import prefix was used as a value |
| SDK after the fix | One bridge tear-off. `saved(0.0)` and `stats.normalPdf(0.0)` match. VM and JavaScript print `true`, `true`, `true` |
| SDK cache | A checksum-valid v11 consumer is rebuilt to `provider-defaults-v12` |
| Owner failure before the fix | `quds test test/owner_defaults.quds` exited 254. Value and mixin closures called `_seed`. The protected tear-off was the raw Dart method |
| Owner after the fix | Bridges stay in the provider and call `_q0()`. External protected access is E207 at `test/owner_defaults_reject.quds:4`. VM and JavaScript print `true`, `12`, `true`, `4`, `4`, `true` |
| Extension identity | `HashMap.identity`, not Expando. Object holding int, bool, and String; two generic specializations; two receivers; a readonly result; and an intersection default. VM and JavaScript print the same 15 lines |
| Analysis | `dart analyze lib bin test`: no issues. `python3 tool/audit_language.py --check`: 115 decisions, no unearned complete |
| Suite | `dart test`: 769 passed, reporter 06:08, wall 369931 ms |

No rule was marked `complete`. Union signatures, foreign Dart implementors, a real Flutter engine run, and the platform matrix remain open.

---

# Inferred interface default bridges — 2026-11-19

Base: `ddc9e4e`. Generated ABI: `provider-defaults-v11`.

| Check | Observed result |
| --- | --- |
| Failing case before the fix | `quds test test/inferred_interface.quds` exited 254. Generated Dart called `_seed` from the consumer at the Quds test coordinates |
| Quds test | `ok an inferred interface default stays in the provider` |
| Generated boundary | Consumer golden calls `$QudsMethodDefault...` and does not contain `_seed` or `_q0()`. The provider resolver calls `_q0()` |
| VM and JavaScript | Both print `70`, `true`, `70`, `20` |
| Cache | A checksum-valid v10 provider with the resolver removed is rebuilt to `provider-defaults-v11` and prints `70` |
| Analysis | `dart analyze lib bin test`: no issues. `dart format .` left package sources unchanged (568 files) and could not parse bundled `toolchains/dart` sources |
| Suite | `dart test`: 761 passed, reporter 05:53, wall 354640 ms |

No rule was marked `complete`. SDK-section default values still use a consumer adapter for literal defaults. Union/intersection boundaries, foreign implementors, real Flutter engine runs, and pub.dev stay open.

---

# Inferred provider results — 2026-11-19

Base: `683c8b9`. Generated ABI: `provider-defaults-v10`.
Contract: [INFERRED_PROVIDER_RESULTS.md](INFERRED_PROVIDER_RESULTS.md).

| Check | Observed result |
| --- | --- |
| Original CLI reproduction | Before: provider expression result int was checked against void (E300). After: direct function, stored function and method each print `7` |
| Quds conformance | 13 actual Quds test declarations, launched by the new Dart driver |
| Focused regression set | `dart test test/inferred_provider_test.dart test/generic_inheritance_test.dart test/generic_methods_test.dart test/parameter_forms_test.dart`: 94 passed in 46s |
| New golden/VM/JavaScript | Consumer, provider and facade pass `dart analyze` with warnings fatal; actual VM and compiled JavaScript/Node outputs match the same 41 lines |
| Negative conformance | Consumer assignment/argument/bound/private/ambiguous errors retain consumer coordinates. Direct/mutual recursion reports E300 with a return-annotation diagnostic at the provider. Unsafe inferred overrides and unannotated multiline value returns are rejected |
| Cache migration | A valid-checksum v9 provider with the new bridge removed is rebuilt automatically; run prints `7`, and caches record v10 |
| `dart format .` | 104 files, 0 changes |
| `dart analyze` | No issues found |
| `dart test` | **758 passed, 0 failed, 11m16s**, before the final scope-only bridge guard |
| Final affected regression set | `dart test test/inferred_provider_test.dart test/quds_value_adapters_test.dart test/parameter_forms_test.dart test/call_suspension_test.dart test/constructor_packet_regressions_test.dart`: **59 passed, 0 failed, 45s** after the guard; format/analyze rerun and clean |
| `python3 tool/audit_language.py --check` | 115 decisions indexed; statuses unchanged |
| `python3 tool/sync_keyword_docs.py --check`, `git diff --check` | Passed |

The slice covers direct calls and values through prefixes, unprefixed show imports
and filtered re-exports; sequential/private defaults, reference equality, generics,
Future/nullable/record/class/alias result types, concrete/static/inherited/readonly
method values and virtual dispatch. Default expressions stay in their provider and
do not run when a reference is taken. Lexical owner substitution fixes generic
method default checking and imported inherited-field/override-owner lookup.

Backend method names are assigned before result-dependent body checking, with
unresolved results deferred only for name matching. Full override result checking
remains enforced after inference, including against a declared base contract.
Existing concrete result checks remain early. The final bridge guard explicitly
retains the previous requirement for ordinary multiline bodies: only a declared
result or an expression body enables this provider protocol. The focused final
rerun covers the affected import/default/constructor/await paths after narrowing
that guard. No result is replaced by dynamic,
and no approved syntax changes. Ordinary multiline value returns still require an
annotation. Inferred declaring-interface defaults, SDK-section bridges, private
nominal API publication, generator and cross-package certification remain outside
this milestone. No rule is promoted to complete; no Flutter engine claim is made.
The latest handoff is [LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
Older validation sections below are historical.

---

# Awaited calls and null-aware Quds methods — 2026-11-19

Base: `f21bfb4`. Generated ABI: `provider-defaults-v9`.
Contract and limits: [CALL_SUSPENSION.md](CALL_SUSPENSION.md).

| Check | Observed result |
| --- | --- |
| Baseline Quds reproduction | Rejected generated Dart: await inside synchronous closures, and a gap-method bridge accessed on a nullable receiver |
| `dart test test/call_suspension_test.dart` | 5 passed in 16s, including ten actual Quds test declarations, two source-coordinate rejection tests, VM/JS and cache migration |
| Golden/VM/JavaScript | Generated consumer/provider analyzed with `--no-fatal-warnings`; actual VM and JavaScript/Node executions printed the same 24 lines |
| Cache upgrade | An otherwise valid v8 cache with a matching legacy-output checksum was rebuilt, printed `12` and recorded ABI v9 |
| `dart format .` | 103 files, 0 changes on the final run |
| `dart analyze` | No issues found |
| `dart test` | **745 passed, 0 failed, 10m51s** |
| `python3 tool/audit_language.py --check` | 115 decisions indexed; no status promoted to complete |
| `python3 tool/sync_keyword_docs.py --check`, `git diff --check` | Passed |

Awaited operands remain in the caller's async scope for reordered ordinary calls,
supported provider-default calls and automatic constructors. Null-aware Quds
methods capture the receiver once, skip operands/defaults/body on null and report
a nullable result. Future<void> is preserved as a value; void statements, readonly
receivers, failed-operand ordering and awaited receivers have executable coverage.
The pre-existing adapter golden was updated for the new null-short-circuit path.
No approved syntax changed. This does not certify every native/partial/generator
or awaiting-default combination; see the contract document's explicit limits.

A fresh network probe still receives CONNECT 403 from storage.googleapis.com;
Flutter's Dart SDK and engine tester are unavailable. No actual Flutter engine,
device, F5 or cross-host claim is made by this run. A separate inferred-provider
return bug was reproduced and recorded in the handoff; it is not included in this
milestone's successful-test claims. Older sections below are historical.

---

# Constructor packets and awaited operands — 2026-11-19

Base: `d84f077` (latest `origin/main` at validation). Generated ABI:
`provider-defaults-v8`. Approved specification 1.2 syntax is unchanged.

| Check | Observed result |
| --- | --- |
| `dart format .` | 102 files processed; the new test driver formatted. Subsequent compiler-test formatting: no changes |
| `dart analyze` | No issues found, including the final compiler-test assertion change |
| `dart run bin/quds.dart test test/constructor_packet_regressions.quds` | 11 Quds declarations passed |
| `dart test` | **740 passed, 0 failed, 9m44s**, completed 2026-11-19 15:44 UTC |
| New executable/golden driver (included above) | Deterministic golden; generated consumer and provider analyzed with `--no-fatal-warnings`; VM and compiled JavaScript executed with the same 18 output lines |
| New negative cases (included above) | Self/forward defaults rejected with E503 at Quds coordinates; imported bound/type/positional/private-constructor errors rejected at consumer coordinates |
| Cache migration (included above) | A valid-checksum v7 provider with the old unbound-slot defect was rebuilt by v8; execution printed `7` |
| `dart test test/compiler_test.dart --name 'quds create flutter writes the app in quds'` | 1 passed; in this PATH Flutter is unavailable, so this case exercises its documented missing-Flutter branch |
| `python3 tool/audit_language.py --check` | 115 decisions indexed; statuses unchanged |
| `python3 tool/sync_keyword_docs.py --check`, `git diff --check` | Passed |

The four reviewed failures are repaired: sequential constructor defaults, `await`
inside packet operands, bounded generic bridge invocations, and imported named
constructor default ownership. Regressions also cover receiver-first evaluation,
all-supplied operands in source order, Future/void results, awaited spreads, native
alias collisions, failed defaults skipping bodies and prefixed const objects.
Imported prefixed function values and imported method gaps retain their provider.
Generated fixture warnings (unused private constructor and constant-condition dead
code) are nonfatal; analyzer errors still fail the executable/golden test.

The earlier Flutter-create assertion now accepts either the plain StatelessWidget
name or a qualified native alias and verifies the alias import. The actual Flutter
engine was **not** downloaded or executed: its SDK download remains blocked by
CONNECT 403. This run is not evidence of real-device/F5 or engine validation.
No rule was promoted to complete: 24 partial, 91 needs_certification, 0 complete.
Handoff: [LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md). Contract:
[QUDS_PARAMETER_FORMS.md](QUDS_PARAMETER_FORMS.md). Older sections are historical.

---

# Packet values and generic constructor defaults — 2026-11-19

Base: `ea105c7` on `cursor/language-remainder-b792`. ABI stays `provider-defaults-v7`.

| Check | Observed result |
| --- | --- |
| Packet values | Mixed optional groups, a default with a variadic, and an optional positional with a variadic print `5`, `7`, `true`, `6`, `7`, `x:0`, `a:2`, `true`, `1`, `6`, `true` |
| Generic constructor | `Box<int>()` and `Box<String>(items: ["q"])` print `0`, `1`. The provider bridge contains `_q0<T>()` and the caller does not |
| Named default before required | `awkward<int>` and `Awkward.keep<int>` each print `4`, `4`, `true` |
| Analysis | `dart analyze lib bin test` after `dart format`: no issues |
| Suite | `dart test`: 729 passed, 1 failed, wall clock 6m 4s (ended 16:26 Asia/Gaza). The failure is the existing `quds create flutter writes the app in quds` case |

No rule was marked `complete`. A raw Dart function value still has no omission token. Certification of the remaining rules, real F5, and pub.dev stay open.

---

# Method overloads and imported parent constructor defaults — 2026-11-19

Base: `662adb3`. ABI: `provider-defaults-v7`.

| Check | Observed result |
| --- | --- |
| Method overloads | `dart test test/language_test.dart --name "class method overloads"`: passed. Output is `a`, `n2`, `b`, `n3`, `cc`, `n2`. Ambiguous calls are `E310`, an unselected tear-off is `E311`, and a missing candidate is `E500` |
| Parent slots | Synthesized `Child(tag: "ok")` prints `7`, `ok`, `4`. The child file calls `Parent.$QudsCtorSlots` and does not contain `_seed` or `_q0()` |
| Const, super, generic | The shape program prints `4`, `8`, `1`, `5`, `2` after the earlier six lines |
| Analysis | `dart analyze lib bin test` after formatting: **No issues found** |
| Full suite | `dart test`: **730 passed, 1 failed, in 5m56s**. The failure is `quds create flutter writes the app in quds`: the local Flutter SDK prefixes widget types (`class MyApp extends _qNative….StatelessWidget`). That failure is outside this slice |

No rule was marked `complete`. Mixed optional groups, default-plus-variadic values, and opaque Dart function values remain open.

---

# Optional positional gaps and provider-owned constructor defaults — 2026-11-19

Base: `61dc336`. Contract: [QUDS_PARAMETER_FORMS.md](QUDS_PARAMETER_FORMS.md).
ABI: `provider-defaults-v6`.

| Check | Observed result |
| --- | --- |
| Parameter driver | `dart test test/parameter_forms_test.dart`: **22 passed**. Declarations still report 15 `ok` lines. VM and JS print the same 24 lines, including both gap results `16` |
| Provider constructor | `api.Owner()` runs the provider `_seed()` through `$QudsCtor` and prints `7`, then `4` |
| Shape execution | Parent synthesis, lambda kinds, and required-named to optional-named widening print `4`, `ok`, `2`, `5`, `3`, `6` |
| Negative cases | 19 rejection cases, including mixed lambda groups, a dual override, and a positional argument to `name: Type = expr` |
| ABI cache | A v4 cache is rebuilt to `provider-defaults-v6` |
| SDK migration | Optional named arguments in `quds:math`, its reference tests, and `bench/memory_workload.quds` are passed by name. Embedded `mathSdkSource` matches `lib/sdk/math.quds` |
| Analysis | `dart analyze lib bin test`: **No issues found** |
| Full suite | First complete run after the slice: **722 passed, 4 failed, in 6m19s**. The math-source mismatch and both memory-profiler failures were then fixed and retested (3 memory tests passed; the source match passed). `quds create flutter writes the app in quds` still fails because the local Flutter SDK prefixes widget types (`extends _qNative….StatelessWidget`). That failure is outside this slice |

No rule was marked `complete`. Class method overload Dart names and default-plus-variadic values remain open.

---

# Required named and optional positional metadata — 2026-11-19

Base: `d4851c3`. The handoff was updated before implementation.
Contract: [QUDS_PARAMETER_FORMS.md](QUDS_PARAMETER_FORMS.md).

| Check | Observed result |
| --- | --- |
| Primary Quds program | 15 declarations cover named-required cursor skipping, omission/null, computed sequential defaults, function identity, generic contexts, overload labels, readonly/interface methods, constructors, evaluation order and nullable short-circuit |
| Initial focused regressions | 109 passed in 26s across parser/semantics/function/method/value and parameter-form drivers |
| Callback/generic regressions after correction | 67 passed in 28s; constructor/Dart-generic/parameter regressions then 69 passed in 46s |
| Final parameter driver | 20 passed in 28s before the added variadic-default regression; final parser + parameter drivers **32 passed in 41s** |
| Negative conformance | 17 source cases plus an actual imported computed-constructor boundary check; original consumer Quds coordinates retained |
| Generated Dart | New deterministic golden; generated entry analyzed; VM and JavaScript/Node agree on 22 lines |
| ABI v5 | Simulated v4 cache keeps valid provider checksums after parameter bridges are removed; actual `quds run` rebuilds and prints `8`, `7`, `true`. Existing generic-interface upgrade regression also targets v5 |
| Documentation example | Actual `quds run /tmp/quds-parameter-example/main.quds`: `8`, `14`, `8`, `9`, `null`, `7`, `9`, `true` |
| Final formatting/analysis | `dart analyze`: **No issues found**; `dart format .`: **102 files, zero changes** |
| Full suite | `dart test`: **726 passed, zero failures, in 12m31s** |

An initial full run was stopped after a stale generic-method golden exposed changed
internal temporary numbering. Broader targeted checks then caught plain positional
callback labels affecting nested function-type compatibility and doubled explicit
constructor type arguments. These were corrected and tested on the VM and JS;
the generic-method golden changed only internal identifiers. The last parser change
rejects a variadic default with E503 instead of silently accepting forbidden syntax.
The final full run passed all 726 tests on fixed compiler/test sources.
Superseded runners were explicitly terminated after stdin interrupts left them
running; only the final stable log supplies the full-suite result.
Readiness inventory, keyword catalog sync and `git diff --check` passed.

Known limits are explicit: direct named-default calls retain their legacy positional
exception; imported/stored optional positional gaps, mixed optional groups, lambda
forms and general computed constructors still need follow-up. Rule QUDS-022 is
partial, not complete. No unobserved CI, Flutter engine/device or performance
certification is claimed.

---

# Generic interface defaults and lexical signature types — 2026-11-19

Base: `21f2538`. Handoff updated before implementation in
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
Contract: [QUDS_INTERFACE_DEFAULTS.md](QUDS_INTERFACE_DEFAULTS.md).

| Check | Observed result |
| --- | --- |
| Primary Quds suite | `dart run bin/quds.dart test test/quds_value_adapters.quds`: **35 declarations passed** |
| Focused adapter driver | `dart test test/quds_value_adapters_test.dart`: **9 passed in 15s**; final strengthened driver **9 passed in 16s** |
| Generic contracts | Owner specialization through inherited interfaces, method/owner/caller-alias binder collisions, dependent `U: T` bounds and stable repeated references |
| Provider lexical signatures | User class and alias, record and callback defaults resolve in the declaring provider; mutable generic results retain their qualification |
| Negative bound | `copy<String>` under `T: num` rejects with E300 at consumer line 4 |
| Generated Dart | Deterministic golden; generated entry analyzes; actual VM and JavaScript/Node agree on **106 output lines** |
| Cache ABI v4 | Valid-checksum v3 provider has generic interface bridge/resolver definitions removed; actual `quds run` rebuilds and prints `7:9`, `11`, `70`, `6`, `true` |
| Final package format | `dart format .`: **101 files, zero changes** |
| Final analysis | `dart analyze`: **No issues found** |
| Documentation example | Actual cross-library `quds run /tmp/quds-generic-interface-example/main.quds`: `7`, `true`, `Quds` |
| Full suite | `dart test`: **705 passed, zero failures or skips, in 10m07s** |

Compiler source remained fixed during the full run. Afterwards, the cache regression
was narrowed to the newly introduced generic interface protocol and its actual
execution; the bound diagnostic assertion was tightened to E300. The adapter driver
passed all 9 tests again in 16s for those harness changes.

Generic owners have fresh resolver binders; implementation forwarding plans freshen
method binders before simultaneous substitution. Provider alias/native type bindings
remain lexical, and function/record labels are not substituted as type identifiers.
The inferred generic function pattern protects its own binders from caller aliases.
Existing readonly/privacy/omission and exactly-once default semantics stay active.

Unions/intersections, full parameter-form parity, foreign Dart implementors,
expanded parts/cycles/conditional-export certification, new resolver debugger-frame
projection and performance certification remain separate work. This is not full
certification of all 115 decisions. No remote CI or device result is claimed.

---

# Interface computed-default bridges — 2026-11-19

Base: `6beeeac`. Handoff updated before implementation in
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
Contract: [QUDS_INTERFACE_DEFAULTS.md](QUDS_INTERFACE_DEFAULTS.md).

| Check | Observed result |
| --- | --- |
| Primary Quds suite | 30 declarations; provider-private defaults, inheritance, multiple contracts, stable equality, readonly, live getters, null/missing, nullable short-circuit, failure before body, method generics and native alias hygiene |
| Focused parser/semantics/value/readonly regressions | 129 passed in 27s |
| Generated Dart | Updated deterministic golden; generated entry analyzed; actual VM and JavaScript/Node agree on 93 output lines |
| Existing generic-interface path | A generic declaring interface still executes without claiming the new identity guarantee |
| Readonly rejection | A mutating implementation of a readonly interface contract remains rejected at Quds source coordinates |
| Cache ABI v3 | A valid-checksum v2 provider has interface bridge/resolver definitions removed; actual quds run rebuilds it and prints `7:9`, `11`, `70` |
| Final adapter driver after import cleanup | 8 passed in 15s |
| Final package format | 101 files; zero changes |
| Final analysis | No issues found |
| Documentation example | Actual `quds run /tmp/quds-interface-example/main.quds`: `70`, `40`, `true` |
| Full suite | **704 passed, zero failures or skips, in 9m42s** |

The interface provider resolves defaults into a typed record; implementing members
forward to the original virtual body. Reserved packet names avoid shadowing a Dart
alias such as `values`. Provider-qualified parent/mixin lookup repairs inherited
method metadata rather than treating an optional method as a required function.

An unnecessary direct import in the test driver was removed after analysis reported
it as an info; the same symbols are exported by quds_lang.dart. Compiler source
remained fixed during the full run. Analysis is clean after that harness cleanup;
the adapter driver was rerun successfully after the full suite.

Readiness inventory regenerated/checked; keyword catalog sync and `git diff --check` passed.
No unobserved remote CI or physical-device result is claimed.

The slice deliberately excludes generic declaring interfaces and provider-specific
signature types. They retain their old source acceptance and lowering. Foreign Dart
implementors, broader export/part cases, resolver debugger frames and performance
are not certified by these local compiler results.

---

# Imported concrete method defaults — 2026-11-19

Base: `35d41c5`. Handoff updated before coding in
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
Contract: [QUDS_PROVIDER_DEFAULTS.md](QUDS_PROVIDER_DEFAULTS.md).

| Check | Observed result |
| --- | --- |
| Primary Quds suite | 22 declarations; imported private fields/helpers and Dart alias, class/method generic defaults, static/inherited owners, virtual dispatch, readonly/nullable references and direct calls |
| Focused parser/semantics/value/readonly drivers | 128 passed in 28s |
| Generated Dart | Golden updated; entry analysis passed; actual VM and JavaScript/Node agree on 60 lines |
| Visibility | Consumer access to the provider's private field and method remains rejected at consumer Quds coordinates |
| Nullable calls | Inferred nullable result; null short-circuits before supplied argument expressions and defaults |
| ABI upgrade | v1 cache keeps valid output checksums after method bridge definitions are removed; actual `quds run` rebuilds and prints `7:9` and `11` under v2 |
| Final package format | 101 files; zero changes |
| Final static analysis | No issues found |
| Documentation example | Actual `quds run /tmp/quds-import-method-example/main.quds`: `true`, `11`, `Quds`, `12`, `7` |
| Full suite | **703 passed, zero failures or skips, in 9m33s** |

Readiness inventory regenerated/checked; keyword sync and `git diff --check` passed.
No unobserved remote CI or physical-device result is claimed.

Imported method bodies/defaults are analyzed under their provider library scope
and active privacy context, with context restoration. This fixes missing private
fields and Dart aliases without granting consumer access to private members.
A readonly generic field read remains readonly; the fixture's unconstrained T
copy uses an ordinary method rather than erasing that qualification.

Bridge names include declaring-owner identity. Proxies implement the same members;
base defaults survive an override while the body still dispatches virtually.
Interfaces, protected/private exported bridges, non-class owner kinds, SDK methods
and unsupported parameter/default shapes remain outside this ABI slice.

---

# Provider-owned default bridges — 2026-11-19

Base: `f42d8ce`. Handoff updated before implementation in
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
Contract: [QUDS_PROVIDER_DEFAULTS.md](QUDS_PROVIDER_DEFAULTS.md).

| Check | Observed result |
| --- | --- |
| Primary Quds suite | 18 declarations; private provider helper and Dart alias, prefix/unprefixed/show/re-export identity, explicit/contextual generics, null/missing, async targets and direct calls |
| Focused parser/semantics/value/readonly drivers | 127 passed in 25s |
| Final adapter driver | 7 passed in 13s; includes source visibility/type rejection and legacy-ABI dependency repair |
| Generated Dart | Golden updated; generated entry analyzed; actual VM and JavaScript/Node agree on 45 lines including async and direct provider calls |
| Final source formatting | 101 files; zero changes |
| Final source analysis | No issues found |
| Documentation example | Actual `quds run /tmp/quds-provider-example/main.quds`: `7:9`, `12:12`, `true` |
| Provider compiler full suite before cache epoch | 702 passed, zero failures/skips in 9m36s |
| Final full suite including cache epoch | **703 passed, zero failures or skips, in 10m06s** |

The final cache change records `provider-defaults-v1` in generated artifacts.
Both build and warm-run cache checks reject older epochs. The regression removes
provider bridge functions and updates its output checksum to remain valid, then
removes the ABI marker. Actual `quds run` repairs the provider automatically and
prints `7:9`. This proves ABI migration independently of corruption detection.

Every eligible public provider declaration emits its ABI bridge even without a
local reference. Names depend on the source signature, not compiler-local names
or checkout paths. Combinators follow the imported/exported library's functions;
a relative CLI source path is normalized before looking up that library.
Direct calls capture supplied arguments in source order before entering the bridge.

A subsequent full attempt exposed SDK sections entering this local-provider ABI
path: the math-foundations generated Dart referenced a bridge absent from its SDK
bundle. SDK program source files are now excluded using the loaded SDK entries,
including aliases for the same source. `dart test test/math_foundations_test.dart
test/quds_value_adapters_test.dart --reporter expanded` passed all 7 tests in 9s
on the corrected source, including VM/JavaScript for both suites.

An early full run was interrupted to extend the correction to direct calls;
only the fresh run on the final source is reported as the complete result.
Provider methods, interfaces, inferred return metadata, SDK sections and complex
parameter/default forms remain outside this slice. No complete rule certification
or unobserved remote/device result is claimed.

---

# Concrete default method bridges — 2026-11-19

Base: `81a5287`. Handoff updated before implementation in
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
Contract: [QUDS_METHOD_VALUES.md](QUDS_METHOD_VALUES.md).

| Check | Observed result |
| --- | --- |
| Primary Quds suite | 15 declarations passed; same/different receivers, live fields, generic/static/inherited/nullable methods, readonly proxies, overriding defaults and interface fallback |
| Focused value/readonly drivers | 80 passed in 24s |
| Final adapter driver | 5 passed in 6s; includes E307 rejection of a mutating default method through readonly |
| Dart output | New deterministic golden; analysis; actual VM and JavaScript/Node agree on 30 lines |
| Static analysis | No issues found |
| Final package format | 101 files; zero changes |
| Documentation example | Actual `quds run /tmp/quds-method-bridge-example.quds`: `true`, `2`, `5` |
| Full compiler suite | **701 passed, zero failures or skips, in 9m27s** |

Bridge names retain their declaring owner, so an override cannot replace the
selected base default. Proxies implement private bridges as well as original
methods. Static adapters no longer try to capture a Type as an instance. Direct
method defaults that read fields now use the captured receiver.

Readiness inventory regenerated and checked; keyword catalog sync and
`git diff --check` passed. These local results do not claim an unobserved remote
CI or device session.

Imported/interface and default-plus-intersection adapters retain their earlier
closure lowering. Their repeated-reference identity is not certified here.
No new parameter syntax or relaxation of readonly/private/protected is introduced.

---

# Default value adapter correction — 2026-11-19

Base: `e7d4aa0`. Handoff was updated before implementation in
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).

- Reproduced invalid generated Dart when an omitted default referred to an earlier
  omitted default. Sequential typed locals now resolve defaults exactly once.
- A private omission token distinguishes explicit `missing` and null from omission.
- Stored default slots are named optional, following spec 1.2. The previous
  optional-positional adapter was an implementation conflict. Direct-call matching
  and complete required-named/bracket metadata are separate unfinished work.
- Same-file function bridges preserve repeated reference equality, including
  explicit/contextual generic specialization. Method/import adapters still use
  closures and do not yet have the same identity guarantee.

| Check | Observed result |
| --- | --- |
| Focused value drivers | 72 passed in 17s after named-slot and bridge changes |
| Final adapter driver | 4 passed in 6s; primary Quds suite has 10 declarations |
| New Quds regressions | Earlier defaults, fresh per-call evaluation, supplied-before-default order, explicit null/missing, reference equality and failing default before body |
| Generated output | Deterministic compilation; Dart analysis; actual VM and JavaScript/Node agree on 17 lines |
| Documentation example | Actual `quds run /tmp/quds-default-doc.quds`: `33`, `44`, `true` |
| Package formatting | 101 files, zero changes on final format check |
| Static analysis | `dart analyze`: no issues found |
| Readiness/catalog/whitespace | Inventory regenerated and checked; keyword sync and `git diff --check` passed |
| Final full suite | **700 passed, zero failures or skips, in 9m55s** |

An additional self-referencing default exposed an adapter being expanded again
while its named bridge was being emitted. Bridge declaration lowering is now an
explicit call-local option, so taking a nested reference uses the existing bridge.
The regression executes on VM/JavaScript. The initial full run was interrupted
at 289 passing tests to apply that correction; interrupted tests are not claimed
as a completed result. The fresh full run uses the final source.

The earlier local uncommitted adapter implementation is preserved in Git stash;
this correction is applied to the other agent's merged source, not overlaid onto
it. No environment publication or pub.dev release is part of this change.

---

# Compiler validation — latest 2026-11-18

## Windows portable line endings and import paths — 2026-11-18

`portable (windows-latest)` failed on `91f1ba7` and on this branch for the same
reasons. Golden files checked out with `\r\n`, and
`test/target_platform_test.dart` compared a forward-slash temp path with the
compiler's backslash dependency. `.gitattributes` now checks text out as LF.
The portable golden, stdout, and path comparisons also ignore a carriage return
or separator difference. Ubuntu and macOS portable jobs were already green.
On commit `2ba4643`, CI completed with no failing checks. `portable
(windows-latest)` succeeded and finished at 22:04 Asia/Gaza, as did
`portable (ubuntu-latest)`, `test`, and `flutter-engine`. One macOS portable
run succeeded and the duplicate run was cancelled. Run:
https://github.com/MohammedAsaadAsaad/quds_lang/actions/runs/44386812148


## Quds value adapters, imported overloads, and deferred imports — 2026-11-18

This batch is the cloud-agent work on `cursor/language-completion-b792`, cut from
`91f1ba7`. Review it from [LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
Contracts: [QUDS_FUNCTION_VALUES.md](QUDS_FUNCTION_VALUES.md) and
[QUDS_METHOD_VALUES.md](QUDS_METHOD_VALUES.md). Spec 1.2 is unchanged. No rule
was marked complete.

| Check | Observed result |
| --- | --- |
| Quds adapter suite | **5 declarations passed**: default omission versus explicit null, variadic pack/spread, intersection and generic method/extension/import values, a zero-argument readonly result guard, deferred `loadLibrary` |
| Negative adapter cases | Non-deferred `loadLibrary` is E300; a deferred import without a prefix is rejected; mutating a guarded readonly result is E307; a required parameter after a default stays E910 |
| Focused value regressions | **71 passed** across adapter, Quds function, Quds method, and native function value drivers |
| Generated Dart | Adapter web program analyzed; VM and JavaScript/Node agreed. Function-value golden now includes `choose$1` and the other public overload aliases. Inherited static calls emit the declaring type |
| Conversion aliases | The first full run missed `$QudsCast…` public aliases because conversion functions were skipped. Restoring unique-name aliases made `test/conversions_test.dart` and `test/export_cast_test.dart` pass |
| `dart analyze` | No issues found |
| Package format | `dart format --output=none --set-exit-if-changed lib test bin tool examples editors`: 100 files, zero pending changes |
| Final full suite | **698 passed; 1 failed; 5m35s** |
| Inventory and catalogs | `tool/audit_language.py --check`, `tool/sync_keyword_docs.py --check`, academy `tool/sync_keywords.py --check`, and `git diff --check` passed |

The single full-suite failure is `quds create flutter writes the app in quds`.
Generated Flutter types use a `_qNative…` prefix, so the source does not contain
the literal `extends StatelessWidget`. The same assertion fails on unmodified
`91f1ba7` in this environment. It is not a regression of this batch, and this
run is not a fully green suite.

Default, variadic, and intersection adapters apply when a function or method is
stored. Direct calls still fill defaults at the call site. A required or variadic
parameter after a default, a readonly result guard on a method with parameters,
class method overloads, full constraint solving, polymorphic callbacks,
parent-constructor synthesis, editor refactoring, a real device Flutter session,
and certification of the `needs_certification` rules remain open.


## Quds bound/static generic method values — 2026-11-18

## Quds bound/static generic method values — 2026-11-18

Handoff updated before coding: [LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).
Contract and limits: [QUDS_METHOD_VALUES.md](QUDS_METHOD_VALUES.md).

| Check | Observed result |
| --- | --- |
| Primary Quds suite | **5 declarations passed**: receiver once, class/method scopes and inheritance, static/import/private/protected/interface dispatch, nullable/Future values and readonly aliases |
| Negative conformance | **20 cases plus readonly-this escape** verify bounds/types, static/instance misuse, nullable access, private/protected access, readonly writes/return erasure and adapter rejections |
| Focused method/function/native/generic/readonly regressions | **121 passed in 24s** |
| Generated Dart | Golden deterministic; entry analysis passed; imported provider staged; actual VM and JavaScript/Node agreed on 19 output lines |
| Qualified static regression | Imported class prefix emitted once; direct static call and method value executed |
| Qualified static isolate regression | Reproduced an unchecked MemberAccess-to-Identifier cast; replaced with owner reference lookup; actual primary-suite VM isolate returned 14 |
| Documentation example | Actual `quds run` printed `3`, `Quds`, `4` |
| `dart format .` | 100 files; zero changes |
| `dart analyze` | No issues found |
| Final full suite | **700 passed; zero failures; zero skips in 10m40s** |
| Readiness/whitespace | Inventory regenerated and checked; `git diff --check` passed |

The initial full run was interrupted after the additional qualified-static
isolate regression exposed a dependent code path. A fresh complete run uses the
corrected source; the interrupted run is not claimed as a passing result.

Required positional methods retain their declaring owner's generic arguments,
method-parameter shadowing, visibility and readonly checks. Nullable generic
method values share the existing single receiver capture. Transitive readonly
result adapters, defaults/variadics/intersections, extension values, method
overloads and inherited-static owner lowering remain explicitly limited.

CI adds the primary method suite directly and the driver to its portable subset.
This configures Windows/macOS coverage; no unobserved remote success or actual
Flutter engine execution is claimed.


## Quds generic function values and local overload contexts — 2026-11-18

Active handoff updated before implementation:
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md). Contract and examples:
[QUDS_FUNCTION_VALUES.md](QUDS_FUNCTION_VALUES.md).

| Check | Observed result |
| --- | --- |
| Primary Quds suite | **5 declarations passed**: explicit/contextual generic values, callback contexts, local overload selection, explicit-arity selection, single imports and once-only argument evaluation |
| Negative conformance | **14 cases** reject ambiguous/missing overload contexts with E311, unresolved single generic values with E302, invalid bounds/types with E300 and unsupported default/variadic adapters with E910 |
| Focused Quds/native/method/parser/semantics regressions | **124 passed in 14s** |
| Dart output | Deterministic golden matched; generated entry analyzed, imported helper staged; actual VM and JavaScript/Node agreed on 14 output lines |
| Forward/async/import behavior | Forward local generic function return inference, Future-valued references and a prefixed imported generic provider executed successfully |
| Documentation example | Actual `quds run` printed `3`, `4`, `integer` |
| `dart format .` | 99 files; zero changes |
| `dart analyze` | No issues found |
| Full compiler suite | **677 passed; zero failures; zero skips in 9m48s** |
| Readiness and whitespace | 115-rule inventory regenerated/checked; `git diff --check` passed |

CI now lists the primary native/Quds function suites directly and includes the
new driver in its portable subset. These are configuration changes, not observed
remote Windows/macOS run results.

The selected reference uses the declaration's generated name without modifying
the global overload group. Two compatible candidates remain E311; no candidate
is selected merely because it appears first. Explicit arguments are checked
before context selection. Direct-call overload resolution remains on its existing
path. The approved `name<Type>` and expected function-type syntax are preserved.

The certified slice has required positional parameters. Generic/overloaded
computed-default, variadic, intersection and class-method adapters, imported
overload registration/export naming, provider-inferred return metadata and full
constraint solving remain work. See the contract for the exact limits. No full
QUDS-024/045/085 certification or actual Flutter engine run is claimed.


## Contextual native generic function values — 2026-11-18

Handoff updated before coding: [LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md).

| Check | Observed result |
| --- | --- |
| Primary Quds suite | **13 declarations passed**: explicit and contextual values, checked bounds, required/optional/named callbacks, label reordering, nullable methods and Future results |
| Focused parser/semantics/native/nullability regressions | **120 passed in 18s** |
| Generated Dart | Deterministic golden matched; analysis passed; actual VM and JavaScript/Node agreed on 24 output lines |
| Hygiene and variance | Caller alias `T = String` did not capture native T; broader result context kept the inferred input type; incompatible narrowing was rejected |
| Negative cases | Missing context remains E910; an undetermined formal in a function context reports E302; conflicts, wrong forms, bad bounds, nullable misuse and readonly receivers rejected at Quds spans |
| Documentation example | Actual `quds run`: `(int, int) -> int = math.max` printed `7` without explicit type arguments |
| `dart format .` | 98 files; zero changes |
| `dart analyze` | No issues found |
| Full compiler suite | **661 passed; zero failures; zero skips in 9m44s** |
| Readiness inventory and whitespace | Regenerated, checked, and `git diff --check` passed |

Inferred arguments are emitted explicitly in Dart and use the same nullable
receiver-capture path as explicit instantiation. Native formal names are
freshened so inference cannot resolve them through caller aliases. Parameter
constraints are gathered first; return context fills unresolved parameters and
the final specialized signature must satisfy function subtyping and all bounds.

This remains conservative structural inference. Full mixed-variance constraint
solving, recursive instantiate-to-bound, polymorphic callback types and Quds
function/overload specialization are unfinished. Explicit type arguments remain
available. No complete language-rule certification or actual Flutter engine
execution is claimed by these compiler tests.


## Explicit native generic function values — 2026-11-18

The active handoff was updated before implementation in
[LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md); older handoffs link to it.

| Check | Observed result |
| --- | --- |
| Primary Quds suite | **10 declarations passed**, including explicit top-level/prefixed/static/bound values, nested type arguments, optional/named specialization, class bounds and nullable receivers |
| Focused parser/semantics/native regressions | **93 passed in 23s** |
| Generated Dart | Deterministic golden matched; Dart analysis passed; VM and JavaScript/Node agreed on all 15 output lines |
| Documentation example | Actual `quds run` of `math.max<int>` printed `7` |
| Invalid specializations | Arity/bound violations, non-generic targets, getter-returned ordinary functions, wrong arguments and incompatible binding annotations rejected at Quds source coordinates |
| Full compiler suite | **653 passed; zero failures; zero skips in 10m03s** |
| `dart analyze` | No issues found |
| Format/audit/diff | Changed files formatted; 115-rule inventory regenerated and checked; diff whitespace check passed |

Dart rejects direct instantiation of a nullable generic function value. The
emitter captures the nullable receiver once and instantiates its non-null bound
method in the selected arm. Both null and present receivers execute in Quds;
the generated nullable-method program also analyzes and runs on VM and JS.
An initial full run began before the final getter-target guard was added and
reported that newly added rejection against the earlier compiled library. It was
stopped and replaced with a fresh full run of the final compiler. The focused
93-test run already verified that guard.

Bare native generic values, polymorphic callback types and explicit Quds
function/overload specialization remain limited; this does not certify all
function-type rules or Dart parity. No actual Flutter engine run is claimed.


## Optional/named native function values — 2026-11-18

- Primary Quds suite expanded to eight declarations, with omission/null,
  bound methods, native callbacks, reduced compatible signatures and exactly-once
  callee/argument evaluation in source order.
- Focused parser/semantics/native-generic/value suite: **86 passed in 15s**.
- Full `dart test --reporter expanded`: **645 passed, one golden mismatch in
  10m17s**. The new function-value call path added unnecessary parentheses to
  existing identifier calls. Preserved the previous rendering rather than
  rewriting the existing golden.
- After that correction, `dart test test/function_nullability_test.dart
  test/native_function_values_test.dart --reporter expanded`: **37 passed in
  10s**, including the previously failing deterministic golden, real Dart
  analysis and VM/JavaScript execution. The complete suite was not rerun after
  this rendering-only correction.
- `dart analyze`: no issues; `dart format .`: 98 files, zero changes before
  the correction; changed emitter formatted afterward. Readiness audit and
  `git diff --check` passed.
- Generic native function values and complete Quds declaration/lambda optional
  parameter parity are not claimed. Type-level defaults describe optionality;
  native declaration defaults remain authoritative at runtime.


## Language readiness, target environments and Flutter tooling — 2026-11-18

Working plan: [LANGUAGE_READINESS_AR.md](LANGUAGE_READINESS_AR.md). Inventory:
[LANGUAGE_READINESS.md](LANGUAGE_READINESS.md). No full Dart-parity or 115-rule
certification claim is made by this milestone.

| Check | Observed result |
| --- | --- |
| `dart pub get --enforce-lockfile` | Passed with Dart 3.13.7; lockfile unchanged |
| `dart format .` | 98 files; zero changes |
| `dart analyze` | No issues found |
| `python3 tool/audit_language.py --check` | Exactly 115 decisions indexed; manifest, evidence paths and generated inventory consistent |
| `dart run bin/quds.dart test test/native_function_values.quds` | **4 Quds declarations passed**: required function/static values, captured receiver once, generic-class substitution and null-aware method values |
| Focused feature suite | **16 passed in 1m03s**: native values, target selection, project CLI and F5 integration |
| Final native/target/F5 focused rerun | **10 passed in 12s**, including readonly E307 and Flutter UI target flags |
| Final F5 imported-web breakpoint regression | **2 passed in 6s**; initial and refreshed maps used the selected web graph |
| Generated native-value program | Dart analysis passed; actual VM and JavaScript/Node execution agreed: `2`, `12`, `4`, `1` |
| Conditional dependency program | Actual VM and JavaScript execution agreed on `web`; deliberately invalid inactive dependency was not loaded |
| Flutter platform command tests | Real Quds compiled; simulated Flutter verified APK/web/Linux flags, custom appbundle target and native exit 17 |
| F5 protocol integration | Separate DAP peer verified saved imports, reload/restart, internal response filtering, original error paths, preserved output, recovery and mapped breakpoints |
| VS Code command check | `node --check editors/vscode/extension.js` and `node test/editor/vscode_hot_updates.cjs` passed |
| Full compiler suite | **634 passed; zero failures; zero skips in 9m54s** |
| `git diff --check` | Passed |

These protocol tests do **not** claim real Flutter engine/device hot reload,
state retention or native debugger variable presentation. Official engine
artifacts were unavailable locally (the previously confirmed network response was
403). The new Actions jobs configure portable Linux/Windows/macOS checks and an
actual Flutter Academy widget/web build, but no remote success is claimed:
`gh run list` returned `Forbidden` from GitHub's API in this environment. Native
Android/iOS/desktop artifacts and signing still need their real host toolchains.
No environment or pub.dev package was published.

Required-positional native function/method values are a verified slice. Generic,
optional and named function values, richer callback shapes, deferred libraries,
project-wide refactorings and the remaining release gates are still tracked as
unfinished. Target-aware loading fixes existing approved syntax rather than
changing it. Without an explicit browser device the CLI assumes native Flutter;
LSP target-context selection and interactive device auto-detection remain limits.

## Generic class inheritance and Quds module staging — L3.2c — 2026-11-16

Contract, examples and limits: [GENERIC_INHERITANCE.md](GENERIC_INHERITANCE.md).

| Check | Observed result |
| --- | --- |
| Baseline reproductions | Generic inherited constructor fields failed E500; private writes emitted the wrong Dart name; an inherited static field shifted constructor argument labels |
| Primary Quds inheritance suites | **13 declarations passed**, including two prefixed cross-file cases |
| New inheritance runner | **28 passed**: primary suites, 20 invalid type/constructor/override cases, five visibility rejections, original span and Dart golden/backend execution |
| Multi-file Quds runner regressions | Shared SDK identity and relative Dart helper passed; staged `quds analyze` passed; private part helper passed; no source-side generated Dart files |
| Combined focused check | **108 passed**, including previous nullability, constraints, collections/interfaces and test-discovery regressions |
| Dart golden | Exact deterministic `generic_inheritance.dart.txt` output matched; generated program analyzed without issues |
| VM + JavaScript/Node | Quds fixture passed both with marker `GENERIC INHERITANCE OK`; source-order arguments evaluated once; private writes and static-field layout exercised |
| `dart pub get` | Passed |
| Final format/analyze | 46 Dart files; zero format changes; analyze reports no issues |
| Final `dart test --reporter expanded` | **409 passed; zero failures; zero skips** in 8m29s |
| `git diff --check` | Passed |

The checker and emitter share specialized inherited field views. Generic scopes,
parent signatures and member spellings survive constructor/property/override
analysis. Explicit super initializing formals select named or positional Dart
forwarding according to the parent. Fixed metadata excludes static/event/lazy
fields from constructor argument positions.

Multi-file test coverage exposed missing dependency output, SDK imports used
only in a generic type annotation, bare relative `.dart` normalization/binding,
part directive order and internal symbol collisions between parts. The staging
helper re-emits AST directives into a shared temporary module tree and rebuilds
source maps; no regex-only transpilation is introduced.

Intermediate focused failures were corrected, including missing context for
empty expression/getter results. One intermediate full run was intentionally
interrupted to add the verified static-field layout regression. Its interrupted
tests are not reported as completed validation. The final stable run above is
authoritative. No syntax redesign, math API addition or complete generic/Dart
inheritance parity is claimed; remaining cases are listed in the contract.


## Collection inference and generic interface contracts — L3.2b — 2026-11-16

Contract, examples and remaining limitations:
[COLLECTION_INFERENCE_INTERFACES.md](COLLECTION_INFERENCE_INTERFACES.md).

| Check | Observed result |
| --- | --- |
| Baseline probes | Map<K,V> inference and List-to-Iterable<T> inference failed with E500; an instantiated interface implementation failed with E700 |
| Primary Quds suites | **22 declarations passed**: 16 collection cases and six interface cases |
| New focused runner | **29 passed**: primary suites, 26 rejected programs, original diagnostic spans, deterministic golden and backend execution |
| Combined focused check with L3.1/L3.2a runners | **73 passed**, including all previous nullability/constraint cases |
| Generated Dart | Exact `collection_interfaces.dart.txt` golden matched; `dart analyze --fatal-infos` passed |
| Dart VM and JavaScript/Node | Quds fixture passed on both with marker `COLLECTION INTERFACES OK`; argument side effects remained once and in source order |
| `dart pub get` | Passed; dependency constraints retained |
| Isolated debugger regression | One passed, zero skips; no debugger timing fix claimed |
| Final `dart format .` | 45 files; zero pending changes |
| Final `dart analyze` | No issues |
| Final `dart test --reporter expanded` | **378 passed; zero failures; one skip** in 7m54s. The skipped debugger case passed separately on the final tree |
| `git diff --check` | Passed |

Inference uses shared structural type traversal and per-candidate evidence, with
post-substitution compatibility and bound checks. Mutable collection invariance
is maintained through generic calls. Expected context reaches nested Map values
and empty collection/return blocks. Substitution is simultaneous and preserves
nullable function/result boundaries. The emitter retains inferred function
arguments and instantiated inherited interface contracts.

The first focused regression run caught a new failure in explicit dependent
calls from L3.2a. Supplying the known explicit substitution to the same candidate
checker fixed it; the combined focused run passed all 71 tests before the two additional getter
regressions; the final focused run above passed 73.
The backend fixture also exposed unsupported `return map:` parsing; the existing
literal syntax now works there and receives declared return context.
The first full run finished with 375 passes, one failure and one skip. The
failure exposed null rejected against a concrete nullable parameter in the new
matcher; it now accepts the nullable shell without inventing inner generic
evidence. A new Quds declaration covers this, the original language test passed
in isolation, and the 71 focused tests passed again. The skipped debugger test
reported empty stackFrames after retries and passed in isolation. A subsequent
full run was deliberately interrupted to add two getter-kind rejections (a
write-only property and a method used as a function-valued getter). That
interrupted run is not a completed validation. The final stable run in the
table is authoritative; no fix to the debugger timing race is claimed.
No approved syntax was redesigned. Generic interface methods and the broader
inference/variance/external-type cases listed in the contract remain outside
this delivery; L3.2 is not declared complete.


## Generic argument constraints — L3.2a — 2026-11-16

The first part of L3.2 checks Quds generic applications, without claiming all
inference/interface work is complete. Contract and limits:
[GENERIC_CONSTRAINTS.md](GENERIC_CONSTRAINTS.md). Agent continuation plan:
[LANGUAGE_NEXT_STAGE_HANDOFF_AR.md](LANGUAGE_NEXT_STAGE_HANDOFF_AR.md).

| Check | Observed result |
| --- | --- |
| Baseline probes | Incorrect arity and invalid numeric bounds in annotations were accepted; a valid dependent bound was rejected; a nullable implementing type incorrectly satisfied a nonnullable interface bound |
| Primary `quds test test/generic_constraints.quds` | **Nine declarations passed**: explicit/inferred and dependent constructor bounds, explicit generic functions, forwarding bound evidence, nested fields, numeric/nullable/interface bounds |
| Final `dart test test/generic_constraints_test.dart --reporter expanded` | **25 passed**: primary Quds runner, 22 invalid programs, original diagnostic spans, deterministic golden and backend integration |
| Dart golden + analysis | Exact output matched `test/goldens/generic_constraints.dart.txt`; generated program passed `dart analyze --fatal-infos` |
| Dart VM + JavaScript/Node | Quds fixture executed on both with marker `GENERIC CONSTRAINTS OK`; explicit type arguments and once-only argument order retained |
| `dart pub get` | Passed; dependency constraints retained |
| Final `dart format .` | 44 files; zero pending changes |
| Final `dart analyze` | No issues |
| Final `dart test --reporter expanded` | **350 passed; zero failures; zero skips** in 7m29s |
| `git diff --check` | Passed |

The shared checker validates argument count/types and substitutes dependent
bounds for annotations, explicit functions and explicit/inferred constructors.
Bound evidence is scoped, explicit function arguments seed result inference,
and explicit arguments survive Dart emission. Interface inheritance no longer
discards whole-value nullability during compatibility checks.

An initial complete-project run was intentionally interrupted to add the
confirmed nullable-interface regression and fix. Its interrupted tests are not
reported as a completed validation; the final stable run above is authoritative.
No syntax redesign or math API additions are included. Map/callback inference,
generic interface inheritance/substitution and external metadata remain future
L3.2 work; L3.3/3.4 also remain open.


## Function type nullability and composition — 2026-11-16

First implementation package from
[LANGUAGE_NEXT_STAGE_HANDOFF_AR.md](LANGUAGE_NEXT_STAGE_HANDOFF_AR.md).
Contracts and remaining scope: [FUNCTION_NULLABILITY.md](FUNCTION_NULLABILITY.md).

| Check | Observed result |
| --- | --- |
| Baseline reproduction | `((int) -> int?)?` combined with a fallback callback failed with E300 before the fix; the same program now executes |
| Primary `quds test test/function_nullability.quds` | **16 declarations passed**, covering callback/result null layers, aliases, promotion, fallback, assertions, null assignment, higher-order functions, nested collections, records, variance and evaluation order |
| `dart test test/function_nullability_test.dart --reporter expanded` | **19 passed**: Quds runner, 15 rejected programs, independent test promotion scopes, original diagnostic spans, golden output plus backend execution |
| Generated Dart golden | Exact deterministic output matched `test/goldens/function_nullability.dart.txt`; generated program analyzed with `--fatal-infos` without issues |
| Dart VM + JavaScript/Node | Quds fixture executed successfully on both; marker `FUNCTION NULLABILITY OK` |
| `dart pub get` | Passed; existing dependency constraints retained |
| `dart analyze` | No issues |
| `dart format .` | 43 Dart files; zero pending changes |
| Final `dart test --reporter expanded` | **325 passed; zero failures; zero skips** in 7m32s |
| `git diff --check` | Passed |

Shared structural type operations distinguish top-level function nullability
from nullable results, ignore arrow `>` when splitting generic parameters,
and preserve record delimiters. Invocation and compatibility use these shapes;
Dart emission recursively renders function types nested in generic and record
types. Nullable results no longer satisfy nonnullable `Object`. Test declarations
save/clear/restore promotion facts so one test cannot make another's unsafe
callback call appear valid. Existing approved syntax remains unchanged.

This delivery does not complete all generic/readonly combinations or the math
expansion. The handoff identifies L3.2 as the next implementation package.


## Typed numeric storage in core — 2026-11-16

Added the native typed-storage section to `quds:core`, with the same names
available through `quds:core::typed`. Contracts and platform/precision limits:
[CORE_TYPED_STORAGE.md](CORE_TYPED_STORAGE.md).

| Check | Observed result |
| --- | --- |
| Primary Quds storage suites | **Nine declarations passed** across typed_storage.quds, typed_storage_prefix.quds and typed_storage_core.quds |
| Focused typed storage compiler/interoperability tests | **16 passed**, including unsafe writes, readonly capture, filtered exports, nominal identity, completion and hidden names |
| Dart VM + JavaScript/Node driver | Native storage smoke checks and readonly writes blocked across Dart/dynamic boundaries; mutable aliases remain visible |
| Compiler import-completion regression | Passed after adding the newly available core:: / typed suggestions to its exact expectation |
| Final `dart test --reporter expanded` | **306 passed; zero failures; zero skips** |
| `dart analyze` | No issues |
| Final format | 41 Dart files; zero pending changes |
| Embedded core synchronization | Byte-identical on repeat using `python3 tool/sync_sdk.py core` |
| `git diff --check` | Passed |

The SDK reuses Dart storage classes; numeric payloads are not copied by views.
Compiler integration reads concrete list element/interface metadata, retains
native identities across prefixes and generic type arguments, and protects
readonly native storage through captured references and runtime unmodifiable
views. Empty re-export filter intersections no longer expose all names.
An intermediate full run found a stale completion expectation (core previously
had no sections); the final stable run above passed with the new typed section
explicitly tested. No new syntax or reinterpretation of approved rules was
introduced. Strided views, broad generic Dart interop and backend performance
guarantees are outside this delivery.


## Language foundation: indexed mutation — 2026-11-16

This delivery strengthens the compiler before further math expansion.
Contracts, examples and remaining foundation work:
[LANGUAGE_NUMERIC_FOUNDATION.md](LANGUAGE_NUMERIC_FOUNDATION.md).

| Check | Observed result |
| --- | --- |
| Primary Quds indexed mutation suite | **10 declarations passed**: shared aliases, nested targets/order, negative indices, map keys/lookups, lazy defaults, compound operations, bounds, async, Result propagation and nullable nested literals |
| Focused `dart test test/index_assignment_test.dart --reporter expanded` | **16 passed**, including readonly method aliases, original diagnostic spans and 12 unsafe-access cases |
| Quds JavaScript fixture | Compiled with Dart to JavaScript and executed with Node; marker `INDEX WEB OK` |
| Final `dart test --reporter expanded` | **290 passed; zero failures; zero skips** |
| `dart analyze` | No issues |
| Final format | 40 Dart files; zero pending changes |
| `git diff --check` | Passed |

The typed AST now represents indexed assignment, with target/value traversal
for source maps and Result propagation. Receiver and indices are evaluated once;
indexed writes retain shared-object behavior, negative-list indexing, lazy
null-coalescing and compound-update order. Map reads correctly admit absent
keys, while writes check stored value types. Readonly instance-field views
cannot be made mutable by introducing a local alias inside a readonly method.
Contextual list element types support nullable/nested literals without relaxing
invariance of mutable collection references. Existing compiler and all math
suites passed on the final tree. No approved syntax was redesigned.


## Symbolic domain audit and imported sibling types — 2026-11-16

Public math functions remain **380**. Contracts and limitations:
[MATH_SYMBOLIC.md](MATH_SYMBOLIC.md).

| Check | Observed result |
| --- | --- |
| Primary Quds symbolic reference suite | **1475 exact cases passed on 59 polynomials**, including dense degrees 9, 12 and 16 at five rational points |
| Hand-written Quds symbolic suite | **Eight declarations passed**: singular domains, safe identities, zero powers, zero/cancelling polynomials, exactly-once nested calls and degree/work boundaries |
| Quds section import suite | Passed with hidden sibling BigFraction metadata and distinct caller BigFraction / private _PhaseState classes |
| Focused compiler regression suite | **Nine passed**: forty nested calls, hidden type rejection, foreign constructor types and existing compiler guards |
| Final `dart test --reporter expanded` | **274 passed; zero failures; zero skips** |
| `dart analyze` | No issues |
| Final `dart format --output=none --set-exit-if-changed .` | 39 files; zero pending changes |
| JavaScript + Node | Symbolic domain and zero-power checks passed alongside all existing math/graph interoperability checks |
| Repeated generators and SDK synchronization | Five artifacts byte-identical, including the supplemental Dart reference fixture |
| `git diff --check` | Passed |

The initial Quds repro showed `0*(1/x)` incorrectly simplify to zero, and the
documented degree-16 integration case incorrectly throw unsupported above
exponent 8. Zero products now require a conservative totality proof; powers up
to 16 honor the integration contract. Zero-power differentiation explicitly
avoids introducing a reciprocal singularity as that proof becomes stricter.

Class signatures are validated in the defining library, and foreign field /
constructor types retain nominal identity. Private SDK metadata uses internal
keys rather than colliding with caller private class names. Successful argument
checks are reused locally; competing overload trials retain their selected
contextual check. The new polynomial oracle only evaluates trees and compares
against Python Fraction formulas, rather than differentiating/integrating its
own expected AST.

An intermediate full run before adding the upper-degree references had 273
passes and the existing empty-frame debugger skip. The final stable tree above
passed all 274 tests without skips. No debugger retry or suppression was added;
this result does not establish that the pre-existing adapter race is fixed.


## Integrated binary64 / interval delivery — 2026-11-16

Integrated with `a5f1e6e`, preserving the concurrent library sections, flow,
matching and numbered-plan additions. Public math functions: **380**.
`RealInterval` supplements `OutwardInterval` in `interval::outward`;
its contract includes subnormals and unbounded endpoints. Neighbors are in
`scalar`. Details: [MATH_INTERVAL.md](MATH_INTERVAL.md).

| Check | Observed result |
| --- | --- |
| Full `dart test --reporter expanded --concurrency=2` | **268 passed; zero failures; one existing debugger skip** |
| Isolated debugger test | **One passed; zero skips**, using the exact name command recorded below |
| Primary interval references | **1138 passed** again on the integrated tree |
| Primary interval contracts | Five declarations passed |
| Primary section import test | Passed: prefixed sections, whole-library import, shared nominal types and both interval APIs |
| Focused compiler/parser tests | **18 passed**, including the added section identity and qualified parameter regressions |
| Concurrent plan / flow / matching Quds suites | Passed in the full run; plan marker 78, flow marker 58012 on 4164 networks; matching 5040 checks on 682 graphs |
| `dart analyze` | No issues |
| Final format | 39 Dart files; zero pending changes |
| JavaScript + Node | Math and graph checks passed, including binary64 and interval boundaries |
| Repeated generators and SDK synchronization | Four artifacts byte-identical |
| `git diff --check` | Passed |

Three compiler regressions were exposed by actual Quds imports and fixed:
SDK sections now share one parsed declaration identity, function lookahead
accepts qualified parameter types already supported by the type grammar, and
section `show` combinators retain classes referenced through prefixed types.
The debugger still skipped itself for empty frames in the parallel full run
and passed alone; no suppression was added and that race is not claimed fixed.


## Binary64 neighbors and outward-rounded intervals — pre-integration run 2026-11-16

Added `nextUp`, `nextDown`, `ulp`, `realInterval` and `RealInterval`.
The integrated SDK has **380** public top-level functions; this table records
the pre-integration run. A post-integration result will be recorded above it. Contracts and limitations:
[MATH_INTERVAL.md](MATH_INTERVAL.md).

| Check | Observed result |
| --- | --- |
| Primary `quds test test/math_interval_reference.quds` | **1138 reference cases passed**, using independent Python nextafter/ulp and Fraction extrema |
| Primary `quds test test/math_interval.quds` | **Five declarations passed**: IEEE boundaries, rounded decimal operations, unbounded reals, underflow/overflow and domain rejection |
| `dart analyze` | No issues |
| `dart format --output=none --set-exit-if-changed .` | 39 Dart files; zero changes |
| Full `dart test --reporter expanded` | **260 passed; zero failures; one skipped debugger integration test** |
| Isolated skipped debugger test | **One passed; zero skips** with `dart test test/compiler_test.dart --name 'quds debug stops on the quds line' --reporter expanded` |
| JavaScript + Node | Neighbor limits, signed zero, ULP, interval arithmetic and underflow/overflow checks passed with existing math/graph smoke suites |
| Regeneration | Embedded SDK, interval references, numerical references and API inventory byte-identical on repeat |
| `git diff --check` | Passed |

The pre-existing debugger test skipped itself in the parallel full run because
the Dart debug adapter returned an empty stack after its built-in retries.
It passed when rerun alone. No retry or suppression was added and this run does
not establish that the existing debugger race is fixed. No math test skipped.



## Numbered plan items 3–15

Public math functions: **376**. Contracts: [MATH_PLAN.md](MATH_PLAN.md) and [MATH_CONTRACTS.md](MATH_CONTRACTS.md).

| Check | Observed result |
| --- | --- |
| Quds plan suite | **78 expects, zero failures**, marker `QUDS PLAN CHECKS=78 FAILURES=0` |
| Hessian | `x*x*y` at `(2, 3)` is `[[6, 4], [4, 0]]`; `HyperDual.sqrt` at 0 throws |
| Phase I | The nonnegative example is value 12 at `[4, 0]`; a negative empty program throws `linearProgramPhase is infeasible` |
| Reverse mode | Same `[12, 4]` gradient as forward mode, from one callback |
| Exact reference | **1199 checks, zero failures** after renaming the local parameter that shadowed `decimal` |
| `dart analyze` | No issues |
| `dart test` | **264 passed, zero failures, zero skips** |

## Integer flow and bipartite matching — B4

Added `FlowEdge`, `MaximumFlow`, `maximumFlow`, `MatchEdge`, `Matching`, and
`maximumMatching` in `graph::flow` and `graph::matching`. Public math functions:
**326**. Contracts: [MATH_FLOW.md](MATH_FLOW.md).

| Check | Observed result |
| --- | --- |
| Quds flow oracle | **58012 checks on 4164 networks**, minimum cut by subset enumeration |
| Quds matching oracle | **5040 checks on 682 graphs**, maximum size by subset enumeration |
| Section import and completion | `use quds:math::graph` sees the flow, and `graph::` offers `flow`, `matching`, and `weighted` |
| `dart analyze` | No issues |
| `dart test` | **262 passed, 1 skipped, zero failures**. The skip is the existing debugger case after `debug adapter returned no stack frames after retries` |

## Exact planar geometry — C3

Added six public functions: `binaryFraction`, `orientation2D`,
`segmentsIntersect`, `polygonSignedAreaExact`, `pointInPolygon`, `convexHull`.
The SDK now has **324** public top-level functions. Contracts, exact binary64
input interpretation and exclusions: [MATH_GEOMETRY.md](MATH_GEOMETRY.md).

| Check | Observed result |
| --- | --- |
| Quds geometry references | **738 cases passed**, independently generated with Python Fraction, rational segment/ray intersections and Jarvis hulls |
| Hand-written Quds geometry suite | **Six declarations passed**, including subnormal/large coordinates, degenerate segments, winding, ownership and nonfinite rejection |
| Compiler regression suite | Six tests passed; List/Set implement Iterable with the same element type; element widening remains rejected |
| Final format | 39 Dart files; zero changes |
| `dart analyze` | No issues |
| Final `dart test --reporter expanded` | **259 passed; zero failures; zero skips** |
| JavaScript + Node | Exact binary fraction, subnormal orientation, hull, area and containment smoke checks passed |

The Quds tests exposed a missing collection interface compatibility rule, fixed
without relaxing generic element equality. The direct generated-Dart smoke
caller supplies the explicit containment boundary flag, as required by the
backend calling convention for Quds default arguments.


## Forward AD, gradients and Jacobians — C1 / first part of C2

Added `Dual`, `dualConstant`, `dualVariable`, `evaluateDual`, `autoDerivative`,
`autoGradient` and `autoJacobian`. Public math functions: **318**.
Contracts and limitations: [MATH_AUTODIFF.md](MATH_AUTODIFF.md).

| Check | Observed result |
| --- | --- |
| Quds analytic references | **598 cases**, each checking value and tangent against mpmath at 400 digits |
| Hand-written Quds AD suite | Nine declarations passed: arithmetic, domains, callback counts, empty dimensions, shape failures, ownership and extreme scales |
| Quds import/alias suites | Prefix and filtered imports passed, including inferred signature types and a distinct caller class/alias named Dual |
| Compiler rejection tests | Distinct nominal types, hidden source names and generated private aliases reject; existing list element compatibility remains enforced |
| `dart format --output=none --set-exit-if-changed .` | 39 Dart files; zero pending changes |
| `dart analyze` | No issues |
| Final `dart test --reporter expanded` | **256 passed; zero failures; zero skips** |
| JavaScript + Node | Scalar AD, gradient and Jacobian numeric checks passed with existing smoke tests |
| AD/numerical regeneration and embedded SDK synchronization | Byte-identical on repeat |
| `git diff --check` | Passed |

The compiler now distinguishes unary/binary operator arity and preserves nominal
identity in imported callback signatures. Inferred types hidden by source-level
show filters use private backend imports rather than leaking those source names.
Imported functions/classes resolve their own library bindings and do not let a
caller's alias redefine their mathematical types. Numeric generic widening was
not introduced: the existing List<int>-to-List<num> rejection remains tested.

An initial web smoke incorrectly compared the textual formatting of floating
numbers; it now checks numeric gradient components, since VM and JavaScript can
print integer-valued doubles differently. No numerical tolerance was weakened.

One intermediate parallel full run reported process status 113 for the old
1167-case numerical Quds suite after all its success markers, with empty stderr.
This could not be reproduced in isolation, in three concurrent runs, or in the
final complete rerun. The nonzero-status assertion remains unchanged; no retry
was added to tests or CI, and the cause is not established. This is retained as
an unresolved process anomaly rather than claimed as a fixed compiler defect.

AD thresholds are sampled-grid checks (relative 1e-10 plus three minimum-subnormal
units), not global error bounds. Hessians, reverse AD and tensors remain pending.


## Exact arithmetic foundation — delivery B3

Added BigInt interop/re-export, canonical rational arithmetic and seven exact
combinatorial functions. The SDK now has **312** public top-level functions;
all have Quds call sites. Contracts: [MATH_EXACT.md](MATH_EXACT.md).

| Check | Observed result |
| --- | --- |
| `quds test test/math_exact_reference.quds` | **1199 reference cases**, zero failures |
| `quds test test/math_exact.quds` | Six declarations passed: operators, normalization, raw/canonical distinction, imports, boundaries and errors |
| Compiler regressions | Typed BigInt result/operand checks and nullable rejection passed; filtered library imports retain their own BigInt types |
| `dart format --output=none --set-exit-if-changed .` | 39 Dart files; zero pending changes |
| `dart analyze` | No issues |
| `dart test --reporter expanded` | **251 passed; zero failures; zero skips** |
| JavaScript + Node | BigInt arithmetic, factorial/Fibonacci and rational normalization passed, alongside existing smoke checks |
| Reference generation and embedded SDK synchronization | Byte-identical on repeat |
| `git diff --check` | Passed |

Independent references use Python integers/Fraction, inclusion-exclusion for
Stirling, convolution for Catalan and Euler's pentagonal recurrence for integer
partitions. Running the committed Quds files requires no Python. Case counts
include multi-assertion rational normalization checks and are not a count of
independent mathematical theorems.

SDK operator metadata previously discarded Dart operators. They are now read and
statically checked, including the distinct unary/binary minus signatures; no
BigInt operation is hardcoded as dynamic. A filtered math import also exposed
validation of a private class's BigInt field against the caller rather than its
own library scope. The scope/type lookup was corrected, and the full rerun passed.
No syntax was added. Decimal, rigorous intervals and other roadmap work remain.


## Weighted graphs — delivery B2

Added `WeightedEdge`, `ShortestPaths`, `SpanningForest`, `dijkstra`, `bellmanFord`
and `minimumSpanningForest`. Public top-level math functions: **303**.
Contracts and numerical limits: [MATH_WEIGHTED_GRAPH.md](MATH_WEIGHTED_GRAPH.md).

| Check | Observed result |
| --- | --- |
| `quds test test/math_weighted_graph.quds` | Four declarations passed; **224,537 assertions on 4357 graphs** |
| Independent Quds oracles | Floyd–Warshall for paths/cycles, exhaustive edge subsets for forest optimality |
| `dart format .` / final format check | 39 Dart files; formatted; final check has zero changes |
| `dart analyze` | No issues |
| `dart test --reporter expanded` | **248 passed; zero failures; zero skips** |
| JavaScript + Node | Existing smoke plus all three weighted APIs and path reconstruction passed |
| Earlier Quds numerical/unweighted suites | Passed unchanged, including 1167 numerical and 151,457 unweighted graph assertions |
| `git diff --check` | Passed |

Input domains, deterministic ties, parallel edges, disconnected graphs, negative
cycles, malformed endpoints, NaN/infinity, sum overflow and invalid predecessor
chains have Quds tests. The exhaustive graph grid uses small exactly representable
integer weights; it is not a certificate for arbitrarily ill-conditioned real
weights. No language syntax changed. Other roadmap deliveries remain outstanding.


## Quds-first math tests and compiler corrections

Mathematical behavior is now tested primarily in `.quds` suites through
`quds test`. Dart/JavaScript numerical fixtures remain supplemental platform
checks. This policy is recorded in `AGENTS.md`, and CI executes the direct Quds
suites before `dart test`. The SDK still has 300 public top-level functions;
this change adds tests and compiler fixes, not new mathematical domains.

| Command/check | Observed outcome |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | 39 Dart files; zero pending formatting changes |
| `dart analyze` | No issues |
| Final `dart test --reporter expanded` | **247 passed; zero failures; zero skips** |
| `quds test test/math_reference.quds` | **1167 numerical reference checks**, zero failures |
| `quds test test/math_graph_reference.quds` | **151,457 assertions on 1695 graphs**, zero failures; separate 20,000-vertex chain passed |
| Primary math suites | All **51** test declarations passed across eight `.quds` files |
| Quds matcher/negative fixtures | Matcher suite passed with its intentional skipped assertions; four negative files each exited 65 with the expected diagnostic |
| Public API call inventory | **300/300** public functions have Quds call sites; generation rejects any missing Quds call |
| Supplemental Dart numerical fixture | Original 2591 checks unchanged and passed |
| Supplemental graph VM/JavaScript fixtures | Original 119,740 assertions on each platform passed |
| Generation/source synchronization | Byte-identical numerical fixtures/inventory and embedded SDK on repeat |

`test/math_quds_test.dart` launches seven Quds files and checks all parsed
completion titles and the numerical/graph execution markers. The eighth primary
file, `math_graph.quds`, is launched by the existing graph integration test.
Assertions and independent graph oracles live in Quds, not the Dart launcher.

The 1167 numerical values are the same independently generated values/tolerances
as their corresponding structured cases in the supplemental Dart fixture;
they are not additional independent reference inputs. Raw Dart-only expressions
(BigInt oracles and additional matrix/sampling checks) remain clearly supplemental.
Every API having a Quds call is traceability, not proof of every branch or domain.

### Defects corrected

- `quds test` no longer lets a source `main()` bypass test discovery. It uses a
  separate driver and a collision-free bridge inside the compiled suite.
- Files with no actual tests fail with `No tests found`; they cannot report an
  empty successful run. Legacy zero-argument test functions remain supported and
  asynchronous legacy tests are awaited in sequence.
- Any counted test failure produces exit 1. The old raw count made 256 failures
  appear successful on POSIX. Reproduction against the prior committed CLI gave
  exit 0 for an empty file, a test file with `main`, and 256 failing tests;
  all three regressions are now covered and fail correctly.
- The Quds graph oracle exposed missing parsing for approved `&`, `|`, `^`,
  `<<`, `>>`, `>>>` and `~`. Their precedence follows the existing specification;
  integer and eager boolean operations, const evaluation, invalid operands and
  exactly-once operand order have regressions. No new syntax was invented.
- `isFinite`, `isInfinite`, `isNaN`, `isNegative` and collection `single` have
  static getter shapes, mirrored in completion metadata.
- Imported Quds functions retain their own filtered/prefixed and unprefixed Dart
  imports even when the caller uses only `use quds:math as m show ...`.
- A filtered/prefixed `dart:core` import no longer removes core types needed by
  generated code. Source-level import filters remain checked by Quds semantics.
- Cross-library underscore fields/methods now receive `E206` in the original
  `.quds` coordinates, matching explicit `private`; same-library access remains
  valid. `protected` and the approved accessibility syntax were not redesigned.

One earlier full run found an existing negative fixture expecting `E200` for
`List<int> + Map<String, int>`. That is a type mismatch, which the diagnostic
specification assigns `E300`; the expected code was corrected precisely, with no
loosening to accept arbitrary errors. The final full rerun passed all 247 tests.


## Math expansion: unweighted graphs

Added eight graph functions to `quds:math`, bringing its top-level public
function inventory to **300**. The broader missing-domain roadmap is in
[MATH_EXPANSION_ROADMAP_AR.md](MATH_EXPANSION_ROADMAP_AR.md); only its first graph
package is implemented here. Contracts, complexity, examples and limits are in
[MATH_GRAPH.md](MATH_GRAPH.md). No language syntax or existing math API changed.

Validation used Dart 3.13.7 on Linux x64 and Node for JavaScript execution.

| Command/check | Observed outcome |
| --- | --- |
| Baseline `dart test` before additions | 228 passed; 1 existing debug test skipped |
| `dart format --output=none --set-exit-if-changed .` | 36 Dart files; zero changes |
| `dart analyze` | No issues |
| Final `dart test --reporter expanded` | **232 passed; zero failures; zero skips** |
| Isolated `dart test test/math_graph_test.dart --reporter expanded` | All 3 tests passed |
| Independent graph fixture, Dart VM | **119,740 checks; 1695 graphs; zero failures** |
| Same fixture, compiled JavaScript + Node | **119,740 checks; 1695 graphs; zero failures** |
| Deep-chain graph checks | 20,000 vertices; iterative SCC, BFS, path, topology, weak components and coloring passed on VM/JS |
| `dart run bin/quds.dart test test/math_graph.quds` | All 13 test declarations and enclosing group reported `ok` |
| Existing math, math-accuracy, prefix and matcher Quds suites | All commands exited 0; matcher suite retains its intentional skipped assertions |
| Four existing negative CLI fixtures | Each exited 65 and matched its intended diagnostic |
| `dart run bin/quds.dart run examples/math_graph.quds` | Five output lines match the documented example |
| Embedded source sync and numerical fixture/inventory regeneration | Byte-identical on repeat; original 2591 numerical reference cases unchanged |
| `git diff --check` | Passed |

The graph fixture exhausts all directed graphs with loops through 3 vertices and
all simple undirected graphs through 5 vertices, plus 64 fixed-seed multigraphs.
Its oracles use Floyd–Warshall and exhaustive coloring, independently of the
SDK's BFS, Kosaraju and Kahn implementations. Invalid-edge/endpoint checks require
the exact error strings, and the harness checks execution counts. These finite
checks do not establish correctness for every possible input or a measured
universal performance guarantee.

An intermediate full run failed only the source/embedded equality check because
SDK example comments were edited after that test process had loaded the older
embedded constant. With both files synchronized and frozen, the complete rerun
passed all 232 tests. No assertion was removed or relaxed. The baseline's debug
skip did not recur in the final run.


## Math audit and compiler prerequisites

Validated with Dart 3.13.7 on Linux x64. See [MATH_ACCURACY.md](MATH_ACCURACY.md)
for numerical contracts, reference versions, tolerances and limitations, and
[MATH_COVERAGE.md](MATH_COVERAGE.md) for the 292-function inventory.

| Command/check | Observed outcome |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | 35 files; zero changes |
| `dart analyze` | No issues |
| `dart test --reporter expanded` | 228 passed; 1 skipped; no failures |
| Frozen native math reference runner | 2591 checks; zero failures |
| JavaScript math smoke | `dart compile js` passed; Node printed `WEB MATH OK` |
| `quds test test/math.quds` | All 14 test declarations passed |
| `quds test test/math_accuracy.quds` | All 10 former failing regressions passed |
| Prefix and matcher suites | Passed; matcher fixture intentionally skips two assertions |
| Four negative CLI fixtures in CI | Each exited 65 with its expected diagnostic |
| Embedded SDK/source equality | Passed |
| Reference regeneration | Byte-identical fixture and coverage inventory |
| `git diff --check` | Passed |

The skipped full-suite test is the existing debug-adapter integration test:
`test/compiler_test.dart` skips after retrying a breakpoint stop that has no stack
frames. It is unrelated to the numerical changes; no numerical reference or math
regression was skipped. The precision and JavaScript test file also passed in
isolation (2 tests), and embedded math-source equality passed in isolation (1 test).
No debug-adapter fix or Flutter UI validation is claimed here.

The original review's ten failing math cases now pass. Frozen cases use SciPy,
NumPy, selected 80-digit mpmath anchors, analytic identities, exact integer
comparisons and fixed-seed sampling. The detailed document distinguishes sampled
accuracy from a global error guarantee and explains the corrected constant-sample
Kendall expectation and floating least-squares assertions.

---

The sections below are historical records from 2026-11-11. Their older test counts,
implementation gaps and environment-publication statements are retained as history,
not as claims about the current compiler or environment.

Validated on Linux x64 with Dart **3.13.7 (stable)**. The package's locked
development dependencies require Dart >=3.13.0. No Flutter installation, service,
or additional credential is required for this workflow.

## Original baseline

An archive of commit `e1760fc5fa0ce202241343a4cb2a5b48cc21e449` was checked in
`/tmp/quds-baseline`, separately from the working implementation:

| Command | Result |
| --- | --- |
| `dart pub get` | Passed; dependencies installed |
| `dart analyze` | Passed; no issues |
| `dart test` | Passed; **4 tests**, none skipped |
| `dart format --output=none --set-exit-if-changed .` | Exit 1; original lexer needed formatting |

Initial attempts were blocked by a missing SDK and then read-only per-user tool
cache paths. The SDK was obtained from the official digest-pinned Dart Docker
image, and approved tool initialization created Dart's per-user settings/cache.
These were environment prerequisites, not lexer test failures.

## Final implementation

Commands run from `/workspace/quds_lang`, with SDK/Pub activation documented in
`ENVIRONMENT.md`:

| Command | Result |
| --- | --- |
| `bash tool/setup_environment.sh` | Passed; package restore and CLI activation; repeated successfully |
| `dart pub get --enforce-lockfile` | Passed; no dependency changes |
| `dart format .` | Passed; compiler and tests formatted |
| `dart format --output=none --set-exit-if-changed .` | Passed; zero changed files |
| `dart analyze` | Passed; no issues |
| `dart test --reporter expanded` | Passed; **69 tests**, zero failures/skips |
| `quds build examples/sum.quds` | Passed; generated adjacent Dart |
| `dart analyze examples/sum.dart` | Passed; no issues |
| `dart examples/sum.dart` | Exit 0; exact expected output below |
| `git diff --check` | Passed |

```text
Total: 60
12
```

The suite exercises:

- Original lexer tests plus exact token/coordinate expectations, continuation
  layout, EOF dedents, Unicode/UTF-8 offsets, CRLF/CR, comments, longest-match
  operators and lexical errors.
- AST shape, precedence/associativity, functions, if/else-if, named blocks,
  malformed programs, original interpolation coordinates and oversized literals.
- Symbols, immutable/mutable assignment, explicit shadowing, lexical scope,
  parameter mutability, type/return checks, constant-initializer structure,
  named-argument validation and rejected overloads.
- Exact deterministic generated-Dart golden output.
- Real Dart analysis and execution for the acceptance program, strings and
  interpolation, scopes/Unicode/const, named argument side-effect order, and
  runtime boolean short circuiting/arithmetic.
- CLI subprocesses: build/rebuild, actual Dart execution, usage, missing input,
  original-source diagnostics, and preservation of user-owned/existing output.

Validation caught and corrected four test-harness references to the wrong class
for `resolvedExecutable`, an off-by-one token golden, and constant boolean test
inputs that caused Dart dead-code warnings. The short-circuit regression now
uses runtime boolean values and still asserts that the side-effecting branch
never executes. No failing assertions were disabled.

The initial lexer formatting issue is resolved in the new implementation.
GitHub Actions configuration was added for the same format/analyze/test workflow;
remote CI execution has not been observed.

## Const evaluation — 2026-11-11

Re-validated from the repository root on Linux x64 with Dart **3.13.7 (stable)**
after evaluating the supported `const` subset in Quds. The SDK used for this
run is the official `3.13.7` archive; the digest-pinned Docker extraction in
`ENVIRONMENT.md` was not repeated because Docker was not installed. No
application dependency or lockfile changed.

| Command | Result |
| --- | --- |
| `dart pub get --enforce-lockfile` | Passed; no dependency changes |
| `dart format --output=none --set-exit-if-changed .` | Passed; zero changed files |
| `dart analyze` | Passed; no issues |
| `dart test --reporter expanded` | Passed; **97 tests**, zero failures/skips |
| `quds build examples/sum.quds` | Passed; generated adjacent Dart |
| `dart analyze examples/sum.dart` | Passed; no issues |
| `dart examples/sum.dart` | Exit 0; exact output below |
| `git diff --check` | Passed |

```text
Total: 60
12
```

The added tests cover const arithmetic and wrapping, numeric and list equality,
references to earlier constants, short-circuit `and`/`or` (including a skipped
integer remainder and a rejected skipped call), original-source Q200/Q100
coordinates, unary `+` lowered once, runtime remainder left to Dart, and the
const CLI diagnostic. Generated const Dart is checked against
`test/goldens/const_eval.dart.txt` and executed. No assertion was disabled.

## Top-level const and bool conditions — 2026-11-11

Re-validated from the repository root on Linux x64 with Dart **3.13.7 (stable)**
after accepting top-level `const` bindings and lowering bool conditions so
generated Dart does not report `dead_code`. No dependency or lockfile changed.
`examples/sum.dart` was regenerated and stayed identical to its golden.

| Command | Result |
| --- | --- |
| `dart pub get --enforce-lockfile` | Passed; no dependency changes |
| `dart format --output=none --set-exit-if-changed .` | Passed; zero changed files |
| `dart analyze` | Passed; no issues |
| `dart test --reporter expanded` | Passed; **107 tests**, zero failures/skips |
| `dart run bin/quds.dart build examples/sum.quds` | Passed; generated adjacent Dart |
| `dart analyze examples/sum.dart` | Passed; no issues |
| `dart examples/sum.dart` | Exit 0; exact output below |
| `git diff --check` | Passed |

```text
Total: 60
12
```

The added tests cover top-level arithmetic, earlier-const references, a skipped
remainder, list equality, a const declared after `main`, original Q200
coordinates for remainder, forward reference, calls, module-scope `var`, and a
repeated name. Bool literals, const bools, and reassigned bool locals used in
`if`/`and`/`or` are executed under `dart analyze`. A taken runtime `true and
(1 % 0 == 0)` still throws Dart's integer remainder error. No assertion was
disabled.

## Limits and environment persistence

This validates MVP-0 plus const evaluation of that subset, including top-level
consts, not all 115 decisions. See `MVP_0.md` and `OPEN_QUESTIONS.md` for the
supported grammar, conservative typing, unresolved syntax, source-map gap, and
deferred language features. Const forms outside the MVP-0 expressions, inferred
const, const constructors, web numeric behavior, and the minimum signed 64-bit
literal spelling remain open.
Native execution was tested; web/Flutter, other Dart SDK versions, and published
snapshot restoration were not tested.

The current machine supports this development workflow. Reusable draft saves
for `install_script` and `start_skill` returned `INVALID_ARGUMENT`; persistence
could not be confirmed. Tested local setup/start instructions are retained in
`ENVIRONMENT.md` and `tool/setup_environment.sh`. Publication remains unperformed.
No extra network domain is needed for the verified Docker-based SDK route.

## 2026-11-16 — L3.2d generic interface methods

- `dart pub get`: succeeded with the existing dependency constraints.
- `dart format .`: 47 files, zero changes in the final pass.
- `dart analyze`: no issues.
- `dart test test/generic_methods_test.dart test/generic_inheritance_test.dart test/collection_interfaces_test.dart test/generic_constraints_test.dart test/function_nullability_test.dart --reporter expanded`: **130 passed**, zero failures/skips, 21 seconds.
- `dart test --reporter expanded`: **438 passed**, zero failures/skips, **7m54s**.
- New primary suite: 16 Quds declarations. Negative programs: 26. Golden Dart
  analyzed and executed on Dart VM and JavaScript/Node. See GENERIC_METHODS.md.
- Intermediate regression: stricter generic bounds exposed nullable lookup/removal
  signatures and concrete nullable inference. Both were corrected before the
  focused and full final runs. No failed result is being counted as a pass.

## 2026-11-16 — L3.3 readonly paths

- `dart format .`: 48 files (one formatting change before the final run).
- `dart analyze`: no issues.
- `dart test test/readonly_paths_test.dart test/index_assignment_test.dart test/typed_storage_test.dart test/generic_methods_test.dart --reporter expanded`: **82 passed**, zero failures/skips, 45 seconds.
- `dart test --reporter expanded`: **459 passed**, zero failures/skips, **7m56s**.
- Six new Quds declarations; negative programs and original spans; nested
  List/Map/nullable/dynamic/callback mutation attempts on VM and JavaScript.
- An earlier full run was interrupted to retain the standard scalar-leaf
  UnmodifiableListView path. It is not counted as a completed validation.
- See READONLY_PATHS.md for unsupported custom-class runtime proxies, mutable
  Set elements and Map keys. No universal runtime readonly guarantee is claimed.

## 2026-11-16 — L3.4 measured emitter and CLI phases

- `dart format .`: 50 files, zero changes. `dart analyze`: no issues.
- `dart test test/performance_test.dart test/quds_test_runner_test.dart --reporter expanded`: **9 passed**, zero failures/skips, 26 seconds.
- `dart test --reporter expanded`: **461 passed**, zero failures/skips, **4m38s**.
- Emitter-only benchmark: one warm-up/five samples per size. All output/mapping
  SHA-256 values identical before/after. 4000-function median: 3248090 → 18919 µs.
  Raw samples/tool metadata in bench/results, limits in PERFORMANCE_BASELINE.md.
- `dart run bin/quds.dart benchmark bench/language_workloads.quds --measure --warmup 1 --repeat 5`: passed VM assert parity and all AOT output checks; checksum
  `2181009417.0` then `99990000`. Metrics archived in bench/results.
- Intermediate AOT invocation placed --packages at the wrong CLI level; fixed
  before the successful workload, focused, and full runs. Imported nominal-type
  staging and duplicate generated imports were corrected and regression-tested.

## 2026-11-16 — finite math foundations and final verification

- `dart pub get`: succeeded with existing constraints.
- `dart format .`: 51 files, zero changes in final pass.
- `dart analyze`: no issues.
- `dart test test/math_foundations_test.dart test/math_quds_test.dart --name 'math foundations|math_foundations' --reporter expanded`: **4 passed**, zero failures/skips, **19 seconds**. Assertions are in Quds: 11 primary declarations, one frozen-reference declaration and one section-import declaration. The extra runner analyzes and executes an actual Quds consumer on VM and JavaScript/Node.
- `dart test --reporter expanded`: **465 passed**, zero failures/skips, **5m03s** on final source. An earlier 465-pass run (4m39s) preceded the generated-section diagnostic refinement and is not the final result.
- **686** exact-rational Quds references; **512** CNF families against independent truth masks; all 512 three-element relation matrices give 19 labelled orders; all 16 tetrahedron boundary-face subsets and known homology examples. These are internal mathematical cases, not additional top-level test-runner counts.
- All **389** public top-level math APIs have direct Quds call sites in the updated inventory. Embedded/source math text matches exactly. Python generator/profiler tools parse successfully. New Quds suites are also listed explicitly in CI; no remote CI result is claimed here.
- `python3 tool/profile_workload_memory.py`: six checksum-verified Linux AOT launches, first discarded. Five recorded peak-RSS samples: **12160 KiB** each. wait4 measures the child lifetime including fork/exec and possible launcher high-water-mark floor; this is not a Dart heap/allocation measurement. Archive: bench/results/language_workloads_memory.json.
- Numerical refinements before final runs: preserve the small Kalman prior weight when gain rounds to one; apply Markov normalization tolerance consistently on repeated transitions. Euler now rejects repeated abstract triangle faces; contract change is explicit in MATH_FOUNDATIONS.
- Compiler analysis exposed generated private bridge aliases and automatically selected nominal section names. Standalone private aliases are omitted, part bridges retained, and the generated automatic combinator warning is scoped away. Final source-map/part/module tests passed.
- Full remaining-domain status and limitations: MATH_20_DOMAIN_STATUS_AR and MATH_FOUNDATIONS. No claim of complete mathematics, all 115 language features, or arbitrary custom-class runtime readonly proxies.

## 2026-11-17 — heap profiling and readonly collection graphs

- Baseline: 50 focused readonly/generic-method tests passed before changes.
- `dart format .`: 56 files, zero changes in final pass (see formatter output).
- `dart analyze`: no issues.
- Focused readonly/native/generic/memory runners: **89 passed**, zero failures/skips, **29s**.
- `dart test --reporter expanded`: **471 passed, 1 skipped**, zero failures, **5m06s**. The pre-existing debugger race returned empty stackFrames under load.
- `dart test test/compiler_test.dart --name 'quds debug stops on the quds line' --reporter expanded`: **1 passed**, zero failures/skips, **3s**. This does not claim that the race is fixed.
- `dart run tool/profile_heap.dart`: checksum 213097200; 20000 retained HeapCell objects return to zero after release/GC; weak-cache removed graph elements return to zero. Cumulative typed allocation traces: 8 → 109 → 110 Float64List allocations and 0 → 0 → 100 Float64ArrayView allocations.
- `dart run tool/profile_web_memory.dart`: same checksum and six synchronous phase observations; V8 heap/process/backing-store statistics and allocation samples are archived separately. VM trace counts are not conflated with sampled V8 allocation sizes.
- Raw measurements: bench/results/heap_vm.json and heap_web.json. Definitions and known VM profiler initialization requirement are in HEAP_AND_READONLY_GRAPH.md.
- New primary Quds suite: four declarations, plus three negative programs and an actual cross-library Dart/JS guard driver. The memory workload itself is Quds.
- Generated-key lookup accepts readonly keys for reads without weakening insertion typing. Defaulted method bodies now retain declaring class scope.

## 2026-11-17 — readonly class guards, async qualifications and debugger startup

- `dart format .`, followed by `dart format --output=none --set-exit-if-changed .`:
  **59 files, zero remaining formatting changes**.
- `dart analyze`: **No issues found**.
- `dart run bin/quds.dart test test/readonly_classes.quds`: **8 declarations pass**,
  including generic/private cross-library parents, cycles, interface dispatch,
  lazy cache aliases, copyWith and value equality.
- `dart test test/readonly_classes_test.dart --reporter expanded`: **7 tests pass**,
  including real VM/JavaScript mutation attempts, asynchronous delivery,
  multi-directory CLI build, native-boundary diagnostics and artifact consistency.
- `dart test test/compiler_test.dart --name 'debug hides|quds debug stops'
  --reporter expanded`: **2 pass**. The real debugger test no longer skips empty
  frames. A DAP transcript identified duplicate startup entry/breakpoint stops;
  unrequested entry events are suppressed, explicit stopOnEntry remains visible.
- Final `dart test --reporter expanded`: **479 pass, zero skipped, zero failures**, 
  **6m10s**. Earlier diagnostic runs exposed missing bundle writes in old test
  drivers, a sealed-exhaustiveness conflict and nested async-qualification loss;
  those failures were fixed before this final source snapshot.
- `dart run tool/profile_heap.dart` and `dart run tool/profile_web_memory.dart`:
  both complete, checksum **213097200**. Updated raw results are committed under
  bench/results. VM HeapCell counts **0 → 20000 → 0**, and **0** after the weak
  graph removes an element whose readonly class proxy was actually accessed.
  Allocation counts remain Float64List **8 → 109 → 110**, plus **100** view
  allocations. V8 reports six phases; samples are estimates, not exact counts.

See READONLY_CLASSES.md for standalone runtime bundling, runtime guard metadata,
source identity versus Dart proxy identity, and explicit native/sealed/mixin
limits. This package does not claim all 115 language features are complete.

## 2026-11-17 — native Dart generic metadata and final language/memory gate

- `dart format --output=none --set-exit-if-changed .`: **62 files, zero changes**.
- `dart analyze`: **No issues found**.
- `dart run bin/quds.dart test test/dart_generics.quds`: **7 declarations pass**.
- `dart run bin/quds.dart test test/dart_generics_prefix.quds`: **1 declaration
  passes**, including one declaration reached through two export/import paths.
- `dart test test/dart_generics_test.dart --reporter expanded`: **22 pass**.
  This includes original-source diagnostic spans, rejected unsupported native
  signatures, nominal identity, a normalized deterministic golden and actual
  Dart analysis plus VM/JavaScript execution. Receiver/argument effects, await,
  Future results, implicit constructors and omitted-versus-null defaults are
  exercised by Quds programs.
- Final frozen-source `dart test --reporter expanded`: **501 pass, zero skipped,
  zero failures**, **5m59s**. The real breakpoint/locals/evaluate test passes.
- Repeated `dart run tool/profile_heap.dart` and
  `dart run tool/profile_web_memory.dart`: **both complete**, checksum
  **213097200**, refreshed raw JSON under bench/results. VM source HeapCell
  counts are **0 → 20000 → 0**, and **0** after removing the accessed readonly
  graph. Float64 allocation traces remain **8 → 109 → 110**, plus **100** views.
  V8 records all six phases; allocation samples remain estimates.
- `git diff --check`: clean.

DART_GENERIC_METADATA.md records the implemented direct-call subset and explicit
E910 limits. LANGUAGE_MEMORY_COMPLETION_AR.md closes the finite handoff plan;
it does not assert that all 115 language decisions or arbitrary Dart source
forms have complete implementation parity.

## 2026-11-17 — editor latency, completion coverage and Quds debugger mappings

- `dart format --output=none --set-exit-if-changed .`: **64 files, zero changes**.
- `dart analyze`: **No issues found**.
- `node --check editors/vscode/extension.js`: **passes**.
- `dart test test/editor_test.dart --reporter expanded`: **15 pass**, covering
  analysis artifacts/diagnostic parity, Quds/native generic specialization,
  generic SDK extensions, signature help, native argument names, indentation
  argument blocks, Arabic names, private imported members, backend-name hiding,
  helper/const-comment source maps, qualified debugger frame names, a mocked
  VS Code signature provider and startup analysis for multiple documents.
- Real DAP tests pass: simple Quds breakpoint/locals/evaluate, and a program that
  stops on Quds line 7, expands Arabic-named list `القيم`, expands its Payload
  element, reads field `value` as **41**, and evaluates `القيم[0].value` as **41**.
  Nested references and Watch evaluateName expressions retain source names;
  user string values are not rewritten.
- Final frozen-source `dart test --reporter expanded`: **517 pass, zero skipped,
  zero failures**, **5m37s**.
- `dart run tool/profile_editor.dart`: **completes**. Fresh-process samples on
  the math import workload: full compilation **3687.790ms**, editor analysis
  **1627.528ms**. Cached completion: **623 items**, **100 samples**, p50
  **3.237ms**, p95 **6.984ms**, maximum **19.134ms**, including JSON encoding.
  Profiling ran concurrently with the full suite; startup timings are individual
  samples affected by CPU contention. Rendering, OS pipe transport and starting
  the Dart process are excluded. Raw data: bench/results/editor_latency.json.
- `git diff --check`: clean.

EDITOR_PERFORMANCE_DEBUG_AR.md documents the queue, diagnostic parity, coverage,
measurement scope and extension reload instructions. No approved language syntax
was changed. This is not a claim of complete Flutter/Dart analyzer parity or a
visual VS Code-host performance test.

## 2026-11-17 — augment stage 1

- `dart format .`: 66 files formatted; one changed during the gate.
- `dart analyze`: No issues found.
- `dart test test/augment_test.dart --reporter expanded`: 11 pass.
- `dart test --reporter expanded`: 528 pass, zero skipped/failing, 5m30s.
- Coverage includes Quds local/generic/part/native augmentation, imported
  extension visibility, negative structural cases, cross-part source mappings,
  generated Dart analysis, VM and JavaScript execution.
- `git diff --check`: clean.

## 2026-11-17 — class/augment conversions and exact Fraction casts

- `dart format --output=none --set-exit-if-changed .`: **68 files, zero changes**.
- `dart analyze`: **No issues found**.
- `dart test test/conversions_test.dart --reporter expanded`: **31 pass**, 1m02s
  in the final focused run (concurrent with an earlier full development run).
  Seven drivers execute **14 Quds tests** across local/imported/generic/native/
  part/math/external augmentation suites. Additional tests cover static rejection,
  source-coordinate ambiguity, unused duplicate declarations, deterministic Dart
  golden output, actual CLI builds and VM/JavaScript execution with Dart analysis.
- Actual SDK Fraction cases include int-to-Fraction contextual conversions,
  both operand orders, whole/non-whole/non-normalized fractions, zero denominator,
  platform minimum integers and VM overflow. The VM and JavaScript programs pass.
- `dart test test/memory_profiling_test.dart --reporter expanded`: **3 pass**,
  12s. The controller now waits for PauseStart and counts distinct workload pause
  locations from its own isolate. A deterministic replay/isolate regression is
  included alongside actual VM/Node retain/release/weak-cache measurements.
- Final frozen-source `dart test --reporter expanded`: **560 pass, zero skipped,
  zero failures**, **6m04s**. This includes all previous lexer/parser/compiler,
  math, memory, editor, debugger, interoperability and CLI test groups.
- VS Code syntax grammar JSON parses successfully.
- `git diff --check` and `git diff --cached --check`: clean.

A development run overlapping SDK source edits reported the embedded-source
comparison; an earlier full run also exposed a VM-service disconnect in the heap
profiler. The final gate above ran after SDK synchronization and the checkpoint
controller fix, without compiler/tool source edits during execution. No retries
were added to conceal profiler failures.

The owner-approved syntax amendment is recorded in QUDS_LANGUAGE_SPECIFICATION.md
and LANGUAGE_DECISIONS.md. AUGMENT_AND_CONVERSIONS_AR.md provides the Arabic
handoff, executable commands, examples and precise unsupported contexts. This
milestone does not claim complete implicit conversion inference for every
collection/callback/variadic form or external structural/static augmentation.

## 2026-11-17 — completion responsiveness as documents grow

- `dart format .`: **71 files**, one formatted during the gate.
- `dart analyze`: **No issues found**.
- `node --check editors/vscode/extension.js`: passes.
- `dart test test/editor_test.dart test/editor_growth_test.dart --reporter expanded`:
  **21 pass**, **7s**. Covers new symbols after repeated incomplete growing edits,
  truthful diagnostics, numbered receivers, Unicode/UTF-8/UTF-16/CRLF indexing,
  reused background semantic-token arrays for 5,000 bindings, continued analysis
  after a deep failed input, real stdio LSP traffic, and mocked VS Code request
  cancellation/timeout/late responses/stale versions/semantic refresh.
- Final frozen-source `dart test --reporter expanded`: **566 pass, zero skipped,
  zero failures**, **5m58s**, including compiler, math, memory, debugger and CLI
  regressions.
- Actual coordinate-conversion baseline from commit 6435682 on the generated
  5,000-binding workload: semantic-token computation **4626.412ms**. Indexed
  implementation: **68.124ms**, now computed in the analysis worker for live
  documents instead of blocking the input isolate.
- `node test/editor/lsp_growth.cjs /workspace/toolchains/dart/bin/dart`: passes.
  Real stdio, 10 samples, initial document approximately 10,000 lines: paired
  semantic-token/completion requests p50 **75.374ms**, p95 **178.727ms**, including
  pipe framing and JSON decoding. Last incomplete edit through background-ready
  diagnostics and member completion: **387.655ms**. These measurements exclude
  VS Code rendering and process startup; raw data and scope are recorded in
  bench/results/editor_growth.json.
- `git diff --check`: clean.

EDITOR_COMPLETION_GROWTH_AR.md records the reproduced quadratic paths, recovery,
worker/request handling and extension reload instructions. This supersedes use
of the earlier tiny-buffer benchmark as evidence for large-document behavior.
No approved language syntax changed and no visual VS Code-host latency claim
is made.

## 2026-11-17 — early colors and diagnostics without typing starvation

- `dart format .`: **73 files, zero changes**.
- `dart analyze`: **No issues found**.
- `node --check editors/vscode/extension.js`: passes.
- `dart test test/editor_diagnostics_test.dart test/editor_growth_test.dart test/editor_test.dart --reporter expanded`:
  **25 pass**, **9s**. New coverage verifies provisional AST colors before full
  semantic checking, actual E200 diagnostics before recovery completes, unchanged
  token projection through Unicode/multiline edits, diagnostics for two documents
  during sustained typing, virtual-clock maximum-debounce/client-close cleanup,
  and stage/version-aware semantic refresh. Existing real stdio growth coverage
  also exercises interleaved notifications/responses through serialized writes.
- Final frozen-source `dart test --reporter expanded`: **570 pass, zero skipped,
  zero failures**, **6m28s**, including compiler, math, memory, debugger, editor,
  native interoperability and CLI tests.
- `dart run tool/profile_diagnostics.dart`: completes. Compared with the protocol
  from 5f8b9c5, initial declaration colors for 1,000 bindings with quds:math are
  **65.322ms** versus **863.358ms**. First actual semantic error after editing:
  **391.292ms** versus **759.677ms**. For 5,000 bindings: first colors **305.358ms**
  versus **755.089ms**, first error **361.025ms** versus **499.985ms**.
- Continuous-typing sample: 21 updates, 60ms apart; **3 complete checks during
  typing**, versus **zero** with the previous trailing-only debounce. Publication
  still rejects obsolete versions; scheduling bounds do not guarantee analysis
  completion while a heavy prior job is running.
- Full-check latency is reported too: initial 5,000-binding check **900.382ms**
  versus **755.176ms**, math sample **983.922ms** versus **863.910ms**. The added
  syntax-color phase has a cost; no checks were removed to improve first paint.
- Raw single-sample data, timings and measurement limits:
  bench/results/editor_diagnostics.json. Includes LspSession/worker/debounce;
  excludes VS Code rendering and pipe transport. No universal latency guarantee.
- `git diff --check` and `git diff --cached --check`: clean.

EDITOR_DIAGNOSTICS_LATENCY_AR.md documents phases, token projection, truthful
error publication, serial stdio writes, reproductions and extension reloads.
The full compiler remains authoritative; provisional colors do not feed types
into completion and syntax success does not clear semantic errors. No approved
language syntax changed.

## 2026-11-17 — SDK re-exports, run/debug graph construction and cache repair

- Reproduced the user's exact source and missing some.dart/quds_math.dart errors
  on a new temporary package. The original program now runs and prints
  `test_lang_quds` and `Instance of 'Fraction'`.
- The reduced export-only example, including contextual `f: Fraction = 1` and
  explicit `1 to Fraction`, executes through the CLI and prints **1/1** and **1**.
- `dart test --reporter expanded`: **576 pass, zero skipped/failing**, **7m23s**.
  Includes the new Quds re-export driver, fresh CLI run with Dart analysis,
  SDK/error identity across directories, missing/damaged artifact repair,
  imported-body diagnostics, explicit/implicit conflict checks, and a fresh
  real DAP launch stopping at original Quds line 5.
- A cache-upgrade regression was added while that full run was in progress:
  `dart test test/export_cast_test.dart --plain-name 'rebuilding a dependency' --reporter expanded`:
  **1 pass**, **18s**. It first executes a valid older generated bundle/caller,
  then forces a dependency rebuild and verifies the cached caller is revalidated
  against the replacement SDK. The final cache revalidation change was covered
  by this targeted test rather than claiming it was part of the earlier full
  run's test discovery.
- `dart test test/export_cast_test.dart --plain-name 'fresh run builds dependencies' --reporter expanded`:
  **1 pass**, **28s** under concurrent full-suite load. Generated entry and nested
  module analyze without warnings; Fraction and ConversionError identities agree.
- After the final cache change, `dart format --output=none --set-exit-if-changed .`:
  **74 files, zero changes**; `dart analyze`: **No issues found**.
- `git diff --check`: clean.

SDK_EXPORT_RUN_DEBUG_AR.md explains why the user's import/export/constructor
syntax was valid, why the binding uses SDK implicit conversion rather than the
new explicit declaration, the reduced working example and duplicate-conversion
E310 behavior. No approved syntax or conversion precedence was redesigned.

## 2026-11-18 — English keyword reference and editor tooltips

The English guide was prepared and linked to the owner before editor changes.
`KEYWORD_REFERENCE.md` contains **111 entries** shared by keyword hover and
keyword/snippet completion. `KEYWORD_TOOLTIPS_IMPLEMENTATION.md` documents the
maintenance path, behavior, tests and limits.

Validation on Dart 3.13.7 / Node 24.22.1:

- `python3 tool/sync_keyword_docs.py --check`: pass; generated Markdown matches
  the guide and every parser `word(...)` spelling has an entry.
- `dart format .`: **76 files**; final formatting was applied before testing.
- `dart analyze`: **No issues found**.
- `dart test test/keyword_docs_test.dart --reporter expanded`: **11 pass**.
  Covers exact completion/hover Markdown, contextual identifiers and ordinary
  symbol fallback, UTF-16/safe suffix ranges, strings/comments/member exclusion,
  triple-string closure, malformed buffers and a 15,000-line buffer. All 110
  supported example fragments parse; the approved `deferred` example is checked
  for the current rejection and is explicitly labeled unsupported in its help.
- `node --check editors/vscode/extension.js`: pass.
- `node test/editor/vscode_keyword_docs.cjs`: **VSCODE KEYWORD DOCS OK**;
  Markdown/plain-text completion documentation is preserved without enabling
  Markdown trust.
- `dart test --reporter expanded`: **588 pass, zero failures/skips**, runner
  **6m50s**, wall **6m52.842s**. Includes actual LSP growth/diagnostic tests,
  Quds math conformance, compiler/CLI execution, conversion/import/debug
  regressions, memory tests, and the new keyword documentation tests.
- `git diff --check`: clean.

An earlier full run was intentionally interrupted to include a discovered
triple-string editor-scanner fix and its regression. The complete result above
is the subsequent run on the final code, not the interrupted run.

No approved syntax was redesigned. Hover recognition is conservative for
ambiguous contextual syntax. Keyword help uses bundled data and lexical scanning,
without compiling or loading SDK metadata on its request path. VS Code rendering
was tested through its adapter harness; a manual interactive editor session was
not performed. Update/reinstall the extension with `quds install`, then reload
the editor window to load both new client and server behavior.

## 2026-11-18 — Unquoted part module paths and local completion

The owner clarified that `part` and `part of` should use unquoted paths and offer
completion like `use`/`export`. The specification now uses `uri` rather than
requiring a string literal for `part`; PART_PATHS.md explains the clarification,
examples and compatibility. Existing quoted file paths remain literal.

- Unquoted part paths use import/export normalization: `src.details` becomes
  `src/details.quds`, and `^.owner` becomes `../owner.quds`. URI components such
  as `src.show` are read as paths rather than import combinators.
- Completion offers local Quds files/directories and `of `, supports parent
  traversal, and excludes self, SDK/package schemes and sections. URI completion
  does not invoke semantic compilation. LSP edit ranges are tested directly.
- Definition navigation follows the same bare/literal interpretation as parsing;
  formatting retains unquoted paths. Ownership and shared privacy are preserved.
- The English keyword reference and generated tooltip catalog now show
  unquoted `part`/`part of` examples.

Final verification on Dart 3.13.7:

- `dart format .`: **77 files**; final changes formatted before the full run.
- `dart analyze`: **No issues found**.
- `python3 tool/sync_keyword_docs.py --check`: pass.
- `dart test test/parts_paths_test.dart test/keyword_docs_test.dart --reporter expanded`:
  **20 pass**, **7s**. Nine part regressions cover normalization, missing paths,
  formatting, completion, actual LSP edits, definition navigation, mismatched
  ownership, executable Quds conformance, and a fresh CLI run with generated Dart
  analysis. The other eleven tests cover shared keyword documentation.
- The primary Quds suite `test/parts_paths.quds` imports a bare-path owner with a
  nested part and checks private-field access through their shared library.
- Fresh CLI execution in a `quds.yaml` project prints **7**; generated owner/part
  directives use matching Dart file paths and `dart analyze` exits **0**.
- `dart test --reporter expanded`: **597 pass, zero failures/skips**; runner
  **7m36s**, wall **7m37.897s**. Includes existing quoted-part compatibility,
  conversion/debug/CLI, editor-growth and Quds math suites.
- `git diff --check`: clean.

### Quds Academy and native pub/Flutter source interop (2026-11-18)

- `dart format .`: **84 files, zero changes** on final formatting check.
- `dart analyze`: **No issues found**.
- `dart test test/academy_interop_test.dart --reporter expanded`: **8 pass**,
  **18s**. Includes actual Dart execution of native package imports, part-owned
  types, generic function aliases, super formals, typed-data boundaries, fresh
  defaults, raw strings and nested constructor argument blocks.
- `python3 examples/flutter_app/quds_academy/tool/check_core.py`: **3 Quds suites
  pass** against actual pub `sqlite_plus` **0.1.14**, after Quds source formatting.
  Covers parameterized SQL/Unicode, duplicate completion, export/reopen, preference
  preservation, reset, all twelve lesson outputs and 111 bilingual keyword entries.
- `python3 examples/flutter_app/quds_academy/tool/sync_keywords.py --check`: pass.
- Source-only UI build against official Flutter stable source **ab291203**:
  all **4 Quds modules** generated. Dart analysis of generated `main.dart` found
  **zero errors**, one unused typed-data import warning and two informational
  deprecations in Flutter 3.50 (`material.dart` / `GlobalMaterialLocalizations`).
  The final source build with an explicit byte-image type annotation also passes;
  generated Dart still carries the redundant unprefixed typed-data import, so the
  final source analysis exits 2 with the same warning and two infos (zero errors).
- This source check uses actual SDK/API source and actual pub dependencies; it
  **does not run the Flutter engine**. Flutter pub resolution, widget tests, web
  build, browser rendering and screenshots remain **unverified** because the
  managed proxy returns **403** for `storage.googleapis.com`. The domain is saved
  in a configuration draft but not active in the runtime. No environment published.
- See `docs/QUDS_ACADEMY.md` and the application's README for continuation steps.
- `dart test --reporter expanded`: **605 pass, zero failures/skips**, runner
  **7m56s**. Final focused rerun after typed-data re-export correction: **8 pass,
  9s**; final root `dart analyze`: **No issues found**.

### Academy colored examples and categorized reference (2026-11-18)

- Added twelve bilingual purpose-oriented categories. All 111 keyword entries
  appear exactly once. Search supports the complete catalog from the overview
  and the selected category after navigation. Unsupported `deferred` remains
  explicitly identified; example fragments are identified as such.
- Quds code panels use selectable rich text with distinct lexical colors. The
  pure-Quds display scanner preserves original characters, including Unicode,
  escapes, raw/triple strings, line comments and nested block comments. It does
  not parse or execute user code. Interpolation keeps its surrounding string color.
- `python3 examples/flutter_app/quds_academy/tool/check_core.py`: **5 Quds suites
  pass**, including source reconstruction for every reference example, incomplete
  snippets, lexical distinctions, and exact category membership.
- `dart test test/academy_interop_test.dart --reporter expanded`: **8 pass**, **26s**.
  Extended native String coverage with actual Arabic and UTF-16 surrogate
  `codeUnitAt` execution. Its signature and completion entry were missing and
  are now registered; the approved syntax is unchanged.
- All **6 Quds UI/content modules** generate against real Flutter source APIs.
  Generated main Dart source analysis: **zero errors**, the existing unused
  unprefixed typed-data import warning and two Flutter 3.50 deprecation infos;
  exit **2**. This is source verification, not engine execution.
- Desktop and phone widget scenarios now cover category selection, filtered
  words, rich spans, Arabic and text scaling. They remain **unexecuted here**:
  the Flutter engine artifact download is unavailable. No visual/browser/device
  validation is claimed. The project owner separately reported the previous
  application version running successfully on their own setup.
- The first full suite exposed an existing test synchronization defect: the live
  completion test treated the early `quds/semanticTokensReady` notification as
  completed semantic analysis. It now waits for `publishDiagnostics` with
  `qudsAnalysisComplete: true` before editing. Completion content and the <200ms
  response requirement remain unchanged. The focused corrected test passes.
- The complete affected compiler test file was rerun after correcting that
  synchronization: `dart test test/compiler_test.dart --reporter expanded`:
  **70 pass, 3m40s**. No completion-content or latency assertion was removed.
- Supplementary web-target check: compile a Quds program importing the actual
  display scanner with `dart compile js`, then execute with Node. Result:
  **`Quds colors JS OK`**, preserving Arabic, keyword tokens and source text.
- Analysis of all six generated application modules (with generated SDK bundles
  resolved at their actual relative paths): **zero errors**, **3 warnings**
  (redundant typed-data imports and a non-null assertion), **2 deprecation infos**,
  exit **2**. These existing warnings are distinct from the clean compiler-root
  `dart analyze` result.
- Final `dart format .`: **84 files, zero changes**. Final compiler-root
  `dart analyze`: **No issues found**. Keyword synchronization check and
  `git diff --check`: pass.
- Full sweep `dart test --reporter expanded`: **604 pass, 1 failure**, **9m48s**.
  The sole failure is the synchronization issue described above; the entire
  affected **70-test file subsequently passes** with the correction. All other
  tests in that sweep passed, including executable Quds SDK/math conformance.
  A second full 605-test sweep was not performed after the test-only correction.

### Flutter save-to-reload development runner (2026-11-18)

- `quds run <entry.quds>` in a Flutter project now runs the official Flutter
  machine transport, monitors saved Quds sources and imported dependencies,
  preflights the whole graph, and requests `app.restart` with
  `fullRestart: false` only after a valid build. `R` requests a hot restart;
  repeated saves/startup updates are coalesced and serialized. Unchanged source
  compilations are cached against dependency content. Source maps are retained.
- Device arguments are forwarded after `--`; target/protocol/release/profile/
  no-hot overrides are rejected. Non-generated output is protected, with initial
  ownership errors retaining exit code **73**. Compilation failure does not end
  a running Flutter session or request a reload.
- `dart test --reporter expanded`: **608 pass, zero failures**, **7m37s**.
  Includes the existing primary Quds SDK/math suites and the new live-run tests.
- `dart test test/flutter_live_test.dart --reporter expanded`: **3 pass** in
  repeated focused checks. The fixtures compile actual Quds files, use actual
  subprocess IO and a simulated Flutter machine peer, and cover imported edits,
  error/recovery, no partial graph writes on compile failure, atomic replacement,
  new imports, startup queuing, overlapping saves, explicit restart, rejected
  updates/retry, device arguments and generated-file ownership. Final checks also
  exercise rejection of flags that bypass the generated target or live mode.
- Existing `quds run launches flutter with the generated target` regression:
  **1 pass**, **2s**, now expects `run --machine -t lib/quds_gen/main.dart`.
- Compiler-root `dart analyze`: **No issues found**. `dart format .` and
  `git diff --check` pass; the formatter now covers **86 files**.
- The final argument guard and startup-baseline refinements were additionally
  checked by the focused live-run suite after the full run. No language syntax
  changes are introduced.
- No Flutter engine/device execution is claimed: official engine artifact
  downloads remain unavailable in this managed environment. Protocol tests do
  not establish real widget state preservation or renderer behavior. The
  implementation is scoped to `quds run` / VS Code **Quds: Run**; the existing
  F5/debug-adapter path remains separate. See `docs/FLUTTER_LIVE_UPDATES.md`.

### Academy editor launch actions and compiler selection (2026-11-18)

- `dart test test/editor_actions_test.dart --reporter expanded`: **4 pass**,
  runner **under 1s**. The actual Academy entry parses in recovery mode with
  **zero parser errors**, including its nested named argument blocks. All three
  launch actions are available immediately with background analysis enabled.
- The same suite verifies actions despite missing packages/type errors and
  unrelated syntax errors, removes them when `main` is removed, and handles
  unopened files without resolving their imports.
- The Node fixture selects an external project's `quds_lang` compiler using
  absolute/relative package URIs and Unicode/space paths, rejects stale compiled
  executables in favor of current sources, reuses fresh executables, tolerates
  invalid package configs, and ignores obsolete CodeLens responses. Direct
  `node test/editor/vscode_actions.cjs`: **VSCODE ACTIONS OK**.
- `dart test test/editor_growth_test.dart test/editor_diagnostics_test.dart
  test/editor_test.dart --reporter expanded`: **25 pass**, **12s**, including
  actual LSP requests and existing VS Code request/diagnostic fixtures.
- `dart analyze`: **No issues found**. `dart format .`: **87 files, zero changes**.
  `node --check editors/vscode/extension.js` and `git diff --check`: pass.
- CodeLens now depends on current source syntax rather than successful semantic
  analysis. Analysis diagnostics remain enabled independently. VS Code refreshes
  actions after analysis, prefers the active document's compiler context, and
  uses source execution while stale executables rebuild in the background.
- The screenshot alone does not identify the user's installed server version.
  Current source parsing is verified; an outdated global/custom server remains
  a plausible explanation for its E100 diagnostics. Updating installed compiler
  and extension and reloading the window is documented in
  `docs/EDITOR_RUN_ACTIONS.md`. No desktop VS Code UI execution is claimed.
- `dart test --reporter expanded`: **612 pass, zero failures**, **7m24s**.
  Includes the new four action/compiler-selection regressions, existing live
  Flutter protocol tests, actual LSP/editor suites and Quds math conformance.

### Project CLI and native Dart tooltip previews (2026-11-18)

- `quds pub` forwards arbitrary native pub subcommands and arguments with inherited
  IO and exit status. Flutter SDK projects use Flutter pub; other projects use
  Dart pub. SDK detection uses parsed YAML and honors directory selection.
- `quds create .` delegates platform scaffolding to Flutter, preserves protected
  user/configuration files, updates Flutter dependencies with `yaml_edit`, removes
  only newly generated Dart starter files, and supports `--no-pub`.
- `quds run` discovers `lib/main.quds` / `main.quds`, accepts normal device/mode
  options and Quds targets, keeps debug hot reload, and delegates release/profile/
  no-hot sessions to ordinary Flutter execution. The previous separator spelling
  remains compatible. Flutter discovery now uses the portable PATH resolver.
- `dart test test/project_cli_test.dart test/flutter_live_test.dart
  test/dart_doc_preview_test.dart --reporter expanded`: **14 pass**, **1m28s**.
  Includes real offline Dart pub get/deps, simulated Flutter pub/scaffolding/modes,
  protected existing files and YAML flow maps, actual Quds hot-update protocol,
  executable Dart-versus-Quds preview equivalence, native `.of` metadata, worker
  JSON/Unicode transport and VS Code fallback/cache/native-only behavior.
- Final focused hover/fallback regressions: **2 pass**, under **1s**, including
  real LSP native-documentation tagging and removal of its internal marker.
- `dart test --reporter expanded`: **623 pass, zero failures**, **10m05s**.
  Includes existing primary Quds SDK/math conformance and actual editor/LSP suites.
- Compiler-root `dart analyze`: **No issues found**. Final `dart format .`:
  **92 files, zero changes**. JavaScript syntax and `git diff --check`: pass.
- An earlier sweep was stopped while diagnosing AST-parser-induced cold CLI
  startup cost. The final design isolates the Dart documentation parser in an
  optional, lazy editor worker. Normal CLI and LSP imports do not load it.
  `dart bin/quds.dart help`: **2.575s** in one source-start measurement;
  `dart compile exe bin/quds.dart -o .dart_tool/quds/quds-cli-review`: success;
  compiled `help`: **0.016s** in one local measurement (not an application-build
  latency guarantee). The compiled CLI also successfully launched the worker:
  **AOT documentation worker OK**.
- Final lazy-worker presentation check:
  `node test/editor/vscode_doc_preview.cjs`: **VSCODE DOC PREVIEW OK**. Ordinary
  documentation does not spawn the parser; cold native previews immediately keep
  the original and cache later results. Warm waits are bounded to 200ms. Unsupported
  Dart remains explicitly identified; source files and metadata stay unchanged.
- Platform scaffolding/run tests use a Flutter subprocess peer, not a Flutter
  engine. Actual native platform generation/build/release/device execution remains
  unverified in this managed environment. No environment publication occurred.
- Usage and limits: `docs/PROJECT_CLI.md`, `docs/DART_TOOLTIP_PREVIEWS.md` and the
  updated `docs/FLUTTER_LIVE_UPDATES.md`. No approved Quds syntax was redesigned.
