import 'dart:io';

import 'package:quds_lang/src/sdk.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

void main() {
  test('embedded quds:json matches lib/sdk/json.quds', () {
    final disk = File('lib/sdk/json.quds').readAsStringSync().trimRight();
    expect(embeddedSdk['json']?.trimRight(), disk);
  });

  test('quds test passes primary quds:json suite', () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', 'test/json_sdk.quds'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('ok parseJson, parseJsonObject'));
    expect(result.stdout, contains('ok jsonPath and typed jsonRequire'));
  }, timeout: const Timeout.factor(4));

  test('quds:json strict analyze and VM / JS parity pass', () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-json-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final entry = File('${sandbox.path}/app.quds')..writeAsStringSync('''
use quds:json

readName(src: String) -> Result<String, JsonError>:
  obj = parseJsonObject(src)?
  return jsonRequireString(obj, "name")

main():
  data: Map<String, Object?> = map:
    "name": "Quds"
    "ver": 1
  encoded = encodeJson(data)
  match readName(encoded):
    Ok(name):
      print "{name}|{encoded}"
    Error(err):
      print err.toString()
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
    expect(run.stdout, 'Quds|{"name":"Quds","ver":1}\n');

    final jsOut = '${sandbox.path}/app.js';
    final jsBuild = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'compile', 'js', '-o', jsOut, entry.path],
      workingDirectory: sandbox.path,
    );
    expect(jsBuild.exitCode, 0, reason: '${jsBuild.stdout}\n${jsBuild.stderr}');
    final nodeRun = await Process.run('node', [jsOut]);
    expect(nodeRun.exitCode, 0, reason: '${nodeRun.stdout}\n${nodeRun.stderr}');
    expect(nodeRun.stdout, 'Quds|{"name":"Quds","ver":1}\n');
  }, timeout: const Timeout.factor(4));
}
