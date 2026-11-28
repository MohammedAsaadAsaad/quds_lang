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

    test(
        'unlabeled non-draggable points omit noisy internal IDs while draggable and explicitly labeled points keep labels',
        () async {
      final session = QudsSession(policy: QudsExecutionPolicy.scientific());
      final res = await session.run('''
use quds:viz as viz
s = viz.scene(title: "Clean Grid")
s.point("t0_0", 1.0, 2.0, color: "#10B981")
s.point("sun", 0.0, 0.0, label: "الشمس")
s.point("A", 3.0, 4.0, draggable: true)
s.render()
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      final scene = res.lastGeometryScene!;
      final tree = scene.findPrimitive('t0_0') as QudsGeoPoint;
      final sun = scene.findPrimitive('sun') as QudsGeoPoint;
      final handle = scene.findPrimitive('A') as QudsGeoPoint;
      expect(tree.label, isNull);
      expect(sun.label, equals('الشمس'));
      expect(handle.label, equals('A'));
      expect(scene.interactiveTouch, isFalse);
    });

    test(
        'viz.pointer() enables interactiveTouch and streams live finger coordinates across frames',
        () async {
      final session = QudsSession(policy: QudsExecutionPolicy.scientific());
      const script = '''
use quds:viz as viz
p = viz.pointer()
s = viz.scene(title: "Touch Pad", bounds: [-5.0, 5.0, -5.0, 5.0])
s.circle("finger", [p.x, p.y], 0.4, stroke: "#38BDF8")
s.readout("taps", p.taps)
s.render()
''';
      final initial = await session.run(script);
      expect(initial.succeeded, isTrue, reason: '${initial.error}');
      expect(initial.lastGeometryScene!.interactiveTouch, isTrue);
      final c0 =
          initial.lastGeometryScene!.findPrimitive('finger') as QudsGeoCircle;
      expect(c0.cx, closeTo(0.0, 1e-6));

      session.patchInteractiveInputs({
        '__quds_pointer': {
          'x': 2.5,
          'y': -1.25,
          'down': true,
          'tapX': 2.5,
          'tapY': -1.25,
          'taps': 3,
          'vx': 1.2,
          'vy': -0.4,
          'active': true,
        },
      });
      final next = await session.stepFrame(1.0 / 60.0, source: script);
      expect(next.succeeded, isTrue, reason: '${next.error}');
      final c1 =
          next.lastGeometryScene!.findPrimitive('finger') as QudsGeoCircle;
      expect(c1.cx, closeTo(2.5, 1e-6));
      expect(c1.cy, closeTo(-1.25, 1e-6));
      expect(next.lastGeometryScene!.readings.first.value, equals('3'));

      // Round-trip JSON preserves interactiveTouch
      final roundTrip =
          QudsGeometrySceneOutput.fromJson(next.lastGeometryScene!.toJson());
      expect(roundTrip.interactiveTouch, isTrue);

      session.resetAnimation();
      expect(session.interactiveInputs.containsKey('__quds_pointer'), isFalse);
    });
  });
}
