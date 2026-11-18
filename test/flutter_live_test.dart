import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

class LiveApp {
  LiveApp(this.root, this.process);
  final Directory root;
  final Process process;
  String output = '';
  String errors = '';
  File file(String path) => File('${root.path}/$path');
  List<Map> get requests => !file('requests').existsSync()
      ? []
      : file('requests')
          .readAsLinesSync()
          .map((s) => jsonDecode(s) as Map)
          .toList();
  Future<void> until(bool Function() condition) async {
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (!condition() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    expect(condition(), isTrue, reason: '$output\n$errors');
  }

  Future<void> stop() async {
    process.stdin.write('q');
    await process.stdin.flush();
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill();
      await process.exitCode;
    }
    await process.stdin.close();
  }
}

Future<LiveApp> launch(
    {bool delayed = false, List<String> arguments = const []}) async {
  final root = Directory.systemTemp.createTempSync('quds-hot-');
  addTearDown(() => root.deleteSync(recursive: true));
  File('${root.path}/pubspec.yaml').writeAsStringSync(
      'name: hot_probe\ndependencies:\n  flutter:\n    sdk: flutter\n');
  Directory('${root.path}/lib').createSync();
  File('${root.path}/lib/helper.quds')
      .writeAsStringSync('message() -> String = "first"\n');
  File('${root.path}/lib/main.quds')
      .writeAsStringSync('use helper\nmain():\n  print message()\n');
  if (delayed) File('${root.path}/delay').writeAsStringSync('yes');
  final fake = File('${root.path}/fake.dart')..writeAsStringSync(r'''
import 'dart:io';
import 'dart:convert';
import 'dart:async';
void send(Map message) => stdout.writeln(jsonEncode([message]));
Future<void> main(List<String> args) async {
  File('arguments').writeAsStringSync(jsonEncode(args));
  File('boot').writeAsStringSync('ready');
  send({'event':'app.start','params':{'appId':'test-app'}});
  if (File('delay').existsSync()) {
    while (!File('start-now').existsSync()) { await Future<void>.delayed(Duration(milliseconds:20)); }
  }
  send({'event':'app.started','params':{'appId':'test-app'}});
  await for (final line in stdin.transform(utf8.decoder).transform(LineSplitter())) {
    for (final command in jsonDecode(line) as List) {
      if (command['method'] == 'app.stop') { exit(0); }
      if (command['method'] != 'app.restart') { throw StateError('Unexpected $command'); }
      final record = Map.of(command);
      record['main'] = File('lib/quds_gen/main.dart').readAsStringSync();
      record['helper'] = File('lib/quds_gen/helper.dart').readAsStringSync();
      File('requests').writeAsStringSync(jsonEncode(record)+'\n', mode:FileMode.append,flush:true);
      if (File('hold').existsSync()) {
        while (File('hold').existsSync()) { await Future<void>.delayed(Duration(milliseconds:20)); }
      }
      send({'id':command['id'], 'result': File('reject').existsSync()
        ? {'code':1,'message':'requires restart'} : {'code':0}});
    }
  }
}
''');
  final bin = Directory('${root.path}/bin')..createSync();
  final flutter = File('${bin.path}/flutter')
    ..writeAsStringSync(
        '#!/bin/sh\nexec "${Platform.resolvedExecutable}" "${fake.path}" "\$@"\n');
  await Process.run('chmod', ['+x', flutter.path]);
  final child = await Process.start(Platform.resolvedExecutable, [
    File('bin/quds.dart').absolute.path,
    'run',
    '${root.path}/lib/main.quds',
    ...arguments
  ], environment: {
    'PATH': '${bin.path}:${Platform.environment['PATH']}'
  });
  final app = LiveApp(root, child);
  child.stdout.transform(utf8.decoder).listen((s) => app.output += s);
  child.stderr.transform(utf8.decoder).listen((s) => app.errors += s);
  addTearDown(app.stop);
  await app.until(() =>
      app.file('boot').existsSync() &&
      app.output.contains('watching saved sources'));
  return app;
}

