# Quds Academy implementation and continuation guide

The requested deliverable is `examples/flutter_app/quds_academy`: an animated,
responsive Arabic/English Flutter learning application written in Quds. See its
README for executable setup and validation commands.

## Scope

The application supplies twelve bilingual lessons, quizzes, curated executable
demonstrations, four navigation destinations, a searchable 111-keyword reference,
progress and preferences. SQL is written in Quds and uses the real pub package
`sqlite_plus` 0.1.14. Dart files are limited to platform byte persistence and build/
test integration. Bundled fonts include their upstream OFL licenses.

No approved language syntax was redesigned. UI code uses normal imports, classes,
functions, callbacks, prefix conditional expressions and nested named argument
blocks. Numeric conveniences retain the approved Quds getter syntax, e.g. `.round`.

## Compiler work exposed by this application

- Lex and parse approved raw single/triple string literals without interpolation.
- Treat `label` contextually and accept nested constructor argument blocks.
- Preserve fresh computed/collection defaults in synthesized constructors.
- Check terminal try/catch/finally paths and contextual default expression types.
- Join nullable callbacks and compatible branch result types.
- Bind native pub imports in imported Quds modules, with canonical package URIs
  and owning Dart library imports for declarations in parts.
- Preserve native generic ancestry and inherited getter signatures in Quds classes.
- Read Dart export filters, super formals, function aliases and embedded SDK source
  provenance. String delimiters inside Dart method bodies no longer truncate APIs.
- Merge project pub package resolution with compiler test-runner dependencies.
- Use one typed-data identity for signatures crossing native and Quds modules.

Regression coverage is in `test/academy_interop_test.dart`. These changes improve
real interoperation; they do not establish support for every possible Dart API or
claim that all 115 language rules have been implemented.

## Verification and continuation

Five executable Quds suites independently validate real SQL behavior, all lesson
demonstration results, bilingual keyword/category coverage and lossless syntax colors
without Flutter. The root
Dart suite runs compiler and SDK conformance, including existing Quds math suites.
Exact recorded results are in `docs/VALIDATION.md`.

An additional source-only check uses the actual official Flutter stable source
checkout and embedded Dart UI source, with real pub dependency sources. This can
check compilation against API declarations but cannot execute Flutter rendering.
It is explicitly supplementary and does not replace the normal Flutter SDK.

The environment proxy rejects engine downloads from `storage.googleapis.com`
with 403. The allowlist entry was saved to a configuration draft, not applied to
the runtime; no environment was published. The remaining release gate is to
apply network access through environment settings, install the official engine,
then run the app README's Flutter commands. Widget tests are provided but remain
unexecuted until that gate is available. Inspect desktop/mobile Arabic/English
screenshots, text scaling, keyboard focus, reduced motion, real browser storage
and any target native platform before asserting visual or platform readiness.

Keep changes incremental: fix any compiler regression with a reproducing Quds
case; do not replace the interface or SQL implementation with Dart to bypass it.

## Guided reference and syntax colors

The next UI iteration adds twelve purpose-oriented categories covering all 111
reference entries exactly once. The flow is category → word → explanation and
colored example, with a category return action and scoped bilingual search.
Conversion/augmentation, safe resources, concurrency, composition and reactive
state have dedicated categories, making advanced facilities discoverable alongside
basics. Existing unsupported markers remain visible; this is documentation
organization, not a change to approved language syntax or support status.

All code panels use `SelectableText.rich` with Quds-generated spans. The small
pure-Quds display scanner preserves the original characters, supports ordinary,
raw and triple strings, line and nested block comments, numeric and keyword
styles, and tolerates fragments. It is deliberately a presentation component,
not a second compiler/interpreter. Interpolation remains string-colored.

This exposed missing metadata for Dart's `String.codeUnitAt(int)`. Its actual
native signature is now registered in the language's string member surface and
completion list. Executable compiler regressions cover Arabic and UTF-16 surrogate
code units; no new Quds syntax was introduced.
