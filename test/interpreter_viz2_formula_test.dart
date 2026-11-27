import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group(
      'Package 1 — viz 2.0 (Animation, 3D, VectorField, Graph, Forms) & QudsFormulaEngine',
      () {
    test('frame-stepped animation loop, trail, and line intersection',
        () async {
      final session = QudsSession(
        policy: QudsExecutionPolicy.standard(),
        allowTopLevelRebind: true,
      );
      const src = '''
use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
theta = 0.8 * m.cos(2.0 * clk.t)
bobX = 3.0 * m.sin(theta)
bobY = -3.0 * m.cos(theta)

scene = viz.scene(title: "Pendulum", grid: true)
hit = scene.intersect([0.0, 0.0], [4.0, 4.0], [0.0, 4.0], [4.0, 0.0])
scene.segment("rod", [0.0, 0.0], [bobX, bobY], color: "#94A3B8")
scene.point("bob", bobX, bobY, color: "#EF4444")
scene.trail("arc", [[0.0, -3.0], [bobX, bobY]], color: "#38BDF8")
scene.render()
print "t={clk.t.toStringAsFixed(2)} f={clk.frame} hit={hit[0]},{hit[1]}"
''';

      final r0 = await session.run(src);
      expect(r0.succeeded, isTrue, reason: '${r0.error}');
      expect(r0.animationSpec, isNotNull);
      expect(r0.animationSpec!.frame, 0);
      expect(r0.printedLines.first, contains('t=0.00 f=0 hit=2.0,2.0'));

      final r1 = await session.stepFrame(0.5);
      expect(r1.succeeded, isTrue, reason: '${r1.error}');
      expect(r1.animationSpec!.frame, 1);
      expect(r1.animationSpec!.time, closeTo(0.5, 1e-6));
      expect(r1.printedLines.first, contains('t=0.50 f=1'));

      session.resetAnimation();
      final r2 = await session.updateInteractiveInputs({});
      expect(r2.animationSpec!.frame, 0);
      expect(r2.animationSpec!.time, closeTo(0.0, 1e-6));

      await session.dispose();
    });

    test(
        '3D surface, 2D vector field, and interactive graph outputs serialize and export SVG',
        () async {
      final session = QudsSession(policy: QudsExecutionPolicy.standard());
      const src = '''
use dart:math as m
use quds:viz as viz

wave(x: double, y: double) -> double:
  r = m.sqrt(x * x + y * y)
  return m.sin(r) / (r + 0.5)

viz.surface3d(wave, xMin: -4.0, xMax: 4.0, yMin: -4.0, yMax: 4.0, steps: 8, title: "Ripple 3D", colorMap: "plasma")

vortex(x: double, y: double) -> List<double>:
  return [-y, x]

viz.vectorField(vortex, xMin: -3.0, xMax: 3.0, yMin: -3.0, yMax: 3.0, steps: 5, title: "Vortex")

g = viz.graph(title: "Shortest Path", directed: false)
g.circleLayout(["A", "B", "C", "D"], radius: 3.0)
g.edge("A", "B", weight: 2.0)
g.edge("B", "C", weight: 3.0)
g.edge("C", "D", weight: 1.0)
g.edge("A", "D", weight: 9.0)
g.highlightPath(["A", "B", "C", "D"])
g.render()
''';
      final res = await session.run(src);
      expect(res.succeeded, isTrue, reason: '${res.error}');

      final surf = res.lastSurface3D;
      expect(surf, isNotNull);
      expect(surf!.xs.length, 9);
      expect(surf.zs.length, 9);
      expect(surf.toSvg(), contains('<polygon'));
      final surfRoundTrip = QudsSurface3DOutput.fromJson(surf.toJson());
      expect(surfRoundTrip.title, 'Ripple 3D');
      expect(surfRoundTrip.zs.length, 9);

      final vf = res.lastVectorField;
      expect(vf, isNotNull);
      expect(vf!.arrows.length, 36);
      expect(vf.toSvg(), contains('<line'));
      final vfRoundTrip = QudsVectorFieldOutput.fromJson(vf.toJson());
      expect(vfRoundTrip.arrows.length, 36);

      final graph = res.lastGraph;
      expect(graph, isNotNull);
      expect(graph!.nodes.length, 4);
      expect(graph.edges.where((e) => e.highlighted).length, 3);
      expect(graph.toSvg(), contains('<circle'));
      final graphRoundTrip = QudsGraphOutput.fromJson(graph.toJson());
      expect(graphRoundTrip.nodes.length, 4);

      await session.dispose();
    });

    test('micro-app form controls update live via updateInteractiveInputs',
        () async {
      final session = QudsSession(
        policy: QudsExecutionPolicy.standard(),
        allowTopLevelRebind: true,
      );
      const src = '''
use quds:viz as viz

item = viz.input("item", value: "Laptop", label: "Item")
price = viz.number("price", value: 1000.0, min: 0.0, label: "Price")
tier = viz.select("tier", ["Standard", "VIP"], value: "Standard", label: "Tier")
accent = viz.color("accent", value: "#10B981", label: "Badge Color")
clicks = viz.button("apply", label: "Recalculate")
rate = if tier == "VIP": 0.15 else: 0.05
total = price * (1.0 - rate)

results = map:
  "Item": item
  "Discount": "{(rate * 100).toStringAsFixed(0)}%"
  "Total": total
  "Accent": accent
  "Clicks": clicks

viz.form(results, title: "Pricing Micro-App", summary: "Instant quote calculator")
''';
      final r1 = await session.run(src);
      expect(r1.succeeded, isTrue, reason: '${r1.error}');
      expect(r1.lastForm, isNotNull);
      expect(r1.lastForm!.entries['Total'], 950.0);
      expect(r1.lastForm!.interactiveInputs.length, 5);

      final r2 = await session.updateInteractiveInputs({
        'item': 'Workstation',
        'price': 2000.0,
        'tier': 'VIP',
        'apply': 2,
      });
      expect(r2.succeeded, isTrue, reason: '${r2.error}');
      expect(r2.lastForm!.entries['Item'], 'Workstation');
      expect(r2.lastForm!.entries['Total'], 1700.0);
      expect(r2.lastForm!.entries['Clicks'], 2);

      await session.dispose();
    });

    test(
        'QudsFormulaEngine validates, caches ASTs, evaluates formulas/rules/batches under sandbox',
        () async {
      final engine = QudsFormulaEngine();

      // Static validation
      expect(engine.validate('amount * 1.15').valid, isTrue);
      expect(engine.validate('use host:secret\n1 + 1').valid, isFalse);
      expect(engine.validate('if (broken').valid, isFalse);

      // Single expression evaluation + AST cache hit
      final total = await engine.evaluate<double>(
        'amount * (1.0 + tax) - discount',
        context: {'amount': 200.0, 'tax': 0.15, 'discount': 10.0},
      );
      expect(total, closeTo(220.0, 1e-9));
      final cachedBefore = engine.cacheSize;

      // Batch evaluation reuses cached AST
      final batch = await engine.evaluateBatch<double>(
        'amount * (1.0 + tax) - discount',
        [
          {'amount': 100.0, 'tax': 0.10, 'discount': 0.0},
          {'amount': 500.0, 'tax': 0.20, 'discount': 50.0},
        ],
      );
      expect(batch[0], closeTo(110.0, 1e-9));
      expect(batch[1], closeTo(550.0, 1e-9));
      expect(engine.cacheSize, cachedBefore);

      // Multi-line business rule script
      final ruleRes = await engine.evaluateRule(
        '''
var fee = 0.0
if amount > 1000.0:
  fee = amount * 0.02
else:
  fee = 15.0
print "fee={fee}"
fee
''',
        context: {'amount': 1500.0},
      );
      expect(ruleRes.succeeded, isTrue, reason: '${ruleRes.error}');
      expect(ruleRes.value, 30.0);
      expect(ruleRes.printedLines, ['fee=30.0']);
    });
  });
}
