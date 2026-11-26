import 'dart:io';
import 'package:quds/quds.dart';
import 'package:test/test.dart';
import 'package:quds/src/dart_api.dart';

void main() {
  test('typed top getters survive setters without hiding a function named get',
      () {
    final root = Directory.systemTemp.createTempSync('quds-native-getter-');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = File('${root.path}/api.dart')
      ..writeAsStringSync(
          'int get answer => 7;\nset answer(int value) {}\nint get(int value) => value + 1;\n');
    final surface = readDartFile(file)!;
    expect(surface.names['answer']!.type, 'int');
    expect(surface.names['answer']!.callable, false);
    expect(surface.names['get']!.callable, true);
    final io = readDartLibrary('dart:io')!;
    expect(io.names['stdout']!.type, 'Stdout');
    expect(io.names['stdout']!.callable, false);
    expect(io.names['exitCode']!.type, 'int');
    expect(io.names['exitCode']!.callable, false);
  });

  test('string repetition conformance runs primarily in Quds', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/string_repeat.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(
        '${result.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(3));
  });

  test('native console write adds no newline', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'run', 'test/console_repeat_vm.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect('${result.stdout}'.replaceAll('\r\n', '\n'),
        'somesomesomesomesome|xx!\ndone\n');
  });
  test(
      'repetition preserves constants, order and awaited operands on VM and JS',
      () async {
    final input = File('test/string_repeat_web.quds').absolute;
    final result = compile(input.readAsStringSync(), file: input.path);
    expect(result.dart,
        File('test/goldens/string_repeat.dart.txt').readAsStringSync());
    expect(
        result.dart, compile(input.readAsStringSync(), file: input.path).dart);
    final root = Directory.systemTemp.createTempSync('quds-repeat-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    const repeated = 'somesomesomesomesome';
    const expected =
        '$repeated\n$repeated\n$repeated\nSC\n$repeated\nCS\n$repeated\nCS\ntrue\n';
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}${vm.stderr}');
    expect('${vm.stdout}'.replaceAll('\r\n', '\n'), expected);
    final js = '${root.path}/main.js';
    final built = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(built.exitCode, 0, reason: '${built.stdout}${built.stderr}');
    final run = await Process.run('node',
        ['-e', 'globalThis.self = globalThis; require(process.argv[1]);', js]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.replaceAll('\r\n', '\n'), expected);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
