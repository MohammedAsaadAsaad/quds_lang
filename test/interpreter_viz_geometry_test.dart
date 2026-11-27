import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group('Phase 5 — Scientific Rich Outputs & Interactive Geometry (quds:viz)',
      () {
    test(
        'interactive geometry scene with quds:math::geometry recomputes live on handle drag and slider move',
        () async {
      final session = QudsSession(policy: QudsExecutionPolicy.scientific());

      const geometryScript = '''
use quds:math::vector show Vec2
use quds:math::geometry show polygonCentroid, triangulatePolygon
use quds:viz as viz

A = viz.point("A", 0.0, 0.0, draggable: true)
B = viz.point("B", 6.0, 0.0, draggable: true)
C = viz.point("C", 0.0, 3.0, draggable: true)
radius = viz.slider("radius", min: 0.5, max: 5.0, value: 1.5, step: 0.5)

poly = [Vec2(A.x, A.y), Vec2(B.x, B.y), Vec2(C.x, C.y)]
center = polygonCentroid(poly)
tris = triangulatePolygon(poly)

scene = viz.scene(title: "Interactive Triangle", grid: true, interactive: true)
scene.polygon("tri", poly, fill: "#2563EB22", stroke: "#2563EB")
scene.mesh("triMesh", tris, vertices: poly)
scene.point("A", A)
scene.point("B", B)
scene.point("C", C)
scene.point("G", center, label: "Centroid", color: "#DC2626")
scene.circle("cG", center, radius, stroke: "#10B981", dashed: true)
scene.segment("median", A, center, dashed: true)
scene.angle("angA", B, A, C, showDegrees: true)
scene.render()
''';

      // 1. Initial run
      final initial = await session.run(geometryScript, file: 'triangle.quds');
      expect(initial.succeeded, isTrue, reason: '${initial.error}');
      final scene1 = initial.lastGeometryScene;
      expect(scene1, isNotNull);
      expect(scene1!.title, 'Interactive Triangle');
      expect(scene1.draggablePoints.map((p) => p.id), ['A', 'B', 'C']);
      expect(scene1.interactiveInputs.map((i) => i.id),
          containsAll(['A', 'B', 'C', 'radius']));

      final g1 = scene1.findPrimitive('G') as QudsGeoPoint;
      expect(g1.x, closeTo(2.0, 1e-9));
      expect(g1.y, closeTo(1.0, 1e-9));

      final ang1 = scene1.findPrimitive('angA') as QudsGeoAngle;
      expect(ang1.degrees, closeTo(90.0, 1e-6));

      final circ1 = scene1.findPrimitive('cG') as QudsGeoCircle;
      expect(circ1.radius, closeTo(1.5, 1e-9));

      // Verify full JSON round-trip and valid SVG rendering
      final decoded = QudsGeometrySceneOutput.fromJson(scene1.toJson());
      expect(decoded.primitives.length, scene1.primitives.length);
      expect(decoded.bounds.minX, closeTo(scene1.bounds.minX, 1e-9));
      final svg = scene1.toSvg();
      expect(svg, contains('<svg'));
      expect(svg, contains('data-id="G"'));
      expect(svg, contains('data-draggable="true"'));

      // 2. Simulate user dragging point C to (6.0, 6.0) and moving slider radius to 2.5
      final updated = await session.updateInteractiveInputs({
        'C': {'x': 6.0, 'y': 6.0},
        'radius': 2.5,
      });
      expect(updated.succeeded, isTrue, reason: '${updated.error}');
      final scene2 = updated.lastGeometryScene!;
      final g2 = scene2.findPrimitive('G') as QudsGeoPoint;
      // New centroid of (0,0), (6,0), (6,6) is (4.0, 2.0)
      expect(g2.x, closeTo(4.0, 1e-9));
      expect(g2.y, closeTo(2.0, 1e-9));

      // New angle at A between (6,0) and (6,6) is 45 degrees
      final ang2 = scene2.findPrimitive('angA') as QudsGeoAngle;
      expect(ang2.degrees, closeTo(45.0, 1e-6));

      final circ2 = scene2.findPrimitive('cG') as QudsGeoCircle;
      expect(circ2.radius, closeTo(2.5, 1e-9));
    });

    test(
        '2D plot, table, matrix, and LaTeX outputs serialize cleanly and export SVG',
        () async {
      final session = QudsSession(policy: QudsExecutionPolicy.scientific());
      final res = await session.run('''
use quds:math
use quds:viz as viz

xs = [0.0, 1.0, 2.0, 3.0]
ys = [sin(x) for x in xs]
viz.plot(xs, ys, title: "Sine Wave", xLabel: "t", yLabel: "sin(t)")
viz.table(["t", "sin(t)"], [[0.0, 0.0], [1.0, 0.84]])
viz.matrix([[1.0, 2.0], [3.0, 4.0]], title: "A")
viz.latex("\\\\int_0^\\\\pi \\\\sin(x)\\\\,dx = 2")
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.outputs.length, 4);
      expect(res.outputs[0], isA<QudsPlot2DOutput>());
      expect(res.outputs[1], isA<QudsTableOutput>());
      expect(res.outputs[2], isA<QudsMatrixOutput>());
      expect(res.outputs[3], isA<QudsTextOutput>());

      final plot = res.lastPlot!;
      expect(plot.toSvg(), contains('<polyline'));
      expect(plot.toJson()['kind'], 'plot2d');

      final mat = res.outputs[2] as QudsMatrixOutput;
      expect(mat.rows, 2);
      expect(mat.cols, 2);
    });

    test(
        'policy maxPrimitives and maxOutputCount protect host UI from overload',
        () async {
      final primSession = QudsSession(
        policy: QudsExecutionPolicy.scientific(maxPrimitives: 3),
      );
      final primRes = await primSession.run('''
use quds:viz as viz
s = viz.scene()
s.point("p1", 0.0, 0.0)
s.point("p2", 1.0, 0.0)
s.point("p3", 2.0, 0.0)
s.point("p4", 3.0, 0.0)
''');
      expect(primRes.succeeded, isFalse);
      expect((primRes.error as QudsPolicyViolationException).kind,
          QudsPolicyViolationKind.primitiveLimit);

      final outSession = QudsSession(
        policy: QudsExecutionPolicy.scientific(maxOutputCount: 1),
      );
      final outRes = await outSession.run('''
use quds:viz as viz
viz.latex("a = 1")
viz.latex("b = 2")
''');
      expect(outRes.succeeded, isFalse);
      expect((outRes.error as QudsPolicyViolationException).kind,
          QudsPolicyViolationKind.outputLimit);
    });
  });
}
