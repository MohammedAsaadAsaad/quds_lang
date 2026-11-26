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

  test(
      'hosted pub.dev package installs editor support without mutating pub cache',
      () async {
    final root = Directory.systemTemp.createTempSync('quds-hosted-install-');
    addTearDown(() => root.deleteSync(recursive: true));
    final home = Directory('${root.path}/home')..createSync();
    final pubCache = Directory('${root.path}/pub_cache')..createSync();
    final pubBin = Directory('${pubCache.path}/bin')..createSync();
    File('${pubBin.path}/${Platform.isWindows ? 'quds.bat' : 'quds'}')
        .writeAsStringSync('echo quds\n');
    final hostedPkg =
        Directory('${pubCache.path}/hosted/pub.dev/quds-0.1.0-alpha.2')
          ..createSync(recursive: true);
    final extSrc = Directory('${hostedPkg.path}/editors/vscode')
      ..createSync(recursive: true);
    Directory('${extSrc.path}/syntaxes').createSync();
    Directory('${extSrc.path}/icons').createSync();
    File('${extSrc.path}/package.json').writeAsStringSync(
        '{"name":"quds","publisher":"quds-lang","version":"0.1.0"}\n');
    File('${extSrc.path}/extension.js').writeAsStringSync('// ok\n');
    File('${extSrc.path}/language-configuration.json')
        .writeAsStringSync('{}\n');
    File('${extSrc.path}/README.md').writeAsStringSync('# Quds\n');
    File('${extSrc.path}/syntaxes/quds.tmLanguage.json')
        .writeAsStringSync('{}\n');
    File('${extSrc.path}/icons/quds.png').writeAsBytesSync([0, 1, 2, 3]);
    Directory('${home.path}/.claude').createSync(recursive: true);
    final emptyBin = Directory('${root.path}/empty_bin')..createSync();

    final runner = File('${root.path}/hosted_runner.dart')
      ..writeAsStringSync('''
import 'dart:io';
import 'package:quds/src/toolchain.dart';

Future<void> main(List<String> args) async {
  final pkg = Directory(args[0]);
  final nonHosted = Directory(args[1]);
  if (!isHostedPubCachePackage(pkg)) {
    stderr.writeln('Expected hosted package to be detected');
    exitCode = 2;
    return;
  }
  if (isHostedPubCachePackage(nonHosted)) {
    stderr.writeln('Did not expect non-hosted directory to be detected');
    exitCode = 3;
    return;
  }
  exitCode = await installToolchain(
    packageRoot: pkg,
    extensionSource: Directory('\${pkg.path}/editors/vscode'),
    extensionId: 'quds-lang.quds-0.1.0',
    extensionFiles: const [
      'package.json',
      'extension.js',
      'language-configuration.json',
      'README.md',
      'syntaxes/quds.tmLanguage.json',
      'icons/quds.png',
    ],
    vsixBytes: () => const <int>[],
  );
}
''');
    final env = {
      'HOME': home.path,
      'USERPROFILE': home.path,
      'XDG_CONFIG_HOME': '${home.path}/.config',
      'PUB_CACHE': pubCache.path,
      'PATH': emptyBin.path,
      'QUDS_INSTALL_OFFLINE': '1',
    };
    final run = await Process.run(
      Platform.resolvedExecutable,
      [
        '--packages=${File('.dart_tool/package_config.json').absolute.path}',
        runner.path,
        hostedPkg.path,
        root.path,
      ],
      environment: env,
    );
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect('${run.stdout}', contains('Using active quds command from pub.dev'));
    expect(
      Directory('${hostedPkg.path}/.dart_tool').existsSync(),
      isFalse,
      reason: 'Hosted pub cache package must not be mutated',
    );
    expect(
      File('${home.path}/.vscode/extensions/quds-lang.quds-0.1.0/package.json')
          .existsSync(),
      isTrue,
    );
    final lspJson =
        File('${home.path}/.quds/claude-marketplace/plugins/quds/.lsp.json')
            .readAsStringSync();
    expect(lspJson, contains('"args":["lsp"]'));
    expect(lspJson, isNot(contains('bin/quds.dart')));
  });
}
