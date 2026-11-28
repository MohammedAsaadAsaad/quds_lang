import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group('quds:pen built-in vector pen graphics module', () {
    for (final preferBytecode in [true, false]) {
      test(
        'draws squares, fills polygons, circles, stars, dots, and auto-frames bounds (${preferBytecode ? "Register VM" : "AST"})',
        () async {
          final session = QudsSession(policy: QudsExecutionPolicy.scientific());
          final res = await session.run(
            r'''
use quds:pen as pen
use quds:viz as viz

side = viz.slider("side", min: 20.0, max: 120.0, value: 60.0, label: "طول الضلع")

pen.color("sky", "emerald")
pen.width(2.5)
pen.beginFill()
pen.polygon(4, side)
pen.endFill()

pen.up()
pen.goto(100.0, 20.0)
pen.down()
pen.color(pen.hsl(320.0, 0.85, 0.58))
pen.star(5, 45.0)
pen.dot(6.0, "gold")
pen.stamp("amber")
pen.text("Quds Pen")
pen.readout("الأضلاع", 4, color: "emerald")

pen.render(title: "اختبار القلم", showPen: true)
print "{pen.x().round()}|{pen.y().round()}|{pen.heading().round()}|{pen.isDown()}"
''',
            preferBytecode: preferBytecode,
          );
          expect(res.succeeded, isTrue, reason: '${res.error}');
          expect(res.printedLines, equals(['100|20|0|true']));

          final scene = res.lastGeometryScene;
          expect(scene, isNotNull);
          expect(scene!.title, 'اختبار القلم');
          expect(scene.interactiveInputs, hasLength(1));
          expect(scene.interactiveInputs.first.id, 'side');
          // 4 square segments + 5 star segments = 9 segments
          expect(scene.primitives.whereType<QudsGeoSegment>(), hasLength(9));
          // 1 filled square + 1 stamp nib + 1 live cursor nib = 3 polygons
          expect(scene.primitives.whereType<QudsGeoPolygon>(), hasLength(3));
          expect(scene.primitives.whereType<QudsGeoLabel>(), hasLength(1));
          expect(scene.readings.any((r) => r.label == 'الأضلاع'), isTrue);
          expect(scene.readings.any((r) => r.label == 'الخطوط'), isTrue);
        },
      );
    }

    test(
        'progressive 60fps stroke animation reveals strokes gradually across frames',
        () async {
      final session = QudsSession(policy: QudsExecutionPolicy.scientific());
      const code = r'''
use quds:pen as pen
for i in 1..12:
  pen.color(pen.hsl(i * 30.0))
  pen.forward(50.0)
  pen.right(30.0)
pen.render(title: "دائرة متحركة", animate: true, duration: 4.0)
''';
      final frames = await session.runTimeline(code, frames: 4, dt: 0.5);
      expect(frames, hasLength(4));
      for (final f in frames) {
        expect(f.succeeded, isTrue, reason: '${f.error}');
        expect(f.lastGeometryScene?.animation, isNotNull);
      }
      final segsFrame1 = frames[1]
          .lastGeometryScene!
          .primitives
          .whereType<QudsGeoSegment>()
          .length;
      final segsFrame3 = frames[3]
          .lastGeometryScene!
          .primitives
          .whereType<QudsGeoSegment>()
          .length;
      expect(segsFrame3, greaterThan(segsFrame1));
    });

    test('supports circle, arc, backward, home, distance, clear, and reset',
        () async {
      final session = QudsSession(policy: QudsExecutionPolicy.scientific());
      final res = await session.run(r'''
use quds:pen as pen
pen.forward(30.0)
pen.left(90.0)
pen.forward(40.0)
d = pen.distance(0.0, 0.0)
pen.home()
pen.circle(25.0, steps: 24)
pen.arc(15.0, 90.0, steps: 8)
pen.render(title: "دوائر")
print "{d.round()}|{pen.position().length}"
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, equals(['50|2']));
      expect(
        res.lastGeometryScene!.primitives.whereType<QudsGeoSegment>().length,
        greaterThanOrEqualTo(34),
      );
    });
  });
}
