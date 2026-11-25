import 'dart:io';

import 'package:quds/quds.dart';
import 'package:quds/src/complete.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

void main() {
  test('Quds using/Disposable primary suite passes quds test', () async {
    final testRun = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', 'test/using_disposable.quds'],
    );
    expect(testRun.exitCode, 0, reason: '${testRun.stdout}\n${testRun.stderr}');
  }, timeout: const Timeout.factor(3));

  test(
      'using rejects non-disposable values, nullable resources, and sync using async',
      () {
    expect(
      () => compile('main():\n  using x = 42:\n    print x\n'),
      throwsA(predicate((e) => '$e'.contains('dispose or close'))),
    );
    expect(
      () => compile('''
use quds:core
class Res implements Disposable:
  dispose() -> void:
    print "x"
main():
  maybe: Res? = Res()
  using r = maybe:
    print 1
'''),
      throwsA(predicate((e) => '$e'.contains('dispose or close'))),
    );
    expect(
      () => compile('''
use quds:core
class Res implements AsyncDisposable:
  dispose() async -> void:
    print "x"
main():
  using async r = Res()
  print 1
'''),
      throwsA(predicate((e) => '$e'.contains('E803'))),
    );
  });

  test('formatter and LSP completion support scoped using statements', () {
    const raw = '''
use quds:core
class Temp implements Disposable:
  tag: String
  dispose() -> void:
    print tag
main():
  using t=Temp(tag:"ok")
  print t.tag
''';
    final formatted = formatQuds(raw);
    expect(formatted, contains('using t = Temp(tag: "ok")'));
    expect(formatQuds(formatted), formatted);

    const completeSource = '''
use quds:core
class Temp implements Disposable:
  tag: String
  dispose() -> void:
    print tag
main():
  using t = Temp(tag: "ok")
  print t.
''';
    final lines = completeSource.split('\n');
    final items = completeAt(
      source: completeSource,
      line: lines.length - 2,
      character: lines[lines.length - 2].length,
      compileSource: (text) {
        try {
          return compile(text);
        } catch (_) {
          return null;
        }
      },
    );
    final labels = [for (final item in items) item['label'] as String];
    expect(labels, containsAll(['tag', 'dispose']));
  });

  test('scoped using + Disposable + StreamController match on Dart VM and JS',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-using-parity-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final src = File('${sandbox.path}/app.quds')..writeAsStringSync('''
use quds:core
use dart:async show StreamController

class Box implements Disposable:
  name: String
  dispose() -> void:
    print "drop:{name}"

main() async:
  using a = Box(name: "A")
  using async sc = StreamController<int>.broadcast()
  sc.add(1)
  print "body:{a.name}:{sc.isClosed}"
''');

    final analyze = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'analyze', '--fatal-infos', src.path],
      workingDirectory: sandbox.path,
    );
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');

    final vm = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'run', src.path],
      workingDirectory: sandbox.path,
    );
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, 'body:A:false\ndrop:A\n');

    final jsOut = '${sandbox.path}/app.js';
    final jsCompile = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'compile', 'js', '-o', jsOut, src.path],
      workingDirectory: sandbox.path,
    );
    expect(jsCompile.exitCode, 0,
        reason: '${jsCompile.stdout}\n${jsCompile.stderr}');
    final jsRun = await Process.run('node', [jsOut]);
    expect(jsRun.exitCode, 0, reason: '${jsRun.stdout}\n${jsRun.stderr}');
    expect(jsRun.stdout, vm.stdout);
  }, timeout: const Timeout.factor(3));
}
