import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

final cli = File('bin/quds.dart').absolute.path;

class Project {
  Project(this.root);
  final Directory root;
  File file(String path) {
    final f = File('${root.path}/$path');
    f.parent.createSync(recursive: true);
    return f;
  }

  Future<ProcessResult> run(List<String> args) =>
      Process.run(Platform.resolvedExecutable, [cli, ...args],
          workingDirectory: root.path,
          environment: {
            'PATH': '${root.path}/bin:${Platform.environment['PATH']}'
          });
  List<List<dynamic>> get calls => file('calls').existsSync()
      ? file('calls')
          .readAsLinesSync()
          .map((s) => jsonDecode(s) as List)
          .toList()
      : [];
}

Future<Project> project({bool flutter = true}) async {
  final root = Directory.systemTemp.createTempSync('quds-project-');
  addTearDown(() => root.deleteSync(recursive: true));
  final p = Project(root);
  p.file('pubspec.yaml').writeAsStringSync(
      'name: sample\nenvironment:\n  sdk: ">=3.3.0 <4.0.0"\n${flutter ? 'dependencies:\n  flutter:\n    sdk: flutter\n' : ''}');
  p
      .file('lib/main.quds')
      .writeAsStringSync('main():\n  print "project entry"\n');
  final script = p.file('fake.dart')..writeAsStringSync(r'''
import 'dart:io'; import 'dart:convert';
void main(List<String> args) {
 File('calls').writeAsStringSync(jsonEncode(args)+'\n',mode:FileMode.append,flush:true);
 if(args.first=='create') {
  Directory('linux').createSync();
  Directory('web').createSync();
  File('pubspec.yaml').writeAsStringSync('name: overwritten\ndependencies:\n  flutter:\n    sdk: flutter\n');
  Directory('lib').createSync();File('lib/main.dart').writeAsStringSync('// generated dart');
  Directory('test').createSync();File('test/widget_test.dart').writeAsStringSync('// generated test');
 }
 if (File('fail').existsSync()) { stderr.writeln('backend error'); exit(17); }
 stdout.writeln('backend ok');
}
''');
  final launcher = p.file('bin/flutter')
    ..writeAsStringSync(
        '#!/bin/sh\nexec "${Platform.resolvedExecutable}" "${script.path}" "\$@"\n');
  await Process.run('chmod', ['+x', launcher.path]);
  return p;
}

