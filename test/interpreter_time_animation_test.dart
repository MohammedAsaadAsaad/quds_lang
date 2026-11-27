import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group('Time-based execution, stateful physics & animated gradient curves',
      () {
    test(
        'stateful nonlinear pendulum integrates over time with live telemetry readouts',
        () async {
      const pendulumCode = '''
use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
L = 2.5
g = 9.81
mass = 1.0
damping = 0.08

var theta = viz.state("theta", 1.0)
var omega = viz.state("omega", 0.0)
var trail = viz.state("trail", [])

if clk.frame > 0:
  alpha = -(g / L) * m.sin(theta) - damping * omega
  omega = omega + alpha * clk.dt
  theta = theta + omega * clk.dt
  viz.setState("theta", theta)
  viz.setState("omega", omega)

bobX = L * m.sin(theta)
bobY = -L * m.cos(theta)
trail.add([bobX, bobY])
if trail.length > 40:
  trail = trail.sublist(trail.length - 40)
viz.setState("trail", trail)

v = (omega * L).abs()
ke = 0.5 * mass * v * v
pe = mass * g * L * (1.0 - m.cos(theta))
totalE = ke + pe

scene = viz.scene(title: "بندول فيزيائي حي", bounds: [-3.2, 3.2, -3.2, 0.8])
scene.trail("path", trail, gradient: viz.palette("ocean"), strokeWidth: 2.5)
scene.segment("rod", [0.0, 0.0], [bobX, bobY], color: "#CBD5E1")
scene.point("bob", bobX, bobY, color: "#EF4444", radius: 8.0)
scene.readout("t", clk.t, unit: "s", color: "#38BDF8")
scene.readout("θ", theta * 180.0 / m.pi, unit: "°", color: "#F59E0B")
scene.readout("ω", omega, unit: "rad/s", color: "#A855F7")
scene.readout("E", totalE, unit: "J", color: "#10B981")
scene.render()
''';

      final session = QudsSession();
      addTearDown(session.dispose);

      final frames = await session.runTimeline(
        pendulumCode,
        frames: 30,
        dt: 1.0 / 30.0,
      );
      expect(frames, hasLength(30));
      for (final f in frames) {
        expect(f.succeeded, isTrue, reason: '${f.error}');
      }

      final firstScene = frames.first.lastGeometryScene!;
      final lastScene = frames.last.lastGeometryScene!;

      // Fixed camera bounds preserved identically across all frames
      expect(firstScene.bounds.minX, closeTo(-3.2, 1e-9));
      expect(lastScene.bounds.maxY, closeTo(0.8, 1e-9));

      // Telemetry readouts present and updated across time
      expect(firstScene.readings, hasLength(4));
      expect(lastScene.readings, hasLength(4));
      expect(firstScene.readings[0].value, equals('0.00'));
      expect(double.parse(lastScene.readings[0].value),
          closeTo(29.0 / 30.0, 1e-2));

      // Pendulum physically swung away from initial angle 1.0 rad (~57.3°)
      final theta0 = double.parse(firstScene.readings[1].value);
      final thetaEnd = double.parse(lastScene.readings[1].value);
      expect(theta0, closeTo(57.3, 0.2));
      expect(thetaEnd, lessThan(theta0 - 15.0));

      // Energy decreased slightly due to positive damping
      final e0 = double.parse(firstScene.readings[3].value);
      final eEnd = double.parse(lastScene.readings[3].value);
      expect(eEnd, lessThan(e0));
      expect(eEnd, greaterThan(0.0));

      // Trail accumulated up to 30 points
      final trailPrim = lastScene.findPrimitive('path') as QudsGeoCurve;
      expect(trailPrim.points, hasLength(30));
      expect(trailPrim.gradientColors, isNotEmpty);

      // Reset clears persistent state cleanly back to initial angle
      session.resetAnimation();
      final resetRes = await session.run(pendulumCode);
      expect(resetRes.succeeded, isTrue);
      final resetTheta =
          double.parse(resetRes.lastGeometryScene!.readings[1].value);
      expect(resetTheta, closeTo(57.3, 0.2));
    });

    test(
        'Temple Fay butterfly curve draws progressively from point 1 to last with gradient colors & SVG',
        () async {
      const butterflyCode = '''
use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
steps = 240
maxU = 12.0 * m.pi

var pts = []
for i in 0..steps:
  u = (i / steps) * maxU
  s = m.sin(u / 12.0)
  r = m.exp(m.cos(u)) - 2.0 * m.cos(4.0 * u) - s * s * s * s * s
  pts.add([r * m.sin(u), r * m.cos(u)])

scene = viz.scene(title: "فراشة تيمبل فاي", bounds: [-4.2, 4.2, -3.5, 4.2])
scene.curve("butterfly", pts, gradient: viz.palette("butterfly"), progress: clk.progress, strokeWidth: 2.8, glow: true, showHead: true)
scene.readout("الاكتمال", clk.progress * 100.0, unit: "%", color: "#F43F5E")
scene.render()
''';

      final session = QudsSession();
      addTearDown(session.dispose);

      // Frame at t = 0.0 -> progress = 0.0 (first point only)
      final r0 = await session.run(butterflyCode);
      expect(r0.succeeded, isTrue, reason: '${r0.error}');
      final curve0 =
          r0.lastGeometryScene!.findPrimitive('butterfly') as QudsGeoCurve;
      expect(curve0.progress, closeTo(0.0, 1e-9));
      expect(curve0.visiblePoints(), hasLength(1));
      expect(curve0.gradientColors, hasLength(7));
      expect(curve0.glow, isTrue);
      expect(curve0.showHead, isTrue);

      // Scrub to midpoint t = 4.0s -> progress = 0.5 (half the butterfly drawn)
      final rHalf = await session.seekTime(4.0);
      expect(rHalf.succeeded, isTrue, reason: '${rHalf.error}');
      final curveHalf =
          rHalf.lastGeometryScene!.findPrimitive('butterfly') as QudsGeoCurve;
      expect(curveHalf.progress, closeTo(0.5, 1e-6));
      expect(curveHalf.visiblePoints().length, inInclusiveRange(120, 122));

      // Scrub to completion t = 7.99s -> almost 100% drawn + JSON round-trip + gradient SVG
      final rFull = await session.seekTime(7.99);
      expect(rFull.succeeded, isTrue, reason: '${rFull.error}');
      final sceneFull = rFull.lastGeometryScene!;
      final curveFull = sceneFull.findPrimitive('butterfly') as QudsGeoCurve;
      expect(curveFull.progress, greaterThan(0.99));
      expect(curveFull.visiblePoints().length, greaterThanOrEqualTo(240));

      // Verify full JSON round-trip preserves gradient, progress, glow, showHead, readings
      final roundTrip = QudsGeometrySceneOutput.fromJson(sceneFull.toJson());
      final rtCurve = roundTrip.findPrimitive('butterfly') as QudsGeoCurve;
      expect(rtCurve.gradientColors, equals(curveFull.gradientColors));
      expect(rtCurve.progress, closeTo(curveFull.progress, 1e-9));
      expect(rtCurve.glow, isTrue);
      expect(rtCurve.showHead, isTrue);
      expect(roundTrip.readings.first.label, equals('الاكتمال'));

      // Verify SVG renders individual colored segments and head circle
      final svg = sceneFull.toSvg();
      expect(svg, contains('data-id="butterfly_0"'));
      expect(svg, contains('data-id="butterfly_head"'));
    });

    test(
        'color helpers (hsl, rgb, lerpColor, gradient, palette) & custom per-vertex colors',
        () async {
      const code = '''
use quds:viz as viz

c_red = viz.hsl(0.0, 1.0, 0.5)
c_rgb = viz.rgb(16, 185, 129)
c_mid = viz.lerpColor("#000000", "#FFFFFF", 0.5)
c_grad = viz.gradient(["#FF0000", "#0000FF"], 0.5)
pal = viz.palette("rainbow")

var pts = []
var cols = []
for i in 0..10:
  pts.add([i * 0.5, i * 0.2])
  cols.add(viz.hsl(i * 36.0, 0.9, 0.55))

scene = viz.scene(title: "Custom Vertex Colors")
scene.curve("custom", pts, colors: cols, strokeWidth: 3.0)
scene.render()
''';

      final session = QudsSession();
      addTearDown(session.dispose);

      final res = await session.run(code);
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(session.getVariable('c_red'), equals('#FF0000'));
      expect(session.getVariable('c_rgb'), equals('#10B981'));
      expect(session.getVariable('c_mid'), equals('#808080'));
      expect(session.getVariable('c_grad'), equals('#800080'));
      expect((session.getVariable('pal') as List), hasLength(7));

      final curve =
          res.lastGeometryScene!.findPrimitive('custom') as QudsGeoCurve;
      expect(curve.pointColors, hasLength(11));
      expect(curve.colorAt(0, 0.0), equals(curve.pointColors.first));
    });
  });
}
