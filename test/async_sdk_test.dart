import 'dart:io';

import 'package:quds/src/sdk.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

void main() {
  test('embedded quds:async matches lib/sdk/async.quds', () {
    final disk = File('lib/sdk/async.quds').readAsStringSync().trimRight();
    expect(embeddedSdk['async']?.trimRight(), disk);
  });

  test('quds test passes primary quds:async suite', () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', 'test/async_sdk.quds'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('ok Semaphore bounds concurrency'));
    expect(result.stdout, contains('ok Channel supports unbounded'));
    expect(
        result.stdout, contains('ok CancellationSource and CancellationToken'));
    expect(result.stdout, contains('ok withTimeout, withTimeoutOrNull'));
    expect(result.stdout, contains('ok waitAll, race, mapConcurrent'));
    expect(result.stdout, contains('ok AsyncGate, BroadcastChannel'));
  }, timeout: const Timeout.factor(4));

  test('quds:async strict analyze and VM / JS parity pass', () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-async-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final entry = File('${sandbox.path}/app.quds')..writeAsStringSync('''
use quds:async

doubleAsync(n: int) async -> int:
  await sleep(2ms)
  return n * 2

main() async:
  mapped = await mapConcurrent<int, int>([1, 2, 3], 2, (n) -> doubleAsync(n))
  bus = BroadcastChannel<String>()
  sub = bus.subscribe()
  bus.publish("hi")
  bus.close()
  msgs = await drainChannel<String>(sub)
  okVal = await withTimeout<int>(200ms, () -> doubleAsync(5))
  gate = AsyncGate()
  gate.open()
  await gate.wait()
  print "{mapped}|{msgs}|{okVal}"
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
    expect(run.stdout, '[2, 4, 6]|[hi]|10\n');

    final jsOut = '${sandbox.path}/app.js';
    final jsBuild = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'compile', 'js', '-o', jsOut, entry.path],
      workingDirectory: sandbox.path,
    );
    expect(jsBuild.exitCode, 0, reason: '${jsBuild.stdout}\n${jsBuild.stderr}');
    final nodeRun = await Process.run(
      'node',
      [
        '-e',
        'globalThis.self = globalThis; require(process.argv[1]);',
        jsOut,
      ],
    );
    expect(nodeRun.exitCode, 0, reason: '${nodeRun.stdout}\n${nodeRun.stderr}');
    expect(nodeRun.stdout, '[2, 4, 6]|[hi]|10\n');
  }, timeout: const Timeout.factor(4));
}