void success(ProcessResult result) =>
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
void main() {
  test('flutter clean forwards arguments, cwd, output and failure status',
      () async {
    final p = await project();
    final result = await p.run(['flutter', 'clean', '--verbose']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(p.calls.last, ['clean', '--verbose']);
    expect(result.stdout, contains('backend ok'));
    p.file('fail').writeAsStringSync('fail');
    final failed = await p.run(['flutter', 'clean']);
    expect(failed.exitCode, 17);
    expect(failed.stderr, contains('backend error'));
    expect((await p.run(['flutter'])).exitCode, 64);
  });

  test('pub forwards arbitrary Flutter subcommands, options and exit status',
      () async {
    final p = await project();
    success(await p.run(['pub', 'upgrade', '--major-versions', '--offline']));
    success(
        await p.run(['pub', 'future-command', '--future-option=hello world']));
    expect(p.calls[0], ['pub', 'upgrade', '--major-versions', '--offline']);
    expect(
        p.calls[1], ['pub', 'future-command', '--future-option=hello world']);
    p.file('fail').writeAsStringSync('fail');
    final failed = await p.run(['pub', 'get']);
    expect(failed.exitCode, 17);
    expect(failed.stderr, contains('backend error'));
  });
  test('pub delegates actual offline Dart resolution in a non-Flutter project',
      () async {
    final p = await project(flutter: false);
    success(await p.run(['pub', 'get', '--offline']));
    expect(p.file('pubspec.lock').existsSync(), true);
    final deps = await p.run(['pub', 'deps', '--json']);
    success(deps);
    expect(jsonDecode(deps.stdout as String)['root'], 'sample');
    expect(p.calls, isEmpty);
    p.file('nested/pubspec.yaml').writeAsStringSync(
        'name: nested\ndependencies: {flutter: {sdk: flutter}}\n');
    success(await p.run(['pub', '-Cnested', 'get']));
    expect(p.calls.last, ['pub', '-Cnested', 'get']);
  });
  test(
      'create . adds platforms and preserves source, pubspec entries and Dart user files',
      () async {
    final p = await project(flutter: false);
    p.file('pubspec.yaml').writeAsStringSync(
        'name: sample\n# retained comment\nenvironment:\n  sdk: ">=3.3.0 <4.0.0"\ndependencies: {matcher: ^0.12.16}\n');
    p.file('lib/main.dart').writeAsStringSync('// user bootstrap');
    p.file('test/widget_test.dart').writeAsStringSync('// user test');
    final source = p.file('lib/main.quds').readAsStringSync();
    success(await p.run(['create', '.', '--platforms=linux,web', '--no-pub']));
    expect(p.calls.single, contains('--platforms=linux,web'));
    expect(p.calls.single, contains('--no-pub'));
    expect(p.file('lib/main.quds').readAsStringSync(), source);
    expect(p.file('lib/main.dart').readAsStringSync(), '// user bootstrap');
    expect(p.file('test/widget_test.dart').readAsStringSync(), '// user test');
    final spec = p.file('pubspec.yaml').readAsStringSync();
    expect(spec, contains('retained comment'));
    expect(spec, contains('matcher'));
    expect(spec, contains('sdk: flutter'));
    success(await p.run(['run', '-d', 'linux', '--release']));
    expect(p.calls.last, contains('lib/quds_gen/main.dart'));
    expect(Directory('${p.root.path}/linux').existsSync(), true);
    expect(p.file('.gitignore').readAsStringSync(), contains('lib/quds_gen/'));
  });
  test(
      'create . removes newly generated Dart starters and invokes pub get unless disabled',
      () async {
    final p = await project();
    success(await p.run(['create', '.', '--platforms=web']));
    expect(p.file('lib/main.dart').existsSync(), false);
    expect(p.file('test/widget_test.dart').existsSync(), false);
    expect(p.calls.last, ['pub', 'get']);
    p.file('fail').writeAsStringSync('fail');
    final before = p.file('pubspec.yaml').readAsStringSync();
    expect((await p.run(['create', '.', '--no-pub'])).exitCode, 17);
    expect(p.file('pubspec.yaml').readAsStringSync(), before);
  });
  test(
      'run autodetects entry; supports debug, profile, release and Quds target options',
      () async {
    final p = await project();
    for (final mode in ['--debug', '--profile', '--release']) {
      success(await p.run(
          ['run', '-d', 'linux', mode, '--dart-define=TITLE=hello world']));
      final args = p.calls.last;
      expect(args, contains('lib/quds_gen/main.dart'));
      expect(args, contains(mode));
      expect(args, contains('linux'));
      expect(args.contains('--machine'), mode == '--debug');
      expect(p.file('lib/quds_gen/main.dart').readAsStringSync(),
          contains('project entry'));
    }
    p.file('lib/other.quds').writeAsStringSync('main():\n  print "other"\n');
    success(await p
        .run(['run', '--target=lib/other.quds', '-d', 'chrome', '--release']));
    expect(p.calls.last, contains('lib/quds_gen/other.dart'));
    expect((await p.run(['run', '--debug', '--release'])).exitCode, 64);
  });
  test(
      'platform build prepares Quds graph and forwards native flags and failures',
      () async {
    final p = await project();
    p.file('lib/main.quds').writeAsStringSync(
        'use browser when platform == "web"\nuse native when platform != "web"\nmain():\n  print choice()\n');
    p
        .file('lib/browser.quds')
        .writeAsStringSync('choice() -> String = "browser"\n');
    p
        .file('lib/native.quds')
        .writeAsStringSync('choice() -> String = "native"\n');
    for (final target in ['apk', 'web', 'linux']) {
      success(await p.run(['build', target, '--release', '--build-number=3']));
      expect(p.calls.last, [
        'build',
        target,
        '-t',
        'lib/quds_gen/main.dart',
        '--release',
        '--build-number=3'
      ]);
      expect(
          p.file('lib/quds_gen/main.dart').readAsStringSync(),
          contains(target == 'web'
              ? "import 'browser.dart'"
              : "import 'native.dart'"));
    }
    p.file('lib/second.quds').writeAsStringSync('main():\n  print "second"\n');
    success(await p.run(['build', 'appbundle', '-t', 'lib/second.quds']));
    expect(p.calls.last, contains('lib/quds_gen/second.dart'));
    p.file('fail').writeAsStringSync('fail');
    expect((await p.run(['build', 'linux'])).exitCode, 17);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
