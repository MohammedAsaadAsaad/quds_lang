# Embedded Quds Interpreter & Code Editor Engine

Quds ships two pure-Dart embeddable libraries (**zero `dart:io` dependencies**, works natively on **Flutter Desktop, Android, iOS, Flutter Web, and Dart CLI/Server** without requiring a Dart SDK on the end user's device):

- `package:quds/interpreter.dart` — AST interpreter, persistent MATLAB-like workspace (`QudsSession`), execution policies & capability sandboxing (`QudsExecutionPolicy`, `QudsHostModule`), native AST debugger (`QudsDebugController`), and rich scientific / interactive geometry outputs (`quds:viz`).
- `package:quds/editor_engine.dart` — Resilient syntax & semantic highlighter, official Quds formatter (`formatQuds`), live syntax + policy-aware diagnostics with quick fixes, context-aware autocomplete (including live workspace, `quds:*` SDKs, `::sections`, `quds:viz`, and host modules), hover docs, signature help, outline, folding, and smart indentation helpers.

Neither library alters or impacts desktop IDE workflows (`quds lsp`, `quds debug`, `quds build`, or the VS Code extension).

---

## 1. Choosing an Execution Policy (`QudsExecutionPolicy`)

| Preset | Intended Use | Key Controls |
| --- | --- | --- |
| `QudsExecutionPolicy.strictSandbox()` | Calculators, educational sandboxes, untrusted formulas | Strict `maxSteps`, `timeout`, `maxCallDepth`, `maxCollectionLength`, `allowAsync: false`, safe pure-SDK allowlist only |
| `QudsExecutionPolicy.scientific()` | MATLAB/Jupyter-like scientific apps & geometry labs | Full `quds:math`, `quds:viz`, `quds:json`, `quds:collection`, `quds:async` + protective UI-safe limits |
| `QudsExecutionPolicy.systemBridge(capabilities: ...)` | Automation / host-integrated scripts accessing controlled system parts | Explicit `QudsCapability` grants + dynamic `onPermissionCheck` approval callback + `onCallIntercept` / `onStatementIntercept` |
| `QudsExecutionPolicy(...)` / `.copyWith(...)` | Custom domain rules | Mix any resource limit, language feature flag (`allowMutation`, `allowClasses`, `allowImports`), custom `importResolver`, and interceptors |

### Example: Capability-Gated Host Module

```dart
import 'package:quds/interpreter.dart';

final fsModule = QudsHostModule.builder('host:fs', description: 'Scoped files')
    .function(
      'readText',
      (pos, named, ctx) => readHostFile('${pos[0]}'),
      capability: 'fs.read',
      signature: 'readText(path: String) -> String',
      documentation: 'Reads a UTF-8 file inside an allowed workspace directory.',
    )
    .build();

final session = QudsSession(
  policy: QudsExecutionPolicy.systemBridge(
    capabilities: [QudsCapability.fileRead(allowedRoots: ['/workspace/data/'])],
    onPermissionCheck: (req) {
      final path = '${req.positionalArguments.first}';
      return path.startsWith('/workspace/data/')
          ? const QudsPermissionDecision.allow()
          : QudsPermissionDecision.deny('Access denied outside /workspace/data/');
    },
  ),
  hostModules: [fsModule],
);
```

---

## 2. Native Interactive Debugger (`QudsDebugController`)

Attach a `QudsDebugController` to any `QudsSession` for line breakpoints, conditional breakpoints (`condition: 'i == 5'`), hit counts, non-stopping logpoints (`logMessage`), `stepOver`, `stepInto`, `stepOut`, `pause`, `continueRun`, `stop`, automatic watch expressions, and live frame evaluation (`pause.evaluate('acc * 2')`):

```dart
final debugger = QudsDebugController();
debugger.setBreakpoints('sim.quds', const [
  QudsBreakpoint(file: 'sim.quds', line: 4, condition: 'err < 0.01'),
]);
debugger.setWatchExpressions(['err', 'iter']);

final session = QudsSession(
  policy: QudsExecutionPolicy.scientific(),
  debugger: debugger,
);

debugger.onPaused.listen((pause) async {
  final preview = await pause.evaluate('err * 100');
  print('Paused at ${pause.span}, locals=${pause.locals}, err%=$preview');
  debugger.stepOver();
});
```

---

## 3. Interactive Geometry & Scientific Visualizations (`quds:viz`)

`quds:viz` connects directly with `quds:math::vector` (`Vec2`) and `quds:math::geometry` (`polygonCentroid`, `triangulatePolygon`) and emits JSON-serializable `QudsOutput` models (`QudsGeometrySceneOutput`, `QudsPlot2DOutput`, `QudsTableOutput`, `QudsMatrixOutput`, `QudsTextOutput`) with built-in `.toSvg()` export.

When the user drags a handle or moves a slider in Flutter or Web, call `session.updateInteractiveInputs(...)` to recompute the geometry scene immediately:

```dart
final updated = await session.updateInteractiveInputs({
  'C': {'x': 6.0, 'y': 6.0},
  'radius': 2.5,
});
final scene = updated.lastGeometryScene!; // JSON & SVG ready for CustomPainter/Canvas
```

---

## 4. Embedded Code Editor Engine (`package:quds/editor_engine.dart`)

Attach `QudsEditorEngine` to the same `QudsSession` so highlighting, formatting, diagnostics, and autocomplete automatically reflect the active `QudsExecutionPolicy`, registered `QudsHostModule`s, and live workspace variables:

```dart
import 'package:quds/editor_engine.dart';

final editor = QudsEditorEngine(session: session);
final analysis = editor.analyze(source);          // highlights, errors, policy checks, outline, folds
final formatted = editor.format(source);          // official formatQuds
final items = editor.completeAt(source, offset);  // imports, ::sections, $., viz., scene., workspace, keywords
final hover = editor.hoverAt(source, offset);     // docs, signatures, live workspace values
final sig = editor.signatureHelpAt(source, offset);
final next = editor.handleNewline(source, cursor); // auto-indent after `:` blocks
```

---

## 5. CLI Quick Execution & Interactive REPL

```bash
quds eval 'use quds:math; print mean([2.0, 4.0, 6.0])'
quds eval --sandbox script.quds
quds repl
```

See [example/scientific_interpreter_demo.dart](../example/scientific_interpreter_demo.dart) for a complete runnable script.
