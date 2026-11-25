import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test(
      'F5 save/reload refreshes Quds graph; manual restart and error recovery use DAP',
      () async {
    final root = Directory.systemTemp.createTempSync('quds-f5-');
    addTearDown(() => root.deleteSync(recursive: true));
    File file(String path) {
      final f = File('${root.path}/$path');
      f.parent.createSync(recursive: true);
      return f;
    }

    file('pubspec.yaml').writeAsStringSync(
        'name: f5_app\ndependencies:\n  flutter:\n    sdk: flutter\n');
    file('lib/main.quds')
        .writeAsStringSync('use helper\nmain():\n  print message()\n');
    file('lib/helper.quds')
        .writeAsStringSync('use broken when platform != "web"\n'
            'message() -> String = "initial"\n');
    file('lib/broken.quds').writeAsStringSync('invalid ??? native syntax\n');
    final fixture = File('test/fixtures/flutter_debug_peer.dart').absolute;
    final flutter = file('bin/flutter')
      ..writeAsStringSync(
          '#!/bin/sh\nexec "${Platform.resolvedExecutable}" "${fixture.path}" "\$@"\n');
    await Process.run('chmod', ['+x', flutter.path]);
    final child = await Process.start(
        Platform.resolvedExecutable,
        [
          File('bin/quds.dart').absolute.path,
          'debug',
          file('lib/main.quds').path
        ],
        workingDirectory: root.path,
        environment: {
          'PATH': '${root.path}/bin:${Platform.environment['PATH']}'
        });
    final messages = <Map<String, dynamic>>[], buffer = <int>[];
    final errors = StringBuffer();
    child.stderr.transform(utf8.decoder).listen(errors.write);
    final stream = child.stdout.listen((chunk) {
      buffer.addAll(chunk);
      while (true) {
        var boundary = -1;
        for (var i = 0; i + 3 < buffer.length; i++) {
          if (buffer[i] == 13 &&
              buffer[i + 1] == 10 &&
              buffer[i + 2] == 13 &&
              buffer[i + 3] == 10) {
            boundary = i;
            break;
          }
        }
        if (boundary < 0) break;
        final size = int.parse(RegExp(r'Content-Length: (\d+)')
            .firstMatch(ascii.decode(buffer.sublist(0, boundary)))![1]!);
        final start = boundary + 4;
        if (buffer.length < start + size) break;
        messages.add(
            jsonDecode(utf8.decode(buffer.sublist(start, start + size)))
                as Map<String, dynamic>);
        buffer.removeRange(0, start + size);
      }
    });
    List<Map> calls() => file('dap-calls').existsSync()
        ? file('dap-calls')
            .readAsLinesSync()
            .map((l) => jsonDecode(l) as Map)
            .toList()
        : [];
    Future<void> until(bool Function() condition) async {
      final end = DateTime.now().add(const Duration(seconds: 20));
      while (!condition() && DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      expect(condition(), true, reason: '$messages\n$errors');
    }

    void send(int seq, String command, [Map<String, dynamic>? args]) =>
        child.stdin.write(encodeFrame({
          'seq': seq,
          'type': 'request',
          'command': command,
          'arguments': args ?? {}
        }));
    try {
      send(1, 'launch',
          {'program': file('lib/main.quds').path, 'deviceId': 'chrome'});
      await until(
          () => messages.any((m) => m['event'] == 'flutter.appStarted'));
      expect(jsonDecode(file('adapter-args').readAsStringSync()),
          ['debug-adapter']);
      expect(calls().first['arguments']['program'],
          endsWith('lib/quds_gen/main.dart'));
      // Imported breakpoints must use the initial web graph's maps too; a
      // separate default-native compile would load the deliberately invalid file.
      send(10, 'setBreakpoints', {
        'source': {'path': file('lib/helper.quds').path},
        'breakpoints': [
          {'line': 2}
        ]
      });
      await until(() => calls().last['command'] == 'setBreakpoints');
      expect(calls().last['arguments']['source']['path'],
          endsWith('lib/quds_gen/helper.dart'));
      file('lib/helper.quds').writeAsStringSync(
          '# shifted source\n\nmessage() -> String = "saved"\n');
      await until(() => calls().any((m) => m['command'] == 'hotReload'));
      expect(calls().last['helper'], contains('saved'));
      expect(
          messages.where(
              (m) => m['type'] == 'response' && (m['request_seq'] as int) < 0),
          isEmpty);
      send(2, 'hotRestart');
      await until(() => messages
          .any((m) => m['type'] == 'response' && m['request_seq'] == 2));
      expect(calls().last['command'], 'hotRestart');
      send(3, 'setBreakpoints', {
        'source': {'path': file('lib/helper.quds').path},
        'breakpoints': [
          {'line': 3}
        ]
      });
      await until(() => calls().last['command'] == 'setBreakpoints');
      final positions = SourcePositions.parse(
          file('lib/quds_gen/helper.dart.map').readAsStringSync());
      final generatedLine =
          positions.generated(file('lib/helper.quds').path, 3);
      expect(generatedLine, isNotNull);
      expect(calls().last['arguments']['source']['path'],
          endsWith('lib/quds_gen/helper.dart'));
      expect(calls().last['arguments']['breakpoints'], [
        {'line': generatedLine}
      ]);

      final previous = file('lib/quds_gen/helper.dart').readAsStringSync();
      final count = calls().length;
      file('lib/helper.quds')
          .writeAsStringSync('message() -> String = unknown\n');
      await until(() => messages.any((m) =>
          m['event'] == 'output' && '${m['body']}'.contains('helper.quds')));
      expect(calls().length, count);
      expect(file('lib/quds_gen/helper.dart').readAsStringSync(), previous);
      send(4, 'hotReload');
      await until(() => messages
          .any((m) => m['type'] == 'response' && m['request_seq'] == 4));
      expect(
          messages.firstWhere((m) =>
              m['type'] == 'response' && m['request_seq'] == 4)['success'],
          false);
      expect(calls().length, count);
      file('lib/helper.quds')
          .writeAsStringSync('message() -> String = "recovered"\n');
      await until(() => calls().length > count);
      expect(calls().last['helper'], contains('recovered'));
      send(5, 'disconnect');
      await child.stdin.flush();
      await until(() => messages
          .any((m) => m['type'] == 'response' && m['request_seq'] == 5));
      await child.stdin.close();
      await child.exitCode.timeout(const Duration(seconds: 5));
    } finally {
      child.kill();
      await child.stdin.close();
      await stream.cancel();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
  test(
      'editor hot-update commands save first and require an active Quds session',
      () async {
    final result =
        await Process.run('node', ['test/editor/vscode_hot_updates.cjs']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('VSCODE HOT UPDATES OK'));
  });
}
