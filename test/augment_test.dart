import 'dart:io';
import 'dart:convert';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  for (final name in ['augment', 'augment_parts', 'augment_import']) {
    test('Quds augment conformance $name', () async {
      final result = await Process.run(Platform.resolvedExecutable,
          ['run', 'bin/quds.dart', 'test', 'test/$name.quds']);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect('${result.stdout}'.split('\n').where((l) => l.startsWith('ok ')),
          hasLength(name == 'augment' ? 3 : 1));
    });
  }
  for (final body in [
    'class A:\n  value: int = 1\naugment A:\n  value: int = 2\n',
    'class A:\n  read() -> int = 1\naugment A:\n  read() -> int = 2\n',
    'class A:\n  value: int = 1\naugment A extends Object:\n  extra: int = 0\n',
    'augment int:\n  value: int = 0\n',
    'augment int:\n  init():\n    print 1\n',
    'class A<T>:\n  value: T required\naugment A<int>:\n  read() -> int = 1\n',
  ])
    test('rejects invalid augment $body', () {
      expect(() => compile(body, file: 'invalid_augment.quds'),
          throwsA(isA<CompilerException>()));
    });
  test('merged part members retain their original source file', () {
    final file = File('test/fixtures/augment/owner.quds').absolute;
    final result = compile(file.readAsStringSync(), file: file.path);
    final part = File('test/fixtures/augment/addition.quds').absolute.path;
    expect((jsonDecode(result.sourceMap!) as Map)['sources'], contains(part));
    final line = SourcePositions.parse(result.sourceMap!).generated(part, 4)!;
    expect(result.dart.split('\n')[line - 1], contains('+='));
  });
  test('augment emits valid standalone Dart on VM and JavaScript', () async {
    final dir = Directory.systemTemp.createTempSync('quds-augment-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final result = compile('''class Counter:
  var value: int = 0
augment Counter:
  increment():
    value += 1
augment int:
  readonly squared() -> int = this * this
main():
  value = Counter()
  value.increment()
  number = 5
  check number.squared() == 25
  check value.value == 1
  print "AUGMENT OK"
''');
    final output = File('${dir.path}/program.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(dir.path, result);
    final analyze = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', output.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, 'AUGMENT OK\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', output.path, '-o', '${dir.path}/program.js']);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final js = await Process.run('node', ['${dir.path}/program.js']);
    expect(js.exitCode, 0, reason: '${js.stdout}\n${js.stderr}');
    expect(js.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
