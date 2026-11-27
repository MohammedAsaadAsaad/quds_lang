import 'dart:math' as math;

import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group('Package 3 — quds:data (DataTable/CSV/FFT) & QudsStreamBridge', () {
    test(
        'DataTable parses CSV, filters, sorts, groups, describes, fits linear regression, and emits viz outputs',
        () async {
      final session = QudsSession(policy: QudsExecutionPolicy.standard());
      const src = '''
use quds:data as data

csv = "city,temp,sales\\nJerusalem,22.0,120.0\\nHebron,20.0,100.0\\nJerusalem,26.0,160.0\\nHebron,24.0,140.0\\nNablus,28.0,180.0"
df = data.parseCsv(csv)
stats = df.describe("sales")
reg = df.linearRegression("temp", "sales")
byCity = df.groupBy("city", "sales", op: "mean").sortBy("mean_sales", desc: true)
hot = df.filter((row) -> row["temp"] >= 24.0)
ma = df.movingAverage("sales", 2)

byCity.toVizTable(title: "Mean Sales by City")
df.toVizPlot("temp", "sales", title: "Temp vs Sales", kind: "scatter")

print "rows={df.rowCount} mean={stats['mean']} slope={reg['slope'].toStringAsFixed(1)} r2={reg['r2'].toStringAsFixed(2)} hot={hot.rowCount} ma1={ma[1]}"
''';
      final res = await session.run(src);
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(
        res.printedLines.first,
        'rows=5 mean=140.0 slope=10.0 r2=1.00 hot=3 ma1=110.0',
      );
      expect(res.outputs.whereType<QudsTableOutput>().length, 1);
      expect(res.lastPlot, isNotNull);

      await session.dispose();
    });

    test('FFT magnitude spectrum identifies exact dominant frequency',
        () async {
      final session = QudsSession(policy: QudsExecutionPolicy.standard());
      const src = '''
use dart:math as m
use quds:data as data

sr = 64.0
var sig = []
for i in 0..63:
  t = i / sr
  sig.add(2.0 * m.sin(2.0 * m.pi * 8.0 * t) + 0.5 * m.sin(2.0 * m.pi * 16.0 * t))

spec = data.fftMagnitude(sig, sampleRate: sr)
print "peak={spec['peakFreq'].toStringAsFixed(1)} mag={spec['peakMagnitude'].toStringAsFixed(2)}"
''';
      final res = await session.run(src);
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines.first, 'peak=8.0 mag=2.00');

      await session.dispose();
    });

    test(
        'QudsStreamBridge streams live host telemetry under capability policy enforcement',
        () async {
      final bridge = QudsStreamBridge(
        uri: 'host:telemetry',
        requiredCapability: 'telemetry:read',
        maxBufferSize: 128,
      );
      for (var i = 0; i < 64; i++) {
        bridge.push('vibration', 1.5 * math.sin(2 * math.pi * 5 * i / 64.0));
      }
      bridge.pushVec3('accel', 0.1, 9.81, -0.05);

      // 1. Authorized session succeeds and computes FFT on live stream buffer!
      final allowedSession = QudsSession(
        policy: QudsExecutionPolicy.systemBridge(
          allowedLibraries: const {
            'quds:data',
            'quds:math',
            'host:telemetry',
          },
          capabilities: const [
            QudsCapability('telemetry:read', description: 'Read telemetry'),
          ],
        ),
        hostModules: [bridge.toHostModule()],
      );
      final ok = await allowedSession.run('''
use quds:data as data
use host:telemetry as tel

samples = tel.history("vibration", limit: 64)
spec = data.fftMagnitude(samples, sampleRate: 64.0)
acc = tel.latest("accel")
st = tel.stats("vibration")
print "peak={spec['peakFreq'].toStringAsFixed(1)} ay={acc['y']} count={st['count']}"
''');
      expect(ok.succeeded, isTrue, reason: '${ok.error}');
      expect(ok.printedLines.first, 'peak=5.0 ay=9.81 count=64');

      // 2. Unauthorized session (missing capability) is blocked by policy!
      final deniedSession = QudsSession(
        policy: QudsExecutionPolicy.systemBridge(
          allowedLibraries: const {'host:telemetry'},
          capabilities: const [],
        ),
        hostModules: [bridge.toHostModule()],
      );
      final blocked = await deniedSession.run('''
use host:telemetry as tel
print tel.latest("accel")
''');
      expect(blocked.succeeded, isFalse);
      expect(blocked.error, isA<QudsPolicyViolationException>());

      await allowedSession.dispose();
      await deniedSession.dispose();
    });
  });
}
