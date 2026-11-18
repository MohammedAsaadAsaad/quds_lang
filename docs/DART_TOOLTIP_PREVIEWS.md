# Dart examples displayed as Quds in native tooltips

Native Dart/Flutter signatures already have Quds-shaped parameter/return syntax;
they are now displayed in a Quds code fence as well. Native documentation retains
its original prose, links and source metadata. At hover presentation time, the
VS Code extension can replace fenced Dart examples with Quds previews.

The transformation is temporary. It does not edit SDK files, pub-cache files,
Dart source, generated code, saved documentation or definition navigation.
Quds-authored documentation is not routed through the native preview service.

## Conservative conversion

The optional worker parses Dart examples into Dart ASTs using `analyzer` and
prints a supported subset into Quds. The result must also pass the Quds lexer
and parser. It is not regex-only source transpilation and it does not execute
hovered code. Supported examples include ordinary typed functions, variables,
mutable/immutable bindings, calls and constructors, named arguments, properties,
strings/interpolation, ordinary lists, return/if/else, boolean/arithmetic and
conditional expressions, assignments and straightforward Future<T> async/await.
Async return annotations are translated to Quds's logical return type.

Complex classes, cascades, explicit const constructor expressions, comments whose
placement cannot be preserved, maps/sets needing block syntax, generics/default
parameter forms outside this subset and incomplete examples keep their original
Dart fences. Numeric convenience calls with unresolved receiver types also stay
Dart rather than guessing whether a custom method is a Quds getter. Preserved
examples have an explicit original-Dart note. Converted examples are marked as
translated for display; surrounding imports/declarations may still be required.
Inline API references and English prose are unchanged.

## Editor responsiveness

The Dart AST dependency is isolated in a persistent optional editor worker.
Normal compiler, pub, create, run and LSP startup do not import that library.
The parser is installed as a tooling dependency, but generated applications do
not import it.
The service starts on the first native Dart-example hover and warms up separately. A cold service immediately returns the original
tooltip and caches the converted result when ready; subsequent hovers can show
the preview. Warm requests wait at most 200ms before falling back. The UI never
waits for a full cold Dart parser startup. Old-document responses are discarded.

Conversion and pending/cache sizes are bounded. A failed or missing optional
service leaves original documentation usable. Compiler and language-server
commands remain functional without it. First-use source compilation of the
optional worker can take several seconds; no immediate cold-preview guarantee
is made. Reload the updated VS Code extension after `quds install` to activate
this presentation layer.

## Checks

Tests compare Dart execution with execution of the converted Quds for mutable
typed values, async calls, conditions, literal braces and interpolation. A native
`.of` hover fixture verifies its unchanged Dart source and metadata. Additional
checks cover fallback cases, real worker JSON/Unicode transport, cold-worker
fallback/cache behavior, native-only rendering and obsolete-buffer rejection.
This is a documentation preview, not a complete Dart-to-Quds migration tool.