void main() {
  test(
      'save reloads imported Quds; invalid dependency keeps all output; R restarts',
      () async {
    final app = await launch();
    expect(jsonDecode(app.file('arguments').readAsStringSync()),
        ['run', '--machine', '-t', 'lib/quds_gen/main.dart']);
    app
        .file('lib/helper.quds')
        .writeAsStringSync('message() -> String = "second"\n');
    await app.until(() => app.requests.length == 1);
    expect(app.requests[0]['helper'], contains('second'));
    expect(app.requests[0]['params']['fullRestart'], false);
    await app.until(() => app.output.contains('update completed'));
    final previousMain = app.file('lib/quds_gen/main.dart').readAsStringSync();
    final previousHelper =
        app.file('lib/quds_gen/helper.dart').readAsStringSync();
    app.file('lib/main.quds').writeAsStringSync(
        'use helper\nmain():\n  print "changed"\n  print message()\n');
    app
        .file('lib/helper.quds')
        .writeAsStringSync('message() -> String = unknown\n');
    await app.until(() => app.output.contains('compilation failed'));
    expect(app.errors, contains('helper.quds'));
    expect(app.file('lib/quds_gen/main.dart').readAsStringSync(), previousMain);
    expect(app.file('lib/quds_gen/helper.dart').readAsStringSync(),
        previousHelper);
    expect(app.requests.length, 1);
    // Atomic-save replacement and newly created imported module.
    app
        .file('lib/extra.quds')
        .writeAsStringSync('extra() -> String = "new module"\n');
    app
        .file('lib/replacement')
        .writeAsStringSync('use extra\nmessage() -> String = extra()\n');
    app.file('lib/replacement').renameSync(app.file('lib/helper.quds').path);
    await app.until(() => app.requests.length == 2);
    expect(app.file('lib/quds_gen/extra.dart').existsSync(), true);
    expect(app.requests[1]['main'], contains('changed'));
    app.process.stdin.write('R');
    await app.process.stdin.flush();
    await app.until(() => app.requests.length == 3);
    expect(app.requests[2]['params']['fullRestart'], true);
    expect(app.requests[2]['params']['appId'], 'test-app');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
      'startup saves and overlapping saves serialize; Flutter rejection permits retry',
      () async {
    final app = await launch(delayed: true, arguments: ['--', '-d', 'linux']);
    expect(jsonDecode(app.file('arguments').readAsStringSync()),
        ['run', '--machine', '-t', 'lib/quds_gen/main.dart', '-d', 'linux']);
    app
        .file('lib/helper.quds')
        .writeAsStringSync('message() -> String = "startup save"\n');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(app.requests, isEmpty);
    app.file('hold').writeAsStringSync('hold');
    app.file('reject').writeAsStringSync('reject');
    app.file('start-now').writeAsStringSync('go');
    await app.until(() => app.requests.length == 1);
    expect(app.requests[0]['helper'], contains('startup save'));
    app
        .file('lib/helper.quds')
        .writeAsStringSync('message() -> String = "during reload"\n');
    app.process.stdin.write('R');
    await app.process.stdin.flush();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(app.requests.length, 1);
    app.file('hold').deleteSync();
    await app.until(() => app.output.contains('Flutter rejected'));
    await app.until(() => app.requests.length == 2);
    expect(app.requests[1]['helper'], contains('during reload'));
    expect(app.requests[1]['params']['fullRestart'], true);
    app.file('reject').deleteSync();
    app
        .file('lib/helper.quds')
        .writeAsStringSync('message() -> String = "recovered"\n');
    await app.until(() => app.requests.length == 3);
    expect(app.requests[2]['params']['fullRestart'], false);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('foreign generated dependency is not overwritten or reloaded', () async {
    final app = await launch();
    final main = app.file('lib/quds_gen/main.dart').readAsStringSync();
    app
        .file('lib/quds_gen/helper.dart')
        .writeAsStringSync('// user-owned Dart\n');
    app
        .file('lib/helper.quds')
        .writeAsStringSync('message() -> String = "changed"\n');
    await app.until(() => app.output.contains('compilation failed'));
    expect(app.errors, contains('Refusing to overwrite'));
    expect(app.file('lib/quds_gen/helper.dart').readAsStringSync(),
        '// user-owned Dart\n');
    expect(app.file('lib/quds_gen/main.dart').readAsStringSync(), main);
    expect(app.requests, isEmpty);
    app.file('boot').deleteSync();
    final retry = await Process.run(Platform.resolvedExecutable, [
      File('bin/quds.dart').absolute.path,
      'run',
      app.file('lib/main.quds').path
    ], environment: {
      'PATH': '${app.root.path}/bin:${Platform.environment['PATH']}'
    });
    expect(retry.exitCode, 73);
    expect(app.file('boot').existsSync(), false,
        reason: 'An invalid initial graph must not launch Flutter');
    for (final option in [
      '--release',
      '--no-hot',
      '--target=other.dart',
      '-tother.dart'
    ]) {
      final invalid = await Process.run(Platform.resolvedExecutable, [
        File('bin/quds.dart').absolute.path,
        'run',
        app.file('lib/main.quds').path,
        '--',
        option,
      ], environment: {
        'PATH': '${app.root.path}/bin:${Platform.environment['PATH']}'
      });
      expect(invalid.exitCode, 64, reason: option);
      expect(app.file('boot').existsSync(), false);
    }
  });
}
