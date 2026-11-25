import 'dart:io';
import 'package:test/test.dart';

void main() {
  for (final valid in [true, false]) {
    test(
        'local activation reports ${valid ? 'success with an executable' : 'failure for an invalid package'}',
        () async {
      final root = Directory.systemTemp.createTempSync('quds-activation-');
      addTearDown(() => root.deleteSync(recursive: true));
      final package = Directory('${root.path}/package')..createSync();
      File('${package.path}/pubspec.yaml').writeAsStringSync(valid
          ? "name: quds_install_fixture\nenvironment:\n  sdk: '>=3.3.0 <4.0.0'\nexecutables:\n  quds_fixture: main\n"
          : '[invalid yaml');
      Directory('${package.path}/bin').createSync();
      File('${package.path}/bin/main.dart')
          .writeAsStringSync("void main() { print('fixture active'); }\n");
      final runner = File('${root.path}/runner.dart')..writeAsStringSync('''
import 'dart:io';
import 'package:quds/src/toolchain.dart';
void main(List<String> args) { exitCode = activateCommand(Directory(args.single)) ? 0 : 1; }
''');
      final environment = {
        'HOME': root.path,
        'USERPROFILE': root.path,
        'PUB_CACHE': '${root.path}/cache',
        'QUDS_INSTALL_OFFLINE': '1',
      };
      final run = await Process.run(
          Platform.resolvedExecutable,
          [
            '--packages=${File('.dart_tool/package_config.json').absolute.path}',
            runner.path,
            package.path
          ],
          environment: environment);
      expect(run.exitCode, valid ? 0 : 1, reason: '${run.stdout}${run.stderr}');
      if (valid) {
        final command =
            '${root.path}/cache/bin/quds_fixture${Platform.isWindows ? '.bat' : ''}';
        expect(File(command).existsSync(), true);
        final activated = await Process.run(command, [],
            environment: environment, runInShell: Platform.isWindows);
        expect(activated.exitCode, 0,
            reason: '${activated.stdout}${activated.stderr}');
        expect('${activated.stdout}'.replaceAll('\r\n', '\n'),
            endsWith('fixture active\n'));
      }
    });
  }
}
