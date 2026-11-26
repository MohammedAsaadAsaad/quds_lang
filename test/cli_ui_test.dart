import 'dart:io';

import 'package:quds/src/cli_ui.dart';
import 'package:test/test.dart';

void main() {
  group('extractGlobalCliFlags', () {
    test('preserves quds -v as version and parses --verbose / -V / -q', () {
      final version = extractGlobalCliFlags(['-v'], environment: const {});
      expect(version.arguments, ['-v']);
      expect(version.verbose, isFalse);

      final before =
          extractGlobalCliFlags(['--verbose', 'build'], environment: const {});
      expect(before.arguments, ['build']);
      expect(before.verbose, isTrue);

      final after = extractGlobalCliFlags(['analyze', '-v', 'a.quds'],
          environment: const {});
      expect(after.arguments, ['analyze', 'a.quds']);
      expect(after.verbose, isTrue);

      final quiet = extractGlobalCliFlags(['test', '-q', 't.quds'],
          environment: const {});
      expect(quiet.arguments, ['test', 't.quds']);
      expect(quiet.quiet, isTrue);
    });

    test('never strips flags belonging to user program or raw passthrough', () {
      final runProgram = extractGlobalCliFlags(
          ['run', 'app.quds', '-v', '--quiet'],
          environment: const {});
      expect(runProgram.arguments, ['run', 'app.quds', '-v', '--quiet']);
      expect(runProgram.verbose, isFalse);
      expect(runProgram.quiet, isFalse);

      final runBeforeEntry = extractGlobalCliFlags(
          ['run', '-v', 'app.quds', '-q'],
          environment: const {});
      expect(runBeforeEntry.arguments, ['run', 'app.quds', '-q']);
      expect(runBeforeEntry.verbose, isTrue);
      expect(runBeforeEntry.quiet, isFalse);

      final dartPass = extractGlobalCliFlags(['dart', 'analyze', '-v'],
          environment: const {});
      expect(dartPass.arguments, ['dart', 'analyze', '-v']);
      expect(dartPass.verbose, isFalse);

      final afterDash =
          extractGlobalCliFlags(['build', '--', '-v'], environment: const {});
      expect(afterDash.arguments, ['build', '--', '-v']);
      expect(afterDash.verbose, isFalse);
    });
  });

  group('CLI formatting, live progress, and verbosity', () {
    Future<ProcessResult> runQuds(
      List<String> args, {
      String? workingDirectory,
      Map<String, String>? env,
    }) {
      return Process.run(
        Platform.resolvedExecutable,
        ['run', '${Directory.current.path}/bin/quds.dart', ...args],
        workingDirectory: workingDirectory,
        environment: env,
      );
    }

    test('help is organized into clear sections with global options', () async {
      final help = await runQuds(['help']);
      expect(help.exitCode, 0, reason: '${help.stderr}');
      final out = '${help.stdout}';
      expect(out, contains('Global Options'));
      expect(out, contains('--verbose'));
      expect(out, contains('--quiet'));
      expect(out, contains('Build & Run'));
      expect(out, contains('Code Quality & Docs'));
      expect(out, contains('Projects & Packages'));
      expect(out, contains('Toolchain & Editors'));

      final topic = await runQuds(['help', 'compile']);
      expect(topic.exitCode, 0, reason: '${topic.stderr}');
      expect('${topic.stdout}', contains('Quds — compile'));
      expect('${topic.stdout}', contains('Global options:'));
    });

    test(
        'run, analyze, test, and build emit progress on stderr without polluting stdout',
        () async {
      final dir = Directory.systemTemp.createTempSync('quds-cli-ui-');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/app.quds')
          .writeAsStringSync('main():\n  print "hello-ui"\n');
      File('${dir.path}/sample_test.quds').writeAsStringSync('''
test "adds":
  expect(1 + 2, equals(3))
''');

      // 1. Verbose run keeps stdout pure and prints detailed trace to stderr.
      final verboseRun = await runQuds(['run', '--verbose', 'app.quds'],
          workingDirectory: dir.path);
      expect(verboseRun.exitCode, 0, reason: '${verboseRun.stderr}');
      expect('${verboseRun.stdout}'.replaceAll('\r\n', '\n'), 'hello-ui\n');
      expect('${verboseRun.stderr}', contains('[quds] Compiling app.quds'));
      expect('${verboseRun.stderr}', contains('[quds] Exited with code 0'));

      // 2. Interactive TTY minimal progress writes to stderr and keeps stdout pure.
      final ttyRun = await runQuds(
        ['run', 'app.quds'],
        workingDirectory: dir.path,
        env: {'QUDS_CLI_TTY': '1'},
      );
      expect(ttyRun.exitCode, 0, reason: '${ttyRun.stderr}');
      expect('${ttyRun.stdout}'.replaceAll('\r\n', '\n'), 'hello-ui\n');
      expect('${ttyRun.stderr}', contains('Compiling app.quds'));

      // 3. Quiet suppresses interactive progress on stderr.
      final quietRun = await runQuds(
        ['run', '-q', 'app.quds'],
        workingDirectory: dir.path,
        env: {'QUDS_CLI_TTY': '1'},
      );
      expect(quietRun.exitCode, 0, reason: '${quietRun.stderr}');
      expect('${quietRun.stdout}'.replaceAll('\r\n', '\n'), 'hello-ui\n');
      expect('${quietRun.stderr}'.trim(), isEmpty);

      // 4. Verbose build, analyze, and test report structured steps on stderr.
      final verboseBuild = await runQuds(['build', '-v', 'app.quds'],
          workingDirectory: dir.path);
      expect(verboseBuild.exitCode, 0, reason: '${verboseBuild.stderr}');
      expect('${verboseBuild.stderr}', contains('Build finished'));

      final verboseAnalyze = await runQuds(['analyze', '-v', 'app.quds'],
          workingDirectory: dir.path);
      expect(verboseAnalyze.exitCode, 0, reason: '${verboseAnalyze.stderr}');
      expect('${verboseAnalyze.stderr}', contains('Analysis finished'));

      final verboseTest = await runQuds(['test', '-v', 'sample_test.quds'],
          workingDirectory: dir.path);
      expect(verboseTest.exitCode, 0, reason: '${verboseTest.stderr}');
      expect('${verboseTest.stdout}', contains('ok adds'));
      expect('${verboseTest.stderr}', contains('Test run finished'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
