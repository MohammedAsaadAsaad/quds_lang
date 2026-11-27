/// End-to-end demonstration of embedding Quds in a scientific application:
/// 1. `QudsEditorEngine`: syntax highlighting, formatting, policy diagnostics,
///    and context-aware autocomplete.
/// 2. `QudsSession` + `QudsExecutionPolicy`: sandboxed scientific execution.
/// 3. `QudsDebugController`: breakpoint pause, live watch & expression eval.
/// 4. `quds:viz` + `quds:math::geometry`: interactive geometry scene with
///    live recomputation when dragging a vertex or sliding a parameter.
///
/// Run with: `dart run example/scientific_interpreter_demo.dart`
library;

import 'package:quds/editor_engine.dart';
import 'package:quds/interpreter.dart';

Future<void> main() async {
  // 1. Configure a scientific execution policy and native AST debugger.
  final debugger = QudsDebugController();
  final session = QudsSession(
    policy: QudsExecutionPolicy.scientific(
      maxSteps: 100000,
      timeout: const Duration(seconds: 5),
    ),
    debugger: debugger,
  );
  final editor = QudsEditorEngine(session: session);

  const script = '''
use quds:math::vector show Vec2
use quds:math::geometry show polygonCentroid, triangulatePolygon
use quds:viz as viz

A = viz.point("A", 0.0, 0.0, draggable: true)
B = viz.point("B", 6.0, 0.0, draggable: true)
C = viz.point("C", 0.0, 3.0, draggable: true)
radius = viz.slider("radius", min: 0.5, max: 5.0, value: 1.5)

poly = [Vec2(A.x, A.y), Vec2(B.x, B.y), Vec2(C.x, C.y)]
center = polygonCentroid(poly)
tris = triangulatePolygon(poly)

scene = viz.scene(title: "Interactive Triangle", grid: true, interactive: true)
scene.polygon("tri", poly, fill: "#2563EB22", stroke: "#2563EB")
scene.mesh("mesh", tris, vertices: poly)
scene.point("A", A)
scene.point("B", B)
scene.point("C", C)
scene.point("G", center, label: "Centroid", color: "#DC2626")
scene.circle("cG", center, radius, stroke: "#10B981", dashed: true)
scene.angle("angA", B, A, C, showDegrees: true)
scene.render()
''';

  // 2. Editor engine: analyze, highlight, and autocomplete before execution.
  final analysis = editor.analyze(script, file: 'triangle.quds');
  print('Editor valid syntax: ${analysis.validSyntax}');
  print('Highlight spans: ${analysis.highlights.length}');
  print('Outline symbols: ${analysis.symbols.map((s) => s.name).join(', ')}');

  final sceneCompletions =
      editor.completeAt('use quds:viz as viz\nscene = viz.scene()\nscene.', 46);
  print(
      'Scene autocomplete: ${sceneCompletions.map((c) => c.label).take(6).join(', ')}');

  // 3. Attach a breakpoint on line 12 (after computing `center`) and inspect live!
  debugger.setLineBreakpoints('triangle.quds', [12]);
  debugger.setWatchExpressions(['center.x', 'center.y']);
  final sub = debugger.onPaused.listen((pause) async {
    final sum = await pause.evaluate('center.x + center.y');
    print(
        'Paused at ${pause.span} | watch center=(${pause.watchResults['center.x']?.summary}, '
        '${pause.watchResults['center.y']?.summary}) | live eval x+y=$sum');
    debugger.continueRun();
  });

  // 4. Initial run
  final initial = await session.run(script, file: 'triangle.quds');
  if (!initial.succeeded) {
    throw StateError('Execution failed: ${initial.error}');
  }
  final scene1 = initial.lastGeometryScene!;
  final g1 = scene1.findPrimitive('G') as QudsGeoPoint;
  final ang1 = scene1.findPrimitive('angA') as QudsGeoAngle;
  print(
      'Initial centroid: (${g1.x}, ${g1.y}), angle A: ${ang1.degrees.toStringAsFixed(1)}°');

  // 5. Disable breakpoint and simulate user dragging vertex C + moving slider
  debugger.clearBreakpoints();
  final updated = await session.updateInteractiveInputs({
    'C': {'x': 6.0, 'y': 6.0},
    'radius': 2.5,
  });
  final scene2 = updated.lastGeometryScene!;
  final g2 = scene2.findPrimitive('G') as QudsGeoPoint;
  final ang2 = scene2.findPrimitive('angA') as QudsGeoAngle;
  print('After dragging C to (6, 6): centroid=(${g2.x}, ${g2.y}), '
      'angle A=${ang2.degrees.toStringAsFixed(1)}°, SVG bytes=${scene2.toSvg().length}');

  await sub.cancel();
  await debugger.dispose();
  await session.dispose();
}
