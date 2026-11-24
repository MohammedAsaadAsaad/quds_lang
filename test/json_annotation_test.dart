import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

void main() {
  test('quds test passes primary @Json annotation suite', () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', 'test/json_annotation.quds'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('ok @Json on enum encodes'));
    expect(result.stdout, contains('ok @Json on value class roundtrips'));
    expect(result.stdout, contains('ok @Json on sealed type roundtrips'));
  }, timeout: const Timeout.factor(4));

  test('@Json and @JsonKey reject invalid targets and unsupported field types',
      () {
    expect(
      () => compile('''
@Json
class Box<T>:
  value: T required
''', file: 'bad_json_generic.quds'),
      throwsA(isA<CompilerException>()),
    );

    expect(
      () => compile('''
@Json
interface Bad:
  x: int
''', file: 'bad_json_interface.quds'),
      throwsA(isA<CompilerException>()),
    );

    expect(
      () => compile('''
class Plain:
  x: int = 1

@Json
class Holder:
  plain: Plain required
''', file: 'bad_json_nested.quds'),
      throwsA(isA<CompilerException>()),
    );

    expect(
      () => compile('''
@Json
class BadIgnore:
  @JsonKey(ignore: true)
  mustHave: int required
''', file: 'bad_json_ignore.quds'),
      throwsA(isA<CompilerException>()),
    );

    expect(
      () => compile('''
@Json
class DupKey:
  @JsonKey(name: "id")
  a: int = 1
  @JsonKey(name: "id")
  b: int = 2
''', file: 'bad_json_dup.quds'),
      throwsA(isA<CompilerException>()),
    );

    expect(
      () => compile('''
@Json
class BadMap:
  items: Map<int, String> = map:
''', file: 'bad_json_map.quds'),
      throwsA(isA<CompilerException>()),
    );
  });

  test('@Json cross-library import, strict analyze, and VM / JS parity pass',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-atjson-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    File('${sandbox.path}/models.quds').writeAsStringSync('''
@Json
enum Status:
  active
  paused

@Json
value class Profile:
  @JsonKey(name: "user_name")
  userName: String required
  status: Status = Status.active
''');
    final entry = File('${sandbox.path}/app.quds')..writeAsStringSync('''
use models

@Json
value class Wrapper:
  profile: Profile required
  count: int = 1

main():
  w = Wrapper(profile: Profile(userName: "quds", status: Status.paused), count: 3)
  encoded = w.toJsonString()
  back = Wrapper.fromJsonString(encoded)
  print "{back.profile.userName}:{back.profile.status.toJson()}:{back.count}"
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
    expect(run.stdout, 'quds:paused:3\n');

    final jsOut = '${sandbox.path}/app.js';
    final jsBuild = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'compile', 'js', '-o', jsOut, entry.path],
      workingDirectory: sandbox.path,
    );
    expect(jsBuild.exitCode, 0, reason: '${jsBuild.stdout}\n${jsBuild.stderr}');
    final nodeRun = await Process.run('node', [jsOut]);
    expect(nodeRun.exitCode, 0, reason: '${nodeRun.stdout}\n${nodeRun.stderr}');
    expect(nodeRun.stdout, 'quds:paused:3\n');
  }, timeout: const Timeout.factor(4));
}
