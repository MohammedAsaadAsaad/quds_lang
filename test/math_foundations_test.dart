import 'dart:io';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test('math foundations actual Quds API executes on VM and JavaScript',
      () async {
    final directory =
        Directory.systemTemp.createTempSync('quds-math-foundations-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('test/math_foundations_web.quds');
    final compiled = compile(input.readAsStringSync(), file: input.path);
    writeSdkBundles(directory.path, compiled);
    final emitted = File('${directory.path}/program.dart')
      ..writeAsStringSync(compiled.dart);
    final analyze = await Process.run(Platform.resolvedExecutable,
        ['analyze', '--fatal-infos', emitted.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm =
        await Process.run(Platform.resolvedExecutable, ['run', emitted.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, 'MATH FOUNDATIONS VM WEB OK\n');
    final js = '${directory.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', emitted.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final web = await Process.run('node', [js]);
    expect(web.exitCode, 0, reason: '${web.stdout}\n${web.stderr}');
    expect(web.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
