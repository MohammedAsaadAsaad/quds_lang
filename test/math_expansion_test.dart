import 'dart:io';

import 'package:quds/src/sdk.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

void main() {
  test('embedded quds:math matches lib/sdk/math.quds', () {
    final disk = File('lib/sdk/math.quds').readAsStringSync().trimRight();
    expect(embeddedSdk['math']?.trimRight(), disk);
  });

  test('quds test passes primary math expansion suite', () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', 'test/math_expansion.quds'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('ok graphBridges, articulationPoints'));
    expect(result.stdout, contains('ok triangulatePolygon preserves exact'));
    expect(result.stdout, contains('ok timeseries PACF, AR(p) fitting'));
    expect(result.stdout, contains('ok combinatorics generators'));
    expect(result.stdout, contains('ok stats cohenD, logisticRegression'));
  }, timeout: const Timeout.factor(4));

  test('quds:math expansion strict analyze and VM / JS parity pass', () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-math-exp-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final entry = File('${sandbox.path}/app.quds')..writeAsStringSync('''
use quds:math as m

main():
  bridges = m.graphBridges([[1, 2], [0, 2], [0, 1, 3], [2]])
  tris = m.triangulatePolygon([
    m.Vec2(x: 0.0, y: 0.0),
    m.Vec2(x: 2.0, y: 0.0),
    m.Vec2(x: 2.0, y: 1.0),
    m.Vec2(x: 1.0, y: 1.0),
    m.Vec2(x: 1.0, y: 2.0),
    m.Vec2(x: 0.0, y: 2.0),
  ])
  holt = m.holtForecast([5.0, 7.0, 9.0, 11.0], 0.5, 0.5, 1)
  perms = m.permutationsOf(3)
  dVal = m.cohenD([4.0, 5.0, 6.0], [1.0, 2.0, 3.0])
  logW = m.logisticRegression([[1.0, -2.0], [1.0, -1.0], [1.0, 1.0], [1.0, 2.0]], [0, 0, 1, 1], lambda: 0.1)
  w = m.ridgeRegression([[1.0, 1.0], [1.0, 2.0], [1.0, 3.0]], [3.0, 5.0, 7.0], 0.0)
  print "{bridges}|{tris.length}|{holt[0].round()}|{perms.length}|{dVal.round()}|{logW[1] > 1.0}|{w[1].round()}"
''');

    final analyze = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'analyze', '--fatal-infos', entry.path],
      workingDirectory: sandbox.path,
    );
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');

    final run = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'run', entry.path],
      workingDirectory: sandbox.path,
    );
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, '[[2, 3]]|4|13|6|3|true|2\n');

    final jsOut = '${sandbox.path}/app.js';
    final jsBuild = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'compile', 'js', '-o', jsOut, entry.path],
      workingDirectory: sandbox.path,
    );
    expect(jsBuild.exitCode, 0, reason: '${jsBuild.stdout}\n${jsBuild.stderr}');
    final nodeRun = await Process.run('node', [jsOut]);
    expect(nodeRun.exitCode, 0, reason: '${nodeRun.stdout}\n${nodeRun.stderr}');
    expect(nodeRun.stdout, '[[2, 3]]|4|13|6|3|true|2\n');
  }, timeout: const Timeout.factor(4));
}
