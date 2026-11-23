import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

void main() {
  test(
      'when test: runs private-access inline tests under quds test and strips completely from build/run/analyze/js',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-when-test-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    Directory('${sandbox.path}/lib').createSync();
    Directory('${sandbox.path}/bin').createSync();
    File('${sandbox.path}/pubspec.yaml').writeAsStringSync('''
name: shop
version: 0.1.0
environment:
  sdk: ^3.0.0
''');

    final pricing = File('${sandbox.path}/lib/pricing.quds')
      ..writeAsStringSync('''
_applyDiscount(price: double, pct: double) -> double = price * (1.0 - pct)

finalPrice(price: double) -> double = _applyDiscount(price, 0.15)

runtimeMode() -> String:
  when test:
    return "test"
  when not test:
    return "prod"

when test:
  const testPct = 0.25

  class FakePromo:
    factor: double

  _samplePrice() -> double = 200.0

  group "pricing internals":
    test "private helper and test-only mock class work":
      promo = FakePromo(factor: testPct)
      expect(_applyDiscount(_samplePrice(), promo.factor), closeTo(150.0, 0.0001))
      expect(runtimeMode(), equals("test"))

  test "public pricing works":
    expect(finalPrice(100.0), closeTo(85.0, 0.0001))
''');

    final app = File('${sandbox.path}/bin/app.quds')..writeAsStringSync('''
use package:shop/pricing

main():
  print "{finalPrice(100.0)}:{runtimeMode()}"
''');

    // 1. Default compile (testing: false) strips the entire when test: block
    final prod = compile(pricing.readAsStringSync(), file: pricing.path);
    expect(prod.dart, isNot(contains('FakePromo')));
    expect(prod.dart, isNot(contains('_samplePrice')));
    expect(prod.dart, isNot(contains('package:matcher')));
    expect(prod.dart, isNot(contains('_qTestFailed')));

    // 2. Strict quds analyze --fatal-infos passes cleanly on lib/pricing.quds and bin/app.quds
    final analyze = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'analyze', '--fatal-infos', pricing.path, app.path],
      workingDirectory: sandbox.path,
    );
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');

    // 3. Production quds run sees runtimeMode() == "prod"
    final run = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'run', app.path],
      workingDirectory: sandbox.path,
    );
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, '85.0:prod\n');

    // 4. quds compile js + node works with zero matcher dependency
    final jsOut = '${sandbox.path}/app.js';
    final jsBuild = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'compile', 'js', '-o', jsOut, app.path],
      workingDirectory: sandbox.path,
    );
    expect(jsBuild.exitCode, 0, reason: '${jsBuild.stdout}\n${jsBuild.stderr}');
    final nodeRun = await Process.run('node', [jsOut]);
    expect(nodeRun.exitCode, 0, reason: '${nodeRun.stdout}\n${nodeRun.stderr}');
    expect(nodeRun.stdout, '85:prod\n');

    // 5. quds test runs inline when test: block and sees private _applyDiscount + FakePromo + mode=="test"
    final testOne = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', pricing.path],
      workingDirectory: sandbox.path,
    );
    expect(testOne.exitCode, 0, reason: '${testOne.stdout}\n${testOne.stderr}');
    expect(testOne.stdout,
        contains('ok private helper and test-only mock class work'));
    expect(testOne.stdout, contains('ok public pricing works'));

    // 6. quds test lib discovers files containing when test: automatically
    final testDir = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', 'lib'],
      workingDirectory: sandbox.path,
    );
    expect(testDir.exitCode, 0, reason: '${testDir.stdout}\n${testDir.stderr}');
    expect(testDir.stdout, contains('1/1 test file passed.'));

    // 7. -n filtering works inside when test: blocks
    final filtered = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', '-n', 'internals', pricing.path],
      workingDirectory: sandbox.path,
    );
    expect(filtered.exitCode, 0,
        reason: '${filtered.stdout}\n${filtered.stderr}');
    expect(filtered.stdout,
        contains('ok private helper and test-only mock class work'));
    expect(filtered.stdout, isNot(contains('ok public pricing works')));
  }, timeout: const Timeout.factor(4));
}
