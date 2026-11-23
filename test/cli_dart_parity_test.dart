import 'dart:io';

import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

Future<ProcessResult> _quds(List<String> args, {String? workingDirectory}) {
  return Process.run(
    Platform.resolvedExecutable,
    [_qudsBin, ...args],
    workingDirectory: workingDirectory,
  );
}

void main() {
  test(
      'global --version, per-command --help, dart passthrough, and direct .quds execution',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-cli-global-');
    addTearDown(() => sandbox.deleteSync(recursive: true));

    for (final flag in ['--version', '-v', 'version']) {
      final res = await _quds([flag]);
      expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
      expect(res.stdout, contains('Quds CLI'));
      expect(res.stdout, contains('Dart'));
    }

    for (final cmd in [
      'build',
      'compile',
      'run',
      'analyze',
      'test',
      'format',
      'create',
      'doc',
    ]) {
      final res = await _quds([cmd, '--help']);
      expect(res.exitCode, 0, reason: '$cmd --help failed: ${res.stderr}');
      expect(res.stdout, contains('quds $cmd'));
    }

    final dartPass = await _quds(['dart', '--version']);
    expect(dartPass.exitCode, 0, reason: '${dartPass.stderr}');
    expect('${dartPass.stdout}${dartPass.stderr}', contains('Dart SDK'));

    final infoHelp = await _quds(['info', '--help']);
    expect(infoHelp.exitCode, 0, reason: '${infoHelp.stderr}');

    final script = File('${sandbox.path}/hi.quds')
      ..writeAsStringSync(
          'main(args: List<String>):\n  print "hi {args.first}"\n');
    final direct = await _quds([script.path, 'Quds']);
    expect(direct.exitCode, 0, reason: '${direct.stdout}\n${direct.stderr}');
    expect(direct.stdout, 'hi Quds\n');
  }, timeout: const Timeout.factor(4));

  test('quds compile builds native exe, js, and kernel artifacts from .quds',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-cli-compile-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final app = File('${sandbox.path}/hello.quds')..writeAsStringSync('''
use quds:text

main():
  print "  quds compile  ".trim().capitalized()
''');

    // 1. native exe
    final exeOut = '${sandbox.path}/hello_bin';
    final exeRes = await _quds(['compile', 'exe', '-o', exeOut, app.path],
        workingDirectory: sandbox.path);
    expect(exeRes.exitCode, 0, reason: '${exeRes.stdout}\n${exeRes.stderr}');
    expect(File(exeOut).existsSync(), isTrue);
    final runExe = await Process.run(exeOut, const []);
    expect(runExe.exitCode, 0, reason: '${runExe.stdout}\n${runExe.stderr}');
    expect(runExe.stdout, 'Quds compile\n');

    // 2. js + node execution
    final jsOut = '${sandbox.path}/hello.js';
    final jsRes = await _quds(['compile', 'js', '-o', jsOut, app.path],
        workingDirectory: sandbox.path);
    expect(jsRes.exitCode, 0, reason: '${jsRes.stdout}\n${jsRes.stderr}');
    expect(File(jsOut).existsSync(), isTrue);
    final runJs = await Process.run('node', [jsOut]);
    expect(runJs.exitCode, 0, reason: '${runJs.stdout}\n${runJs.stderr}');
    expect(runJs.stdout, 'Quds compile\n');

    // 3. kernel with default output path beside source (.dill)
    final kernelRes = await _quds(['compile', 'kernel', app.path],
        workingDirectory: sandbox.path);
    expect(kernelRes.exitCode, 0,
        reason: '${kernelRes.stdout}\n${kernelRes.stderr}');
    final dillFile = File('${sandbox.path}/hello.dill');
    expect(dillFile.existsSync(), isTrue);
    final runDill =
        await Process.run(Platform.resolvedExecutable, [dillFile.path]);
    expect(runDill.exitCode, 0, reason: '${runDill.stdout}\n${runDill.stderr}');
    expect(runDill.stdout, 'Quds compile\n');

    // 4. invalid target -> exit 64
    final badTarget = await _quds(['compile', 'bogus', app.path]);
    expect(badTarget.exitCode, 64);
  }, timeout: const Timeout.factor(4));

  test('quds run supports -e/--eval, -D/--define, and --[no-]enable-asserts',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-cli-run-');
    addTearDown(() => sandbox.deleteSync(recursive: true));

    final evalRes = await _quds(['run', '-e', 'print 20 + 22']);
    expect(evalRes.exitCode, 0, reason: '${evalRes.stdout}\n${evalRes.stderr}');
    expect(evalRes.stdout, '42\n');

    final defineFile = File('${sandbox.path}/env.quds')..writeAsStringSync('''
main():
  mode = String.fromEnvironment("MODE", defaultValue: "none")
  print mode
''');
    final def1 = await _quds(['run', '-DMODE=release', defineFile.path]);
    expect(def1.exitCode, 0, reason: '${def1.stdout}\n${def1.stderr}');
    expect(def1.stdout, 'release\n');

    final def2 =
        await _quds(['run', '--define', 'MODE=staging', defineFile.path]);
    expect(def2.exitCode, 0, reason: '${def2.stdout}\n${def2.stderr}');
    expect(def2.stdout, 'staging\n');

    final assertFile = File('${sandbox.path}/asserts.quds')
      ..writeAsStringSync('''
main():
  assert(false)
  print "passed"
''');
    final noAsserts =
        await _quds(['run', '--no-enable-asserts', assertFile.path]);
    expect(noAsserts.exitCode, 0,
        reason: '${noAsserts.stdout}\n${noAsserts.stderr}');
    expect(noAsserts.stdout, 'passed\n');

    final withAsserts =
        await _quds(['run', '--enable-asserts', assertFile.path]);
    expect(withAsserts.exitCode, isNot(0));

    final unknownFlag = await _quds(['run', '--bogus-flag', assertFile.path]);
    expect(unknownFlag.exitCode, 64);
  }, timeout: const Timeout.factor(2));

  test(
      'quds analyze supports directories and --fatal-infos/--no-fatal-warnings',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-cli-analyze-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    Directory('${sandbox.path}/lib').createSync();
    File('${sandbox.path}/lib/a.quds')
        .writeAsStringSync('add(a: int, b: int) -> int = a + b\n');
    File('${sandbox.path}/lib/b.quds')
        .writeAsStringSync('main():\n  print 1\n');

    final ok = await _quds(['analyze', '--fatal-infos'],
        workingDirectory: sandbox.path);
    expect(ok.exitCode, 0, reason: '${ok.stdout}\n${ok.stderr}');
    expect(ok.stdout, contains('Analyzed 2 files: no issues found.'));

    File('${sandbox.path}/lib/broken.quds')
        .writeAsStringSync('main():\n  print missingName\n');
    final bad = await _quds(['analyze', sandbox.path]);
    expect(bad.exitCode, 65);
    expect(bad.stderr, contains('E200'));
    expect(bad.stderr, contains('1 failed'));
  }, timeout: const Timeout.factor(2));

  test(
      'quds test supports default test/ discovery, -n/-N filters, --fail-fast, and asserts',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-cli-test-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    Directory('${sandbox.path}/test').createSync();

    File('${sandbox.path}/test/math_test.quds').writeAsStringSync('''
group "math":
  test "add":
    expect(1 + 2, 3)
  test "mul":
    expect(2 * 3, 6)
test "alpha check":
  assert(true)
  expect(true, isTrue)
''');
    File('${sandbox.path}/test/other_test.quds').writeAsStringSync('''
test "beta check":
  expect("ok", "ok")
''');

    // 1. Default discovery runs test/*_test.quds
    final all = await _quds(['test'], workingDirectory: sandbox.path);
    expect(all.exitCode, 0, reason: '${all.stdout}\n${all.stderr}');
    expect(all.stdout, contains('2/2 test files passed.'));

    // 2. -n regex filter matches group + test name
    final filtered = await _quds(
      ['test', '-n', 'math add', 'test/math_test.quds'],
      workingDirectory: sandbox.path,
    );
    expect(filtered.exitCode, 0,
        reason: '${filtered.stdout}\n${filtered.stderr}');
    expect(filtered.stdout, contains('ok add'));
    expect(filtered.stdout, isNot(contains('ok mul')));
    expect(filtered.stdout, isNot(contains('ok alpha check')));

    // 3. -N plain substring filter
    final plain = await _quds(
      ['test', '-N', 'alpha', 'test/math_test.quds'],
      workingDirectory: sandbox.path,
    );
    expect(plain.exitCode, 0, reason: '${plain.stdout}\n${plain.stderr}');
    expect(plain.stdout, contains('ok alpha check'));
    expect(plain.stdout, isNot(contains('ok math')));

    // 4. --fail-fast stops after first failure
    final failSuite = File('${sandbox.path}/fail_test.quds')
      ..writeAsStringSync('''
test "first fails":
  expect(1, 2)
test "second skipped by fail-fast":
  print "SHOULD_NOT_RUN"
  expect(1, 1)
''');
    final ff = await _quds(['test', '--fail-fast', failSuite.path]);
    expect(ff.exitCode, 1);
    expect(ff.stdout, contains('FAIL first fails:'));
    expect(ff.stdout, isNot(contains('SHOULD_NOT_RUN')));
  }, timeout: const Timeout.factor(2));

  test(
      'quds create templates (package, cli, --force), format -o/-l, default build, and doc -o',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-cli-create-');
    addTearDown(() => sandbox.deleteSync(recursive: true));

    // 1. create -t package
    final pkgCreate = await _quds(['create', '-t', 'package', 'my_pkg'],
        workingDirectory: sandbox.path);
    expect(pkgCreate.exitCode, 0,
        reason: '${pkgCreate.stdout}\n${pkgCreate.stderr}');
    final pkgDir = '${sandbox.path}/my_pkg';
    expect(File('$pkgDir/lib/my_pkg.quds').existsSync(), isTrue);
    expect(File('$pkgDir/lib/src/my_pkg_base.quds').existsSync(), isTrue);
    expect(File('$pkgDir/test/my_pkg_test.quds').existsSync(), isTrue);

    final pkgTest = await _quds(['test'], workingDirectory: pkgDir);
    expect(pkgTest.exitCode, 0, reason: '${pkgTest.stdout}\n${pkgTest.stderr}');

    final pkgBuild =
        await _quds(['build', '--package'], workingDirectory: pkgDir);
    expect(pkgBuild.exitCode, 0,
        reason: '${pkgBuild.stdout}\n${pkgBuild.stderr}');
    expect(File('$pkgDir/lib/my_pkg.dart').existsSync(), isTrue);

    // 2. create -t cli + --force
    final cliCreate = await _quds(['create', '--template=cli', 'my_cli'],
        workingDirectory: sandbox.path);
    expect(cliCreate.exitCode, 0,
        reason: '${cliCreate.stdout}\n${cliCreate.stderr}');
    final cliDir = '${sandbox.path}/my_cli';
    final cliRun = await _quds(['run', 'bin/my_cli.quds', 'World'],
        workingDirectory: cliDir);
    expect(cliRun.exitCode, 0, reason: '${cliRun.stdout}\n${cliRun.stderr}');
    expect(cliRun.stdout, 'Hello, World!\n');

    final noForce = await _quds(['create', '-t', 'cli', 'my_cli'],
        workingDirectory: sandbox.path);
    expect(noForce.exitCode, 73);
    final withForce = await _quds(['create', '-t', 'cli', '--force', 'my_cli'],
        workingDirectory: sandbox.path);
    expect(withForce.exitCode, 0);

    // 3. default quds build (no file arg -> builds main.quds)
    final consoleCreate =
        await _quds(['create', 'app_default'], workingDirectory: sandbox.path);
    expect(consoleCreate.exitCode, 0);
    final defBuild =
        await _quds(['build'], workingDirectory: '${sandbox.path}/app_default');
    expect(defBuild.exitCode, 0,
        reason: '${defBuild.stdout}\n${defBuild.stderr}');
    expect(
      File('${sandbox.path}/app_default/.dart_tool/quds/out/main.dart')
          .existsSync(),
      isTrue,
    );

    // 4. format -o show, -o none --set-exit-if-changed, -l 100
    final messy = File('${sandbox.path}/messy.quds')
      ..writeAsStringSync('main():\n  x=1+2\n  print x\n');
    final fmtShow =
        await _quds(['format', '-o', 'show', '-l', '100', messy.path]);
    expect(fmtShow.exitCode, 0, reason: '${fmtShow.stderr}');
    expect(fmtShow.stdout, contains('x = 1 + 2'));
    expect(messy.readAsStringSync(), contains('x=1+2')); // untouched!

    final fmtNone = await _quds(
        ['format', '-o', 'none', '--set-exit-if-changed', messy.path]);
    expect(fmtNone.exitCode, 1);
    expect(messy.readAsStringSync(), contains('x=1+2')); // still untouched!

    // 5. doc -o <dir> on package lib/
    final docOutDir = '${sandbox.path}/doc_html';
    final docRes = await _quds(['doc', '-o', docOutDir, '$pkgDir/lib']);
    expect(docRes.exitCode, 0, reason: '${docRes.stdout}\n${docRes.stderr}');
    expect(File('$docOutDir/my_pkg.html').existsSync(), isTrue);
    expect(File('$docOutDir/my_pkg.html').readAsStringSync(),
        contains('Returns a greeting from my_pkg.'));
  }, timeout: const Timeout.factor(3));
}
