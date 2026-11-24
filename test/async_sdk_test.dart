import 'dart:io';

import 'package:quds_lang/src/sdk.dart';
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
  }, timeout: const Timeout.factor(4));

  test('quds:async strict analyze and VM / JS parity pass', () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-async-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final entry = File('${sandbox.path}/app.quds')..writeAsStringSync('''
use quds:async

sendAll(ch: Channel<int>) async -> void:
  for n in [10, 20, 30]:
    await ch.send(n)
  ch.close()

main() async:
  sem = Semaphore(permits: 1)
  lock sem:
    ch = Channel<int>(capacity: 2)
    p = sendAll(ch)
    items = await drainChannel<int>(ch)
    await p
    cts = CancellationSource()
    cts.cancel("ok")
    print "{items}|{cts.token().reason()}"
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
    expect(run.stdout, '[10, 20, 30]|ok\n');

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
    expect(nodeRun.stdout, '[10, 20, 30]|ok\n');
  }, timeout: const Timeout.factor(4));
}
