import 'dart:io';

import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test('readonly Dart boundary conformance executes in Quds', () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      ['run', 'bin/quds.dart', 'test', 'test/readonly_dart_boundaries.quds'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(
        result.stdout,
        contains(
            'ok readonly records, Result, MapEntry, Optional, sealed type, and extension types cross boundaries'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
      'readonly records, Result, MapEntry, Optional, and extension types enforce transitive immutability across Dart boundaries on VM and JS',
      () async {
    final dir = Directory.systemTemp.createTempSync('quds-ro-dart-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final input = File('test/readonly_dart_boundaries_web.quds');
    final compiled = compile(input.readAsStringSync(), file: input.path);
    File('${dir.path}/views.dart').writeAsStringSync(compiled.dart);
    writeSdkBundles(dir.path, compiled);
    final driver = File('${dir.path}/driver.dart')..writeAsStringSync(r'''
import 'views.dart' as q;

void check(bool ok, String msg) {
  if (!ok) throw StateError('Failed: $msg');
}

void blocked(void Function() run, String msg) {
  try {
    run();
  } on UnsupportedError {
    return;
  }
  throw StateError('Readonly boundary allowed mutation: $msg');
}

void main() {
  final xs = <int>[1, 2];
  final pair = q.exposePair(xs);
  blocked(() => pair.$1.add(3), 'positional record list add');
  blocked(() => pair.$1[0] = 9, 'positional record list set');
  xs[0] = 42;
  check(pair.$1[0] == 42 && pair.$2 == 'ok', 'positional record reflects owner write');

  final named = q.exposeNamed(xs);
  blocked(() => named.items.add(4), 'named record list add');
  check(named.items[0] == 42 && named.title == 'ok', 'named record reads cleanly');

  final okRes = q.exposeOk(xs);
  switch (okRes) {
    case q.Ok(:final value):
      blocked(() => value.add(5), 'Ok value list add');
      check(value[0] == 42, 'Ok value reads cleanly');
    case q.Error():
      throw StateError('Expected Ok');
  }

  final errs = <String>['bad'];
  final errRes = q.exposeErr(errs);
  switch (errRes) {
    case q.Error(:final error):
      blocked(() => error.add('more'), 'Error value list add');
      errs[0] = 'worse';
      check(error[0] == 'worse', 'Error value reflects owner write');
    case q.Ok():
      throw StateError('Expected Error');
  }

  final entry = q.exposeEntry(xs);
  blocked(() => entry.value.add(6), 'MapEntry value list add');
  check(entry.key == 'k' && entry.value[0] == 42, 'MapEntry reads cleanly');

  final opt = q.exposeOptPresent(xs);
  check(opt.isPresent, 'Optional present');
  blocked(() => opt.value!.add(7), 'Optional value list add');
  check(opt.value![0] == 42, 'Optional value reads cleanly');

  final optMissing = q.exposeOptMissing();
  check(!optMissing.isPresent, 'Optional missing');

  final safeList = q.exposeSafeList(q.SafeList(xs));
  blocked(() => (safeList as List<int>).add(8), 'extensionType wrapping List add');
  check((safeList as List<int>)[0] == 42, 'extensionType reads cleanly');

  final shape = q.exposeShape(q.Circle(r: 2.5));
  check(shape is q.Circle && shape.r == 2.5, 'deeply immutable sealed type');

  final uid = q.exposeUserId(q.UserId('u99'));
  check((uid as String) == 'u99', 'immutable extensionType');

  final cb = q.exposeCallback(() => 123);
  check(cb() == 123, 'function value passthrough');

  print('READONLY DART BOUNDARIES OK');
}
''');
    final analyze = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', driver.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm =
        await Process.run(Platform.resolvedExecutable, ['run', driver.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect('${vm.stdout}'.replaceAll('\r\n', '\n'),
        'READONLY DART BOUNDARIES OK\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', driver.path, '-o', '${dir.path}/driver.js']);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final js = await Process.run('node', [
      '-e',
      'globalThis.self = globalThis; require(process.argv[1]);',
      '${dir.path}/driver.js'
    ]);
    expect(js.exitCode, 0, reason: '${js.stdout}\n${js.stderr}');
    expect('${js.stdout}'.replaceAll('\r\n', '\n'),
        '${vm.stdout}'.replaceAll('\r\n', '\n'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  group('unsound readonly Dart boundaries stay rejected with E910', () {
    final rejects = <String, String>{
      'record containing mutable native File': '''
use dart:io
expose(f: File) -> readonly (int, File) = (1, f)
''',
      'Result containing mutable native File': '''
use dart:io
expose(f: File) -> readonly Result<File, String> = Ok(f)
''',
      'MapEntry containing mutable native File': '''
use dart:io
expose(f: File) -> readonly MapEntry<String, File> = MapEntry("k", f)
''',
      'sealed type containing mutable List field': '''
sealed type Bag:
  Box(items: List<int>)
expose(b: Bag) -> readonly Bag = b
''',
      'extension type wrapping mutable native File': '''
use dart:io
type FileHandle wraps File
expose(h: FileHandle) -> readonly FileHandle = h
''',
      'erased call passing record with mutable native File': '''
use dart:io
use dart:convert
main():
  r: readonly (int, File) = (1, File("unused"))
  print jsonEncode(r)
''',
    };
    for (final entry in rejects.entries) {
      test('rejects ${entry.key} with E910', () {
        expect(
          () => compile(entry.value),
          throwsA(isA<CompilerException>()
              .having((e) => e.code, 'code', equals('E910'))),
        );
      });
    }

    test(
        'preserves transitive readonly through match on readonly Result (E307)',
        () {
      expect(
        () => compile('''
main():
  r: readonly Result<List<int>, String> = Ok([1])
  match r:
    Ok(xs):
      xs[0] = 2
    Error(_):
      print "err"
'''),
        throwsA(isA<CompilerException>()
            .having((e) => e.code, 'code', equals('E307'))),
      );
    });

    test(
        'preserves transitive readonly through named record field access (E307)',
        () {
      expect(
        () => compile('''
main():
  r: readonly (items: List<int>, title: String) = (items: [1], title: "ok")
  r.items[0] = 2
'''),
        throwsA(isA<CompilerException>()
            .having((e) => e.code, 'code', equals('E307'))),
      );
    });
  });
}
